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
            try f.db.execute(query: "CREATE TRIGGER reject_exchange BEFORE INSERT ON otzaria_annotation_exchange_outbox BEGIN SELECT RAISE(ABORT,'owned fixture enqueue failure'); END;")
            var sawExpected = false
            do {
                try f.db.transaction {
                    try f.db.execute(query: "UPDATE annotations SET note='outer mutation';")
                    try f.queue.addPendingSync(ckRecordId: f.uuid.uuidString, operation: "delete")
                    _ = try f.commit()
                }
            } catch let error as SQLiteError {
                sawExpected = error.localizedDescription.contains("owned fixture enqueue failure")
            }
            try require(sawExpected, "did not execute failing INSERT trigger")
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
            let status = sqlite3_create_function_v2(f.db.dbPointer, "cancel_exchange_task", 0, SQLITE_UTF8, nil,
                                                   cancelExchangeTask, nil, nil, nil)
            try require(status == SQLITE_OK, "SQLite callback setup failed")
            try f.db.execute(query: "CREATE TRIGGER cancel_after_enqueue AFTER INSERT ON otzaria_annotation_exchange_outbox BEGIN SELECT cancel_exchange_task(); END;")
            let task = Task.detached { try f.commit() }
            do { _ = try await task.value; throw CheckFailure("cancelled insert committed") }
            catch is CancellationError {}
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
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if mode == "self-tests" { try await Acceptance(root: root).run(); return }
        if mode == "crash-after-commit" || mode == "crash-before-outer-commit" {
            let phase = mode == "crash-after-commit" ? "after" : "before"
            let f = try Fixture(root: root, name: "crash-\(phase)")
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
