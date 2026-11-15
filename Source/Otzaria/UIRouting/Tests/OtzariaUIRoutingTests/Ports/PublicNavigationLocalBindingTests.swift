import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

extension PublicNavigationV2Tests {
    /// Same independent workspace/profile History shape as N's 2b846845 repro,
    /// plus actual reader false/true inspector state and local tab projection.
    @MainActor func testNativeShapedLocalBindingAndExactReceiptsForAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            for destination in [history, settings] {
                let registry = try registry(), source = source(backend), host = PublicV2TestHost(source), core = try core(source)
                let presentation: PublicNavigationSpecV2.Presentation = destination == settings ? .sheet : .currentTab
                let intent = PublicNavigationSpecV2(destination: destination, presentation: presentation), invocation = invocation(source)
                let plan = try await registry.bindPublicV2(intent, scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
                guard case .surface(let prepared) = plan else { return XCTFail("Expected surface") }
                XCTAssertEqual(source.effects, 0)
                try prepared.authorizeCommit(current: source.scene); source.effects += 1; source.sceneRevision += 1
                // Native projection's state comes from the independently owned
                // workspace, not prepared.command.route.state or desired IDs.
                let actual = nativeObservedRoute(prepared.command, destination: destination, backend: backend,
                    presentation: .init(kind: destination == settings ? .sheet : .currentTab),
                    state: .init(workspaceID: host.workspace.value, profileID: host.profile.value))
                let observed = UISceneSnapshot(sceneID: source.scene.sceneID, revision: source.sceneRevision, backendSnapshot: source.backend, visibleRoute: actual)
                let receipt = UISceneReceipt(requestId: invocation.requestId, route: actual, backendSnapshot: source.backend,
                    sceneID: source.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
                XCTAssertEqual(prepared.command.route.route, actual)
                try prepared.validateCompletion(receipt: receipt, observed: observed)
                XCTAssertEqual(source.effects, 1)
            }
            for presentation in PublicNavigationSpecV2.Presentation.allCases {
                let registry = try registry(), source = source(backend), host = PublicV2TestHost(source), core = try core(source)
                let component = presentation == .sheet ? info : presentation == .inspector ? links : nil
                let intent = PublicNavigationSpecV2(destination: reader, content: content(backend, mode: presentation == .newTab ? .newTab : .sameTab),
                    presentation: presentation, component: component), invocation = invocation(source)
                let plan = try await registry.bindPublicV2(intent, scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
                guard case .reader(let retained) = plan else { return XCTFail("Content received a surface grant") }
                XCTAssertEqual(retained.route.state.inspectorVisible, presentation == .inspector)
                source.onReader = { issued in
                    let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: source.scene)
                    let prepared = try command.prepareNavigation(readerCommand: issued)
                    try prepared.authorizeCommit(current: source.scene)
                    source.effects += 1; source.sceneRevision += 1
                    if presentation == .inspector { host.inspectorVisible = true }
                    let actual = self.nativeObservedRoute(command, destination: self.reader, backend: backend,
                        content: issued.destination, presentation: .init(kind: presentation.nativeKind, tabID: host.tab.value),
                        state: .init(workspaceID: host.workspace.value, profileID: host.profile.value,
                            sidebarVisible: host.sidebarVisible, inspectorVisible: host.inspectorVisible),
                        focus: component.map { .init(kind: .component, anchor: $0) })
                    let coreReceipt = ActionUIReceipt(requestId: issued.invocation.requestId, snapshot: source.backend, sceneID: source.sceneID, destination: issued.destination)
                    let receipt = UISceneReceipt(requestId: issued.invocation.requestId, route: actual, backendSnapshot: source.backend,
                        sceneID: source.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6, coreReceipt: coreReceipt)
                    XCTAssertEqual(retained.route, actual)
                    try prepared.validateCompletion(receipt: receipt, observed: .init(sceneID: source.scene.sceneID, revision: 6, backendSnapshot: source.backend, visibleRoute: actual))
                    return .acknowledged(coreReceipt)
                }
                let result = await core.execute(.init(requestId: invocation.requestId, action: "reader.open",
                    arguments: try XCTUnwrap(ActionJSON.encoded(intent.content!).object), expectedBackend: backend), context: source.context)
                XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
                XCTAssertEqual(source.resolutions, 1); XCTAssertEqual(source.readerCalls, 1); XCTAssertEqual(source.effects, 1)
            }
        }
    }

