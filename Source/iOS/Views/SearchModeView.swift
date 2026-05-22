import SwiftUI
import Combine

struct SearchModeView: View {
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager
    @State private var showingFilter = false
    @State private var showingHelp = false
    @State private var showingSaveResults = false
    @State private var showingSavedResults = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var inputBarHeight: CGFloat = 60 // fallback default
    @State private var searchSubject = PassthroughSubject<String, Never>()

    var body: some View {
        @Bindable var viewModel = navigationManager.searchViewModel
        VStack(spacing: 0) {
            if viewModel.results.isEmpty {
                filterAndInputView(viewModel: viewModel)
            } else {
                searchResultsView(viewModel: viewModel)
            }

            searchProgressView(viewModel: viewModel)
        }
        .toolbar {
            toolbarContent(viewModel: viewModel)
        }
        .onChange(of: navigationManager.searchText) { _, newValue in
            searchSubject.send(newValue)
        }
        .onReceive(searchSubject.debounce(for: .seconds(0.3), scheduler: RunLoop.main)) { debouncedValue in
            viewModel.filterText = debouncedValue
            viewModel.updateDisplayedCategories()
        }
        .sheet(isPresented: $showingSaveResults) {
            iOSResultWriterView(results: viewModel.results, query: viewModel.query)
        }
        .sheet(isPresented: $showingSavedResults) {
            iOSSavedResultsView()
        }
    }

    // MARK: - Sub-views

    private func filterAndInputView(viewModel: iOSSearchViewModel) -> some View {
        ZStack(alignment: .bottom) {
            SearchFilterUIKitView(
                viewModel: viewModel,
                displayedCategories: viewModel.displayedCategories,
                updateTrigger: viewModel.updateTrigger,
                onTap: {
                    isSearchFieldFocused = false
                }
            )
            .ignoresSafeArea(edges: .vertical)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomInputBar(viewModel: viewModel)
                    .background {
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { inputBarHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, h in inputBarHeight = h }
                        }
                    }
            }

            searchHistoryOverlay(viewModel: viewModel)
        }
    }

    private func searchResultsView(viewModel: iOSSearchViewModel) -> some View {
        SearchResultsListView(results: viewModel.results) { item in
            handleSelection(item)
        }
    }

    @ViewBuilder
    private func searchProgressView(viewModel: iOSSearchViewModel) -> some View {
        let integrationStates = navigationManager.activeIntegrationStates
        if viewModel.isSearching || !integrationStates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isSearching {
                    VStack(alignment: .leading) {
                        ProgressView(
                            value: Double(viewModel.completedTables),
                            total: Double(max(viewModel.totalTables, 1))
                        )
                        .progressViewStyle(LinearProgressViewStyle())

                        if viewModel.totalRowsInTable > 0 {
                            ProgressView(
                                value: Double(viewModel.completedRowsInTable),
                                total: Double(viewModel.totalRowsInTable)
                            )
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }

                ActiveIntegrationStatesView()
            }
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: integrationStates.count)
        }
    }

    @ViewBuilder
    private func bottomInputBar(viewModel: iOSSearchViewModel) -> some View {
        @Bindable var viewModel = viewModel
        HStack(alignment: .center, spacing: 8) {
            // Search Bar
            TextField("Search...", text: $viewModel.query)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.addToHistory(viewModel.query)
                    viewModel.startSearch()
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(.quinary)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.secondary, lineWidth: 1)
                )
                .cornerRadius(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

            Picker("Mode", selection: $viewModel.searchMode) {
                Image(systemName: "text.quote").tag(SearchMode.phrase)
                Image(systemName: "checklist.checked").tag(SearchMode.contains)
                Image(systemName: "checklist").tag(SearchMode.or)
            }
            .frame(width: 120)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.vertical)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func searchHistoryOverlay(viewModel: iOSSearchViewModel) -> some View {
        if isSearchFieldFocused, !viewModel.searchHistory.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("Search History")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All") {
                        viewModel.searchHistory.forEach { viewModel.removeFromHistory($0) }
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                List {
                    ForEach(viewModel.searchHistory, id: \.self) { historyQuery in
                        Button(action: {
                            viewModel.query = historyQuery
                            viewModel.addToHistory(historyQuery)
                            isSearchFieldFocused = false
                            viewModel.startSearch()
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                Text(historyQuery)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            let item = viewModel.searchHistory[index]
                            viewModel.removeFromHistory(item)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .frame(maxHeight: 250)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
            .padding(.horizontal)
            .padding(.bottom, inputBarHeight)
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            .zIndex(2)
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(viewModel: iOSSearchViewModel) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isSearching {
                Button(action: { viewModel.stopSearch() }) {
                    Image(systemName: "stop")
                        .foregroundColor(.red)
                }
            } else {
                Button(action: { viewModel.startSearch() }) {
                    Image(systemName: "play")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showingSavedResults = true }) {
                Image(systemName: "bookmark")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.results.isEmpty {
                Button(action: { showingSaveResults = true }) {
                    Image(systemName: "pencil.line")
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                showingHelp = true
            }) {
                Image(systemName: "questionmark.circle")
            }
            .popover(isPresented: $showingHelp) {
                SearchHelpView()
                    .frame(width: 300, height: 450)
                    .presentationCompactAdaptation(.popover)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.results.isEmpty {
                Button(action: {
                    viewModel.stopSearch()
                    viewModel.results = []
                    viewModel.query = ""
                }) {
                    Image(systemName: "xmark.circle")
                }
            }
        }
    }

    private func handleSelection(_ item: SearchResultItem) {
        Task {
            let table = item.tableName.hasPrefix("b") ? String(item.tableName.dropFirst()) : item.tableName
            if let tableInt = Int(table), let bookData = LibraryDataManager.shared.getBook([tableInt]).first {
                await MainActor.run {
                    navigationManager.openBook(bookData, initialContentId: item.bookId)
                }
            }
        }
    }
}

// MARK: - Help View

struct SearchHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("searchOptionsHelp", comment: ""))
                    .font(.headline)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("exactSearchTitle", comment: ""))
                        .font(.subheadline).bold()
                    Text(NSLocalizedString("exactSearchDesc", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("separateWordsSearchTitle", comment: ""))
                        .font(.subheadline).bold()
                    Text(NSLocalizedString("separateWordsSearchDesc", comment: ""))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "anyWordsSearchTitle"))
                        .font(.subheadline).bold()
                    Text(String(localized: "anyWordsSearchDesc"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
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
                let vm = iOSSearchViewModel()
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
