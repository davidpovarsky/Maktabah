import Foundation
import Observation
import Combine

// Explicit engine/backend doubles. These tests prove request routing and stale
// publication rejection, never real engine ranking, UI or physical acceptance.
struct SearchResultItem {
    let bookTitle: String
    init(_ title: String) { bookTitle = title }
}
enum SearchMode { case phrase, contains, near }
enum ViewModelState { case loading, loaded, error(String) }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var generation: UInt64 = 0
    var activeBackendID: BackendID = .otzaria
    var activeCapabilities: BackendCapabilities = [.search]
    var usesNativeMaktabahDataPath: Bool { activeBackendID == .otzaria }
}
enum OtzariaDataProfileRegistry { static let activeProfileID = "explicit-test-profile" }
enum ZayitSearchExistingDatabaseProvider { static let currentURL: URL? = nil }
enum OtzariaSearchEngineBridge {
    static func splitQueryWords(_ text: String) throws -> [String] { text.split(separator: " ").map(String.init) }
}
extension String {
    func normalizeArabic(_ flag: Bool) -> String { lowercased() }
    init(localized: String, defaultValue: String) { self = defaultValue }
}
@MainActor final class ZayitSearchModelDouble {
    var matchMode: ZayitSearchMatchMode = .flexible
    var query = ""; var hits: [ZayitSearchHit] = []; var errorMessage: String?
    var isLoading = false; var isLoadingMore = false; var hasMore = false; var totalHits: UInt64 = 0
    var searchCalls = 0; var cancelCalls = 0; var pageCalls = 0
    func cancelSearch() { cancelCalls += 1; isLoading = false; isLoadingMore = false; hits = [] }
    func runSearch(filters: ZayitSearchFilters) { searchCalls += 1; isLoading = true }
    func loadNextPage() { pageCalls += 1 }
}
@MainActor final class ZayitSearchSessionController: ObservableObject {
    enum State: Equatable { case ready, restoring, notConfigured, failed(String) }
    var state: State = .ready
    let model = ZayitSearchModelDouble()
    func restoreIfNeeded(existingSeforimDB: URL?) async {}
}
@Observable @MainActor final class SearchViewModel {
    var query = ""; var selectedBookIds: Set<Int> = []
    var searchMode: SearchMode = .phrase; var nearDistance = 10
    var backendSearchOptions = LibrarySearchOptions()
    var state: ViewModelState = .loaded
    var results: [SearchResultItem] = []
    var isSearching = false; var isLoadingMoreBackendResults = false; var hasMoreBackendResults = false
    var backendPaginationErrorMessage: String?
    var totalTables = 0; var searchCalls = 0; var stopCalls = 0; var pageCalls = 0
    var delayNanoseconds: UInt64 = 0
    func setSelectedBooks(_ ids: Set<Int>) { selectedBookIds = ids }
    func startSearch() async {
        searchCalls += 1; isSearching = true
        do { if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) } }
        catch { isSearching = false; return }
        results = [.init(query)]; isSearching = false; hasMoreBackendResults = true
    }
    func stopSearch() { stopCalls += 1; isSearching = false; isLoadingMoreBackendResults = false }
    func clearResults() { stopSearch(); results = [] }
    func loadNextBackendPage() { pageCalls += 1; isLoadingMoreBackendResults = true }
}

