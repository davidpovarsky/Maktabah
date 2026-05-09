import SwiftUI

struct SearchModeView: View {
    @Environment(iOSNavigationManager.self) var navigationManager: iOSNavigationManager
    @State private var showingFilter = false
    @State private var showingHelp = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        @Bindable var viewModel = navigationManager.searchViewModel
        VStack(spacing: 0) {
            if viewModel.results.isEmpty {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        SearchFilterUIKitView(viewModel: viewModel)
                            .ignoresSafeArea(edges: [.bottom])

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
                            .padding(.bottom, 8)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            .zIndex(2)
                        }
                    }

                    Divider()
                    // Search Bar
                    TextField("Search...", text: $viewModel.query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.addToHistory(viewModel.query)
                            viewModel.startSearch()
                        }
                        .frame(height: 40)
                        .padding([.leading, .trailing], 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 40)
                                .stroke(.tertiary, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    Picker("Mode", selection: $viewModel.searchMode) {
                        Text("==").tag(SearchMode.phrase)
                        Text("&").tag(SearchMode.contains)
                        Text("/").tag(SearchMode.or)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                // Results List
                SearchResultsListView(results: viewModel.results) { item in
                    handleSelection(item)
                }
            }

            // Progress
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
            }
        }
        .toolbar(content: {
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
        })
        .onChange(of: navigationManager.searchText) { _, newValue in
            viewModel.filterText = newValue
            viewModel.updateDisplayedCategories()
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
                SearchFilterUIKitView(viewModel: iOSSearchViewModel())
                    .navigationTitle("Filter Search")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .previewDisplayName("Search Filter")
        }
    }
}
