import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class DiscoveryTests: XCTestCase, @unchecked Sendable {
    private func context(_ backend: ActionBackendID, origin: ActionOrigin = .inApp, rights: Bool = true, navigation: Bool = true,
                         scene: String? = "scene-1", paired: Bool = true) -> ActionExecutionContext {
        .init(subjectID: "synthetic-ui-test", origin: origin, allowedBackends: [backend], contentRights: rights ? [backend] : [],
              scopes: navigation ? [.discovery, .contentRead, .navigation] : [.discovery, .contentRead], foregroundSceneID: scene, pairedDeviceAvailable: paired)
    }
    private func scene(_ backend: ActionBackendID = .otzaria) -> UISceneSnapshot {
        .init(sceneID: .init(rawValue: "scene-1")!, revision: 5,
              backendSnapshot: .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil))
    }
    private func invocation(_ scene: UISceneSnapshot, deadline: UInt64 = UInt64.max) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: scene.backendSnapshot, deadlineUptimeNanoseconds: deadline)
    }
    private func registry(stage: UIDestinationDescriptor.Implementation = .implemented) throws -> UIDestinationRegistry {
        func descriptor(_ id: String, action: String, risk: Int = 2, mutates: Bool = false) -> UIDestinationDescriptor {
            .init(id: UIDestinationID(rawValue: id)!, title: "Synthetic host surface", implementation: stage,
                  supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: [action], riskTier: risk, mutatesUserData: mutates)
        }
        // The .implemented stage here is test-host metadata, not shipped catalog data.
        return try UIDestinationRegistry(descriptors: [descriptor("test.reader", action: "reader.open"), descriptor("test.search", action: "search.query", risk: 1),
            descriptor("test.notes", action: "notes.prepareDraft"), descriptor("test.mutation", action: "reader.open", mutates: true), descriptor("test.risk", action: "reader.open", risk: 3)])
    }
    private func executor(_ backend: ActionBackendID, ready: Bool = true, supported: Bool = true, ui: Bool = true) async throws -> DiscoveryRuntime {
        let ports = DiscoveryCorePorts(backend: backend, ready: ready, supported: supported)
        let sink: (any ActionUICommandSink)? = ui ? DiscoveryCoreUI() : nil
        return DiscoveryRuntime(core: try ActionExecutor(state: ports, resolver: ports, search: ports, ui: sink), state: ports)
    }
    func testActualCorePolicyDiscoverySixOriginsAllBackends() async throws {
        let registry = try registry()
        for backend in ActionBackendID.allCases {
            let core = try await executor(backend), scene = scene(backend)
            for origin in [ActionOrigin.inApp, .appIntent, .deepLink, .internalAI, .guide, .mcp] {
                let host = core.host(scene), context = context(backend, origin: origin)
                let result = try await registry.discover(scene: scene, context: context, invocation: invocation(scene), core: core.core, host: host)
                let ids = Set(result.map { $0.id.rawValue })
                XCTAssertTrue(ids.contains("test.reader"))
                XCTAssertEqual(ids.contains("test.search"), origin != .deepLink)
                XCTAssertFalse(ids.contains("test.notes"))
                XCTAssertFalse(ids.contains("test.mutation"))
                XCTAssertFalse(ids.contains("test.risk"))
            }
        }
    }
    func testReadinessRightsSceneDeviceAndHostEligibility() async throws {
        let registry = try registry(), scene = scene(), invocation = invocation(scene)
        for pair in [(false, true), (true, false)] {
            let core = try await executor(.otzaria, ready: pair.0, supported: pair.1), host = core.host(scene)
            let result = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation, core: core.core, host: host)
            XCTAssertTrue(result.isEmpty)
            let calls = await host.calls; XCTAssertEqual(calls, 0)
        }
        for context in [context(.otzaria, rights: false), context(.otzaria, navigation: false), context(.otzaria, scene: nil), context(.otzaria, origin: .mcp, paired: false)] {
            let core = try await executor(.otzaria), host = core.host(scene)
            let result = try await registry.discover(scene: scene, context: context, invocation: invocation, core: core.core, host: host)
            let ids = Set(result.map { $0.id.rawValue })
            if context.contentRights.isEmpty { XCTAssertFalse(ids.contains("test.search")) }
            if !context.scopes.contains(.navigation) || context.foregroundSceneID == nil { XCTAssertFalse(ids.contains("test.reader")) }
            if context.origin == .mcp { XCTAssertTrue(ids.isEmpty) }
        }
        for behavior in [DiscoveryHost.Behavior.unsupported, .notReady, .denied] {
            let core = try await executor(.otzaria), host = core.host(scene, behavior)
            let result = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation, core: core.core, host: host)
            XCTAssertTrue(result.isEmpty)
        }
        let noUI = try await executor(.otzaria, ui: false)
        let result = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation, core: noUI.core, host: noUI.host(scene))
        XCTAssertFalse(result.contains { $0.id.rawValue == "test.reader" })
    }
    func testFixturesInventoryAndEmptyNeverAdvertiseAsLive() async throws {
        let scene = scene(), core = try await executor(.otzaria), host = core.host(scene)
        for registry in [try UIDestinationRegistry(), try UIDestinationRegistry.fixtures(), try registry(stage: .fixture), try registry(stage: .inventoryOnly)] {
            let result = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation(scene), core: core.core, host: host)
            XCTAssertTrue(result.isEmpty)
        }
        let calls = await host.calls; XCTAssertEqual(calls, 0)
    }
    func testStaleSceneBackendDeadlineAndCancellationDuringHostWait() async throws {
        let registry = try registry(), scene = scene(), core = try await executor(.otzaria)
        for behavior in [DiscoveryHost.Behavior.staleRevision, .staleBackend, .wrongScene] {
            do {
                _ = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation(scene), core: core.core, host: core.host(scene, behavior))
                XCTFail("Stale host assessment accepted")
            } catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        }
        do {
            _ = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation(scene, deadline: 0), core: core.core, host: core.host(scene))
            XCTFail("Expired discovery accepted")
        } catch { XCTAssertEqual((error as? UIRouteError)?.status, .cancelled) }
        let wrong = ActionPortInvocation(requestId: UUID(), snapshot: .init(backend: .sefaria, generation: 1), deadlineUptimeNanoseconds: UInt64.max)
        do { _ = try await registry.discover(scene: scene, context: context(.otzaria), invocation: wrong, core: core.core, host: core.host(scene)); XCTFail("Wrong backend accepted") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
        let host = core.host(scene, .blocked), context = context(.otzaria), invocation = invocation(scene)
        let task = Task { try await registry.discover(scene: scene, context: context, invocation: invocation, core: core.core, host: host) }
        await host.waitForEntry(); task.cancel(); await host.release()
        do { _ = try await task.value; XCTFail("Cancelled discovery advertised destinations") } catch is CancellationError {} catch { XCTFail("Unexpected \(error)") }
    }
    func testSuccessfulDiscoveryCancelsDeadlineWaitWithoutAdvancingClock() async throws {
        let registry = try registry(), scene = scene(), core = try await executor(.otzaria), clock = DiscoveryClock()
        let result = try await registry.discover(scene: scene, context: context(.otzaria), invocation: invocation(scene, deadline: 20), core: core.core, host: core.host(scene), clock: clock)
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(clock.now(), 10)
        XCTAssertEqual(clock.pendingSleeps, 0)
    }
    func testDeadlineRecheckedAfterHostAwait() async throws {
        let registry = try registry(), scene = scene(), core = try await executor(.otzaria), host = core.host(scene, .blocked), clock = DiscoveryClock()
        let context = context(.otzaria), invocation = invocation(scene, deadline: 20)
        let task = Task { try await registry.discover(scene: scene, context: context, invocation: invocation, core: core.core, host: host, clock: clock) }
        await host.waitForEntry(); clock.advance(to: 20); await host.release()
        do { _ = try await task.value; XCTFail("Late host response accepted") } catch { XCTAssertEqual((error as? UIRouteError)?.status, .cancelled) }
    }
}

