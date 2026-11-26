import Foundation
import SQLite3

// Explicit host/DTO/logging boundaries; all relationship SQL, schema, decoder,
// source classification/grouping, normalizer and SQLite wrapper are production.
final class OtzariaMaktabahBridge: @unchecked Sendable {
    let database: SQLiteDatabase
    init(database: SQLiteDatabase) { self.database = database }
    func withDatabase<T>(_ work: (SQLiteDatabase) throws -> T) throws -> T {
        try work(database)
    }
}
struct CategoryData {
    let id: Int
    let name: String
    let level: Int
    let order: Int
    let parentId: Int?
}
struct TorahLinkedSource: Sendable {
    typealias ID = String
    let id: ID
    let sourceRef: String
}
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) {}
}
final class SQLTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var statements: [String] = []
    func append(_ sql: String) { lock.lock(); statements.append(sql); lock.unlock() }
    func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return statements }
}

@main struct FullSourceInspectorAcceptance {
    struct Input: Decodable {
        struct Window: Decodable {
            let name: String
            let bookID: Int
            let indices: [Int]
        }
        let uri: String
        let windows: [Window]
    }
    static func identity(_ source: OtzariaLinkedSource) -> String {
        "\(source.id):\(source.linkedBookId):\(source.linkedLineId)"
    }
    static func record(_ source: OtzariaLinkedSource) -> [String: Any] {
        [
            "id": source.id, "linked_book": source.linkedBookId,
            "linked_line": source.linkedLineId, "line_index": source.linkedLineIndex,
            "book_title": source.bookTitle, "he_ref": source.heRef as Any? ?? NSNull(),
            "category_id": source.linkedCategoryId as Any? ?? NSNull(),
            "category_path": source.linkedCategoryPath,
            "book_order": source.linkedBookOrderIndex as Any? ?? NSNull(),
            "raw_type": source.rawConnectionType, "display_type": source.connectionType,
            "matched_side": source.matchedSide,
            "source_book": source.sourceBookId, "target_book": source.targetBookId,
            "content": source.content
        ]
    }
    static func main() async throws {
        let input = try JSONDecoder().decode(Input.self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let db = try SQLiteDatabase(path: input.uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        precondition(sqlite3_db_readonly(db.dbPointer, "main") == 1)
        let capabilities = try OtzariaDatabaseCapabilities(database: db)
        precondition(capabilities.hasSplitLineContent && capabilities.hasZstdDictionaries)
        precondition(capabilities.hasLinkRanges && capabilities.hasSuppressedLinkSides)
        let bridge = OtzariaMaktabahBridge(database: db)
        let trace = SQLTrace()
        let context = Unmanaged.passUnretained(trace).toOpaque()
        precondition(sqlite3_trace_v2(db.dbPointer, UInt32(SQLITE_TRACE_STMT), { _, context, raw, _ in
            if let context, let raw, let sql = sqlite3_sql(OpaquePointer(raw)) {
                Unmanaged<SQLTrace>.fromOpaque(context).takeUnretainedValue()
                    .append(String(cString: sql))
            }
            return 0
        }, context) == SQLITE_OK)
        defer { sqlite3_trace_v2(db.dbPointer, 0, nil, nil) }
        var cases: [[String: Any]] = []
        for window in input.windows {
            OtzariaLineSourcesService.clearCategoryCache()
            let beforeMetadata = trace.snapshot().count
            let metadataStarted = Date()
            let metadata = try bridge.getLinksMetadataForLineIndices(
                bookID: window.bookID, sourceLineIndices: window.indices, includeContent: false)
            let metadataMS = Date().timeIntervalSince(metadataStarted) * 1_000
            let metadataSQL = Array(trace.snapshot().dropFirst(beforeMetadata))
            let metadataQueries = metadataSQL.filter { $0.contains("WITH win(id)") }
            precondition(metadataQueries.count == (Set(window.indices).count + 399) / 400)
            precondition(metadataQueries.allSatisfy { !$0.contains("linked_content") })
            precondition(!metadataSQL.contains { $0.contains("SELECT dict") })
            precondition(metadata.count >= 2_000, "chosen genuine source must exercise >2000 relationships")
            precondition(metadata.allSatisfy { $0.content.isEmpty })
            let identities = metadata.map(identity)
            precondition(Set(identities).count == metadata.count)

            let grouped = OtzariaLinkedSourceGrouping.bookGroups(from: metadata)
            precondition(grouped.reduce(0) { $0 + $1.count } == metadata.count)
            precondition(Set(grouped.flatMap(\.sources).map(identity)) == Set(identities))
            precondition(grouped.allSatisfy { group in
                Set(group.sources.map(\.linkedBookId)).count == 1
                    && group.id == String(group.sources[0].linkedBookId)
            })

            let contentStarted = Date()
            let full = try bridge.getLinksMetadataForLineIndices(
                bookID: window.bookID, sourceLineIndices: window.indices, includeContent: true)
            let contentMS = Date().timeIntervalSince(contentStarted) * 1_000
            precondition(full.map(identity) == identities)
            for (light, complete) in zip(metadata, full) {
                var a = record(light); var b = record(complete)
                a.removeValue(forKey: "content"); b.removeValue(forKey: "content")
                // swift-corelibs-foundation on Windows reports false even when
                // NSDictionary.isEqual(to:) receives the same dictionary.
                let metadataJSON = try JSONSerialization.data(withJSONObject: a, options: [.sortedKeys])
                let contentJSON = try JSONSerialization.data(withJSONObject: b, options: [.sortedKeys])
                precondition(metadataJSON == contentJSON)
            }
            try JSONSerialization.data(withJSONObject: full.map(record), options: [.sortedKeys])
                .write(to: output.appendingPathComponent(window.name + ".json"))

            var prefetch: [[String: Any]] = []
            for count in [100, 500, 2_000] {
                let selected = Array(full.prefix(count))
                let requests = selected.map {
                    TorahLinkedSource(id: identity($0),
                        sourceRef: "otzaria:v1:\($0.linkedBookId):\($0.linkedLineIndex)")
                }
                let before = trace.snapshot().count
                let started = Date()
                let snippets = try bridge.fetchSnippets(for: requests)
                let elapsed = Date().timeIntervalSince(started) * 1_000
                let statements = Array(trace.snapshot().dropFirst(before))
                let batchSQL = statements.filter { $0.contains("SELECT l.bookId, l.lineIndex,") }
                let byBook = Dictionary(grouping: selected, by: \.linkedBookId)
                let expectedQueries = byBook.values.reduce(0) {
                    $0 + (Set($1.map(\.linkedLineIndex)).count + 399) / 400
                }
                precondition(batchSQL.count == expectedQueries)
                precondition(snippets.count == count)
                for source in selected {
                    precondition(snippets[identity(source)] == source.content.otsariaPlainText)
                }
                prefetch.append(["relationships": count, "queries": batchSQL.count,
                    "unique_books": byBook.count, "ms": elapsed, "status": "PASS"])
            }
            cases.append(["case": window.name, "book_id": window.bookID,
                "requested_unique_lines": Set(window.indices).count,
                "relationships": metadata.count, "metadata_queries": metadataQueries.count,
                "metadata_ms": metadataMS, "content_ms": contentMS,
                "metadata_excludes_content": true, "book_identity_grouping_exact": true,
                "prefetch": prefetch, "status": "PASS"])
            print("PASS actual Inspector \(window.name) relationships=\(metadata.count) metadata=\(metadataMS)ms full=\(contentMS)ms")
        }
        // No element is yielded; the call cannot start before cancellation.
        let barrier = AsyncStream<Void>.makeStream()
        let beforeCancel = trace.snapshot().count
        let cancelled = Task.detached {
            for await _ in barrier.stream { break }
            return try bridge.getLinksMetadataForLineIndices(
                bookID: input.windows[0].bookID,
                sourceLineIndices: input.windows[0].indices)
        }
        cancelled.cancel()
        barrier.continuation.finish()
        do {
            _ = try await cancelled.value
            preconditionFailure("cancelled original service cannot return source")
        } catch is CancellationError {}
        precondition(trace.snapshot().count == beforeCancel)
        let report: [String: Any] = [
            "status": "ACTUAL_FULL_V32_INSPECTOR_SOURCE_PASS_NOT_UI",
            "cases": cases, "cancelled_before_query": true,
            "sqlite_version": String(cString: sqlite3_libversion()),
            "native_ui_executed": 0, "physical_device_executed": 0
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("RESULT.json"))
    }
}
