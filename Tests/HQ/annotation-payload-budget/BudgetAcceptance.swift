import Foundation
import SQLite3
import OtzariaActionCore
import Glibc

@MainActor
final class BudgetChecks {
    var rows: [[String: Any]] = []
    func run(_ name: String, _ body: () throws -> Void) {
        do { try body(); rows.append(["name": name, "status": "PASS"]) }
        catch { rows.append(["name": name, "status": "FAIL", "error": String(describing: error)]) }
    }
}

@main
struct BudgetAcceptance {
    @MainActor
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let checks = BudgetChecks()
        func open(_ name: String) throws -> Fixture {
            let fixture = try Fixture(root: root, name: name, create: false)
            try fixture.db.execute(query: "PRAGMA foreign_keys=ON;")
            return fixture
        }
        let sample = try open("legacy-read")
        checks.run("typed_limits_and_real_sha256") {
            try require(TorahAnnotationPayloadLimits.maximumArchiveBytes == 1_048_576, "archive")
            try require(TorahAnnotationPayloadLimits.maximumBodyBytes == 1_064_976, "frame")
            try require(TorahAnnotationPayloadLimits.maximumBase64Bytes == 1_419_968, "body base64")
            try require(TorahAnnotationEnvelopeCodec.maximumBytes == 2_097_152, "whole envelope")
            try require(TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes == 2_796_204, "stored base64")
            try require(try AcceptanceDigest().sha256(Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "actual SHA256")
        }
        checks.run("legacy_read_and_unknown_bytes_do_not_migrate") {
            let before = try databaseRows(sample); let ddl = try schemaBytes(sample)
            try require(try sample.ledger.hasInstalledSchema(), "missing legacy")
            let version = try sample.ledger.version(mutationID: fixedMutationID)
            try require(version != nil, "legacy version")
            let row = try sample.db.fetch(query: "SELECT message_id,payload_base64 FROM otzaria_annotation_exchange_inbox;") {
                ($0.string(at: 0)!, $0.string(at: 1)!)
            }[0]
            try require(try sample.ledger.incomingBytes(messageID: UUID(uuidString: row.0)!, destination: scope())
                == Data(base64Encoded: row.1), "unknown bytes changed")
            try require(try storageVersion(sample) == 1 && databaseRows(sample) == before && schemaBytes(sample) == ddl,
                "read migrated or changed legacy data")
        }
        checks.run("exact_framed_body_and_one_byte_over") {
            let payload = try sample.payload(rich: Data(repeating: 0xA5, count: TorahAnnotationPayloadLimits.maximumBodyBytes))
            guard case .supported(let envelope, let original) = try TorahAnnotationEnvelopeCodec.decode(payload) else {
                throw CheckFailure("supported body")
            }
            try require(envelope.richBody?.bytes.count == 1_064_976 && original == payload, "body changed")
            try rejects(.payloadTooLarge) {
                _ = try sample.payload(rich: Data(repeating: 0xA5, count: TorahAnnotationPayloadLimits.maximumBodyBytes + 1))
            }
            var fields = try AnnotationEnvelopeJSONCodec.decodeObject(payload)
            var body = fields["richBody"]!.object!
            body["bytesBase64"] = .string(String(repeating: "A", count: TorahAnnotationPayloadLimits.maximumBase64Bytes + 4))
            fields["richBody"] = .object(body)
            try rejects(.payloadTooLarge) {
                _ = try TorahAnnotationEnvelopeCodec.decode(AnnotationExchangeValidation.canonical(.object(fields)))
            }
        }
        checks.run("whole_envelope_unknown_metadata_exact_limit_and_over") {
            let exact = try exactEnvelope(sample, byteCount: 2_097_152)
            try require(try TorahAnnotationEnvelopeCodec.decode(exact).originalBytes == exact, "unknown bytes lost")
            try rejects(.payloadTooLarge) {
                _ = try TorahAnnotationEnvelopeCodec.decode(exactEnvelope(sample, byteCount: 2_097_153))
            }
            do { _ = try ActionWireCodec.decodeObject(exact); throw CheckFailure("global action cap was lifted") }
            catch is ActionContractError { }
        }
        checks.run("strict_json_grammar_not_weakened") {
            for bad in [
                #"{"schemaVersion":1,"schema\u0056ersion":1}"#,
                #"{"schemaVersion":2,"x":"a","x":"b"}"#,
                "{\"schemaVersion\":2,\"x\":" + String(repeating: "[", count: 18) + "0"
                    + String(repeating: "]", count: 18) + "}",
                "{\"schemaVersion\":2,\"x\":[" + Array(repeating: "0", count: 10_001).joined(separator: ",") + "]}"
            ] {
                try rejects(.invalidEnvelope) { _ = try TorahAnnotationEnvelopeCodec.decode(Data(bad.utf8)) }
            }
            let numbers = try AnnotationEnvelopeJSONCodec.decodeObject(Data(#"{"large":18446744073709551615}"#.utf8))
            try require(numbers["large"] == .unsigned(UInt64.max), "UInt64 loss")
        }
        checks.run("fresh_v2_idempotent_and_unrelated_rows_unchanged") {
            let fixture = try Fixture(root: root, name: "fresh", install: false)
            let before = try fixture.originals()
            try fixture.db.execute(query: "PRAGMA foreign_keys=ON;")
            try fixture.db.execute(query: "PRAGMA user_version=739;")
            try fixture.ledger.installSchema()
            let rows = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
            try fixture.ledger.installSchema()
            try require(try storageVersion(fixture) == 2 && databaseRows(fixture) == rows && schemaBytes(fixture) == ddl,
                "fresh install not idempotent")
            try require(try fixture.originals() == before && fixture.scalar("PRAGMA user_version;") == 739
                && fixture.scalar("PRAGMA foreign_keys;") == 1, "unrelated state changed")
        }
        checks.run("legacy_upgrade_preserves_rowid_types_bytes_native_history_and_foreign_keys") {
            let fixture = try open("upgrade")
            let before = try databaseRows(fixture, exceptStorageVersion: true)
            try fixture.ledger.installSchema()
            try require(try storageVersion(fixture) == 2, "upgrade version")
            try require(try databaseRows(fixture, exceptStorageVersion: true) == before, "rowid/type/bytes changed")
            try require(try fixture.ledger.hasNativeCreationSchema(), "native extension changed")
            try require(try fixture.db.fetch(query: "PRAGMA foreign_key_check;") { $0.int64(at: 0) }.isEmpty,
                "foreign key violation")
            try require(try fixture.scalar("PRAGMA foreign_keys;") == 1 && fixture.scalar("PRAGMA user_version;") == 739,
                "PRAGMA altered")
            let ddl = try schemaBytes(fixture)
            try fixture.ledger.installSchema()
            try require(try schemaBytes(fixture) == ddl, "second upgrade changed DDL")
        }
        checks.run("embedded_NUL_invalid_UTF8_and_blob_storage_preserved") {
            let fixture = try open("raw-preservation")
            try fixture.db.execute(query: """
                UPDATE otzaria_annotation_exchange_versions SET destinations_json=CAST(X'6100FF62' AS TEXT);
                """)
            try fixture.db.execute(query: """
                UPDATE otzaria_annotation_exchange_inbox SET payload_base64=X'610062';
                """)
            let before = try databaseRows(fixture, exceptStorageVersion: true)
            try fixture.ledger.installSchema()
            try require(try databaseRows(fixture, exceptStorageVersion: true) == before, "raw storage bytes/type changed")
        }
        checks.run("actual_outer_transaction_failure_rolls_back_schema_and_data") {
            let fixture = try open("outer-rollback")
            let before = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
            do {
                try fixture.db.transaction {
                    try fixture.ledger.installSchema()
                    try require(try storageVersion(fixture) == 2, "nested upgrade not executed")
                    throw CheckFailure("deliberate outer rollback")
                }
            } catch is CheckFailure { }
            try require(try storageVersion(fixture) == 1 && databaseRows(fixture) == before && schemaBytes(fixture) == ddl,
                "outer rollback did not restore original")
        }
        checks.run("actual_payload_CAS_failure_rolls_back_migration") {
            let fixture = try open("cas-rollback")
            let before = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
            try rejects(.staleRevision) {
                let witness = try fixture.witness()
                _ = try fixture.ledger.commitLocal(mutationID: UUID(), payload: fixture.payload(witness),
                    expectedSource: witness, expectedRevision: 99)
            }
            try require(try databaseRows(fixture) == before && schemaBytes(fixture) == ddl, "CAS migration leaked")
        }
        checks.run("actual_SQLite_insert_denial_rolls_back_migration") {
            let fixture = try open("denied-write")
            let before = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
            let witness = try fixture.witness(); let payload = try fixture.payload(witness)
            sqlite3_set_authorizer(fixture.db.dbPointer, denyOriginalVersionInsert, nil)
            do {
                _ = try fixture.ledger.commitLocal(mutationID: UUID(), payload: payload,
                    expectedSource: witness, expectedRevision: 1)
                throw CheckFailure("insert denial accepted")
            } catch is SQLiteError { }
            sqlite3_set_authorizer(fixture.db.dbPointer, nil, nil)
            try require(try databaseRows(fixture) == before && schemaBytes(fixture) == ddl, "failed write leaked migration")
        }
        let mutations: [(String, String)] = [
            ("future", "PRAGMA ignore_check_constraints=ON;"),
            ("partial", "DROP TABLE otzaria_annotation_exchange_inbox;"),
            ("altered", "ALTER TABLE otzaria_annotation_exchange_versions ADD COLUMN unexpected TEXT;"),
            ("user-index", "CREATE INDEX unexpected_payload_index ON otzaria_annotation_exchange_versions(payload_digest);"),
            ("trigger", "CREATE TRIGGER unexpected_payload_trigger AFTER INSERT ON otzaria_annotation_exchange_versions BEGIN SELECT 1; END;"),
            ("external-reference", "CREATE VIEW external_payload_view AS SELECT * FROM otzaria_annotation_exchange_versions;"),
            ("scratch-collision", "CREATE TABLE otzaria_annotation_exchange_versions__payload_v2(x);"),
            ("temp-shadow", "CREATE TEMP TABLE otzaria_annotation_exchange_versions(x);")
        ]
        for (name, sql) in mutations {
            checks.run("refuse_" + name + "_without_repair") {
                let fixture = try open(name)
                try fixture.db.execute(query: sql)
                if name == "future" {
                    try fixture.db.execute(query: "UPDATE otzaria_annotation_exchange_schema SET version=3;")
                    try fixture.db.execute(query: "PRAGMA ignore_check_constraints=OFF;")
                }
                let before = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
                try rejects(.schemaMismatch) { try fixture.ledger.installSchema() }
                try require(try databaseRows(fixture) == before && schemaBytes(fixture) == ddl, "refusal mutated store")
            }
        }
        for (name, sql) in [
            ("fresh-external-view", "CREATE VIEW external_payload_view AS SELECT * FROM otzaria_annotation_exchange_versions;"),
            ("fresh-scratch-name", "CREATE TABLE otzaria_annotation_exchange_versions__payload_v2(x);")
        ] {
            checks.run(name + "_rejected_before_create") {
                let fixture = try Fixture(root: root, name: name, install: false)
                try fixture.db.execute(query: sql)
                let before = try databaseRows(fixture); let ddl = try schemaBytes(fixture)
                try rejects(.schemaMismatch) { try fixture.ledger.installSchema() }
                try require(try databaseRows(fixture) == before && schemaBytes(fixture) == ddl, "fresh refusal created schema")
            }
        }
        checks.run("exact_2MiB_real_commit_replay_and_unknown_inbox_preservation") {
            let fixture = try open("incoming-upgrade")
            let before = try fixture.originals()
            let payload = try exactEnvelope(fixture, byteCount: 2_097_152)
            let witness = try fixture.witness(); let mutation = UUID()
            let commit = try fixture.ledger.commit(mutationID: mutation, payload: payload, expectedSource: witness,
                expectedRevision: 1, destinations: [scope()])
            try require(try storageVersion(fixture) == 2 && commit.revision == 2, "large commit not stored")
            let replay = try fixture.ledger.commit(mutationID: mutation, payload: payload, expectedSource: witness,
                expectedRevision: 1, destinations: [scope()])
            try require(replay.replayed && replay.deliveries == commit.deliveries, "large replay differs")
            try require(try fixture.ledger.version(mutationID: mutation)?.payload == payload, "large stored bytes differ")
            let message = UUID()
            var fields = try AnnotationEnvelopeJSONCodec.decodeObject(payload); fields["schemaVersion"] = .integer(9)
            let future = try AnnotationExchangeValidation.canonical(.object(fields))
            _ = try fixture.ledger.recordIncoming(messageID: message, destination: scope(), namespace: namespace,
                annotationUUID: fixture.uuid, revision: 2, payload: future, expectedDigest: AcceptanceDigest().sha256(future))
            try require(try fixture.ledger.incomingBytes(messageID: message, destination: scope()) == future,
                "large unknown inbox bytes differ")
            try require(try fixture.originals() == before, "annotation or CloudKit queue changed")
            try require(try fixture.scalar("SELECT length(payload_base64) FROM otzaria_annotation_exchange_versions WHERE mutation_id=?;",
                [mutation.uuidString]) == 2_796_204, "stored whole-envelope base64 not exact")
        }
        let cancelled = await Task.detached {
            do {
                let fixture = try Fixture(root: root, name: "cancelled-migration", create: false)
                var calls: Int32 = 0
                let didCancel = withUnsafeMutablePointer(to: &calls) { pointer in
                    sqlite3_set_authorizer(fixture.db.dbPointer, cancelOnOriginalSchemaDrop, pointer)
                    defer { sqlite3_set_authorizer(fixture.db.dbPointer, nil, nil) }
                    do { try fixture.ledger.installSchema(); return false }
                    catch is CancellationError { return true }
                    catch { return false }
                }
                return didCancel && calls == 1
            } catch { return false }
        }.value
        checks.run("cancellation_during_real_schema_drop_rolls_back") {
            let fixture = try open("cancelled-migration")
            let before = try Data(contentsOf: root.appendingPathComponent("cancelled-migration.before.json"))
            try require(cancelled && storageVersion(fixture) == 1 && databaseRows(fixture) == before,
                "cancellation did not drain/rollback actual migration")
        }
        let failures = checks.rows.filter { $0["status"] as? String != "PASS" }
        let report: [String: Any] = ["status": failures.isEmpty ? "PASS" : "FAIL", "cases": checks.rows,
            "passed": checks.rows.count - failures.count, "failed": failures.count,
            "scope": "Whole original SQLite/Envelope/Ledger with owned v1 fixtures and actual OpenSSL",
            "appleRuntime": false, "nativeBodyAuthority": false, "userDatabaseTouched": false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
        if !failures.isEmpty { exit(1) }
    }
}
