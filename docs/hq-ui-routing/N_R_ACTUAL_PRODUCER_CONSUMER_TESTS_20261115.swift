import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Exact R Store/policy/models/persistence and actual adapter producer block.
/// UIKit manager/setters are the explicitly proposed-hook boundary double.
@MainActor final class NRActualProducerConsumerTests: XCTestCase, @unchecked Sendable {
    func testActualStoreCheckpointAndPublicationABAUseOriginalAuthority() async throws {
        let f = try await RConsumerFixture(.otzaria)
        defer { f.cleanup() }
        let source = f.store.mappingSource(scene: f.n.sceneID.rawValue)
        let initial = try XCTUnwrap(f.store.mappingObservation(scene: f.n.sceneID.rawValue))
        XCTAssertEqual(initial.coverage, .workspaceStoreOnly)
        let consumer = RAuthorityConsumer(f.n)
        var fences = 0
        let subscription = source.subscribeInvalidation(owner: consumer) { owner, event in
            owner.revoke()
            XCTAssertNil(f.store.mappingObservation(scene: f.n.sceneID.rawValue))
            XCTAssertNil(event.epoch); fences += 1
        }
        defer { subscription.cancel() }
        let original = try f.n.core.prepareNavigationSynchronously(sceneID: f.n.sceneID.rawValue,
            invocation: f.n.invocation, context: f.n.context)
        let broad = try XCTUnwrap(f.store.snapshot).revision
        try f.store.transaction { _ in }
        try original.validateFreshness()
        XCTAssertGreaterThan(try XCTUnwrap(f.store.snapshot).revision, broad)
        XCTAssertEqual(source.event.epoch, initial.epoch)
        try f.store.saveTabs(f.documents, activeID: f.b.id, groupID: f.groupID)
        XCTAssertThrowsError(try original.validateFreshness())
        let replacement = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        let second = try f.n.core.prepareNavigationSynchronously(sceneID: f.n.sceneID.rawValue,
            invocation: f.n.invocation, context: f.n.context)
        try f.store.saveTabs(f.documents, activeID: f.a.id, groupID: f.groupID)
        XCTAssertThrowsError(try second.validateFreshness())
        XCTAssertEqual(fences, 2)
        XCTAssertEqual(f.store.mappingObservation(scene: f.n.sceneID.rawValue)?.projection.activeTabID, f.a.id)
        XCTAssertNotEqual(source.event.epoch, initial.epoch)
        f.n.authority.release(replacement)
        XCTAssertEqual(f.n.driver.applied, 0)
    }

    func testUninstalledNativeHookCannotBindFromStoreOnlySuccess() async throws {
        let f = try await RConsumerFixture(.otzaria, installed: false)
        defer { f.cleanup() }
        XCTAssertNotNil(f.store.mappingObservation(scene: f.n.sceneID.rawValue))
        XCTAssertNil(f.adapter.mappingOwnershipObservation())
        XCTAssertNil(f.adapter.mappingOwnershipSource.mappingRevision)
        do { _ = try await f.bind(); XCTFail("Store-only data authorized a native binding") }
        catch { XCTAssertEqual(f.n.driver.applied, 0) }
    }

