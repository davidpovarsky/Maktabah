import Foundation
import SQLite3
import OtzariaActionCore

struct AnnotationExchangeDelivery: Sendable, Equatable {
    let messageID: UUID
    let mutationID: UUID
    let destination: AnnotationExchangeDestination
    let namespace: String
    let annotationUUID: UUID
    let revision: Int64
    let payloadDigest: String
    let payload: Data
    let acknowledged: Bool
}

struct AnnotationExchangeAcknowledgement: Sendable, Equatable {
    let messageID: UUID
    let destination: AnnotationExchangeDestination
    let namespace: String
    let annotationUUID: UUID
    let revision: Int64
    let payloadDigest: String
}

struct AnnotationExchangeCommit: Sendable, Equatable {
    let mutationID: UUID
    let namespace: String
    let annotationUUID: UUID
    let revision: Int64
    let payloadDigest: String
    let replayed: Bool
    let deliveries: [AnnotationExchangeDelivery]
}

/// Validated immutable version bytes. Reading a version neither applies it nor
/// creates a transport acknowledgement; unknown envelope versions stay intact.
struct AnnotationExchangeVersion: Sendable, Equatable {
    let mutationID: UUID
    let namespace: String
    let annotationUUID: UUID
    let revision: Int64
    let sourceDigest: String
    let payloadDigest: String
    let payload: Data
    let destinationsJSON: String
}

/// Explicit component on the original injected handle. It never opens a DB,
/// changes annotations/CloudKit, applies incoming data, or starts a transport.
final class AnnotationExchangeLedger: Sendable {
    private let database: SQLiteDatabase
    private let digest: any AnnotationExchangeDigesting
    private static let schema = "otzaria_annotation_exchange_schema"
    private static let heads = "otzaria_annotation_exchange_heads"
    private static let versions = "otzaria_annotation_exchange_versions"
    private static let outbox = "otzaria_annotation_exchange_outbox"
    private static let inbox = "otzaria_annotation_exchange_inbox"

    init(database: SQLiteDatabase, digest: any AnnotationExchangeDigesting) {
        self.database = database; self.digest = digest
    }

    /// Deliberately explicit: constructing a ledger performs no migration.
    func installSchema() throws {
        try Task.checkCancellation()
        try database.transaction {
            let statements = [
                "CREATE TABLE IF NOT EXISTS \(Self.schema) (singleton INTEGER PRIMARY KEY CHECK(singleton = 1), version INTEGER NOT NULL CHECK(typeof(version) = 'integer' AND version = 1));",
                "INSERT OR IGNORE INTO \(Self.schema) (singleton, version) VALUES (1, 1);",
                """
                CREATE TABLE IF NOT EXISTS \(Self.heads) (
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    revision INTEGER NOT NULL CHECK(typeof(revision) = 'integer' AND revision > 0),
                    PRIMARY KEY(namespace, annotation_uuid)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS \(Self.versions) (
                    mutation_id TEXT PRIMARY KEY NOT NULL CHECK(length(mutation_id) = 36),
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    revision INTEGER NOT NULL CHECK(typeof(revision) = 'integer' AND revision > 0),
                    source_digest TEXT NOT NULL CHECK(length(source_digest) = 64),
                    payload_digest TEXT NOT NULL CHECK(length(payload_digest) = 64),
                    payload_base64 TEXT NOT NULL CHECK(length(payload_base64) BETWEEN 1 AND 87400),
                    deletion_state TEXT NOT NULL CHECK(deletion_state IN ('active', 'tombstone')),
                    destinations_json TEXT NOT NULL,
                    UNIQUE(namespace, annotation_uuid, revision)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS \(Self.outbox) (
                    message_id TEXT PRIMARY KEY NOT NULL CHECK(length(message_id) = 36),
                    mutation_id TEXT NOT NULL CHECK(length(mutation_id) = 36),
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    status TEXT NOT NULL CHECK(status IN ('pending', 'acknowledged')),
                    UNIQUE(mutation_id, destination, account_id, space_id)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS \(Self.inbox) (
                    message_id TEXT NOT NULL CHECK(length(message_id) = 36),
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    revision INTEGER NOT NULL CHECK(typeof(revision) = 'integer' AND revision > 0),
                    payload_digest TEXT NOT NULL CHECK(length(payload_digest) = 64),
                    payload_base64 TEXT NOT NULL CHECK(length(payload_base64) BETWEEN 1 AND 87400),
                    envelope_version INTEGER NOT NULL CHECK(typeof(envelope_version) = 'integer' AND envelope_version > 0),
                    status TEXT NOT NULL CHECK(status IN ('pending_review', 'unsupported')),
                    PRIMARY KEY(destination, account_id, space_id, message_id)
                );
                """,
                "CREATE INDEX IF NOT EXISTS otzaria_annotation_exchange_pending ON \(Self.outbox)(destination, account_id, space_id, status);"
            ]
            for statement in statements { try database.execute(query: statement) }
            try requireSchema()
            try Task.checkCancellation()
        }
    }

