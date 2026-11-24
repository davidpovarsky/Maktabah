import Foundation
import SQLite3
import OtzariaActionCore
#if os(iOS) && canImport(AnytypeOriginalEditor)
import AnytypeOriginalEditor
#endif

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


// MARK: - Explicit saved-row original-native attempt history

/// Comparison data only. No caller, selected-Space lease or native authority is
/// constructed here. The original SDK accepts nonempty, non-NUL identities and
/// compares their exact UTF8 bytes; it has no independent 512-byte ID limit.
struct AnnotationLocalEditorNativeComparison: Sendable, Equatable {
    let accountID: String
    let spaceID: String

    init(accountID: String, spaceID: String) throws {
        guard !accountID.isEmpty, !spaceID.isEmpty,
              !accountID.utf8.contains(0), !spaceID.utf8.contains(0) else {
            throw AnnotationLocalEditorNativeAttemptError.invalidComparison
        }
        self.accountID = accountID
        self.spaceID = spaceID
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.accountID.utf8.elementsEqual(rhs.accountID.utf8)
            && lhs.spaceID.utf8.elementsEqual(rhs.spaceID.utf8)
    }
}

enum AnnotationLocalEditorNativeAttemptError: Error, Sendable, Equatable {
    case invalidComparison, unsupportedSavedBody, nestedTransaction
    case preparedAttemptExists, dispatchMayHaveOccurred, noPreparedAttempt
    case wrongPreparation, observationChanged, schemaMismatch, corruptRecord
}

enum AnnotationLocalEditorNativeAttemptState: String, Sendable {
    case prepared
    case dispatchMayHaveOccurred = "dispatch_may_have_occurred"
    case abandonedBeforeDispatch = "abandoned_before_dispatch"
}

/// Historical local data, not a live source witness or a native dispatch permit.
/// Only an actual read/commit on the same captured storage constructs one.
struct AnnotationLocalEditorNativeAttemptObservation: Sendable {
    let attemptID: UUID
    let annotationUUID: UUID
    let preparedSessionID: UUID
    let savedRevision: Int64
    let sourceDigest: String
    let payloadDigest: String
    let bodyDigest: String
    let state: AnnotationLocalEditorNativeAttemptState
    fileprivate let observedBy: AnnotationLocalEditorPersistence

    fileprivate func matches(_ other: Self) -> Bool {
        observedBy === other.observedBy && attemptID == other.attemptID
            && annotationUUID == other.annotationUUID
            && preparedSessionID == other.preparedSessionID
            && savedRevision == other.savedRevision
            && sourceDigest.utf8.elementsEqual(other.sourceDigest.utf8)
            && payloadDigest.utf8.elementsEqual(other.payloadDigest.utf8)
            && bodyDigest.utf8.elementsEqual(other.bodyDigest.utf8)
            && state == other.state
    }
}

/// A newly prepared, original-session-bound local attempt. History cannot be
/// decoded into this object, and another session cannot adopt its saved caller.
final class AnnotationLocalEditorNativePreparation: Sendable {
    let snapshot: AnnotationLocalEditorSnapshot
    let comparison: AnnotationLocalEditorNativeComparison
    let observation: AnnotationLocalEditorNativeAttemptObservation
    fileprivate let storage: AnnotationLocalEditorPersistence
    fileprivate let image: AnnotationLocalEditorNativeFrozenImage

    fileprivate init(storage: AnnotationLocalEditorPersistence,
                     snapshot: AnnotationLocalEditorSnapshot,
                     comparison: AnnotationLocalEditorNativeComparison,
                     observation: AnnotationLocalEditorNativeAttemptObservation,
                     image: AnnotationLocalEditorNativeFrozenImage) {
        self.storage = storage
        self.snapshot = snapshot
        self.comparison = comparison
        self.observation = observation
        self.image = image
    }
}

