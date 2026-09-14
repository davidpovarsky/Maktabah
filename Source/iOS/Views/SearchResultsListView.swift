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

    private var locationText: String {
        if isHebrewBackend {
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

