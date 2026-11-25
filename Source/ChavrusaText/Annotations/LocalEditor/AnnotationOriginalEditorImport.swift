#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import AnytypeOriginalEditor

enum AnnotationOriginalEditorImportPreparationOutcome {
    case prepared(AnnotationOriginalEditorImportAttempt)
    /// The original SQLite transaction committed. No SDK handle was invoked.
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

enum AnnotationOriginalEditorImportInvocationOutcome {
    /// Only the original await returned. Native history remains separate;
    /// this is neither a destination mapping nor an acknowledgement.
    case nativeAwaitReturned(AnnotationLocalEditorNativeAttemptObservation)
    case recordedWithoutOwnership(AnnotationLocalEditorNativeAttemptObservation)
}

/// Even a failure after a successful preparation retains that durable fact.
/// No thrown await is interpreted as rollback or permission to retry.
struct AnnotationOriginalEditorImportFailure: Error {
    enum Stage: Sendable { case sdkPreparation, dispatchTransition, nativeAwait }
    let stage: Stage
    let prepared: AnnotationLocalEditorNativeAttemptObservation
    let dispatch: AnnotationLocalEditorNativeAttemptObservation?
    let underlying: any Error
}

/// Retain this object independently of the editor/presentation/awaiting task.
/// Only an actual local receipt and the SDK's real drained callback can fill it.
/// There is no decoder, public initializer, mapping writer or ACK constructor.
@MainActor
final class AnnotationOriginalEditorImportHistory {
    let preparation: AnnotationLocalEditorNativeAttemptObservation
    private(set) var dispatch: AnnotationLocalEditorNativeAttemptObservation?
    private(set) var native: AnytypeOriginalAnnotationImportHistory?

    fileprivate init(preparation: AnnotationLocalEditorNativeAttemptObservation) {
        self.preparation = preparation
    }

    fileprivate func recordDispatch(_ receipt: AnnotationLocalEditorNativeAttemptObservation) {
        dispatch = receipt
    }

    fileprivate func recordNative(_ receipt: AnytypeOriginalAnnotationImportHistory) {
        // The concrete original native owner delivers once, after both drains.
        guard native == nil else { return }
        native = receipt
    }
}

/// Joins one original saved-row preparation to one closed original account/Space
/// import. The durable possible-dispatch transition precedes every native call.
/// Nothing in history can recreate this owner or replace its exact SDK handle.
@MainActor
final class AnnotationOriginalEditorImportAttempt {
    let history: AnnotationOriginalEditorImportHistory
    private let local: AnnotationLocalEditorSession
    private let prepared: AnnotationLocalEditorNativePreparation
    private let observation: AnnotationOriginalEditorSourceObservation
    private let sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    private var native: AnytypeOriginalAnnotationImportAttempt?
    private var invocationStarted = false

    private init(
        local: AnnotationLocalEditorSession,
        prepared: AnnotationLocalEditorNativePreparation,
        observation: AnnotationOriginalEditorSourceObservation,
        sourceLifetime: AnytypeOriginalAnnotationImportSourceLifetime
    ) {
        self.local = local
        self.prepared = prepared
        self.observation = observation
        self.sourceLifetime = sourceLifetime
        history = .init(preparation: prepared.observation)
    }

    static func prepare(
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot,
        observation: AnnotationOriginalEditorSourceObservation,
        account: AnytypeOriginalEditorAccountSession
    ) async throws -> AnnotationOriginalEditorImportPreparationOutcome {
        try observation.bindLocal(local)
        try observation.requireCurrent()
        try account.validateCurrent()
        let comparison = try AnnotationLocalEditorNativeComparison(
            accountID: account.identity.accountID, spaceID: account.identity.spaceID
        )
        let outcome = try await local.prepareNativeAttempt(snapshot: snapshot, comparison: comparison)
        let prepared: AnnotationLocalEditorNativePreparation
        switch outcome {
        case .recordedWithoutOwnership(let receipt):
            observation.retire()
            local.retire()
            return .recordedWithoutOwnership(receipt)
        case .prepared(let actual):
            prepared = actual
        }

        // From here on, every error carries the actual committed preparation.
        var lifetime: AnytypeOriginalAnnotationImportSourceLifetime?
        do {
            guard observation.isCurrent, local.ownsNativePreparation(prepared) else {
                observation.retire()
                local.retire()
                return .recordedWithoutOwnership(prepared.observation)
            }
            try Task.checkCancellation()
            try account.validateCurrent()
            guard let version = prepared.snapshot.version,
                  let nativeSnapshot = try AnnotationOriginalEditorMount.nativeBody(in: prepared.snapshot) else {
                throw AnnotationLocalEditorNativeAttemptError.unsupportedSavedBody
            }
            let receipt = prepared.observation
            let source = try AnytypeOriginalAnnotationImportSource(
                namespace: version.namespace,
                annotationUUID: receipt.annotationUUID,
                preparedSessionID: receipt.preparedSessionID,
                attemptID: receipt.attemptID,
                savedRevision: receipt.savedRevision,
                sourceDigest: receipt.sourceDigest,
                payloadDigest: receipt.payloadDigest,
                bodyDigest: receipt.bodyDigest,
                accountID: prepared.comparison.accountID,
                spaceID: prepared.comparison.spaceID
            )
            let actualLifetime = AnytypeOriginalAnnotationImportSourceLifetime(source: source)
            lifetime = actualLifetime
            // Each link is registered outside all transaction/repository locks.
            // Session, DB, annotation, scene and presentation retirement now all
            // synchronously invalidate this exact SDK token before replacement.
            try local.bindNativeImportRetirement(actualLifetime, prepared: prepared)
            try observation.bindImport(actualLifetime, local: local)
            let owner = AnnotationOriginalEditorImportAttempt(
                local: local, prepared: prepared, observation: observation,
                sourceLifetime: actualLifetime
            )
            let retainedHistory = owner.history
            owner.native = try account.prepareAnnotationImport(
                snapshot: nativeSnapshot, sourceLifetime: actualLifetime,
                sourceIsCurrent: { [weak owner] candidate in
                    owner?.isCurrent(candidate) == true
                },
                onDrained: { [retainedHistory] actual in
                    retainedHistory.recordNative(actual)
                }
            )
            guard owner.isCurrent(source) else {
                owner.retire()
                return .recordedWithoutOwnership(receipt)
            }
            return .prepared(owner)
        } catch {
            lifetime?.retire()
            observation.retire()
            local.retire()
            throw AnnotationOriginalEditorImportFailure(
                stage: .sdkPreparation, prepared: prepared.observation,
                dispatch: nil, underlying: error
            )
        }
    }

