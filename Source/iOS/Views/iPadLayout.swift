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

    @State private var showingAddFavorites = false
    @AppStorage("lastSelectedTab") private var savedSelectedTab: iOSTab = .viewer
    @StateObject private var historyViewModel = HistoryViewModel.shared
    @StateObject private var backendCoordinator = BackendCoordinator.shared

    var body: some View {
        Group {
            switch selectedTab.canonical {
            case .viewer:
                viewerTabContent
            case .search, .textSearch, .zayitSearch:
                searchTabContent
            case .author:
                authorTabContent
            case .annotations:
                annotationsTabContent
            case .history:
                historyTabContent
            }
        }
        .themeTint()
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            topTabSelector
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: historyViewModel)
        }
        .onAppear {
            if savedSelectedTab == .textSearch || savedSelectedTab == .zayitSearch {
                selectedTab = .search
                savedSelectedTab = .search
            } else {
                selectedTab = savedSelectedTab.canonical
            }
            if !selectedTab.isAvailable(for: backendCoordinator.activeCapabilities) {
                selectedTab = .viewer
                savedSelectedTab = .viewer
            }
            if bManager.unifiedSearchSession.selectedBookIds != bManager.searchViewModel.selectedBookIds {
                bManager.unifiedSearchSession.selectedBookIds = bManager.searchViewModel.selectedBookIds
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activeLibraryBackendDidChange)) { _ in
            if !selectedTab.isAvailable(for: backendCoordinator.activeCapabilities) {
                selectedTab = .viewer
                savedSelectedTab = .viewer
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            let canonical = newValue.canonical
            savedSelectedTab = canonical
            if selectedTab != canonical {
                selectedTab = canonical
            }
            bManager.switchToMode(canonical.appMode)
        }
        .onChange(of: bManager.currentMode) { _, newMode in
            let matchingTab = iOSTab(appMode: newMode)
            if selectedTab != matchingTab {
                selectedTab = matchingTab
            }
        }
        .onChange(of: bManager.searchViewModel.selectedBookIds) { _, newIds in
            if bManager.unifiedSearchSession.selectedBookIds != newIds {
                bManager.unifiedSearchSession.selectedBookIds = newIds
            }
        }
        .onChange(of: bManager.unifiedSearchSession.selectedBookIds) { _, newIds in
            if bManager.searchViewModel.selectedBookIds != newIds {
                bManager.searchViewModel.setSelectedBooks(newIds)
            }
        }
    }

    private var availableTabs: [iOSTab] {
        iOSTab.allCases.filter { $0.isAvailable(for: backendCoordinator.activeCapabilities) }
    }

    private var topTabSelector: some View {
        Picker(String(localized: "Navigation"), selection: $selectedTab) {
            ForEach(availableTabs) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("MaktabahTopTabSelector")
        .frame(maxWidth: 680)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Tab Contents

    @ViewBuilder
    private var viewerTabContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationStack {
                iOSLibraryView()
                    .navigationTitle(iOSTab.viewer.title)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(
                text: Bindable(bManager.libraryViewModel).searchQuery,
                placement: .toolbar,
                prompt: String(localized: "Search Library")
            )
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color.appBackground)
        } detail: {
            iOSReaderTabView(columnVisibility: $columnVisibility)
                .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .inspector(isPresented: Binding(
            get: { bManager.activeReaderViewModel?.readerInspectorVisible ?? false },
            set: { newValue in
                if newValue {
                    bManager.activeReaderViewModel?.readerInspectorVisible = true
                } else {
                    bManager.activeReaderViewModel?.closeReaderInspector()
                }
            }
        )) {
            if let activeReaderViewModel = bManager.activeReaderViewModel {
                OtzariaReaderSourcesInspectorHost(
                    viewModel: activeReaderViewModel,
                    navigationManager: bManager
                )
                .inspectorColumnWidth(min: 320, ideal: 400, max: 500)
            }
        }
    }

    @ViewBuilder
    private var searchTabContent: some View {
        NavigationSplitView {
            searchSidebarContent
        } detail: {
            NavigationStack {
                SearchModeView()
                    .navigationTitle(iOSTab.search.title)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var searchSidebarContent: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                SearchFilterUIKitView(
                    viewModel: bManager.searchViewModel,
                    displayedCategories: bManager.searchViewModel.displayedCategories,
                    updateTrigger: bManager.searchViewModel.updateTrigger,
                    onTap: {}
                )
                .themeTint()
            }
            .navigationTitle(String(localized: "search.filterByBooksTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $bManager.searchViewModel.filterText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String(localized: "Search Book")
            )
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !bManager.unifiedSearchSession.selectedBookIds.isEmpty {
                        Button(String(localized: "Clear All")) {
                            bManager.unifiedSearchSession.clearFilter()
                        }
                    }
                }
            }
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var authorTabContent: some View {
        NavigationStack {
            AuthorModeView(onOpenBook: { book in
                bManager.openBook(book)
            })
            .navigationTitle(iOSTab.author.title)
            .toolbarGeneral(showSettings: $showSettings)
        }
        .searchable(
            text: Bindable(bManager.authorViewModel).searchText,
            placement: .toolbar,
            prompt: String(localized: "Search Narrators")
        )
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var annotationsTabContent: some View {
        NavigationStack {
            AnnotationListView()
                .navigationTitle(iOSTab.annotations.title)
                .toolbarGeneral(showSettings: $showSettings)
        }
        .searchable(
            text: Bindable(bManager.annotationViewModel).searchText,
            placement: .toolbar,
            prompt: String(localized: "Search Annotations")
        )
        .searchScopes(Bindable(bManager.annotationViewModel).searchScope) {
            ForEach(AnnotationSearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private var historyTabContent: some View {
        NavigationStack {
            iOSHistoryView()
                .navigationTitle(iOSTab.history.title)
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
                        .accessibilityLabel(String(localized: "Add Favorite"))
                        .help(String(localized: "Add Favorite"))
                    }
                }
        }
        .searchable(
            text: Binding(
                get: { historyViewModel.searchText },
                set: { historyViewModel.searchText = $0 }
            ),
            placement: .toolbar,
            prompt: String(localized: "Search History & Favorites")
        )
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color.appBackground)
    }
}
