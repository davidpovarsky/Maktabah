import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual Core actor + P's canonical preparation, synthetic native driver.
/// These are host-contract regressions, never native UI acceptance.
@MainActor final class NativeSceneNavigationOrchestratorTests: XCTestCase, @unchecked Sendable {
    private func fixture(scopes: Set<ActionScope> = [.navigation, .discovery], backendID: ActionBackendID = .otzaria,
                         clock: any ActionClock = SystemActionClock(), deadline: UInt64 = UInt64.max) async throws -> NavigationFixture {
        let backend = NavigationTestBackend(backendID), authority = try NativeNavigationAuthority(), scene = UIStableID(rawValue: "scene.A")!
        let lease = try authority.mount(sceneID: scene, foreground: true)
        let directory = try NativeSceneDirectory(authority: backend, clock: clock), driver = NavigationTestDriver(sceneID: scene, backend: backend)
        _ = try directory.mount(sceneID: scene, observe: { driver.observation }, validateLifetime: { _ in })
        let ports = NavigationTestPorts(), core = try ActionExecutor(state: backend, resolver: ports, search: ports, clock: clock, navigationAuthority: authority)
        let orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory, clock: clock)
        try orchestrator.register(driver)
        let context = ActionExecutionContext(subjectID: "native-user", origin: .inApp, allowedBackends: [backendID], scopes: scopes, foregroundSceneID: scene.rawValue)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: backend.value, deadlineUptimeNanoseconds: deadline)
        let snapshot = try await directory.currentScene(sceneID: scene, context: context, invocation: invocation)
        let descriptor = UIDestinationDescriptor(id: UIDestinationID(rawValue: "native.settings")!, title: "Test native settings", implementation: .implemented,
            supportedBackends: [backendID], presentations: [.sheet], requiredCoreActions: [])
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(requestId: invocation.requestId, destination: descriptor.id, backend: backendID,
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
    func testCanonicalGenerationDriftAfterFinalObservationIsRejectedOnAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await fixture(backendID: backend)
            f.driver.afterApply = { f.backend.afterSnapshot = {
                f.backend.value = .init(backend: backend, generation: 2, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil)
            } }
            let result = try await f.orchestrator.commit(f.command, context: f.context)
            guard case .staleState(let failure) = result else { XCTFail("Final canonical drift completed: \(result)"); continue }
            XCTAssertEqual(failure.code, "native_effect_uncertain"); XCTAssertEqual(f.driver.applied, 1)
        }
    }
    func testCanonicalEpochDriftAfterFinalObservationIsRejected() async throws {
        let f = try await fixture(backendID: .sefariaEmbedded)
        f.driver.afterApply = { f.backend.afterSnapshot = { f.backend.value = .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 8) } }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .staleState(let failure) = result else { return XCTFail("Final epoch drift completed: \(result)") }
        XCTAssertEqual(failure.code, "native_effect_uncertain")
    }
    func testCanonicalReadinessLossAfterFinalObservationIsRejected() async throws {
        let f = try await fixture()
        f.driver.afterApply = { f.backend.afterSnapshot = { f.backend.available = false } }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .unavailable(let failure) = result else { return XCTFail("Final readiness loss completed: \(result)") }
        XCTAssertEqual(failure.code, "native_effect_uncertain")
    }
    func testCanonicalDeadlineExpiresDuringFinalSynchronousCompletionCheck() async throws {
        let clock = CompletionTestClock(), f = try await fixture(clock: clock, deadline: 200)
        f.driver.afterApply = { f.backend.afterSnapshot = { f.backend.onSynchronousSnapshot = { clock.expire() } } }
        let result = try await f.orchestrator.commit(f.command, context: f.context)
        guard case .failed(let failure) = result else { return XCTFail("Final deadline drift completed: \(result)") }
        XCTAssertEqual(failure.code, "native_effect_uncertain"); XCTAssertGreaterThan(clock.now(), 200)
    }
    func testCoreReaderOwnerKeepsContextUntilItsPostSinkCompletionOnAllBackends() async throws {
        for backendID in ActionBackendID.allCases { try await readerScenario(backendID, revokeAtFinalAwait: false) }
    }
    func testCoreReaderFinalBackendAwaitRevocationCannotCompleteSinkReceipt() async throws {
        for backendID in ActionBackendID.allCases { try await readerScenario(backendID, revokeAtFinalAwait: true) }
    }
    private func readerScenario(_ backendID: ActionBackendID, revokeAtFinalAwait: Bool) async throws {
            let backend = NavigationTestBackend(backendID), authority = try NativeNavigationAuthority(), sceneID = UIStableID(rawValue: "reader.scene")!
            backend.readerReady = true
            let lease = try authority.mount(sceneID: sceneID, foreground: true)
            let directory = try NativeSceneDirectory(authority: backend), driver = NavigationTestDriver(sceneID: sceneID, backend: backend)
            _ = try directory.mount(sceneID: sceneID, observe: { driver.observation }, validateLifetime: { _ in })
            let ports = NavigationTestPorts(allowReader: true), sink = NavigationReaderSink()
            let core = try ActionExecutor(state: backend, resolver: ports, search: ports, ui: sink, navigationAuthority: authority)
            let orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority, directory: directory)
            try orchestrator.register(driver)
            let context = ActionExecutionContext(subjectID: "native-reader", origin: .inApp, allowedBackends: [backendID], scopes: [.navigation],
                allowedWorkKeys: [backendID: ["fixture:work"]], foregroundSceneID: sceneID.rawValue)
            let admitted = try authority.admit(context: context, sceneID: sceneID)
            let descriptor = UIDestinationDescriptor(id: UIDestinationID(rawValue: "native.reader")!, title: "Synthetic reader", implementation: .implemented,
                supportedBackends: [backendID], presentations: [.currentTab], requiredCoreActions: ["reader.open"], requiresContent: true)
            let registry = try UIDestinationRegistry(descriptors: [descriptor])
            sink.onOpen = { reader in
                let scene = try await directory.currentScene(sceneID: sceneID, context: context, invocation: reader.invocation)
                let route = RouteSpec(requestId: reader.invocation.requestId, destination: descriptor.id, backend: backendID, content: reader.destination,
                    presentation: .init(tabID: UIStableID(rawValue: "native-tab")!), scene: .init(kind: .specific, sceneID: sceneID, expectedRevision: scene.revision))
                let command = try UISceneCommand(route: registry.validate(route), invocation: reader.invocation, scene: scene)
                let result = await orchestrator.commit(command, readerCommand: reader, context: context)
                guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
                if revokeAtFinalAwait {
                    // The first post-sink backend await remains current; revoke
                    // during Core's LAST shared backend await after that ACK.
                    backend.afterSnapshot = { backend.afterSnapshot = {
                        do { try authority.invalidate(lease) }
                        catch { XCTFail("Fixture revocation failed: \(error)") }
                    } }
                }
                return .acknowledged(coreReceipt)
            }
            let ref = ActionTextRef(backend: backendID, workKey: "fixture:work", position: backendID == .otzaria ? .legacyLine(1) : .canonicalRef("Fixture 1"))
            let result = await core.execute(.init(action: "reader.open", arguments: ["sectionLocator": try .encoded(ref)], expectedBackend: backendID), context: context)
            if revokeAtFinalAwait {
                XCTAssertNotEqual(result.status, .completed, "A native sink ACK is not the final Core action result")
                XCTAssertThrowsError(try authority.navigationState(sceneID: sceneID.rawValue))
            } else {
                XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
                XCTAssertEqual(try authority.navigationState(sceneID: sceneID.rawValue).context, context)
            }
            XCTAssertEqual(sink.calls, 1); XCTAssertEqual(driver.applied, 1)
            authority.release(admitted)
            XCTAssertThrowsError(try authority.navigationState(sceneID: sceneID.rawValue))
    }
    func testOldRequestCleanupCannotReleaseReissuedOrReplacedNativeContext() async throws {
        for replaceLifetime in [false, true] {
            let f = try await fixture(), old = try f.authority.admit(context: f.context, sceneID: f.command.scene.sceneID)
            if replaceLifetime {
                f.authority.unmount(f.lease)
                _ = try f.authority.mount(sceneID: f.command.scene.sceneID, foreground: true)
            } else { try f.authority.invalidate(f.lease) }
            let current = try f.authority.admit(context: f.context, sceneID: f.command.scene.sceneID)
            f.authority.release(old)
            let live = try f.authority.navigationState(sceneID: f.command.scene.sceneID.rawValue)
            XCTAssertEqual(live.context, current.context); XCTAssertEqual(live.lifetimeID, current.lifetimeID)
            XCTAssertEqual(live.authorityRevision, current.authorityRevision)
            f.authority.release(current)
            XCTAssertThrowsError(try f.authority.navigationState(sceneID: f.command.scene.sceneID.rawValue))
        }
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
    var value: ActionBackendSnapshot
    var available = true
    var readerReady = false
    var afterSnapshot: (@MainActor () -> Void)?
    var onSynchronousSnapshot: (@MainActor () -> Void)?
    init(_ backend: ActionBackendID) { value = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil) }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        guard available else { throw ActionPortError.unavailable }
        onSynchronousSnapshot?(); return value
    }
    func snapshot() async throws -> ActionBackendSnapshot {
        let captured = value, callback = afterSnapshot
        afterSnapshot = nil; callback?(); return captured
    }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: readerReady && action == "reader.open", supported: readerReady && action == "reader.open", availableNow: readerReady)
    }
}
private final class CompletionTestClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 100
    func now() -> UInt64 { lock.withLock { value } }
    func expire() { lock.withLock { value = 201 } }
    func sleep(until deadline: UInt64) async throws { try await Task.sleep(nanoseconds: 60_000_000_000) }
}
private struct NavigationTestPorts: ActionResolverPort, ActionSearchPort {
    var allowReader = false
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { .notFound }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { .notFound }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination {
        guard allowReader else { throw ActionPortError.notSupported }; return destination
    }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.notSupported }
}
@MainActor private final class NavigationTestDriver: NativeSceneDriver {
    let sceneID: UIStableID
    let backend: NavigationTestBackend
    var command: UISceneCommand?
    var applied = 0, wrongSurface = false, wait = false
    var content: ActionReaderDestination?
    var afterApply: (@MainActor () throws -> Void)?
    init(sceneID: UIStableID, backend: NavigationTestBackend) { self.sceneID = sceneID; self.backend = backend }
    var surface: NativeSurfaceState {
        .init(destination: UIDestinationID(rawValue: content == nil ? (wrongSurface ? "native.history" : "native.settings") : "native.reader")!,
              presentation: content == nil ? .init(kind: applied == 0 ? .currentTab : .sheet) : .init(tabID: UIStableID(rawValue: "native-tab")!),
              content: content, state: .init(), focus: nil)
    }
    var observation: NativeSceneDirectory.Observation {
        .init(isForeground: true, isMounted: true,
              visibleRoute: applied == 0 ? nil : command.map { surface.observedRoute(for: $0, backend: backend.value) }, surface: surface)
    }
    func validateSurface(_ command: UISceneCommand) throws {}
    func beginObservation(_ command: UISceneCommand) throws { self.command = command }
    func apply(_ command: UISceneCommand) throws { applied += 1; content = command.route.route.content; try afterApply?() }
    func waitUntilVisible(_ command: UISceneCommand) async throws -> NativeSurfaceState {
        if wait { try await Task.sleep(nanoseconds: 10_000_000_000) }
        return surface
    }
    func endObservation(requestID: UUID) { command = nil }
}
@MainActor private final class NavigationReaderSink: ActionUICommandSink {
    var calls = 0
    var onOpen: (@MainActor @Sendable (ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement)?
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        calls += 1
        guard let onOpen else { throw ActionPortError.unavailable }
        return try await onOpen(command)
    }
}
