import SwiftUI

struct GlobalSearchResultsHeader: View {
    @Bindable var session: UnifiedSearchSessionController
    @State private var showsFilter = false
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("תוצאות חיפוש").font(.headline)
                    Text(session.loadedResultsSummary)
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("global-search-count")
                }
                Spacer(minLength: 8)
                GlassEffectContainer {
                    HStack(spacing: 12) {
                        Button {
                            showsFilter.toggle()
                            if !showsFilter { session.resultKitabFilter = "" }
                            filterFocused = showsFilter
                        } label: {
                            Image(systemName: "magnifyingglass").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(showsFilter ? "סגור סינון תוצאות" : "סינון תוצאות לפי ספר")
                        .accessibilityIdentifier("global-search-result-filter-toggle")
                        if session.supportsResultSorting {
                            Menu {
                                if session.isSefaria {
                                    Picker("מיון", selection: $session.sefariaSortOrder) {
                                        Text("רלוונטיות").tag(LibrarySearchSortOrder.relevance)
                                        Text("סדר קנוני").tag(LibrarySearchSortOrder.canonical)
                                        Text("סדר כרונולוגי").tag(LibrarySearchSortOrder.chronological)
                                    }
                                    Toggle("סדר הפוך", isOn: $session.sefariaReverseSort)
                                } else {
                                    Picker("מיון", selection: $session.otzariaOrder) {
                                        ForEach(OtzariaSearchOrder.allCases, id: \.self) { order in
                                            Text(order.label).tag(order)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down").frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("מיון תוצאות")
                            .accessibilityIdentifier("global-search-sort")
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }
            if showsFilter || !session.resultKitabFilter.isEmpty {
                HStack {
                    TextField("סינון תוצאות שנטענו לפי שם הספר…", text: $session.resultKitabFilter)
                        .textFieldStyle(.roundedBorder)
                        .focused($filterFocused)
                        .submitLabel(.done)
                        .onSubmit { filterFocused = false }
                        .accessibilityIdentifier("global-search-result-filter")
                    Button("סיום") {
                        session.resultKitabFilter = ""
                        showsFilter = false
                        filterFocused = false
                    }
                    .accessibilityIdentifier("global-search-result-filter-done")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.appBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("global-search-results-header")
    }
}
