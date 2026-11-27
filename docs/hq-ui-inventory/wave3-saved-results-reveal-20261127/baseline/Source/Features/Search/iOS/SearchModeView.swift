import SwiftUI

struct SearchModeView: View {
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager
    @Environment(\.maktabahNativeRoutingSession) private var nativeRoutingSession
    @Environment(\.isSearching) var isSearching
    @State private var showingSaveResults = false
    @State private var showingSavedResults = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var ftsManager = FtsMigrationManager.shared
    @State private var showFtsMigrationOverlay = false
    @State private var nativePresentationOwner = UUID()
    @AppStorage("hideFtsMigrationBannerv5") private var hideFtsMigrationBanner = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var canSaveResults: Bool {
        BackendCoordinator.shared.usesNativeMaktabahDataPath && navigationManager.unifiedSearchSession.results.contains { Int($0.archive) != nil }
    }

    var body: some View {
        @Bindable var session = navigationManager.unifiedSearchSession
        @Bindable var viewModel = navigationManager.searchViewModel

        VStack(spacing: 0) {
            GlobalSearchHeader(session: session, onSubmit: submitSearch)
            GlobalSearchContent(session: session, viewModel: viewModel, onSubmit: submitSearch) {
                searchResultsView(session: session)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ftsMigrationBanner()
        }
        .navigationBarTitleDisplayMode(session.results.isEmpty ? .automatic : .inline)
        .toolbar {
            GlobalSearchToolbar(
                session: session,
                canSaveResults: canSaveResults,
                onSaveResults: { nativePresentationBinding($showingSaveResults).wrappedValue = true },
                onSavedResults: { nativePresentationBinding($showingSavedResults).wrappedValue = true }
            )
        }
        .sheet(isPresented: $session.showsBookFilterSheet) {
            SearchFilterModalView(session: session, viewModel: viewModel)
        }
        .sheet(isPresented: $session.showsSearchDataSheet) {
            NavigationStack {
                SearchDataView()
            }
        }
        .sheet(isPresented: nativePresentationBinding($showingSaveResults)) {
            iOSResultWriterView(
                results: session.results,
                query: session.query,
                searchMode: session.scope == .exact ? .phrase : (session.scope == .fuzzy ? .contains : .near),
                searchViewModel: viewModel
            )
        }
        .sheet(isPresented: nativePresentationBinding($showingSavedResults)) {
            iOSSavedResultsView()
        }
        .animation(.easeInOut(duration: 0.5), value: session.results.isEmpty)
        .animation(.interpolatingSpring(stiffness: 300, damping: 20),
                   value: session.isSearching)
        .onAppear {
            observeNativePresentation()
            if session.searchViewModel !== viewModel { session.searchViewModel = viewModel }
            if !session.availableScopes.contains(session.scope), !session.hasSubmitted {
                session.scope = session.availableScopes.first ?? session.scope
            }
            if session.selectedBookIds != viewModel.selectedBookIds {
                session.selectedBookIds = viewModel.selectedBookIds
            }
            if BackendCoordinator.shared.usesNativeMaktabahDataPath {
                ftsManager.checkNeedsMigration()
            }
        }
        .onChange(of: nativeRoutingSession.map(ObjectIdentifier.init), initial: true) { _, _ in
            observeNativePresentation()
        }
        .onChange(of: navigationManager.currentMode) { _, _ in
            nativeRoutingSession?.renderSearchEntryFromOriginalView()
        }
        .onDisappear {
            nativeRoutingSession?.removeSearchPresentation(owner: nativePresentationOwner)
        }
        .onChange(of: viewModel.selectedBookIds) { _, newIds in
            if session.selectedBookIds != newIds {
                session.selectedBookIds = newIds
            }
        }
        .onChange(of: session.selectedBookIds) { _, newIds in
            if viewModel.selectedBookIds != newIds {
                viewModel.setSelectedBooks(newIds)
            }
        }
        .onChange(of: session.isSearching) { _, isSearching in
            if isSearching {
                viewModel.resultKitabFilter = ""
            } else if viewModel.sortKey != .bookTitle || !viewModel.sortAscending {
                viewModel.sortResults(by: viewModel.sortKey, ascending: viewModel.sortAscending)
            }
        }
        .overlay {
            if showFtsMigrationOverlay {
                ZStack {
                    Color.appBackground
                        .ignoresSafeArea()
                        .onTapGesture {}

                    FtsMigrationProgressView(
                        onCancel: {
                            nativePresentationBinding($showFtsMigrationOverlay).wrappedValue = false
                        },
                        onUpdate: {
                            try await ftsManager.performMigration()
                            await MainActor.run { nativePresentationBinding($showFtsMigrationOverlay).wrappedValue = false }
                        }
                    )
                    .transition(AnyTransition.opacity.combined(with: .scale))
                }
            }
        }
        .animation(.easeInOut, value: showFtsMigrationOverlay)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("global-search-screen")
        .modifier(MaktabahNativeRoutingSurface(kind: .searchResults))
        #if DEBUG
        .task {
            await MaktabahNativeRoutingComposition.shared.runSearchResultsAcceptanceProbe(manager: navigationManager)
        }
        #endif
    }

    // MARK: - Sub-views

    /// Read the existing State storage at each precommit/receipt check. These
    /// are passive blockers; the semantic action never dismisses a user's UI.
    @MainActor private func observeNativePresentation() {
        let saving = $showingSaveResults, saved = $showingSavedResults
        let migration = $showFtsMigrationOverlay
        nativeRoutingSession?.observeSearchPresentation(owner: nativePresentationOwner) {
            saving.wrappedValue || saved.wrappedValue || migration.wrappedValue
        }
    }

    /// Every original local overlay write retires an in-flight or completed
    /// component proof BEFORE State changes, even for an A -> B -> A cycle.
    /// Search entry never invokes these setters or dismisses their contents.
    @MainActor private func nativePresentationBinding(_ original: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { original.wrappedValue }, set: { value in
            nativeRoutingSession?.originalSearchPresentationWillChange(owner: nativePresentationOwner)
            original.wrappedValue = value
        })
    }

