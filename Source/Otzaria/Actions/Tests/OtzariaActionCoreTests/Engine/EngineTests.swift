import Foundation
import XCTest
@testable import OtzariaActionCore

final class EngineTests: XCTestCase, @unchecked Sendable {
    func context(backend: ActionBackendID = .otzaria, scene: String? = "fixture-scene", scopes: Set<ActionScope> = [.discovery, .contentRead, .navigation], rights: Bool = true, maxActions: Int = 100, maxBytes: Int = 65_536) -> ActionExecutionContext {
        .init(subjectID: "fixture-user", origin: .inApp, allowedBackends: Set(ActionBackendID.allCases),
            contentRights: rights ? Set(ActionBackendID.allCases) : [], scopes: scopes, foregroundSceneID: scene, maxActions: maxActions, maxResultBytes: maxBytes)
    }
    func request(_ action: String = "search.query", backend: ActionBackendID = .otzaria, extra: ActionObject = [:], deadline: Int? = nil) -> ActionRequest {
        var args: ActionObject = action == "search.query" ? ["text": .string("fixture")] : [:]
        args.merge(extra) { _, new in new }
        return .init(action: action, arguments: args, expectedBackend: backend, deadlineMs: deadline)
    }
    func openRequest(backend: ActionBackendID = .otzaria) throws -> ActionRequest {
        let ref = ActionTextRef(backend: backend, workKey: "fixture:work", position: .legacyLine(42))
        return request("reader.open", backend: backend, extra: ["sectionLocator": try .encoded(ref)])
    }
    func testInitialFiveAcrossAllThreeMockBackends() async throws {
        for backend in ActionBackendID.allCases {
            let ports = MockPorts(backend: backend), ctx = context(backend: backend)
            let ui = await MockUI(ports: ports)
            let core = try ActionExecutor(state: ports, resolver: ports, search: ports, ui: ui)
            for req in [request("system.listBackends", backend: backend, extra: ["includeReadiness": .bool(true)]),
                        request("catalog.resolveWork", backend: backend, extra: ["query": .string("known")]),
                        request("catalog.resolveReference", backend: backend, extra: ["text": .string("known reference")]),
                        request(backend: backend), try openRequest(backend: backend)] {
                let result = await core.execute(req, context: ctx)
                XCTAssertEqual(result.status, .completed, "\(backend) \(req.action): \(String(describing: result.error))")
                _ = try ActionWireCodec.encodeResult(result)
            }
        }
    }
    func testBackendConflictsAndInvalidSemanticsPrecedeAllProviderCalls() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let otz = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42))
        let sef = ActionTextRef(backend: .sefaria, workKey: "fixture:work", position: .canonicalRef("Fixture 1:1"))
        let other = ActionTextRef(backend: .otzaria, workKey: "fixture:other", position: .legacyLine(42))
        let bad: [ActionRequest] = [
            request(extra: ["backend": .string("sefaria")]),
            request(extra: ["scopeWorkRefs": .array([try .encoded(ActionWorkRef(backend: .otzaria, workKey: "a")), try .encoded(ActionWorkRef(backend: .sefaria, workKey: "b"))])]),
            request("reader.open", extra: ["sectionLocator": try .encoded(otz), "focusLocator": try .encoded(sef)]),
            request("reader.open", extra: ["sectionLocator": try .encoded(otz), "focusLocator": try .encoded(other)]),
            request("catalog.resolveReference", extra: ["text": .string("   ")]),
            request(extra: ["limit": .integer(101)]),
            request(extra: ["unknown": .bool(true)])
        ]
        for req in bad { let r = await core.execute(req, context: context()); XCTAssertEqual(r.status, .failed) }
        let counts = await ports.counts()
        XCTAssertEqual(counts.snapshot + counts.assessment + counts.resolution + counts.search, 0)
    }
    func testInactiveBackendRequiresSwitchWithoutCommandCalls() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let result = await core.execute(request(backend: .sefariaEmbedded), context: context())
        XCTAssertEqual(result.status, .requiresBackendSwitch)
        let counts = await ports.counts()
        XCTAssertEqual(counts.assessment + counts.resolution + counts.search, 0)
    }
    func testRightsOriginAndScopeFailClosed() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let denied = await core.execute(request(), context: context(rights: false))
        XCTAssertEqual(denied.error?.code, "content_rights_required")
        let remote = ActionExecutionContext(subjectID: "remote", origin: .mcp, allowedBackends: [.otzaria], contentRights: [.otzaria], scopes: [.contentRead])
        let offline = await core.execute(request(), context: remote)
        XCTAssertEqual(offline.error?.code, "device_offline")
        let link = ActionExecutionContext(subjectID: "link", origin: .deepLink, allowedBackends: [.otzaria], contentRights: [.otzaria], scopes: [.contentRead])
        let blocked = await core.execute(request(), context: link)
        XCTAssertEqual(blocked.status, .notSupported)
        let counts = await ports.counts(); XCTAssertEqual(counts.search, 0)
    }
    func testAmbiguityCappedAndUnknownEmbeddedReferenceNotInvented() async throws {
        let ports = MockPorts(backend: .sefariaEmbedded), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let ambiguous = await core.execute(request("catalog.resolveWork", backend: .sefariaEmbedded, extra: ["query": .string("ambiguous"), "limit": .integer(10)]), context: context())
        XCTAssertEqual(ambiguous.status, .needsDisambiguation); XCTAssertEqual(ambiguous.candidates?.count, 10)
        let unknown = await core.execute(request("catalog.resolveReference", backend: .sefariaEmbedded, extra: ["text": .string("unknown Hebrew phrase")]), context: context())
        XCTAssertEqual(unknown.error?.code, "not_found")
    }
    func testSemanticSupportAvailabilityAndRealZeroAreDistinct() async throws {
        let ports = MockPorts(backend: .sefariaEmbedded), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        await ports.configure(strictEmbedded: true)
        for options: ActionObject in [["searchMode": .string("near"), "wordDistance": .integer(7)], ["sortOrder": .string("canonical")]] {
            let r = await core.execute(request(backend: .sefariaEmbedded, extra: options), context: context()); XCTAssertEqual(r.status, .notSupported)
        }
        await ports.configure(available: false)
        let missing = await core.execute(request(backend: .sefariaEmbedded), context: context())
        XCTAssertEqual(missing.status, .unavailable); XCTAssertEqual(missing.error?.code, "index_missing")
        await ports.configure()
        let zero = await core.execute(request(backend: .sefariaEmbedded), context: context())
        XCTAssertEqual(zero.status, .completed); XCTAssertEqual(zero.data?["total"], .integer(0))
    }
    func testPaginationIdentityAndProviderErrors() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        await ports.configure(.one)
        let page = await core.execute(request(extra: ["offset": .integer(10)]), context: context())
        XCTAssertEqual(page.data?["nextOffset"], .integer(17)); XCTAssertEqual(page.data?["precision"], .string("lower_bound"))
        for behavior in [MockPorts.Behavior.nonAdvancing, .duplicate, .wrongBackend] {
            await ports.configure(behavior)
            let bad = await core.execute(request(), context: context()); XCTAssertEqual(bad.status, .failed)
        }
        await ports.configure(.secretError)
        let error = await core.execute(request(), context: context())
        let text = String(decoding: try ActionWireCodec.encodeResult(error), as: UTF8.self)
        XCTAssertEqual(error.error?.code, "provider_failed")
        XCTAssertFalse(text.contains("DO_NOT_LEAK")); XCTAssertFalse(text.contains("SELECT")); XCTAssertFalse(text.contains("private.db"))
    }
    func testGenerationAndEmbeddedEpochChangesDiscardResults() async throws {
        for (backend, behavior) in [(ActionBackendID.otzaria, MockPorts.Behavior.stale), (.sefariaEmbedded, .epoch)] {
            let ports = MockPorts(backend: backend), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
            await ports.configure(behavior)
            let result = await core.execute(request(backend: backend), context: context())
            XCTAssertEqual(result.status, .staleState)
        }
    }
    func testUIQueueSceneAndExactReceiptBinding() async throws {
        let ports = MockPorts(), ui = await MockUI(ports: ports)
        let core = try ActionExecutor(state: ports, resolver: ports, search: ports, ui: ui)
        let noScene = await core.execute(try openRequest(), context: context(scene: nil))
        XCTAssertEqual(noScene.status, .requiresForeground)
        for behavior in [MockUI.Behavior.queued, .wrongTarget, .wrongFocus, .wrongRequest, .stale] {
            await ui.configure(behavior)
            let result = await core.execute(try openRequest(), context: context())
            if behavior == .queued { XCTAssertEqual(result.status, .uiQueued) }
            else if behavior == .stale { XCTAssertEqual(result.status, .staleState) }
            else { XCTAssertEqual(result.error?.code, "invalid_backend_response") }
            XCTAssertNotEqual(result.status, .completed)
        }
    }
    func testCancellationDeadlineAndReplayBudget() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports, ledgerCapacity: 8)
        await ports.configure(.stall)
        let start = Date()
        let timed = await core.execute(request(deadline: 100), context: context())
        XCTAssertEqual(timed.status, .cancelled); XCTAssertEqual(timed.error?.code, "deadline_exceeded")
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        await ports.releasePending()
        let task = Task { await core.execute(self.request(deadline: 1000), context: self.context()) }
        try await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()
        let cancelled = await task.value
        XCTAssertEqual(cancelled.status, .cancelled)
        await ports.releasePending()
        await ports.configure()
        let ctx = context(maxActions: 1), req = request()
        let beforeReplay = await ports.counts()
        let first = await core.execute(req, context: ctx), replay = await core.execute(req, context: ctx)
        XCTAssertEqual(first, replay)
        let afterReplay = await ports.counts()
        XCTAssertEqual(afterReplay.search - beforeReplay.search, 1)
        let overBudget = await core.execute(request(), context: ctx)
        XCTAssertEqual(overBudget.error?.code, "action_budget_exceeded")
    }
    func testStagedCountWritesAndDiscoveryCannotAdvertiseThem() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let count = await core.execute(request("search.countOccurrences", extra: ["text": .string("word word"), "countUnit": .string("matching_occurrences")]), context: context())
        XCTAssertEqual(count.error?.code, "exact_count_unavailable")
        let note = await core.execute(request("notes.saveDraft", extra: ["draftRef": .string("fixture-draft"), "confirmationToken": .string("asserted-confirmation-token")]), context: context())
        XCTAssertEqual(note.status, .notSupported)
        let actions = await core.advertisedActions(for: .otzaria, context: context())
        XCTAssertTrue(Set(actions.map(\.id)).isSubset(of: ActionRegistry.implemented))
        XCTAssertFalse(actions.contains { $0.mutatesUserData })
    }
    func testOutputAndWorkScopeBudgets() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let tooLarge = await core.execute(request("system.listBackends", extra: ["includeReadiness": .bool(true)]), context: context(maxBytes: 1024))
        XCTAssertEqual(tooLarge.error?.code, "result_budget_exceeded")
        let restricted = ActionExecutionContext(subjectID: "restricted", origin: .inApp, allowedBackends: [.otzaria], contentRights: [.otzaria],
            scopes: [.contentRead], allowedWorkKeys: [.otzaria: ["fixture:work"]])
        let unscoped = await core.execute(request(), context: restricted)
        XCTAssertEqual(unscoped.error?.code, "scope_required")
        let scope = ActionWorkRef(backend: .otzaria, workKey: "fixture:work")
        await ports.configure(.wrongScope)
        let wrong = await core.execute(request(extra: ["scopeWorkRefs": .array([try .encoded(scope)])]), context: restricted)
        XCTAssertEqual(wrong.status, .failed)
    }
    func testSameRequestCannotReplayUnderChangedAuthorityOrAfterGenerationChange() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports, ledgerCapacity: 2)
        let ctx = context(), req = request()
        let first = await core.execute(req, context: ctx); XCTAssertEqual(first.status, .completed)
        let changed = await core.execute(req, context: context())
        XCTAssertEqual(changed.error?.code, "request_replay_conflict")
        await ports.bumpGeneration()
        let stale = await core.execute(req, context: ctx); XCTAssertEqual(stale.status, .staleState)
        _ = await core.execute(request(), context: context())
        let full = await core.execute(request(), context: context()); XCTAssertEqual(full.error?.code, "request_ledger_full")
    }
    func testCandidateProjectionRefusesExtraDataAndDropsProviderDebugReason() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        for query in ["unsafe candidate", "unsafe reason"] {
            let result = await core.execute(request("catalog.resolveWork", extra: ["query": .string(query)]), context: context())
            let wire = String(decoding: try ActionWireCodec.encodeResult(result), as: UTF8.self)
            XCTAssertFalse(wire.contains("DO_NOT_LEAK")); XCTAssertFalse(wire.contains("private.db"))
            if query == "unsafe candidate" { XCTAssertEqual(result.error?.code, "invalid_backend_response") }
            else { XCTAssertEqual(result.status, .needsDisambiguation); XCTAssertNil(result.candidates?.first?.reason) }
        }
    }
    func testUncooperativeWorkersHaveBoundedAdmissionAndFiniteDeadlines() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        await ports.configure(.stall)
        let requests = (0..<9).map { _ in request(deadline: 1000) }
        let ctx = context()
        let started = Date()
        let results = await withTaskGroup(of: ActionResult.self, returning: [ActionResult].self) { group in
            for request in requests { group.addTask { await core.execute(request, context: ctx) } }
            var results: [ActionResult] = []
            for await result in group { results.append(result) }
            return results
        }
        let counts = await ports.counts()
        await ports.releasePending() // No indefinite orphan test tasks.
        XCTAssertEqual(results.filter { $0.error?.code == "executor_busy" }.count, 1)
        XCTAssertEqual(results.filter { $0.status == .cancelled }.count, 8)
        XCTAssertEqual(counts.search, 8)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }
    func testTypedUnsignedSearchPreservesWireValuesAndCanonicalReplay() async throws {
        for (offset, limit, distance): (UInt64, UInt64, UInt64) in [(5, 1, 4), (100_000, 100, 100), (0, 1, 0)] {
            let typedPorts = MockPorts(), wirePorts = MockPorts()
            let typedCore = try ActionExecutor(state: typedPorts, resolver: typedPorts, search: typedPorts)
            let wireCore = try ActionExecutor(state: wirePorts, resolver: wirePorts, search: wirePorts)
            let req = request(extra: ["offset": .unsigned(offset), "limit": .unsigned(limit), "wordDistance": .unsigned(distance)])
            let bytes = try JSONEncoder().encode(req), ctx = context()
            let typed = await typedCore.execute(req, context: ctx)
            let wire = await wireCore.execute(data: bytes, context: ctx)
            XCTAssertEqual(typed.status, .completed); XCTAssertEqual(wire, typed)
            let observed = await typedPorts.lastSearchQuery, observedWire = await wirePorts.lastSearchQuery
            XCTAssertEqual(observed?.offset, Int(offset)); XCTAssertEqual(observed?.limit, Int(limit)); XCTAssertEqual(observed?.wordDistance, Int(distance))
            XCTAssertEqual(observedWire, observed)
            let replay = await typedCore.execute(data: bytes, context: ctx)
            XCTAssertEqual(replay, typed)
            let counts = await typedPorts.counts(); XCTAssertEqual(counts.search, 1)
        }
    }
    func testTypedUnsignedResolutionLimitDoesNotDefault() async throws {
        let ports = MockPorts(), core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let result = await core.execute(request("catalog.resolveWork", extra: ["query": .string("ambiguous"), "limit": .unsigned(3)]), context: context())
        XCTAssertEqual(result.status, .needsDisambiguation); XCTAssertEqual(result.candidates?.count, 3)
        let observed = await ports.lastWorkQuery; XCTAssertEqual(observed?.limit, 3)
        for value: ActionJSON in [.unsigned(UInt64.max), .bool(true), .number(3)] {
            let invalid = await core.execute(request(extra: ["offset": value]), context: context())
            XCTAssertEqual(invalid.status, .failed)
        }
    }
    func testAdvertisementUsesExecutionPolicyAcrossOriginsAndBackends() async throws {
        for backend in ActionBackendID.allCases {
            let ports = MockPorts(backend: backend), ui = await MockUI(ports: ports)
            let core = try ActionExecutor(state: ports, resolver: ports, search: ports, ui: ui)
            for origin in [ActionOrigin.inApp, .appIntent, .deepLink, .internalAI, .guide, .mcp] {
                let ctx = ActionExecutionContext(subjectID: "origin-fixture", origin: origin, allowedBackends: [backend], contentRights: [backend],
                    scopes: [.discovery, .contentRead, .navigation], foregroundSceneID: "fixture-scene", pairedDeviceAvailable: true)
                let advertised = await core.advertisedActions(for: backend, context: ctx)
                let result = await core.execute(request(backend: backend), context: ctx)
                XCTAssertEqual(advertised.contains { $0.id == "search.query" }, result.status == .completed, "\(backend) \(origin)")
                if origin == .deepLink { XCTAssertEqual(result.error?.code, "origin_action_not_allowed") }
            }
            let emptyScene = context(backend: backend, scene: " ")
            let advertised = await core.advertisedActions(for: backend, context: emptyScene)
            XCTAssertFalse(advertised.contains { $0.id == "reader.open" })
        }
    }
}
