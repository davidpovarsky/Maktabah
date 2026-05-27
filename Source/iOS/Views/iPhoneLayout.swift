//
//  iPhoneLayout.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 03/05/26.
//

import SwiftUI

// MARK: - iPhone Layout

struct iPhoneLayout: View {
    @Bindable var bManager: iOSNavigationManager
    @Binding var selectedTab: iOSTab
    @Binding var showSettings: Bool
    @State private var showingAddFavorites = false

    var body: some View {
        @Bindable var libraryVM = bManager.libraryViewModel
        @Bindable var searchVM = bManager.searchViewModel
        @Bindable var authorVM = bManager.authorViewModel
        @Bindable var annotationVM = bManager.annotationViewModel

        TabView(selection: $selectedTab) {
            NavigationStack {
                iOSLibraryView()
                    .navigationTitle(iOSTab.viewer.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $libraryVM.searchText, placement: .toolbar, prompt: String(localized: "Search Library"))
            .tabItem { Label(iOSTab.viewer.title, systemImage: iOSTab.viewer.icon) }
            .tag(iOSTab.viewer)

            NavigationStack {
                SearchModeView()
                    .navigationTitle(iOSTab.search.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $searchVM.filterText, placement: .toolbar, prompt: String(localized: "Filter Books to Search"))
            .tabItem { Label(iOSTab.search.title, systemImage: iOSTab.search.icon) }
            .tag(iOSTab.search)

            NavigationStack {
                AuthorModeView()
                    .navigationTitle(iOSTab.author.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $authorVM.searchText, placement: .toolbar, prompt: String(localized: "Search Narrators"))
            .tabItem { Label(iOSTab.author.title, systemImage: iOSTab.author.icon) }
            .tag(iOSTab.author)

            NavigationStack {
                AnnotationListView()
                    .navigationTitle(iOSTab.annotations.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $annotationVM.searchText, placement: .toolbar, prompt: String(localized: "Search Annotations"))
            .tabItem { Label(iOSTab.annotations.title, systemImage: iOSTab.annotations.icon) }
            .tag(iOSTab.annotations)

            NavigationStack {
                iOSHistoryView()
                    .navigationTitle(iOSTab.history.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showSettings = true } label: {
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
                    get: { HistoryViewModel.shared.searchText },
                    set: { HistoryViewModel.shared.searchText = $0 }
                ),
                placement: .toolbar,
                prompt: String(localized: "Search History & Favorites")
            )
            .tabItem { Label(iOSTab.history.title, systemImage: iOSTab.history.icon) }
            .tag(iOSTab.history)
        }
        .themeTint()
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: HistoryViewModel.shared)
        }
        .onChange(of: selectedTab) { _, newValue in
            bManager.switchToMode(newValue.appMode)
        }
    }
}
