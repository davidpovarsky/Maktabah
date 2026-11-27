from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
source = (ROOT / 'proposal/NATIVE_HELPER_ADDITION.swift').read_text()
start = source.index('    private enum OriginalSavedResultsFixtureError: Error {')
end = source.index('    private func originalSavedBookmark(in container: URL)', start)
actual = source[start:end]
encoder = source[source.index('private extension JSONEncoder {'):]
controls = r'''
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
'''
harness = 'import Foundation\nimport SQLite3\nfinal class OriginalSavedResultsOracle {\n' + actual + controls + '\n}\n' + encoder + r'''
@main struct Main {
    static func main() throws {
        try OriginalSavedResultsOracle().run(root: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
'''
out = ROOT / 'controls'
out.mkdir(exist_ok=True)
(out / 'OriginalSQLiteOracleControls.swift').write_text(harness)
(out / 'SOURCE_EXTRACT.json').write_text(json.dumps({
    'source': 'proposal/NATIVE_HELPER_ADDITION.swift',
    'source_sha256': hashlib.sha256(source.encode()).hexdigest(),
    'exact_extracted_span_sha256': hashlib.sha256(actual.encode()).hexdigest(),
    'range_utf8': [len(source[:start].encode()), len(source[:end].encode())],
    'harness_sha256': hashlib.sha256(harness.encode()).hexdigest(),
    'cases': 10,
    'boundary': 'Actual read-only helper and real SQLite; explicit disposable fixture writer solely for counterexamples. No app/SDK/native/system acceptance.'
}, indent=2) + '\n')
print(json.dumps({'harness_bytes': len(harness.encode()), 'source_sha256': hashlib.sha256(source.encode()).hexdigest()}))
