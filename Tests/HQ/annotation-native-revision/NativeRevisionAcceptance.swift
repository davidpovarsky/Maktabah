import Foundation
import SQLite3
import Synchronization
import OtzariaActionCore
import Darwin

// The original LocalFixture/helper prefix is extracted verbatim by the driver.
// These tests exercise the original SQLite persistence boundary only. Their
// opaque rich body and request fixtures are not claimed as native SDK archives.
let revisionSchemaTable = "otzaria_local_editor_native_revision_schema"
let revisionAttemptsTable = "otzaria_local_editor_native_revision_attempts"
let revisionRequestBytes = Data("{\"operation\":\"revision\",\"fixture\":\"opaque bounded SDK request bytes\",\"utf8\":\"\u{05e9}\u{05dc}\u{05d5}\u{05dd}\"}".utf8)
let revisionRequestDigest = AnnotationExchangePlatformDigest().sha256(revisionRequestBytes)
let revisionComparison = try! AnnotationLocalEditorNativeComparison(
    accountID: "fixture-account", spaceID: "fixture-space")

func revisionTarget(objectID: String = "fixture-existing-root",
                    heads: [String] = ["head-001", "head-002"]) throws -> AnnotationLocalEditorNativeRevisionTarget {
    try .init(objectID: objectID, expectedHeads: heads, expectedRootDigest: String(repeating: "a", count: 64))
}

func revisionJSON(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
}

func revisionObject(_ data: Data) throws -> [String: Any] {
    guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw LocalCheckFailure("expected JSON object")
    }
    return result
}

func revisionData(_ text: String) throws -> Data {
    guard let bytes = Data(base64Encoded: text) else { throw LocalCheckFailure("invalid base64") }
    return bytes
}

/// Includes every original schema object and every typed cell/rowid. Only the
/// two explicitly new revision tables and their own index are excluded.
func revisionProtectedDatabase(_ db: SQLiteDatabase) throws -> Data {
    try db.withSerializedAccess {
        let schema = try db.fetch(query: """
            SELECT type, name, tbl_name, coalesce(sql, '') FROM main.sqlite_master
            WHERE tbl_name NOT IN (?, ?) ORDER BY type COLLATE BINARY, name COLLATE BINARY;
            """, parameters: [revisionSchemaTable, revisionAttemptsTable]) { row -> [String] in
                try (0..<4).map { index in
                    guard let text = row.string(at: Int32(index)) else { throw LocalCheckFailure("schema string missing") }
                    return text
                }
            }
        var contents: [String: [String]] = [:]
        for entry in schema where entry[0] == "table" {
            let quoted = "\"" + entry[1].replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let projection = entry[3].uppercased().contains("WITHOUT ROWID") ? "*" : "rowid, *"
            let sql = "SELECT \(projection) FROM main.\(quoted);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db.dbPointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                throw LocalCheckFailure("original table read failed: " + entry[1])
            }
            defer { sqlite3_finalize(stmt) }
            var rows: [String] = []
            var code = sqlite3_step(stmt)
            while code == SQLITE_ROW {
                var cells: [String] = []
                for index in 0..<sqlite3_column_count(stmt) {
                    let type = sqlite3_column_type(stmt, index)
                    switch type {
                    case SQLITE_INTEGER: cells.append("i:" + String(sqlite3_column_int64(stmt, index)))
                    case SQLITE_FLOAT: cells.append("f:" + String(sqlite3_column_double(stmt, index).bitPattern, radix: 16))
                    case SQLITE_NULL: cells.append("null")
                    default:
                        let length = Int(sqlite3_column_bytes(stmt, index))
                        let bytes: Data
                        if length == 0 { bytes = Data() }
                        else {
                            guard let pointer = sqlite3_column_blob(stmt, index) else {
                                throw LocalCheckFailure("original cell bytes missing")
                            }
                            bytes = Data(bytes: pointer, count: length)
                        }
                        cells.append((type == SQLITE_TEXT ? "t:" : "b:") + bytes.base64EncodedString())
                    }
                }
                rows.append(try revisionJSON(cells).base64EncodedString())
                code = sqlite3_step(stmt)
            }
            guard code == SQLITE_DONE else { throw LocalCheckFailure("partial original table read") }
            contents[entry[1]] = rows.sorted()
        }
        return try revisionJSON(["schema": schema, "rows": contents])
    }
}

@MainActor
struct RevisionProtectedState {
    let database: Data
    let cloud: CloudKitSyncManager.Observation
    init(_ f: LocalFixture) throws {
        database = try revisionProtectedDatabase(f.db)
        cloud = CloudKitSyncManager.shared.observation
    }
    func verify(_ f: LocalFixture) throws {
        try check(try revisionProtectedDatabase(f.db) == database, "original rows/tags/history/queues/ACK/schema changed")
        let current = CloudKitSyncManager.shared.observation
        try check(current.uploads == cloud.uploads && current.trackPending == cloud.trackPending &&
                  current.deletes == cloud.deletes, "revision bookkeeping published a CloudKit callback")
    }
}

