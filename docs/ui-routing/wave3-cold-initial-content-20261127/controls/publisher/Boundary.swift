import Foundation
import Observation

// EXPLICIT boundary: no UIKit, file/database I/O, rendering, actual backend,
// or native acceptance. The complete touched Reader+Content functions and
// actual coordinator/request/resolver/model types compile unchanged. These
// shells expose exact callback and async suspension points to those bodies.
enum ReaderScrollTarget: Equatable, Sendable { case top, bottom }
enum DatabaseError: Error { case bookNotFound(String) }
enum SefariaRef {
    static func canonicalInput(_ value: String) -> String { value }
    static func sectionAncestors(of value: String) -> [String] { [value] }
}
@MainActor final class BooksData {
    let id: Int
    var backendLocator: TextLocator?
    let book = "Original book"
    let archive = "fixture"
    init(_ id: Int = 1, locator: TextLocator?) { self.id = id; backendLocator = locator }
}
struct BookContent: Sendable {
    let id: Int
    let nash: String
    let backendLocator: TextLocator?
    let page: Int? = 7
    let part: Int? = 8
    let heRef: String? = "Original reference"
}
@MainActor final class BoundaryConnection {
    func connect(archive: String) throws {}
    func getContent(bkid: String, contentId: Int) -> BookContent? { .init(id: contentId, nash: "legacy", backendLocator: nil) }
    func getFirstContent(bkid: String) -> BookContent? { .init(id: 0, nash: "legacy first", backendLocator: nil) }
}
@MainActor final class BoundaryTOC {
    var loads = 0
    var callback: (() -> Void)?
    func loadTOC(book: BooksData) { loads += 1; let call = callback; callback = nil; call?() }
}
@MainActor final class BoundaryHistory {
    struct Entry { let lastContentId: Int }
    var entriesByBookId: [Int: Entry] = [:]
    var updates: [Int] = []
    func updateLastContentId(_ id: Int, for book: Int) { updates.append(id) }
}
@MainActor @Observable final class BoundaryReaderState {
    var currentBook: BooksData?
    var currentID: Int? = 901
    var currentPart: Int? = 902
    var currentPage: Int? = 903
    var currentLocator: TextLocator?
    var scrollPosition: CGPoint? = CGPoint(x: 11, y: 12)
    var selectedRange: NSRange? = NSRange(location: 13, length: 14)
}
struct BoundarySearchEvent { let contentId: Int? }
struct BoundaryAnnotationEvent { struct Value { let contentId: Int }; let annotation: Value }
struct ContentRenderPayload {
    let text: String
    init(bookId: Int? = nil, text: String, content: BookContent? = nil, keepScrollPosition: Bool) { self.text = text }
}
@MainActor @Observable final class ReaderViewModel {
    var currentBook: BooksData?
    var currentDestination: LibraryReaderDestination? {
        didSet { let hook = destinationHook; destinationHook = nil; hook?() }
    }
    var contentText = ""
    enum State: Equatable { case loading, loaded, error(String) }
    var state: State = .loaded
    var backendSection: LibraryTextSection?
    var backendRenderModel: LibraryReaderRenderModel?
    var selectedSegmentLocator: TextLocator?
    var navigationItems: [LibraryNavigationItem] = []
    var backendLoadTask: Task<Void, Never>?
    let contentLoadCoordinator = ReaderContentLoadCoordinator()
    let tocViewModel = BoundaryTOC()
    let bookConnection = BoundaryConnection()
    let historyVM = BoundaryHistory()
    enum PendingReaderScrollTarget { case top, bottom }
    var pendingReaderScrollTarget: PendingReaderScrollTarget?
    @ObservationIgnored var destinationHook: (() -> Void)?
    @ObservationIgnored var contentHook: (() -> Void)?
    @ObservationIgnored var published: [TextLocator?] = []
    var currentPage: Int? = 41
    var currentPart: Int? = 42
    var currentHeRef: String? = "prior reference"
    var currentContentId: Int = 40
    var recordHistory: Bool = true
    var _currentID: Int? = 43
    var currentID: Int? {
        get { _currentID }
        set { _currentID = newValue }
    }
    let readerState = BoundaryReaderState()
    var searchEvent: BoundarySearchEvent?
    var annotationEvent: BoundaryAnnotationEvent?
    @ObservationIgnored var annotationLoads = 0
    @ObservationIgnored var lineClears = 0
    @ObservationIgnored var limitUpdates = 0
    @ObservationIgnored var windowTitleUpdates = 0
    var contentPayload = ContentRenderPayload(text: "", keepScrollPosition: false)
    @ObservationIgnored var onContentChanged: ((BookContent) -> Void)?
    @ObservationIgnored var onPayloadChanged: ((ContentRenderPayload) -> Void)?
    @ObservationIgnored var onNavigationLimitsChanged: (() -> Void)?
    init(_ book: BooksData) { currentBook = book }
    func loadAnnotations() {
        annotationLoads += 1
        let hook = contentHook; contentHook = nil; hook?()
    }
    func clearOtzariaLineSelectionForContentChange() { lineClears += 1 }
    func updateNavigationLimits() { limitUpdates += 1 }
    func updateWindowTitle(book: BooksData?, page: Int?, part: Int?) { windowTitleUpdates += 1 }

}
@MainActor final class LegacyIdentityRegistry {
    static let shared = LegacyIdentityRegistry()
    var locators: [Int: TextLocator] = [:]
    func locator(for id: Int) -> TextLocator? { locators[id] }
}
@MainActor final class QualifiedLocatorStore {
    struct Entry: Sendable { let locator: TextLocator }
    static let shared = QualifiedLocatorStore()
    var reads = 0
    var records: [TextLocator] = []
    func record(_ locator: TextLocator, title: String) async throws { records.append(locator) }
    var hold = false
    var result: [Entry] = []
    var continuations: [CheckedContinuation<[Entry], Never>] = []
    func entries() async -> [Entry] {
        reads += 1
        if !hold { return result }
        return await withCheckedContinuation { continuations.append($0) }
    }
    func resume(_ value: [Entry]) { let old = continuations; continuations = []; old.forEach { $0.resume(returning: value) } }
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation: UInt64 = 0
    var navReads = 0
    var holdNavigation = false
    var navigation: [LibraryNavigationItem] = []
    var navContinuations: [CheckedContinuation<[LibraryNavigationItem], any Error>] = []
    var sectionReads: [TextLocator] = []
    var sectionContinuations: [(TextLocator, CheckedContinuation<LibraryTextSection, any Error>)] = []
    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        navReads += 1
        if !holdNavigation { return navigation }
        return try await withCheckedThrowingContinuation { navContinuations.append($0) }
    }
    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        sectionReads.append(locator)
        return try await withCheckedThrowingContinuation { sectionContinuations.append((locator, $0)) }
    }
    func resumeNavigation(_ value: [LibraryNavigationItem]) {
        let old = navContinuations; navContinuations = []; old.forEach { $0.resume(returning: value) }
    }
    func resumeSection(_ locator: TextLocator) {
        guard let index = sectionContinuations.firstIndex(where: { $0.0 == locator }) else { return }
        let entry = sectionContinuations.remove(at: index)
        entry.1.resume(returning: .init(locator: locator, displayRef: "Original section", heRef: nil,
            segments: [.init(locator: locator, heRef: nil, primaryText: "original content", translation: nil)],
            previous: nil, next: nil, versions: [], links: [], origin: .offline))
    }
    func rejectNavigation(_ error: any Error) {
        let old = navContinuations; navContinuations = []; old.forEach { $0.resume(throwing: error) }
    }
    func rejectSection(_ locator: TextLocator, _ error: any Error) {
        guard let index = sectionContinuations.firstIndex(where: { $0.0 == locator }) else { return }
        let entry = sectionContinuations.remove(at: index); entry.1.resume(throwing: error)
    }
    func drain() {
        let sections = sectionContinuations; sectionContinuations = []
        sections.forEach { $0.1.resume(throwing: CancellationError()) }
        let nav = navContinuations; navContinuations = []; nav.forEach { $0.resume(throwing: CancellationError()) }
    }
}
@MainActor final class BookPageCache {
    static let shared = BookPageCache()
    var writes: [TextLocator?] = []
    func set(bookId: Int, content: BookContent) { writes.append(content.backendLocator) }
}
@MainActor enum MaktabahBackendAdapter {
    static func preparedRenderModel(from section: LibraryTextSection) async throws -> LibraryReaderRenderModel {
        LibraryReaderRenderModel(section: section, preferredMode: .source)
    }
    static func content(from section: LibraryTextSection, renderModel: LibraryReaderRenderModel) -> BookContent {
        .init(id: 1, nash: "original content", backendLocator: section.locator)
    }
}
