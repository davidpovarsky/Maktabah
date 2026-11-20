import Foundation

/// One Reader owns the study presentation and any original note sheet above it.
/// A closing identity remains retained until the actual system onDismiss. A new
/// request may queue behind it, but cannot reuse a closing presenter.
struct NativeStudySheetPresentationState: Equatable {
    struct Presentation: Identifiable, Equatable {
        let id: UUID
    }

    enum NoteHost: Equatable {
        case reader
        case study(UUID)
    }

    struct NotePresentation: Equatable {
        let id: UUID
        let host: NoteHost
    }

    struct Dismissal: Equatable {
        let showContents: Bool
        let studyStillRequested: Bool
    }

    private(set) var presentation: Presentation?
    private(set) var isPresented = false
    private(set) var studyRequested = false
    private(set) var pendingContents = false
    private(set) var note: NotePresentation?

    var presentedItem: Presentation? { isPresented ? presentation : nil }

    mutating func requestStudy() {
        guard !pendingContents else { return }
        studyRequested = true
        presentIfPossible()
    }

    mutating func requestDismissal(showContents: Bool = false) {
        studyRequested = false
        pendingContents = pendingContents || showContents
        if let presentation, note?.host == .study(presentation.id) {
            // The original note editor must finish its real dismissal first.
            return
        }
        isPresented = false
    }

    @discardableResult
    mutating func beginNote(id: UUID) -> Bool {
        guard note == nil else { return false }
        if let presentation {
            guard isPresented, studyRequested, !pendingContents else { return false }
            note = .init(id: id, host: .study(presentation.id))
        } else {
            note = .init(id: id, host: .reader)
        }
        return true
    }

    @discardableResult
    mutating func noteDidDismiss(id: UUID) -> Bool {
        guard note?.id == id else { return false }
        note = nil
        if !studyRequested { isPresented = false }
        presentIfPossible()
        return true
    }

    mutating func studyDidDismiss(id: UUID) -> Dismissal? {
        guard presentation?.id == id, !isPresented else { return nil }
        presentation = nil
        let result = Dismissal(showContents: pendingContents,
                               studyStillRequested: studyRequested)
        pendingContents = false
        if !result.showContents { presentIfPossible() }
        return result
    }

    private mutating func presentIfPossible() {
        guard studyRequested, !pendingContents, presentation == nil, note == nil else { return }
        presentation = .init(id: UUID())
        isPresented = true
    }
}

#if os(iOS)
import SwiftUI
import TorahInspectorUI

/// The compact view is a projection of the same Reader selection. It has no
/// repository, source actions or NavigationStack of its own. The original Kit
/// stays mounted behind it, retaining drill-down and expanded source state.
struct NativeStudySheetContent {
    let isPeek: Bool
    let title: String
    let subtitle: String
    let excerpt: String
    let expand: @MainActor () -> Void

    var excerptDirection: LayoutDirection {
        for scalar in excerpt.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF: return .rightToLeft
            default: if CharacterSet.letters.contains(scalar) { return .leftToRight }
            }
        }
        return .rightToLeft
    }
}

struct NativeStudySheetPeek: View {
    let content: NativeStudySheetContent
    let selectedTool: TorahStudyTool
    let close: @MainActor () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if !content.subtitle.isEmpty {
                        Text(content.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Button(action: close) {
                    Image(systemName: "xmark").frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TorahStrings.close)
                .accessibilityIdentifier("reader-study-peek-close")
            }
            if !content.excerpt.isEmpty {
                Text(content.excerpt)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, content.excerptDirection)
                    .accessibilityIdentifier("reader-study-peek-passage")
            }
            Button(action: content.expand) {
                HStack {
                    Text(selectedTool.localizedTitle(locale: locale))
                    Spacer(minLength: 8)
                    Label(TorahStrings.viewDetails, systemImage: "chevron.up")
                }
                .font(.caption.weight(.semibold))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader-study-peek-expand")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-study-peek")
    }
}

@available(iOS 27.0, *)
struct NativeStudySheetPresentation: ViewModifier {
    @Binding var detent: PresentationDetent
    let noteIsPresented: Bool
    @Environment(\.layoutDirection) private var layoutDirection

    static let peek = PresentationDetent.height(155)

