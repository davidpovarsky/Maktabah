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
    init(_ book: BooksData) { currentBook = book }
    func updateContentState(with content: BookContent) {
        contentText = content.nash; published.append(content.backendLocator)
        let hook = contentHook; contentHook = nil; hook?()
    }
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
