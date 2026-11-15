import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class NavigationAuthorizationTests: XCTestCase, @unchecked Sendable {
    @MainActor private func context(_ backend: ActionBackendID = .otzaria, origin: ActionOrigin = .inApp,
        scopes: Set<ActionScope> = [.discovery, .navigation], subject: String = "native-subject",
        allowed: Set<ActionBackendID>? = nil, works: [ActionBackendID: Set<String>]? = nil,
        scene: String? = "native-scene", paired: Bool = true, correlation: UUID = UUID()) -> ActionExecutionContext {
        .init(subjectID: subject, correlationID: correlation, origin: origin, allowedBackends: allowed ?? [backend],
            scopes: scopes, allowedWorkKeys: works, foregroundSceneID: scene, pairedDeviceAvailable: paired)
    }
    private func descriptor(_ id: String = "native.settings", actions: [String] = [], content: Bool = false) -> UIDestinationDescriptor {
        .init(id: .init(rawValue: id)!, title: "Synthetic native host", implementation: .implemented,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .sidebar], anchors: [.init(rawValue: "native.sidebar")!],
            requiredCoreActions: actions, requiresContent: content)
    }
    @MainActor private func command(_ host: NavigationAuthorityFixture, descriptor: UIDestinationDescriptor? = nil,
                                   deadline: UInt64 = UInt64.max) throws -> UISceneCommand {
        let descriptor = descriptor ?? self.descriptor()
        let registry = try UIDestinationRegistry(descriptors: [descriptor])
        let route = RouteSpec(destination: descriptor.id, backend: host.backend.backend,
            scene: .init(kind: .specific, sceneID: .init(rawValue: host.sceneID), expectedRevision: host.sceneRevision), expectedBackendSnapshot: host.backend)
        return try UISceneCommand(route: registry.validate(route), invocation: .init(requestId: route.requestId, snapshot: host.backend,
            deadlineUptimeNanoseconds: deadline), scene: host.scene)
    }
    @MainActor private func executor(_ host: NavigationAuthorityFixture, clock: any ActionClock = SystemActionClock()) throws -> ActionExecutor {
        try ActionExecutor(state: host, resolver: host, search: host, ui: host, clock: clock, navigationAuthority: host)
    }
    private func changed(_ original: ActionExecutionContext, subject: String? = nil, origin: ActionOrigin? = nil,
                         scopes: Set<ActionScope>? = nil, allowed: Set<ActionBackendID>? = nil,
                         rights: Set<ActionBackendID>? = nil, works: [ActionBackendID: Set<String>]? = nil,
                         scene: String? = nil) -> ActionExecutionContext {
        .init(subjectID: subject ?? original.subjectID, correlationID: original.correlationID, origin: origin ?? original.origin,
            allowedBackends: allowed ?? original.allowedBackends, contentRights: rights ?? original.contentRights,
            scopes: scopes ?? original.scopes, allowedWorkKeys: works ?? original.allowedWorkKeys,
            foregroundSceneID: scene ?? original.foregroundSceneID, pairedDeviceAvailable: original.pairedDeviceAvailable,
            maxActions: original.maxActions, maxResultBytes: original.maxResultBytes)
    }
    private func completion(_ command: UISceneCommand) -> (receipt: UISceneReceipt, observed: UISceneSnapshot) {
        let applied = command.scene.revision + 1
        let receipt = UISceneReceipt(requestId: command.invocation.requestId, route: command.route.route,
            backendSnapshot: command.invocation.snapshot, sceneID: command.scene.sceneID,
            basedOnSceneRevision: command.scene.revision, appliedSceneRevision: applied)
        let observed = UISceneSnapshot(sceneID: command.scene.sceneID, revision: applied,
            backendSnapshot: command.invocation.snapshot, visibleRoute: command.route.route)
        return (receipt, observed)
    }
    @MainActor func testCompletionRequiresGuardAndExactObservedReceiptWithoutRegrant() async throws {
        for backend in ActionBackendID.allCases {
            let host = NavigationAuthorityFixture(context: context(backend), backend: backend)
            let prepared = try await command(host).prepareNavigation(using: executor(host), context: host.context)
            let result = completion(prepared.command)
            XCTAssertThrowsError(try prepared.validateCompletion(receipt: result.receipt, observed: result.observed))
            try prepared.authorizeCommit(current: host.scene)
            host.effects += 1
            try prepared.validateCompletion(receipt: result.receipt, observed: result.observed)
            let wrong = UISceneReceipt(requestId: UUID(), route: result.receipt.route, backendSnapshot: host.backend,
                sceneID: host.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
            XCTAssertThrowsError(try prepared.validateCompletion(receipt: wrong, observed: result.observed))
            XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene), "Completion must not reissue commit authority")
            XCTAssertEqual(host.effects, 1)
        }
    }
    @MainActor func testRevocationAfterObservedMutationPreventsCompletion() async throws {
        for mutation in 0..<10 {
            let original = changed(context(.sefariaEmbedded, works: [.sefariaEmbedded: ["fixture:work"]]), rights: [.sefariaEmbedded])
            let host = NavigationAuthorityFixture(context: original, backend: .sefariaEmbedded)
            let prepared = try await command(host).prepareNavigation(using: executor(host), context: original)
            try prepared.authorizeCommit(current: host.scene)
            host.effects += 1
            let observedResult = completion(prepared.command)
            switch mutation {
            case 0: host.active = false
            case 1: host.authorityRevision += 2 // Revocation + restore while original context fields match.
            case 2: host.context = changed(original, subject: "replaced-subject")
            case 3: host.context = changed(original, scopes: [.discovery])
            case 4: host.context = changed(original, rights: [])
            case 5: host.context = changed(original, works: [.sefariaEmbedded: []])
            case 6: host.lifetimeID = UUID()
            case 7: host.backend = .init(backend: .sefariaEmbedded, generation: 2, rpcEpoch: 7)
            case 8: host.backend = .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 8)
            default: host.context = changed(original, scene: "other-scene")
            }
            // Structural observation alone remains correct about the captured
            // effect, but cannot prove current post-await permission/freshness.
            XCTAssertNoThrow(try observedResult.receipt.validate(for: prepared.command, observed: observedResult.observed))
            XCTAssertThrowsError(try prepared.validateCompletion(receipt: observedResult.receipt, observed: observedResult.observed))
            XCTAssertEqual(host.effects, 1, "Refusing completion is not rollback/no-effect proof")
        }
    }
    @MainActor func testDeadlineAndCancellationAfterMutationDoNotBecomeCompletion() async throws {
        let host = NavigationAuthorityFixture(context: context()), clock = DiscoveryClock(), core = try executor(host, clock: clock)
        let prepared = try await command(host, deadline: 20).prepareNavigation(using: core, context: host.context)
        try prepared.authorizeCommit(current: host.scene); host.effects += 1
        let result = completion(prepared.command)
        clock.advance(to: 20)
        XCTAssertThrowsError(try prepared.validateCompletion(receipt: result.receipt, observed: result.observed)) {
            XCTAssertEqual(($0 as? ActionNavigationError)?.status, .cancelled)
        }
        let next = try await command(host, deadline: 30).prepareNavigation(using: core, context: host.context)
        try next.authorizeCommit(current: host.scene); host.effects += 1
        let nextResult = completion(next.command), gate = SceneTestGate()
        let task = Task { @MainActor in
            await gate.enter()
            try next.validateCompletion(receipt: nextResult.receipt, observed: nextResult.observed)
        }
        await gate.waitForEntry(); task.cancel(); await gate.release()
        do { try await task.value; XCTFail("Cancelled post-effect wait completed") } catch is CancellationError {} catch { XCTFail("Unexpected \(error)") }
        XCTAssertEqual(host.effects, 2)
    }
    @MainActor func testReaderAcknowledgementRequiresConsumedGuardAndFreshPostSinkAuthority() async throws {
        for mode in 0..<3 {
            let host = NavigationAuthorityFixture(context: context()), core = try executor(host)
            host.onReader = { reader in
                if mode == 2 { return .queued(handle: "queued-fixture") }
                if mode == 1 {
                    try reader.navigationAuthorization!.authorizeCommit(invocation: reader.invocation, sceneID: reader.sceneID, destination: reader.destination)
                    host.effects += 1
                    host.active = false // An awaited native observation could revoke context after the effect.
                }
                return .acknowledged(.init(requestId: reader.invocation.requestId, snapshot: reader.invocation.snapshot,
                    sceneID: reader.sceneID, destination: reader.destination))
            }
            let ref = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42))
            let result = await core.execute(.init(action: "reader.open", arguments: ["sectionLocator": try .encoded(ref)], expectedBackend: .otzaria), context: host.context)
            if mode == 2 { XCTAssertEqual(result.status, .uiQueued); XCTAssertEqual(host.effects, 0) }
            else {
                XCTAssertEqual(result.status, .failed)
                XCTAssertEqual(result.error?.code, mode == 0 ? "navigation_commit_not_authorized" : "navigation_authority_changed")
                XCTAssertEqual(host.effects, mode == 1 ? 1 : 0)
            }
            XCTAssertEqual(host.resolutions, 1); XCTAssertEqual(host.readerCalls, 1)
        }
    }
    @MainActor func testPureNavigationAllThreeBackendsSixOriginsAndOneUse() async throws {
        for backend in ActionBackendID.allCases {
            for origin in [ActionOrigin.inApp, .appIntent, .deepLink, .internalAI, .guide, .mcp] {
                let host = NavigationAuthorityFixture(context: context(backend, origin: origin), backend: backend)
                let command = try command(host), core = try executor(host)
                let prepared = try await command.prepareNavigation(using: core, context: host.context)
                XCTAssertEqual(prepared.command, command)
                try prepared.authorizeCommit(current: host.scene)
                XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene))
                XCTAssertEqual(host.resolutions, 0)
                XCTAssertEqual(host.searches, 0)
                XCTAssertEqual(host.readerCalls, 0)
            }
        }
    }
    @MainActor func testRevokedOrChangedAuthorityNeverCommits() async throws {
        for mutation in 0..<9 {
            let original = changed(context(works: [.otzaria: ["fixture:work"]]), rights: [.otzaria])
            let host = NavigationAuthorityFixture(context: original), core = try executor(host)
            let prepared = try await command(host).prepareNavigation(using: core, context: original)
            switch mutation {
            case 0: host.context = changed(original, subject: "different-subject")
            case 1: host.context = changed(original, scopes: [.discovery])
            case 2: host.context = changed(original, origin: .deepLink)
            case 3: host.context = changed(original, allowed: [.sefaria])
            case 4: host.context = changed(original, works: [.otzaria: []])
            case 5: host.context = changed(original, scene: "different-scene")
            case 6: host.active = false
            case 7: host.authorityRevision += 2 // Revocation then restoration, even when context matches.
            default: host.context = changed(original, rights: [])
            }
            XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene), "mutation \(mutation)")
        }
    }
    @MainActor func testRawPreparationBindsInvocationSceneAndCannotBecomeReaderAuthority() async throws {
        let host = NavigationAuthorityFixture(context: context()), core = try executor(host), command = try command(host)
        let authorization = try await core.prepareNavigation(sceneID: host.sceneID, invocation: command.invocation, context: host.context)
        let wrongRequest = ActionPortInvocation(requestId: UUID(), snapshot: host.backend, deadlineUptimeNanoseconds: command.invocation.deadlineUptimeNanoseconds)
        XCTAssertThrowsError(try authorization.authorizeCommit(invocation: wrongRequest, sceneID: host.sceneID))
        XCTAssertThrowsError(try authorization.authorizeCommit(invocation: command.invocation, sceneID: "another-scene"))
        let content = ActionReaderDestination(sectionLocator: .init(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42)))
        XCTAssertThrowsError(try authorization.authorizeCommit(invocation: command.invocation, sceneID: host.sceneID, destination: content))
        try authorization.authorizeCommit(invocation: command.invocation, sceneID: host.sceneID)
    }
    @MainActor func testLifetimeReplacementAndBackendGenerationEpochDriftFailClosed() async throws {
        for mutation in 0..<5 {
            let host = NavigationAuthorityFixture(context: context(.sefariaEmbedded), backend: .sefariaEmbedded)
            let prepared = try await command(host).prepareNavigation(using: executor(host), context: host.context)
            switch mutation {
            case 0: host.lifetimeID = UUID()
            case 1: host.backend = .init(backend: .sefariaEmbedded, generation: 2, rpcEpoch: 7)
            case 2: host.backend = .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 8)
            case 3: host.backend = .init(backend: .sefariaEmbedded, generation: 1)
            default: host.backend = .init(backend: .sefaria, generation: 1)
            }
            XCTAssertThrowsError(try prepared.authorizeCommit(current: prepared.command.scene))
        }
    }
    @MainActor func testCurrentSubjectScopeScenePairingAndMissingEpochRequiredAtPreparation() async throws {
        for mode in 0..<5 {
            let supplied = context()
            let host = NavigationAuthorityFixture(context: supplied)
            switch mode {
            case 0: host.context = context(subject: "different")
            case 1: host.context = context(scopes: [.discovery])
            case 2: host.context = context(scene: nil)
            case 3: host.context = context(origin: .mcp, paired: false)
            default: host.active = false
            }
            do { _ = try await command(host).prepareNavigation(using: executor(host), context: mode == 0 ? supplied : host.context); XCTFail("Invalid authority prepared") }
            catch {}
        }
        let host = NavigationAuthorityFixture(context: context(.sefariaEmbedded), backend: .sefariaEmbedded)
        host.backend = .init(backend: .sefariaEmbedded, generation: 1)
        // Structural commands also refuse a missing Embedded epoch.
        XCTAssertThrowsError(try command(host))
    }
    @MainActor func testDeadlineAndCancellationRecheckedSynchronously() async throws {
        let clock = DiscoveryClock(), host = NavigationAuthorityFixture(context: context()), core = try executor(host, clock: clock)
        let prepared = try await command(host, deadline: 20).prepareNavigation(using: core, context: host.context)
        clock.advance(to: 20)
        XCTAssertThrowsError(try prepared.authorizeCommit(current: host.scene))
        let other = try await command(host, deadline: 30).prepareNavigation(using: core, context: host.context)
        let gate = SceneTestGate()
        let task = Task { @MainActor in await gate.enter(); try other.authorizeCommit(current: host.scene) }
        await gate.waitForEntry(); task.cancel(); await gate.release()
        do { try await task.value; XCTFail("Cancelled commit authorized") } catch is CancellationError {} catch { XCTFail("Unexpected \(error)") }
    }
    @MainActor func testDiscoveryPermissionIsSeparateFromExecutionPreparation() async throws {
        let host = NavigationAuthorityFixture(context: context(scopes: [.discovery]))
        let core = try executor(host), command = try command(host)
        let registry = try UIDestinationRegistry(descriptors: [descriptor()])
        let hidden = try await registry.discover(scene: host.scene, context: host.context, invocation: command.invocation, core: core, host: host)
        XCTAssertTrue(hidden.isEmpty)
        do { _ = try await command.prepareNavigation(using: core, context: host.context); XCTFail("Discovery granted commit") } catch {}
        host.context = context(scopes: [.navigation])
        let stillHidden = try await registry.discover(scene: host.scene, context: host.context, invocation: command.invocation, core: core, host: host)
        XCTAssertTrue(stillHidden.isEmpty)
        let prepared = try await command.prepareNavigation(using: core, context: host.context)
        try prepared.authorizeCommit(current: host.scene) // Execution requires navigation, not metadata discovery.
        host.context = context()
        let visible = try await registry.discover(scene: host.scene, context: host.context, invocation: command.invocation, core: core, host: host)
        XCTAssertEqual(visible.map(\.id), [descriptor().id])
        // Discovery itself did not yield a preparation or consume this commit.
        let independent = try await command.prepareNavigation(using: core, context: host.context)
        try independent.authorizeCommit(current: host.scene)
    }
    @MainActor func testMissingSynchronousFacetCannotUseASecondAuthority() async throws {
        let host = NavigationAuthorityFixture(context: context())
        let core = try ActionExecutor(state: AsyncOnlyNavigationState(host: host), resolver: host, search: host, navigationAuthority: host)
        do { _ = try await command(host).prepareNavigation(using: core, context: host.context); XCTFail("Unrelated/async-only authority accepted") }
        catch { XCTAssertEqual((error as? ActionNavigationError)?.code, "synchronous_navigation_authority_unavailable") }
        let sceneCommand = try command(host), registry = try UIDestinationRegistry(descriptors: [descriptor()])
        let hidden = try await registry.discover(scene: host.scene, context: host.context, invocation: sceneCommand.invocation, core: core, host: host)
        XCTAssertTrue(hidden.isEmpty, "UI-only discovery needs a genuinely available canonical guard")
        let noNativeContext = try ActionExecutor(state: host, resolver: host, search: host)
        do { _ = try await sceneCommand.prepareNavigation(using: noNativeContext, context: host.context); XCTFail("Missing native context silently accepted") }
        catch { XCTAssertEqual((error as? ActionNavigationError)?.code, "navigation_context_authority_unavailable") }
    }
    @MainActor func testCanonicalBackendAndNativeContextRemainSeparateSources() async throws {
        let original = context(), backendSource = NavigationAuthorityFixture(context: original)
        let nativeSource = NavigationAuthorityFixture(context: original)
        let core = try ActionExecutor(state: backendSource, resolver: backendSource, search: backendSource, navigationAuthority: nativeSource)
        let sceneCommand = try command(backendSource)
        let prepared = try await sceneCommand.prepareNavigation(using: core, context: original)
        nativeSource.backend = .init(backend: .sefariaEmbedded, generation: 999, rpcEpoch: 999) // Not a backend authority for this Core.
        try prepared.authorizeCommit(current: backendSource.scene)
        let another = try await sceneCommand.prepareNavigation(using: core, context: original)
        // Same-backend canonical resource-generation advance also invalidates preparation.
        backendSource.backend = .init(backend: .otzaria, generation: 2)
        XCTAssertThrowsError(try another.authorizeCommit(current: sceneCommand.scene))
    }
    @MainActor func testMissingEmbeddedSynchronousProofDoesNotBlockOtherBackends() async throws {
        for backend in ActionBackendID.allCases {
            let host = NavigationAuthorityFixture(context: context(backend), backend: backend)
            host.embeddedSyncUnavailable = true
            let core = try executor(host), sceneCommand = try command(host)
            let registry = try UIDestinationRegistry(descriptors: [descriptor()])
            let discovered = try await registry.discover(scene: host.scene, context: host.context, invocation: sceneCommand.invocation, core: core, host: host)
            if backend == .sefariaEmbedded {
                XCTAssertTrue(discovered.isEmpty)
                do { _ = try await sceneCommand.prepareNavigation(using: core, context: host.context); XCTFail("Missing real synchronous epoch proof accepted") } catch {}
            } else {
                XCTAssertEqual(discovered.count, 1)
                let prepared = try await sceneCommand.prepareNavigation(using: core, context: host.context)
                try prepared.authorizeCommit(current: host.scene)
            }
        }
    }
    @MainActor func testEpochDriftAfterImmediateGuardCannotBecomeCompletedReceipt() async throws {
        let host = NavigationAuthorityFixture(context: context(.sefariaEmbedded), backend: .sefariaEmbedded), core = try executor(host)
        let sceneCommand = try command(host), prepared = try await sceneCommand.prepareNavigation(using: core, context: host.context)
        try prepared.authorizeCommit(current: host.scene)
        host.effects += 1 // Synthetic synchronous effect; no atomic cross-actor barrier is claimed.
        host.backend = .init(backend: .sefariaEmbedded, generation: 1, rpcEpoch: 8)
        let receipt = UISceneReceipt(requestId: sceneCommand.invocation.requestId, route: sceneCommand.route.route,
            backendSnapshot: sceneCommand.invocation.snapshot, sceneID: sceneCommand.scene.sceneID, basedOnSceneRevision: 5, appliedSceneRevision: 6)
        XCTAssertThrowsError(try receipt.validate(for: sceneCommand, observed: .init(sceneID: host.scene.sceneID, revision: 6,
            backendSnapshot: host.backend, visibleRoute: sceneCommand.route.route)))
        XCTAssertEqual(host.effects, 1, "Stale receipt is not rollback/no-effect proof")
    }
    @MainActor func testEmptySemanticRoutesCannotSmuggleContentPrivateStateOrFakeActions() async throws {
        let host = NavigationAuthorityFixture(context: context()), settings = descriptor()
        let registry = try UIDestinationRegistry(descriptors: [settings])
        let ref = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42))
        XCTAssertThrowsError(try registry.validate(.init(destination: settings.id, content: .init(sectionLocator: ref))))
        XCTAssertThrowsError(try registry.validate(.init(destination: settings.id, state: .init(privateState: .init(selectedText: "secret")))))
        let fake = descriptor("native.fake", actions: ["system.listBackends"])
        do { _ = try await command(host, descriptor: fake).prepareNavigation(using: executor(host), context: host.context); XCTFail("Fake semantic backing authorized UI-only") } catch {}
        for risk in [0, 1, 3, 4] {
            let invalid = UIDestinationDescriptor(id: settings.id, title: "Invalid", implementation: .implemented,
                supportedBackends: [.otzaria], presentations: [.currentTab], riskTier: risk)
            XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [invalid]))
        }
    }
    @MainActor func testFullCommandBindingAndTrustedSceneRevisionStillRequired() async throws {
        let host = NavigationAuthorityFixture(context: context()), core = try executor(host)
        let prepared = try await command(host).prepareNavigation(using: core, context: host.context)
        let wrong = UISceneSnapshot(sceneID: host.scene.sceneID, revision: host.sceneRevision + 1, backendSnapshot: host.backend)
        XCTAssertThrowsError(try prepared.authorizeCommit(current: wrong))
        XCTAssertEqual(prepared.command.route.route.destination.rawValue, "native.settings")
        try prepared.authorizeCommit(current: host.scene)
    }
    @MainActor func testReaderStillUsesResolverSinkGuardAndExactReceiptAllBackends() async throws {
        for backend in ActionBackendID.allCases {
            let host = NavigationAuthorityFixture(context: context(backend, works: [backend: ["fixture:work"]]), backend: backend)
            let core = try executor(host)
            let descriptor = descriptor("native.reader", actions: ["reader.open"], content: true)
            let registry = try UIDestinationRegistry(descriptors: [descriptor])
            let ref = ActionTextRef(backend: backend, workKey: "fixture:work", position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1"))
            let destination = ActionReaderDestination(sectionLocator: ref)
            let request = ActionRequest(action: "reader.open", arguments: ["sectionLocator": try .encoded(ref)], expectedBackend: backend)
            host.onReader = { reader in
                let route = RouteSpec(requestId: request.requestId, destination: descriptor.id, backend: backend, content: destination,
                    presentation: .init(tabID: .init(rawValue: "native-tab")))
                let scene = host.scene
                let command = try UISceneCommand(route: registry.validate(route), invocation: reader.invocation, scene: scene)
                let prepared = try command.prepareNavigation(readerCommand: reader)
                try prepared.authorizeCommit(current: scene)
                host.effects += 1
                let receipt = ActionUIReceipt(requestId: reader.invocation.requestId, snapshot: reader.invocation.snapshot, sceneID: reader.sceneID, destination: reader.destination)
                let uiReceipt = UISceneReceipt(requestId: request.requestId, route: command.route.route, backendSnapshot: host.backend, sceneID: scene.sceneID,
                    basedOnSceneRevision: scene.revision, appliedSceneRevision: scene.revision + 1, coreReceipt: receipt)
                try prepared.validateCompletion(receipt: uiReceipt, observed: .init(sceneID: scene.sceneID, revision: scene.revision + 1,
                    backendSnapshot: host.backend, visibleRoute: command.route.route))
                return .acknowledged(receipt)
            }
            let result = await core.execute(request, context: host.context)
            XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
            XCTAssertEqual(host.resolutions, 1); XCTAssertEqual(host.readerCalls, 1); XCTAssertEqual(host.effects, 1)
        }
    }
    @MainActor func testReaderCannotBypassResolverOrForgePreparationAndRevocationBeforeCommit() async throws {
        let host = NavigationAuthorityFixture(context: context(works: [.otzaria: ["fixture:work"]])), core = try executor(host)
        let descriptor = descriptor("native.reader", actions: ["reader.open"], content: true), registry = try UIDestinationRegistry(descriptors: [descriptor])
        let ref = ActionTextRef(backend: .otzaria, workKey: "fixture:work", position: .legacyLine(42))
        let destination = ActionReaderDestination(sectionLocator: ref)
        let route = RouteSpec(destination: descriptor.id, backend: .otzaria, content: destination, presentation: .init(tabID: .init(rawValue: "native-tab")))
        let invocation = ActionPortInvocation(requestId: route.requestId, snapshot: host.backend, deadlineUptimeNanoseconds: UInt64.max)
        let command = try UISceneCommand(route: registry.validate(route), invocation: invocation, scene: host.scene)
        do { _ = try await command.prepareNavigation(using: core, context: host.context); XCTFail("UI-only seam authorized content") } catch {}
        XCTAssertThrowsError(try command.prepareNavigation(readerCommand: .init(destination: destination, sceneID: host.sceneID, invocation: invocation)))
        let surface = try await core.prepareNavigation(sceneID: host.sceneID, invocation: invocation, context: host.context)
        let forged = try command.prepareNavigation(readerCommand: .init(destination: destination, sceneID: host.sceneID, invocation: invocation, navigationAuthorization: surface))
        XCTAssertThrowsError(try forged.authorizeCommit(current: host.scene))
        host.onReader = { reader in
            host.active = false
            guard let auth = reader.navigationAuthorization else { throw ActionPortError.unavailable }
            try auth.authorizeCommit(invocation: reader.invocation, sceneID: reader.sceneID, destination: reader.destination)
            host.effects += 1
            return .acknowledged(.init(requestId: reader.invocation.requestId, snapshot: reader.invocation.snapshot, sceneID: reader.sceneID, destination: reader.destination))
        }
        let result = await core.execute(.init(action: "reader.open", arguments: ["sectionLocator": try .encoded(ref)], expectedBackend: .otzaria), context: host.context)
        XCTAssertEqual(result.status, .failed); XCTAssertEqual(host.effects, 0)
        XCTAssertEqual(host.resolutions, 1); XCTAssertEqual(host.readerCalls, 1)
    }
}

