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

    private var searchPrompt: String {
        switch selectedTab {
        case .viewer: String(localized: "Search Library")
        case .search: String(localized: "Filter Books to Search")
        case .author: String(localized: "Search Narrators")
        case .annotations: String(localized: "Search Annotations")
        case .history: String(localized: "Search History & Favorites")
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                iOSLibraryView()
                    .navigationTitle(iOSTab.viewer.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showSettings = true } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .searchable(text: $bManager.searchText, placement: .toolbar, prompt: searchPrompt)
            .tabItem { Label(iOSTab.viewer.title, systemImage: iOSTab.viewer.icon) }
            .tag(iOSTab.viewer)

            NavigationStack {
                SearchModeView()
                    .navigationTitle(iOSTab.search.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $bManager.searchText, placement: .toolbar, prompt: searchPrompt)
            .tabItem { Label(iOSTab.search.title, systemImage: iOSTab.search.icon) }
            .tag(iOSTab.search)

            NavigationStack {
                AuthorModeView()
                    .navigationTitle(iOSTab.author.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $bManager.searchText, placement: .toolbar, prompt: searchPrompt)
            .tabItem { Label(iOSTab.author.title, systemImage: iOSTab.author.icon) }
            .tag(iOSTab.author)

            NavigationStack {
                AnnotationListView()
                    .navigationTitle(iOSTab.annotations.title)
                    .adaptiveReaderPush(item: $bManager.selectedBook, manager: bManager)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .searchable(text: $bManager.searchText, placement: .toolbar, prompt: searchPrompt)
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
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showingAddFavorites = true }) {
                                Image(systemName: "plus")
                            }
                        }
                    }
            }
            .searchable(text: $bManager.searchText, placement: .toolbar, prompt: searchPrompt)
            .tabItem { Label(iOSTab.history.title, systemImage: iOSTab.history.icon) }
            .tag(iOSTab.history)
        }
        .sheet(isPresented: $showingAddFavorites) {
            iOSAddFavoriteSheet(viewModel: iOSHistoryViewModel.shared)
        }
        .onChange(of: selectedTab) { _, newValue in
            bManager.switchToMode(newValue.appMode)
        }
    }
}
