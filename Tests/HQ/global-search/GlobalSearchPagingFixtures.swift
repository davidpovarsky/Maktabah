import Foundation
import Synchronization

// Actual production loadNextBackendPage/startSearch/stopSearch and canonical
// BackendPaginationState compile verbatim. Only provider/storage/native paths
// are doubles. Held continuations deliberately ignore cancellation to test
// superseded failures arriving after a newer request has started.
struct SearchResultItem: Equatable { let id: Int }
enum SearchMode { case phrase, contains, near, or
    var librarySearchMode: LibrarySearchMode {
        switch self { case .phrase: .phrase; case .contains: .contains; case .near: .near; case .or: .or }
    }
}
enum ViewModelState { case loading, loaded, error(String) }
enum LibraryBackendError: Error { case staleRequest }
enum FixtureFailure: LocalizedError {
    case page
    var errorDescription: String? { "controlled page failure" }
}
struct LibrarySearchRequest {
    let query: String; let offset: Int; let limit: Int; let filters: [String]; let scopeWorkKeys: [String]
    let options: LibrarySearchOptions
}
struct LibrarySearchPage { let hits: [SearchResultItem]; let total: Int; let nextOffset: Int? }
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var requests: [LibrarySearchRequest] = []
    var pending: [Int: CheckedContinuation<LibrarySearchPage, Error>] = [:]
    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        let index = requests.count
        requests.append(request)
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }
    func fail(_ index: Int) { pending.removeValue(forKey: index)!.resume(throwing: FixtureFailure.page) }
    func succeed(_ index: Int, ids: Range<Int>, next: Int?) {
        pending.removeValue(forKey: index)!.resume(returning: .init(hits: ids.map { .init(id: $0) }, total: 300, nextOffset: next))
    }
}
struct FixtureLocator { let workKey: String }
struct FixtureBook { let backendLocator: FixtureLocator?; let backendSearchPath: String? }
final class FixtureLibrary: @unchecked Sendable {
    var booksById: [Int: FixtureBook] = [:]
    func performSearch(params: LibrarySearchParams, callbacks: ()) async {}
}
actor FixtureSearchEngine {
    func currentlyPaused() -> Bool { false }; func isRunning() -> Bool { false }
    func stop() {}; func resume() {}; func pause() {}
}
struct LibrarySearchParams {
    let tableToScan: Set<String>; let searchEngine: FixtureSearchEngine
    let query: String; let mode: SearchMode; let nearDistance: Int
}
enum MaktabahBackendAdapter {
    static let usesGenericModels = true
    static func searchItem(_ item: SearchResultItem) -> SearchResultItem { item }
}
@MainActor final class SearchViewModel {
    var query = "baseline"; var selectedBookIds: Set<Int> = []
    var searchMode = SearchMode.phrase; var nearDistance = 10
    var backendSearchOptions = LibrarySearchOptions()
    var state = ViewModelState.loaded
    var results: [SearchResultItem] = (0..<50).map { .init(id: $0) }
    var isSearching = false; var isPaused = false; var isLoadingMoreBackendResults = false
    var backendPaginationErrorMessage: String?
    var backendSearchGeneration: UInt64 = 1
    var paginationState = BackendPaginationState(nextOffset: 50, totalResults: 300, loadedCount: 50, lastCommittedOffset: 0)
    var totalTables = 0; var completedTables = 0; var completedRowsInTable = 0; var totalRowsInTable = 0
    let backendPageSize = 100
    let loadMoreBackendWork = Mutex<Task<Void, Never>?>(nil)
    let searchWork = Mutex<Task<Void, Never>?>(nil)
    let ldm = FixtureLibrary(); let searchEngine = FixtureSearchEngine()
    func cancelCompletionDismiss() {}
    func clearSearchWork() { searchWork.withLock { $0?.cancel(); $0 = nil } }
    func resolveTablesToScan() -> Set<String> { [] }
    func makeLibrarySearchCallbacks() -> () { () }
}
struct SearchHitResolver {
    static let shared = SearchHitResolver()
    func clearCache() {}
}

