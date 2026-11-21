#if DEBUG && os(iOS) && targetEnvironment(simulator)
import Foundation
import SwiftUI
import Observation
#if canImport(AnytypeOriginalEditor)
import AnytypeOriginalEditor
#endif

/// This entry is confined to the SDK's explicit, owned simulator qualification.
/// Ordinary annotation editing never requests or creates an Anytype account.
@MainActor
struct AnnotationOriginalEditorQualificationEntry: View {
    static let marker = "owned-local-only"
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"] == marker
    }

    @Environment(\.exact9401Workspace) private var workspace
    let annotation: Annotation
    let draft: @MainActor () -> AnnotationOriginalEditorQualificationDraft
    let closeOriginalSheet: @MainActor () -> Void
    @State private var errorMessage: String?
    #if canImport(AnytypeOriginalEditor)
    @State private var presentation: AnnotationOriginalEditorQualificationPresentation?
    #endif

    private var entryError: String? {
        do {
            try draft().requireSavedBlankUnchanged(annotation)
            guard workspace != nil else { throw AnnotationOriginalEditorQualificationUIError.noWorkspace }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        if Self.isRequested {
            ThemeSection("Original editor qualification") {
                #if canImport(AnytypeOriginalEditor)
                Button("Open original editor") {
                    do {
                        // Recheck the live original controls at the actual tap.
                        try draft().requireSavedBlankUnchanged(annotation)
                        guard let workspace else { throw AnnotationOriginalEditorQualificationUIError.noWorkspace }
                        presentation = .init(annotation: annotation, workspace: workspace)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .accessibilityIdentifier("annotation-original-editor-open")
                .disabled(entryError != nil)
                if let reason = errorMessage ?? entryError {
                    Text(reason)
                        .accessibilityIdentifier("annotation-original-editor-entry-status")
                }
                #else
                Text("Original editor is unavailable in this build.")
                    .accessibilityIdentifier("annotation-original-editor-unavailable")
                #endif
            }
            #if canImport(AnytypeOriginalEditor)
            .fullScreenCover(item: $presentation, onDismiss: {
                // A captured rich body must never return to the stale quick-note
                // Save action. The original sheet is closed without calling it.
                closeOriginalSheet()
            }) { model in
                AnnotationOriginalEditorQualificationView(model: model)
                    .interactiveDismissDisabled(true)
            }
            #endif
        }
    }
}

/// Passive identity on the existing book-annotation row and its original Edit
/// action. Blank notes are correctly absent from the inspector's nonempty-note
/// list; qualification opens them through this existing all-annotations UI.
@MainActor
struct AnnotationOriginalEditorQualificationIdentity: ViewModifier {
    let identifier: String
    var value: String? = nil
    @ViewBuilder func body(content: Content) -> some View {
        if AnnotationOriginalEditorQualificationEntry.isRequested {
            if let value {
                content.accessibilityIdentifier(identifier).accessibilityValue(value)
            } else {
                content.accessibilityIdentifier(identifier)
            }
        } else {
            content
        }
    }
}

/// Exact original controls, including the actual mounted UITextView, are checked
/// before leaving the quick-note editor. Even whitespace-only drafts are edits.
struct AnnotationOriginalEditorQualificationDraft {
    let noteText: String
    let nativeText: String?
    let lastEnteredText: String?
    let nativeEditorIsCurrent: Bool
    let selectedColorHex: String
    let isUnderline: Bool
    let tagsText: String

    func requireSavedBlankUnchanged(_ annotation: Annotation) throws {
        guard let id = annotation.id, id > 0,
              annotation.ckRecordId.flatMap(UUID.init(uuidString:)) != nil else {
            throw AnnotationOriginalEditorQualificationUIError.unsaved
        }
        guard (annotation.note ?? "").isEmpty else {
            throw AnnotationOriginalEditorQualificationUIError.nonempty
        }
        let originalColor = annotation.type == .underline
            && (annotation.colorHex.isEmpty || annotation.colorHex == "#000000")
            ? "#000000" : annotation.colorHex
        guard nativeEditorIsCurrent, let nativeText,
              noteText.isEmpty, nativeText.isEmpty, (lastEnteredText ?? "").isEmpty,
              isUnderline == (annotation.type == .underline),
              selectedColorHex.utf8.elementsEqual(originalColor.utf8),
              tagsText.utf8.elementsEqual(annotation.tags.joined(separator: ", ").utf8) else {
            throw AnnotationOriginalEditorQualificationUIError.pendingChanges
        }
        // Existing rich/unknown bodies are independently rejected by the real
        // saved-row read in AnnotationOriginalEditorQualification.begin.
    }
}

private enum AnnotationOriginalEditorQualificationUIError: LocalizedError {
    case unsaved, nonempty, pendingChanges, noWorkspace, closed, missingReceipt
    var errorDescription: String? {
        switch self {
        case .unsaved: "Save this blank note before opening the original editor."
        case .nonempty: "This qualification requires an already saved blank note."
        case .pendingChanges: "Keep the saved note, style and tags unchanged before opening the original editor."
        case .noWorkspace: "The original reader workspace is unavailable."
        case .closed: "The original editor has been closed."
        case .missingReceipt: "The original save did not provide a current durable receipt."
        }
    }
}

#if canImport(AnytypeOriginalEditor)
@MainActor @Observable
private final class AnnotationOriginalEditorQualificationPresentation: Identifiable {
    let id = UUID()
    let annotation: Annotation
    let workspace: StudyWorkspaceNavigationAdapter
    private let store = AnnotationStore.shared
    private var qualification: AnnotationOriginalEditorQualification?
    private var started = false
    private var closed = false
    private var reportDirectory: URL?
    private(set) var mount: AnnotationOriginalEditorMount?
    private(set) var stage = "preparing"
    private(set) var message = "Opening the original editor…"
    private(set) var reportJSON = "{}"
    private var report: [String: Any] = [:]

    init(annotation: Annotation, workspace: StudyWorkspaceNavigationAdapter) {
        self.annotation = annotation
        self.workspace = workspace
    }

    var canSave: Bool { stage == "editing" && !closed }
    var canReopen: Bool { stage == "saved" && !closed }

    func begin() async {
        guard !started, !closed else { return }
        started = true
        do {
            guard AnnotationOriginalEditorQualificationEntry.isRequested else {
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            let opened = try await AnnotationOriginalEditorQualification.begin(
                annotation: annotation, store: store, workspace: workspace
            )
            guard !closed, !Task.isCancelled else {
                opened.retire()
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            qualification = opened
            mount = opened.firstMount
            let snapshot = opened.firstMount.snapshot
            guard let savedID = snapshot.annotation.id else { throw AnnotationLocalEditorError.missingAnnotation }
            report = [
                "schema": 1, "qualification": AnnotationOriginalEditorQualificationEntry.marker,
                "bundle_id": Bundle.main.bundleIdentifier ?? "",
                "annotation_id": savedID,
                "annotation_uuid": snapshot.annotationUUID.uuidString,
                "profile_id": opened.firstMount.binding.hostProfileID,
                "source_witness_sha256": snapshot.source.digest,
                "initial_revision": snapshot.revision,
                "initial_note_blank": (snapshot.annotation.note ?? "").isEmpty,
                "initial_rich_body_absent": snapshot.document == nil,
                "original_object_id": opened.firstMount.binding.objectID,
                "original_space_id": opened.firstMount.binding.spaceID,
                "preview_derived_from_native_body": false,
                "preview_qualification": "not-derived; original blank quick-note preview preserved"
            ]
            try publish(stage: "editing", message: "Type in the original editor, then capture and save.")
        } catch {
            fail(error)
        }
    }

    func save() async {
        guard canSave, let qualification else { return }
        stage = "saving"
        message = "Capturing the original blocks and saving this note…"
        do {
            // The qualification keeps the original blank preview. It neither
            // parses native blocks nor substitutes preview text for their body.
            let outcome = try await qualification.firstMount.save(textPreview: annotation.note ?? "")
            let receipt: AnnotationExchangeCommit
            let delivery: String
            switch outcome {
            case .committed(let saved):
                receipt = saved.receipt
                delivery = "committed"
                guard saved.snapshot.annotationUUID == qualification.firstMount.snapshot.annotationUUID,
                      saved.snapshot.annotation.id == annotation.id else {
                    throw AnnotationLocalEditorError.wrongOwner
                }
            case .completedWithoutOwnership(let committed):
                receipt = committed
                delivery = "completedWithoutOwnership"
            }
            // Record a real commit even if the presenting UI was retired while
            // its already-admitted original transaction completed.
            report["commit_delivery"] = delivery
            report["commit_revision"] = receipt.revision
            report["payload_digest"] = receipt.payloadDigest
            report["commit_replayed"] = receipt.replayed
            guard let capture = qualification.firstMount.retainedCapture else {
                throw AnnotationOriginalEditorQualificationUIError.missingReceipt
            }
            report["native_archive_sha256"] = capture.snapshot.nativeArchiveSHA256
            report["native_body_bytes"] = capture.snapshot.bodyBytes.count
            report["native_exported_object_count"] = capture.snapshot.exportedObjectCount
            report["retained_capture_directory"] = capture.retainedDirectoryURL.path
            // An own commit invalidation can retire the first local owner.
            // Either receipt is durable; explicit reopen obtains a NEW source
            // and saved-row session rather than reviving this retired Host.
            let deliverable = !closed
            try publish(stage: deliverable ? "saved" : "committed-without-current-view",
                        message: deliverable ? "The original body was saved. Reopen it through the current saved note to verify the blocks."
                            : "The body was saved. This editor no longer owns the source; close this sheet.")
        } catch {
            fail(error)
        }
    }

    func reopen() async {
        guard canReopen, let qualification, let id = annotation.id else { return }
        stage = "reopening"
        message = "Importing the saved body into the original editor…"
        do {
            // The original CAS clears its cache. Its original lookup supplies
            // the current row; reopen then re-reads and verifies the durable
            // revision, payload digest and exact opaque native bytes itself.
            guard let current = store.loadAnnotationById(id) else {
                throw AnnotationLocalEditorError.missingAnnotation
            }
            let reopened = try await qualification.reopen(annotation: current, workspace: workspace)
            guard !closed, !Task.isCancelled else {
                reopened.retire()
                throw AnnotationOriginalEditorQualificationUIError.closed
            }
            mount = reopened
            guard let savedID = reopened.snapshot.annotation.id,
                  let payloadDigest = reopened.snapshot.version?.payloadDigest else {
                throw AnnotationOriginalEditorQualificationUIError.missingReceipt
            }
            report["reopened_annotation_id"] = savedID
            report["reopened_annotation_uuid"] = reopened.snapshot.annotationUUID.uuidString
            report["reopened_revision"] = reopened.snapshot.revision
            report["reopened_payload_digest"] = payloadDigest
            report["reopened_object_id"] = reopened.binding.objectID
            report["reopened_space_id"] = reopened.binding.spaceID
            report["reopened_source_witness_sha256"] = reopened.snapshot.source.digest
            report["durable_body_verified_by_original_reopen"] = true
            try publish(stage: "reopened", message: "The original editor has reopened the saved blocks.")
        } catch {
            fail(error)
        }
    }

    func retire() {
        closed = true
        qualification?.retire()
    }

    private func publish(stage: String, message: String) throws {
        self.stage = stage
        self.message = message
        report["stage"] = stage
        let bytes = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .withoutEscapingSlashes])
        guard bytes.count <= 32_768, let json = String(data: bytes, encoding: .utf8) else {
            throw AnnotationLocalEditorError.invalidIntent
        }
        if reportDirectory == nil {
            let documents = try FileManager.default.url(for: .documentDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
            let root = documents.appendingPathComponent("original-editor-qualification", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let owned = root.appendingPathComponent(id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: false)
            reportDirectory = owned
        }
        if let reportDirectory {
            try bytes.write(to: reportDirectory.appendingPathComponent(stage + ".json"), options: .atomic)
        }
        reportJSON = json
    }

    private func fail(_ error: any Error) {
        qualification?.retire()
        mount = nil
        report["failure_type"] = String(reflecting: type(of: error))
        report["failure"] = String(String(describing: error).prefix(1_024))
        if let directory = qualification?.firstMount.retainedFailureDirectory {
            report["retained_failure_directory"] = directory.path
        }
        do {
            try publish(stage: "failed", message: "Original editor qualification failed. Any captured evidence is retained.")
        } catch {
            stage = "failed"
            message = "Original editor qualification failed; its evidence report could not be written."
        }
    }

    isolated deinit { qualification?.retire() }
}

@MainActor
private struct AnnotationOriginalEditorQualificationView: View {
    @Environment(\.dismiss) private var dismiss
    let model: AnnotationOriginalEditorQualificationPresentation

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text(model.message)
                    .accessibilityIdentifier("annotation-original-editor-status")
                    .accessibilityValue(model.stage)
                if let mount = model.mount {
                    AnnotationOriginalEditorController(controller: mount.viewController)
                        .id(ObjectIdentifier(mount.viewController))
                        .accessibilityIdentifier("annotation-original-editor-host")
                        .accessibilityElement(children: .contain)
                } else if model.stage == "preparing" {
                    ProgressView()
                }
                Text("Qualification receipt")
                    .font(.caption)
                    .accessibilityIdentifier("annotation-original-editor-receipt")
                    .accessibilityValue(model.reportJSON)
                if model.canSave {
                    Button("Capture and save original blocks") { Task { await model.save() } }
                        .accessibilityIdentifier("annotation-original-editor-save")
                }
                if model.canReopen {
                    Button("Reopen saved original blocks") { Task { await model.reopen() } }
                        .accessibilityIdentifier("annotation-original-editor-reopen")
                }
            }
            .padding(.bottom, 8)
            .navigationTitle("Original editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        model.retire()
                        dismiss()
                    }
                    .accessibilityIdentifier("annotation-original-editor-close")
                }
            }
        }
        .task { await model.begin() }
    }
}

/// The supplied controller is the retained original SDK Host. No Maktabah text
/// editor, block renderer, body parser or editor service graph is created here.
@MainActor
private struct AnnotationOriginalEditorController: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
#endif
