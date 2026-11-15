import Foundation

// Deterministic data-source double, not SQLite or zstd validation.
struct SQLiteRow {
    let values: [Any?]
    func int(at index: Int32) -> Int { values[Int(index)] as? Int ?? 0 }
    func string(at index: Int32) -> String? { values[Int(index)] as? String }
    func isNull(at index: Int32) -> Bool { values[Int(index)] == nil }
}
final class SQLiteDatabase {
    var entries: [[Any?]] = [[10, nil, "ספר", 0], [11, 10, "א", 1], [12, 10, "ב", 1]]
    var mappings: [(Int, Int)] = [(0, 11), (1, 11), (2, 12)]
    var lines: [[Any?]] = [[100, 0, "שָׁלוֹם 😀", "א"], [101, 1, "English e\u{301}", "ב"], [102, 2, "ג", "ג"]]
    var sourceFetches = 0
    var metadataRows = 0
    var sourceError: Error?
    var onFetch: (() throws -> Void)?
    func fetch<T>(query: String, parameters: [Any] = [], mapping: (SQLiteRow) throws -> T) throws -> [T] {
        try onFetch?()
        let rows: [[Any?]]
        if query.contains("FROM tocEntry te") { rows = entries }
        else if query.contains("FROM line_toc lt") { rows = mappings.map { [$0.0, $0.1] } }
        else if query.contains("SELECT l.lineIndex,") && query.contains("LIMIT 1") {
            let indices = lines.compactMap { $0[1] as? Int }.sorted()
            let target = parameters.count > 1 ? parameters[1] as? Int : nil
            let selected: Int?
            if query.contains("l.lineIndex = ?") { selected = indices.first { $0 == target } }
            else if query.contains("l.lineIndex > ?") { selected = indices.first { $0 > target! } }
            else if query.contains("l.lineIndex < ?") { selected = indices.last { $0 < target! } }
            else { selected = indices.first }
            rows = selected.map { index in
                [[index, indices.last { $0 < index }, indices.first { $0 > index }]]
            } ?? []
            metadataRows += rows.count
        }
        else if query.contains("SELECT lineIndex") {
            rows = lines.map { [$0[1]] }
            metadataRows += rows.count
        }
        else if query.contains("LEFT JOIN line_toc") {
            rows = lines.flatMap { line -> [[Any?]] in
                let matches = mappings.filter { $0.0 == line[1] as? Int }
                return matches.isEmpty ? [[line[1], nil]] : matches.map { [$0.0, $0.1] }
            }
        }
        else {
            sourceFetches += 1
            if let sourceError { throw sourceError }
            if query.contains("lineIndex >=") {
                let start = parameters[1] as! Int, end = parameters[2] as! Int
                rows = lines.filter { let index = $0[1] as! Int; return start <= index && index <= end }
            } else { rows = lines.filter { parameters.dropFirst().compactMap { $0 as? Int }.contains($0[1] as! Int) } }
        }
        return try rows.map { try mapping(SQLiteRow(values: $0)) }
    }
}
struct OtzariaDatabaseCapabilities { init(database: SQLiteDatabase) throws {} }
struct OtzariaLineContentProjection { let expression = "l.content"; let join = "" }
enum OtzariaLineContentCompatibility { static func projection(capabilities: OtzariaDatabaseCapabilities) -> OtzariaLineContentProjection { .init() } }
final class OtzariaLineContentDecoder {
    init(database: SQLiteDatabase, capabilities: OtzariaDatabaseCapabilities) throws {}
    func decode(row: SQLiteRow, at index: Int32) throws -> String { row.string(at: index) ?? "" }
}
enum OtzariaTOCSchemaCompatibility {
    struct Projection { let resolvedLineIndex = "ln.lineIndex" }
    static func projection(in db: SQLiteDatabase) throws -> Projection { .init() }
}
struct OtzariaPerformanceTelemetry {
    static let shared = Self()
    struct Interval { func end(extra: String) {} }
    func begin(_ name: String) -> Interval { .init() }
}
struct OtzariaFileLogger { static let shared = Self(); func log(_ value: String) {} }
extension String { var otsariaPlainText: String { self } }