struct RevisionRecord: Codable, Equatable, Sendable {
    let attempt: String
    let operation: String
    let imageBase64: String
    let imageSHA256: String
    let targetBase64: String
    let targetSHA256: String
    let requestBase64: String?
    let requestSHA256: String?
    let state: String
}

func revisionRows(_ db: SQLiteDatabase) throws -> [RevisionRecord] {
    try db.fetch(query: """
        SELECT attempt_uuid, operation, image_base64, image_sha256, target_base64,
               target_sha256, request_base64, request_sha256, dispatch_state
        FROM main.otzaria_local_editor_native_revision_attempts ORDER BY attempt_uuid COLLATE BINARY;
        """) { row in
            func string(_ index: Int32) throws -> String {
                guard let result = row.string(at: index) else { throw LocalCheckFailure("revision column missing") }
                return result
            }
            return try RevisionRecord(attempt: string(0), operation: string(1), imageBase64: string(2),
                imageSHA256: string(3), targetBase64: string(4), targetSHA256: string(5),
                requestBase64: row.string(at: 6), requestSHA256: row.string(at: 7), state: string(8))
        }
}

func onlyRevision(_ db: SQLiteDatabase) throws -> RevisionRecord {
    let rows = try revisionRows(db)
    try check(rows.count == 1, "expected exactly one revision")
    return rows[0]
}

func requireAnyRevisionError(_ work: () throws -> Void) throws {
    do { try work() }
    catch is SQLiteError { return }
    throw LocalCheckFailure("expected original SQLite failure")
}

/// Hooks belong solely to an owned fixture connection. No foreign schema
/// trigger is installed to evade the production schema validator.
final class RevisionSQLProbe: Sendable {
    enum Mode: Sendable { case observe, refuseCommit, crashBeforeCommit }
    struct Observation: Sendable {
        var inserts = 0
        var updates = 0
        var commitCalls = 0
        var retirementStarted = false
    }
    let mode: Mode
    let marker: URL?
    let retireOwner: AnnotationLocalEditorLifetime?
    let retired = DispatchSemaphore(value: 0)
    private let state = Mutex(Observation())
    init(_ mode: Mode = .observe, marker: URL? = nil, retireOwner: AnnotationLocalEditorLifetime? = nil) {
        self.mode = mode; self.marker = marker; self.retireOwner = retireOwner
    }
    var observation: Observation { state.withLock { $0 } }
    func wrote(_ operation: Int32) {
        let start = state.withLock { value -> Bool in
            if operation == SQLITE_INSERT { value.inserts += 1 }
            if operation == SQLITE_UPDATE { value.updates += 1 }
            guard retireOwner != nil, !value.retirementStarted else { return false }
            value.retirementStarted = true
            return true
        }
        if start, let retireOwner {
            DispatchQueue.global().async {
                // Runs on another thread: the original in-transaction lifetime
                // lock must finish before this retirement can be observed.
                retireOwner.retire()
                self.retired.signal()
            }
        }
    }
    func beforeCommit() -> Int32 {
        let observed = state.withLock { value -> Observation in
            value.commitCalls += 1
            return value
        }
        guard observed.inserts + observed.updates > 0 else { return 0 }
        switch mode {
        case .observe: return 0
        case .refuseCommit: return 1
        case .crashBeforeCommit:
            guard let marker else { _exit(74) }
            do {
                try revisionJSON(["phase": "inside_actual_sqlite_commit_hook", "processID": Int(getpid()),
                    "inserts": observed.inserts, "updates": observed.updates,
                    "commitCalls": observed.commitCalls]).write(to: marker, options: .atomic)
            } catch { _exit(74) }
            _exit(73)
        }
    }
}

func revisionUpdateHook(_ context: UnsafeMutableRawPointer?, _ operation: Int32,
                        _ database: UnsafePointer<CChar>?, _ table: UnsafePointer<CChar>?,
                        _ rowID: sqlite3_int64) {
    guard let context, let database, let table, String(cString: database) == "main",
          String(cString: table) == "otzaria_local_editor_native_revision_attempts" else { return }
    Unmanaged<RevisionSQLProbe>.fromOpaque(context).takeUnretainedValue().wrote(operation)
}
func revisionCommitHook(_ context: UnsafeMutableRawPointer?) -> Int32 {
    guard let context else { return 0 }
    return Unmanaged<RevisionSQLProbe>.fromOpaque(context).takeUnretainedValue().beforeCommit()
}
func revisionHooks(_ db: SQLiteDatabase, _ probe: RevisionSQLProbe?) {
    if let probe {
        let pointer = Unmanaged.passUnretained(probe).toOpaque()
        sqlite3_update_hook(db.dbPointer, revisionUpdateHook, pointer)
        sqlite3_commit_hook(db.dbPointer, revisionCommitHook, pointer)
    } else {
        sqlite3_update_hook(db.dbPointer, nil, nil)
        sqlite3_commit_hook(db.dbPointer, nil, nil)
    }
}

