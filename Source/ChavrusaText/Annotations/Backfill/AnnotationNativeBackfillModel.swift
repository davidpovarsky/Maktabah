#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import Observation
import AnytypeOriginalEditor

/// Owns one original profile/scene generation for a bounded explicit run.
/// Individual note observations use the existing shared LocalEditor consumer.
@MainActor
private final class AnnotationNativeBackfillRunOwner {
    let lifetime = AnnotationLocalEditorLifetime()
    let connection: AnnotationLocalEditorConnection
    let mapping: StudyWorkspaceMappingObservation
    private weak var workspace: StudyWorkspaceNavigationAdapter?
    private var subscription: StudyWorkspaceMappingSubscription?
    private var batchSource: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime?

    init(workspace: StudyWorkspaceNavigationAdapter,
         connection: AnnotationLocalEditorConnection) throws {
        guard let mapping = workspace.mappingOwnershipObservation(),
              mapping.coverage == .liveNativeSetters, mapping.source.event.phase == .available,
              mapping.source.event.epoch == mapping.epoch else {
            throw AnnotationNativeBackfillError.unavailableWorkspace
        }
        self.workspace = workspace; self.connection = connection; self.mapping = mapping
        subscription = mapping.source.subscribeInvalidation(owner: self) { owner, _ in owner.retire() }
        try requireCurrent()
    }

    var isCurrent: Bool {
        guard lifetime.isCurrent, connection.lifetime.isCurrent,
              let actual = workspace?.mappingOwnershipObservation(),
              actual.source === mapping.source, actual.owner == mapping.owner,
              actual.scene.utf8.elementsEqual(mapping.scene.utf8),
              actual.epoch == mapping.epoch, actual.projection == mapping.projection,
              actual.coverage == .liveNativeSetters,
              actual.source.event.phase == .available,
              actual.source.event.epoch == actual.epoch else {
            retire(); return false
        }
        return true
    }

    func requireCurrent() throws {
        guard isCurrent else { throw AnnotationNativeBackfillError.wrongProfile }
    }

    /// Both captured parent generations close the exact SDK token before
    /// native factory admission. There is no polling-only await gap.
    func bindNativeBatch(_ source: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime) throws {
        do {
            try requireCurrent()
            guard batchSource == nil, source.isCurrent,
                  source.source.hostProfileID.utf8.elementsEqual(mapping.projection.profileID.uuidString.utf8) else {
                throw AnnotationNativeBackfillError.wrongProfile
            }
            try lifetime.bindNativeBackfillRetirement(source)
            try connection.lifetime.bindNativeBackfillRetirement(source)
            batchSource = source
            try requireCurrent()
            guard source.isCurrent else { throw AnnotationNativeBackfillError.wrongProfile }
        } catch {
            source.retire()
            throw error
        }
    }

    func retire() {
        lifetime.retire()
        subscription?.cancel(); subscription = nil
    }

    isolated deinit { lifetime.retire(); subscription?.cancel() }
}

@MainActor
@Observable
final class AnnotationNativeBackfillModel {
    enum State: Equatable {
        case ready, running, pausing, closing, completed, paused, failed, closeFailed
    }
    private(set) var state: State = .ready
    private(set) var total: Int64 = 0
    private(set) var scanned = 0
    private(set) var converted = 0
    private(set) var retained: [AnnotationNativeBackfillDisposition: Int] = [:]
    /// An actual committed receipt remains observable even after owner loss.
    private(set) var lastCommit: AnnotationExchangeCommit?
    private(set) var failureCode: String?
    private(set) var retainedCaptureDirectory: URL?
    private(set) var batchLimitReached = false

    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var cleanup: Task<Void, Error>?
    @ObservationIgnored private var runOwner: AnnotationNativeBackfillRunOwner?
    @ObservationIgnored private var local: AnnotationLocalEditorSession?
    @ObservationIgnored private var observation: AnnotationOriginalEditorSourceObservation?
    @ObservationIgnored private var nativeSource: AnytypeOriginalEditorLocalAnnotationSourceLifetime?
    @ObservationIgnored private var native: AnytypeOriginalEditorLocalAnnotationSession?
    @ObservationIgnored private var nativeBatchSource: AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime?
    @ObservationIgnored private var nativeBatch: AnytypeOriginalEditorLocalAnnotationBatchSession?
    @ObservationIgnored private var nativeAdmissions = 0
    @ObservationIgnored private var afterClose: State = .paused
    @ObservationIgnored private var requestedNativeRuntime = false

