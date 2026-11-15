import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class ScenePortTests: XCTestCase, @unchecked Sendable {
    private func make(_ backend: ActionBackendID = .otzaria) throws -> UISceneCommand {
        let ref = ActionTextRef(backend: backend, workKey: "fixture:work", position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1"))
        let snapshot = ActionBackendSnapshot(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil)
        let route = RouteSpec(destination: .init(rawValue: "fixture.reader")!, backend: backend,
            content: .init(sectionLocator: ref), presentation: .init(tabID: .init(rawValue: "tab-1")),
            state: .init(selectedItemID: .init(rawValue: "item-1")), focus: .init(kind: .content, locator: ref),
            scene: .init(kind: .specific, sceneID: .init(rawValue: "scene-1"), expectedRevision: 5), expectedBackendSnapshot: snapshot)
        return try UISceneCommand(route: UIDestinationRegistry.fixtures().validate(route),
            invocation: .init(requestId: route.requestId, snapshot: snapshot, deadlineUptimeNanoseconds: 100),
            scene: .init(sceneID: .init(rawValue: "scene-1")!, revision: 5, backendSnapshot: snapshot))
    }
    private func coreReceipt(_ command: UISceneCommand) -> ActionUIReceipt {
        .init(requestId: command.invocation.requestId, snapshot: command.invocation.snapshot, sceneID: command.scene.sceneID.rawValue, destination: command.route.route.content!)
    }
    private func receipt(_ command: UISceneCommand, route: RouteSpec? = nil, requestId: UUID? = nil, snapshot: ActionBackendSnapshot? = nil,
                         scene: UIStableID? = nil, base: UInt64 = 5, applied: UInt64 = 6, core: ActionUIReceipt? = nil) -> UISceneReceipt {
        .init(requestId: requestId ?? command.invocation.requestId, route: route ?? command.route.route,
              backendSnapshot: snapshot ?? command.invocation.snapshot, sceneID: scene ?? command.scene.sceneID,
              basedOnSceneRevision: base, appliedSceneRevision: applied, coreReceipt: core ?? coreReceipt(command))
    }
    private func observed(_ command: UISceneCommand) -> UISceneSnapshot {
        .init(sceneID: command.scene.sceneID, revision: 6, backendSnapshot: command.invocation.snapshot, visibleRoute: command.route.route)
    }
    func testExactAcknowledgementAllBackends() throws {
        for backend in ActionBackendID.allCases {
            let command = try make(backend)
            try command.validateCurrent(command.scene, now: 99)
            try receipt(command).validate(for: command, observed: observed(command))
        }
    }
    func testEveryReceiptBindingAndObservedStateRequired() throws {
        let command = try make(), expected = observed(command), route = command.route.route
        let wrongScene = UIStableID(rawValue: "scene-other")!
        let stale = ActionBackendSnapshot(backend: .otzaria, generation: 2)
        for bad in [receipt(command, requestId: UUID()), receipt(command, snapshot: stale), receipt(command, scene: wrongScene),
                    receipt(command, base: 4), receipt(command, applied: 5)] {
            XCTAssertThrowsError(try bad.validate(for: command, observed: expected))
        }
        let changedRoutes = [
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: .sefaria),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend, content: route.content, presentation: .init(tabID: .init(rawValue: "other-tab")), state: route.state, focus: route.focus, scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend, content: route.content, presentation: route.presentation, state: .init(selectedItemID: .init(rawValue: "other-item")), focus: route.focus, scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot),
            RouteSpec(requestId: route.requestId, destination: route.destination, backend: route.backend, content: route.content, presentation: route.presentation, state: route.state, focus: .init(kind: .component, anchor: .init(rawValue: "fixture.reader.toc")), scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot)
        ]
        for bad in changedRoutes { XCTAssertThrowsError(try receipt(command, route: bad).validate(for: command, observed: expected)) }
        for bad in [UISceneSnapshot(sceneID: wrongScene, revision: 6, backendSnapshot: command.invocation.snapshot, visibleRoute: route),
                    .init(sceneID: command.scene.sceneID, revision: 7, backendSnapshot: command.invocation.snapshot, visibleRoute: route),
                    .init(sceneID: command.scene.sceneID, revision: 6, backendSnapshot: stale, visibleRoute: route),
                    .init(sceneID: command.scene.sceneID, revision: 6, backendSnapshot: command.invocation.snapshot),
                    .init(sceneID: command.scene.sceneID, revision: 6, backendSnapshot: command.invocation.snapshot, visibleRoute: changedRoutes[1])] {
            XCTAssertThrowsError(try receipt(command).validate(for: command, observed: bad))
        }
        let wrongDestination = ActionReaderDestination(sectionLocator: .init(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(99)))
        let wrongCore = ActionUIReceipt(requestId: route.requestId, snapshot: command.invocation.snapshot, sceneID: command.scene.sceneID.rawValue, destination: wrongDestination)
        XCTAssertThrowsError(try receipt(command, core: wrongCore).validate(for: command, observed: expected))
        let missing = UISceneReceipt(requestId: route.requestId, route: route, backendSnapshot: command.invocation.snapshot, sceneID: command.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
        XCTAssertThrowsError(try missing.validate(for: command, observed: expected))
    }
    func testPrecommitDeadlineSceneGenerationEpochAndTargetBindings() throws {
        for backend in ActionBackendID.allCases {
            let command = try make(backend)
            XCTAssertThrowsError(try command.validateCurrent(command.scene, now: 100))
            XCTAssertThrowsError(try command.validateCurrent(.init(sceneID: command.scene.sceneID, revision: 6, backendSnapshot: command.invocation.snapshot), now: 1))
            let changed = ActionBackendSnapshot(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 8 : 9)
            XCTAssertThrowsError(try command.validateCurrent(.init(sceneID: command.scene.sceneID, revision: 5, backendSnapshot: changed), now: 1))
            XCTAssertThrowsError(try UISceneCommand(route: command.route, invocation: .init(requestId: UUID(), snapshot: command.invocation.snapshot, deadlineUptimeNanoseconds: 100), scene: command.scene))
            let another = UISceneSnapshot(sceneID: UIStableID(rawValue: "other-scene")!, revision: 5, backendSnapshot: command.invocation.snapshot)
            XCTAssertThrowsError(try UISceneCommand(route: command.route, invocation: command.invocation, scene: another))
        }
        let command = try make(), registry = try UIDestinationRegistry.fixtures()
        let inactive = UISceneSnapshot(sceneID: command.scene.sceneID, revision: 5, backendSnapshot: .init(backend: .sefaria, generation: 1))
        XCTAssertThrowsError(try UISceneCommand(route: command.route, invocation: command.invocation, scene: inactive)) {
            XCTAssertEqual(($0 as? UIRouteError)?.status, .requiresBackendSwitch)
        }
        let unprepared = RouteSpec(destination: command.route.route.destination, content: command.route.route.content)
        XCTAssertThrowsError(try UISceneCommand(route: registry.validate(unprepared), invocation: .init(requestId: unprepared.requestId, snapshot: command.invocation.snapshot, deadlineUptimeNanoseconds: 100), scene: command.scene))
        let missingBackend = RouteSpec(destination: UIDestinationID(rawValue: "fixture.settings")!)
        XCTAssertThrowsError(try UISceneCommand(route: registry.validate(missingBackend), invocation: .init(requestId: missingBackend.requestId, snapshot: command.invocation.snapshot, deadlineUptimeNanoseconds: 100), scene: command.scene))
    }
    func testCancellationIsRecheckedBeforeCommit() async throws {
        let command = try make(), gate = SceneTestGate()
        let task = Task { await gate.enter(); try command.validateCurrent(command.scene, now: 1) }
        await gate.waitForEntry(); task.cancel(); await gate.release()
        do { try await task.value; XCTFail("Cancelled command accepted") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    @MainActor func testPortQueueDoesNotCommitAndAcknowledgementMatchesObservation() async throws {
        let command = try make(), port = SceneContractFake(scene: try make().scene)
        let context = ActionExecutionContext(subjectID: "synthetic-port-test", origin: .inApp, allowedBackends: [.otzaria], scopes: [.discovery, .navigation], foregroundSceneID: command.scene.sceneID.rawValue)
        port.queued = true
        let outcome = try await port.commit(command, context: context)
        guard case .queued = outcome else { return XCTFail("Expected queue-only result") }
        let unchanged = try await port.snapshot(target: command.route.route.scene, context: context)
        XCTAssertEqual(unchanged, command.scene)
        port.queued = false
        let committed = try await port.commit(command, context: context)
        guard case .acknowledged(let receipt) = committed else { return XCTFail("Missing receipt") }
        let observed = try await port.snapshot(target: command.route.route.scene, context: context)
        try receipt.validate(for: command, observed: observed)
        // A second command pinned to the old scene must fail before another commit.
        do { _ = try await port.commit(command, context: context); XCTFail("Stale command committed twice") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
    }
}

/// Protocol example against synthetic in-memory state, not a native UI adapter.
@MainActor private final class SceneContractFake: UISceneNavigationPort {
    private var current: UISceneSnapshot
    var queued = false
    init(scene: UISceneSnapshot) { current = scene }
    func snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot { current }
    func commit(_ command: UISceneCommand, context: ActionExecutionContext) async throws -> UISceneAcknowledgement {
        try command.validateCurrent(current, now: 1)
        if queued { return .queued(handle: "synthetic-queue") }
        let route = command.route.route, before = current.revision
        current = .init(sceneID: current.sceneID, revision: before + 1, backendSnapshot: current.backendSnapshot, visibleRoute: route)
        let core = route.content.map { ActionUIReceipt(requestId: route.requestId, snapshot: command.invocation.snapshot, sceneID: current.sceneID.rawValue, destination: $0) }
        return .acknowledged(.init(requestId: route.requestId, route: route, backendSnapshot: current.backendSnapshot, sceneID: current.sceneID,
                                  basedOnSceneRevision: before, appliedSceneRevision: current.revision, coreReceipt: core))
    }
}

actor SceneTestGate {
    private var entered = false
    private var observer: CheckedContinuation<Void, Never>?
    private var blocked: CheckedContinuation<Void, Never>?
    func enter() async { entered = true; observer?.resume(); observer = nil; await withCheckedContinuation { blocked = $0 } }
    func waitForEntry() async { if !entered { await withCheckedContinuation { observer = $0 } } }
    func release() { blocked?.resume(); blocked = nil }
}
