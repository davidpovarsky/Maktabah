import Foundation
import SQLite3
import OtzariaActionCore

// This executable uses the original LocalFixture prefix and whole product files.
// Its body is an explicitly opaque component fixture, never an Anytype archive.
let preserveFullNote = String(repeating: "\u{05E9}\u{05B8}\u{05C1}\u{05DC}\u{05D5}\u{05B9}\u{05DD} English \u{1F4DA}\n", count: 1_300)

func preservePreview(_ note: String) -> String {
    var result = ""
    for scalar in note.unicodeScalars {
        let candidate = result + String(scalar)
        if candidate.utf8.count > 8_192 { break }
        result = candidate
    }
    return result
}

func preserveJSON(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

@MainActor
func preserveSeed(root: URL, name: String, note: String? = preserveFullNote)
    throws -> (LocalFixture, AnnotationLocalEditorPersistence, AnnotationLocalEditorSnapshot) {
    let fixture = try LocalFixture(root: root, name: name)
    if let note {
        try fixture.db.execute(query: "UPDATE annotations SET note=? WHERE id=?;",
                               parameters: [note, fixture.annotation.id!])
    } else {
        try fixture.db.execute(query: "UPDATE annotations SET note=NULL WHERE id=?;",
                               parameters: [fixture.annotation.id!])
    }
    let storage = try fixture.storage()
    return (fixture, storage, try storage.read())
}

func preserveIntent(_ storage: AnnotationLocalEditorPersistence,
                    _ snapshot: AnnotationLocalEditorSnapshot,
                    mutation: UUID = UUID(), preview: String? = nil,
                    suffix: String = "preserved") throws -> AnnotationLocalEditorIntent {
    try storage.prepareNativeBackfill(snapshot: snapshot, mutationID: mutation,
        body: fixtureBody(suffix), textPreview: preview ?? preservePreview(snapshot.annotation.note ?? ""),
        editorRevision: "component-only-" + suffix)
}

@MainActor
func preserveRefusal<E: Error & Equatable>(_ fixture: LocalFixture, _ expected: E,
                                         _ body: () throws -> Void) throws {
    let image = try fixture.databaseImage()
    let cloud = CloudKitSyncManager.shared.observation
    try rejects(expected, body)
    try check(try fixture.databaseImage() == image, "refusal changed the actual SQLite image")
    let after = CloudKitSyncManager.shared.observation
    try check(after.uploads == cloud.uploads && after.trackPending == cloud.trackPending &&
              after.deletes == cloud.deletes, "refusal published a CloudKit callback")
}

@MainActor
final class LongNotePreservationCases {
    struct Row: Codable { let name: String; let status: String; let error: String? }
    let root: URL
    var rows: [Row] = []
    init(root: URL) { self.root = root }
    func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do { try await body(); rows.append(.init(name: name, status: "PASS", error: nil)); print("PASS \(name)") }
        catch { rows.append(.init(name: name, status: "FAIL", error: String(describing: error))); print("FAIL \(name): \(error)") }
    }

    func execute() async {
        await run("long_utf8_note_preserves_actual_complete_saved_text_and_body") {
            let (f, p, before) = try preserveSeed(root: root, name: "long-body")
            try check(preserveFullNote.utf8.count > 8_192, "fixture is not genuinely long")
            let intent = try preserveIntent(p, before), saved = try p.commit(intent)
            try check(intent.noteWritePolicy == .preserveOriginalText && saved.receipt.revision == 1,
                      "wrong preservation policy or revision")
            try check(saved.snapshot.annotation.note?.utf8.elementsEqual(preserveFullNote.utf8) == true,
                      "complete original UTF-8 text was truncated or replaced")
            guard case .supported(let envelope, _)? = saved.snapshot.document else {
                throw LocalCheckFailure("missing actual saved rich envelope")
            }
            try check(envelope.textPreview.utf8.elementsEqual(intent.textPreview.utf8) &&
                      envelope.textPreview.utf8.count <= 8_192 && envelope.richBody?.bytes == fixtureBody("preserved").bytes,
                      "bounded preview or rich fixture body changed")
            var expected = before.annotation
            expected.lastModified = saved.snapshot.annotation.lastModified
            try check(saved.snapshot.annotation == expected, "original columns, tags or CloudKit identity changed")
            try check(saved.snapshot.source == (try f.ledger.captureSource(annotationUUID: f.uuid)),
                      "saved source witness does not describe the actual original row")
        }
        await run("preservation_queues_original_upload_without_remote_delivery_or_ack") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "queue")
            let saved = try p.commit(preserveIntent(p, snapshot))
            try check(saved.receipt.deliveries.isEmpty && !AnnotationExchangeCapability.liveExchangeEnabled,
                      "preservation unexpectedly enabled remote exchange")
            try check(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox;") == 0,
                      "preservation created a remote delivery or ACK")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload';",
                                   [snapshot.annotation.ckRecordId!]) == 1, "original upload is not durable")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete';") == 1,
                      "unrelated original deletion was modified")
        }
        await run("short_note_requires_and_preserves_exact_preview_bytes") {
            let text = "\u{05D0}\u{05B7} short \u{1F4DA}"
            let (_, p, snapshot) = try preserveSeed(root: root, name: "short", note: text)
            let saved = try p.commit(preserveIntent(p, snapshot, preview: text))
            try check(saved.snapshot.annotation.note?.utf8.elementsEqual(text.utf8) == true, "short original text changed")
        }
        await run("short_note_prefix_without_complete_text_is_refused") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "short-prefix", note: "complete short text")
            try preserveRefusal(f, AnnotationLocalEditorError.invalidPreview) {
                _ = try preserveIntent(p, snapshot, preview: "complete")
            }
        }
        await run("long_note_nonprefix_preview_is_refused") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "wrong-prefix")
            try preserveRefusal(f, AnnotationLocalEditorError.invalidPreview) {
                _ = try preserveIntent(p, snapshot, preview: "not the original prefix")
            }
        }
        await run("canonically_equivalent_but_different_utf8_preview_is_refused") {
            let actual = "e\u{0301}" + String(repeating: " original", count: 1_200)
            let alternative = "\u{00E9}"
            try check(actual.hasPrefix(alternative) && !actual.utf8.starts(with: alternative.utf8),
                      "fixture did not distinguish Unicode equivalence from exact bytes")
            let (f, p, snapshot) = try preserveSeed(root: root, name: "unicode", note: actual)
            try preserveRefusal(f, AnnotationLocalEditorError.invalidPreview) {
                _ = try preserveIntent(p, snapshot, preview: alternative)
            }
        }
        await run("missing_and_empty_original_notes_are_refused_without_schema") {
            for (name, note) in [("missing", Optional<String>.none), ("empty", Optional(""))] {
                let (f, p, snapshot) = try preserveSeed(root: root, name: name, note: note)
                try preserveRefusal(f, AnnotationLocalEditorError.invalidPreview) {
                    _ = try preserveIntent(p, snapshot, preview: "")
                }
                try check(try !f.ledger.hasInstalledSchema(), "invalid original note installed rich schema")
            }
        }
        await run("oversized_or_nul_preview_is_refused_before_write") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "preview-bounds")
            for preview in [String(repeating: "x", count: 8_193), "\0"] {
                try preserveRefusal(f, AnnotationLocalEditorError.invalidPreview) {
                    _ = try preserveIntent(p, snapshot, preview: preview)
                }
            }
        }
        await run("existing_rich_body_cannot_be_preserved_as_first_conversion") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "existing")
            let saved = try p.commit(preserveIntent(p, snapshot))
            try preserveRefusal(f, AnnotationLocalEditorError.unsupportedBody) {
                _ = try preserveIntent(p, saved.snapshot)
            }
        }
        await run("concurrent_plain_note_change_refuses_preservation_without_overwrite") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "stale-note")
            let intent = try preserveIntent(p, snapshot)
            try f.db.execute(query: "UPDATE annotations SET note=? WHERE id=?;",
                             parameters: ["new original note from another writer", f.annotation.id!])
            try preserveRefusal(f, AnnotationExchangeError.staleSource) { _ = try p.commit(intent) }
        }
        await run("concurrent_original_tag_change_refuses_preservation") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "stale-tag")
            let intent = try preserveIntent(p, snapshot)
            try f.db.execute(query: "UPDATE tags SET name=? WHERE id=(SELECT tagId FROM annotation_tags WHERE annotationId=? LIMIT 1);",
                             parameters: ["changed original tag", f.annotation.id!])
            try preserveRefusal(f, AnnotationExchangeError.staleSource) { _ = try p.commit(intent) }
        }
        await run("pending_original_deletion_refuses_preservation") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "pending-delete")
            let intent = try preserveIntent(p, snapshot)
            try f.repository.addPendingSync(ckRecordId: snapshot.annotation.ckRecordId!, operation: "delete")
            try preserveRefusal(f, AnnotationLocalEditorError.pendingDeletion) { _ = try p.commit(intent) }
        }
        await run("caller_changed_snapshot_text_cannot_replace_actual_row") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "forged-note")
            var annotation = snapshot.annotation
            annotation.note = String(repeating: "caller replacement ", count: 1_000)
            let forged = AnnotationLocalEditorSnapshot(annotation: annotation, annotationUUID: snapshot.annotationUUID,
                databaseURL: snapshot.databaseURL, revision: snapshot.revision, document: snapshot.document,
                source: snapshot.source, version: snapshot.version, sessionID: snapshot.sessionID)
            let intent = try preserveIntent(p, forged)
            try preserveRefusal(f, AnnotationExchangeError.staleSource) { _ = try p.commit(intent) }
        }
        await run("write_policy_substitution_cannot_reuse_another_intent_digest") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "policy-forgery")
            let preserve = try preserveIntent(p, snapshot)
            let ordinary = try p.prepare(snapshot: snapshot, mutationID: preserve.mutationID, body: preserve.body,
                textPreview: preserve.textPreview, editorRevision: preserve.editorRevision)
            try check(ordinary.intentDigest != preserve.intentDigest, "policies share a durable intent digest")
            for intent in [ordinary, preserve] {
                let other: AnnotationLocalEditorNoteWritePolicy =
                    intent.noteWritePolicy == .replaceWithPreview ? .preserveOriginalText : .replaceWithPreview
                let forged = AnnotationLocalEditorIntent(mutationID: intent.mutationID, snapshot: intent.snapshot,
                    body: intent.body, textPreview: intent.textPreview, editorRevision: intent.editorRevision,
                    intentDigest: intent.intentDigest, noteWritePolicy: other)
                try preserveRefusal(f, AnnotationLocalEditorError.invalidIntent) { _ = try p.commit(forged) }
            }
            _ = try p.commit(preserve)
        }
        await run("same_mutation_cannot_replay_between_ordinary_and_preserve_policies") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "policy-replay")
            let preserve = try preserveIntent(p, snapshot)
            let ordinary = try p.prepare(snapshot: snapshot, mutationID: preserve.mutationID, body: preserve.body,
                textPreview: preserve.textPreview, editorRevision: preserve.editorRevision)
            _ = try p.commit(preserve)
            try preserveRefusal(f, AnnotationExchangeError.idempotencyConflict) { _ = try p.commit(ordinary) }
        }
        await run("actual_annotation_write_then_version_insert_failure_rolls_back_everything") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "rollback")
            let intent = try preserveIntent(p, snapshot), before = try f.databaseImage()
            let probe = LocalSQLiteWriteFailureProbe()
            let context = Unmanaged.passUnretained(probe).toOpaque()
            let priorObserver = sqlite3_update_hook(f.db.dbPointer, observeLocalPreviewWrite, context)
            defer {
                sqlite3_update_hook(f.db.dbPointer, nil, nil)
                sqlite3_set_authorizer(f.db.dbPointer, nil, nil)
            }
            try check(priorObserver == nil, "fixture already has an update observer")
            try check(sqlite3_set_authorizer(f.db.dbPointer, refuseLocalVersionInsert, context) == SQLITE_OK,
                      "failed to install actual SQLite authorizer")
            var failed = false
            do { _ = try p.commit(intent) } catch { failed = true }
            sqlite3_update_hook(f.db.dbPointer, nil, nil)
            sqlite3_set_authorizer(f.db.dbPointer, nil, nil)
            withExtendedLifetime(probe) {}
            try check(failed && probe.observation.previewUpdates == 1 &&
                      probe.observation.deniedVersionInserts > 0, "fault did not reach actual UPDATE then refused INSERT")
            try check(try f.databaseImage() == before && !f.ledger.hasInstalledSchema(),
                      "actual rollback left note, timestamp, queue or rich schema changes")
            let saved = try p.commit(intent)
            try check(saved.receipt.revision == 1 &&
                      saved.snapshot.annotation.note?.utf8.elementsEqual(preserveFullNote.utf8) == true,
                      "rolled-back intent could not subsequently complete exactly once")
        }
        await run("exact_preserve_retry_keeps_timestamp_full_text_and_one_revision") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "retry")
            let intent = try preserveIntent(p, snapshot), first = try p.commit(intent)
            let before = try f.databaseImage(), second = try p.commit(intent)
            try check(second.receipt.replayed && first.snapshot.annotation == second.snapshot.annotation &&
                      first.snapshot.source == second.snapshot.source && first.snapshot.version == second.snapshot.version, "preserve retry was not the exact saved version")
            try check(try f.databaseImage() == before &&
                      f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1,
                      "retry changed actual saved data")
        }
        await run("same_mutation_with_different_rich_bytes_is_conflict") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "body-conflict")
            let first = try preserveIntent(p, snapshot)
            _ = try p.commit(first)
            let changed = try preserveIntent(p, snapshot, mutation: first.mutationID, suffix: "changed")
            try preserveRefusal(f, AnnotationExchangeError.idempotencyConflict) { _ = try p.commit(changed) }
        }
        await run("owner_retirement_refuses_preparation_and_prepared_commit") {
            for prepareBeforeRetirement in [false, true] {
                let (f, p, snapshot) = try preserveSeed(root: root, name: "retire-\(prepareBeforeRetirement)")
                let intent = prepareBeforeRetirement ? try preserveIntent(p, snapshot) : nil
                p.owner.retire()
                try preserveRefusal(f, AnnotationLocalEditorError.retired) {
                    if let intent { _ = try p.commit(intent) }
                    else { _ = try preserveIntent(p, snapshot) }
                }
            }
        }
        await run("disconnect_reopen_does_not_restore_old_preservation_authority") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "reconnect")
            let intent = try preserveIntent(p, snapshot)
            f.store.disconnect()
            try f.store.setup(at: f.url)
            try preserveRefusal(f, AnnotationLocalEditorError.retired) { _ = try p.commit(intent) }
            guard let annotation = try f.repository.loadAnnotationById(f.annotation.id!) else {
                throw LocalCheckFailure("reopened original note missing")
            }
            try check(annotation.note?.utf8.elementsEqual(preserveFullNote.utf8) == true,
                      "retired writer changed reopened data")
        }
        await run("ordinary_save_still_replaces_note_with_bounded_preview") {
            let (_, p, snapshot) = try preserveSeed(root: root, name: "ordinary")
            let preview = preservePreview(preserveFullNote)
            let intent = try p.prepare(snapshot: snapshot, mutationID: UUID(), body: fixtureBody(),
                                       textPreview: preview, editorRevision: "ordinary")
            let saved = try p.commit(intent)
            try check(intent.noteWritePolicy == .replaceWithPreview &&
                      saved.snapshot.annotation.note?.utf8.elementsEqual(preview.utf8) == true &&
                      (saved.snapshot.annotation.note?.utf8.count ?? 0) < preserveFullNote.utf8.count,
                      "ordinary Save changed its established replacement behavior")
        }
        await run("ordinary_edit_can_follow_a_complete_preserved_conversion") {
            let (_, p, snapshot) = try preserveSeed(root: root, name: "later-edit")
            let first = try p.commit(preserveIntent(p, snapshot))
            let intent = try p.prepare(snapshot: first.snapshot, mutationID: UUID(), body: fixtureBody("edited"),
                                       textPreview: "explicit ordinary edit", editorRevision: "edited")
            let second = try p.commit(intent)
            try check(second.receipt.revision == 2 && second.snapshot.annotation.note == "explicit ordinary edit",
                      "normal edit after first-body conversion was not admitted")
        }
        await run("prepare_then_cancel_creates_no_saved_version_or_original_change") {
            let (f, p, snapshot) = try preserveSeed(root: root, name: "cancel")
            let before = try f.databaseImage()
            _ = try preserveIntent(p, snapshot)
            p.owner.retire()
            try check(try f.databaseImage() == before && !f.ledger.hasInstalledSchema(),
                      "preparation or cancellation persisted a draft")
        }
    }
}