/// One trusted live authority instance is injected into the actual Core actor.
/// Synthetic MainActor state and effects, not a native UI acceptance fixture.
@MainActor private final class NavigationAuthorityFixture: ActionNavigationAuthority, ActionSynchronousBackendStatePort, ActionResolverPort, ActionSearchPort,
    ActionUICommandSink, UIDestinationEligibilityPort {
    var context: ActionExecutionContext
    var backend: ActionBackendSnapshot
    var sceneID = "native-scene"
    var sceneRevision: UInt64 = 5
    var lifetimeID = UUID()
    var authorityRevision: UInt64 = 1
    var active = true
    var resolutions = 0
    var searches = 0
    var readerCalls = 0
    var effects = 0
    var embeddedSyncUnavailable = false
    var onReader: (@MainActor @Sendable (ActionOpenReaderCommand) throws -> ActionUIAcknowledgement)?
    var scene: UISceneSnapshot { .init(sceneID: .init(rawValue: sceneID)!, revision: sceneRevision, backendSnapshot: backend) }
    init(context: ActionExecutionContext, backend: ActionBackendID = .otzaria) {
        self.context = context; self.backend = .init(backend: backend, generation: 1, rpcEpoch: backend == .sefariaEmbedded ? 7 : nil)
    }
    func navigationState(sceneID: String) throws -> ActionNavigationState {
        guard sceneID == self.sceneID else { throw ActionPortError.unavailable }
        return .init(context: context, sceneID: self.sceneID, lifetimeID: lifetimeID, authorityRevision: authorityRevision, active: active)
    }
    func currentBackendSnapshot() throws -> ActionBackendSnapshot {
        if embeddedSyncUnavailable && backend.backend == .sefariaEmbedded { throw ActionPortError.unavailable }
        return backend
    }
    func snapshot() async throws -> ActionBackendSnapshot { backend }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport {
        .init(id: backend, operations: Dictionary(uniqueKeysWithValues: ActionRegistry.implemented.map { ($0, .init(registered: true, supported: true, availableNow: true)) }))
    }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment { .init(registered: true, supported: true, availableNow: true) }
    func resolveWork(_ query: ActionResolveWorkQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionWorkRef> { throw ActionPortError.unavailable }
    func resolveReference(_ query: ActionResolveReferenceQuery, invocation: ActionPortInvocation) async throws -> ActionResolution<ActionTextRef> { throw ActionPortError.unavailable }
    func validateDestination(_ destination: ActionReaderDestination, invocation: ActionPortInvocation) async throws -> ActionReaderDestination { resolutions += 1; return destination }
    func search(_ query: ActionSearchQuery, invocation: ActionPortInvocation) async throws -> ActionSearchPage { searches += 1; throw ActionPortError.unavailable }
    func open(_ command: ActionOpenReaderCommand) async throws -> ActionUIAcknowledgement {
        readerCalls += 1
        guard let onReader else { throw ActionPortError.unavailable }
        return try onReader(command)
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        guard sceneID.rawValue == self.sceneID else { throw ActionPortError.unavailable }; return scene
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext,
                invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        .init(sceneID: self.scene.sceneID, sceneRevision: sceneRevision, backendSnapshot: backend, supported: true, ready: true, allowed: true)
    }
}
private struct AsyncOnlyNavigationState: ActionBackendStatePort {
    let host: NavigationAuthorityFixture
    func snapshot() async throws -> ActionBackendSnapshot { try await host.snapshot() }
    func report(for backend: ActionBackendID) async throws -> ActionBackendReport { try await host.report(for: backend) }
    func assess(action: String, arguments: ActionObject, invocation: ActionPortInvocation) async throws -> ActionCapabilityAssessment {
        try await host.assess(action: action, arguments: arguments, invocation: invocation)
    }
}
