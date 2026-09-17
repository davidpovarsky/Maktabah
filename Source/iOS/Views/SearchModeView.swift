import SwiftUI

struct SearchModeView: View {
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager
    @Environment(\.isSearching) var isSearching
    @State private var showingSaveResults = false
    @State private var showingSavedResults = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var ftsManager = FtsMigrationManager.shared
    @State private var showFtsMigrationOverlay = false
    @AppStorage("hideFtsMigrationBanner") private var hideFtsMigrationBanner = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private var canSaveResults: Bool {
        BackendCoordinator.shared.usesNativeMaktabahDataPath && navigationManager.unifiedSearchSession.results.contains { Int($0.archive) != nil }
    }

    var body: some View {
        @Bindable var session = navigationManager.unifiedSearchSession
        @Bindable var viewModel = navigationManager.searchViewModel

        VStack(spacing: 0) {
            if !isSearching {
                SearchInputBar(
                    text: Bindable(session).query,
                    isFocused: _isSearchFieldFocused,
                    onSubmit: {
                        Task {
                            viewModel.addToHistory(session.query)
                            session.runSearch()
                            isSearchFieldFocused = false
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.appBackground)

                UnifiedSearchInputControls(session: session)
            }

            ZStack(alignment: .top) {
                if !session.results.isEmpty {
                    searchResultsView(session: session)
                } else if horizontalSizeClass == .regular {
                    searchRegularEmptyState(session: session, viewModel: viewModel)
                } else {
                    compactFilterView(viewModel: viewModel)
                }

                if !isSearching && isSearchFieldFocused {
                    SearchHistoryOverlay(
                        session: session,
                        viewModel: viewModel,
                        inputBarHeight: 0,
                        isVisible: .init(
                            get: { isSearchFieldFocused },
                            set: { isSearchFieldFocused = $0 ?? false }
                        )
                    )
                    .hideTabBarWhenKeyboardShown()
                    .zIndex(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, content: {
            UnifiedSearchProgressView(session: session)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        })
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ftsMigrationBanner()
        }
        .navigationBarTitleDisplayMode(session.results.isEmpty ? .automatic : .inline)
        .toolbar {
            UnifiedSearchToolbar(
                session: session,
                onLeadingAction: {
                    session.clearResults()
                    session.query = ""
                },
                showSortMenu: true,
                showSaveMenu: true,
                canSaveResults: canSaveResults,
                onSaveResults: { showingSaveResults = true },
                onSavedResults: { showingSavedResults = true }
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
        .sheet(isPresented: $showingSaveResults) {
            iOSResultWriterView(
                results: session.results,
                query: session.query,
                searchMode: session.scope == .exact ? .phrase : (session.scope == .fuzzy ? .contains : .near),
                searchViewModel: viewModel
            )
        }
        .sheet(isPresented: $showingSavedResults) {
            iOSSavedResultsView()
        }
        .animation(.easeInOut(duration: 0.5), value: session.results.isEmpty)
        .animation(.interpolatingSpring(stiffness: 300, damping: 20),
                   value: session.isSearching)
        .onAppear {
            session.searchViewModel = viewModel
            if session.selectedBookIds != viewModel.selectedBookIds {
                session.selectedBookIds = viewModel.selectedBookIds
            }
            if BackendCoordinator.shared.usesNativeMaktabahDataPath {
                ftsManager.checkNeedsMigration()
            }
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
        .overlay {
            if showFtsMigrationOverlay {
                Color.appBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                    }
                    .zIndex(10)

                FtsMigrationProgressView(
                    onCancel: {
                        showFtsMigrationOverlay = false
                    },
                    onUpdate: {
                        try await ftsManager.performMigration()
                        await MainActor.run { showFtsMigrationOverlay = false }
                    }
                )
                .zIndex(11)
                .transition(AnyTransition.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut, value: showFtsMigrationOverlay)
    }

    // MARK: - Sub-views

    private func compactFilterView(viewModel: SearchViewModel) -> some View {
        SearchFilterUIKitView(
            viewModel: viewModel,
            displayedCategories: viewModel.displayedCategories,
            updateTrigger: viewModel.updateTrigger,
            onTap: { isSearchFieldFocused = false }
        )
        .themeTint()
        .ignoresSafeArea(edges: .bottom)
    }

    private func searchRegularEmptyState(session: UnifiedSearchSessionController, viewModel: SearchViewModel) -> some View {
        ContentUnavailableView {
            Label("חיפוש בספרים", systemImage: "magnifyingglass")
        } description: {
            if session.selectedBookIds.isEmpty {
                Text("בחר ספרים בסרגל הצד או הקלד מילות חיפוש בשדה למעלה")
            } else {
                Text("נבחרו \(session.selectedBookIds.count) ספרים לחיפוש. הקלד מילות חיפוש בשדה למעלה ולחץ Enter.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func searchResultsView(session: UnifiedSearchSessionController) -> some View {
        let filtered: [SearchResultItem] = session.resultKitabFilter.isEmpty
            ? session.results
            : session.results.filter {
                $0.bookTitle
                    .normalizeArabic(false)
                    .contains(
                        session.resultKitabFilter.normalizeArabic(false)
                )
            }

        return SearchResultsListView(
            results: filtered,
            isLoadingMore: session.isLoadingMore,
            hasMore: session.hasMore,
            onLoadMore: {
                session.loadNextPage()
            },
            onSearchInBook: { item in
                session.searchInBook(item)
            }
        ) { item in
            session.openResult(item, using: navigationManager)
        }
        .searchable(
            text: Bindable(session).resultKitabFilter,
            placement: .toolbar,
            prompt: .filterByBooks
        )
    }

    @ViewBuilder
    private func ftsMigrationBanner() -> some View {
        if BackendCoordinator.shared.usesNativeMaktabahDataPath && ftsManager.needsMigration && !hideFtsMigrationBanner && !ftsManager.isMigrating {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text(.ftsMigrationAvailable)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                }

                VStack(spacing: 10) {
                    Button {
                        showFtsMigrationOverlay = true
                    } label: {
                        Text(.ftsMigrationUpdateNowCountBtn(
                            ftsManager.totalArchivesToMigrate
                        ))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(uiColor: .tintColor))

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
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .shadow(radius: 2)
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
