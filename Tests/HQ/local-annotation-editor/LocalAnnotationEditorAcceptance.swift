import Foundation
import Combine
import SQLite3
import Synchronization
import OtzariaActionCore

struct LocalCheckFailure: Error, CustomStringConvertible, Sendable {
    let description: String
    init(_ description: String) { self.description = description }
}
func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw LocalCheckFailure(message) }
}
func rejects<E: Error & Equatable>(_ expected: E, _ work: () throws -> Void) throws {
    do { try work() } catch let error as E { try check(error == expected, "expected \(expected), got \(error)"); return }
    throw LocalCheckFailure("expected \(expected), accepted")
}
@MainActor
func rejectsAsync<E: Error & Equatable>(_ expected: E, _ work: @MainActor () async throws -> Void) async throws {
    do { try await work() } catch let error as E { try check(error == expected, "expected \(expected), got \(error)"); return }
    throw LocalCheckFailure("expected \(expected), accepted")
}
let fixtureFormat = try! AnnotationLocalEditorBodyFormat(identifier: "org.otzaria.acceptance.two-blocks", version: 1)
func fixtureBody(_ suffix: String = "one") -> TorahAnnotationEnvelope.RichBody {
    // Opaque fixture bytes only: not claimed to be Anytype serialization.
    let bytes = Data("{\"blocks\":[{\"id\":\"b1\",\"text\":\"שלום \(suffix)\"},{\"id\":\"b2\",\"text\":\"שני\"}]}".utf8)
    return .init(format: fixtureFormat.identifier, formatVersion: 1, bytes: bytes)
}

@MainActor
struct LocalFixture {
    let url: URL
    let annotation: Annotation
    let db: SQLiteDatabase
    let store = AnnotationStore.shared
    var repository: AnnotationRepository { store.repository }
    var uuid: UUID { UUID(uuidString: annotation.ckRecordId!)! }
    var ledger: AnnotationExchangeLedger { .init(database: db, digest: AnnotationExchangePlatformDigest()) }

    init(root: URL, name: String) throws {
        url = root.appendingPathComponent(name, isDirectory: true)
        AnnotationStore.shared.disconnect()
        try AnnotationStore.shared.setup(at: url)
        let row = Annotation(id: nil, bkId: 28, contentId: 2, range: NSRange(location: 4, length: 5),
            rangeDiacritics: NSRange(location: 6, length: 7), colorHex: "#123456", type: .underline,
            note: "original plain note", createdAt: 1_700_000_001, context: "original context שָׁלוֹם",
            page: 9, part: 1, tags: ["עיון", "second"], ckRecordId: UUID().uuidString,
            lastModified: nil, backendLocator: .init(backend: .fixture, workKey: "fixture:28:2"))
        let id = try AnnotationStore.shared.addAnnotation(row)
        guard let saved = try AnnotationRepository.shared.loadAnnotationById(id), let database = AnnotationRepository.shared.db else {
            throw LocalCheckFailure("original setup/add/load failed")
        }
        annotation = saved; db = database
        try AnnotationRepository.shared.addPendingSync(ckRecordId: "unrelated-delete", operation: "delete")
        CloudKitSyncManager.shared.resetObservation()
    }
    func session(formats: Set<AnnotationLocalEditorBodyFormat> = [fixtureFormat]) throws -> AnnotationLocalEditorSession {
        try store.makeLocalAnnotationEditor(annotation: annotation, supportedFormats: formats)
    }
    func storage(owner: AnnotationLocalEditorLifetime = .init()) throws -> AnnotationLocalEditorPersistence {
        try .init(connection: repository.captureLocalEditorConnection(), annotationID: annotation.id!, annotationUUID: uuid,
            sessionID: UUID(), owner: owner, formats: [fixtureFormat], digest: AnnotationExchangePlatformDigest())
    }
    func scalar(_ query: String, _ parameters: [Any] = []) throws -> Int64 {
        try db.fetch(query: query, parameters: parameters) { $0.int64(at: 0) }.first ?? -1
    }
    func rows() throws -> Data {
        try ledger.captureSource(annotationUUID: uuid).canonicalBytes
    }
    /// Snapshot the actual SQLite image, including rows, tags, ledger and queues.
    func databaseImage() throws -> Data {
        try db.withSerializedAccess {
            var count: sqlite3_int64 = 0
            guard let bytes = sqlite3_serialize(db.dbPointer, "main", &count, 0),
                  count > 0, count <= Int.max else {
                throw LocalCheckFailure("SQLite image unavailable")
            }
            defer { sqlite3_free(bytes) }
            return Data(bytes: bytes, count: Int(count))
        }
    }
    func refusePlainWrite<E: Error & Equatable>(_ expected: E) throws {
        let before = try databaseImage()
        let cloud = CloudKitSyncManager.shared.observation
        var edited = annotation
        edited.note = "stale plain replacement"
        edited.colorHex = "#ffffff"
        edited.tags = ["stale replacement tag"]
        try rejects(expected) { try store.updateAnnotation(edited) }
        try check(try databaseImage() == before, "refused plain Save changed SQLite bytes")
        let after = CloudKitSyncManager.shared.observation
        try check(after.uploads == cloud.uploads && after.trackPending == cloud.trackPending &&
                  after.deletes == cloud.deletes, "refused plain Save published a CloudKit callback")
    }
    func intent(_ session: AnnotationLocalEditorSession, snapshot: AnnotationLocalEditorSnapshot,
                mutation: UUID = UUID(), suffix: String = "one", preview: String = "תצוגה פשוטה") throws -> AnnotationLocalEditorIntent {
        try session.prepareSave(snapshot: snapshot, mutationID: mutation, body: fixtureBody(suffix),
                                textPreview: preview, editorRevision: "fixture-revision-\(suffix)")
    }
    func save(_ session: AnnotationLocalEditorSession, _ intent: AnnotationLocalEditorIntent) async throws -> AnnotationLocalEditorCommitted {
        guard case .committed(let saved) = try await session.save(intent) else { throw LocalCheckFailure("lost expected ownership") }
        return saved
    }
    func initialSave(_ session: AnnotationLocalEditorSession) async throws -> AnnotationLocalEditorCommitted {
        let snapshot = try await session.read()
        return try await save(session, intent(session, snapshot: snapshot))
    }
    func replacePayload(_ saved: AnnotationLocalEditorCommitted, mutate: (inout ActionObject) throws -> Void) throws -> Data {
        var fields = try ActionWireCodec.decodeObject(saved.snapshot.version!.payload)
        try mutate(&fields)
        let bytes = try AnnotationExchangeValidation.canonical(.object(fields))
        let hash = AnnotationExchangePlatformDigest().sha256(bytes)
        try db.execute(query: "UPDATE otzaria_annotation_exchange_versions SET payload_base64=?, payload_digest=? WHERE mutation_id=?;",
                       parameters: [bytes.base64EncodedString(), hash, saved.receipt.mutationID.uuidString])
        return bytes
    }
}

