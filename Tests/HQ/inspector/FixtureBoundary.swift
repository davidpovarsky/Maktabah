import Foundation
import Dispatch

// Boundary substitutes only: actual generated service SQL executes in SQLite.
// Decoder instrumentation uses plain text; it does not validate production zstd.
struct FixtureError: Error { let message: String }
struct SQLiteRow {
    let values: [Any]
    func int(at index: Int) -> Int { (values[index] as? NSNumber)?.intValue ?? 0 }
    func string(at index: Int) -> String? { values[index] as? String }
    func isNull(at index: Int) -> Bool { values[index] is NSNull }
}
final class SQLiteDatabase: @unchecked Sendable {
    let path: String
    var queryCount = 0
    var metadataQueries = 0
    var cancelAfterMetadataBatch = false
    var cancelAtMetadataRow: Int?
    var cancelAtSnippetRow: Int?
    var metadataRowCount = 0
    var snippetRowCount = 0
    var brokenMetadata = false
    var splitContent = false
    init(path: String) { self.path = path }
    func fetch<T>(query: String, parameters: [Any] = [], map: (SQLiteRow) throws -> T) throws -> [T] {
        queryCount += 1
        let metadata = query.contains("WITH win")
        let snippet = query.contains("SELECT l.bookId, l.lineIndex")
        if metadata { metadataQueries += 1 }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
        process.arguments = [CommandLine.arguments[2], "--query", path]
        let input = Pipe(), output = Pipe()
        process.standardInput = input; process.standardOutput = output
        try process.run()
        let actualQuery = metadata && brokenMetadata ? "SELECT * FROM missing_link_table" : query
        let request = try JSONSerialization.data(withJSONObject: ["query": actualQuery, "parameters": parameters])
        input.fileHandleForWriting.write(request); try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let result = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        if let error = result["error"] as? String { throw FixtureError(message: error) }
        var mapped: [T] = []
        for values in result["rows"] as! [[Any]] {
            if metadata {
                metadataRowCount += 1
                if metadataRowCount == cancelAtMetadataRow { withUnsafeCurrentTask { $0?.cancel() } }
            }
            if snippet {
                snippetRowCount += 1
                if snippetRowCount == cancelAtSnippetRow { withUnsafeCurrentTask { $0?.cancel() } }
            }
            mapped.append(try map(SQLiteRow(values: values)))
        }
        if metadata && cancelAfterMetadataBatch { withUnsafeCurrentTask { $0?.cancel() } }
        return mapped
    }
}
final class OtzariaMaktabahBridge: @unchecked Sendable {
    static let shared = OtzariaMaktabahBridge(database: SQLiteDatabase(path: "unused"))
    let database: SQLiteDatabase
    var currentReadingUnitMode: OtzariaUnitMode = .chapter
    var cachedAnchor: OtzariaLineAnchor?
    init(database: SQLiteDatabase) { self.database = database }
    func withDatabase<T>(_ work: (SQLiteDatabase) throws -> T) throws -> T { try work(database) }
    func lineAnchor(bookId: Int, contentId: Int, characterIndex: Int) -> OtzariaLineAnchor? { cachedAnchor }
    func lineAnchorAsync(bookId: Int, contentId: Int, characterIndex: Int) async -> OtzariaLineAnchor? { cachedAnchor }
    func cachedReadingUnit(bookId: Int, contentId: Int, mode: OtzariaUnitMode) -> OtzariaReadingUnit? { nil }
}
struct OtzariaDatabaseCapabilities {
    let hasLinkRanges = true
    let hasSuppressedLinkSides = true
    let hasSplitLineContent: Bool
    init(database: SQLiteDatabase) throws { hasSplitLineContent = database.splitContent }
}
struct OtzariaBookSchemaProjection {
    let filePath: String; let isBaseBook: String; let dependenceType: String
}
enum OtzariaBookSchemaCompatibility {
    static func projection(in db: SQLiteDatabase, alias: String) throws -> OtzariaBookSchemaProjection {
        OtzariaBookSchemaProjection(filePath: "\(alias).filePath", isBaseBook: "\(alias).isBaseBook", dependenceType: "\(alias).dependenceType")
    }
}
struct OtzariaLineContentProjection { let join: String; let expression: String }
enum OtzariaLineContentCompatibility {
    static func projection(capabilities: OtzariaDatabaseCapabilities, lineAlias: String, contentAlias: String) -> OtzariaLineContentProjection {
        capabilities.hasSplitLineContent
        ? OtzariaLineContentProjection(join: "LEFT JOIN line_content \(contentAlias) ON \(contentAlias).id = \(lineAlias).id", expression: "\(contentAlias).content")
        : OtzariaLineContentProjection(join: "", expression: "\(lineAlias).content")
    }
}
final class OtzariaLineContentDecoder {
    nonisolated(unsafe) static var decoded = 0
    nonisolated(unsafe) static var fail = false
    init(database: SQLiteDatabase, capabilities: OtzariaDatabaseCapabilities) throws {}
    func decode(row: SQLiteRow, at index: Int) throws -> String {
        if Self.fail { throw FixtureError(message: "fixture decode failure") }
        Self.decoded += 1
        return row.string(at: index) ?? ""
    }
}
struct CategoryData {
    let id: Int; let name: String; let level: Int; let order: Int; let parentId: Int?
}
struct TorahLinkedSource: Sendable {
    typealias ID = String
    let id: ID
    let sourceRef: String
}
struct OtzariaReadingUnit {
    let bookId: Int
    let id = "fixture-unit"
    let startLineIndex = 0
    let endLineIndex = 3998
    let sourceLineIndices: [Int]
}
enum OtzariaUnitMode { case chapter; var storageValue: String { "chapter" } }
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    func begin(_ name: String) -> Self { self }
    func end(extra: String) {}
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ message: String) {}
}
extension String { var otsariaPlainText: String { self } }