enum AnnotationLocalEditorNativePreparationOutcome: Sendable {
    case prepared(AnnotationLocalEditorNativePreparation)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

enum AnnotationLocalEditorNativeTransitionOutcome: Sendable {
    case recorded(AnnotationLocalEditorNativeAttemptObservation)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

/// The exact immutable SQL image retains the whole original saved payload. Body
/// bytes, including historical capturedAgainstRevision, are never re-encoded.
fileprivate struct AnnotationLocalEditorNativeFrozenImage: Sendable {
    let attemptID: UUID
    let snapshot: AnnotationLocalEditorSnapshot
    let comparison: AnnotationLocalEditorNativeComparison
    let sourceBase64: String
    let payloadBase64: String
    let body: TorahAnnotationEnvelope.RichBody
    let bodyDigest: String
    let version: AnnotationExchangeVersion

    static let columns = [
        "attempt_uuid", "namespace", "annotation_uuid", "annotation_id",
        "prepared_session_uuid", "captured_database_url", "native_account_id",
        "native_space_id", "source_canonical_base64", "source_digest",
        "version_mutation_uuid", "saved_revision", "payload_digest",
        "payload_base64", "destinations_json", "body_format",
        "body_format_version", "body_byte_count", "body_digest"
    ]

    var parameters: [Any] {
        [
            attemptID.uuidString, version.namespace, snapshot.annotationUUID.uuidString,
            snapshot.annotation.id!, snapshot.sessionID.uuidString,
            snapshot.databaseURL.absoluteString, comparison.accountID, comparison.spaceID,
            sourceBase64, snapshot.source.digest, version.mutationID.uuidString,
            version.revision, version.payloadDigest, payloadBase64, version.destinationsJSON,
            body.format, body.formatVersion, Int64(body.bytes.count), bodyDigest
        ]
    }

    static var exactPredicate: String {
        columns.map { "\($0) = ? COLLATE BINARY" }.joined(separator: " AND ")
    }

    func observation(storage: AnnotationLocalEditorPersistence,
                     state: AnnotationLocalEditorNativeAttemptState) -> AnnotationLocalEditorNativeAttemptObservation {
        .init(attemptID: attemptID, annotationUUID: snapshot.annotationUUID,
              preparedSessionID: snapshot.sessionID, savedRevision: version.revision,
              sourceDigest: snapshot.source.digest, payloadDigest: version.payloadDigest,
              bodyDigest: bodyDigest, state: state, observedBy: storage)
    }
}

extension AnnotationLocalEditorPersistence {
    private enum NativeAttemptTables {
        static let schema = "otzaria_local_editor_native_attempt_schema"
        static let attempts = "otzaria_local_editor_native_attempts"
        static let active = "otzaria_local_editor_native_attempt_one_active"
        static let sourceMaximumBytes = 8_388_608
        static let sourceMaximumBase64Bytes = 4 * ((sourceMaximumBytes + 2) / 3)
    }

    /// Discovery never installs schema, rewrites history or adopts an old owner.
    /// Possible-dispatch history is found independently of the current revision,
    /// session, numeric row ID, URL, account and Space.
    func nativeAttemptObservation() throws -> AnnotationLocalEditorNativeAttemptObservation? {
        var result: AnnotationLocalEditorNativeAttemptObservation?
        try connection.database.transaction {
            try requireCurrent()
            if try requireNativeAttemptSchemaLocked(installIfAbsent: false) {
                result = try nativeActiveAttemptLocked()
            }
            try requireCurrent()
        }
        return result
    }

    func prepareNativeAttempt(snapshot: AnnotationLocalEditorSnapshot,
                              comparison: AnnotationLocalEditorNativeComparison) throws -> AnnotationLocalEditorNativePreparation {
        try requireSnapshotOwner(snapshot)
        return try withNativeAttemptCommit {
            let actual = try requireNativeSavedSnapshotLocked(snapshot)
            let image = try nativeFrozenImage(snapshot: actual, comparison: comparison)
            _ = try requireNativeAttemptSchemaLocked(installIfAbsent: true)
            if let existing = try nativeActiveAttemptLocked() {
                if existing.state == .dispatchMayHaveOccurred {
                    throw AnnotationLocalEditorNativeAttemptError.dispatchMayHaveOccurred
                }
                throw AnnotationLocalEditorNativeAttemptError.preparedAttemptExists
            }
            let names = AnnotationLocalEditorNativeFrozenImage.columns.joined(separator: ", ")
            let placeholders = Array(repeating: "?", count: AnnotationLocalEditorNativeFrozenImage.columns.count)
                .joined(separator: ", ")
            try connection.database.execute(query: """
                INSERT INTO main.\(NativeAttemptTables.attempts) (\(names), dispatch_state)
                VALUES (\(placeholders), 'prepared');
                """, parameters: image.parameters)
            guard sqlite3_changes64(connection.database.dbPointer) == 1 else {
                throw AnnotationLocalEditorNativeAttemptError.corruptRecord
            }
            try requireNativeImageLocked(image, state: .prepared)
            let observation = image.observation(storage: self, state: .prepared)
            guard let actualObservation = try nativeActiveAttemptLocked(),
                  observation.matches(actualObservation) else {
                throw AnnotationLocalEditorNativeAttemptError.corruptRecord
            }
            // Both objects exist before the original outer COMMIT.
            return AnnotationLocalEditorNativePreparation(storage: self, snapshot: actual,
                comparison: comparison, observation: observation, image: image)
        }
    }

