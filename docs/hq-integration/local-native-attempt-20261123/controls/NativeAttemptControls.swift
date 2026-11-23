import Foundation
import Dispatch
import Glibc
import SQLite3
import OtzariaActionCore

// NEW component controls. Original SQLiteDatabase, complete local persistence,
// Session, ledger, version/source codec and lifetime methods execute unchanged.
// Explicit adapter rows/body/CloudKit boundary are defined in the support file;
// no opaque fixture body is claimed to be a valid original SDK/native archive.
struct NativeCaseResult: Codable {
    let name: String
    let status: String
    let assertions: Int
    let detail: String
}

@MainActor final class NativeAttemptControls {
    let root: URL
    var results: [NativeCaseResult] = []
    var assertions = 0
    init(root: URL) { self.root = root }

    func verify(_ value: Bool, _ message: String) throws {
        assertions += 1
        guard value else { throw CheckFailure(message) }
    }
    func refuse(_ message: String, expected: (any Error) -> Bool,
                _ body: () throws -> Void) throws {
        var actual: (any Error)?
        do { try body() } catch { actual = error }
        try verify(actual.map(expected) == true, message + "; actual=" + String(describing: actual))
    }
    func nativeRefusal(_ value: AnnotationLocalEditorNativeAttemptError,
                       _ body: () throws -> Void) throws {
        try refuse("expected native refusal \(value)", expected: { ($0 as? AnnotationLocalEditorNativeAttemptError) == value }, body)
    }
    func run(_ name: String, _ body: () async throws -> Void) async {
        let start = assertions
        do {
            try await body()
            results.append(.init(name: name, status: "PASS", assertions: assertions - start, detail: "actual original SQLite component"))
        } catch {
            results.append(.init(name: name, status: "FAIL", assertions: assertions - start, detail: String(describing: error)))
        }
        print("\(results.last!.status) \(name) assertions=\(assertions-start) \(results.last!.detail)")
    }
    func comparison(_ account: String = "actual-comparison-account", _ space: String = "actual-comparison-space") throws -> AnnotationLocalEditorNativeComparison {
        try .init(accountID: account, spaceID: space)
    }
    func advance(_ storage: AnnotationLocalEditorPersistence, text: String) throws -> AnnotationLocalEditorSnapshot {
        let snapshot = try storage.read()
        let intent = try storage.prepare(snapshot: snapshot, mutationID: UUID(),
            body: .init(format: NativeAttemptFixture.format, formatVersion: 1, bytes: NativeAttemptFixture.body),
            textPreview: text, editorRevision: "new-local-saved-revision")
        return try storage.commit(intent).snapshot
    }

