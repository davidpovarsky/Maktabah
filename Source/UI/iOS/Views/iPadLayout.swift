//
//  iPadLayout.swift
//  Maktabah-iOS
//
//

import SwiftUI
import UIKit

struct iPadLayout: View {
    @Bindable var bManager: iOSNavigationManager
    @Binding var selectedTab: iOSTab
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showSettings: Bool
    @Bindable var sidebar: ReaderSidebarPageCoordinator

    @State private var showingAddFavorites = false
    @State private var preferredLibraryCompactColumn: NavigationSplitViewColumn = .detail
    @AppStorage("lastSelectedTab") private var savedSelectedTab: iOSTab = .viewer
    @StateObject private var historyViewModel = HistoryViewModel.shared
    @StateObject private var backendCoordinator = BackendCoordinator.shared
    @State private var searchPresentation = GlobalSearchPresentationCoordinator()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.exact9401Workspace) private var workspace
    @Environment(\.maktabahNativeRoutingSession) private var routingSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var readerSidebarIsOpen: Bool {
        horizontalSizeClass == .compact
            ? preferredLibraryCompactColumn == .sidebar
            : columnVisibility != .detailOnly
    }

    private var readerChromeAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.90)
    }

    // Only the selected Reader supplies a preference to the global tab bar.
    // Other tabs retain their original system policy.
    private var readerTabBarVisibility: Visibility? {
        guard ChavrusaTextReaderUI.isEnabled, selectedTab == .viewer else { return nil }
        return sidebar.navigationChrome.isVisible ? .visible : .hidden
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(iOSTab.viewer.title, systemImage: iOSTab.viewer.icon, value: .viewer) {
                viewerTabContent
                    .modifier(ReaderTabBarVisibility(visibility: readerTabBarVisibility))
            }

            if iOSTab.search.isAvailable(for: backendCoordinator.activeCapabilities) {
                Tab(iOSTab.search.title, systemImage: iOSTab.search.icon, value: .search) {
                    searchTabContent
                        .modifier(GlobalTabBarVisibility(isSelected: selectedTab == .search))
                }
            }

            if iOSTab.author.isAvailable(for: backendCoordinator.activeCapabilities) {
                Tab(iOSTab.author.title, systemImage: iOSTab.author.icon, value: .author) {
                    authorTabContent
                        .modifier(GlobalTabBarVisibility(isSelected: selectedTab == .author))
                }
            }

            Tab(iOSTab.annotations.title, systemImage: iOSTab.annotations.icon, value: .annotations) {
                annotationsTabContent
                    .modifier(GlobalTabBarVisibility(isSelected: selectedTab == .annotations))
            }

            Tab(iOSTab.history.title, systemImage: iOSTab.history.icon, value: .history) {
                historyTabContent
                    .modifier(GlobalTabBarVisibility(isSelected: selectedTab == .history))
            }
        }
        .themeTint()
        .background(Color.appBackground.ignoresSafeArea())
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

    // MARK: - Tab Contents

    @ViewBuilder
    private var viewerTabContent: some View {
        if ChavrusaTextReaderUI.isEnabled {
            workspaceViewerTabContent
        } else {
            originalViewerTabContent
        }
    }

    @ViewBuilder
    private var workspaceViewerTabContent: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredLibraryCompactColumn
        ) {
            ReaderSidebarPager(coordinator: sidebar) { isActive in
                iOSLibraryView()
                    .toolbarGeneral(showSettings: $showSettings)
                .toolbarBackground(Color.appBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .background(Color.appBackground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("library-column")
                .modifier(MaktabahNativeRoutingSurface(kind: .library))
            } contents: { isActive in
                activeReaderTableOfContents
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("toc-column")
                    .modifier(MaktabahNativeRoutingSurface(kind: .tableOfContents))
            }
            .environment(\.readerSidebarUsesSharedSearch, true)
        } detail: {
            VStack(spacing: 0) {
                if horizontalSizeClass == .regular {
                    WorkspaceDocumentTabStrip(manager: bManager, workspace: workspace,
                                              chromeVisible: sidebar.navigationChrome.isVisible)
                }
                iOSReaderTabView(
                    columnVisibility: $columnVisibility,
                    preferredCompactColumn: $preferredLibraryCompactColumn,
                    usesToolbarDocumentTabs: horizontalSizeClass != .regular
                )
            }
            .background(Color.appBackground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader-detail-column")
            .modifier(MaktabahNativeRoutingSurface(kind: .reader))
            .modifier(Exact9401ViewerToolbar(manager: bManager))
        }
        .overlay {
            ReaderLibrarySearchMorph(manager: bManager, sidebar: sidebar)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color.appBackground.ignoresSafeArea())
        .environment(\.chavrusaReaderSidebar, sidebar)
        .environment(\.chavrusaReaderNavigationChromeVisible, sidebar.navigationChrome.isVisible)
        .background {
            ReaderSceneIdentityReader(
                observeWindow: { owner, window in
                    sidebar.observeNavigationChromeWindow(owner: owner, window: window)
                },
                resolve: { _ in }
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .onChange(of: bManager.activeTabId) { _, _ in revealReaderNavigationChrome() }
        .onChange(of: bManager.activeReaderViewModel?.currentContentId) { _, _ in revealReaderNavigationChrome() }
        .onChange(of: bManager.activeReaderViewModel?.readerInspectorVisible) { _, visible in
            if visible == true { revealReaderNavigationChrome() }
        }
        .onChange(of: bManager.activeReaderViewModel?.isPopoverPresented) { _, visible in
            if visible == true { revealReaderNavigationChrome() }
        }
        .onChange(of: readerSidebarIsOpen) { _, open in
            if open { revealReaderNavigationChrome() }
        }
        .onChange(of: sidebar.overview.requestID) { _, id in
            if id != nil { revealReaderNavigationChrome() }
        }
        .onChange(of: selectedTab) { _, _ in revealReaderNavigationChrome() }
        .onDisappear { sidebar.navigationChrome.reveal() }
        .onReceive(NotificationCenter.default.publisher(for: .chavrusaReaderDidScroll)) {
            receiveReaderNavigationScroll($0)
        }
        .onChange(of: bManager.showingTabsList, initial: true) { _, showing in
            if showing, workspace?.attached == true { sidebar.overview.request() }
        }
        .overlay { studyOverviewPresentation }
    }

    private func revealReaderNavigationChrome() {
        withAnimation(readerChromeAnimation) { sidebar.navigationChrome.reveal() }
    }

    private func receiveReaderNavigationScroll(_ note: Notification) {
        guard ChavrusaTextReaderUI.isEnabled, selectedTab == .viewer, scenePhase == .active,
              let workspace, workspace.attached,
              let source = note.object as? ReaderViewModel,
              source === bManager.activeReaderViewModel,
              !sidebar.overview.blocksRouting,
              !source.isPopoverPresented, !source.readerInspectorVisible,
              let scrollView = note.userInfo?[ChavrusaReaderScrollKey.scrollView] as? UIScrollView,
              sidebar.ownsNavigationChromeWindow(scrollView, sceneID: workspace.sceneID),
              let translationY = note.userInfo?[ChavrusaReaderScrollKey.translationY] as? CGFloat,
              let isAtTop = note.userInfo?[ChavrusaReaderScrollKey.isAtTop] as? Bool
        else { return }
        if note.userInfo?[ChavrusaReaderScrollKey.beginsDrag] as? Bool == true {
            sidebar.navigationChrome.beginDragging()
        } else {
            withAnimation(readerChromeAnimation) {
                sidebar.navigationChrome.consume(translationY: translationY, isAtTop: isAtTop)
            }
        }
    }

    @ViewBuilder
    private var studyOverviewPresentation: some View {
        if let workspace, let id = sidebar.overview.requestID {
            ReaderOverviewPresentation(
                isPresented: Binding(
                    get: { sidebar.overview.requestID == id && sidebar.overview.isRequested },
                    set: { if !$0 { sidebar.overview.requestClose(id) } }
                ),
                lifecycle: .init(
                    id: id,
                    willPresent: { sidebar.overview.canPresent(id) },
                    didPresent: { sidebar.overview.didMount(id) },
                    didDismiss: { finishStudyOverview(id, workspace: workspace, dismantled: false) },
                    didDismantle: { finishStudyOverview(id, workspace: workspace, dismantled: true) }
                )
            ) {
                StudyGroupsOverview(
                    workspace: workspace, manager: bManager,
                    onOpenLibrary: {
                        selectedTab = .viewer
                        bManager.switchToMode(.viewer)
                        sidebar.showLibrary()
                        columnVisibility = .all
                        preferredLibraryCompactColumn = .sidebar
                    },
                    onClose: { sidebar.overview.requestClose(id) }
                )
                .environment(\.maktabahNativeRoutingSession, routingSession)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }

    private func finishStudyOverview(_ id: UUID, workspace: StudyWorkspaceNavigationAdapter, dismantled: Bool) {
        let finished = dismantled
            ? sidebar.overview.didDismantle(id)
            : sidebar.overview.didDismiss(id)
        guard finished else { return }
        bManager.showingTabsList = false
        workspace.synchronize(bManager)
    }

    /// Preserve the original flag-off three-column composition from
    /// 3dc5100900fc25eac1b312d7893eb50e7bd510cb. The current original Library,
    /// TOC and Reader still own their controls, rendering and data.
    private var originalViewerTabContent: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredLibraryCompactColumn
        ) {
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library-column")
            .modifier(MaktabahNativeRoutingSurface(kind: .library))
        } content: {
            activeReaderTableOfContents
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("toc-column")
                .modifier(MaktabahNativeRoutingSurface(kind: .tableOfContents))
        } detail: {
            iOSReaderTabView(
                columnVisibility: $columnVisibility,
                preferredCompactColumn: $preferredLibraryCompactColumn
            )
            .background(Color.appBackground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reader-detail-column")
            .modifier(MaktabahNativeRoutingSurface(kind: .reader))
        }
        .navigationSplitViewStyle(.balanced)
        .background(Color.appBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var activeReaderTableOfContents: some View {
        if let tab = activeReaderTab {
            iOSTOCView(
                tocViewModel: tab.viewModel.tocViewModel,
                selectedId: selectedTOCNode(for: tab.viewModel)?.id,
                bookTitle: tab.book.book,
                onClose: closeTableOfContents,
                onRetry: { tab.viewModel.loadTOC(book: tab.book) },
                embedsNavigationStack: false,
                onSelect: { id in
                    tab.viewModel.didSelectTOCNode(id: id)
                    if ChavrusaTextReaderUI.isEnabled && horizontalSizeClass == .compact { closeTableOfContents() }
                }
            )
            .onAppear {
                if tab.viewModel.tocViewModel.tocNodes.isEmpty && !tab.viewModel.tocViewModel.isLoading {
                    tab.viewModel.loadTOC(book: tab.book)
                }
            }
        } else {
            ContentUnavailableView(
                String(localized: "No Table of Contents"),
                systemImage: "list.bullet.rectangle",
                description: Text("Select a book to read")
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            .background(Color.appBackground)
        }
    }

    private var activeReaderTab: iOSNavigationManager.ReaderTab? {
        bManager.openTabs.first(where: { $0.id == bManager.activeTabId })
            ?? bManager.openTabs.first
    }

    private func selectedTOCNode(for viewModel: ReaderViewModel) -> TOCNode? {
        if let locator = viewModel.backendSection?.locator,
           let node = viewModel.tocViewModel.findNode(for: locator) {
            return node
        }
        return viewModel.tocViewModel.findNode(forContentId: viewModel.currentContentId)
    }

    private func closeTableOfContents() {
        preferredLibraryCompactColumn = .detail
        withAnimation(.snappy(duration: 0.30, extraBounce: 0)) {
            columnVisibility = .detailOnly
        }
    }

    @ViewBuilder
    private var searchTabContent: some View {
        NavigationSplitView(columnVisibility: $searchPresentation.columnVisibility) {
            searchSidebarContent
        } detail: {
            NavigationStack {
                SearchModeView()
                    .modifier(MaktabahNativeRoutingSurface(kind: .search))
                    .navigationTitle(iOSTab.search.title)
                    .toolbarGeneral(showSettings: $showSettings)
            }
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .environment(\.globalSearchBookChooser) {
            if horizontalSizeClass == .compact { bManager.unifiedSearchSession.showsBookFilterSheet = true }
            else { searchPresentation.showBooks() }
        }
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
                .modifier(MaktabahNativeRoutingSurface(kind: .annotations))
                .navigationTitle(iOSTab.annotations.title)
                .toolbarGeneral(showSettings: $showSettings)
        }
        .searchable(
            text: Bindable(bManager.annotationViewModel).searchText,
            placement: .toolbar,
            prompt: String(localized: .Annotation.searchAnnotations)
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
                .modifier(MaktabahNativeRoutingSurface(kind: .history))
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

/// Keep Reader content at the same structural position when tab selection
/// changes. Only this noninteractive background conditionally publishes a
/// preference, above the Reader's navigation and nested sidebar pager.
private struct ReaderTabBarVisibility: ViewModifier {
    let visibility: Visibility?

    func body(content: Content) -> some View {
        content.background {
            if let visibility {
                Color.clear
                    .toolbarVisibility(visibility, for: .tabBar)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The selected original global destination explicitly owns a visible tab bar.
/// Give the native tab container a positive request after leaving Reader,
/// rather than relying on removal of the offscreen Reader's preference.
/// Keep each destination at the same structural position as selection changes.
private struct GlobalTabBarVisibility: ViewModifier {
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if ChavrusaTextReaderUI.isEnabled {
            content.modifier(ReaderTabBarVisibility(visibility: isSelected ? .visible : nil))
        } else {
            // The original flags-off destination has no added preference host.
            content
        }
    }
}
