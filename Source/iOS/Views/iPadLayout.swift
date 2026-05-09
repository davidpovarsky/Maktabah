//
//  iPadLayout.swift
//  Maktabah-iOS
//

import SwiftUI

struct iPadLayout: View {
    @Bindable var bManager: iOSNavigationManager
    @Binding var selectedTab: iOSTab
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showSettings: Bool
    
    @State private var showingSearchHelp = false
    @State private var showingAddFavorites = false
    @State private var path: [iOSTab] = []
    
    @StateObject private var historyViewModel = iOSHistoryViewModel.shared

    private var filteredFavorites: [BooksData] {
        if bManager.searchText.isEmpty || !path.isEmpty {
            return historyViewModel.favoriteBooks
        }
        return historyViewModel.favoriteBooks.filter {
            $0.book.localizedCaseInsensitiveContains(bManager.searchText)
        }
    }

    private var filteredHistory: [BooksData] {
        if bManager.searchText.isEmpty || !path.isEmpty {
            return historyViewModel.historyBooks
        }
        return historyViewModel.historyBooks.filter {
            $0.book.localizedCaseInsensitiveContains(bManager.searchText)
        }
    }

    private func searchPrompt(for tab: iOSTab) -> String {
        switch selectedTab {
        case .viewer: String(localized: "Search Library")
        case .search: String(localized: "Filter Books to Search")
        case .author: String(localized: "Search Narrators")
        case .annotations: String(localized: "Search Annotations")
        case .history: String(localized: "Search History & Favorites")
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack(path: $path) {
                List {
                    Section {
                        ForEach(iOSTab.allCases.filter { $0 != .history }) { tab in
                            NavigationLink(value: tab) {
                                Label(tab.title, systemImage: tab.icon)
                            }
                            .foregroundStyle(.primary)
                        }
                    }

                    if !filteredFavorites.isEmpty {
                        Section(header: Text("Favorites".localized)) {
                            ForEach(filteredFavorites, id: \.id) { book in
                                BookRowView(book: book, isFavorite: true, viewModel: historyViewModel) {
                                    bManager.openBook(book)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    let book = filteredFavorites[index]
                                    historyViewModel.toggleFavorite(book.id)
                                }
                            }
                        }
                    }

                    if !filteredHistory.isEmpty {
                        Section(header: Text("History".localized)) {
                            ForEach(filteredHistory, id: \.id) { book in
                                BookRowView(
                                    book: book,
                                    isFavorite: historyViewModel.favoriteBookIds.contains(book.id),
                                    viewModel: historyViewModel
                                ) {
                                    bManager.openBook(book)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    let book = filteredHistory[index]
                                    historyViewModel.removeHistory(book.id)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .listStyle(.insetGrouped)
                .searchable(text: $bManager.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Favorites & History".localized)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showingAddFavorites = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .navigationDestination(for: iOSTab.self) { tab in
                    destinationView(for: tab)
                }
            }
        } detail: {
            iOSReaderTabView()
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: historyViewModel)
        }
        .onAppear {
            historyViewModel.loadBooksData()
        }
    }

    @ViewBuilder
    private func destinationView(for tab: iOSTab) -> some View {
        Group {
            switch tab {
            case .viewer:
                iOSLibraryView()
            case .search:
                SearchModeView()
            case .author:
                AuthorModeView()
            case .annotations:
                AnnotationListView()
            case .history:
                EmptyView()
            }
        }
        .navigationTitle(tab.title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $bManager.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt(for: tab).localized)
        .onAppear {
            if selectedTab != tab {
                selectedTab = tab
                bManager.switchToMode(tab.appMode)
            }
        }
    }
}
