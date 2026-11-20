import CloudKit
import Foundation
import SQLite3
import Synchronization
import OtzariaActionCore

// LocalFixture/check/fixtureBody are the exact unchanged original fixture prefix
// of LocalAnnotationEditorAcceptance.swift, copied and hashed by the driver.
// Every Store, Repository, SQLite, ledger, session and cloud-ownership method is
// a complete production source file. Only account/transport/waits below are
// explicit doubles. No account, CloudKit request or original editor is mounted.

final class CloudGate: Sendable {
    private struct State { var entered = false; var released = false }
    private let state = Mutex(State())

    func pause() async throws {
        state.withLock { $0.entered = true }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !state.withLock({ $0.released }) {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw LocalCheckFailure("explicit boundary release timed out") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func waitForEntry() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !state.withLock({ $0.entered }) {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw LocalCheckFailure("explicit boundary entry timed out") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
    func release() { state.withLock { $0.released = true } }
}

enum CloudBoundaryError: Error, Equatable { case lookup, upload, worker }

final class CloudDouble: Sendable {
    struct Observation: Sendable {
        var lookups = 0
        var debounced: [Annotation] = []
        var uploaded: [Annotation] = []
        var workerWaits = 0
        var workerRequests: [URLRequest] = []
    }
    private struct State {
        var identity: AnnotationLocalEditorCloudAccount?
        var permitted = true
        var lookupError = false
        var pauseLookup: Int?
        var pauseDebounce = false
        var pauseUpload = false
        var pauseWorkerWait = false
        var pauseWorkerSend = false
        var alteredDebounce = false
        var remoteFailure = false
        var workerFailure = false
        var request: URLRequest?
        var observations = Observation()
    }
    let center: NotificationCenter
    let changed: Notification.Name
    let account: AnnotationLocalEditorCloudAccountObservation
    let lookupGate = CloudGate()
    let debounceGate = CloudGate()
    let uploadGate = CloudGate()
    let workerWaitGate = CloudGate()
    let workerSendGate = CloudGate()
    private let state: Mutex<State>

    init() throws {
        let center = NotificationCenter(), changed = Notification.Name("org.otzaria.fixture.account.changed")
        self.center = center; self.changed = changed
        account = AnnotationLocalEditorCloudAccountObservation(center: center, changedNotification: changed)
        state = Mutex(State(identity: try Self.identity("fixture-account-a")))
    }
    static func identity(_ name: String) throws -> AnnotationLocalEditorCloudAccount {
        try .init(recordName: name, zoneName: "fixture-user-zone", ownerName: "fixture-user-owner")
    }
    var observation: Observation { state.withLock { $0.observations } }
    func missingIdentity() { state.withLock { $0.identity = nil } }
    func changeIdentity(_ name: String) throws { let value = try Self.identity(name); state.withLock { $0.identity = value } }
    func setPermission(_ value: Bool) { state.withLock { $0.permitted = value } }
    func failLookup() { state.withLock { $0.lookupError = true } }
    func pauseLookup(_ call: Int) { state.withLock { $0.pauseLookup = call } }
    func pauseDebounce() { state.withLock { $0.pauseDebounce = true } }
    func pauseUpload() { state.withLock { $0.pauseUpload = true } }
    func pauseWorkerWait() { state.withLock { $0.pauseWorkerWait = true } }
    func pauseWorkerSend() { state.withLock { $0.pauseWorkerSend = true } }
    func alterDebouncedRecord() { state.withLock { $0.alteredDebounce = true } }
    func failUpload() { state.withLock { $0.remoteFailure = true } }
    func failWorker() { state.withLock { $0.workerFailure = true } }
    func setWorkerRequest(_ value: URLRequest?) { state.withLock { $0.request = value } }
    func notifyAccountChange() { center.post(name: changed, object: nil) }

    var client: AnnotationLocalEditorCloudClient {
        .init(account: account, isPermitted: { self.state.withLock { $0.permitted } }, resolveAccount: {
            let captured = self.state.withLock { value in
                value.observations.lookups += 1
                return (value.identity, value.lookupError, value.pauseLookup == value.observations.lookups)
            }
            // Capture before suspension: the real API may return an old lookup
            // after an account notification. The production epoch must reject it.
            if captured.2 { try await self.lookupGate.pause() }
            if captured.1 { throw CloudBoundaryError.lookup }
            return captured.0
        }, debounce: { annotation in
            let captured = self.state.withLock { value in
                value.observations.debounced.append(annotation)
                return (value.pauseDebounce, value.alteredDebounce)
            }
            if captured.0 { try await self.debounceGate.pause() }
            if captured.1 { var other = annotation; other.note = "changed by explicit double"; return other }
            return annotation
        }, upload: { annotation in
            let captured = self.state.withLock { value in
                value.observations.uploaded.append(annotation)
                return (value.pauseUpload, value.remoteFailure)
            }
            if captured.0 {
                do { try await self.uploadGate.pause() }
                catch { return .failed(error) }
            }
            return captured.1 ? .failed(CloudBoundaryError.upload) : .succeeded
        }, workerRequest: {
            self.state.withLock { $0.request }
        }, waitForWorker: {
            let pause = self.state.withLock { value in value.observations.workerWaits += 1; return value.pauseWorkerWait }
            if pause { try await self.workerWaitGate.pause() }
        }, sendWorker: { request in
            let captured = self.state.withLock { value in
                value.observations.workerRequests.append(request)
                return (value.pauseWorkerSend, value.workerFailure)
            }
            if captured.0 {
                do { try await self.workerSendGate.pause() }
                catch { return .failure(error) }
            }
            return captured.1 ? .failure(CloudBoundaryError.worker) : .success(())
        })
    }
}

@MainActor
final class CloudCases {
    struct Row: Codable { let name: String; let status: String; let error: String? }
    let root: URL
    var rows: [Row] = []
    init(root: URL) { self.root = root }

    func run(_ name: String, _ body: @MainActor () async throws -> Void) async {
        do { try await body(); rows.append(.init(name: name, status: "PASS", error: nil)); print("PASS \(name)") }
        catch { rows.append(.init(name: name, status: "FAIL", error: String(describing: error))); print("FAIL \(name): \(error)") }
    }
    func fixture(_ name: String) throws -> LocalFixture { try .init(root: root, name: name) }
    func prepared(_ f: LocalFixture, _ s: AnnotationLocalEditorSession, _ d: CloudDouble?) async throws -> AnnotationLocalEditorCloudPreparation {
        let snapshot = try await s.read()
        return try await s.prepareOwnedCloudSave(f.intent(s, snapshot: snapshot), client: d?.client)
    }
    func committed(_ outcome: AnnotationLocalEditorCloudSaveOutcome) throws -> AnnotationLocalEditorCommitted {
        guard case .committed(let saved) = outcome.local else { throw LocalCheckFailure("expected actual owned local commit") }
        return saved
    }
    func stillPending(_ f: LocalFixture) throws {
        try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload';", [f.annotation.ckRecordId!]) == 1, "durable upload was lost")
        try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete';") == 1, "unrelated deletion changed")
    }
    func noUpload(_ completion: AnnotationLocalEditorCloudCompletion, _ reason: AnnotationLocalEditorCloudDeferral,
                  _ f: LocalFixture, _ d: CloudDouble?) throws {
        guard case .notAttempted(let actual) = completion.remote else { throw LocalCheckFailure("upload unexpectedly admitted") }
        try check(actual == reason && completion.pending == .retained(reason), "wrong refusal classification")
        try check(d?.observation.uploaded.isEmpty ?? true, "explicit transport was called")
        try check(!completion.mayDeliverToOriginalOwner, "refused cloud completion delivered")
        try stillPending(f)
    }
    func success(_ completion: AnnotationLocalEditorCloudCompletion) throws {
        guard case .succeeded = completion.remote else { throw LocalCheckFailure("actual remote success lost") }
    }
    func failedUpload(_ completion: AnnotationLocalEditorCloudCompletion) throws {
        guard case .failed(let error) = completion.remote, error as? CloudBoundaryError == .upload else {
            throw LocalCheckFailure("actual admitted error lost or replaced")
        }
    }
    func workerRequest(_ suffix: String = "original") -> URLRequest {
        var request = URLRequest(url: URL(string: "https://owned-fixture.invalid/\(suffix)")!)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    func savePaused(_ s: AnnotationLocalEditorSession, _ p: AnnotationLocalEditorCloudPreparation,
                    at gate: CloudGate, change: @MainActor () throws -> Void) async throws -> AnnotationLocalEditorCloudCompletion {
        let outcome = try await s.saveOwnedCloud(p)
        do {
            try await gate.waitForEntry()
            try change()
            gate.release()
            return await outcome.publication.completion
        } catch {
            gate.release()
            _ = await outcome.publication.completion
            throw error
        }
    }
    func preparePaused(_ s: AnnotationLocalEditorSession, _ intent: AnnotationLocalEditorIntent,
                       _ d: CloudDouble, change: @MainActor () throws -> Void) async throws -> AnnotationLocalEditorCloudPreparation {
        let worker = Task { try await s.prepareOwnedCloudSave(intent, client: d.client) }
        do {
            try await d.lookupGate.waitForEntry()
            try change()
            d.lookupGate.release()
            return try await worker.value
        } catch {
            d.lookupGate.release()
            _ = try? await worker.value
            throw error
        }
    }

    func execute() async {
        await run("disabled_original_client_has_no_container_or_transport") {
            try check(!AppConfig.useICloud && AnnotationLocalEditorCloudClient.original() == nil, "disabled adapter created a client")
        }
        await run("missing_client_saves_locally_and_retains_original_pending") {
            let f = try fixture("missing-client"), s = try f.session()
            let p = try await prepared(f, s, nil), outcome = try await s.saveOwnedCloud(p)
            let saved = try committed(outcome); let result = await outcome.publication.completion
            try check(saved.receipt.revision == 1 && saved.receipt.deliveries.isEmpty, "local offline commit absent")
            try noUpload(result, .unavailable, f, nil)
            try check(CloudKitSyncManager.shared.observation.uploads.isEmpty, "owned path also called legacy transport")
        }
        await run("missing_precommit_identity_never_adopts_later_account") {
            let f = try fixture("missing-identity"), s = try f.session(), d = try CloudDouble(); d.missingIdentity()
            let p = try await prepared(f, s, d); try d.changeIdentity("fixture-later-account")
            let outcome = try await s.saveOwnedCloud(p); let result = await outcome.publication.completion
            try noUpload(result, .accountUnavailable, f, d)
            try check(d.observation.lookups == 1, "postcommit account was adopted")
        }
        await run("failed_precommit_identity_never_retries_after_commit") {
            let f = try fixture("failed-identity"), s = try f.session(), d = try CloudDouble(); d.failLookup()
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p)
            let result = await outcome.publication.completion
            try noUpload(result, .accountUnavailable, f, d)
            try check(d.observation.lookups == 1, "identity failure retried")
        }
        await run("account_notification_during_preparation_rejects_old_lookup_result") {
            let f = try fixture("prepare-account"), s = try f.session(), d = try CloudDouble(); d.pauseLookup(1)
            let snapshot = try await s.read(), intent = try f.intent(s, snapshot: snapshot)
            let p = try await preparePaused(s, intent, d) { d.notifyAccountChange() }
            let outcome = try await s.saveOwnedCloud(p); let result = await outcome.publication.completion
            try noUpload(result, .accountChanged, f, d)
        }
        await run("source_write_during_preparation_refuses_before_local_commit") {
            let f = try fixture("prepare-source"), s = try f.session(), d = try CloudDouble(); d.pauseLookup(1)
            let snapshot = try await s.read(), intent = try f.intent(s, snapshot: snapshot)
            try await rejectsAsync(AnnotationExchangeError.staleSource) {
                _ = try await preparePaused(s, intent, d) {
                    var changed = f.annotation; changed.note = "original concurrent Save"; try f.store.updateAnnotation(changed)
                }
            }
            try check(try !f.ledger.hasInstalledSchema() && d.observation.uploaded.isEmpty, "failed preparation committed or uploaded")
        }
        await run("owner_retirement_during_preparation_is_one_way") {
            let f = try fixture("prepare-owner"), s = try f.session(), d = try CloudDouble(); d.pauseLookup(1)
            let snapshot = try await s.read(), intent = try f.intent(s, snapshot: snapshot)
            try await rejectsAsync(AnnotationLocalEditorError.retired) {
                _ = try await preparePaused(s, intent, d) { s.retire() }
            }
            try check(try !f.ledger.hasInstalledSchema(), "retired preparation committed")
        }
        await run("exact_success_acknowledges_once_without_legacy_upload_or_metadata_loss") {
            let f = try fixture("success"), s = try f.session(), d = try CloudDouble()
            _ = f.store.loadAnnotations(bkId: 28, contentId: 2)
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p), saved = try committed(outcome)
            let result = await outcome.publication.completion; try success(result)
            try check(result.pending == .acknowledged && result.mayDeliverToOriginalOwner, "exact success was not acknowledged")
            try check(d.observation.uploaded == [saved.snapshot.annotation] && CloudKitSyncManager.shared.observation.uploads.isEmpty, "duplicate/different transport")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=?;", [f.annotation.ckRecordId!]) == 0, "ACK did not remove exact upload")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete';") == 1, "unrelated delete lost")
            var expected = f.annotation; expected.note = saved.snapshot.annotation.note; expected.lastModified = saved.snapshot.annotation.lastModified
            try check(saved.snapshot.annotation == expected && saved.receipt.deliveries.isEmpty, "original identity/metadata drift")
            try check(f.store.loadAnnotations(bkId: 28, contentId: 2).first?.note == expected.note, "original cache stale")
        }
        await run("original_annotation_cloud_record_mapping_preserves_uuid_zone_and_plain_note") {
            let f = try fixture("record-mapping")
            let zone = CKRecordZone.ID(zoneName: "explicit-fixture-zone", ownerName: "explicit-fixture-owner")
            guard let record = f.annotation.toCKRecord(zoneID: zone) else { throw LocalCheckFailure("original record mapping failed") }
            try check(record.recordID.recordName == f.annotation.ckRecordId && record.recordID.zoneID == zone, "original record destination changed")
            guard var parsed = AnnotationSyncHandler.parse(from: record) else { throw LocalCheckFailure("original record parse failed") }
            parsed.id = f.annotation.id
            try check(parsed == f.annotation, "original plain-note/tag/locator mapping changed")
        }
        await run("original_two_second_debouncer_delivers_one_retained_instance") {
            let f = try fixture("real-debouncer"), original = CloudKitUploadDebouncer<Annotation>()
            let observed = Mutex<[Annotation]>([]), gate = CloudGate()
            await original.add(items: [(id: f.annotation.ckRecordId!, item: f.annotation)], completion: nil, debounce: true) { items, callbacks in
                observed.withLock { $0 += items }
                if callbacks.isEmpty { gate.release() }
            }
            // Use the gate's released state through a bounded pause; this waits
            // on the actual original timer, without asserting product latency.
            try await gate.pause()
            withExtendedLifetime(original) {}
            try check(observed.withLock { $0 } == [f.annotation], "original debounce delivery differed")
        }
        await run("retirement_during_debounce_prevents_upload") {
            let f = try fixture("debounce-owner"), s = try f.session(), d = try CloudDouble(); d.pauseDebounce()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.debounceGate) { s.retire() }
            try noUpload(result, .ownerRetired, f, d)
        }
        await run("profile_disconnect_reopen_during_debounce_never_revives_connection") {
            let f = try fixture("debounce-profile"), s = try f.session(), d = try CloudDouble(); d.pauseDebounce()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.debounceGate) { f.store.disconnect(); f.store.connect() }
            try noUpload(result, .ownerRetired, f, d)
        }
        await run("account_aba_during_debounce_keeps_old_epoch_retired") {
            let f = try fixture("debounce-account"), s = try f.session(), d = try CloudDouble(); d.pauseDebounce()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.debounceGate) {
                d.notifyAccountChange(); try d.changeIdentity("fixture-account-b"); try d.changeIdentity("fixture-account-a")
            }
            try noUpload(result, .accountChanged, f, d)
        }
        await run("permission_loss_during_debounce_prevents_upload") {
            let f = try fixture("debounce-permission"), s = try f.session(), d = try CloudDouble(); d.pauseDebounce()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.debounceGate) { d.setPermission(false) }
            try noUpload(result, .permissionLost, f, d)
        }
        await run("debounced_different_record_never_reaches_transport") {
            let f = try fixture("debounce-tamper"), s = try f.session(), d = try CloudDouble(); d.alterDebouncedRecord()
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p)
            let result = await outcome.publication.completion
            try noUpload(result, .invalidRecord, f, d)
        }
        await run("admitted_remote_success_after_editor_retirement_is_retained_without_ack") {
            let f = try fixture("upload-owner"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { s.retire() }
            try success(result); try check(result.pending == .retained(.ownerRetired) && !result.mayDeliverToOriginalOwner, "retired upload was acknowledged/delivered")
            try stillPending(f); try check(d.observation.uploaded.count == 1, "admitted upload retried")
        }
        await run("admitted_remote_success_after_profile_aba_cannot_ack_captured_db") {
            let f = try fixture("upload-profile"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { f.store.disconnect(); f.store.connect() }
            try success(result); try check(result.pending == .retained(.ownerRetired), "old connection acknowledged")
            try stillPending(f)
        }
        await run("admitted_remote_success_after_account_aba_cannot_ack") {
            let f = try fixture("upload-account"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { d.notifyAccountChange(); try d.changeIdentity("fixture-account-a") }
            try success(result); try check(result.pending == .retained(.accountChanged), "account ABA acknowledged")
            try stillPending(f)
        }
        await run("admitted_remote_success_after_permission_loss_cannot_ack") {
            let f = try fixture("upload-permission"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { d.setPermission(false) }
            try success(result); try check(result.pending == .retained(.permissionLost), "permission loss acknowledged")
            try stillPending(f)
        }
        await run("new_same_uuid_revision_during_upload_preserves_newer_pending") {
            let f = try fixture("upload-new-revision"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d), storage = try f.storage()
            let result = try await savePaused(s, p, at: d.uploadGate) {
                let latest = try storage.read()
                let newer = try storage.prepare(snapshot: latest, mutationID: UUID(), body: fixtureBody("newer"), textPreview: "newer local revision", editorRevision: nil)
                let saved = try storage.commit(newer); try check(saved.receipt.revision == 2, "new revision missing")
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "newer pending acknowledged by old upload")
            try stillPending(f); try check(try f.repository.loadAnnotationById(f.annotation.id!)?.note == "newer local revision", "new note erased")
        }
        await run("same_connection_same_second_replacement_refuses_old_ack") {
            let f = try fixture("upload-local-replace"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) {
                try f.db.execute(query: "INSERT OR REPLACE INTO sync_pending(ck_record_id,operation,queued_at) SELECT ck_record_id,operation,queued_at FROM sync_pending WHERE ck_record_id=?;", parameters: [f.annotation.ckRecordId!])
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "same-second replacement lost")
            try stillPending(f)
        }
        await run("foreign_original_pending_replacement_refuses_old_ack") {
            let f = try fixture("upload-foreign-replace"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) {
                let connection = try f.repository.captureLocalEditorConnection()
                let foreign = try SQLiteDatabase(path: connection.databaseURL.path)
                try SyncPendingStore(database: foreign).addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "upload")
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "foreign enqueue acknowledged by old upload")
            try stillPending(f)
        }
        await run("foreign_pending_aba_with_identical_values_refuses_old_ack") {
            let f = try fixture("upload-foreign-aba"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) {
                let connection = try f.repository.captureLocalEditorConnection()
                let foreign = try SQLiteDatabase(path: connection.databaseURL.path)
                try foreign.transaction {
                    try foreign.execute(query: "UPDATE sync_pending SET queued_at=queued_at+1 WHERE ck_record_id=?;", parameters: [f.annotation.ckRecordId!])
                    try foreign.execute(query: "UPDATE sync_pending SET queued_at=queued_at-1 WHERE ck_record_id=?;", parameters: [f.annotation.ckRecordId!])
                }
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "foreign pending ABA acknowledged")
            try stillPending(f)
        }
        await run("unrelated_same_connection_write_conservatively_defers_ack") {
            let f = try fixture("upload-unrelated"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) {
                try f.repository.addPendingSync(ckRecordId: "another-owned-upload", operation: "upload")
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "unrelated write did not defer")
            try stillPending(f)
        }
        await run("original_tag_write_during_upload_defers_ack_and_keeps_tags") {
            let f = try fixture("upload-tags"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { try f.store.addTags(["new-tag"], toAnnotationIDs: [f.annotation.id!]) }
            try success(result); try check(result.pending == .retained(.pendingChanged), "changed original tag acknowledged")
            try stillPending(f); try check(try f.repository.loadAnnotationById(f.annotation.id!)?.tags.contains("new-tag") == true, "new tag lost")
        }
        await run("remote_error_preserves_actual_error_and_original_pending_without_retry") {
            let f = try fixture("upload-failure"), s = try f.session(), d = try CloudDouble(); d.failUpload()
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p)
            let result = await outcome.publication.completion; try failedUpload(result)
            try check(result.pending == .retained(.remoteFailure) && d.observation.uploaded.count == 1, "remote error changed/retried")
            try stillPending(f)
        }
        await run("remote_error_after_retirement_preserves_error_and_refuses_delivery") {
            let f = try fixture("upload-error-owner"), s = try f.session(), d = try CloudDouble(); d.pauseUpload(); d.failUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { s.retire() }
            try failedUpload(result); try check(result.pending == .retained(.ownerRetired) && !result.mayDeliverToOriginalOwner, "retired error delivered/rewritten")
            try stillPending(f)
        }
        await run("no_precommit_worker_request_never_adopts_later_destination") {
            let f = try fixture("worker-no-request"), s = try f.session(), d = try CloudDouble()
            let p = try await prepared(f, s, d); d.setWorkerRequest(workerRequest())
            let outcome = try await s.saveOwnedCloud(p), result = await outcome.publication.completion
            try success(result); guard case .notConfigured = result.worker else { throw LocalCheckFailure("later worker was adopted") }
            try check(d.observation.workerRequests.isEmpty && d.observation.workerWaits == 0, "later worker invoked")
        }
        await run("changed_worker_after_ack_keeps_actual_ack_but_refuses_new_destination") {
            let f = try fixture("worker-change"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerWait()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerWaitGate) { d.setWorkerRequest(workerRequest("other")) }
            try success(result); guard case .notAttempted(.workerChanged) = result.worker else { throw LocalCheckFailure("new worker destination admitted") }
            try check(result.pending == .acknowledged && d.observation.workerRequests.isEmpty, "real ACK lost/new worker sent")
        }
        await run("permission_loss_after_ack_defers_worker_without_rollback_claim") {
            let f = try fixture("worker-permission"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerWait()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerWaitGate) { d.setPermission(false) }
            try success(result); guard case .notAttempted(.permissionLost) = result.worker else { throw LocalCheckFailure("worker permission loss missed") }
            try check(result.pending == .acknowledged && !result.mayDeliverToOriginalOwner, "actual ACK lost or stale delivery")
        }
        await run("account_notification_after_ack_defers_worker_without_rollback_claim") {
            let f = try fixture("worker-account"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerWait()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerWaitGate) { d.notifyAccountChange() }
            try success(result); guard case .notAttempted(.accountChanged) = result.worker else { throw LocalCheckFailure("worker account change missed") }
            try check(result.pending == .acknowledged && !result.mayDeliverToOriginalOwner, "actual ACK lost/stale completion")
        }
        await run("editor_retirement_after_ack_defers_worker_without_rollback_claim") {
            let f = try fixture("worker-owner"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerWait()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerWaitGate) { s.retire() }
            try success(result); guard case .notAttempted(.ownerRetired) = result.worker else { throw LocalCheckFailure("worker retirement missed") }
            try check(result.pending == .acknowledged && !result.mayDeliverToOriginalOwner, "actual ACK lost/stale completion")
        }
        await run("worker_uses_exact_captured_request_and_retains_actual_outcome") {
            let f = try fixture("worker-success"), s = try f.session(), d = try CloudDouble(), request = workerRequest(); d.setWorkerRequest(request)
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p), result = await outcome.publication.completion
            try success(result); guard case .completed = result.worker else { throw LocalCheckFailure("worker actual success lost") }
            try check(result.pending == .acknowledged && result.mayDeliverToOriginalOwner && d.observation.workerRequests == [request], "different/duplicate worker or ACK")
        }
        await run("worker_failure_does_not_rewrite_remote_success_or_committed_ack") {
            let f = try fixture("worker-failure"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.failWorker()
            let p = try await prepared(f, s, d), outcome = try await s.saveOwnedCloud(p), result = await outcome.publication.completion
            try success(result); guard case .failed(let error) = result.worker, error as? CloudBoundaryError == .worker else { throw LocalCheckFailure("worker error lost") }
            try check(result.pending == .acknowledged && d.observation.workerRequests.count == 1, "worker failure retried/rewrote ACK")
        }
        await run("retirement_after_worker_admission_retains_actual_worker_effect") {
            let f = try fixture("worker-inflight"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerSend()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerSendGate) { s.retire() }
            try success(result); guard case .completed = result.worker else { throw LocalCheckFailure("admitted worker result rewritten") }
            try check(result.pending == .acknowledged && !result.mayDeliverToOriginalOwner, "retired completion delivered or ACK erased")
        }
        await run("prepared_operation_is_consumed_once_with_no_duplicate_commit_or_upload") {
            let f = try fixture("one-use"), s = try f.session(), d = try CloudDouble(), p = try await prepared(f, s, d)
            let first = try await s.saveOwnedCloud(p); _ = await first.publication.completion
            try await rejectsAsync(AnnotationLocalEditorCloudDeferral.alreadyConsumed) { _ = try await s.saveOwnedCloud(p) }
            try check(try f.scalar("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions;") == 1 && d.observation.uploaded.count == 1, "preparation replay duplicated effects")
        }
        await run("foreign_session_cannot_consume_preparation_or_steal_original_owner") {
            let f = try fixture("foreign-session"), a = try f.session(), b = try f.session(), d = try CloudDouble(), p = try await prepared(f, a, d)
            try await rejectsAsync(AnnotationLocalEditorError.wrongOwner) { _ = try await b.saveOwnedCloud(p) }
            try check(try !f.ledger.hasInstalledSchema(), "foreign session committed")
            let correct = try await a.saveOwnedCloud(p), result = await correct.publication.completion
            try success(result); try check(result.pending == .acknowledged, "foreign refusal consumed valid preparation")
        }
        await run("retired_before_owned_save_does_not_commit_local_or_remote") {
            let f = try fixture("before-save-retired"), s = try f.session(), d = try CloudDouble(), p = try await prepared(f, s, d)
            s.retire(); try await rejectsAsync(AnnotationLocalEditorError.retired) { _ = try await s.saveOwnedCloud(p) }
            try check(try !f.ledger.hasInstalledSchema() && d.observation.uploaded.isEmpty, "retired save had effects")
        }
        await run("durable_replay_retains_receipt_without_new_publication_witness") {
            let f = try fixture("durable-replay"), storage = try f.storage(), snapshot = try storage.read()
            let intent = try storage.prepare(snapshot: snapshot, mutationID: UUID(), body: fixtureBody(), textPreview: "owned preview", editorRevision: nil)
            let first = try storage.commitForOwnedCloud(intent), second = try storage.commitForOwnedCloud(intent)
            try check(first.witness != nil && second.witness == nil && second.refusal == .durableReplay, "durable replay supplied new transport authority")
            try check(second.saved.receipt.replayed && first.saved.receipt.mutationID == second.saved.receipt.mutationID, "durable original receipt changed")
            try stillPending(f)
        }
        await run("outer_transaction_cannot_masquerade_as_owned_durable_commit") {
            let f = try fixture("outer-transaction"), storage = try f.storage(), snapshot = try storage.read()
            let intent = try storage.prepare(snapshot: snapshot, mutationID: UUID(), body: fixtureBody(), textPreview: "must not commit", editorRevision: nil)
            try f.db.transaction {
                try rejects(AnnotationLocalEditorCloudDeferral.invalidPublication) { _ = try storage.commitForOwnedCloud(intent) }
            }
            try check(try !f.ledger.hasInstalledSchema() && f.rows() == snapshot.source.canonicalBytes, "non-durable nested commit accepted")
        }
        await run("aliased_account_lifetime_refused_without_recursive_lock_or_delete") {
            let f = try fixture("aliased-lifetime"), storage = try f.storage(), snapshot = try storage.read()
            let intent = try storage.prepare(snapshot: snapshot, mutationID: UUID(), body: fixtureBody(), textPreview: "owned preview", editorRevision: nil)
            let committed = try storage.commitForOwnedCloud(intent)
            guard let witness = committed.witness else { throw LocalCheckFailure("valid witness missing") }
            try rejects(AnnotationLocalEditorCloudDeferral.invalidPublication) { _ = try storage.acknowledgeCloud(witness, account: storage.owner) }
            try stillPending(f)
        }
        await run("account_retired_at_locked_entry_preserves_account_changed_category") {
            let f = try fixture("locked-account-retired"), storage = try f.storage(), snapshot = try storage.read()
            let intent = try storage.prepare(snapshot: snapshot, mutationID: UUID(), body: fixtureBody(), textPreview: "owned preview", editorRevision: nil)
            let committed = try storage.commitForOwnedCloud(intent), account = AnnotationLocalEditorLifetime()
            guard let witness = committed.witness else { throw LocalCheckFailure("valid witness missing") }
            account.retire()
            try rejects(AnnotationLocalEditorCloudDeferral.accountChanged) { _ = try storage.acknowledgeCloud(witness, account: account) }
            try stillPending(f)
            try check(storage.isOwned, "account refusal retired the editor or connection")
        }
        await run("new_pending_after_ack_prevents_late_worker_and_delivery") {
            let f = try fixture("post-ack-new-pending"), s = try f.session(), d = try CloudDouble(); d.setWorkerRequest(workerRequest()); d.pauseWorkerWait()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.workerWaitGate) { try f.repository.addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "upload") }
            try success(result); guard case .notAttempted(.pendingChanged) = result.worker else { throw LocalCheckFailure("late worker ignored new pending") }
            try check(result.pending == .acknowledged && !result.mayDeliverToOriginalOwner, "actual earlier ACK rewritten or stale delivery")
            try stillPending(f)
        }
        await run("later_original_delete_is_never_erased_by_successful_old_upload") {
            let f = try fixture("upload-later-delete"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) { try f.repository.addPendingSync(ckRecordId: f.annotation.ckRecordId!, operation: "delete") }
            try success(result); try check(result.pending == .retained(.pendingChanged), "new original deletion acknowledged")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='delete';", [f.annotation.ckRecordId!]) == 1, "new original deletion lost")
        }
        await run("ambiguous_case_variant_pending_is_not_deleted_by_first_match") {
            let f = try fixture("ambiguous-pending"), s = try f.session(), d = try CloudDouble(); d.pauseUpload()
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.uploadGate) {
                try f.db.execute(query: "INSERT INTO sync_pending(ck_record_id,operation,queued_at) VALUES(?, 'upload', 1);", parameters: [f.annotation.ckRecordId!.lowercased()])
            }
            try success(result); try check(result.pending == .retained(.pendingChanged), "ambiguous pending row acknowledged")
            try check(try f.scalar("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? COLLATE NOCASE;", [f.annotation.ckRecordId!]) == 2, "pending ambiguity was deleted")
        }
        await run("account_observation_is_synchronous_one_way_and_owner_scoped") {
            let first = try CloudDouble(), second = try CloudDouble()
            try check(first.account.lifetime.isCurrent && second.account.lifetime.isCurrent, "new observations unavailable")
            first.notifyAccountChange()
            try check(!first.account.lifetime.isCurrent && second.account.lifetime.isCurrent, "notification did not retire synchronously or crossed observer centers")
            try first.changeIdentity("fixture-account-a")
            try check(!first.account.lifetime.isCurrent, "same identity revived retired epoch")
        }
        await run("source_change_during_post_upload_account_lookup_refuses_ack") {
            let f = try fixture("post-upload-lookup"), s = try f.session(), d = try CloudDouble(); d.pauseLookup(3)
            let p = try await prepared(f, s, d)
            let result = try await savePaused(s, p, at: d.lookupGate) { try f.repository.addPendingSync(ckRecordId: "concurrent-during-account-await", operation: "upload") }
            try success(result); try check(result.pending == .retained(.pendingChanged), "post-await source change not rechecked")
            try stillPending(f)
        }
        await run("busy_preparation_rejects_second_operation_without_shared_state_change") {
            let f = try fixture("busy-prepare"), s = try f.session(), d = try CloudDouble(); d.pauseLookup(1)
            let snapshot = try await s.read(), intent = try f.intent(s, snapshot: snapshot)
            let worker = Task { try await s.prepareOwnedCloudSave(intent, client: d.client) }
            do {
                try await d.lookupGate.waitForEntry()
                try await rejectsAsync(AnnotationLocalEditorError.busy) { _ = try await s.prepareOwnedCloudSave(intent, client: d.client) }
                d.lookupGate.release(); let p = try await worker.value
                let outcome = try await s.saveOwnedCloud(p), result = await outcome.publication.completion
                try success(result); try check(d.observation.uploaded.count == 1, "busy path introduced extra upload")
            } catch {
                d.lookupGate.release(); _ = try? await worker.value; throw error
            }
        }
    }
}

@main
struct LocalAnnotationCloudAcceptance {
    @MainActor
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else { throw LocalCheckFailure("one owned fixture root required") }
        let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let report = root.appendingPathComponent("CASES.json")
        guard !FileManager.default.fileExists(atPath: report.path) else { throw LocalCheckFailure("preserve prior result") }
        let cases = CloudCases(root: root)
        await cases.execute()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cases.rows).write(to: report, options: .atomic)
        let failed = cases.rows.filter { $0.status != "PASS" }.count
        print("CLOUD_COMPONENT_RESULT \(cases.rows.count - failed) PASS / \(failed) FAIL")
        if failed != 0 { throw LocalCheckFailure("component failures retained") }
    }
}
