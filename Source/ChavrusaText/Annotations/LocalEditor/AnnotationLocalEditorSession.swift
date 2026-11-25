import Foundation
#if os(iOS) && canImport(AnytypeOriginalEditor)
import AnytypeOriginalEditor
#endif

/// A local host session for an already-saved annotation, obtained from the
/// original AnnotationStore. Mounting an original Anytype editor is a separate
/// consumer boundary; no native editor, Space, or account is synthesized here.
@MainActor
final class AnnotationLocalEditorSession {
    let id: UUID
    let annotationUUID: UUID
    let databaseURL: URL
    private let persistence: AnnotationLocalEditorPersistence
    // Alias the original transaction owner's one-way lifetime. Source events
    // may arrive off MainActor while its detached SQLite worker is suspended.
    private nonisolated let retirementOwner: AnnotationLocalEditorLifetime
    private let didCommit: @MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void
    private let didCommitOwnedCloud: (@MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void)?
    private var busy = false

    fileprivate init(persistence: AnnotationLocalEditorPersistence,
                     didCommitOwnedCloud: (@MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void)? = nil,
                     didCommit: @escaping @MainActor @Sendable (AnnotationLocalEditorCommitted, Bool) -> Void) {
        self.persistence = persistence; self.didCommit = didCommit
        retirementOwner = persistence.owner
        self.didCommitOwnedCloud = didCommitOwnedCloud
        id = persistence.sessionID; annotationUUID = persistence.annotationUUID
        databaseURL = persistence.connection.databaseURL
    }

    deinit { retirementOwner.retire() }

    /// Cancel/host removal retires authority permanently. It never deletes the
    /// saved annotation or retries an operation that was already admitted.
    nonisolated func retire() { retirementOwner.retire() }
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
    /// Read-only identity lookup on the current original profile connection.
    /// It never registers a legacy alias or changes the saved CloudKit identity.
    @MainActor
    func resolveAnnotationExchangeIdentity(annotation: Annotation) throws -> UUID? {
        guard let id = annotation.id, id > 0 else { throw AnnotationLocalEditorError.missingAnnotation }
        let connection = try repository.captureLocalEditorConnection()
        try connection.lifetime.requireCurrent()
        let uuid = try AnnotationExchangeIdentity.resolve(database: connection.database, annotationID: id,
                                                          originalRecordID: annotation.ckRecordId)
        try connection.lifetime.requireCurrent()
        return uuid
    }

