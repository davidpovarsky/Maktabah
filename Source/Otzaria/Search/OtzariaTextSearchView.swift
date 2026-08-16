import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OtzariaTextSearchView: View {
    @Environment(iOSNavigationManager.self) private var navigationManager: iOSNavigationManager
    @StateObject private var viewModel = OtzariaTextSearchViewModel()
    @State private var didCopyIndexLog = false
    @State private var showsAdvancedOptions = false
    @FocusState private var searchFocused: Bool
    private let onOpenResult: ((SearchResultItem, String) -> Void)?

    init(onOpenResult: ((SearchResultItem, String) -> Void)? = nil) {
        self.onOpenResult = onOpenResult
    }

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
                    Label(indexActionTitle, systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isIndexing || viewModel.isSearching)

                Button {
                    copyIndexLog()
                } label: {
                    Label("העתק לוג אינדוקס", systemImage: "doc.on.doc")
                }
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

            DisclosureGroup("אפשרויות חיפוש מתקדמות", isExpanded: $showsAdvancedOptions) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("שאילתה שלילית", text: $viewModel.negativeQuery)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Picker("טווח", selection: $viewModel.scope) {
                            Text("מרחק מילים").tag(OtzariaSearchScope.wordDistance)
                            Text("אותה פסקה").tag(OtzariaSearchScope.sameParagraph)
                            Text("אותו סעיף").tag(OtzariaSearchScope.sameSection)
                        }
                        Picker("מילים נדרשות", selection: $viewModel.wordMatchMode) {
                            Text("כולן").tag(OtzariaWordMatchMode.all)
                            Text("מילה כלשהי").tag(OtzariaWordMatchMode.anyWord)
                            Text("רוב המילים").tag(OtzariaWordMatchMode.mostWords)
                            Text("לפחות…").tag(OtzariaWordMatchMode.atLeast)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Stepper(
                            "מרחק חיובי: \(viewModel.distance)",
                            value: $viewModel.distance,
                            in: 0...(viewModel.mode == .fuzzy ? 2 : 20)
                        )
                        Stepper(
                            "מרחק שלילי: \(viewModel.negativeDistance)",
                            value: $viewModel.negativeDistance,
                            in: 0...20
                        )
                    }

                    Picker("טווח לשאילתה השלילית", selection: $viewModel.negativeScope) {
                        Text("מרחק מילים").tag(OtzariaSearchScope.wordDistance)
                        Text("אותה פסקה").tag(OtzariaSearchScope.sameParagraph)
                        Text("אותו סעיף").tag(OtzariaSearchScope.sameSection)
                    }
                    .pickerStyle(.menu)

                    if viewModel.wordMatchMode == .atLeast {
                        Stepper(
                            "לפחות \(viewModel.wordMatchCount) מילים",
                            value: $viewModel.wordMatchCount,
                            in: 1...100
                        )
                    }

                    HStack {
                        Toggle("התאם ניקוד", isOn: $viewModel.matchNikud)
                        Toggle("התאם טעמים", isOn: $viewModel.matchTaamim)
                        Picker("קיבוץ", selection: $viewModel.grouping) {
                            Text("ללא").tag(nil as OtzariaResultGrouping?)
                            Text("אותו סעיף").tag(OtzariaResultGrouping.sameSection as OtzariaResultGrouping?)
                            Text("טקסט זהה").tag(OtzariaResultGrouping.identicalText as OtzariaResultGrouping?)
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.top, 8)
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

            if let detail = viewModel.indexStatusDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.totalCount > 0 {
                Text(resultCountLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.resultsTruncated {
                Label("ייתכן שהתוצאות חלקיות — צמצמו את החיפוש", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if didCopyIndexLog {
                Text("Index log copied.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let logURL = OtzariaIndexFileLogger.logFileURL() {
                Text("Log: \(logURL.path)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.results.isEmpty {
            emptyState
        } else {
            ThemeList(isGrouped: false) {
                ForEach(Array(viewModel.results.enumerated()), id: \.offset) { index, item in
                    Button { openResult(item) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            SearchResultRow(item: item)
                            if let engineResults = viewModel.enginePage?.results,
                               engineResults.indices.contains(index) {
                                let engineResult = engineResults[index]
                                if engineResult.mergedCount > 1 {
                                    Text("\(engineResult.mergedCount) תוצאות אוחדו")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(engineResult.merged.prefix(3), id: \.id) { sibling in
                                        Text("• \(sibling.title) — \(sibling.reference)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
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
        if let onOpenResult {
            onOpenResult(item, viewModel.query)
            return
        }
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

    private func copyIndexLog() {
        let text = viewModel.indexLogCopyText()
        #if canImport(UIKit)
        UIPasteboard.general.string = text.isEmpty ? "Otzaria index log is empty." : text
        #endif
        didCopyIndexLog = true
    }

    private var indexActionTitle: String {
        if case .paused = viewModel.status { return "המשך אינדוקס" }
        return "בנה/רענן אינדקס"
    }

    private var resultCountLabel: String {
        if let groups = viewModel.groupCount {
            return "\(viewModel.totalCount) תוצאות גולמיות · \(groups) קבוצות"
        }
        return "\(viewModel.totalCount) תוצאות"
    }
}
