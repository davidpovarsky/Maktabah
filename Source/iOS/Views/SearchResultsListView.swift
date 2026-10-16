import SwiftUI

struct SearchResultGroup: Identifiable {
    let id: String
    var versions: [SearchResultItem]

    var primaryItem: SearchResultItem {
        versions.first!
    }
}

struct SearchResultsListView: View {
    let results: [SearchResultItem]
    var showsBookTitle: Bool = true
    var isLoadingMore: Bool = false
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    var onSearchInBook: ((SearchResultItem) -> Void)? = nil
    let onSelect: (SearchResultItem) -> Void

    @State private var expandedResultIDs: Set<String> = []
    @State private var selectedVersionIndex: [String: Int] = [:]

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
        ThemeList(isGrouped: false) {
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
                                versions: group.versions
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
                    ShareLink(item: [item.bookTitle, item.attributedText.string]
                        .filter { !$0.isEmpty }.joined(separator: "\n"))
                    if let onSearchInBook {
                        Button(String(localized: "Search in book", defaultValue: "חפש בספר"), systemImage: "magnifyingglass") { onSearchInBook(item) }
                    }
                }
                .onAppear {
                    if index >= max(0, groups.count - 10), hasMore, !isLoadingMore {
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
            }
        }
        .listStyle(.plain)
    }
}

struct SearchResultContextPreview: View {
    let item: SearchResultItem
    var onOpen: (() -> Void)? = nil
    @State private var fullSegments: [SearchPreviewSegment] = []
    @State private var previewError: String?
    @State private var isLoading = false
    @State private var retryToken = 0

    private var isHebrewBackend: Bool {
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.archive == "Zayit" || item.backendLocator != nil
    }

