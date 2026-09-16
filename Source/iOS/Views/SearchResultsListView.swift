import SwiftUI

struct SearchResultsListView: View {
    let results: [SearchResultItem]
    var showsBookTitle: Bool = true
    var isLoadingMore: Bool = false
    var hasMore: Bool = false
    var onLoadMore: (() -> Void)? = nil
    let onSelect: (SearchResultItem) -> Void

    var body: some View {
        ThemeList(isGrouped: false) {
            ForEach(Array(results.enumerated()), id: \.offset) { index, item in
                Button(action: { onSelect(item) }) {
                    SearchResultRow(item: item, showsBookTitle: showsBookTitle)
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
                    Button("Search in book", systemImage: "magnifyingglass") { onSelect(item) }
                } preview: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.bookTitle).font(.headline)
                        let loc = SearchResultRow.locationText(for: item)
                        if !loc.isEmpty {
                            Text(loc).font(.caption).foregroundStyle(.secondary)
                        }
                        if !item.attributedText.string.isEmpty {
                            let hebrewBackend = item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
                            Text(AttributedString(item.attributedText))
                                .font(hebrewBackend ? .body : ReaderViewModel.kfgqpc)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding()
                    .frame(width: 360, alignment: .leading)
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

struct SearchResultRow: View {
    let item: SearchResultItem
    var showsBookTitle: Bool = true

    private var isHebrewBackend: Bool {
        item.archive == "Otzaria" || item.archive == "Sefaria" || item.backendLocator != nil
    }

    static func locationText(for item: SearchResultItem) -> String {
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

                    Divider()
                        .frame(maxHeight: 18)
                }

                Text(locationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
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

