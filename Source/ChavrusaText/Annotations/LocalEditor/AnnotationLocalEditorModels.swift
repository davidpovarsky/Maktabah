import Foundation
import Synchronization
import OtzariaActionCore
#if os(iOS) && canImport(AnytypeOriginalEditor)
import AnytypeOriginalEditor
#endif

enum AnnotationLocalEditorError: Error, Sendable, Equatable {
    case noConnection, retired, busy, wrongOwner, wrongProfile, missingAnnotation
    case unsupportedBody, unsupportedEnvelope, staleBody, pendingDeletion
    case invalidPreview, invalidIntent, corruptRecord
}

/// A synchronous, one-way lifetime. Retirement performs no I/O or client
/// callbacks. The optional closed SDK link invalidates its exact native token
/// before this lock is released; that SDK entry schedules observer delivery
/// separately. It never reenters a Host lifetime, repository or SQLite lock.
/// Reopening the same file cannot revive a retired editor.
final class AnnotationLocalEditorLifetime: Sendable {
    private struct State: Sendable {
        var retired = false
        #if os(iOS) && canImport(AnytypeOriginalEditor)
        struct NativeImportLink: Sendable {
            weak var source: AnytypeOriginalAnnotationImportSourceLifetime?
        }
        var nativeImports: [NativeImportLink] = []
        struct LocalAnnotationLink: Sendable {
            weak var source: AnytypeOriginalEditorLocalAnnotationSourceLifetime?
        }
        var localAnnotations: [LocalAnnotationLink] = []
        struct NativeBackfillLink: Sendable {
            weak var source: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime?
        }
        var nativeBackfills: [NativeBackfillLink] = []
        #endif
    }
    private let state = Mutex(State())

    func retire() {
        #if os(iOS) && canImport(AnytypeOriginalEditor)
        let retained = state.withLock { value -> (
            [AnytypeOriginalAnnotationImportSourceLifetime],
            [AnytypeOriginalEditorLocalAnnotationSourceLifetime],
            [AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime]
        ) in
            guard !value.retired else { return ([], [], []) }
            value.retired = true
            let imports = value.nativeImports.compactMap { $0.source }
            let annotations = value.localAnnotations.compactMap { $0.source }
            let backfills = value.nativeBackfills.compactMap { $0.source }
            value.nativeImports.removeAll()
            value.localAnnotations.removeAll()
            value.nativeBackfills.removeAll()
            for source in imports { source.retire() }
            for source in annotations { source.retire() }
            for source in backfills { source.retire() }
            return (imports, annotations, backfills)
        }
        // A last strong release/deinit must occur outside this Host lock too.
        withExtendedLifetime(retained) {}
        #else
        state.withLock { $0.retired = true }
        #endif
    }

    var isCurrent: Bool { state.withLock { !$0.retired } }
    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
    }

    /// Internal DB completion boundary. Callers must already own their original
    /// SQLite lock and must not reenter this lifetime from body.
    func withCurrent<Value>(_ body: () throws -> Value) throws -> Value {
        try state.withLock { value in
            guard !value.retired else { throw AnnotationLocalEditorError.retired }
            return try body()
        }
    }

    #if os(iOS) && canImport(AnytypeOriginalEditor)
    /// Called only for a newly prepared exact saved-row owner, outside every
    /// Host transaction/repository lock. There is no arbitrary observer closure.
    /// An already retired parent also retires the incoming SDK token before
    /// returning; separate parent registrations therefore have no admission gap.
    func bindNativeImportRetirement(_ source: AnytypeOriginalAnnotationImportSourceLifetime) throws {
        let retained = try state.withLock { value in
            guard !value.retired, source.isCurrent else {
                source.retire()
                throw AnnotationLocalEditorError.retired
            }
            let sources = value.nativeImports.compactMap { $0.source }
            value.nativeImports = sources.map { .init(source: $0) }
            if !sources.contains(where: { $0 === source }) {
                value.nativeImports.append(.init(source: source))
            }
            return sources
        }
        withExtendedLifetime(retained) {}
    }

    /// The local-only native editor has the same synchronous retirement fence
    /// as an explicit import. Its SDK token cannot outlive this original owner.
    func bindLocalAnnotationRetirement(_ source: AnytypeOriginalEditorLocalAnnotationSourceLifetime) throws {
        let retained = try state.withLock { value in
            guard !value.retired, source.isCurrent else {
                source.retire()
                throw AnnotationLocalEditorError.retired
            }
            let sources = value.localAnnotations.compactMap { $0.source }
            value.localAnnotations = sources.map { .init(source: $0) }
            if !sources.contains(where: { $0 === source }) {
                value.localAnnotations.append(.init(source: source))
            }
            return sources
        }
        withExtendedLifetime(retained) {}
    }

    /// The bounded Backfill run must retire with BOTH its run owner and the
    /// captured original DB connection before native GCD admission can occur.
    /// The SDK token marks itself unavailable synchronously and defers observers.
    func bindNativeBackfillRetirement(_ source: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime) throws {
        let retained = try state.withLock { value in
            guard !value.retired, source.isCurrent else {
                source.retire()
                throw AnnotationLocalEditorError.retired
            }
            let sources = value.nativeBackfills.compactMap { $0.source }
            value.nativeBackfills = sources.map { .init(source: $0) }
            if !sources.contains(where: { $0 === source }) {
                value.nativeBackfills.append(.init(source: source))
            }
            return sources
        }
        withExtendedLifetime(retained) {}
    }
    #endif
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

/// Native Backfill may preserve the exact existing plain note while adding its
/// first rich body. Ordinary edits continue to replace the note with preview.
enum AnnotationLocalEditorNoteWritePolicy: String, Sendable {
    case replaceWithPreview
    case preserveOriginalText
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
    let noteWritePolicy: AnnotationLocalEditorNoteWritePolicy

    init(mutationID: UUID, snapshot: AnnotationLocalEditorSnapshot,
         body: TorahAnnotationEnvelope.RichBody, textPreview: String,
         editorRevision: String?, intentDigest: String,
         noteWritePolicy: AnnotationLocalEditorNoteWritePolicy = .replaceWithPreview) {
        self.mutationID = mutationID
        self.snapshot = snapshot
        self.body = body
        self.textPreview = textPreview
        self.editorRevision = editorRevision
        self.intentDigest = intentDigest
        self.noteWritePolicy = noteWritePolicy
    }
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