    /// Commit this one-way fact before a future original SDK invocation. A second
    /// call is uncertainty, never a new dispatch permission. No SDK is called.
    func markNativeAttemptMayHaveDispatched(_ prepared: AnnotationLocalEditorNativePreparation) throws -> AnnotationLocalEditorNativeAttemptObservation {
        guard prepared.storage === self,
              prepared.observation.observedBy === self else {
            throw AnnotationLocalEditorNativeAttemptError.wrongPreparation
        }
        return try withNativeAttemptCommit {
            guard try requireNativeAttemptSchemaLocked(installIfAbsent: false),
                  let previous = try nativeActiveAttemptLocked() else {
                throw AnnotationLocalEditorNativeAttemptError.noPreparedAttempt
            }
            guard previous.state != .dispatchMayHaveOccurred else {
                throw AnnotationLocalEditorNativeAttemptError.dispatchMayHaveOccurred
            }
            guard previous.matches(prepared.observation) else {
                throw AnnotationLocalEditorNativeAttemptError.observationChanged
            }
            _ = try requireNativeSavedSnapshotLocked(prepared.snapshot)
            try requireNativeImageLocked(prepared.image, state: .prepared)
            try connection.database.execute(query: """
                UPDATE main.\(NativeAttemptTables.attempts)
                SET dispatch_state = 'dispatch_may_have_occurred'
                WHERE \(AnnotationLocalEditorNativeFrozenImage.exactPredicate)
                    AND dispatch_state = 'prepared';
                """, parameters: prepared.image.parameters)
            guard sqlite3_changes64(connection.database.dbPointer) == 1 else {
                throw AnnotationLocalEditorNativeAttemptError.observationChanged
            }
            try requireNativeImageLocked(prepared.image, state: .dispatchMayHaveOccurred)
            let receipt = prepared.image.observation(storage: self, state: .dispatchMayHaveOccurred)
            guard let actual = try nativeActiveAttemptLocked(), receipt.matches(actual) else {
                throw AnnotationLocalEditorNativeAttemptError.corruptRecord
            }
            return receipt
        }
    }

    /// Explicitly abandons a confirmed prepared record, preserving its complete
    /// immutable image. Winning the same DB CAS invalidates the old preparation;
    /// if marking won first, this operation refuses. It returns no new caller.
    func abandonPreparedNativeAttempt(_ observed: AnnotationLocalEditorNativeAttemptObservation,
                                      currentSnapshot: AnnotationLocalEditorSnapshot) throws -> AnnotationLocalEditorNativeAttemptObservation {
        guard observed.observedBy === self, observed.annotationUUID == annotationUUID,
              observed.state == .prepared else {
            throw AnnotationLocalEditorNativeAttemptError.wrongPreparation
        }
        return try withNativeAttemptCommit {
            _ = try requireNativeSavedSnapshotLocked(currentSnapshot)
            guard try requireNativeAttemptSchemaLocked(installIfAbsent: false),
                  let previous = try nativeActiveAttemptLocked() else {
                throw AnnotationLocalEditorNativeAttemptError.noPreparedAttempt
            }
            guard previous.state != .dispatchMayHaveOccurred else {
                throw AnnotationLocalEditorNativeAttemptError.dispatchMayHaveOccurred
            }
            guard previous.matches(observed) else {
                throw AnnotationLocalEditorNativeAttemptError.observationChanged
            }
            try connection.database.execute(query: """
                UPDATE main.\(NativeAttemptTables.attempts)
                SET dispatch_state = 'abandoned_before_dispatch'
                WHERE attempt_uuid = ? COLLATE BINARY
                    AND namespace = ? COLLATE BINARY AND annotation_uuid = ? COLLATE BINARY
                    AND prepared_session_uuid = ? COLLATE BINARY AND saved_revision = ?
                    AND source_digest = ? COLLATE BINARY AND payload_digest = ? COLLATE BINARY
                    AND body_digest = ? COLLATE BINARY AND dispatch_state = 'prepared';
                """, parameters: [observed.attemptID.uuidString, Self.namespace, annotationUUID.uuidString,
                    observed.preparedSessionID.uuidString, observed.savedRevision, observed.sourceDigest,
                    observed.payloadDigest, observed.bodyDigest])
            guard sqlite3_changes64(connection.database.dbPointer) == 1,
                  try nativeActiveAttemptLocked() == nil else {
                throw AnnotationLocalEditorNativeAttemptError.observationChanged
            }
            let receipt = AnnotationLocalEditorNativeAttemptObservation(
                attemptID: observed.attemptID, annotationUUID: observed.annotationUUID,
                preparedSessionID: observed.preparedSessionID, savedRevision: observed.savedRevision,
                sourceDigest: observed.sourceDigest, payloadDigest: observed.payloadDigest,
                bodyDigest: observed.bodyDigest, state: .abandonedBeforeDispatch, observedBy: self)
            return receipt
        }
    }

