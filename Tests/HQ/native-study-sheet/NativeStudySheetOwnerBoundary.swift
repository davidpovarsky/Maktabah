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
    // ORIGINAL_CLOSE_BODY
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
    // ORIGINAL_BINDING_BODY
    // ORIGINAL_UPDATE_BODY
    // ORIGINAL_TOGGLE_BODY
    // ORIGINAL_DISMISS_BODY
    func noteEditorDidDismiss(presentationID: UUID, fromParentDismissal: Bool) { preconditionFailure("Child callbacks have separate actual lifecycle controls") }
    func presentContents() { preconditionFailure("TOC is covered by real Native and the separate lifecycle controls") }
    func originalDidDismiss(_ id: UUID) { nativeStudyDidDismiss(id: id) }
    func actualBinding() -> Binding<NativeStudySheetPresentationState.Presentation?> { nativeStudyBinding }
    func originalOpenAction() { toggleStudyPanel(); updatePanelPresentation(animated: false) }
    func originalLayoutCallback() { updatePanelPresentation(animated: false) }
}
