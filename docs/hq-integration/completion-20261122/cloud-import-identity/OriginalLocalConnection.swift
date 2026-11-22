import Foundation
import Synchronization

enum AnnotationLocalEditorError: Error, Sendable, Equatable {
    case noConnection, retired, busy, wrongOwner, wrongProfile, missingAnnotation
    case unsupportedBody, unsupportedEnvelope, staleBody, pendingDeletion
    case invalidPreview, invalidIntent, corruptRecord
}

/// A synchronous, one-way lifetime. Retirement never acquires another lock or
/// calls client code. The opt-in completion's critical section is entered only
/// after the original SQLite lock; it cannot await or call a transport/client.
/// Reopening the same file cannot revive a retired editor.
final class AnnotationLocalEditorLifetime: Sendable {
    private let retired = Mutex(false)
    func retire() { retired.withLock { $0 = true } }
    var isCurrent: Bool { retired.withLock { !$0 } }
    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
    }

    /// Internal DB completion boundary. Callers must already own their original
    /// SQLite lock and must not reenter this lifetime from `body`.
    func withCurrent<Value>(_ body: () throws -> Value) throws -> Value {
        try retired.withLock { value in
            guard !value else { throw AnnotationLocalEditorError.retired }
            return try body()
        }
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

