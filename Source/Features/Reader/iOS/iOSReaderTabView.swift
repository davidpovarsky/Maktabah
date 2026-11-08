import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var preferredCompactColumn: NavigationSplitViewColumn
    let showsLegacyDocumentTabs: Bool

    init(
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all),
        preferredCompactColumn: Binding<NavigationSplitViewColumn> = .constant(.detail),
        showsLegacyDocumentTabs: Bool = true
    ) {
        self._columnVisibility = columnVisibility
        self._preferredCompactColumn = preferredCompactColumn
        self.showsLegacyDocumentTabs = showsLegacyDocumentTabs
    }

    private var activeTab: iOSNavigationManager.ReaderTab? {
        bManager.openTabs.first(where: { $0.id == bManager.activeTabId }) ?? bManager.openTabs.first
    }

    private var isRegularLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
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
                    if showsLegacyDocumentTabs, isRegularLayout, bManager.openTabs.count > 1 {
                        ToolbarItem(placement: .principal) {
                            ReaderTabsView()
                        }
                    } else if showsLegacyDocumentTabs, bManager.openTabs.count > 1 {
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
}