    /// Memory-only ownership of the same privately constructed preparation.
    /// The SDK currentness callback must never call the database/CAS observer.
    func ownsNativePreparation(_ prepared: AnnotationLocalEditorNativePreparation) -> Bool {
        prepared.storage === self && prepared.observation.observedBy === self
            && prepared.snapshot.sessionID == sessionID && isOwned
    }

    #if os(iOS) && canImport(AnytypeOriginalEditor)
    func bindLocalAnnotationRetirement(
        _ source: AnytypeOriginalEditorLocalAnnotationSourceLifetime,
        snapshot: AnnotationLocalEditorSnapshot
    ) throws {
        do {
            guard isOwned, snapshot.sessionID == sessionID,
                  snapshot.annotationUUID == annotationUUID,
                  snapshot.databaseURL.absoluteString.utf8.elementsEqual(connection.databaseURL.absoluteString.utf8),
                  source.source.annotationUUID == annotationUUID,
                  source.source.expectedRevision == snapshot.revision,
                  source.source.sourceWitnessSHA256 == snapshot.source.digest,
                  source.source.payloadSHA256 == snapshot.version?.payloadDigest else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            // No SQL or callback is performed while either parent is linked.
            // A retired original DB or editor immediately retires the SDK token.
            try owner.bindLocalAnnotationRetirement(source)
            try connection.lifetime.bindLocalAnnotationRetirement(source)
            guard isOwned, source.isCurrent else { throw AnnotationLocalEditorError.retired }
        } catch {
            source.retire()
            throw error
        }
    }

    func bindNativeImportRetirement(
        _ source: AnytypeOriginalAnnotationImportSourceLifetime,
        prepared: AnnotationLocalEditorNativePreparation
    ) throws {
        guard prepared.storage === self, prepared.observation.observedBy === self else {
            source.retire()
            throw AnnotationLocalEditorNativeAttemptError.wrongPreparation
        }
        do {
            // Register separately, never from withNativeAttemptCommit/withCurrent.
            // Either original parent can synchronously close the exact SDK token.
            try owner.bindNativeImportRetirement(source)
            try connection.lifetime.bindNativeImportRetirement(source)
            guard ownsNativePreparation(prepared), source.isCurrent else {
                throw AnnotationLocalEditorError.retired
            }
        } catch {
            source.retire()
            throw error
        }
    }
    #endif

    /// Delivery classification cannot hide an actual committed attempt receipt.
    func canDeliverNativeSnapshot(_ snapshot: AnnotationLocalEditorSnapshot) -> Bool {
        guard isOwned else { return false }
        do {
            try requireUnchanged(snapshot)
            return isOwned
        } catch { return false }
    }

    private func withNativeAttemptCommit<Value>(_ body: () throws -> Value) throws -> Value {
        guard owner !== connection.lifetime else {
            throw AnnotationLocalEditorNativeAttemptError.wrongPreparation
        }
        return try connection.database.withSerializedAccess {
            guard sqlite3_get_autocommit(connection.database.dbPointer) != 0 else {
                throw AnnotationLocalEditorNativeAttemptError.nestedTransaction
            }
            // This check occurs before either nonrecursive lifetime Mutex is held.
            try requireCurrent()
            return try owner.withCurrent {
                try connection.lifetime.withCurrent {
                    // The original transaction callback returns Void. This holder
                    // bridges that API; body creates its nonoptional receipt before
                    // COMMIT. A successful callback always fills it, and afterward
                    // there is no throwing cancellation/currentness/ownership check.
                    var committed: Value?
                    try connection.database.transaction {
                        let receipt = try body()
                        committed = receipt
                        try Task.checkCancellation()
                    }
                    return committed!
                }
            }
        }
    }