@main struct GlobalSearchPagingFixtureRunner {
    static var assertions = 0
    @MainActor static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        guard condition() else { fatalError("FAIL actual paging: " + message) }
    }
    @MainActor static func wait(_ condition: () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("held provider did not start")
    }
    @MainActor static func main() async {
        let model = SearchViewModel(); let provider = BackendCoordinator.shared
        model.loadNextBackendPage()
        await wait { provider.requests.count == 1 }
        check(provider.requests[0].offset == 50, "real request consumes authoritative offset50")
        model.loadNextBackendPage()
        check(provider.requests.count == 1, "active-page duplicate is suppressed")
        let failed = model.loadMoreBackendWork.withLock { $0! }
        provider.fail(0); await failed.value
        check(model.results.count == 50 && model.paginationState.nextOffset == 50, "failure preserves rows and continuation")
        check(model.backendPaginationErrorMessage == "controlled page failure" && !model.isLoadingMoreBackendResults,
              "actual catch publishes error and releases loading")
        model.loadNextBackendPage()
        check(model.backendPaginationErrorMessage == nil, "actual retry clears prior error at start")
        await wait { provider.requests.count == 2 }
        check(provider.requests[1].offset == 50, "retry uses failed offset unchanged")
        let retry = model.loadMoreBackendWork.withLock { $0! }
        provider.succeed(1, ids: 50..<150, next: 150); await retry.value
        check(model.results.map(\.id) == Array(0..<150), "retry appends once in source order")
        check(model.paginationState.nextOffset == 150 && !model.isLoadingMoreBackendResults,
              "successful retry commits continuation and releases loading")

        // Superseded late failure while a newer page is actively loading.
        model.loadNextBackendPage(); await wait { provider.requests.count == 3 }
        let stale = model.loadMoreBackendWork.withLock { $0! }
        model.stopSearch()
        check(!model.isLoadingMoreBackendResults, "real stop cancels page task and releases loading")
        model.loadNextBackendPage(); await wait { provider.requests.count == 4 }
        let current = model.loadMoreBackendWork.withLock { $0! }
        provider.fail(2); await stale.value
        check(model.isLoadingMoreBackendResults && model.backendPaginationErrorMessage == nil,
              "late cancelled failure cannot clear newer loading or publish stale error")
        check(model.results.count == 150 && model.paginationState.nextOffset == 150,
              "superseded failure preserves current rows/continuation")
        provider.succeed(3, ids: 150..<250, next: 250); await current.value
        check(model.results.map(\.id) == Array(0..<250), "newer active page remains publishable")

        // Fresh initial search clears a prior page error in its actual body.
        model.loadNextBackendPage(); await wait { provider.requests.count == 5 }
        let errorPage = model.loadMoreBackendWork.withLock { $0! }
        provider.fail(4); await errorPage.value
        check(model.backendPaginationErrorMessage != nil, "second controlled failure actually reached catch")
        model.stopSearch(); model.query = "fresh"
        let initial = Task { @MainActor in await model.startSearch() }
        await wait { provider.requests.count == 6 }
        check(provider.requests[5].offset == 0 && model.backendPaginationErrorMessage == nil && model.results.isEmpty,
              "actual new search resets old page error/rows and starts offset0")
        provider.succeed(5, ids: 1000..<1100, next: 100); await initial.value
        check(model.results.map(\.id) == Array(1000..<1100) && model.paginationState.nextOffset == 100,
              "fresh initial request replaces old results with correct paging")

        // A cancelled old page may fail after an entirely new search succeeds.
        model.loadNextBackendPage(); await wait { provider.requests.count == 7 }
        let old = model.loadMoreBackendWork.withLock { $0! }
        model.stopSearch(); model.query = "newest"
        let newest = Task { @MainActor in await model.startSearch() }
        await wait { provider.requests.count == 8 }
        provider.succeed(7, ids: 2000..<2010, next: nil); await newest.value
        provider.fail(6); await old.value
        check(model.results.map(\.id) == Array(2000..<2010) && model.backendPaginationErrorMessage == nil,
              "late old page error cannot overwrite newly completed search")
        check(!model.isSearching && !model.isLoadingMoreBackendResults && !model.paginationState.hasMore,
              "late cleanup cannot resurrect loading/paging")
        check(provider.pending.isEmpty, "all held continuations consumed; no hidden pending backend operation")
        print("PASS: \(assertions) ACTUAL Search+Execution paging/cancellation assertions with held/throwing provider; native NOT_RUN")
    }
}