    /// Explicit opt-in, saved or explicitly migrated identity only. Normal note Save/Cancel/tags and their
    /// original cache/CloudKit methods remain unchanged. A future real editor
    /// must declare the exact body formats it can round-trip; there is no default.
    @MainActor
    func makeLocalAnnotationEditor(annotation: Annotation,
                                   supportedFormats: Set<AnnotationLocalEditorBodyFormat>) throws -> AnnotationLocalEditorSession {
        guard let id = annotation.id, id > 0 else { throw AnnotationLocalEditorError.missingAnnotation }
        let connection = try repository.captureLocalEditorConnection()
        let uuid: UUID
        if let original = annotation.ckRecordId.flatMap(UUID.init(uuidString:)) {
            // Keep the original UUID constructor inert. The first actual read
            // validates uniqueness and the current stored bytes; cached UUID
            // letter case never restamps the original CloudKit record name.
            uuid = original
        } else if let registered = try AnnotationExchangeIdentity.resolve(
            database: connection.database, annotationID: id, originalRecordID: annotation.ckRecordId) {
            uuid = registered
        } else {
            throw AnnotationLocalEditorError.missingAnnotation
        }
        let persistence = try AnnotationLocalEditorPersistence(connection: connection, annotationID: id,
            annotationUUID: uuid, sessionID: UUID(), owner: AnnotationLocalEditorLifetime(),
            formats: supportedFormats, digest: AnnotationExchangePlatformDigest())
        return AnnotationLocalEditorSession(persistence: persistence, didCommitOwnedCloud: { [self] _, _ in
            // Same original cache/tree publication, without dispatching a second
            // unowned upload alongside the explicitly prepared owned operation.
            clearAllCaches()
            events.send(.treeInvalidated)
        }) { [self] saved, canDeliver in
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

extension AnnotationLocalEditorSession {
    /// Explicit opt-in. The existing normal save method and its CloudKit path
    /// remain unchanged. Missing actual identity still permits a local commit
    /// but permanently defers this preparation's upload; it never adopts an
    /// account discovered only after the commit.
    func prepareOwnedCloudSave(_ intent: AnnotationLocalEditorIntent) async throws -> AnnotationLocalEditorCloudPreparation {
        try await prepareOwnedCloudSave(intent, client: AnnotationLocalEditorCloudClient.original())
    }

    /// Internal component boundary. Application callers use the overload above;
    /// tests must declare their identity/transport/wait doubles explicitly.
    func prepareOwnedCloudSave(_ intent: AnnotationLocalEditorIntent,
                               client: AnnotationLocalEditorCloudClient?) async throws -> AnnotationLocalEditorCloudPreparation {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        guard didCommitOwnedCloud != nil else { throw AnnotationLocalEditorCloudDeferral.invalidPublication }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try await AnnotationLocalEditorCloudPreparation.prepare(intent: intent, storage: storage, client: client) }
        return try await withTaskCancellationHandler {
            let prepared = try await worker.value
            try storage.requireUnchanged(intent.snapshot)
            try Task.checkCancellation()
            return prepared
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }

    func saveOwnedCloud(_ preparation: AnnotationLocalEditorCloudPreparation) async throws -> AnnotationLocalEditorCloudSaveOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        guard let didCommitOwnedCloud else { throw AnnotationLocalEditorCloudDeferral.invalidPublication }
        try preparation.consume(for: persistence)
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.commitForOwnedCloud(preparation.intent) }
        return try await withTaskCancellationHandler {
            let committed = try await worker.value
            let saved = committed.saved
            if !saved.receipt.replayed { didCommitOwnedCloud(saved, storage.canDeliver(saved)) }
            let outcome: AnnotationLocalEditorOutcome = storage.canDeliver(saved)
                ? .committed(saved) : .completedWithoutOwnership(saved.receipt)
            // The actual local commit is returned immediately. The publication
            // handle retains the real remote/ACK/worker outcome independently of
            // whether the original editor survives the subsequent awaits.
            let publication = AnnotationLocalEditorCloudPublication(storage: storage, preparation: preparation, committed: committed)
            return .init(local: outcome, publication: publication)
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }
}


// MARK: - Explicit saved-row original-native attempt bookkeeping

extension AnnotationLocalEditorSession {
    func nativeAttemptObservation() async throws -> AnnotationLocalEditorNativeAttemptObservation? {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.nativeAttemptObservation() }
        return try await withTaskCancellationHandler {
            let observation = try await worker.value
            try owner.requireCurrent()
            try storage.connection.lifetime.requireCurrent()
            try Task.checkCancellation()
            return observation
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }

    func prepareNativeAttempt(snapshot: AnnotationLocalEditorSnapshot,
                              comparison: AnnotationLocalEditorNativeComparison) async throws -> AnnotationLocalEditorNativePreparationOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.prepareNativeAttempt(snapshot: snapshot, comparison: comparison) }
        return try await withTaskCancellationHandler {
            let prepared = try await worker.value
            guard storage.canDeliverNativeSnapshot(prepared.snapshot) else {
                return .recordedWithoutOwnership(prepared.observation)
            }
            return .prepared(prepared)
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }

    func markNativeAttemptMayHaveDispatched(_ prepared: AnnotationLocalEditorNativePreparation) async throws -> AnnotationLocalEditorNativeTransitionOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached { try storage.markNativeAttemptMayHaveDispatched(prepared) }
        return try await withTaskCancellationHandler {
            let receipt = try await worker.value
            // Preserve the durable fact even if the original source/owner retired.
            return storage.canDeliverNativeSnapshot(prepared.snapshot)
                ? .recorded(receipt) : .recordedWithoutOwnership(receipt)
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }

    func abandonPreparedNativeAttempt(_ observed: AnnotationLocalEditorNativeAttemptObservation,
                                      currentSnapshot: AnnotationLocalEditorSnapshot) async throws -> AnnotationLocalEditorNativeTransitionOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached {
            try storage.abandonPreparedNativeAttempt(observed, currentSnapshot: currentSnapshot)
        }
        return try await withTaskCancellationHandler {
            let receipt = try await worker.value
            return storage.canDeliverNativeSnapshot(currentSnapshot)
                ? .recorded(receipt) : .recordedWithoutOwnership(receipt)
        } onCancel: {
            owner.retire()
            worker.cancel()
        }
    }
}

extension AnnotationLocalEditorSession {
    /// No SQL or asynchronous work. This observes the same private preparation
    /// and the original captured session/database generations only.
    func ownsNativePreparation(_ prepared: AnnotationLocalEditorNativePreparation) -> Bool {
        persistence.ownsNativePreparation(prepared)
    }

    #if os(iOS) && canImport(AnytypeOriginalEditor)
    func bindLocalAnnotationRetirement(
        _ source: AnytypeOriginalEditorLocalAnnotationSourceLifetime,
        snapshot: AnnotationLocalEditorSnapshot
    ) throws {
        guard !busy else { source.retire(); throw AnnotationLocalEditorError.busy }
        try persistence.bindLocalAnnotationRetirement(source, snapshot: snapshot)
    }

