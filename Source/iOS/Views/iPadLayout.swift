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

    @StateObject private var historyViewModel = HistoryViewModel.shared

    // Sidebar search tetap lokal — dipakai hanya untuk filter sidebar (Favorites & History)
    @State private var sidebarSearchText: String = ""

    private var filteredFavorites: [BooksData] {
        if sidebarSearchText.isEmpty || !path.isEmpty {
            return historyViewModel.favoriteBooks
        }
        return historyViewModel.favoriteBooks.filter {
            $0.book.normalizeArabic(false).contains(
                sidebarSearchText.normalizeArabic(false)
            )
        }
    }

    private var filteredHistory: [BooksData] {
        if sidebarSearchText.isEmpty || !path.isEmpty {
            return historyViewModel.historyBooks
        }
        return historyViewModel.historyBooks.filter {
            $0.book.normalizeArabic(false).contains(
                sidebarSearchText.normalizeArabic(false)
            )
        }
    }

    private func searchPrompt(for tab: iOSTab) -> String {
        switch tab {
        case .viewer: String(localized: "Search Library")
        case .otzariaTextSearch: String(localized: "Search Otzaria Texts")
        case .zayitSearch: String(localized: "Search Zayit Index")
        case .search: String(localized: "Filter Books to Search")
        case .author: String(localized: "Search Narrators")
        case .annotations: String(localized: "Search Annotations")
        case .history: String(localized: "Search History & Favorites")
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack(path: $path) {
                sidebarContent
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $sidebarSearchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search Favorites & History".localized
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gear")
                            }
                            .accessibilityLabel(String(localized: "Settings"))
                            .help(String(localized: "Settings"))
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showingAddFavorites = true }) {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel(
                                String(localized: "Add Favorite")
                            )
                            .help(String(localized: "Add Favorite"))
                        }
                    }
                    .withActiveIntegrationStates()
                    .navigationDestination(for: iOSTab.self) { tab in
                        destinationView(for: tab)
                    }
            }
        } detail: {
            iOSReaderTabView(columnVisibility: $columnVisibility)
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: historyViewModel)
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        ThemeList(isGrouped: true) {
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
                        BookRowView(
                            book: book,
                            isFavorite: true,
                            viewModel: historyViewModel
                        ) {
                            let lastId = historyViewModel.entriesByBookId[
                                book.id
                            ]?.lastContentId
                            bManager.openBook(book, initialContentId: lastId)
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
                            isFavorite: historyViewModel.favoriteBookIds
                                .contains(book.id),
                            viewModel: historyViewModel
                        ) {
                            let lastId = historyViewModel.entriesByBookId[
                                book.id
                            ]?.lastContentId
                            bManager.openBook(book, initialContentId: lastId)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let book = filteredHistory[index]
                            historyViewModel.removeHistory(for: book.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for tab: iOSTab) -> some View {
        @Bindable var libraryVM = bManager.libraryViewModel
        @Bindable var searchVM = bManager.searchViewModel
        @Bindable var authorVM = bManager.authorViewModel
        @Bindable var annotationVM = bManager.annotationViewModel

        Group {
            switch tab {
            case .viewer:
                iOSLibraryView()
                    .searchable(
                        text: $libraryVM.searchQuery,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt(for: tab).localized
                    )
            case .otzariaTextSearch:
                OtzariaTextSearchView()
            case .zayitSearch:
                ZayitSearchView(
                    existingSeforimDB: {
                        ZayitSearchExistingDatabaseProvider.currentURL
                    },
                    openResult: { hit in
                        ZayitSearchReaderNavigationAdapter.open(hit, using: bManager)
                    }
                )
            case .search:
                SearchModeView()
                    .searchable(
                        text: $searchVM.filterText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt(for: tab).localized
                    )
            case .author:
                AuthorModeView(onOpenBook: { book in
                    bManager.openBook(book)
                })
                    .searchable(
                        text: $authorVM.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt(for: tab).localized
                    )
            case .annotations:
                AnnotationListView()
                    .searchable(
                        text: $annotationVM.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt(for: tab).localized
                    )
                    .searchScopes($annotationVM.searchScope) {
                        ForEach(AnnotationSearchScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
            case .history:
                EmptyView()
            }
        }
        .navigationTitle(tab.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if selectedTab != tab {
                selectedTab = tab
                bManager.switchToMode(tab.appMode)
            }
        }
    }
}