    /// All original row values and tag rows participate; lastModified is data,
    /// never a monotonic revision. No UUID is created or backfilled here.
    func captureSource(annotationUUID: UUID) throws -> AnnotationExchangeSourceWitness {
        try Task.checkCancellation()
        var result: AnnotationExchangeSourceWitness?
        try database.transaction { result = try captureSourceLocked(annotationUUID: annotationUUID) }
        guard let result else { throw AnnotationExchangeError.corruptRecord }
        return result
    }

    private func captureSourceLocked(annotationUUID: UUID) throws -> AnnotationExchangeSourceWitness {
        let rows: [(Int64, ActionObject)] = try database.fetch(
            query: "SELECT * FROM annotations WHERE ckRecordId = ? COLLATE NOCASE;",
            parameters: [annotationUUID.uuidString]) { row in
                var values: ActionObject = [:]
                var id: Int64?
                for index in 0..<row.columnCount {
                    let name = row.stmt.columnName(index)
                    guard !name.isEmpty, values[name] == nil else { throw AnnotationExchangeError.corruptRecord }
                    values[name] = try Self.column(row, index: index)
                    if name == "id", row.type(at: index) == SQLITE_INTEGER { id = row.int64(at: index) }
                }
                guard let id, id > 0 else { throw AnnotationExchangeError.corruptRecord }
                return (id, values)
            }
        guard rows.count <= 1 else { throw AnnotationExchangeError.ambiguousSource }
        let exists = !rows.isEmpty
        var canonical: ActionObject = ["annotationUUID": .string(annotationUUID.uuidString),
                                       "state": .string(exists ? "present" : "absent")]
        var metadata: ActionObject = ["state": .string(exists ? "present" : "absent")]
        if let (id, fields) = rows.first {
            let tags: [ActionJSON] = try database.fetch(query: """
                SELECT a.annotationId, a.tagId, t.id, t.name, t.normalizedName FROM annotation_tags a
                LEFT JOIN tags t ON t.id = a.tagId WHERE a.annotationId = ?
                ORDER BY a.annotationId, a.tagId, t.id, t.name, t.normalizedName;
                """, parameters: [id]) { row in
                    .array(try (0..<row.columnCount).map { try Self.column(row, index: $0) })
                }
            canonical["fields"] = .object(fields); canonical["tags"] = .array(tags)
            // Original source provenance is represented without inventing a
            // canonical reference. The note itself is not a locator/preview.
            var sourceFields = fields; sourceFields.removeValue(forKey: "note")
            metadata["fields"] = .object(sourceFields); metadata["tags"] = .array(tags)
        }
        let bytes = try AnnotationExchangeValidation.canonical(.object(canonical))
        guard bytes.count <= 8_388_608 else { throw AnnotationExchangeError.payloadTooLarge }
        let hash = try hash(bytes)
        metadata["snapshotSHA256"] = .string(hash)
        return .init(annotationUUID: annotationUUID, exists: exists, canonicalBytes: bytes, digest: hash, metadata: metadata)
    }

