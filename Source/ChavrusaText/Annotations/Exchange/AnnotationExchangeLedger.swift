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

    /// Deliberately explicit: construction and read-only discovery never migrate.
    /// An existing v1 store upgrades only inside this same SQLite transaction.
    func installSchema() throws {
        try Task.checkCancellation()
        try database.transaction {
            try requireNoTemporarySchemaShadows()
            let objects = try exchangeSchemaObjects()
            if objects.isEmpty {
                try requirePayloadRebuildIsolation()
                for definition in Self.schemaDefinitions(version: 2) {
                    try database.execute(query: definition.sql)
                }
                try database.execute(query: "INSERT INTO \(Self.schema) (singleton, version) VALUES (1, 2);")
            } else if try verifiedSchemaVersion() == 1 {
                try upgradePayloadStorageLocked()
            }
            guard try verifiedSchemaVersion() == 2 else { throw AnnotationExchangeError.schemaMismatch }
            try Task.checkCancellation()
        }
    }

    /// Original v1 DDL remains the exact migration preimage; only the two stored
    /// envelope limits and the explicit storage-schema version change in v2.
    private static var legacySchemaStatements: [String] {
        return [
            "CREATE TABLE IF NOT EXISTS \(Self.schema) (singleton INTEGER PRIMARY KEY CHECK(singleton = 1), version INTEGER NOT NULL CHECK(typeof(version) = 'integer' AND version = 1));",
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
    }

    private static var exchangeTableNames: [String] {
        [schema, heads, versions, outbox, inbox]
    }

    private static func schemaDefinitions(version: Int64) -> [(name: String, type: String, table: String, sql: String)] {
        let names = exchangeTableNames + ["otzaria_annotation_exchange_pending"]
        return zip(names, legacySchemaStatements).map { name, statement in
            var sql = statement
                .replacingOccurrences(of: "CREATE TABLE IF NOT EXISTS ", with: "CREATE TABLE ")
                .replacingOccurrences(of: "CREATE INDEX IF NOT EXISTS ", with: "CREATE INDEX ")
            if sql.hasSuffix(";") { sql.removeLast() }
            if version == 2 {
                if name == schema { sql = sql.replacingOccurrences(of: "AND version = 1", with: "AND version = 2") }
                if name == versions || name == inbox {
                    sql = sql.replacingOccurrences(of: "BETWEEN 1 AND 87400",
                        with: "BETWEEN 1 AND \(TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes)")
                }
            }
            let isIndex = name == "otzaria_annotation_exchange_pending"
            return (name, isIndex ? "index" : "table", isIndex ? outbox : name, sql)
        }
    }

    private func exchangeSchemaObjects() throws -> [(name: String, type: String, table: String, sql: String?)] {
        let names = Self.exchangeTableNames + ["otzaria_annotation_exchange_pending"]
        return try database.fetch(query: """
            SELECT name, type, tbl_name, sql FROM main.sqlite_master
            WHERE name COLLATE NOCASE IN (?, ?, ?, ?, ?, ?) OR tbl_name COLLATE NOCASE IN (?, ?, ?, ?, ?);
            """, parameters: names + Self.exchangeTableNames) { row in
                (try Self.nativeText(row, 0), try Self.nativeText(row, 1),
                 try Self.nativeText(row, 2), row.isNull(at: 3) ? nil : try Self.nativeText(row, 3))
            }
    }

    private func requireNoTemporarySchemaShadows() throws {
        let names = Self.exchangeTableNames + ["otzaria_annotation_exchange_pending"]
        let temporary = try database.fetch(query: "SELECT name, tbl_name, sql FROM sqlite_temp_master;") { row in
            (try Self.nativeText(row, 0), try Self.nativeText(row, 1), row.string(at: 2) ?? "")
        }
        guard temporary.allSatisfy({ object in
            !names.contains(where: { name in
                object.0.lowercased() == name || object.1.lowercased() == name
                    || object.2.lowercased().contains(name)
            })
        }) else { throw AnnotationExchangeError.schemaMismatch }
    }

    private func verifiedSchemaVersion() throws -> Int64 {
        try requireNoTemporarySchemaShadows()
        let values = try database.fetch(query: "SELECT singleton, version FROM main.\(Self.schema);") { row in
            (row.type(at: 0), row.int64(at: 0), row.type(at: 1), row.int64(at: 1))
        }
        guard values.count == 1, values[0].0 == SQLITE_INTEGER, values[0].1 == 1,
              values[0].2 == SQLITE_INTEGER, [Int64(1), 2].contains(values[0].3) else {
            throw AnnotationExchangeError.schemaMismatch
        }
        let version = values[0].3
        let definitions = Self.schemaDefinitions(version: version)
        let objects = try exchangeSchemaObjects()
        for definition in definitions {
            let matches = objects.filter { $0.name == definition.name }
            // SQLite's own ALTER TABLE RENAME quotes the final table header.
            // Accept only that exact known variant, not general SQL rewriting.
            let quoted = definition.sql.replacingOccurrences(
                of: "CREATE TABLE \(definition.name) (", with: "CREATE TABLE \"\(definition.name)\" (")
            guard matches.count == 1, let actual = matches.first,
                  actual.type == definition.type, actual.table == definition.table,
                  actual.sql == definition.sql || (definition.type == "table" && actual.sql == quoted) else {
                throw AnnotationExchangeError.schemaMismatch
            }
        }
        let explicit = Set(definitions.map(\.name))
        let expectedAutomatic = Set([
            "sqlite_autoindex_\(Self.heads)_1",
            "sqlite_autoindex_\(Self.versions)_1", "sqlite_autoindex_\(Self.versions)_2",
            "sqlite_autoindex_\(Self.outbox)_1", "sqlite_autoindex_\(Self.outbox)_2",
            "sqlite_autoindex_\(Self.inbox)_1"
        ])
        let automatic = objects.filter { !explicit.contains($0.name) }
        guard automatic.count == expectedAutomatic.count, Set(automatic.map(\.name)) == expectedAutomatic,
              automatic.allSatisfy({ $0.type == "index" && $0.sql == nil
                  && $0.name.hasPrefix("sqlite_autoindex_" + $0.table + "_") }) else {
            throw AnnotationExchangeError.schemaMismatch
        }
        return version
    }

    private func requirePayloadRebuildIsolation() throws {
        let targets = [Self.schema, Self.versions, Self.inbox]
        let temporaryNames = targets.map { $0 + "__payload_v2" }
        let allObjects = try database.fetch(query: "SELECT name, tbl_name, sql FROM main.sqlite_master;") { row in
            (try Self.nativeText(row, 0), try Self.nativeText(row, 1), row.string(at: 2))
        }
        // The original schema has no incoming reference to these three tables.
        // Refuse unknown dependencies rather than disable foreign keys or rewrite
        // another object's SQL. Heads, outbox and native history remain in place.
        guard allObjects.allSatisfy({ object in
            guard !temporaryNames.contains(object.0.lowercased()),
                  !temporaryNames.contains(object.1.lowercased()) else { return false }
            if targets.contains(object.1) { return true }
            guard let sql = object.2?.lowercased() else { return true }
            return !targets.contains(where: { sql.contains($0) })
        }) else { throw AnnotationExchangeError.schemaMismatch }
    }

    private func upgradePayloadStorageLocked() throws {
        guard try verifiedSchemaVersion() == 1 else { throw AnnotationExchangeError.schemaMismatch }
        let rebuilt: [(name: String, columns: [String])] = [
            (Self.schema, ["singleton", "version"]),
            (Self.versions, ["mutation_id", "namespace", "annotation_uuid", "revision", "source_digest",
                "payload_digest", "payload_base64", "deletion_state", "destinations_json"]),
            (Self.inbox, ["message_id", "destination", "account_id", "space_id", "namespace", "annotation_uuid",
                "revision", "payload_digest", "payload_base64", "envelope_version", "status"])
        ]
        let targets = rebuilt.map(\.name)
        let temporaryNames = targets.map { $0 + "__payload_v2" }
        try requirePayloadRebuildIsolation()
        let definitions = Self.schemaDefinitions(version: 2)
        for (index, item) in rebuilt.enumerated() {
            try Task.checkCancellation()
            guard let definition = definitions.first(where: { $0.name == item.name }) else {
                throw AnnotationExchangeError.schemaMismatch
            }
            let temporary = temporaryNames[index]
            let create = definition.sql.replacingOccurrences(
                of: "CREATE TABLE \(item.name) (", with: "CREATE TABLE \(temporary) (")
            try database.execute(query: create)
            let columns = (["rowid"] + item.columns).joined(separator: ", ")
            let selected = (["rowid"] + item.columns.map { item.name == Self.schema && $0 == "version" ? "2" : $0 })
                .joined(separator: ", ")
            try database.execute(query: "INSERT INTO \(temporary) (\(columns)) SELECT \(selected) FROM \(item.name);")
            let preserved = ["rowid"] + item.columns.filter { !(item.name == Self.schema && $0 == "version") }
            // Compare storage class and complete bytes in both directions.
            // Text equality alone could overlook embedded NUL/invalid UTF-8.
            let projection = preserved.flatMap { ["typeof(\($0))", "hex(CAST(\($0) AS BLOB))"] }
                .joined(separator: ", ")
            for (left, right) in [(item.name, temporary), (temporary, item.name)] {
                let differences = try database.fetch(query: """
                    SELECT COUNT(*) FROM (
                        SELECT \(projection) FROM \(left) EXCEPT SELECT \(projection) FROM \(right)
                    );
                    """) { $0.int64(at: 0) }
                guard differences == [0] else { throw AnnotationExchangeError.corruptRecord }
            }
        }
        for (index, item) in rebuilt.enumerated() {
            try Task.checkCancellation()
            try database.execute(query: "DROP TABLE \(item.name);")
            try database.execute(query: "ALTER TABLE \(temporaryNames[index]) RENAME TO \(item.name);")
        }
        guard try verifiedSchemaVersion() == 2 else { throw AnnotationExchangeError.schemaMismatch }
        try Task.checkCancellation()
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
        let rows: [(Int64, ActionObject)]
        if let recordID = try AnnotationExchangeIdentity.originalRecordID(database: database, annotationUUID: annotationUUID) {
            rows = try database.fetch(
            query: "SELECT * FROM main.annotations WHERE ckRecordId = ? COLLATE BINARY;",
            parameters: [recordID]) { row in
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
        } else {
            rows = []
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
            try installSchema()
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
                if localOnly && !deliveries.isEmpty {
                    try requireLinkedLocalReplay(deliveries)
                } else {
                    guard Set(deliveries.map(\.destination)) == Set(destinations), deliveries.count == destinations.count else {
                        throw AnnotationExchangeError.corruptRecord
                    }
                }
                answer = .init(mutationID: mutationID, namespace: envelope.namespace, annotationUUID: envelope.annotationUUID,
                    revision: prior.2, payloadDigest: payloadHash, replayed: true, deliveries: localOnly ? [] : deliveries)
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
                      encoded.utf8.count <= TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes,
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
            try installSchema()
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
                guard let encoded = row.string(at: 0),
                      encoded.utf8.count <= TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes,
                      let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
                      bytes.count <= TorahAnnotationEnvelopeCodec.maximumBytes,
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
                      let encoded = row.string(at: 6),
                      encoded.utf8.count <= TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes,
                      let bytes = Data(base64Encoded: encoded), bytes.base64EncodedString() == encoded,
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
            _ = try verifiedSchemaVersion()
        } catch is CancellationError { throw CancellationError() }
        catch { throw AnnotationExchangeError.schemaMismatch }
    }
    private func hash(_ bytes: Data) throws -> String {
        let result = try digest.sha256(bytes)
        guard AnnotationExchangeValidation.digest(result) else { throw AnnotationExchangeError.corruptRecord }
        return result
    }
}


/// Local persistence facts only. A stored native object ID is not a fresh
/// native readback, an account/Space authority, or proof that a body was applied.
struct AnnotationExchangeNativeIdentityRecord: Sendable, Equatable {
    let destination: AnnotationExchangeDestination
    let namespace: String
    let annotationUUID: UUID
    let messageID: UUID
    let nativeObjectID: String
}

struct AnnotationExchangeNativeCreationFence: Sendable, Equatable {
    enum DispatchState: String, Sendable {
        case prepared
        case dispatchMayHaveOccurred = "dispatch_may_have_occurred"
    }
    let delivery: AnnotationExchangeDelivery
    let dispatchState: DispatchState
}

enum AnnotationExchangeNativeCreationError: Error, Sendable, Equatable {
    case commitmentNotPending
    case nonMaterializable
    case conflictingAttempt
    case noPreparedAttempt
    case dispatchMayHaveOccurred
    case identityAlreadyRecorded
    case nestedDispatchTransition
}

/// Explicit opt-in persistence for the existing outbox's native create intent.
/// No RPC, recovery search, native identity write, ACK or automatic reset lives
/// here. Original SDK identity/body receipts and their owner validation remain
/// prerequisites for future transport integration.
extension AnnotationExchangeLedger {
    private enum NativeCreationTables {
        static let schema = "otzaria_annotation_exchange_native_schema"
        static let attempts = "otzaria_annotation_exchange_native_create_attempts"
        static let identities = "otzaria_annotation_exchange_native_identities"
    }

    private static var nativeCreationStatements: [(name: String, sql: String)] {
        [
            (NativeCreationTables.schema, """
                CREATE TABLE \(NativeCreationTables.schema) (
                    singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
                    version INTEGER NOT NULL CHECK(typeof(version) = 'integer' AND version = 1)
                )
                """),
            (NativeCreationTables.attempts, """
                CREATE TABLE \(NativeCreationTables.attempts) (
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    message_id TEXT NOT NULL CHECK(length(message_id) = 36),
                    dispatch_state TEXT NOT NULL CHECK(dispatch_state IN ('prepared', 'dispatch_may_have_occurred')),
                    PRIMARY KEY(destination, account_id, space_id, namespace, annotation_uuid),
                    UNIQUE(message_id),
                    FOREIGN KEY(message_id) REFERENCES \(Self.outbox)(message_id)
                )
                """),
            (NativeCreationTables.identities, """
                CREATE TABLE \(NativeCreationTables.identities) (
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    message_id TEXT NOT NULL CHECK(length(message_id) = 36),
                    native_object_id TEXT NOT NULL CHECK(length(native_object_id) BETWEEN 1 AND 512),
                    PRIMARY KEY(destination, account_id, space_id, namespace, annotation_uuid),
                    UNIQUE(destination, account_id, space_id, native_object_id),
                    UNIQUE(message_id),
                    FOREIGN KEY(message_id) REFERENCES \(Self.outbox)(message_id)
                )
                """)
        ]
    }

    /// Does not install the base ledger or change PRAGMA user_version. A partial,
    /// altered or future extension is refused, never repaired or backfilled.
    func installNativeCreationSchema() throws {
        try Task.checkCancellation()
        try database.transaction {
            guard try hasInstalledSchema() else { throw AnnotationExchangeError.schemaMismatch }
            if try nativeCreationSchemaObjects().isEmpty {
                for item in Self.nativeCreationStatements { try database.execute(query: item.sql) }
                try database.execute(query: "INSERT INTO \(NativeCreationTables.schema) (singleton, version) VALUES (1, 1);")
            }
            try requireNativeCreationSchema()
            try Task.checkCancellation()
        }
    }

    func hasNativeCreationSchema() throws -> Bool {
        try Task.checkCancellation()
        var installed = false
        try database.transaction {
            if try nativeCreationSchemaObjects().isEmpty { return }
            try requireNativeCreationSchema()
            installed = true
        }
        return installed
    }

    /// Records only an exact currently pending, active rich-body commitment on
    /// the original source. It neither validates a native body format nor grants
    /// permission to create an object. The facade must revalidate its real owner.
    func prepareNativeCreation(for delivery: AnnotationExchangeDelivery) throws -> AnnotationExchangeNativeCreationFence {
        try Task.checkCancellation()
        var result: AnnotationExchangeNativeCreationFence?
        try database.transaction {
            try requireNativeCreationSchema()
            let actual = try requireMaterializablePendingDelivery(delivery)
            if try nativeIdentityLocked(destination: actual.destination, namespace: actual.namespace,
                                        annotationUUID: actual.annotationUUID) != nil {
                throw AnnotationExchangeNativeCreationError.identityAlreadyRecorded
            }
            if let prior = try nativeCreationFenceLocked(destination: actual.destination, namespace: actual.namespace,
                                                         annotationUUID: actual.annotationUUID) {
                guard prior.delivery == actual else { throw AnnotationExchangeNativeCreationError.conflictingAttempt }
                result = prior
            } else {
                try database.execute(query: """
                    INSERT INTO \(NativeCreationTables.attempts)
                    (destination, account_id, space_id, namespace, annotation_uuid, message_id, dispatch_state)
                    VALUES (?, ?, ?, ?, ?, ?, 'prepared');
                    """, parameters: try nativeScope(actual.destination, actual.namespace, actual.annotationUUID) + [actual.messageID.uuidString])
                result = try nativeCreationFenceLocked(destination: actual.destination, namespace: actual.namespace,
                                                       annotationUUID: actual.annotationUUID)
            }
            guard result?.delivery == actual else { throw AnnotationExchangeError.corruptRecord }
            try Task.checkCancellation()
        }
        guard let result else { throw AnnotationExchangeError.corruptRecord }
        return result
    }

    /// The first transition commits before a caller could invoke the original
    /// RPC. A repeated transition is uncertainty, never a fresh dispatch permit.
    /// This method performs no RPC and cannot prove that one occurred.
    func markNativeCreationMayHaveDispatched(_ delivery: AnnotationExchangeDelivery) throws -> AnnotationExchangeNativeCreationFence {
        try Task.checkCancellation()
        var result: AnnotationExchangeNativeCreationFence?
        try database.withSerializedAccess {
            // A released SAVEPOINT is not durable while an outer transaction
            // can still roll back. Keep the original connection lock through
            // the actual outermost COMMIT before returning this stored fact.
            guard sqlite3_get_autocommit(database.dbPointer) != 0 else {
                throw AnnotationExchangeNativeCreationError.nestedDispatchTransition
            }
            try database.transaction {
                try requireNativeCreationSchema()
                let actual = try requireMaterializablePendingDelivery(delivery)
                if try nativeIdentityLocked(destination: actual.destination, namespace: actual.namespace,
                                            annotationUUID: actual.annotationUUID) != nil {
                    throw AnnotationExchangeNativeCreationError.identityAlreadyRecorded
                }
                guard let prior = try nativeCreationFenceLocked(destination: actual.destination, namespace: actual.namespace,
                                                                annotationUUID: actual.annotationUUID) else {
                    throw AnnotationExchangeNativeCreationError.noPreparedAttempt
                }
                guard prior.delivery == actual else { throw AnnotationExchangeNativeCreationError.conflictingAttempt }
                guard prior.dispatchState == .prepared else { throw AnnotationExchangeNativeCreationError.dispatchMayHaveOccurred }
                try database.execute(query: """
                    UPDATE \(NativeCreationTables.attempts) SET dispatch_state = 'dispatch_may_have_occurred'
                    WHERE destination = ? AND account_id = ? AND space_id = ? AND namespace = ? AND annotation_uuid COLLATE NOCASE = ?
                        AND message_id = ? AND dispatch_state = 'prepared';
                    """, parameters: try nativeScope(actual.destination, actual.namespace, actual.annotationUUID) + [actual.messageID.uuidString])
                result = try nativeCreationFenceLocked(destination: actual.destination, namespace: actual.namespace,
                                                       annotationUUID: actual.annotationUUID)
                guard result?.delivery == actual, result?.dispatchState == .dispatchMayHaveOccurred else {
                    throw AnnotationExchangeError.corruptRecord
                }
                try Task.checkCancellation()
            }
            guard sqlite3_get_autocommit(database.dbPointer) != 0 else {
                throw AnnotationExchangeError.corruptRecord
            }
        }
        guard let result else { throw AnnotationExchangeError.corruptRecord }
        return result
    }

    /// Recovery reads the earlier commitment even when a newer local revision
    /// exists. An empty native search cannot erase this durable uncertainty.
    func nativeCreationFence(destination: AnnotationExchangeDestination, namespace: String,
                             annotationUUID: UUID) throws -> AnnotationExchangeNativeCreationFence? {
        try Task.checkCancellation()
        var result: AnnotationExchangeNativeCreationFence?
        try database.transaction {
            try requireNativeCreationSchema()
            result = try nativeCreationFenceLocked(destination: destination, namespace: namespace, annotationUUID: annotationUUID)
        }
        return result
    }

    /// Read-only observation; never authority or a fresh native/body receipt.
    /// No production identity writer exists until the original SDK's opaque
    /// owner-checked readback receipt can be consumed by the real facade.
    func recordedNativeIdentity(destination: AnnotationExchangeDestination, namespace: String,
                                annotationUUID: UUID) throws -> AnnotationExchangeNativeIdentityRecord? {
        try Task.checkCancellation()
        var result: AnnotationExchangeNativeIdentityRecord?
        try database.transaction {
            try requireNativeCreationSchema()
            result = try nativeIdentityLocked(destination: destination, namespace: namespace, annotationUUID: annotationUUID)
        }
        return result
    }

    private func requireMaterializablePendingDelivery(_ supplied: AnnotationExchangeDelivery) throws -> AnnotationExchangeDelivery {
        let rows = try queryDeliveries(where: "o.message_id = ?", parameters: [supplied.messageID.uuidString])
        guard rows.count == 1, let actual = rows.first, actual == supplied, !actual.acknowledged else {
            throw AnnotationExchangeNativeCreationError.commitmentNotPending
        }
        guard case .supported(let envelope, _) = try TorahAnnotationEnvelopeCodec.decode(actual.payload),
              envelope.deletionState == .active, envelope.richBody != nil else {
            throw AnnotationExchangeNativeCreationError.nonMaterializable
        }
        guard try currentRevisionLocked(namespace: actual.namespace, annotationUUID: actual.annotationUUID) == actual.revision else {
            throw AnnotationExchangeError.staleRevision
        }
        let current = try captureSourceLocked(annotationUUID: actual.annotationUUID)
        guard current.exists, current.metadata == envelope.source else { throw AnnotationExchangeError.staleSource }
        return actual
    }

    private func nativeCreationFenceLocked(destination: AnnotationExchangeDestination, namespace: String,
                                          annotationUUID: UUID) throws -> AnnotationExchangeNativeCreationFence? {
        // Find UUID case variants before validating canonical stored text.
        // Otherwise an earlier uncertain row could disappear from this scope.
        let rows = try database.fetch(query: """
            SELECT message_id, dispatch_state, annotation_uuid FROM \(NativeCreationTables.attempts)
            WHERE destination = ? AND account_id = ? AND space_id = ? AND namespace = ? AND annotation_uuid COLLATE NOCASE = ?;
            """, parameters: try nativeScope(destination, namespace, annotationUUID)) { row in
                (try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2))
            }
        guard rows.count <= 1 else { throw AnnotationExchangeError.corruptRecord }
        guard let row = rows.first else { return nil }
        guard let storedAnnotation = UUID(uuidString: row.2), storedAnnotation == annotationUUID,
              storedAnnotation.uuidString == row.2,
              let message = UUID(uuidString: row.0), message.uuidString == row.0,
              let state = AnnotationExchangeNativeCreationFence.DispatchState(rawValue: row.1) else {
            throw AnnotationExchangeError.corruptRecord
        }
        let deliveries = try queryDeliveries(where: "o.message_id = ?", parameters: [message.uuidString])
        guard deliveries.count == 1, let actual = deliveries.first, actual.destination == destination,
              actual.namespace == namespace, actual.annotationUUID == annotationUUID else {
            throw AnnotationExchangeError.corruptRecord
        }
        return .init(delivery: actual, dispatchState: state)
    }

    private func nativeIdentityLocked(destination: AnnotationExchangeDestination, namespace: String,
                                      annotationUUID: UUID) throws -> AnnotationExchangeNativeIdentityRecord? {
        let rows = try database.fetch(query: """
            SELECT message_id, native_object_id, annotation_uuid FROM \(NativeCreationTables.identities)
            WHERE destination = ? AND account_id = ? AND space_id = ? AND namespace = ? AND annotation_uuid COLLATE NOCASE = ?;
            """, parameters: try nativeScope(destination, namespace, annotationUUID)) { row in
                (try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2))
            }
        guard rows.count <= 1 else { throw AnnotationExchangeError.corruptRecord }
        guard let row = rows.first else { return nil }
        guard let storedAnnotation = UUID(uuidString: row.2), storedAnnotation == annotationUUID,
              storedAnnotation.uuidString == row.2,
              let message = UUID(uuidString: row.0), message.uuidString == row.0,
              AnnotationExchangeValidation.identifier(row.1),
              let fence = try nativeCreationFenceLocked(destination: destination, namespace: namespace, annotationUUID: annotationUUID),
              fence.delivery.messageID == message else {
            throw AnnotationExchangeError.corruptRecord
        }
        return .init(destination: destination, namespace: namespace, annotationUUID: annotationUUID,
                     messageID: message, nativeObjectID: row.1)
    }

    private func nativeScope(_ destination: AnnotationExchangeDestination, _ namespace: String, _ uuid: UUID) throws -> [Any] {
        guard AnnotationExchangeValidation.identifier(namespace) else { throw AnnotationExchangeError.invalidScope }
        return [destination.destination, destination.account, destination.space, namespace, uuid.uuidString]
    }

    private static func nativeText(_ row: SQLiteRow, _ index: Int32) throws -> String {
        guard row.type(at: index) == SQLITE_TEXT, let value = row.string(at: index),
              value.utf8.count == Int(sqlite3_column_bytes(row.stmt, index)) else {
            throw AnnotationExchangeError.corruptRecord
        }
        return value
    }

    private func nativeCreationSchemaObjects() throws -> [(name: String, type: String, table: String, sql: String?)] {
        let names = Self.nativeCreationStatements.map(\.name)
        return try database.fetch(query: """
            SELECT name, type, tbl_name, sql FROM sqlite_master
            WHERE name COLLATE NOCASE IN (?, ?, ?) OR tbl_name COLLATE NOCASE IN (?, ?, ?);
            """, parameters: names + names) { row in
                (try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2), row.string(at: 3))
            }
    }

    private func requireNativeCreationSchema() throws {
        guard try hasInstalledSchema() else { throw AnnotationExchangeError.schemaMismatch }
        let statements = Self.nativeCreationStatements
        let rows = try nativeCreationSchemaObjects()
        let tables = rows.filter { $0.type == "table" }
        guard tables.count == statements.count, Set(tables.map(\.name)) == Set(statements.map(\.name)) else {
            throw AnnotationExchangeError.schemaMismatch
        }
        for item in statements {
            guard let table = tables.first(where: { $0.name == item.name }),
                  table.table == item.name, table.sql == item.sql else { throw AnnotationExchangeError.schemaMismatch }
        }
        // Only SQLite's implicit indexes from the exact owned DDL are allowed.
        // A trigger or altered unique index cannot secretly modify an ACK/row.
        guard rows.filter({ $0.type != "table" }).allSatisfy({
            $0.type == "index" && $0.sql == nil && $0.name.hasPrefix("sqlite_autoindex_" + $0.table + "_")
        }) else { throw AnnotationExchangeError.schemaMismatch }
        let version = try database.fetch(query: "SELECT singleton, version FROM \(NativeCreationTables.schema);") { row in
            (row.type(at: 0), row.int64(at: 0), row.type(at: 1), row.int64(at: 1))
        }
        guard version.count == 1, version[0].0 == SQLITE_INTEGER, version[0].1 == 1,
              version[0].2 == SQLITE_INTEGER, version[0].3 == 1 else { throw AnnotationExchangeError.schemaMismatch }
    }
}

