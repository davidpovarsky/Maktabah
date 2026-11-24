#if os(iOS) && canImport(AnytypeOriginalEditor)
import Foundation
import UIKit
#if DEBUG && targetEnvironment(simulator)
@_spi(OriginalEditorQualification) import AnytypeOriginalEditor
#else
import AnytypeOriginalEditor
#endif

/// A thin consumer of the original SDK and original annotation persistence.
/// The SDK owns native editing/export. AnnotationLocalEditorSession owns the
/// saved UUID, complete-envelope limit, transaction, revision CAS and sync queue.
@MainActor
final class AnnotationOriginalEditorMount {
    let snapshot: AnnotationLocalEditorSnapshot
    let viewController: UIViewController
    let binding: AnytypeOriginalEditorBinding
    private let local: AnnotationLocalEditorSession
    private let source: AnnotationOriginalEditorSourceObservation
    private let nativeOwner: NativeOwner
    private var saveAttempted = false
    private(set) var retainedCapture: AnytypeOriginalEditorSnapshotCapture?
    private(set) var retainedFailureDirectory: URL?
    private(set) var committedOutcome: AnnotationLocalEditorOutcome?

    static var supportedFormats: Set<AnnotationLocalEditorBodyFormat> {
        get throws {
            [try AnnotationLocalEditorBodyFormat(identifier: AnytypeOriginalEditorSnapshot.format,
                                                version: AnytypeOriginalEditorSnapshot.formatVersion)]
        }
    }

    private init(local: AnnotationLocalEditorSession, snapshot: AnnotationLocalEditorSnapshot,
                 source: AnnotationOriginalEditorSourceObservation,
                 nativeOwner: NativeOwner, controller: UIViewController) {
        self.local = local
        self.snapshot = snapshot
        self.source = source
        self.nativeOwner = nativeOwner
        binding = nativeOwner.binding
        viewController = controller
    }

    static func open(local: AnnotationLocalEditorSession, snapshot: AnnotationLocalEditorSnapshot,
                     source: AnnotationOriginalEditorSourceObservation,
                     binding: AnytypeOriginalEditorBinding) async throws -> AnnotationOriginalEditorMount {
        var openedHost: AnytypeOriginalEditorHost?
        do {
            try source.bindLocal(local)
            try source.requireCurrent()
            guard local.isCurrent,
                  binding.annotationUUID == snapshot.annotationUUID,
                  binding.annotationUUID == source.annotationUUID,
                  binding.hostProfileID.utf8.elementsEqual(source.profileID.uuidString.utf8),
                  binding.expectedRevision == snapshot.revision,
                  binding.sourceWitnessSHA256 == snapshot.source.digest else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try assertUnchanged(snapshot, try await local.read())
            try source.requireCurrent()
            let lifetime = AnytypeOriginalEditorSourceLifetime(binding: binding)
            try source.bind(lifetime)
            let host = try await AnytypeOriginalEditorModule.openExistingEditor(
                binding: binding, sourceLifetime: lifetime
            ) { [source, local] candidate in
                candidate == binding && source.isCurrent && local.isCurrent
            }
            openedHost = host
            // Target resolution and ObjectOpen can both suspend. Read the same
            // original saved row again before this controller becomes visible.
            try assertUnchanged(snapshot, try await local.read())
            try source.requireCurrent()
            let controller = try host.makeViewController()
            return .init(local: local, snapshot: snapshot, source: source, nativeOwner: .existing(host), controller: controller)
        } catch {
            openedHost?.retire()
            source.retire()
            local.retire()
            throw error
        }
    }