    var isRunning: Bool { state == .running || state == .pausing || state == .closing }
    var retainedCount: Int { retained.values.reduce(0, +) }
    func count(_ disposition: AnnotationNativeBackfillDisposition) -> Int { retained[disposition, default: 0] }

    func start(workspace: StudyWorkspaceNavigationAdapter, preparationCompleted: Bool) {
        guard preparationCompleted, worker == nil, cleanup == nil, state != .closeFailed else { return }
        let owner: AnnotationNativeBackfillRunOwner
        let formats: Set<AnnotationLocalEditorBodyFormat>
        do {
            let connection = try AnnotationRepository.shared.captureLocalEditorConnection()
            owner = try AnnotationNativeBackfillRunOwner(workspace: workspace, connection: connection)
            formats = try AnnotationOriginalEditorMount.supportedFormats
        } catch {
            failureCode = String(describing: error); state = .failed; return
        }
        runOwner = owner
        state = .running; total = 0; scanned = 0; converted = 0; retained = [:]
        lastCommit = nil; failureCode = nil; retainedCaptureDirectory = nil
        requestedNativeRuntime = false; batchLimitReached = false; nativeAdmissions = 0
        worker = Task { [self] in
            var terminal = State.completed
            do {
                let connection = owner.connection, lifetime = owner.lifetime
                let (catalog, scan) = try await Self.detached {
                    let catalog = try AnnotationNativeBackfillCatalog(connection: connection,
                        owner: lifetime, formats: formats, digest: AnnotationExchangePlatformDigest())
                    return (catalog, try catalog.inspect())
                }
                try owner.requireCurrent(); try Task.checkCancellation()
                total = scan.rowCount
                var cursor: Int64 = 0
                scanLoop: while true {
                    try owner.requireCurrent(); try Task.checkCancellation()
                    let after = cursor
                    let batch = try await Self.detached {
                        try catalog.readBatch(scan, afterAnnotationID: after)
                    }
                    for item in batch.items {
                        try owner.requireCurrent(); try Task.checkCancellation()
                        scanned += 1
                        guard item.disposition == .ready, let candidate = item.candidate else {
                            retained[item.disposition, default: 0] += 1
                            continue
                        }
                        if nativeAdmissions >= AnytypeOriginalEditorLocalAnnotationBatchSession.maximumAnnotations {
                            batchLimitReached = true; terminal = .paused; break scanLoop
                        }
                        do {
                            let outcome = try await convert(candidate, owner: owner, workspace: workspace)
                            switch outcome {
                            case .committed(let actual): lastCommit = actual.receipt
                            case .completedWithoutOwnership(let actual): lastCommit = actual
                            }
                            converted += 1
                            // Never hide a real COMMIT with a post-save throw.
                            if !owner.isCurrent || Task.isCancelled {
                                terminal = .paused; break scanLoop
                            }
                        } catch {
                            if Self.isChangedSource(error), owner.isCurrent, !Task.isCancelled {
                                retained[.changed, default: 0] += 1
                            } else if (error as? AnnotationNativeBackfillError) == .previewWouldChangeSavedText,
                                      owner.isCurrent, !Task.isCancelled {
                                // A completed capture whose complete text or bounded
                                // preview differs cannot Save. Its private draft is already
                                // retired; retain the original and continue other notes.
                                retained[.previewMismatch, default: 0] += 1
                            } else { throw error }
                        }
                    }
                    cursor = batch.lastAnnotationID
                    if batch.isComplete { break }
                }
            } catch is CancellationError {
                terminal = .paused
            } catch {
                failureCode = String(describing: error)
                terminal = owner.isCurrent && !Task.isCancelled ? .failed : .paused
            }
            retireCurrentNote()
            retireCurrentBatch()
            owner.retire()
            if requestedNativeRuntime {
                afterClose = terminal
                state = .closing
                // This independent task keeps the real AccountStop/drain alive
                // when the presentation's awaiting task has been cancelled.
                let closing = Task { @MainActor in
                    try await AnytypeOriginalEditorModule.suspendLocalAnnotationRuntime(
                        appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
                }
                cleanup = closing
                do {
                    try await closing.value
                    cleanup = nil; state = terminal
                } catch {
                    failureCode = String(describing: error)
                    cleanup = nil; state = .closeFailed
                }
            } else { state = terminal }
            runOwner = nil
            worker = nil
        }
    }

    func pause() {
        guard isRunning else { return }
        if state != .closing { state = .pausing }
        worker?.cancel()
        runOwner?.retire()
        retireCurrentNote()
        retireCurrentBatch()
    }

    /// Retry the retained failed native Stop only. It never repeats a body
    /// conversion, native AccountCreate or a canonical SQLite mutation.
    func retryClose() {
        guard state == .closeFailed, cleanup == nil, worker == nil else { return }
        state = .closing
        let closing = Task { @MainActor in
            try await AnytypeOriginalEditorModule.retrySuspendLocalAnnotationRuntime(
                appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier)
        }
        cleanup = closing
        worker = Task { [self] in
            do { try await closing.value; state = afterClose }
            catch { failureCode = String(describing: error); state = .closeFailed }
            cleanup = nil; worker = nil
        }
    }

    private func convert(_ candidate: AnnotationNativeBackfillCandidate,
                         owner: AnnotationNativeBackfillRunOwner,
                         workspace: StudyWorkspaceNavigationAdapter) async throws -> AnnotationLocalEditorOutcome {
        defer { retireCurrentNote() }
        try owner.requireCurrent(); try Task.checkCancellation()
        let source = try AnnotationOriginalEditorSourceObservation(annotation: candidate.annotation,
            store: AnnotationStore.shared, workspace: workspace, presentationLifetime: owner.lifetime)
        observation = source
        let local = try AnnotationStore.shared.makeLocalAnnotationEditor(annotation: candidate.annotation,
            supportedFormats: AnnotationOriginalEditorMount.supportedFormats)
        self.local = local
        try source.bindLocal(local)
        let captured = try await local.read()
        try owner.requireCurrent(); try source.requireCurrent()
        guard source.profileID == owner.mapping.projection.profileID,
              captured.databaseURL.absoluteString.utf8.elementsEqual(owner.connection.databaseURL.absoluteString.utf8),
              source.annotationUUID == candidate.annotationUUID else {
            throw AnnotationNativeBackfillError.wrongProfile
        }
        try AnnotationNativeBackfillPolicy.requireSameCandidate(candidate, snapshot: captured)
        guard try AnnotationOriginalEditorMount.nativeBody(in: captured) == nil,
              let savedText = captured.annotation.note else {
            throw AnnotationNativeBackfillError.sourceChanged
        }
        let descriptor = try AnytypeOriginalEditorLocalAnnotationSource(
            hostProfileID: source.profileID.uuidString, annotationUUID: captured.annotationUUID,
            expectedRevision: captured.revision, sourceWitnessSHA256: captured.source.digest,
            payloadSHA256: captured.version?.payloadDigest)
        let lifetime = AnytypeOriginalEditorLocalAnnotationSourceLifetime(source: descriptor)
        nativeSource = lifetime
        try source.bindLocalAnnotation(lifetime, local: local, snapshot: captured)
        let batch = try await currentBatch(owner: owner)
        try owner.requireCurrent(); try source.requireCurrent(); try Task.checkCancellation()
        guard nativeAdmissions < AnytypeOriginalEditorLocalAnnotationBatchSession.maximumAnnotations else {
            throw AnnotationNativeBackfillError.sourceChanged
        }
        // Count admission attempts, including retained/uncertain ones. A UUID
        // is never retried inside the same original private Space.
        nativeAdmissions += 1
        let opened = try await batch.openPlainAnnotation(
            sourceLifetime: lifetime, text: savedText
        ) { [source, local] actual in
            actual == descriptor && source.isCurrent && local.isCurrent
        }
        native = opened
        try owner.requireCurrent(); try source.requireCurrent()
        try AnnotationOriginalEditorMount.assertUnchanged(captured, try await local.read())
        try source.requireCurrent()
        let binding = opened.binding
        guard binding.annotationUUID == captured.annotationUUID,
              binding.hostProfileID.utf8.elementsEqual(source.profileID.uuidString.utf8),
              binding.expectedRevision == captured.revision,
              binding.sourceWitnessSHA256 == captured.source.digest else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        let actual: AnytypeOriginalEditorLocalAnnotationCapture
        do {
            actual = try await opened.captureNativeSnapshot(maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes)
        } catch {
            if let failure = error as? AnytypeOriginalEditorSnapshotCaptureFailure {
                retainedCaptureDirectory = failure.retainedDirectoryURL
            }
            throw error
        }
        retainedCaptureDirectory = actual.nativeCapture.retainedDirectoryURL
        guard actual.nativeCapture.snapshot.provenance.matchesCaptureBinding(binding) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        try AnnotationNativeBackfillPolicy.requireExactCapturedText(savedText: savedText,
            originalNativeFullPlainText: actual.fullPlainText, originalNativePreview: actual.textPreview)
        try owner.requireCurrent(); try source.requireCurrent()
        try AnnotationOriginalEditorMount.assertUnchanged(captured, try await local.read())
        try source.requireCurrent(); try Task.checkCancellation()
        let intent = try local.prepareNativeBackfill(snapshot: captured, mutationID: UUID(),
            capture: actual, nativeSession: opened, hostProfileID: source.profileID)
        // Reuse the real saved-note CAS, original pending queue/cache publication
        // and configured CloudKit path. No Anytype destination is introduced.
        return try await local.save(intent)
    }

    private func currentBatch(owner: AnnotationNativeBackfillRunOwner) async throws
        -> AnytypeOriginalEditorLocalAnnotationBatchSession {
        try owner.requireCurrent(); try Task.checkCancellation()
        if let nativeBatch {
            guard let nativeBatchSource, nativeBatchSource.isCurrent,
                  nativeBatch.source == nativeBatchSource.source else {
                throw AnnotationNativeBackfillError.wrongProfile
            }
            return nativeBatch
        }
        let descriptor = try AnytypeOriginalEditorLocalAnnotationBatchSource(
            hostProfileID: owner.mapping.projection.profileID.uuidString, batchID: UUID())
        let lifetime = AnytypeOriginalEditorLocalAnnotationBatchSourceLifetime(source: descriptor)
        try owner.bindNativeBatch(lifetime)
        nativeBatchSource = lifetime
        // The actual runtime may dispatch before a throwing factory returns;
        // retain Stop/drain ownership even if opening the batch fails.
        requestedNativeRuntime = true
        let opened = try await AnytypeOriginalEditorModule.openLocalAnnotationBatch(
            appGroup: ITorahSharedContainer.chavrusaTextAppGroupIdentifier,
            sourceLifetime: lifetime
        ) { [owner] actual in
            actual == descriptor && owner.isCurrent
        }
        nativeBatch = opened
        try owner.requireCurrent(); try Task.checkCancellation()
        guard lifetime.isCurrent, opened.source == descriptor else {
            throw AnnotationNativeBackfillError.wrongProfile
        }
        return opened
    }

    private func retireCurrentBatch() {
        nativeBatch?.retire(); nativeBatch = nil
        nativeBatchSource?.retire(); nativeBatchSource = nil
    }

    private func retireCurrentNote() {
        native?.retire(); native = nil
        nativeSource?.retire(); nativeSource = nil
        observation?.retire(); observation = nil
        local?.retire(); local = nil
    }

    private nonisolated static func detached<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let task = Task.detached(priority: .utility, operation: operation)
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: { task.cancel() }
    }

    private nonisolated static func isChangedSource(_ error: any Error) -> Bool {
        if let error = error as? AnnotationNativeBackfillError {
            return error == .sourceChanged
        }
        if let error = error as? AnnotationExchangeError {
            return error == .staleSource || error == .staleRevision
        }
        return false
    }

    isolated deinit {
        runOwner?.retire(); native?.retire(); nativeSource?.retire()
        nativeBatch?.retire(); nativeBatchSource?.retire()
        observation?.retire(); local?.retire(); worker?.cancel()
    }
}
#endif
