import Foundation
import XCTest
@testable import OtzariaActionCore

/// Explicit trusted-port doubles. These validate Core authorization/proof
/// handling; no fixture here is represented as an actual engine/index count.
private actor OccurrencePorts: ActionBackendStatePort, ActionResolverPort, ActionSearchPort, ActionOccurrenceCountPort {
    enum Mutation: Sendable, CaseIterable {
        case none, zero, wrongRequest, wrongGeneration, wrongQuery, wrongScope, wrongContract, wrongEngine
        case badSnapshotDigest, badArtifactDigest, badDatabaseDigest, incomplete, coverageMismatch, emptyCoverage
        case overDocumentBudget, overPositionBudget, impossibleCounts, falseZero, emptyToken, compoundToken
        case staleAfterCount, missingScope, changedScopeRevision, stall
    }
    var mutation: Mutation = .none
    var failure: ActionOccurrenceFailure?
    var available = true
    var generation: UInt64 = 1
    let backend: ActionBackendID
    private var countCalls = 0
    private var searchCalls = 0
    private var resolutionCalls = 0
    init(backend: ActionBackendID = .otzaria) { self.backend = backend }
    func configure(_ mutation: Mutation = .none, failure: ActionOccurrenceFailure? = nil, available: Bool = true) {
        self.mutation = mutation; self.failure = failure; self.available = available
    }
    func bump() { generation += 1 }
    func counts() -> (count: Int, search: Int, resolutions: Int) { (countCalls, searchCalls, resolutionCalls) }
    func snapshot() -> ActionBackendSnapshot { .init(backend: backend, generation: generation) }
    func report(for backend: ActionBackendID) -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues:
            ["system.listBackends", "catalog.resolveWork", "catalog.resolveReference", "search.query", "search.countOccurrences"].map {
                ($0, .init(registered: true, supported: true, availableNow: available))
            }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) -> ActionCapabilityAssessment {
        .init(registered: true, supported: true, availableNow: available, reasonCode: available ? nil : "index_missing")
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) -> ActionResolution<ActionWorkRef> {
        resolutionCalls += 1
        guard mutation != .missingScope, let ref = query.workRef else { return .notFound }
        return .unique(mutation == .changedScopeRevision
            ? .init(backend: ref.backend, workKey: ref.workKey, catalogRevision: "different-source") : ref)
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) throws -> ActionReaderDestination { throw ActionPortError.notSupported }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) -> ActionSearchPage {
        searchCalls += 1
        return .init(hits: [], total: 0, precision: .exact)
    }
    func countOccurrences(_ query: ActionOccurrenceQuery, invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        countCalls += 1
        if mutation == .stall { try await Task.sleep(nanoseconds: 5_000_000_000) }
        if let failure { throw failure }
        if mutation == .staleAfterCount { bump() }
        let digest = String(repeating: "a", count: 64)
        let proof = ActionOccurrenceEvidence(
            contract: mutation == .wrongContract ? "document-total" : ActionOccurrenceEvidence.requiredContract,
            engineRevision: mutation == .wrongEngine ? String(repeating: "b", count: 40) : ActionOccurrenceEvidence.requiredEngineRevision,
            engineSnapshotSHA256: mutation == .badSnapshotDigest ? "not-a-digest" : digest,
            artifactIdentity: mutation == .badArtifactDigest ? String(repeating: "z", count: 64) : digest,
            databaseSHA256: mutation == .badDatabaseDigest ? String(repeating: "A", count: 64) : digest,
            expectedIndexedDocuments: mutation == .emptyCoverage ? 0 : 100,
            observedIndexedDocuments: mutation == .coverageMismatch ? 99 : mutation == .emptyCoverage ? 0 : 100,
            visitedDocuments: mutation == .overDocumentBudget ? 1_000_001 : 1,
            visitedPositions: mutation == .overPositionBudget ? 10_000_001 : 2,
            completeManagedArtifact: mutation != .incomplete)
        let actualQuery = mutation == .wrongQuery
            ? ActionOccurrenceQuery(backend: query.backend, text: "a different input", scopeWorkRefs: query.scopeWorkRefs)
            : mutation == .wrongScope
            ? ActionOccurrenceQuery(backend: query.backend, text: query.text, scopeWorkRefs: [])
            : query
        return .init(requestId: mutation == .wrongRequest ? UUID() : invocation.requestId,
            snapshot: mutation == .wrongGeneration ? .init(backend: backend, generation: generation + 1) : invocation.snapshot,
            query: actualQuery, count: mutation == .zero || mutation == .falseZero ? 0 : mutation == .impossibleCounts ? 3 : 2,
            matchingDocuments: mutation == .zero ? 0 : 1,
            normalizedToken: mutation == .emptyToken ? "" : mutation == .compoundToken ? "two tokens" : "משה", evidence: proof)
    }
}

