//
//  ReaderContentLoadCoordinator.swift
//  Maktabah
//
//  Downstream-owned coordinator managing asynchronous content loading generations and tokens.
//  Guarantees that stale or cancelled async responses never overwrite a newer page or active book.
//

import Foundation

/// Token uniquely identifying an asynchronous section content load request.
struct ReaderContentRequestToken: Equatable, Sendable {
    let id: UUID
    let generation: UInt64
    let backend: BackendID
    let workKey: String
    let sectionLocator: TextLocator
    let scrollTarget: ReaderScrollTarget?

    init(
        id: UUID = UUID(),
        generation: UInt64,
        backend: BackendID,
        workKey: String,
        sectionLocator: TextLocator,
        scrollTarget: ReaderScrollTarget? = nil
    ) {
        self.id = id
        self.generation = generation
        self.backend = backend
        self.workKey = workKey
        self.sectionLocator = sectionLocator
        self.scrollTarget = scrollTarget
    }
}

/// Thread-safe coordinator for tracking active content loading operations.
final class ReaderContentLoadCoordinator: @unchecked Sendable {
    private var currentGeneration: UInt64 = 0
    private var activeToken: ReaderContentRequestToken?
    private var activeNavGeneration: UInt64 = 0
    private var activeNavWorkKey: String?
    private let lock = NSLock()
    private let initialContentOwnerID = UUID()
    private var initialContentRevision: UInt64? = 0
    private var initialContentRequest: ReaderInitialContentRequest?
    private var initialContentPhase: ReaderInitialContentRequest.Phase?
    private var initialContentDestination: LibraryReaderDestination?
    private var initialContentToken: ReaderContentRequestToken?

    init() {}

    /// Begins a new load request, invalidating any prior in-flight request.
    @discardableResult
    func beginRequest(
        backend: BackendID,
        workKey: String,
        sectionLocator: TextLocator,
        scrollTarget: ReaderScrollTarget? = nil
    ) -> ReaderContentRequestToken {
        lock.lock()
        defer { lock.unlock() }

        retireInitialContentLocked()
        currentGeneration &+= 1
        let token = ReaderContentRequestToken(
            generation: currentGeneration,
            backend: backend,
            workKey: workKey,
            sectionLocator: sectionLocator,
            scrollTarget: scrollTarget
        )
        activeToken = token
        return token
    }

    /// Read the existing immutable request identity under the same lock used by
    /// begin/invalidate. Consumers can detect same-work reload/ABA without a
    /// second generation counter or a change to content publication semantics.
    func currentRequestToken() -> ReaderContentRequestToken? {
        lock.lock()
        defer { lock.unlock() }
        return activeToken
    }