@MainActor
final class NativeRevisionCases {
    struct Row: Codable { let name: String; let status: String; let error: String? }
    let root: URL
    var rows: [Row] = []
    init(root: URL) { self.root = root }
    func run(_ name: String, _ work: @MainActor () async throws -> Void) async {
        do { try await work(); rows.append(.init(name: name, status: "PASS", error: nil)); print("PASS \(name)") }
        catch { rows.append(.init(name: name, status: "FAIL", error: String(describing: error))); print("FAIL \(name): \(error)") }
    }
    func saved(_ name: String) async throws -> (LocalFixture, AnnotationLocalEditorPersistence,
            AnnotationLocalEditorSnapshot, AnnotationLocalEditorCommitted) {
        let f = try LocalFixture(root: root, name: name)
        let session = try f.session()
        let committed = try await f.initialSave(session)
        let storage = try f.storage()
        return (f, storage, try storage.read(), committed)
    }
    func prepare(_ storage: AnnotationLocalEditorPersistence, _ snapshot: AnnotationLocalEditorSnapshot)
        throws -> AnnotationLocalEditorNativeRevisionPreparation {
        try storage.prepareNativeRevision(snapshot: snapshot, comparison: revisionComparison, target: revisionTarget())
    }
    func mark(_ storage: AnnotationLocalEditorPersistence, _ prepared: AnnotationLocalEditorNativeRevisionPreparation)
        throws -> AnnotationLocalEditorNativeAttemptObservation {
        try storage.markNativeRevisionMayHaveDispatched(prepared,
            requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest)
    }