    private static func column(_ row: SQLiteRow, index: Int32) throws -> ActionJSON {
        switch row.type(at: index) {
        case SQLITE_NULL: return .object(["type": .string("null")])
        case SQLITE_INTEGER: return .object(["type": .string("integer"), "value": .string(String(row.int64(at: index)))])
        case SQLITE_FLOAT:
            return .object(["type": .string("float64bits"), "value": .string(String(row.double(at: index).bitPattern, radix: 16))])
        case SQLITE_TEXT:
            // SQLite TEXT may contain embedded NUL or non-UTF8 bytes. A C-string
            // conversion would make distinct source rows share one witness.
            let count = Int(sqlite3_column_bytes(row.stmt, index))
            guard count <= 8_388_608 else { throw AnnotationExchangeError.payloadTooLarge }
            let pointer = sqlite3_column_text(row.stmt, index)
            guard count == 0 || pointer != nil else { throw AnnotationExchangeError.corruptRecord }
            let bytes = pointer.map { Data(bytes: $0, count: count) } ?? Data()
            return .object(["type": .string("textBytesBase64"), "value": .string(bytes.base64EncodedString())])
        case SQLITE_BLOB:
            guard sqlite3_column_bytes(row.stmt, index) <= 8_388_608 else { throw AnnotationExchangeError.payloadTooLarge }
            let value = row.blob(at: index) ?? Data()
            return .object(["type": .string("blobBase64"), "value": .string(value.base64EncodedString())])
        default: throw AnnotationExchangeError.corruptRecord
        }
    }

    /// Idempotency belongs to the caller's stable mutation ID and exact bytes.
    /// A successful retry cannot overwrite a later head or create more messages.
    func commit(mutationID: UUID, payload: Data, expectedSource: AnnotationExchangeSourceWitness,
                expectedRevision: Int64, destinations: [AnnotationExchangeDestination]) throws -> AnnotationExchangeCommit {
        try commitValidated(mutationID: mutationID, payload: payload, expectedSource: expectedSource,
            expectedRevision: expectedRevision, destinations: destinations, localOnly: false)
    }

    /// Explicit offline persistence. No account/Space is invented and no outbox
    /// row is produced. The existing exchange entry point still rejects [].
    func commitLocal(mutationID: UUID, payload: Data, expectedSource: AnnotationExchangeSourceWitness,
                     expectedRevision: Int64) throws -> AnnotationExchangeCommit {
        try commitValidated(mutationID: mutationID, payload: payload, expectedSource: expectedSource,
            expectedRevision: expectedRevision, destinations: [], localOnly: true)
    }