    /// Caller owns DB and both lifetimes. Do not call read/requireCurrent/isOwned.
    private func requireNativeSavedSnapshotLocked(_ expected: AnnotationLocalEditorSnapshot) throws -> AnnotationLocalEditorSnapshot {
        try requireSnapshotOwner(expected)
        let actual = try snapshotLocked()
        guard actual.source == expected.source else { throw AnnotationExchangeError.staleSource }
        guard actual.revision == expected.revision, actual.version == expected.version else {
            throw AnnotationExchangeError.staleRevision
        }
        try requireEditable(actual)
        guard actual.source.exists, let version = actual.version,
              version.revision > 0, version.revision == actual.revision,
              version.sourceDigest == actual.source.digest,
              version.destinationsJSON == "[]",
              case .supported(let envelope, let bytes)? = actual.document,
              bytes == version.payload, envelope.richBody != nil,
              envelope.annotationUUID == actual.annotationUUID,
              envelope.namespace == Self.namespace,
              let recordID = actual.annotation.ckRecordId else {
            throw AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody
        }
        let deleted = try connection.database.fetch(query: """
            SELECT COUNT(*) FROM sync_pending
            WHERE ck_record_id = ? COLLATE NOCASE AND operation = 'delete';
            """, parameters: [recordID]) { $0.int64(at: 0) }.first ?? 0
        guard deleted == 0 else { throw AnnotationLocalEditorError.pendingDeletion }
        return actual
    }

    private func nativeFrozenImage(snapshot: AnnotationLocalEditorSnapshot,
                                   comparison: AnnotationLocalEditorNativeComparison) throws -> AnnotationLocalEditorNativeFrozenImage {
        guard let version = snapshot.version,
              case .supported(let envelope, _)? = snapshot.document,
              let body = envelope.richBody, !body.bytes.isEmpty,
              body.bytes.count <= TorahAnnotationPayloadLimits.maximumBodyBytes,
              snapshot.source.canonicalBytes.count <= NativeAttemptTables.sourceMaximumBytes,
              version.payload.count <= TorahAnnotationPayloadLimits.maximumEnvelopeBytes,
              try digest.sha256(snapshot.source.canonicalBytes) == snapshot.source.digest,
              try digest.sha256(version.payload) == version.payloadDigest else {
            throw AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody
        }
        let bodyDigest = try digest.sha256(body.bytes)
        guard AnnotationExchangeValidation.digest(bodyDigest) else {
            throw AnnotationLocalEditorNativeAttemptError.corruptRecord
        }
        return .init(attemptID: UUID(), snapshot: snapshot, comparison: comparison,
                     sourceBase64: snapshot.source.canonicalBytes.base64EncodedString(),
                     payloadBase64: version.payload.base64EncodedString(), body: body,
                     bodyDigest: bodyDigest, version: version)
    }

    private func requireNativeImageLocked(_ image: AnnotationLocalEditorNativeFrozenImage,
                                          state: AnnotationLocalEditorNativeAttemptState) throws {
        let count = try connection.database.fetch(query: """
            SELECT COUNT(*) FROM main.\(NativeAttemptTables.attempts)
            WHERE \(AnnotationLocalEditorNativeFrozenImage.exactPredicate) AND dispatch_state = ? COLLATE BINARY;
            """, parameters: image.parameters + [state.rawValue]) { $0.int64(at: 0) }
        guard count == [1] else { throw AnnotationLocalEditorNativeAttemptError.corruptRecord }
    }

