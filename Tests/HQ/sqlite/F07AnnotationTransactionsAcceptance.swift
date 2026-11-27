import Foundation
import SQLite3
import Synchronization

private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}
private enum Injected: Error { case rollback, mapping }
private func require(_ value: @autoclosure () throws -> Bool, _ text: String) throws {
    if try !value() { throw Failure(text) }
}
private func requireFailure(_ work: () throws -> Void, contains: String? = nil) throws {
    do { try work() }
    catch {
        if let contains { try require(String(describing: error).contains(contains), "Wrong failure: \(error)") }
        return
    }
    throw Failure("Expected an actual failure")
}
private struct Case: Codable {
    let name: String
    let passed: Bool
    let error: String?
}
private final class WorkerResult: Sendable {
    let errors = Mutex<[String]>([])
}
private struct Fixture {
    let directory: URL
    let store = AnnotationStore.shared
    let repository = AnnotationRepository.shared
    let database: SQLiteDatabase
    init(_ directory: URL, fresh: Bool = true) throws {
        self.directory = directory
        if fresh { try require(!FileManager.default.fileExists(atPath: directory.path), "Owned fixture must be fresh") }
        try store.setup(at: directory)
        guard let db = repository.db else { throw Failure("Real annotation database did not open") }
        database = db
        try require(try scalar("PRAGMA journal_mode") == "wal", "Real repository did not enable WAL")
    }
    func scalar(_ sql: String, _ parameters: [Any] = []) throws -> String {
        try database.fetch(query: sql, parameters: parameters) { $0.string(at: 0) ?? "<NULL>" }.first ?? "<NONE>"
    }
    func annotation(_ n: Int, suffix: String = "original") -> Annotation {
        Annotation(id: nil, bkId: n.isMultiple(of: 2) ? 28 : -28, contentId: n,
            range: NSRange(location: 2, length: 4), rangeDiacritics: NSRange(location: 2, length: 4),
            colorHex: "#F9D55C", type: .highlight, note: "הערה \(n) — \(suffix)",
            createdAt: 1700000000 + Int64(n), context: "נַפְשִׁי — source \(n)", page: n, part: 1,
            tags: ["לימוד", "cycle-\(n)"], ckRecordId: "f07-owned-\(n)-\(suffix)",
            backendLocator: TextLocator(backend: n.isMultiple(of: 2) ? .otzaria : .sefaria,
                workKey: n.isMultiple(of: 2) ? "book:28" : "Psalms"))
    }
    func load(_ id: Int64) throws -> Annotation {
        guard let value = try repository.loadAnnotationById(id) else { throw Failure("Original row disappeared") }
        return value
    }
    func snapshot() throws -> [[String]] {
        var rows: [[String]] = []
        for table in ["annotations", "annotation_tags", "tags", "sync_pending"] {
            rows.append([table])
            let columnCount = try database.fetch(query: "PRAGMA table_info(\(table))") { $0.int(at: 0) }.count
            rows += try database.fetch(query: "SELECT * FROM \(table) ORDER BY rowid") { row in
                (0..<columnCount).map { row.string(at: Int32($0)) ?? "<NULL>" }
            }
        }
        return rows
    }
}

