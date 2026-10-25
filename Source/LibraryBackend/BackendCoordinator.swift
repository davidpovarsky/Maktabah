#if canImport(Combine)
import Combine
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

extension Notification.Name {
    static let activeLibraryBackendDidChange = Notification.Name("activeLibraryBackendDidChange")
    static let libraryBackendDataDidReload = Notification.Name("libraryBackendDataDidReload")
    static let libraryBackendConfigurationRequested = Notification.Name("libraryBackendConfigurationRequested")
}

/// Strongly-typed immutable payload representing a validated, pre-staged backend transition.
struct PreparedBackendTransition: Sendable, Equatable {
    let transitionToken: UInt64
    let outgoingBackend: BackendID
    let incomingBackend: BackendID
    let outgoingSnapshotData: Data?
    let incomingSnapshotData: Data?
    let isCleanDestination: Bool
    let stagedTabs: [StagedTabSession]
    let targetActiveTabId: UUID?
    let targetModeRaw: String?
    let createdAt: Date

    struct StagedTabSession: Sendable, Equatable {
        let id: UUID
        let bookId: Int
        let bookTitle: String
        let backendLocator: String?
        let contentId: Int?
        let locator: TextLocator?
        let page: Int?
        let part: Int?
        let scrollPosition: CGPoint?
        let selectedRange: NSRange?
        let expandedNodeIDs: [Int]?
        let sidebarScrollPosition: CGPoint?
        let isSidebarCollapsed: Bool?
        let searchText: String?
        let searchModeRaw: Int?
        let nearDistance: Int?
        let highlightTerms: [String]?

        init(
            id: UUID,
            bookId: Int,
            bookTitle: String,
            backendLocator: String?,
            contentId: Int? = nil,
            locator: TextLocator? = nil,
            page: Int? = nil,
            part: Int? = nil,
            scrollPosition: CGPoint? = nil,
            selectedRange: NSRange? = nil,
            expandedNodeIDs: [Int]? = nil,
            sidebarScrollPosition: CGPoint? = nil,
            isSidebarCollapsed: Bool? = nil,
            searchText: String? = nil,
            searchModeRaw: Int? = nil,
            nearDistance: Int? = nil,
            highlightTerms: [String]? = nil
        ) {
            self.id = id
            self.bookId = bookId
            self.bookTitle = bookTitle
            self.backendLocator = backendLocator
            self.contentId = contentId
            self.locator = locator
            self.page = page
            self.part = part
            self.scrollPosition = scrollPosition
            self.selectedRange = selectedRange
            self.expandedNodeIDs = expandedNodeIDs
            self.sidebarScrollPosition = sidebarScrollPosition
            self.isSidebarCollapsed = isSidebarCollapsed
            self.searchText = searchText
            self.searchModeRaw = searchModeRaw
            self.nearDistance = nearDistance
            self.highlightTerms = highlightTerms
        }
    }

    init(
        transitionToken: UInt64,
        outgoingBackend: BackendID,
        incomingBackend: BackendID,
        outgoingSnapshotData: Data?,
        incomingSnapshotData: Data?,
        isCleanDestination: Bool,
        stagedTabs: [StagedTabSession],
        targetActiveTabId: UUID?,
        targetModeRaw: String? = nil,
        createdAt: Date = Date()
    ) {
        self.transitionToken = transitionToken
        self.outgoingBackend = outgoingBackend
        self.incomingBackend = incomingBackend
        self.outgoingSnapshotData = outgoingSnapshotData
        self.incomingSnapshotData = incomingSnapshotData
        self.isCleanDestination = isCleanDestination
        self.stagedTabs = stagedTabs
        self.targetActiveTabId = targetActiveTabId
        self.targetModeRaw = targetModeRaw
        self.createdAt = createdAt
    }
}

enum BackendTransitionError: Error, Equatable, LocalizedError {
    case staleRequest
    case invalidTargetBackend(String)
    case capabilityUnavailable(BackendID)
    case outgoingPersistFailed(String)
    case missingTargetCatalog(BackendID)
    case unresolvableBook(bookId: Int, title: String, locator: String?)
    case foreignBackendLocator(locator: String, expectedBackend: BackendID)
    case corruptedSessionSnapshot(String)
    case transitionSuperseded

