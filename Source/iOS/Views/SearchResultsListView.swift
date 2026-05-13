import SwiftUI

struct SearchResultsListView: View {
    let results: [SearchResultItem]
    var showsBookTitle: Bool = true
    let onSelect: (SearchResultItem) -> Void

    var body: some View {
        List(results, id: \.bookId) { item in
            Button(action: { onSelect(item) }) {
                SearchResultRow(item: item, showsBookTitle: showsBookTitle)
            }
        }
        .listStyle(.plain)
    }
}

struct SearchResultRow: View {
    let item: SearchResultItem
    var showsBookTitle: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text(
                    "ص: \(item.page)".convertToArabicDigits() +
                        " -" + "ج: \(item.part)".convertToArabicDigits()
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .environment(\.layoutDirection, .leftToRight)

                if showsBookTitle {
                    Spacer()

                    Text(item.bookTitle)
                        .font(iOSReaderViewModel.kfgqpc)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Text(AttributedString(item.attributedText))
                .font(iOSReaderViewModel.kfgqpc)
                .lineLimit(3)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