    /// Verifies whether the provided token is still the active, non-superseded load request.
    func isTokenActive(_ token: ReaderContentRequestToken) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let active = activeToken else { return false }
        return active.id == token.id && active.generation == token.generation
    }

    /// Complete check verifying token is active AND current book workKey matches.
    func canApplyContent(
        token: ReaderContentRequestToken,
        currentBookLocator: TextLocator?
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let active = activeToken else { return false }
        guard active.id == token.id && active.generation == token.generation else { return false }
        guard let bookLocator = currentBookLocator else { return false }
        return bookLocator.backend == token.backend && bookLocator.workKey == token.workKey
    }

    /// Explicitly invalidates all currently active requests (e.g. on book switch, tab switch, or reset).
    func invalidate() {
        lock.lock()
        defer { lock.unlock() }

        retireInitialContentLocked()
        currentGeneration &+= 1
        activeToken = nil
        activeNavWorkKey = nil
    }

    // MARK: Original initial-content invocation ownership

    func initialContentSourceObservation() -> ReaderInitialContentSourceObservation? {
        lock.lock(); defer { lock.unlock() }
        guard let revision = initialContentRevision else { return nil }
        return .init(coordinator: self, ownerID: initialContentOwnerID,
            revision: revision, pendingRequestID: pendingInitialContentIDLocked)
    }

    func isInitialContentSourceCurrent(_ observation: ReaderInitialContentSourceObservation) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return observation.ownerID == initialContentOwnerID
            && initialContentRevision == observation.revision
            && pendingInitialContentIDLocked == observation.pendingRequestID
    }

    func beginInitialContentRequest(source: ReaderInitialContentRequest.Source,
                                    deadlineUptimeNanoseconds: UInt64? = nil) -> ReaderInitialContentRequest? {
        lock.lock(); defer { lock.unlock() }
        // Retire BEFORE any original setter/callback. Even an exhausted or
        // already-expired competing start cannot preserve an older observation.
        retireInitialContentLocked()
        activeToken = nil; activeNavWorkKey = nil
        guard let revision = initialContentRevision,
              deadlineUptimeNanoseconds.map({ DispatchTime.now().uptimeNanoseconds < $0 }) ?? true else { return nil }
        let request = ReaderInitialContentRequest(coordinator: self, source: source,
            revision: revision, deadlineUptimeNanoseconds: deadlineUptimeNanoseconds)
        initialContentRequest = request; initialContentPhase = .reserved
        initialContentDestination = source.originalDestination
        return request
    }

    /// Consume entry BEFORE loadTOC or any other original callback. A second
    /// caller cannot use the same handle, even with equal original arguments.
    func claimInitialContentRequest(_ request: ReaderInitialContentRequest,
                                     source: ReaderInitialContentRequest.Source) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request), initialContentPhase == .reserved,
              request.source == source else { return false }
        initialContentPhase = .resolving
        return true
    }

    /// The original resolver owns these outputs. Only this invocation can
    /// declare them, and it cannot cross the original book's qualified work.
    func recordInitialContentDestination(_ destination: LibraryReaderDestination,
                                         request: ReaderInitialContentRequest) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request),
              initialContentPhase == .resolving || initialContentPhase == .handingOff,
              destinationMatchesInitialBookLocked(destination, request: request) else { return false }
        initialContentDestination = destination
        return true
    }

    func beginInitialContentHandoff(_ request: ReaderInitialContentRequest,
                                    destination: LibraryReaderDestination) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request), initialContentPhase == .resolving,
              destinationMatchesInitialBookLocked(destination, request: request) else { return false }
        initialContentPhase = .handingOff
        return true
    }

    /// Same original token issuer, reached once by the retained pre-token
    /// invocation. No later current-token sample can substitute for this result.
    func beginRequest(continuing request: ReaderInitialContentRequest, backend: BackendID,
                      workKey: String, sectionLocator: TextLocator,
                      scrollTarget: ReaderScrollTarget? = nil) -> ReaderContentRequestToken? {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request), initialContentPhase == .handingOff,
              currentGeneration < .max, let book = request.source.bookLocator,
              backend == book.backend, workKey == book.workKey,
              sectionLocator.backend == backend, sectionLocator.workKey == workKey,
              initialContentDestination?.sectionLocator == sectionLocator else { return nil }
        // Consume the phase before the original token publication. There is no
        // callback, await, cancellation hook or rearming inside this lock.
        initialContentPhase = .issued
        currentGeneration += 1
        let token = ReaderContentRequestToken(generation: currentGeneration, backend: backend,
            workKey: workKey, sectionLocator: sectionLocator, scrollTarget: scrollTarget)
        initialContentToken = token; activeToken = token
        return token
    }

    func initialContentState(for request: ReaderInitialContentRequest) -> ReaderInitialContentRequest.State? {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request), let phase = initialContentPhase else { return nil }
        return .init(phase: phase, destination: initialContentDestination, token: initialContentToken)
    }

    func finishInitialContentRequest(_ request: ReaderInitialContentRequest) {
        lock.lock(); defer { lock.unlock() }
        guard isInitialContentCurrentLocked(request),
              initialContentPhase == .issued || initialContentPhase == .resolving else { return }
        initialContentPhase = .completed
    }

    func invalidateInitialContentRequest(_ request: ReaderInitialContentRequest) {
        lock.lock(); defer { lock.unlock() }
        guard initialContentRequest === request else { return }
        retireInitialContentLocked()
        activeToken = nil; activeNavWorkKey = nil
    }

    private var pendingInitialContentIDLocked: UUID? {
        initialContentPhase == .completed ? nil : initialContentRequest?.id
    }
    private func isInitialContentCurrentLocked(_ request: ReaderInitialContentRequest) -> Bool {
        initialContentRequest === request && initialContentRevision == request.sourceRevision
            && (initialContentPhase == .completed
                || (request.deadlineUptimeNanoseconds.map({ DispatchTime.now().uptimeNanoseconds < $0 }) ?? true))
    }
    private func destinationMatchesInitialBookLocked(_ destination: LibraryReaderDestination,
                                                      request: ReaderInitialContentRequest) -> Bool {
        guard let book = request.source.bookLocator,
              destination.sectionLocator.backend == book.backend,
              destination.sectionLocator.workKey == book.workKey else { return false }
        return destination.focusLocator.map { $0.backend == book.backend && $0.workKey == book.workKey } ?? true
    }
    private func retireInitialContentLocked() {
        if let revision = initialContentRevision, revision < .max { initialContentRevision = revision + 1 }
        else { initialContentRevision = nil }
        initialContentRequest = nil; initialContentPhase = nil
        initialContentDestination = nil; initialContentToken = nil
    }

    /// Begins a secondary navigation loading task for a specific workKey.
    func beginNavigationItemsRequest(for workKey: String) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }

        activeNavGeneration &+= 1
        activeNavWorkKey = workKey
        return activeNavGeneration
    }

    /// Checks if a navigation response generation is still authoritative for the current workKey.
    func isNavigationItemsRequestActive(generation: UInt64, workKey: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return activeNavGeneration == generation && activeNavWorkKey == workKey
    }

    func beginNavigationRequest(workKey: String) -> UInt64 {
        beginNavigationItemsRequest(for: workKey)
    }

    func canApplyNavigation(generation: UInt64, workKey: String) -> Bool {
        isNavigationItemsRequestActive(generation: generation, workKey: workKey)
    }
}