    private func nativeActiveAttemptLocked() throws -> AnnotationLocalEditorNativeAttemptObservation? {
        // IS NOT includes malformed/nontext/NULL states instead of hiding them
        // outside the partial unique index. The mapper refuses any unknown state.
        let rows = try connection.database.fetch(query: """
            SELECT attempt_uuid, annotation_uuid, prepared_session_uuid, saved_revision,
                   source_digest, payload_digest, body_digest, dispatch_state
            FROM main.\(NativeAttemptTables.attempts)
            WHERE namespace = ? COLLATE BINARY AND annotation_uuid = ? COLLATE NOCASE
                AND dispatch_state IS NOT 'abandoned_before_dispatch'
            LIMIT 2;
            """, parameters: [Self.namespace, annotationUUID.uuidString]) { row in
                func uuid(_ column: Int32) throws -> UUID {
                    let text = try Self.nativeAttemptText(row, column, maximumBytes: 36)
                    guard let value = UUID(uuidString: text), value.uuidString.utf8.elementsEqual(text.utf8) else {
                        throw AnnotationLocalEditorNativeAttemptError.corruptRecord
                    }
                    return value
                }
                let attempt = try uuid(0), annotation = try uuid(1), session = try uuid(2)
                let source = try Self.nativeAttemptText(row, 4, maximumBytes: 64)
                let payload = try Self.nativeAttemptText(row, 5, maximumBytes: 64)
                let body = try Self.nativeAttemptText(row, 6, maximumBytes: 64)
                let stateText = try Self.nativeAttemptText(row, 7, maximumBytes: 32)
                guard annotation == annotationUUID, row.type(at: 3) == SQLITE_INTEGER,
                      row.int64(at: 3) > 0,
                      [source, payload, body].allSatisfy(AnnotationExchangeValidation.digest),
                      let state = AnnotationLocalEditorNativeAttemptState(rawValue: stateText),
                      state != .abandonedBeforeDispatch else {
                    throw AnnotationLocalEditorNativeAttemptError.corruptRecord
                }
                return AnnotationLocalEditorNativeAttemptObservation(attemptID: attempt,
                    annotationUUID: annotation, preparedSessionID: session, savedRevision: row.int64(at: 3),
                    sourceDigest: source, payloadDigest: payload, bodyDigest: body,
                    state: state, observedBy: self)
            }
        guard rows.count <= 1 else { throw AnnotationLocalEditorNativeAttemptError.corruptRecord }
        return rows.first
    }

    private static func nativeAttemptText(_ row: SQLiteRow, _ column: Int32,
                                          maximumBytes: Int) throws -> String {
        let count = Int(sqlite3_column_bytes(row.stmt, column))
        guard row.type(at: column) == SQLITE_TEXT, count <= maximumBytes,
              let text = row.string(at: column), text.utf8.count == count else {
            throw AnnotationLocalEditorNativeAttemptError.corruptRecord
        }
        return text
    }

