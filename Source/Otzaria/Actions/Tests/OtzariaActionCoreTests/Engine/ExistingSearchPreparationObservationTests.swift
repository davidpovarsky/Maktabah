import Foundation
import XCTest
@testable import OtzariaActionCore

// Explicit provider and clock doubles for Core's new opt-in projection.
// These controls do not claim app assets, a native engine, Hanlin or provider UI.
private func observationContext(rights: Bool = true,
                                scopes: Set<ActionScope> = [.discovery, .contentRead],
                                origin: ActionOrigin = .internalAI,
                                maxActions: Int = 20) -> ActionExecutionContext {
    .init(subjectID: "installed-source-observation-control", origin: origin,
          allowedBackends: [.otzaria], contentRights: rights ? [.otzaria] : [],
          scopes: scopes, allowedWorkKeys: [.otzaria: ["book:1"]], maxActions: maxActions)
}

private final class ObservationClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 1
    func now() -> UInt64 { lock.withLock { value } }
    func advance() { lock.withLock { value += 6_000_000_000 } }
    func sleep(until deadline: UInt64) async throws {
        while now() < deadline { try await Task<Never, Never>.sleep(nanoseconds: 1_000_000) }
    }
}

@MainActor private final class ObservedPreparationSource: ActionBackendStatePort, ActionResolverPort,
    ActionSearchPort, ActionSearchPreparationObservationPort {
    enum Mode { case eligible, unavailable, wrongRequest, wrongSnapshot, wrongDeadline, sourceChange, sourceABA, failure }
    var current = ActionBackendSnapshot(backend: .otzaria, generation: 17)
    var registered = true
    var supported = true
    var ready = false
    var mode = Mode.eligible
    var delay: UInt64 = 0
    var makesReady = true
    var observations = 0
    var preparations = 0
    var searches = 0
    var reports = 0
    var assessments = 0
    var preparedQuery: ActionSearchQuery?
    var searchedQuery: ActionSearchQuery?
    nonisolated let hasSearchExecutionPreparation: Bool
    init(configured: Bool = true) { hasSearchExecutionPreparation = configured }
    func snapshot() async throws -> ActionBackendSnapshot { current }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        reports += 1
        var operations = Dictionary(uniqueKeysWithValues: ["search.query", "search.openResults", "search.countOccurrences"].map {
            ($0, ActionCapabilityAssessment(registered: registered, supported: supported, availableNow: ready))
        })
        operations["catalog.resolveReference"] = .init(registered: true, supported: true, availableNow: true)
        return .init(id: backend, operations: operations)
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        assessments += 1
        return .init(registered: registered, supported: supported, availableNow: ready)
    }
    func observeExistingSearchPreparation(invocation: ActionPortInvocation) async throws -> ActionExistingSearchPreparationObservation {
        observations += 1
        if delay > 0 { try await Task<Never, Never>.sleep(nanoseconds: delay) }
        try Task.checkCancellation()
        switch mode {
        case .eligible: return .eligible(invocation: invocation)
        case .unavailable: return .unavailable
        case .wrongRequest:
            return .eligible(invocation: .init(requestId: UUID(), snapshot: invocation.snapshot,
                                               deadlineUptimeNanoseconds: invocation.deadlineUptimeNanoseconds))
        case .wrongSnapshot:
            return .eligible(invocation: .init(requestId: invocation.requestId,
                snapshot: .init(backend: .otzaria, generation: invocation.snapshot.generation + 1),
                deadlineUptimeNanoseconds: invocation.deadlineUptimeNanoseconds))
        case .wrongDeadline:
            return .eligible(invocation: .init(requestId: invocation.requestId, snapshot: invocation.snapshot,
                                               deadlineUptimeNanoseconds: invocation.deadlineUptimeNanoseconds + 1))
        case .sourceChange:
            current = .init(backend: .sefaria, generation: current.generation + 1)
            return .eligible(invocation: invocation)
        case .sourceABA:
            current = .init(backend: .otzaria, generation: current.generation + 2)
            return .eligible(invocation: invocation)
        case .failure: throw ActionPortError.unavailable
        }
    }
    func prepareSearchExecution(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws {
        preparations += 1; preparedQuery = query
        if makesReady { ready = true }
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        searches += 1; searchedQuery = query
        guard ready else { throw ActionPortError.unavailable }
        return .init(hits: [], total: 0, precision: .exact, totalSemantics: .matchingDocuments)
    }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { .notFound }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { destination }
}

