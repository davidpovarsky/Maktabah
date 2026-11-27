import Foundation
import OtzariaActionCore

public struct UIDestinationRegistry: Sendable {
    public let descriptors: [UIDestinationDescriptor]
    public let migrations: [UIRouteMigration]
    private let byID: [UIDestinationID: UIDestinationDescriptor]

    /// Default is empty, not a fabricated live surface catalog.
    public init(descriptors: [UIDestinationDescriptor] = [], migrations: [UIRouteMigration] = []) throws {
        guard descriptors.count <= 128, migrations.count <= 128, Set(descriptors.map(\.id)).count == descriptors.count else { throw UIRouteError(.failed, "invalid_registry") }
        let core = try ActionRegistry()
        for descriptor in descriptors {
            guard !descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, descriptor.title.unicodeScalars.count <= 256,
                  (0...4).contains(descriptor.riskTier), descriptor.anchors.count <= 64, Set(descriptor.anchors).count == descriptor.anchors.count,
                  Set(descriptor.supportedBackends).count == descriptor.supportedBackends.count,
                  Set(descriptor.presentations).count == descriptor.presentations.count,
                  descriptor.requiredCoreActions.count <= 16, Set(descriptor.requiredCoreActions).count == descriptor.requiredCoreActions.count,
                  descriptor.requiredCoreActions.allSatisfy({ core.descriptor(for: $0) != nil }) else { throw UIRouteError(.failed, "invalid_registry") }
            if descriptor.implementation == .implemented && descriptor.requiredCoreActions.isEmpty {
                guard descriptor.riskTier == 2, !descriptor.mutatesUserData, !descriptor.requiresContent,
                      !descriptor.allowsPrivateState else { throw UIRouteError(.failed, "invalid_registry") }
            }
            try Self.validatePublicNavigationPolicyV2(descriptor)
        }
        guard descriptors.reduce(0, { $0 + Self.publicVariantsV2($1).count }) <= 128 else { throw UIRouteError(.failed, "public_variants_limit") }
        let ids = Set(descriptors.map(\.id))
        guard Set(migrations.map(\.from)).count == migrations.count else { throw UIRouteError(.failed, "invalid_migrations") }
        for migration in migrations {
            guard migration.fromVersion == 0, !ids.contains(migration.from), migration.to == nil || ids.contains(migration.to!) else { throw UIRouteError(.failed, "invalid_migrations") }
        }
        self.descriptors = descriptors; self.migrations = migrations
        byID = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.id, $0) })
    }

    public func descriptor(for id: UIDestinationID) -> UIDestinationDescriptor? { byID[id] }
    public func validate(_ route: RouteSpec) throws -> UIValidatedRoute {
        do { try ActionSchemaValidator.validate(try ActionJSON.encoded(route), schema: UIRouteSchemas.privateRoute()) }
        catch { throw UIRouteError(.failed, "invalid_route_shape") }
        // Use Core's typed position decoder rather than another locator parser.
        do { _ = try ActionJSON.encoded(route).decoded(as: RouteSpec.self) }
        catch { throw UIRouteError(.failed, "invalid_canonical_reference") }
        guard let descriptor = byID[route.destination] else { throw UIRouteError(.notSupported, "unknown_destination") }
        guard descriptor.publicNavigationV2?.searchReferenceKind == nil else {
            throw UIRouteError(.notSupported, "typed_search_continuation_required")
        }
        guard !descriptor.mutatesUserData, descriptor.riskTier < 3 else { throw UIRouteError(.notSupported, "persistent_mutation_not_route") }
        guard descriptor.presentations.contains(route.presentation.kind), !descriptor.requiresContent || route.content != nil else { throw UIRouteError(.notSupported, "unsupported_variant") }
        let anchors = Set(descriptor.anchors)
        guard Set(route.state.visibleComponents).isSubset(of: anchors), Set(route.state.expandedComponents).isSubset(of: anchors) else { throw UIRouteError(.notSupported, "unknown_component") }
        if let sheet = route.state.sheet { guard anchors.contains(sheet), descriptor.presentations.contains(.sheet) else { throw UIRouteError(.notSupported, "unknown_sheet") } }
        if route.state.sidebarVisible == true && !descriptor.presentations.contains(.sidebar) { throw UIRouteError(.notSupported, "sidebar_not_supported") }
        if route.state.inspectorVisible == true && !descriptor.presentations.contains(.inspector) { throw UIRouteError(.notSupported, "inspector_not_supported") }
        var backends = Set<ActionBackendID>()
        if let backend = route.backend { backends.insert(backend) }
        if let snapshot = route.expectedBackendSnapshot { backends.insert(snapshot.backend) }
        if let content = route.content {
            guard descriptor.requiredCoreActions.contains("reader.open") else { throw UIRouteError(.notSupported, "reader_action_required") }
            backends.insert(content.sectionLocator.backend)
            if let focus = content.focusLocator {
                backends.insert(focus.backend)
                guard focus.workKey == content.sectionLocator.workKey else { throw UIRouteError(.failed, "cross_work_focus") }
            }
            let createsTab = route.presentation.kind == .newTab || route.presentation.kind == .newWindow
            guard (content.presentationMode == .newTab) == createsTab else { throw UIRouteError(.failed, "presentation_conflict") }
        }
        let canonicalFocus = route.content.map { $0.focusLocator ?? $0.sectionLocator }
        if let focus = route.focus {
            switch focus.kind {
            case .component:
                guard let anchor = focus.anchor, anchors.contains(anchor), focus.locator == nil, focus.range == nil else { throw UIRouteError(.failed, "invalid_component_focus") }
            case .content, .selection:
                guard let ref = focus.locator, focus.anchor == nil, ref == canonicalFocus else { throw UIRouteError(.failed, "invalid_content_focus") }
                backends.insert(ref.backend)
                if focus.kind == .selection {
                    guard let range = focus.range, range.location <= 1_000_000_000,
                          range.length <= 10_000, range.location <= 1_000_000_000 - range.length else { throw UIRouteError(.failed, "invalid_selection_range") }
                } else if focus.range != nil { throw UIRouteError(.failed, "unexpected_selection_range") }
            }
        }
        if let scroll = route.state.scrollAnchor {
            backends.insert(scroll.backend)
            guard scroll == route.content?.sectionLocator || scroll == route.content?.focusLocator else { throw UIRouteError(.failed, "unbound_scroll_anchor") }
        }
        if let privateState = route.state.privateState {
            guard descriptor.allowsPrivateState else { throw UIRouteError(.notSupported, "private_state_not_supported") }
            if let search = privateState.search {
                guard descriptor.requiredCoreActions.contains("search.query") else { throw UIRouteError(.notSupported, "search_action_required") }
                backends.insert(search.backend)
                for ref in search.scopeWorkRefs { backends.insert(ref.backend) }
            }
            if privateState.draftNote != nil && !descriptor.requiredCoreActions.contains("notes.prepareDraft") { throw UIRouteError(.notSupported, "draft_action_required") }
        }
        guard backends.count <= 1 else { throw UIRouteError(.failed, "conflicting_backends") }
        let backend = backends.first
        if let backend, !descriptor.supportedBackends.contains(backend) { throw UIRouteError(.notSupported, "backend_variant_not_supported") }
        if route.scene.kind == .specific {
            guard route.scene.sceneID != nil else { throw UIRouteError(.failed, "missing_scene_id") }
        } else if route.scene.sceneID != nil { throw UIRouteError(.failed, "unexpected_scene_id") }
        guard (route.scene.kind == .newWindow) == (route.presentation.kind == .newWindow) else { throw UIRouteError(.failed, "scene_presentation_conflict") }
        let normalized = RouteSpec(version: route.version, requestId: route.requestId, destination: route.destination, backend: backend,
            content: route.content, presentation: route.presentation, state: route.state, focus: route.focus, scene: route.scene, expectedBackendSnapshot: route.expectedBackendSnapshot)
        return UIValidatedRoute(route: normalized, descriptor: descriptor)
    }

    /// Host variant assessment supplements, never replaces, Core authorization.
    /// No shipped fixture/inventory descriptor can appear in live discovery.
    /// The original invocation deadline/cancellation covers every awaited port,
    /// including Core advertisement and current-scene observations. Timely return
    /// requires cooperative ports; this is not an uncooperative-worker boundary.
    public func discover(scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation,
                         core: ActionExecutor, host: any UIDestinationEligibilityPort, clock: any ActionClock = SystemActionClock()) async throws -> [UIDestinationDescriptor] {
        try Task.checkCancellation()
        guard invocation.snapshot == scene.backendSnapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
        if invocation.snapshot.backend == .sefariaEmbedded && invocation.snapshot.rpcEpoch == nil { throw UIRouteError(.unavailable, "rpc_epoch_unavailable") }
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let candidates = descriptors.filter { $0.implementation == .implemented && !$0.mutatesUserData && $0.riskTier < 3 && $0.supportedBackends.contains(scene.backendSnapshot.backend)
            && $0.publicNavigationV2?.searchReferenceKind == nil }
        guard !candidates.isEmpty else { return [] }
        return try await UIDiscoveryCancellationScope.run(until: invocation.deadlineUptimeNanoseconds, clock: clock) {
            try await discoverCurrent(candidates: candidates, scene: scene, context: context, invocation: invocation, core: core, host: host, clock: clock)
        }
    }

    func requireCurrentScene(_ scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation,
                                     host: any UIDestinationEligibilityPort, clock: any ActionClock) async throws {
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let current = try await host.currentScene(sceneID: scene.sceneID, context: context, invocation: invocation)
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        if current.backendSnapshot.backend == .sefariaEmbedded && current.backendSnapshot.rpcEpoch == nil { throw UIRouteError(.unavailable, "rpc_epoch_unavailable") }
        guard current.sceneID == scene.sceneID, current.revision == scene.revision,
              current.backendSnapshot == invocation.snapshot else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
    }

    private func discoverCurrent(candidates: [UIDestinationDescriptor], scene: UISceneSnapshot, context: ActionExecutionContext,
                                 invocation: ActionPortInvocation, core: ActionExecutor, host: any UIDestinationEligibilityPort,
                                 clock: any ActionClock) async throws -> [UIDestinationDescriptor] {
        try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        let coreIDs = Set(await core.advertisedActions(for: scene.backendSnapshot.backend, context: context).map(\.id))
        try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
        var result: [UIDestinationDescriptor] = []
        for descriptor in candidates where Set(descriptor.requiredCoreActions).isSubset(of: coreIDs) {
            if descriptor.requiredCoreActions.isEmpty {
                do { try await core.checkNavigationDiscovery(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context) }
                catch { continue }
            }
            try Task.checkCancellation()
            guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
            let assessment = try await host.assess(descriptor, scene: scene, context: context, invocation: invocation)
            try Task.checkCancellation()
            guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
            guard assessment.sceneID == scene.sceneID, assessment.sceneRevision == scene.revision,
                  assessment.backendSnapshot == scene.backendSnapshot else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            if assessment.supported && assessment.ready && assessment.allowed { result.append(descriptor.withoutPublicNavigationV2()) }
        }
        try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
        return result
    }

    /// Synthetic metadata only, never a claim about an installed native surface.
    public static func fixtures() throws -> UIDestinationRegistry {
        func id(_ string: String) -> UIDestinationID { UIDestinationID(rawValue: string)! }
        let reader = UIDestinationDescriptor(id: id("fixture.reader"), title: "Synthetic reader — not native", implementation: .fixture,
            supportedBackends: ActionBackendID.allCases, presentations: PresentationSpec.Kind.allCases,
            anchors: [id("fixture.reader.text"), id("fixture.reader.toc"), id("fixture.reader.inspector"), id("fixture.reader.noteSheet")],
            requiredCoreActions: ["reader.open"], requiresContent: true, allowsPublicRoute: true)
        let notes = UIDestinationDescriptor(id: id("fixture.notes"), title: "Synthetic draft — never persisted", implementation: .fixture,
            supportedBackends: ActionBackendID.allCases, presentations: [.sheet, .currentTab], anchors: [id("fixture.notes.editor")],
            requiredCoreActions: ["reader.open", "notes.prepareDraft"], requiresContent: true, allowsPrivateState: true)
        let settings = UIDestinationDescriptor(id: id("fixture.settings"), title: "Synthetic settings — no mutation", implementation: .fixture,
            supportedBackends: ActionBackendID.allCases, presentations: [.currentTab, .sheet], anchors: [id("fixture.settings.language")])
        return try UIDestinationRegistry(descriptors: [reader, notes, settings], migrations: [
            UIRouteMigration(fromVersion: 0, from: id("fixture.legacyReader"), to: reader.id),
            UIRouteMigration(fromVersion: 0, from: id("fixture.removed"), to: nil)
        ])
    }
}
