import Foundation
import SQLite3
import OtzariaActionCore

struct CaseResult: Codable, Sendable {
    let name: String
    let status: String
    let milliseconds: Double
    let error: String?
}

@MainActor
final class Acceptance {
    let root: URL
    var results: [CaseResult] = []
    init(root: URL) { self.root = root }

    func test(_ name: String, _ body: () throws -> Void) {
        let began = Date()
        acceptancePrint("RUN \(name)")
        do {
            try body()
            results.append(.init(name: name, status: "PASS", milliseconds: Date().timeIntervalSince(began) * 1000, error: nil))
            acceptancePrint("PASS \(name)")
        } catch {
            results.append(.init(name: name, status: "FAIL", milliseconds: Date().timeIntervalSince(began) * 1000, error: String(describing: error)))
            acceptancePrint("FAIL \(name): \(error)")
        }
    }

    func asyncTest(_ name: String, _ body: () async throws -> Void) async {
        let began = Date()
        acceptancePrint("RUN \(name)")
        do {
            try await body()
            results.append(.init(name: name, status: "PASS", milliseconds: Date().timeIntervalSince(began) * 1000, error: nil))
            acceptancePrint("PASS \(name)")
        } catch {
            results.append(.init(name: name, status: "FAIL", milliseconds: Date().timeIntervalSince(began) * 1000, error: String(describing: error)))
            acceptancePrint("FAIL \(name): \(error)")
        }
    }