// Durable consent and transport state extend the original exchange ledger.
// They never own an account, create a native object, or infer a peer ACK.
struct AnnotationExchangeNativeReadOrigin: Sendable, Equatable {
    let destination: AnnotationExchangeDestination
    let objectID: String
    let nativeRootSHA256: String
    let nativeResponseSHA256: String
}

struct AnnotationExchangeNativeLink: Sendable, Equatable {
    let id: UUID
    let namespace: String
    let annotationUUID: UUID
    let destination: AnnotationExchangeDestination
    let objectID: String
    let nativeRootSHA256: String
    let confirmedLocalRevision: Int64
    let active: Bool
}

struct AnnotationExchangeLinkedDelivery: Sendable, Equatable {
    enum State: String, Sendable {
        case pending, dispatchMayHaveOccurred = "dispatch_may_have_occurred"
        case verified, needsReview = "needs_review", superseded, unlinked
    }
    let delivery: AnnotationExchangeDelivery
    let link: AnnotationExchangeNativeLink
    let state: State
    let retryCount: Int64
    let notBefore: Int64
    let attemptID: UUID?
}

extension AnnotationExchangeLedger {
    private enum LinkedTables {
        static let links = "otzaria_annotation_exchange_links"
        static let deliveries = "otzaria_annotation_exchange_linked_deliveries"
        static let incoming = "otzaria_annotation_exchange_linked_incoming"
        static let reviews = "otzaria_annotation_exchange_linked_reviews"
    }

