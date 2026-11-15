import Foundation
import Observation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Actual Swift Observation setter behavior and existing N/Core authorities.
/// The source model is synthetic with StudyWorkspaceStore's snapshot pattern;
/// this is portable verification, not an Apple/native Store integration test.
@MainActor final class NativeBindingSourceObservationTests: XCTestCase, @unchecked Sendable {
    func testSameTurnWorkspaceABARevokesEachActualAdmissionBeforeSetterReturns() async throws {
        let source = NativeObservedSelectionFixture(), backend = NavigationTestBackend(.otzaria)
        let authority = try NativeNavigationAuthority(), scene = UIStableID(rawValue: "owner.scene")!
        let lease = try authority.mount(sceneID: scene, foreground: true)
        let context = ActionExecutionContext(subjectID: "native.owner", origin: .deepLink, allowedBackends: [.otzaria],
            scopes: [.navigation], foregroundSceneID: scene.rawValue)
        let ports = NavigationTestPorts(), core = try ActionExecutor(state: backend, resolver: ports, search: ports, navigationAuthority: authority)
        var invalidations = 0
        let observation = NativeBindingSourceObservation(readRevision: { source.snapshot?.revision }, onInvalidation: {
            invalidations += 1
            do { try authority.invalidate(lease) } catch { authority.unmount(lease); XCTFail("Could not revoke fixture authority: \(error)") }
        })
        defer { observation.cancel() }
        let original = try authority.admit(context: context, sceneID: scene)
        let invocation = ActionPortInvocation(requestId: UUID(), snapshot: backend.value, deadlineUptimeNanoseconds: UInt64.max)
        let first = try core.prepareNavigationSynchronously(sceneID: scene.rawValue, invocation: invocation, context: context)
        try source.select("B") {
            XCTAssertThrowsError(try authority.navigationState(sceneID: scene.rawValue))
            XCTAssertThrowsError(try first.validateFreshness())
        }
        let replacement = try authority.admit(context: context, sceneID: scene)
        let second = try core.prepareNavigationSynchronously(sceneID: scene.rawValue, invocation: invocation, context: context)
        try source.select("A") {
            XCTAssertThrowsError(try authority.navigationState(sceneID: scene.rawValue))
            XCTAssertThrowsError(try second.validateFreshness())
        }
        // No await/render/onChange occurred between A→B→A or readmission.
        XCTAssertEqual(source.snapshot?.selection, "A"); XCTAssertEqual(source.snapshot?.revision, 3)
        XCTAssertEqual(invalidations, 2)
        authority.release(original); authority.release(replacement)
        XCTAssertThrowsError(try authority.navigationState(sceneID: scene.rawValue))
    }

    func testObserverRearmsOncePerMutationAndCancellationStopsOldLifetime() async {
        let source = NativeObservedSelectionFixture()
        var invalidations = 0
        let observation = NativeBindingSourceObservation(readRevision: { source.snapshot?.revision }, onInvalidation: { invalidations += 1 })
        for index in 1...64 {
            source.select("S\(index)") { XCTAssertEqual(invalidations, index) }
        }
        observation.cancel(); source.select("later") { XCTAssertEqual(invalidations, 64) }
        source.select("still later") { XCTAssertEqual(invalidations, 64) }
    }

    func testSourceTrackingDoesNotRetainCancelledOrReleasedObserver() async {
        let source = NativeObservedSelectionFixture()
        var invalidations = 0
        var observation: NativeBindingSourceObservation? = .init(readRevision: { source.snapshot?.revision }, onInvalidation: { invalidations += 1 })
        let released = ObservationWeakReference(observation)
        observation = nil
        XCTAssertNil(released.value)
        source.select("B") { XCTAssertEqual(invalidations, 0) }
    }

    func testUnavailableSnapshotStillInvalidatesAndNeverBecomesBindingPermission() async {
        let source = NativeObservedSelectionFixture()
        var invalidations = 0
        let observation = NativeBindingSourceObservation(readRevision: { source.snapshot?.revision }, onInvalidation: { invalidations += 1 })
        defer { observation.cancel() }
        source.snapshot = nil; XCTAssertEqual(invalidations, 1)
        source.snapshot = .init(revision: 3, selection: "A"); XCTAssertEqual(invalidations, 2)
    }

