import Foundation
import SQLite3
import OtzariaActionCore

enum AnnotationNativeBackfillError: Error, Sendable, Equatable {
    case wrongScan, wrongProfile, invalidRow(Int64), sourceChanged
    case previewWouldChangeSavedText, unavailableWorkspace
}

enum AnnotationNativeBackfillDisposition: String, Sendable, CaseIterable {
    case ready, existingRich, metadataOnly, pendingDeletion
    case needsPreparation, longNote, unsupported, changed
}

/// Selection data only. A new actual local session must read and compare the
/// original row again before native creation and before its canonical Save.
struct AnnotationNativeBackfillCandidate: Sendable {
    let annotation: Annotation
    let annotationUUID: UUID
    let sourceSHA256: String
    let savedRevision: Int64
    let payloadSHA256: String?
    let planMutationID: UUID
}

struct AnnotationNativeBackfillItem: Sendable {
    let disposition: AnnotationNativeBackfillDisposition
    let candidate: AnnotationNativeBackfillCandidate?
}

struct AnnotationNativeBackfillScan: Sendable {
    let id: UUID
    let lastAnnotationID: Int64
    let rowCount: Int64
}

struct AnnotationNativeBackfillBatch: Sendable {
    let lastAnnotationID: Int64
    let isComplete: Bool
    let items: [AnnotationNativeBackfillItem]
}

/// This policy cannot construct a native body or authorize a native operation.
/// It accepts only a byte-preserving saved-plain conversion with a current plan.
enum AnnotationNativeBackfillPolicy {
    static let maximumUnchangedPreviewBytes = 8_192

    static func disposition(snapshot: AnnotationLocalEditorSnapshot,
                            plan: AnnotationExchangeVersion?,
                            pendingDeletion: Bool,
                            digest: any AnnotationExchangeDigesting) throws
        -> AnnotationNativeBackfillDisposition {
        guard let text = snapshot.annotation.note, !text.isEmpty else { return .metadataOnly }
        if pendingDeletion { return .pendingDeletion }
        if let document = snapshot.document {
            switch document {
            case .unsupported:
                return .unsupported
            case .supported(let envelope, _):
                // Preserve every opaque existing rich body, including formats
                // this SDK cannot read. Backfill never replaces one with text.
                if envelope.richBody != nil { return .existingRich }
                guard envelope.deletionState == .active,
                      envelope.source == snapshot.source.metadata,
                      snapshot.version?.sourceDigest == snapshot.source.digest,
                      snapshot.version?.destinationsJSON == "[]" else { return .changed }
            }
        }
        guard !text.utf8.contains(0) else { return .unsupported }
        guard text.utf8.count <= maximumUnchangedPreviewBytes else { return .longNote }
        guard let plan, plan.namespace == AnnotationBackfillPlanner.namespace,
              plan.annotationUUID == snapshot.annotationUUID, plan.revision > 0,
              plan.sourceDigest == snapshot.source.digest, plan.destinationsJSON == "[]",
              case .supported(let envelope, let bytes) = try TorahAnnotationEnvelopeCodec.decode(plan.payload),
              envelope.annotationUUID == snapshot.annotationUUID,
              envelope.namespace == AnnotationBackfillPlanner.namespace,
              envelope.deletionState == .active, envelope.richBody == nil,
              envelope.source == snapshot.source.metadata,
              let marker = try AnnotationEnvelopeJSONCodec.decodeObject(bytes)["otzariaBackfill"]?.object,
              Set(marker.keys) == Set(["schemaVersion", "classification", "sourceSHA256",
                                       "plainNoteSHA256", "localBodySHA256"]),
              marker["schemaVersion"]?.integer == 1,
              marker["classification"]?.string == "annotation",
              marker["sourceSHA256"]?.string == snapshot.source.digest,
              marker["plainNoteSHA256"]?.string == (try digest.sha256(Data(text.utf8))),
              marker["localBodySHA256"] == (snapshot.version.map { .string($0.payloadDigest) } ?? .null)
        else { return .needsPreparation }
        return .ready
    }

