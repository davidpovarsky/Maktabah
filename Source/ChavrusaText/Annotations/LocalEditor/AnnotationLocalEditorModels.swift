import Foundation
import Synchronization
import OtzariaActionCore

enum AnnotationLocalEditorError: Error, Sendable, Equatable {
    case noConnection, retired, busy, wrongOwner, wrongProfile, missingAnnotation
    case unsupportedBody, unsupportedEnvelope, staleBody, pendingDeletion
    case invalidPreview, invalidIntent, corruptRecord
}

/// A synchronous, one-way lifetime. Never acquires a repository/SQLite lock or
/// calls client code. Replacing a connection creates a new instance; reopening
/// the same file cannot revive a retired editor.
final class AnnotationLocalEditorLifetime: Sendable {
    private let retired = Mutex(false)
    func retire() { retired.withLock { $0 = true } }
    var isCurrent: Bool { retired.withLock { !$0 } }
    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
    }
}

/// Captured together under the original repository's state lock. The mapper is
/// the original pure row mapper; it does not look up the repository's live DB.
struct AnnotationLocalEditorConnection: Sendable {
    let database: SQLiteDatabase
    let syncPending: SyncPendingStore
    let databaseURL: URL
    let lifetime: AnnotationLocalEditorLifetime
    let mapRow: @Sendable (SQLiteRow, [String]) -> Annotation

    func requireCurrent(owner: AnnotationLocalEditorLifetime) throws {
        try owner.requireCurrent()
        try lifetime.requireCurrent()
    }
}

struct AnnotationLocalEditorBodyFormat: Sendable, Hashable {
    let identifier: String
    let version: Int64

    init(identifier: String, version: Int64) throws {
        guard AnnotationExchangeValidation.identifier(identifier), version > 0 else {
            throw AnnotationLocalEditorError.unsupportedBody
        }
        self.identifier = identifier; self.version = version
    }

    func accepts(_ body: TorahAnnotationEnvelope.RichBody) -> Bool {
        body.format == identifier && body.formatVersion == version
    }
}

struct AnnotationLocalEditorSnapshot: Sendable {
    let annotation: Annotation
    let annotationUUID: UUID
    let databaseURL: URL
    let revision: Int64
    /// nil is a legacy plain note. Unsupported versions retain their bytes and
    /// are readable here, but cannot be replaced by this editor.
    let document: TorahAnnotationEnvelopeDocument?
    let source: AnnotationExchangeSourceWitness
    let version: AnnotationExchangeVersion?
    let sessionID: UUID
}

/// One prepared save intent is reused on retry, retaining its source witness,
/// mutation ID and expected revision. Durable replay preserves the original
/// timestamp; a fully rolled-back attempt has no durable timestamp to preserve.
struct AnnotationLocalEditorIntent: Sendable {
    let mutationID: UUID
    let snapshot: AnnotationLocalEditorSnapshot
    let body: TorahAnnotationEnvelope.RichBody
    let textPreview: String
    let editorRevision: String?
    let intentDigest: String
}

struct AnnotationLocalEditorCommitted: Sendable {
    let receipt: AnnotationExchangeCommit
    let snapshot: AnnotationLocalEditorSnapshot
}

enum AnnotationLocalEditorOutcome: Sendable {
    case committed(AnnotationLocalEditorCommitted)
    /// The transaction really committed. Retirement/source change suppresses
    /// delivery to the old editor; it is not a rollback or an invitation to retry.
    case completedWithoutOwnership(AnnotationExchangeCommit)
}
