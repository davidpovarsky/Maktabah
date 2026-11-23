import Foundation
import SQLite3
import OtzariaActionCore

@main
struct LegacySeeder {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var records: [[String: Any]] = []
        for name in budgetSeedNames {
            let path = root.appendingPathComponent(name + ".sqlite")
            try require(!FileManager.default.fileExists(atPath: path.path), "refuse seed overwrite")
            let fixture = try Fixture(root: root, name: name)
            try fixture.db.execute(query: "PRAGMA foreign_keys=ON;")
            try fixture.db.execute(query: "PRAGMA user_version=739;")
            let witness = try fixture.witness()
            let payload = try fixture.payload(witness, extra: true)
            let commit = try fixture.ledger.commit(mutationID: fixedMutationID, payload: payload,
                expectedSource: witness, expectedRevision: 0, destinations: [scope()])
            let delivery = commit.deliveries[0]
            try fixture.ledger.installNativeCreationSchema()
            _ = try fixture.ledger.prepareNativeCreation(for: delivery)
            _ = try fixture.ledger.markNativeCreationMayHaveDispatched(delivery)
            // Explicit synthetic local-history row: no native identity receipt,
            // readback, body application or ACK is being manufactured or claimed.
            try fixture.db.execute(query: """
                INSERT INTO otzaria_annotation_exchange_native_identities
                (destination,account_id,space_id,namespace,annotation_uuid,message_id,native_object_id)
                VALUES(?,?,?,?,?,?,?);
                """, parameters: [delivery.destination.destination, delivery.destination.account,
                    delivery.destination.space, delivery.namespace, delivery.annotationUUID.uuidString,
                    delivery.messageID.uuidString, "synthetic-preservation-only"])
            var unknown = try ActionWireCodec.decodeObject(payload)
            unknown["schemaVersion"] = .integer(23)
            unknown["futureOpaque"] = .object(["uint64": .unsigned(UInt64.max), "bytes": .string("untouched")])
            let bytes = try AnnotationExchangeValidation.canonical(.object(unknown))
            _ = try fixture.ledger.recordIncoming(messageID: UUID(), destination: scope(), namespace: namespace,
                annotationUUID: fixture.uuid, revision: 1, payload: bytes,
                expectedDigest: AcceptanceDigest().sha256(bytes))
            try require(try storageVersion(fixture) == 1, "seeder did not execute original v1")
            try require(try fixture.scalar("PRAGMA foreign_keys;") == 1, "foreign keys disabled")
            let snapshot = try databaseRows(fixture)
            try snapshot.write(to: root.appendingPathComponent(name + ".before.json"))
            records.append(["name": name, "version": 1, "rowsSHA256": try AcceptanceDigest().sha256(snapshot)])
        }
        let report: [String: Any] = ["status": "PASS", "scope": "Whole original v1 Ledger and Envelope produced owned fixtures",
            "fixtureCount": records.count, "fixtures": records, "nativeRuntime": false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