    func run() async throws {
        test("actual_platform_SHA256_known_vectors") {
            try require(AcceptanceDigest().sha256(Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "empty vector")
            try require(AcceptanceDigest().sha256(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "abc vector")
        }
        test("constructor_is_inert_and_capability_stays_off") {
            let f = try Fixture(root: root, name: "inert", install: false)
            let before = try f.originals()
            try require(!AnnotationExchangeCapability.liveExchangeEnabled, "live capability enabled")
            try require(f.scalar("SELECT count(*) FROM sqlite_master WHERE name LIKE 'otzaria_annotation_exchange_%';") == 0, "constructor migrated")
            try rejects(.schemaMismatch) { _ = try f.ledger.pending(for: scope()) }
            try require(f.originals() == before, "original data changed")
            try f.ledger.installSchema(); try f.ledger.installSchema()
            try require(f.originals() == before, "explicit install changed original data")
        }
        test("exact_rich_bytes_preview_and_unknown_fields_survive_reopen") {
            let f = try Fixture(root: root, name: "rich")
            let original = try f.originals(), source = try f.witness()
            let rich = Data([0, 255, 13, 10] + Array("בְּרֵאשִׁית\n<strong>body</strong>".utf8))
            let bytes = try f.payload(source, rich: rich, extra: true)
            guard case .supported(let decoded, let retained) = try TorahAnnotationEnvelopeCodec.decode(bytes) else { throw CheckFailure("supported became unknown") }
            try require(decoded.richBody?.bytes == rich && retained == bytes, "lossy rich decode")
            try require(decoded.textPreview == "תצוגה בלבד", "preview overwritten by body")
            let commit = try f.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: source, expectedRevision: 0, destinations: [scope()])
            let reopened = try Fixture(root: root, name: "rich", create: false)
            let delivery = try reopened.ledger.pending(for: scope()).first
            try require(delivery?.payload == bytes && delivery?.messageID == commit.deliveries[0].messageID, "reopen changed exact bytes or receipt")
            try require(reopened.originals() == original, "ledger touched original rows")
            try bytes.write(to: root.appendingPathComponent("rich-payload.json"))
            try Data(commit.payloadDigest.utf8).write(to: root.appendingPathComponent("rich-payload.sha256"))
        }
        test("unknown_version_is_exact_quarantine_without_execution") {
            let f = try Fixture(root: root, name: "unknown")
            let before = try f.originals()
            let bytes = Data("{ \"schemaVersion\": 98, \"future\": [\"אבג\", 18446744073709551615], \"opaque\":true }\n".utf8)
            guard case .unsupported(let version, let exact) = try TorahAnnotationEnvelopeCodec.decode(bytes) else { throw CheckFailure("unknown accepted") }
            try require(version == 98 && exact == bytes, "unknown bytes changed")
            let hash = try AcceptanceDigest().sha256(bytes), message = UUID()
            try require(f.ledger.recordIncoming(messageID: message, destination: scope(), namespace: namespace,
                annotationUUID: f.uuid, revision: 7, payload: bytes, expectedDigest: hash), "unknown not stored")
            let reopened = try Fixture(root: root, name: "unknown", create: false)
            try require(reopened.ledger.incomingBytes(messageID: message, destination: scope()) == bytes, "unknown bytes lost")
            try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_inbox WHERE status='unsupported';") == 1, "unknown not quarantined")
            try require(reopened.ledger.pending(for: scope()).isEmpty, "unknown generated outbox")
            try require(reopened.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 0, "unknown advanced head")
            try rejects(.unsupportedVersion(98)) {
                _ = try f.ledger.commit(mutationID: UUID(), payload: bytes, expectedSource: f.witness(), expectedRevision: 0, destinations: [scope()])
            }
            try require(reopened.originals() == before, "unknown applied data")
        }
        test("all_original_handles_close_before_reopen_and_retry") {
            var saved: AnnotationExchangeCommit?
            var source: AnnotationExchangeSourceWitness?
            var bytes = Data(), originals = Data()
            do {
                let f = try Fixture(root: root, name: "closed")
                let witness = try f.witness()
                bytes = try f.payload(witness); source = witness; originals = try f.originals()
                saved = try f.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: witness,
                    expectedRevision: 0, destinations: [scope()])
            }
            // Only value receipts/witnesses survive this scope; neither stores
            // a database or ledger reference. The original handle has closed.
            let reopened = try Fixture(root: root, name: "closed", create: false)
            guard let source, let saved else { throw CheckFailure("missing test receipt") }
            let retried = try reopened.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: source,
                expectedRevision: 0, destinations: [scope()])
            try require(retried.replayed && retried.deliveries == saved.deliveries, "closed/reopened idempotency lost")
            try require(reopened.originals() == originals, "original rows changed across close")
        }
        test("duplicate_escaped_keys_malformed_UTF8_and_numbers_are_rejected") {
            let inputs = [Data("{\"schemaVersion\":1,\"schema\\u0056ersion\":2}".utf8),
                          Data([123,34,115,99,104,101,109,97,86,101,114,115,105,111,110,34,58,49,44,34,120,34,58,34,255,34,125]),
                          Data("{\"schemaVersion\":1.5}".utf8), Data("{\"schemaVersion\":0}".utf8),
                          Data("{\"schemaVersion\":-1}".utf8), Data("{\"schemaVersion\":\"1\"}".utf8)]
            for bytes in inputs { try rejects(.invalidEnvelope) { _ = try TorahAnnotationEnvelopeCodec.decode(bytes) } }
        }
        test("invalid_UUID_base64_types_and_scope_are_rejected") {
            let f = try Fixture(root: root, name: "invalid")
            let valid = try ActionWireCodec.decodeObject(f.payload())
            for field in ["annotationUUID", "namespace", "originatingApp"] {
                var bad = valid; bad[field] = .string("invalid identity / whitespace")
                try rejects(.invalidEnvelope) { _ = try TorahAnnotationEnvelopeCodec.decode(AnnotationExchangeValidation.canonical(.object(bad))) }
            }
            var bad = valid
            bad["richBody"] = .object(["format": .string("x"), "formatVersion": .integer(1), "bytesBase64": .string("YQ")])
            try rejects(.invalidEnvelope) { _ = try TorahAnnotationEnvelopeCodec.decode(AnnotationExchangeValidation.canonical(.object(bad))) }
            try rejects(.invalidScope) { _ = try scope("a b") }
            try rejects(.invalidScope) { _ = try scope("", "space") }
            try rejects(.invalidScope) { _ = try f.commit(destinations: [scope(), scope()]) }
        }
        test("oversized_payload_fails_intact_without_rows") {
            let f = try Fixture(root: root, name: "oversize"), before = try f.originals()
            let bytes = Data(repeating: 65, count: TorahAnnotationEnvelopeCodec.maximumBytes + 1)
            try rejects(.payloadTooLarge) { _ = try TorahAnnotationEnvelopeCodec.decode(bytes) }
            try rejects(.payloadTooLarge) {
                _ = try f.ledger.recordIncoming(messageID: UUID(), destination: scope(), namespace: namespace,
                    annotationUUID: f.uuid, revision: 1, payload: bytes, expectedDigest: String(repeating: "0", count: 64))
            }
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_inbox;") == 0, "oversize stored")
            try require(f.originals() == before, "oversize modified source")
        }
        test("schema_constraints_reject_fractional_revision_and_invalid_status") {
            let f = try Fixture(root: root, name: "constraints")
            try sqliteRejects { try f.db.execute(query: "INSERT INTO otzaria_annotation_exchange_heads VALUES (?, ?, 1.5);", parameters: [namespace, f.uuid.uuidString]) }
            try sqliteRejects { try f.db.execute(query: "INSERT INTO otzaria_annotation_exchange_heads VALUES (?, ?, 0);", parameters: [namespace, f.uuid.uuidString]) }
            let c = try f.commit()
            try sqliteRejects { try f.db.execute(query: "UPDATE otzaria_annotation_exchange_outbox SET status='delivered';") }
            try sqliteRejects { try f.db.execute(query: "INSERT INTO otzaria_annotation_exchange_outbox SELECT * FROM otzaria_annotation_exchange_outbox;") }
            try require(f.ledger.pending(for: scope()).first?.messageID == c.deliveries[0].messageID, "constraints changed valid row")
        }
        test("unknown_ledger_schema_fails_closed") {
            let f = try Fixture(root: root, name: "future-schema", install: false)
            try f.db.execute(query: "CREATE TABLE otzaria_annotation_exchange_schema(singleton INTEGER,version INTEGER);")
            try f.db.execute(query: "INSERT INTO otzaria_annotation_exchange_schema VALUES (1,99);")
            try rejects(.schemaMismatch) { try f.ledger.installSchema() }
            try require(f.scalar("SELECT count(*) FROM sqlite_master WHERE name='otzaria_annotation_exchange_heads';") == 0, "failed install leaked schema")
        }
        test("missing_or_ambiguous_original_UUID_is_not_backfilled") {
            let f = try Fixture(root: root, name: "identity")
            try f.db.execute(query: "UPDATE annotations SET ckRecordId=NULL;")
            try require(!f.witness().exists, "missing identity invented")
            try require(f.scalar("SELECT count(*) FROM annotations WHERE ckRecordId IS NULL;") == 1, "UUID backfilled")
            try f.db.execute(query: "UPDATE annotations SET ckRecordId=?;", parameters: [f.uuid.uuidString])
            try f.db.execute(query: "INSERT INTO annotations(id,ckRecordId) VALUES (2,?);", parameters: [f.uuid.uuidString.lowercased()])
            try rejects(.ambiguousSource) { _ = try f.witness() }
            try require(f.scalar("SELECT count(*) FROM annotations;") == 2, "duplicate repaired destructively")
        }
        test("same_second_source_edit_rejects_stale_witness") {
            let f = try Fixture(root: root, name: "same-second"), old = try f.witness()
            let payload = try f.payload(old)
            try f.db.execute(query: "UPDATE annotations SET note='changed in same second' WHERE id=1;")
            try require(f.scalar("SELECT lastModified FROM annotations WHERE id=1;") == 1700000001, "fixture changed clock")
            try require(f.witness().digest != old.digest, "same-second edit invisible")
            try rejects(.staleSource) { _ = try f.ledger.commit(mutationID: UUID(), payload: payload, expectedSource: old, expectedRevision: 0, destinations: [scope()]) }
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 0, "stale advanced head")
        }
        test("tag_locator_and_embedded_NUL_each_change_source_witness") {
            let f = try Fixture(root: root, name: "source-bytes")
            let original = try f.witness()
            try f.db.execute(query: "UPDATE tags SET name='tag changed';")
            let tag = try f.witness(); try require(tag.digest != original.digest, "tag omitted")
            try f.db.execute(query: "UPDATE annotations SET backendLocator='different opaque locator';")
            let locator = try f.witness(); try require(locator.digest != tag.digest, "locator omitted")
            try f.db.execute(query: "UPDATE annotations SET note=CAST(X'410042' AS TEXT);")
            let nulB = try f.witness()
            try f.db.execute(query: "UPDATE annotations SET note=CAST(X'410043' AS TEXT);")
            let nulC = try f.witness(); try require(nulB.digest != nulC.digest, "C-string truncation in source witness")
            try f.db.execute(query: "UPDATE annotations SET note=CAST(X'41FF43' AS TEXT);")
            try require(f.witness().digest != nulC.digest, "invalid UTF8 source bytes collapsed")
        }
        test("source_metadata_and_revision_mismatch_do_not_write") {
            let f = try Fixture(root: root, name: "mismatch")
            let old = try f.witness(), bytes = try f.payload(old)
            var object = try ActionWireCodec.decodeObject(bytes)
            object["source"] = .object(["state": .string("present"), "snapshotSHA256": .string(String(repeating: "0", count: 64))])
            try rejects(.staleSource) { _ = try f.ledger.commit(mutationID: UUID(), payload: AnnotationExchangeValidation.canonical(.object(object)), expectedSource: old, expectedRevision: 0, destinations: [scope()]) }
            try rejects(.staleRevision) { _ = try f.ledger.commit(mutationID: UUID(), payload: bytes, expectedSource: old, expectedRevision: 1, destinations: [scope()]) }
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_versions;") == 0, "mismatch wrote version")
        }
        test("dangling_original_tag_link_changes_witness_and_rejects_stale_commit") {
            let f = try Fixture(root: root, name: "dangling-tag")
            let old = try f.witness(), bytes = try f.payload(old)
            try f.db.execute(query: "INSERT INTO annotation_tags(annotationId,tagId) VALUES (1,987654321);")
            try require(f.witness().digest != old.digest, "dangling original tag association omitted from source witness")
            try rejects(.staleSource) {
                _ = try f.ledger.commit(mutationID: UUID(), payload: bytes, expectedSource: old, expectedRevision: 0, destinations: [scope()])
            }
        }
        test("idempotent_retry_binds_exact_payload_and_destination_set") {
            let f = try Fixture(root: root, name: "idempotency")
            let a = try scope(), b = try scope("account-b"), w = try f.witness(), bytes = try f.payload(w)
            let first = try f.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: w, expectedRevision: 0, destinations: [a,b])
            let second = try f.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: w, expectedRevision: 0, destinations: [b,a])
            try require(second.replayed && first.deliveries == second.deliveries && second.revision == 1, "retry changed receipt")
            try rejects(.idempotencyConflict) { _ = try f.ledger.commit(mutationID: fixedMutationID, payload: f.payload(w, preview: "different"), expectedSource: w, expectedRevision: 0, destinations: [a,b]) }
            try rejects(.idempotencyConflict) { _ = try f.ledger.commit(mutationID: fixedMutationID, payload: bytes, expectedSource: w, expectedRevision: 0, destinations: [a]) }
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_outbox;") == 2, "retry duplicated messages")
        }
        test("ACK_is_bound_to_destination_account_space_UUID_revision_digest_and_message") {
            let f = try Fixture(root: root, name: "acks")
            let original = try f.originals(), a = try scope(), b = try scope("account-b")
            let c = try f.commit(destinations: [a,b]), d = c.deliveries.first { $0.destination == a }!
            let invalid = [ack(d, destination: b), ack(d, destination: try scope("account-a", "space-other")),
                ack(d, destination: try scope("account-a", "space-a", "another-app")), ack(d, uuid: UUID()),
                ack(d, revision: 2), ack(d, digest: String(repeating: "0", count: 64)), ack(d, messageID: UUID()),
                ack(d, envelopeNamespace: "other.namespace")]
            for receipt in invalid { try rejects(.receiptMismatch) { _ = try f.ledger.acknowledge(receipt) } }
            try require(f.ledger.pending(for: a).count == 1 && f.ledger.pending(for: b).count == 1, "wrong ACK consumed message")
            try require(f.ledger.acknowledge(ack(d)), "correct ACK no-op")
            try require(!f.ledger.acknowledge(ack(d)), "duplicate ACK changed state")
            try require(f.ledger.pending(for: a).isEmpty && f.ledger.pending(for: b).count == 1, "cross-destination effect")
            try require(f.originals() == original, "ACK changed original/CloudKit rows")
        }
        test("old_ACK_does_not_consume_newer_revision_or_account") {
            let f = try Fixture(root: root, name: "old-ack"), before = try f.cloudRows()
            let one = try f.commit(), two = try f.commit(expectedRevision: 1, preview: "newer")
            try f.ledger.acknowledge(ack(one.deliveries[0]))
            try require(f.ledger.pending(for: scope()).map(\.messageID) == two.deliveries.map(\.messageID), "newer message consumed")
            try require(f.ledger.pending(for: scope("signed-in-new-account")).isEmpty, "old account visible as new")
            try require(f.cloudRows() == before, "CloudKit queue ACKed")
        }
        test("nested_enqueue_failure_rolls_back_source_cloud_queue_and_ledger") {
            let f = try Fixture(root: root, name: "enqueue-failure"), before = try f.originals()
            let fault = ExchangeWriteFault(.rejectOutbox)
            let pointer = Unmanaged.passUnretained(fault).toOpaque()
            try require(sqlite3_set_authorizer(f.db.dbPointer, authorizeExchangeWriteFault, pointer) == SQLITE_OK,
                        "SQLite authorizer registration failed")
            sqlite3_update_hook(f.db.dbPointer, observeExchangeWriteFault, pointer)
            defer {
                sqlite3_set_authorizer(f.db.dbPointer, nil, nil)
                sqlite3_update_hook(f.db.dbPointer, nil, nil)
            }
            var sawExpected = false
            do {
                try f.db.transaction {
                    try f.db.execute(query: "UPDATE annotations SET note='outer mutation';")
                    try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "delete")
                    _ = try f.commit()
                }
            } catch let error as SQLiteError {
                sawExpected = error.localizedDescription.contains("not authorized")
            }
            let observed = fault.observation
            try require(sawExpected && observed.deniedOutboxAuthorizations == 1
                        && observed.outboxWasAttemptedAfterVersionAndHead,
                        "did not reach failing outbox INSERT after actual version/head writes")
            try JSONEncoder().encode(observed).write(to: root.appendingPathComponent("enqueue-failure-hook.json"))
            try require(f.originals() == before, "outer source/CloudKit transaction leaked")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_versions;") == 0, "version survived failed enqueue")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_heads;") == 0, "head survived failed enqueue")
        }
        test("outer_failure_after_inner_release_rolls_back_everything") {
            let f = try Fixture(root: root, name: "outer-failure"), before = try f.originals()
            do {
                try f.db.transaction {
                    try f.db.execute(query: "UPDATE annotations SET note='outer write';")
                    try f.queue.addPendingSync(ckRecordId: "new-cloud-row", operation: "upload")
                    _ = try f.commit()
                    throw CheckFailure("intentional outer failure")
                }
            } catch let failure as CheckFailure { try require(failure.description == "intentional outer failure", "unexpected error") }
            try require(f.originals() == before, "released SAVEPOINT escaped outer rollback")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_outbox;") == 0, "inner messages committed")
        }
        test("successful_outer_transaction_preserves_original_cloud_queue_semantics") {
            let f = try Fixture(root: root, name: "outer-success")
            var cloudBeforeLedger = Data()
            try f.db.transaction {
                try f.db.execute(query: "UPDATE annotations SET note='saved source';")
                try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "upload")
                cloudBeforeLedger = try f.cloudRows()
                _ = try f.commit()
            }
            try require(f.cloudRows() == cloudBeforeLedger, "ledger altered original pending queue")
            try require(f.queue.fetchPendingSync(operation: "delete") == ["unrelated-deletion"], "original delete-wins semantics changed")
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 1, "outer commit lost ledger")
            try cloudBeforeLedger.write(to: root.appendingPathComponent("cloud-before-ledger.json"))
            try f.cloudRows().write(to: root.appendingPathComponent("cloud-after-ledger.json"))
        }
        test("tombstone_requires_prior_identity_and_absent_original_source") {
            let f = try Fixture(root: root, name: "tombstone")
            let firstWitness = try f.witness(), firstBytes = try f.payload(firstWitness)
            let original = try f.ledger.commit(mutationID: fixedMutationID, payload: firstBytes, expectedSource: firstWitness, expectedRevision: 0, destinations: [scope()])
            try f.db.transaction {
                try f.db.execute(query: "DELETE FROM annotation_tags WHERE annotationId=1;")
                try f.db.execute(query: "DELETE FROM annotations WHERE id=1;")
                try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "delete")
                let missing = try f.witness()
                let tombstone = try f.ledger.commit(mutationID: UUID(), payload: f.payload(missing, state: .tombstone), expectedSource: missing, expectedRevision: 1, destinations: [scope()])
                try require(tombstone.revision == 2, "tombstone revision")
            }
            let deleted = try f.originals()
            let oldRetry = try f.ledger.commit(mutationID: fixedMutationID, payload: firstBytes, expectedSource: firstWitness, expectedRevision: 0, destinations: [scope()])
            try require(oldRetry.replayed && oldRetry.deliveries == original.deliveries, "old retry not stable")
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 2, "old retry resurrected head")
            try require(f.originals() == deleted, "old retry resurrected source")
            let absent = try Fixture(root: root, name: "never-existed")
            try absent.db.execute(query: "DELETE FROM annotations;")
            let witness = try absent.witness()
            try rejects(.missingSource) { _ = try absent.ledger.commit(mutationID: UUID(), payload: absent.payload(witness, state: .tombstone), expectedSource: witness, expectedRevision: 0, destinations: [scope()]) }
        }
        test("known_inbox_is_review_only_exact_idempotent_and_account_scoped") {
            let f = try Fixture(root: root, name: "inbox"), before = try f.originals()
            let bytes = try f.payload(extra: true), hash = try AcceptanceDigest().sha256(bytes), id = UUID()
            try require(f.ledger.recordIncoming(messageID: id, destination: scope(), namespace: namespace, annotationUUID: f.uuid, revision: 1, payload: bytes, expectedDigest: hash), "first inbox")
            try require(!f.ledger.recordIncoming(messageID: id, destination: scope(), namespace: namespace, annotationUUID: f.uuid, revision: 1, payload: bytes, expectedDigest: hash), "duplicate inbox")
            let changed = try f.payload(preview: "conflict")
            try rejects(.idempotencyConflict) { _ = try f.ledger.recordIncoming(messageID: id, destination: scope(), namespace: namespace, annotationUUID: f.uuid, revision: 1, payload: changed, expectedDigest: AcceptanceDigest().sha256(changed)) }
            try require(f.ledger.incomingBytes(messageID: id, destination: scope("account-b")) == nil, "cross account inbox leaked")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_inbox WHERE status='pending_review';") == 1, "known auto-applied")
            try require(f.ledger.pending(for: scope()).isEmpty && f.originals() == before, "inbox changed original or emitted ACK")
        }
        test("incoming_digest_and_identity_mismatch_are_rejected") {
            let f = try Fixture(root: root, name: "inbox-mismatch"), bytes = try f.payload(), hash = try AcceptanceDigest().sha256(bytes)
            try rejects(.receiptMismatch) { _ = try f.ledger.recordIncoming(messageID: UUID(), destination: scope(), namespace: namespace, annotationUUID: f.uuid, revision: 1, payload: bytes, expectedDigest: String(repeating: "0", count: 64)) }
            try rejects(.receiptMismatch) { _ = try f.ledger.recordIncoming(messageID: UUID(), destination: scope(), namespace: namespace, annotationUUID: UUID(), revision: 1, payload: bytes, expectedDigest: hash) }
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_inbox;") == 0, "mismatch stored")
        }
        test("corrupt_payload_and_orphan_outbox_fail_closed") {
            let f = try Fixture(root: root, name: "corruption"), c = try f.commit()
            try f.db.execute(query: "UPDATE otzaria_annotation_exchange_versions SET payload_digest=?;", parameters: [String(repeating: "0", count: 64)])
            try rejects(.corruptRecord) { _ = try f.ledger.pending(for: scope()) }
            try f.db.execute(query: "UPDATE otzaria_annotation_exchange_versions SET payload_digest=?;", parameters: [c.payloadDigest])
            try f.db.execute(query: "DELETE FROM otzaria_annotation_exchange_versions;")
            try rejects(.corruptRecord) { _ = try f.ledger.pending(for: scope()) }
            try rejects(.corruptRecord) { _ = try f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) }
        }
        await asyncTest("pre_cancelled_commit_and_ACK_do_not_write") {
            let f = try Fixture(root: root, name: "cancel-before"), original = try f.originals()
            let w = try f.witness(), bytes = try f.payload(w), a = try scope()
            let task = Task.detached {
                withUnsafeCurrentTask { $0?.cancel() }
                return try f.ledger.commit(mutationID: UUID(), payload: bytes, expectedSource: w, expectedRevision: 0, destinations: [a])
            }
            do { _ = try await task.value; throw CheckFailure("cancelled commit succeeded") }
            catch is CancellationError {}
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_versions;") == 0, "cancelled commit wrote")
            let committed = try f.commit(), receipt = ack(committed.deliveries[0])
            let ackTask = Task.detached {
                withUnsafeCurrentTask { $0?.cancel() }
                return try f.ledger.acknowledge(receipt)
            }
            do { _ = try await ackTask.value; throw CheckFailure("cancelled ACK succeeded") }
            catch is CancellationError {}
            try require(f.ledger.pending(for: a).count == 1 && f.originals() == original, "cancelled ACK consumed data")
        }
        await asyncTest("cancellation_after_real_enqueue_rolls_back_before_commit") {
            let f = try Fixture(root: root, name: "cancel-after-insert"), before = try f.originals()
            let fault = ExchangeWriteFault(.cancelAfterOutbox)
            let pointer = Unmanaged.passUnretained(fault).toOpaque()
            sqlite3_update_hook(f.db.dbPointer, observeExchangeWriteFault, pointer)
            defer { sqlite3_update_hook(f.db.dbPointer, nil, nil) }
            let task = Task.detached { try f.commit() }
            do { _ = try await task.value; throw CheckFailure("cancelled insert committed") }
            catch is CancellationError {}
            let observed = fault.observation
            try require(observed.cancellationsAfterOutboxInsert == 1
                        && observed.insertedTables.filter({ $0 == "otzaria_annotation_exchange_outbox" }).count == 1
                        && observed.insertedTables.contains("otzaria_annotation_exchange_versions")
                        && observed.insertedTables.contains("otzaria_annotation_exchange_heads")
                        && observed.insertedRowIDs.allSatisfy({ $0 > 0 }),
                        "cancellation did not follow actual outbox/version/head inserts")
            try JSONEncoder().encode(observed).write(to: root.appendingPathComponent("enqueue-cancellation-hook.json"))
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_outbox;") == 0, "cancellation left outbox")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_heads;") == 0 && f.originals() == before, "cancellation leaked head/source")
        }
        await asyncTest("eight_concurrent_same_revision_writers_have_one_atomic_winner") {
            let f = try Fixture(root: root, name: "concurrent"), before = try f.cloudRows()
            let w = try f.witness(), bytes = try f.payload(w), a = try scope()
            let outcomes = await withTaskGroup(of: String.self, returning: [String].self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        do {
                            _ = try f.ledger.commit(mutationID: UUID(), payload: bytes, expectedSource: w, expectedRevision: 0, destinations: [a])
                            return "committed"
                        } catch AnnotationExchangeError.staleRevision { return "staleRevision" }
                        catch { return "UNEXPECTED \(error)" }
                    }
                }
                var values: [String] = []; for await value in group { values.append(value) }; return values
            }
            try require(outcomes.filter { $0 == "committed" }.count == 1 && outcomes.filter { $0 == "staleRevision" }.count == 7, "unexpected outcomes \(outcomes)")
            try require(f.ledger.pending(for: a).count == 1 && f.cloudRows() == before, "concurrent duplication/CloudKit change")
        }
        linkedSyncCases()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(results).write(to: root.appendingPathComponent("CASES.json"))
        acceptancePrint("CASES \(results.count) PASS \(results.filter { $0.status == "PASS" }.count) FAIL \(results.filter { $0.status == "FAIL" }.count)")
        if results.contains(where: { $0.status == "FAIL" }) { throw CheckFailure("acceptance case failures") }
    }
}

