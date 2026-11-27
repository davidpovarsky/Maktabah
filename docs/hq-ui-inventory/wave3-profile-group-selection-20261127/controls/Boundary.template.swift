import Foundation
import Observation

// EXPLICIT DOMAIN / APPLE BOUNDARIES: Combine delivery, the book resolver,
// Reader rendering/IO, navigation-manager storage, and user callbacks below
// are small shells. Actual Store/persistence/mapping, prepared stage, policy,
// complete adapter body, original selectTab/closeTab/setters, content-token
// coordinator and same-backend snapshot terminal are compiled unchanged.
@MainActor final class AnyCancellable {
    private var cancellation: (() -> Void)?
    init(_ cancellation: @escaping () -> Void) { self.cancellation = cancellation }
    func cancel() { cancellation?(); cancellation = nil }
}
@MainActor final class BoundaryPublisher {
    private var subscribers: [UUID: (()) -> Void] = [:]
    var beforeSend: (() -> Void)?
    func sink(_ receive: @escaping (()) -> Void) -> AnyCancellable {
        let id = UUID(); subscribers[id] = receive
        return AnyCancellable { [weak self] in self?.subscribers.removeValue(forKey: id) }
    }
    func send() {
        let hook = beforeSend; beforeSend = nil; hook?()
        for id in Array(subscribers.keys) { subscribers[id]?(()) }
    }
}

// ACTUAL_BACKEND_TRANSITION_ERROR
// ACTUAL_PREPARED_BACKEND_TRANSITION
// ACTUAL_SNAPSHOT_PROTOCOL
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    let objectWillChange = BoundaryPublisher()
    var activeBackendID: BackendID = .otzaria { willSet { objectWillChange.send() } }
    var committedBackendID: BackendID? = .otzaria
    var generation: UInt64 = 0 { willSet { objectWillChange.send() } }
    var pendingBackendID: BackendID? { willSet { objectWillChange.send() } }
    var isTransitioning = false { willSet { objectWillChange.send() } }
    var activeSessionSnapshots: (any BackendSnapshotStaging)?
    var beforeOriginalAsyncCommit: (() throws -> Void)?
    var terminalEvents: [String] = []
    // ACTUAL_COMMIT_PREPARED
    // ACTUAL_COMMITTED_TERMINAL
    func commitCheckedAsync(_ backend: BackendID, beforeCommit: () throws -> Void = {}, publish: () -> Void = {}) async throws {
        await Task.yield()
        try beforeOriginalAsyncCommit?()
        guard activeBackendID == backend, committedBackendID == backend else { throw BackendTransitionError.transitionSuperseded }
        if let snapshots = activeSessionSnapshots {
            try await snapshots.withSnapshotRollback {
                try performCommittedBackendPublication(beforeCommit: beforeCommit, publish: publish)
            }
        } else {
            try performCommittedBackendPublication(beforeCommit: beforeCommit, publish: publish)
        }
    }
    func resetBoundary() {
        activeBackendID = .otzaria; committedBackendID = .otzaria; generation = 0
        pendingBackendID = nil; isTransitioning = false; activeSessionSnapshots = nil
        beforeOriginalAsyncCommit = nil; objectWillChange.beforeSend = nil; terminalEvents = []
    }
}

