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
    let chrome: TorahInspectorChrome
    var contentID: UUID = UUID()
    let onAddNote: ((TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onOpenNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    let onDeleteNote: ((TorahInspectorNote, TorahInspectorSelection, @escaping TorahInspectorHostActions.NotesDidChange) -> Void)?
    var nativeSheet: NativeStudySheetContent? = nil
    @ObservedObject private var backendCoordinator = BackendCoordinator.shared

    var body: some View {
        @Bindable var viewModel = viewModel

        if viewModel.readerInspectorVisible,
           let selection = inspectorSession.selection(
                sefariaLocator: viewModel.selectedSegmentLocator,
                otzariaLine: viewModel.otzariaSelectedLineAnchor
           ) {
            presentedInspector(selection: selection)
            .id("\(backendCoordinator.generation):\(viewModel.currentReaderTextMode.rawValue):\(contentID)")
            .modifier(MaktabahNativeRoutingSurface(kind: .inspector, inspectorReader: viewModel))
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

    @ViewBuilder
    private func presentedInspector(selection: TorahInspectorSelection) -> some View {
        if let nativeSheet {
            ZStack(alignment: .top) {
                // Never remove/recreate the Kit at a detent boundary. Its
                // private NavigationStack and expanded source state stay owned
                // by this exact Reader/session/contentID.
                originalInspector(selection: selection)
                    .opacity(nativeSheet.isPeek ? 0 : 1)
                    .allowsHitTesting(!nativeSheet.isPeek)
                    .accessibilityHidden(nativeSheet.isPeek)
                if nativeSheet.isPeek {
                    NativeStudySheetPeek(content: nativeSheet, selectedTool: selectedTool,
                        close: closeOriginalInspector)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else {
            originalInspector(selection: selection)
        }
    }

    private func originalInspector(selection: TorahInspectorSelection) -> some View {
        TorahInspectorUI.TorahInspectorView(
                repository: inspectorSession.repository,
                selection: selection,
                entryMode: .relationships,
                chrome: chrome,
                selectedTool: $selectedTool,
                presentationOptions: nativeSheet != nil
                    ? .init(showsStudyToolsTitle: false, showsSelectedSegmentTitle: false, usesMinimalChrome: true)
                    : (ChavrusaTextReaderUI.isEnabled
                        ? .init(showsStudyToolsTitle: false, showsSelectedSegmentTitle: false)
                        : .init()),
                onClose: closeOriginalInspector,
                onOpenInNewTab: { selection in
                    guard let locator = inspectorSession.locator(for: selection) else { return }
                    navigationManager.openTorahInspectorLocationInNewTab(locator)
                },
                onAddNote: onAddNote,
                onOpenNote: onOpenNote,
                onDeleteNote: onDeleteNote,
                showsCloseButton: showsCloseButton
            )
    }

    private func closeOriginalInspector() {
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeInspector] originalClose invoked visible=\(viewModel.readerInspectorVisible)")
        #endif
        viewModel.closeReaderInspector()
        #if DEBUG
        OtzariaFileLogger.shared.log("[NativeInspector] originalClose returned visible=\(viewModel.readerInspectorVisible)")
        #endif
    }
}
#endif
