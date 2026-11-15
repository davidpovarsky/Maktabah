import Foundation
import XCTest
import OtzariaActionCore
@testable import OtzariaUIRouting

final class PublicNavigationV2Tests: XCTestCase, @unchecked Sendable {
    private let settings = UIDestinationID(rawValue: "test.settings")!
    private let history = UIDestinationID(rawValue: "test.history")!
    private let reader = UIDestinationID(rawValue: "test.reader")!
    private let font = UIDestinationID(rawValue: "test.settings.fontSize")!
    private let appearance = UIDestinationID(rawValue: "test.settings.appearance")!
    private let links = UIDestinationID(rawValue: "test.reader.links")!
    private let info = UIDestinationID(rawValue: "test.reader.info")!
    private func registry() throws -> UIDestinationRegistry {
        let settings = UIDestinationDescriptor(id: settings, title: "Synthetic settings", implementation: .implemented,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .sheet], anchors: [font, appearance],
            publicNavigationV2: .init(rules: [.init(presentation: .currentTab), .init(presentation: .sheet, components: [font, appearance])]))
        let history = UIDestinationDescriptor(id: history, title: "Synthetic history", implementation: .implemented,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab], allowsPublicRoute: true,
            publicNavigationV2: .init(rules: [.init(presentation: .currentTab)]))
        let reader = UIDestinationDescriptor(id: reader, title: "Synthetic reader", implementation: .implemented,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .newTab, .sheet, .inspector], anchors: [links, info],
            requiredCoreActions: ["reader.open"], requiresContent: true, allowsPublicRoute: true,
            publicNavigationV2: .init(rules: [.init(presentation: .currentTab), .init(presentation: .newTab),
                .init(presentation: .sheet, allowsRoot: false, components: [info]), .init(presentation: .inspector, components: [links])]))
        return try UIDestinationRegistry(descriptors: [settings, history, reader])
    }
    private func content(_ backend: ActionBackendID, mode: ActionReaderDestination.PresentationMode = .sameTab) -> ActionReaderDestination {
        .init(sectionLocator: .init(backend: backend, workKey: "fixture:work", position: backend == .otzaria ? .legacyLine(42) : .canonicalRef("Fixture 1:1")), presentationMode: mode)
    }
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }
    private func wire(_ object: ActionObject) throws -> Data { try JSONEncoder().encode(ActionJSON.object(object)) }
    @MainActor private func source(_ backend: ActionBackendID = .otzaria) -> NavigationAuthorityFixture {
        .init(context: .init(subjectID: "public-v2-native", origin: .deepLink, allowedBackends: [backend], contentRights: [backend],
            scopes: [.discovery, .contentRead, .navigation], foregroundSceneID: "native-scene", pairedDeviceAvailable: true), backend: backend)
    }
    @MainActor private func core(_ source: NavigationAuthorityFixture) throws -> ActionExecutor {
        try ActionExecutor(state: source, resolver: source, search: source, ui: source, navigationAuthority: source)
    }
    @MainActor private func invocation(_ source: NavigationAuthorityFixture, deadline: UInt64 = UInt64.max) -> ActionPortInvocation {
        .init(requestId: UUID(), snapshot: source.backend, deadlineUptimeNanoseconds: deadline)
    }
    func testNewGoldensAndAllBackendPresentationRoundTrips() throws {
        let registry = try registry()
        let settings = try UIRouteCodec.decodePublicV2(fixture("public-settings-v2"), registry: registry)
        XCTAssertEqual(settings.presentation, .sheet); XCTAssertEqual(settings.component, font)
        let inspector = try UIRouteCodec.decodePublicV2(fixture("public-inspector-v2"), registry: registry)
        XCTAssertEqual(inspector.presentation, .inspector); XCTAssertEqual(inspector.component, links)
        for backend in ActionBackendID.allCases {
            for presentation in PublicNavigationSpecV2.Presentation.allCases {
                let component = presentation == .sheet ? info : presentation == .inspector ? links : nil
                let input = PublicNavigationSpecV2(destination: reader, content: content(backend, mode: presentation == .newTab ? .newTab : .sameTab),
                    presentation: presentation, component: component)
                let data = try UIRouteCodec.encodePublicV2(input, registry: registry)
                let decoded = try UIRouteCodec.decodePublicV2(data, registry: registry)
                XCTAssertEqual(decoded.backend, backend); XCTAssertEqual(decoded.content, input.content)
                XCTAssertEqual(decoded.component, component); XCTAssertEqual(decoded.presentation, presentation)
                let fields = try ActionWireCodec.decodeObject(data)
                XCTAssertNil(fields["requestId"]); XCTAssertNil(fields["state"]); XCTAssertNil(fields["scene"])
            }
        }
    }
    func testDecodedIntentMustFitBudgetAfterBackendNormalization() throws {
        let registry = try registry(), encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var boundary: Data?, belowBoundary: Data?
        for count in 1...512 {
            let ref = ActionTextRef(backend: .sefaria, workKey: "fixture:work", position: .canonicalRef(String(repeating: "📖", count: count)))
            let destination = ActionReaderDestination(sectionLocator: ref, focusLocator: ref)
            let input = PublicNavigationSpecV2(destination: reader, content: destination, presentation: .inspector, component: links)
            let raw = try encoder.encode(input)
            let normalized = PublicNavigationSpecV2(destination: reader, backend: .sefaria, content: destination, presentation: .inspector, component: links)
            let normalizedBytes = try encoder.encode(normalized)
            if raw.count <= UIRouteCodec.maxPublicBytes && normalizedBytes.count > UIRouteCodec.maxPublicBytes {
                boundary = raw
                break
            }
            if normalizedBytes.count <= UIRouteCodec.maxPublicBytes { belowBoundary = raw }
        }
        let raw = try XCTUnwrap(boundary, "No normalization boundary exercised")
        XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(raw, registry: registry)) {
            XCTAssertEqual(($0 as? UIRouteError)?.code, "public_route_too_large")
        }
        let accepted = try UIRouteCodec.decodePublicV2(XCTUnwrap(belowBoundary), registry: registry)
        let encoded = try UIRouteCodec.encodePublicV2(accepted, registry: registry)
        XCTAssertLessThanOrEqual(encoded.count, UIRouteCodec.maxPublicBytes)
        XCTAssertEqual(try UIRouteCodec.decodePublicV2(encoded, registry: registry), accepted)
    }
    func testV1IsFrozenAndMigrationIsExplicitOptInWithoutImportedCorrelation() throws {
        let registry = try registry(), id = UUID()
        let v1 = PublicRouteSpec(requestId: id, destination: history)
        let bytes = try UIRouteCodec.encodePublic(v1, registry: registry)
        XCTAssertEqual(try UIRouteCodec.decodePublic(bytes, registry: registry), v1)
        XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(bytes, registry: registry))
        let migrated = try UIRouteCodec.migratePublicV1ToV2(bytes, registry: registry)
        let v2 = try UIRouteCodec.encodePublicV2(migrated, registry: registry)
        XCTAssertFalse(String(decoding: v2, as: UTF8.self).contains(id.uuidString))
        XCTAssertThrowsError(try UIRouteCodec.decodePublic(v2, registry: registry))
        XCTAssertThrowsError(try UIRouteCodec.decodePrivate(v2, registry: registry))
        let oldReader = PublicRouteSpec(destination: reader, content: content(.sefaria, mode: .newTab), presentation: .newTab)
        let migratedReader = try UIRouteCodec.migratePublicV1ToV2(UIRouteCodec.encodePublic(oldReader, registry: registry), registry: registry)
        XCTAssertEqual(migratedReader.content, oldReader.content); XCTAssertEqual(migratedReader.presentation, .newTab)
        // Opting settings into v2 does not enable its formerly refused v1 URL.
        XCTAssertThrowsError(try UIRouteCodec.encodePublic(.init(destination: settings), registry: registry))
        let privateOnly = UIDestinationDescriptor(id: .init(rawValue: "test.v1Only")!, title: "V1 only", implementation: .implemented,
            supportedBackends: [.otzaria], presentations: [.currentTab], allowsPublicRoute: true)
        let oldRegistry = try UIDestinationRegistry(descriptors: [privateOnly])
        let old = try UIRouteCodec.encodePublic(.init(destination: privateOnly.id), registry: oldRegistry)
        XCTAssertThrowsError(try UIRouteCodec.migratePublicV1ToV2(old, registry: oldRegistry))
        let descriptorData = try JSONEncoder().encode(privateOnly)
        XCTAssertEqual(try JSONDecoder().decode(UIDestinationDescriptor.self, from: descriptorData), privateOnly)
        XCTAssertFalse(String(decoding: descriptorData, as: UTF8.self).contains("publicNavigationV2"))
    }
    func testExactVariantAllowlistNeverGuessesAnchorOrPresentation() throws {
        let registry = try registry()
        let invalid = [
            PublicNavigationSpecV2(destination: settings, presentation: .inspector),
            .init(destination: settings, presentation: .currentTab, component: font),
            .init(destination: settings, presentation: .sheet, component: links),
            .init(destination: reader, content: content(.otzaria), presentation: .sheet),
            .init(destination: .init(rawValue: "unknown.destination")!),
            .init(destination: reader, backend: .sefaria, content: content(.otzaria), presentation: .inspector)
        ]
        for input in invalid { XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(input, registry: registry)) }
    }
    func testStrictClosedSchemaRejectsPrivateAuthorityAndMutationPayloads() throws {
        let registry = try registry(), base = try ActionWireCodec.decodeObject(fixture("public-settings-v2"))
        for key in ["requestId", "scene", "sceneID", "tabID", "workspaceID", "profileID", "sessionID", "state", "focus", "selectedItemID",
                    "expectedBackendSnapshot", "context", "permissions", "authorityRevision", "draftNote", "selectedText", "search", "query",
                    "settingValue", "value", "save", "selector", "swiftType", "jsMethod", "path"] {
            var fields = base; fields[key] = .string("injected")
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(fields), registry: registry), key)
        }
        for value in ["../../font", "UIView.setValue:", "test.settings.fontSize\n", "file:private", "rpc.execute", "test.settings.unknown"] {
            var fields = base; fields["component"] = .string(value)
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(fields), registry: registry), value)
        }
        for presentation in ["newWindow", "popover", "sidebar", "setValue", "sheet\n"] {
            var fields = base; fields["presentation"] = .string(presentation)
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(fields), registry: registry))
        }
        var nested = base; nested["presentation"] = .object(["kind": .string("sheet"), "tabID": .string("private-tab")])
        XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(wire(nested), registry: registry))
    }
    func testSingleParserRejectsDuplicatesFractionsUnknownVersionsAndOversize() throws {
        let registry = try registry(), original = String(decoding: try fixture("public-settings-v2"), as: UTF8.self)
        for key in ["version", "ver\\u0073ion"] {
            let duplicate = "{\"\(key)\":2," + original.dropFirst()
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(Data(duplicate.utf8), registry: registry))
        }
        for token in ["1", "0", "3", "2.00000000000000000001", "1e-999", "true", "null"] {
            let bad = original.replacingOccurrences(of: "\"version\": 2", with: "\"version\": \(token)")
            XCTAssertNotEqual(bad, original)
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(Data(bad.utf8), registry: registry))
        }
        for raw in ["[]", "null", "{", String(repeating: "[", count: 18) + "0" + String(repeating: "]", count: 18)] {
            XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(Data(raw.utf8), registry: registry))
        }
        XCTAssertThrowsError(try UIRouteCodec.decodePublicV2(Data(repeating: 32, count: 4097), registry: registry))
    }
    func testPublicReferencesRejectPrivateRevisionsPathsSchemesAndCrossWork() throws {
        let registry = try registry(), original = content(.sefaria)
        for token in ["/private/book", "C:private", "file:secret", "https:secret", "javascript:alert", "data:secret", "book?private", "book#secret", "book\nsecret"] {
            let ref = ActionTextRef(backend: .sefaria, workKey: token, position: original.sectionLocator.position)
            XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: reader, content: .init(sectionLocator: ref), presentation: .inspector), registry: registry))
            let badPosition = ActionTextRef(backend: .sefaria, workKey: "fixture:work", position: .canonicalRef(token))
            XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: reader, content: .init(sectionLocator: badPosition), presentation: .inspector), registry: registry))
        }
        for ref in [ActionTextRef(backend: .sefaria, workKey: "fixture:work", position: original.sectionLocator.position, catalogRevision: "private"),
                    .init(backend: .sefaria, workKey: "fixture:work", position: original.sectionLocator.position, dataRevision: "private")] {
            XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: reader, content: .init(sectionLocator: ref), presentation: .inspector), registry: registry))
        }
        let focus = ActionTextRef(backend: .sefaria, workKey: "other:work", position: .canonicalRef("Other 1:1"))
        XCTAssertThrowsError(try UIRouteCodec.encodePublicV2(.init(destination: reader,
            content: .init(sectionLocator: original.sectionLocator, focusLocator: focus), presentation: .inspector), registry: registry))
    }
    func testPolicyRegistrationBoundsStagesAndReadOnlySemantics() throws {
        func descriptor(stage: UIDestinationDescriptor.Implementation = .implemented, rules: [UIPublicNavigationPolicyV2.Rule],
                        presentations: [PresentationSpec.Kind] = [.currentTab, .sheet], mutates: Bool = false,
                        actions: [String] = [], requiresContent: Bool = false) -> UIDestinationDescriptor {
            .init(id: settings, title: "Synthetic policy", implementation: stage, supportedBackends: [.otzaria], presentations: presentations,
                anchors: [font], requiredCoreActions: actions, mutatesUserData: mutates, requiresContent: requiresContent,
                publicNavigationV2: .init(rules: rules))
        }
        for invalid in [descriptor(rules: []), descriptor(stage: .fixture, rules: [.init(presentation: .sheet)]),
                        descriptor(rules: [.init(presentation: .sheet), .init(presentation: .sheet)]),
                        descriptor(rules: [.init(presentation: .inspector)]), descriptor(rules: [.init(presentation: .sheet, allowsRoot: false)]),
                        descriptor(rules: [.init(presentation: .sheet, components: [links])]),
                        descriptor(rules: [.init(presentation: .sheet, components: [font, font])]),
                        descriptor(rules: [.init(presentation: .sheet)], mutates: true),
                        descriptor(rules: [.init(presentation: .sheet)], actions: ["notes.prepareDraft"]),
                        descriptor(rules: [.init(presentation: .sheet)], actions: ["reader.open"], requiresContent: false)] {
            XCTAssertThrowsError(try UIDestinationRegistry(descriptors: [invalid]))
        }
        let many = (0..<33).map { i in UIDestinationDescriptor(id: .init(rawValue: "test.limit\(i)")!, title: "Bounded", implementation: .implemented,
            supportedBackends: [.otzaria], presentations: [.currentTab, .newTab, .sheet, .inspector],
            publicNavigationV2: .init(rules: PublicNavigationSpecV2.Presentation.allCases.map { .init(presentation: $0) })) }
        XCTAssertThrowsError(try UIDestinationRegistry(descriptors: many))
    }
    @MainActor func testBindingUsesFreshLocalCorrelationSceneBackendAndOneUseGuard() async throws {
        for backend in ActionBackendID.allCases {
            let source = source(backend), host = PublicV2TestHost(source), core = try core(source), registry = try registry()
            let intent = try UIRouteCodec.decodePublicV2(fixture("public-settings-v2"), registry: registry), invocation = invocation(source)
            let plan = try await registry.bindPublicV2(intent, scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
            guard case .surface(let prepared) = plan else { return XCTFail("Expected guarded UI-only plan") }
            let local = prepared.command.route.route
            XCTAssertEqual(local.requestId, invocation.requestId); XCTAssertEqual(local.backend, backend)
            XCTAssertEqual(local.scene.sceneID, source.scene.sceneID); XCTAssertEqual(local.scene.expectedRevision, source.sceneRevision)
            XCTAssertEqual(local.focus?.anchor, font); XCTAssertNil(local.state.privateState); XCTAssertNil(local.presentation.tabID)
            XCTAssertEqual(source.effects, 0, "Import/binding never activates a control or persists a value")
            try prepared.authorizeCommit(current: source.scene)
            XCTAssertThrowsError(try prepared.authorizeCommit(current: source.scene))
        }
    }
    @MainActor func testDiscoveryReportsOnlyExactVerifiedVariantsAndNoGenericPolicyAdvertisement() async throws {
        let source = source(), host = PublicV2TestHost(source), core = try core(source), registry = try registry(), invocation = invocation(source)
        host.unsupported.insert(PublicV2TestHost.key(settings, .sheet, font))
        let generic = try await registry.discover(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
        XCTAssertFalse(generic.isEmpty); XCTAssertTrue(generic.allSatisfy { $0.publicNavigationV2 == nil })
        let variants = try await registry.discoverPublicV2(scene: source.scene, context: source.context, invocation: invocation, core: core, host: host)
        XCTAssertFalse(variants.contains { $0.destination == settings && $0.presentation == .sheet && $0.component == font })
        XCTAssertTrue(variants.contains { $0.destination == settings && $0.presentation == .sheet && $0.component == appearance })
        XCTAssertLessThanOrEqual(variants.count, 128); XCTAssertEqual(source.effects, 0)
    }
    @MainActor func testRuntimeUnsupportedUnreadyDeniedAndBackendSwitchNeverFallback() async throws {
        let registry = try registry(), intent = try UIRouteCodec.decodePublicV2(fixture("public-settings-v2"), registry: registry)
        for mode in 0..<4 {
            let source = source(), host = PublicV2TestHost(source), core = try core(source)
            if mode == 0 { host.unsupported.insert(PublicV2TestHost.key(settings, .sheet, font)) }
            if mode == 1 { host.ready = false }
            if mode == 2 { host.allowed = false }
            let request = mode == 3 ? PublicNavigationSpecV2(destination: settings, backend: .sefaria, presentation: .sheet, component: font) : intent
            do { _ = try await registry.bindPublicV2(request, scene: source.scene, context: source.context, invocation: invocation(source), core: core, host: host); XCTFail("Unavailable variant bound") }
            catch { XCTAssertEqual((error as? UIRouteError)?.status, [.notSupported, .unavailable, .failed, .requiresBackendSwitch][mode]) }
            XCTAssertEqual(source.effects, 0); XCTAssertEqual(source.backend.backend, .otzaria)
        }
    }
    @MainActor func testRightsAndGenerationRevocationAcrossHostAwaitAreRechecked() async throws {
        let registry = try registry(), intent = try UIRouteCodec.decodePublicV2(fixture("public-settings-v2"), registry: registry)
        for discovery in [false, true] {
          for mode in 0..<3 {
            let source = source(), host = PublicV2TestHost(source), core = try core(source), gate = ReviewGate()
            if discovery { host.variantGate = gate } else { host.navigationGate = gate }
            let original = source.context, scene = source.scene, invocation = invocation(source)
            let task = Task {
                if discovery { _ = try await registry.discoverPublicV2(scene: scene, context: original, invocation: invocation, core: core, host: host) }
                else { _ = try await registry.bindPublicV2(intent, scene: scene, context: original, invocation: invocation, core: core, host: host) }
            }
            let safety = safetyRelease(gate)
            await gate.waitForEntry()
            if mode == 0 { source.active = false }
            if mode == 1 { source.backend = .init(backend: .otzaria, generation: 2) }
            if mode == 2 { source.context = .init(subjectID: original.subjectID, correlationID: original.correlationID, origin: original.origin,
                allowedBackends: original.allowedBackends, contentRights: [], scopes: original.scopes, foregroundSceneID: original.foregroundSceneID,
                pairedDeviceAvailable: original.pairedDeviceAvailable) }
            await gate.release()
            do { _ = try await task.value; XCTFail("Stale/revoked context bound") } catch {}
            let observation = await gate.observation(); XCTAssertFalse(observation.safetyReleased); XCTAssertEqual(observation.pending, 0)
            safety.cancel(); await safety.value
          }
        }
    }
    @MainActor func testDeadlineAndCancellationCleanExactVariantWaits() async throws {
        let registry = try registry(), intent = try UIRouteCodec.decodePublicV2(fixture("public-settings-v2"), registry: registry)
        for discovery in [false, true] {
          for cancel in [false, true] {
            let source = source(), host = PublicV2TestHost(source), core = try core(source), gate = ReviewGate()
            if discovery { host.variantGate = gate } else { host.navigationGate = gate }
            let scene = source.scene, context = source.context
            let invocation = invocation(source, deadline: SystemActionClock().now() + 500_000_000)
            let task = Task {
                if discovery { _ = try await registry.discoverPublicV2(scene: scene, context: context, invocation: invocation, core: core, host: host) }
                else { _ = try await registry.bindPublicV2(intent, scene: scene, context: context, invocation: invocation, core: core, host: host) }
            }
            let safety = safetyRelease(gate)
            await gate.waitForEntry(); if cancel { task.cancel() }
            do { _ = try await task.value; XCTFail("Late/cancelled binding returned a plan") }
            catch is CancellationError { XCTAssertTrue(cancel) }
            catch { XCTAssertEqual((error as? UIRouteError)?.status, .cancelled) }
            let observation = await gate.observation(); XCTAssertFalse(observation.safetyReleased); XCTAssertEqual(observation.pending, 0)
            safety.cancel(); await safety.value
          }
        }
    }
    @MainActor func testReaderBindingRequiresLocalTabAndHostContentRights() async throws {
        let registry = try registry(), source = source(), host = PublicV2TestHost(source), core = try core(source)
        let intent = PublicNavigationSpecV2(destination: reader, content: content(.otzaria), presentation: .inspector, component: links)
        do { _ = try await registry.bindPublicV2(intent, scene: source.scene, context: source.context, invocation: invocation(source), core: core, host: host)
            XCTFail("Public payload invented a missing native tab") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "route_not_prepared") }
        let old = source.context
        source.context = .init(subjectID: old.subjectID, correlationID: old.correlationID, origin: old.origin,
            allowedBackends: old.allowedBackends, contentRights: [], scopes: old.scopes,
            foregroundSceneID: old.foregroundSceneID, pairedDeviceAvailable: old.pairedDeviceAvailable)
        do { _ = try await registry.bindPublicV2(intent, scene: source.scene, localTabID: .init(rawValue: "native-tab"),
            context: source.context, invocation: invocation(source), core: core, host: host)
            XCTFail("Import granted host-denied content rights") }
        catch { XCTAssertEqual((error as? UIRouteError)?.code, "permission_denied") }
        XCTAssertEqual(source.effects, 0); XCTAssertEqual(source.resolutions, 0)
    }
    @MainActor func testReaderPlanUsesFreshCoreSinkInvocationAndCannotBypassSemanticExecution() async throws {
      for backend in ActionBackendID.allCases {
        let registry = try registry(), source = source(backend), host = PublicV2TestHost(source), core = try core(source)
        let intent = PublicNavigationSpecV2(destination: reader, content: content(backend), presentation: .inspector, component: links), invocation = invocation(source)
        let plan = try await registry.bindPublicV2(intent, scene: source.scene, localTabID: .init(rawValue: "native-tab"),
            context: source.context, invocation: invocation, core: core, host: host)
        guard case .reader(let validated) = plan else { return XCTFail("Reader content received a surface grant") }
        XCTAssertEqual(source.resolutions, 0); XCTAssertEqual(source.readerCalls, 0); XCTAssertEqual(source.effects, 0)
        XCTAssertEqual(validated.route.requestId, invocation.requestId); XCTAssertEqual(validated.route.state.inspectorVisible, true)
        source.onReader = { reader in
            let command = try UISceneCommand(route: validated, invocation: reader.invocation, scene: source.scene)
            let prepared = try command.prepareNavigation(readerCommand: reader)
            try prepared.authorizeCommit(current: source.scene); source.effects += 1
            let receipt = ActionUIReceipt(requestId: reader.invocation.requestId, snapshot: reader.invocation.snapshot, sceneID: reader.sceneID, destination: reader.destination)
            let uiReceipt = UISceneReceipt(requestId: validated.route.requestId, route: validated.route, backendSnapshot: source.backend, sceneID: source.scene.sceneID,
                basedOnSceneRevision: 5, appliedSceneRevision: 6, coreReceipt: receipt)
            try prepared.validateCompletion(receipt: uiReceipt, observed: .init(sceneID: source.scene.sceneID, revision: 6, backendSnapshot: source.backend, visibleRoute: validated.route))
            return .acknowledged(receipt)
        }
        let args = try XCTUnwrap(ActionJSON.encoded(intent.content!).object)
        let result = await core.execute(.init(requestId: invocation.requestId, action: "reader.open", arguments: args, expectedBackend: source.backend.backend), context: source.context)
        XCTAssertEqual(result.status, .completed, "\(String(describing: result.error))")
        XCTAssertEqual(source.resolutions, 1); XCTAssertEqual(source.effects, 1)
      }
    }
    @MainActor func testStructuralReaderPlanCannotGrantDeniedWork() async throws {
        for backend in ActionBackendID.allCases {
            let registry = try registry(), source = source(backend), original = source.context
            source.context = .init(subjectID: original.subjectID, correlationID: original.correlationID, origin: original.origin,
                allowedBackends: original.allowedBackends, contentRights: original.contentRights, scopes: original.scopes,
                allowedWorkKeys: [backend: ["different:work"]], foregroundSceneID: original.foregroundSceneID,
                pairedDeviceAvailable: original.pairedDeviceAvailable)
            let core = try core(source), invocation = invocation(source)
            let intent = PublicNavigationSpecV2(destination: reader, content: content(backend), presentation: .inspector, component: links)
            let plan = try await registry.bindPublicV2(intent, scene: source.scene, localTabID: .init(rawValue: "native-tab"),
                context: source.context, invocation: invocation, core: core, host: PublicV2TestHost(source))
            guard case .reader = plan else { return XCTFail("Content received a surface grant") }
            let args = try XCTUnwrap(ActionJSON.encoded(intent.content!).object)
            let result = await core.execute(.init(requestId: invocation.requestId, action: "reader.open", arguments: args,
                expectedBackend: backend), context: source.context)
            XCTAssertEqual(result.status, .failed); XCTAssertEqual(result.error?.code, "permission_denied")
            XCTAssertEqual(source.resolutions, 0); XCTAssertEqual(source.readerCalls, 0); XCTAssertEqual(source.effects, 0)
        }
    }
    @MainActor func testRetainedReaderPlanRejectsGenerationChangedBeforeActualCoreSink() async throws {
        for backend in ActionBackendID.allCases {
            let registry = try registry(), source = source(backend), core = try core(source), invocation = invocation(source)
            let intent = PublicNavigationSpecV2(destination: reader, content: content(backend), presentation: .inspector, component: links)
            let plan = try await registry.bindPublicV2(intent, scene: source.scene, localTabID: .init(rawValue: "native-tab"),
                context: source.context, invocation: invocation, core: core, host: PublicV2TestHost(source))
            guard case .reader(let retained) = plan else { return XCTFail("Content received a surface grant") }
            source.backend = .init(backend: backend, generation: source.backend.generation + 1, rpcEpoch: source.backend.rpcEpoch)
            source.onReader = { reader in
                do {
                    _ = try UISceneCommand(route: retained, invocation: reader.invocation, scene: source.scene)
                    XCTFail("Retained route silently rebound to a newer generation")
                    throw ActionPortError.invalidResponse
                } catch let error as UIRouteError {
                    XCTAssertEqual(error.status, .staleState); XCTAssertEqual(error.code, "backend_generation_changed")
                    // Test host translates the route's refusal into the existing Core port error.
                    throw ActionPortError.staleState
                }
            }
            let args = try XCTUnwrap(ActionJSON.encoded(intent.content!).object)
            let result = await core.execute(.init(requestId: invocation.requestId, action: "reader.open", arguments: args,
                expectedBackend: backend), context: source.context)
            XCTAssertEqual(result.status, .staleState); XCTAssertEqual(result.error?.code, "backend_generation_changed")
            XCTAssertEqual(source.resolutions, 1); XCTAssertEqual(source.readerCalls, 1); XCTAssertEqual(source.effects, 0)
        }
    }
    private func safetyRelease(_ gate: ReviewGate) -> Task<Void, Never> {
        Task { do { try await Task.sleep(nanoseconds: 2_000_000_000); try Task.checkCancellation(); await gate.release(safety: true) } catch {} }
    }
}

