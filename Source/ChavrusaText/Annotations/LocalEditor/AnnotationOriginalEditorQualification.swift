#if DEBUG && os(iOS) && targetEnvironment(simulator) && canImport(AnytypeOriginalEditor)
import Foundation
import CryptoKit
@_spi(OriginalEditorQualification) import AnytypeOriginalEditor

/// Native acceptance uses the actual Maktabah row and original Anytype runtime.
/// The SDK's SPI admits only an owned simulator lifecycle. The adapter
/// cannot select arbitrary native account, Space or object IDs.
@MainActor
final class AnnotationOriginalEditorQualification {
    let firstMount: AnnotationOriginalEditorMount
    private(set) var reopenedMount: AnnotationOriginalEditorMount?
    private let original: AnytypeOriginalEditorQualificationSession
    private let store: AnnotationStore
    private let annotationUUID: UUID
    private let profileID: UUID
    private let presentationLifetime: AnnotationLocalEditorLifetime
    private var reopenAttempted = false
    private var processResumeAttempted = false
    private(set) var processResumeWorkspaceNamespace: UUID?
    private(set) var processResumeSavedBodySHA256: String?
    private(set) var processResumeArchiveSHA256: String?
    var processResumeReceipt: AnytypeOriginalEditorProcessResumeReceipt? { original.processResumeReceipt }

    private init(original: AnytypeOriginalEditorQualificationSession,
                 firstMount: AnnotationOriginalEditorMount, store: AnnotationStore,
                 profileID: UUID, presentationLifetime: AnnotationLocalEditorLifetime) {
        self.original = original
        self.firstMount = firstMount
        self.store = store
        annotationUUID = firstMount.snapshot.annotationUUID
        self.profileID = profileID
        self.presentationLifetime = presentationLifetime
    }

    static func begin(annotation: Annotation, store: AnnotationStore,
                      workspace: StudyWorkspaceNavigationAdapter,
                      presentationLifetime: AnnotationLocalEditorLifetime) async throws -> AnnotationOriginalEditorQualification {
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: store, workspace: workspace,
            presentationLifetime: presentationLifetime
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
            return .init(original: original, firstMount: mount, store: store,
                         profileID: observation.profileID, presentationLifetime: presentationLifetime)
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
            annotation: annotation, store: store, workspace: workspace,
            presentationLifetime: presentationLifetime
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


    static func resume(annotation: Annotation, store: AnnotationStore,
                       workspace: StudyWorkspaceNavigationAdapter,
                       presentationLifetime: AnnotationLocalEditorLifetime) async throws -> AnnotationOriginalEditorQualification {
        guard ProcessInfo.processInfo.environment["OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] == "resume-owned-once" else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        let observation = try AnnotationOriginalEditorSourceObservation(
            annotation: annotation, store: store, workspace: workspace,
            presentationLifetime: presentationLifetime
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
                  snapshot.revision > 0,
                  (snapshot.annotation.note ?? "").isEmpty,
                  let native = try AnnotationOriginalEditorMount.nativeBody(in: snapshot) else {
                throw AnnotationLocalEditorError.unsupportedBody
            }
            let source = try descriptor(snapshot, profileID: observation.profileID)
            let context = try processResumeContext(snapshot)
            let original = try await AnytypeOriginalEditorModule.resumeEditableAcceptance(
                source: source, snapshot: native, context: context
            ) { [observation, local] current in
                current == source && observation.isCurrent && local.isCurrent
            }
            try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await local.read())
            try observation.requireCurrent()
            let mount = try await AnnotationOriginalEditorMount.open(
                local: local, snapshot: snapshot, source: observation, binding: original.binding
            )
            let qualification = AnnotationOriginalEditorQualification(
                original: original, firstMount: mount, store: store,
                profileID: observation.profileID, presentationLifetime: presentationLifetime
            )
            qualification.processResumeWorkspaceNamespace = context.workspaceNamespace
            qualification.processResumeSavedBodySHA256 = SHA256.hash(data: native.bodyBytes)
                .map { String(format: "%02x", $0) }.joined()
            qualification.processResumeArchiveSHA256 = native.nativeArchiveSHA256
            return qualification
        } catch {
            observation.retire()
            local.retire()
            throw error
        }
    }

    func prepareProcessResume() async throws -> AnytypeOriginalEditorProcessResumeReceipt {
        guard ProcessInfo.processInfo.environment["OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] == "prepare-owned-once",
              !processResumeAttempted, let reopenedMount else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        processResumeAttempted = true
        let snapshot = try await reopenedMount.readCurrentSnapshot()
        guard snapshot.annotationUUID == annotationUUID,
              reopenedMount.binding.hostProfileID.utf8.elementsEqual(profileID.uuidString.utf8),
              let native = try AnnotationOriginalEditorMount.nativeBody(in: snapshot) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        let source = try Self.descriptor(snapshot, profileID: profileID)
        let context = try Self.processResumeContext(snapshot)
        let receipt = try await reopenedMount.prepareProcessResume(
            session: original, snapshot: native, currentSource: source, context: context
        )
        try AnnotationOriginalEditorMount.assertUnchanged(snapshot, try await reopenedMount.readCurrentSnapshot())
        processResumeWorkspaceNamespace = context.workspaceNamespace
        processResumeSavedBodySHA256 = SHA256.hash(data: native.bodyBytes)
            .map { String(format: "%02x", $0) }.joined()
        processResumeArchiveSHA256 = native.nativeArchiveSHA256
        return receipt
    }

    private static func processResumeContext(
        _ snapshot: AnnotationLocalEditorSnapshot
    ) throws -> AnytypeOriginalEditorProcessResumeContext {
        let arguments = ProcessInfo.processInfo.arguments
        let indexes = arguments.indices.filter { arguments[$0] == "-studyWorkspaceTestingNamespace" }
        guard indexes.count == 1, let index = indexes.first, arguments.indices.contains(index + 1),
              let namespace = UUID(uuidString: arguments[index + 1]),
              namespace.uuidString == arguments[index + 1],
              UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace") == namespace.uuidString,
              let annotationID = snapshot.annotation.id, annotationID > 0,
              let payloadDigest = snapshot.version?.payloadDigest else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        return try .init(workspaceNamespace: namespace, legacyAnnotationID: annotationID,
                         payloadDigest: payloadDigest)
    }

    func retire() {
        presentationLifetime.retire()
        firstMount.retire()
        reopenedMount?.retire()
    }

    private static func descriptor(_ snapshot: AnnotationLocalEditorSnapshot,
                                   profileID: UUID) throws -> AnytypeOriginalEditorQualificationSource {
        try .init(hostProfileID: profileID.uuidString, annotationUUID: snapshot.annotationUUID,
                  expectedRevision: snapshot.revision, sourceWitnessSHA256: snapshot.source.digest)
    }

    isolated deinit {
        presentationLifetime.retire()
        firstMount.retire()
        reopenedMount?.retire()
    }
}
#endif