    func runAll() async {
        await run("read_only_then_exact_saved_image_and_original_table_preservation") {
            let f = try NativeAttemptFixture(root: root, name: "freeze")
            let before = try f.originals()
            let schemaBefore = try f.scalar("PRAGMA main.schema_version;")
            try verify(try f.storage.nativeAttemptObservation() == nil, "read absent history")
            try verify(try f.scalar("PRAGMA main.schema_version;") == schemaBefore, "read cannot create schema")
            try verify(try f.scalar("SELECT COUNT(*) FROM main.sqlite_master WHERE name LIKE 'otzaria_local_editor_native_attempt%';") == 0, "no history objects after read")
            let snap = try f.storage.read()
            let prepared = try f.storage.prepareNativeAttempt(snapshot: snap, comparison: comparison())
            let image = try f.db.fetch(query: """
                SELECT source_canonical_base64,payload_base64,saved_revision,version_mutation_uuid,
                       prepared_session_uuid,native_account_id,native_space_id,body_byte_count,body_digest,
                       destinations_json,captured_database_url,annotation_id
                FROM main.otzaria_local_editor_native_attempts;
                """) { row in (0..<row.columnCount).map { row.string(at: $0)! } }
            try verify(image.count == 1, "one durable preparation")
            let row = image[0]
            try verify(Data(base64Encoded: row[0]) == snap.source.canonicalBytes, "whole actual source retained")
            try verify(Data(base64Encoded: row[1]) == snap.version!.payload, "whole payload/unknown metadata retained")
            try verify(row[2] == String(snap.revision) && row[3] == snap.version!.mutationID.uuidString, "full original version identity")
            try verify(row[4] == snap.sessionID.uuidString && prepared.snapshot.sessionID == snap.sessionID, "captured actual session")
            try verify(row[5].utf8.elementsEqual(prepared.comparison.accountID.utf8) && row[6].utf8.elementsEqual(prepared.comparison.spaceID.utf8), "exact comparison bytes")
            try verify(row[7] == String(NativeAttemptFixture.body.count) && row[8] == (try BudgetOpenSSLDigest().sha256(NativeAttemptFixture.body)), "complete unchanged opaque body hash")
            try verify(row[9] == "[]" && row[10] == f.path.absoluteString && row[11] == "1", "actual local destination/DB/row frozen")
            let document = try TorahAnnotationEnvelopeCodec.decode(Data(base64Encoded: row[1])!)
            guard case .supported(let env, let bytes) = document else { throw CheckFailure("saved fixture envelope unsupported") }
            try verify(env.richBody?.bytes == NativeAttemptFixture.body, "historical body bytes untouched")
            let unknown = try AnnotationEnvelopeJSONCodec.decodeObject(bytes)["futurePrivateMetadata"]?.object
            try verify(unknown?["counter"] == .unsigned(UInt64.max), "full-width future metadata preserved")
            let observation = try f.storage.nativeAttemptObservation()
            try verify(observation?.attemptID == prepared.observation.attemptID && observation?.state == .prepared, "actual committed history readback")
            try verify(try f.originals() == before, "preparation/read changed no original annotation/tags/pending/ledger rows")
        }
        await run("native_comparison_exact_utf8_no_invented_length_cap") {
            let composed = try comparison("\u{00e9}", "Space")
            let decomposed = try comparison("e\u{0301}", "Space")
            try verify("\u{00e9}" == "e\u{0301}" && composed != decomposed, "canonical Swift String equivalence cannot authorize exact identity")
            try verify(try comparison("Account", "Space") != comparison("account", "Space"), "case-sensitive comparison")
            try nativeRefusal(.invalidComparison) { _ = try comparison("", "Space") }
            try nativeRefusal(.invalidComparison) { _ = try comparison("Account", "Space\u{0}tail") }
            let f = try NativeAttemptFixture(root: root, name: "long-id")
            let long = try comparison(String(repeating: "a", count: 1024), String(repeating: "ש", count: 600))
            let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: long)
            try verify(p.comparison == long, "original SDK length policy retained")
            try verify(try f.scalar("SELECT length(CAST(native_account_id AS BLOB)) FROM otzaria_local_editor_native_attempts;") == 1024, "all account bytes actually stored")
            try verify(try f.scalar("SELECT length(CAST(native_space_id AS BLOB)) FROM otzaria_local_editor_native_attempts;") == 1200, "all Space UTF8 bytes actually stored")
        }
        await run("outer_transaction_only_all_three_transitions") {
            let f = try NativeAttemptFixture(root: root, name: "nested")
            let s = try f.storage.read(), c = try comparison()
            try f.db.transaction {
                try nativeRefusal(.nestedTransaction) { _ = try f.storage.prepareNativeAttempt(snapshot: s, comparison: c) }
            }
            try verify(try f.scalar("SELECT COUNT(*) FROM main.sqlite_master WHERE name LIKE 'otzaria_local_editor_native_attempt%';") == 0, "no nested preparation/schema escaped")
            let p = try f.storage.prepareNativeAttempt(snapshot: s, comparison: c)
            try f.db.transaction {
                try nativeRefusal(.nestedTransaction) { _ = try f.storage.markNativeAttemptMayHaveDispatched(p) }
                try nativeRefusal(.nestedTransaction) { _ = try f.storage.abandonPreparedNativeAttempt(p.observation, currentSnapshot: s) }
            }
            try verify(try f.storage.nativeAttemptObservation()?.state == .prepared, "nested transitions cannot manufacture durable fact")
        }
        await run("full_source_full_version_saved_revision_and_pending_delete_CAS") {
            let source = try NativeAttemptFixture(root: root, name: "stale-source")
            let s = try source.storage.read()
            try source.db.execute(query: "UPDATE annotations SET backendLocator = ? WHERE id=1;", parameters: ["different original source bytes"])
            try refuse("whole source mismatch before prepare", expected: { ($0 as? AnnotationExchangeError) == .staleSource }) {
                _ = try source.storage.prepareNativeAttempt(snapshot: s, comparison: comparison())
            }
            try verify(try source.scalar("SELECT COUNT(*) FROM main.sqlite_master WHERE name LIKE 'otzaria_local_editor_native_attempt%';") == 0, "stale preparation writes nothing")

            let version = try NativeAttemptFixture(root: root, name: "stale-version")
            let v = try version.storage.read()
            let p = try version.storage.prepareNativeAttempt(snapshot: v, comparison: comparison())
            var fields = try AnnotationEnvelopeJSONCodec.decodeObject(v.version!.payload)
            fields["newUnknownField"] = .string("actual changed saved bytes at unchanged revision")
            let bytes = try AnnotationExchangeValidation.canonical(.object(fields))
            try version.db.execute(query: "UPDATE otzaria_annotation_exchange_versions SET payload_base64=?,payload_digest=? WHERE mutation_id=?;",
                parameters: [bytes.base64EncodedString(), try BudgetOpenSSLDigest().sha256(bytes), v.version!.mutationID.uuidString])
            try refuse("full version mismatch before mark", expected: { ($0 as? AnnotationExchangeError) == .staleRevision }) {
                _ = try version.storage.markNativeAttemptMayHaveDispatched(p)
            }
            try verify(try version.storage.nativeAttemptObservation()?.state == .prepared, "stale saved image never marked")

            let revision = try NativeAttemptFixture(root: root, name: "stale-revision")
            let original = try revision.storage.read()
            let r = try revision.storage.prepareNativeAttempt(snapshot: original, comparison: comparison())
            let updated = try advance(revision.storage, text: "new actual saved note")
            try verify(updated.revision == original.revision + 1, "actual original save advances version")
            try refuse("new saved source/version cannot reuse old preparation", expected: {
                ($0 as? AnnotationExchangeError) == .staleSource || ($0 as? AnnotationExchangeError) == .staleRevision
            }) { _ = try revision.storage.markNativeAttemptMayHaveDispatched(r) }
            try nativeRefusal(.preparedAttemptExists) {
                _ = try revision.storage.prepareNativeAttempt(snapshot: updated, comparison: comparison("other", "other"))
            }

            let deletion = try NativeAttemptFixture(root: root, name: "pending-delete")
            let d = try deletion.storage.prepareNativeAttempt(snapshot: deletion.storage.read(), comparison: comparison())
            try deletion.pending.addPendingSync(ckRecordId: NativeAttemptFixture.uuid.uuidString, operation: "delete")
            try refuse("original pending delete blocks marking", expected: { ($0 as? AnnotationLocalEditorError) == .pendingDeletion }) {
                _ = try deletion.storage.markNativeAttemptMayHaveDispatched(d)
            }
            try verify(try deletion.storage.nativeAttemptObservation()?.state == .prepared, "delete cannot dispatch")
        }
        await run("prepared_abandon_is_explicit_same_DB_CAS_and_old_token_stays_dead") {
            let f = try NativeAttemptFixture(root: root, name: "abandon")
            let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison())
            let other = try NativeAttemptFixture.makeStorage(f.connection), s = try other.read()
            try nativeRefusal(.wrongPreparation) { _ = try other.markNativeAttemptMayHaveDispatched(p) }
            try nativeRefusal(.wrongPreparation) { _ = try other.abandonPreparedNativeAttempt(p.observation, currentSnapshot: s) }
            try nativeRefusal(.preparedAttemptExists) { _ = try other.prepareNativeAttempt(snapshot: s, comparison: comparison("other-account", "other-space")) }
            guard let observed = try other.nativeAttemptObservation() else { throw CheckFailure("new session must observe actual prepared history") }
            let abandoned = try other.abandonPreparedNativeAttempt(observed, currentSnapshot: s)
            try verify(abandoned.state == .abandonedBeforeDispatch && abandoned.attemptID == p.observation.attemptID, "actual explicit abandonment preserves original attempt")
            try nativeRefusal(.noPreparedAttempt) { _ = try f.storage.markNativeAttemptMayHaveDispatched(p) }
            let next = try other.prepareNativeAttempt(snapshot: s, comparison: comparison("other-account", "other-space"))
            try verify(next.observation.attemptID != p.observation.attemptID && next.observation.preparedSessionID == other.sessionID, "fresh preparation never adopts old caller/session")
            try nativeRefusal(.observationChanged) { _ = try f.storage.markNativeAttemptMayHaveDispatched(p) }
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 2, "immutable history retained")
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts WHERE dispatch_state='abandoned_before_dispatch';") == 1, "one abandoned history row")
        }
        await run("possible_dispatch_blocks_every_new_session_revision_and_tuple") {
            let f = try NativeAttemptFixture(root: root, name: "one-way")
            let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison())
            let originalRows = try f.originals()
            let mark = try f.storage.markNativeAttemptMayHaveDispatched(p)
            try verify(mark.state == .dispatchMayHaveOccurred && mark.attemptID == p.observation.attemptID, "one original outer COMMIT recorded possible dispatch")
            try nativeRefusal(.dispatchMayHaveOccurred) { _ = try f.storage.markNativeAttemptMayHaveDispatched(p) }
            try nativeRefusal(.dispatchMayHaveOccurred) { _ = try f.storage.abandonPreparedNativeAttempt(p.observation, currentSnapshot: p.snapshot) }
            try verify(try f.originals() == originalRows, "marker never modifies saved source/body/outbox/pending")

            f.storage.owner.retire()
            let fresh = try NativeAttemptFixture.makeStorage(f.connection)
            let newSnapshot = try advance(fresh, text: "different current saved revision after possible dispatch")
            try verify(newSnapshot.revision == p.snapshot.revision + 1, "actual new revision persisted")
            try nativeRefusal(.dispatchMayHaveOccurred) {
                _ = try fresh.prepareNativeAttempt(snapshot: newSnapshot, comparison: comparison("new-account", "new-space"))
            }
            let history = try fresh.nativeAttemptObservation()
            try verify(history?.savedRevision == p.snapshot.revision && history?.preparedSessionID == p.snapshot.sessionID, "history cannot follow the new caller/revision")
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 1, "new tuple never partitions same annotation active scope")
        }
        await run("real_original_DB_serialization_mark_vs_abandon_one_winner") {
            let f = try NativeAttemptFixture(root: root, name: "race")
            let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison())
            let other = try NativeAttemptFixture.makeStorage(f.connection)
            let s = try other.read(), observed = try other.nativeAttemptObservation()!
            let start = DispatchSemaphore(value: 0)
            let mark = Task.detached { () -> Bool in
                guard start.wait(timeout: .now() + 5) == .success else { return false }
                do { _ = try f.storage.markNativeAttemptMayHaveDispatched(p); return true } catch { return false }
            }
            let abandon = Task.detached { () -> Bool in
                guard start.wait(timeout: .now() + 5) == .success else { return false }
                do { _ = try other.abandonPreparedNativeAttempt(observed, currentSnapshot: s); return true } catch { return false }
            }
            start.signal(); start.signal()
            let marked = await mark.value, abandoned = await abandon.value
            try verify(marked != abandoned, "exactly one original SQLite CAS wins")
            let state = try f.db.fetch(query: "SELECT dispatch_state FROM otzaria_local_editor_native_attempts;") { $0.string(at: 0)! }
            try verify(state == [marked ? "dispatch_may_have_occurred" : "abandoned_before_dispatch"], "durable state matches real winning transition")
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 1, "race creates no duplicate history")
        }
        await run("real_COMMIT_veto_cancellation_and_success_receipt_boundary") {
            let veto = try NativeAttemptFixture(root: root, name: "commit-veto")
            let vp = try veto.storage.prepareNativeAttempt(snapshot: veto.storage.read(), comparison: comparison())
            sqlite3_commit_hook(veto.db.dbPointer, vetoActualCommit, nil)
            var refused = false
            do { _ = try veto.storage.markNativeAttemptMayHaveDispatched(vp) } catch { refused = true }
            sqlite3_commit_hook(veto.db.dbPointer, nil, nil)
            try verify(refused, "actual SQLite commit veto throws")
            try verify(try veto.storage.nativeAttemptObservation()?.state == .prepared, "failed COMMIT rolls marker back")

            let cancel = try NativeAttemptFixture(root: root, name: "update-cancel")
            let cp = try cancel.storage.prepareNativeAttempt(snapshot: cancel.storage.read(), comparison: comparison())
            sqlite3_update_hook(cancel.db.dbPointer, cancelCurrentTaskAtAttemptUpdate, nil)
            let cancelled = await Task.detached { () -> Bool in
                do { _ = try cancel.storage.markNativeAttemptMayHaveDispatched(cp); return false }
                catch { return error is CancellationError }
            }.value
            sqlite3_update_hook(cancel.db.dbPointer, nil, nil)
            try verify(cancelled, "actual original worker cancellation after UPDATE refuses before COMMIT")
            try verify(try cancel.storage.nativeAttemptObservation()?.state == .prepared, "cancelled transaction rolls marker back")

            let success = try NativeAttemptFixture(root: root, name: "commit-cancel")
            let sp = try success.storage.prepareNativeAttempt(snapshot: success.storage.read(), comparison: comparison())
            sqlite3_commit_hook(success.db.dbPointer, cancelCurrentTaskAtCommit, nil)
            let actual = try await Task.detached { () throws -> (AnnotationLocalEditorNativeAttemptObservation, Bool) in
                let receipt = try success.storage.markNativeAttemptMayHaveDispatched(sp)
                return (receipt, Task.isCancelled)
            }.value
            sqlite3_commit_hook(success.db.dbPointer, nil, nil)
            try verify(actual.1, "worker was really cancelled inside actual COMMIT")
            try verify(actual.0.state == .dispatchMayHaveOccurred, "successful COMMIT receipt survives subsequent cancellation")
            try verify(try success.storage.nativeAttemptObservation()?.state == .dispatchMayHaveOccurred, "postcommit receipt matches durable state")
        }
        await run("retired_owner_waiting_for_original_DB_lock_cannot_write") {
            let f = try NativeAttemptFixture(root: root, name: "retirement")
            let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison())
            let started = DispatchSemaphore(value: 0)
            let worker: Task<Bool, Never> = f.db.withSerializedAccess {
                let task = Task.detached { () -> Bool in
                    started.signal()
                    do { _ = try f.storage.markNativeAttemptMayHaveDispatched(p); return false }
                    catch { return (error as? AnnotationLocalEditorError) == .retired }
                }
                if started.wait(timeout: .now() + 5) != .success { return task }
                f.storage.owner.retire()
                return task
            }
            try verify(await worker.value, "retirement wins before lifetime admission under DB lock")
            let fresh = try NativeAttemptFixture.makeStorage(f.connection)
            try verify(try fresh.nativeAttemptObservation()?.state == .prepared, "no marker after retirement")
        }
        await run("exact_main_schema_temp_shadow_future_version_and_corrupt_identity_fail_closed") {
            let f = try NativeAttemptFixture(root: root, name: "schema")
            try f.db.execute(query: "CREATE TEMP TABLE otzaria_local_editor_native_attempts (x INTEGER);")
            try nativeRefusal(.schemaMismatch) { _ = try f.storage.nativeAttemptObservation() }
            try nativeRefusal(.schemaMismatch) { _ = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison()) }
            try verify(try f.scalar("SELECT COUNT(*) FROM main.sqlite_master WHERE name LIKE 'otzaria_local_editor_native_attempt%';") == 0, "temp shadow cannot cause main schema creation")
            try f.db.execute(query: "DROP TABLE temp.otzaria_local_editor_native_attempts;")
            _ = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison())
            try f.db.execute(query: "CREATE TRIGGER unexpected_native_control AFTER UPDATE ON otzaria_local_editor_native_attempts BEGIN SELECT 1; END;")
            try nativeRefusal(.schemaMismatch) { _ = try f.storage.nativeAttemptObservation() }
            try f.db.execute(query: "DROP TRIGGER unexpected_native_control;")
            try f.db.execute(query: "PRAGMA ignore_check_constraints = ON;")
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_attempt_schema SET version=2;")
            try nativeRefusal(.schemaMismatch) { _ = try f.storage.nativeAttemptObservation() }
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_attempt_schema SET version=1;")
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_attempts SET annotation_uuid=lower(annotation_uuid);")
            try nativeRefusal(.corruptRecord) { _ = try f.storage.nativeAttemptObservation() }
            try nativeRefusal(.corruptRecord) { _ = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(), comparison: comparison("new", "new")) }
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 1, "noncanonical UUID cannot hide active history")
            try f.db.execute(query: "UPDATE otzaria_local_editor_native_attempts SET annotation_uuid=upper(annotation_uuid),dispatch_state='future_unknown_state';")
            try nativeRefusal(.corruptRecord) { _ = try f.storage.nativeAttemptObservation() }
            try verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 1, "unknown state remains blocking evidence")
        }
        await run("actual_Session_wrappers_no_publication_callbacks_for_bookkeeping") {
            let f = try NativeAttemptFixture(root: root, name: "session")
            let store = AnnotationStore(connection: f.connection)
            let initial = try f.storage.read()
            let session = try store.makeLocalAnnotationEditor(annotation: initial.annotation,
                supportedFormats: [try .init(identifier: NativeAttemptFixture.format, version: 1)])
            let snap = try await session.read()
            let cloudBefore = CloudKitSyncManager.shared.count, rowsBefore = try f.originals()
            try verify(try await session.nativeAttemptObservation() == nil, "actual Session read")
            guard case .prepared(let p) = try await session.prepareNativeAttempt(snapshot: snap, comparison: comparison()) else {
                throw CheckFailure("current actual Session must receive preparation")
            }
            guard case .recorded(let receipt) = try await session.markNativeAttemptMayHaveDispatched(p) else {
                throw CheckFailure("current actual Session must receive committed marker")
            }
            try verify(receipt.state == .dispatchMayHaveOccurred, "actual Session marker committed")
            try verify(store.invalidations == 0 && store.events.count == 0 && CloudKitSyncManager.shared.count == cloudBefore, "bookkeeping invokes no save/CloudKit/cache callbacks")
            try verify(try f.originals() == rowsBefore, "Session bookkeeping preserves all original rows")
            session.retire()
            var retired = false
            do { _ = try await session.nativeAttemptObservation() } catch { retired = (error as? AnnotationLocalEditorError) == .retired }
            try verify(retired, "retired Session cannot reacquire observation authority")
        }
    }

    func write(_ path: URL) throws {
        struct Report: Codable {
            let scope: String
            let nativeInvocationCount: Int
            let testsReplayed: Int
            let cases: [NativeCaseResult]
            let assertions: Int
            let pass: Int
            let fail: Int
        }
        let report = Report(scope: "NEW real original SQLite/version/lifetime/persistence/Session component controls with explicit Linux/application adapters; no Apple UI or SDK/native archive/import qualification",
            nativeInvocationCount: 0, testsReplayed: 0, cases: results, assertions: assertions,
            pass: results.filter { $0.status == "PASS" }.count, fail: results.filter { $0.status == "FAIL" }.count)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: path)
    }
}

