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
                    Text("חיפושים אחרונים")
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