// The actual original SQLite driver calls this synchronous function inside the
// real transaction. No asynchronous waiting or repository state lock is added.
func retireLocalEditorDuringSQL(_ context: OpaquePointer?, _ count: Int32,
                               _ values: UnsafeMutablePointer<OpaquePointer?>?) {
    if let context, let pointer = sqlite3_user_data(context) {
        Unmanaged<AnnotationLocalEditorLifetime>.fromOpaque(pointer).takeUnretainedValue().retire()
    }
    sqlite3_result_int(context, 1)
}

// Fault injection belongs only to this owned fixture connection. The actual
// SQLite update hook proves the preview write ran before its version INSERT
// is denied; the original driver must roll the complete transaction back.
final class LocalSQLiteWriteFailureProbe: Sendable {
    struct Observation: Sendable {
        var previewUpdates = 0
        var deniedVersionInserts = 0
    }
    private let state = Mutex(Observation())
    var observation: Observation { state.withLock { $0 } }
    func recordPreview() { state.withLock { $0.previewUpdates += 1 } }
    func recordRefusal() { state.withLock { $0.deniedVersionInserts += 1 } }
}

func observeLocalPreviewWrite(_ context: UnsafeMutableRawPointer?, _ operation: Int32,
                              _ database: UnsafePointer<CChar>?, _ table: UnsafePointer<CChar>?,
                              _ rowID: sqlite3_int64) {
    guard let context, operation == SQLITE_UPDATE, let database, let table,
          String(cString: database) == "main", String(cString: table) == "annotations" else { return }
    Unmanaged<LocalSQLiteWriteFailureProbe>.fromOpaque(context).takeUnretainedValue().recordPreview()
}

func refuseLocalVersionInsert(_ context: UnsafeMutableRawPointer?, _ operation: Int32,
                              _ table: UnsafePointer<CChar>?, _ column: UnsafePointer<CChar>?,
                              _ database: UnsafePointer<CChar>?, _ trigger: UnsafePointer<CChar>?) -> Int32 {
    guard let context, operation == SQLITE_INSERT, let database, let table,
          String(cString: database) == "main",
          String(cString: table) == "otzaria_annotation_exchange_versions" else { return SQLITE_OK }
    Unmanaged<LocalSQLiteWriteFailureProbe>.fromOpaque(context).takeUnretainedValue().recordRefusal()
    return SQLITE_DENY
}

