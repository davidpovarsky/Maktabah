import Foundation
import SQLite3
import OtzariaActionCore

/// Local annotation persistence on the original captured handle. This is not an
/// Anytype document store, importer, transport, or replacement editor renderer.
final class AnnotationLocalEditorPersistence: Sendable {
    static let namespace = "otzaria.local.annotation"
    private static let intentKey = "otzariaLocalBodyCommit"
    let connection: AnnotationLocalEditorConnection
    let annotationID: Int64
    let annotationUUID: UUID
    let sessionID: UUID
    let owner: AnnotationLocalEditorLifetime
    private let formats: Set<AnnotationLocalEditorBodyFormat>
    private let digest: any AnnotationExchangeDigesting
    private let ledger: AnnotationExchangeLedger

    init(connection: AnnotationLocalEditorConnection, annotationID: Int64, annotationUUID: UUID,
         sessionID: UUID, owner: AnnotationLocalEditorLifetime,
         formats: Set<AnnotationLocalEditorBodyFormat>, digest: any AnnotationExchangeDigesting) throws {
        guard annotationID > 0, !formats.isEmpty else { throw AnnotationLocalEditorError.invalidIntent }
        self.connection = connection; self.annotationID = annotationID; self.annotationUUID = annotationUUID
        self.sessionID = sessionID; self.owner = owner; self.formats = formats; self.digest = digest
        ledger = AnnotationExchangeLedger(database: connection.database, digest: digest)
        try connection.requireCurrent(owner: owner)
    }

    var isOwned: Bool { owner.isCurrent && connection.lifetime.isCurrent }

    func read() throws -> AnnotationLocalEditorSnapshot {
        var result: AnnotationLocalEditorSnapshot?
        try connection.database.transaction {
            try requireCurrent()
            result = try snapshotLocked()
            try requireCurrent()
        }
        guard let result else { throw AnnotationLocalEditorError.corruptRecord }
        return result
    }

    func prepare(snapshot: AnnotationLocalEditorSnapshot, mutationID: UUID,
                 body: TorahAnnotationEnvelope.RichBody, textPreview: String,
                 editorRevision: String?) throws -> AnnotationLocalEditorIntent {
        try connection.requireCurrent(owner: owner)
        try requireSnapshotOwner(snapshot)
        try requireEditable(snapshot)
        guard formats.contains(where: { $0.accepts(body) }),
              body.bytes.count <= TorahAnnotationEnvelopeCodec.maximumBytes else {
            throw AnnotationLocalEditorError.unsupportedBody
        }
        guard textPreview.utf8.count <= 8_192, !textPreview.utf8.contains(0), editorRevision.map({ $0.utf8.count <= 512 }) ?? true else {
            throw AnnotationLocalEditorError.invalidPreview
        }
        if case .supported(let old, _)? = snapshot.document, let previous = old.richBody {
            guard previous.format == body.format, previous.formatVersion == body.formatVersion else {
                throw AnnotationLocalEditorError.unsupportedBody
            }
        }
        let fields: ActionObject = [
            "namespace": .string(Self.namespace), "annotationUUID": .string(annotationUUID.uuidString),
            "expectedRevision": .integer(snapshot.revision), "sourceSHA256": .string(snapshot.source.digest),
            "priorPayloadSHA256": snapshot.version.map { .string($0.payloadDigest) } ?? .null,
            "format": .string(body.format), "formatVersion": .integer(body.formatVersion),
            "bytesBase64": .string(body.bytes.base64EncodedString()), "textPreview": .string(textPreview),
            "editorRevision": editorRevision.map(ActionJSON.string) ?? .null
        ]
        let intentDigest = try digest.sha256(AnnotationExchangeValidation.canonical(.object(fields)))
        guard AnnotationExchangeValidation.digest(intentDigest) else { throw AnnotationLocalEditorError.corruptRecord }
        return .init(mutationID: mutationID, snapshot: snapshot, body: body, textPreview: textPreview,
                     editorRevision: editorRevision, intentDigest: intentDigest)
    }