private actor DiscoveryCorePorts: ActionBackendStatePort, ActionResolverPort, ActionSearchPort {
    let backend: ActionBackendID
    let ready: Bool
    let supported: Bool
    init(backend: ActionBackendID, ready: Bool, supported: Bool) { self.backend = backend; self.ready = ready; self.supported = supported }
    func snapshot() async throws -> ActionBackendSnapshot { .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil) }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues: ["system.listBackends", "catalog.resolveWork", "catalog.resolveReference", "search.query", "reader.open"].map {
            ($0, ActionCapabilityAssessment(registered: true, supported: supported, availableNow: ready))
        }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment { .init(registered: true, supported: supported, availableNow: ready) }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { throw ActionPortError.unavailable }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { throw ActionPortError.unavailable }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.unavailable }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.unavailable }
}
@MainActor private final class DiscoveryCoreUI: ActionUICommandSink {
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement { throw ActionPortError.unavailable }
}
private struct DiscoveryRuntime {
    let core: ActionExecutor
    let state: DiscoveryCorePorts
    func host(_ scene: UISceneSnapshot, _ behavior: DiscoveryHost.Behavior = .ready) -> DiscoveryHost {
        DiscoveryHost(behavior, scene: scene, state: state)
    }
}
private actor DiscoveryHost: UIDestinationEligibilityPort {
    enum Behavior: Sendable { case ready, unsupported, notReady, denied, staleRevision, staleBackend, wrongScene, blocked }
    let behavior: Behavior
    private(set) var calls = 0
    private let gate = ReviewGate()
    private let scene: UISceneSnapshot
    private let state: DiscoveryCorePorts
    init(_ behavior: Behavior, scene: UISceneSnapshot, state: DiscoveryCorePorts) {
        self.behavior = behavior; self.scene = scene; self.state = state
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try Task.checkCancellation()
        guard sceneID == scene.sceneID else { throw UIRouteError(.unavailable, "scene_unavailable") }
        return .init(sceneID: scene.sceneID, revision: scene.revision, backendSnapshot: try await state.snapshot())
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        calls += 1
        if behavior == .blocked { try await gate.wait() }
        return .init(sceneID: behavior == .wrongScene ? UIStableID(rawValue: "other-scene")! : scene.sceneID,
            sceneRevision: behavior == .staleRevision ? scene.revision + 1 : scene.revision,
            backendSnapshot: behavior == .staleBackend ? .init(backend: scene.backendSnapshot.backend, generation: 2) : scene.backendSnapshot,
            supported: behavior != .unsupported, ready: behavior != .notReady, allowed: behavior != .denied)
    }
    func waitForEntry() async { await gate.waitForEntry() }
    func release() async { await gate.release() }
}
final class DiscoveryClock: ActionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 10
    private var waits: [UUID: (UInt64, CheckedContinuation<Void, any Error>)] = [:]
    var pendingSleeps: Int { lock.withLock { waits.count } }
    func now() -> UInt64 { lock.withLock { value } }
    func advance(to value: UInt64) {
        let ready = lock.withLock {
            self.value = value
            let ready = waits.filter { $0.value.0 <= value }
            ready.keys.forEach { waits.removeValue(forKey: $0) }
            return ready.values.map { $0.1 }
        }
        ready.forEach { $0.resume() }
    }
    func sleep(until deadline: UInt64) async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                lock.withLock {
                    if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                    else if value >= deadline { continuation.resume() }
                    else { waits[id] = (deadline, continuation) }
                }
            }
        }, onCancel: { self.lock.withLock { self.waits.removeValue(forKey: id)?.1.resume(throwing: CancellationError()) } })
    }
}
