#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import HanlinMiniAppsBridge
import HanlinMiniAppsPicker
#if canImport(AnytypeOriginalEditor)
import AnytypeOriginalEditor
#endif

/// The only MiniApps integration owner in this app. Execution remains in Hanlin MiniApps.
@MainActor
final class OtzariaMiniAppsCoordinator {
    static let shared = OtzariaMiniAppsCoordinator()
    static let sourceAppID = "com.davidpovarsky.chavrusatext"

    private struct SceneOwner {
        weak var manager: iOSNavigationManager?
        weak var scene: UIWindowScene?
        weak var workspace: StudyWorkspaceNavigationAdapter?
    }
    private struct EditorOwner {
        let currentText: () -> String?
        let didCommit: (Annotation) -> Void
    }
    static let originalEditorMetadataKey = "otzaria.original-editor.miniapps.v1"
    #if canImport(AnytypeOriginalEditor)
    private struct OriginalEditorOwner {
        weak var model: AnnotationOriginalEditorProductionPresentation?
    }
    private var originalEditors: [UUID: OriginalEditorOwner] = [:]

    func registerOriginalEditor(_ model: AnnotationOriginalEditorProductionPresentation) {
        originalEditors[model.id] = .init(model: model)
    }
    func unregisterOriginalEditor(id: UUID) { originalEditors.removeValue(forKey: id) }
    #endif

    private var scenes: [String: SceneOwner] = [:]
    private var editors: [UUID: EditorOwner] = [:]
    private var processing = Set<UUID>()
    private var reportedFailures = Set<UUID>()
    private struct QueuedPresentation {
        let requestID: UUID
        let show: (@escaping () -> Void) -> Bool
    }
    private var presentationQueues: [String: [QueuedPresentation]] = [:]
    private var presentingScenes = Set<String>()
    private var queuedResults = Set<UUID>()

    static var callbackURL: URL {
        #if DEBUG
        URL(string: "maktabah-debug://miniapps-result")!
        #else
        URL(string: "maktabah://miniapps-result")!
        #endif
    }

    func registerEditor(id: UUID, currentText: @escaping () -> String?,
                        didCommit: @escaping (Annotation) -> Void) {
        editors[id] = .init(currentText: currentText, didCommit: didCommit)
    }

    func unregisterEditor(id: UUID) { editors.removeValue(forKey: id) }

    func attach(manager: iOSNavigationManager, scene: UIWindowScene,
                workspace: StudyWorkspaceNavigationAdapter?) {
        scenes[scene.session.persistentIdentifier] = .init(manager: manager, scene: scene, workspace: workspace)
        resume(manager: manager)
    }

    /// Foreground recovery also delivers a result after cold launch or an interrupted callback.
    func resume(manager: iOSNavigationManager) {
        // A cold URL may arrive before a scene's root presenter is in its window.
        // Keep its saved-note/result UI queued until scene attachment or activation.
        for key in Array(presentationQueues.keys) { drainPresentations(key: key) }
        guard let store = try? MiniAppBridgeStore(),
              let results = try? store.pendingResults(sourceAppID: Self.sourceAppID) else { return }
        for result in results where !reportedFailures.contains(result.requestID) {
            consume(result, store: store, fallbackManager: manager)
        }
    }

    @discardableResult
    func receive(_ url: URL, manager: iOSNavigationManager) -> Bool {
        guard url.scheme == Self.callbackURL.scheme, url.host == Self.callbackURL.host else { return false }
        guard let id = MiniAppBridgeStore.requestID(from: url) else { return true }
        do {
            let store = try MiniAppBridgeStore()
            // A repeated URL for an already acknowledged edit must be a no-op.
            guard let result = try store.pendingResults(sourceAppID: Self.sourceAppID)
                .first(where: { $0.requestID == id }) else { return true }
            reportedFailures.remove(id)
            consume(result, store: store, fallbackManager: manager)
        } catch { show(error: error, sourceView: nil) }
        return true
    }