@MainActor
final class LocalCases {
    struct Row: Codable { let name: String; let status: String; let error: String? }
    let root: URL
    var rows: [Row] = []
    init(root: URL) { self.root = root }
    func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do { try await body(); rows.append(.init(name: name, status: "PASS", error: nil)); print("PASS \(name)") }
        catch { rows.append(.init(name: name, status: "FAIL", error: String(describing: error))); print("FAIL \(name): \(error)") }
    }
    func fixture(_ name: String) throws -> LocalFixture { try .init(root: root, name: name) }

    func execute() async {
        await run("legacy_read_has_no_schema_or_original_mutation") {
            let f = try fixture("legacy"); let before = try f.rows(); let s = try f.session(); let value = try await s.read()
            try check(value.revision == 0 && value.document == nil, "legacy body")
            try check(try f.rows() == before, "read changed original row")
            try check(try !f.ledger.hasInstalledSchema(), "read installed schema")
        }
        await run("same_uuid_atomic_two_block_body_and_plain_preview") {
            let f = try fixture("body"); let s = try f.session(); let saved = try await f.initialSave(s)
            try check(saved.receipt.annotationUUID == f.uuid && saved.receipt.revision == 1, "identity/revision")
            guard case .supported(let body, _)? = saved.snapshot.document else { throw LocalCheckFailure("body missing") }
            try check(body.richBody?.bytes == fixtureBody().bytes, "opaque blocks changed")
            try check(try f.repository.loadAnnotationById(f.annotation.id!)?.note == "תצוגה פשוטה", "preview not original note")
        }
        await run("all_original_metadata_tags_and_uuid_preserved") {
            let f = try fixture("metadata"); let s = try f.session(); let saved = try await f.initialSave(s)
            var expected = f.annotation; expected.note = saved.snapshot.annotation.note; expected.lastModified = saved.snapshot.annotation.lastModified
            try check(saved.snapshot.annotation == expected, "original metadata drift")
        }
        await run("original_queue_upload_delete_preserved_and_no_exchange_destination") {
            let f = try fixture("queue"); let s = try f.session(); let saved = try await f.initialSave(s)
            try check(saved.receipt.deliveries.isEmpty && !AnnotationExchangeCapability.liveExchangeEnabled, "live exchange enabled")
            try check(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") == 0, "outbox generated")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload';", [f.annotation.ckRecordId!]) == 1, "original upload absent")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete';") == 1, "unrelated delete changed")
        }
        await run("original_store_cache_reads_committed_preview") {
            let f = try fixture("cache"); _ = f.store.loadAnnotations(bkId: 28, contentId: 2)
            let s = try f.session(); _ = try await f.initialSave(s)
            try check(f.store.loadAnnotations(bkId: 28, contentId: 2).first?.note == "תצוגה פשוטה", "stale original cache")
        }
        await run("original_cloudkit_boundary_receives_plain_record_once_without_requeue") {
            let f = try fixture("cloud"); let s = try f.session(); let saved = try await f.initialSave(s)
            let observation = CloudKitSyncManager.shared.observation
            try check(observation.uploads == [saved.snapshot.annotation] && observation.trackPending == [false], "publication drift")
        }
        await run("exact_retry_returns_same_version_without_duplicate_publication") {
            let f = try fixture("retry"); let s = try f.session(); let initial = try await s.read(); let intent = try f.intent(s, snapshot: initial)
            let first = try await f.save(s, intent); let original = try f.rows(); let second = try await f.save(s, intent)
            try check(second.receipt.replayed && first.receipt.mutationID == second.receipt.mutationID, "not replayed")
            try check(try f.rows() == original && f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1, "retry changed data")
            try check(CloudKitSyncManager.shared.observation.uploads.count == 1, "retry published twice")
        }
        await run("same_mutation_different_body_is_conflict") {
            let f = try fixture("conflict"); let s = try f.session(); let initial = try await s.read(); let first = try f.intent(s, snapshot: initial)
            _ = try await f.save(s, first)
            let other = try f.intent(s, snapshot: initial, mutation: first.mutationID, suffix: "different")
            try await rejectsAsync(AnnotationExchangeError.idempotencyConflict) { _ = try await s.save(other) }
        }
        await run("new_revision_preserves_immutable_previous_bytes") {
            let f = try fixture("revision"); let s = try f.session(); let first = try await f.initialSave(s)
            let second = try await f.save(s, f.intent(s, snapshot: first.snapshot, suffix: "two"))
            try check(second.receipt.revision == 2, "revision did not advance")
            try check(try f.ledger.version(mutationID: first.receipt.mutationID)?.payload == first.snapshot.version?.payload, "history rewritten")
        }
        await run("second_session_stale_revision_cannot_overwrite") {
            let f = try fixture("stale"); let a = try f.session(), b = try f.session(); let old = try await b.read()
            let intent = try f.intent(b, snapshot: old); _ = try await f.initialSave(a)
            try await rejectsAsync(AnnotationExchangeError.staleSource) { _ = try await b.save(intent) }
        }
        await run("normal_save_invalidates_old_rich_intent_without_altering_normal_path") {
            let f = try fixture("normal"); let s = try f.session(); let old = try await s.read(); let intent = try f.intent(s, snapshot: old)
            var changed = f.annotation; changed.note = "normal original Save"; try f.store.updateAnnotation(changed)
            try await rejectsAsync(AnnotationExchangeError.staleSource) { _ = try await s.save(intent) }
        }
        await run("original_tag_change_invalidates_source_witness") {
            let f = try fixture("tags"); let s = try f.session(); let old = try await s.read(); let intent = try f.intent(s, snapshot: old)
            try f.store.addTags(["changed"], toAnnotationIDs: [f.annotation.id!])
            try await rejectsAsync(AnnotationExchangeError.staleSource) { _ = try await s.save(intent) }
        }
        await run("changed_original_row_is_rejected_by_post_worker_read_publication") {
            let f = try fixture("read-publication-source"); let storage = try f.storage(); let old = try storage.read()
            var edited = f.annotation; edited.note = "actual original Save after snapshot"; try f.store.updateAnnotation(edited)
            try rejects(AnnotationExchangeError.staleSource) { try storage.requireUnchanged(old) }
        }
        await run("changed_version_is_rejected_by_post_worker_read_publication") {
            let f = try fixture("read-publication-version"); let storage = try f.storage(); let old = try storage.read()
            let intent = try storage.prepare(snapshot: old, mutationID: UUID(), body: fixtureBody(), textPreview: "preview", editorRevision: nil)
            let saved = try storage.commit(intent)
            _ = try f.replacePayload(saved) { $0["futureMetadata"] = .string("retained newer bytes") }
            try check(try f.rows() == saved.snapshot.source.canonicalBytes, "test unexpectedly changed original row")
            try rejects(AnnotationExchangeError.staleRevision) { try storage.requireUnchanged(saved.snapshot) }
        }
        await run("pending_original_delete_cannot_be_resurrected") {
            let f = try fixture("delete-wins"); let s = try f.session(); let old = try await s.read(); let intent = try f.intent(s, snapshot: old)
            try f.repository.addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "delete")
            try await rejectsAsync(AnnotationLocalEditorError.pendingDeletion) { _ = try await s.save(intent) }
            try check(try f.rows() == old.source.canonicalBytes && !f.ledger.hasInstalledSchema(), "rejected write changed data/schema")
        }
        await run("missing_original_annotation_is_not_recreated") {
            let f = try fixture("missing"); let s = try f.session(); try f.store.deleteAnnotation(id: f.annotation.id!)
            try await rejectsAsync(AnnotationLocalEditorError.missingAnnotation) { _ = try await s.read() }
        }
        await run("ambiguous_uuid_is_never_selected_by_first_match") {
            let f = try fixture("ambiguous"); var duplicate = f.annotation; duplicate.id = nil; _ = try f.repository.addAnnotation(duplicate)
            let s = try f.session()
            try await rejectsAsync(AnnotationExchangeError.ambiguousSource) { _ = try await s.read() }
        }
        await run("profile_switch_and_return_never_revives_old_owner") {
            let f = try fixture("profile-a"); let s = try f.session(); let old = try await s.read(); let intent = try f.intent(s, snapshot: old)
            _ = try fixture("profile-b"); try f.store.setup(at: f.url)
            try await rejectsAsync(AnnotationLocalEditorError.retired) { _ = try await s.save(intent) }
            try check(try f.rows() == old.source.canonicalBytes, "old profile written")
        }
        await run("disconnect_reconnect_same_file_requires_fresh_session") {
            let f = try fixture("reconnect"); let s = try f.session(); f.store.disconnect(); f.store.connect()
            try await rejectsAsync(AnnotationLocalEditorError.retired) { _ = try await s.read() }
            let fresh = try f.session(); let value = try await fresh.read(); try check(value.annotationUUID == f.uuid, "fresh owner missing")
        }
        await run("retire_before_save_has_no_schema_or_write") {
            let f = try fixture("retire"); let s = try f.session(); let old = try await s.read(); let intent = try f.intent(s, snapshot: old)
            s.retire()
            try await rejectsAsync(AnnotationLocalEditorError.retired) { _ = try await s.save(intent) }
            try check(try f.rows() == old.source.canonicalBytes && !f.ledger.hasInstalledSchema(), "retired write admitted")
        }
        await run("read_and_cancel_does_not_save_or_backfill") {
            let f = try fixture("cancel"); let before = try f.rows(); let s = try f.session(); _ = try await s.read(); s.retire()
            try check(try f.rows() == before && !f.ledger.hasInstalledSchema(), "cancel changed saved annotation")
        }
        await run("foreign_session_snapshot_is_denied") {
            let f = try fixture("foreign-owner"); let a = try f.session(), b = try f.session(); let snapshot = try await a.read()
            try rejects(AnnotationLocalEditorError.wrongOwner) { _ = try f.intent(b, snapshot: snapshot) }
        }
        await run("unsupported_body_format_is_readable_but_never_overwritten") {
            let f = try fixture("unknown-body"); let s = try f.session(); let saved = try await f.initialSave(s)
            let raw = try f.replacePayload(saved) { fields in var body = fields["richBody"]!.object!; body["formatVersion"] = .integer(99); fields["richBody"] = .object(body) }
            let value = try await s.read(); try check(value.document?.originalBytes == raw, "unknown bytes lost")
            try rejects(AnnotationLocalEditorError.unsupportedBody) { _ = try f.intent(s, snapshot: value) }
            try f.refusePlainWrite(AnnotationPlainWriteError.requiresExpandedEditor)
        }
        await run("future_envelope_is_retained_and_read_only") {
            let f = try fixture("future-envelope"); let s = try f.session(); let saved = try await f.initialSave(s)
            let raw = try f.replacePayload(saved) { $0["schemaVersion"] = .integer(2) }
            let value = try await s.read(); try check(value.document?.originalBytes == raw, "future envelope lost")
            try rejects(AnnotationLocalEditorError.unsupportedEnvelope) { _ = try f.intent(s, snapshot: value) }
            try f.refusePlainWrite(AnnotationPlainWriteError.unavailable)
        }
        await run("unknown_envelope_and_rich_metadata_survive_supported_edit") {
            let f = try fixture("unknown-metadata"); let s = try f.session(); let saved = try await f.initialSave(s)
            _ = try f.replacePayload(saved) { fields in
                fields["futureMetadata"] = .object(["preserve": .unsigned(UInt64.max)])
                var body = fields["richBody"]!.object!; body["futureStyle"] = .string("opaque"); fields["richBody"] = .object(body)
            }
            let value = try await s.read(); let next = try await f.save(s, f.intent(s, snapshot: value, suffix: "next"))
            let fields = try ActionWireCodec.decodeObject(next.snapshot.version!.payload)
            try check(fields["futureMetadata"]?.object?["preserve"] == .unsigned(UInt64.max), "unknown metadata removed")
            try check(fields["richBody"]?.object?["futureStyle"] == .string("opaque"), "rich metadata removed")
        }
        await run("altered_snapshot_document_cannot_remove_preserved_unknown_fields") {
            let f = try fixture("forged-document"); let s = try f.session(); let saved = try await f.initialSave(s)
            _ = try f.replacePayload(saved) { $0["futureMetadata"] = .string("must stay") }
            let current = try await s.read()
            var fields = try ActionWireCodec.decodeObject(current.version!.payload)
            fields.removeValue(forKey: "futureMetadata")
            let changed = try AnnotationExchangeValidation.canonical(.object(fields))
            let forged = AnnotationLocalEditorSnapshot(annotation: current.annotation, annotationUUID: current.annotationUUID,
                databaseURL: current.databaseURL, revision: current.revision,
                document: try TorahAnnotationEnvelopeCodec.decode(changed), source: current.source,
                version: current.version, sessionID: current.sessionID)
            try rejects(AnnotationLocalEditorError.invalidIntent) { _ = try f.intent(s, snapshot: forged) }
            try check(try f.ledger.currentVersion(namespace: AnnotationLocalEditorPersistence.namespace,
                annotationUUID: f.uuid)?.payload == current.version?.payload, "forged document changed stored bytes")
        }
        await run("unknown_local_commit_marker_is_not_reinterpreted") {
            let f = try fixture("unknown-marker"); let s = try f.session(); let saved = try await f.initialSave(s)
            _ = try f.replacePayload(saved) { $0["otzariaLocalBodyCommit"] = .object(["schemaVersion": .integer(2)]) }
            let value = try await s.read()
            try rejects(AnnotationLocalEditorError.unsupportedEnvelope) { _ = try f.intent(s, snapshot: value) }
        }
        await run("future_database_schema_is_not_migrated_by_read") {
            let f = try fixture("future-schema")
            try f.ledger.installSchema()
            try f.db.execute(query: "PRAGMA ignore_check_constraints=ON;")
            try f.db.execute(query: "UPDATE otzaria_annotation_exchange_schema SET version=3;")
            try f.db.execute(query: "PRAGMA ignore_check_constraints=OFF;")
            let s = try f.session(); try await rejectsAsync(AnnotationExchangeError.schemaMismatch) { _ = try await s.read() }
            try check(try f.scalar("SELECT version FROM otzaria_annotation_exchange_schema;") == 3, "future schema changed")
            try f.refusePlainWrite(AnnotationExchangeError.schemaMismatch)
        }
        await run("partial_schema_is_not_repaired_by_read") {
            let f = try fixture("partial-schema"); try f.db.execute(query: "CREATE TABLE otzaria_annotation_exchange_heads(opaque TEXT);")
            let s = try f.session(); try await rejectsAsync(AnnotationExchangeError.schemaMismatch) { _ = try await s.read() }
            try check(try f.scalar("SELECT COUNT(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange_%';") == 1, "partial schema repaired")
            try f.refusePlainWrite(AnnotationExchangeError.schemaMismatch)
        }
        await run("corrupt_body_digest_is_rejected") {
            let f = try fixture("digest"); let s = try f.session(); _ = try await f.initialSave(s)
            try f.db.execute(query: "UPDATE otzaria_annotation_exchange_versions SET payload_digest=?;", parameters: [String(repeating: "0", count: 64)])
            try await rejectsAsync(AnnotationExchangeError.corruptRecord) { _ = try await s.read() }
            try f.refusePlainWrite(AnnotationExchangeError.corruptRecord)
        }
        await run("payload_bound_refusal_preserves_preview_schema_and_queue") {
            let f = try fixture("large"); let s = try f.session(); let old = try await s.read()
            let before = try f.databaseImage()
            let body = TorahAnnotationEnvelope.RichBody(format: fixtureFormat.identifier, formatVersion: 1,
                bytes: Data(repeating: 1, count: TorahAnnotationPayloadLimits.maximumBodyBytes + 1))
            try rejects(AnnotationLocalEditorError.unsupportedBody) {
                _ = try s.prepareSave(snapshot: old, mutationID: UUID(), body: body, textPreview: "changed", editorRevision: nil)
            }
            try check(try f.databaseImage() == before && f.rows() == old.source.canonicalBytes &&
                      !f.ledger.hasInstalledSchema(), "oversized body changed original storage")
            try check(CloudKitSyncManager.shared.observation.uploads.isEmpty, "oversized body published")
        }
        await run("sqlite_failure_after_preview_rolls_back_entire_commit") {
            let f = try fixture("rollback"); try f.ledger.installSchema(); let s = try f.session(); let old = try await s.read()
            let before = try f.databaseImage()
            let fault = LocalSQLiteWriteFailureProbe()
            let pointer = Unmanaged.passUnretained(fault).toOpaque()
            try check(sqlite3_set_authorizer(f.db.dbPointer, refuseLocalVersionInsert, pointer) == SQLITE_OK,
                      "owned SQLite authorizer registration")
            let priorObserver = sqlite3_update_hook(f.db.dbPointer, observeLocalPreviewWrite, pointer)
            defer {
                sqlite3_set_authorizer(f.db.dbPointer, nil, nil)
                sqlite3_update_hook(f.db.dbPointer, nil, nil)
            }
            try check(priorObserver == nil, "fixture already has an update observer")
            do { _ = try await s.save(f.intent(s, snapshot: old)); throw LocalCheckFailure("expected SQLite failure") } catch is SQLiteError {}
            try check(fault.observation.previewUpdates == 1 && fault.observation.deniedVersionInserts == 1,
                      "failure did not follow the actual original preview UPDATE")
            try check(try f.databaseImage() == before && f.rows() == old.source.canonicalBytes, "preview escaped rollback")
            try check(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 0, "version escaped rollback")
            try check(CloudKitSyncManager.shared.observation.uploads.isEmpty, "failed transaction published")
        }
        await run("retirement_during_original_sql_rolls_back_before_commit") {
            let f = try fixture("retire-sql"); let owner = AnnotationLocalEditorLifetime(); let storage = try f.storage(owner: owner)
            let old = try storage.read(); let intent = try storage.prepare(snapshot: old, mutationID: UUID(), body: fixtureBody(), textPreview: "changed", editorRevision: nil)
            let pointer = Unmanaged.passUnretained(owner).toOpaque()
            try check(sqlite3_create_function(f.db.dbPointer, "retire_local_editor", 0, SQLITE_UTF8, pointer, retireLocalEditorDuringSQL, nil, nil) == SQLITE_OK, "SQLite callback registration")
            defer { sqlite3_create_function(f.db.dbPointer, "retire_local_editor", 0, SQLITE_UTF8, nil, nil, nil, nil) }
            try f.db.execute(query: "CREATE TRIGGER retire_owner AFTER UPDATE OF note ON annotations BEGIN SELECT retire_local_editor(); END;")
            try rejects(AnnotationLocalEditorError.retired) { _ = try storage.commit(intent) }
            try check(try f.rows() == old.source.canonicalBytes && !f.ledger.hasInstalledSchema(), "retired transaction committed")
        }
        await run("normal_plain_save_refuses_rich_body_before_any_original_write") {
            // The current repository now refuses an old quick editor after a rich
            // commit. Historical passes of the former stale-body behavior remain
            // attributable to their original source only.
            let f = try fixture("normal-after-rich"); let s = try f.session(); let saved = try await f.initialSave(s)
            try f.refusePlainWrite(AnnotationPlainWriteError.requiresExpandedEditor)
            let value = try await s.read()
            try check(value.version?.payload == saved.snapshot.version?.payload &&
                      value.revision == saved.snapshot.revision &&
                      value.source.canonicalBytes == saved.snapshot.source.canonicalBytes,
                      "refused plain Save changed the saved rich note")
            _ = try f.intent(s, snapshot: value)
        }
        await run("lowercase_original_uuid_bytes_are_not_restamped") {
            let f = try fixture("uuid-case"); try f.db.execute(query: "UPDATE annotations SET ckRecordId=lower(ckRecordId);")
            let s = try f.session(); let saved = try await f.initialSave(s)
            try check(saved.snapshot.annotation.ckRecordId == f.uuid.uuidString.lowercased(), "original UUID restamped")
        }
        await run("nul_preview_is_rejected_before_original_sqlite_string_binding") {
            let f = try fixture("nul"); let s = try f.session(); let value = try await s.read()
            try rejects(AnnotationLocalEditorError.invalidPreview) { _ = try f.intent(s, snapshot: value, preview: "first\0second") }
        }
        await run("empty_format_contract_has_no_implicit_editor_default") {
            let f = try fixture("no-format")
            try rejects(AnnotationLocalEditorError.invalidIntent) { _ = try f.session(formats: []) }
        }
        await run("format_conversion_is_not_implicit_even_when_both_are_known") {
            let f = try fixture("conversion"); let other = try AnnotationLocalEditorBodyFormat(identifier: "fixture.other", version: 1)
            let s = try f.session(formats: [fixtureFormat, other]); let saved = try await f.initialSave(s)
            let body = TorahAnnotationEnvelope.RichBody(format: other.identifier, formatVersion: 1, bytes: Data([1]))
            try rejects(AnnotationLocalEditorError.unsupportedBody) {
                _ = try s.prepareSave(snapshot: saved.snapshot, mutationID: UUID(), body: body, textPreview: "same", editorRevision: nil)
            }
        }
        await run("replay_of_older_head_cannot_replace_or_publish_newer_body") {
            let f = try fixture("old-replay"); let s = try f.session(); let firstIntent = try f.intent(s, snapshot: await s.read())
            let first = try await f.save(s, firstIntent); let next = try await f.save(s, f.intent(s, snapshot: first.snapshot, suffix: "two"))
            try await rejectsAsync(AnnotationExchangeError.staleRevision) { _ = try await s.save(firstIntent) }
            try check(try f.ledger.currentVersion(namespace: AnnotationLocalEditorPersistence.namespace, annotationUUID: f.uuid)?.payload == next.snapshot.version?.payload, "newer version overwritten")
        }
        await run("retirement_during_publication_reports_real_commit_without_owner_delivery") {
            let f = try fixture("retire-publication"); let s = try f.session(); let intent = try f.intent(s, snapshot: await s.read())
            let subscription = f.store.events.sink { event in if case .localEditorCommitted(let sessionID) = event, sessionID == s.id { s.retire() } }
            defer { subscription.cancel() }
            guard case .completedWithoutOwnership(let receipt) = try await s.save(intent) else { throw LocalCheckFailure("retired delivery accepted") }
            try check(receipt.revision == 1 && !receipt.replayed, "actual commit lost")
            try check(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1, "committed body rolled back or duplicated")
        }
        await run("orphaned_version_is_not_treated_as_a_legacy_empty_note") {
            let f = try fixture("orphan"); let s = try f.session(); _ = try await f.initialSave(s)
            try f.db.execute(query: "DELETE FROM otzaria_annotation_exchange_heads;")
            try await rejectsAsync(AnnotationExchangeError.corruptRecord) { _ = try await s.read() }
        }
        await run("original_exchange_api_still_rejects_empty_destinations") {
            let f = try fixture("exchange-empty"); let s = try f.session(); let saved = try await f.initialSave(s)
            try rejects(AnnotationExchangeError.invalidScope) {
                _ = try f.ledger.commit(mutationID: UUID(), payload: saved.snapshot.version!.payload,
                    expectedSource: saved.snapshot.source, expectedRevision: 1, destinations: [])
            }
        }
        await run("ordinary_original_save_and_tags_still_work_on_legacy_note") {
            let f = try fixture("ordinary"); var edited = f.annotation; edited.note = "plain original"; edited.colorHex = "#abcdef"
            edited.tags = ["replacement"]; try f.store.updateAnnotation(edited)
            let actual = try f.repository.loadAnnotationById(f.annotation.id!)
            try check(actual?.note == edited.note && actual?.colorHex == edited.colorHex && actual?.tags == edited.tags, "normal Save changed")
            try check(try !f.ledger.hasInstalledSchema(), "normal Save gained automatic rich hook")
        }
    }
}

