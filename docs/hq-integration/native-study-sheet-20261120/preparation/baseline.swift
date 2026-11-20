import Foundation

// Explicit non-Apple boundary: value storage and Binding callbacks only.
// The driver inserts the COMPLETE actual binding, updatePanelPresentation and
// toggleStudyPanel bodies; it also inserts original closeReaderInspector.
// This fixture does not claim SwiftUI mounting, animation, UIKit or Native ACK.
@propertyWrapper
final class State<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
}
struct Animation {
    static func spring(response: Double, dampingFraction: Double, blendDuration: Double) -> Self { .init() }
}
func withAnimation(_ animation: Animation, _ body: () -> Void) { body() }
enum FloatingState { case hidden, half }
final class OriginalReaderCloseBoundary {
    var otzariaSourcesLoadTask: Task<Void, Never>?
    var readerInspectorVisible = false
    var selectedSegmentLocator: String? = "original-locator"
    var otzariaSelectedLineAnchor: String? = "original-anchor"
    var otzariaLinkedSources = ["original-link"]
    var otzariaSourcesIsLoading = true
    var otzariaSourcesError: String? = "original-error"
    var resetCount = 0
    func resetOtzariaSourcesPanelNavigation() { resetCount += 1 }
    func closeReaderInspector() {
        otzariaSourcesLoadTask?.cancel()
        otzariaSourcesLoadTask = nil
        readerInspectorVisible = false
        selectedSegmentLocator = nil
        otzariaSelectedLineAnchor = nil
        otzariaLinkedSources = []
        otzariaSourcesIsLoading = false
        otzariaSourcesError = nil
        resetOtzariaSourcesPanelNavigation()
    }
}
struct StudySheetOwnerBoundary {
    @State var nativeStudyPresentation = NativeStudySheetPresentationState()
    let viewModel = OriginalReaderCloseBoundary()
    var showPanel: Bool { viewModel.readerInspectorVisible }
    var usesNativeStudySheet = true
    @State var showPanelSheet = false
    @State var floatingPanelState: FloatingState? = .hidden
    var shouldPresentPanelInContent = false
    var sidebarCoordinator: Int? = nil
    var useWideLayout = true
    @State var pendingNotesDidChange: (() -> Void)? = nil
    @State var editingNote: String? = nil
    func setEditingAnnotation(_ value: String?) { editingNote = value }
    private var nativeStudyBinding: Binding<NativeStudySheetPresentationState.Presentation?> {
        let id = nativeStudyPresentation.presentation?.id
        return Binding(
            get: { usesNativeStudySheet ? nativeStudyPresentation.presentedItem : nil },
            set: { value in
                guard value == nil, nativeStudyPresentation.presentation?.id == id else { return }
                nativeStudyPresentation.requestDismissal()
            }
        )
    }
    private func updatePanelPresentation(animated: Bool = true) {
        let updates = {
            if usesNativeStudySheet {
                showPanelSheet = false
                floatingPanelState = .hidden
                if showPanel {
                    nativeStudyPresentation.requestStudy()
                } else {
                    nativeStudyPresentation.requestDismissal()
                    if let note = nativeStudyPresentation.note,
                       case .study = note.host {
                        setEditingAnnotation(nil)
                        pendingNotesDidChange = nil
                    }
                }
            } else if !showPanel {
                showPanelSheet = false
                floatingPanelState = .hidden
            } else if shouldPresentPanelInContent {
                showPanelSheet = false
                if floatingPanelState == nil || floatingPanelState == .hidden {
                    floatingPanelState = .half
                }
            } else if sidebarCoordinator != nil || useWideLayout {
                showPanelSheet = false
                floatingPanelState = .hidden
            } else {
                floatingPanelState = .hidden
                showPanelSheet = true
            }
        }

        if animated {
            let animation = showPanel
                ? Animation.spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08)
                : Animation.spring(response: 0.34, dampingFraction: 0.96, blendDuration: 0.05)
            withAnimation(animation) {
                updates()
            }
        } else {
            updates()
        }
    }
    private func toggleStudyPanel() {
        if showPanel {
            viewModel.closeReaderInspector()
        } else {
            viewModel.readerInspectorVisible = true
        }
    }
    private func nativeStudyDidDismiss(id: UUID) {
        guard nativeStudyPresentation.presentation?.id == id else { return }
        // A completed parent dismissal also proves any child presentation ended.
        // The exact child UUID makes a later child callback harmless.
        if let note = nativeStudyPresentation.note, note.host == .study(id) {
            setEditingAnnotation(nil)
            pendingNotesDidChange = nil
            noteEditorDidDismiss(presentationID: note.id, fromParentDismissal: true)
        }
        guard let result = nativeStudyPresentation.studyDidDismiss(id: id) else { return }
        #if DEBUG
        nativeStudyAcceptance.didDismissStudy(id)
        #endif
        if !result.studyStillRequested, showPanel { viewModel.closeReaderInspector() }
        if result.showContents { presentContents() }
    }
    func noteEditorDidDismiss(presentationID: UUID, fromParentDismissal: Bool) { preconditionFailure("Child callbacks have separate actual lifecycle controls") }
    func presentContents() { preconditionFailure("TOC is covered by real Native and the separate lifecycle controls") }
    func originalDidDismiss(_ id: UUID) { nativeStudyDidDismiss(id: id) }
    func actualBinding() -> Binding<NativeStudySheetPresentationState.Presentation?> { nativeStudyBinding }
    func originalOpenAction() { toggleStudyPanel(); updatePanelPresentation(animated: false) }
    func originalLayoutCallback() { updatePanelPresentation(animated: false) }
}