    func showReader(sourceText: String, range: NSRange, reader: ReaderViewModel, textView: UITextView) {
        do {
            guard sourceText == reader.contentText, textView.window != nil,
                  let swiftRange = Range(range, in: sourceText) else { throw MiniAppBridgeError.invalidSelection }
            let selectedText = String(sourceText[swiftRange])
            let draft = try reader.makeAnnotationDraft(in: range, mode: .highlight,
                sourceText: sourceText, color: UserDefaults.standard.recentHighlightColors.first ?? .yellow)
            let document = try OtzariaMiniAppsDocument(annotation: draft, draft: "", selection: nil,
                isReaderSelection: true, editorID: nil, title: reader.currentBook?.book ?? "")
            let selection = MiniAppTextSelection(location: range.location, length: range.length, text: selectedText)
            present(document: document, inputText: selectedText, sourceText: sourceText,
                sourceSelection: selection, sourceView: textView)
        } catch { show(error: error, sourceView: textView) }
    }

    func showEditor(annotation: Annotation, draft: String, selection: NSRange?,
                    editorID: UUID, textView: UITextView?) {
        do {
            let document = try OtzariaMiniAppsDocument(annotation: annotation, draft: draft,
                selection: selection, isReaderSelection: false, editorID: editorID,
                title: annotation.resolvedBookTitle)
            let input = document.selection.flatMap { $0.length > 0 ? $0.text : nil } ?? ""
            present(document: document, inputText: input, sourceText: draft,
                sourceSelection: document.selection, sourceView: textView)
        } catch { show(error: error, sourceView: textView) }
    }

    #if canImport(AnytypeOriginalEditor)
    func showOriginalEditor(annotation: Annotation, context: AnytypeOriginalEditorMiniAppsContext,
                            editorID: UUID, sourceView: UIView) {
        do {
            var range: NSRange?
            if let location = context.documentSelectionLocation, let length = context.selectionLength,
               let selectedText = context.selectedText {
                let candidate = NSRange(location: location, length: length)
                if let swiftRange = Range(candidate, in: context.documentText),
                   context.documentText[swiftRange].utf8.elementsEqual(selectedText.utf8) { range = candidate }
            }
            let document = try OtzariaMiniAppsDocument(annotation: annotation, draft: context.documentText,
                selection: range, isReaderSelection: false, editorID: editorID, title: annotation.resolvedBookTitle)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let nativeContext = String(decoding: try encoder.encode(context), as: UTF8.self)
            present(document: document, inputText: context.selectedText ?? "", sourceText: context.documentText,
                sourceSelection: document.selection, sourceView: sourceView,
                additionalMetadata: [Self.originalEditorMetadataKey: nativeContext], sourceKind: "native-annotation",
                requestedOperation: (context.selectedText?.isEmpty == false) ? .replaceSelection : .insert)
        } catch { show(error: error, sourceView: sourceView) }
    }
    #endif

    private func present(document: OtzariaMiniAppsDocument, inputText: String, sourceText: String,
                         sourceSelection: MiniAppTextSelection?, sourceView: UIView?,
                         additionalMetadata: [String: String] = [:], sourceKind: String? = nil,
                         requestedOperation: MiniAppOperation? = nil) {
        do {
            let store = try MiniAppBridgeStore()
            let scene = sourceView?.window?.windowScene
            let metadata = try document.metadata.merging(additionalMetadata) { original, _ in original }
            let source = MiniAppSourceContext(appID: Self.sourceAppID, displayName: "ChavrusaText",
                documentID: document.annotationUUID, documentTitle: document.title,
                selection: sourceSelection,
                documentText: sourceText, kind: sourceKind ?? (document.isReaderSelection ? "reader" : "annotation"),
                locator: document.locatorJSON, sceneID: scene?.session.persistentIdentifier,
                metadata: metadata)
            let callbacks = MiniAppCallbacks(success: Self.callbackURL, error: Self.callbackURL, cancel: Self.callbackURL)
            let operation: MiniAppOperation = requestedOperation ??
                (!document.isReaderSelection && (document.selection?.length ?? 0) > 0 ? .replaceSelection : .insert)
            guard let presenter = presenter(in: scene, sourceView: sourceView) else { throw OtzariaMiniAppsError.unavailable }
            let picker = MiniAppPicker(store: store, source: source,
                inputs: [.init(kind: .text, text: inputText, typeIdentifier: "public.plain-text")],
                operation: operation, callbacks: callbacks, onOpen: { [weak self] url in
                    // The shared picker owns its dismissal before invoking onOpen.
                    UIApplication.shared.open(url, options: [:]) { opened in
                        if !opened {
                            Task { @MainActor in self?.show(error: OtzariaMiniAppsError.unavailable, sourceView: sourceView) }
                        }
                    }
                }, onError: { [weak self] error in self?.show(error: error, sourceView: sourceView) })
            let controller = UIHostingController(rootView: picker)
            controller.modalPresentationStyle = .pageSheet
            controller.sheetPresentationController?.detents = [.medium(), .large()]
            presenter.present(controller, animated: true)
        } catch { show(error: error, sourceView: sourceView) }
    }