@main
struct AnnotationExchangeAcceptanceMain {
    static func main() async {
        do { try await run() }
        catch { acceptancePrint("FAILED: \(error)"); failAcceptance() }
    }

    static func run() async throws {
        guard CommandLine.arguments.count == 3 else { throw CheckFailure("usage: executable MODE OWNED_FIXTURE_DIRECTORY") }
        let mode = CommandLine.arguments[1], root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        acceptancePrint("ACTUAL_SQLITE \(String(cString: sqlite3_libversion()))")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if mode == "self-tests" { try await Acceptance(root: root).run(); return }
        if mode == "linked-sync-only" {
            let acceptance = await Acceptance(root: root)
            await acceptance.linkedSyncCases()
            let results = await acceptance.results
            try JSONEncoder().encode(results).write(to: root.appendingPathComponent("CASES.json"))
            acceptancePrint("LINKED CASES \(results.count) PASS \(results.filter { $0.status == "PASS" }.count)")
            if results.contains(where: { $0.status != "PASS" }) { throw CheckFailure("linked component case failure") }
            return
        }
        if mode == "linked-consent-only" {
            let acceptance = await Acceptance(root: root)
            await acceptance.linkedConsentCases()
            let results = await acceptance.results
            try JSONEncoder().encode(results).write(to: root.appendingPathComponent("CASES.json"))
            acceptancePrint("CONSENT CASES \(results.count) PASS \(results.filter { $0.status == "PASS" }.count)")
            if results.count != 7 || results.contains(where: { $0.status != "PASS" }) {
                throw CheckFailure("linked consent component case failure")
            }
            return
        }
        if mode == "crash-after-commit" || mode == "crash-before-outer-commit" {
            let phase = mode == "crash-after-commit" ? "after" : "before"
            let f = try Fixture(root: root, name: "crash-\(phase)")
            // AnnotationRepository.connect uses this original API. Verify the
            // actual mode because its public method intentionally ignores errors.
            f.db.enableWALMode()
            let mode = try f.db.fetch(query: "PRAGMA journal_mode;") { $0.string(at: 0) }.first ?? nil
            try require(mode == "wal", "actual app WAL mode unavailable")
            acceptancePrint("CRASH_JOURNAL_MODE wal; synchronous=\(try f.scalar("PRAGMA synchronous;"))")
            let originals = try f.originals(), cloud = try f.cloudRows()
            if phase == "after" {
                let commit = try f.commit(fixedMutationID)
                try writeCrashReceipt(f, phase: phase, commit: commit, originals: originals, cloudRows: cloud, root: root)
                abruptlyTerminate()
            }
            try f.db.transaction {
                try f.db.execute(query: "UPDATE annotations SET note='uncommitted source';")
                try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "delete")
                let commit = try f.commit(fixedMutationID)
                try writeCrashReceipt(f, phase: phase, commit: commit, originals: originals, cloudRows: cloud, root: root)
                abruptlyTerminate()
            }
            throw CheckFailure("crash path unexpectedly returned")
        }
        if mode == "verify-crash-after" || mode == "verify-crash-before" {
            let phase = mode.hasSuffix("after") ? "after" : "before"
            let receipt = try JSONDecoder().decode(CrashReceipt.self, from: Data(contentsOf: root.appendingPathComponent("crash-\(phase).json")))
            let f = try Fixture(root: root, name: "crash-\(phase)", create: false)
            try require(f.originals().base64EncodedString() == receipt.originalsBase64, "crash changed original rows")
            try require(f.cloudRows().base64EncodedString() == receipt.cloudRowsBase64, "crash changed CloudKit queue")
            if phase == "after" {
                let pending = try f.ledger.pending(for: scope())
                try require(pending.count == 1 && pending[0].messageID == receipt.messageID && pending[0].payloadDigest == receipt.payloadDigest && pending[0].payload.base64EncodedString() == receipt.payloadBase64, "committed delivery lost after process termination")
                let retried = try f.commit(receipt.mutationID)
                try require(retried.replayed && retried.deliveries == pending && retried.revision == 1, "post-crash retry duplicated")
            } else {
                try require(f.ledger.pending(for: scope()).isEmpty, "uncommitted delivery survived process termination")
                try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 0, "uncommitted head survived")
                let committed = try f.commit(receipt.mutationID)
                try require(!committed.replayed && committed.revision == 1, "rollback lost ability to retry")
            }
            acceptancePrint("PASS actual_process_termination_\(phase)_commit_reopen")
            return
        }
        throw CheckFailure("unknown mode \(mode)")
    }
}


