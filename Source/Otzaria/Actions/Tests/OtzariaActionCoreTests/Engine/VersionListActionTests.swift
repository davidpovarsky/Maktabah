import XCTest
@testable import OtzariaActionCore

private actor VersionProvider: ActionBackendStatePort, ActionVersionListPort {
    enum Response { case versions, empty, failed, stale }
    let response: Response
    private var generation: UInt64 = 1
    private(set) var requests: [ActionWorkRef] = []

    init(_ response: Response) { self.response = response }
    func snapshot() -> ActionBackendSnapshot { .init(backend: .sefaria, generation: generation) }

    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: ["reader.listVersions": .init(registered: true, supported: true, availableNow: true)])
    }

    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: true)
    }

    func versions(for work: ActionWorkRef, invocation: ActionPortInvocation) throws -> [ActionTextVersion] {
        requests.append(work)
        switch response {
        case .empty: return []
        case .failed: throw ActionPortError.invalidResponse
        case .stale: generation += 1
        case .versions: break
        }
        return [.init(title: "מהדורה", language: "he", isPrimary: true),
                .init(title: "Translation", language: "en", license: "CC-BY")]
    }
}

final class VersionListActionTests: XCTestCase, @unchecked Sendable {
    private let work = ActionWorkRef(backend: .sefaria, workKey: "Genesis")
    private func run(_ provider: VersionProvider, allowed: Set<String> = ["Genesis"]) async throws -> ActionResult {
        let other = MockPorts()
        let engine = try ActionExecutor(state: provider, resolver: other, search: other)
        let request = ActionRequest(action: "reader.listVersions", arguments: ["workRef": try .encoded(work)])
        return await engine.execute(request, context: .init(subjectID: "versions", origin: .internalAI,
            allowedBackends: [.sefaria], contentRights: [.sefaria], scopes: [.discovery, .contentRead],
            allowedWorkKeys: [.sefaria: allowed]))
    }

    func testPreservesOriginalVersionsInSourceOrder() async throws {
        let provider = VersionProvider(.versions)
        let result = try await run(provider)
        XCTAssertEqual(result.status, .completed)
        let body = try XCTUnwrap(result.data)
        XCTAssertEqual(try body["workRef"]?.decoded(as: ActionWorkRef.self), work)
        XCTAssertEqual(try body["versions"]?.decoded(as: [ActionTextVersion].self), [
            .init(title: "מהדורה", language: "he", isPrimary: true),
            .init(title: "Translation", language: "en", license: "CC-BY")
        ])
        let reads = await provider.requests
        XCTAssertEqual(reads, [work])
    }

    func testDistinguishesVerifiedEmptyListFromFailedOrStaleResponse() async throws {
        let empty = try await run(VersionProvider(.empty))
        XCTAssertEqual(empty.status, .completed)
        XCTAssertEqual(empty.data?["versions"], .array([]))
        let failed = try await run(VersionProvider(.failed))
        XCTAssertEqual(failed.error?.code, "invalid_backend_response")
        XCTAssertNil(failed.data)
        let stale = try await run(VersionProvider(.stale))
        XCTAssertEqual(stale.status, .staleState)
        XCTAssertNil(stale.data)
    }

    func testEnforcesWorkScopeAndRealProviderReadiness() async throws {
        let provider = VersionProvider(.versions)
        let denied = try await run(provider, allowed: ["Exodus"])
        XCTAssertEqual(denied.error?.code, "permission_denied")
        let reads = await provider.requests
        XCTAssertTrue(reads.isEmpty)

        let action = "reader.listVersions"
        let legacy = ActionBackendSemanticProfile(backend: .sefaria)
        var evidence = ActionBackendRuntimeEvidence(snapshot: .init(backend: .sefaria, generation: 1))
        evidence.catalog = .ready
        evidence.registeredCapabilities = ["versions"]
        XCTAssertFalse(try legacy.assess(action: action, evidence: evidence).availableNow)
        evidence.network = .ready
        XCTAssertTrue(try legacy.assess(action: action, evidence: evidence).availableNow)
        let embedded = ActionBackendSemanticProfile(backend: .sefariaEmbedded)
        var embeddedEvidence = ActionBackendRuntimeEvidence(snapshot: .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 2))
        embeddedEvidence.registeredCapabilities = ["versions"]
        XCTAssertFalse(try embedded.assess(action: action, evidence: embeddedEvidence).supported)
    }
}