    private func consume(_ result: MiniAppResult, store: MiniAppBridgeStore,
                         fallbackManager: iOSNavigationManager) {
        guard processing.insert(result.requestID).inserted else { return }
        var continuingAsynchronously = false
        defer { if !continuingAsynchronously { processing.remove(result.requestID) } }
        do {
            guard let request = try store.request(id: result.requestID),
                  request.source.appID == Self.sourceAppID else { throw MiniAppBridgeError.wrongSource }
            let sceneOwner = request.source.sceneID.flatMap { scenes[$0] }
            let manager = sceneOwner?.manager ?? fallbackManager
            let scene = sceneOwner?.scene ?? scenes.values.first(where: { $0.manager === manager })?.scene
            if result.status == .cancelled {
                _ = try store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
                return
            }
            if result.status == .error {
                display(result, store: store, scene: scene)
                return
            }
            if result.operation == .display || result.operation == .custom {
                display(result, store: store, scene: scene)
                return
            }
            let document = try OtzariaMiniAppsDocument.restore(from: request.source)
            if try OtzariaMiniAppsPersistence.committed(result, document: document) != nil {
                _ = try store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
                return
            }
            if let contextJSON = request.source.metadata[Self.originalEditorMetadataKey] {
                #if canImport(AnytypeOriginalEditor)
                continuingAsynchronously = true
                receiveOriginal(result, document: document, contextJSON: contextJSON,
                    store: store, manager: manager, scene: scene)
                return
                #else
                throw OtzariaMiniAppsError.unavailable
                #endif
            }
            let editor = document.editorID.flatMap { editors[$0] }.flatMap {
                $0.currentText() == nil ? nil : $0
            }
            if let current = editor?.currentText(), current != document.draftNote {
                throw OtzariaMiniAppsError.changedDocument
            }
            let attachments = try retainAttachments(result, store: store)
            let text = try document.editedText(result, attachmentURLs: attachments)
            let commit = try OtzariaMiniAppsPersistence.apply(result, document: document, text: text)
            if !commit.replayed {
                AnnotationStore.shared.clearAllCaches()
                AnnotationStore.shared.events.send(.treeInvalidated)
                CloudKitSyncManager.shared.upload(annotations: [commit.annotation], trackPending: false)
                ReaderAnnotationRefreshCoordinator.shared.notifyAnnotationMutated()
                NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
            }
            // Acknowledge only after the original annotation transaction and receipt committed.
            _ = try store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
            if let editor { editor.didCommit(commit.annotation) }
            else { showSavedNote(commit.annotation, requestID: result.requestID, manager: manager, scene: scene) }
        } catch {
            reportedFailures.insert(result.requestID)
            enqueuePresentation(requestID: result.requestID, scene: nil) { [weak self] finished in
                self?.presentError(error, sourceView: nil, onDismiss: finished) ?? false
            }
        }
    }