// Real SQLite durability tests of the Host ledger. The test origins are data,
// not SDK receipts, and confer no native, account, network or UI acceptance.
private func linkedOrigin(_ space: String = "space-a", root: String = String(repeating: "a", count: 64)) throws -> AnnotationExchangeNativeReadOrigin {
    .init(destination: try scope("account-a", space, "anytype.original"), objectID: "native-object-" + space,
          nativeRootSHA256: root, nativeResponseSHA256: String(repeating: "b", count: 64))
}

private func localLinkedCommit(_ f: Fixture, origin: AnnotationExchangeNativeReadOrigin? = nil,
                               enableLink: Bool = false, revision: Int64, mutation: UUID = UUID(),
                               expectedConsent: AnnotationExchangeNativeConsentObservation? = nil) throws -> AnnotationExchangeVersion {
    var result: AnnotationExchangeVersion?
    try f.db.transaction {
        let source = try f.witness()
        _ = try f.ledger.commitLocal(mutationID: mutation, payload: f.payload(source, preview: "revision \(revision + 1)"),
                                     expectedSource: source, expectedRevision: revision)
        guard let version = try f.ledger.version(mutationID: mutation) else { throw CheckFailure("missing immutable local version") }
        if let origin {
            let consent = try expectedConsent ?? f.ledger.nativeConsentObservation(namespace: namespace, annotationUUID: f.uuid)
            try f.ledger.acceptNativeOrigin(origin, version: version, enableLink: enableLink, expectedConsent: consent)
        }
        try f.ledger.enqueueLinkedVersion(version, suppressing: origin)
        result = version
    }
    guard let result else { throw CheckFailure("missing actual commit") }
    return result
}

