import SwiftUI

struct iOSReaderTabView: View {
    @Environment(iOSNavigationManager.self) var bManager
    @Binding var columnVisibility: NavigationSplitViewVisibility

    init(columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all)) {
        self._columnVisibility = columnVisibility
    }

    private var activeTab: iOSNavigationManager.ReaderTab? {
        bManager.openTabs.first(where: { $0.id == bManager.activeTabId }) ?? bManager.openTabs.first
    }

    var body: some View {
        Group {
            if let activeTab {
                iOSReaderWorkspaceView(
                    book: activeTab.book,
                    viewModel: activeTab.viewModel,
                    initialContentId: activeTab.initialContentId,
                    libraryColumnVisibility: $columnVisibility
                )
                .id(activeTab.id)
                .toolbar {
                    if bManager.openTabs.count > 1 {
                        ToolbarItem(placement: .topBarTrailing) {
                            ReaderTabsView(isDarkMode: TextViewState.shared.isDarkMode)
                        }
                    }
                }
            } else {
                ThemeView {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Select a book to read")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    let bManager = iOSNavigationManager()
    let book1 = BooksData(id: 1, book: "صحيح البخاري", archive: 1, muallif: 1)
    let book2 = BooksData(id: 2, book: "صحيح المسلم", archive: 1, muallif: 2)

    let tab1 = iOSNavigationManager.ReaderTab(id: UUID(), book: book1, initialContentId: nil, viewModel: ReaderViewModel(book: book1))
    let tab2 = iOSNavigationManager.ReaderTab(id: UUID(), book: book2, initialContentId: nil, viewModel: ReaderViewModel(book: book2))

    bManager.openTabs = [tab1, tab2]
    bManager.activeTabId = tab1.id
    bManager.selectedBook = book1

    return iOSReaderTabView()
        .environment(bManager)
}
