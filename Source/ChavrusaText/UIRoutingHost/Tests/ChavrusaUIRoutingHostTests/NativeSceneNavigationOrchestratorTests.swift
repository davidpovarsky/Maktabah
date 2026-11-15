import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual Core actor + P's canonical preparation, synthetic native driver.
/// These are host-contract regressions, never native UI acceptance.
@MainActor final class NativeSceneNavigationOrchestratorTests: XCTestCase, @unchecked Sendable {
    private func fixture(scopes: Set<ActionScope> = [.navigation, .discovery]) async throws -> NavigationFixture {
        let backend = NavigationTestBackend(), authority = try NativeNavigationAuthority(), scene = UIStableID(rawValue: "scene.A")!
        let lease = try authority.mount(sceneID: scene, foreground: true)
        let directory = try NativeSceneDirectory(authority: backend), driver = NavigationTestDriver(sceneID: scene, backend: backend)
        _ = try directory.mount(sceneID: scene, observe: { driver.observation }, validateLifetime: { _ in })
        let ports = NavigationTestPorts(), core = try ActionExecutor(state: backend, resolver: ports, search: ports, navigationAuthority: authority)
        let orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory)
        try orchestrator.register(driver)
        let context = ActionExecutionContext(subjectID: "native-user", origin: .inApp, allowedBackends: [.otzaria], scopes: scopes, foregroundSceneID: scene.rawValue)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: backend.value, deadlineUptimeNanoseconds: UInt64.max)
        let snapshot = try await directory.currentScene(sceneID: scene, context: context, invocation: invocation)
        let descriptor = UIDestinationDescriptor(id: UIDestinationID(rawValue: "native.settings")!, title: "Test native settings", implementation: .implemented,
            supportedBackends: [.otzaria], presentations: [.sheet], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: invocation.requestId, destination: descriptor.id, backend: .otzaria,
                              presentation: .init(kind: .sheet), scene: .init(kind: .specific, sceneID: scene, expectedRevision: snapshot.revision))
        let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: snapshot)
        return .init(orchestrator: orchestrator, authority: authority, lease: lease, backend: backend, driver: driver, context: context, command: command)
    }
    func testCanonicalGuardThenExactVisibleReceipt() async throws {
        let f = try await fixture(), result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .acknowledged(let receipt) = result else { return XCTFail("Expected receipt, got \(result)") }
        XCTAssertEqual(receipt.route, f.command.route.route); XCTAssertGreaterThan(receipt.appliedSceneRevision, receipt.basedOnSceneRevision)
        XCTAssertEqual(f.driver.applied, 1)
    }
    func testMissingCanonicalScopeNeverMutatesNativeUI() async throws {
        let f = try await fixture(scopes: [.discovery])
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .failed = result else { return XCTFail("Expected denied noncompletion") }
        XCTAssertEqual(f.driver.applied, 0)
    }
    func testWrongVisibleSurfaceDoesNotAcknowledgeSameRequest() async throws {
        let f = try await fixture(); f.driver.afterApply = { f.driver.wrongSurface = true }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .failed(let failure) = result else { return XCTFail("Wrong native surface completed") }
        XCTAssertEqual(failure.code, "native_effect_uncertain"); XCTAssertEqual(f.driver.applied, 1)
    }
    func testBackendChangeAfterDispatchPreservesEffectUncertainty() async throws {
        let f = try await fixture()
        f.driver.afterApply = { f.backend.value = .init(backend: .otzaria, generation: 2) }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .staleState(let failure) = result else { return XCTFail("Changed backend completed") }
        XCTAssertEqual(failure.code, "native_effect_uncertain"); XCTAssertFalse(failure.retryable)
    }
    func testRevocationDuringVisibleWaitCannotBecomeCompletion() async throws {
        let f = try await fixture()
        f.driver.afterApply = { try f.authority.invalidate(f.lease) }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .staleState(let failure) = result else { return XCTFail("Revoked native request completed") }
        XCTAssertEqual(failure.code, "native_effect_uncertain")
    }
    func testRepeatedRequestDoesNotDispatchAgainOrReuseOldCompletion() async throws {
        let f = try await fixture()
        _ = try await f.orchestrator.commit(f.command, context: f.context)
        let duplicate = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .staleState = duplicate else { return XCTFail("Reused completion") }
        XCTAssertEqual(f.driver.applied, 1)
    }
    func testCancellationAfterDispatchNeverClaimsNoEffect() async throws {
        let f = try await fixture(), (stream, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        f.driver.wait = true; f.driver.afterApply = { signal.yield(()) }
        let task = Task { try await f.orchestrator.commit(f.command, context: f.context) }
        var iterator = stream.makeAsyncIterator(); _ = await iterator.next(); task.cancel()
        let result = try await task.value
        guard case .failed(let failure) = result else { return XCTFail("Cancelled effect became completion or no-effect") }
        XCTAssertEqual(failure.code, "native_effect_uncertain"); XCTAssertEqual(f.driver.applied, 1)
        signal.finish()
    }
    func testForegroundLossInvalidatesContextAndOldLeaseCannotRemoveReplacement() async throws {
        let f = try await fixture()
        try f.authority.admit(context: f.context, sceneID: f.command.scene.sceneID)
        let old = try f.authority.navigationState(sceneID: f.command.scene.sceneID.rawValue)
        try f.authority.setForeground(false, lease: f.lease)
        XCTAssertThrowsError(try f.authority.navigationState(sceneID: f.command.scene.sceneID.rawValue))
        f.authority.unmount(f.lease)
        let replacement = try f.authority.mount(sceneID: f.command.scene.sceneID, foreground: true)
        f.authority.unmount(f.lease)
        try f.authority.admit(context: f.context, sceneID: replacement.sceneID)
        let current = try f.authority.navigationState(sceneID: replacement.sceneID.rawValue)
        XCTAssertNotEqual(old.lifetimeID, current.lifetimeID); XCTAssertGreaterThan(current.authorityRevision, old.authorityRevision)
    }
}