@main
enum LocalAnnotationEditorAcceptance {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw LocalCheckFailure("mode and owned fixture directory required") }
        let mode = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard mode == "self-tests" else {
            try await cold(mode: mode, root: root)
            return
        }
        let cases = LocalCases(root: root)
        await cases.execute()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cases.rows).write(to: root.appendingPathComponent("CASES.json"))
        print("ACTUAL_SQLITE \(String(cString: sqlite3_libversion()))")
        print("TOTAL \(cases.rows.count) PASS \(cases.rows.filter { $0.status == "PASS" }.count)")
        try check(cases.rows.count == 43 && Set(cases.rows.map(\.name)).count == 43, "exact component declarations")
        if cases.rows.contains(where: { $0.status != "PASS" }) { throw LocalCheckFailure("component cases failed") }
    }

    struct ColdRecord: Codable {
        let processID: Int32
        let databasePath: String
        let rowID: Int64
        let annotationUUID: UUID
        let mutationID: UUID
        let revision: Int64
        let note: String
        let tags: [String]
        let source: Data
        let sourceSHA256: String
        let payload: Data
        let payloadSHA256: String
        let body: Data
    }

    struct ColdObservation: Codable {
        let mode: String
        let processID: Int32
        let priorProcessID: Int32?
        let annotationUUID: UUID
        let revision: Int64
        let payloadSHA256: String
        let sourceSHA256: String
        let originalPendingUpload: Bool
        let exchangeDestinations: Int
        let sqliteVersion: String
        let status: String
    }

    @MainActor
    static func record(_ saved: AnnotationLocalEditorCommitted) throws -> ColdRecord {
        guard let rowID = saved.snapshot.annotation.id, let note = saved.snapshot.annotation.note,
              let version = saved.snapshot.version,
              case .supported(let envelope, _)? = saved.snapshot.document, let body = envelope.richBody else {
            throw LocalCheckFailure("saved body/source missing")
        }
        return .init(processID: ProcessInfo.processInfo.processIdentifier,
            databasePath: saved.snapshot.databaseURL.path, rowID: rowID,
            annotationUUID: saved.snapshot.annotationUUID, mutationID: saved.receipt.mutationID,
            revision: saved.receipt.revision, note: note, tags: saved.snapshot.annotation.tags,
            source: saved.snapshot.source.canonicalBytes, sourceSHA256: saved.snapshot.source.digest,
            payload: version.payload, payloadSHA256: version.payloadDigest, body: body.bytes)
    }

    @MainActor
    static func cold(mode: String, root: URL) async throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        let firstURL = root.appendingPathComponent("cold-expected-1.json")
        let nextURL = root.appendingPathComponent("cold-expected-2.json")
        let processID = ProcessInfo.processInfo.processIdentifier
        let current: ColdRecord
        let previousPID: Int32?
        let database: SQLiteDatabase
        if mode == "cold-write" {
            try check(!FileManager.default.fileExists(atPath: firstURL.path), "cold writer must use a fresh owned directory")
            let fixture = try LocalFixture(root: root, name: "cold-profile")
            let session = try fixture.session()
            let saved = try await fixture.initialSave(session)
            current = try record(saved)
            database = fixture.db
            previousPID = nil
            try encoder.encode(current).write(to: firstURL, options: .atomic)
        } else {
            guard mode == "cold-reopen" || mode == "cold-reopen-final" else {
                throw LocalCheckFailure("unknown mode")
            }
            let first = try decoder.decode(ColdRecord.self, from: Data(contentsOf: firstURL))
            let expected: ColdRecord
            if mode == "cold-reopen" { expected = first }
            else { expected = try decoder.decode(ColdRecord.self, from: Data(contentsOf: nextURL)) }
            let profile = root.appendingPathComponent("cold-profile", isDirectory: true)
            try check(expected.databasePath.utf8.elementsEqual(profile.appendingPathComponent("Annotations.sqlite").path.utf8), "unexpected profile path")
            try check(processID != expected.processID && processID != first.processID, "cold read must run in another process")
            try AnnotationStore.shared.setup(at: profile)
            guard let db = AnnotationRepository.shared.db,
                  let annotation = try AnnotationRepository.shared.loadAnnotationById(expected.rowID) else {
                throw LocalCheckFailure("original cold setup/read failed")
            }
            database = db
            let session = try AnnotationStore.shared.makeLocalAnnotationEditor(annotation: annotation, supportedFormats: [fixtureFormat])
            let snapshot = try await session.read()
            try check(snapshot.annotationUUID == expected.annotationUUID && snapshot.annotation.id == expected.rowID, "cold UUID or row changed")
            try check(snapshot.revision == expected.revision && snapshot.version?.mutationID == expected.mutationID, "cold revision changed")
            try check(snapshot.source.canonicalBytes == expected.source && snapshot.source.digest == expected.sourceSHA256, "cold original columns/tags changed")
            try check(snapshot.version?.payload == expected.payload && snapshot.version?.payloadDigest == expected.payloadSHA256, "cold version bytes changed")
            try check(snapshot.annotation.note?.utf8.elementsEqual(expected.note.utf8) == true && snapshot.annotation.tags == expected.tags, "cold plain note/tags changed")
            guard case .supported(let envelope, _)? = snapshot.document else { throw LocalCheckFailure("cold body missing") }
            try check(envelope.richBody?.bytes == expected.body, "cold two-block bytes changed")
            let ledger = AnnotationExchangeLedger(database: db, digest: AnnotationExchangePlatformDigest())
            try check(try ledger.version(mutationID: first.mutationID)?.payload == first.payload, "original immutable version changed")
            previousPID = expected.processID
            if mode == "cold-reopen" {
                let intent = try session.prepareSave(snapshot: snapshot, mutationID: UUID(), body: fixtureBody("cold-two"),
                    textPreview: "תצוגה שנייה אחרי פתיחה קרה", editorRevision: "cold-revision-two")
                guard case .committed(let saved) = try await session.save(intent) else { throw LocalCheckFailure("cold edit lost ownership") }
                try check(saved.receipt.revision == first.revision + 1 && saved.receipt.annotationUUID == first.annotationUUID, "cold edit changed UUID or revision")
                try check(try ledger.version(mutationID: first.mutationID)?.payload == first.payload, "cold edit rewrote old version")
                current = try record(saved)
                try encoder.encode(current).write(to: nextURL, options: .atomic)
            } else {
                current = expected
            }
        }
        let pending = try database.fetch(query: "SELECT COUNT(*) FROM sync_pending WHERE ck_record_id = ? COLLATE NOCASE AND operation='upload';",
            parameters: [current.annotationUUID.uuidString]) { $0.int64(at: 0) }.first ?? -1
        let outbox = try database.fetch(query: "SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") { $0.int64(at: 0) }.first ?? -1
        let versions = try database.fetch(query: "SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") { $0.int64(at: 0) }.first ?? -1
        try check(pending == 1 && outbox == 0 && versions == current.revision, "cold queue/outbox/history mismatch")
        let observation = ColdObservation(mode: mode, processID: processID, priorProcessID: previousPID,
            annotationUUID: current.annotationUUID, revision: current.revision,
            payloadSHA256: current.payloadSHA256, sourceSHA256: current.sourceSHA256,
            originalPendingUpload: pending == 1, exchangeDestinations: Int(outbox),
            sqliteVersion: String(cString: sqlite3_libversion()), status: "PASS_COMPONENT_COLD_PROCESS")
        try encoder.encode(observation).write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
        print("COLD_PROCESS \(mode) PID \(processID) REVISION \(current.revision)")
        // No forced checkpoint or simulated shutdown. A separate executable
        // process must reopen the original SQLite store after this one exits.
    }
}