    func testActualAdapterProjectionBindsP050AndStrictFullSurfaceReceiptOnAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await RConsumerFixture(backend)
            defer { f.cleanup() }
            let admitted = f.n.admitted
            guard case .surface(let prepared) = try await f.bind() else { return XCTFail("Missing original preparation") }
            let before = try XCTUnwrap(f.adapter.mappingOwnershipObservation())
            XCTAssertEqual(before.coverage, .liveNativeSetters)
            let result = await f.n.orchestrator.commitPrepared(prepared, admitted: admitted)
            guard case .acknowledged(let receipt) = result else { return XCTFail("No exact full receipt: \(result)") }
            XCTAssertEqual(receipt.route, prepared.command.route.route)
            XCTAssertEqual(receipt.route.state.workspaceID?.rawValue, before.projection.groupID.uuidString)
            XCTAssertEqual(receipt.route.state.profileID?.rawValue, before.projection.profileID.uuidString)
            XCTAssertEqual(f.n.driver.applied, 1)
            XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, admitted.authorityRevision)
            XCTAssertEqual(f.adapter.mappingOwnershipObservation()?.epoch, before.epoch)
        }
    }

    func testActualProducerRevocationInCoreFinalAwaitRefusesEarlierExactNativeACK() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await RConsumerFixture(backend, reader: true)
            defer { f.cleanup() }
            let consumer = RAuthorityConsumer(f.n)
            let subscription = f.adapter.mappingOwnershipSource.subscribeInvalidation(owner: consumer) { owner, _ in owner.revoke() }
            defer { subscription.cancel() }
            guard case .reader(let retained) = try await f.bind() else { return XCTFail("Missing original reader route") }
            var nativeACK = false
            f.n.sink.onOpen = { issued in
                let scene = try await f.n.directory.currentScene(sceneID: f.n.sceneID, context: f.n.context, invocation: issued.invocation)
                let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene)
                let reply = await f.n.orchestrator.commit(command, readerCommand: issued, context: f.n.context)
                guard case .acknowledged(let receipt) = reply, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
                nativeACK = true
                f.n.backend.afterSnapshot = { f.n.backend.afterSnapshot = { f.manager.activeTabId = f.b.id } }
                return .acknowledged(coreReceipt)
            }
            do {
                let result = try await f.n.orchestrator.executeReaderPlan(retained, originalInvocation: f.n.invocation, admitted: f.n.admitted)
                XCTAssertNotEqual(result.status, .completed)
            } catch { XCTAssertEqual((error as? UIRouteError)?.code, "native_effect_uncertain") }
            XCTAssertTrue(nativeACK)
            XCTAssertEqual(consumer.revocations, 1)
            XCTAssertEqual(f.n.driver.applied, 1); XCTAssertEqual(f.n.sink.calls, 1)
            XCTAssertNil(f.n.driver.command); XCTAssertEqual(f.n.directory.pendingObservationCount, 0)
            XCTAssertThrowsError(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue))
        }
    }

    func testActualNativeSameTurnABAAndPostpublicationReadmissionPreserveReplacementCleanup() async throws {
        let f = try await RConsumerFixture(.otzaria)
        defer { f.cleanup() }
        let consumer = RAuthorityConsumer(f.n)
        let source = f.adapter.mappingOwnershipSource
        var fenced = 0
        let subscription = source.subscribeInvalidation(owner: consumer) { owner, _ in
            owner.revoke(); fenced += 1
            XCTAssertNil(f.adapter.mappingOwnershipObservation())
            do {
                _ = try f.host.observePublicNavigationBinding(f.n.intent, requestId: f.n.invocation.requestId, sceneID: f.n.sceneID)
                XCTFail("Publication fence allowed a binding")
            } catch {}
        }
        defer { subscription.cancel() }
        let first = try await f.bind()
        f.manager.activeTabId = f.b.id
        guard case .surface(let old) = first else { return XCTFail("Missing original") }
        XCTAssertThrowsError(try old.authorizeCommit(current: old.command.scene))
        let replacement = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        let second = try await f.bind()
        f.manager.activeTabId = f.a.id
        guard case .surface(let between) = second else { return XCTFail("Missing intervening original") }
        XCTAssertThrowsError(try between.authorizeCommit(current: between.command.scene))
        XCTAssertEqual(fenced, 2)
        let newest = try f.n.authority.admit(context: f.n.context, sceneID: f.n.sceneID)
        f.n.authority.release(f.n.admitted); f.n.authority.release(replacement)
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, newest.authorityRevision)
        XCTAssertEqual(source.event.phase, .available)
        // Ready notifications are filtered: a new admitted operation stays live.
        let final = try await f.bind()
        guard case .surface(let prepared) = final else { return XCTFail("Missing newest") }
        guard case .acknowledged = await f.n.orchestrator.commitPrepared(prepared, admitted: newest) else { return XCTFail("Newest admission was revoked by final ready publication") }
        f.n.authority.release(newest)
    }

    func testFixedSourceAndExactOwnerRejectReplacementAndSameUUIDReaderABA() async throws {
        let f = try await RConsumerFixture(.otzaria)
        defer { f.cleanup() }
        guard case .surface(let prepared) = try await f.bind() else { return XCTFail("Missing original") }
        let first = try XCTUnwrap(f.adapter.mappingOwnershipObservation())
        var tabs = f.manager.openTabs
        tabs[0].viewModel = MappingFixtureReader()
        f.manager.openTabs = tabs
        XCTAssertNotEqual(f.adapter.mappingOwnershipObservation()?.epoch, first.epoch)
        XCTAssertThrowsError(try prepared.authorizeCommit(current: prepared.command.scene))
        let other = StudyWorkspaceNavigationAdapter(sceneID: f.n.sceneID.rawValue, store: f.store)
        other.fixtureConnect(f.manager, groupID: f.groupID, backend: f.backendID)
        f.host.read = { other.mappingOwnershipObservation() }
        XCTAssertThrowsError(try f.host.observePublicNavigationBinding(f.n.intent, requestId: f.n.invocation.requestId, sceneID: f.n.sceneID))
        XCTAssertEqual(f.n.driver.applied, 0)
    }

    func testReadmissionInsideActualReadyNotificationSurvivesListenerOrder() async throws {
        let f = try await RConsumerFixture(.otzaria)
        defer { f.cleanup() }
        let source = f.adapter.mappingOwnershipSource, revoker = RAuthorityConsumer(f.n)
        let ready = RReadyAdmission(f.n)
        let invalidation = source.subscribeInvalidation(owner: revoker) { owner, _ in owner.revoke() }
        let publication = source.subscribe(owner: ready) { owner, event in
            guard event.phase == .available else { return }
            do {
                owner.state = try owner.n.authority.admit(context: owner.n.context, sceneID: owner.n.sceneID)
                owner.preparation = try owner.n.core.prepareNavigationSynchronously(sceneID: owner.n.sceneID.rawValue,
                    invocation: owner.n.invocation, context: owner.n.context)
            } catch { XCTFail("Published owner could not admit: \(error)") }
        }
        defer { invalidation.cancel(); publication.cancel() }
        f.manager.activeTabId = f.b.id
        let replacement = try XCTUnwrap(ready.state), preparation = try XCTUnwrap(ready.preparation)
        XCTAssertEqual(revoker.revocations, 1)
        try preparation.validateFreshness()
        f.n.authority.release(f.n.admitted)
        XCTAssertEqual(try f.n.authority.navigationState(sceneID: f.n.sceneID.rawValue).authorityRevision, replacement.authorityRevision)
        let plan = try await f.bind()
        guard case .surface(let bound) = plan else { return XCTFail("Missing publication-time replacement") }
        guard case .acknowledged = await f.n.orchestrator.commitPrepared(bound, admitted: replacement) else { return XCTFail("Final ready notification revoked the admitted replacement") }
        f.n.authority.release(replacement)
    }
}

