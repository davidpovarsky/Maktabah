import Foundation

// Only the app environment is doubled. The runner inserts the exact production
// bridge methods and compiles both complete reading/line-anchor extensions.
final class OtzariaMaktabahBridge: @unchecked Sendable {
    static let shared = OtzariaMaktabahBridge(database: SQLiteDatabase())
    let lock = NSRecursiveLock()
    var dbGeneration: UInt64 = 0
    var database: SQLiteDatabase?
    var openedDatabaseURL: URL?
    var readingUnitService: OtzariaReadingUnitService?
    var currentReadingUnitMode: OtzariaUnitMode = .paragraph
    var fallbackContent: BookContent?
    init(database: SQLiteDatabase) { self.database = database }
    func requireDatabase() throws -> SQLiteDatabase {
        guard let database else { throw CancellationError() }
        return database
    }
    static func clearCategoryCache() {}
    struct Book { let id: Int }
    func resolveBook(stableKey: String, expectedBookId: Int) throws -> Book? { nil }
    func getFirstContent(bookId: Int) -> BookContent? { fallbackContent }
    func getContent(bookId: Int, contentId: Int) -> BookContent? { fallbackContent }
    func getPreviousContent(bookId: Int, before: Int) -> BookContent? { nil }
    func getNextContent(bookId: Int, after: Int) -> BookContent? { nil }
}
struct BookContent {
    let id: Int
    let nash: String
    let page: Int
    let part: Int
    let heRef: String?
}
struct BookPageCache { static let shared = Self(); func removeAll() {} }
struct LegacyIdentityRegistry {
    static let shared = Self()
    struct Locator { let position: Position }
    enum Position { case legacyLine(Int) }
    func locator(for id: Int) -> Locator? { nil }
}
enum OtzariaInspectorDocumentMapper {
    // Mapper belongs to the Inspector lane. This double is explicitly not
    // evidence about its own conversion behavior.
    static var onMap: (() -> Void)?
    static func section(from unit: OtzariaReadingUnit, previous: OtzariaReadingUnitDescriptor?, next: OtzariaReadingUnitDescriptor?) -> LibraryTextSection {
        onMap?()
        let locator = TextLocator(backend: .otzaria, workKey: "book:\(unit.bookId)", position: .legacyLine(unit.startLineIndex))
        return LibraryTextSection(locator: locator, displayRef: "fixture", heRef: nil,
            segments: [LibraryTextSegment(locator: locator, heRef: nil, primaryText: unit.plainText, translation: nil)],
            previous: nil, next: nil, versions: [], links: [], origin: .offline)
    }
}
