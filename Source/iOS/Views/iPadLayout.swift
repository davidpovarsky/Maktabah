//
//  iPadLayout.swift
//  Maktabah-iOS
//

import SwiftUI

struct iPadLayout: View {
    private enum DetailMode {
        case reader
        case otzariaTextSearch
        case zayitSearch
    }

    @Bindable var bManager: iOSNavigationManager
    @Binding var selectedTab: iOSTab
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showSettings: Bool

    @State private var showingSearchHelp = false
    @State private var showingAddFavorites = false
    @State private var path: [iOSTab] = []
    @State private var detailMode: DetailMode = .reader
    @State private var showingZayitReader = false
    @State private var showingOtzariaReader = false

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
            detailContent
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: historyViewModel)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private var sidebarContent: some View {
        ThemeList(isGrouped: true) {
            Section {
                ForEach(iOSTab.allCases.filter {
                    $0 != .history && $0 != .zayitSearch && $0 != .otzariaTextSearch
                }) { tab in
                    if tab == .search {
                        Button {
                            transitionSidebar(to: tab)
                        } label: {
                            Label(tab.title, systemImage: tab.icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(Text(tab.title))
                    } else {
                        Button {
                            selectSidebar(tab)
                        } label: {
                            Label(tab.title, systemImage: tab.icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
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
                            prepareReaderDetail()
                            let lastId = historyViewModel.entriesByBookId[
                                book.id
                            ]?.lastContentId
                            detailMode = .reader
                            showingZayitReader = false
                            showingOtzariaReader = false
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
                            prepareReaderDetail()
                            let lastId = historyViewModel.entriesByBookId[
                                book.id
                            ]?.lastContentId
                            detailMode = .reader
                            showingZayitReader = false
                            showingOtzariaReader = false
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
    private var detailContent: some View {
        switch detailMode {
        case .reader:
            iOSReaderTabView(columnVisibility: $columnVisibility)
        case .otzariaTextSearch:
            NavigationStack {
                UnifiedSearchWorkspaceView(
                    openOtzaria: { item, descriptor in
                        guard let book = LibraryDataManager.shared.getBook([item.bookId]).first else { return }
                        bManager.openBook(
                            book,
                            initialContentId: item.page,
                            searchText: descriptor.readerFallback
                        )
                        showingOtzariaReader = true
                    },
                    openZayit: { hit, _ in
                        if ZayitSearchReaderNavigationAdapter.open(hit, using: bManager) {
                            showingOtzariaReader = true
                        }
                    }
                )
                .navigationDestination(isPresented: $showingOtzariaReader) {
                    iOSReaderTabView(columnVisibility: $columnVisibility)
                }
            }
        case .zayitSearch:
            NavigationStack {
                ZayitSearchView(
                    existingSeforimDB: {
                        ZayitSearchExistingDatabaseProvider.currentURL
                    },
                    openResult: { hit in
                        if ZayitSearchReaderNavigationAdapter.open(
                            hit,
                            using: bManager
                        ) {
                            showingZayitReader = true
                        }
                    }
                )
                .navigationDestination(isPresented: $showingZayitReader) {
                    iOSReaderTabView(columnVisibility: $columnVisibility)
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
                // Otzaria Search is presented in the split view's detail column.
                EmptyView()
            case .zayitSearch:
                // Zayit Search is presented in the split view's detail column.
                EmptyView()
            case .search:
                // Unified search is presented in the split view's detail column.
                EmptyView()
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
            if tab != .zayitSearch && tab != .otzariaTextSearch {
                detailMode = .reader
                showingZayitReader = false
                showingOtzariaReader = false
            }
            if selectedTab != tab {
                selectedTab = tab
                bManager.switchToMode(tab.appMode)
            }
        }
    }

    private func selectSidebar(_ tab: iOSTab) {
        transitionSidebar(to: tab)
    }

    private func transitionSidebar(to tab: iOSTab) {
        // Every sidebar transition clears the complete author/detail route in
        // one transaction. This prevents value-less nested NavigationLinks
        // from surviving after the selected section changes.
        path.removeAll()
        showingZayitReader = false
        showingOtzariaReader = false
        sidebarSearchText = ""
        bManager.authorViewModel.currentRowi = nil
        bManager.authorViewModel.searchText = ""
        selectedTab = tab
        bManager.switchToMode(tab.appMode)
        if tab == .otzariaTextSearch || tab == .search {
            detailMode = .otzariaTextSearch
        } else {
            detailMode = .reader
            path = [tab]
        }
    }

    private func prepareReaderDetail() {
        bManager.authorViewModel.currentRowi = nil
        showingZayitReader = false
        showingOtzariaReader = false
        detailMode = .reader
    }
}