    /// This callback is deliberately memory-only: exact private preparation,
    /// original session/DB flags, source observation and exact immutable tuple.
    /// No SQL, file access, account creation or decoded-history adoption occurs.
    private func isCurrent(_ candidate: AnytypeOriginalAnnotationImportSource) -> Bool {
        candidate == sourceLifetime.source && sourceLifetime.isCurrent
            && local.ownsNativePreparation(prepared) && observation.isCurrent
    }

    /// Invoke only after explicit user intent. A second invocation never repeats
    /// either the durable transition or native RPC, even after a thrown await.
    func invoke() async throws -> AnnotationOriginalEditorImportInvocationOutcome {
        guard !invocationStarted else { throw AnnotationLocalEditorError.busy }
        invocationStarted = true
        guard let native, isCurrent(sourceLifetime.source) else {
            retire()
            throw AnnotationLocalEditorError.retired
        }
        let local = self.local, lifetime = sourceLifetime
        return try await withTaskCancellationHandler {
            let transition: AnnotationLocalEditorNativeTransitionOutcome
            do {
                transition = try await local.markNativeAttemptMayHaveDispatched(prepared)
            } catch {
                retire()
                throw AnnotationOriginalEditorImportFailure(
                    stage: .dispatchTransition, prepared: prepared.observation,
                    dispatch: history.dispatch, underlying: error
                )
            }
            switch transition {
            case .recordedWithoutOwnership(let receipt):
                history.recordDispatch(receipt)
                retire()
                return .recordedWithoutOwnership(receipt)
            case .recorded(let receipt):
                history.recordDispatch(receipt)
                // No await separates this check from the exact SDK invocation.
                // The SDK independently checks its synchronously retired token.
                guard !Task.isCancelled, isCurrent(sourceLifetime.source) else {
                    retire()
                    return .recordedWithoutOwnership(receipt)
                }
                do {
                    try await native.invoke()
                    retire()
                    return .nativeAwaitReturned(receipt)
                } catch {
                    retire()
                    throw AnnotationOriginalEditorImportFailure(
                        stage: .nativeAwait, prepared: prepared.observation,
                        dispatch: receipt, underlying: error
                    )
                }
            }
        } onCancel: {
            lifetime.retire()
            local.retire()
        }
    }

    @discardableResult
    func requestCancellation() -> AnytypeOriginalAnnotationImportAttempt.CancellationScheduling? {
        native?.requestCancellation()
    }

    func retire() {
        sourceLifetime.retire()
        observation.retire()
        local.retire()
    }

    isolated deinit {
        sourceLifetime.retire()
        observation.retire()
        local.retire()
    }
}

extension AnnotationStore {
    /// Explicit saved-annotation entry point. The account handle can only come
    /// from the SDK's actual account presentation and selected-Space owner.
    /// Preparation performs local bookkeeping and SDK preparation, never an RPC.
    @MainActor
    func prepareOriginalAnnotationImport(
        annotation: Annotation,
        workspace: StudyWorkspaceNavigationAdapter,
        presentationLifetime: AnnotationLocalEditorLifetime,
        account: AnytypeOriginalEditorAccountSession
    ) async throws -> AnnotationOriginalEditorImportPreparationOutcome {
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: self, workspace: workspace,
            presentationLifetime: presentationLifetime
        )
        var capturedLocal: AnnotationLocalEditorSession?
        do {
            let local = try makeLocalAnnotationEditor(
                annotation: annotation,
                supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
            capturedLocal = local
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            return try await AnnotationOriginalEditorImportAttempt.prepare(
                local: local, snapshot: snapshot, observation: observation, account: account
            )
        } catch {
            observation.retire()
            capturedLocal?.retire()
            throw error
        }
    }
}
#endif