    #if canImport(AnytypeOriginalEditor)
    private func receiveOriginal(_ result: MiniAppResult, document: OtzariaMiniAppsDocument,
                                 contextJSON: String, store: MiniAppBridgeStore,
                                 manager: iOSNavigationManager, scene: UIWindowScene?) {
        if let id = document.editorID, let model = originalEditors[id]?.model {
            applyOriginal(result, document: document, contextJSON: contextJSON, store: store, model: model, scene: scene)
            return
        }
        // A cold callback must mount the original native editor against its
        // actual saved row and the current scene's original workspace owner.
        enqueuePresentation(requestID: result.requestID, scene: scene) { [weak self] finished in
            guard let self, let presenter = self.presenter(in: scene) else { return false }
            let owner = scene.flatMap { self.scenes[$0.session.persistentIdentifier] }
                ?? self.scenes.values.first(where: { $0.manager === manager })
            guard let workspace = owner?.workspace else { return false }
            do {
                let annotation = try OtzariaMiniAppsPersistence.savedAnnotation(document: document)
                let model = AnnotationOriginalEditorProductionPresentation(
                    annotation: annotation, inspected: nil, workspace: workspace)
                model.onReady = { [weak self, weak model] in
                    guard let self, let model else { return }
                    self.applyOriginal(result, document: document, contextJSON: contextJSON,
                        store: store, model: model, scene: scene)
                }
                model.onOpenFailure = { [weak self] error in
                    self?.originalFailure(error, requestID: result.requestID, scene: scene)
                }
                let controller = OtzariaMiniAppsResultHost(rootView:
                    AnnotationOriginalEditorProductionView(model: model).interactiveDismissDisabled(true))
                controller.modalPresentationStyle = .fullScreen
                controller.isModalInPresentation = true
                controller.onDismiss = finished
                presenter.present(controller, animated: true)
                return true
            } catch {
                self.processing.remove(result.requestID)
                self.reportedFailures.insert(result.requestID)
                return self.presentError(error, sourceView: presenter.view, onDismiss: finished)
            }
        }
    }

    private func applyOriginal(_ result: MiniAppResult, document: OtzariaMiniAppsDocument,
                               contextJSON: String, store: MiniAppBridgeStore,
                               model: AnnotationOriginalEditorProductionPresentation, scene: UIWindowScene?) {
        Task { [weak self, weak model] in
            guard let self else { return }
            defer { self.processing.remove(result.requestID) }
            do {
                guard let model,
                      model.annotation.ckRecordId == document.annotationUUID,
                      model.annotation.id == document.annotationID else { throw OtzariaMiniAppsError.missingDocument }
                let files = try self.retainAttachments(result, store: store)
                guard !result.items.isEmpty else { throw OtzariaMiniAppsError.noResult }
                let text = try result.items.map { item -> String in
                    if let text = item.text { return text }
                    if let url = item.url { return url.absoluteString }
                    if let id = item.attachmentID {
                        guard let url = files[id] else { throw MiniAppBridgeError.invalidAttachment }
                        return url.absoluteString
                    }
                    throw OtzariaMiniAppsError.noResult
                }.joined(separator: "\n")
                let outcome = try await model.applyMiniApps(result, contextJSON: contextJSON, text: text)
                let receipt: AnnotationExchangeCommit
                switch outcome {
                case .committed(let saved): receipt = saved.receipt
                case .completedWithoutOwnership(let committed): receipt = committed
                }
                guard receipt.mutationID == result.requestID,
                      receipt.annotationUUID == UUID(uuidString: document.annotationUUID) else {
                    throw MiniAppBridgeError.conflictingResult
                }
                // The native archive and exact result receipt already committed
                // together. UI retirement cannot convert that commit into retry.
                _ = try store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
                ReaderAnnotationRefreshCoordinator.shared.notifyAnnotationMutated()
                NotificationCenter.default.post(name: .torahInspectorNotesDidChange, object: nil)
            } catch {
                self.originalFailure(error, requestID: result.requestID, scene: scene)
            }
        }
    }

