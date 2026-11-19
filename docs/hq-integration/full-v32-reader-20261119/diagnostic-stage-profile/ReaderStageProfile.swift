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
@main struct ReaderStageProfile {
    struct Input: Decodable { let uri: String }
    @inline(never) static func counts(_ unit: OtzariaReadingUnit) -> (Int, Int) {
        (unit.plainText.count, unit.html.count)
    }
    static func main() throws {
        let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf:
            URL(fileURLWithPath: CommandLine.arguments[1])))
        let db = try SQLiteDatabase(path: input.uri,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
        precondition(sqlite3_db_readonly(db.dbPointer, "main") == 1)
        let service = OtzariaReadingUnitService(database: db)
        var rows: [[String: Any]] = []
        for pass in 0..<3 {
            if pass == 0 { service.clearCaches() }
            let descriptorStart = Date()
            guard let descriptor = try service.descriptor(bookId: 5869,
                containingLineIndex: 95380, mode: .chapter) else { fatalError("Missing actual source") }
            let descriptorMS = Date().timeIntervalSince(descriptorStart) * 1000
            let buildStart = Date()
            guard let unit = try service.buildUnit(from: descriptor) else { fatalError("Missing actual unit") }
            let buildMS = Date().timeIntervalSince(buildStart) * 1000
            let countStart = Date()
            let (plainCount, htmlCount) = counts(unit)
            let countMS = Date().timeIntervalSince(countStart) * 1000
            precondition(unit.sourceLineIndices.count == 110196)
            precondition(plainCount == 17728260 && htmlCount == 18066752)
            let row: [String: Any] = ["pass": pass, "descriptor_ms": descriptorMS,
                "build_unit_including_source_and_normalization_ms": buildMS,
                "diagnostic_grapheme_counts_ms": countMS, "plain_graphemes": plainCount,
                "html_graphemes": htmlCount, "source_rows": unit.sourceLineIndices.count]
            rows.append(row)
            print("PROFILE \(pass) descriptor=\(descriptorMS) build=\(buildMS) counts=\(countMS)")
        }
        let result: [String: Any] = ["status": "DIAGNOSTIC_ORIGINAL_BUILD_VS_LOG_COUNTS_NOT_ACCEPTANCE",
            "records": rows, "native_ui_executed": 0, "physical_device_executed": 0]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