    private func commitValidated(mutationID: UUID, payload: Data, expectedSource: AnnotationExchangeSourceWitness,
                expectedRevision: Int64, destinations: [AnnotationExchangeDestination], localOnly: Bool) throws -> AnnotationExchangeCommit {
        try Task.checkCancellation()
        guard expectedRevision >= 0 else { throw AnnotationExchangeError.staleRevision }
        let decoded = try TorahAnnotationEnvelopeCodec.decode(payload)
        guard case .supported(let envelope, _) = decoded else {
            if case .unsupported(let version, _) = decoded { throw AnnotationExchangeError.unsupportedVersion(version) }
            throw AnnotationExchangeError.invalidEnvelope
        }
        guard envelope.annotationUUID == expectedSource.annotationUUID, envelope.source == expectedSource.metadata else {
            throw AnnotationExchangeError.staleSource
        }
        let payloadHash = try hash(payload)
        let scopes: String
        if localOnly { scopes = "[]" }
        else { scopes = try AnnotationExchangeValidation.destinationList(destinations) }
        var answer: AnnotationExchangeCommit?
        try database.transaction {
            try requireSchema()
            let old = try database.fetch(query: """
                SELECT namespace, annotation_uuid, revision, source_digest, payload_digest, payload_base64, destinations_json
                FROM \(Self.versions) WHERE mutation_id = ?;
                """, parameters: [mutationID.uuidString]) { row in
                    (row.string(at: 0), row.string(at: 1), row.int64(at: 2), row.string(at: 3), row.string(at: 4), row.string(at: 5), row.string(at: 6))
                }
            if let prior = old.first {
                guard old.count == 1, prior.0 == envelope.namespace, prior.1 == envelope.annotationUUID.uuidString,
                      prior.2 > 0, prior.3 == expectedSource.digest, prior.4 == payloadHash,
                      prior.5 == payload.base64EncodedString(), prior.6 == scopes else {
                    throw AnnotationExchangeError.idempotencyConflict
                }
                let deliveries = try deliveriesForMutation(mutationID)
                guard Set(deliveries.map(\.destination)) == Set(destinations), deliveries.count == destinations.count else {
                    throw AnnotationExchangeError.corruptRecord
                }
                answer = .init(mutationID: mutationID, namespace: envelope.namespace, annotationUUID: envelope.annotationUUID,
                    revision: prior.2, payloadDigest: payloadHash, replayed: true, deliveries: deliveries)
                return
            }
            let current = try captureSourceLocked(annotationUUID: envelope.annotationUUID)
            guard current == expectedSource else { throw AnnotationExchangeError.staleSource }
            let head = try currentRevisionLocked(namespace: envelope.namespace, annotationUUID: envelope.annotationUUID)
            guard head == expectedRevision else { throw AnnotationExchangeError.staleRevision }
            guard head < Int64.max else { throw AnnotationExchangeError.revisionExhausted }
            if envelope.deletionState == .tombstone {
                guard !current.exists, head > 0 else { throw AnnotationExchangeError.missingSource }
            } else { guard current.exists else { throw AnnotationExchangeError.missingSource } }
            let revision = head + 1
            try Task.checkCancellation()
            try database.execute(query: """
                INSERT INTO \(Self.versions)
                (mutation_id, namespace, annotation_uuid, revision, source_digest, payload_digest, payload_base64, deletion_state, destinations_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, parameters: [mutationID.uuidString, envelope.namespace, envelope.annotationUUID.uuidString, revision,
                                    current.digest, payloadHash, payload.base64EncodedString(), envelope.deletionState.rawValue, scopes])
            try database.execute(query: """
                INSERT INTO \(Self.heads) (namespace, annotation_uuid, revision) VALUES (?, ?, ?)
                ON CONFLICT(namespace, annotation_uuid) DO UPDATE SET revision = excluded.revision;
                """, parameters: [envelope.namespace, envelope.annotationUUID.uuidString, revision])
            for destination in destinations {
                try database.execute(query: """
                    INSERT INTO \(Self.outbox) (message_id, mutation_id, destination, account_id, space_id, status)
                    VALUES (?, ?, ?, ?, ?, 'pending');
                    """, parameters: [UUID().uuidString, mutationID.uuidString, destination.destination, destination.account, destination.space])
            }
            let deliveries = try deliveriesForMutation(mutationID)
            guard deliveries.count == destinations.count else { throw AnnotationExchangeError.corruptRecord }
            try Task.checkCancellation()
            answer = .init(mutationID: mutationID, namespace: envelope.namespace, annotationUUID: envelope.annotationUUID,
                revision: revision, payloadDigest: payloadHash, replayed: false, deliveries: deliveries)
        }
        guard let answer else { throw AnnotationExchangeError.corruptRecord }
        return answer
    }

    /// Read-only schema discovery for legacy notes. A partial or future schema
    /// is not treated as an empty store and is never repaired by a read.
    func hasInstalledSchema() throws -> Bool {
        let expected = [Self.schema, Self.heads, Self.versions, Self.outbox, Self.inbox]
        let rows = try database.fetch(query: """
            SELECT name, type FROM sqlite_master WHERE name IN (?, ?, ?, ?, ?);
            """, parameters: expected) { row in (row.string(at: 0), row.string(at: 1)) }
        if rows.isEmpty { return false }
        guard rows.count == expected.count, Set(rows.compactMap { $0.0 }) == Set(expected),
              rows.allSatisfy({ $0.1 == "table" }) else { throw AnnotationExchangeError.schemaMismatch }
        try requireSchema()
        return true
    }

    func currentVersion(namespace: String, annotationUUID: UUID) throws -> AnnotationExchangeVersion? {
        guard AnnotationExchangeValidation.identifier(namespace) else { throw AnnotationExchangeError.invalidScope }
        var result: AnnotationExchangeVersion?
        try database.transaction {
            try requireSchema()
            let revision = try currentRevisionLocked(namespace: namespace, annotationUUID: annotationUUID)
            if revision == 0 {
                let orphaned = try database.fetch(query: "SELECT COUNT(*) FROM \(Self.versions) WHERE namespace = ? AND annotation_uuid = ?;",
                    parameters: [namespace, annotationUUID.uuidString]) { $0.int64(at: 0) }.first ?? 0
                guard orphaned == 0 else { throw AnnotationExchangeError.corruptRecord }
            }
            let rows = try versionRows(where: "namespace = ? AND annotation_uuid = ? AND revision = ?",
                parameters: [namespace, annotationUUID.uuidString, revision])
            guard rows.count == (revision == 0 ? 0 : 1) else { throw AnnotationExchangeError.corruptRecord }
            result = rows.first
        }
        return result
    }

    func version(mutationID: UUID) throws -> AnnotationExchangeVersion? {
        try requireSchema()
        let rows = try versionRows(where: "mutation_id = ?", parameters: [mutationID.uuidString])
        guard rows.count <= 1 else { throw AnnotationExchangeError.corruptRecord }
        return rows.first
    }

    private func versionRows(where suffix: String, parameters: [Any]) throws -> [AnnotationExchangeVersion] {
        try database.fetch(query: """
            SELECT mutation_id, namespace, annotation_uuid, revision, source_digest,
                   payload_digest, payload_base64, deletion_state, destinations_json
            FROM \(Self.versions) WHERE \(suffix);
            """, parameters: parameters) { row in
                func text(_ index: Int32) throws -> String {
                    guard row.type(at: index) == SQLITE_TEXT, let value = row.string(at: index),
                          value.utf8.count == Int(sqlite3_column_bytes(row.stmt, index)) else {
                        throw AnnotationExchangeError.corruptRecord
                    }
                    return value
                }
                let mutationText = try text(0), namespace = try text(1), uuidText = try text(2)
                let sourceDigest = try text(4), payloadDigest = try text(5), encoded = try text(6)
                let deletion = try text(7), destinations = try text(8)
                guard let mutation = UUID(uuidString: mutationText), mutation.uuidString == mutationText,
                      AnnotationExchangeValidation.identifier(namespace),
                      let uuid = UUID(uuidString: uuidText), uuid.uuidString == uuidText,
                      row.type(at: 3) == SQLITE_INTEGER, row.int64(at: 3) > 0,
                      AnnotationExchangeValidation.digest(sourceDigest),
                      AnnotationExchangeValidation.digest(payloadDigest),
                      let payload = Data(base64Encoded: encoded), payload.base64EncodedString() == encoded,
                      payload.count <= TorahAnnotationEnvelopeCodec.maximumBytes,
                      try self.hash(payload) == payloadDigest,
                      TorahAnnotationEnvelope.DeletionState(rawValue: deletion) != nil else {
                    throw AnnotationExchangeError.corruptRecord
                }
                let decoded = try TorahAnnotationEnvelopeCodec.decode(payload)
                if case .supported(let envelope, _) = decoded {
                    guard envelope.namespace == namespace, envelope.annotationUUID == uuid,
                          envelope.source["snapshotSHA256"]?.string == sourceDigest,
                          envelope.deletionState.rawValue == deletion else { throw AnnotationExchangeError.corruptRecord }
                }
                return .init(mutationID: mutation, namespace: namespace, annotationUUID: uuid,
                    revision: row.int64(at: 3), sourceDigest: sourceDigest, payloadDigest: payloadDigest,
                    payload: payload, destinationsJSON: destinations)
            }
    }

    func currentRevision(namespace: String, annotationUUID: UUID) throws -> Int64 {
        guard AnnotationExchangeValidation.identifier(namespace) else { throw AnnotationExchangeError.invalidScope }
        try requireSchema()
        return try currentRevisionLocked(namespace: namespace, annotationUUID: annotationUUID)
    }
    private func currentRevisionLocked(namespace: String, annotationUUID: UUID) throws -> Int64 {
        let rows = try database.fetch(query: """
            SELECT h.revision, v.mutation_id FROM \(Self.heads) h LEFT JOIN \(Self.versions) v
            ON v.namespace = h.namespace AND v.annotation_uuid = h.annotation_uuid AND v.revision = h.revision
            WHERE h.namespace = ? AND h.annotation_uuid = ?;
            """, parameters: [namespace, annotationUUID.uuidString]) { row in
                guard row.type(at: 0) == SQLITE_INTEGER, row.string(at: 1).flatMap(UUID.init(uuidString:)) != nil else {
                    throw AnnotationExchangeError.corruptRecord
                }
                return row.int64(at: 0)
            }
        guard rows.count <= 1, rows.first.map({ $0 > 0 }) ?? true else { throw AnnotationExchangeError.corruptRecord }
        return rows.first ?? 0
    }

    func pending(for destination: AnnotationExchangeDestination, limit: Int = 50) throws -> [AnnotationExchangeDelivery] {
        guard (1...100).contains(limit) else { throw AnnotationExchangeError.invalidScope }
        try requireSchema()
        return try queryDeliveries(where: "o.destination = ? AND o.account_id = ? AND o.space_id = ? AND o.status = 'pending' ORDER BY v.revision, o.message_id LIMIT ?",
            parameters: [destination.destination, destination.account, destination.space, limit])
    }

    /// Returns false for an identical repeated ACK. Never removes a record or
    /// affects another destination, newer revision, or original CloudKit queue.
    @discardableResult
    func acknowledge(_ receipt: AnnotationExchangeAcknowledgement) throws -> Bool {
        guard receipt.revision > 0, AnnotationExchangeValidation.identifier(receipt.namespace),
              AnnotationExchangeValidation.digest(receipt.payloadDigest) else { throw AnnotationExchangeError.receiptMismatch }
        var changed = false
        try database.transaction {
            try requireSchema()
            let matches = try queryDeliveries(where: "o.message_id = ?", parameters: [receipt.messageID.uuidString])
            guard matches.count == 1, let delivery = matches.first,
                  delivery.destination == receipt.destination, delivery.namespace == receipt.namespace,
                  delivery.annotationUUID == receipt.annotationUUID, delivery.revision == receipt.revision,
                  delivery.payloadDigest == receipt.payloadDigest else { throw AnnotationExchangeError.receiptMismatch }
            if delivery.acknowledged { return }
            try Task.checkCancellation()
            try database.execute(query: "UPDATE \(Self.outbox) SET status = 'acknowledged' WHERE message_id = ? AND status = 'pending';",
                parameters: [receipt.messageID.uuidString])
            guard try queryDeliveries(where: "o.message_id = ?", parameters: [receipt.messageID.uuidString]).first?.acknowledged == true else {
                throw AnnotationExchangeError.corruptRecord
            }
            try Task.checkCancellation(); changed = true
        }
        return changed
    }

    /// Durable inbox only: supported data awaits explicit review and unknown
    /// versions are quarantined. Neither path applies data or creates an ACK.
    @discardableResult
    func recordIncoming(messageID: UUID, destination: AnnotationExchangeDestination, namespace: String,
                        annotationUUID: UUID, revision: Int64, payload: Data, expectedDigest: String) throws -> Bool {
        try Task.checkCancellation()
        guard payload.count <= TorahAnnotationEnvelopeCodec.maximumBytes else { throw AnnotationExchangeError.payloadTooLarge }
        guard AnnotationExchangeValidation.identifier(namespace), revision > 0,
              AnnotationExchangeValidation.digest(expectedDigest), try hash(payload) == expectedDigest else {
            throw AnnotationExchangeError.receiptMismatch
        }
        let decoded = try TorahAnnotationEnvelopeCodec.decode(payload)
        let version: Int64, status: String
        switch decoded {
        case .supported(let envelope, _):
            guard envelope.namespace == namespace, envelope.annotationUUID == annotationUUID else { throw AnnotationExchangeError.receiptMismatch }
            version = TorahAnnotationEnvelopeCodec.schemaVersion; status = "pending_review"
        case .unsupported(let unknown, _): version = unknown; status = "unsupported"
        }
        let scope: [Any] = [destination.destination, destination.account, destination.space, messageID.uuidString]
        var inserted = false
        try database.transaction {
            try requireSchema()
            let rows = try database.fetch(query: """
                SELECT namespace, annotation_uuid, revision, payload_digest, payload_base64, envelope_version, status
                FROM \(Self.inbox) WHERE destination = ? AND account_id = ? AND space_id = ? AND message_id = ?;
                """, parameters: scope) { row in
                    (row.string(at: 0), row.string(at: 1), row.int64(at: 2), row.string(at: 3), row.string(at: 4), row.int64(at: 5), row.string(at: 6))
                }
            if let old = rows.first {
                guard rows.count == 1, old.0 == namespace, old.1 == annotationUUID.uuidString, old.2 == revision,
                      old.3 == expectedDigest, old.4 == payload.base64EncodedString(), old.5 == version, old.6 == status else {
                    throw AnnotationExchangeError.idempotencyConflict
                }
                return
            }
            try Task.checkCancellation()
            try database.execute(query: """
                INSERT INTO \(Self.inbox)
                (destination, account_id, space_id, message_id, namespace, annotation_uuid, revision, payload_digest, payload_base64, envelope_version, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, parameters: scope + [namespace, annotationUUID.uuidString, revision, expectedDigest, payload.base64EncodedString(), version, status])
            try Task.checkCancellation(); inserted = true
        }
        return inserted
    }

    func incomingBytes(messageID: UUID, destination: AnnotationExchangeDestination) throws -> Data? {
        try requireSchema()
        let values = try database.fetch(query: """
            SELECT payload_base64, payload_digest FROM \(Self.inbox)
            WHERE destination = ? AND account_id = ? AND space_id = ? AND message_id = ?;
            """, parameters: [destination.destination, destination.account, destination.space, messageID.uuidString]) { row in
                guard let encoded = row.string(at: 0), let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
                      let expected = row.string(at: 1), try self.hash(bytes) == expected else { throw AnnotationExchangeError.corruptRecord }
                return bytes
            }
        guard values.count <= 1 else { throw AnnotationExchangeError.corruptRecord }
        return values.first
    }

    private func deliveriesForMutation(_ mutationID: UUID) throws -> [AnnotationExchangeDelivery] {
        try queryDeliveries(where: "o.mutation_id = ? ORDER BY o.destination, o.account_id, o.space_id", parameters: [mutationID.uuidString])
    }

    private func queryDeliveries(where suffix: String, parameters: [Any]) throws -> [AnnotationExchangeDelivery] {
        try database.fetch(query: """
            SELECT o.message_id, v.mutation_id, v.namespace, v.annotation_uuid, v.revision,
                   v.payload_digest, v.payload_base64, v.deletion_state, o.destination, o.account_id, o.space_id, o.status, v.source_digest
            FROM \(Self.outbox) o LEFT JOIN \(Self.versions) v ON v.mutation_id = o.mutation_id WHERE \(suffix);
            """, parameters: parameters) { row in
                guard let message = row.string(at: 0).flatMap(UUID.init(uuidString:)),
                      let mutation = row.string(at: 1).flatMap(UUID.init(uuidString:)),
                      let namespace = row.string(at: 2), AnnotationExchangeValidation.identifier(namespace),
                      let uuid = row.string(at: 3).flatMap(UUID.init(uuidString:)), row.type(at: 4) == SQLITE_INTEGER, row.int64(at: 4) > 0,
                      let expected = row.string(at: 5), AnnotationExchangeValidation.digest(expected),
                      let encoded = row.string(at: 6), let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
                      try self.hash(bytes) == expected,
                      let app = row.string(at: 8), let account = row.string(at: 9), let space = row.string(at: 10),
                      let status = row.string(at: 11), ["pending", "acknowledged"].contains(status),
                      case .supported(let envelope, _) = try TorahAnnotationEnvelopeCodec.decode(bytes),
                      envelope.namespace == namespace, envelope.annotationUUID == uuid,
                      envelope.deletionState.rawValue == row.string(at: 7), envelope.source["snapshotSHA256"]?.string == row.string(at: 12) else {
                    throw AnnotationExchangeError.corruptRecord
                }
                return .init(messageID: message, mutationID: mutation,
                    destination: try .init(destination: app, account: account, space: space), namespace: namespace, annotationUUID: uuid,
                    revision: row.int64(at: 4), payloadDigest: expected, payload: bytes, acknowledged: status == "acknowledged")
            }
    }

    private func requireSchema() throws {
        do {
            let values = try database.fetch(query: "SELECT singleton, version FROM \(Self.schema);") { ($0.int64(at: 0), $0.int64(at: 1)) }
            guard values.count == 1, values[0].0 == 1, values[0].1 == 1 else { throw AnnotationExchangeError.schemaMismatch }
        } catch is CancellationError { throw CancellationError() }
        catch { throw AnnotationExchangeError.schemaMismatch }
    }
    private func hash(_ bytes: Data) throws -> String {
        let result = try digest.sha256(bytes)
        guard AnnotationExchangeValidation.digest(result) else { throw AnnotationExchangeError.corruptRecord }
        return result
    }
}