enum BackendID: String, Sendable { case otzaria, sefaria, sefariaEmbedded }
struct TextLocator: Equatable, Sendable {
    enum Position: Equatable, Sendable { case legacyLine(Int), canonicalRef(String) }
    let backend: BackendID; let workKey: String; let position: Position
    var persistenceKey: String { "\(backend):\(workKey):\(position)" }
}
struct TorahInspectorSelection: Sendable {
    enum Scope: Sendable { case section, segment }
    let providerID: String; let canonicalRef: String; let preferredSegmentRef: String?; let scope: Scope
    init(providerID: String, canonicalRef: String, preferredSegmentRef: String? = nil, scope: Scope) {
        self.providerID = providerID; self.canonicalRef = canonicalRef; self.scope = scope
        self.preferredSegmentRef = preferredSegmentRef ?? (scope == .segment ? canonicalRef : nil)
    }
}
struct TorahInspectorNote: Sendable {
    let id: String; let selectedText: String; let note: String; let tag: String?
}
final class AnnotationManager: @unchecked Sendable {
    static let shared = AnnotationManager()
    let lock = NSLock()
    var rows: [Annotation] = []
    var onLoad: @Sendable () -> Void = {}
    func loadAnnotations(bkId: Int) -> [Annotation] {
        let (rows, hook) = lock.withLock { (self.rows, self.onLoad) }
        hook()
        return rows
    }
}
struct LegacyIdentityRegistry: Sendable {
    static let shared = Self()
    func locator(for id: Int) -> TextLocator? { nil }
}
final class FixtureFlag: @unchecked Sendable {
    let lock = NSLock()
    private var state = false
    func set() { lock.withLock { state = true } }
    var value: Bool { lock.withLock { state } }
}
enum SefariaRef { static func canonicalInput(_ input: String) -> String { input } }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var activeBackendID: BackendID = .otzaria
    var generation = 0
}
@MainActor enum OtzariaBackendActivation { static var isActive = true }
struct FixtureBook {
    let id: Int
    var backendLocator: TextLocator? { TextLocator(backend: .otzaria, workKey: "book:\(id)", position: .legacyLine(0)) }
}
struct FixtureSection { let locator: TextLocator }
struct FixtureMapping { let locator: TextLocator }
struct FixtureRenderModel {
    let mapping: FixtureMapping
    func renderedSegment(at index: Int) -> FixtureMapping? { mapping }
}
struct FixtureReaderState { var selectedRange: NSRange? }
@MainActor final class ReaderViewModel {
    var otzariaSourcesSelectedBookID: String?
    var otzariaSourcesSelectedGroupID: String?
    var otzariaSourcesExpandedSourceIDs = Set<Int>()
    var otzariaSourcesLoadTask: Task<Void, Never>?
    var readerInspectorVisible = false
    var selectedSegmentLocator: TextLocator?
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var otzariaLinkedSources: [OtzariaLinkedSource] = []
    var otzariaSourcesError: String?
    var otzariaSourcesIsLoading = false
    var readerState = FixtureReaderState()
    var backendRenderModel: FixtureRenderModel?
    var backendSection: FixtureSection?
    var currentBook: FixtureBook? = FixtureBook(id: 1)
    var currentContentId = 0
    var currentHeRef: String?
    var currentAnnotations: [Annotation] = []
    var selectedSegmentRange: NSRange?
}