    var errorDescription: String? {
        switch self {
        case .staleRequest:
            return "The transition request is stale or was superseded."
        case .invalidTargetBackend(let id):
            return "Target backend '\(id)' is not a valid canonical backend."
        case .capabilityUnavailable(let id):
            return "Capability unavailable for backend '\(id.rawValue)'."
        case .outgoingPersistFailed(let msg):
            return "Failed to persist outgoing session: \(msg)"
        case .missingTargetCatalog(let id):
            return "Target catalog unavailable for backend '\(id.rawValue)'."
        case .unresolvableBook(let id, let title, let loc):
            return "Book id=\(id) title='\(title)' locator='\(loc ?? "nil")' cannot be resolved in target catalog."
        case .foreignBackendLocator(let loc, let exp):
            return "Locator '\(loc)' belongs to foreign backend; expected '\(exp.rawValue)'."
        case .corruptedSessionSnapshot(let msg):
            return "Corrupted session snapshot: \(msg)"
        case .transitionSuperseded:
            return "Transition was superseded by a newer request."
        }
    }
}

/// Lifecycle participant in the single-authority backend switch orchestration.
@MainActor
protocol BackendSwitchParticipant: AnyObject, Sendable {
    /// Phase 1 (Sync): Preflight validation and staging under CURRENT backend.
    /// Captures outgoing snapshot, validates target backend/locator/book against target catalog,
    /// and pre-stages incoming state in memory without destroying current tabs.
    /// Throws if any validation or snapshot operation fails.
    func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition?

    /// Phase 1 (Async): Async variant of prepareTransition for catalog loading / async preflight.
    func prepareTransitionAsync(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) async throws -> PreparedBackendTransition?

    /// Phase 2: Non-throwing publication after coordinator state commits.
    /// Installs pre-staged incoming tabs and updates UI controls.
    func publishTransition(to targetBackend: BackendID, transition: PreparedBackendTransition?)

    /// Phase 3: Finalization after notifications are posted.
    func completeTransition(to targetBackend: BackendID)

    /// Abort: Discards staged state. Current tabs and UI remain intact.
    func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error)
}

extension BackendSwitchParticipant {
    func prepareTransition(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) throws -> PreparedBackendTransition? {
        nil
    }

    func prepareTransitionAsync(from currentBackend: BackendID, to targetBackend: BackendID, token: UInt64) async throws -> PreparedBackendTransition? {
        try prepareTransition(from: currentBackend, to: targetBackend, token: token)
    }

    func completeTransition(to targetBackend: BackendID) {}
    func abortTransition(from currentBackend: BackendID, to targetBackend: BackendID, error: Error) {}
}

final class WeakSwitchParticipant: @unchecked Sendable {
    weak var value: (any BackendSwitchParticipant)?
    init(_ value: any BackendSwitchParticipant) {
        self.value = value
    }
}

@MainActor
final class BackendCoordinator {
    enum StartupResolution: Equatable {
        case chooseSource
        case configureOtzaria
        case ready(BackendID)
    }

    enum TransitionPhase: Equatable {
        case idle
        case preparing(from: BackendID, to: BackendID, token: UInt64)
        case failed(error: String)
    }

    static let shared = BackendCoordinator()
    nonisolated static let selectionDefaultsKey = "activeLibraryBackend.v1"

    #if canImport(Combine)
    @Published private(set) var activeBackendID: BackendID
    @Published private(set) var pendingBackendID: BackendID?
    @Published private(set) var generation: UInt64 = 0
    @Published private(set) var transitionPhase: TransitionPhase = .idle
    #else
    private(set) var activeBackendID: BackendID
    private(set) var pendingBackendID: BackendID?
    private(set) var generation: UInt64 = 0
    private(set) var transitionPhase: TransitionPhase = .idle
    #endif

    private(set) var activeTransitionToken: UInt64 = 0
    private var switchParticipants: [WeakSwitchParticipant] = []