    func body(content: Content) -> some View {
        content
            .presentationDetents([Self.peek, .medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            // Placement is logical; content retains its real layout direction.
            // Physical right is verified independently by actual window frames.
            .presentationPlacement(layoutDirection == .rightToLeft ? .leading : .trailing)
            .interactiveDismissDisabled(noteIsPresented)
    }
}

#if DEBUG
import CryptoKit

/// Explicit mini-fixture observation and lifecycle-race input only. This does
/// not participate in Core admission, NativeSurfaceWitness or note persistence.
@MainActor
final class NativeStudySheetAcceptance {
    struct Context: Equatable {
        let ownerID: UUID
        let presentationID: UUID?
        let noteID: UUID?
        let contentID: UUID
        let sessionIdentity: String
        let readerIdentity: String
        let sourceToken: String
        let selectionToken: String
        let selectedTool: String
        let detent: String
        let studyVisible: Bool
    }

    private struct Command: Decodable {
        let deliveryID: UUID
        let id: UUID
        let ownerID: UUID
        let presentationID: UUID
        let noteID: UUID?
        let sourceToken: String
        let action: String
    }

    private weak var marker: UIViewController?
    private weak var originalNoteTextView: UITextView?
    private var observedContext: Context?
    private var notePresentationID: UUID?
    private var consumed: Set<UUID> = []
    private var observedDeliveries: Set<UUID> = []
    private var pendingReopen: Command?
    private var events: [[String: Any]] = []
    private var lastWritten: Data?

    static var namespace: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-NativeStudySheetAcceptanceEnabled"),
              arguments.indices.contains(flag + 1), arguments[flag + 1] == "YES",
              UserDefaults.standard.bool(forKey: "NativeStudySheetAcceptanceEnabled"),
              OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
              let raw = UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace"),
              let value = UUID(uuidString: raw) else { return nil }
        return value.uuidString
    }

    static func token(_ fields: [String]) -> String {
        let bytes = (try? JSONEncoder().encode(fields)) ?? Data()
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    func observe(_ controller: UIViewController?, context: Context) {
        guard Self.namespace != nil else { return }
        if controller == nil {
            guard observedContext?.ownerID == context.ownerID,
                  observedContext?.presentationID == context.presentationID else { return }
        }
        marker = controller
        observedContext = context
    }

    func observeNote(_ view: UITextView?, presentationID: UUID) {
        guard Self.namespace != nil else { return }
        if view != nil || notePresentationID == presentationID {
            originalNoteTextView = view
            notePresentationID = presentationID
        }
    }

    func didDismissStudy(_ id: UUID) { record("study_onDismiss", presentationID: id) }
    func didDismissNote(_ id: UUID, fromParent: Bool) {
        record(fromParent ? "note_finished_by_parent_onDismiss" : "note_onDismiss", noteID: id)
    }

    private func record(_ event: String, commandID: UUID? = nil, deliveryID: UUID? = nil,
                        presentationID: UUID? = nil, noteID: UUID? = nil) {
        guard Self.namespace != nil, events.count < 48 else { return }
        var row: [String: Any] = ["event": event, "sequence": events.count,
                                  "uptime": ProcessInfo.processInfo.systemUptime]
        row["commandID"] = commandID?.uuidString
        row["deliveryID"] = deliveryID?.uuidString
        row["presentationID"] = presentationID?.uuidString
        row["noteID"] = noteID?.uuidString
        events.append(row)
    }

    private var actualSheet: UISheetPresentationController? {
        var node = marker
        for _ in 0..<16 {
            guard let current = node else { return nil }
            if current.presentingViewController != nil,
               let sheet = current.presentationController as? UISheetPresentationController {
                return sheet
            }
            node = current.parent
        }
        return nil
    }

    private func noteIsActuallyPresented(_ context: Context, in window: UIWindow) -> Bool {
        guard let expected = context.noteID, expected == notePresentationID,
              let view = originalNoteTextView, view.window === window,
              !view.isHidden, view.alpha >= 0.95 else { return false }
        var top = window.rootViewController
        for _ in 0..<16 {
            guard let presented = top?.presentedViewController else { break }
            top = presented
        }
        return top?.presentingViewController != nil && top.map { view.isDescendant(of: $0.view) } == true
    }

    private func url(_ namespace: String, suffix: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("native-study-sheet-" + namespace + suffix)
    }

    private func readCommand(_ namespace: String) -> Command? {
        guard let path = url(namespace, suffix: ".command.json"),
              let values = try? path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink == false,
              let size = values.fileSize, size > 0, size <= 4096,
              let handle = try? FileHandle(forReadingFrom: path) else { return nil }
        defer { try? handle.close() }
        guard let bytes = try? handle.read(upToCount: 4097), bytes.count <= 4096 else { return nil }
        return try? JSONDecoder().decode(Command.self, from: bytes)
    }

    /// Called only by the current original Reader. The accepted operations are
    /// original actions, never mutations of presentation state or receipts.
    func poll(context: Context, close: () -> Void, contents: () -> Void, toggle: () -> Void) {
        guard let namespace = Self.namespace else { return }
        defer { writeObservation(context: context, namespace: namespace) }
        if let command = pendingReopen {
            guard command.ownerID == context.ownerID,
                  command.presentationID == context.presentationID,
                  command.sourceToken == context.sourceToken,
                  !context.studyVisible,
                  let sheet = actualSheet,
                  sheet.presentedViewController.isBeingDismissed,
                  sheet.presentedViewController.viewIfLoaded?.window != nil else {
                // No invented transition: a later onDismiss alone is not proof
                // that the request was delivered during the actual dismissal.
                if command.presentationID != context.presentationID || actualSheet == nil {
                    pendingReopen = nil
                    record("closing_phase_not_observed", commandID: command.id)
                }
                return
            }
            pendingReopen = nil
            record("actual_closing_before_toggle", commandID: command.id,
                   presentationID: command.presentationID)
            toggle()
            return
        }
        guard observedDeliveries.count < 32, let command = readCommand(namespace),
              !observedDeliveries.contains(command.deliveryID) else { return }
        observedDeliveries.insert(command.deliveryID)
        if consumed.contains(command.id) {
            record("refused_replayed_command", commandID: command.id, deliveryID: command.deliveryID)
            return
        }
        guard consumed.count < 16 else { return }
        consumed.insert(command.id)
        guard command.ownerID == context.ownerID,
              command.presentationID == context.presentationID,
              command.sourceToken == context.sourceToken,
              let observedContext, observedContext.ownerID == context.ownerID,
              observedContext.presentationID == context.presentationID,
              observedContext.sourceToken == context.sourceToken,
              let sheet = actualSheet, let window = sheet.presentedViewController.viewIfLoaded?.window,
              window.windowScene?.activationState == .foregroundActive,
              (marker as? NativeStudySheetObservation.Controller)?.hasAppeared == true,
              !sheet.presentedViewController.isBeingPresented,
              !sheet.presentedViewController.isBeingDismissed else {
            record("refused_stale_or_unmounted", commandID: command.id)
            return
        }
        switch command.action {
        case "closeParent", "openContents":
            guard command.noteID == context.noteID, context.noteID != nil,
                  noteIsActuallyPresented(context, in: window) else {
                record("refused_missing_actual_child", commandID: command.id)
                return
            }
            record("actual_child_before_action", commandID: command.id,
                   presentationID: command.presentationID, noteID: context.noteID)
            if command.action == "closeParent" { close() } else { contents() }
        case "reopenDuringDismiss":
            guard command.noteID == nil, context.noteID == nil else {
                record("refused_child_for_reopen", commandID: command.id)
                return
            }
            pendingReopen = command
            record("actual_sheet_before_close", commandID: command.id,
                   presentationID: command.presentationID)
            close()
        default:
            record("refused_unknown_action", commandID: command.id)
        }
    }

    private func writeObservation(context: Context, namespace: String) {
        guard let path = url(namespace, suffix: ".json") else { return }
        let sheet = actualSheet
        let window = sheet?.presentedViewController.viewIfLoaded?.window
        var row: [String: Any] = [
            "namespace": namespace, "ownerID": context.ownerID.uuidString,
            "contentID": context.contentID.uuidString, "sessionIdentity": context.sessionIdentity,
            "readerIdentity": context.readerIdentity, "sourceToken": context.sourceToken,
            "selectionToken": context.selectionToken,
            "selectedTool": context.selectedTool, "detent": context.detent,
            "systemSheet": sheet != nil, "events": events,
            "appeared": (marker as? NativeStudySheetObservation.Controller)?.hasAppeared == true,
            "actualClosing": sheet?.presentedViewController.isBeingDismissed == true,
            "actualChild": window.map { noteIsActuallyPresented(context, in: $0) } ?? false
        ]
        row["presentationID"] = context.presentationID?.uuidString
        row["noteID"] = context.noteID?.uuidString
        row["sheetIdentity"] = sheet.map { String(describing: ObjectIdentifier($0)) }
        row["systemDetentIdentifier"] = sheet?.selectedDetentIdentifier?.rawValue
        row["contentLayoutDirection"] = marker?.viewIfLoaded?.effectiveUserInterfaceLayoutDirection.rawValue
        row["sceneID"] = window?.windowScene?.session.persistentIdentifier
        if let sheet, let window {
            let view = sheet.presentedViewController.view!
            let frame = view.convert(view.bounds, to: window)
            let bounds = window.bounds
            let values = [frame.minX, frame.minY, frame.width, frame.height,
                          bounds.minX, bounds.minY, bounds.width, bounds.height]
            if values.allSatisfy(\.isFinite) {
                row["sheetFrame"] = values.prefix(4).map(Double.init)
                row["windowBounds"] = values.suffix(4).map(Double.init)
            }
        }
        guard let bytes = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
              bytes.count <= 32768, bytes != lastWritten else { return }
        do {
            try bytes.write(to: path, options: .atomic)
            lastWritten = bytes
        } catch { }
    }
}

struct NativeStudySheetObservation: UIViewControllerRepresentable {
    let observe: @MainActor (UIViewController?) -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.observe = observe
        observe(controller)
    }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.observe?(nil)
        controller.observe = nil
    }
    final class Controller: UIViewController {
        var observe: (@MainActor (UIViewController?) -> Void)?
        private(set) var hasAppeared = false
        override func loadView() {
            view = UIView(); view.backgroundColor = .clear
            view.isUserInteractionEnabled = false; view.isAccessibilityElement = false
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated); hasAppeared = true; observe?(self)
        }
        override func viewWillDisappear(_ animated: Bool) {
            hasAppeared = false
            super.viewWillDisappear(animated)
        }
    }
}
#endif
#endif
