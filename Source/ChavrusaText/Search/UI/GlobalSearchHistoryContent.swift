import SwiftUI
import UIKit

struct GlobalSearchHistoryContent: View {
    let session: UnifiedSearchSessionController
    @Bindable var viewModel: SearchViewModel
    let onSubmit: () -> Void

    var body: some View {
        List {
            Section {
                if viewModel.searchHistory.isEmpty {
                    ContentUnavailableView("חיפוש בטקסט הספרים", systemImage: "magnifyingglass",
                                           description: Text("הקלידו מילים ולחצו על חיפוש.")
                                               .foregroundStyle(Color.primary))
                } else {
                    ForEach(viewModel.searchHistory, id: \.self) { query in
                        Button {
                            session.query = query
                            onSubmit()
                        } label: {
                            Label(query, systemImage: "clock")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("global-search-history-\(query)")
                        .swipeActions {
                            Button("מחק", role: .destructive) { viewModel.removeFromHistory(query) }
                        }
                    }
                }
            } header: {
                HStack {
                    NativeSearchHistoryHeading()
                    Spacer()
                    if !viewModel.searchHistory.isEmpty {
                        Button("נקה הכול") {
                            for query in viewModel.searchHistory { viewModel.removeFromHistory(query) }
                        }
                        .accessibilityIdentifier("global-search-history-clear")
                    }
                }
            }
            .listRowBackground(Color.appBackground)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
        .accessibilityIdentifier("global-search-history")
    }
}

/// A real UILabel supplies the heading's own accessibility frame. The native
/// List section host otherwise synthesizes a second, window-wide text element
/// even when its SwiftUI HStack uses `.contain` (Native run 44633736259).
private struct NativeSearchHistoryHeading: UIViewRepresentable {
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = "חיפושים אחרונים"
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .natural
        label.isAccessibilityElement = true
        label.accessibilityTraits.insert(.header)
        label.accessibilityIdentifier = "global-search-history-heading"
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = max(0, proposal.width ?? uiView.intrinsicContentSize.width)
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(width, fitted.width), height: fitted.height)
    }
}