    private var readerMode: LibraryReaderTextMode {
        TextViewState.shared.readerTextMode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !fullSegments.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        let isTranslationVersion = (item.resultLanguage != nil && item.resultLanguage != "he")
                        ForEach(fullSegments) { segment in
                            let showPrimary = isTranslationVersion
                                ? (segment.translation == nil || segment.translation!.isEmpty)
                                : (readerMode == .source || readerMode == .both || (readerMode == .translation && (segment.translation == nil || segment.translation!.isEmpty)))
                            let showTranslation = isTranslationVersion
                                ? (segment.translation != nil && !segment.translation!.isEmpty)
                                : ((readerMode == .translation || readerMode == .both || (readerMode == .source && segment.primary.isEmpty)) && segment.translation != nil && !segment.translation!.isEmpty)

                            VStack(alignment: .leading, spacing: 6) {
                                if showPrimary && !segment.primary.isEmpty {
                                    Text(segment.primary)
                                        .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                                        .multilineTextAlignment(.leading)
                                        .environment(\.layoutDirection, segment.primary.isParagraphRTL ? .rightToLeft : .leftToRight)
                                }
                                if showTranslation, let translation = segment.translation, !translation.isEmpty {
                                    Text(translation)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                        .environment(\.layoutDirection, translation.isParagraphRTL ? .rightToLeft : .leftToRight)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .textSelection(.enabled)
                } else if isLoading {
                    ProgressView(String(localized: "Loading full text…", defaultValue: "טוען טקסט מלא…"))
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let previewError {
                    ContentUnavailableView {
                        Label(String(localized: "Full Text Unavailable", defaultValue: "הטקסט המלא אינו זמין"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(previewError)
                    } actions: {
                        Button(String(localized: "Retry", defaultValue: "נסה שוב")) { retryToken += 1 }
                    }
                } else if !item.attributedText.string.isEmpty {
                    Text(AttributedString(item.attributedText))
                        .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                        .multilineTextAlignment(.leading)
                } else {
                    ProgressView()
                }

                if let onOpen {
                    Button(action: onOpen) {
                        Label(String(localized: "Open", defaultValue: "פתח"), systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("search-result-open-\(item.stableID)")
                    .padding(.top, 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("search-result-expanded-preview-\(item.stableID)")
                .accessibilityLabel(String(localized: "Expanded search preview", defaultValue: "תצוגה מקדימה מורחבת"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-result-expanded-preview-\(item.stableID)")
        .task(id: "\(item.stableID):\(retryToken)") {
            guard let locator = item.backendLocator else {
                if item.attributedText.string.isEmpty {
                    previewError = String(localized: "The full text for this result is empty.", defaultValue: "הטקסט המלא עבור תוצאה זו ריק.")
                }
                return
            }
            isLoading = true
            previewError = nil
            do {
                let section = try await BackendCoordinator.shared.section(at: locator)
                try Task.checkCancellation()
                fullSegments = section.segments.compactMap { segment in
                    let primary = segment.primaryText.readerPlainText
                    let translation = segment.translation?.readerPlainText
                    guard !primary.isEmpty || translation?.isEmpty == false else { return nil }
                    return SearchPreviewSegment(
                        id: segment.locator.persistenceKey,
                        primary: primary,
                        translation: translation
                    )
                }
                if fullSegments.isEmpty {
                    previewError = String(localized: "The full text for this result is empty.", defaultValue: "הטקסט המלא עבור תוצאה זו ריק.")
                }
            } catch is CancellationError {
                return
            } catch {
                previewError = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct SearchPreviewSegment: Identifiable {
    let id: String
    let primary: String
    let translation: String?
}

struct SearchResultRow: View {
    let item: SearchResultItem
    var showsBookTitle: Bool = true
    var isExpanded: Bool = false
    var versionCount: Int = 1
    var selectedVersionIndex: Binding<Int>? = nil
    var versions: [SearchResultItem] = []

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                if showsBookTitle {
                    Text(item.bookTitle)
                        .font(isHebrewBackend || !item.bookTitle.containsArabicCharacters ? .headline : ReaderViewModel.kfgqpcTitle)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    if !locationText.isEmpty {
                        Divider()
                            .frame(maxHeight: 18)
                    }
                }

                if !locationText.isEmpty {
                    Text(locationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if versionCount > 1, let selectedBinding = selectedVersionIndex {
                    Menu {
                        ForEach(Array(versions.enumerated()), id: \.offset) { idx, v in
                            Button {
                                selectedBinding.wrappedValue = idx
                            } label: {
                                HStack {
                                    Text(v.versionTitle ?? v.resultLanguage ?? "Version \(idx + 1)")
                                    if idx == selectedBinding.wrappedValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(item.versionTitle ?? item.resultLanguage ?? "גרסה")
                            Text("(\(versionCount))")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                } else if let versionTitle = item.versionTitle, !versionTitle.isEmpty {
                    Text(versionTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                }
            }

            if !isExpanded {
                Text(AttributedString(item.attributedText))
                    .font(isHebrewBackend || !item.attributedText.string.containsArabicCharacters ? .body : ReaderViewModel.kfgqpc)
                    .lineLimit(3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    let items = [
        SearchResultItem(
            archive: "1",
            tableName: "t1",
            bookId: 1,
            bookTitle: "كتاب الإيمان",
            page: 12,
            part: 1,
            attributedText: NSAttributedString(string: "هذا نص تجريبي للبحث الأول يوضح كيفية ظهور نتائج البحث.")
        ),
        SearchResultItem(
            archive: "1",
            tableName: "t1",
            bookId: 2,
            bookTitle: "صحيح البخاري",
            page: 45,
            part: 2,
            attributedText: NSAttributedString(string: "مثال آخر لنتيجة البحث يحتوي على بعض الكلمات المفتاحية.")
        ),
        SearchResultItem(
            archive: "1",
            tableName: "t1",
            bookId: 3,
            bookTitle: "فتح الباري",
            page: 108,
            part: 3,
            attributedText: NSAttributedString(string: "النص الثالث والأخير في المعاينة لتأكيد جودة التصميم والترتيب.")
        )
    ]
    
    return SearchResultsListView(results: items, onSelect: { _ in })
}
