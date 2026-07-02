import SwiftUI

struct OtzariaTextSearchView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @StateObject private var viewModel = OtzariaTextSearchViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            viewModel.refreshStatus()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.isIndexing {
                    Button(role: .cancel) {
                        viewModel.cancelIndexing()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                }

                Button {
                    viewModel.rebuildIndex()
                } label: {
                    Label("בנה/רענן אינדקס", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isIndexing || viewModel.isSearching)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("חפש בכל טקסטי אוצריא", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { viewModel.search() }

                Button {
                    viewModel.search()
                    searchFocused = false
                } label: {
                    Label("חפש", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching || viewModel.isIndexing)
            }

            HStack(spacing: 12) {
                Picker("מצב", selection: $viewModel.mode) {
                    ForEach(OtzariaSearchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("סדר", selection: $viewModel.order) {
                    Text("סדר ספרים").tag(OtzariaSearchOrder.catalogue)
                    Text("רלוונטיות").tag(OtzariaSearchOrder.relevance)
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text(viewModel.status.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.isSearching || viewModel.isIndexing {
                    ProgressView()
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.results.isEmpty {
            emptyState
        } else {
            SearchResultsListView(results: viewModel.results) { item in
                openResult(item)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("חיפוש טקסטים באוצריא")
                .font(.headline)
            Text("בפעם הראשונה לחץ על 'בנה/רענן אינדקס'. לאחר מכן החיפוש רץ דרך מנוע Rust/Tantivy של אוצריא, ולא דרך SQLite FTS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openResult(_ item: SearchResultItem) {
        Task {
            guard let bookData = LibraryDataManager.shared.getBook([item.bookId]).first else { return }
            await MainActor.run {
                navigationManager.openBook(
                    bookData,
                    initialContentId: item.page,
                    searchText: viewModel.query
                )
            }
        }
    }
}
