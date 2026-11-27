import Foundation
import OtzariaActionCore

extension UIDestinationRegistry {
    static func validatePublicNavigationPolicyV2(_ descriptor: UIDestinationDescriptor) throws {
        guard let policy = descriptor.publicNavigationV2 else { return }
        guard descriptor.implementation == .implemented, !descriptor.mutatesUserData, descriptor.riskTier == 2,
              !descriptor.supportedBackends.isEmpty,
              descriptor.requiredCoreActions.isEmpty || descriptor.requiredCoreActions == ["reader.open"],
              descriptor.requiresContent == (descriptor.requiredCoreActions == ["reader.open"]),
              (1...4).contains(policy.rules.count), Set(policy.rules.map(\.presentation)).count == policy.rules.count else {
            throw UIRouteError(.failed, "invalid_public_policy")
        }
        if let kind = policy.searchReferenceKind {
            guard descriptor.id == kind.destination, descriptor.requiredCoreActions.isEmpty,
                  !descriptor.requiresContent, !descriptor.allowsPrivateState, descriptor.anchors.isEmpty,
                  descriptor.presentations == [.currentTab], policy.rules.count == 1,
                  policy.rules[0].presentation == .currentTab, !policy.rules[0].allowsRoot,
                  policy.rules[0].components.isEmpty else {
                throw UIRouteError(.failed, "invalid_public_policy")
            }
        }
        for rule in policy.rules {
            guard descriptor.presentations.contains(rule.presentation.nativeKind), rule.components.count <= 16,
                  rule.allowsRoot || !rule.components.isEmpty || policy.searchReferenceKind != nil,
                  Set(rule.components).count == rule.components.count,
                  Set(rule.components).isSubset(of: Set(descriptor.anchors)) else { throw UIRouteError(.failed, "invalid_public_policy") }
        }
    }

    static func publicVariantsV2(_ descriptor: UIDestinationDescriptor) -> [UIPublicNavigationVariantV2] {
        // A reference-required operation is not an unresolved root. Only its
        // typed live catalog may advertise an actual selectable target.
        guard descriptor.publicNavigationV2?.searchReferenceKind == nil else { return [] }
        return (descriptor.publicNavigationV2?.rules ?? []).flatMap { rule in
            var components: [UIDestinationID?] = rule.components.map(Optional.some)
            if rule.allowsRoot { components.insert(nil, at: 0) }
            return components.map { UIPublicNavigationVariantV2(destination: descriptor.id, presentation: rule.presentation, component: $0, requiresContent: descriptor.requiresContent) }
        }
    }

    func validatePublicNavigationV2(_ intent: PublicNavigationSpecV2) throws -> PublicNavigationSpecV2 {
        guard let descriptor = descriptor(for: intent.destination), descriptor.implementation == .implemented,
              let policy = descriptor.publicNavigationV2,
              let rule = policy.rules.first(where: { $0.presentation == intent.presentation }) else {
            throw UIRouteError(.notSupported, "public_variant_not_supported")
        }
        if let kind = policy.searchReferenceKind {
            guard descriptor.id == kind.destination, let backend = intent.backend,
                  intent.presentation == .currentTab, intent.content == nil, intent.component == nil,
                  let reference = intent.searchReference, reference.utf8.count == 36,
                  let parsed = UUID(uuidString: reference), parsed.uuidString.lowercased() == reference else {
                throw UIRouteError(.failed, "invalid_public_search_reference")
            }
            guard descriptor.supportedBackends.contains(backend) else {
                throw UIRouteError(.notSupported, "backend_variant_not_supported")
            }
            // A finite metadata reference is not a private RouteSpec. Its
            // dedicated source-bound executor must still resolve it and obtain
            // the original Core operation authority. No generic plan exists.
            return intent
        } else {
            guard intent.searchReference == nil else { throw UIRouteError(.failed, "invalid_public_route") }
            guard intent.component.map({ rule.components.contains($0) }) ?? rule.allowsRoot else {
                throw UIRouteError(.notSupported, "public_variant_not_supported")
            }
        }
        let localShape = RouteSpec(destination: intent.destination, backend: intent.backend, content: intent.content,
            presentation: .init(kind: intent.presentation.nativeKind),
            focus: intent.component.map { .init(kind: .component, anchor: $0) })
        let normalized = try validate(localShape)
        return .init(version: intent.version, destination: intent.destination, backend: normalized.route.backend,
            content: intent.content, presentation: intent.presentation, component: intent.component,
            searchReference: intent.searchReference)
    }

    private func requirePublicAssessment(_ assessment: UIRouteEligibility, scene: UISceneSnapshot) throws {
        guard assessment.sceneID == scene.sceneID, assessment.sceneRevision == scene.revision,
              assessment.backendSnapshot == scene.backendSnapshot else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
    }