/// Exact public host capability checks over the EXISTING shared test authority;
/// this adds no second backend/resolver/permissions implementation.
@MainActor private final class PublicV2TestHost: UIPublicNavigationEligibilityPort {
    let source: NavigationAuthorityFixture
    var unsupported: Set<String> = []
    var ready = true
    var allowed = true
    var navigationGate: ReviewGate?
    var variantGate: ReviewGate?
    init(_ source: NavigationAuthorityFixture) { self.source = source }
    static func key(_ destination: UIDestinationID, _ presentation: PublicNavigationSpecV2.Presentation, _ component: UIDestinationID?) -> String {
        destination.rawValue + ":" + presentation.rawValue + ":" + (component?.rawValue ?? "root")
    }
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UISceneSnapshot {
        try await source.currentScene(sceneID: sceneID, context: context, invocation: invocation)
    }
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        try await source.assess(descriptor, scene: scene, context: context, invocation: invocation)
    }
    func assessPublicVariant(_ variant: UIPublicNavigationVariantV2, scene: UISceneSnapshot, context: ActionExecutionContext,
                             invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        if let variantGate { try await variantGate.wait() }
        return assessment(variant.destination, variant.presentation, variant.component, scene: scene, requiresContent: variant.requiresContent)
    }
    func assessPublicNavigation(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot, context: ActionExecutionContext,
                                invocation: ActionPortInvocation) async throws -> UIRouteEligibility {
        if let navigationGate { try await navigationGate.wait() }
        return assessment(intent.destination, intent.presentation, intent.component, scene: scene, requiresContent: intent.content != nil)
    }
    private func assessment(_ destination: UIDestinationID, _ presentation: PublicNavigationSpecV2.Presentation,
                            _ component: UIDestinationID?, scene: UISceneSnapshot, requiresContent: Bool) -> UIRouteEligibility {
        .init(sceneID: scene.sceneID, sceneRevision: scene.revision, backendSnapshot: scene.backendSnapshot,
            supported: !unsupported.contains(Self.key(destination, presentation, component)), ready: ready,
            allowed: allowed && (!requiresContent || source.context.contentRights.contains(source.backend.backend)))
    }
}