    private static var nativeAttemptDefinitions: [(name: String, type: String, table: String, sql: String)] {
        let schema = NativeAttemptTables.schema, attempts = NativeAttemptTables.attempts
        let active = NativeAttemptTables.active
        return [
            (schema, "table", schema, """
                CREATE TABLE \(schema) (
                    singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
                    version INTEGER NOT NULL CHECK(typeof(version) = 'integer' AND version = 1)
                )
                """),
            (attempts, "table", attempts, """
                CREATE TABLE \(attempts) (
                    attempt_uuid TEXT PRIMARY KEY NOT NULL CHECK(typeof(attempt_uuid) = 'text' AND length(CAST(attempt_uuid AS BLOB)) = 36),
                    namespace TEXT NOT NULL CHECK(typeof(namespace) = 'text' AND namespace = 'otzaria.local.annotation'),
                    annotation_uuid TEXT NOT NULL CHECK(typeof(annotation_uuid) = 'text' AND length(CAST(annotation_uuid AS BLOB)) = 36),
                    annotation_id INTEGER NOT NULL CHECK(typeof(annotation_id) = 'integer' AND annotation_id > 0),
                    prepared_session_uuid TEXT NOT NULL CHECK(typeof(prepared_session_uuid) = 'text' AND length(CAST(prepared_session_uuid AS BLOB)) = 36),
                    captured_database_url TEXT NOT NULL CHECK(typeof(captured_database_url) = 'text' AND length(CAST(captured_database_url AS BLOB)) > 0 AND instr(captured_database_url, char(0)) = 0),
                    native_account_id TEXT COLLATE BINARY NOT NULL CHECK(typeof(native_account_id) = 'text' AND length(CAST(native_account_id AS BLOB)) > 0 AND instr(native_account_id, char(0)) = 0),
                    native_space_id TEXT COLLATE BINARY NOT NULL CHECK(typeof(native_space_id) = 'text' AND length(CAST(native_space_id AS BLOB)) > 0 AND instr(native_space_id, char(0)) = 0),
                    source_canonical_base64 TEXT NOT NULL CHECK(typeof(source_canonical_base64) = 'text' AND length(CAST(source_canonical_base64 AS BLOB)) BETWEEN 1 AND \(NativeAttemptTables.sourceMaximumBase64Bytes)),
                    source_digest TEXT NOT NULL CHECK(typeof(source_digest) = 'text' AND length(CAST(source_digest AS BLOB)) = 64),
                    version_mutation_uuid TEXT NOT NULL CHECK(typeof(version_mutation_uuid) = 'text' AND length(CAST(version_mutation_uuid AS BLOB)) = 36),
                    saved_revision INTEGER NOT NULL CHECK(typeof(saved_revision) = 'integer' AND saved_revision > 0),
                    payload_digest TEXT NOT NULL CHECK(typeof(payload_digest) = 'text' AND length(CAST(payload_digest AS BLOB)) = 64),
                    payload_base64 TEXT NOT NULL CHECK(typeof(payload_base64) = 'text' AND length(CAST(payload_base64 AS BLOB)) BETWEEN 1 AND \(TorahAnnotationPayloadLimits.maximumStoredEnvelopeBase64Bytes)),
                    destinations_json TEXT NOT NULL CHECK(typeof(destinations_json) = 'text' AND destinations_json = '[]'),
                    body_format TEXT NOT NULL CHECK(typeof(body_format) = 'text' AND length(CAST(body_format AS BLOB)) BETWEEN 1 AND 512),
                    body_format_version INTEGER NOT NULL CHECK(typeof(body_format_version) = 'integer' AND body_format_version > 0),
                    body_byte_count INTEGER NOT NULL CHECK(typeof(body_byte_count) = 'integer' AND body_byte_count BETWEEN 1 AND \(TorahAnnotationPayloadLimits.maximumBodyBytes)),
                    body_digest TEXT NOT NULL CHECK(typeof(body_digest) = 'text' AND length(CAST(body_digest AS BLOB)) = 64),
                    dispatch_state TEXT NOT NULL CHECK(typeof(dispatch_state) = 'text' AND dispatch_state IN ('prepared', 'dispatch_may_have_occurred', 'abandoned_before_dispatch'))
                )
                """),
            (active, "index", attempts, """
                CREATE UNIQUE INDEX \(active)
                ON \(attempts)(namespace COLLATE BINARY, annotation_uuid COLLATE NOCASE)
                WHERE dispatch_state IN ('prepared', 'dispatch_may_have_occurred')
                """)
        ]
    }