@MainActor private final class RReadyAdmission {
    let n: PublicConsumerFixture
    var state: ActionNavigationState?
    var preparation: ActionNavigationPreparation?
    init(_ n: PublicConsumerFixture) { self.n = n }
}

@MainActor private final class RAuthorityConsumer {
    let n: PublicConsumerFixture
    var revocations = 0
    init(_ n: PublicConsumerFixture) { self.n = n }
    func revoke() {
        revocations += 1
        do { try n.authority.invalidate(n.lease) }
        catch { n.authority.unmount(n.lease); XCTFail("Original authority revocation failed: \(error)") }
    }
}

@MainActor private final class RConsumerFixture {
    let n: PublicConsumerFixture
    let root: URL
    let store: StudyWorkspaceStore
    let manager: iOSNavigationManager
    let adapter: StudyWorkspaceNavigationAdapter
    let host: RExactProducerBindingHost
    let a: ReaderDocumentTab, b: ReaderDocumentTab
    let groupID: UUID
    let backendID: BackendID
    var documents: [ReaderDocumentTab] { [a, b] }
    init(_ backend: ActionBackendID, reader: Bool = false, installed: Bool = true) async throws {
        n = try await PublicConsumerFixture(backend, reader: reader)
        backendID = BackendID(rawValue: backend.rawValue)!
        BackendCoordinator.shared.activeBackendID = backendID
        root = FileManager.default.temporaryDirectory.appendingPathComponent("N-R-consumer-\(UUID())")
        store = StudyWorkspaceStore(persistence: .init(url: root.appendingPathComponent("workspace.json")),
            canonicalSessionURL: root.appendingPathComponent("absent.json"))
        let id = UUID(uuidString: n.driver.targetTabID.rawValue)!
        let signedBook = backend == .otzaria ? 17 : -17
        a = .init(backend: backendID, session: .init(id: id, bookId: signedBook,
            backendLocator: .init(backend: backendID, workKey: "fixture:work", position: .legacyLine(0))))
        b = .init(backend: backendID, session: .init(id: UUID(), bookId: signedBook - 1,
            backendLocator: .init(backend: backendID, workKey: "other:work", position: .legacyLine(0))))
        try store.attach(scene: n.sceneID.rawValue, legacyTabs: [a, b], activeID: a.id)
        let group = try XCTUnwrap(store.selectedGroup(scene: n.sceneID.rawValue)); groupID = group.id
        manager = iOSNavigationManager(installed: installed)
        manager.openTabs = [
            .init(id: a.id, book: .init(signedBook, key: "fixture:work", backend: backendID), viewModel: .init()),
            .init(id: b.id, book: .init(signedBook - 1, key: "other:work", backend: backendID), viewModel: .init())]
        manager.activeTabId = a.id
        adapter = StudyWorkspaceNavigationAdapter(sceneID: n.sceneID.rawValue, store: store)
        adapter.fixtureConnect(manager, groupID: group.id, backend: backendID)
        n.driver.actualState = .init(workspaceID: .init(rawValue: group.id.uuidString), profileID: .init(rawValue: group.profileID.uuidString), inspectorVisible: reader ? false : nil)
        host = RExactProducerBindingHost(n, adapter: adapter, manager: manager)
    }
    func bind() async throws -> UIPublicNavigationPlanV2 {
        let scene = try await n.directory.currentScene(sceneID: n.sceneID, context: n.context, invocation: n.invocation)
        return try await n.registry.bindPublicV2(n.intent, scene: scene, context: n.context, invocation: n.invocation,
            core: n.core, host: host, clock: n.clock)
    }
    func cleanup() { n.authority.release(n.admitted); try? FileManager.default.removeItem(at: root) }
}

