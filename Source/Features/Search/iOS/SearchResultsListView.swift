import SwiftUI

struct SearchResultGroup: Identifiable {
    let id: String
    var versions: [SearchResultItem]

    var primaryItem: SearchResultItem {
        versions.first(where: { $0.resultLanguage == "he" || $0.resultLanguage == nil })
            ?? versions[0]
    }
}

struct SearchResultsListView: View {
    var results: [SearchResultItem] = []
    var showsBookTitle: Bool = true
    var isLoadingMore: Bool = false
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    var onSearchInBook: ((SearchResultItem) -> Void)? = nil
    var query: String = ""
    var mode: SearchMode = .phrase
    var nearDistance: Int = 10
    let onSelect: (SearchResultItem) -> Void

    @State private var expandedResultIDs: Set<String> = []
    @State private var selectedVersionIndex: [String: Int] = [:]

    private var keywords: [String] {
        FtsQueryParser.extractKeywords(query: query, mode: mode)
    }

    private var groupedResults: [SearchResultGroup] {
        var groups: [SearchResultGroup] = []
        var indexByKey: [String: Int] = [:]

        for item in results {
            let key = canonicalKey(for: item)
            if let idx = indexByKey[key] {
                if !groups[idx].versions.contains(where: { $0.stableID == item.stableID }) {
                    groups[idx].versions.append(item)
                }
            } else {
                indexByKey[key] = groups.count
                groups.append(SearchResultGroup(id: key, versions: [item]))
            }
        }
        return groups
    }

    private func canonicalKey(for item: SearchResultItem) -> String {
        if let locator = item.backendLocator {
            return locator.persistenceKey
        }
        return "\(item.archive):\(item.tableName):\(item.bookId):\(item.part):\(item.page)"
    }

    var body: some View {
        List {
            let groups = groupedResults
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                let activeIdx = selectedVersionIndex[group.id] ?? 0
                let item = group.versions.indices.contains(activeIdx) ? group.versions[activeIdx] : group.primaryItem
                let isExpanded = expandedResultIDs.contains(group.id)

                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                            if expandedResultIDs.remove(group.id) == nil {
                                expandedResultIDs.insert(group.id)
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            SearchResultRow(
                                item: item,
                                showsBookTitle: showsBookTitle,
                                isExpanded: isExpanded,
                                versionCount: group.versions.count,
                                selectedVersionIndex: Binding(
                                    get: { selectedVersionIndex[group.id] ?? 0 },
                                    set: { selectedVersionIndex[group.id] = $0 }
                                ),
                                versions: group.versions,
                                keywords: keywords,
                                mode: mode,
                                nearDistance: nearDistance
                            )
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Preview full search result"))
                    .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("search-result-preview-toggle-\(item.stableID)")

                    if isExpanded {
                        SearchResultContextPreview(item: item) {
                            onSelect(item)
                        }
                        .id(item.stableID)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .contextMenu {
                    Button(String(localized: "Open", defaultValue: "פתח"), systemImage: "book") { onSelect(item) }
                    Button(String(localized: "Copy", defaultValue: "העתק"), systemImage: "doc.on.doc") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = item.attributedText.string
                        #endif
                    }
                    Button(String(localized: "Copy with source", defaultValue: "העתק עם מקור"), systemImage: "text.quote") {
                        let source = item.bookTitle
                        let body = item.attributedText.string
                        let combined = [body, source].filter { !$0.isEmpty }.joined(separator: "\n")
                        #if canImport(UIKit)
                        UIPasteboard.general.string = combined
                        #endif
                    }
                    if let onSearchInBook {
                        Button(String(localized: "Search in this book", defaultValue: "חפש בספר זה"), systemImage: "magnifyingglass") {
                            onSearchInBook(item)
                        }
                    }
                }
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .id(group.id)
                .onAppear {
                    if index == groups.count - 5, hasMore, !isLoadingMore {
                        onLoadMore?()
                    }
                }
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if hasMore {
                Button(action: { onLoadMore?() }) {
                    HStack {
                        Spacer()
                        Text("Load more results", comment: "Load more search results button")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - SearchResultRow

struct SearchResultRow: View {
    let item: SearchResultItem
    var showsBookTitle: Bool = true
    var isExpanded: Bool = false
    var versionCount: Int = 1
    var selectedVersionIndex: Binding<Int>? = nil
    var versions: [SearchResultItem] = []
    var keywords: [String] = []
    var mode: SearchMode = .phrase
    var nearDistance: Int = 10
    @State private var resolvedSnippet: NSAttributedString?

    private var isHebrewBackend: Bool {
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.archive == "Zayit" || item.backendLocator != nil
    }

    static func locationText(for item: SearchResultItem) -> String {
        if let locationDisplayText = item.locationDisplayText, !locationDisplayText.isEmpty {
            return locationDisplayText
        }
        let isHebrew = item.archive == "Otzaria" || item.archive == "Sefaria" || item.archive == "Zayit" || item.backendLocator != nil
        if isHebrew {
            var parts: [String] = []
            if item.part > 0 {
                parts.append(String(format: NSLocalizedString("search.result.volume", value: "כרך %d", comment: ""), item.part))
            }
            if item.page > 0 {
                parts.append(String(format: NSLocalizedString("search.result.page", value: "עמ' %d", comment: ""), item.page))
            }
            return parts.joined(separator: " • ")
        } else {
            if item.page <= 0 && item.part <= 0 {
                return ""
            }
            return "ص: \(item.page)".convertToArabicDigits() +
                " -" + "ج: \(item.part)".convertToArabicDigits()
        }
    }

    private var locationText: String {
        Self.locationText(for: item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if showsBookTitle {
                    Text(item.bookTitle)
                        .font(isHebrewBackend ? .headline : ReaderViewModel.kfgqpcTitle)
                        .foregroundColor(Color.accentColor)
                }

                if !locationText.isEmpty {
                    Text(locationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let versionTitle = item.versionTitle, !versionTitle.isEmpty {
                    Text(versionTitle)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundColor(.secondary)
                }

                Spacer()

                if versionCount > 1, let selectedVersionIndex, !versions.isEmpty {
                    Menu {
                        ForEach(Array(versions.enumerated()), id: \.offset) { idx, ver in
                            Button {
                                selectedVersionIndex.wrappedValue = idx
                            } label: {
                                HStack {
                                    Text(ver.versionTitle ?? ver.resultLanguage?.uppercased() ?? "v\(idx + 1)")
                                    if selectedVersionIndex.wrappedValue == idx {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(item.resultLanguage?.uppercased() ?? "\(versionCount)v")
                                .font(.caption2.bold())
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let snippet = (item.hasResolvedSnippet ? item.attributedText : nil) ?? resolvedSnippet ?? SearchHitResolver.shared.cachedSnippet(for: item) {
                if !isExpanded {
                    Text(AttributedString(snippet))
                        .font(isHebrewBackend || !snippet.string.containsArabicCharacters ? .body : ReaderViewModel.kfgqpc)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("...")
                    .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                    .foregroundColor(.secondary)
                    .task(id: item.id) {
                        do {
                            try await Task.sleep(for: .seconds(0.05))
                        } catch {
                            return
                        }
                        guard !keywords.isEmpty else { return }
                        if let resolved = await SearchHitResolver.shared.resolveSnippet(
                            for: item,
                            keywords: keywords,
                            mode: mode,
                            nearDistance: nearDistance
                        ) {
                            resolvedSnippet = resolved
                        }
                    }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