final class OccurrenceActionTests: XCTestCase, @unchecked Sendable {
    private func context(rights: Bool = true, scopes: Set<ActionScope> = [.discovery, .contentRead],
                         works: [ActionBackendID: Set<String>]? = nil, origin: ActionOrigin = .inApp) -> ActionExecutionContext {
        .init(subjectID: "occurrence-fixture", origin: origin, allowedBackends: Set(ActionBackendID.allCases),
              contentRights: rights ? Set(ActionBackendID.allCases) : [], scopes: scopes, allowedWorkKeys: works)
    }
    private func request(backend: ActionBackendID = .otzaria, scopes: Bool = true,
                         extra: ActionObject = [:], deadline: Int? = nil) throws -> ActionRequest {
        var args: ActionObject = ["text": .string("משה"), "countUnit": .string("matching_occurrences")]
        if scopes { args["scopeWorkRefs"] = try .encoded([ActionWorkRef(backend: backend, workKey: "book:1", catalogRevision: "catalog-fixture")]) }
        args.merge(extra) { _, new in new }
        return .init(action: "search.countOccurrences", arguments: args, expectedBackend: backend, deadlineMs: deadline)
    }
    private func core(_ ports: OccurrencePorts) throws -> ActionExecutor { try .init(state: ports, resolver: ports, search: ports) }

