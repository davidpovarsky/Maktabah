import Foundation
import XCTest
import OtzariaActionCore
import OtzariaUIRouting
@testable import ChavrusaUIRoutingHost

/// Future consumer seam over actual Core/P preparations and N's real directory,
/// admission and orchestrator. Native model/driver remains synthetic, not UIKit.
@MainActor final class NativePublicPreparedCommitTests: XCTestCase, @unchecked Sendable {
    func testOriginalBoundSurfaceCompletesWithoutReplacingOrReleasingAdmissionOnAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await PublicConsumerFixture(backend)
            defer { f.authority.release(f.admitted) }
            let prepared = try await f.surfacePlan()
            let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
            guard case .acknowledged(let receipt) = result else { return XCTFail("No exact visible receipt: \(result)") }
            XCTAssertEqual(receipt.route.state, f.driver.actualState)
            XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
            XCTAssertGreaterThan(receipt.appliedSceneRevision, receipt.basedOnSceneRevision)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
            XCTAssertThrowsError(try prepared.authorizeCommit(current: prepared.command.scene), "Original preparation was consumed")
        }
    }

    func testConsumedOriginalMappingOrGenerationDriftCannotBeRepreparedIntoSuccess() async throws {
        for backend in ActionBackendID.allCases {
            for mode in 0..<3 {
                let f = try await PublicConsumerFixture(backend)
                defer { f.authority.release(f.admitted) }
                let prepared = try await f.surfacePlan()
                if mode == 0 { try prepared.authorizeCommit(current: prepared.command.scene) }
                if mode == 1 { f.host.mappingRevision += 1 }
                if mode == 2 { f.backend.value = .init(backend: backend, generation: 2, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil) }
                let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
                if case .acknowledged = result { XCTFail("Original grant/binding was discarded in mode \(mode)") }
                XCTAssertEqual(f.driver.applied, 0); XCTAssertNil(f.driver.command)
                XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
            }
        }
    }

    func testOldPreparedAdmissionAndCleanupCannotTakeReplacementContext() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await PublicConsumerFixture(backend), prepared = try await f.surfacePlan()
            try f.authority.invalidate(f.lease)
            let replacement = try f.authority.admit(context: f.context, sceneID: f.sceneID)
            defer { f.authority.release(replacement) }
            let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
            guard case .staleState = result else { return XCTFail("Replacement admission was borrowed") }
            f.authority.release(f.admitted)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, replacement.authorityRevision)
            XCTAssertEqual(f.driver.applied, 0); XCTAssertNil(f.driver.command)
        }
    }

    func testFinalMappingDriftAfterDispatchRemainsUncertainAndDoesNotReleaseOwner() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await PublicConsumerFixture(backend), prepared = try await f.surfacePlan()
            defer { f.authority.release(f.admitted) }
            f.driver.afterApply = { f.backend.afterSnapshot = { f.host.mappingRevision += 1 } }
            let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
            guard case .staleState(let failure) = result else { return XCTFail("Stale final binding completed") }
            XCTAssertEqual(failure.code, "native_effect_uncertain")
            XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
        }
    }

    func testPreparedCancellationJoinsObserverCleanupAndRetainsOuterAdmission() async throws {
        let f = try await PublicConsumerFixture(.otzaria), prepared = try await f.surfacePlan()
        defer { f.authority.release(f.admitted) }
        let (stream, signal) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        defer { signal.finish() }
        f.driver.wait = true; f.driver.afterApply = { signal.yield(()) }
        let task = Task { await f.orchestrator.commitPrepared(prepared, admitted: f.admitted) }
        var iterator = stream.makeAsyncIterator(); _ = await iterator.next(); task.cancel()
        let result = await task.value
        guard case .failed(let failure) = result else { return XCTFail("Cancelled possible effect completed") }
        XCTAssertEqual(failure.code, "native_effect_uncertain")
        XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
        XCTAssertEqual(f.directory.pendingObservationCount, 0)
        XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
    }

    func testRetainedBoundReaderRouteUsesActualCoreSinkAndHoldsAdmissionUntilWholeResult() async throws {
        for backend in ActionBackendID.allCases {
            let f = try await PublicConsumerFixture(backend, reader: true)
            defer { f.authority.release(f.admitted) }
            let plan = try await f.bind()
            guard case .reader(let retained) = plan else { return XCTFail("Content received a surface grant") }
            f.sink.onOpen = { issued in
                // Keep the exact validated route and its internal binding guard;
                // transport/deadline come from the independently issued Core sink.
                let scene = try await f.directory.currentScene(sceneID: f.sceneID, context: f.context, invocation: issued.invocation)
                let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: scene)
                let result = await f.orchestrator.commit(command, readerCommand: issued, context: f.context)
                guard case .acknowledged(let receipt) = result, let coreReceipt = receipt.coreReceipt else { throw ActionPortError.invalidResponse }
                return .acknowledged(coreReceipt)
            }
            let args = try XCTUnwrap(ActionJSON.encoded(try XCTUnwrap(retained.route.content)).object)
            let result = await f.core.execute(.init(requestId: retained.route.requestId, action: "reader.open", arguments: args,
                expectedBackend: backend, expectedGeneration: f.invocation.snapshot.generation, deadlineMs: 5_000), context: f.context)
            XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
            XCTAssertEqual(f.sink.calls, 1); XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
            XCTAssertEqual(retained.route.state.inspectorVisible, false)
            XCTAssertEqual(try f.authority.navigationState(sceneID: f.sceneID.rawValue).authorityRevision, f.admitted.authorityRevision)
        }
    }

    func testDriverUnregistrationInsideFinalAuthorityReadCannotAcknowledge() async throws {
        let f = try await PublicConsumerFixture(.otzaria), prepared = try await f.surfacePlan()
        defer { f.authority.release(f.admitted) }
        f.driver.afterApply = {
            f.backend.afterSnapshot = {
                f.backend.onSynchronousSnapshot = {
                    f.backend.onSynchronousSnapshot = nil
                    f.orchestrator.unregister(f.driver)
                }
            }
        }
        let result = await f.orchestrator.commitPrepared(prepared, admitted: f.admitted)
        guard case .staleState(let failure) = result else { return XCTFail("Unregistered native owner acknowledged completion") }
        XCTAssertEqual(failure.code, "native_effect_uncertain")
        XCTAssertEqual(f.driver.applied, 1); XCTAssertNil(f.driver.command)
    }
}

