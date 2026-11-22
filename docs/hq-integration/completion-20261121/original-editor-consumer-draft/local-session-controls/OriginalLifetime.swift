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