    func testRealObservationInvalidationDuringFinalCoreBackendAwaitRejectsEarlierNativeACK() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await PublicConsumerFixture(backend, reader: true), source = NativeObservedSelectionFixture()
            let observation = NativeBindingSourceObservation(readRevision: { source.snapshot?.revision }, onInvalidation: {
                do { try f.authority.invalidate(f.lease) }
                catch { f.authority.unmount(f.lease); XCTFail("Could not revoke fixture owner: \(error)") }
            })
            defer { observation.cancel(); f.authority.release(f.admitted) }
            guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing structural reader route") }
            f.sink.onOpen = { issued in
                let scene = try await f.directory.currentScene(sceneID: f.sceneID, context: f.context, invocation: issued.invocation)
                let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene)
                let result = await f.orchestrator.commit(command, readerCommand: issued, context: f.context)
                guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
                // Revoke from the observed owner's setter in Core's LAST shared
                // backend await, after the sink's visible receipt has returned.
                f.backend.afterSnapshot = { f.backend.afterSnapshot = { source.select("B") {} } }
                return .acknowledged(coreReceipt)
            }
            let args = try XCTUnwrap(ActionJSON.encoded(try XCTUnwrap(retained.route.content)).object)
            let result = await f.core.execute(.init(requestId: retained.route.requestId, action: "reader.open", arguments: args,
                expectedBackend: backend, expectedGeneration: f.invocation.snapshot.generation), context: f.context)
            XCTAssertNotEqual(result.status, .completed, "An earlier native ACK cannot outlive true-owner revocation")
            XCTAssertThrowsError(try f.authority.navigationState(sceneID: f.sceneID.rawValue))
            XCTAssertEqual(source.snapshot?.selection, "B")
            XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
            XCTAssertEqual(f.directory.pendingObservationCount, 0)
        }
    }

    func testProducerMappingEpochPreservesCheckpointButRevokesSelection() async throws {
        let f = try await PublicConsumerFixture(.otzaria), source = NativeMappingEpochFixture()
        var invalidations = 0
        let observation = NativeBindingSourceObservation(readRevision: { source.mappingRevision }, onInvalidation: {
            invalidations += 1
            do { try f.authority.invalidate(f.lease) }
            catch { f.authority.unmount(f.lease); XCTFail("Could not revoke fixture mapping: \(error)") }
        })
        defer { observation.cancel(); f.authority.release(f.admitted) }
        let prepared = try await f.surfacePlan()
        source.checkpoint()
        XCTAssertEqual(source.snapshotRevision, 2); XCTAssertEqual(source.mappingRevision, 1)
        let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
        guard case .acknowledged(let receipt) = result else { return XCTFail("Nonmapping checkpoint revoked the owned transition") }
        XCTAssertGreaterThan(receipt.appliedSceneRevision, receipt.basedOnSceneRevision)
        XCTAssertEqual(source.mappingRevision, 1); XCTAssertEqual(invalidations, 0)
        XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
        source.select("B")
        XCTAssertEqual(source.mappingRevision, 2); XCTAssertEqual(invalidations, 1)
        XCTAssertThrowsError(try f.authority.navigationState(sceneID: f.sceneID.rawValue))
    }

    func testBroadCheckpointRevisionIsNotAUsableMappingEpoch() async throws {
        let f = try await PublicConsumerFixture(.otzaria), source = NativeMappingEpochFixture()
        let observation = NativeBindingSourceObservation(readRevision: { source.snapshotRevision }, onInvalidation: {
            do { try f.authority.invalidate(f.lease) }
            catch { f.authority.unmount(f.lease); XCTFail("Could not revoke broad-source fixture: \(error)") }
        })
        defer { observation.cancel(); f.authority.release(f.admitted) }
        let prepared = try await f.surfacePlan(), unchangedNativeState = f.driver.actualState
        source.checkpoint()
        XCTAssertEqual(source.mappingRevision, 1); XCTAssertEqual(f.driver.actualState, unchangedNativeState)
        let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
        if case .acknowledged = result { XCTFail("An already revoked source unexpectedly completed") }
        XCTAssertEqual(f.driver.applied, 0)
        // This expected refusal is the integration constraint: a watcher of the
        // actual Store's broad revision alone would reject an ordinary checkpoint.
        // Real native activation needs a true-owner narrow mapping event/epoch.
    }
}

@MainActor @Observable private final class NativeObservedSelectionFixture {
    struct Snapshot { let revision: UInt64; let selection: String }
    var snapshot: Snapshot? = .init(revision: 1, selection: "A")
    func select(_ selection: String, afterAssignment: () throws -> Void) rethrows {
        snapshot = .init(revision: (snapshot?.revision ?? 0) + 1, selection: selection)
        try afterAssignment()
    }
}

@MainActor private final class ObservationWeakReference {
    weak var value: NativeBindingSourceObservation?
    init(_ value: NativeBindingSourceObservation?) { self.value = value }
}

/// Producer-owned classification, not a proxy's mirror. The actual native
/// Store currently lacks this narrow epoch: this fixture specifies the required
/// distinction and does not claim that native integration already implements it.
@MainActor @Observable private final class NativeMappingEpochFixture {
    private(set) var snapshotRevision: UInt64 = 1
    private(set) var mappingRevision: UInt64 = 1
    private(set) var selection = "A"
    func checkpoint() { snapshotRevision += 1 }
    func select(_ value: String) { selection = value; snapshotRevision += 1; mappingRevision += 1 }
}
