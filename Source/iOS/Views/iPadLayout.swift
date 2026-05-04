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

    private var searchPrompt: String {
        switch selectedTab {
        case .viewer: String(localized: "Search Library")
        case .search: String(localized: "Filter Books to Search")
        case .author: String(localized: "Search Authors")
        case .annotations: String(localized: "Search Annotations")
        case .history: String(localized: "Search History & Favorites")
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TabView(selection: $selectedTab) {
                iOSLibraryView()
                    .tabItem { Label(iOSTab.viewer.title, systemImage: iOSTab.viewer.icon) }
                    .tag(iOSTab.viewer)

                SearchModeView()
                    .tabItem { Label(iOSTab.search.title, systemImage: iOSTab.search.icon) }
                    .tag(iOSTab.search)

                AuthorModeView()
                    .tabItem { Label(iOSTab.author.title, systemImage: iOSTab.author.icon) }
                    .tag(iOSTab.author)

                AnnotationListView()
                    .tabItem { Label(iOSTab.annotations.title, systemImage: iOSTab.annotations.icon) }
                    .tag(iOSTab.annotations)

                iOSHistoryView()
                    .tabItem { Label(iOSTab.history.title, systemImage: iOSTab.history.icon) }
                    .tag(iOSTab.history)
            }
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.automatic)
            .searchable(text: $bManager.searchText, placement: .sidebar, prompt: searchPrompt.localized)
            .onChange(of: selectedTab) { _, newValue in
                bManager.switchToMode(newValue.appMode)
            }
            .padding(.horizontal, 0.3)
            .toolbar {
                modeToolbar()
            }
        } detail: {
            iOSReaderTabView()
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: iOSHistoryViewModel.shared)
        }
    }

    @ToolbarContentBuilder
    private func modeToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showSettings = true } label: {
                Image(systemName: "gear")
            }
        }

        switch selectedTab {
        case .viewer:
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    bManager.libraryViewModel.showOnlyDownloaded.toggle()
                } label: {
                    Image(systemName: bManager.libraryViewModel.showOnlyDownloaded
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
            }
        case .search:
            ToolbarItemGroup(placement: .topBarTrailing) {
                if bManager.searchViewModel.isSearching {
                    Button(action: { bManager.searchViewModel.stopSearch() }) {
                        Image(systemName: "stop").foregroundColor(.red)
                    }
                } else {
                    Button(action: { bManager.searchViewModel.startSearch() }) {
                        Image(systemName: "play")
                    }
                }

                Button(action: { showingSearchHelp = true }) {
                    Image(systemName: "questionmark.circle")
                }
                .popover(isPresented: $showingSearchHelp) {
                    SearchHelpView()
                        .frame(width: 300, height: 450)
                        .presentationCompactAdaptation(.popover)
                }

                if !bManager.searchViewModel.results.isEmpty {
                    Button(action: {
                        bManager.searchViewModel.stopSearch()
                        bManager.searchViewModel.results = []
                        bManager.searchViewModel.query = ""
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                }
            }
        case .annotations:
            ToolbarItem(placement: .topBarTrailing) {
                @Bindable var viewModel = bManager.annotationViewModel
                Menu {
                    Picker("Group By", selection: $viewModel.groupingMode) {
                        Text("Book").tag(AnnotationGroupingMode.book)
                        Text("Tag").tag(AnnotationGroupingMode.tag)
                    }
                    Divider()
                    Picker("Sort By", selection: $viewModel.sortField) {
                        Text("Date Created").tag(AnnotationSortField.createdAt)
                        Text("Context").tag(AnnotationSortField.context)
                        Text("Page").tag(AnnotationSortField.page)
                        Text("Part").tag(AnnotationSortField.part)
                    }
                    Picker("Order", selection: $viewModel.sortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        case .history:
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddFavorites = true }) {
                    Image(systemName: "plus")
                }
            }
        default:
            ToolbarItem(placement: .topBarTrailing) { EmptyView() }
        }
    }
}