    private func submitSearch() {
        let session = navigationManager.unifiedSearchSession
        guard !session.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        session.runSearch()
    }

    private func compactFilterView(viewModel: SearchViewModel) -> some View {
        SearchFilterUIKitView(
            viewModel: viewModel,
            displayedCategories: viewModel.displayedCategories,
            updateTrigger: viewModel.updateTrigger,
            onTap: { isSearchFieldFocused = false },
            onShowBookInfo: { book in
                navigationManager.selectedBookForInfo = book
            }
        )
        .themeTint()
        .ignoresSafeArea(edges: .bottom)
    }

    private func searchRegularEmptyState(session: UnifiedSearchSessionController, viewModel: SearchViewModel) -> some View {
        ContentUnavailableView {
            Label(String(localized: "Search Books"), systemImage: "magnifyingglass")
        } description: {
            if session.selectedBookIds.isEmpty {
                Text(String(localized: "Select books in the sidebar or enter search terms above."))
            } else {
                Text(String(format: String(localized: "%lld books selected. Enter search terms above and press Return."), Int64(session.selectedBookIds.count)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func searchResultsView(session: UnifiedSearchSessionController) -> some View {
        let filtered = session.filteredResults

        return SearchResultsListView(
            results: filtered,
            isLoadingMore: session.isLoadingMore,
            hasMore: session.hasMore,
            automaticallyLoadsMore: session.allowsAutomaticPaging && session.resultKitabFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            nativeContinuation: session.nativeSearchContinuation,
            onLoadMore: {
                session.loadNextPage()
            },
            onSearchInBook: { item in
                session.searchInBook(item)
            },
            query: session.query,
            mode: session.searchModeForReader,
            nearDistance: session.nearDistanceForReader
        ) { item in
            session.openResult(item, using: navigationManager)
        }
        .accessibilityIdentifier("global-search-results")
    }

    @ViewBuilder
    private func ftsMigrationBanner() -> some View {
        if BackendCoordinator.shared.usesNativeMaktabahDataPath && ftsManager.needsMigration && !hideFtsMigrationBanner && !ftsManager.isMigrating {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text(ftsManager.isOptimizationOnly ? .ftsOptimizationAvailable : .ftsMigrationAvailable)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }

                VStack(spacing: 10) {
                    Button {
                        nativePresentationBinding($showFtsMigrationOverlay).wrappedValue = true
                    } label: {
                        Text(ftsManager.isOptimizationOnly
                            ? .ftsOptimizationNowCountBtn(ftsManager.totalArchivesToMigrate)
                            : .ftsMigrationUpdateNowCountBtn(ftsManager.totalArchivesToMigrate))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                    .prominentButtonStyleIfAvailable()

                    Button {
                        hideFtsMigrationBanner = true
                        ReusableFunc.showAlert(
                            title: String(localized: .ftsMigrationAlertTitle),
                            message: String(localized: .ftsMigrationAlertMessage)
                        )
                    } label: {
                        Text(.ftsMigrationHideBannerBtn)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            #if os(iOS)
            .roundedBorder()
            #endif
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: ftsManager.isMigrating)
            .animation(.easeInOut, value: ftsManager.needsMigration)
        }
    }
}

// MARK: - Previews

struct SearchModeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchModeView()
                .environment(iOSNavigationManager())
                .previewDisplayName("Search")
            NavigationStack {
                let vm = SearchViewModel()
                SearchFilterUIKitView(
                    viewModel: vm,
                    displayedCategories: vm.displayedCategories,
                    updateTrigger: vm.updateTrigger
                )
                .navigationTitle("Filter Search")
                .navigationBarTitleDisplayMode(.inline)
            }
            .previewDisplayName("Search Filter")
        }
    }
}