    private var registrations: [BackendID: LibraryBackendRegistration] = [:]
    private var inFlightCancellations: [UUID: @Sendable () -> Void] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let committed = defaults.string(forKey: Self.selectionDefaultsKey)
            .flatMap(BackendID.init(rawValue:))
        activeBackendID = committed ?? .otzaria
        pendingBackendID = nil
    }

    var committedBackendID: BackendID? {
        defaults.string(forKey: Self.selectionDefaultsKey).flatMap(BackendID.init(rawValue:))
    }

    var activeCapabilities: BackendCapabilities {
        registrations[activeBackendID]?.capabilities ?? []
    }

    var capabilities: BackendCapabilities {
        activeCapabilities
    }

    var usesNativeMaktabahDataPath: Bool {
        registrations[activeBackendID]?.usesNativeMaktabahDataPath ?? true
    }

    var activeSourceDescription: String {
        registrations[activeBackendID]?.sourceDescription ?? activeBackendID.displayName
    }

    func register(_ registration: LibraryBackendRegistration) {
        registrations[registration.id] = registration
    }

    func beginConfiguration(of backendID: BackendID) {
        pendingBackendID = backendID
    }

    func cancelConfiguration() {
        pendingBackendID = nil
    }

    func resolveStartup(hasValidOtzariaInstallation: Bool) -> StartupResolution {
        switch committedBackendID {
        case .sefaria:
            return .ready(.sefaria)
        case .otzaria:
            return hasValidOtzariaInstallation ? .ready(.otzaria) : .configureOtzaria
        case nil:
            guard hasValidOtzariaInstallation else { return .chooseSource }
            commit(.otzaria)
            return .ready(.otzaria)
        }
    }

    func addSwitchParticipant(_ participant: any BackendSwitchParticipant) {
        switchParticipants.removeAll(where: { $0.value == nil })
        if !switchParticipants.contains(where: { $0.value === participant }) {
            switchParticipants.append(WeakSwitchParticipant(participant))
        }
    }

    func removeSwitchParticipant(_ participant: any BackendSwitchParticipant) {
        switchParticipants.removeAll(where: { $0.value === participant || $0.value == nil })
    }

    /// Two-phase fail-closed transition to targetBackend.
    /// Preflights and stages before modifying defaults, generation, activeBackendID, or posting notifications.
    @discardableResult
    func commit(_ backendID: BackendID) -> Bool {
        do {
            try performTwoPhaseSwitch(to: backendID)
            return true
        } catch {
            return false
        }
    }

    /// Throwing variant for callers that require explicit error reporting.
    func commitChecked(_ backendID: BackendID) throws {
        try performTwoPhaseSwitch(to: backendID)
    }

    /// Async variants for preflight with catalog resolution or async loading.
    @discardableResult
    func commitAsync(_ backendID: BackendID) async -> Bool {
        do {
            try await performTwoPhaseSwitchAsync(to: backendID)
            return true
        } catch {
            return false
        }
    }

    func commitCheckedAsync(_ backendID: BackendID) async throws {
        try await performTwoPhaseSwitchAsync(to: backendID)
    }

    /// Compatibility entry point for callers whose selection is immediately usable.
    func select(_ backendID: BackendID) {
        commit(backendID)
    }

    private func performTwoPhaseSwitch(to targetBackend: BackendID) throws {
        let wasCommitted = committedBackendID == targetBackend
        guard !wasCommitted || targetBackend != activeBackendID else {
            pendingBackendID = nil
            return
        }

        // Validate target backend canonicality
        guard targetBackend == .otzaria || targetBackend == .sefaria else {
            throw BackendTransitionError.invalidTargetBackend(targetBackend.rawValue)
        }

        // Validate registration if backends are registered
        if !registrations.isEmpty && registrations[targetBackend] == nil {
            throw BackendTransitionError.capabilityUnavailable(targetBackend)
        }

        let currentBackend = activeBackendID
        activeTransitionToken &+= 1
        let thisToken = activeTransitionToken
        transitionPhase = .preparing(from: currentBackend, to: targetBackend, token: thisToken)

        // Clean up dead participants
        switchParticipants.removeAll(where: { $0.value == nil })
        let activeParticipants = switchParticipants.compactMap { $0.value }

        // PHASE 1: PREPARE (Preflight and stage while currentBackend is STILL ACTIVE)
        var preparedTransitions: [ObjectIdentifier: PreparedBackendTransition?] = [:]
        do {
            for participant in activeParticipants {
                let transition = try participant.prepareTransition(from: currentBackend, to: targetBackend, token: thisToken)
                preparedTransitions[ObjectIdentifier(participant)] = transition
            }
        } catch {
            for participant in activeParticipants {
                participant.abortTransition(from: currentBackend, to: targetBackend, error: error)
            }
            transitionPhase = .failed(error: error.localizedDescription)
            // FAIL-CLOSED: defaults, activeBackendID, generation, cancellations remain UNTOUCHED!
            throw error
        }

        // Check if transition was superseded while preparing
        guard thisToken == activeTransitionToken else {
            let staleError = BackendTransitionError.transitionSuperseded
            for participant in activeParticipants {
                participant.abortTransition(from: currentBackend, to: targetBackend, error: staleError)
            }
            transitionPhase = .failed(error: staleError.localizedDescription)
            throw staleError
        }

        // PHASE 2: ATOMIC COORDINATOR COMMIT
        let oldRegistrations = registrations.values
        pendingBackendID = nil
        defaults.set(targetBackend.rawValue, forKey: Self.selectionDefaultsKey)
        inFlightCancellations.values.forEach { $0() }
        inFlightCancellations.removeAll()
        generation &+= 1
        activeBackendID = targetBackend
        transitionPhase = .idle

        Task {
            for registration in oldRegistrations {
                await registration.invalidateTransientState()
            }
        }

        // PHASE 3: NON-THROWING PARTICIPANT PUBLICATION (New activeBackendID is active)
        for participant in activeParticipants {
            let transition = preparedTransitions[ObjectIdentifier(participant)] ?? nil
            participant.publishTransition(to: targetBackend, transition: transition)
        }

        // PHASE 4: POST NOTIFICATION (Exactly once, after state & UI publication agree)
        NotificationCenter.default.post(name: .activeLibraryBackendDidChange, object: targetBackend)

        // PHASE 5: COMPLETE
        for participant in activeParticipants {
            participant.completeTransition(to: targetBackend)
        }
    }

    private func performTwoPhaseSwitchAsync(to targetBackend: BackendID) async throws {
        let wasCommitted = committedBackendID == targetBackend
        guard !wasCommitted || targetBackend != activeBackendID else {
            pendingBackendID = nil
            return
        }

        // Validate target backend canonicality
        guard targetBackend == .otzaria || targetBackend == .sefaria else {
            throw BackendTransitionError.invalidTargetBackend(targetBackend.rawValue)
        }

        // Validate registration if backends are registered
        if !registrations.isEmpty && registrations[targetBackend] == nil {
            throw BackendTransitionError.capabilityUnavailable(targetBackend)
        }

        let currentBackend = activeBackendID
        activeTransitionToken &+= 1
        let thisToken = activeTransitionToken
        transitionPhase = .preparing(from: currentBackend, to: targetBackend, token: thisToken)

        // Clean up dead participants
        switchParticipants.removeAll(where: { $0.value == nil })
        let activeParticipants = switchParticipants.compactMap { $0.value }

        // PHASE 1: ASYNC PREPARE (Preflight and stage while currentBackend is STILL ACTIVE)
        var preparedTransitions: [ObjectIdentifier: PreparedBackendTransition?] = [:]
        do {
            for participant in activeParticipants {
                let transition = try await participant.prepareTransitionAsync(from: currentBackend, to: targetBackend, token: thisToken)
                preparedTransitions[ObjectIdentifier(participant)] = transition
            }
        } catch {
            for participant in activeParticipants {
                participant.abortTransition(from: currentBackend, to: targetBackend, error: error)
            }
            transitionPhase = .failed(error: error.localizedDescription)
            // FAIL-CLOSED: defaults, activeBackendID, generation, cancellations remain UNTOUCHED!
            throw error
        }

        // Check if transition was superseded while preparing
        guard thisToken == activeTransitionToken else {
            let staleError = BackendTransitionError.transitionSuperseded
            for participant in activeParticipants {
                participant.abortTransition(from: currentBackend, to: targetBackend, error: staleError)
            }
            transitionPhase = .failed(error: staleError.localizedDescription)
            throw staleError
        }

        // PHASE 2: ATOMIC COORDINATOR COMMIT
        let oldRegistrations = registrations.values
        pendingBackendID = nil
        defaults.set(targetBackend.rawValue, forKey: Self.selectionDefaultsKey)
        inFlightCancellations.values.forEach { $0() }
        inFlightCancellations.removeAll()
        generation &+= 1
        activeBackendID = targetBackend
        transitionPhase = .idle

        Task {
            for registration in oldRegistrations {
                await registration.invalidateTransientState()
            }
        }

        // PHASE 3: NON-THROWING PARTICIPANT PUBLICATION (New activeBackendID is active)
        for participant in activeParticipants {
            let transition = preparedTransitions[ObjectIdentifier(participant)] ?? nil
            participant.publishTransition(to: targetBackend, transition: transition)
        }

        // PHASE 4: POST NOTIFICATION (Exactly once, after state & UI publication agree)
        NotificationCenter.default.post(name: .activeLibraryBackendDidChange, object: targetBackend)

        // PHASE 5: COMPLETE
        for participant in activeParticipants {
            participant.completeTransition(to: targetBackend)
        }
    }

    func catalog(forceRefresh: Bool = false) async throws -> [LibraryCatalogNode] {
        guard let provider = registrations[activeBackendID]?.catalog else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.catalog(forceRefresh: forceRefresh) }
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        guard locator.backend == activeBackendID else { throw LibraryBackendError.staleRequest }
        guard let provider = registrations[activeBackendID]?.text else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.section(at: locator) }
    }

    func normalize(_ input: String) async throws -> TextLocator {
        guard let provider = registrations[activeBackendID]?.navigation else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.normalizedLocator(for: input) }
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        guard work.locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.navigation else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.tableOfContents(for: work) }
    }

    func navigationStructures(for work: LibraryWork) async throws -> [LibraryNavigationStructure] {
        guard work.locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.navigation else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.navigationStructures(for: work) }
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        guard let provider = registrations[activeBackendID]?.navigation else {
            return []
        }
        return try await perform { try await provider.navigationItems(for: work) }
    }

    func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        guard let provider = registrations[activeBackendID]?.workMetadata else {
            return nil
        }
        return try await perform { try await provider.workMetadata(for: workKey) }
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        guard let provider = registrations[activeBackendID]?.search else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.search(request) }
    }

    func authors() async throws -> [LibraryAuthor] {
        guard let provider = registrations[activeBackendID]?.authors else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.authors() }
    }

    func versions(for workKey: String) async throws -> [TextVersionMetadata] {
        guard let provider = registrations[activeBackendID]?.metadata else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.versions(for: workKey) }
    }

    func related(to locator: TextLocator) async throws -> [TextLocator] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.metadata else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.related(to: locator) }
    }

    func links(for locator: TextLocator) async throws -> [LibraryRelatedSource] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.relationships else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.links(for: locator) }
    }

    func topics(for locator: TextLocator) async throws -> [LibraryRelatedTopic] {
        guard locator.backend == activeBackendID,
              let provider = registrations[activeBackendID]?.relationships else {
            throw LibraryBackendError.capabilityUnavailable
        }
        return try await perform { try await provider.topics(for: locator) }
    }

    func offlineProvider() -> (any OfflineLibraryProviding)? {
        registrations[activeBackendID]?.offline
    }

    func offlineWorkProvider() -> (any OfflineWorkProviding)? {
        registrations[activeBackendID]?.offlineWorks
    }

    private func validate(_ requestGeneration: UInt64) throws {
        try Task.checkCancellation()
        guard requestGeneration == generation else { throw LibraryBackendError.staleRequest }
    }

    private func perform<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let requestGeneration = generation
        let id = UUID()
        let task = Task<T, Error> { try await operation() }
        inFlightCancellations[id] = { task.cancel() }
        defer { inFlightCancellations.removeValue(forKey: id) }
        let result = try await task.value
        try validate(requestGeneration)
        return result
    }
}

#if canImport(Combine)
extension BackendCoordinator: ObservableObject {}
#endif
