//
//  ReaderWorkspaceChromeHost.swift
//  Maktabah
//
//  Downstream-owned unified top chrome host combining the Safari 3-group toolbar (Plan B),
//  the 40pt DuckDuckGo-inspired document tab strip (Plan C2), and the StudyGroupsOverview (Plan C3).
//

#if os(iOS)
import SwiftUI

/// Wraps the iPad reader detail area with a single coordinated top bar (`ReaderLibraryToolbarHost`)
/// and a real-height (`40pt`) `ReaderDocumentTabsBarRepresentable` strip so no floating overlay covers the text.
/// Connects all toolbar actions (`showingBookSearchSheet`, `showingAnnotationSheet`, `showingDisplaySettingsPopover`,
/// `showingBookInfoPopover`) to real modal/popover presenters and suppresses duplicate inner navigation bars when active.
struct ReaderWorkspaceChromeHost<DetailContent: View>: View {
    @Environment(iOSNavigationManager.self) private var navigationManager
    @SceneStorage("chavrusa.studyWorkspace.sceneID") private var persistedSceneID: String = ""
    @State private var sessionFallbackSceneID: String = UUID().uuidString

    @Bindable var sidebarCoordinator: ReaderSidebarStateCoordinator
    @State private var searchCoordinator = ExpandableLibrarySearchCoordinator()
    @State private var sceneCoordinator: StudyWorkspaceSceneCoordinator?

    @State private var showingBookSearchSheet: Bool = false
    @State private var showingAnnotationSheet: Bool = false
    @State private var showingDisplaySettingsPopover: Bool = false
    @State private var showingBookInfoPopover: Bool = false

    @ViewBuilder var detailContent: () -> DetailContent

    init(
        sidebarCoordinator: ReaderSidebarStateCoordinator,
        @ViewBuilder detailContent: @escaping () -> DetailContent
    ) {
        self.sidebarCoordinator = sidebarCoordinator
        self.detailContent = detailContent
    }

    var body: some View {
        let flags = ChavrusaTextFeatureFlags.shared
        let workspaceFeaturesEnabled = flags.effectiveStudyWorkspaceEnabled || flags.effectiveDuckTabStripEnabled
        let activeSceneCoordinator: StudyWorkspaceSceneCoordinator? = workspaceFeaturesEnabled ? sceneCoordinator : nil
        let showSafariToolbar = flags.effectiveSafariToolbarSearchEnabled
        let showDuckTabStrip = flags.effectiveDuckTabStripEnabled
            && !navigationManager.openTabs.isEmpty
            && !(flags.effectiveStudyWorkspaceEnabled && (activeSceneCoordinator?.isOverviewPresented ?? false))
        let showOverview = flags.effectiveStudyWorkspaceEnabled && (activeSceneCoordinator?.isOverviewPresented ?? false)

        Group {
            if showOverview, let activeSceneCoordinator {
                StudyGroupsOverview(
                    sceneCoordinator: activeSceneCoordinator,
                    sidebarCoordinator: sidebarCoordinator
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showSafariToolbar {
                detailContent()
                    .toolbar(.hidden, for: .navigationBar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailContent()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if showSafariToolbar || showDuckTabStrip {
                VStack(spacing: 0) {
                    if showSafariToolbar {
                        ReaderLibraryToolbarHost(
                            sidebarCoordinator: sidebarCoordinator,
                            searchCoordinator: searchCoordinator,
                            sceneCoordinator: activeSceneCoordinator,
                            libraryViewModel: navigationManager.libraryViewModel,
                            showingBookSearchSheet: $showingBookSearchSheet,
                            showingAnnotationSheet: $showingAnnotationSheet,
                            showingDisplaySettingsPopover: $showingDisplaySettingsPopover,
                            showingBookInfoPopover: $showingBookInfoPopover
                        )
                    }

                    if showDuckTabStrip, let activeSceneCoordinator {
                        ReaderDocumentTabsBarRepresentable(
                            sceneCoordinator: activeSceneCoordinator,
                            sidebarCoordinator: sidebarCoordinator
                        )
                        .frame(height: ReaderTabStripLayout.barHeight)
                    }
                }
            }
        }
        .onAppear {
            ensureSceneCoordinatorInitializedIfNeeded()
        }
        .onChange(of: persistedSceneID) { _, _ in
            ensureSceneCoordinatorInitializedIfNeeded()
        }
        .onChange(of: flags.studyWorkspaceEnabled) { _, _ in
            ensureSceneCoordinatorInitializedIfNeeded()
        }
        .onChange(of: flags.duckTabStripEnabled) { _, _ in
            ensureSceneCoordinatorInitializedIfNeeded()
        }
        .onChange(of: navigationManager.openTabs.count) { _, _ in
            guard flags.effectiveStudyWorkspaceEnabled, let activeSceneCoordinator else { return }
            activeSceneCoordinator.navigationAdapter.captureLiveState(
                from: navigationManager,
                intoGroup: activeSceneCoordinator.activeGroup.id
            )
        }
        .onChange(of: navigationManager.activeTabId) { _, _ in
            guard flags.effectiveStudyWorkspaceEnabled, let activeSceneCoordinator else { return }
            activeSceneCoordinator.navigationAdapter.captureLiveState(
                from: navigationManager,
                intoGroup: activeSceneCoordinator.activeGroup.id
            )
        }
        .sheet(isPresented: $showingBookSearchSheet) {
            if let activeTab = navigationManager.activeTab {
                iOSBookSearchView(
                    book: activeTab.book,
                    onSelect: { result, query in
                        activeTab.viewModel.didSelectSearch(result: result, query: query)
                        showingBookSearchSheet = false
                    },
                    viewModel: activeTab.viewModel.searchViewModel
                )
            }
        }
        .sheet(isPresented: $showingAnnotationSheet) {
            if let activeTab = navigationManager.activeTab {
                iOSBookAnnotationsView(
                    bookId: activeTab.book.id,
                    viewModel: activeTab.viewModel.bookAnnotationsViewModel,
                    onSelect: { ann in
                        activeTab.viewModel.didSelectAnnotation(ann)
                        showingAnnotationSheet = false
                    },
                    onUpdate: { updated in
                        try activeTab.viewModel.updateAnnotation(updated)
                    },
                    onDelete: { ann in
                        if let id = ann.id {
                            try activeTab.viewModel.deleteAnnotation(id: id)
                        }
                    }
                )
            }
        }
    }

    private func ensureSceneCoordinatorInitializedIfNeeded() {
        sceneCoordinator = StudyWorkspaceSceneCoordinator.acquireIfEnabled(
            persistedSceneID: &persistedSceneID,
            sessionFallbackID: sessionFallbackSceneID,
            existingCoordinator: sceneCoordinator,
            featureFlags: ChavrusaTextFeatureFlags.shared
        )
    }
}
#endif
