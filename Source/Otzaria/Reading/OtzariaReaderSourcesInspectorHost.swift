#if os(iOS)
import SwiftUI
import TorahInspectorCore
import TorahInspectorUI

struct OtzariaReaderSourcesInspectorHost: View {
    var viewModel: ReaderViewModel
    var navigationManager: iOSNavigationManager
    @Binding var inspectorSession: MaktabahTorahInspectorSession
    @Binding var selectedTool: TorahStudyTool
    let showsCloseButton: Bool
    let onAddNote: ((TorahInspectorSelection, TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, TorahInspectorHostActions.NotesDidChange) -> Void)?
    @ObservedObject private var backendCoordinator = BackendCoordinator.shared

    var body: some View {
        @Bindable var viewModel = viewModel

        if viewModel.readerInspectorVisible,
           let selection = inspectorSession.selection(
                sefariaLocator: viewModel.selectedSegmentLocator,
                otzariaLine: viewModel.otzariaSelectedLineAnchor
           ) {
            TorahInspectorUI.TorahInspectorView(
                repository: inspectorSession.repository,
                selection: selection,
                entryMode: .segmentRelationships,
                selectedTool: $selectedTool,
                onClose: {
                    viewModel.closeReaderInspector()
                },
                onOpenInNewTab: { selection in
                    guard let locator = inspectorSession.locator(for: selection) else { return }
                    navigationManager.openTorahInspectorLocationInNewTab(locator)
                },
                onAddNote: onAddNote,
                onOpenNote: onOpenNote,
                onDeleteNote: onDeleteNote,
                showsCloseButton: showsCloseButton
            )
            .id("\(backendCoordinator.generation):\(viewModel.currentReaderTextMode.rawValue)")
            .onChange(of: backendCoordinator.generation) { _, _ in
                inspectorSession = MaktabahTorahInspectorSession(viewModel: viewModel)
                viewModel.closeReaderInspector()
            }
            .onChange(of: viewModel.currentReaderTextMode) { _, mode in
                inspectorSession = MaktabahTorahInspectorSession(
                    viewModel: viewModel,
                    preferredMode: mode
                )
            }
        } else {
            EmptyView()
        }
    }
}
#endif
