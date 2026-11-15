// The full production OtzariaTextSearchViewModel is compiled unchanged by the
// harness. Only its repository, indexing/storage/backend and UI dependencies
// are doubles; no real index, network, installer or user data is accessed.
import Foundation

final class OtzariaMaktabahBridge: @unchecked Sendable {
    static let shared = OtzariaMaktabahBridge()
    var databasePath: String? = "fixture-database"
}
@MainActor final class BackendCoordinator {
    static let shared = BackendCoordinator()
    var generation: UInt64 = 0
}
struct OtzariaSearchArtifactStorage: Sendable {
    init() throws {}
    func stagingURL(databasePath: String) -> URL { FixtureEnvironment.root.appendingPathComponent("never-staging") }
}
struct OtzariaSearchArtifactInstaller: Sendable {
    func recover(databasePath: String, storage: OtzariaSearchArtifactStorage) {}
}
final class OtzariaSearchIndexManager: @unchecked Sendable {
    static let shared = OtzariaSearchIndexManager()
    func indexURL(for path: String) -> URL { FixtureEnvironment.root.appendingPathComponent("otzaria-viewmodel-index") }
    func previousIndexURL(for path: String) -> URL { FixtureEnvironment.root.appendingPathComponent("never-previous") }
    func buildingIndexURL(for path: String) -> URL { FixtureEnvironment.root.appendingPathComponent("never-building") }
    func validateCurrentIndex(databasePath: String) throws -> UInt64 { 300 }
    func trustedManagedArtifactIdentity(databasePath: String) -> String? { nil }
    func compatibility(databasePath: String) -> OtzariaIndexCompatibility? { nil }
    func checkpoint(indexURL: URL) -> OtzariaIndexCheckpoint? { nil }
    func clearIndex(databasePath: String) throws {}
}
struct FixtureIndexingProgress: Sendable {
    let processedBooks: Int
    let totalBooks: Int
    let processedLines: Int
}
actor OtzariaSearchIndexingService {
    static let shared = OtzariaSearchIndexingService()
    func rebuildIndex(databasePath: String, progress: @escaping @Sendable (FixtureIndexingProgress) -> Void) throws -> UInt64 {
        throw FixtureError.expected
    }
}
struct OtzariaSearchArtifactProgress: Sendable {
    enum Stage: Sendable { case downloading, verifying, extracting, installing, ready }
    let stage: Stage
    let completedBytes: Int64
    let totalBytes: Int64
}
struct OtzariaSearchArtifactAvailability: Sendable {
    let artifact: OtzariaResolvedSearchArtifact
    let requiredFreeBytes: Int64
    let availableFreeBytes: Int64
}
actor OtzariaSearchArtifactService {
    static let shared = OtzariaSearchArtifactService()
    func install(databasePath: String, progress: @escaping @Sendable (OtzariaSearchArtifactProgress) -> Void) throws -> UInt64 {
        throw FixtureError.expected
    }
    func checkAvailability(databasePath: String) throws -> OtzariaSearchArtifactAvailability { throw FixtureError.expected }
    func cancel() {}
}
enum FixtureOtzariaError: LocalizedError {
    case page, currentQuery
    var errorDescription: String? {
        switch self { case .page: return "fixture page failed"; case .currentQuery: return "new query failed" }
    }
}
final class OtzariaTantivySearchRepository: @unchecked Sendable {
    enum Reply {
        case page(OtzariaSearchPage)
        case failure(FixtureOtzariaError)
        case held(OtzariaSearchPage, DispatchSemaphore)
    }
    static let shared = OtzariaTantivySearchRepository()
    private let lock = NSLock()
    private var replies: [String: [Int: Reply]] = [:]
    private var started: [(String, Int)] = []
    func set(query: String, offset: Int, reply: Reply) {
        lock.lock(); defer { lock.unlock() }
        replies[query, default: [:]][offset] = reply
    }
    func hasStarted(query: String, offset: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return started.contains { $0.0 == query && $0.1 == offset }
    }
    func search(databasePath: String, request: OtzariaSearchRequest) throws -> OtzariaSearchPage {
        lock.lock()
        let reply = replies[request.query]?[request.offset] ?? .failure(.page)
        started.append((request.query, request.offset))
        lock.unlock()
        switch reply {
        case .page(let page): return page
        case .failure(let error): throw error
        case .held(let page, let gate):
            guard gate.wait(timeout: .now() + 5) == .success else { throw FixtureOtzariaError.page }
            return page
        }
    }
    func navigationItems(from page: OtzariaSearchPage) -> [SearchResultItem] {
        page.results.map { item($0.stableHitID) }
    }
    func invalidate(databasePath: String) {}
    func documentCount(databasePath: String) throws -> UInt64 { 300 }
}

extension SearchFixtureRunner {
    @MainActor static func waitForOtzaria(_ condition: () -> Bool) async {
        for _ in 0..<2000 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Otzaria fixture timed out")
    }

    @MainActor static func otzariaPaginationRetry() async throws {
        let repository = OtzariaTantivySearchRepository.shared
        let index = OtzariaSearchIndexManager.shared.indexURL(for: "fixture-database")
        try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        func response(_ range: ClosedRange<Int>) -> OtzariaSearchPage {
            .init(totalCount: 300, groupCount: nil, truncated: true, results: range.map(engineHit))
        }
        let model = OtzariaTextSearchViewModel()
        repository.set(query: "retry-otzaria", offset: 0, reply: .page(response(1...100)))
        model.query = "retry-otzaria"
        model.search()
        await waitForOtzaria { !model.isSearching }
        check(model.results.count == 100 && model.hasMore && model.errorMessage == nil,
              "actual Otzaria view model first page")

        repository.set(query: "retry-otzaria", offset: 100, reply: .failure(.page))
        model.loadNextPage()
        await waitForOtzaria { !model.isLoadingMore }
        check(model.errorMessage == "fixture page failed" && model.results.count == 100 && model.hasMore,
              "actual Otzaria failed page preserves hits and cursor")

        repository.set(query: "retry-otzaria", offset: 100, reply: .page(response(101...200)))
        model.loadNextPage()
        check(model.errorMessage == nil, "actual Otzaria retry clears stale page error immediately")
        await waitForOtzaria { !model.isLoadingMore }
        check(model.results.count == 200 && model.hasMore && model.errorMessage == nil,
              "actual Otzaria successful retry hides failed-page feedback while more pages remain")

        // Hold an old page's success, then fail a new search. The old completion
        // must not erase the newer generation's real error when it is released.
        let gate = DispatchSemaphore(value: 0)
        defer { gate.signal() }
        repository.set(query: "retry-otzaria", offset: 200, reply: .held(response(201...300), gate))
        model.loadNextPage()
        let oldPageTask = model.fixturePaginationTask
        await waitForOtzaria { repository.hasStarted(query: "retry-otzaria", offset: 200) }
        repository.set(query: "new-otzaria", offset: 0, reply: .failure(.currentQuery))
        model.query = "new-otzaria"
        model.search()
        await waitForOtzaria { !model.isSearching }
        check(model.errorMessage == "new query failed", "new generation publishes its own error")
        gate.signal()
        await oldPageTask?.value
        check(model.errorMessage == "new query failed" && model.results.isEmpty,
              "stale Otzaria page success cannot clear current generation error")
    }
}