@MainActor
func preserveCold(_ mode: String, root: URL) async throws {
    let expectedURL = root.appendingPathComponent("long-cold-expected.json")
    if mode == "cold-write" {
        let (f, p, snapshot) = try preserveSeed(root: root, name: "long-cold-profile")
        let intent = try preserveIntent(p, snapshot), saved = try p.commit(intent)
        guard let version = saved.snapshot.version, let lastModified = saved.snapshot.annotation.lastModified else {
            throw LocalCheckFailure("saved version or timestamp missing")
        }
        let expected: [String: Any] = [
            "processID": Int(getpid()), "profilePath": f.url.path, "databasePath": p.connection.databaseURL.path,
            "rowID": saved.snapshot.annotation.id!, "annotationUUID": f.uuid.uuidString,
            "mutationID": saved.receipt.mutationID.uuidString, "revision": saved.receipt.revision,
            "noteBase64": Data(preserveFullNote.utf8).base64EncodedString(),
            "noteSHA256": AnnotationExchangePlatformDigest().sha256(Data(preserveFullNote.utf8)),
            "noteByteCount": preserveFullNote.utf8.count,
            "previewBase64": Data(intent.textPreview.utf8).base64EncodedString(),
            "bodyBase64": intent.body.bytes.base64EncodedString(),
            "sourceBase64": saved.snapshot.source.canonicalBytes.base64EncodedString(),
            "sourceSHA256": saved.snapshot.source.digest, "payloadBase64": version.payload.base64EncodedString(),
            "payloadSHA256": version.payloadDigest, "tags": saved.snapshot.annotation.tags,
            "lastModified": lastModified
        ]
        try preserveJSON(expected).write(to: expectedURL, options: .atomic)
        try preserveJSON(["mode": mode, "processID": Int(getpid()), "status": "PASS_ORIGINAL_LONG_NOTE_COMMITTED"])
            .write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
        return
    }
    guard let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: expectedURL)) as? [String: Any],
          let firstPID = expected["processID"] as? Int, let profile = expected["profilePath"] as? String,
          let rowID = (expected["rowID"] as? NSNumber)?.int64Value else {
        throw LocalCheckFailure("missing original writer identity")
    }
    try check(firstPID != Int(getpid()), "cold reopen reused the writer process")
    try AnnotationStore.shared.setup(at: URL(fileURLWithPath: profile, isDirectory: true))
    let repository = AnnotationStore.shared.repository
    guard let annotation = try repository.loadAnnotationById(rowID), let uuid = annotation.ckRecordId.flatMap(UUID.init(uuidString:)) else {
        throw LocalCheckFailure("original reopened note is missing")
    }
    let p = try AnnotationLocalEditorPersistence(connection: repository.captureLocalEditorConnection(),
        annotationID: rowID, annotationUUID: uuid, sessionID: UUID(), owner: .init(),
        formats: [fixtureFormat], digest: AnnotationExchangePlatformDigest())
    let snapshot = try p.read()
    try check(snapshot.annotation.note?.utf8.elementsEqual(preserveFullNote.utf8) == true &&
              Data(snapshot.annotation.note!.utf8).base64EncodedString() == expected["noteBase64"] as? String,
              "cold original complete UTF-8 note changed")
    try check(snapshot.annotationUUID.uuidString == expected["annotationUUID"] as? String &&
              snapshot.revision == 1 && snapshot.version?.mutationID.uuidString == expected["mutationID"] as? String &&
              snapshot.source.canonicalBytes.base64EncodedString() == expected["sourceBase64"] as? String &&
              snapshot.source.digest == expected["sourceSHA256"] as? String &&
              snapshot.version?.payload.base64EncodedString() == expected["payloadBase64"] as? String &&
              snapshot.version?.payloadDigest == expected["payloadSHA256"] as? String &&
              snapshot.annotation.tags == expected["tags"] as? [String],
              "cold original identity, tags, source or immutable body changed")
    try rejects(AnnotationLocalEditorError.unsupportedBody) { _ = try preserveIntent(p, snapshot) }
    try preserveJSON(["mode": mode, "processID": Int(getpid()), "writerProcessID": firstPID,
                      "status": "PASS_ORIGINAL_LONG_NOTE_COLD_REOPEN", "nativeExecution": false,
                      "sourceSHA256": snapshot.source.digest, "payloadSHA256": snapshot.version!.payloadDigest])
        .write(to: root.appendingPathComponent(mode + ".json"), options: .atomic)
}

@main
struct LongNotePreservationAcceptance {
    @MainActor
    static func main() async {
        do {
            guard CommandLine.arguments.count == 3 else { throw LocalCheckFailure("mode and owned fixture root required") }
            let mode = CommandLine.arguments[1], root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if mode == "self-tests" {
                let suite = LongNotePreservationCases(root: root)
                await suite.execute()
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(suite.rows).write(to: root.appendingPathComponent("CASES.json"), options: .atomic)
                if suite.rows.contains(where: { $0.status != "PASS" }) { exit(1) }
            } else if mode == "cold-write" || mode == "cold-reopen" {
                try await preserveCold(mode, root: root)
            } else { throw LocalCheckFailure("unknown mode") }
        } catch {
            FileHandle.standardError.write(Data("LONG_NOTE_PRESERVATION_COMPONENT_FAILURE: \(error)\n".utf8))
            exit(1)
        }
    }
}
