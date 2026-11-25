import Foundation
import SQLite3
import OtzariaActionCore

enum AnnotationBackfillError: Error, Sendable, Equatable {
    case invalidBatch, wrongProfile, missingIdentity(Int64), invalidOriginalRow(Int64)
    case unsupportedSavedBody(Int64), unsupportedPlan(Int64)
}

struct AnnotationBackfillSnapshot: Sendable {
    let sessionID: UUID
    let lastAnnotationID: Int64
    let sourceRowCount: Int64
}

struct AnnotationBackfillEntry: Sendable, Codable {
    let annotationID: Int64
    let annotationUUID: UUID
    let mutationID: UUID
    let sourceSHA256: String
    let localBodySHA256: String?
    let planRevision: Int64
    let replayed: Bool
}

struct AnnotationBackfillBatch: Sendable {
    let lastAnnotationID: Int64
    let scanned: Int
    let metadataOnly: Int
    let pendingDeletion: Int
    let prepared: Int
    let reused: Int
    let isComplete: Bool
    let entries: [AnnotationBackfillEntry]
}

/// Explicit, bounded preparation on the original captured profile connection.
/// Original notes, CloudKit identities/queue and rich bodies remain untouched.
/// Plans are local receipts; no network destination or acknowledgement is made.
final class AnnotationBackfillPlanner: Sendable {
    static let namespace = "otzaria.annotation.backfill.v1"
    private static let marker = "otzariaBackfill"
    private let connection: AnnotationLocalEditorConnection
    private let owner: AnnotationLocalEditorLifetime
    private let digest: any AnnotationExchangeDigesting
    private let ledger: AnnotationExchangeLedger
    private let sessionID = UUID()

    init(connection: AnnotationLocalEditorConnection, owner: AnnotationLocalEditorLifetime,
         digest: any AnnotationExchangeDigesting) throws {
        self.connection = connection
        self.owner = owner
        self.digest = digest
        self.ledger = AnnotationExchangeLedger(database: connection.database, digest: digest)
        try requireCurrent()
    }

    /// Read-only discovery; even a legacy profile gets no schema or UUID writes.
    func inspect() throws -> AnnotationBackfillSnapshot {
        var result: AnnotationBackfillSnapshot?
        try connection.database.transaction {
            try requireCurrent()
            let rows = try connection.database.fetch(
                query: "SELECT COALESCE(MAX(id), 0), COUNT(*) FROM annotations;"
            ) { ($0.int64(at: 0), $0.int64(at: 1)) }
            guard rows.count == 1, let row = rows.first, row.0 >= 0, row.1 >= 0 else {
                throw AnnotationBackfillError.invalidBatch
            }
            result = .init(sessionID: sessionID, lastAnnotationID: row.0, sourceRowCount: row.1)
            try requireCurrent()
        }
        guard let result else { throw AnnotationBackfillError.invalidBatch }
        return result
    }