@MainActor private struct NavigationFixture {
    let orchestrator: NativeSceneNavigationOrchestrator
    let authority: NativeNavigationAuthority
    let lease: NativeNavigationAuthority.Lease
    let backend: NavigationTestBackend
    let driver: NavigationTestDriver
    let context: ActionExecutionContext
    let command: UISceneCommand
}
@MainActor private final class NavigationTestBackend: ActionSynchronousBackendStatePort {
    var value = ActionBackendSnapshot(backend: .otzaria, generation: 1)
    func currentBackendSnapshot() throws -> ActionBackendSnapshot { value }
    func snapshot() async throws -> ActionBackendSnapshot { value }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment { .init(registered: false, supported: false, availableNow: false) }
}
private struct NavigationTestPorts: ActionResolverPort, ActionSearchPort {
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { .notFound }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.notSupported }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.notSupported }
}
@MainActor private final class NavigationTestDriver: NativeSceneDriver {
    let sceneID: UIStableID
    let backend: NavigationTestBackend
    var command: UISceneCommand?
    var applied = 0, wrongSurface = false, wait = false
    var afterApply: (@MainActor () throws -> Void)?
    init(sceneID: UIStableID, backend: NavigationTestBackend) { self.sceneID = sceneID; self.backend = backend }
    var surface: NativeSurfaceState {
        .init(destination: UIDestinationID(rawValue: wrongSurface ? "native.history" : "native.settings")!,
              presentation: .init(kind: applied == 0 ? .currentTab : .sheet), content: nil, state: .init(), focus: nil)
    }
    var observation: NativeSceneDirectory.Observation {
        .init(isForeground: true, isMounted: true,
              visibleRoute: applied == 0 ? nil : command.map { surface.observedRoute(for: $0, backend: backend.value) }, surface: surface)
    }
    func validateSurface(_ command: UISceneCommand) throws {}
    func beginObservation(_ command: UISceneCommand) throws { self.command = command }
    func apply(_ command: UISceneCommand) throws { applied += 1; try afterApply?() }
    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState {
        if wait { try await Task.sleep(nanoseconds: 10_000_000_000) }
        return surface
    }
    func endObservation(requestID: UUID) { command = nil }
}