    /// Exact owned schema only; partial/future/altered or temporary shadows fail
    /// closed. Reads pass false and never install any table or index.
    private func requireNativeAttemptSchemaLocked(installIfAbsent: Bool) throws -> Bool {
        let names = [NativeAttemptTables.schema, NativeAttemptTables.attempts, NativeAttemptTables.active]
        let shadows = try connection.database.fetch(query: """
            SELECT COUNT(*) FROM sqlite_temp_master
            WHERE name COLLATE NOCASE IN (?, ?, ?) OR tbl_name COLLATE NOCASE IN (?, ?, ?)
                OR instr(lower(coalesce(sql, '')), 'otzaria_local_editor_native_attempt') > 0;
            """, parameters: names + names) { $0.int64(at: 0) }
        guard shadows == [0] else { throw AnnotationLocalEditorNativeAttemptError.schemaMismatch }
        let definitions = Self.nativeAttemptDefinitions
        func objects() throws -> [(String, String, String, String?)] {
            try connection.database.fetch(query: """
                SELECT name, type, tbl_name, sql FROM main.sqlite_master
                WHERE name COLLATE NOCASE IN (?, ?, ?) OR tbl_name COLLATE NOCASE IN (?, ?)
                LIMIT 5;
                """, parameters: names + [NativeAttemptTables.schema, NativeAttemptTables.attempts]) { row in
                    (try Self.nativeAttemptText(row, 0, maximumBytes: 256),
                     try Self.nativeAttemptText(row, 1, maximumBytes: 16),
                     try Self.nativeAttemptText(row, 2, maximumBytes: 256),
                     row.isNull(at: 3) ? nil : try Self.nativeAttemptText(row, 3, maximumBytes: 8_192))
                }
        }
        var actual = try objects()
        if actual.isEmpty {
            guard installIfAbsent else { return false }
            for definition in definitions {
                let prefix = definition.type == "table" ? "CREATE TABLE " : "CREATE UNIQUE INDEX "
                let sql = definition.sql.replacingOccurrences(of: prefix + definition.name,
                    with: prefix + "main." + definition.name)
                try connection.database.execute(query: sql)
            }
            try connection.database.execute(query: """
                INSERT INTO main.\(NativeAttemptTables.schema) (singleton, version) VALUES (1, 1);
                """)
            actual = try objects()
        }
        guard actual.count == 4 else { throw AnnotationLocalEditorNativeAttemptError.schemaMismatch }
        for definition in definitions {
            let matches = actual.filter { $0.0 == definition.name }
            guard matches.count == 1, let row = matches.first,
                  row.1 == definition.type, row.2 == definition.table,
                  row.3 == definition.sql else {
                throw AnnotationLocalEditorNativeAttemptError.schemaMismatch
            }
        }
        let automatic = actual.filter { !names.contains($0.0) }
        guard automatic.count == 1, let index = automatic.first,
              index.0 == "sqlite_autoindex_" + NativeAttemptTables.attempts + "_1",
              index.1 == "index", index.2 == NativeAttemptTables.attempts, index.3 == nil else {
            throw AnnotationLocalEditorNativeAttemptError.schemaMismatch
        }
        let versions = try connection.database.fetch(query: """
            SELECT singleton, version FROM main.\(NativeAttemptTables.schema) LIMIT 2;
            """) { ($0.type(at: 0), $0.int64(at: 0), $0.type(at: 1), $0.int64(at: 1)) }
        guard versions.count == 1, let version = versions.first,
              version.0 == SQLITE_INTEGER, version.1 == 1,
              version.2 == SQLITE_INTEGER, version.3 == 1 else {
            throw AnnotationLocalEditorNativeAttemptError.schemaMismatch
        }
        return true
    }
}

/// A plain note update has no native body replacement authority.
enum AnnotationPlainWriteError: LocalizedError, Equatable {
    case requiresExpandedEditor, unavailable

    var errorDescription: String? {
        switch self {
        case .requiresExpandedEditor:
            String(localized: "Use the expanded editor to change this formatted note.",
                   table: "OriginalAnnotationEditor")
        case .unavailable:
            String(localized: "The saved note could not be checked. Close and reopen it before editing.",
                   table: "OriginalAnnotationEditor")
        }
    }
}

extension AnnotationLocalEditorPersistence {
    /// Called before the original row, tags and queue writes on that same handle.
    /// Reads never install a schema or reinterpret an unsupported envelope.
    static func requirePlainWrite(
        database: SQLiteDatabase, annotationID: Int64, originalRecordID: String?
    ) throws {
        try database.withSerializedAccess {
            guard sqlite3_get_autocommit(database.dbPointer) == 0 else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            let records: [String?] = try database.fetch(
                query: "SELECT ckRecordId FROM annotations WHERE id = ?;",
                parameters: [annotationID]
            ) { row in
                if row.type(at: 0) == SQLITE_NULL { return nil }
                guard row.type(at: 0) == SQLITE_TEXT, let value = row.string(at: 0),
                      value.utf8.count == Int(sqlite3_column_bytes(row.stmt, 0)) else {
                    throw AnnotationExchangeError.corruptRecord
                }
                return value
            }
            guard records.count == 1 else { throw AnnotationLocalEditorError.missingAnnotation }
            guard records[0].map({ Array($0.utf8) }) == originalRecordID.map({ Array($0.utf8) }) else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            let ledger = AnnotationExchangeLedger(database: database, digest: AnnotationExchangePlatformDigest())
            guard try ledger.hasInstalledSchema() else { return }
            // Legacy rows with no UUID cannot name an immutable rich version.
            // The exact original record-ID comparison above still protects identity.
            guard let uuid = records[0].flatMap(UUID.init(uuidString:)),
                  let version = try ledger.currentVersion(namespace: Self.namespace, annotationUUID: uuid) else {
                return
            }
            guard case .supported(let envelope, _) = try TorahAnnotationEnvelopeCodec.decode(version.payload),
                  envelope.deletionState == .active, version.destinationsJSON == "[]" else {
                throw AnnotationPlainWriteError.unavailable
            }
            guard envelope.richBody == nil else {
                throw AnnotationPlainWriteError.requiresExpandedEditor
            }
        }
    }
}
