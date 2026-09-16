//
//  iPadLayout.swift
//  Maktabah-iOS
//

import SwiftUI

struct iPadLayout: View {
    private enum DetailMode {
        case reader
        case search
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
    @ObservedObject private var donationManager = DonationManager.shared

    /// Sidebar search tetap lokal — dipakai hanya untuk filter sidebar (Favorites & History)
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
        switch tab.canonical {
        case .viewer: String(localized: "Search Library")
        case .search: String(localized: "Filter Books to Search")
        case .author: String(localized: "Search Narrators")
        case .annotations: String(localized: "Search Annotations")
        case .history: String(localized: "Search History & Favorites")
        default: String(localized: "Filter Books to Search")
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
        .onReceive(NotificationCenter.default.publisher(for: .activeLibraryBackendDidChange)) { _ in
            if detailMode == .search && !BackendCoordinator.shared.capabilities.contains(.search) {
                transitionSidebar(to: .viewer)
            }
        }
        .onChange(of: bManager.currentMode) { _, newMode in
            if newMode == .viewer {
                prepareReaderDetail()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            let canonical = newTab.canonical
            let alreadyInDetail = (canonical == .search && detailMode == .search)
            if path.first != canonical && !alreadyInDetail {
                transitionSidebar(to: canonical)
            }
        }
        .onAppear {
            if path.isEmpty && selectedTab == .viewer {
                transitionSidebar(to: .viewer)
            }
        }
    }

    private var sidebarContent: some View {
        ThemeList(isGrouped: true) {
            Section {
                let visibleTabs = iOSTab.allCases.filter { tab in
                    if tab == .history { return false }
                    if tab == .search && !BackendCoordinator.shared.capabilities.contains(.search) { return false }
                    return true
                }
                ForEach(visibleTabs) { tab in
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
                            historyViewModel.toggleFavorite(book)
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
                            historyViewModel.removeHistory(for: book)
                        }
                    }
                }
            }


            if donationManager.shouldShowDonation {
                Section {
                    DonationHistoryButton {
                        donationManager.showDonationSheet = true
                    }
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch detailMode {
        case .reader:
            iOSReaderTabView(columnVisibility: $columnVisibility)
        case .search:
            NavigationStack {
                SearchModeView()
                    .navigationTitle(iOSTab.search.title)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for tab: iOSTab) -> some View {
        @Bindable var libraryVM = bManager.libraryViewModel
        @Bindable var authorVM = bManager.authorViewModel
        @Bindable var annotationVM = bManager.annotationViewModel

        Group {
            switch tab.canonical {
            case .viewer:
                iOSLibraryView()
                    .searchable(
                        text: $libraryVM.searchQuery,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt(for: tab).localized
                    )
            case .search:
                // Search is presented in the split view's detail column.
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
            default:
                EmptyView()
            }
        }
        .navigationTitle(tab.canonical.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            let canonical = tab.canonical
            if canonical != .search {
                detailMode = .reader
                showingZayitReader = false
                showingOtzariaReader = false
            }
            if selectedTab != canonical {
                selectedTab = canonical
                bManager.switchToMode(canonical.appMode)
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
        let canonical = tab.canonical
        path.removeAll()
        showingZayitReader = false
        showingOtzariaReader = false
        sidebarSearchText = ""
        bManager.authorViewModel.currentRowi = nil
        bManager.authorViewModel.searchText = ""
        selectedTab = canonical
        bManager.switchToMode(canonical.appMode)
        if canonical == .search {
            detailMode = .search
        } else {
            detailMode = .reader
            path = [canonical]
        }
    }

    private func prepareReaderDetail() {
        bManager.authorViewModel.currentRowi = nil
        showingZayitReader = false
        showingOtzariaReader = false
        detailMode = .reader
    }
}