    func execute() async {
        await run("plain_note_cannot_install_revision_schema") {
            let f = try LocalFixture(root: root, name: "plain"), p = try f.storage()
            let snapshot = try p.read(), before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "plain preparation wrote schema or data")
        }
        await run("prepared_revision_retains_complete_original_saved_image") {
            let (f, p, snapshot, _) = try await saved("image")
            let protected = try RevisionProtectedState(f), prepared = try prepare(p, snapshot)
            let record = try onlyRevision(f.db), bytes = try revisionData(record.imageBase64)
            try check(record.operation == "revision" && record.state == "prepared" &&
                      record.requestBase64 == nil && record.requestSHA256 == nil, "wrong initial state")
            try check(record.attempt == prepared.observation.attemptID.uuidString, "attempt identity changed")
            try check(AnnotationExchangePlatformDigest().sha256(bytes) == record.imageSHA256, "image digest differs")
            let image = try revisionObject(bytes)
            guard let columns = image["columns"] as? [String], let values = image["values"] as? [Any],
                  columns.count == values.count, Set(columns).count == columns.count else { throw LocalCheckFailure("invalid frozen image") }
            let fields = Dictionary(uniqueKeysWithValues: zip(columns, values))
            guard let version = snapshot.version, case .supported(let envelope, _)? = snapshot.document,
                  let body = envelope.richBody else { throw LocalCheckFailure("actual saved rich image missing") }
            let expectedFields: [String: Any] = [
                "attempt_uuid": prepared.observation.attemptID.uuidString,
                "namespace": version.namespace, "annotation_uuid": snapshot.annotationUUID.uuidString,
                "annotation_id": snapshot.annotation.id!, "prepared_session_uuid": snapshot.sessionID.uuidString,
                "captured_database_url": snapshot.databaseURL.absoluteString,
                "native_account_id": revisionComparison.accountID, "native_space_id": revisionComparison.spaceID,
                "source_canonical_base64": snapshot.source.canonicalBytes.base64EncodedString(),
                "source_digest": snapshot.source.digest, "version_mutation_uuid": version.mutationID.uuidString,
                "saved_revision": version.revision, "payload_digest": version.payloadDigest,
                "payload_base64": version.payload.base64EncodedString(), "destinations_json": version.destinationsJSON,
                "body_format": body.format, "body_format_version": body.formatVersion,
                "body_byte_count": Int64(body.bytes.count), "body_digest": AnnotationExchangePlatformDigest().sha256(body.bytes)
            ]
            let expectedBytes = try revisionJSON(expectedFields), actualBytes = try revisionJSON(fields)
            try check(image["schema"] as? String == "otzaria.original.annotation.revision-source.v1" &&
                      columns.count == 19 && actualBytes == expectedBytes, "complete original saved image differs")
            try check(fields["annotation_uuid"] as? String == snapshot.annotationUUID.uuidString, "UUID changed")
            try check(fields["prepared_session_uuid"] as? String == snapshot.sessionID.uuidString, "session changed")
            try check(fields["captured_database_url"] as? String == snapshot.databaseURL.absoluteString, "profile changed")
            try check(fields["source_canonical_base64"] as? String == snapshot.source.canonicalBytes.base64EncodedString(), "source bytes changed")
            try check(fields["payload_base64"] as? String == snapshot.version!.payload.base64EncodedString(), "whole saved payload changed")
            try check(fields["payload_digest"] as? String == snapshot.version!.payloadDigest, "saved payload digest changed")
            try check(fields["native_account_id"] as? String == revisionComparison.accountID &&
                      fields["native_space_id"] as? String == revisionComparison.spaceID, "comparison changed")
            let target = try revisionObject(revisionData(record.targetBase64))
            try check(target["objectID"] as? String == prepared.target.objectID &&
                      target["expectedHeads"] as? [String] == prepared.target.expectedHeads &&
                      target["expectedRootSHA256"] as? String == prepared.target.expectedRootDigest, "native comparison target changed")
            let targetBytes = try revisionData(record.targetBase64)
            try check(AnnotationExchangePlatformDigest().sha256(targetBytes) == record.targetSHA256, "target digest differs")
            try protected.verify(f)
        }
        await run("revision_coexists_with_permanent_dispatched_fresh_import_fence") {
            let (f, p, snapshot, _) = try await saved("coexist")
            let fresh = try p.prepareNativeAttempt(snapshot: snapshot, comparison: revisionComparison)
            _ = try p.markNativeAttemptMayHaveDispatched(fresh)
            let protected = try RevisionProtectedState(f)
            let revision = try prepare(p, snapshot); _ = try mark(p, revision)
            try check(try p.nativeAttemptObservation()?.state == .dispatchMayHaveOccurred, "fresh history lost")
            try rejects(AnnotationLocalEditorNativeAttemptError.dispatchMayHaveOccurred) {
                _ = try p.prepareNativeAttempt(snapshot: snapshot, comparison: revisionComparison)
            }
            try protected.verify(f)
        }
        await run("exact_request_bytes_and_digest_commit_together") {
            let (f, p, snapshot, _) = try await saved("request"), protected = try RevisionProtectedState(f)
            let prepared = try prepare(p, snapshot), before = try onlyRevision(f.db)
            let receipt = try mark(p, prepared), after = try onlyRevision(f.db)
            try check(receipt.state == .dispatchMayHaveOccurred && receipt.attemptID == prepared.observation.attemptID, "wrong transition receipt")
            try check(after.requestBase64 == revisionRequestBytes.base64EncodedString() &&
                      after.requestSHA256 == revisionRequestDigest && after.state == "dispatch_may_have_occurred", "request not durable")
            try check(after.imageBase64 == before.imageBase64 && after.imageSHA256 == before.imageSHA256 &&
                      after.targetBase64 == before.targetBase64 && after.targetSHA256 == before.targetSHA256, "immutable revision image changed")
            try protected.verify(f)
        }
        await run("same_revision_preparation_dispatches_only_once") {
            let (f, p, snapshot, _) = try await saved("one-use"), prepared = try prepare(p, snapshot)
            _ = try mark(p, prepared); let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.observationChanged) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "second dispatch changed persisted bytes")
        }
        await run("concurrent_revision_cas_has_exactly_one_winner") {
            let (f, p, snapshot, _) = try await saved("concurrent"), protected = try RevisionProtectedState(f)
            let prepared = try prepare(p, snapshot)
            let work: @Sendable () throws -> Bool = {
                do {
                    _ = try p.markNativeRevisionMayHaveDispatched(prepared,
                        requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest)
                    return true
                } catch AnnotationLocalEditorNativeAttemptError.observationChanged { return false }
            }
            let first = Task.detached { try work() }, second = Task.detached { try work() }
            let winners = [try await first.value, try await second.value].filter { $0 }.count
            let actualRows = try revisionRows(f.db)
            try check(winners == 1 && actualRows.count == 1, "CAS did not admit exactly one transition")
            try protected.verify(f)
        }
        await run("stale_source_before_preparation_is_refused") {
            let (f, p, snapshot, _) = try await saved("stale-source-prepare")
            try f.db.execute(query: "UPDATE annotations SET context='new original context' WHERE id=?;", parameters: [f.annotation.id!])
            let before = try f.databaseImage()
            try rejects(AnnotationExchangeError.staleSource) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "stale preparation wrote bytes")
        }
        await run("stale_revision_before_preparation_is_refused") {
            let (f, p, snapshot, committed) = try await saved("stale-revision-prepare")
            _ = try f.replacePayload(committed) { $0["futureRevisionMetadata"] = .string("changed") }
            let before = try f.databaseImage()
            try rejects(AnnotationExchangeError.staleRevision) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "stale revision preparation wrote bytes")
        }
        await run("source_change_before_dispatch_preserves_prepared_record") {
            let (f, p, snapshot, _) = try await saved("stale-source-dispatch"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "UPDATE annotations SET context='new original context' WHERE id=?;", parameters: [f.annotation.id!])
            let before = try f.databaseImage()
            try rejects(AnnotationExchangeError.staleSource) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "stale dispatch changed record")
        }
        await run("revision_change_before_dispatch_preserves_prepared_record") {
            let (f, p, snapshot, committed) = try await saved("stale-revision-dispatch"), prepared = try prepare(p, snapshot)
            _ = try f.replacePayload(committed) { $0["futureRevisionMetadata"] = .string("changed") }
            let before = try f.databaseImage()
            try rejects(AnnotationExchangeError.staleRevision) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "stale revision dispatch changed record")
        }
        await run("foreign_session_snapshot_cannot_prepare_revision") {
            let (f, _, snapshot, _) = try await saved("foreign-session"), other = try f.storage(), before = try f.databaseImage()
            try rejects(AnnotationLocalEditorError.wrongOwner) { _ = try prepare(other, snapshot) }
            try check(try f.databaseImage() == before, "foreign session wrote a revision")
        }
        await run("foreign_storage_cannot_adopt_revision_preparation") {
            let (f, p, snapshot, _) = try await saved("foreign-storage"), prepared = try prepare(p, snapshot)
            let other = try f.storage(), before = try f.databaseImage()
            try check(!other.ownsNativeRevisionPreparation(prepared), "foreign storage reports ownership")
            try rejects(AnnotationLocalEditorNativeAttemptError.wrongPreparation) { _ = try mark(other, prepared) }
            try check(try f.databaseImage() == before, "foreign storage changed bytes")
        }
        await run("different_profile_cannot_adopt_revision_preparation") {
            let (f, p, snapshot, _) = try await saved("profile-a"), prepared = try prepare(p, snapshot)
            let (other, otherStorage, _, _) = try await saved("profile-b")
            let firstBefore = try f.databaseImage(), secondBefore = try other.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.wrongPreparation) { _ = try mark(otherStorage, prepared) }
            let firstAfter = try f.databaseImage(), secondAfter = try other.databaseImage()
            try check(firstAfter == firstBefore && secondAfter == secondBefore, "cross-profile write")
        }
        await run("retired_owner_cannot_prepare_revision") {
            let (f, p, snapshot, _) = try await saved("retired-prepare"), before = try f.databaseImage()
            p.owner.retire()
            try rejects(AnnotationLocalEditorError.retired) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "retired owner installed schema")
        }
        await run("retired_owner_cannot_mark_revision_dispatch") {
            let (f, p, snapshot, _) = try await saved("retired-dispatch"), prepared = try prepare(p, snapshot)
            p.owner.retire(); let before = try f.databaseImage()
            try check(!p.ownsNativeRevisionPreparation(prepared), "retired preparation reports ownership")
            try rejects(AnnotationLocalEditorError.retired) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "retired owner changed dispatch state")
        }
        await run("disconnect_reconnect_never_revives_prepared_owner") {
            let (f, p, snapshot, _) = try await saved("reconnect"), prepared = try prepare(p, snapshot)
            f.store.disconnect(); f.store.connect()
            let before = try f.databaseImage()
            try check(!p.ownsNativeRevisionPreparation(prepared), "reconnection revived owner")
            try rejects(AnnotationLocalEditorError.retired) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "old connection changed record")
        }
        await run("pending_original_delete_blocks_preparation") {
            let (f, p, snapshot, _) = try await saved("delete-prepare")
            try f.repository.addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "delete")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorError.pendingDeletion) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "preparation resurrected original deletion")
        }
        await run("pending_original_delete_blocks_dispatch") {
            let (f, p, snapshot, _) = try await saved("delete-dispatch"), prepared = try prepare(p, snapshot)
            try f.repository.addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "delete")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorError.pendingDeletion) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "dispatch resurrected original deletion")
        }
        await run("nested_transaction_does_not_issue_revision_preparation") {
            let (f, p, snapshot, _) = try await saved("nested"), before = try f.databaseImage()
            try f.db.transaction {
                try rejects(AnnotationLocalEditorNativeAttemptError.nestedTransaction) { _ = try prepare(p, snapshot) }
            }
            try check(try f.databaseImage() == before, "nested transaction wrote revision schema")
        }
        await run("empty_request_does_not_consume_preparation") {
            let (f, p, snapshot, _) = try await saved("empty-request"), prepared = try prepare(p, snapshot), before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.wrongPreparation) {
                _ = try p.markNativeRevisionMayHaveDispatched(prepared, requestBytes: Data(),
                    requestSHA256: AnnotationExchangePlatformDigest().sha256(Data()))
            }
            try check(try f.databaseImage() == before, "empty request consumed preparation")
        }
        await run("mismatched_request_digest_does_not_consume_preparation") {
            let (f, p, snapshot, _) = try await saved("digest"), prepared = try prepare(p, snapshot), before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.wrongPreparation) {
                _ = try p.markNativeRevisionMayHaveDispatched(prepared, requestBytes: revisionRequestBytes,
                    requestSHA256: String(repeating: "0", count: 64))
            }
            try check(try f.databaseImage() == before, "mismatched request digest wrote bytes")
        }
        await run("oversized_request_does_not_consume_preparation") {
            let (f, p, snapshot, _) = try await saved("oversized"), prepared = try prepare(p, snapshot), before = try f.databaseImage()
            let oversized = Data(repeating: 65, count: 2 * 1_024 * 1_024 + 1)
            try rejects(AnnotationLocalEditorNativeAttemptError.wrongPreparation) {
                _ = try p.markNativeRevisionMayHaveDispatched(prepared, requestBytes: oversized,
                    requestSHA256: AnnotationExchangePlatformDigest().sha256(oversized))
            }
            try check(try f.databaseImage() == before, "oversized request wrote bytes")
        }
        await run("stored_image_tampering_cannot_authorize_dispatch") {
            let (f, p, snapshot, _) = try await saved("image-tamper"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_revision_attempts SET image_base64=?;",
                parameters: [Data("changed frozen image".utf8).base64EncodedString()])
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.observationChanged) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "tampered image was rewritten/adopted")
        }
        await run("stored_target_tampering_cannot_authorize_dispatch") {
            let (f, p, snapshot, _) = try await saved("target-tamper"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_revision_attempts SET target_sha256=?;",
                parameters: [String(repeating: "0", count: 64)])
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.observationChanged) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "tampered target was rewritten/adopted")
        }
        await run("partial_foreign_schema_is_not_migrated_or_adopted") {
            let (f, p, snapshot, _) = try await saved("partial-schema")
            try f.db.execute(query: "CREATE TABLE otzaria_local_editor_native_revision_schema(version INTEGER);")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try prepare(p, snapshot) }
            try check(try f.databaseImage() == before, "foreign schema was changed")
        }
        await run("unexpected_revision_column_is_refused") {
            let (f, p, snapshot, _) = try await saved("extra-column"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "ALTER TABLE otzaria_local_editor_native_revision_attempts ADD COLUMN foreign_field TEXT;")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "foreign table definition adopted")
        }
        await run("temporary_revision_shadow_is_refused") {
            let (f, p, snapshot, _) = try await saved("temp-shadow"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "CREATE TEMP TABLE otzaria_local_editor_native_revision_attempts(value TEXT);")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "temp shadow led to main write")
        }
        await run("foreign_revision_trigger_is_refused_before_write") {
            let (f, p, snapshot, _) = try await saved("trigger"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: """
                CREATE TRIGGER foreign_revision_trigger AFTER UPDATE ON otzaria_local_editor_native_revision_attempts
                BEGIN SELECT 1; END;
                """)
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "foreign trigger was admitted")
        }
        await run("foreign_revision_index_is_refused") {
            let (f, p, snapshot, _) = try await saved("index"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "CREATE INDEX foreign_revision_index ON otzaria_local_editor_native_revision_attempts(image_sha256);")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "foreign index was admitted")
        }
        await run("missing_revision_schema_marker_is_refused") {
            let (f, p, snapshot, _) = try await saved("marker"), prepared = try prepare(p, snapshot)
            try f.db.execute(query: "DELETE FROM otzaria_local_editor_native_revision_schema;")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorNativeAttemptError.schemaMismatch) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "missing marker recreated during dispatch")
        }
        await run("prepare_commit_fault_rolls_back_actual_insert_and_schema") {
            let (f, p, snapshot, _) = try await saved("rollback-prepare"), before = try f.databaseImage()
            let probe = RevisionSQLProbe(.refuseCommit)
            revisionHooks(f.db, probe)
            defer { revisionHooks(f.db, nil) }
            try requireAnyRevisionError { _ = try prepare(p, snapshot) }
            let observed = probe.observation
            try check(observed.inserts == 1 && observed.commitCalls == 1, "fault did not reach real INSERT and COMMIT")
            try check(try f.databaseImage() == before, "failed original SQLite COMMIT retained schema/row")
        }
        await run("dispatch_commit_fault_rolls_back_actual_update_request_and_state") {
            let (f, p, snapshot, _) = try await saved("rollback-dispatch"), prepared = try prepare(p, snapshot)
            let before = try f.databaseImage(), probe = RevisionSQLProbe(.refuseCommit)
            revisionHooks(f.db, probe)
            defer { revisionHooks(f.db, nil) }
            try requireAnyRevisionError { _ = try mark(p, prepared) }
            let observed = probe.observation
            try check(observed.updates == 1 && observed.commitCalls == 1, "fault did not reach real UPDATE and COMMIT")
            try check(try f.databaseImage() == before, "failed COMMIT retained request or dispatch state")
        }
        await run("native_target_bounds_and_exact_utf8_order_match_closed_sdk") {
            let accepted = try revisionTarget(heads: (0..<64).map { String(format: "h%03d", $0) })
            try check(accepted.expectedHeads.count == 64, "boundary valid head count refused")
            _ = try revisionTarget(heads: [String(repeating: "x", count: 512)])
            _ = try revisionTarget(heads: ["e\u{301}", "\u{e9}"])
            for invalid in [[], ["b", "a"], ["a", "a"], [""], ["a\u{0}b"],
                            [String(repeating: "x", count: 513)], (0..<65).map { String(format: "h%03d", $0) }] {
                try rejects(AnnotationLocalEditorNativeAttemptError.invalidComparison) { _ = try revisionTarget(heads: invalid) }
            }
            try rejects(AnnotationLocalEditorNativeAttemptError.invalidComparison) { _ = try revisionTarget(objectID: "") }
            try rejects(AnnotationLocalEditorNativeAttemptError.invalidComparison) { _ = try revisionTarget(objectID: "x\u{0}y") }
        }
        await run("normal_actor_routes_prepare_and_one_dispatch_receipt") {
            let f = try LocalFixture(root: root, name: "actor"), session = try f.session()
            let saved = try await f.initialSave(session), protected = try RevisionProtectedState(f)
            guard case .prepared(let prepared) = try await session.prepareNativeRevision(
                snapshot: saved.snapshot, comparison: revisionComparison, target: revisionTarget()) else {
                throw LocalCheckFailure("unexpected lost ownership")
            }
            try check(session.ownsNativeRevisionPreparation(prepared), "normal actor lost owner")
            guard case .recorded(let observation) = try await session.markNativeRevisionMayHaveDispatched(
                prepared, requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest) else {
                throw LocalCheckFailure("normal actor did not report actual committed transition")
            }
            try check(observation.state == .dispatchMayHaveOccurred, "wrong actor transition")
            try protected.verify(f)
        }
        await run("actor_retirement_preserves_prepared_history_without_dispatch") {
            let f = try LocalFixture(root: root, name: "actor-retire"), session = try f.session()
            let saved = try await f.initialSave(session)
            guard case .prepared(let prepared) = try await session.prepareNativeRevision(
                snapshot: saved.snapshot, comparison: revisionComparison, target: revisionTarget()) else {
                throw LocalCheckFailure("unexpected lost ownership")
            }
            session.retire()
            let before = try f.databaseImage()
            try await rejectsAsync(AnnotationLocalEditorError.retired) {
                _ = try await session.markNativeRevisionMayHaveDispatched(
                    prepared, requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest)
            }
            try check(try f.databaseImage() == before, "retirement changed prepared history")
        }
        await run("retirement_after_actual_insert_cannot_relabel_committed_history") {
            let (f, p, snapshot, _) = try await saved("retire-after-insert")
            let protected = try RevisionProtectedState(f), probe = RevisionSQLProbe(retireOwner: p.owner)
            revisionHooks(f.db, probe)
            defer { revisionHooks(f.db, nil) }
            let prepared = try prepare(p, snapshot)
            try check(probe.retired.wait(timeout: .now() + 10) == .success, "concurrent retirement did not finish after protected commit")
            try check(probe.observation.inserts == 1 && probe.observation.commitCalls == 1, "actual insert/commit not observed")
            let committedRecord = try onlyRevision(f.db)
            try check(!p.ownsNativeRevisionPreparation(prepared) && committedRecord.state == "prepared", "retirement rewrote actual committed state")
            let before = try f.databaseImage()
            try rejects(AnnotationLocalEditorError.retired) { _ = try mark(p, prepared) }
            try check(try f.databaseImage() == before, "retired preparation dispatched")
            try protected.verify(f)
        }
    }
}

