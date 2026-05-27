import SwiftUI

struct iOSHistoryView: View {
    @StateObject private var viewModel = HistoryViewModel.shared
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager

    var body: some View {
        let filteredFavorites = viewModel.filteredFavorites
        let filteredHistory = viewModel.filteredHistory

        ThemeList(isGrouped: true) {
            if !filteredFavorites.isEmpty {
                Section(header: Text("Favorites")) {
                    ForEach(filteredFavorites, id: \.id) { book in
                        BookRowView(book: book, isFavorite: true, viewModel: viewModel) {
                            let lastId = viewModel.entriesByBookId[book.id]?.lastContentId
                            navigationManager.openBook(book, initialContentId: lastId)
                        }
                    }
                    .onDelete(perform: removeFavorite)
                }
            }

            if !filteredHistory.isEmpty {
                Section(header: Text("History")) {
                    ForEach(filteredHistory, id: \.id) { book in
                        BookRowView(book: book, isFavorite: viewModel.favoriteBookIds.contains(book.id), viewModel: viewModel) {
                            let lastId = viewModel.entriesByBookId[book.id]?.lastContentId
                            navigationManager.openBook(book, initialContentId: lastId)
                        }
                    }
                    .onDelete(perform: removeHistory)
                }
            } else if filteredFavorites.isEmpty {
                if !viewModel.searchText.isEmpty {
                    Text("No results found for \"\(viewModel.searchText)\"")
                        .foregroundColor(.secondary)
                } else {
                    Text("No recent history")
                        .foregroundColor(.secondary)
                }
            }
        }
        .refreshable {
            CloudKitSyncManager.shared.fetchChanges()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        .withActiveIntegrationStates()
        .navigationTitle("History & Favorites")
    }

    private func removeFavorite(at offsets: IndexSet) {
        for index in offsets {
            let book = viewModel.favoriteBooks[index]
            viewModel.toggleFavorite(book.id)
        }
    }

    private func removeHistory(at offsets: IndexSet) {
        for index in offsets {
            let book = viewModel.historyBooks[index]
            viewModel.removeHistory(for: book.id)
        }
    }
}

struct BookRowView: View {
    let book: BooksData
    let isFavorite: Bool
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(book.book)
                    .font(iOSReaderViewModel.kfgqpc)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    viewModel.toggleFavorite(book.id)
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
                .accessibilityLabel(isFavorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                .help(isFavorite ? String(localized: "Remove Favorite") : String(localized: "Add Favorite"))
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Rectangle())
        }
    }
}

struct iOSAddFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HistoryViewModel
    @State private var searchText = ""
    @State private var searchViewModel = iOSSearchViewModel()

    var body: some View {
        NavigationStack {
            SearchFilterUIKitView(
                viewModel: searchViewModel,
                displayedCategories: searchViewModel.displayedCategories,
                updateTrigger: searchViewModel.updateTrigger
            )
            .ignoresSafeArea(edges: [.vertical])
            .navigationTitle("Select Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search Books")
            .onChange(of: searchText) { _, newValue in
                searchViewModel.filterText = newValue
                searchViewModel.updateDisplayedCategories()
            }
            .onAppear {
                searchViewModel.selectedBookIds = Set(viewModel.favoriteBookIds)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let newFavs = searchViewModel.selectedBookIds
                        let currentFavs = Set(viewModel.favoriteBookIds)
                        for id in newFavs.subtracting(currentFavs) {
                            viewModel.toggleFavorite(id)
                        }
                        for id in currentFavs.subtracting(newFavs) {
                            viewModel.toggleFavorite(id)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .themeTint()
    }
}
