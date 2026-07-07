import SwiftUI

#if os(iOS)
struct OtzariaSourcesSplitColumn: View {
    @Environment(iOSNavigationManager.self) private var navigationManager

    private var activeReaderViewModel: ReaderViewModel? {
        if let activeTabId = navigationManager.activeTabId {
            return navigationManager.openTabs.first(where: { $0.id == activeTabId })?.viewModel
                ?? navigationManager.openTabs.first?.viewModel
        }
        return navigationManager.openTabs.first?.viewModel
    }

    var body: some View {
        if let viewModel = activeReaderViewModel,
           viewModel.otzariaSourcesInspectorVisible {
            OtzariaReaderSourcesInspectorHost(
                viewModel: viewModel,
                navigationManager: navigationManager
            )
        } else {
            EmptyView()
        }
    }
}
#endif
