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
              body.bytes.count <= TorahAnnotationPayloadLimits.maximumBodyBytes else {
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
        let fields = try AnnotationEnvelopeJSONCodec.decodeObject(bytes)
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
        var fields: ActionObject = try inherited.map { try AnnotationEnvelopeJSONCodec.decodeObject($0) } ?? [:]
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
        let fields = try AnnotationEnvelopeJSONCodec.decodeObject(version.payload)
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

// MARK: - Explicit owned CloudKit completion on the same captured handle

extension AnnotationLocalEditorPersistence {
    /// The original local commit remains inside its original transaction code.
    /// This outer transaction captures a provisional pending witness after all
    /// of our writes, then finalizes it only after the actual outer COMMIT.
    /// Finalization refusal never discards the already-committed local receipt.
    func commitForOwnedCloud(_ intent: AnnotationLocalEditorIntent) throws -> AnnotationLocalEditorCloudCommitted {
        var saved: AnnotationLocalEditorCommitted?
        var provisional: AnnotationLocalEditorCloudWitness?
        try connection.database.withSerializedAccess {
            guard sqlite3_get_autocommit(connection.database.dbPointer) != 0 else {
                throw AnnotationLocalEditorCloudDeferral.invalidPublication
            }
            try connection.database.transaction {
                let result = try commit(intent)
                saved = result
                if !result.receipt.replayed {
                    let pending = try cloudPendingLocked(recordID: result.snapshot.annotation.ckRecordId)
                    guard pending?.operation == "upload" else { throw AnnotationLocalEditorCloudDeferral.pendingChanged }
                    provisional = .init(saved: result, pending: pending, writes: try cloudWritesLocked())
                }
            }
        }
        guard let saved else { throw AnnotationLocalEditorError.corruptRecord }
        guard !saved.receipt.replayed else { return .init(saved: saved, witness: nil, refusal: .durableReplay) }
        guard let provisional else { return .init(saved: saved, witness: nil, refusal: .pendingChanged) }
        do {
            try withCloudLifetimes(account: nil) {
                try connection.database.transaction { try validateCloudWitnessLocked(provisional) }
            }
            return .init(saved: saved, witness: provisional, refusal: nil)
        } catch {
            return .init(saved: saved, witness: nil, refusal: isOwned ? .pendingChanged : .ownerRetired)
        }
    }

    func requireCloudWitness(_ witness: AnnotationLocalEditorCloudWitness,
                             account: AnnotationLocalEditorLifetime) throws {
        try withCloudLifetimes(account: account) {
            try connection.database.transaction { try validateCloudWitnessLocked(witness) }
        }
    }

    /// Requires a real successful upload at the caller. This method never calls
    /// a live coordinator. It validates and deletes only this exact pending
    /// version under DB→editor→connection→account, retaining those lifetimes
    /// through the original COMMIT. Any unrelated/intervening write defers ACK.
    func acknowledgeCloud(_ witness: AnnotationLocalEditorCloudWitness,
                          account: AnnotationLocalEditorLifetime) throws -> AnnotationLocalEditorCloudWitness? {
        try withCloudLifetimes(account: account) {
            var next: AnnotationLocalEditorCloudWitness?
            try connection.database.transaction {
                try validateCloudWitnessLocked(witness)
                guard let pending = witness.pending, pending.operation == "upload",
                      witness.writes.totalChanges < Int64.max else {
                    throw AnnotationLocalEditorCloudDeferral.pendingChanged
                }
                try connection.database.execute(query: """
                    DELETE FROM sync_pending WHERE rowid = ? AND ck_record_id = ? COLLATE BINARY
                    AND operation = 'upload' AND queued_at = ?;
                    """, parameters: [pending.rowID, pending.recordID, pending.queuedAt])
                guard sqlite3_changes64(connection.database.dbPointer) == 1 else {
                    throw AnnotationLocalEditorCloudDeferral.pendingChanged
                }
                let writes = try cloudWritesLocked()
                guard writes.totalChanges == witness.writes.totalChanges + 1,
                      writes.dataVersion == witness.writes.dataVersion,
                      try cloudPendingLocked(recordID: witness.saved.snapshot.annotation.ckRecordId) == nil else {
                    throw AnnotationLocalEditorCloudDeferral.pendingChanged
                }
                try validateCloudSavedLocked(witness.saved)
                next = .init(saved: witness.saved, pending: nil, writes: writes)
            }
            // Reaching here means DELETE really committed. Never add a throwing
            // ownership/cancellation check after it or describe it as rollback.
            return next
        }
    }

    private func withCloudLifetimes<Value>(account: AnnotationLocalEditorLifetime?,
                                            _ body: () throws -> Value) throws -> Value {
        // Production construction always creates distinct lifetimes. Refuse a
        // malformed injected boundary instead of recursively locking a Mutex.
        guard owner !== connection.lifetime,
              account.map({ $0 !== owner && $0 !== connection.lifetime }) ?? true else {
            throw AnnotationLocalEditorCloudDeferral.invalidPublication
        }
        return try connection.database.withSerializedAccess {
            guard sqlite3_get_autocommit(connection.database.dbPointer) != 0 else {
                throw AnnotationLocalEditorCloudDeferral.invalidPublication
            }
            return try owner.withCurrent {
                try connection.lifetime.withCurrent {
                    if let account {
                        // Distinguish refusal of the account lease itself from
                        // errors thrown by the protected body. Capturing the
                        // latter as Result avoids reentering the lifetime Mutex.
                        let result: Result<Value, any Error>
                        do { result = try account.withCurrent { Result(catching: body) } }
                        catch AnnotationLocalEditorError.retired {
                            throw AnnotationLocalEditorCloudDeferral.accountChanged
                        }
                        return try result.get()
                    }
                    return try body()
                }
            }
        }
    }

    /// Caller owns the DB and all required lifetimes. Do not call isOwned/read/
    /// requireCurrent here: those would reenter a nonrecursive lifetime Mutex.
    private func validateCloudWitnessLocked(_ witness: AnnotationLocalEditorCloudWitness) throws {
        guard try cloudWritesLocked() == witness.writes else { throw AnnotationLocalEditorCloudDeferral.pendingChanged }
        try validateCloudSavedLocked(witness.saved)
        guard try cloudPendingLocked(recordID: witness.saved.snapshot.annotation.ckRecordId) == witness.pending,
              try cloudWritesLocked() == witness.writes else {
            throw AnnotationLocalEditorCloudDeferral.pendingChanged
        }
    }

    private func validateCloudSavedLocked(_ saved: AnnotationLocalEditorCommitted) throws {
        try requireSnapshotOwner(saved.snapshot)
        let current = try snapshotLocked()
        guard let version = current.version, current.source == saved.snapshot.source,
              current.version == saved.snapshot.version, current.revision == saved.snapshot.revision,
              saved.receipt.namespace == Self.namespace, saved.receipt.annotationUUID == annotationUUID,
              saved.receipt.mutationID == version.mutationID, saved.receipt.revision == version.revision,
              saved.receipt.payloadDigest == version.payloadDigest, !saved.receipt.replayed,
              saved.receipt.deliveries.isEmpty else { throw AnnotationLocalEditorCloudDeferral.sourceChanged }
    }

    private func cloudWritesLocked() throws -> AnnotationLocalEditorCloudWriteStamp {
        let total = sqlite3_total_changes64(connection.database.dbPointer)
        let versions = try connection.database.fetch(query: "PRAGMA data_version;") { $0.int64(at: 0) }
        guard total >= 0, versions.count == 1, let version = versions.first, version >= 0 else {
            throw AnnotationLocalEditorCloudDeferral.pendingChanged
        }
        return .init(totalChanges: total, dataVersion: version)
    }

    private func cloudPendingLocked(recordID: String?) throws -> AnnotationLocalEditorCloudPendingRow? {
        guard let recordID, !recordID.isEmpty else { throw AnnotationLocalEditorCloudDeferral.invalidRecord }
        let rows = try connection.database.fetch(query: """
            SELECT rowid, ck_record_id, operation, queued_at FROM sync_pending
            WHERE ck_record_id = ? COLLATE NOCASE;
            """, parameters: [recordID]) { row -> AnnotationLocalEditorCloudPendingRow in
            guard let key = row.string(at: 1), let operation = row.string(at: 2) else {
                throw AnnotationLocalEditorCloudDeferral.pendingChanged
            }
            return .init(rowID: row.int64(at: 0), recordID: key, operation: operation, queuedAt: row.int64(at: 3))
        }
        guard rows.count <= 1 else { throw AnnotationLocalEditorCloudDeferral.pendingChanged }
        if let row = rows.first {
            guard row.rowID > 0, row.recordID.utf8.elementsEqual(recordID.utf8),
                  row.operation == "upload", row.queuedAt >= 0 else {
                throw AnnotationLocalEditorCloudDeferral.pendingChanged
            }
        }
        return rows.first
    }
}