@MainActor
func writeRevisionCold(_ mode: String, root: URL) async throws {
    let name = mode == "cold-write" ? "cold-profile" : mode + "-profile"
    let f = try LocalFixture(root: root, name: name), session = try f.session()
    _ = try await f.initialSave(session)
    let p = try f.storage(), snapshot = try p.read()
    let fresh = try p.prepareNativeAttempt(snapshot: snapshot, comparison: revisionComparison)
    _ = try p.markNativeAttemptMayHaveDispatched(fresh)
    let protected = try RevisionProtectedState(f)
    let prepared = try p.prepareNativeRevision(snapshot: snapshot, comparison: revisionComparison, target: revisionTarget())
    let before = try onlyRevision(f.db)
    let journal = try f.db.fetch(query: "PRAGMA journal_mode=WAL;") { $0.string(at: 0) }
    try f.db.execute(query: "PRAGMA synchronous=FULL;")
    let sync = try f.scalar("PRAGMA synchronous;")
    try check(journal == ["wal"] && sync == 2, "actual crash fixture durability is not WAL/FULL")
    let expected: [String: Any] = [
        "mode": mode, "processID": Int(getpid()), "profilePath": f.url.path,
        "databasePath": f.url.appendingPathComponent("Annotations.sqlite").path,
        "annotationUUID": snapshot.annotationUUID.uuidString, "rowID": snapshot.annotation.id!,
        "sourceSHA256": snapshot.source.digest, "payloadSHA256": snapshot.version!.payloadDigest,
        "protectedBase64": protected.database.base64EncodedString(),
        "protectedSHA256": AnnotationExchangePlatformDigest().sha256(protected.database),
        "preparedRecord": try revisionObject(JSONEncoder().encode(before)),
        "requestBase64": revisionRequestBytes.base64EncodedString(), "requestSHA256": revisionRequestDigest,
        "freshAttemptUUID": fresh.observation.attemptID.uuidString, "journalMode": "wal", "synchronous": sync
    ]
    try revisionJSON(expected).write(to: root.appendingPathComponent(mode + "-expected.json"), options: .atomic)
    if mode == "cold-write" {
        try protected.verify(f)
        try revisionJSON(["mode": mode, "processID": Int(getpid()), "status": "PASS_PREPARED_COMMITTED"])
            .write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
        return
    }
    if mode == "crash-before" {
        let probe = RevisionSQLProbe(.crashBeforeCommit, marker: root.appendingPathComponent(mode + "-marker.json"))
        revisionHooks(f.db, probe)
        _ = try p.markNativeRevisionMayHaveDispatched(prepared,
            requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest)
        withExtendedLifetime(probe) {}
        throw LocalCheckFailure("crash hook did not execute")
    }
    _ = try p.markNativeRevisionMayHaveDispatched(prepared,
        requestBytes: revisionRequestBytes, requestSHA256: revisionRequestDigest)
    try protected.verify(f)
    try revisionJSON(["phase": "after_actual_sqlite_commit_return", "processID": Int(getpid()),
                      "state": try onlyRevision(f.db).state])
        .write(to: root.appendingPathComponent(mode + "-marker.json"), options: .atomic)
    _exit(73)
}