    /// Enumerate only exact host-verified public combinations. Static policy and
    /// generic discovery alone are not live variant capabilities or grants.
    public func discoverPublicV2(scene: UISceneSnapshot, context: ActionExecutionContext, invocation: ActionPortInvocation,
                                 core: ActionExecutor, host: any UIPublicNavigationEligibilityPort,
                                 clock: any ActionClock = SystemActionClock()) async throws -> [UIPublicNavigationVariantV2] {
        try await UIDiscoveryCancellationScope.run(until: invocation.deadlineUptimeNanoseconds, clock: clock) {
            let eligible = Set(try await discover(scene: scene, context: context, invocation: invocation, core: core, host: host, clock: clock).map(\.id))
            var result: [UIPublicNavigationVariantV2] = []
            for descriptor in descriptors where eligible.contains(descriptor.id) {
                for variant in Self.publicVariantsV2(descriptor) {
                    let assessment = try await host.assessPublicVariant(variant, scene: scene, context: context, invocation: invocation)
                    try requirePublicAssessment(assessment, scene: scene)
                    try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
                    try await core.checkNavigationDiscovery(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context)
                    if assessment.supported && assessment.ready && assessment.allowed { result.append(variant) }
                }
            }
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            if !result.isEmpty { try await core.checkNavigationDiscovery(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context) }
            return result
        }
    }

    /// Bind a public intent to fresh trusted LOCAL state. The URL carries no
    /// correlation, tab, scene, revision or rights. No backend is switched.
    /// The reader plan is structural: canonical reader.open/resolver/sink and
    /// exact receipts are still mandatory; no content grant is minted here.
    @MainActor public func bindPublicV2(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot,
                             context: ActionExecutionContext, invocation: ActionPortInvocation, core: ActionExecutor,
                             host: any UIPublicNavigationBindingPort, clock: any ActionClock = SystemActionClock()) async throws -> UIPublicNavigationPlanV2 {
        let normalized = try UIRouteCodec.decodePublicV2(UIRouteCodec.encodePublicV2(intent, registry: self), registry: self)
        // Search continuation has its own original Core operation/receipt. A
        // generic content-free surface plan would erase the selected target.
        // Refuse before observing a local binding or preparing any authority.
        guard normalized.searchReference == nil else {
            throw UIRouteError(.notSupported, "typed_search_continuation_required")
        }
        guard invocation.snapshot == scene.backendSnapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
        let backend = normalized.backend ?? scene.backendSnapshot.backend
        guard backend == scene.backendSnapshot.backend else { throw UIRouteError(.requiresBackendSwitch, "backend_selection_required") }
        // Capture original canonical context/lifetime and actual local mapping
        // synchronously BEFORE any await, including entry into the deadline scope.
        let authority = try core.prepareNavigationSynchronously(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context)
        let binding = try host.observePublicNavigationBinding(normalized, requestId: invocation.requestId, sceneID: scene.sceneID)
        let local = UIPublicNavigationLocalBindingGuard(host: host, intent: normalized, invocation: invocation, binding: binding, authority: authority)
        try local.validate(current: scene)
        guard normalized.content != nil || binding.tab == .absent else { throw UIRouteError(.failed, "unexpected_local_tab") }
        let route = RouteSpec(requestId: invocation.requestId, destination: normalized.destination, backend: backend, content: normalized.content,
            presentation: .init(kind: normalized.presentation.nativeKind, tabID: binding.tab.value),
            state: .init(workspaceID: binding.workspace.value, profileID: binding.profile.value,
                         sidebarVisible: binding.sidebarVisible,
                         inspectorVisible: normalized.presentation == .inspector ? true : binding.inspectorVisible),
            focus: normalized.component.map { .init(kind: .component, anchor: $0) },
            scene: .init(kind: .specific, sceneID: scene.sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
        let validated = try validate(route)
        let command = try UISceneCommand(route: .init(route: validated.route, descriptor: validated.descriptor, publicLocalBinding: local), invocation: invocation, scene: scene)
        let result = try await UIDiscoveryCancellationScope.run(until: invocation.deadlineUptimeNanoseconds, clock: clock) { @MainActor in
            try local.validate(current: scene)
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            try local.validate(current: scene)
            let assessment = try await host.assessPublicNavigation(normalized, scene: scene, context: context, invocation: invocation)
            try local.validate(current: scene)
            try requirePublicAssessment(assessment, scene: scene)
            guard assessment.supported else { throw UIRouteError(.notSupported, "public_variant_not_supported") }
            guard assessment.ready else { throw UIRouteError(.unavailable, "public_variant_not_ready") }
            guard assessment.allowed else { throw UIRouteError(.failed, "permission_denied") }
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            try local.validate(current: scene)
            if normalized.content != nil {
                // Retain original local/lifetime boundary, but never turn this
                // surface-only preparation into the later Core content grant.
                return UIPublicNavigationPlanV2.reader(command.route)
            }
            return UIPublicNavigationPlanV2.surface(UIAuthorizedSceneCommand(command: command, authorization: authority))
        }
        // Returning from the structured scope is another await boundary.
        try local.validate(current: scene)
        return result
    }
}