    func testExactOccurrencesStayDistinctFromMatchingDocumentTotal() async throws {
        let p = OccurrencePorts(), c = try core(p)
        let result = await c.execute(try request(), context: context())
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["count"]?.decoded(as: UInt64.self), 2)
        XCTAssertEqual(try result.data?["matchingDocuments"]?.decoded(as: UInt64.self), 1)
        XCTAssertEqual(result.data?["countUnit"], .string("matching_occurrences"))
        XCTAssertEqual(result.data?["precision"], .string("exact"))
        let calls = await p.counts(); XCTAssertEqual(calls.count, 1); XCTAssertEqual(calls.search, 0); XCTAssertEqual(calls.resolutions, 1)
    }
    func testProvenZeroHasExactZeroAndCoverageEvidence() async throws {
        let p = OccurrencePorts(); await p.configure(.zero)
        let result = await (try core(p)).execute(try request(), context: context())
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(try result.data?["count"]?.decoded(as: UInt64.self), 0)
        XCTAssertNotNil(result.data?["evidence"])
    }
    func testOriginalSearchPortAndPageTotalRemainUnchanged() async throws {
        let p = OccurrencePorts(), c = try core(p)
        let result = await c.execute(.init(action: "search.query", arguments: ["text": .string("word")], expectedBackend: .otzaria), context: context())
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(result.data?["total"], .integer(0))
        let calls = await p.counts(); XCTAssertEqual(calls.search, 1); XCTAssertEqual(calls.count, 0)
    }
    func testMissingOptionalCountPortCannotExecuteOrAdvertise() async throws {
        let p = MockPorts(), c = try ActionExecutor(state: p, resolver: p, search: p)
        let result = await c.execute(try request(), context: context())
        XCTAssertEqual(result.error?.code, "exact_count_unavailable")
        let actions = await c.advertisedActions(for: .otzaria, context: context())
        XCTAssertFalse(actions.contains { $0.id == "search.countOccurrences" })
        let calls = await p.counts(); XCTAssertEqual(calls.search, 0)
    }
    func testQualifiedPortCanAdvertiseOnlyWithCurrentRightsAndReadiness() async throws {
        let p = OccurrencePorts(), c = try core(p)
        let eligible = await c.advertisedActions(for: .otzaria, context: context())
        XCTAssertTrue(eligible.contains { $0.id == "search.countOccurrences" })
        let denied = await c.advertisedActions(for: .otzaria, context: context(rights: false))
        XCTAssertFalse(denied.contains { $0.id == "search.countOccurrences" })
        await p.configure(available: false)
        let unavailable = await c.advertisedActions(for: .otzaria, context: context())
        XCTAssertFalse(unavailable.contains { $0.id == "search.countOccurrences" })
    }
    func testDocumentAndSegmentUnitsAreNotSilentlyReinterpreted() async throws {
        let p = OccurrencePorts(), c = try core(p)
        for unit in ["matching_documents", "matching_segments"] {
            let result = await c.execute(try request(extra: ["countUnit": .string(unit)]), context: context())
            XCTAssertEqual(result.status, .notSupported); XCTAssertNil(result.data)
        }
        let calls = await p.counts(); XCTAssertEqual(calls.count, 0); XCTAssertEqual(calls.search, 0)
    }
    func testLemmatizedModeCannotProduceAnExactCount() async throws {
        let p = OccurrencePorts()
        let result = await (try core(p)).execute(try request(extra: ["matchMode": .string("hebrewLemmatized")]), context: context())
        XCTAssertEqual(result.status, .notSupported); XCTAssertNil(result.data)
        let calls = await p.counts(); XCTAssertEqual(calls.count, 0)
    }
    func testOtherBackendsRemainUnsupportedWithoutFallback() async throws {
        for backend in [ActionBackendID.sefaria, .sefariaEmbedded] {
            let p = OccurrencePorts(backend: backend)
            let result = await (try core(p)).execute(try request(backend: backend), context: context())
            XCTAssertNotEqual(result.status, .completed); XCTAssertNil(result.data)
            let calls = await p.counts(); XCTAssertEqual(calls.count, 0)
        }
    }
    func testRightsAndDeepLinksCannotReachCountProvider() async throws {
        let p = OccurrencePorts(), c = try core(p)
        for ctx in [context(rights: false), context(scopes: [.discovery]), context(origin: .deepLink)] {
            let result = await c.execute(try request(), context: ctx)
            XCTAssertNotEqual(result.status, .completed); XCTAssertNil(result.data)
        }
        let calls = await p.counts(); XCTAssertEqual(calls.count, 0)
    }
    func testRestrictedWorkAuthorityRequiresExactExplicitScope() async throws {
        let p = OccurrencePorts(), c = try core(p)
        let restricted = context(works: [.otzaria: ["book:1"]])
        let broad = await c.execute(try request(scopes: false), context: restricted)
        XCTAssertEqual(broad.error?.code, "scope_required")
        let other = await c.execute(try request(extra: ["scopeWorkRefs": try .encoded([ActionWorkRef(backend: .otzaria, workKey: "book:2")])]), context: restricted)
        XCTAssertEqual(other.error?.code, "permission_denied")
        let allowed = await c.execute(try request(), context: restricted)
        XCTAssertEqual(allowed.status, .completed)
        let calls = await p.counts(); XCTAssertEqual(calls.count, 1)
    }
    func testDuplicatedScopesFailBeforeCounting() async throws {
        let p = OccurrencePorts()
        let ref = ActionWorkRef(backend: .otzaria, workKey: "book:1")
        let result = await (try core(p)).execute(try request(extra: ["scopeWorkRefs": try .encoded([ref, ref])]), context: context())
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(result.error?.code, "invalid_arguments")
        let calls = await p.counts(); XCTAssertEqual(calls.count, 0)
    }
    func testMissingOrDifferentCatalogRevisionDoesNotCount() async throws {
        for mutation in [OccurrencePorts.Mutation.missingScope, .changedScopeRevision] {
            let p = OccurrencePorts(); await p.configure(mutation)
            let result = await (try core(p)).execute(try request(), context: context())
            XCTAssertNotEqual(result.status, .completed); XCTAssertNil(result.data)
            let calls = await p.counts(); XCTAssertEqual(calls.count, 0); XCTAssertEqual(calls.resolutions, 1)
        }
    }
    func testForgedOrPartialEvidenceNeverPublishesAnyCount() async throws {
        let invalid: [OccurrencePorts.Mutation] = [.wrongRequest, .wrongGeneration, .wrongQuery, .wrongScope,
            .wrongContract, .wrongEngine, .badSnapshotDigest, .badArtifactDigest, .badDatabaseDigest,
            .incomplete, .coverageMismatch, .emptyCoverage, .overDocumentBudget, .overPositionBudget,
            .impossibleCounts, .falseZero, .emptyToken, .compoundToken]
        for mutation in invalid {
            let p = OccurrencePorts(); await p.configure(mutation)
            let result = await (try core(p)).execute(try request(), context: context())
            XCTAssertEqual(result.error?.code, "invalid_backend_response", "\(mutation)")
            XCTAssertNil(result.data, "\(mutation)")
            let calls = await p.counts(); XCTAssertEqual(calls.count, 1, "\(mutation)")
        }
    }
    func testSourceChangeAfterCountingDiscardsAValidNumericResult() async throws {
        let p = OccurrencePorts(); await p.configure(.staleAfterCount)
        let result = await (try core(p)).execute(try request(), context: context())
        XCTAssertEqual(result.status, .staleState); XCTAssertNil(result.data)
    }
    func testTypedFailuresContainNoPartialNumber() async throws {
        let failures: [(ActionOccurrenceFailure, ActionStatus, String)] = [
            (.unsupportedQuery, .notSupported, "occurrence_query_unavailable"),
            (.incompleteCoverage, .unavailable, "occurrence_coverage_unavailable"),
            (.budgetExceeded, .unavailable, "occurrence_budget_exceeded"),
            (.cancelled, .cancelled, "cancelled"),
            (.deadlineExceeded, .cancelled, "deadline_exceeded"),
            (.staleIndex, .staleState, "backend_generation_changed")]
        for (error, status, code) in failures {
            let p = OccurrencePorts(); await p.configure(failure: error)
            let result = await (try core(p)).execute(try request(), context: context())
            XCTAssertEqual(result.status, status); XCTAssertEqual(result.error?.code, code); XCTAssertNil(result.data)
            let wire = String(decoding: try ActionWireCodec.encodeResult(result), as: UTF8.self)
            XCTAssertFalse(wire.contains("\"count\":")); XCTAssertFalse(wire.contains("\"precision\":\"exact\""))
        }
    }
    func testUnavailableIndexCannotBecomeZeroOrReachProvider() async throws {
        let p = OccurrencePorts(); await p.configure(available: false)
        let result = await (try core(p)).execute(try request(), context: context())
        XCTAssertEqual(result.status, .unavailable); XCTAssertNil(result.data)
        let calls = await p.counts(); XCTAssertEqual(calls.count, 0)
    }
    func testDeadlineStopsPendingCountWithoutPublishingPartialData() async throws {
        let p = OccurrencePorts(); await p.configure(.stall)
        let result = await (try core(p)).execute(try request(deadline: 100), context: context())
        XCTAssertEqual(result.status, .cancelled); XCTAssertEqual(result.error?.code, "deadline_exceeded"); XCTAssertNil(result.data)
        let calls = await p.counts(); XCTAssertEqual(calls.count, 1)
    }
    func testCancellationAfterProviderEntryCannotPublish() async throws {
        let p = OccurrencePorts(); await p.configure(.stall)
        let c = try core(p), req = try request(deadline: 2_000), ctx = context()
        let task = Task { await c.execute(req, context: ctx) }
        let end = Date().addingTimeInterval(1)
        while await p.counts().count == 0, Date() < end { try await Task.sleep(nanoseconds: 1_000_000) }
        let entered = await p.counts().count
        task.cancel()
        let result = await task.value
        XCTAssertEqual(entered, 1); XCTAssertEqual(result.status, .cancelled); XCTAssertNil(result.data)
    }
    func testReplayReusesSameProofButNewGenerationInvalidatesIt() async throws {
        let p = OccurrencePorts(), c = try core(p), req = try request(), ctx = context()
        let first = await c.execute(req, context: ctx)
        let second = await c.execute(req, context: ctx)
        XCTAssertEqual(first.status, .completed); XCTAssertEqual(first, second)
        let before = await p.counts(); XCTAssertEqual(before.count, 1)
        await p.bump()
        let changed = await c.execute(req, context: ctx)
        XCTAssertEqual(changed.status, .staleState); XCTAssertNil(changed.data)
        let after = await p.counts(); XCTAssertEqual(after.count, 1)
    }
    func testAuthorityChangeCannotReplayPreviousCount() async throws {
        let p = OccurrencePorts(), c = try core(p), req = try request(), ctx = context()
        let first = await c.execute(req, context: ctx); XCTAssertEqual(first.status, .completed)
        let denied = await c.execute(req, context: context(rights: false))
        XCTAssertEqual(denied.error?.code, "content_rights_required"); XCTAssertNil(denied.data)
        let calls = await p.counts(); XCTAssertEqual(calls.count, 1)
    }
}
