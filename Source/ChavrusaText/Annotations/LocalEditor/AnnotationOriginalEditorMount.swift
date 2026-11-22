#if DEBUG && os(iOS) && targetEnvironment(simulator) && canImport(AnytypeOriginalEditor)
import Foundation
import UIKit
import AnytypeOriginalEditor

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
    private let host: AnytypeOriginalEditorHost
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
                 host: AnytypeOriginalEditorHost, controller: UIViewController) {
        self.local = local
        self.snapshot = snapshot
        self.source = source
        self.host = host
        binding = host.binding
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
            return .init(local: local, snapshot: snapshot, source: source, host: host, controller: controller)
        } catch {
            openedHost?.retire()
            source.retire()
            local.retire()
            throw error
        }
    }

    /// One concrete save attempt. No automatic recapture/retry can silently
    /// adopt a newer row or pretend an uncertain earlier write was rolled back.
    func save(textPreview: String) async throws -> AnnotationLocalEditorOutcome {
        guard !saveAttempted else { throw AnnotationLocalEditorError.busy }
        saveAttempted = true
        do {
            try source.requireCurrent()
            guard local.isCurrent else { throw AnnotationLocalEditorError.retired }
            viewController.view.isUserInteractionEnabled = false
            viewController.view.endEditing(true)
            // The SDK's actual registered-write/RPC barrier is mandatory here;
            // endEditing itself and optimistic UI text are not a flush receipt.
            let capture = try await host.captureNativeSnapshot(
                maximumBodyBytes: TorahAnnotationEnvelopeCodec.maximumBytes
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
                textPreview: textPreview, editorRevision: capture.snapshot.nativeArchiveSHA256
            )
            // The captured editor cannot keep accepting changes while its body
            // is committed. The local session remains authoritative for its CAS.
            host.retire()
            let outcome = try await local.save(intent)
            // A committedWithoutOwnership receipt is still an actual commit.
            // Never throw cancellation/retirement after receiving that receipt.
            committedOutcome = outcome
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

    func retire() {
        host.retire()
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
            maximumBodyBytes: TorahAnnotationEnvelopeCodec.maximumBytes)
    }

    isolated deinit {
        host.retire()
        source.retire()
        local.retire()
    }
}
#endif
