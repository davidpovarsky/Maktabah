import Foundation
import SQLite3

private struct CheckFailure: Error { let message: String }
private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(message: message) }
}
private func expectFailure<T>(_ category: String, _ action: () throws -> T) throws {
    do {
        _ = try action()
    } catch let error as SQLiteError {
        switch (category, error) {
        case ("execution", .executionFailed), ("bind", .bindFailed), ("prepare", .prepareFailed): return
        default: throw CheckFailure(message: "Unexpected SQLite error category: \(error)")
        }
    }
    throw CheckFailure(message: "SQLite \(category) failure was incorrectly returned as success")
}
private final class FailureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func add(_ item: String) { lock.lock(); defer { lock.unlock() }; items.append(item) }
    var failures: [String] { lock.lock(); defer { lock.unlock() }; return items }
}
private struct Result: Codable { let name: String; let passed: Bool; let error: String? }
private final class Harness {
    var results: [Result] = []
    func check(_ name: String, _ action: () throws -> Void) {
        do {
            try action(); results.append(.init(name: name, passed: true, error: nil))
            print("PASS \(name)")
        } catch {
            results.append(.init(name: name, passed: false, error: String(describing: error)))
            print("FAIL \(name): \(error)")
        }
    }
}
private struct SourceOracle: Decodable {
    let uri: String
    let label: String
    let expected: [[String]]
}
private let sourceSQL = """
    SELECT CAST(l.id AS TEXT), CAST(l.bookId AS TEXT), CAST(l.lineIndex AS TEXT), b.title
    FROM line l JOIN book b ON b.id = l.bookId
    WHERE l.bookId = 1 ORDER BY l.lineIndex, l.id LIMIT 5
    """

