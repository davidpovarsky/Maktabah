import Foundation
import OtzariaActionCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class AvailabilityFixtureState: @unchecked Sendable {
    private let lock = NSLock()
    private var status = 200
    private var payload = "{\"hits\":{\"total\":0,\"hits\":[]}}"
    private var requests = 0
    private var boundedReadOnly = true
    func set(status: Int, payload: String) { lock.lock(); defer { lock.unlock() }; self.status = status; self.payload = payload }
    func response(_ request: URLRequest) -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        requests += 1
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        boundedReadOnly = boundedReadOnly && request.httpMethod == "POST" && request.timeoutInterval <= 2
            && (body?["query"] as? String)?.hasPrefix("maktabah_readiness_") == true
            && (body?["size"] as? Int) == 1
        return (status, Data(payload.utf8))
    }
    func observed() -> (Int, Bool) { lock.lock(); defer { lock.unlock() }; return (requests, boundedReadOnly) }
}
private final class AvailabilityFixtureProtocol: URLProtocol, @unchecked Sendable {
    static let state = AvailabilityFixtureState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.state.response(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension IntegrationAcceptance {
    @MainActor static func legacySourceChecks() async throws {
        let cache = SefariaDiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let source = SefariaRemoteStore(cache: cache)
        func response(_ total: String, rows: String = "[]") throws -> SefariaSearchResponseDTO {
            try JSONDecoder().decode(SefariaSearchResponseDTO.self,
                from: Data(("{\"hits\":{\"total\":" + total + ",\"hits\":" + rows + "}}").utf8))
        }
        let request = LibrarySearchRequest(query: "משה", offset: 0, limit: 50)
        let query = ActionSearchQuery(backend: .sefaria, text: "משה", limit: 50)
        let zero = try await source.projectSearchResponse(response("{\"value\":0,\"relation\":\"eq\"}"), request: request)
        check(zero.sourceEvidence?.totalRelation == "eq" && zero.sourceEvidence?.rawHitCount == 0,
            "real source provider preserves actual DTO exact relation and raw empty count")
        let accepted = try ActionLibraryProjection.searchPage(zero, query: query, works: [])
        check(accepted.hits.isEmpty && accepted.precision == .unknown, "proven genuine zero accepted without promoting aggregate precision")
        for total in ["0", "{\"value\":0,\"relation\":\"gte\"}", "{\"value\":0,\"relation\":\"unknown-source-relation\"}"] {
            let page = try await source.projectSearchResponse(response(total), request: request)
            do { _ = try ActionLibraryProjection.searchPage(page, query: query, works: []); fatalError("unknown/lower-bound zero accepted") }
            catch { check(true, "unknown/lower-bound source evidence cannot establish genuine zero") }
        }
        let row = "[{\"_source\":{\"ref\":\"Genesis 1:1\",\"index_title\":\"Genesis\",\"exact\":\"fixture\"}}]"
        let work = LibraryWork(locator: .init(backend: .sefaria, workKey: "Genesis", position: .canonicalRef("Genesis")),
            title: "Genesis", heTitle: nil, categories: [], description: nil)
        let nonempty = try await source.projectSearchResponse(response("{\"value\":1,\"relation\":\"gte\"}", rows: row), request: request)
        check(nonempty.sourceEvidence?.allRowsMapped == true && nonempty.nextOffset == 1,
            "actual provider retains mapping proof and raw consumed cursor for a lower-bound total")
        check(try ActionLibraryProjection.searchPage(nonempty, query: query, works: [work]).precision == .unknown,
            "lower-bound total never becomes an exact action count")
        do {
            _ = try await source.projectSearchResponse(response("{\"value\":1,\"relation\":\"eq\"}", rows: "[{\"_source\":{\"ref\":\"\"}}]"), request: request)
            fatalError("dropped source row became an empty result")
        } catch { check(true, "actual provider refuses source rows dropped by native identity mapping") }
        var forged = zero
        forged.sourceEvidence = .init(backend: .sefaria, rawHitCount: 1, allRowsMapped: false, totalRelation: "eq")
        do { _ = try ActionLibraryProjection.searchPage(forged, query: query, works: []); fatalError("dropped row proof accepted") }
        catch { check(true, "projection verifies raw/mapped row agreement") }
        forged.sourceEvidence = .init(backend: .otzaria, rawHitCount: 0, allRowsMapped: true, totalRelation: "eq")
        do { _ = try ActionLibraryProjection.searchPage(forged, query: query, works: []); fatalError("foreign source proof accepted") }
        catch { check(true, "foreign source evidence cannot certify Legacy zero") }
        let old = try JSONDecoder().decode(LibrarySearchPage.self, from: Data("{\"hits\":[],\"total\":0,\"nextOffset\":null}".utf8))
        check(old.sourceEvidence == nil, "existing encoded search pages remain source compatible with nil evidence")
        // Actual URLSession/HTTP client/provider, explicit in-memory protocol
        // transport. No live endpoint, user query, session or disk cache touched.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AvailabilityFixtureProtocol.self]
        let client = SefariaHTTPClient(session: URLSession(configuration: configuration))
        let service = SefariaRemoteStore(client: client, cache: cache)
        check(try await service.observeSearchService(), "production provider establishes readiness from an actual decoded search-endpoint response")
        check(try await service.observeSearchService(), "short-lived source observation can be reused without UI session reset")
        check(AvailabilityFixtureProtocol.state.observed().0 == 1, "bounded readiness observation does not repeatedly probe the endpoint")
        await service.clearTransientState()
        AvailabilityFixtureProtocol.state.set(status: 200, payload: "{\"hits\":{\"total\":{},\"hits\":[]}}")
        do { _ = try await service.observeSearchService(); fatalError("malformed service response advertised readiness") }
        catch { check(true, "missing source total evidence cannot make the service ready") }
        AvailabilityFixtureProtocol.state.set(status: 503, payload: "{}")
        do { _ = try await service.observeSearchService(); fatalError("failed service advertised readiness") }
        catch { check(true, "actual HTTP failure remains unavailable instead of ready/empty") }
        let observed = AvailabilityFixtureProtocol.state.observed()
        check(observed.0 == 3 && observed.1, "availability uses one 2s request with synthetic probe text and size1, no hidden retries")
    }
}
