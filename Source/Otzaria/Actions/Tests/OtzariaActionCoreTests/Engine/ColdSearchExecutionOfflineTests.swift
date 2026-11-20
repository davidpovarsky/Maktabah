import Foundation
import XCTest
@testable import OtzariaActionCore

// Independently materialized after the Windows host disconnected. The earlier
// uncommitted ColdSearchExecutionTests.swift / orphaned job has UNKNOWN outcome;
// byte equivalence to it is NOT_VERIFIED. These are original-Core controls with
// explicit provider/UI doubles, not an app engine, filesystem or Native proof.
private func coldContext(rights: Bool = true, scopes: Set<ActionScope> = [.discovery, .contentRead, .navigation],
                         works: Set<String>? = ["book:1"]) -> ActionExecutionContext {
    .init(subjectID: "cold-execution-fixture", origin: .inApp, allowedBackends: [.otzaria],
          contentRights: rights ? [.otzaria] : [], scopes: scopes,
          allowedWorkKeys: works.map { [.otzaria: $0] }, foregroundSceneID: "cold-scene")
}

@MainActor private final class ColdExecutionSource: ActionSynchronousBackendStatePort, ActionResolverPort,
    ActionSearchPort, ActionSearchExecutionPreparationPort, ActionOccurrenceCountPort, ActionNavigationAuthority {
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 7)
    var context = coldContext()
    var registered = true
    var supported = true
    var ready = false
    nonisolated let hasSearchExecutionPreparation: Bool
    var makesReady = true
    var delay: UInt64 = 0
    var throwsUnavailable = false
    var afterPreparation: (@MainActor () -> Void)?
    var preparations = 0
    var searches = 0
    var assessments = 0
    var resolutions = 0
    var counts = 0
    var preparedQuery: ActionSearchQuery?
    var searchedQuery: ActionSearchQuery?
    var preparedInvocation: ActionPortInvocation?
    var assessedArguments: [ActionObject] = []
    var events: [String] = []
    let lifetime = UUID()
    var authorityRevision: UInt64 = 1
    init(hasPreparation: Bool = true) { hasSearchExecutionPreparation = hasPreparation }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { current }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        .init(context: context, sceneID: "cold-scene", lifetimeID: lifetime,
              authorityRevision: authorityRevision, active: true)
    }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues:
            ["search.query", "search.openResults", "search.countOccurrences"].map {
                ($0, ActionCapabilityAssessment(registered: registered, supported: supported,
                                               availableNow: ready, reasonCode: "index_missing"))
            }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        assessments += 1; assessedArguments.append(arguments); events.append("assess")
        return .init(registered: registered, supported: supported, availableNow: ready, reasonCode: "index_missing")
    }
    func prepareSearchExecution(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws {
        preparations += 1; preparedQuery = query; preparedInvocation = invocation; events.append("prepare")
        if delay > 0 { try await Task<Never, Never>.sleep(nanoseconds: delay) }
        try Task.checkCancellation()
        if throwsUnavailable { throw ActionPortError.unavailable }
        afterPreparation?()
        if makesReady { ready = true }
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        searches += 1; searchedQuery = query; events.append("search")
        guard ready else { throw ActionPortError.unavailable }
        return .init(hits: [], total: 0, precision: .exact, totalSemantics: .matchingDocuments)
    }
    func countOccurrences(_ query: ActionOccurrenceQuery, invocation: ActionPortInvocation) async throws -> ActionExactOccurrenceCount {
        counts += 1; throw ActionOccurrenceFailure.incompleteCoverage
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> {
        resolutions += 1
        return .unique(query.workRef ?? .init(backend: query.backend, workKey: "book:1"))
    }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { destination }
}

@MainActor private final class ColdExecutionUI: ActionSearchResultsUICommandSink {
    let source: ColdExecutionSource
    var prepared: ActionSearchResultsQuery?
    var displayed: ActionSearchResultsQuery?
    var commands = 0
    var receipt: ActionSearchResultsReceipt?
    init(_ source: ColdExecutionSource) { self.source = source }
    func canOpenSearchResults(in sceneID: String) -> Bool { sceneID == "cold-scene" }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.notSupported }
    func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws {
        prepared = query
    }
    func openSearchResults(_ command: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement {
        guard prepared == command.query, let authority = command.navigationAuthorization else { throw ActionPortError.invalidResponse }
        try authority.authorizeCommit(invocation: command.invocation, sceneID: command.sceneID, searchQuery: command.query)
        commands += 1; displayed = command.query
        let observed = ActionSearchResultsReceipt(requestId: command.invocation.requestId,
            snapshot: command.invocation.snapshot, sceneID: command.sceneID, query: command.query, submissionRevision: commands)
        receipt = observed
        return .acknowledged(observed)
    }
    func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand, receipt: ActionSearchResultsReceipt) throws {
        guard displayed == command.query, receipt == self.receipt else { throw ActionPortError.staleState }
    }
}