@main private enum F07AnnotationTransactionsAcceptance {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else { throw Failure("Expected mode and owned fixture root") }
        let mode = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if mode == "cold-write" || mode == "cold-reopen" { try cold(mode, root); return }
        guard mode == "controls" else { throw Failure("Unknown mode") }
        var results: [Case] = []
        func check(_ name: String, _ work: (Fixture) throws -> Void) {
            do {
                let fixture = try Fixture(root.appendingPathComponent(name))
                defer { fixture.store.disconnect(); fixture.store.clearAllCaches() }
                try work(fixture)
                results.append(.init(name: name, passed: true, error: nil))
                print("PASS \(name)")
            } catch {
                AnnotationStore.shared.disconnect(); AnnotationStore.shared.clearAllCaches()
                results.append(.init(name: name, passed: false, error: String(describing: error)))
                print("FAIL \(name): \(error)")
            }
        }
        check("thirty_real_store_add_edit_delete_tag_cycles") { f in
            for n in 1...30 {
                let id = try f.store.addAnnotation(f.annotation(n))
                let added = try f.load(id)
                try require(added.note == f.annotation(n).note && Set(added.tags) == Set(f.annotation(n).tags), "Added body/tags mismatch at \(n)")
                try require(f.store.loadAnnotationById(id)?.note == added.note, "Store cache did not expose saved body")
                var edited = added; edited.note = "עודכן \(n)"; edited.tags = ["לימוד", "updated-\(n)"]
                try f.store.updateAnnotation(edited)
                try require(try f.load(id).note == edited.note && Set(f.load(id).tags) == Set(edited.tags), "Updated row/tags mismatch")
                try require(f.store.loadAnnotationById(id)?.note == edited.note, "Updated Store cache is stale")
                try require(try f.scalar("SELECT operation FROM sync_pending WHERE ck_record_id=?", [added.ckRecordId!]) == "upload", "Durable upload missing")
                try f.store.deleteAnnotation(id: id)
                try require(try f.repository.loadAnnotationById(id) == nil && f.store.loadAnnotationById(id) == nil, "Delete left row/cache")
                try require(try f.scalar("SELECT COUNT(*) FROM annotation_tags WHERE annotationId=?", [id]) == "0", "Delete left tag relation")
                try require(try f.scalar("SELECT operation FROM sync_pending WHERE ck_record_id=?", [added.ckRecordId!]) == "delete", "Delete queue is not atomic")
            }
            try require(try f.scalar("SELECT COUNT(*) FROM annotations") == "0", "Thirty cycles left rows")
            try require(try f.scalar("SELECT COUNT(*) FROM tags") == "0", "Unused tags were not cleaned")
            try require(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE operation='delete'") == "30", "Thirty durable deletes not retained")
        }
        check("nested_savepoint_rollback_preserves_outer_commit") { f in
            try f.repository.transaction {
                _ = try f.repository.addAnnotation(f.annotation(101))
                try requireFailure {
                    try f.repository.transaction {
                        _ = try f.repository.addAnnotation(f.annotation(102))
                        throw Injected.rollback
                    }
                }
                _ = try f.repository.addAnnotation(f.annotation(103))
            }
            try require(try f.scalar("SELECT group_concat(contentId,',') FROM (SELECT contentId FROM annotations ORDER BY contentId)") == "101,103", "Nested rollback lost outer rows or retained inner row")
            try require(try f.scalar("SELECT COUNT(*) FROM sync_pending") == "2", "Nested rollback leaked pending upload")
        }
        check("outer_rollback_reverts_nested_note_tags_and_pending") { f in
            let before = try f.snapshot()
            try requireFailure {
                try f.repository.transaction {
                    _ = try f.repository.addAnnotation(f.annotation(111))
                    try f.repository.transaction { _ = try f.repository.addAnnotation(f.annotation(112)) }
                    throw Injected.rollback
                }
            }
            try require(try f.snapshot() == before, "Outer rollback leaked note, tag, relation or queue")
        }
        check("mapping_throw_resets_real_cached_statement_before_commit") { f in
            let id = try f.store.addAnnotation(f.annotation(121))
            try requireFailure {
                _ = try f.database.fetch(query: "SELECT id FROM annotations") { _ -> Int in throw Injected.mapping }
            }
            var annotation = try f.load(id); annotation.note = "after throwing mapper"
            try f.store.updateAnnotation(annotation)
            try require(try f.load(id).note == annotation.note, "Actual write after mapper failure failed")
            let rows = try f.database.fetch(query: "SELECT id FROM annotations") { $0.int64(at: 0) }
            try require(rows == [id], "Cached statement did not reset")
        }
        for operation in ["add", "edit", "delete"] {
            check("pending_sync_failure_rolls_back_\(operation)") { f in
                let id = try f.store.addAnnotation(f.annotation(131))
                let before = try f.snapshot()
                try f.database.execute(query: "CREATE TEMP TRIGGER f07_owned_queue_failure BEFORE INSERT ON sync_pending BEGIN SELECT RAISE(ABORT,'F07_OWNED_QUEUE_FAILURE'); END;")
                defer { try? f.database.execute(query: "DROP TRIGGER f07_owned_queue_failure") }
                try requireFailure({
                    switch operation {
                    case "add": _ = try f.store.addAnnotation(f.annotation(132))
                    case "edit":
                        var changed = try f.load(id); changed.note = "must roll back"; changed.tags = ["must-roll-back"]
                        try f.store.updateAnnotation(changed)
                    default: try f.store.deleteAnnotation(id: id)
                    }
                }, contains: "F07_OWNED_QUEUE_FAILURE")
                try require(try f.snapshot() == before, "Queue failure partially changed \(operation)")
                try require(f.store.loadAnnotationById(id)?.note == f.annotation(131).note, "Rejected operation changed Store cache")
            }
        }
        check("wal_reader_snapshot_survives_original_store_write") { f in
            let id = try f.store.addAnnotation(f.annotation(141))
            let reader = try SQLiteDatabase(path: f.directory.appendingPathComponent("Annotations.sqlite").path,
                flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            try reader.execute(query: "BEGIN")
            defer { try? reader.execute(query: "ROLLBACK") }
            func note() throws -> String? { try reader.fetch(query: "SELECT note FROM annotations WHERE id=?", parameters: [id]) { $0.string(at: 0) }.first ?? nil }
            let old = try note()
            var changed = try f.load(id); changed.note = "committed during read snapshot"
            try f.store.updateAnnotation(changed)
            try require(try note() == old, "Held WAL reader snapshot unexpectedly changed")
            try require(try f.load(id).note == changed.note, "Original writer failed while WAL reader remained open")
            try reader.execute(query: "COMMIT")
            try require(try note() == changed.note, "New WAL snapshot did not see committed note")
        }
        check("annotation_save_completes_during_independent_relationship_cursor") { f in
            // This owned SQLite fixture models the independent corpus connection.
            // It is not the full production relationship provider or native UI.
            let corpus = try SQLiteDatabase(path: f.directory.appendingPathComponent("owned-relations.sqlite").path)
            try corpus.execute(query: "CREATE TABLE links(id INTEGER PRIMARY KEY, source INTEGER, target INTEGER)")
            try corpus.transaction {
                for n in 1...2000 { try corpus.execute(query: "INSERT INTO links VALUES(?,?,?)", parameters: [n, n, n + 1]) }
            }
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0), ended = DispatchSemaphore(value: 0)
            let result = WorkerResult()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { ended.signal() }
                do {
                    let rows = try corpus.fetch(query: "SELECT id FROM links ORDER BY id") { row -> Int in
                        if row.int(at: 0) == 1 {
                            entered.signal()
                            try require(release.wait(timeout: .now() + 8) == .success, "Owned cursor barrier timed out")
                        }
                        return row.int(at: 0)
                    }
                    try require(rows == Array(1...2000), "Relationship cursor lost rows")
                } catch { result.errors.withLock { $0.append(String(describing: error)) } }
            }
            defer { release.signal() }
            try require(entered.wait(timeout: .now() + 5) == .success, "Actual cursor did not enter")
            let id = try f.store.addAnnotation(f.annotation(151))
            try require(try f.load(id).note == f.annotation(151).note, "Annotation save failed during cursor")
            try require(ended.wait(timeout: .now()) == .timedOut, "Cursor was not active during save")
            release.signal()
            try require(ended.wait(timeout: .now() + 5) == .success, "Cursor did not finish")
            try require(result.errors.withLock { $0.isEmpty }, "Concurrent cursor failed")
        }
        let data = try JSONEncoder().encode(results)
        try data.write(to: root.appendingPathComponent("CASES.json"))
        print("F07 actual component cases: \(results.filter(\.passed).count)/\(results.count)")
        if results.contains(where: { !$0.passed }) { exit(1) }
    }

    static func cold(_ mode: String, _ root: URL) throws {
        let directory = root.appendingPathComponent("cold-profile")
        let receiptURL = root.appendingPathComponent("cold-write.json")
        let f = try Fixture(directory, fresh: mode == "cold-write")
        defer { f.store.disconnect(); f.store.clearAllCaches() }
        var prior: Int32? = nil
        if mode == "cold-write" {
            for n in 201...230 { _ = try f.store.addAnnotation(f.annotation(n)) }
        } else {
            let before = try JSONSerialization.jsonObject(with: Data(contentsOf: receiptURL)) as! [String: Any]
            prior = (before["pid"] as! NSNumber).int32Value
            try require(prior != ProcessInfo.processInfo.processIdentifier, "Cold process reused writer PID")
        }
        for n in 201...230 {
            let values = f.store.loadAnnotations(bkId: n.isMultiple(of: 2) ? 28 : -28, contentId: n)
            try require(values.count == 1 && values[0].note == f.annotation(n).note, "Cold note mismatch \(n)")
            try require(Set(values[0].tags) == Set(f.annotation(n).tags), "Cold tags mismatch")
            try require(values[0].backendLocator == f.annotation(n).backendLocator, "Cold backend locator changed")
        }
        try require(try f.scalar("SELECT COUNT(*) FROM annotations") == "30", "Cold count differs")
        try require(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE operation='upload'") == "30", "Cold durable queue differs")
        try require(try f.scalar("PRAGMA quick_check") == "ok", "Cold SQLite integrity failed")
        let receipt: [String: Any] = ["mode": mode, "pid": ProcessInfo.processInfo.processIdentifier,
            "prior_pid": prior.map { $0 as Any } ?? NSNull(), "annotations": 30,
            "database": directory.appendingPathComponent("Annotations.sqlite").path,
            "native_ui_executed": 0, "cloudkit_transport_executed": 0]
        try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys, .prettyPrinted])
            .write(to: root.appendingPathComponent(mode + ".json"))
        print("PASS \(mode), 30 original rows, tags, queues and backend identities")
    }
}
