import Foundation
import SQLite3
struct OtzariaPerformanceTelemetry: Sendable {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger: Sendable {
    static let shared = Self()
    func log(_ value: String) { print(value) }
}
@main struct PairedReaderTiming {
    struct Input: Decodable { let uri: String }
    @inline(never) static func byteSizes(_ unit: OtzariaReadingUnit) -> (Int, Int) {
        (unit.plainText.utf8.count, unit.html.utf8.count)
    }
    static func measure(_ label: String, round: Int, clear: () -> Void,
                        read: () throws -> OtzariaReadingUnit?) throws -> [String: Any] {
        clear()
        print("BEGIN round=\(round) version=\(label)")
        let first = Date()
        guard let cold = try read() else { fatalError("Actual chapter missing") }
        let coldMS = Date().timeIntervalSince(first) * 1000
        let second = Date()
        guard let warm = try read() else { fatalError("Actual chapter missing") }
        let warmMS = Date().timeIntervalSince(second) * 1000
        precondition(cold == warm, "Original cold/warm full-content and locator equality")
        precondition(cold.id == "toc:851774")
        precondition(cold.sourceLineIndices.count == 110196)
        precondition(cold.startLineIndex == 40920 && cold.endLineIndex == 151115)
        let bytesStart = Date()
        let (plainBytes, htmlBytes) = byteSizes(cold)
        let bytesMS = Date().timeIntervalSince(bytesStart) * 1000
        precondition(plainBytes == 30245157 && htmlBytes == 30583708)
        print("END round=\(round) version=\(label) cold=\(coldMS) warm=\(warmMS) bytesDiagnostic=\(bytesMS)")
        return ["round": round, "version": label, "cold_ms": coldMS, "warm_ms": warmMS,
                "diagnostic_utf8_sizes_ms": bytesMS, "source_rows": cold.sourceLineIndices.count,
                "plain_utf8_bytes": plainBytes, "html_utf8_bytes": htmlBytes,
                "original_cold_warm_full_equality": true]
    }
    static func main() throws {
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments[1])))
        let db = try SQLiteDatabase(path: input.uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        precondition(sqlite3_db_readonly(db.dbPointer, "main") == 1)
        let baseline = BaselineOtzariaReadingUnitService(database: db)
        let candidate = OtzariaReadingUnitService(database: db)
        var records: [[String: Any]] = []
        for round in 0..<2 {
            let order = round == 0 ? ["baseline", "candidate"] : ["candidate", "baseline"]
            for version in order {
                let row: [String: Any]
                if version == "baseline" {
                    row = try measure(version, round: round, clear: { baseline.clearCaches() },
                        read: { try baseline.readingUnit(bookId: 5869, containingLineIndex: 95380, mode: .chapter) })
                } else {
                    row = try measure(version, round: round, clear: { candidate.clearCaches() },
                        read: { try candidate.readingUnit(bookId: 5869, containingLineIndex: 95380, mode: .chapter) })
                }
                records.append(row)
            }
        }
        let result: [String: Any] = ["status": "PAIRED_SAME_PROCESS_READER_DIAGNOSTIC_NOT_UI",
            "records": records, "native_ui_executed": 0, "physical_device_executed": 0]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
