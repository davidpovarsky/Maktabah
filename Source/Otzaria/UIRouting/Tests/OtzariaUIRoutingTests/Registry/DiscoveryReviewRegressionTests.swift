import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

/// Focused DISC-01/02 reproduction against the real Core actor and controlled
/// synthetic authorities. No real UI/provider or uncooperative-return claim.
final class DiscoveryReviewRegressionTests: XCTestCase, @unchecked Sendable {
    private func fixture(_ backend: ActionBackendID = .otzaria, blockHost: Bool = false, blockCore: Bool = false,
                         missingEpoch: Bool = false, observationCall: Int? = nil, deadline: UInt64 = UInt64.max) throws -> ReviewFixture {
        let state = ReviewCoreState(backend: backend), hostGate = ReviewGate(), coreGate = ReviewGate()
        let snapshot = ActionBackendSnapshot(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded && !missingEpoch ? 7 : nil)
        let scene = UISceneSnapshot(sceneID: UIStableID(rawValue: "review-scene")!, revision: 5, backendSnapshot: snapshot)
        let host = ReviewHost(state: state, scene: scene, gate: blockHost ? hostGate : nil, observationGate: observationCall == nil ? nil : hostGate, blockedObservation: observationCall)
        let ports = ReviewCorePorts(state: state, gate: blockCore ? coreGate : nil)
        let core = try ActionExecutor(state: ports, resolver: ports, search: ports)
        let descriptor = UIDestinationDescriptor(id: UIDestinationID(rawValue: "review.search")!, title: "Synthetic review host", implementation: .implemented,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], requiredCoreActions: ["search.query"], riskTier: 1)
        return ReviewFixture(registry: try UIDestinationRegistry(descriptors: [descriptor]), core: core, host: host, state: state,
            scene: scene, invocation: .init(requestId: UUID(), snapshot: snapshot, deadlineUptimeNanoseconds: deadline),
            context: .init(subjectID: "discovery-review", origin: .inApp, allowedBackends: [backend], contentRights: [backend],
                scopes: [.discovery, .contentRead], foregroundSceneID: scene.sceneID.rawValue), hostGate: hostGate, coreGate: coreGate)
    }
    private func assertStatus(_ task: Task<[UIDestinationDescriptor], any Error>, _ status: ActionStatus,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do { let result = try await task.value; XCTFail("Unexpected eligible metadata: \(result.map(\.id.rawValue))", file: file, line: line) }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, status, file: file, line: line) }
    }
    private func safetyRelease(_ gate: ReviewGate) -> Task<Void, Never> {
        Task {
            do { try await Task.sleep(nanoseconds: 2_000_000_000); try Task.checkCancellation(); await gate.release(safety: true) }
            catch {}
        }
    }
    func testGenerationDriftWithEchoedHostAssessmentIsRejected() async throws {
        let before = try fixture()
        await before.state.bumpGeneration()
        await assertStatus(Task { try await before.discover() }, .staleState)

        let during = try fixture(blockHost: true), safety = safetyRelease(during.hostGate)
        let task = Task { try await during.discover() }
        await during.hostGate.waitForEntry()
        await during.state.bumpGeneration()
        await during.hostGate.release()
        await assertStatus(task, .staleState)
        safety.cancel(); await safety.value
    }
    func testEmbeddedEpochDriftWithEchoedHostAssessmentIsRejected() async throws {
        let before = try fixture(.sefariaEmbedded)
        await before.state.bumpEpoch()
        await assertStatus(Task { try await before.discover() }, .staleState)

        let during = try fixture(.sefariaEmbedded, blockHost: true), safety = safetyRelease(during.hostGate)
        let task = Task { try await during.discover() }
        await during.hostGate.waitForEntry()
        await during.state.bumpEpoch()
        await during.hostGate.release()
        await assertStatus(task, .staleState)
        safety.cancel(); await safety.value
    }
    func testTwoIndependentScenesUseExactSelectorAndRejectMatchingOtherScene() async throws {
        let fixture = try fixture()
        // Both scenes share revision and backend snapshot; only ID distinguishes them.
        let result = try await fixture.discover()
        XCTAssertEqual(result.map(\.id.rawValue), ["review.search"])
        let selected = await fixture.host.selectedScenes()
        XCTAssertEqual(selected, Array(repeating: fixture.scene.sceneID, count: 4))
        await fixture.host.selectWrongScene()
        await assertStatus(Task { try await fixture.discover() }, .staleState)
    }
    func testMissingExactSceneNeverFallsBackToOtherScene() async throws {
        let fixture = try fixture()
        await fixture.host.removeSelectedScene()
        await assertStatus(Task { try await fixture.discover() }, .unavailable)
    }
    func testSceneRevisionChangesBeforeAndDuringAssessmentAreRejected() async throws {
        let before = try fixture()
        await before.host.bumpSceneRevision()
        await assertStatus(Task { try await before.discover() }, .staleState)
        let during = try fixture(blockHost: true), safety = safetyRelease(during.hostGate)
        let task = Task { try await during.discover() }
        await during.hostGate.waitForEntry()
        await during.host.bumpSceneRevision()
        await during.hostGate.release()
        await assertStatus(task, .staleState)
        safety.cancel(); await safety.value
    }
    func testCoreGenerationDriftDuringAdvertisementIsRejected() async throws {
        let fixture = try fixture(blockCore: true), safety = safetyRelease(fixture.coreGate)
        let task = Task { try await fixture.discover() }
        await fixture.coreGate.waitForEntry()
        await fixture.state.bumpGeneration()
        await fixture.coreGate.release()
        await assertStatus(task, .staleState)
        safety.cancel(); await safety.value
    }
    func testBackendSwitchAndLostEpochDuringAssessmentAreRejected() async throws {
        for backend in [ActionBackendID.otzaria, .sefariaEmbedded] {
            let fixture = try fixture(backend, blockHost: true), safety = safetyRelease(fixture.hostGate)
            let task = Task { try await fixture.discover() }
            await fixture.hostGate.waitForEntry()
            if backend == .sefariaEmbedded { await fixture.state.loseEpoch() }
            else { await fixture.state.switchBackend() }
            await fixture.hostGate.release()
            await assertStatus(task, backend == .sefariaEmbedded ? .unavailable : .staleState)
            safety.cancel(); await safety.value
        }
    }
    func testDeadlineCleansInitialAndFinalCurrentSceneWaits() async throws {
        for call in [1, 4] {
            let fixture = try fixture(observationCall: call, deadline: SystemActionClock().now() + 500_000_000)
            let safety = safetyRelease(fixture.hostGate)
            let task = Task { try await fixture.discover() }
            await fixture.hostGate.waitForEntry()
            await assertStatus(task, .cancelled)
            let observation = await fixture.hostGate.observation()
            XCTAssertGreaterThan(observation.entries, 0)
            XCTAssertFalse(observation.safetyReleased)
            XCTAssertEqual(observation.pending, 0)
            safety.cancel(); await safety.value
        }
    }
    func testExternalCancellationCleansInitialAndFinalCurrentSceneWaits() async throws {
        for call in [1, 4] {
            let fixture = try fixture(observationCall: call), safety = safetyRelease(fixture.hostGate)
            let task = Task { try await fixture.discover() }
            await fixture.hostGate.waitForEntry(); task.cancel()
            do { _ = try await task.value; XCTFail("Cancelled observation returned metadata") }
            catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
            let observation = await fixture.hostGate.observation()
            XCTAssertFalse(observation.safetyReleased)
            XCTAssertEqual(observation.pending, 0)
            safety.cancel(); await safety.value
        }
    }
    func testMissingEmbeddedEpochIsUnavailableBeforeDiscovery() async throws {
        let fixture = try fixture(.sefariaEmbedded, missingEpoch: true)
        await assertStatus(Task { try await fixture.discover() }, .unavailable)
    }
    func testDiscoveryDeadlineCancelsCooperativeHostBeforeSafetyRelease() async throws {
        let deadline = SystemActionClock().now() + 500_000_000
        let fixture = try fixture(blockHost: true, deadline: deadline), safety = safetyRelease(fixture.hostGate)
        let task = Task { try await fixture.discover() }
        await fixture.hostGate.waitForEntry()
        await assertStatus(task, .cancelled)
        let observation = await fixture.hostGate.observation()
        XCTAssertGreaterThan(observation.entries, 0)
        XCTAssertFalse(observation.safetyReleased, "Discovery waited for safety/manual release instead of its deadline")
        XCTAssertEqual(observation.pending, 0)
        safety.cancel(); await safety.value
    }
    func testCallerDeadlineAlsoBoundsCoreAdvertisement() async throws {
        let deadline = SystemActionClock().now() + 500_000_000
        let fixture = try fixture(blockCore: true, deadline: deadline), safety = safetyRelease(fixture.coreGate)
        let task = Task { try await fixture.discover() }
        await fixture.coreGate.waitForEntry()
        await assertStatus(task, .cancelled)
        let observation = await fixture.coreGate.observation()
        XCTAssertGreaterThan(observation.entries, 0)
        XCTAssertFalse(observation.safetyReleased, "Core advertisement outlived the caller deadline until safety release")
        XCTAssertEqual(observation.pending, 0)
        safety.cancel(); await safety.value
    }
    func testExternalCancellationCleansUpCooperativeHostBeforeSafetyRelease() async throws {
        let fixture = try fixture(blockHost: true), safety = safetyRelease(fixture.hostGate)
        let task = Task { try await fixture.discover() }
        await fixture.hostGate.waitForEntry(); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled discovery returned metadata") }
        catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
        let observation = await fixture.hostGate.observation()
        XCTAssertFalse(observation.safetyReleased)
        XCTAssertEqual(observation.pending, 0)
        safety.cancel(); await safety.value
    }
}