    static func requireSameCandidate(_ candidate: AnnotationNativeBackfillCandidate,
                                     snapshot: AnnotationLocalEditorSnapshot) throws {
        guard candidate.annotation.id == snapshot.annotation.id,
              candidate.annotationUUID == snapshot.annotationUUID,
              candidate.annotation.ckRecordId.map({ Data($0.utf8) })
                == snapshot.annotation.ckRecordId.map({ Data($0.utf8) }),
              candidate.sourceSHA256 == snapshot.source.digest,
              candidate.savedRevision == snapshot.revision,
              candidate.payloadSHA256 == snapshot.version?.payloadDigest,
              candidate.annotation.note.map({ Data($0.utf8) })
                == snapshot.annotation.note.map({ Data($0.utf8) }) else {
            throw AnnotationNativeBackfillError.sourceChanged
        }
    }

    static func requireExactPreview(savedText: String, originalNativePreview: String) throws {
        guard !savedText.isEmpty, !savedText.utf8.contains(0),
              savedText.utf8.count <= maximumUnchangedPreviewBytes,
              savedText.utf8.elementsEqual(originalNativePreview.utf8) else {
            throw AnnotationNativeBackfillError.previewWouldChangeSavedText
        }
    }
}

/// Read-only bounded scan of the original captured profile and its existing
/// plans. Discovery never registers UUIDs, installs schemas, edits notes or
/// creates a transport entry. All writes stay in the existing local Save.
final class AnnotationNativeBackfillCatalog: Sendable {
    private let connection: AnnotationLocalEditorConnection
    private let owner: AnnotationLocalEditorLifetime
    private let formats: Set<AnnotationLocalEditorBodyFormat>
    private let digest: any AnnotationExchangeDigesting
    private let ledger: AnnotationExchangeLedger
    private let scanID = UUID()

    init(connection: AnnotationLocalEditorConnection, owner: AnnotationLocalEditorLifetime,
         formats: Set<AnnotationLocalEditorBodyFormat>, digest: any AnnotationExchangeDigesting) throws {
        self.connection = connection; self.owner = owner; self.formats = formats; self.digest = digest
        ledger = AnnotationExchangeLedger(database: connection.database, digest: digest)
        try requireCurrent()
    }

    func inspect() throws -> AnnotationNativeBackfillScan {
        var result: AnnotationNativeBackfillScan?
        try connection.database.transaction {
            try requireCurrent()
            let rows = try connection.database.fetch(
                query: "SELECT COALESCE(MAX(id), 0), COUNT(*) FROM main.annotations;"
            ) { ($0.int64(at: 0), $0.int64(at: 1)) }
            guard rows.count == 1, let row = rows.first, row.0 >= 0, row.1 >= 0 else {
                throw AnnotationNativeBackfillError.wrongScan
            }
            result = .init(id: scanID, lastAnnotationID: row.0, rowCount: row.1)
            try requireCurrent()
        }
        guard let result else { throw AnnotationNativeBackfillError.wrongScan }
        return result
    }

