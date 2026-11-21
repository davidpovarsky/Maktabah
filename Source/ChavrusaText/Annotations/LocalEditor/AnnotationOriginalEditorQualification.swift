#if DEBUG && os(iOS) && targetEnvironment(simulator) && canImport(AnytypeOriginalEditor)
import Foundation
@_spi(OriginalEditorQualification) import AnytypeOriginalEditor

/// Native acceptance uses the actual Maktabah row and original Anytype runtime.
/// The SDK's SPI admits only an owned fresh simulator environment. The adapter
/// cannot select arbitrary native account, Space or object IDs.
@MainActor
final class AnnotationOriginalEditorQualification {
    let firstMount: AnnotationOriginalEditorMount
    private(set) var reopenedMount: AnnotationOriginalEditorMount?
    private let original: AnytypeOriginalEditorQualificationSession
    private let store: AnnotationStore
    private let annotationUUID: UUID
    private let profileID: UUID
    private var reopenAttempted = false

    private init(original: AnytypeOriginalEditorQualificationSession,
                 firstMount: AnnotationOriginalEditorMount, store: AnnotationStore,
                 profileID: UUID) {
        self.original = original
        self.firstMount = firstMount
        self.store = store
        annotationUUID = firstMount.snapshot.annotationUUID
        self.profileID = profileID
    }

    static func begin(annotation: Annotation, store: AnnotationStore,
                      workspace: StudyWorkspaceNavigationAdapter) async throws -> AnnotationOriginalEditorQualification {
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: store, workspace: workspace
        )
        let local: AnnotationLocalEditorSession
        do {
            local = try store.makeLocalAnnotationEditor(
                annotation: annotation, supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
        } catch {
            observation.retire()
            throw error
        }
        do {
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            try observation.requireCurrent()
            guard snapshot.annotationUUID == observation.annotationUUID,
                  snapshot.annotation.id == observation.annotationID,
                  snapshot.document == nil,
                  (snapshot.annotation.note ?? "").isEmpty else {
                // Stage B starts from a genuinely saved blank note. Existing
                // text, rich bodies and unknown formats remain untouched.
                throw AnnotationLocalEditorError.unsupportedBody
            }
            let source = try descriptor(snapshot, profileID: observation.profileID)
            let original = try await AnytypeOriginalEditorModule.beginEditableAcceptance(source: source) {
                [observation, local] current in
                current == source && observation.isCurrent && local.isCurrent
            }
            try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
            try observation.requireCurrent()
            let mount = try await AnnotationOriginalEditorMount.open(
                local: local, snapshot: snapshot, source: observation, binding: original.binding
            )
            return .init(original: original, firstMount: mount, store: store, profileID: observation.profileID)
        } catch {
            observation.retire()
            local.retire()
            throw error
        }
    }

    /// Re-read the actual committed body, prove its bytes and durable receipt,
    /// then ask the original engine to import it into its one owned restore Space.
    /// Historical capture revision/source are never substituted for this row.
    func reopen(annotation: Annotation, workspace: StudyWorkspaceNavigationAdapter) async throws -> AnnotationOriginalEditorMount {
        guard !reopenAttempted,
              let capture = firstMount.retainedCapture,
              let outcome = firstMount.committedOutcome else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        let receipt: AnnotationExchangeCommit
        switch outcome {
        case .committed(let saved): receipt = saved.receipt
        case .completedWithoutOwnership(let committed): receipt = committed
        }
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: store, workspace: workspace
        )
        guard observation.annotationUUID == annotationUUID, observation.profileID == profileID else {
            observation.retire()
            throw AnnotationLocalEditorError.wrongOwner
        }
        let local: AnnotationLocalEditorSession
        do {
            local = try store.makeLocalAnnotationEditor(
                annotation: annotation, supportedFormats: AnnotationOriginalEditorMount.supportedFormats
            )
        } catch {
            observation.retire()
            throw error
        }
        do {
            try observation.bindLocal(local)
            let snapshot = try await local.read()
            try observation.requireCurrent()
            guard snapshot.annotationUUID == annotationUUID,
                  snapshot.revision == receipt.revision,
                  snapshot.version?.payloadDigest == receipt.payloadDigest,
                  let native = try AnnotationOriginalEditorMount.nativeBody(in: snapshot),
                  native.bodyBytes == capture.snapshot.bodyBytes else {
                throw AnnotationLocalEditorError.staleBody
            }
            let currentSource = try Self.descriptor(snapshot, profileID: profileID)
            // The SDK's restore capability is single-use even if native import
            // fails or the source changes after it has started.
            reopenAttempted = true
            let binding = try await original.prepareReopen(snapshot: native, currentSource: currentSource) {
                [observation, local] candidate in
                candidate == currentSource && observation.isCurrent && local.isCurrent
            }
            try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
            try observation.requireCurrent()
            let mount = try await AnnotationOriginalEditorMount.open(
                local: local, snapshot: snapshot, source: observation, binding: binding
            )
            reopenedMount = mount
            return mount
        } catch {
            observation.retire()
            local.retire()
            throw error
        }
    }

    func retire() {
        firstMount.retire()
        reopenedMount?.retire()
    }

    private static func descriptor(_ snapshot: AnnotationLocalEditorSnapshot,
                                   profileID: UUID) throws -> AnytypeOriginalEditorQualificationSource {
        try .init(hostProfileID: profileID.uuidString, annotationUUID: snapshot.annotationUUID,
                  expectedRevision: snapshot.revision, sourceWitnessSHA256: snapshot.source.digest)
    }

    isolated deinit {
        firstMount.retire()
        reopenedMount?.retire()
    }
}
#endif
