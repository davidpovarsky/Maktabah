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
        for rule in policy.rules {
            guard descriptor.presentations.contains(rule.presentation.nativeKind), rule.components.count <= 16,
                  rule.allowsRoot || !rule.components.isEmpty, Set(rule.components).count == rule.components.count,
                  Set(rule.components).isSubset(of: Set(descriptor.anchors)) else { throw UIRouteError(.failed, "invalid_public_policy") }
        }
    }

    static func publicVariantsV2(_ descriptor: UIDestinationDescriptor) -> [UIPublicNavigationVariantV2] {
        (descriptor.publicNavigationV2?.rules ?? []).flatMap { rule in
            var components: [UIDestinationID?] = rule.components.map(Optional.some)
            if rule.allowsRoot { components.insert(nil, at: 0) }
            return components.map { UIPublicNavigationVariantV2(destination: descriptor.id, presentation: rule.presentation, component: $0, requiresContent: descriptor.requiresContent) }
        }
    }

    func validatePublicNavigationV2(_ intent: PublicNavigationSpecV2) throws -> PublicNavigationSpecV2 {
        guard let descriptor = descriptor(for: intent.destination), descriptor.implementation == .implemented,
              let policy = descriptor.publicNavigationV2,
              let rule = policy.rules.first(where: { $0.presentation == intent.presentation }),
              intent.component.map({ rule.components.contains($0) }) ?? rule.allowsRoot else {
            throw UIRouteError(.notSupported, "public_variant_not_supported")
        }
        let localShape = RouteSpec(destination: intent.destination, backend: intent.backend, content: intent.content,
            presentation: .init(kind: intent.presentation.nativeKind),
            focus: intent.component.map { .init(kind: .component, anchor: $0) })
        let normalized = try validate(localShape)
        return .init(version: intent.version, destination: intent.destination, backend: normalized.route.backend,
            content: intent.content, presentation: intent.presentation, component: intent.component)
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
    public func bindPublicV2(_ intent: PublicNavigationSpecV2, scene: UISceneSnapshot, localTabID: UIStableID? = nil,
                             context: ActionExecutionContext, invocation: ActionPortInvocation, core: ActionExecutor,
                             host: any UIPublicNavigationEligibilityPort, clock: any ActionClock = SystemActionClock()) async throws -> UIPublicNavigationPlanV2 {
        let normalized = try UIRouteCodec.decodePublicV2(UIRouteCodec.encodePublicV2(intent, registry: self), registry: self)
        guard invocation.snapshot == scene.backendSnapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
        let backend = normalized.backend ?? scene.backendSnapshot.backend
        guard backend == scene.backendSnapshot.backend else { throw UIRouteError(.requiresBackendSwitch, "backend_selection_required") }
        guard normalized.content != nil || localTabID == nil else { throw UIRouteError(.failed, "unexpected_local_tab") }
        let route = RouteSpec(requestId: invocation.requestId, destination: normalized.destination, backend: backend, content: normalized.content,
            presentation: .init(kind: normalized.presentation.nativeKind, tabID: localTabID),
            state: .init(inspectorVisible: normalized.presentation == .inspector ? true : nil),
            focus: normalized.component.map { .init(kind: .component, anchor: $0) },
            scene: .init(kind: .specific, sceneID: scene.sceneID, expectedRevision: scene.revision), expectedBackendSnapshot: invocation.snapshot)
        let command = try UISceneCommand(route: validate(route), invocation: invocation, scene: scene)
        return try await UIDiscoveryCancellationScope.run(until: invocation.deadlineUptimeNanoseconds, clock: clock) {
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            let assessment = try await host.assessPublicNavigation(normalized, scene: scene, context: context, invocation: invocation)
            try requirePublicAssessment(assessment, scene: scene)
            guard assessment.supported else { throw UIRouteError(.notSupported, "public_variant_not_supported") }
            guard assessment.ready else { throw UIRouteError(.unavailable, "public_variant_not_ready") }
            guard assessment.allowed else { throw UIRouteError(.failed, "permission_denied") }
            try await requireCurrentScene(scene, context: context, invocation: invocation, host: host, clock: clock)
            if normalized.content != nil {
                // Fresh current canonical context, but this surface-only grant
                // is discarded and can never authorize the content destination.
                _ = try await core.prepareNavigation(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context)
                return .reader(command.route)
            }
            return .surface(try await command.prepareNavigation(using: core, context: context))
        }
    }
}
