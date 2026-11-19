import SwiftUI

struct GlobalSearchHistoryContent: View {
    let session: UnifiedSearchSessionController
    @Bindable var viewModel: SearchViewModel
    let onSubmit: () -> Void

    var body: some View {
        List {
            Section {
                if viewModel.searchHistory.isEmpty {
                    ContentUnavailableView("חיפוש בטקסט הספרים", systemImage: "magnifyingglass",
                                           description: Text("הקלידו מילים ולחצו על חיפוש."))
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
                    // Hierarchical .primary still inherits the native section
                    // header's subdued style. Use the dynamic system label color
                    // explicitly against the original sepia/system background.
                    Text("חיפושים אחרונים")
                        .foregroundStyle(Color(uiColor: .label))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("global-search-history-heading")
                    Spacer()
                    if !viewModel.searchHistory.isEmpty {
                        Button("נקה הכול") {
                            for query in viewModel.searchHistory { viewModel.removeFromHistory(query) }
                        }
                        .accessibilityIdentifier("global-search-history-clear")
                    }
                }
                // Keep the heading and Clear action as their own native
                // accessibility elements. Combining this split-view section
                // header gave its text the entire window's AX frame, including
                // the unrelated book sidebar, rather than its rendered bounds.
                .accessibilityElement(children: .contain)
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