    private func originalFailure(_ error: Error, requestID: UUID, scene: UIWindowScene?) {
        processing.remove(requestID)
        reportedFailures.insert(requestID)
        _ = presentError(error, sourceView: presenter(in: scene)?.view, onDismiss: {})
    }
    #endif

    private func retainAttachments(_ result: MiniAppResult, store: MiniAppBridgeStore) throws -> [UUID: URL] {
        let attachments = result.items.compactMap(\.attachmentID)
        guard !attachments.isEmpty else { return [:] }
        let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("MiniApps", isDirectory: true)
            .appendingPathComponent(result.requestID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var saved: [UUID: URL] = [:]
        for id in attachments {
            let source = try store.attachmentURL(id: id)
            let name = result.items.first(where: { $0.attachmentID == id })?.name.map {
                URL(fileURLWithPath: $0).lastPathComponent
            } ?? source.lastPathComponent
            let destination = folder.appendingPathComponent(id.uuidString + "-" + name)
            try Data(contentsOf: source).write(to: destination, options: .atomic)
            saved[id] = destination
        }
        return saved
    }

    private func enqueuePresentation(requestID: UUID, scene: UIWindowScene?,
                                     show: @escaping (@escaping () -> Void) -> Bool) {
        guard queuedResults.insert(requestID).inserted else { return }
        let target = scene ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        let key = target?.session.persistentIdentifier ?? "foreground"
        presentationQueues[key, default: []].append(.init(requestID: requestID, show: show))
        drainPresentations(key: key)
    }

    private func drainPresentations(key: String) {
        guard !presentingScenes.contains(key), let next = presentationQueues[key]?.first else { return }
        presentingScenes.insert(key)
        let shown = next.show { [weak self] in
            guard let self else { return }
            self.queuedResults.remove(next.requestID)
            self.presentingScenes.remove(key)
            Task { @MainActor [weak self] in self?.drainPresentations(key: key) }
        }
        if shown { presentationQueues[key]?.removeFirst() }
        else { presentingScenes.remove(key) }
    }

    private func showSavedNote(_ annotation: Annotation, requestID: UUID,
                               manager: iOSNavigationManager, scene: UIWindowScene?) {
        enqueuePresentation(requestID: requestID, scene: scene) { [weak self] finished in
            guard let self, let presenter = self.presenter(in: scene) else { return false }
            if let book = manager.openTabs.first(where: { $0.book.id == annotation.bkId })?.book
                ?? LibraryDataManager.shared.getBook([annotation.bkId]).first {
                manager.openBook(book, options: OpenBookOptions(contentId: annotation.contentId,
                    annotationEvent: ReaderAnnotationEvent(annotation: annotation)))
            }
            let editor = iOSAnnotationEditorSheet(annotation: annotation,
                onSave: { try AnnotationStore.shared.updateAnnotation($0) },
                onDelete: { try AnnotationStore.shared.deleteAnnotation(id: $0) })
            let controller = OtzariaMiniAppsResultHost(rootView: editor)
            controller.onDismiss = finished
            controller.modalPresentationStyle = .pageSheet
            controller.sheetPresentationController?.detents = [.medium(), .large()]
            presenter.present(controller, animated: true)
            return true
        }
    }

    private func display(_ result: MiniAppResult, store: MiniAppBridgeStore, scene: UIWindowScene?) {
        enqueuePresentation(requestID: result.requestID, scene: scene) { [weak self] finished in
            guard let self, let presenter = self.presenter(in: scene) else { return false }
            let files: [UUID: URL]
            do { files = try self.retainAttachments(result, store: store) }
            catch {
                self.reportedFailures.insert(result.requestID)
                return self.presentError(error, sourceView: presenter.view, onDismiss: finished)
            }
            let items: [Any] = result.items.compactMap { item in
                if let text = item.text { return text }
                if let url = item.url { return url }
                if let id = item.attachmentID { return files[id] }
                return nil
            }
            let acknowledge = {
                _ = try? store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
            }
            if !files.isEmpty {
                let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
                if let popover = activity.popoverPresentationController {
                    popover.sourceView = presenter.view
                    popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
                }
                activity.completionWithItemsHandler = { [weak activity] _, _, _, _ in
                    acknowledge()
                    if let activity { activity.dismiss(animated: true, completion: finished) }
                    else { finished() }
                }
                presenter.present(activity, animated: true)
            } else {
                let text = result.message ?? result.items.compactMap { $0.text ?? $0.url?.absoluteString }.joined(separator: "\n")
                let alert = UIAlertController(title: String(localized: "Mini Apps"),
                    message: text.isEmpty ? String(localized: "Done") : text, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "Done"), style: .default) { [weak alert] _ in
                    acknowledge()
                    if let alert { alert.dismiss(animated: true, completion: finished) }
                    else { finished() }
                })
                presenter.present(alert, animated: true)
            }
            return true
        }
    }

    private func presenter(in scene: UIWindowScene?, sourceView: UIView? = nil) -> UIViewController? {
        var responder: UIResponder? = sourceView
        while let current = responder {
            if let controller = current as? UIViewController { return visiblePresenter(controller) }
            responder = current.next
        }
        let targetScene = scene ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        guard let root = targetScene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? targetScene?.windows.first?.rootViewController else { return nil }
        return visiblePresenter(root)
    }

    private func visiblePresenter(_ controller: UIViewController) -> UIViewController? {
        let candidate = top(controller)
        guard candidate.viewIfLoaded?.window != nil else { return nil }
        return candidate
    }

    private func top(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed { return top(presented) }
        return controller
    }

    func show(error: Error, sourceView: UIView?) {
        _ = presentError(error, sourceView: sourceView, onDismiss: {})
    }

    private func presentError(_ error: Error, sourceView: UIView?, onDismiss: @escaping () -> Void) -> Bool {
        guard let presenter = presenter(in: sourceView?.window?.windowScene, sourceView: sourceView) else { return false }
        let alert = UIAlertController(title: String(localized: "Mini Apps"),
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { [weak alert] _ in
            if let alert { alert.dismiss(animated: true, completion: onDismiss) }
            else { onDismiss() }
        })
        presenter.present(alert, animated: true)
        return true
    }
}

