import Combine
import Foundation

@MainActor
final class ZayitSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var matchMode: ZayitSearchMatchMode = .flexible
    @Published var hits: [ZayitSearchHit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var configured = false
    @Published var filters = ZayitSearchFilters()

    #if DEBUG
    /// Passive observation of real accepted provider pages; never supplies data.
    var nativePageObserver: ((ZayitSearchRequest, ZayitSearchPage, [ZayitSearchHit], Int) -> Void)?
    #endif

    private let repository: ZayitSearchRepository
    private var generation = 0
    let originalPageLedger = OriginalSearchPageLedger()
    private var searchTask: Task<Void, Never>?
    private var executedRequest: ZayitSearchRequest?
    private var nextOffset = 0
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var totalHits: UInt64 = 0

    init(repository: ZayitSearchRepository) {
        self.repository = repository
    }

    func configure(paths: ZayitSearchDataPaths) async throws {
        cancelSearch()
        let currentGeneration = generation
        do {
            try await repository.configure(paths: paths)
            guard generation == currentGeneration else { throw CancellationError() }
            configured = true
            errorMessage = nil
        } catch {
            if generation == currentGeneration {
                configured = false
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    func reset() async {
        cancelSearch()
        configured = false
        await repository.reset()
    }

    func cancelSearch() {
        generation += 1
        originalPageLedger.invalidate(generation: UInt64(generation))
        searchTask?.cancel()
        searchTask = nil
        executedRequest = nil
        nextOffset = 0
        hits = []
        totalHits = 0
        hasMore = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
    }

    func runSearch(filters: ZayitSearchFilters? = nil) {
        cancelSearch()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        guard configured else {
            errorMessage = "מנוע זית אינו מוכן. יש לבדוק את נתוני החיפוש ולנסות שוב."
            return
        }
        let request = ZayitSearchRequest(query: trimmedQuery, near: matchMode.nearValue,
                                        limit: 50, offset: 0, filters: filters ?? self.filters)
        executedRequest = request
        fetch(request, replacing: true)
    }

    func loadNextPage() {
        guard hasMore, !isLoading, !isLoadingMore, let request = executedRequest else { return }
        let next = ZayitSearchRequest(query: request.query, near: request.near,
                                     limit: request.limit, offset: nextOffset, filters: request.filters)
        fetch(next, replacing: false)
    }

    private func fetch(_ request: ZayitSearchRequest, replacing: Bool) {
        let currentGeneration = generation
        let configuration = ZayitSearchRequest(
            query: request.query, near: request.near, limit: request.limit,
            offset: 0, filters: request.filters
        )
        let attempt = originalPageLedger.begin(
            generation: UInt64(currentGeneration),
            request: .encode(request, configuration: configuration, offset: request.offset, limit: request.limit),
            replacing: replacing, consumedBefore: nextOffset, cursorBefore: nextOffset
        )
        if replacing { isLoading = true } else { isLoadingMore = true }
        errorMessage = nil
        searchTask = Task {
            do {
                let page = try await repository.search(query: request.query, near: request.near,
                                                       offset: request.offset, limit: request.limit,
                                                       filters: request.filters)
                guard currentGeneration == generation, !Task.isCancelled else {
                    originalPageLedger.fail(attempt, cancelled: Task.isCancelled)
                    return
                }
                var seen = Set(replacing ? [] : hits.map(\.id))
                let fresh = page.hits.filter { seen.insert($0.id).inserted }
                hits = replacing ? fresh : hits + fresh
                // Consume raw engine rows, including duplicates, for the cursor.
                nextOffset = request.offset + page.hits.count
                totalHits = page.totalHits
                hasMore = !page.isLastPage && !page.hits.isEmpty
                originalPageLedger.accept(
                    attempt, rawCount: page.hits.count, mappedCount: page.hits.count,
                    consumedAfter: nextOffset, cursorAfter: hasMore ? nextOffset : nil,
                    hasMore: hasMore, rawNextOffset: nextOffset, sourceEvidence: nil
                )
                #if DEBUG
                nativePageObserver?(request, page, hits, nextOffset)
                #endif
            } catch {
                originalPageLedger.fail(attempt, cancelled: Task.isCancelled || error is CancellationError)
                guard currentGeneration == generation, !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                if replacing { hits = []; hasMore = false }
                // Keep successful rows/cursor after a paging failure for retry.
            }
            guard currentGeneration == generation else { return }
            isLoading = false
            isLoadingMore = false
            searchTask = nil
        }
    }
}
