import Foundation

/// A local host session for an already-saved annotation, obtained from the
/// original AnnotationStore. Mounting an original Anytype editor is a separate
/// consumer boundary; no native editor, Space, or account is synthesized here.
@MainActor
final class AnnotationLocalEditorSession {
    let id: UUID
    let annotationUUID: UUID
    let databaseURL: URL
    private let persistence: AnnotationLocalEditorPersistence
    private let didCommit: @MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void
    private var busy = false

    fileprivate init(persistence: AnnotationLocalEditorPersistence,
                     didCommit: @escaping @MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void) {
        self.persistence = persistence; self.didCommit = didCommit
        id = persistence.sessionID; annotationUUID = persistence.annotationUUID
        databaseURL = persistence.connection.databaseURL
    }

    deinit { persistence.owner.retire() }

    /// Cancel/host removal retires authority permanently. It never deletes the
    /// saved annotation or retries an operation that was already admitted.
    func retire() { persistence.owner.retire() }
    var isCurrent: Bool { persistence.isOwned }

    func read() async throws -> AnnotationLocalEditorSnapshot {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.read() }
        return try await withTaskCancellationHandler {
            let snapshot = try await worker.value
            try storage.requireUnchanged(snapshot)
            try Task.checkCancellation()
            return snapshot
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }

    func prepareSave(snapshot: AnnotationLocalEditorSnapshot, mutationID: UUID,
                     body: TorahAnnotationEnvelope.RichBody, textPreview: String,
                     editorRevision: String?) throws -> AnnotationLocalEditorIntent {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        return try persistence.prepare(snapshot: snapshot, mutationID: mutationID, body: body,
            textPreview: textPreview, editorRevision: editorRevision)
    }

    func save(_ intent: AnnotationLocalEditorIntent) async throws -> AnnotationLocalEditorOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.commit(intent) }
        return try await withTaskCancellationHandler {
            let saved = try await worker.value
            let canDeliver = storage.canDeliver(saved)
            if !saved.receipt.replayed { didCommit(saved, canDeliver) }
            guard canDeliver, storage.isOwned else { return .completedWithoutOwnership(saved.receipt) }
            return .committed(saved)
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }
}

extension AnnotationStore {
    /// Explicit opt-in, saved UUID only. Normal note Save/Cancel/tags and their
    /// original cache/CloudKit methods remain unchanged. A future real editor
    /// must declare the exact body formats it can round-trip; there is no default.
    @MainActor
    func makeLocalAnnotationEditor(annotation: Annotation,
                                   supportedFormats: Set<AnnotationLocalEditorBodyFormat>) throws -> AnnotationLocalEditorSession {
        guard let id = annotation.id, id > 0,
              let uuid = annotation.ckRecordId.flatMap(UUID.init(uuidString:)) else {
            throw AnnotationLocalEditorError.missingAnnotation
        }
        let connection = try repository.captureLocalEditorConnection()
        let persistence = try AnnotationLocalEditorPersistence(connection: connection, annotationID: id,
            annotationUUID: uuid, sessionID: UUID(), owner: AnnotationLocalEditorLifetime(),
            formats: supportedFormats, digest: AnnotationExchangePlatformDigest())
        return AnnotationLocalEditorSession(persistence: persistence) { [self] saved, canDeliver in
            // Invalidate rather than installing an old-profile row into the
            // shared cache. This event has no annotation payload and remains
            // safe if a profile switch occurs during an admitted publication.
            clearAllCaches()
            if canDeliver && persistence.isOwned {
                // Admission into the unchanged original upload pipeline only.
                // Its detached/debounced work can finish after later retirement;
                // this is not remote cancellation or rollback authority.
                CloudKitSyncManager.shared.upload(annotations: [saved.snapshot.annotation], trackPending: false)
            }
            events.send(.treeInvalidated)
            // If publication was retired, the original sync_pending upload is
            // already durable in its own profile DB. No ACK is fabricated.
        }
    }
}