    /// Ordinary annotation editing owns a private local-only native draft.
    /// Canonical body bytes are always read from the original saved SQLite row.
    static func openLocalAnnotation(
        local: AnnotationLocalEditorSession,
        snapshot: AnnotationLocalEditorSnapshot,
        source: AnnotationOriginalEditorSourceObservation,
        appGroup: String
    ) async throws -> AnnotationOriginalEditorMount {
        var opened: AnytypeOriginalEditorLocalAnnotationSession?
        var nativeLifetime: AnytypeOriginalEditorLocalAnnotationSourceLifetime?
        do {
            try source.bindLocal(local)
            try source.requireCurrent()
            guard local.isCurrent,
                  snapshot.annotationUUID == source.annotationUUID,
                  snapshot.annotation.id == source.annotationID else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try assertUnchanged(snapshot, try await local.read())
            try source.requireCurrent()
            let descriptor = try AnytypeOriginalEditorLocalAnnotationSource(
                hostProfileID: source.profileID.uuidString,
                annotationUUID: snapshot.annotationUUID,
                expectedRevision: snapshot.revision,
                sourceWitnessSHA256: snapshot.source.digest,
                payloadSHA256: snapshot.version?.payloadDigest
            )
            let body: AnytypeOriginalEditorLocalAnnotationBody
            if let original = try nativeBody(in: snapshot) {
                body = .nativeSnapshot(original)
            } else {
                body = .plainText(snapshot.annotation.note ?? "")
            }
            let lifetime = AnytypeOriginalEditorLocalAnnotationSourceLifetime(source: descriptor)
            nativeLifetime = lifetime
            try source.bindLocalAnnotation(lifetime, local: local, snapshot: snapshot)
            let session = try await AnytypeOriginalEditorModule.openLocalAnnotation(
                appGroup: appGroup, sourceLifetime: lifetime, body: body
            ) { [source, local] candidate in
                candidate == descriptor && source.isCurrent && local.isCurrent
            }
            opened = session
            // The original private runtime can suspend during auth/create/import.
            // Never present its controller over a changed canonical saved row.
            try assertUnchanged(snapshot, try await local.read())
            try source.requireCurrent()
            let binding = session.binding
            guard binding.annotationUUID == snapshot.annotationUUID,
                  binding.hostProfileID.utf8.elementsEqual(source.profileID.uuidString.utf8),
                  binding.expectedRevision == snapshot.revision,
                  binding.sourceWitnessSHA256 == snapshot.source.digest else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            return .init(local: local, snapshot: snapshot, source: source,
                         nativeOwner: .local(session), controller: try session.makeViewController())
        } catch {
            opened?.retire()
            nativeLifetime?.retire()
            source.retire()
            local.retire()
            throw error
        }
    }

    /// One concrete save attempt. No automatic recapture/retry can silently
    /// adopt a newer row or pretend an uncertain earlier write was rolled back.
    func save(textPreview: String? = nil) async throws -> AnnotationLocalEditorOutcome {
        guard !saveAttempted else { throw AnnotationLocalEditorError.busy }
        saveAttempted = true
        do {
            try source.requireCurrent()
            guard local.isCurrent else { throw AnnotationLocalEditorError.retired }
            viewController.view.isUserInteractionEnabled = false
            viewController.view.endEditing(true)
            // The SDK's actual registered-write/RPC barrier is mandatory here;
            // endEditing itself and optimistic UI text are not a flush receipt.
            let (capture, originalPreview) = try await nativeOwner.capture(
                maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes,
                qualificationPreview: textPreview
            )
            // Preserve the original archive before any later source/CAS check.
            retainedCapture = capture
            guard capture.snapshot.provenance.matchesCaptureBinding(binding) else {
                throw AnnotationLocalEditorError.wrongOwner
            }
            try source.requireCurrent()
            try Self.assertUnchanged(snapshot, try await local.read())
            try source.requireCurrent()
            let body = TorahAnnotationEnvelope.RichBody(
                format: AnytypeOriginalEditorSnapshot.format,
                formatVersion: AnytypeOriginalEditorSnapshot.formatVersion,
                bytes: capture.snapshot.bodyBytes
            )
            let intent = try local.prepareSave(
                snapshot: snapshot, mutationID: UUID(), body: body,
                textPreview: originalPreview, editorRevision: capture.snapshot.nativeArchiveSHA256
            )
            // The local SDK capture has already terminally retired its native
            // editor. Keep its source token alive through the canonical CAS.
            // The existing qualification host retains its original retirement.
            if case .existing(let host) = nativeOwner { host.retire() }
            let outcome = try await local.save(intent)
            // A committedWithoutOwnership receipt is still an actual commit.
            // Never throw cancellation/retirement after receiving that receipt.
            committedOutcome = outcome
            nativeOwner.retire()
            source.retire()
            local.retire()
            return outcome
        } catch {
            if let captureFailure = error as? AnytypeOriginalEditorSnapshotCaptureFailure {
                retainedFailureDirectory = captureFailure.retainedDirectoryURL
            }
            retire()
            throw error
        }
    }


