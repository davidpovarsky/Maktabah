import Foundation
import SQLite3

struct PendingIdentity: Codable, Equatable {
    let record: String
    let operation: String
    let queuedAt: Int64
}
struct ImportExpectation: Codable {
    let name: String
    let localID: Int64
    let remoteUUID: String
    let localLocator: TextLocator?
    let remoteLocator: TextLocator?
    let localRawLocator: String?
    let remoteContext: String
    let expectedCount: Int
    let expectedSameID: Bool
    let expectedAdded: Int
    let expectedUpdated: Int
    let older: Bool
    let pending: [PendingIdentity]
    let schema: [String]
}
struct ImportCase {
    let name: String
    let local: TextLocator?
    let remote: TextLocator?
    let sameUUID: Bool
    let adopt: Bool
    let book: Int
    var rawLocal: String? = nil
    var changeContext = false
    var older = false
}
enum ImportControlFailure: Error { case invariant(String) }

func make(_ locator: TextLocator?, id: String?, book: Int, note: String,
          context: String, modified: Int64) -> Annotation {
    Annotation(id: nil, bkId: book, contentId: 10,
               range: NSRange(location: 4, length: 7),
               rangeDiacritics: NSRange(location: 4, length: 7),
               colorHex: "#FFFF00", type: .highlight, note: note, createdAt: 50,
               context: context, page: 1, part: 1, pageArb: "1", partArb: "1",
               tags: [note == "local-note" ? "local-tag" : "remote-tag"],
               ckRecordId: id, lastModified: modified, backendLocator: locator)
}
func pending(_ database: SQLiteDatabase) throws -> [PendingIdentity] {
    try database.fetch(query: "SELECT ck_record_id, operation, queued_at FROM sync_pending ORDER BY ck_record_id;") {
        .init(record: $0.string(at: 0) ?? "", operation: $0.string(at: 1) ?? "", queuedAt: $0.int64(at: 2))
    }
}
func schema(_ database: SQLiteDatabase) throws -> [String] {
    try database.fetch(query: "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name;") {
        ($0.string(at: 0) ?? "") + "|" + ($0.string(at: 1) ?? "") + "|" + ($0.string(at: 2) ?? "")
    }
}
func rawLocator(_ database: SQLiteDatabase, id: Int64) throws -> String? {
    try database.fetch(query: "SELECT backendLocator FROM annotations WHERE id=?;", parameters: [id]) { $0.string(at: 0) }.first ?? nil
}
func writeJSON<T: Encodable>(_ value: T, to path: URL) throws {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: path, options: .atomic)
}
func verify(_ expected: ImportExpectation, repository: AnnotationRepository) throws -> [String] {
    guard let database = repository.db else { throw ImportControlFailure.invariant("no original DB") }
    var failures: [String] = []
    let rows = try repository.loadAllAnnotations()
    if rows.count != expected.expectedCount { failures.append("annotation_count") }
    let remote = rows.filter { $0.ckRecordId == expected.remoteUUID }
    if remote.count != 1 { failures.append("unique_remote_uuid") }
    if let row = remote.first {
        if (row.id == expected.localID) != expected.expectedSameID { failures.append("row_identity") }
        if row.backendLocator != expected.remoteLocator { failures.append("durable_backend_locator") }
        if row.context != expected.remoteContext { failures.append("durable_context") }
        if row.note != (expected.older ? "local-note" : "remote-note") { failures.append("durable_note") }
        if row.lastModified != (expected.older ? 100 : 200) { failures.append("timestamp_conflict_rule") }
        if row.tags != [expected.older ? "local-tag" : "remote-tag"] { failures.append("durable_tags") }
    }
    if !expected.expectedSameID {
        guard let local = try repository.loadAnnotationById(expected.localID) else {
            failures.append("original_local_row_missing")
            return failures
        }
        if local.ckRecordId != nil || local.note != "local-note"
            || local.backendLocator != expected.localLocator || local.context != "original-context" {
            failures.append("unrelated_legacy_source_modified")
        }
        if try rawLocator(database, id: expected.localID) != expected.localRawLocator {
            failures.append("original_locator_bytes_modified")
        }
        if local.tags != ["local-tag"] { failures.append("original_tags_modified") }
    }
    if try pending(database) != expected.pending { failures.append("original_pending_queue_modified") }
    if try schema(database) != expected.schema { failures.append("schema_modified") }
    return failures
}
func cases() -> [ImportCase] {
    let a = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let b = TextLocator(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:2"))
    let o = TextLocator(backend: .otzaria, workKey: "Genesis", position: .canonicalRef("Genesis 1:1"))
    let w = TextLocator(backend: .sefaria, workKey: "Exodus", position: .canonicalRef("Genesis 1:1"))
    return [
        .init(name: "same_uuid_locator_and_context", local: a, remote: b, sameUUID: true, adopt: true, book: -44, changeContext: true),
        .init(name: "legacy_different_backend", local: a, remote: o, sameUUID: false, adopt: false, book: -44),
        .init(name: "legacy_different_work", local: a, remote: w, sameUUID: false, adopt: false, book: -44),
        .init(name: "legacy_different_position", local: a, remote: b, sameUUID: false, adopt: false, book: -44),
        .init(name: "legacy_equal_locator_reordered_json", local: a, remote: a, sameUUID: false, adopt: true, book: -44,
              rawLocal: #"{"position":{"string":"Genesis 1:1","kind":"canonicalRef"},"workKey":"Genesis","backend":"sefaria"}"#),
        .init(name: "legacy_positive_original_identity", local: nil, remote: nil, sameUUID: false, adopt: true, book: 28),
        .init(name: "legacy_negative_missing_locator", local: nil, remote: a, sameUUID: false, adopt: false, book: -44),
        .init(name: "legacy_malformed_locator", local: nil, remote: a, sameUUID: false, adopt: false, book: -44,
              rawLocal: #"{"backend":"sefaria","workKey":"Genesis","position":"malformed"}"#),
        .init(name: "same_uuid_older_remote_preserved", local: a, remote: b, sameUUID: true, adopt: true, book: -44, changeContext: true, older: true)
    ]
}
@main struct CloudImportIdentityControls {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3, ["write", "reopen"].contains(args[1]) else {
            throw ImportControlFailure.invariant("write|reopen and owned directory required")
        }
        let mode = args[1]
        let root = URL(fileURLWithPath: args[2], isDirectory: true)
        let repository = AnnotationRepository.shared
        var results: [[String: Any]] = []
        if mode == "write" {
            var expected: [ImportExpectation] = []
            for (index, test) in cases().enumerated() {
                let directory = root.appendingPathComponent(test.name, isDirectory: true)
                guard !FileManager.default.fileExists(atPath: directory.path) else {
                    throw ImportControlFailure.invariant("refuse existing fixture")
                }
                _ = try repository.setupAnnotationsDatabase(at: directory)
                guard let database = repository.db else { throw ImportControlFailure.invariant("no original DB") }
                let remoteUUID = String(format: "00000000-0000-4000-8000-%012d", index + 1)
                let local = make(test.local, id: test.sameUUID ? remoteUUID : nil,
                                 book: test.book, note: "local-note", context: "original-context", modified: 100)
                let localID = try repository.insertAnnotationRow(local, into: database)
                try repository.replaceTags(local.tags, for: localID)
                if let raw = test.rawLocal {
                    try repository.exec("UPDATE annotations SET backendLocator=? WHERE id=?;", parameters: [raw, localID])
                }
                try repository.addPendingSync(ckRecordId: "unrelated-upload", operation: "upload")
                try repository.addPendingSync(ckRecordId: "unrelated-delete", operation: "delete")
                let raw = try rawLocator(database, id: localID)
                let expectedRow = ImportExpectation(
                    name: test.name, localID: localID, remoteUUID: remoteUUID,
                    localLocator: test.local, remoteLocator: test.older ? test.local : test.remote,
                    localRawLocator: raw, remoteContext: test.changeContext && !test.older ? "remote-context" : "original-context",
                    expectedCount: test.adopt ? 1 : 2, expectedSameID: test.adopt,
                    expectedAdded: test.adopt ? 0 : 1, expectedUpdated: test.adopt && !test.older ? 1 : 0,
                    older: test.older, pending: try pending(database), schema: try schema(database))
                let incoming = make(test.remote, id: remoteUUID, book: test.book, note: "remote-note",
                                    context: test.changeContext ? "remote-context" : "original-context",
                                    modified: test.older ? 99 : 200)
                var imported: (added: [Annotation], updated: [Annotation]) = ([], [])
                try repository.transaction {
                    imported = try repository.applyCloudKitSaves(annotationsToSave: [incoming])
                }
                var failures = try verify(expectedRow, repository: repository)
                if imported.added.count != expectedRow.expectedAdded || imported.updated.count != expectedRow.expectedUpdated {
                    failures.append("original_import_result")
                }
                if let cached = (imported.added + imported.updated).first,
                   let persistedID = cached.id,
                   let persisted = try repository.loadAnnotationById(persistedID),
                   (cached.backendLocator != persisted.backendLocator || cached.context != persisted.context) {
                    failures.append("cache_database_source_divergence")
                }
                expected.append(expectedRow)
                results.append(["name": test.name, "status": failures.isEmpty ? "PASS" : "FAIL",
                                "failures": failures, "added": imported.added.count, "updated": imported.updated.count])
                repository.disconnect()
            }
            try writeJSON(expected, to: root.appendingPathComponent("EXPECTED.json"))
        } else {
            let expected = try JSONDecoder().decode([ImportExpectation].self, from: Data(contentsOf: root.appendingPathComponent("EXPECTED.json")))
            for row in expected {
                _ = try repository.setupAnnotationsDatabase(at: root.appendingPathComponent(row.name, isDirectory: true))
                let failures = try verify(row, repository: repository)
                results.append(["name": row.name, "status": failures.isEmpty ? "PASS" : "FAIL", "failures": failures])
                repository.disconnect()
            }
        }
        let report: [String: Any] = ["schema": 1, "mode": mode, "process_id": ProcessInfo.processInfo.processIdentifier,
            "sqlite_version": String(cString: sqlite3_libversion()), "cases": results,
            "passed": results.filter { ($0["status"] as? String) == "PASS" }.count,
            "failed": results.filter { ($0["status"] as? String) == "FAIL" }.count,
            "scope": "actual full original Repository/Annotation/SQLite/SyncPendingStore; owned fixture DBs; no CloudKit transport, Store cache or native UI"]
        let bytes = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try bytes.write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
        print(String(data: bytes, encoding: .utf8)!)
    }
}