@main struct GlobalSearchPresentationFixtureRunner {
    static var assertions = 0
    @MainActor static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard value() else { fatalError("FAIL: " + message) }
    }
    @MainActor static func settle() async {
        for _ in 0..<12 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    @MainActor static func main() async {
        let backend = BackendCoordinator.shared
        let session = UnifiedSearchSessionController()
        let model = SearchViewModel()
        session.searchViewModel = model
        check(session.scope == .advanced, "existing default advanced is preserved")
        session.query = "one two three"
        session.otzariaDistance = 7
        session.otzariaScope = .sameParagraph
        session.otzariaNegativeQuery = "excluded"
        session.otzariaNegativeScope = .sameSection
        session.otzariaNegativeDistance = 4
        session.otzariaGrouping = .identicalText
        session.runSearch()
        check(session.otzaria.searchCalls == 1 && session.submissionRevision == 1, "single accepted submit")
        check(session.otzaria.scope == .sameParagraph && session.otzaria.negativeScope == .sameSection,
              "missing positive/negative scope bindings reach existing engine")
        check(session.otzaria.grouping == .identicalText && session.otzaria.negativeDistance == 4,
              "grouping and negative distance reach engine")
        check(session.otzaria.customSpacing.isEmpty, "blank spacing retains global distance semantics")
        session.runSearch()
        check(session.otzaria.searchCalls == 1, "duplicate active submit does not create another request")
        session.results = [.init("Alpha"), .init("Beta")]; session.hasMore = true
        session.resultKitabFilter = "missing"
        check(session.filteredResults.isEmpty && session.hasMore, "zero loaded matches retains paging")
        check(!session.resultsAreDirty && session.submissionRevision == 1, "local filter never dirties/reruns engine")
        check(session.selectedBookIds.isEmpty && session.query == "one two three", "local filter preserves scope/query")
        check(session.loadedResultsSummary.contains("0 מתוך 2"), "filtered count explicitly describes loaded results")
        var rowRequests = 0
        for count in [5, 6, 10, 50, 100] {
            for index in 0..<count {
                realRowPrefetch(index: index, groups: Array(0..<count), hasMore: true, isLoadingMore: false,
                                automaticallyLoadsMore: false, onLoadMore: { rowRequests += 1 })
            }
            check(rowRequests == 0, "local filtered projection at \(count) rows never prefetches source pages")
        }
        realRowPrefetch(index: 5, groups: Array(0..<10), hasMore: true, isLoadingMore: false,
                        automaticallyLoadsMore: true, onLoadMore: { rowRequests += 1 })
        check(rowRequests == 1, "normal unfiltered prefetch is preserved")
        session.cancelSearch()
        check(session.wasCancelled && !session.isSearching && !session.hasMore, "cancel has a distinct terminal state")
        check(session.cancellationRevision == 1 && session.otzaria.clearCalls >= 2 && model.stopCalls >= 2,
              "cancel actually invokes all existing task/engine cancellation paths")
        session.runSearch()
        session.selectedBookIds = [42]
        session.configurationDidChange()
        check(session.resultsAreDirty && !session.isSearching, "changing books cancels and marks dirty")
        session.selectedBookIds = []
        check(session.resultsAreDirty, "reverting inputs cannot revive a cancelled result set")
        session.runSearch()
        check(!session.resultsAreDirty, "one explicit rerun commits the new configuration")
        session.otzariaCustomSpacingText = "2,,4"
        session.otzariaAlternativeWordsText = ";alpha,beta;;gamma"
        session.runSearch()
        check(session.otzaria.customSpacing == ["0-1": "2", "1-2": "", "2-3": "4"], "spacing empty positions preserved")
        check(session.otzaria.alternativeWords["0"] == [] && session.otzaria.alternativeWords["1"] == ["alpha", "beta"]
              && session.otzaria.alternativeWords["3"] == ["gamma"], "alternative positions preserved without compaction")
        session.otzariaCustomSpacingText = "invalid"
        let submissions = session.submissionRevision
        session.runSearch()
        check(session.errorMessage != nil && session.submissionRevision == submissions, "invalid options never dispatch engine")
        session.scope = .exact
        session.runSearch()
        check(session.otzaria.negativeQuery.isEmpty && session.otzaria.grouping == nil && session.otzaria.customSpacing.isEmpty,
              "hidden advanced options never leak into exact mode")
        backend.activeBackendID = .sefariaEmbedded
        session.handleBackendChanged()
        check(session.availableScopes == [.exact] && !session.supportsSefariaOptions && !session.supportsResultSorting,
              "Embedded hides every ignored advanced/sort control")
        session.query = "embedded"; session.runSearch(); await settle()
        check(model.searchCalls == 1 && model.searchMode == .phrase && model.backendSearchOptions.matchMode == .exact,
              "Embedded dispatches exact only")
        check(!model.backendSearchOptions.reverseSort && model.backendSearchOptions.wordDistance == 0,
              "Embedded does not silently forward ignored options")
        check(session.loadedResultsSummary.contains("אינו מאומת"), "unknown total precision is explicit")
        backend.activeBackendID = .sefaria
        session.handleBackendChanged(); session.query = "legacy"
        session.sefariaMatchMode = .hebrewLemmatized; session.sefariaWordDistance = 8
        session.runSearch(); await settle()
        check(model.searchMode == .near && model.nearDistance == 8 && model.backendSearchOptions.matchMode == .hebrewLemmatized,
              "legacy actual SearchViewModel mode preserves advanced match/distance")
        check(session.results.count == 1 && session.hasMore, "legacy initial completion publishes live results")
        session.resultKitabFilter = "no loaded matches"
        let beforeFiltering = session.paginationRevision
        _ = session.filteredResults
        check(session.filteredResults.isEmpty && model.pageCalls == 0 && session.paginationRevision == beforeFiltering,
              "loaded filter does not invoke paging provider or initial search")
        session.loadNextPage()
        await settle()
        check(model.pageCalls == 1 && session.isLoadingMore, "legacy page start is observed")
        model.backendPaginationErrorMessage = "held-page-failure"; model.isLoadingMoreBackendResults = false
        await settle()
        check(session.errorMessage == "held-page-failure" && !session.isLoadingMore && session.results.count == 1,
              "page failure is distinct and preserves previous results")
        session.loadNextPage(); model.backendPaginationErrorMessage = nil
        model.results.append(.init("second page")); model.isLoadingMoreBackendResults = false
        await settle()
        check(session.results.count == 2 && session.errorMessage == nil, "page retry/live observation retains late results")
        check(model.pageCalls == 2 && session.paginationRevision == beforeFiltering + 2,
              "explicit paging is retained even while local matches are empty")
        session.query = "held"; model.delayNanoseconds = 100_000_000
        session.runSearch(); await settle(); session.cancelSearch()
        await settle()
        check(session.wasCancelled && session.results.isEmpty && !session.isSearching, "cancel held async task rejects publication")
        try? await Task.sleep(nanoseconds: 120_000_000)
        check(session.results.isEmpty && session.wasCancelled, "late async completion cannot resurrect cancelled results")
        session.clearResults()
        check(!session.hasSubmitted && !session.wasCancelled && session.resultKitabFilter.isEmpty, "reset restores canonical pre-search state")
        print("PASS: \(assertions) Global Search presentation/orchestration assertions; boundary doubles, real Observation; native NOT_RUN")
    }
}
