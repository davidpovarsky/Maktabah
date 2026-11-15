import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

@MainActor
final class NativeSceneDirectoryTests: XCTestCase, @unchecked Sendable {
    private let id = UIStableID(rawValue: "native-scene.A")!
    private var context: ActionExecutionContext {
        .init(subjectID: "native-user", origin: .inApp, allowedBackends: Set(ActionBackendID.allCases),
              scopes: [.navigation, .discovery], foregroundSceneID: id.rawValue)
    }
    private func invocation(_ state: HostTestAuthority, deadline: UInt64 = UInt64.max) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: state.value, deadlineUptimeNanoseconds: deadline)
    }
    private func mounted(_ host: NativeSceneDirectory, id: UIStableID? = nil) throws -> NativeSceneDirectory.Lease {
        try host.mount(sceneID: id ?? self.id, observe: { .init(isForeground: true, isMounted: true, visibleRoute: nil) },
                       validateLifetime: { guard $0.subjectID == "native-user" else { throw UIRouteError(.failed, "scene_access_denied") } })
    }
    func testMissingSceneNeverFallsBackToAnotherWindow() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state)
        _ = try mounted(host, id: UIStableID(rawValue: "native-scene.B")!)
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("fallback") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "scene_missing") }
    }
    func testTwoScenesAndStableReadOnlyRevisions() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state)
        _ = try mounted(host); let other = UIStableID(rawValue: "native-scene.B")!; _ = try mounted(host, id: other)
        let a = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        let b = try await host.currentScene(sceneID: other, context: context, invocation: invocation(state))
        let again = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        XCTAssertNotEqual(a.sceneID, b.sceneID); XCTAssertNotEqual(a.revision, b.revision); XCTAssertEqual(a, again)
    }
    func testDuplicateMountAndFiniteSceneAdmission() async throws {
        let host = try NativeSceneDirectory(authority: HostTestAuthority(), sceneCapacity: 1)
        _ = try mounted(host)
        XCTAssertThrowsError(try mounted(host)); XCTAssertThrowsError(try mounted(host, id: UIStableID(rawValue: "native-scene.B")!))
        XCTAssertEqual(host.mountedSceneCount, 1)
    }
    func testOldLeaseCannotRemoveRemountedSceneOrReuseRevision() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state)
        let old = try mounted(host)
        let a = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        host.unmount(old); let new = try mounted(host); host.unmount(old)
        let b = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        XCTAssertNotEqual(old, new); XCTAssertGreaterThan(b.revision, a.revision)
    }
    func testNativeStateChangeAdvancesRevision() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), observation = HostTestObservation()
        _ = try host.mount(sceneID: id, observe: { observation.value }, validateLifetime: { _ in })
        let a = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        observation.value = .init(isForeground: false, isMounted: true, visibleRoute: nil)
        let b = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        XCTAssertGreaterThan(b.revision, a.revision)
    }
    func testAuthorityIsReadForEveryObservationAcrossThreeBackends() async throws {
        for backend in ActionBackendID.allCases {
            let state = HostTestAuthority(backend), host = try NativeSceneDirectory(authority: state)
            _ = try mounted(host); let call = invocation(state)
            _ = try await host.currentScene(sceneID: id, context: context, invocation: call)
            state.value = .init(backend: backend, generation: 2, rpcEpoch: backend == .sefariaEmbedded ? 8 : nil)
            do { _ = try await host.currentScene(sceneID: id, context: context, invocation: call); XCTFail("stale authority") }
            catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
            XCTAssertEqual(state.reads, 2)
        }
    }
    func testEmbeddedWithoutEpochFailsUnavailable() async throws {
        let state = HostTestAuthority(.sefariaEmbedded), host = try NativeSceneDirectory(authority: state)
        state.value = .init(backend: .sefariaEmbedded, generation: 1); _ = try mounted(host)
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("missing epoch") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .unavailable) }
    }
    func testRevocationAfterAuthorityAwaitFails() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), observation = HostTestObservation()
        _ = try host.mount(sceneID: id, observe: { observation.value }, validateLifetime: { _ in
            guard observation.allowed else { throw UIRouteError(.failed, "scene_access_revoked") }
        })
        state.onRead = { observation.allowed = false }
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("revoked") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "scene_access_revoked") }
        XCTAssertEqual(host.pendingObservationCount, 0)
    }
    func testSceneCloseDuringAuthorityAwaitFailsEvenAfterSameIDRemount() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), old = try mounted(host)
        state.onRead = { host.unmount(old); _ = try self.mounted(host) }
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("ABA") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "scene_lifetime_changed") }
    }
    func testNativeChangeDuringAuthorityAwaitFails() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), observation = HostTestObservation()
        _ = try host.mount(sceneID: id, observe: { observation.value }, validateLifetime: { _ in })
        state.onRead = { observation.value = .init(isForeground: false, isMounted: true, visibleRoute: nil) }
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("changed scene") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "scene_changed_during_observation") }
    }
    func testNativeABANotificationDuringAwaitIsStale() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), lease = try mounted(host)
        state.onRead = { try host.invalidate(lease) }
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("ABA") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .staleState) }
    }
    func testCurrentTargetNeedsTrustedExactSceneAndNeverChoosesFirst() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state); _ = try mounted(host)
        let missing = ActionExecutionContext(subjectID: "native-user", origin: .inApp, allowedBackends: [.otzaria], scopes: [.navigation])
        do { _ = try await host.snapshot(target: .init(), context: missing); XCTFail("guessed scene") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .requiresForeground) }
        let current = try await host.snapshot(target: .init(), context: context)
        XCTAssertEqual(current.sceneID, id)
    }
    func testNotMountedIsQueuedAndInventoryNeverBecomesSupported() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state), observation = HostTestObservation()
        observation.value = .init(isForeground: true, isMounted: false, visibleRoute: nil)
        _ = try host.mount(sceneID: id, observe: { observation.value }, validateLifetime: { _ in })
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state)); XCTFail("not mounted") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .uiQueued) }
        observation.value = .init(isForeground: true, isMounted: true, visibleRoute: nil)
        let scene = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state))
        let descriptor = try UIDestinationRegistry.fixtures().descriptors[0]
        let result = try await host.assess(descriptor, scene: scene, context: context, invocation: invocation(state))
        XCTAssertFalse(result.supported); XCTAssertFalse(result.allowed); XCTAssertFalse(result.ready)
    }
    func testExpiredDeadlineDoesNotStartAuthorityRead() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state); _ = try mounted(host)
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state, deadline: 0)); XCTFail("expired") }
        catch { XCTAssertEqual((error as? UIRouteError)?.status, .cancelled) }
        XCTAssertEqual(state.reads, 0); XCTAssertEqual(host.pendingObservationCount, 0)
    }
    func testDeadlineCancelsCooperativeAuthorityAndReleasesAdmission() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state); _ = try mounted(host)
        state.wait = true
        let deadline = SystemActionClock().now() + 30_000_000
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation(state, deadline: deadline)); XCTFail("timeout") }
        catch { XCTAssertTrue(error is CancellationError || (error as? UIRouteError)?.status == .cancelled) }
        XCTAssertEqual(host.pendingObservationCount, 0); XCTAssertEqual(state.pendingReads, 0)
    }
    func testInFlightAdmissionIsBoundedAndCancellationReleasesIt() async throws {
        let state = HostTestAuthority(), host = try NativeSceneDirectory(authority: state, observationCapacity: 1)
        _ = try mounted(host); state.wait = true
        let (stream, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        state.onRead = { signal.yield(()) }
        let context = context, id = id, invocation = invocation(state)
        let task = Task { try await host.currentScene(sceneID: id, context: context, invocation: invocation) }
        var iterator = stream.makeAsyncIterator(); _ = await iterator.next()
        do { _ = try await host.currentScene(sceneID: id, context: context, invocation: invocation); XCTFail("unbounded admission") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "scene_observer_busy") }
        task.cancel()
        do { _ = try await task.value; XCTFail("cancelled observer") } catch {}
        signal.finish()
        XCTAssertEqual(host.pendingObservationCount, 0); XCTAssertEqual(state.pendingReads, 0)
    }
}

@MainActor private final class HostTestObservation {
    var value = NativeSceneDirectory.Observation(isForeground: true, isMounted: true, visibleRoute: nil)
    var allowed = true
}
@MainActor private final class HostTestAuthority: ActionBackendStatePort {
    var value: ActionBackendSnapshot
    var reads = 0, pendingReads = 0
    var wait = false
    var onRead: (@MainActor () throws -> Void)?
    init(_ backend: ActionBackendID = .otzaria) { value = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil) }
    func snapshot() async throws -> ActionBackendSnapshot {
        reads += 1; pendingReads += 1; defer { pendingReads -= 1 }
        try onRead?()
        if wait { try await Task.sleep(nanoseconds: 10_000_000_000) }
        return value
    }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { .init(id: backend, operations: [:]) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        .init(registered: false, supported: false, availableNow: false)
    }
}