    /// Each successful batch is committed atomically. Restarting a scan reuses
    /// exact current receipts and never creates a second annotation or outbox.
    func prepareBatch(_ snapshot: AnnotationBackfillSnapshot, afterAnnotationID: Int64,
                      limit: Int = 50) throws -> AnnotationBackfillBatch {
        guard snapshot.sessionID == sessionID, afterAnnotationID >= 0,
              snapshot.lastAnnotationID >= afterAnnotationID, (1...100).contains(limit) else {
            throw AnnotationBackfillError.invalidBatch
        }
        var result: AnnotationBackfillBatch?
        try connection.database.transaction {
            try requireCurrent()
            let rows = try connection.database.fetch(query: """
                SELECT * FROM annotations WHERE id > ? AND id <= ? ORDER BY id LIMIT ?;
                """, parameters: [afterAnnotationID, snapshot.lastAnnotationID, limit]) { row in
                    let annotation = self.connection.mapRow(row, [])
                    guard let id = annotation.id, id > 0 else {
                        throw AnnotationBackfillError.invalidOriginalRow(afterAnnotationID)
                    }
                    // Original row mapping uses SQLite strings; verify that the
                    // note itself was not truncated at a NUL or invalid UTF-8.
                    let index = (0..<row.columnCount).first { row.stmt.columnName($0) == "note" }
                    guard let index else { throw AnnotationBackfillError.invalidOriginalRow(id) }
                    if row.type(at: index) == SQLITE_NULL {
                        guard annotation.note == nil else { throw AnnotationBackfillError.invalidOriginalRow(id) }
                    } else {
                        guard row.type(at: index) == SQLITE_TEXT, let note = annotation.note,
                              note.utf8.count == Int(sqlite3_column_bytes(row.stmt, index)),
                              !note.utf8.contains(0) else { throw AnnotationBackfillError.invalidOriginalRow(id) }
                    }
                    return annotation
                }
            var entries: [AnnotationBackfillEntry] = []
            var metadataOnly = 0, deleted = 0, prepared = 0, reused = 0
            for annotation in rows {
                try requireCurrent()
                guard let id = annotation.id else { throw AnnotationBackfillError.invalidBatch }
                guard let note = annotation.note, !note.isEmpty else {
                    metadataOnly += 1
                    continue
                }
                guard let recordID = annotation.ckRecordId, !recordID.isEmpty else {
                    throw AnnotationBackfillError.missingIdentity(id)
                }
                let deletion = try connection.database.fetch(query: """
                    SELECT COUNT(*) FROM sync_pending
                    WHERE ck_record_id = ? COLLATE NOCASE AND operation = 'delete';
                    """, parameters: [recordID]) { $0.int64(at: 0) }.first ?? 0
                if deletion > 0 {
                    deleted += 1
                    continue
                }
                let uuid = try AnnotationExchangeIdentity.resolve(database: connection.database,
                    annotationID: id, originalRecordID: recordID)
                    ?? AnnotationExchangeIdentity.registerLegacy(database: connection.database,
                        annotationID: id, originalRecordID: recordID)
                if !(try ledger.hasInstalledSchema()) { try ledger.installSchema() }
                let witness = try ledger.captureSource(annotationUUID: uuid)
                guard witness.exists else { throw AnnotationExchangeError.missingSource }
                let local = try ledger.currentVersion(namespace: AnnotationLocalEditorPersistence.namespace,
                                                       annotationUUID: uuid)
                if let local {
                    guard local.destinationsJSON == "[]",
                          case .supported(let body, _) = try TorahAnnotationEnvelopeCodec.decode(local.payload),
                          body.deletionState == .active, body.source == witness.metadata else {
                        throw AnnotationBackfillError.unsupportedSavedBody(id)
                    }
                }
                let current = try ledger.currentVersion(namespace: Self.namespace, annotationUUID: uuid)
                let bodyHash = local?.payloadDigest
                let noteHash = try digest.sha256(Data(note.utf8))
                guard AnnotationExchangeValidation.digest(noteHash) else {
                    throw AnnotationExchangeError.corruptRecord
                }
                let marker: ActionObject = [
                    "schemaVersion": .integer(1),
                    "classification": .string("annotation"),
                    "sourceSHA256": .string(witness.digest),
                    "plainNoteSHA256": .string(noteHash),
                    "localBodySHA256": bodyHash.map(ActionJSON.string) ?? .null
                ]
                if let current {
                    guard current.destinationsJSON == "[]",
                          case .supported(let envelope, let bytes) = try TorahAnnotationEnvelopeCodec.decode(current.payload),
                          envelope.richBody == nil, envelope.deletionState == .active,
                          let oldMarker = try AnnotationEnvelopeJSONCodec.decodeObject(bytes)[Self.marker]?.object,
                          oldMarker["schemaVersion"]?.integer == 1,
                          Set(oldMarker.keys) == Set(marker.keys) else {
                        throw AnnotationBackfillError.unsupportedPlan(id)
                    }
                    if current.sourceDigest == witness.digest && oldMarker == marker {
                        reused += 1
                        entries.append(.init(annotationID: id, annotationUUID: uuid,
                            mutationID: current.mutationID, sourceSHA256: witness.digest,
                            localBodySHA256: bodyHash, planRevision: current.revision, replayed: true))
                        continue
                    }
                }
                let envelope = TorahAnnotationEnvelope(namespace: Self.namespace, annotationUUID: uuid,
                    originatingApp: "maktabah", source: witness.metadata, richBody: nil,
                    textPreview: Self.preview(note), editorRevision: nil, title: nil, deletionState: .active)
                var fields = try AnnotationEnvelopeJSONCodec.decodeObject(TorahAnnotationEnvelopeCodec.encode(envelope))
                fields[Self.marker] = .object(marker)
                let payload = try AnnotationExchangeValidation.canonical(.object(fields))
                let previousRevision = current?.revision ?? 0
                let mutation = try mutationID(uuid: uuid, source: witness.digest, body: bodyHash,
                                              previousRevision: previousRevision)
                let receipt = try ledger.commitLocal(mutationID: mutation, payload: payload,
                    expectedSource: witness, expectedRevision: previousRevision)
                guard receipt.deliveries.isEmpty, !receipt.replayed,
                      receipt.revision == previousRevision + 1 else {
                    throw AnnotationExchangeError.corruptRecord
                }
                prepared += 1
                entries.append(.init(annotationID: id, annotationUUID: uuid, mutationID: receipt.mutationID,
                    sourceSHA256: witness.digest, localBodySHA256: bodyHash,
                    planRevision: receipt.revision, replayed: false))
            }
            try requireCurrent()
            let last = rows.last?.id ?? snapshot.lastAnnotationID
            result = .init(lastAnnotationID: last, scanned: rows.count, metadataOnly: metadataOnly,
                pendingDeletion: deleted, prepared: prepared, reused: reused,
                isComplete: rows.count < limit || last == snapshot.lastAnnotationID, entries: entries)
        }
        // No cancellation check after COMMIT may hide the receipt of real work.
        guard let result else { throw AnnotationBackfillError.invalidBatch }
        return result
    }

    private func requireCurrent() throws {
        try Task.checkCancellation()
        try connection.requireCurrent(owner: owner)
        let rows = try connection.database.fetch(query: "PRAGMA database_list;") {
            ($0.string(at: 1), $0.string(at: 2))
        }.filter { $0.0 == "main" }
        guard rows.count == 1, let path = rows.first?.1,
              URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
                == connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath() else {
            throw AnnotationBackfillError.wrongProfile
        }
    }

    private func mutationID(uuid: UUID, source: String, body: String?, previousRevision: Int64) throws -> UUID {
        let value: ActionObject = ["domain": .string(Self.namespace), "annotationUUID": .string(uuid.uuidString),
            "sourceSHA256": .string(source), "localBodySHA256": body.map(ActionJSON.string) ?? .null,
            "previousPlanRevision": .integer(previousRevision)]
        let hex = try digest.sha256(AnnotationExchangeValidation.canonical(.object(value)))
        guard AnnotationExchangeValidation.digest(hex) else { throw AnnotationExchangeError.corruptRecord }
        var bytes = stride(from: 0, to: 32, by: 2).map { index -> UInt8 in
            let start = hex.index(hex.startIndex, offsetBy: index)
            return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    private static func preview(_ note: String) -> String {
        var result = String.UnicodeScalarView()
        var count = 0
        for scalar in note.unicodeScalars {
            let size = scalar.utf8.count
            guard count + size <= 8_192 else { break }
            result.append(scalar)
            count += size
        }
        return String(result)
    }
}
