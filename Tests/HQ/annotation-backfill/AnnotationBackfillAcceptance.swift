import Foundation
import SQLite3
import Synchronization
import Darwin

private struct BackfillCheckFailure: Error, CustomStringConvertible {
    let description: String
}

private func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw BackfillCheckFailure(description: message) }
}

private final class RetirementHook: Sendable {
    let owner: AnnotationLocalEditorLifetime
    let inserts = Mutex(0)
    init(owner: AnnotationLocalEditorLifetime) { self.owner = owner }
}

private func retireAfterRealInsert(_ context: UnsafeMutableRawPointer?, _ operation: Int32,
                                   _ database: UnsafePointer<CChar>?, _ table: UnsafePointer<CChar>?,
                                   _ rowID: sqlite3_int64) {
    guard operation == SQLITE_INSERT, let context, let table,
          String(cString: table) == "otzaria_annotation_exchange_versions" else { return }
    let hook = Unmanaged<RetirementHook>.fromOpaque(context).takeUnretainedValue()
    hook.inserts.withLock { $0 += 1 }
    hook.owner.retire()
}

private struct BackfillFixture {
    let directory: URL
    let database: SQLiteDatabase
    let connection: AnnotationLocalEditorConnection
    let owner = AnnotationLocalEditorLifetime()
    let planner: AnnotationBackfillPlanner

    init(root: URL, name: String, count: Int, legacy: Bool = false, create: Bool = true) throws {
        directory = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = AnnotationRepository.shared
        _ = try repository.setupAnnotationsDatabase(at: directory)
        connection = try repository.captureLocalEditorConnection()
        database = connection.database
        planner = try AnnotationBackfillPlanner(connection: connection, owner: owner,
                                                digest: AnnotationExchangePlatformDigest())
        if create {
            try database.transaction {
                for index in 1...max(1, count) where index <= count {
                    let record = legacy
                        ? "legacy_2_\(index)_0_1700000000"
                        : String(format: "00000000-0000-4000-8000-%012lld", Int64(index))
                    let text = "Existing note \(index) · הערה בעברית ובאנגלית\nLine two"
                    try database.execute(query: """
                        INSERT INTO annotations
                        (id,bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,color,type,note,
                         createdAt,context,part,page,ckRecordId,lastModified,backendLocator)
                        VALUES (?,2,?,0,8,0,8,'#FFFF00',0,?,1700000000,'source context',1,1,?,1700000001,NULL);
                        """, parameters: [index, index, text, record])
                }
                try database.execute(query: "INSERT INTO tags(id,name,normalizedName) VALUES (1,'Study','study');")
                if count > 0 {
                    try database.execute(query: "INSERT INTO annotation_tags(annotationId,tagId) VALUES (1,1);")
                }
                try connection.syncPending.addPendingSync(ckRecordId: "existing-cloud-upload", operation: "upload")
                try connection.syncPending.addPendingSync(ckRecordId: "existing-cloud-delete", operation: "delete")
            }
        }
    }

    func scalar(_ sql: String, _ parameters: [Any] = []) throws -> Int64 {
        try database.fetch(query: sql, parameters: parameters) { $0.int64(at: 0) }.first ?? -1
    }

    func originalDigest() throws -> String {
        let columns = [
            "annotations": ["id","bkId","contentId","startIndex","length","startIndexDiac","lengthDiac",
                "color","type","note","createdAt","context","part","page","ckRecordId","lastModified","backendLocator"],
            "tags": ["id","name","normalizedName"],
            "annotation_tags": ["annotationId","tagId"],
            "sync_pending": ["ck_record_id","operation","queued_at"]
        ]
        var result: [String: [[String]]] = [:]
        for (table, names) in columns {
            let projection = names.flatMap { ["typeof(\($0))", "hex(CAST(\($0) AS BLOB))"] }.joined(separator: ",")
            result[table] = try database.fetch(
                query: "SELECT \(projection) FROM \(table) ORDER BY \(names.joined(separator: ","));"
            ) { row in (0..<row.columnCount).map { row.string(at: $0) ?? "<SQL NULL>" } }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return AnnotationExchangePlatformDigest().sha256(try encoder.encode(result))
    }

    func all() throws -> [AnnotationBackfillBatch] {
        let snapshot = try planner.inspect()
        var cursor: Int64 = 0
        var batches: [AnnotationBackfillBatch] = []
        while true {
            let batch = try planner.prepareBatch(snapshot, afterAnnotationID: cursor)
            batches.append(batch)
            cursor = batch.lastAnnotationID
            if batch.isComplete { break }
        }
        return batches
    }
}

private struct CaseObservation: Codable {
    let name: String
    let status: String
    let seconds: Double
    let error: String?
}

private struct Benchmark: Codable {
    let count: Int
    let processID: Int32
    let prepared: Int
    let reused: Int
    let originalDigestBefore: String
    let originalDigestAfter: String
    let elapsedSeconds: Double
    let batchMilliseconds: [Double]
    let lookupMilliseconds: [Double]
    let footprintBoundaryBytes: [UInt64]
    let footprintSampling: String
}

private func footprint() throws -> UInt64 {
    var value = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &value) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard status == KERN_SUCCESS else { throw BackfillCheckFailure(description: "task_info \(status)") }
    return value.phys_footprint
}