extension Acceptance {
    func linkedSyncCases() {
        test("unlinked_save_preserves_empty_destinations_and_creates_no_link_schema") {
            let f = try Fixture(root: root, name: "linked-off"), before = try f.originals()
            let version = try localLinkedCommit(f, revision: 0)
            try require(version.destinationsJSON == "[]" && !f.ledger.hasLinkedSyncSchema(), "unlinked save acquired a destination")
            try require(f.ledger.pending(for: linkedOrigin().destination).isEmpty && f.originals() == before, "unlinked side effect")
        }
        test("opt_in_origin_is_atomic_and_does_not_echo_to_its_native_copy") {
            let f = try Fixture(root: root, name: "linked-origin"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let links = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)
            try require(links.count == 1 && links[0].objectID == origin.objectID, "actual origin lost")
            try require(f.ledger.pending(for: origin.destination).isEmpty, "received body echoed to origin")
            let version = try localLinkedCommit(f, revision: 1)
            let pending = try f.ledger.linkedDeliveries(for: links[0])
            try require(pending.count == 1 && pending[0].delivery.payload == version.payload && pending[0].state == .pending, "saved immutable body not queued")
            let replay = try f.ledger.commitLocal(mutationID: version.mutationID, payload: version.payload,
                                                  expectedSource: f.witness(), expectedRevision: 1)
            try require(replay.replayed && replay.deliveries.isEmpty, "local replay changed creation scope")
            try require(f.ledger.pending(for: origin.destination).count == 1, "local replay duplicated delivery")
        }
        test("outer_save_rollback_removes_body_and_linked_delivery_together") {
            let f = try Fixture(root: root, name: "linked-rollback"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let before = try f.originals()
            do {
                try f.db.transaction {
                    try f.db.execute(query: "UPDATE annotations SET note='rolled back linked save';")
                    try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "upload")
                    _ = try localLinkedCommit(f, revision: 1)
                    throw CheckFailure("deliberate outer rollback")
                }
            } catch let error as CheckFailure { try require(error.description == "deliberate outer rollback", "wrong failure") }
            try require(f.originals() == before && f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 1, "Save rollback leaked original source/body")
            try require(f.ledger.pending(for: origin.destination).isEmpty, "Save rollback leaked delivery")
        }
        test("linked_saved_revisions_coalesce_without_acknowledging_older_bytes") {
            let f = try Fixture(root: root, name: "linked-coalesce"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let newest = try localLinkedCommit(f, revision: 2)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let items = try f.ledger.linkedDeliveries(for: link)
            try require(items.count == 2 && items[0].state == .superseded && items[1].state == .pending, "coalescing lost ordered states")
            try require(!items[0].delivery.acknowledged && items[1].delivery.payload == newest.payload, "superseded body received a fake ACK")
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_versions;") == 3, "immutable history lost")
        }
        test("linked_backoff_and_uncertain_dispatch_survive_fresh_connection") {
            let f = try Fixture(root: root, name: "linked-reopen"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0]
            try f.ledger.deferLinkedRead(queued, now: 100)
            let reopened = try Fixture(root: root, name: "linked-reopen", create: false)
            let deferred = try reopened.ledger.linkedDeliveries(for: link)[0]
            try require(deferred.retryCount == 1 && deferred.notBefore == 101, "backoff lost across restart")
            try rejects(.staleRevision) { try reopened.db.transaction {
                try reopened.ledger.markLinkedRevisionDispatch(deferred, attemptID: UUID(), observedRootSHA256: origin.nativeRootSHA256, now: 100)
            } }
            let attempt = UUID()
            try reopened.db.transaction { try reopened.ledger.markLinkedRevisionDispatch(deferred, attemptID: attempt, observedRootSHA256: origin.nativeRootSHA256, now: 101) }
            let again = try Fixture(root: root, name: "linked-reopen", create: false)
            let uncertain = try again.ledger.linkedDeliveries(for: link)[0]
            try require(uncertain.state == .dispatchMayHaveOccurred && uncertain.attemptID == attempt && !uncertain.delivery.acknowledged, "uncertainty lost")
            try rejects(.staleRevision) { try again.db.transaction {
                try again.ledger.markLinkedRevisionDispatch(uncertain, attemptID: UUID(), observedRootSHA256: origin.nativeRootSHA256, now: 1000)
            } }
        }
        test("native_handoff_storage_requires_exact_message_attempt_and_keeps_peer_ack_separate") {
            let f = try Fixture(root: root, name: "linked-ack"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0], attempt = UUID()
            try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: attempt, observedRootSHA256: origin.nativeRootSHA256, now: 100) }
            try rejects(.receiptMismatch) { try f.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: UUID(), nativeRootSHA256: String(repeating: "c", count: 64), nativeResponseSHA256: origin.nativeResponseSHA256) }
            try f.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: attempt, nativeRootSHA256: String(repeating: "c", count: 64), nativeResponseSHA256: origin.nativeResponseSHA256)
            let result = try f.ledger.linkedDeliveries(for: link)[0]
            try require(result.state == .verified && result.delivery.acknowledged && result.link.confirmedLocalRevision == 2, "exact native handoff not stored")
            try require(f.scalar("SELECT count(*) FROM sqlite_master WHERE name LIKE '%remote_ack%';") == 0, "peer ACK was invented")
        }
        test("late_R2_native_completion_keeps_newer_R3_received_baseline") {
            let f = try Fixture(root: root, name: "linked-late"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0], attempt = UUID()
            try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: attempt, observedRootSHA256: origin.nativeRootSHA256, now: 100) }
            let newer = try linkedOrigin(root: String(repeating: "d", count: 64))
            _ = try localLinkedCommit(f, origin: newer, revision: 2)
            try f.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: attempt,
                nativeRootSHA256: String(repeating: "c", count: 64), nativeResponseSHA256: origin.nativeResponseSHA256)
            let actual = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let historical = try f.ledger.linkedDeliveries(for: actual)[0]
            try require(actual.confirmedLocalRevision == 3 && actual.nativeRootSHA256 == newer.nativeRootSHA256,
                        "late historical completion rolled the live baseline back")
            try require(historical.state == .verified && historical.delivery.acknowledged,
                        "valid historical R2 handoff receipt was discarded")
        }
        test("unlink_stops_new_deliveries_and_retains_copy_identity_history_and_uncertainty") {
            let f = try Fixture(root: root, name: "linked-unlink"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0]
            try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: UUID(), observedRootSHA256: origin.nativeRootSHA256, now: 100) }
            try f.ledger.unlinkNativeCopy(link)
            _ = try localLinkedCommit(f, revision: 2)
            try require(f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid).isEmpty, "link remained active")
            let retained = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid, activeOnly: false)[0]
            let uncertain = try f.ledger.linkedDeliveries(for: retained)
            try require(retained.objectID == origin.objectID && uncertain.count == 1 && uncertain[0].state == .dispatchMayHaveOccurred && !uncertain[0].delivery.acknowledged, "unlink deleted historical outcome")
            try require(f.scalar("SELECT count(*) FROM annotations;") == 1 && f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_versions;") == 3, "unlink deleted note/history")
        }
        test("received_origin_suppresses_only_that_copy_and_replay_cannot_add_consent") {
            let f = try Fixture(root: root, name: "linked-isolation"), a = try linkedOrigin(), b = try linkedOrigin("space-b")
            _ = try localLinkedCommit(f, origin: a, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, origin: b, enableLink: true, revision: 1)
            let received = try localLinkedCommit(f, origin: a, revision: 2)
            let links = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)
            let aItems = try f.ledger.linkedDeliveries(for: links.first { $0.destination == a.destination }!)
            let bItems = try f.ledger.linkedDeliveries(for: links.first { $0.destination == b.destination }!)
            try require(aItems.allSatisfy { $0.state == .superseded } && bItems.last?.delivery.mutationID == received.mutationID, "origin suppression leaked across Space")
            try rejects(.idempotencyConflict) { try f.ledger.requireNativeOriginReplay(mutationID: received.mutationID, origin: a, enableLink: true) }
            try f.ledger.requireNativeOriginReplay(mutationID: received.mutationID, origin: a, enableLink: false)
        }
        test("R2_unknown_Receive_R3_reviewed_CAS_without_echo_outbox_unblocks_link") {
            let f = try Fixture(root: root, name: "linked-review"), a = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: a, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0], firstAttempt = UUID()
            try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: firstAttempt, observedRootSHA256: a.nativeRootSHA256, now: 100) }
            let fresh = try linkedOrigin(root: String(repeating: "d", count: 64))
            let received = try localLinkedCommit(f, origin: fresh, revision: 2)
            let current = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            try require(f.ledger.pending(for: fresh.destination).count == 1, "received R3 acquired a fabricated outbox")
            let reconciliation = UUID()
            try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: current, version: received, attemptID: reconciliation, observedRootSHA256: fresh.nativeRootSHA256) }
            let reopened = try Fixture(root: root, name: "linked-review", create: false)
            try require(reopened.ledger.unresolvedLinkedReconciliations(for: [current]) == Set([current.id]), "reconciliation dispatch lost on restart")
            let confirmed = String(repeating: "e", count: 64)
            try reopened.ledger.recordLinkedReconciliationReadback(link: current, version: received, attemptID: reconciliation, nativeRootSHA256: confirmed, nativeResponseSHA256: fresh.nativeResponseSHA256)
            let old = try reopened.ledger.linkedDeliveries(for: current)[0]
            try require(old.state == .superseded && !old.delivery.acknowledged, "old unknown delivery got a fabricated ACK")
            try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_reviews WHERE prior_state='dispatch_may_have_occurred' AND prior_attempt_id=? AND resolution_attempt_id=?;", [firstAttempt.uuidString, reconciliation.uuidString]) == 1, "prior uncertainty lost from reconciliation history")
            try require(reopened.ledger.unresolvedLinkedReconciliations(for: [current]).isEmpty, "verified reconciliation did not release its fence")
            _ = try localLinkedCommit(reopened, revision: 3)
            let finalLink = try reopened.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            let pending = try reopened.ledger.linkedDeliveries(for: finalLink).last!
            try reopened.db.transaction { try reopened.ledger.markLinkedRevisionDispatch(pending, attemptID: UUID(), observedRootSHA256: confirmed, now: 200) }
        }
        test("unknown_reconciliation_blocks_newer_automatic_work_until_verified_review") {
            let f = try Fixture(root: root, name: "linked-review-fence"), a = try linkedOrigin()
            let first = try localLinkedCommit(f, origin: a, enableLink: true, revision: 0)
            let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0], firstAttempt = UUID()
            try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: link, version: first, attemptID: firstAttempt, observedRootSHA256: a.nativeRootSHA256) }
            let second = try localLinkedCommit(f, revision: 1)
            let pending = try f.ledger.linkedDeliveries(for: link)[0]
            try rejects(.staleRevision) { try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(pending, attemptID: UUID(), observedRootSHA256: a.nativeRootSHA256, now: 100) } }
            let resolution = UUID()
            try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: link, version: second, attemptID: resolution, observedRootSHA256: a.nativeRootSHA256) }
            try f.ledger.recordLinkedReconciliationReadback(link: link, version: second, attemptID: resolution, nativeRootSHA256: String(repeating: "d", count: 64), nativeResponseSHA256: a.nativeResponseSHA256)
            try require(f.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_reconciliations WHERE attempt_id=? AND state='superseded' AND resolution_attempt_id=?;", [firstAttempt.uuidString, resolution.uuidString]) == 1, "older reconciliation history not bound to observed resolution")
            let completed = try f.ledger.linkedDeliveries(for: link)[0]
            try require(completed.state == .verified && completed.delivery.acknowledged, "exact current outgoing body was not acknowledged by its actual handoff data")
        }
        for newerFirst in [false, true] {
            let order = newerFirst ? "newer_then_older" : "older_then_newer"
            test("same_revision_review_callbacks_\(order)_preserve_causal_fences_and_roots") {
                let name = "linked-review-order-" + order
                let f = try Fixture(root: root, name: name), origin = try linkedOrigin()
                let version = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
                let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
                let a = UUID(), b = UUID(), rootA = String(repeating: "c", count: 64), rootB = String(repeating: "d", count: 64)
                try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: link, version: version, attemptID: a, observedRootSHA256: origin.nativeRootSHA256) }
                // B's genuine read observes A's native result while A's local
                // callback is still delayed. Both immutable local revisions match.
                try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: link, version: version, attemptID: b, observedRootSHA256: rootA) }
                let reopened = try Fixture(root: root, name: name, create: false)
                let first = newerFirst ? b : a, firstRoot = newerFirst ? rootB : rootA
                let second = newerFirst ? a : b, secondRoot = newerFirst ? rootA : rootB
                try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: first, nativeRootSHA256: firstRoot, nativeResponseSHA256: origin.nativeResponseSHA256)
                if !newerFirst {
                    try require(reopened.ledger.unresolvedLinkedReconciliations(for: [link]) == Set([link.id]), "older callback cleared the newer same-revision fence")
                    try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_reconciliations WHERE attempt_id=? AND state='dispatch_may_have_occurred' AND dispatch_sequence=2;", [b.uuidString]) == 1, "newer attempt was superseded by an older callback")
                }
                try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: second, nativeRootSHA256: secondRoot, nativeResponseSHA256: origin.nativeResponseSHA256)
                let final = try reopened.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
                try require(final.nativeRootSHA256 == rootB && final.confirmedLocalRevision == version.revision, "same-revision baseline regressed by callback order")
                try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_links WHERE confirmed_dispatch_sequence=2 AND dispatch_sequence=2;") == 1, "causal dispatch order was not durable")
                try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_reconciliations WHERE state='verified' AND ((attempt_id=? AND native_root_sha256=?) OR (attempt_id=? AND native_root_sha256=?));", [a.uuidString, rootA, b.uuidString, rootB]) == 2, "actual older/newer receipt history was discarded")
                try require(reopened.ledger.unresolvedLinkedReconciliations(for: [link]).isEmpty, "actual completed attempts left a stale barrier")
                // Exact receipt replay is harmless; an altered old receipt is not.
                try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: a, nativeRootSHA256: rootA, nativeResponseSHA256: origin.nativeResponseSHA256)
                try rejects(.receiptMismatch) { try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: a, nativeRootSHA256: rootB, nativeResponseSHA256: origin.nativeResponseSHA256) }
            }
            test("same_revision_delivery_and_review_callbacks_\(order)_keep_original_attempt_history") {
                let name = "linked-delivery-review-order-" + order
                let f = try Fixture(root: root, name: name), origin = try linkedOrigin()
                _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
                let version = try localLinkedCommit(f, revision: 1)
                let link = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
                let queued = try f.ledger.linkedDeliveries(for: link)[0]
                let a = UUID(), b = UUID(), rootA = String(repeating: "c", count: 64), rootB = String(repeating: "d", count: 64)
                try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: a, observedRootSHA256: origin.nativeRootSHA256, now: 100) }
                try f.db.transaction { try f.ledger.markLinkedReconciliationDispatch(link: link, version: version, attemptID: b, observedRootSHA256: rootA) }
                let reopened = try Fixture(root: root, name: name, create: false)
                if newerFirst {
                    try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: b, nativeRootSHA256: rootB, nativeResponseSHA256: origin.nativeResponseSHA256)
                    let reviewed = try reopened.ledger.linkedDeliveries(for: link)[0]
                    try require(reviewed.state == .verified && reviewed.delivery.acknowledged && reviewed.attemptID == a, "review replaced the original in-flight attempt identity")
                    try reopened.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: a, nativeRootSHA256: rootA, nativeResponseSHA256: origin.nativeResponseSHA256)
                } else {
                    try reopened.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: a, nativeRootSHA256: rootA, nativeResponseSHA256: origin.nativeResponseSHA256)
                    try require(reopened.ledger.unresolvedLinkedReconciliations(for: [link]) == Set([link.id]), "ordinary callback cleared a newer explicit attempt")
                    try reopened.ledger.recordLinkedReconciliationReadback(link: link, version: version, attemptID: b, nativeRootSHA256: rootB, nativeResponseSHA256: origin.nativeResponseSHA256)
                }
                let final = try reopened.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
                let completed = try reopened.ledger.linkedDeliveries(for: link)[0]
                try require(final.nativeRootSHA256 == rootB && final.confirmedLocalRevision == version.revision, "late ordinary readback regressed the reviewed root")
                try require(completed.state == .verified && completed.delivery.acknowledged && completed.attemptID == a, "ordinary receipt identity/history was not preserved")
                try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_deliveries WHERE attempt_id=? AND dispatch_sequence=1 AND native_root_sha256=? AND native_response_sha256=?;", [a.uuidString, rootA, origin.nativeResponseSHA256]) == 1, "ordinary sealed result bytes were lost")
                try require(reopened.scalar("SELECT count(*) FROM otzaria_annotation_exchange_linked_reconciliations WHERE attempt_id=? AND dispatch_sequence=2 AND state='verified' AND native_root_sha256=?;", [b.uuidString, rootB]) == 1, "reviewed result was not retained independently")
                try reopened.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: a, nativeRootSHA256: rootA, nativeResponseSHA256: origin.nativeResponseSHA256)
            }
        }
    }
}