@MainActor
func reopenRevisionCold(_ mode: String, root: URL) async throws {
    let writer = mode == "cold-reopen" ? "cold-write" : mode.replacingOccurrences(of: "-reopen", with: "")
    let expected = try revisionObject(Data(contentsOf: root.appendingPathComponent(writer + "-expected.json")))
    guard let path = expected["profilePath"] as? String,
          let rowID = (expected["rowID"] as? NSNumber)?.int64Value,
          let firstPID = expected["processID"] as? Int else { throw LocalCheckFailure("missing cold identity") }
    try check(firstPID != Int(getpid()), "cold reopen reused writer process")
    let store = AnnotationStore.shared
    try store.setup(at: URL(fileURLWithPath: path, isDirectory: true))
    guard let annotation = try store.repository.loadAnnotationById(rowID), let db = store.repository.db else {
        throw LocalCheckFailure("original cold annotation missing")
    }
    let before = try revisionProtectedDatabase(db)
    let session = try store.makeLocalAnnotationEditor(annotation: annotation, supportedFormats: [fixtureFormat])
    let snapshot = try await session.read()
    try check(snapshot.annotationUUID.uuidString == expected["annotationUUID"] as? String &&
              snapshot.source.digest == expected["sourceSHA256"] as? String &&
              snapshot.version?.payloadDigest == expected["payloadSHA256"] as? String, "cold original source changed")
    let afterRead = try revisionProtectedDatabase(db)
    try check(before.base64EncodedString() == expected["protectedBase64"] as? String &&
              afterRead == before, "cold read rewrote original data")
    let actual = try onlyRevision(db)
    guard let oldObject = expected["preparedRecord"] as? [String: Any] else { throw LocalCheckFailure("missing prepared record") }
    let old = try JSONDecoder().decode(RevisionRecord.self, from: revisionJSON(oldObject))
    let shouldDispatch = writer == "crash-after"
    if shouldDispatch {
        try check(actual.state == "dispatch_may_have_occurred" &&
                  actual.requestBase64 == expected["requestBase64"] as? String &&
                  actual.requestSHA256 == expected["requestSHA256"] as? String, "committed request lost at crash")
        try check(actual.attempt == old.attempt && actual.imageBase64 == old.imageBase64 &&
                  actual.imageSHA256 == old.imageSHA256 && actual.targetBase64 == old.targetBase64 &&
                  actual.targetSHA256 == old.targetSHA256, "crash rewrote immutable image")
    } else {
        try check(actual == old, "uncommitted dispatch was retained or prepared image changed")
    }
    let storage = try AnnotationLocalEditorPersistence(connection: store.repository.captureLocalEditorConnection(),
        annotationID: rowID, annotationUUID: snapshot.annotationUUID, sessionID: UUID(), owner: .init(),
        formats: [fixtureFormat], digest: AnnotationExchangePlatformDigest())
    try check(try storage.nativeAttemptObservation()?.state == .dispatchMayHaveOccurred, "permanent fresh-import fence lost")
    let current = try storage.read()
    try rejects(AnnotationLocalEditorNativeAttemptError.dispatchMayHaveOccurred) {
        _ = try storage.prepareNativeAttempt(snapshot: current, comparison: revisionComparison)
    }
    try check(try revisionProtectedDatabase(db) == before, "cold discovery changed original state")
    try revisionJSON(["mode": mode, "status": "PASS_ORIGINAL_SQLITE_COLD_REOPEN",
        "processID": Int(getpid()), "writerProcessID": firstPID, "databasePath": expected["databasePath"]!,
        "revisionState": actual.state, "originalStateUnchanged": true, "freshImportFencePreserved": true,
        "nativeExecution": false]).write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
}

@main
struct NativeRevisionAcceptance {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 3 else { throw LocalCheckFailure("mode and owned fixture root required") }
            let mode = CommandLine.arguments[1], root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            switch mode {
            case "self-tests":
                let suite = NativeRevisionCases(root: root)
                await suite.execute()
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(suite.rows).write(to: root.appendingPathComponent("CASES.json"), options: .atomic)
                if suite.rows.contains(where: { $0.status != "PASS" }) { exit(1) }
            case "cold-write", "crash-before", "crash-after": try await writeRevisionCold(mode, root: root)
            case "cold-reopen", "crash-before-reopen", "crash-after-reopen": try await reopenRevisionCold(mode, root: root)
            default: throw LocalCheckFailure("unknown mode")
            }
        } catch {
            FileHandle.standardError.write(Data("NATIVE_REVISION_COMPONENT_FAILURE: \(error)\n".utf8))
            exit(1)
        }
    }
}