    func commit(_ intent: AnnotationLocalEditorIntent) throws -> AnnotationLocalEditorCommitted {
        try requireSnapshotOwner(intent.snapshot)
        // Recompute the command from its original snapshot, never from newer DB
        // contents. This also checks unsupported versions/formats before writes.
        let validated = try prepare(snapshot: intent.snapshot, mutationID: intent.mutationID,
            body: intent.body, textPreview: intent.textPreview, editorRevision: intent.editorRevision)
        guard validated.intentDigest == intent.intentDigest else { throw AnnotationLocalEditorError.invalidIntent }
        var result: AnnotationLocalEditorCommitted?
        try connection.database.transaction {
            try requireCurrent()
            if !(try ledger.hasInstalledSchema()) { try ledger.installSchema() }
            if let previous = try ledger.version(mutationID: intent.mutationID) {
                result = try replayLocked(previous, intent: intent)
                try requireCurrent()
                return
            }
            let before = try snapshotLocked()
            guard before.source == intent.snapshot.source else { throw AnnotationExchangeError.staleSource }
            guard before.revision == intent.snapshot.revision, before.version == intent.snapshot.version else {
                throw AnnotationExchangeError.staleRevision
            }
            try requireEditable(before)
            guard let recordID = before.annotation.ckRecordId else { throw AnnotationLocalEditorError.missingAnnotation }
            let deleted = try connection.database.fetch(query: """
                SELECT COUNT(*) FROM sync_pending WHERE ck_record_id = ? COLLATE NOCASE AND operation = 'delete';
                """, parameters: [recordID]) { $0.int64(at: 0) }.first ?? 0
            guard deleted == 0 else { throw AnnotationLocalEditorError.pendingDeletion }
            try Task.checkCancellation()
            try connection.database.execute(query: """
                UPDATE annotations SET note = ?, lastModified = ?
                WHERE id = ? AND ckRecordId = ? COLLATE NOCASE;
                """, parameters: [intent.textPreview, Int64(Date().timeIntervalSince1970), annotationID, recordID])
            // Same original pending queue, in the same outer transaction. No
            // exchange destination or acknowledgement is manufactured here.
            try connection.syncPending.addPendingSync(ckRecordId: recordID, operation: "upload")
            let source = try ledger.captureSource(annotationUUID: annotationUUID)
            let payload = try updatedPayload(intent: intent, inherited: before.version?.payload, source: source)
            let receipt = try ledger.commitLocal(mutationID: intent.mutationID, payload: payload,
                expectedSource: source, expectedRevision: intent.snapshot.revision)
            guard receipt.deliveries.isEmpty else { throw AnnotationLocalEditorError.corruptRecord }
            let after = try snapshotLocked()
            guard after.revision == receipt.revision, after.version?.payloadDigest == receipt.payloadDigest,
                  after.annotation.note?.utf8.elementsEqual(intent.textPreview.utf8) == true else {
                throw AnnotationLocalEditorError.corruptRecord
            }
            try requireCurrent()
            result = .init(receipt: receipt, snapshot: after)
        }
        // No throwing cancellation/ownership check after COMMIT: callers must
        // receive the actual receipt even if ownership was retired meanwhile.
        guard let result else { throw AnnotationLocalEditorError.corruptRecord }
        return result
    }

    /// Revalidate the exact original source and version after asynchronous work,
    /// before a snapshot is delivered to its still-current local host.
    func requireUnchanged(_ snapshot: AnnotationLocalEditorSnapshot) throws {
        try requireSnapshotOwner(snapshot)
        let current = try read()
        guard current.source == snapshot.source else { throw AnnotationExchangeError.staleSource }
        guard current.version == snapshot.version, current.revision == snapshot.revision else {
            throw AnnotationExchangeError.staleRevision
        }
        try connection.requireCurrent(owner: owner)
    }

    func canDeliver(_ saved: AnnotationLocalEditorCommitted) -> Bool {
        guard isOwned else { return false }
        do {
            try requireUnchanged(saved.snapshot)
            return isOwned
        } catch { return false }
    }

    private func requireSnapshotOwner(_ snapshot: AnnotationLocalEditorSnapshot) throws {
        guard snapshot.sessionID == sessionID, snapshot.annotationUUID == annotationUUID,
              snapshot.annotation.id == annotationID,
              snapshot.source.annotationUUID == annotationUUID,
              snapshot.databaseURL.absoluteString.utf8.elementsEqual(connection.databaseURL.absoluteString.utf8) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        switch (snapshot.version, snapshot.document) {
        case (nil, nil):
            guard snapshot.revision == 0 else { throw AnnotationLocalEditorError.invalidIntent }
        case (.some(let version), .some(let document)):
            guard version.namespace == Self.namespace, version.annotationUUID == annotationUUID,
                  snapshot.revision == version.revision,
                  version.payload == document.originalBytes,
                  try TorahAnnotationEnvelopeCodec.decode(version.payload) == document else {
                throw AnnotationLocalEditorError.invalidIntent
            }
        default: throw AnnotationLocalEditorError.invalidIntent
        }
    }

    private func requireCurrent() throws {
        try Task.checkCancellation()
        try connection.requireCurrent(owner: owner)
        let files = try connection.database.fetch(query: "PRAGMA database_list;") { row in
            (row.string(at: 1), row.string(at: 2))
        }.filter { $0.0 == "main" }
        guard files.count == 1, let path = files.first?.1, !path.isEmpty,
              URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path.utf8.elementsEqual(
                connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath().path.utf8) else {
            throw AnnotationLocalEditorError.wrongProfile
        }
    }