@main struct NativeAttemptControlMain {
    @MainActor static func main() async {
        do {
            let args = CommandLine.arguments
            guard args.count == 3 else { throw CheckFailure("mode plus owned output required") }
            let root = URL(fileURLWithPath: args[2], isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if args[1] == "crash-after-marker" {
                let f = try NativeAttemptFixture(root: root, name: "durable-process")
                let p = try f.storage.prepareNativeAttempt(snapshot: f.storage.read(),
                    comparison: .init(accountID: "before-crash", spaceID: "before-crash"))
                let receipt = try f.storage.markNativeAttemptMayHaveDispatched(p)
                let data = try JSONSerialization.data(withJSONObject: [
                    "attemptID":receipt.attemptID.uuidString, "state":receipt.state.rawValue,
                    "savedRevision":receipt.savedRevision, "pid":getpid(), "exitImmediatelyAfterActualCommit":true
                ], options: [.sortedKeys])
                try data.write(to: root.appendingPathComponent("CRASH_RECEIPT.json"))
                _exit(73)
            }
            let suite = NativeAttemptControls(root: root)
            if args[1] == "verify-reopen" {
                await suite.run("separate_process_reopen_does_not_clear_possible_dispatch") {
                    let prior = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("CRASH_RECEIPT.json"))) as! [String: Any]
                    let f = try NativeAttemptFixture(root: root, name: "durable-process", create: false)
                    let actual = try f.storage.nativeAttemptObservation()
                    try suite.verify(actual?.state == .dispatchMayHaveOccurred && actual?.attemptID.uuidString == prior["attemptID"] as? String, "durable exact pre-crash attempt read by new process")
                    try suite.verify((prior["pid"] as? Int) != Int(getpid()), "genuine distinct process")
                    let current = try suite.advance(f.storage, text: "actual newer saved revision after process restart")
                    try suite.nativeRefusal(.dispatchMayHaveOccurred) {
                        _ = try f.storage.prepareNativeAttempt(snapshot: current, comparison: .init(accountID: "after-crash", spaceID: "different-space"))
                    }
                    try suite.verify(try f.scalar("SELECT COUNT(*) FROM otzaria_local_editor_native_attempts;") == 1, "one active attempt survives process/revision/tuple change")
                }
                try suite.write(root.appendingPathComponent("REOPEN_RESULT.json"))
            } else if args[1] == "component" {
                await suite.runAll()
                try suite.write(root.appendingPathComponent("RESULT.json"))
            } else { throw CheckFailure("unknown mode") }
            if suite.results.contains(where: { $0.status != "PASS" }) { exit(1) }
        } catch {
            print("CONTROL_FATAL \(error)")
            exit(2)
        }
    }
}