// The consent read is retained across a second REAL SQLite connection. Test
// origins remain explicit component data; no SDK receipt or native UI is faked.
private struct CapturedNativeConsent {
    let namespace: String
    let annotationUUID: UUID
    let links: [AnnotationExchangeNativeLink]
}

private func captureNativeConsent(_ f: Fixture) throws -> CapturedNativeConsent {
    var observed: CapturedNativeConsent?
    try f.db.transaction {
        observed = .init(namespace: namespace, annotationUUID: f.uuid,
            links: try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid, activeOnly: false))
    }
    guard let observed else { throw CheckFailure("missing original consent read") }
    return observed
}

private func consentAwareLocalCommit(_ f: Fixture, captured: CapturedNativeConsent,
                                    origin: AnnotationExchangeNativeReadOrigin, enableLink: Bool,
                                    revision: Int64) throws -> AnnotationExchangeVersion {
    // Bind the SAME frozen read used by the baseline scenarios. The production
    // Save API now requires it; never recapture consent at Save time.
    let consent = try AnnotationExchangeNativeConsentObservation(namespace: captured.namespace,
        annotationUUID: captured.annotationUUID, links: captured.links)
    var committed: AnnotationExchangeVersion?
    try f.db.transaction {
        try f.db.execute(query: "UPDATE annotations SET note='received consent-control body';")
        try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "upload")
        committed = try localLinkedCommit(f, origin: origin, enableLink: enableLink, revision: revision,
                                         expectedConsent: consent)
    }
    guard let committed else { throw CheckFailure("missing actual received commitment") }
    return committed
}