    private static var linkedDefinitions: [(name: String, type: String, table: String, sql: String)] {
        let links = LinkedTables.links, deliveries = LinkedTables.deliveries, incoming = LinkedTables.incoming, reviews = LinkedTables.reviews
        return [
            (links, "table", links, """
                CREATE TABLE \(links) (
                    link_id TEXT PRIMARY KEY NOT NULL CHECK(length(link_id) = 36),
                    namespace TEXT NOT NULL CHECK(length(namespace) BETWEEN 1 AND 512),
                    annotation_uuid TEXT NOT NULL CHECK(length(annotation_uuid) = 36),
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    native_object_id TEXT NOT NULL CHECK(length(native_object_id) BETWEEN 1 AND 512),
                    native_root_sha256 TEXT NOT NULL CHECK(length(native_root_sha256) = 64),
                    confirmed_local_revision INTEGER NOT NULL CHECK(typeof(confirmed_local_revision) = 'integer' AND confirmed_local_revision > 0),
                    active INTEGER NOT NULL CHECK(typeof(active) = 'integer' AND active IN (0, 1))
                )
                """),
            (links + "_active_scope", "index", links, "CREATE UNIQUE INDEX \(links)_active_scope ON \(links)(namespace, annotation_uuid, destination, account_id, space_id) WHERE active = 1"),
            (links + "_active_object", "index", links, "CREATE UNIQUE INDEX \(links)_active_object ON \(links)(destination, account_id, space_id, native_object_id) WHERE active = 1"),
            (deliveries, "table", deliveries, """
                CREATE TABLE \(deliveries) (
                    message_id TEXT PRIMARY KEY NOT NULL CHECK(length(message_id) = 36),
                    link_id TEXT NOT NULL CHECK(length(link_id) = 36),
                    state TEXT NOT NULL CHECK(state IN ('pending', 'dispatch_may_have_occurred', 'verified', 'needs_review', 'superseded', 'unlinked')),
                    retry_count INTEGER NOT NULL DEFAULT 0 CHECK(typeof(retry_count) = 'integer' AND retry_count BETWEEN 0 AND 1000000),
                    not_before INTEGER NOT NULL DEFAULT 0 CHECK(typeof(not_before) = 'integer' AND not_before >= 0),
                    attempt_id TEXT CHECK(attempt_id IS NULL OR length(attempt_id) = 36),
                    expected_root_sha256 TEXT CHECK(expected_root_sha256 IS NULL OR length(expected_root_sha256) = 64),
                    native_root_sha256 TEXT CHECK(native_root_sha256 IS NULL OR length(native_root_sha256) = 64),
                    native_response_sha256 TEXT CHECK(native_response_sha256 IS NULL OR length(native_response_sha256) = 64),
                    FOREIGN KEY(message_id) REFERENCES \(Self.outbox)(message_id),
                    FOREIGN KEY(link_id) REFERENCES \(links)(link_id)
                )
                """),
            (incoming, "table", incoming, """
                CREATE TABLE \(incoming) (
                    mutation_id TEXT PRIMARY KEY NOT NULL CHECK(length(mutation_id) = 36),
                    destination TEXT NOT NULL CHECK(length(destination) BETWEEN 1 AND 512),
                    account_id TEXT NOT NULL CHECK(length(account_id) BETWEEN 1 AND 512),
                    space_id TEXT NOT NULL CHECK(length(space_id) BETWEEN 1 AND 512),
                    native_object_id TEXT NOT NULL CHECK(length(native_object_id) BETWEEN 1 AND 512),
                    native_root_sha256 TEXT NOT NULL CHECK(length(native_root_sha256) = 64),
                    native_response_sha256 TEXT NOT NULL CHECK(length(native_response_sha256) = 64),
                    enable_link INTEGER NOT NULL CHECK(typeof(enable_link) = 'integer' AND enable_link IN (0, 1)),
                    FOREIGN KEY(mutation_id) REFERENCES \(Self.versions)(mutation_id)
                )
                """),
            (reviews, "table", reviews, """
                CREATE TABLE \(reviews) (
                    review_id TEXT PRIMARY KEY NOT NULL CHECK(length(review_id) = 36),
                    message_id TEXT NOT NULL CHECK(length(message_id) = 36),
                    prior_state TEXT NOT NULL,
                    prior_attempt_id TEXT,
                    native_root_sha256 TEXT NOT NULL CHECK(length(native_root_sha256) = 64),
                    native_response_sha256 TEXT NOT NULL CHECK(length(native_response_sha256) = 64),
                    FOREIGN KEY(message_id) REFERENCES \(Self.outbox)(message_id)
                )
                """)
        ]
    }