private struct ReviewFixture: Sendable {
    let registry: UIDestinationRegistry
    let core: ActionExecutor
    let host: ReviewHost
    let state: ReviewCoreState
    let scene: UISceneSnapshot
    let invocation: ActionPortInvocation
    let context: ActionExecutionContext
    let hostGate: ReviewGate
    let coreGate: ReviewGate
    func discover() async throws -> [UIDestinationDescriptor] {
        try await registry.discover(scene: scene, context: context, invocation: invocation, core: core, host: host)
    }
}
private actor ReviewCoreState {
    private var snapshot: ActionBackendSnapshot
    init(backend: ActionBackendID) { snapshot = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil) }
    func current() -> ActionBackendSnapshot { snapshot }
    func bumpGeneration() { snapshot = .init(backend: snapshot.backend, generation: snapshot.generation + 1, rpcEpoch: snapshot.rpcEpoch) }
    func switchBackend() { snapshot = .init(backend: .sefaria, generation: snapshot.generation) }
    func loseEpoch() { snapshot = .init(backend: snapshot.backend, generation: snapshot.generation) }
    func bumpEpoch() { snapshot = .init(backend: snapshot.backend, generation: snapshot.generation, rpcEpoch: (snapshot.rpcEpoch ?? 0) + 1) }
}
private actor ReviewCorePorts: ActionBackendStatePort, ActionResolverPort, ActionSearchPort {
    let state: ReviewCoreState
    let gate: ReviewGate?
    init(state: ReviewCoreState, gate: ReviewGate?) { self.state = state; self.gate = gate }
    func snapshot() async throws -> ActionBackendSnapshot { await state.current() }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        if let gate { try await gate.wait() }
        return .init(id: backend, operations: ["system.listBackends": .init(registered: true, supported: true, availableNow: true),
            "search.query": .init(registered: true, supported: true, availableNow: true)])
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment { .init(registered: true, supported: true, availableNow: true) }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { throw ActionPortError.unavailable }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { throw ActionPortError.unavailable }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { throw ActionPortError.unavailable }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { throw ActionPortError.unavailable }
}
private actor ReviewHost: UIDestinationEligibilityPort {
    let state: ReviewCoreState
    let sceneID: UIStableID
    let otherSceneID = UIStableID(rawValue: "other-native-scene")!
    private var scenes: [UIStableID: UISceneSnapshot]
    private var wrongScene = false
    private var selections: [UIStableID] = []
    let gate: ReviewGate?
    let observationGate: ReviewGate?
    let blockedObservation: Int?
    init(state: ReviewCoreState, scene: UISceneSnapshot, gate: ReviewGate?, observationGate: ReviewGate?, blockedObservation: Int?) {
        self.state = state; self.sceneID = scene.sceneID; self.gate = gate
        self.observationGate = observationGate; self.blockedObservation = blockedObservation
        scenes = [scene.sceneID: scene, otherSceneID: .init(sceneID: otherSceneID, revision: scene.revision, backendSnapshot: scene.backendSnapshot)]
    }
    func selectedScenes() -> [UIStableID] { selections }
    func selectWrongScene() { wrongScene = true }
    func removeSelectedScene() { scenes.removeValue(forKey: sceneID) }
    func bumpSceneRevision() {
        guard let scene = scenes[sceneID] else { return }
        scenes[sceneID] = .init(sceneID: sceneID, revision: scene.revision + 1, backendSnapshot: scene.backendSnapshot)
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try Task.checkCancellation()
        selections.append(sceneID)
        if selections.count == blockedObservation, let observationGate { try await observationGate.wait() }
        guard let scene = scenes[wrongScene ? otherSceneID : sceneID] else { throw UIRouteError(.unavailable, "scene_unavailable") }
        // Observe the SAME authority injected into the real Core actor, independently
        // of the requested snapshot and the deliberately echoed assessment.
        return .init(sceneID: scene.sceneID, revision: scene.revision, backendSnapshot: await state.current())
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        if let gate { try await gate.wait() }
        return .init(sceneID: scene.sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot, supported: true, ready: true, allowed: true)
    }
}
actor ReviewGate {
    private var entries = 0
    private var safetyReleased = false
    private var released = false
    private var observer: CheckedContinuation<Void, Never>?
    private var pending: [UUID: CheckedContinuation<Void, any Error>] = [:]
    func wait() async throws {
        let id = UUID()
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                entries += 1; observer?.resume(); observer = nil
                if released { continuation.resume() } else { pending[id] = continuation }
            }
        }, onCancel: { Task { await self.cancel(id) } })
    }
    private func cancel(_ id: UUID) { pending.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
    func waitForEntry() async { if entries == 0 && !released { await withCheckedContinuation { observer = $0 } } }
    func release(safety: Bool = false) {
        safetyReleased = safetyReleased || safety; released = true
        observer?.resume(); observer = nil
        let work = pending; pending = [:]; work.values.forEach { $0.resume() }
    }
    func observation() -> (entries: Int, safetyReleased: Bool, pending: Int) { (entries, safetyReleased, pending.count) }
}