private func elapsed(_ start: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}

private func write<Value: Encodable>(_ value: Value, to path: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: path, options: .atomic)
}

@main
private struct BackfillAcceptance {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else { throw BackfillCheckFailure(description: "mode and fixture directory required") }
        let root = URL(fileURLWithPath: arguments[2])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if arguments[1] == "crash-write" {
            let f = try BackfillFixture(root: root, name: "crash", count: 100, legacy: true)
            let original = try f.originalDigest()
            let snapshot = try f.planner.inspect()
            let batch = try f.planner.prepareBatch(snapshot, afterAnnotationID: 0)
            try check(batch.prepared == 50, "first batch not committed")
            try write(["originalDigest": original, "processID": String(getpid())], to: root.appendingPathComponent("crash-writer.json"))
            _exit(73)
        }
        if arguments[1] == "crash-reopen" {
            let f = try BackfillFixture(root: root, name: "crash", count: 0, create: false)
            let original = try f.originalDigest()
            let batches = try f.all()
            let ready = batches.reduce(0) { $0 + $1.prepared }
            let reused = batches.reduce(0) { $0 + $1.reused }
            try check(ready == 50 && reused == 50, "restart did not resume exactly")
            try check(f.originalDigest() == original, "restart changed original data")
            try check(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 100, "restart duplicated a version")
            try check(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") == 0, "restart created transport work")
            try write(["originalDigest": original, "processID": String(getpid()), "prepared": String(ready), "reused": String(reused)],
                      to: root.appendingPathComponent("crash-reopen.json"))
            return
        }
        if arguments[1] == "reopen-5000" {
            let f = try BackfillFixture(root: root, name: "performance-5000", count: 0, create: false)
            let original = try f.originalDigest()
            let batches = try f.all()
            try check(batches.reduce(0) { $0 + $1.prepared } == 0, "cold scan created duplicate plans")
            try check(batches.reduce(0) { $0 + $1.reused } == 5000, "cold scan lost plans")
            try check(f.originalDigest() == original, "cold scan changed originals")
            try write(["originalDigest": original, "processID": String(getpid()), "reused": "5000"],
                      to: root.appendingPathComponent("reopen-5000.json"))
            return
        }
        guard arguments[1] == "checks" else { throw BackfillCheckFailure(description: "unknown mode") }
        var cases: [CaseObservation] = []
        func run(_ name: String, _ action: () throws -> Void) {
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                try action()
                cases.append(.init(name: name, status: "PASS", seconds: elapsed(start) / 1000, error: nil))
            } catch {
                cases.append(.init(name: name, status: "FAIL", seconds: elapsed(start) / 1000, error: String(describing: error)))
            }
            print("\(cases.last!.status) \(name)")
        }
        run("inspection_has_no_schema_identity_or_original_writes") {
            let f = try BackfillFixture(root: root, name: "inspect", count: 5, legacy: true)
            let before = try f.originalDigest()
            let schema = try f.scalar("SELECT COUNT(*) FROM sqlite_master;")
            let snapshot = try f.planner.inspect()
            try check(snapshot.sourceRowCount == 5 && snapshot.lastAnnotationID == 5, "wrong original census")
            try check(f.scalar("SELECT COUNT(*) FROM sqlite_master;") == schema, "inspection installed schema")
            try check(f.originalDigest() == before, "inspection changed originals")
        }
        run("legacy_and_uuid_migration_preserve_original_rows_and_cloud_queue") {
            for legacy in [false, true] {
                let f = try BackfillFixture(root: root, name: legacy ? "legacy" : "uuid", count: 100, legacy: legacy)
                let before = try f.originalDigest()
                let batches = try f.all()
                try check(batches.reduce(0) { $0 + $1.prepared } == 100, "missing prepared notes")
                try check(Set(batches.flatMap(\.entries).map(\.annotationUUID)).count == 100, "identity collision")
                try check(f.originalDigest() == before, "original data or cloud queue changed")
                try check(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") == 0, "migration created a network destination")
                try check(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions WHERE namespace='otzaria.local.annotation';") == 0, "migration claimed editor ownership")
            }
        }
        run("repeated_scan_is_idempotent") {
            let f = try BackfillFixture(root: root, name: "retry", count: 100, legacy: true)
            let first = try f.all()
            let second = try f.all()
            try check(second.reduce(0) { $0 + $1.prepared } == 0, "retry wrote new versions")
            try check(second.reduce(0) { $0 + $1.reused } == 100, "retry lost receipts")
            try check(first.flatMap(\.entries).map(\.mutationID) == second.flatMap(\.entries).map(\.mutationID), "retry changed mutation identity")
        }
        run("plain_A_B_A_edits_keep_three_distinct_plan_versions") {
            let f = try BackfillFixture(root: root, name: "revision", count: 1)
            let first = try f.all()[0].entries[0]
            try f.database.execute(query: "UPDATE annotations SET note='second' WHERE id=1;")
            let second = try f.all()[0].entries[0]
            try f.database.execute(query: "UPDATE annotations SET note=? WHERE id=1;",
                parameters: ["Existing note 1 · הערה בעברית ובאנגלית\nLine two"])
            let third = try f.all()[0].entries[0]
            try check([first.planRevision, second.planRevision, third.planRevision] == [1, 2, 3], "old mutation was replayed over a new head")
            try check(Set([first.mutationID, second.mutationID, third.mutationID]).count == 3, "mutation collision")
            try check(first.annotationUUID == second.annotationUUID && second.annotationUUID == third.annotationUUID, "note identity changed")
        }
        run("rich_saved_body_is_retained_as_opaque_original_version") {
            let f = try BackfillFixture(root: root, name: "rich", count: 1)
            let uuid = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
            let ledger = AnnotationExchangeLedger(database: f.database, digest: AnnotationExchangePlatformDigest())
            try ledger.installSchema()
            let witness = try ledger.captureSource(annotationUUID: uuid)
            let payload = try TorahAnnotationEnvelopeCodec.encode(.init(
                namespace: AnnotationLocalEditorPersistence.namespace, annotationUUID: uuid, originatingApp: "fixture",
                source: witness.metadata, richBody: .init(format: "test.opaque", formatVersion: 1, bytes: Data([0, 255, 1])),
                textPreview: "Fixture preview", editorRevision: nil, title: nil, deletionState: .active))
            let receipt = try ledger.commitLocal(mutationID: UUID(), payload: payload, expectedSource: witness, expectedRevision: 0)
            let batch = try f.all()[0]
            try check(batch.entries[0].localBodySHA256 == receipt.payloadDigest, "plan lost saved rich identity")
            try check(ledger.currentVersion(namespace: AnnotationLocalEditorPersistence.namespace, annotationUUID: uuid)?.payload == payload, "rich bytes changed")
        }
        run("invalid_legacy_row_rolls_back_whole_batch") {
            let f = try BackfillFixture(root: root, name: "invalid", count: 2, legacy: true)
            try f.database.execute(query: "UPDATE annotations SET ckRecordId='foreign-id' WHERE id=2;")
            let before = try f.originalDigest()
            let schema = try f.scalar("SELECT COUNT(*) FROM sqlite_master;")
            do {
                _ = try f.all()
                throw BackfillCheckFailure(description: "invalid identity accepted")
            } catch is BackfillCheckFailure { throw BackfillCheckFailure(description: "invalid identity accepted") }
            catch {}
            try check(f.originalDigest() == before, "invalid batch changed original data")
            try check(f.scalar("SELECT COUNT(*) FROM sqlite_master;") == schema, "invalid batch left migrated schema")
        }
        run("retirement_after_actual_SQLite_insert_rolls_back_all_new_state") {
            let f = try BackfillFixture(root: root, name: "retirement", count: 3, legacy: true)
            let before = try f.originalDigest()
            let schema = try f.scalar("SELECT COUNT(*) FROM sqlite_master;")
            let hook = RetirementHook(owner: f.owner)
            sqlite3_update_hook(f.database.dbPointer, retireAfterRealInsert, Unmanaged.passUnretained(hook).toOpaque())
            defer { sqlite3_update_hook(f.database.dbPointer, nil, nil) }
            do {
                _ = try f.all()
                throw BackfillCheckFailure(description: "retired batch accepted")
            } catch is BackfillCheckFailure { throw BackfillCheckFailure(description: "retired batch accepted") }
            catch {}
            try check(hook.inserts.withLock { $0 } == 1, "no actual version insert observed")
            try check(f.originalDigest() == before, "retirement changed originals")
            try check(f.scalar("SELECT COUNT(*) FROM sqlite_master;") == schema, "retirement left a partial migration")
        }
        run("highlights_and_pending_deletions_do_not_become_notes") {
            let f = try BackfillFixture(root: root, name: "metadata", count: 3, legacy: true)
            try f.database.execute(query: "UPDATE annotations SET note=NULL WHERE id=1;")
            try f.connection.syncPending.addPendingSync(ckRecordId: "legacy_2_2_0_1700000000", operation: "delete")
            let before = try f.originalDigest()
            let batch = try f.all()[0]
            try check(batch.metadataOnly == 1 && batch.pendingDeletion == 1 && batch.prepared == 1, "metadata became notes or deletion resurrected")
            try check(f.originalDigest() == before, "metadata migration changed original rows")
        }
        run("profile_switch_retires_old_plan_without_writing") {
            let f = try BackfillFixture(root: root, name: "profile-old", count: 2, legacy: true)
            let snapshot = try f.planner.inspect()
            let before = try f.originalDigest()
            _ = try BackfillFixture(root: root, name: "profile-new", count: 2)
            do {
                _ = try f.planner.prepareBatch(snapshot, afterAnnotationID: 0)
                throw BackfillCheckFailure(description: "old profile accepted")
            } catch is BackfillCheckFailure { throw BackfillCheckFailure(description: "old profile accepted") }
            catch {}
            try check(f.originalDigest() == before, "old profile changed")
        }
        run("batch_bounds_and_foreign_session_are_rejected") {
            let f = try BackfillFixture(root: root, name: "bounds", count: 1)
            let snapshot = try f.planner.inspect()
            let foreign = AnnotationBackfillSnapshot(sessionID: UUID(), lastAnnotationID: 1, sourceRowCount: 1)
            for (value, limit) in [(snapshot, 0), (snapshot, 101), (foreign, 50)] {
                do {
                    _ = try f.planner.prepareBatch(value, afterAnnotationID: 0, limit: limit)
                    throw BackfillCheckFailure(description: "invalid batch accepted")
                } catch AnnotationBackfillError.invalidBatch {}
            }
        }
        var benchmarks: [Benchmark] = []
        for count in [100, 1000, 5000] {
            run("actual_local_preparation_performance_\(count)") {
                let f = try BackfillFixture(root: root, name: "performance-\(count)", count: count, legacy: true)
                let original = try f.originalDigest()
                let snapshot = try f.planner.inspect()
                var cursor: Int64 = 0, prepared = 0, reused = 0
                var times: [Double] = []
                var memory = [try footprint()]
                let start = DispatchTime.now().uptimeNanoseconds
                while true {
                    let began = DispatchTime.now().uptimeNanoseconds
                    let batch = try f.planner.prepareBatch(snapshot, afterAnnotationID: cursor)
                    times.append(elapsed(began))
                    memory.append(try footprint())
                    prepared += batch.prepared
                    reused += batch.reused
                    cursor = batch.lastAnnotationID
                    if batch.isComplete { break }
                }
                let seconds = elapsed(start) / 1000
                var lookups: [Double] = []
                for index in stride(from: 1, through: count, by: max(1, count / 100)) {
                    let began = DispatchTime.now().uptimeNanoseconds
                    let record = "legacy_2_\(index)_0_1700000000"
                    let uuid = try AnnotationExchangeIdentity.resolve(database: f.database,
                        annotationID: Int64(index), originalRecordID: record)
                    try check(uuid != nil, "prepared identity missing")
                    lookups.append(elapsed(began))
                }
                let after = try f.originalDigest()
                try check(prepared == count && reused == 0 && original == after, "performance scope lost data or count")
                try check(f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == Int64(count), "performance duplicated notes")
                let integrity = try f.database.fetch(query: "PRAGMA integrity_check;") { $0.string(at: 0) }
                try check(integrity == ["ok"], "SQLite integrity failed")
                benchmarks.append(.init(count: count, processID: getpid(), prepared: prepared, reused: reused,
                    originalDigestBefore: original, originalDigestAfter: after, elapsedSeconds: seconds,
                    batchMilliseconds: times, lookupMilliseconds: lookups, footprintBoundaryBytes: memory,
                    footprintSampling: "Actual task_vm_info phys_footprint at batch boundaries; not peak RSS or UI latency"))
            }
        }
        try write(cases, to: root.appendingPathComponent("CASES.json"))
        try write(benchmarks, to: root.appendingPathComponent("BENCHMARKS.json"))
        guard cases.count == 13 && cases.allSatisfy({ $0.status == "PASS" }) else {
            throw BackfillCheckFailure(description: "backfill acceptance failed; retained CASES.json")
        }
    }
}