@MainActor final class PublicConsumerFixture {
    let sceneID = UIStableID(rawValue: "public.native.scene")!
    let authority: NativeNavigationAuthority
    let lease: NativeNavigationAuthority.Lease
    let admitted: ActionNavigationState
    let backend: NavigationTestBackend
    let directory: NativeSceneDirectory
    let driver: NavigationTestDriver
    let core: ActionExecutor
    let orchestrator: NativeSceneNavigationOrchestrator
    let context: ActionExecutionContext
    let invocation: ActionPortInvocation
    let scene: UISceneSnapshot
    let registry: UIDestinationRegistry
    let host: PublicConsumerBindingHost
    let intent: PublicNavigationSpecV2
    let sink: NavigationReaderSink
    let clock: any ActionClock

    init(_ backendID: ActionBackendID, reader: Bool = false, clock: any ActionClock = SystemActionClock(),
         deadline: UInt64 = UInt64.max, dispatchCapacity: Int = 256) async throws {
        self.clock = clock
        backend = NavigationTestBackend(backendID); backend.readerReady = reader
        authority = try NativeNavigationAuthority(); lease = try authority.mount(sceneID: sceneID, foreground: true)
        context = .init(subjectID: "native.public.consumer", origin: .deepLink, allowedBackends: [backendID],
            contentRights: reader ? [backendID] : [], scopes: reader ? [.navigation, .discovery, .contentRead] : [.navigation, .discovery],
            foregroundSceneID: sceneID.rawValue)
        admitted = try authority.admit(context: context, sceneID: sceneID)
        directory = try NativeSceneDirectory(authority: backend, clock: clock)
        driver = NavigationTestDriver(sceneID: sceneID, backend: backend)
        driver.actualState = .init(workspaceID: .init(rawValue: "11111111-1111-4111-8111-111111111111"),
            profileID: .init(rawValue: "22222222-2222-4222-8222-222222222222"), inspectorVisible: reader ? false : nil)
        driver.targetTabID = UIStableID(rawValue: "33333333-3333-4333-8333-333333333333")!
        let authority = authority, driver = driver
        _ = try directory.mount(sceneID: sceneID, observe: { driver.observation }, validateLifetime: { context in
            guard try authority.navigationState(sceneID: driver.sceneID.rawValue).context == context else { throw ActionPortError.staleState }
        })
        sink = NavigationReaderSink()
        let ports = NavigationTestPorts(allowReader: reader)
        core = try ActionExecutor(state: backend, resolver: ports, search: ports, ui: sink, clock: clock, navigationAuthority: authority)
        orchestrator = try NativeSceneNavigationOrchestrator(core: core, backend: backend, authority: authority,
            directory: directory, dispatchCapacity: dispatchCapacity, clock: clock)
        try orchestrator.register(driver)
        invocation = .init(requestId: UUID(), snapshot: backend.value, deadlineUptimeNanoseconds: deadline)
        scene = try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
        let destination = UIDestinationID(rawValue: reader ? "native.reader" : "native.settings")!
        let content: ActionReaderDestination? = reader ? .init(sectionLocator: .init(backend: backendID, workKey: "fixture:work",
            position: backendID == .otzaria ? .legacyLine(1) : .canonicalRef("Fixture 1"))) : nil
        intent = .init(destination: destination, backend: backendID, content: content, presentation: reader ? .currentTab : .sheet)
        registry = try UIDestinationRegistry(descriptors: [.init(id: destination, title: "Synthetic native consumer", implementation: .implemented,
            supportedBackends: [backendID], presentations: reader ? [.currentTab, .inspector] : [.sheet], requiredCoreActions: reader ? ["reader.open"] : [],
            requiresContent: reader, publicNavigationV2: .init(rules: [.init(presentation: reader ? .currentTab : .sheet)]))])
        host = PublicConsumerBindingHost(directory: directory, backend: backend, driver: driver, context: context, invocation: invocation, hasReaderTarget: reader)
    }
    func bind() async throws -> UIPublicNavigationPlanV2 {
        try await registry.bindPublicV2(intent, scene: scene, context: context, invocation: invocation, core: core, host: host, clock: clock)
    }
    func surfacePlan() async throws -> UIAuthorizedSceneCommand {
        guard case .surface(let prepared) = try await bind() else { throw ActionPortError.invalidResponse }
        return prepared
    }
}