/// Programmatic Save/Cancel and interactive sheet dismissal both release the
/// per-scene result queue after the actual original editor has disappeared.
private final class OtzariaMiniAppsResultHost<Content: View>: UIHostingController<Content> {
    var onDismiss: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil || isBeingDismissed {
            let completion = onDismiss
            onDismiss = nil
            completion?()
        }
    }
}

/// The original Settings navigation embeds the exact shared preferences UI.
/// It does not manufacture a source request just to edit the catalog.
@MainActor
struct OtzariaMiniAppsPreferences: View {
    @State private var store: MiniAppBridgeStore?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let store {
                MiniAppPreferencesView(store: store)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Mini Apps", systemImage: "square.grid.2x2")
                } description: { Text(errorMessage) }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Mini Apps")
        .task {
            guard store == nil, errorMessage == nil else { return }
            do { store = try MiniAppBridgeStore() }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

struct OtzariaMiniAppsSceneRegistration: UIViewRepresentable {
    @Environment(\.exact9401Workspace) private var workspace
    let manager: iOSNavigationManager
    func makeUIView(context: Context) -> RegistrationView {
        let view = RegistrationView()
        view.manager = manager
        view.workspace = workspace
        return view
    }
    func updateUIView(_ view: RegistrationView, context: Context) {
        view.manager = manager
        view.workspace = workspace
        view.register()
    }
    final class RegistrationView: UIView {
        weak var manager: iOSNavigationManager?
        weak var workspace: StudyWorkspaceNavigationAdapter?
        override func didMoveToWindow() { super.didMoveToWindow(); register() }
        func register() {
            guard let manager, let scene = window?.windowScene else { return }
            Task { @MainActor [weak workspace] in
                OtzariaMiniAppsCoordinator.shared.attach(manager: manager, scene: scene, workspace: workspace)
            }
        }
    }
}
#endif
