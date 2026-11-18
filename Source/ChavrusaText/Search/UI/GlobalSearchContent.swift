import SwiftUI

struct GlobalSearchContent<Results: View>: View {
    @Bindable var session: UnifiedSearchSessionController
    let viewModel: SearchViewModel
    let onSubmit: () -> Void
    @ViewBuilder let results: () -> Results

    var body: some View {
        Group {
            if session.resultsAreDirty {
                ContentUnavailableView {
                    Label("הגדרות החיפוש השתנו", systemImage: "arrow.clockwise")
                } description: {
                    Text("התוצאות הקודמות אינן מעודכנות. הפעילו חיפוש מחדש כדי להשתמש בשאילתה, בספרים ובהגדרות שנבחרו.")
                } actions: {
                    Button("חפש מחדש", action: onSubmit)
                        .disabled(session.optionsValidationMessage != nil || session.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("global-search-rerun")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("global-search-dirty")
            } else if session.isSearching {
                VStack(spacing: 12) {
                    ProgressView(session.statusText)
                    Button("עצור חיפוש") { session.cancelSearch() }
                        .accessibilityIdentifier("global-search-cancel")
                }
                .accessibilityIdentifier("global-search-loading")
            } else if session.wasCancelled {
                ContentUnavailableView {
                    Label("החיפוש בוטל", systemImage: "stop.circle")
                } actions: {
                    Button("חפש מחדש", action: onSubmit)
                        .accessibilityIdentifier("global-search-rerun")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("global-search-cancelled")
            } else if !session.results.isEmpty {
                VStack(spacing: 0) {
                    GlobalSearchResultsHeader(session: session)
                    if !session.resultKitabFilter.isEmpty && session.filteredResults.isEmpty {
                        ContentUnavailableView("אין התאמות בתוצאות שנטענו", systemImage: "line.3.horizontal.decrease",
                                               description: Text("נסו שם ספר אחר, נקו את הסינון או טענו תוצאות נוספות."))
                            .accessibilityIdentifier("global-search-filter-empty")
                    }
                    // The original list always remains mounted, including its Load More row at zero matches.
                    results()
                    if session.isLoadingMore {
                        Button("עצור טעינה") { session.cancelSearch() }
                            .accessibilityIdentifier("global-search-cancel")
                    }
                    GlobalSearchPagingFeedback(session: session)
                }
            } else if session.hasSubmitted {
                GlobalSearchEmptyFeedback(session: session, onSubmit: onSubmit)
            } else {
                GlobalSearchHistoryContent(session: session, viewModel: viewModel, onSubmit: onSubmit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onChange(of: session.requestConfiguration) { _, _ in session.configurationDidChange() }
    }
}

private struct GlobalSearchEmptyFeedback: View {
    let session: UnifiedSearchSessionController
    let onSubmit: () -> Void

    var body: some View {
        Group {
            if let error = session.errorMessage {
                ContentUnavailableView {
                    Label("החיפוש נכשל", systemImage: "exclamationmark.magnifyingglass")
                } description: { Text(error) } actions: {
                    Button("נסה שוב", action: onSubmit).accessibilityIdentifier("global-search-retry")
                    if !session.isSefaria {
                        Button("נתוני חיפוש") { session.showsSearchDataSheet = true }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("global-search-error")
            } else if session.packageMissing {
                ContentUnavailableView {
                    Label("נתוני החיפוש אינם מוכנים", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text(session.statusText) } actions: {
                    Button("נתוני חיפוש") { session.showsSearchDataSheet = true }
                        .accessibilityIdentifier("global-search-index-status")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("global-search-missing-index")
            } else {
                ContentUnavailableView("לא נמצאו תוצאות", systemImage: "magnifyingglass",
                                       description: Text("נסו לשנות את מילות החיפוש או את הספרים שנבחרו."))
                    .accessibilityIdentifier("global-search-empty")
            }
        }
    }
}

private struct GlobalSearchPagingFeedback: View {
    let session: UnifiedSearchSessionController
    var body: some View {
        if session.hasMore, !session.isLoadingMore, let message = session.errorMessage {
            VStack {
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("נסה לטעון שוב") { session.loadNextPage() }
                    .accessibilityIdentifier("global-search-page-retry")
            }
            .padding()
            .accessibilityIdentifier("global-search-page-error")
        }
    }
}
