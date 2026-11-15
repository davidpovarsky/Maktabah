// Appended to unchanged immutable R consumer fixture in the isolated test target.
@MainActor final class NActualAppBindingAdapterTests: XCTestCase, @unchecked Sendable {
    private var workspaceOwners: [MaktabahNativeWorkspaceOwner] = []
    private func owner(_ workspace: StudyWorkspaceNavigationAdapter) throws -> MaktabahNativeWorkspaceOwner {
        let owner = MaktabahNativeWorkspaceOwner(); try owner.replace(with: workspace)
        workspaceOwners.append(owner); return owner
    }
    private func adapter(_ f: RConsumerFixture, witness: Bool = false,
                         read: (@MainActor () throws -> MaktabahNativePublicPresentation)? = nil) throws -> MaktabahNativePublicBindingAdapter {
        try MaktabahNativePublicBindingAdapter(sceneID: f.n.sceneID, manager: f.manager, workspace: f.adapter, workspaceOwner: owner(f.adapter),
            authority: f.n.authority, lease: f.n.lease, directory: f.n.directory, backend: f.n.backend,
            presentation: read ?? { .init(ready: true, historyRootAvailable: true,
                witnessedReader: witness ? f.n.driver.surface : nil) }, invalidated: {})
    }
    private func bind(_ f: RConsumerFixture, _ host: MaktabahNativePublicBindingAdapter) async throws -> UIPublicNavigationPlanV2 {
        let scene = try await f.n.directory.currentScene(sceneID: f.n.sceneID, context: f.n.context, invocation: f.n.invocation)
        return try await f.n.registry.bindPublicV2(f.n.intent, scene: scene, context: f.n.context, invocation: f.n.invocation,
            core: f.n.core, host: host, clock: f.n.clock)
    }
    func testUnhookedActualAdapterRefusesEvenSuccessfulStoreAndWitness() async throws {
        let f = try await RConsumerFixture(.otzaria, installed: false); defer { f.cleanup() }
        let host = try adapter(f); defer { host.cancel() }
        XCTAssertNotNil(f.store.mappingObservation(scene: f.n.sceneID.rawValue))
        do { _ = try await bind(f, host); XCTFail("Unhooked native coverage manufactured") } catch {}
        XCTAssertEqual(f.n.driver.applied, 0)
    }
    func testActualAppAdapterExactRootReceiptAndNarrowCheckpointOnAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await RConsumerFixture(backend); defer { f.cleanup() }
            let host = try adapter(f); defer { host.cancel() }
            guard case .surface(let plan) = try await bind(f, host) else { return XCTFail("No original grant") }
            let epoch = f.adapter.mappingOwnershipSource.event.epoch
            try f.store.transaction { _ in }
            XCTAssertEqual(f.adapter.mappingOwnershipSource.event.epoch, epoch)
            guard case .acknowledged(let receipt) = await f.n.orchestrator.commitPrepared(plan, admitted: f.n.admitted) else { return XCTFail("No exact receipt") }
            XCTAssertEqual(receipt.route, plan.command.route.route)
            XCTAssertNil(receipt.route.state.inspectorVisible); XCTAssertNil(receipt.route.state.sidebarVisible)
            XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, f.n.admitted.authorityRevision)
        }
    }
    func testReaderRequiresIndependentWitnessAndPreservesBothInspectorBooleans() async throws {
        for shown in [false, true] {
            let f = try await RConsumerFixture(.otzaria, reader: true); defer { f.cleanup() }
            f.n.driver.content = f.n.intent.content
            f.n.driver.actualState = .init(workspaceID: f.n.driver.actualState.workspaceID,
                profileID: f.n.driver.actualState.profileID, inspectorVisible: shown)
            let absent = try adapter(f); defer { absent.cancel() }
            XCTAssertThrowsError(try absent.observePublicNavigationBinding(f.n.intent, requestId: f.n.invocation.requestId, sceneID: f.n.sceneID))
            // A distinct future consumer, same lease/source; no cancelled-owner repair.
            let observed = try adapter(f, witness: true); defer { observed.cancel() }
            let binding = try observed.observePublicNavigationBinding(f.n.intent, requestId: f.n.invocation.requestId, sceneID: f.n.sceneID)
            XCTAssertEqual(binding.inspectorVisible, shown); XCTAssertNil(binding.sidebarVisible)
            XCTAssertEqual(binding.tab, .present(f.n.driver.targetTabID))
        }
    }
    func testRootNeverCopiesReaderInspectorOrBackgroundTarget() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f, witness: true); defer { host.cancel() }
        f.n.driver.actualState = .init(workspaceID: f.n.driver.actualState.workspaceID,
            profileID: f.n.driver.actualState.profileID, sidebarVisible: true, inspectorVisible: true)
        for destination in ["native.history", "native.settings"] {
            let intent = PublicNavigationSpecV2(destination: UIDestinationID(rawValue: destination)!,
                presentation: destination == "native.history" ? .currentTab : .sheet)
            let binding = try host.observePublicNavigationBinding(intent, requestId: UUID(), sceneID: f.n.sceneID)
            XCTAssertEqual(binding.tab, .absent); XCTAssertNil(binding.inspectorVisible); XCTAssertNil(binding.sidebarVisible)
            XCTAssertEqual(binding.workspace, .present(UIStableID(rawValue: f.groupID.uuidString)!))
        }
    }
    func testUnsupportedShapesAndWrongCurrentReaderIdentityRefuseWithoutApply() async throws {
        let f = try await RConsumerFixture(.otzaria, reader: true); defer { f.cleanup() }
        f.n.driver.content = f.n.intent.content
        let host = try adapter(f, witness: true); defer { host.cancel() }
        for presentation in [PublicNavigationSpecV2.Presentation.newTab, .inspector, .sheet] {
            let intent = PublicNavigationSpecV2(destination: f.n.intent.destination, content: f.n.intent.content, presentation: presentation)
            XCTAssertThrowsError(try host.observePublicNavigationBinding(intent, requestId: UUID(), sceneID: f.n.sceneID))
        }
        let wrong = ActionReaderDestination(sectionLocator: .init(backend: .otzaria, workKey: "other", position: .legacyLine(1)))
        XCTAssertThrowsError(try host.observePublicNavigationBinding(.init(destination: f.n.intent.destination, content: wrong), requestId: UUID(), sceneID: f.n.sceneID))
        f.n.driver.actualState = .init(workspaceID: f.n.driver.actualState.workspaceID, profileID: f.n.driver.actualState.profileID)
        XCTAssertThrowsError(try host.observePublicNavigationBinding(f.n.intent, requestId: UUID(), sceneID: f.n.sceneID), "Unknown inspector is unavailable")
        XCTAssertEqual(f.n.driver.applied, 0)
    }
    func testActualAppObserverRevokesOriginalPreparationsAcrossSameTurnABA() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f); defer { host.cancel() }
        guard case .surface(let original) = try await bind(f, host) else { return XCTFail("No original") }
        f.manager.activeTabId = f.b.id
        XCTAssertThrowsError(try original.authorizeCommit(current: original.command.scene))
        let next = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        let middle = try f.n.core.prepareNavigationSynchronously(sceneID: f.n.sceneID.rawValue, invocation: f.n.invocation, context: f.n.context)
        f.manager.activeTabId = f.a.id
        XCTAssertThrowsError(try middle.validateFreshness())
        XCTAssertThrowsError(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue))
        f.n.authority.release(next); XCTAssertEqual(f.n.driver.applied, 0)
    }
    func testActualAppObserverRefusesCoreLastAwaitAfterExactReaderACK() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await RConsumerFixture(backend, reader: true); defer { f.cleanup() }
            f.n.driver.content = f.n.intent.content
            let host = try adapter(f, witness: true); defer { host.cancel() }
            guard case .reader(let retained) = try await bind(f, host) else { return XCTFail("No reader") }
            var ack = false
            f.n.sink.onOpen = { issued in
                let scene = try await f.n.directory.currentScene(sceneID: f.n.sceneID, context: f.n.context, invocation: issued.invocation)
                let reply = await f.n.orchestrator.commit(try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene), readerCommand: issued, context: f.n.context)
                guard case .acknowledged(let receipt) = reply, let core = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
                ack = true
                f.n.backend.afterSnapshot = { f.n.backend.afterSnapshot = { f.manager.activeTabId = f.b.id } }
                return .acknowledged(core)
            }
            do { let result = try await f.n.orchestrator.executeReaderPlan(retained, originalInvocation: f.n.invocation, admitted: f.n.admitted); XCTAssertNotEqual(result.status, .completed) }
            catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_effect_uncertain") }
            XCTAssertTrue(ack); XCTAssertEqual(f.n.driver.applied, 1); XCTAssertNil(f.n.driver.command)
            XCTAssertEqual(f.n.directory.pendingObservationCount, 0)
        }
    }
    func testReadyNotificationAdmissionIsNotRevokedByActualAppObserver() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f); defer { host.cancel() }
        let owner = RReadyAdmission(f.n)
        let ready = f.adapter.mappingOwnershipSource.subscribe(owner: owner) { owner, event in
            if event.phase == .available {
                do { owner.state = try owner.n.authority.admit(context: owner.n.context, sceneID: owner.n.sceneID) }
                catch { XCTFail("Ready admission failed") }
            }
        }
        defer { ready.cancel() }
        f.manager.activeTabId = f.b.id
        let admitted = try XCTUnwrap(owner.state)
        guard case .surface(let plan) = try await bind(f, host) else { return XCTFail("No ready grant") }
        f.n.authority.release(f.n.admitted)
        guard case .acknowledged = await f.n.orchestrator.commitPrepared(plan, admitted: admitted) else { return XCTFail("Ready admission revoked") }
        f.n.authority.release(admitted)
    }
    func testCancelAndLateOldLeaseCannotTakeReplacementSceneOwner() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f)
        f.n.authority.unmount(f.n.lease)
        let lease = try f.n.authority.mount(sceneID: f.n.sceneID, foreground: true)
        let admitted = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        host.cancel(); host.cancel()
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, admitted.authorityRevision)
        XCTAssertThrowsError(try host.observePublicNavigationBinding(f.n.intent, requestId: UUID(), sceneID: f.n.sceneID))
        f.n.authority.unmount(lease)
    }
    func testBackendGetterCannotRevokeOriginalOwnerIntoSuccessfulBinding() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f); defer { host.cancel() }
        f.n.backend.onSynchronousSnapshot = { f.n.backend.onSynchronousSnapshot = nil; f.manager.activeTabId = f.b.id }
        XCTAssertThrowsError(try host.observePublicNavigationBinding(f.n.intent, requestId: UUID(), sceneID: f.n.sceneID))
        XCTAssertEqual(f.n.driver.applied, 0)
    }
    func testActualCompositionFactoryDefaultsOffAndUsesOriginalLeaseWhenExplicit() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let composition = NAppCompositionBoundary(f.n, manager: f.manager)
        let session = composition.session
        let sourceOwner = try owner(f.adapter)
        session.workspaceProjectionSource = .init(owner: sourceOwner, legacyWorkspace: f.adapter)
        XCTAssertThrowsError(try composition.configureFuturePublicBinding(session: session, manager: f.manager, workspace: f.adapter))
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, f.n.admitted.authorityRevision)
        let installed = try composition.configureFuturePublicBinding(session: session, manager: f.manager, workspace: f.adapter, workspaceOwner: sourceOwner, enabled: true)
        defer { installed.cancel() }
        XCTAssertThrowsError(try composition.configureFuturePublicBinding(session: session, manager: f.manager, workspace: f.adapter, workspaceOwner: sourceOwner, enabled: true))
        f.manager.activeTabId = f.b.id
        XCTAssertThrowsError(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue))
        XCTAssertEqual(session.invalidations, 1); XCTAssertEqual(session.revocations, 1)
        XCTAssertFalse(composition.hasContext)
        let admitted = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        composition.restoreContext(f.n.context)
        try composition.workspaceProjectionDidUpdate(session, workspace: f.adapter)
        XCTAssertEqual(session.invalidations, 1)
        XCTAssertTrue(composition.hasContext)
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, admitted.authorityRevision)
        f.n.authority.release(admitted)
    }
    func testActualSessionPresentationRequiresLiveIndependentReaderEvidence() async throws {
        let f = try await RConsumerFixture(.otzaria, reader: true); defer { f.cleanup() }
        f.n.driver.content = f.n.intent.content
        let session = NAppSessionBoundary(sceneID: f.n.sceneID)
        session.readerSurface = f.n.driver.surface
        XCTAssertNil(try session.publicBindingPresentation().witnessedReader)
        session.installEvidence(f.n.driver.surface, valid: true)
        XCTAssertEqual(try session.publicBindingPresentation().witnessedReader, f.n.driver.surface)
        session.installEvidence(f.n.driver.surface, valid: false)
        XCTAssertNil(try session.publicBindingPresentation().witnessedReader)
    }
    func testActualCurrentSceneAwaitCannotBorrowReadmittedSameContext() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let host = try adapter(f); defer { host.cancel() }
        var replacement: ActionNavigationState?
        f.n.backend.afterSnapshot = {
            f.manager.activeTabId = f.b.id
            do { replacement = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID) }
            catch { XCTFail("Explicit new operation admission failed") }
        }
        do {
            _ = try await host.currentScene(sceneID: f.n.sceneID, context: f.n.context, invocation: f.n.invocation)
            XCTFail("An await borrowed a replacement of the same context")
        } catch {}
        let admitted = try XCTUnwrap(replacement)
        f.n.authority.release(f.n.admitted)
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, admitted.authorityRevision)
        f.n.authority.release(admitted)
    }
    func testActualCompositionRejectsWorkspaceOwnerSubstitutionBeforeCoalescedCallback() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let composition = NAppCompositionBoundary(f.n, manager: f.manager), sourceOwner = try owner(f.adapter)
        NAppCompositionBoundary.shared = composition
        let host = NActualRoutingHostPath(manager: f.manager, sceneID: f.n.sceneID.rawValue, owner: sourceOwner)
        host.runMount()
        let session = try XCTUnwrap(host.session)
        let installed = try composition.configureFuturePublicBinding(session: session, manager: f.manager, workspace: f.adapter, workspaceOwner: sourceOwner, enabled: true)
        defer { installed.cancel() }
        let other = StudyWorkspaceNavigationAdapter(sceneID: f.n.sceneID.rawValue, store: f.store)
        other.fixtureConnect(f.manager, groupID: f.groupID)
        XCTAssertEqual(other.selection, f.adapter.selection, "Actual equal selection must not require onChange")
        try sourceOwner.replace(with: other)
        XCTAssertTrue(try session.readMountedWorkspace() === other, "Exact mount projection rereads the actual canonical owner before refresh")
        XCTAssertThrowsError(try installed.observePublicNavigationBinding(f.n.intent, requestId: UUID(), sceneID: f.n.sceneID), "Old adapter must not observe a substituted current app workspace")
        try composition.workspaceProjectionDidUpdate(session, workspace: other)
        XCTAssertThrowsError(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue))
        XCTAssertEqual(f.n.driver.applied, 0)
    }
    func testActualHostWithoutAuthoritativeProducerRefusesFutureBinding() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let composition = NAppCompositionBoundary(f.n, manager: f.manager)
        NAppCompositionBoundary.shared = composition
        let host = NActualRoutingHostPath(manager: f.manager, sceneID: f.n.sceneID.rawValue, owner: nil, legacy: f.adapter)
        host.runMount()
        XCTAssertThrowsError(try composition.configureFuturePublicBinding(session: try XCTUnwrap(host.session), manager: f.manager,
            workspace: f.adapter, enabled: true))
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, f.n.admitted.authorityRevision)
    }
    func testActualMountAndRefreshClosuresDoNotRetainReplacedWorkspace() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        var transient: StudyWorkspaceNavigationAdapter? = .init(sceneID: f.n.sceneID.rawValue, store: f.store)
        transient!.fixtureConnect(f.manager, groupID: f.groupID)
        let weakOld = NWorkspaceWeakProbe(transient!)
        let sourceOwner = try owner(transient!)
        let composition = NAppCompositionBoundary(f.n, manager: f.manager)
        NAppCompositionBoundary.shared = composition
        let host = NActualRoutingHostPath(manager: f.manager, sceneID: f.n.sceneID.rawValue, owner: sourceOwner)
        host.runMount(); host.runRefresh()
        transient = nil
        try sourceOwner.replace(with: f.adapter)
        XCTAssertNil(weakOld.value, "Neither exact production closure may retain the old workspace")
        XCTAssertTrue(try XCTUnwrap(host.session).readMountedWorkspace() === f.adapter)
    }
    func testExactMountPathReadsEqualSelectionReplacementWithoutAnyRefresh() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        var transient: StudyWorkspaceNavigationAdapter? = .init(sceneID: f.n.sceneID.rawValue, store: f.store)
        transient!.fixtureConnect(f.manager, groupID: f.groupID)
        XCTAssertEqual(transient!.selection, f.adapter.selection)
        let weakOld = NWorkspaceWeakProbe(transient!), sourceOwner = try owner(transient!)
        let composition = NAppCompositionBoundary(f.n, manager: f.manager)
        NAppCompositionBoundary.shared = composition
        let host = NActualRoutingHostPath(manager: f.manager, sceneID: f.n.sceneID.rawValue, owner: sourceOwner)
        host.runMount()
        transient = nil
        try sourceOwner.replace(with: f.adapter)
        // No projection shell assignment, SwiftUI onChange, refresh, Task or await.
        XCTAssertTrue(try XCTUnwrap(host.session).readMountedWorkspace() === f.adapter)
        XCTAssertNil(weakOld.value)
    }
    func testLegacyRefreshStillReadsNewEnvironmentButRemainsPubliclyUnsupported() async throws {
        let f = try await RConsumerFixture(.otzaria); defer { f.cleanup() }
        let composition = NAppCompositionBoundary(f.n, manager: f.manager)
        NAppCompositionBoundary.shared = composition
        let host = NActualRoutingHostPath(manager: f.manager, sceneID: f.n.sceneID.rawValue, owner: nil, legacy: f.adapter)
        host.runMount()
        let other = StudyWorkspaceNavigationAdapter(sceneID: f.n.sceneID.rawValue, store: f.store)
        other.fixtureConnect(f.manager, groupID: f.groupID)
        host.setLegacyEnvironment(other); host.runRefresh()
        XCTAssertTrue(try XCTUnwrap(host.session).readMountedWorkspace() === other)
        XCTAssertThrowsError(try composition.configureFuturePublicBinding(session: try XCTUnwrap(host.session), manager: f.manager,
            workspace: other, enabled: true))
    }
}
@MainActor private final class NWorkspaceWeakProbe {
    weak var value: StudyWorkspaceNavigationAdapter?
    init(_ value: StudyWorkspaceNavigationAdapter) { self.value = value }
}
