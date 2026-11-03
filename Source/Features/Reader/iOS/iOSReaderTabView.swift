import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    var sidebarCoordinator: ReaderSidebarStateCoordinator?
    @State private var fallbackSidebarCoordinator = ReaderSidebarStateCoordinator()

    init(
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all),
        preferredCompactColumn: Binding<NavigationSplitViewColumn> = .constant(.detail),
        sidebarCoordinator: ReaderSidebarStateCoordinator? = nil
    ) {
        self._columnVisibility = columnVisibility
        self._preferredCompactColumn = preferredCompactColumn
        self.sidebarCoordinator = sidebarCoordinator
    }

    private var activeTab: iOSNavigationManager.ReaderTab? {
        bManager.openTabs.first(where: { $0.id == bManager.activeTabId }) ?? bManager.openTabs.first
    }

    private var isRegularLayout: Bool {
        horizontalSizeClass == .regular
    }

    @ViewBuilder
    private var coreReaderContent: some View {
        Group {
            if let activeTab {
                iOSReaderWorkspaceView(
                    book: activeTab.book,
                    viewModel: activeTab.viewModel,
                    initialContentId: activeTab.initialContentId,
                    libraryColumnVisibility: $columnVisibility,
                    preferredCompactColumn: $preferredCompactColumn
                )
                .id(activeTab.id)
                .toolbar {
                    if isRegularLayout, bManager.openTabs.count > 1 {
                        if !ChavrusaTextFeatureFlags.shared.effectiveDuckTabStripEnabled {
                            ToolbarItem(placement: .principal) {
                                ReaderTabsView()
                            }
                        }
                    } else if bManager.openTabs.count > 1 {
                        ToolbarItem(placement: .topBarTrailing) {
                            ReaderTabsView()
                        }
                    }
                }
            } else {
                ThemeView {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text(.Library.selectBookToRead)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    var body: some View {
        let coordinator = sidebarCoordinator ?? fallbackSidebarCoordinator
        if isRegularLayout, ChavrusaTextFeatureFlags.shared.hasAnyReaderChromeUpgradeEnabled {
            ReaderWorkspaceChromeHost(sidebarCoordinator: coordinator) {
                coreReaderContent
            }
        } else {
            coreReaderContent
        }
    }
}
