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

        currentGeneration &+= 1
        activeToken = nil
        activeNavWorkKey = nil
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