    func bindNativeImportRetirement(
        _ source: AnytypeOriginalAnnotationImportSourceLifetime,
        prepared: AnnotationLocalEditorNativePreparation
    ) throws {
        try persistence.bindNativeImportRetirement(source, prepared: prepared)
    }
    #endif
}


// A separate conditional-update owner leaves original fresh-import history intact.
extension AnnotationLocalEditorSession {
    func prepareNativeRevision(
        snapshot: AnnotationLocalEditorSnapshot,
        comparison: AnnotationLocalEditorNativeComparison,
        target: AnnotationLocalEditorNativeRevisionTarget
    ) async throws -> AnnotationLocalEditorNativeRevisionPreparationOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached {
            try storage.prepareNativeRevision(snapshot: snapshot, comparison: comparison, target: target)
        }
        return try await withTaskCancellationHandler {
            let prepared = try await worker.value
            return storage.canDeliverNativeSnapshot(prepared.snapshot)
                ? .prepared(prepared) : .recordedWithoutOwnership(prepared.observation)
        } onCancel: {
            owner.retire(); worker.cancel()
        }
    }

    func markNativeRevisionMayHaveDispatched(
        _ prepared: AnnotationLocalEditorNativeRevisionPreparation,
        requestBytes: Data, requestSHA256: String
    ) async throws -> AnnotationLocalEditorNativeTransitionOutcome {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        busy = true
        defer { busy = false }
        let storage = persistence, owner = persistence.owner
        let worker = Task.detached {
            try storage.markNativeRevisionMayHaveDispatched(prepared,
                requestBytes: requestBytes, requestSHA256: requestSHA256)
        }
        return try await withTaskCancellationHandler {
            let receipt = try await worker.value
            return storage.canDeliverNativeSnapshot(prepared.snapshot)
                ? .recorded(receipt) : .recordedWithoutOwnership(receipt)
        } onCancel: {
            owner.retire(); worker.cancel()
        }
    }

    func ownsNativeRevisionPreparation(_ prepared: AnnotationLocalEditorNativeRevisionPreparation) -> Bool {
        persistence.ownsNativeRevisionPreparation(prepared)
    }

    #if os(iOS) && canImport(AnytypeOriginalEditor)
    func bindNativeRevisionRetirement(
        _ source: AnytypeOriginalAnnotationImportSourceLifetime,
        prepared: AnnotationLocalEditorNativeRevisionPreparation
    ) throws {
        try persistence.bindNativeRevisionRetirement(source, prepared: prepared)
    }
    #endif
}

#if os(iOS) && canImport(AnytypeOriginalEditor)
extension AnnotationLocalEditorSession {
    /// First native conversion only. Full original text and the bounded preview
    /// come from the same closed SDK capture, validated against its still-current
    /// native session. The ordinary editor save API keeps its existing behavior.
    func prepareNativeBackfill(snapshot: AnnotationLocalEditorSnapshot, mutationID: UUID,
                               capture: AnytypeOriginalEditorLocalAnnotationCapture,
                               nativeSession: AnytypeOriginalEditorLocalAnnotationSession,
                               hostProfileID: UUID) throws -> AnnotationLocalEditorIntent {
        guard !busy else { throw AnnotationLocalEditorError.busy }
        guard isCurrent else { throw AnnotationLocalEditorError.retired }
        try nativeSession.validateCapturedSource(capture)
        let binding = nativeSession.binding
        let actual = capture.nativeCapture.snapshot
        guard binding.hostProfileID.utf8.elementsEqual(hostProfileID.uuidString.utf8),
              binding.annotationUUID == snapshot.annotationUUID,
              binding.expectedRevision == snapshot.revision,
              binding.sourceWitnessSHA256 == snapshot.source.digest,
              actual.provenance.matchesCaptureBinding(binding),
              let originalText = snapshot.annotation.note,
              originalText.utf8.elementsEqual(capture.fullPlainText.utf8) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        try persistence.requireUnchanged(snapshot)
        try nativeSession.validateCapturedSource(capture)
        let body = TorahAnnotationEnvelope.RichBody(
            format: AnytypeOriginalEditorSnapshot.format,
            formatVersion: AnytypeOriginalEditorSnapshot.formatVersion,
            bytes: actual.bodyBytes)
        return try persistence.prepareNativeBackfill(snapshot: snapshot, mutationID: mutationID,
            body: body, textPreview: capture.textPreview,
            editorRevision: actual.nativeArchiveSHA256)
    }
}
#endif