@main private struct SQLiteDatabaseAcceptance {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            throw CheckFailure(message: "Expected unique fixture directory and source oracle JSON")
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let harness = Harness()
        let db = try SQLiteDatabase(path: directory.appendingPathComponent("connection.sqlite").path)
        try db.execute(query: "CREATE TABLE numbers(value INTEGER PRIMARY KEY)")
        try db.transaction {
            for i in 1...1000 { try db.execute(query: "INSERT INTO numbers(value) VALUES (?)", parameters: [i]) }
        }
        let ordered = "SELECT value FROM numbers ORDER BY value"
        harness.check("successful_rows_and_genuine_zero") {
            let rows = try db.fetch(query: ordered) { $0.int(at: 0) }
            try require(rows == Array(1...1000), "Source row order or count changed")
            let empty = try db.fetch(query: ordered + " LIMIT 0") { $0.int(at: 0) }
            try require(empty.isEmpty, "Successful zero is not empty")
        }
        harness.check("all_supported_binding_types_keep_values") {
            let row = try db.fetch(query: "SELECT ?, ?, ?, ?, ?",
                parameters: [Int(41), Int64.max, 2.5, "פרק א — نص", NSNull()]) {
                ($0.int(at: 0), $0.int64(at: 1), $0.double(at: 2), $0.string(at: 3), $0.isNull(at: 4))
            }.first
            try require(row?.0 == 41 && row?.1 == Int64.max && row?.2 == 2.5 &&
                row?.3 == "פרק א — نص" && row?.4 == true, "Binding values changed")
        }
        harness.check("step_error_before_first_row_is_not_empty_success") {
            try expectFailure("execution") {
                try db.fetch(query: "SELECT abs(-9223372036854775808)") { $0.int64(at: 0) }
            }
        }
        harness.check("step_error_after_first_row_is_not_partial_success") {
            var mapped = 0
            try expectFailure("execution") {
                try db.fetch(query: "SELECT 1 UNION ALL SELECT abs(-9223372036854775808)") { row in
                    mapped += 1; return row.int64(at: 0)
                }
            }
            try require(mapped == 1, "Did not exercise an actual late SQLite step failure")
        }
        harness.check("same_cached_query_recovers_after_step_failure") {
            let sql = "SELECT ? UNION ALL SELECT abs(?)"
            do { _ = try db.fetch(query: sql, parameters: [8, Int64.min]) { $0.int64(at: 0) } } catch {}
            let result = try db.fetch(query: sql, parameters: [8, -2]) { $0.int64(at: 0) }
            try require(result == [8, 2], "Failed cached statement did not reset")
        }
        harness.check("actual_sqlite_interrupt_never_returns_partial_rows") {
            var mapped = 0
            try expectFailure("execution") {
                try db.fetch(query: ordered) { row in
                    mapped += 1
                    if mapped == 1 { sqlite3_interrupt(db.dbPointer) }
                    return row.int(at: 0)
                }
            }
            try require(mapped == 1, "Interrupt fixture did not stop the active statement")
        }
        harness.check("cached_statement_recovers_after_interrupt") {
            let rows = try db.fetch(query: ordered) { $0.int(at: 0) }
            try require(rows == Array(1...1000), "Interrupt poisoned later reads")
        }
        for (label, value) in [("int", Int(9) as Any), ("int64", Int64(9) as Any),
                               ("double", 2.5 as Any), ("text", "מקור" as Any), ("null", NSNull() as Any)] {
            harness.check("out_of_range_\(label)_bind_cannot_succeed") {
                try expectFailure("bind") {
                    try db.fetch(query: "SELECT ?", parameters: [7, value]) { $0.int(at: 0) }
                }
                let valid = try db.fetch(query: "SELECT ?", parameters: [23]) { $0.int(at: 0) }
                try require(valid == [23], "Binding error poisoned a later valid read")
            }
        }
        harness.check("unsupported_bind_type_still_fails_without_poisoning_cache") {
            try expectFailure("bind") {
                try db.fetch(query: "SELECT ?", parameters: [Date(timeIntervalSince1970: 0)]) { $0.int(at: 0) }
            }
            let rows = try db.fetch(query: "SELECT ?", parameters: [17]) { $0.int(at: 0) }
            try require(rows == [17], "Unsupported bind left stale cache values")
        }
        harness.check("mapping_error_is_preserved_and_statement_is_reset") {
            do {
                _ = try db.fetch(query: ordered) { row -> Int in
                    if row.int(at: 0) == 3 { throw CheckFailure(message: "intentional_mapping_error") }
                    return row.int(at: 0)
                }
                throw CheckFailure(message: "Mapping error was swallowed")
            } catch let error as CheckFailure {
                try require(error.message == "intentional_mapping_error", "Wrong mapping failure")
            }
            let rows = try db.fetch(query: ordered) { $0.int(at: 0) }
            try require(rows.count == 1000 && rows.last == 1000, "Mapping error poisoned next query")
        }
        harness.check("cached_schema_change_error_is_not_empty_success") {
            try db.execute(query: "CREATE TABLE transient_source(value INTEGER)")
            let sql = "SELECT value FROM transient_source"
            _ = try db.fetch(query: sql) { $0.int(at: 0) }
            try db.execute(query: "DROP TABLE transient_source")
            try expectFailure("execution") { try db.fetch(query: sql) { $0.int(at: 0) } }
        }
        harness.check("transaction_rolls_back_when_a_read_fails") {
            try expectFailure("execution") {
                try db.transaction {
                    try db.execute(query: "INSERT INTO numbers(value) VALUES (1001)")
                    _ = try db.fetch(query: "SELECT abs(-9223372036854775808)") { $0.int64(at: 0) }
                }
            }
            let count = try db.fetch(query: "SELECT COUNT(*) FROM numbers") { $0.int(at: 0) }
            try require(count == [1000], "A failed read incorrectly allowed transaction commit")
        }
        try lockChecks(directory: directory, harness: harness)
        harness.check("serialized_concurrent_reads_preserve_entire_results") {
            let errors = FailureRecorder()
            DispatchQueue.concurrentPerform(iterations: 24) { _ in
                do {
                    let rows = try db.fetch(query: ordered) { $0.int(at: 0) }
                    try require(rows == Array(1...1000), "Concurrent result is partial")
                } catch { errors.add(String(describing: error)) }
            }
            try require(errors.failures.isEmpty, errors.failures.joined(separator: "; "))
        }
        let oracles = try JSONDecoder().decode([SourceOracle].self,
            from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
        for oracle in oracles {
            harness.check("actual_readonly_source_\(oracle.label)") {
                let source = try SQLiteDatabase(path: oracle.uri,
                    flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI)
                try require(sqlite3_db_readonly(source.dbPointer, "main") == 1, "Source connection is not read-only")
                let actual = try source.fetch(query: sourceSQL) { row in
                    (0..<4).map { row.string(at: Int32($0)) ?? "<NULL>" }
                }
                try require(actual == oracle.expected && !actual.isEmpty, "Original source identity changed")
            }
        }
        struct Report: Codable {
            let sqliteVersion: String
            let cases: [Result]
            let nativeUIExecuted: Int
            let physicalDeviceExecuted: Int
            let decompressorExecuted: Bool
            let originalDatabaseWrapper: String
        }
        let report = Report(sqliteVersion: String(cString: sqlite3_libversion()),
            cases: harness.results, nativeUIExecuted: 0, physicalDeviceExecuted: 0,
            decompressorExecuted: false, originalDatabaseWrapper: "Source/Core/Database/SQLiteDatabase.swift")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: directory.appendingPathComponent("RESULT.json"))
        let failures = harness.results.filter { !$0.passed }.count
        print("ACTUAL_SQLITE \(harness.results.count) cases; \(failures) failures; version \(report.sqliteVersion)")
        if failures != 0 { exit(1) }
    }
    private static func lockChecks(directory: URL, harness: Harness) throws {
        let path = directory.appendingPathComponent("locked-source.sqlite").path
        let writer = try SQLiteDatabase(path: path)
        try writer.execute(query: "CREATE TABLE data(value INTEGER)")
        try writer.execute(query: "INSERT INTO data(value) VALUES (13)")
        let reader = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
        sqlite3_busy_timeout(reader.dbPointer, 30)
        let sql = "SELECT value FROM data"
        _ = try reader.fetch(query: sql) { $0.int(at: 0) } // populate actual statement cache before writer lock
        try writer.execute(query: "BEGIN EXCLUSIVE")
        harness.check("actual_writer_lock_is_not_empty_success") {
            try expectFailure("execution") { try reader.fetch(query: sql) { $0.int(at: 0) } }
        }
        try writer.execute(query: "ROLLBACK")
        harness.check("read_under_writer_lock_recovers_after_rollback") {
            let rows = try reader.fetch(query: sql) { $0.int(at: 0) }
            try require(rows == [13], "Writer rollback did not restore cached read")
        }
        harness.check("readonly_connection_rejects_writes") {
            try expectFailure("execution") { try reader.execute(query: "INSERT INTO data(value) VALUES (99)") }
            let rows = try reader.fetch(query: sql) { $0.int(at: 0) }
            try require(rows == [13], "Read-only source was changed")
        }
    }
}
