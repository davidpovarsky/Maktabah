import Foundation

// Portable boundaries only. The actual adapter, registry, locator resolver,
// OpenBookOptions and fetchContentById body are compiled by the fixture runner.
// No UIKit, SQLite fixture, search engine or native Reader is substituted as PASS.
struct ReaderHighlightEvent {}
struct ReaderAnnotationEvent {}
struct Annotation {}
enum SearchMode { case contains }
enum SefariaRef {
    static func canonicalInput(_ value: String) -> String { value }
    static func sectionAncestors(of value: String) -> [String] { [value] }
}
struct BooksData { let id: Int; let backendLocator: TextLocator? }
struct BookContent { let id: Int }

@MainActor enum OtzariaDatabaseManagerAdapter {
    static var book: BooksData?
    static var lookup: (String, Int)?
    static func resolveBook(stableKey: String, expectedBookId: Int) throws -> BooksData? {
        lookup = (stableKey, expectedBookId)
        return book
    }
}

@MainActor final class iOSNavigationManager {
    struct Alert { let title: String; let message: String }
    var alertMessage: Alert?
    var calls: [(BooksData, OpenBookOptions)] = []
    func openBook(_ book: BooksData, options: OpenBookOptions = .init()) { calls.append((book, options)) }
    // Keep the old adapter compilable so --adapter-ref fails on behavior.
    func openBook(_ book: BooksData, initialContentId: Int? = nil, searchText: String? = nil,
                  highlightTerms: [String]? = nil) {
        openBook(book, options: .init(contentId: initialContentId, searchText: searchText, highlightTerms: highlightTerms))
    }
}

@MainActor final class FixtureLegacyConnection {
    var calls = 0
    func getContent(bkid: String, contentId: Int, quran: Bool) -> BookContent? {
        calls += 1
        return BookContent(id: contentId)
    }
}
@MainActor final class FixtureReaderModel {
    var currentBook: BooksData?
    let bookConnection = FixtureLegacyConnection()
    var destinations: [LibraryReaderDestination] = []
    var legacyContents: [BookContent] = []
    func loadBackendContent(_ destination: LibraryReaderDestination) { destinations.append(destination) }
    func updateContentState(with content: BookContent) { legacyContents.append(content) }
}

@main @MainActor struct ZayitReaderNavigationFixtures {
    static var checks = 0
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw NSError(domain: "ZayitReaderNavigationFixture", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: message]) }
        checks += 1
    }

    static func main() throws {
        let namespace = CommandLine.arguments[1]
        defer { UserDefaults(suiteName: namespace)?.removePersistentDomain(forName: namespace) }
        let work = TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(0))
        let book = BooksData(id: 103, backendLocator: work)
        OtzariaDatabaseManagerAdapter.book = book
        let manager = iOSNavigationManager()
        let terms = ["בראשית", "אמר", "בראשית"]
        for line in [0, 252, 1175] {
            let hit = ZayitSearchHit(bookId: 103, stableBookKey: "original-stable-book-key", bookTitle: "ברכות",
                                     lineId: Int64(6200228 + line), lineIndex: line, reference: "original reference",
                                     snippetHtml: "original snippet", matchedTerms: terms, score: 1, isBaseBook: true)
            try require(ZayitSearchReaderNavigationAdapter.open(hit, using: manager), "Resolved original hit must open")
            let options = manager.calls.last!.1
            let expected = TextLocator(backend: .otzaria, workKey: "book:103", position: .legacyLine(line))
            try require(options.contentId != nil && options.contentId! < 0, "Raw SQL line index is not a qualified Reader content ID")
            try require(LegacyIdentityRegistry.shared.locator(for: options.contentId!) == expected, "Exact provider book/line must survive registry mapping")
            try require(options.highlightTerms == terms, "Preserve original matched-term order and duplicates")
            try require(options.searchEvent == nil, "Provider terms must not be reparsed as a legacy FTS expression")
            try require(options.searchText == terms.joined(separator: " "), "Retain search provenance for native Clear controls")
            try require(OtzariaDatabaseManagerAdapter.lookup?.0 == hit.stableBookKey
                        && OtzariaDatabaseManagerAdapter.lookup?.1 == 103, "Resolve the actual provider identity")
            let existing = FixtureReaderModel(); existing.currentBook = book
            existing.fetchContentById(options.contentId!)
            try require(existing.destinations == [.init(sectionLocator: expected, focusLocator: expected)],
                        "An existing Reader must load and focus the later-page source")
            try require(existing.bookConnection.calls == 0, "Canonical Reader navigation must not query legacy SQL")
        }
        let empty = ZayitSearchHit(bookId: 103, stableBookKey: "original-stable-book-key", bookTitle: "ברכות",
                                   lineId: 1, lineIndex: 0, reference: "", snippetHtml: "", matchedTerms: [], score: 1, isBaseBook: true)
        try require(ZayitSearchReaderNavigationAdapter.open(empty, using: manager), "Empty provider terms do not change source identity")
        try require(manager.calls.last!.1.highlightTerms == [] && manager.calls.last!.1.searchText == "",
                    "Empty terms clear old transient search state without inventing highlights")
        OtzariaDatabaseManagerAdapter.book = nil
        let count = manager.calls.count
        try require(!ZayitSearchReaderNavigationAdapter.open(empty, using: manager), "An unresolved original book must refuse")
        try require(manager.calls.count == count && manager.alertMessage != nil, "Refusal must not navigate")
        let existing = FixtureReaderModel(); existing.currentBook = book
        let foreign = [TextLocator(backend: .otzaria, workKey: "book:1", position: .legacyLine(1175)),
                       TextLocator(backend: .sefariaEmbedded, workKey: "book:103", position: .legacyLine(1175))]
        for locator in foreign {
            existing.fetchContentById(LegacyIdentityRegistry.shared.id(for: locator))
            try require(existing.destinations.isEmpty && existing.bookConnection.calls == 0,
                        "A qualified ID from another Reader owner must refuse")
        }
        existing.fetchContentById(Int.min)
        try require(existing.destinations.isEmpty && existing.bookConnection.calls == 0, "An unknown negative ID must refuse")
        existing.fetchContentById(0)
        try require(existing.destinations.last?.sectionLocator == work, "Older explicit line-zero callers remain supported")
        existing.fetchContentById(252)
        try require(existing.destinations.last?.focusLocator == .init(backend: .otzaria, workKey: "book:103", position: .legacyLine(252)),
                    "Older raw positive line callers retain exact focus")
        let legacy = FixtureReaderModel(); legacy.currentBook = BooksData(id: 42, backendLocator: nil)
        legacy.fetchContentById(9)
        try require(legacy.bookConnection.calls == 1 && legacy.legacyContents.last?.id == 9 && legacy.destinations.isEmpty,
                    "Original legacy SQL behavior must remain intact")
        print("PASS: \(checks) portable Zayit/Reader navigation assertions; Native UI NOT RUN")
    }
}