    private func snapshotLocked() throws -> AnnotationLocalEditorSnapshot {
        let source = try ledger.captureSource(annotationUUID: annotationUUID)
        guard source.exists else { throw AnnotationLocalEditorError.missingAnnotation }
        let rows = try connection.database.fetch(query: "SELECT * FROM annotations WHERE ckRecordId = ? COLLATE NOCASE;",
            parameters: [annotationUUID.uuidString]) { connection.mapRow($0, []) }
        guard rows.count == 1, var annotation = rows.first, annotation.id == annotationID,
              annotation.ckRecordId.flatMap(UUID.init(uuidString:)) == annotationUUID else {
            throw AnnotationLocalEditorError.missingAnnotation
        }
        // Same query/order as the original fetchTags, on the captured handle.
        annotation.tags = try connection.database.fetch(query: """
            SELECT t.name FROM tags t INNER JOIN annotation_tags at ON t.id = at.tagId
            WHERE at.annotationId = ? ORDER BY t.name COLLATE NOCASE ASC;
            """, parameters: [annotationID]) { $0.string(at: 0) ?? "" }
        let version: AnnotationExchangeVersion?
        if try ledger.hasInstalledSchema() {
            version = try ledger.currentVersion(namespace: Self.namespace, annotationUUID: annotationUUID)
        } else { version = nil }
        let document = try version.map { try TorahAnnotationEnvelopeCodec.decode($0.payload) }
        return .init(annotation: annotation, annotationUUID: annotationUUID, databaseURL: connection.databaseURL,
            revision: version?.revision ?? 0, document: document, source: source, version: version, sessionID: sessionID)
    }

    private func requireEditable(_ snapshot: AnnotationLocalEditorSnapshot) throws {
        guard let document = snapshot.document else { return }
        guard case .supported(let envelope, let bytes) = document else {
            throw AnnotationLocalEditorError.unsupportedEnvelope
        }
        guard envelope.deletionState == .active, envelope.source == snapshot.source.metadata,
              snapshot.version?.sourceDigest == snapshot.source.digest else { throw AnnotationLocalEditorError.staleBody }
        guard snapshot.version?.destinationsJSON == "[]" else { throw AnnotationLocalEditorError.unsupportedEnvelope }
        if let rich = envelope.richBody, !formats.contains(where: { $0.accepts(rich) }) {
            throw AnnotationLocalEditorError.unsupportedBody
        }
        let fields = try ActionWireCodec.decodeObject(bytes)
        if let marker = fields[Self.intentKey] {
            guard let object = marker.object, Set(object.keys) == ["schemaVersion", "intentSHA256"],
                  object["schemaVersion"]?.integer == 1,
                  object["intentSHA256"]?.string.map(AnnotationExchangeValidation.digest) == true else {
                throw AnnotationLocalEditorError.unsupportedEnvelope
            }
        }
    }

    private func updatedPayload(intent: AnnotationLocalEditorIntent, inherited: Data?,
                                source: AnnotationExchangeSourceWitness) throws -> Data {
        // Inherit only the fresh database version validated in this transaction,
        // never an independently supplied document field from a save request.
        var fields: ActionObject = try inherited.map { try ActionWireCodec.decodeObject($0) } ?? [:]
        var rich = fields["richBody"]?.object ?? [:]
        rich["format"] = .string(intent.body.format); rich["formatVersion"] = .integer(intent.body.formatVersion)
        rich["bytesBase64"] = .string(intent.body.bytes.base64EncodedString())
        fields["schemaVersion"] = .integer(TorahAnnotationEnvelopeCodec.schemaVersion)
        fields["namespace"] = .string(Self.namespace); fields["annotationUUID"] = .string(annotationUUID.uuidString)
        if fields["originatingApp"] == nil { fields["originatingApp"] = .string("maktabah") }
        fields["source"] = .object(source.metadata); fields["richBody"] = .object(rich)
        fields["textPreview"] = .string(intent.textPreview); fields["deletionState"] = .string("active")
        if let revision = intent.editorRevision { fields["editorRevision"] = .string(revision) }
        else { fields.removeValue(forKey: "editorRevision") }
        fields[Self.intentKey] = .object(["schemaVersion": .integer(1), "intentSHA256": .string(intent.intentDigest)])
        let bytes = try AnnotationExchangeValidation.canonical(.object(fields))
        _ = try TorahAnnotationEnvelopeCodec.decode(bytes)
        return bytes
    }

    private func replayLocked(_ version: AnnotationExchangeVersion, intent: AnnotationLocalEditorIntent) throws -> AnnotationLocalEditorCommitted {
        let fields = try ActionWireCodec.decodeObject(version.payload)
        guard version.namespace == Self.namespace, version.annotationUUID == annotationUUID,
              version.destinationsJSON == "[]",
              fields[Self.intentKey]?.object?["intentSHA256"]?.string == intent.intentDigest else {
            throw AnnotationExchangeError.idempotencyConflict
        }
        let current = try snapshotLocked()
        guard current.version == version else { throw AnnotationExchangeError.staleRevision }
        try requireEditable(current)
        guard current.source.digest == version.sourceDigest else { throw AnnotationExchangeError.staleSource }
        let receipt = try ledger.commitLocal(mutationID: intent.mutationID, payload: version.payload,
            expectedSource: current.source, expectedRevision: intent.snapshot.revision)
        guard receipt.replayed, receipt.deliveries.isEmpty else { throw AnnotationLocalEditorError.corruptRecord }
        return .init(receipt: receipt, snapshot: current)
    }
}