/// Test-only semantic adapter. Uses actual qualified observations; no cached
/// desired selection, fallback tab, reservation or independent permission state.
@MainActor private final class RExactProducerBindingHost: UIPublicNavigationBindingPort {
    let n: PublicConsumerFixture
    let fixedSource: StudyWorkspaceMappingSource
    let fixedOwner: ObjectIdentifier
    let fixedSourceID: UUID?
    var read: @MainActor () -> StudyWorkspaceMappingObservation?
    init(_ n: PublicConsumerFixture, adapter: StudyWorkspaceNavigationAdapter, manager: iOSNavigationManager) {
        self.n = n; fixedSource = adapter.mappingOwnershipSource
        fixedOwner = ObjectIdentifier(manager); fixedSourceID = adapter.mappingOwnershipObservation()?.epoch.sourceID
        read = { adapter.mappingOwnershipObservation() }
    }
    func observePublicNavigationBinding(_ intent: PublicNavigationSpecV2, requestId: UUID, sceneID: UIStableID) throws -> UIPublicNavigationLocalBinding {
        guard requestId == n.invocation.requestId, sceneID == n.sceneID,
              let actual = read(), actual.source === fixedSource, actual.owner == fixedOwner,
              actual.scene == sceneID.rawValue, actual.coverage == .liveNativeSetters,
              actual.epoch.sourceID == fixedSourceID else { throw ActionPortError.unavailable }
        let projection = actual.projection
        let tab: UIPublicNavigationObservedID
        if let content = intent.content {
            guard let selected = projection.activeTabID, let target = projection.targets[selected],
                  target.backend.rawValue == content.sectionLocator.backend.rawValue,
                  target.workKey == content.sectionLocator.workKey, target.readerOwner != nil,
                  let stable = UIStableID(rawValue: selected.uuidString) else { throw ActionPortError.unavailable }
            tab = .present(stable)
        } else { tab = .absent }
        let scene = try n.directory.synchronousScene(sceneID: sceneID, context: n.context, backend: n.backend.currentBackendSnapshot())
        return .init(sceneID: sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot,
            mappingRevision: actual.epoch.revision, workspace: .present(UIStableID(rawValue: projection.groupID.uuidString)!),
            profile: .present(UIStableID(rawValue: projection.profileID.uuidString)!), tab: tab,
            sidebarVisible: n.driver.actualState.sidebarVisible, inspectorVisible: n.driver.actualState.inspectorVisible)
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await n.directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { eligibility(scene) }
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { eligibility(scene) }
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { eligibility(scene) }
    private func eligibility(_ scene: UISceneSnapshot) -> UIRouteEligibility {
        .init(sceneID: scene.sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot, supported: true, ready: true, allowed: true)
    }
}