final class ColdSearchExecutionOfflineTests: XCTestCase, @unchecked Sendable {
    private func query(work: String? = "book:1") -> ActionSearchQuery {
        .init(backend: .otzaria, text: "בְּרֵאשִׁית", scopeWorkRefs: work.map { [.init(backend: .otzaria, workKey: $0)] } ?? [],
              searchMode: .near, matchMode: .exact, wordDistance: 3, sortOrder: .canonical, offset: 4, limit: 7)
    }
    private func request(_ query: ActionSearchQuery? = nil, deadline: Int? = nil, id: UUID = UUID()) throws -> ActionRequest {
        .init(requestId: id, action: "search.query", arguments: try ActionJSON.encoded(query ?? self.query()).object ?? [:],
              expectedBackend: .otzaria, deadlineMs: deadline)
    }
    @MainActor private func core(_ source: ColdExecutionSource, ui: ColdExecutionUI? = nil) throws -> ActionExecutor {
        try .init(state: source, resolver: source, search: source, ui: ui, navigationAuthority: source)
    }

    @MainActor func testAuthorizedColdQueryKeepsExactQueryAndFreshAssessment() async throws {
        let source = ColdExecutionSource(), executor = try core(source), q = query()
        let result = await executor.execute(try request(q), context: source.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(result.data?["total"], .integer(0))
        XCTAssertEqual(result.data?["totalSemantics"], .string("matching_documents"))
        XCTAssertEqual(source.preparedQuery, q); XCTAssertEqual(source.searchedQuery, q)
        XCTAssertEqual(source.events, ["assess", "prepare", "assess", "search"])
        XCTAssertEqual(source.assessedArguments.count, 2)
        XCTAssertEqual(source.assessedArguments.first, source.assessedArguments.last)
        XCTAssertEqual(source.preparedInvocation?.snapshot, source.current)
    }
    @MainActor func testColdOpenResultsUsesOriginalGrantAndReceiptWithoutHeadlessQuery() async throws {
        let source = ColdExecutionSource(), ui = ColdExecutionUI(source), executor = try core(source, ui: ui)
        let q = ActionSearchQuery(backend: .otzaria, text: "אב", scopeWorkRefs: [.init(backend: .otzaria, workKey: "book:1")])
        let nested: ActionObject = ["text": .string(q.text), "scopeWorkRefs": try .encoded(q.scopeWorkRefs)]
        let r = ActionRequest(action: "search.openResults", arguments: ["searchQuery": .object(nested)],
                              expectedBackend: .otzaria, requestedPresentation: .foreground)
        let result = await executor.execute(r, context: source.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(result.effects, ["search_results_opened"])
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 0); XCTAssertEqual(ui.commands, 1)
        XCTAssertEqual(source.preparedQuery, q); XCTAssertEqual(ui.displayed?.search, q)
        XCTAssertEqual(ui.receipt?.requestId, r.requestId); XCTAssertEqual(ui.receipt?.snapshot, source.current)
    }
    @MainActor func testMissingContentRightsCannotPrepareOrRead() async throws {
        let source = ColdExecutionSource(), executor = try core(source)
        let result = await executor.execute(try request(), context: coldContext(rights: false))
        XCTAssertEqual(result.error?.code, "content_rights_required")
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0); XCTAssertEqual(source.assessments, 0)
    }
    @MainActor func testMissingReadScopeCannotPrepareOrRead() async throws {
        let source = ColdExecutionSource(), executor = try core(source)
        let result = await executor.execute(try request(), context: coldContext(scopes: [.discovery, .navigation]))
        XCTAssertEqual(result.error?.code, "permission_denied")
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testRestrictedWorkDenialPrecedesPreparation() async throws {
        let source = ColdExecutionSource(), executor = try core(source)
        let result = await executor.execute(try request(query(work: "book:2")), context: source.context)
        XCTAssertEqual(result.error?.code, "permission_denied")
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.assessments, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testRestrictedGlobalSearchCannotBorrowOneWorkGrant() async throws {
        let source = ColdExecutionSource(), executor = try core(source)
        let result = await executor.execute(try request(query(work: nil)), context: source.context)
        XCTAssertEqual(result.error?.code, "scope_required")
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.assessments, 0)
    }
    @MainActor func testUnregisteredOrUnsupportedOperationsNeverPrepare() async throws {
        for registered in [false, true] {
            let source = ColdExecutionSource(); source.registered = registered; source.supported = !registered
            let result = await (try core(source)).execute(try request(), context: source.context)
            XCTAssertEqual(result.status, .notSupported); XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
        }
    }
    @MainActor func testAlreadyReadyReadKeepsOldPath() async throws {
        let source = ColdExecutionSource(); source.ready = true
        let result = await (try core(source)).execute(try request(), context: source.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(source.preparations, 0)
        XCTAssertEqual(source.searches, 1); XCTAssertEqual(source.events, ["assess", "search"])
    }
    @MainActor func testDiscoveryAndBackendReportRemainObservations() async throws {
        let source = ColdExecutionSource(), executor = try core(source)
        let actions = await executor.advertisedActions(for: .otzaria, context: source.context)
        XCTAssertFalse(actions.contains { $0.id == "search.query" })
        let result = await executor.execute(.init(action: "system.listBackends", arguments: ["includeReadiness": .bool(true)]), context: source.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
        XCTAssertFalse(source.ready)
    }
    func testProviderWithoutOptionalPreparationKeepsOldUnavailableResult() async throws {
        let provider = MockPorts(); await provider.configure(available: false)
        let executor = try ActionExecutor(state: provider, resolver: provider, search: provider)
        let result = await executor.execute(try request(), context: coldContext())
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(result.error?.code, "index_missing")
        let counts = await provider.counts(); XCTAssertEqual(counts.search, 0)
        let disabled = await ColdExecutionSource(hasPreparation: false)
        let configuredCore = try await core(disabled)
        let disabledResult = await configuredCore.execute(try request(), context: coldContext())
        XCTAssertEqual(disabledResult.status, .unavailable); XCTAssertEqual(disabledResult.error?.code, "index_missing")
        let observations = await MainActor.run { (disabled.preparations, disabled.assessments, disabled.searches) }
        XCTAssertEqual(observations.0, 0); XCTAssertEqual(observations.1, 1); XCTAssertEqual(observations.2, 0)
    }
    @MainActor func testSuccessfulPreparationReturnDoesNotManufactureReadiness() async throws {
        let source = ColdExecutionSource(); source.makesReady = false
        let result = await (try core(source)).execute(try request(), context: source.context)
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(result.error?.code, "index_missing")
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.assessments, 2); XCTAssertEqual(source.searches, 0)
        XCTAssertNil(result.data)
    }
    @MainActor func testPreparationFailureNeverBecomesSuccessfulZero() async throws {
        let source = ColdExecutionSource(); source.throwsUnavailable = true
        let result = await (try core(source)).execute(try request(), context: source.context)
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(result.error?.code, "backend_unavailable")
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 0); XCTAssertNil(result.data)
    }
    @MainActor func testGenerationChangeDuringPreparationDiscardsAuthority() async throws {
        let source = ColdExecutionSource(); source.afterPreparation = { source.current = .init(backend: .otzaria, generation: 8) }
        let result = await (try core(source)).execute(try request(), context: source.context)
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(result.error?.code, "backend_generation_changed")
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testBackendABADuringPreparationCannotRestoreOldInvocation() async throws {
        let source = ColdExecutionSource(); source.afterPreparation = {
            source.current = .init(backend: .sefaria, generation: 8)
            source.current = .init(backend: .otzaria, generation: 9)
        }
        let result = await (try core(source)).execute(try request(), context: source.context)
        XCTAssertEqual(result.status, .staleState); XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testCancellationDuringPreparationNeverDispatchesSearch() async throws {
        let source = ColdExecutionSource(); source.delay = 5_000_000_000
        let executor = try core(source), req = try request(deadline: 2_000), context = source.context
        let task = Task { await executor.execute(req, context: context) }
        let until = DispatchTime.now().uptimeNanoseconds + 500_000_000
        while source.preparations == 0 && DispatchTime.now().uptimeNanoseconds < until {
            try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
        }
        task.cancel()
        let result = await task.value
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(result.status, .cancelled); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testDeadlineDuringPreparationRetainsOriginalDeadlineFailure() async throws {
        let source = ColdExecutionSource(); source.delay = 5_000_000_000
        let result = await (try core(source)).execute(try request(deadline: 100), context: source.context)
        XCTAssertEqual(result.status, .cancelled); XCTAssertEqual(result.error?.code, "deadline_exceeded")
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testPreCancelledRequestDoesNotPrepare() async throws {
        let source = ColdExecutionSource(), executor = try core(source), req = try request(), context = source.context
        let task = Task { withUnsafeCurrentTask { $0?.cancel() }; return await executor.execute(req, context: context) }
        let result = await task.value
        XCTAssertEqual(result.status, .cancelled); XCTAssertEqual(source.preparations, 0)
        XCTAssertEqual(source.assessments, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testReplayDoesNotRepeatPreparationAndConflictDoesNotReuseIt() async throws {
        let source = ColdExecutionSource(), executor = try core(source), req = try request(), context = source.context
        let first = await executor.execute(req, context: context)
        let replay = await executor.execute(req, context: context)
        XCTAssertEqual(first.status, .completed); XCTAssertEqual(first, replay)
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 1)
        let different = ActionSearchQuery(backend: .otzaria, text: "אחר", scopeWorkRefs: [.init(backend: .otzaria, workKey: "book:1")])
        let conflict = await executor.execute(try request(different, id: req.requestId), context: context)
        XCTAssertEqual(conflict.error?.code, "request_replay_conflict")
        XCTAssertEqual(source.preparations, 1); XCTAssertEqual(source.searches, 1)
    }
    @MainActor func testMetadataReadNeverPreparesSearch() async throws {
        let source = ColdExecutionSource(); source.ready = true
        let req = ActionRequest(action: "catalog.resolveWork", arguments: ["query": .string("known")], expectedBackend: .otzaria)
        let result = await (try core(source)).execute(req, context: source.context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(source.resolutions, 1)
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testOccurrenceCountCannotInheritSearchPreparation() async throws {
        let source = ColdExecutionSource()
        let args: ActionObject = ["text": .string("אב"), "countUnit": .string("matching_occurrences"),
                                 "scopeWorkRefs": try .encoded([ActionWorkRef(backend: .otzaria, workKey: "book:1")])]
        let result = await (try core(source)).execute(.init(action: "search.countOccurrences", arguments: args,
            expectedBackend: .otzaria), context: source.context)
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(source.preparations, 0)
        XCTAssertEqual(source.counts, 0); XCTAssertEqual(source.searches, 0); XCTAssertNil(result.data)
    }
}