    /// Read-only discovery does not create even an empty extension.
    func hasLinkedSyncSchema() throws -> Bool {
        let names = Self.linkedDefinitions.map(\.name)
        let objects = try database.fetch(query: "SELECT name, type, tbl_name, sql FROM main.sqlite_master;") { row in
            (try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2), row.string(at: 3))
        }.filter { names.contains($0.0.lowercased()) || names.contains($0.2.lowercased()) }
        if objects.isEmpty { return false }
        guard try hasInstalledSchema() else { throw AnnotationExchangeError.schemaMismatch }
        let shadows = try database.fetch(query: "SELECT name, tbl_name, coalesce(sql, '') FROM sqlite_temp_master;") { row in
            [try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2)]
        }
        guard !shadows.contains(where: { row in row.contains(where: { text in names.contains(where: { text.lowercased().contains($0) }) }) }) else {
            throw AnnotationExchangeError.schemaMismatch
        }
        for definition in Self.linkedDefinitions {
            let matches = objects.filter { $0.0 == definition.name }
            guard matches.count == 1, let actual = matches.first, actual.1 == definition.type,
                  actual.2 == definition.table, actual.3 == definition.sql else { throw AnnotationExchangeError.schemaMismatch }
        }
        let implicit = objects.filter { !names.contains($0.0) }
        let expected = Set([LinkedTables.links, LinkedTables.deliveries, LinkedTables.incoming, LinkedTables.reviews].map { "sqlite_autoindex_" + $0 + "_1" })
        guard implicit.count == expected.count, Set(implicit.map { $0.0 }) == expected,
              implicit.allSatisfy({ $0.1 == "index" && $0.3 == nil }) else { throw AnnotationExchangeError.schemaMismatch }
        return true
    }

    private func installLinkedSyncSchema() throws {
        guard try hasInstalledSchema() else { throw AnnotationExchangeError.schemaMismatch }
        if !(try hasLinkedSyncSchema()) {
            for definition in Self.linkedDefinitions { try database.execute(query: definition.sql) }
        }
        guard try hasLinkedSyncSchema() else { throw AnnotationExchangeError.schemaMismatch }
    }

    func nativeLinks(namespace: String, annotationUUID: UUID, activeOnly: Bool = true) throws -> [AnnotationExchangeNativeLink] {
        guard AnnotationExchangeValidation.identifier(namespace) else { throw AnnotationExchangeError.invalidScope }
        guard try hasLinkedSyncSchema() else { return [] }
        return try linkedRows(where: "namespace = ? AND annotation_uuid = ?" + (activeOnly ? " AND active = 1" : ""),
                              parameters: [namespace, annotationUUID.uuidString])
    }

    private func linkedRows(where predicate: String, parameters: [Any]) throws -> [AnnotationExchangeNativeLink] {
        try database.fetch(query: """
            SELECT link_id, namespace, annotation_uuid, destination, account_id, space_id,
                   native_object_id, native_root_sha256, confirmed_local_revision, active
            FROM main.\(LinkedTables.links) WHERE \(predicate) ORDER BY link_id;
            """, parameters: parameters) { row in
                let idText = try Self.nativeText(row, 0), ns = try Self.nativeText(row, 1), uuidText = try Self.nativeText(row, 2)
                let object = try Self.nativeText(row, 6), root = try Self.nativeText(row, 7)
                guard let id = UUID(uuidString: idText), id.uuidString == idText,
                      let uuid = UUID(uuidString: uuidText), uuid.uuidString == uuidText,
                      AnnotationExchangeValidation.identifier(ns), AnnotationExchangeValidation.identifier(object),
                      AnnotationExchangeValidation.digest(root), row.type(at: 8) == SQLITE_INTEGER, row.int64(at: 8) > 0,
                      row.type(at: 9) == SQLITE_INTEGER, [Int64(0), 1].contains(row.int64(at: 9)) else { throw AnnotationExchangeError.corruptRecord }
                return .init(id: id, namespace: ns, annotationUUID: uuid,
                    destination: try .init(destination: Self.nativeText(row, 3), account: Self.nativeText(row, 4), space: Self.nativeText(row, 5)),
                    objectID: object, nativeRootSHA256: root, confirmedLocalRevision: row.int64(at: 8), active: row.int64(at: 9) == 1)
            }
    }

    /// Called inside the SAME original Save transaction, after a sealed native
    /// read is accepted locally. Consent never fabricates a remote identity.
    func acceptNativeOrigin(_ origin: AnnotationExchangeNativeReadOrigin, version: AnnotationExchangeVersion, enableLink: Bool) throws {
        guard sqlite3_get_autocommit(database.dbPointer) == 0 else { throw AnnotationExchangeError.receiptMismatch }
        try validateNativeOrigin(origin)
        guard try self.version(mutationID: version.mutationID) == version else { throw AnnotationExchangeError.receiptMismatch }
        try installLinkedSyncSchema()
        _ = try recordIncoming(messageID: version.mutationID, destination: origin.destination,
            namespace: version.namespace, annotationUUID: version.annotationUUID, revision: version.revision,
            payload: version.payload, expectedDigest: version.payloadDigest)
        try database.execute(query: """
            INSERT INTO main.\(LinkedTables.incoming)
            (mutation_id, destination, account_id, space_id, native_object_id, native_root_sha256, native_response_sha256, enable_link)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """, parameters: [version.mutationID.uuidString, origin.destination.destination, origin.destination.account,
                origin.destination.space, origin.objectID, origin.nativeRootSHA256, origin.nativeResponseSHA256, enableLink ? Int64(1) : Int64(0)])
        let links = try nativeLinks(namespace: version.namespace, annotationUUID: version.annotationUUID)
        if let link = links.first(where: { $0.destination == origin.destination }) {
            guard link.objectID == origin.objectID else { throw AnnotationExchangeError.receiptMismatch }
            try database.execute(query: "UPDATE main.\(LinkedTables.links) SET native_root_sha256 = ?, confirmed_local_revision = ? WHERE link_id = ? AND active = 1;",
                parameters: [origin.nativeRootSHA256, version.revision, link.id.uuidString])
            // A received version supersedes only undispatched local work.
            // An earlier uncertain native call is retained for explicit review.
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'superseded' WHERE link_id = ? AND state = 'pending';", parameters: [link.id.uuidString])
        } else if enableLink {
            try database.execute(query: """
                INSERT INTO main.\(LinkedTables.links)
                (link_id, namespace, annotation_uuid, destination, account_id, space_id, native_object_id, native_root_sha256, confirmed_local_revision, active)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
                """, parameters: [UUID().uuidString, version.namespace, version.annotationUUID.uuidString,
                    origin.destination.destination, origin.destination.account, origin.destination.space,
                    origin.objectID, origin.nativeRootSHA256, version.revision])
        }
    }

    /// The immutable version remains an ordinary local commitment with []. The
    /// additional outbox rows are independently justified by explicit live links.
    /// Unlinked and Backfill paths perform no extension DDL or queue mutation.
    func enqueueLinkedVersion(_ version: AnnotationExchangeVersion, suppressing origin: AnnotationExchangeNativeReadOrigin? = nil) throws {
        guard sqlite3_get_autocommit(database.dbPointer) == 0 else { throw AnnotationExchangeError.receiptMismatch }
        guard try hasLinkedSyncSchema() else { return }
        guard try self.version(mutationID: version.mutationID) == version, version.destinationsJSON == "[]" else { throw AnnotationExchangeError.receiptMismatch }
        for link in try nativeLinks(namespace: version.namespace, annotationUUID: version.annotationUUID) {
            if let origin, link.destination == origin.destination, link.objectID == origin.objectID { continue }
            let old = try deliveriesForMutation(version.mutationID).filter { $0.destination == link.destination }
            if let existing = old.first {
                guard old.count == 1, try linkedDelivery(messageID: existing.messageID)?.link.id == link.id else { throw AnnotationExchangeError.corruptRecord }
                continue
            }
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'superseded' WHERE link_id = ? AND state = 'pending';", parameters: [link.id.uuidString])
            let message = UUID()
            try database.execute(query: "INSERT INTO \(Self.outbox) (message_id, mutation_id, destination, account_id, space_id, status) VALUES (?, ?, ?, ?, ?, 'pending');",
                parameters: [message.uuidString, version.mutationID.uuidString, link.destination.destination, link.destination.account, link.destination.space])
            try database.execute(query: "INSERT INTO main.\(LinkedTables.deliveries) (message_id, link_id, state) VALUES (?, ?, 'pending');",
                parameters: [message.uuidString, link.id.uuidString])
        }
    }

    func linkedDeliveries(for link: AnnotationExchangeNativeLink) throws -> [AnnotationExchangeLinkedDelivery] {
        guard try hasLinkedSyncSchema() else { return [] }
        let ids = try database.fetch(query: "SELECT message_id FROM main.\(LinkedTables.deliveries) WHERE link_id = ? ORDER BY rowid;", parameters: [link.id.uuidString]) { try Self.nativeText($0, 0) }
        return try ids.map { text in
            guard let id = UUID(uuidString: text), id.uuidString == text, let actual = try linkedDelivery(messageID: id) else { throw AnnotationExchangeError.corruptRecord }
            return actual
        }
    }

    func linkedDelivery(messageID: UUID) throws -> AnnotationExchangeLinkedDelivery? {
        guard try hasLinkedSyncSchema() else { return nil }
        let rows = try database.fetch(query: "SELECT link_id, state, retry_count, not_before, attempt_id FROM main.\(LinkedTables.deliveries) WHERE message_id = ?;", parameters: [messageID.uuidString]) { row in
            (try Self.nativeText(row, 0), try Self.nativeText(row, 1), row.int64(at: 2), row.int64(at: 3), row.isNull(at: 4) ? nil : try Self.nativeText(row, 4))
        }
        guard rows.count <= 1 else { throw AnnotationExchangeError.corruptRecord }
        guard let row = rows.first else { return nil }
        let links = try linkedRows(where: "link_id = ?", parameters: [row.0])
        let deliveries = try queryDeliveries(where: "o.message_id = ?", parameters: [messageID.uuidString])
        guard links.count == 1, let link = links.first, deliveries.count == 1, let delivery = deliveries.first,
              delivery.namespace == link.namespace, delivery.annotationUUID == link.annotationUUID, delivery.destination == link.destination,
              let state = AnnotationExchangeLinkedDelivery.State(rawValue: row.1), row.2 >= 0, row.3 >= 0,
              row.4 == nil || UUID(uuidString: row.4!)?.uuidString == row.4 else { throw AnnotationExchangeError.corruptRecord }
        guard (state == .verified) == delivery.acknowledged else { throw AnnotationExchangeError.corruptRecord }
        return .init(delivery: delivery, link: link, state: state, retryCount: row.2, notBefore: row.3, attemptID: row.4.flatMap(UUID.init(uuidString:)))
    }

    /// Called inside the existing native revision's outermost dispatch commit.
    /// A fresh original locked read must still equal the accepted baseline.
    func markLinkedRevisionDispatch(_ supplied: AnnotationExchangeLinkedDelivery, attemptID: UUID,
                                    observedRootSHA256: String, now: Int64) throws {
        guard sqlite3_get_autocommit(database.dbPointer) == 0 else { throw AnnotationExchangeError.receiptMismatch }
        guard let current = try linkedDelivery(messageID: supplied.delivery.messageID), current == supplied,
              current.link.active, current.state == .pending, now >= current.notBefore,
              current.link.nativeRootSHA256 == observedRootSHA256,
              try currentVersion(namespace: current.delivery.namespace, annotationUUID: current.delivery.annotationUUID)?.mutationID == current.delivery.mutationID,
              !(try linkedDeliveries(for: current.link)).contains(where: { $0.state == .dispatchMayHaveOccurred || $0.state == .needsReview }) else { throw AnnotationExchangeError.staleRevision }
        _ = try requireMaterializablePendingDelivery(current.delivery)
        try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'dispatch_may_have_occurred', attempt_id = ?, expected_root_sha256 = ? WHERE message_id = ? AND state = 'pending';",
            parameters: [attemptID.uuidString, observedRootSHA256, current.delivery.messageID.uuidString])
        guard sqlite3_changes64(database.dbPointer) == 1 else { throw AnnotationExchangeError.receiptMismatch }
    }

    /// Historical completion only. Production calls this exclusively with the
    /// SDK's sealed, source-matched readback. ACK means this local native handoff,
    /// never visibility or acknowledgement by a remote device.
    func recordLinkedNativeReadback(messageID: UUID, attemptID: UUID, nativeRootSHA256: String, nativeResponseSHA256: String) throws {
        guard AnnotationExchangeValidation.digest(nativeRootSHA256), AnnotationExchangeValidation.digest(nativeResponseSHA256) else { throw AnnotationExchangeError.receiptMismatch }
        try database.transaction {
            guard let current = try linkedDelivery(messageID: messageID), current.attemptID == attemptID else { throw AnnotationExchangeError.receiptMismatch }
            if current.state == .verified {
                let exact = try database.fetch(query: "SELECT COUNT(*) FROM main.\(LinkedTables.deliveries) WHERE message_id = ? AND native_root_sha256 = ? AND native_response_sha256 = ?;",
                    parameters: [messageID.uuidString, nativeRootSHA256, nativeResponseSHA256]) { $0.int64(at: 0) }
                guard exact == [1] else { throw AnnotationExchangeError.receiptMismatch }
                return
            }
            guard current.state == .dispatchMayHaveOccurred else { throw AnnotationExchangeError.receiptMismatch }
            let delivery = current.delivery
            _ = try acknowledge(.init(messageID: messageID, destination: delivery.destination, namespace: delivery.namespace,
                annotationUUID: delivery.annotationUUID, revision: delivery.revision, payloadDigest: delivery.payloadDigest))
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'verified', native_root_sha256 = ?, native_response_sha256 = ? WHERE message_id = ? AND attempt_id = ?;",
                parameters: [nativeRootSHA256, nativeResponseSHA256, messageID.uuidString, attemptID.uuidString])
            if current.link.active {
                try database.execute(query: "UPDATE main.\(LinkedTables.links) SET native_root_sha256 = ?, confirmed_local_revision = ? WHERE link_id = ? AND active = 1;",
                    parameters: [nativeRootSHA256, delivery.revision, current.link.id.uuidString])
            }
        }
    }

    /// A new explicit review records the genuine fresh native read before
    /// allowing a new conditional revision. The old native attempt and this
    /// review's prior uncertainty remain immutable history, not an inferred ACK.
    func acceptLinkedReview(_ supplied: AnnotationExchangeLinkedDelivery,
                            origin: AnnotationExchangeNativeReadOrigin) throws -> AnnotationExchangeLinkedDelivery {
        guard sqlite3_get_autocommit(database.dbPointer) == 0 else { throw AnnotationExchangeError.receiptMismatch }
        try validateNativeOrigin(origin)
        guard let current = try linkedDelivery(messageID: supplied.delivery.messageID), current == supplied,
              current.link.active, [.pending, .needsReview, .dispatchMayHaveOccurred].contains(current.state),
              current.link.destination == origin.destination, current.link.objectID == origin.objectID,
              try currentVersion(namespace: current.delivery.namespace, annotationUUID: current.delivery.annotationUUID)?.mutationID == current.delivery.mutationID else { throw AnnotationExchangeError.staleRevision }
        try database.execute(query: "INSERT INTO main.\(LinkedTables.reviews) (review_id, message_id, prior_state, prior_attempt_id, native_root_sha256, native_response_sha256) VALUES (?, ?, ?, ?, ?, ?);",
            parameters: [UUID().uuidString, current.delivery.messageID.uuidString, current.state.rawValue,
                current.attemptID.map { $0.uuidString as Any } ?? NSNull(), origin.nativeRootSHA256, origin.nativeResponseSHA256])
        for older in try linkedDeliveries(for: current.link) where older.delivery.messageID != current.delivery.messageID && [.pending, .needsReview, .dispatchMayHaveOccurred].contains(older.state) {
            try database.execute(query: "INSERT INTO main.\(LinkedTables.reviews) (review_id, message_id, prior_state, prior_attempt_id, native_root_sha256, native_response_sha256) VALUES (?, ?, ?, ?, ?, ?);",
                parameters: [UUID().uuidString, older.delivery.messageID.uuidString, older.state.rawValue,
                    older.attemptID.map { $0.uuidString as Any } ?? NSNull(), origin.nativeRootSHA256, origin.nativeResponseSHA256])
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'superseded' WHERE message_id = ?;", parameters: [older.delivery.messageID.uuidString])
        }
        try database.execute(query: "UPDATE main.\(LinkedTables.links) SET native_root_sha256 = ? WHERE link_id = ? AND active = 1;", parameters: [origin.nativeRootSHA256, current.link.id.uuidString])
        try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'pending', attempt_id = NULL, expected_root_sha256 = NULL, not_before = 0 WHERE message_id = ?;", parameters: [current.delivery.messageID.uuidString])
        guard let result = try linkedDelivery(messageID: current.delivery.messageID) else { throw AnnotationExchangeError.corruptRecord }
        return result
    }

    func deferLinkedRead(_ supplied: AnnotationExchangeLinkedDelivery, now: Int64) throws {
        try database.transaction {
            guard now >= 0, let current = try linkedDelivery(messageID: supplied.delivery.messageID), current == supplied,
                  current.state == .pending, current.link.active, current.retryCount < 1_000_000 else { throw AnnotationExchangeError.receiptMismatch }
            let delay = min(Int64(60), Int64(1) << min(Int64(6), current.retryCount))
            guard now <= Int64.max - delay else { throw AnnotationExchangeError.receiptMismatch }
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET retry_count = retry_count + 1, not_before = ? WHERE message_id = ? AND state = 'pending';",
                parameters: [now + delay, current.delivery.messageID.uuidString])
        }
    }

    func markLinkedReviewRequired(_ supplied: AnnotationExchangeLinkedDelivery) throws {
        guard let current = try linkedDelivery(messageID: supplied.delivery.messageID), current == supplied,
              current.state == .pending || current.state == .dispatchMayHaveOccurred else { throw AnnotationExchangeError.receiptMismatch }
        try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'needs_review' WHERE message_id = ?;", parameters: [current.delivery.messageID.uuidString])
    }

    func unlinkNativeCopy(_ supplied: AnnotationExchangeNativeLink) throws {
        try database.transaction {
            guard try nativeLinks(namespace: supplied.namespace, annotationUUID: supplied.annotationUUID).contains(supplied) else { throw AnnotationExchangeError.receiptMismatch }
            try database.execute(query: "UPDATE main.\(LinkedTables.links) SET active = 0 WHERE link_id = ? AND active = 1;", parameters: [supplied.id.uuidString])
            try database.execute(query: "UPDATE main.\(LinkedTables.deliveries) SET state = 'unlinked' WHERE link_id = ? AND state = 'pending';", parameters: [supplied.id.uuidString])
            // Dispatch uncertainty, versions, the native copy and its history
            // remain untouched. Unlink is not a delete or a synthetic ACK.
        }
    }

    private func validateNativeOrigin(_ origin: AnnotationExchangeNativeReadOrigin) throws {
        guard AnnotationExchangeValidation.identifier(origin.objectID), AnnotationExchangeValidation.digest(origin.nativeRootSHA256),
              AnnotationExchangeValidation.digest(origin.nativeResponseSHA256) else { throw AnnotationExchangeError.receiptMismatch }
    }

    func requireNativeOriginReplay(mutationID: UUID, origin: AnnotationExchangeNativeReadOrigin?, enableLink: Bool) throws {
        guard try hasLinkedSyncSchema() else {
            guard origin == nil && !enableLink else { throw AnnotationExchangeError.idempotencyConflict }
            return
        }
        let rows = try database.fetch(query: "SELECT destination, account_id, space_id, native_object_id, native_root_sha256, native_response_sha256, enable_link FROM main.\(LinkedTables.incoming) WHERE mutation_id = ?;", parameters: [mutationID.uuidString]) { row in
            (try Self.nativeText(row, 0), try Self.nativeText(row, 1), try Self.nativeText(row, 2), try Self.nativeText(row, 3), try Self.nativeText(row, 4), try Self.nativeText(row, 5), row.int64(at: 6))
        }
        guard let origin else {
            guard rows.isEmpty && !enableLink else { throw AnnotationExchangeError.idempotencyConflict }
            return
        }
        guard rows.count == 1, let row = rows.first, row.0 == origin.destination.destination,
              row.1 == origin.destination.account, row.2 == origin.destination.space,
              row.3 == origin.objectID, row.4 == origin.nativeRootSHA256, row.5 == origin.nativeResponseSHA256,
              row.6 == (enableLink ? 1 : 0) else { throw AnnotationExchangeError.idempotencyConflict }
    }

    private func requireLinkedLocalReplay(_ deliveries: [AnnotationExchangeDelivery]) throws {
        guard try hasLinkedSyncSchema() else { throw AnnotationExchangeError.corruptRecord }
        for delivery in deliveries {
            guard let recorded = try linkedDelivery(messageID: delivery.messageID), recorded.delivery == delivery else { throw AnnotationExchangeError.corruptRecord }
        }
    }
}
