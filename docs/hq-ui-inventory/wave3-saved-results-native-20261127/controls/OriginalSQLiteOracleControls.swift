import Foundation
import SQLite3
final class OriginalSavedResultsOracle {
    private enum OriginalSavedResultsFixtureError: Error {
        case rejected(String)
    }
    private struct OriginalSavedResultsCell: Codable, Equatable {
        let type: Int32
        let value: String
    }
    private typealias OriginalSavedResultsRow = [String: OriginalSavedResultsCell]
    private struct OriginalSavedResultsDatabase: Codable, Equatable {
        let folders: [OriginalSavedResultsRow]
        let results: [OriginalSavedResultsRow]
        var canonical: Data {
            get throws { try JSONEncoder.sortedSavedResults.encode(self) }
        }
    }
    private struct OriginalSavedResultsOwner {
        let container: URL
        let metadata: Data
        let bookmark: Data?
        let database: URL
    }
    private struct OriginalSavedResultsFixture {
        let parent: String
        let child: String
        let result: String
        let query: String
        let owner: OriginalSavedResultsOwner
        let parentID: String
        let childID: String
        let mode: String
        let books: String
    }

    private func requireOriginalSavedCondition(_ value: Bool, _ reason: String) throws {
        guard value else { throw OriginalSavedResultsFixtureError.rejected(reason) }
    }