    func readBatch(_ scan: AnnotationNativeBackfillScan, afterAnnotationID: Int64,
                   limit: Int = 25) throws -> AnnotationNativeBackfillBatch {
        guard scan.id == scanID, afterAnnotationID >= 0,
              afterAnnotationID <= scan.lastAnnotationID, (1...50).contains(limit) else {
            throw AnnotationNativeBackfillError.wrongScan
        }
        var result: AnnotationNativeBackfillBatch?
        try connection.database.transaction {
            try requireCurrent()
            let annotations = try connection.database.fetch(query: """
                SELECT * FROM main.annotations
                WHERE id > ? AND id <= ? ORDER BY id LIMIT ?;
                """, parameters: [afterAnnotationID, scan.lastAnnotationID, limit]) { row in
                let annotation = self.connection.mapRow(row, [])
                guard let id = annotation.id, id > 0,
                      let noteColumn = (0..<row.columnCount).first(where: { row.stmt.columnName($0) == "note" })
                else { throw AnnotationNativeBackfillError.invalidRow(afterAnnotationID) }
                if row.type(at: noteColumn) == SQLITE_NULL {
                    guard annotation.note == nil else { throw AnnotationNativeBackfillError.invalidRow(id) }
                } else {
                    guard row.type(at: noteColumn) == SQLITE_TEXT, let text = annotation.note,
                          text.utf8.count == Int(sqlite3_column_bytes(row.stmt, noteColumn)),
                          !text.utf8.contains(0) else { throw AnnotationNativeBackfillError.invalidRow(id) }
                }
                return annotation
            }
            var items: [AnnotationNativeBackfillItem] = []
            for annotation in annotations {
                try requireCurrent()
                guard let id = annotation.id else { throw AnnotationNativeBackfillError.wrongScan }
                guard let text = annotation.note, !text.isEmpty else {
                    items.append(.init(disposition: .metadataOnly, candidate: nil)); continue
                }
                guard let recordID = annotation.ckRecordId, !recordID.isEmpty else {
                    items.append(.init(disposition: .needsPreparation, candidate: nil)); continue
                }
                let deletion = try connection.database.fetch(query: """
                    SELECT COUNT(*) FROM main.sync_pending
                    WHERE ck_record_id = ? COLLATE NOCASE AND operation = 'delete';
                    """, parameters: [recordID]) { $0.int64(at: 0) }.first ?? 0
                if deletion > 0 {
                    items.append(.init(disposition: .pendingDeletion, candidate: nil)); continue
                }
                guard let uuid = try AnnotationExchangeIdentity.resolve(database: connection.database,
                    annotationID: id, originalRecordID: recordID) else {
                    items.append(.init(disposition: .needsPreparation, candidate: nil)); continue
                }
                let storage = try AnnotationLocalEditorPersistence(connection: connection,
                    annotationID: id, annotationUUID: uuid, sessionID: UUID(), owner: owner,
                    formats: formats, digest: digest)
                let snapshot = try storage.read()
                let plan: AnnotationExchangeVersion?
                if try ledger.hasInstalledSchema() {
                    plan = try ledger.currentVersion(namespace: AnnotationBackfillPlanner.namespace, annotationUUID: uuid)
                } else { plan = nil }
                let disposition = try AnnotationNativeBackfillPolicy.disposition(snapshot: snapshot,
                    plan: plan, pendingDeletion: false, digest: digest)
                let candidate: AnnotationNativeBackfillCandidate?
                if disposition == .ready, let plan {
                    candidate = .init(annotation: snapshot.annotation, annotationUUID: uuid,
                        sourceSHA256: snapshot.source.digest, savedRevision: snapshot.revision,
                        payloadSHA256: snapshot.version?.payloadDigest, planMutationID: plan.mutationID)
                } else { candidate = nil }
                items.append(.init(disposition: disposition, candidate: candidate))
            }
            try requireCurrent()
            let last = annotations.last?.id ?? scan.lastAnnotationID
            result = .init(lastAnnotationID: last,
                isComplete: annotations.count < limit || last == scan.lastAnnotationID, items: items)
        }
        guard let result else { throw AnnotationNativeBackfillError.wrongScan }
        return result
    }

    private func requireCurrent() throws {
        try Task.checkCancellation()
        try connection.requireCurrent(owner: owner)
        let main = try connection.database.fetch(query: "PRAGMA database_list;") {
            ($0.string(at: 1), $0.string(at: 2))
        }.filter { $0.0 == "main" }
        guard main.count == 1, let path = main.first?.1,
              URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
                == connection.databaseURL.standardizedFileURL.resolvingSymlinksInPath() else {
            throw AnnotationNativeBackfillError.wrongProfile
        }
    }
}