@MainActor final class ChavrusaTextTargetBackendBookResolver {
    static let shared = ChavrusaTextTargetBackendBookResolver()
    var duringCatalog: (() throws -> Void)?
    var duringResolve: (() throws -> Void)?
    var resolutionCount = 0
    func withTargetCatalog<T>(in backend: BackendID, operation: () async throws -> T) async throws -> T {
        await Task.yield()
        let hook = duringCatalog; duringCatalog = nil; try hook?()
        return try await operation()
    }
    func resolveBook(id: Int, backendLocator: String?, title: String?, in backend: BackendID) throws -> BooksData {
        resolutionCount += 1
        let hook = duringResolve; duringResolve = nil; try hook?()
        return BooksData(id, key: backendLocator ?? "book:\(id)", backend: backend)
    }
}
enum TargetBackendBookIdentity {
    static func matches(id: Int, backend: BackendID, workKey: String?,
                        candidateID: Int, candidateBackend: BackendID?, candidateWorkKey: String?) -> Bool {
        guard id == candidateID, backend == candidateBackend else { return false }
        guard let workKey, !workKey.isEmpty else { return false }
        return workKey == candidateWorkKey
    }
}
@MainActor final class BooksData {
    let id: Int
    let title: String
    var backendLocator: TextLocator?
    init(_ id: Int, key: String, backend: BackendID = .otzaria) {
        self.id = id; title = "Actual boundary book \(id)"
        backendLocator = .init(backend: backend, workKey: key, position: .legacyLine(0))
    }
}
enum SearchMode: Int { case exact = 0 }
enum ReaderScrollTarget: Equatable, Sendable { case top, bottom }
struct BoundaryReaderState {
    var scrollPosition: CGPoint? = .zero
    var selectedRange: NSRange?
    var expandedNodeIDs: [Int] = []
    var sidebarScrollPosition: CGPoint?
    var isSidebarCollapsed = false
    var currentID: Int?
    var currentLocator: TextLocator?
    var currentPage: Int?
    var currentPart: Int?
}
@MainActor @Observable final class ReaderViewModel {
    enum State { case loading, loaded }
    let contentLoadCoordinator = ReaderContentLoadCoordinator()
    var currentBook: BooksData?
    var isPopoverPresented = false
    var backendSection: Int?
    var state = State.loaded
    var currentDestination: LibraryReaderDestination?
    var contentText = "original loaded text"
    var readerState = BoundaryReaderState()
    var currentID: Int? = 523
    var currentContentId: Int? { currentID }
    var currentLocator: TextLocator? { currentDestination?.focusLocator ?? currentDestination?.sectionLocator }
    var currentPage: Int?
    var currentPart: Int?
    var fetchScrollPosition: (() -> CGPoint?)?
    var fetchSelectedRange: (() -> NSRange?)?
    var searchText = "original query"
    var searchMode: SearchMode? = .exact
    var nearDistance = 10
    var highlightTerms: [String]? = ["original"]
    var recordHistory = false
    var needsScrollRestore = false
    var annotationEvent: Int?
    var searchEvent: Int?
    var saveCalls = 0
    var closeCalls = 0
    var loadCalls = 0
    var beforeSave: (() -> Void)?
    var duringLoad: (() -> Void)?
    var duringTOC: (() -> Void)?
    init(book: BooksData) { currentBook = book; contentText = ""; state = .loading }
    func seedLoaded(_ locator: TextLocator) {
        currentDestination = .init(sectionLocator: locator, focusLocator: nil)
        _ = contentLoadCoordinator.beginRequest(backend: locator.backend, workKey: locator.workKey, sectionLocator: locator)
        contentText = "original \(locator.workKey)"; state = .loaded
    }
    func saveCurrentState() { saveCalls += 1; let callback = beforeSave; beforeSave = nil; callback?() }
    func closeReaderInspector() { closeCalls += 1 }
    func clearSearchHighlight() {}
    func loadBackendContent(_ locator: TextLocator) {
        loadCalls += 1
        currentDestination = .init(sectionLocator: locator, focusLocator: nil)
        state = .loading
        _ = contentLoadCoordinator.beginRequest(backend: locator.backend, workKey: locator.workKey, sectionLocator: locator)
        let callback = duringLoad; duringLoad = nil; callback?()
    }
    func loadInitialContent(initialContentId: Int?) { loadCalls += 1 }
    func loadTOC(book: BooksData) { let callback = duringTOC; duringTOC = nil; callback?() }
}
@MainActor final class LegacyIdentityRegistry {
    static let shared = LegacyIdentityRegistry()
    func id(for locator: TextLocator) -> Int { 523 }
}

@MainActor @Observable final class iOSNavigationManager {
    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: ReaderViewModel
        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool { lhs.id == rhs.id }
    }
    // ACTUAL_CURRENT_MODE
    @ObservationIgnored private(set) var nativeModePresentationRevision: UInt64? = 0
    // ACTUAL_SELECTED_BOOK
    // ACTUAL_BOOK_METADATA
    // ACTUAL_OPEN_TABS
    // ACTUAL_ACTIVE_TAB
    // ACTUAL_SHOWING_TABS
    var selectedContentId: Int?
    var selectedBookForInfo: BooksData?
    var persistCalls: [Bool] = []
    var afterPersist: (() -> Void)?
    init() { StudyWorkspaceNavigationAdapter.nativeMappingOwnerInitialized(self) }
    isolated deinit { StudyWorkspaceNavigationAdapter.nativeMappingOwnerWillDeinitialize(self) }
    func fixtureBookRevision(_ value: UInt64?) { selectedBookPresentationRevision = value }
    // ACTUAL_SELECT_TAB
    // ACTUAL_CLOSE_TAB
    func persistCurrentSession(immediate: Bool) {
        persistCalls.append(immediate)
        let callback = afterPersist; afterPersist = nil; callback?()
    }
}
