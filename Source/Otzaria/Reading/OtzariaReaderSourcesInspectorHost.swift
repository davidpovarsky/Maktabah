import SwiftUI

#if os(iOS)
struct OtzariaReaderSourcesInspectorHost: View {
    var viewModel: ReaderViewModel
    var navigationManager: iOSNavigationManager
    var onClose: (() -> Void)?

    var body: some View {
        @Bindable var viewModel = viewModel

        if viewModel.otzariaSourcesInspectorVisible {
            OtzariaLineSourcesInspectorView(
                selectedLine: viewModel.otzariaSelectedLineAnchor,
                sources: viewModel.otzariaLinkedSources,
                isLoading: viewModel.otzariaSourcesIsLoading,
                error: viewModel.otzariaSourcesError,
                isPresented: viewModel.otzariaSourcesInspectorVisible,
                selectedGroupID: $viewModel.otzariaSourcesSelectedGroupID,
                selectedBookID: $viewModel.otzariaSourcesSelectedBookID,
                expandedSourceIDs: $viewModel.otzariaSourcesExpandedSourceIDs,
                onClose: {
                    if let onClose {
                        onClose()
                    } else {
                        viewModel.closeOtzariaSourcesInspector()
                    }
                },
                onOpenSource: { source in
                    navigationManager.openOtzariaLinkedSourceInNewTab(source)
                }
            )
        } else {
            EmptyView()
        }
    }
}
#endif