    func readCurrentSnapshot() async throws -> AnnotationLocalEditorSnapshot {
        try source.requireCurrent()
        guard local.isCurrent else { throw AnnotationLocalEditorError.retired }
        let actual = try await local.read()
        try source.requireCurrent()
        try Self.assertUnchanged(snapshot, actual)
        return actual
    }


    #if DEBUG && targetEnvironment(simulator)
    func prepareProcessResume(
        session: AnytypeOriginalEditorQualificationSession,
        snapshot native: AnytypeOriginalEditorSnapshot,
        currentSource: AnytypeOriginalEditorQualificationSource,
        context: AnytypeOriginalEditorProcessResumeContext
    ) async throws -> AnytypeOriginalEditorProcessResumeReceipt {
        try source.requireCurrent()
        guard local.isCurrent else { throw AnnotationLocalEditorError.retired }
        guard case .existing(let host) = nativeOwner else { throw AnnotationLocalEditorError.wrongOwner }
        return try await session.prepareProcessResume(
            host: host, snapshot: native, currentSource: currentSource, context: context
        ) { [source, local] candidate in
            candidate == currentSource && source.isCurrent && local.isCurrent
        }
    }
    #endif


    func retire() {
        nativeOwner.retire()
        source.retire()
        local.retire()
    }

    static func assertUnchanged(_ expected: AnnotationLocalEditorSnapshot,
                                _ actual: AnnotationLocalEditorSnapshot) throws {
        guard actual.sessionID == expected.sessionID,
              actual.annotationUUID == expected.annotationUUID,
              actual.annotation.id == expected.annotation.id,
              actual.databaseURL.absoluteString.utf8.elementsEqual(expected.databaseURL.absoluteString.utf8) else {
            throw AnnotationLocalEditorError.wrongOwner
        }
        guard actual.source == expected.source else { throw AnnotationExchangeError.staleSource }
        guard actual.revision == expected.revision, actual.version == expected.version else {
            throw AnnotationExchangeError.staleRevision
        }
    }

    static func nativeBody(in snapshot: AnnotationLocalEditorSnapshot) throws -> AnytypeOriginalEditorSnapshot? {
        guard let document = snapshot.document else { return nil }
        guard case .supported(let envelope, _) = document,
              envelope.annotationUUID == snapshot.annotationUUID,
              envelope.deletionState == .active,
              envelope.source == snapshot.source.metadata,
              snapshot.version?.sourceDigest == snapshot.source.digest,
              snapshot.version?.destinationsJSON == "[]" else {
            throw AnnotationLocalEditorError.unsupportedEnvelope
        }
        guard let body = envelope.richBody else { return nil }
        guard body.format == AnytypeOriginalEditorSnapshot.format,
              body.formatVersion == AnytypeOriginalEditorSnapshot.formatVersion else {
            throw AnnotationLocalEditorError.unsupportedBody
        }
        return try AnytypeOriginalEditorSnapshot(bodyBytes: body.bytes,
            maximumBodyBytes: TorahAnnotationPayloadLimits.maximumBodyBytes)
    }

    @MainActor
    private enum NativeOwner {
        case existing(AnytypeOriginalEditorHost)
        case local(AnytypeOriginalEditorLocalAnnotationSession)

        var binding: AnytypeOriginalEditorBinding {
            switch self {
            case .existing(let host): host.binding
            case .local(let session): session.binding
            }
        }

        func capture(maximumBodyBytes: Int, qualificationPreview: String?) async throws
            -> (AnytypeOriginalEditorSnapshotCapture, String) {
            switch self {
            case .existing(let host):
                guard let qualificationPreview else { throw AnnotationLocalEditorError.invalidPreview }
                return (try await host.captureNativeSnapshot(maximumBodyBytes: maximumBodyBytes),
                        qualificationPreview)
            case .local(let session):
                guard qualificationPreview == nil else { throw AnnotationLocalEditorError.invalidPreview }
                let captured = try await session.captureNativeSnapshot(maximumBodyBytes: maximumBodyBytes)
                return (captured.nativeCapture, captured.textPreview)
            }
        }

        func retire() {
            switch self {
            case .existing(let host): host.retire()
            case .local(let session): session.retire()
            }
        }
    }

    isolated deinit {
        nativeOwner.retire()
        source.retire()
        local.retire()
    }
}
#endif
