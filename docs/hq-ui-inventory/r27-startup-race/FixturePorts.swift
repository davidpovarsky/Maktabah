// Unit-test port doubles only. No UIKit, rendering, DEBUG launch or user data.
import Foundation

enum BackendID: String, Codable, CaseIterable, Sendable { case otzaria, sefaria, sefariaEmbedded }
struct TextLocator: Codable, Equatable, Sendable {
    enum Position: Codable, Equatable, Sendable { case legacyLine(Int), canonicalRef(String) }
    var backend: BackendID
    var workKey: String
    var position: Position = .canonicalRef("Genesis 1")
}
struct BooksData {
    let id: Int
    let title: String
    var book: String { title }
    let backendLocator: TextLocator?
}
struct LibraryWork { let locator: TextLocator }
enum SearchMode: Int { case phrase, contains, or, near }
struct FixtureReaderState {
    var currentID: Int?
    var scrollPosition: CGPoint?
    var selectedRange: NSRange?
    var expandedNodeIDs: [Int] = []
    var sidebarScrollPosition: CGPoint?
    var isSidebarCollapsed = false
    var currentLocator: TextLocator?
    var currentPage: Int?
    var currentPart: Int?
}
@MainActor final class ReaderViewModel {
    var readerState = FixtureReaderState()
    var contentText = "" // Never fabricate a rendered reader or book text.
    var recordHistory = false
    var needsScrollRestore = false
    var currentID: Int?
    var currentLocator: TextLocator?
    var currentPage: Int?
    var currentPart: Int?
    var fetchScrollPosition: (() -> CGPoint?)?
    var fetchSelectedRange: (() -> NSRange?)?
    var searchText = ""
    var searchMode: SearchMode?
    var nearDistance = 10
    var highlightTerms: [String]?
    init(book: BooksData) {}
    func loadBackendContent(_ locator: TextLocator) {}
    func loadInitialContent(initialContentId: Int?) {}
    func loadTOC(book: BooksData) {}
}
@MainActor final class iOSNavigationManager {
    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: ReaderViewModel
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }
    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?
    var persisted = 0
    var closed: [UUID] = []
    func selectTab(id: UUID) { activeTabId = id }
    func closeTab(id: UUID) {
        closed.append(id)
        openTabs.removeAll { $0.id == id }
        if activeTabId == id { activeTabId = openTabs.first?.id }
    }
    func persistCurrentSession(immediate: Bool) { persisted += 1 }
    func publishOpen(_ tab: ReaderTab) { openTabs.append(tab); activeTabId = tab.id }
}

// Deterministic continuations, not sleeps/polling or a UI scheduling guess.
@MainActor final class SuspensionGate {
    private var entered: CheckedContinuation<Void, Never>?
    private var blocked: CheckedContinuation<Void, Never>?
    func suspend() async {
        await withCheckedContinuation { continuation in
            blocked = continuation
            entered?.resume(); entered = nil
        }
    }
    func waitUntilSuspended() async {
        if blocked != nil { return }
        await withCheckedContinuation { entered = $0 }
    }
    func release() { blocked?.resume(); blocked = nil }
}
enum BackendTransitionError: Error { case transitionSuperseded }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 0
    var commitGate: SuspensionGate?
    func commitCheckedAsync(_ backend: BackendID,
                            beforeCommit: () throws -> Void = {}, publish: () -> Void = {}) async throws {
        if let gate = commitGate { commitGate = nil; await gate.suspend() }
        try Task.checkCancellation()
        try beforeCommit()
        if activeBackendID != backend { activeBackendID = backend; generation += 1 }
        publish()
    }
}
@MainActor final class ChavrusaTextTargetBackendBookResolver {
    static let shared = ChavrusaTextTargetBackendBookResolver()
    var catalogGate: SuspensionGate?
    func withTargetCatalog<T>(in backend: BackendID, operation: () async throws -> T) async throws -> T {
        if let gate = catalogGate { catalogGate = nil; await gate.suspend() }
        return try await operation()
    }
    func resolveBook(id: Int, backendLocator: String?, title: String?, in backend: BackendID) throws -> BooksData {
        BooksData(id: id, title: title ?? "fixture identity", backendLocator: .init(backend: backend, workKey: backendLocator ?? "Genesis"))
    }
}