private func attachOriginAtExistingVersion(_ f: Fixture, origin: AnnotationExchangeNativeReadOrigin,
                                          version: AnnotationExchangeVersion) throws {
    // Exercise the actual ledger boundary at an existing unreceived local
    // version. This deliberately keeps annotation revision unchanged while
    // consent changes; it is NOT a claim of a native/UI relink journey.
    try f.db.transaction {
        let consent = try f.ledger.nativeConsentObservation(namespace: namespace, annotationUUID: f.uuid)
        try f.ledger.acceptNativeOrigin(origin, version: version, enableLink: true, expectedConsent: consent)
    }
}

private func explicitlyUnlinkObservedCopy(_ f: Fixture, link: AnnotationExchangeNativeLink,
                                         captured: CapturedNativeConsent) throws -> CapturedNativeConsent {
    let consent = try AnnotationExchangeNativeConsentObservation(namespace: captured.namespace,
        annotationUUID: captured.annotationUUID, links: captured.links)
    var result: CapturedNativeConsent?
    try f.db.transaction {
        let returned = try f.ledger.unlinkNativeCopy(link, expectedConsent: consent)
        let after = try captureNativeConsent(f)
        let reread = try AnnotationExchangeNativeConsentObservation(namespace: after.namespace,
            annotationUUID: after.annotationUUID, links: after.links)
        try require(returned == reread, "explicit unlink returned its exact same-transaction consent")
        result = after
    }
    guard let result else { throw CheckFailure("missing explicit unlink observation") }
    return result
}

/// All original and exchange table bytes, including schema and row types. This
/// uses the actual SQLite connection; it does not infer rollback from a counter.
private func consentDatabaseImage(_ f: Fixture) throws -> Data {
    let tables = try f.db.fetch(query: """
        SELECT name, sql FROM sqlite_master
        WHERE type='table' AND (name IN ('annotations','sync_pending') OR name LIKE 'otzaria_annotation_exchange_%')
        ORDER BY name;
        """) { ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "") }
    var image: [[String: Any]] = []
    for (name, sql) in tables {
        var statement: OpaquePointer?
        let query = "SELECT * FROM \"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\";"
        guard sqlite3_prepare_v2(f.db.dbPointer, query, -1, &statement, nil) == SQLITE_OK,
              let statement else { throw CheckFailure("cannot read original SQLite table") }
        defer { sqlite3_finalize(statement) }
        var rows: [String] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            var values: [[String: Any]] = []
            for index in 0..<sqlite3_column_count(statement) {
                let type = sqlite3_column_type(statement, index)
                let count = Int(sqlite3_column_bytes(statement, index))
                let bytes = sqlite3_column_blob(statement, index).map { Data(bytes: $0, count: count) } ?? Data()
                values.append(["type": Int(type), "bytesBase64": bytes.base64EncodedString()])
            }
            let bytes = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
            guard let encoded = String(data: bytes, encoding: .utf8) else { throw CheckFailure("invalid evidence encoding") }
            rows.append(encoded)
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw CheckFailure("incomplete original SQLite table read") }
        image.append(["table": name, "sql": sql, "rows": rows.sorted()])
    }
    return try JSONSerialization.data(withJSONObject: image, options: [.sortedKeys])
}