    /// Preserve SQLite NULL, integer, floating point, text and blob identity.
    /// Both original tables are read in ONE read transaction, including their
    /// sync metadata. No expected result is supplied by the app under test.
    private func readOriginalSavedDatabase(_ url: URL) throws -> OriginalSavedResultsDatabase {
        var database: OpaquePointer?
        let opened = sqlite3_open_v2(url.path, &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard opened == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw OriginalSavedResultsFixtureError.rejected("Cannot open the original Saved Results database read-only")
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1_000)
        try requireOriginalSavedCondition(sqlite3_db_readonly(database, "main") == 1,
                                         "The Saved Results oracle must be read-only")
        try requireOriginalSavedCondition(sqlite3_exec(database, "BEGIN DEFERRED TRANSACTION", nil, nil, nil) == SQLITE_OK,
                                         "Could not begin one original database read snapshot")
        defer { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) }
        func rows(_ sql: String) throws -> [OriginalSavedResultsRow] {
            var statement: OpaquePointer?
            try requireOriginalSavedCondition(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                                             "The original Saved Results schema is unavailable")
            guard let statement else { throw OriginalSavedResultsFixtureError.rejected("Missing original read statement") }
            defer { sqlite3_finalize(statement) }
            var values: [OriginalSavedResultsRow] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return values }
                try requireOriginalSavedCondition(status == SQLITE_ROW, "Original Saved Results read did not complete")
                var row: OriginalSavedResultsRow = [:]
                for column in 0..<sqlite3_column_count(statement) {
                    guard let name = sqlite3_column_name(statement, column) else {
                        throw OriginalSavedResultsFixtureError.rejected("Original SQL column has no name")
                    }
                    let key = String(cString: name), type = sqlite3_column_type(statement, column)
                    let value: String
                    switch type {
                    case SQLITE_NULL: value = ""
                    case SQLITE_INTEGER: value = String(sqlite3_column_int64(statement, column))
                    case SQLITE_FLOAT: value = String(sqlite3_column_double(statement, column).bitPattern)
                    case SQLITE_TEXT:
                        guard let text = sqlite3_column_text(statement, column) else {
                            throw OriginalSavedResultsFixtureError.rejected("Original SQL text is unreadable")
                        }
                        value = String(decoding: UnsafeBufferPointer(start: text,
                            count: Int(sqlite3_column_bytes(statement, column))), as: UTF8.self)
                    case SQLITE_BLOB:
                        let count = Int(sqlite3_column_bytes(statement, column))
                        if count == 0 { value = "" }
                        else {
                            guard let bytes = sqlite3_column_blob(statement, column) else {
                                throw OriginalSavedResultsFixtureError.rejected("Original SQL blob is unreadable")
                            }
                            value = Data(bytes: bytes, count: count).base64EncodedString()
                        }
                    default: throw OriginalSavedResultsFixtureError.rejected("Unknown original SQLite value type")
                    }
                    try requireOriginalSavedCondition(row[key] == nil, "Duplicate original SQL column")
                    row[key] = .init(type: type, value: value)
                }
                values.append(row)
            }
        }
        return try .init(folders: rows("SELECT * FROM folders ORDER BY id"),
                         results: rows("SELECT * FROM results ORDER BY id"))
    }


    func run(root: URL) throws {
        var outcomes: [[String: Any]] = []
        func check(_ name: String, _ test: () throws -> Bool) {
            do { outcomes.append(["name": name, "passed": try test()]) }
            catch { outcomes.append(["name": name, "passed": false, "error": String(describing: error)]) }
        }
        let database = root.appendingPathComponent("original.sqlite")
        let original = try readOriginalSavedDatabase(database)
        check("full_actual_schema_and_order") {
            original.folders.map { $0["id"]?.value } == ["1", "2"]
                && original.results.map { $0["id"]?.value } == ["4", "9"]
                && original.results[0].keys.sorted() == ["archives", "bkId", "ckRecordId", "contentId", "floatProbe", "folder_ckrecord_id", "folder_id", "id", "lastModified", "name", "near_distance", "query", "search_mode"].sorted()
        }
        check("null_remains_distinct_from_empty_text") {
            original.folders[0]["parent"]?.type == SQLITE_NULL
                && original.folders[0]["ckRecordId"]?.type == SQLITE_TEXT
                && original.folders[0]["ckRecordId"]?.value == ""
        }
        check("wide_integer_is_lossless") {
            original.results[0]["lastModified"]?.value == "9007199254740993"
                && original.results[0]["lastModified"]?.type == SQLITE_INTEGER
        }
        check("original_unicode_and_embedded_null_are_lossless") {
            original.results[0]["query"]?.value == "בראשית\0exact"
        }
        check("blob_and_float_type_are_retained") {
            original.results[0]["ckRecordId"]?.type == SQLITE_BLOB
                && original.results[0]["ckRecordId"]?.value == Data([0, 255, 17]).base64EncodedString()
                && original.results[0]["floatProbe"]?.type == SQLITE_FLOAT
                && original.results[0]["floatProbe"]?.value == String(0.125.bitPattern)
        }
        check("read_repetition_is_byte_stable") {
            try readOriginalSavedDatabase(database).canonical == original.canonical
        }
        check("missing_database_refused_without_creation") {
            let absent = root.appendingPathComponent("must-remain-absent.sqlite")
            do { _ = try readOriginalSavedDatabase(absent); return false }
            catch { return !FileManager.default.fileExists(atPath: absent.path) }
        }
        check("missing_original_schema_is_refused") {
            do { _ = try readOriginalSavedDatabase(root.appendingPathComponent("missing-results.sqlite")); return false }
            catch { return true }
        }
        // This writer belongs only to a disposable standalone source-control
        // fixture. Neither test helper nor any app/simulator database is written.
        var fixtureWriter: OpaquePointer?
        guard sqlite3_open_v2(database.path, &fixtureWriter, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let fixtureWriter else { throw OriginalSavedResultsFixtureError.rejected("fixture writer") }
        defer { sqlite3_close(fixtureWriter) }
        check("actual_sync_metadata_mutation_is_detected") {
            guard sqlite3_exec(fixtureWriter, "UPDATE results SET lastModified=lastModified+1 WHERE id=4", nil, nil, nil) == SQLITE_OK else { return false }
            return try readOriginalSavedDatabase(database) != original
        }
        check("actual_deleted_original_row_is_detected") {
            let before = try readOriginalSavedDatabase(database)
            guard sqlite3_exec(fixtureWriter, "DELETE FROM results WHERE id=9", nil, nil, nil) == SQLITE_OK else { return false }
            let after = try readOriginalSavedDatabase(database)
            return after != before && after.results.count == before.results.count - 1
                && after.folders == before.folders
        }
        let failed = outcomes.filter { $0["passed"] as? Bool != true }.count
        let report: [String: Any] = ["boundary": "actual native-test SQLite read helper; disposable standalone fixtures, no app/UIKit/system execution",
            "passed": outcomes.count - failed, "failed": failed, "cases": outcomes]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
        if failed != 0 { throw OriginalSavedResultsFixtureError.rejected("source controls failed") }
    }

}
private extension JSONEncoder {
    static var sortedSavedResults: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }
}

@main struct Main {
    static func main() throws {
        try OriginalSavedResultsOracle().run(root: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