@MainActor private final class UnobservedPreparationPort: ActionSearchPort, ActionSearchExecutionPreparationPort {
    let source: ObservedPreparationSource
    init(_ source: ObservedPreparationSource) { self.source = source }
    func prepareSearchExecution(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws {
        try await source.prepareSearchExecution(query, invocation: invocation)
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage {
        try await source.search(query, invocation: invocation)
    }
}

final class ExistingSearchPreparationObservationTests: XCTestCase, @unchecked Sendable {
    @MainActor private func core(_ source: ObservedPreparationSource, clock: any ActionClock = SystemActionClock()) throws -> ActionExecutor {
        try .init(state: source, resolver: source, search: source, clock: clock)
    }
    private func query(work: String? = "book:1") -> ActionSearchQuery {
        .init(backend: .otzaria, text: "בְּרֵאשִׁית", scopeWorkRefs: work.map { [.init(backend: .otzaria, workKey: $0)] } ?? [],
              searchMode: .near, matchMode: .exact, wordDistance: 3, sortOrder: .canonical, offset: 4, limit: 7)
    }
    private func request(_ query: ActionSearchQuery) throws -> ActionRequest {
        .init(action: "search.query", arguments: try ActionJSON.encoded(query).object ?? [:], expectedBackend: .otzaria)
    }
    @MainActor private func waitForObservation(_ source: ObservedPreparationSource) async throws {
        for _ in 0..<200 {
            if source.observations > 0 { return }
            try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("The controlled observation did not start")
    }

    @MainActor func testPositiveColdObservationAdvertisesOnlySearchWithoutPreparing() async throws {
        let source = ObservedPreparationSource(), executor = try core(source)
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
        XCTAssertEqual(Set(ids), ["catalog.resolveReference", "search.query"])
        XCTAssertEqual(source.observations, 1); XCTAssertEqual(source.reports, 1)
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0); XCTAssertFalse(source.ready)
    }
    @MainActor func testGenericAdvertisementAndReadinessRemainCold() async throws {
        let source = ObservedPreparationSource(), executor = try core(source), context = observationContext()
        let ids = await executor.advertisedActions(for: .otzaria, context: context).map(\.id)
        XCTAssertFalse(ids.contains("search.query"))
        let result = await executor.execute(.init(action: "system.listBackends", arguments: ["includeReadiness": .bool(true)]), context: context)
        let report = result.data?["backends"]?.array?.first { $0.object?["id"] == .string("otzaria") }
        XCTAssertEqual(report?.object?["operations"]?.object?["search.query"]?.object?["availableNow"], .bool(false))
        XCTAssertEqual(source.observations, 0); XCTAssertEqual(source.preparations, 0)
    }
    @MainActor func testReadySearchUsesOriginalPathWithoutObservation() async throws {
        let source = ObservedPreparationSource(); source.ready = true; source.mode = .failure
        let executor = try core(source)
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
        XCTAssertTrue(ids.contains("search.query")); XCTAssertEqual(source.observations, 0)
    }
    @MainActor func testMissingObservationPortCannotPromoteUnknown() async throws {
        let source = ObservedPreparationSource()
        let executor = try ActionExecutor(state: source, resolver: source, search: UnobservedPreparationPort(source))
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
        XCTAssertFalse(ids.contains("search.query")); XCTAssertEqual(source.observations, 0)
    }
    @MainActor func testUnconfiguredExecutionCannotAdvertisePreparation() async throws {
        let source = ObservedPreparationSource(configured: false), executor = try core(source)
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
        XCTAssertFalse(ids.contains("search.query")); XCTAssertEqual(source.observations, 0)
    }
    @MainActor func testUnavailableObservationCannotAdvertise() async throws {
        let source = ObservedPreparationSource(); source.mode = .unavailable
        let ids = try await core(source).advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
        XCTAssertEqual(Set(ids), ["catalog.resolveReference"]); XCTAssertEqual(source.preparations, 0)
    }
    @MainActor func testMissingRegistrationOrSupportPreventsObservation() async throws {
        for missingRegistration in [true, false] {
            let source = ObservedPreparationSource()
            source.registered = !missingRegistration; source.supported = missingRegistration
            let ids = try await core(source).advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
            XCTAssertFalse(ids.contains("search.query")); XCTAssertEqual(source.observations, 0)
        }
    }
    @MainActor func testCanonicalRightsScopesAndOriginPrecedeObservation() async throws {
        for context in [observationContext(rights: false), observationContext(scopes: [.discovery]),
                        observationContext(origin: .deepLink)] {
            let source = ObservedPreparationSource(), executor = try core(source)
            let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: context).map(\.id)
            XCTAssertFalse(ids.contains("search.query")); XCTAssertEqual(source.observations, 0)
        }
    }
    @MainActor func testPreparationObservationMustMatchWholeInvocation() async throws {
        for mode in [ObservedPreparationSource.Mode.wrongRequest, .wrongSnapshot, .wrongDeadline] {
            let source = ObservedPreparationSource(); source.mode = mode
            let ids = try await core(source).advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()).map(\.id)
            XCTAssertFalse(ids.contains("search.query")); XCTAssertEqual(source.preparations, 0)
        }
    }
    @MainActor func testSourceSwitchAndABAInvalidateWholeProjection() async throws {
        for mode in [ObservedPreparationSource.Mode.sourceChange, .sourceABA] {
            let source = ObservedPreparationSource(); source.mode = mode
            let result = try await core(source).advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext())
            XCTAssertTrue(result.isEmpty); XCTAssertEqual(source.preparations, 0)
        }
    }
    @MainActor func testThrownObservationDoesNotRetainEarlierProjection() async throws {
        let source = ObservedPreparationSource(); source.mode = .failure
        let result = try await core(source).advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext())
        XCTAssertTrue(result.isEmpty); XCTAssertEqual(source.preparations, 0)
    }
    @MainActor func testCancelledObservationReturnsWithoutPreparation() async throws {
        let source = ObservedPreparationSource(); source.delay = 30_000_000_000
        let executor = try core(source)
        let task = Task { await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()) }
        try await waitForObservation(source); task.cancel()
        let result = await task.value
        XCTAssertTrue(result.isEmpty); XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testObservationDeadlineUsesExistingBoundedRace() async throws {
        let source = ObservedPreparationSource(); source.delay = 30_000_000_000
        let clock = ObservationClock(), executor = try core(source, clock: clock)
        let task = Task { await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext()) }
        try await waitForObservation(source); clock.advance()
        let result = await task.value
        XCTAssertTrue(result.isEmpty); XCTAssertEqual(source.preparations, 0)
    }
    @MainActor func testProjectionConsumesOneOriginalActionBudget() async throws {
        let source = ObservedPreparationSource(), executor = try core(source), context = observationContext(maxActions: 1)
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: context).map(\.id)
        XCTAssertTrue(ids.contains("search.query")); XCTAssertEqual(source.reports, 1)
        let denied = await executor.execute(.init(action: "system.listBackends"), context: context)
        XCTAssertEqual(denied.error?.code, "action_budget_exceeded")
    }
    @MainActor func testExplicitAuthorizedExecutionRetainsOriginalPreparationAndQuery() async throws {
        let source = ObservedPreparationSource(), executor = try core(source), context = observationContext(maxActions: 2), q = query()
        let ids = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: context).map(\.id)
        XCTAssertTrue(ids.contains("search.query")); XCTAssertEqual(source.preparations, 0)
        let result = await executor.execute(try request(q), context: context)
        XCTAssertEqual(result.status, .completed); XCTAssertEqual(source.preparations, 1)
        XCTAssertEqual(source.assessments, 2); XCTAssertEqual(source.searches, 1)
        XCTAssertEqual(source.preparedQuery, q); XCTAssertEqual(source.searchedQuery, q)
    }
    @MainActor func testAdvertisementNeverGrantsRightsOrWorkScope() async throws {
        let source = ObservedPreparationSource(), executor = try core(source)
        _ = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext())
        let denied = await executor.execute(try request(query()), context: observationContext(rights: false))
        let unscoped = await executor.execute(try request(query(work: nil)), context: observationContext())
        let wrongWork = await executor.execute(try request(query(work: "book:2")), context: observationContext())
        XCTAssertEqual(denied.error?.code, "content_rights_required")
        XCTAssertEqual(unscoped.error?.code, "scope_required"); XCTAssertEqual(wrongWork.error?.code, "permission_denied")
        XCTAssertEqual(source.preparations, 0); XCTAssertEqual(source.searches, 0)
    }
    @MainActor func testExecutionStillRequiresFreshActualReadiness() async throws {
        let source = ObservedPreparationSource(); source.makesReady = false
        let executor = try core(source)
        _ = await executor.advertisedActionsWithExistingSearchPreparation(for: .otzaria, context: observationContext())
        let result = await executor.execute(try request(query()), context: observationContext())
        XCTAssertEqual(result.status, .unavailable); XCTAssertEqual(source.preparations, 1)
        XCTAssertEqual(source.assessments, 2); XCTAssertEqual(source.searches, 0)
    }
}
