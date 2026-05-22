import SwiftUI

struct iOSHistoryView: View {
    @StateObject private var viewModel = iOSHistoryViewModel.shared
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager

    var body: some View {
        List {
            if !viewModel.favoriteBooks.isEmpty {
                Section(header: Text("Favorites")) {
                    ForEach(viewModel.favoriteBooks, id: \.id) { book in
                        BookRowView(book: book, isFavorite: true, viewModel: viewModel) {
                            navigationManager.openBook(book, initialContentId: viewModel.lastContentId(for: book.id))
                        }
                    }
                    .onDelete(perform: removeFavorite)
                }
            }

            if !viewModel.historyBooks.isEmpty {
                Section(header: Text("History")) {
                    ForEach(viewModel.historyBooks, id: \.id) { book in
                        BookRowView(book: book, isFavorite: viewModel.favoriteBookIds.contains(book.id), viewModel: viewModel) {
                            navigationManager.openBook(book, initialContentId: viewModel.lastContentId(for: book.id))
                        }
                    }
                    .onDelete(perform: removeHistory)
                }
            } else if viewModel.favoriteBooks.isEmpty {
                Text("No recent history")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .withActiveIntegrationStates()
        .navigationTitle("History & Favorites")
        .onAppear {
            viewModel.loadBooksData()
        }
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
            viewModel.removeHistory(book.id)
        }
    }
}

struct BookRowView: View {
    let book: BooksData
    let isFavorite: Bool
    @ObservedObject var viewModel: iOSHistoryViewModel
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
                .buttonStyle(PlainButtonStyle())
            }
            .contentShape(Rectangle())
        }
    }
}

struct iOSAddFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: iOSHistoryViewModel
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
                            viewModel.favoriteBookIds = Array(searchViewModel.selectedBookIds)
                            viewModel.saveToUserDefaults()
                            viewModel.loadBooksData()
                            dismiss()
                        }
                        .fontWeight(.bold)
                    }
                }
        }
    }
}
