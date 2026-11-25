import Foundation
import SQLite3
import OtzariaActionCore

@main
struct FirstIncomingUpgrade {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        // This original-v1 fixture was only read by the primary controls; its
        // stored seeder snapshot is still exact before this new focused case.
        let fixture = try Fixture(root: root, name: "legacy-read", create: false)
        try fixture.db.execute(query: "PRAGMA foreign_keys=ON;")
        try require(try storageVersion(fixture) == 1, "first incoming requires actual legacy v1")
        let seed = try Data(contentsOf: root.appendingPathComponent("legacy-read.before.json"))
        try require(try databaseRows(fixture) == seed, "original seeded fixture changed")
        let beforeAll = try JSONSerialization.jsonObject(with: databaseRows(fixture, exceptStorageVersion: true)) as! [String: Any]
        let oldInbox = try fixture.db.fetch(query: """
            SELECT rowid,hex(CAST(message_id AS BLOB)),hex(CAST(payload_base64 AS BLOB)),envelope_version,status
            FROM otzaria_annotation_exchange_inbox ORDER BY rowid;
            """) { row in (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" } }
        let message = UUID()
        var fields = try AnnotationEnvelopeJSONCodec.decodeObject(exactEnvelope(fixture, byteCount: 2_097_152))
        fields["schemaVersion"] = .integer(9)
        let payload = try AnnotationExchangeValidation.canonical(.object(fields))
        try require(payload.count == 2_097_152, "unknown-version capacity")
        let digest = try AcceptanceDigest().sha256(payload)
        let inserted = try fixture.ledger.recordIncoming(messageID: message, destination: scope(), namespace: namespace,
            annotationUUID: fixture.uuid, revision: 2, payload: payload, expectedDigest: digest)
        try require(inserted && storageVersion(fixture) == 2, "first incoming did not perform upgrade")
        let replay = try fixture.ledger.recordIncoming(messageID: message, destination: scope(), namespace: namespace,
            annotationUUID: fixture.uuid, revision: 2, payload: payload, expectedDigest: digest)
        try require(!replay, "incoming idempotency changed")
        try require(try fixture.ledger.incomingBytes(messageID: message, destination: scope()) == payload,
            "complete unknown payload not preserved")
        var before = beforeAll
        var after = try JSONSerialization.jsonObject(with: databaseRows(fixture, exceptStorageVersion: true)) as! [String: Any]
        before.removeValue(forKey: "otzaria_annotation_exchange_inbox")
        after.removeValue(forKey: "otzaria_annotation_exchange_inbox")
        try require(NSDictionary(dictionary: before).isEqual(to: after), "first incoming changed other table rows/types/bytes")
        let retainedInbox = try fixture.db.fetch(query: """
            SELECT rowid,hex(CAST(message_id AS BLOB)),hex(CAST(payload_base64 AS BLOB)),envelope_version,status
            FROM otzaria_annotation_exchange_inbox WHERE message_id != ? ORDER BY rowid;
            """, parameters: [message.uuidString]) { row in (0..<row.columnCount).map { row.string(at: $0) ?? "<NULL>" } }
        try require(retainedInbox == oldInbox, "legacy inbox row changed")
        try require(try fixture.scalar("SELECT length(payload_base64) FROM otzaria_annotation_exchange_inbox WHERE message_id=?;",
            [message.uuidString]) == 2_796_204, "stored envelope bound")
        try require(try fixture.scalar("PRAGMA foreign_keys;") == 1 && fixture.scalar("PRAGMA user_version;") == 739,
            "connection or original schema metadata changed")
        try require(try fixture.db.fetch(query: "PRAGMA foreign_key_check;") { $0.int64(at: 0) }.isEmpty,
            "native history foreign key violation")
        let report: [String: Any] = ["status": "PASS", "case": "actual_first_incoming_v1_upgrade_exact_2MiB",
            "newCases": 1, "primary23CasesReplayed": false, "wholeOriginalV1FixtureReusedUnchanged": true,
            "payloadSHA256": digest, "payloadBytes": payload.count, "storedBase64Bytes": 2_796_204,
            "userDatabaseTouched": false, "nativeBodyOrAppleAcceptance": false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
