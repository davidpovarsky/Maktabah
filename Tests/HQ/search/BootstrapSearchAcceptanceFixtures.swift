import Foundation

// The leased production method is compiled unchanged with the real Swift
// request/hit/page models. Engine/install/DB boundaries are explicit doubles.
// No actual native bridge, installed data or Apple SDK acceptance is implied.
struct Report {
    var otzariaIndexDocuments: UInt64 = 0
    var otzariaSearchResults: UInt64 = 0
    var zayitArtifactIdentity: String?
    var zayitSearchResults: UInt64 = 0
}
enum FixtureFailure: Error { case expected }
enum ZayitSearchDistributionError: Error { case validationFailed(String) }
struct OtzariaSearchRequest {
    enum Mode { case advanced }; enum Order { case relevance }; enum Match { case all }
    let query: String, mode: Mode, facets: [String], limit: Int, order: Order, wordMatchMode: Match
}
struct FixtureOtzariaPage { let totalCount: UInt64 }
@MainActor final class OtzariaSearchEngineBridge {
    init(indexURL: URL) throws {}
    func documentCount() throws -> UInt64 { FixtureState.otzariaCountCalls += 1; return 18_879 }
    func search(_ request: OtzariaSearchRequest) throws -> FixtureOtzariaPage {
        FixtureState.otzariaSearchCalls += 1
        return .init(totalCount: 88)
    }
    func close() { FixtureState.otzariaCloses += 1 }
}
@MainActor final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()
    func indexURL(for path: String) -> URL { URL(fileURLWithPath: "/explicit-fixture-otzaria-index") }
}
struct ZayitSearchArtifactStorage {
    let finalIndex = URL(fileURLWithPath: "/explicit-fixture-zayit-index")
    init() throws {}
}
enum FixtureArtifactStatus { case ready(FixtureManifest), unavailable }
struct FixtureManifest { let artifactIdentity = "explicit-fixture-manifest" }
@MainActor final class ZayitSearchArtifactService {
    static let shared = ZayitSearchArtifactService()
    func status(databaseURL: URL) async -> FixtureArtifactStatus {
        FixtureState.scenario == .unavailableArtifact ? .unavailable : .ready(.init())
    }
}
enum ZayitSearchDataValidator {
    static func managedPaths(seforimDB: URL, lexicalDB: URL, indexDirectory: URL) throws -> ZayitSearchDataPaths {
        .init(seforimDb: seforimDB.path, lexicalDb: lexicalDB.path, indexDir: indexDirectory.path)
    }
}
enum Scenario: CaseIterable {
    case healthy, emptyInitial, warmTotalDrift, warmIDDrift, warmLocationDrift,
         filteredEmpty, filteredForeignBook, afterFilterDrift,
         reopenedTotalDrift, reopenedIDDrift, reopenedLastPageDrift, unavailableArtifact
}
@MainActor enum FixtureState {
    static var scenario = Scenario.healthy
    static var requests: [ZayitSearchRequest] = []
    static var opens = 0, closes = 0
    static var otzariaCountCalls = 0, otzariaSearchCalls = 0, otzariaCloses = 0
    static func reset(_ value: Scenario) {
        scenario = value; requests = []; opens = 0; closes = 0
        otzariaCountCalls = 0; otzariaSearchCalls = 0; otzariaCloses = 0
    }
    static func hit(_ id: Int64, book: Int64 = 7, line: Int = 1) -> ZayitSearchHit {
        .init(bookId: book, stableBookKey: "book:\(book)", bookTitle: "explicit fixture",
            lineId: id, lineIndex: line, reference: "explicit fixture \(line)",
            snippetHtml: "fixture", matchedTerms: ["fixture"], score: 1, isBaseBook: true)
    }
}
@MainActor final class ZayitSearchEngineBridge {
    func open(paths: ZayitSearchDataPaths) throws { FixtureState.opens += 1 }
    func close() { FixtureState.closes += 1 }
    func search(_ request: ZayitSearchRequest) throws -> ZayitSearchPage {
        FixtureState.requests.append(request)
        let call = FixtureState.requests.count, scenario = FixtureState.scenario
        var hits = [FixtureState.hit(11), FixtureState.hit(12, book: 8)]
        var total: UInt64 = 100
        var last = false
        if call == 1 && scenario == .emptyInitial { hits = []; total = 0 }
        if call == 2 {
            if scenario == .warmTotalDrift { total = 101 }
            if scenario == .warmIDDrift { hits[0] = FixtureState.hit(99) }
            if scenario == .warmLocationDrift { hits[0] = FixtureState.hit(11, line: 9) }
        }
        if !request.filters.bookIds.isEmpty {
            hits = scenario == .filteredForeignBook ? [FixtureState.hit(12, book: 8)] : [FixtureState.hit(11)]
            total = 20
            if scenario == .filteredEmpty { hits = []; total = 0 }
        }
        if call == 5 && scenario == .afterFilterDrift { hits[0] = FixtureState.hit(99) }
        if FixtureState.opens == 2 {
            if scenario == .reopenedTotalDrift { total = 101 }
            if scenario == .reopenedIDDrift { hits[0] = FixtureState.hit(99) }
            if scenario == .reopenedLastPageDrift { last = true }
        }
        return .init(hits: hits, totalHits: total, isLastPage: last)
    }
}

@main struct BootstrapSearchAcceptanceFixtures {
    @MainActor static func main() async throws {
        var assertions = 0
        func check(_ value: Bool, _ message: String) {
            assertions += 1
            if !value { fatalError("FAIL: " + message) }
        }
        for scenario in Scenario.allCases {
            FixtureState.reset(scenario)
            var report = Report()
            var failed = false
            do { try await BootstrapSearchFixtureRunner.run(&report) } catch { failed = true }
            check(failed == (scenario != .healthy), "unexpected acceptance for \(scenario)")
            check(FixtureState.otzariaCountCalls == 1 && FixtureState.otzariaSearchCalls == 1 && FixtureState.otzariaCloses == 1,
                  "existing Otzaria checks/defer must run unchanged")
            if scenario == .healthy {
                check(report.otzariaIndexDocuments == 18_879 && report.otzariaSearchResults == 88 && report.zayitSearchResults == 100,
                      "root report retains existing interface and values")
                check(FixtureState.opens == 2 && FixtureState.closes == 2 && FixtureState.requests.count == 6,
                      "actual method must repeat, filter, restore and reopen")
                for (index, request) in FixtureState.requests.enumerated() {
                    check(request.query == "בראשית" && request.near == 5 && request.limit == 25 && request.offset == 0,
                          "query/near/limit/offset remain exactly frozen")
                    check(request.filters.bookIds == (index == 3 ? [7] : []),
                          "only the scoped proof adds the real first-hit book filter")
                }
            } else {
                check(report.zayitSearchResults == 0, "failure cannot publish a successful search receipt")
            }
        }
        print("PASS: \(assertions) assertions across \(Scenario.allCases.count) exact-method scenarios; bridge/install/DB doubles, no native or FFI acceptance")
    }
}