private func requireRejectedConsentSave(_ f: Fixture, captured: CapturedNativeConsent,
                                       origin: AnnotationExchangeNativeReadOrigin, revision: Int64,
                                       evidenceRoot: URL, name: String) throws {
    let before = try consentDatabaseImage(f)
    var rejectedStale = false
    var outcome = "COMMITTED"
    do { _ = try consentAwareLocalCommit(f, captured: captured, origin: origin, enableLink: true, revision: revision) }
    catch AnnotationExchangeError.staleRevision { rejectedStale = true; outcome = "REJECTED_STALE_REVISION" }
    catch { outcome = "OTHER_ERROR: \(error)" }
    let after = try consentDatabaseImage(f)
    try before.write(to: evidenceRoot.appendingPathComponent(name + "-before.json"))
    try after.write(to: evidenceRoot.appendingPathComponent(name + "-after.json"))
    let record: [String: Any] = [
        "name": name, "outcome": outcome, "expected": "REJECTED_STALE_REVISION",
        "capturedLinkIDs": captured.links.map { $0.id.uuidString },
        "capturedActiveIDs": captured.links.filter(\.active).map { $0.id.uuidString },
        "observedRevisionBeforeSave": revision,
        "actualRevisionAfterSave": try f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid),
        "beforeSHA256": try AcceptanceDigest().sha256(before),
        "afterSHA256": try AcceptanceDigest().sha256(after),
        "allTableBytesUnchanged": before == after,
        "actualSQLite": true, "nativeUI": false, "nativeReceipt": false
    ]
    try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
        .write(to: evidenceRoot.appendingPathComponent(name + "-observed.json"))
    try require(rejectedStale, "stale consent was not rejected: \(outcome)")
    try require(before == after, "rejected consent changed original body, queue, version, origin, link or history")
}

extension Acceptance {
    func linkedConsentCases() {
        test("retained_link_cannot_resurrect_after_other_connection_unlinks") {
            let name = "consent-unlink", f = try Fixture(root: root, name: name), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let captured = try captureNativeConsent(f)
            let peer = try Fixture(root: root, name: name, create: false)
            try peer.ledger.unlinkNativeCopy(captured.links[0])
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 1, "unlink altered annotation revision")
            try requireRejectedConsentSave(f, captured: captured, origin: origin, revision: 1, evidenceRoot: root, name: name)
        }
        test("retained_link_cannot_adopt_same_scope_relink_at_same_annotation_revision") {
            let name = "consent-relink", f = try Fixture(root: root, name: name), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let availableVersion = try localLinkedCommit(f, revision: 1)
            let captured = try captureNativeConsent(f)
            let peer = try Fixture(root: root, name: name, create: false)
            try peer.ledger.unlinkNativeCopy(captured.links[0])
            try attachOriginAtExistingVersion(peer, origin: linkedOrigin(root: String(repeating: "c", count: 64)), version: availableVersion)
            let replacement = try peer.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)
            try require(replacement.count == 1 && replacement[0].id != captured.links[0].id, "relink did not create an independent actual identity")
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 2, "consent ABA changed annotation revision")
            try requireRejectedConsentSave(f, captured: captured, origin: origin, revision: 2, evidenceRoot: root, name: name)
        }
        test("retained_absence_cannot_enable_after_other_connection_link_then_unlink") {
            let name = "consent-absence-aba", f = try Fixture(root: root, name: name), origin = try linkedOrigin()
            let availableVersion = try localLinkedCommit(f, revision: 0)
            let captured = try captureNativeConsent(f)
            try require(captured.links.isEmpty, "fixture already had consent")
            let peer = try Fixture(root: root, name: name, create: false)
            try attachOriginAtExistingVersion(peer, origin: origin, version: availableVersion)
            let added = try peer.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            try peer.ledger.unlinkNativeCopy(added)
            try require(peer.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid).isEmpty, "visible absence did not return")
            try require(f.ledger.currentRevision(namespace: namespace, annotationUUID: f.uuid) == 1, "absence ABA changed annotation revision")
            try requireRejectedConsentSave(f, captured: captured, origin: origin, revision: 1, evidenceRoot: root, name: name)
        }
        test("new_explicit_opt_in_after_observed_unlink_creates_new_identity") {
            let f = try Fixture(root: root, name: "consent-fresh-opt-in"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let old = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            try f.ledger.unlinkNativeCopy(old)
            let fresh = try captureNativeConsent(f)
            _ = try consentAwareLocalCommit(f, captured: fresh, origin: origin, enableLink: true, revision: 1)
            let history = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid, activeOnly: false)
            try require(history.count == 2 && history.filter(\.active).count == 1, "fresh explicit consent was lost")
            try require(history.first(where: { $0.id == old.id })?.active == false && history.first(where: \.active)?.id != old.id, "revoked identity was revived")
        }
        test("same_dialog_explicit_unlink_returns_exact_post_transaction_consent_for_receive_only") {
            let f = try Fixture(root: root, name: "consent-own-unlink"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            let captured = try captureNativeConsent(f), link = captured.links[0]
            let afterOwnUnlink = try explicitlyUnlinkObservedCopy(f, link: link, captured: captured)
            try require(afterOwnUnlink.links.count == 1 && afterOwnUnlink.links[0].id == link.id && !afterOwnUnlink.links[0].active, "explicit unlink did not return its exact observed history")
            let saved = try consentAwareLocalCommit(f, captured: afterOwnUnlink, origin: origin, enableLink: false, revision: 1)
            try require(saved.revision == 2 && f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid).isEmpty, "receive-only revived consent")
            try require(f.ledger.pending(for: origin.destination).isEmpty, "receive-only emitted transport")
        }
        test("committed_receive_replay_after_unlink_remains_historical_without_relink") {
            let f = try Fixture(root: root, name: "consent-replay"), origin = try linkedOrigin(), mutation = UUID()
            let saved = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0, mutation: mutation)
            let old = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            try f.ledger.unlinkNativeCopy(old)
            let before = try consentDatabaseImage(f)
            try f.ledger.requireNativeOriginReplay(mutationID: mutation, origin: origin, enableLink: true)
            let replay = try f.ledger.commitLocal(mutationID: mutation, payload: saved.payload,
                expectedSource: f.witness(), expectedRevision: 0)
            try require(replay.replayed && replay.revision == saved.revision, "durable receipt was hidden after unlink")
            try require(before == consentDatabaseImage(f), "historical receipt replay renewed consent or changed data")
        }
        test("transport_root_and_dispatch_progress_do_not_replace_consent_identity") {
            let f = try Fixture(root: root, name: "consent-transport-progress"), origin = try linkedOrigin()
            _ = try localLinkedCommit(f, origin: origin, enableLink: true, revision: 0)
            _ = try localLinkedCommit(f, revision: 1)
            let captured = try captureNativeConsent(f), link = captured.links[0]
            let queued = try f.ledger.linkedDeliveries(for: link)[0], attempt = UUID()
            try f.db.transaction { try f.ledger.markLinkedRevisionDispatch(queued, attemptID: attempt,
                observedRootSHA256: origin.nativeRootSHA256, now: 100) }
            try f.ledger.recordLinkedNativeReadback(messageID: queued.delivery.messageID, attemptID: attempt,
                nativeRootSHA256: String(repeating: "c", count: 64), nativeResponseSHA256: origin.nativeResponseSHA256)
            let actual = try f.ledger.nativeLinks(namespace: namespace, annotationUUID: f.uuid)[0]
            try require(actual.id == link.id && actual.nativeRootSHA256 != link.nativeRootSHA256, "transport precondition not exercised")
            let received = try consentAwareLocalCommit(f, captured: captured,
                origin: linkedOrigin(root: String(repeating: "d", count: 64)), enableLink: true, revision: 2)
            try require(received.revision == 3, "ordinary transport progress was mistaken for new consent")
        }
    }
}