    @MainActor func testLocalBindingMissingStaleAndExplicitObservedAbsence() async throws {
        for mode in 0..<3 {
            let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source)
            if mode == 0 { host.mappingUnavailable = true }
            if mode == 1 { host.observedSceneRevision = source.sceneRevision - 1 }
            if mode == 2 { host.workspace = .absent; host.profile = .absent }
            do {
                let plan = try await registry.bindPublicV2(.init(destination: history), scene: source.scene, context: source.context,
                    invocation: invocation(source), core: core, host: host)
                guard mode == 2, case .surface(let prepared) = plan else { return XCTFail("Missing/stale mapping succeeded") }
                XCTAssertNil(prepared.command.route.route.state.workspaceID); XCTAssertNil(prepared.command.route.route.state.profileID)
                try prepared.authorizeCommit(current: source.scene)
            } catch {
                XCTAssertNotEqual(mode, 2)
                XCTAssertEqual((error as? UIRouteError)?.status, mode == 0 ? .unavailable : .staleState)
            }
            XCTAssertEqual(source.effects, 0)
        }
    }

    @MainActor func testLocalMappingAndNativeLifetimeRevocationAcrossEveryBinderAwait() async throws {
        for boundary in 0..<3 {
            for mode in 0..<9 {
                let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source), gate = ReviewGate()
                installBindingGate(gate, boundary: boundary, host: host)
                let scene = source.scene, context = source.context, invocation = invocation(source)
                let intent = PublicNavigationSpecV2(destination: mode >= 7 ? reader : history, content: mode >= 7 ? content(.otzaria) : nil)
                let task = Task { try await registry.bindPublicV2(intent, scene: scene, context: context, invocation: invocation, core: core, host: host) }
                let safety = safetyRelease(gate); await gate.waitForEntry()
                invalidateBinding(mode: mode, host: host)
                await gate.release()
                do { _ = try await task.value; XCTFail("Binding survived mapping/context/lifetime invalidation at boundary \(boundary), mode \(mode)") } catch {}
                let observation = await gate.observation(); XCTAssertFalse(observation.safetyReleased); XCTAssertEqual(observation.pending, 0)
                safety.cancel(); await safety.value; XCTAssertEqual(source.effects, 0)
            }
        }
    }

    @MainActor func testRetainedLocalBindingRejectsInvalidationBeforeSurfaceOrReaderCommit() async throws {
        for readerPlan in [false, true] {
            for mode in 0..<(readerPlan ? 9 : 7) {
                let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source), invocation = invocation(source)
                let intent = PublicNavigationSpecV2(destination: readerPlan ? reader : history, content: readerPlan ? content(.otzaria) : nil)
                let plan = try await registry.bindPublicV2(intent, scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
                invalidateBinding(mode: mode, host: host)
                switch plan {
                case .surface(let prepared):
                    XCTAssertThrowsError(try prepared.authorizeCommit(current: source.scene))
                case .reader(let retained):
                    source.onReader = { issued in
                        let command = try UISceneCommand(route: retained, invocation: issued.invocation, scene: source.scene)
                        let prepared = try command.prepareNavigation(readerCommand: issued)
                        do { try prepared.authorizeCommit(current: source.scene); source.effects += 1; XCTFail("Reader lost original local/lifetime boundary") }
                        catch { throw ActionPortError.staleState }
                        throw ActionPortError.invalidResponse
                    }
                    let result = await core.execute(.init(requestId: invocation.requestId, action: "reader.open",
                        arguments: try XCTUnwrap(ActionJSON.encoded(intent.content!).object), expectedBackend: .otzaria), context: source.context)
                    XCTAssertNotEqual(result.status, .completed)
                }
                XCTAssertEqual(source.effects, 0)
            }
        }
    }

    @MainActor func testLocalBindingCompletionRejectsABAAfterActualEffect() async throws {
        for mode in [2, 3, 4] {
            let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source), invocation = invocation(source)
            let plan = try await registry.bindPublicV2(.init(destination: history), scene: source.scene, context: source.context,
                invocation: invocation, core: core, host: host)
            guard case .surface(let prepared) = plan else { return XCTFail("Expected surface") }
            try prepared.authorizeCommit(current: source.scene); source.effects += 1; source.sceneRevision += 1
            let actual = nativeObservedRoute(prepared.command, destination: history, backend: .otzaria, presentation: .init(),
                state: .init(workspaceID: host.workspace.value, profileID: host.profile.value))
            let receipt = UISceneReceipt(requestId: invocation.requestId, route: actual, backendSnapshot: source.backend,
                sceneID: source.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
            invalidateBinding(mode: mode, host: host)
            XCTAssertThrowsError(try prepared.validateCompletion(receipt: receipt,
                observed: .init(sceneID: source.scene.sceneID, revision: 6, backendSnapshot: source.backend, visibleRoute: actual)))
            XCTAssertEqual(source.effects, 1, "Post-effect failure does not claim rollback")
        }
    }

    @MainActor func testLocalBindingDeadlineAndCancellationCleanAllBinderAwaits() async throws {
        for boundary in 0..<3 {
            for cancel in [false, true] {
                let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source), gate = ReviewGate()
                installBindingGate(gate, boundary: boundary, host: host)
                let scene = source.scene, context = source.context, invocation = invocation(source, deadline: SystemActionClock().now() + 500_000_000)
                let task = Task { try await registry.bindPublicV2(.init(destination: history), scene: scene, context: context,
                    invocation: invocation, core: core, host: host) }
                let safety = safetyRelease(gate); await gate.waitForEntry(); if cancel { task.cancel() }
                do { _ = try await task.value; XCTFail("Cancelled/late local mapping returned") }
                catch is CancellationError { XCTAssertTrue(cancel) }
                catch { XCTAssertEqual((error as? UIRouteError)?.status ?? (error as? ActionNavigationError)?.status, .cancelled) }
                let observation = await gate.observation(); XCTAssertFalse(observation.safetyReleased); XCTAssertEqual(observation.pending, 0)
                safety.cancel(); await safety.value; XCTAssertEqual(source.effects, 0)
            }
        }
    }

    @MainActor private func installBindingGate(_ gate: ReviewGate, boundary: Int, host: PublicV2TestHost) {
        if boundary == 1 { host.navigationGate = gate }
        else { host.sceneGates[boundary == 0 ? 1 : 2] = gate }
    }
    @MainActor private func invalidateBinding(mode: Int, host: PublicV2TestHost) {
        switch mode {
        case 0: host.workspace = .present(.init(rawValue: "different-workspace")!)
        case 1: host.profile = .present(.init(rawValue: "different-profile")!)
        case 2:
            let workspace = host.workspace, profile = host.profile
            host.workspace = .absent; host.profile = .absent
            host.workspace = workspace; host.profile = profile; host.mappingRevision += 1
        case 3: host.source.lifetimeID = UUID()
        case 4: host.source.active = false; host.source.active = true; host.source.authorityRevision += 1
        case 5: host.mappingUnavailable = true
        case 6: host.source.backend = .init(backend: .otzaria, generation: 2)
        case 7: host.tab = .present(.init(rawValue: "replacement-tab")!)
        default: host.inspectorVisible = true
        }
    }
    /// Only correlation/expectation envelope is retained from the command;
    /// native destination/presentation/content/state/focus are independent inputs.
    private func nativeObservedRoute(_ command: UISceneCommand, destination: UIDestinationID, backend: ActionBackendID,
                                     content: ActionReaderDestination? = nil, presentation: PresentationSpec, state: UIStateSpec, focus: FocusSpec? = nil) -> RouteSpec {
        .init(requestId: command.invocation.requestId, destination: destination, backend: backend, content: content,
            presentation: presentation, state: state, focus: focus, scene: command.route.route.scene, expectedBackendSnapshot: command.invocation.snapshot)
    }
}
