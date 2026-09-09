#if os(iOS)
import SwiftUI
import TorahInspectorCore
import TorahInspectorUI

struct OtzariaReaderSourcesInspectorHost: View {
    var viewModel: ReaderViewModel
    var navigationManager: iOSNavigationManager
    @ObservedObject private var backendCoordinator = BackendCoordinator.shared
    @State private var inspectorSession = MaktabahTorahInspectorSession()

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
                onClose: {
                    viewModel.closeReaderInspector()
                },
                onOpenInNewTab: { selection in
                    guard let locator = inspectorSession.locator(for: selection) else { return }
                    navigationManager.openTorahInspectorLocationInNewTab(locator)
                }
            )
            .id("\(backendCoordinator.generation):\(selection.id)")
            .onChange(of: backendCoordinator.generation) { _, _ in
                inspectorSession = MaktabahTorahInspectorSession()
                viewModel.closeReaderInspector()
            }
        } else {
            EmptyView()
        }
    }
}
#endif
