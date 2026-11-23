#if os(iOS)
import Foundation
import SwiftUI
import UIKit
import HanlinMiniAppsBridge
import HanlinMiniAppsPicker

/// The only MiniApps integration owner in this app. Execution remains in Hanlin MiniApps.
@MainActor
final class OtzariaMiniAppsCoordinator {
    static let shared = OtzariaMiniAppsCoordinator()
    static let sourceAppID = "com.davidpovarsky.chavrusatext"

    private struct SceneOwner {
        weak var manager: iOSNavigationManager?
        weak var scene: UIWindowScene?
    }
    private struct EditorOwner {
        let currentText: () -> String?
        let didCommit: (Annotation) -> Void
    }
    private var scenes: [String: SceneOwner] = [:]
    private var editors: [UUID: EditorOwner] = [:]
    private var processing = Set<UUID>()
    private var reportedFailures = Set<UUID>()
    private var displaying = Set<UUID>()

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

    func attach(manager: iOSNavigationManager, scene: UIWindowScene) {
        scenes[scene.session.persistentIdentifier] = .init(manager: manager, scene: scene)
        resume(manager: manager)
    }

    /// Foreground recovery also delivers a result after cold launch or an interrupted callback.
    func resume(manager: iOSNavigationManager) {
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
            guard let result = try store.result(id: id) else { return true }
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

    private func present(document: OtzariaMiniAppsDocument, inputText: String, sourceText: String,
                         sourceSelection: MiniAppTextSelection?, sourceView: UIView?) {
        do {
            let store = try MiniAppBridgeStore()
            let scene = sourceView?.window?.windowScene
            let source = MiniAppSourceContext(appID: Self.sourceAppID, displayName: "ChavrusaText",
                documentID: document.annotationUUID, documentTitle: document.title,
                selection: sourceSelection,
                documentText: sourceText, kind: document.isReaderSelection ? "reader" : "annotation",
                locator: document.locatorJSON, sceneID: scene?.session.persistentIdentifier,
                metadata: try document.metadata)
            let callbacks = MiniAppCallbacks(success: Self.callbackURL, error: Self.callbackURL, cancel: Self.callbackURL)
            let operation: MiniAppOperation = !document.isReaderSelection && (document.selection?.length ?? 0) > 0
                ? .replaceSelection : .insert
            guard let presenter = presenter(in: scene, sourceView: sourceView) else { throw OtzariaMiniAppsError.unavailable }
            weak var pickerController: UIViewController?
            let picker = MiniAppPicker(store: store, source: source,
                inputs: [.init(kind: .text, text: inputText, typeIdentifier: "public.plain-text")],
                operation: operation, callbacks: callbacks, onOpen: { [weak self] url in
                    let open = {
                        UIApplication.shared.open(url, options: [:]) { opened in
                            if !opened {
                                Task { @MainActor in self?.show(error: OtzariaMiniAppsError.unavailable, sourceView: sourceView) }
                            }
                        }
                    }
                    if let pickerController { pickerController.dismiss(animated: true, completion: open) }
                    else { open() }
                }, onError: { [weak self] error in self?.show(error: error, sourceView: sourceView) })
            let controller = UIHostingController(rootView: picker)
            pickerController = controller
            controller.modalPresentationStyle = .pageSheet
            controller.sheetPresentationController?.detents = [.medium(), .large()]
            presenter.present(controller, animated: true)
        } catch { show(error: error, sourceView: sourceView) }
    }

    private func consume(_ result: MiniAppResult, store: MiniAppBridgeStore,
                         fallbackManager: iOSNavigationManager) {
        guard processing.insert(result.requestID).inserted else { return }
        defer { processing.remove(result.requestID) }
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
            else { showSavedNote(commit.annotation, manager: manager, scene: scene) }
        } catch {
            reportedFailures.insert(result.requestID)
            show(error: error, sourceView: nil)
        }
    }

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

    private func showSavedNote(_ annotation: Annotation, manager: iOSNavigationManager, scene: UIWindowScene?) {
        if let book = manager.openTabs.first(where: { $0.book.id == annotation.bkId })?.book
            ?? LibraryDataManager.shared.getBook([annotation.bkId]).first {
            manager.openBook(book, options: OpenBookOptions(contentId: annotation.contentId,
                annotationEvent: ReaderAnnotationEvent(annotation: annotation)))
        }
        guard let presenter = presenter(in: scene) else { return }
        let editor = iOSAnnotationEditorSheet(annotation: annotation,
            onSave: { try AnnotationStore.shared.updateAnnotation($0) },
            onDelete: { try AnnotationStore.shared.deleteAnnotation(id: $0) })
        let controller = UIHostingController(rootView: editor)
        controller.modalPresentationStyle = .pageSheet
        controller.sheetPresentationController?.detents = [.medium(), .large()]
        presenter.present(controller, animated: true)
    }

    private func display(_ result: MiniAppResult, store: MiniAppBridgeStore, scene: UIWindowScene?) {
        guard let presenter = presenter(in: scene) else { return }
        guard displaying.insert(result.requestID).inserted else { return }
        let files: [UUID: URL]
        do { files = try retainAttachments(result, store: store) }
        catch {
            displaying.remove(result.requestID)
            reportedFailures.insert(result.requestID)
            show(error: error, sourceView: nil)
            return
        }
        let items: [Any] = result.items.compactMap { item in
            if let text = item.text { return text }
            if let url = item.url { return url }
            if let id = item.attachmentID { return files[id] }
            return nil
        }
        if !files.isEmpty {
            let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            }
            presenter.present(activity, animated: true) {
                self.displaying.remove(result.requestID)
                _ = try? store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
            }
        } else {
            let text = result.message ?? result.items.compactMap { $0.text ?? $0.url?.absoluteString }.joined(separator: "\n")
            let alert = UIAlertController(title: String(localized: "Mini Apps"),
                message: text.isEmpty ? String(localized: "Done") : text, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "Done"), style: .default))
            presenter.present(alert, animated: true) {
                self.displaying.remove(result.requestID)
                _ = try? store.acknowledgeResult(id: result.requestID, sourceAppID: Self.sourceAppID)
            }
        }
    }

    private func presenter(in scene: UIWindowScene?, sourceView: UIView? = nil) -> UIViewController? {
        var responder: UIResponder? = sourceView
        while let current = responder {
            if let controller = current as? UIViewController { return top(controller) }
            responder = current.next
        }
        let targetScene = scene ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        guard let root = targetScene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? targetScene?.windows.first?.rootViewController else { return nil }
        return top(root)
    }

    private func top(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed { return top(presented) }
        return controller
    }

    func show(error: Error, sourceView: UIView?) {
        guard let presenter = presenter(in: sourceView?.window?.windowScene, sourceView: sourceView) else { return }
        let alert = UIAlertController(title: String(localized: "Mini Apps"),
            message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        presenter.present(alert, animated: true)
    }
}

struct OtzariaMiniAppsSceneRegistration: UIViewRepresentable {
    let manager: iOSNavigationManager
    func makeUIView(context: Context) -> RegistrationView {
        let view = RegistrationView()
        view.manager = manager
        return view
    }
    func updateUIView(_ view: RegistrationView, context: Context) { view.manager = manager; view.register() }
    final class RegistrationView: UIView {
        weak var manager: iOSNavigationManager?
        override func didMoveToWindow() { super.didMoveToWindow(); register() }
        func register() {
            guard let manager, let scene = window?.windowScene else { return }
            Task { @MainActor in OtzariaMiniAppsCoordinator.shared.attach(manager: manager, scene: scene) }
        }
    }
}
#endif
