import SwiftUI

struct SearchResultsListView: View {
    let results: [SearchResultItem]
    var showsBookTitle: Bool = true
    var isLoadingMore: Bool = false
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    var onSearchInBook: ((SearchResultItem) -> Void)? = nil
    let onSelect: (SearchResultItem) -> Void
    @State private var expandedResultIDs: Set<String> = []

    var body: some View {
        ThemeList(isGrouped: false) {
            ForEach(Array(results.enumerated()), id: \.element.stableID) { index, item in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                            if expandedResultIDs.remove(item.stableID) == nil {
                                expandedResultIDs.insert(item.stableID)
                            }
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            SearchResultRow(item: item, showsBookTitle: showsBookTitle)
                            Image(systemName: expandedResultIDs.contains(item.stableID) ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Preview full search result"))
                    .accessibilityValue(expandedResultIDs.contains(item.stableID) ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("search-result-preview-toggle-\(item.stableID)")

                    if expandedResultIDs.contains(item.stableID) {
                        SearchResultContextPreview(item: item) {
                            onSelect(item)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .contextMenu {
                    Button("Open", systemImage: "book") { onSelect(item) }
                    Button("Copy", systemImage: "doc.on.doc") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = item.attributedText.string
                        #endif
                    }
                    Button("Copy with source", systemImage: "text.quote") {
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
                        Button("Search in book", systemImage: "magnifyingglass") { onSearchInBook(item) }
                    }
                }
                .onAppear {
                    if index >= max(0, results.count - 10), hasMore, !isLoadingMore {
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
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.bookTitle).font(.headline)
                let location = SearchResultRow.locationText(for: item)
                if !location.isEmpty {
                    Text(location).font(.caption).foregroundStyle(.secondary)
                }
                if !fullSegments.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(fullSegments) { segment in
                            VStack(alignment: .leading, spacing: 6) {
                                if !segment.primary.isEmpty {
                                    Text(segment.primary)
                                        .font(isHebrewBackend ? .body : ReaderViewModel.kfgqpc)
                                        .multilineTextAlignment(.leading)
                                        .environment(\.layoutDirection, segment.primary.isParagraphRTL ? .rightToLeft : .leftToRight)
                                }
                                if let translation = segment.translation, !translation.isEmpty {
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
                    ProgressView("Loading full text…")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let previewError {
                    ContentUnavailableView {
                        Label("Full Text Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(previewError)
                    } actions: {
                        Button("Retry") { retryToken += 1 }
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
                        Label("Open", systemImage: "book")
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-result-expanded-preview-\(item.stableID)")
        .task(id: "\(item.backendLocator?.persistenceKey ?? "local"):\(retryToken)") {
            guard let locator = item.backendLocator else { return }
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
                    previewError = String(localized: "The full text for this result is empty.")
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

    private var isHebrewBackend: Bool {
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
    }

    static func locationText(for item: SearchResultItem) -> String {
        if let locationDisplayText = item.locationDisplayText, !locationDisplayText.isEmpty {
            return locationDisplayText
        }
        let isHebrew = item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
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
            HStack {
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

                if let versionTitle = item.versionTitle, !versionTitle.isEmpty {
                    Text(versionTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                }
            }

            Text(AttributedString(item.attributedText))
                .font(isHebrewBackend || !item.attributedText.string.containsArabicCharacters ? .body : ReaderViewModel.kfgqpc)
                .lineLimit(3)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
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

