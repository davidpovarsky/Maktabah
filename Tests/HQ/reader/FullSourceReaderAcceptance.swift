import Foundation
import SQLite3

// Logging/signpost boundaries only. Database, schema, TOC, decoder and reader are real.
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) {}
}

@main struct FullSourceReaderAcceptance {
    struct Input: Decodable {
        struct Book: Decodable {
            let id: Int
            let title: String
            let lineCount: Int
            let first: Int
            let middle: Int
            let last: Int
            let navigation: [Navigation]
        }
        struct Navigation: Decodable {
            let index: Int
            let previous: Int?
            let next: Int?
        }
        let uri: String
        let books: [Book]
    }
    static func main() throws {
        let input = try JSONDecoder().decode(Input.self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let db = try SQLiteDatabase(path: input.uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        guard sqlite3_db_readonly(db.dbPointer, "main") == 1 else {
            throw NSError(domain: "SourceMustBeReadOnly", code: 1)
        }
        let capabilities = try OtzariaDatabaseCapabilities(database: db)
        guard capabilities.hasSplitLineContent, capabilities.hasZstdDictionaries else {
            throw NSError(domain: "ActualSchema6Required", code: 1)
        }
        var results: [[String: Any]] = []
        var navigationChecks = 0
        for book in input.books {
            let service = OtzariaReadingUnitService(database: db)
            for point in book.navigation {
                guard let descriptor = try service.descriptor(bookId: book.id,
                    containingLineIndex: point.index, mode: .line) else {
                    throw NSError(domain: "MissingRealLine", code: book.id)
                }
                precondition(descriptor.sourceLineIndices == [point.index])
                precondition(descriptor.previousStartLineIndex == point.previous)
                precondition(descriptor.nextStartLineIndex == point.next)
                let previous = try service.previousDescriptor(bookId: book.id,
                    beforeLineIndex: point.index, mode: .line)
                let next = try service.nextDescriptor(bookId: book.id,
                    afterLineIndex: point.index, mode: .line)
                precondition(previous?.startLineIndex == point.previous)
                precondition(next?.startLineIndex == point.next)
                navigationChecks += 1
            }
            for mode in [OtzariaUnitMode.line, .paragraph, .chapter] {
                for point in [book.first, book.middle] {
                    service.clearCaches()
                    let started = Date()
                    guard let cold = try service.readingUnit(bookId: book.id,
                        containingLineIndex: point, mode: mode) else {
                        throw NSError(domain: "MissingSourceReadingUnit", code: book.id)
                    }
                    let coldMS = Date().timeIntervalSince(started) * 1_000
                    let warmed = Date()
                    let warm = try service.readingUnit(bookId: book.id,
                        containingLineIndex: point, mode: mode)
                    let warmMS = Date().timeIntervalSince(warmed) * 1_000
                    precondition(warm == cold, "warm reading cannot alter original source or locators")
                    precondition(cold.sourceLineIndices.contains(point))
                    precondition(cold.sourceLineIndices == cold.lineAnchors.map(\.lineIndex))
                    let plain = cold.plainText as NSString
                    for anchor in cold.lineAnchors {
                        precondition(anchor.bookId == book.id)
                        precondition(NSMaxRange(anchor.range) <= plain.length)
                        precondition(plain.substring(with: anchor.range) == anchor.text)
                    }
                    let stem = "\(book.id)-\(mode.rawValue)-\(point)"
                    let record: [String: Any] = [
                        "book_id": book.id, "book_title": book.title, "book_source_rows": book.lineCount,
                        "requested_mode": mode.rawValue, "actual_mode": cold.mode.rawValue,
                        "requested_line": point, "unit_id": cold.id,
                        "toc_entry_id": cold.tocEntryId as Any? ?? NSNull(),
                        "source_indices": cold.sourceLineIndices,
                        "anchors": cold.lineAnchors.map { [
                            "id": $0.id, "book_id": $0.bookId, "index": $0.lineIndex,
                            "he_ref": $0.heRef as Any? ?? NSNull(),
                            "utf16_location": $0.range.location, "utf16_length": $0.range.length
                        ] as [String: Any] },
                        "cold_ms": coldMS, "warm_ms": warmMS,
                        "warm_exact_parity": true, "utf16_anchor_ranges_verified": true
                    ]
                    try cold.html.write(to: output.appendingPathComponent(stem + ".html"),
                        atomically: true, encoding: .utf8)
                    try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
                        .write(to: output.appendingPathComponent(stem + ".json"))
                    results.append(["case": stem, "source_rows": cold.sourceLineIndices.count,
                        "cold_ms": coldMS, "warm_ms": warmMS, "status": "PASS"])
                    print("PASS actual reader \(stem) rows=\(cold.sourceLineIndices.count) cold=\(coldMS)ms warm=\(warmMS)ms")
                }
            }
        }
        let report: [String: Any] = ["status": "ACTUAL_SWIFT_READER_SOURCE_PASS_NOT_UI",
            "cases": results, "navigation_cases": navigationChecks,
            "sqlite_version": String(cString: sqlite3_libversion()),
            "source_readonly": true, "native_ui_executed": 0, "physical_device_executed": 0]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("RESULT.json"))
    }
}