/// Synthetic real-owner model for portable consumer tests; not an app adapter.
@MainActor final class PublicConsumerBindingHost: UIPublicNavigationBindingPort {
    let directory: NativeSceneDirectory
    let backend: NavigationTestBackend
    let driver: NavigationTestDriver
    let context: ActionExecutionContext
    let invocation: ActionPortInvocation
    let hasReaderTarget: Bool
    var mappingRevision: UInt64 = 1
    init(directory: NativeSceneDirectory, backend: NavigationTestBackend, driver: NavigationTestDriver,
         context: ActionExecutionContext, invocation: ActionPortInvocation, hasReaderTarget: Bool) {
        self.directory = directory; self.backend = backend; self.driver = driver; self.context = context
        self.invocation = invocation; self.hasReaderTarget = hasReaderTarget
    }
    func observePublicNavigationBinding(_ intent: PublicNavigationSpecV2, requestId: UUID, sceneID: UIStableID) throws -> UIPublicNavigationLocalBinding {
        guard requestId == invocation.requestId, sceneID == driver.sceneID, (intent.content != nil) == hasReaderTarget else { throw ActionPortError.unavailable }
        let actual = try directory.synchronousScene(sceneID: sceneID, context: context, backend: backend.currentBackendSnapshot())
        func observed(_ value: UIStableID?) -> UIPublicNavigationObservedID { value.map(UIPublicNavigationObservedID.present) ?? .absent }
        return .init(sceneID: actual.sceneID, sceneRevision: actual.revision, backendSnapshot: actual.backendSnapshot, mappingRevision: mappingRevision,
            workspace: observed(driver.actualState.workspaceID), profile: observed(driver.actualState.profileID),
            tab: hasReaderTarget ? .present(driver.targetTabID) : .absent,
            sidebarVisible: driver.actualState.sidebarVisible, inspectorVisible: driver.actualState.inspectorVisible)
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await directory.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { assessment(scene) }
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { assessment(scene) }
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility { assessment(scene) }
    private func assessment(_ scene: UISceneSnapshot) -> UIRouteEligibility {
        .init(sceneID: scene.sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot, supported: true, ready: true, allowed: true)
    }
}
