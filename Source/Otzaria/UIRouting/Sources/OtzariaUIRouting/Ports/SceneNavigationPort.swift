import Foundation
import OtzariaActionCore

/// Trusted host observation, intentionally not Codable/from route state.
public struct UISceneSnapshot: Sendable, Equatable {
    public let sceneID: UIStableID
    public let revision: UInt64
    public let backendSnapshot: ActionBackendSnapshot
    public let visibleRoute: RouteSpec?
    public init(sceneID: UIStableID, revision: UInt64, backendSnapshot: ActionBackendSnapshot, visibleRoute: RouteSpec? = nil) {
        self.sceneID = sceneID; self.revision = revision; self.backendSnapshot = backendSnapshot; self.visibleRoute = visibleRoute
    }
}
/// Registry validation is structural, not a semantic resolution or permission.
public struct UIValidatedRoute: Sendable, Equatable {
    public let route: RouteSpec
    public let descriptor: UIDestinationDescriptor
    let publicLocalBinding: UIPublicNavigationLocalBindingGuard?
    init(route: RouteSpec, descriptor: UIDestinationDescriptor, publicLocalBinding: UIPublicNavigationLocalBindingGuard? = nil) {
        self.route = route; self.descriptor = descriptor; self.publicLocalBinding = publicLocalBinding
    }
}
public struct UISceneCommand: Sendable, Equatable {
    public let route: UIValidatedRoute
    public let invocation: ActionPortInvocation
    public let scene: UISceneSnapshot
    public init(route: UIValidatedRoute, invocation: ActionPortInvocation, scene: UISceneSnapshot) throws {
        guard route.route.requestId == invocation.requestId else { throw UIRouteError(.failed, "request_binding_mismatch") }
        guard route.route.backend != nil else { throw UIRouteError(.failed, "route_not_prepared") }
        if let target = route.route.backend, target != scene.backendSnapshot.backend { throw UIRouteError(.requiresBackendSwitch, "backend_selection_required") }
        guard scene.backendSnapshot == invocation.snapshot else { throw UIRouteError(.staleState, "backend_generation_changed") }
        if invocation.snapshot.backend == .sefariaEmbedded && invocation.snapshot.rpcEpoch == nil { throw UIRouteError(.unavailable, "rpc_epoch_unavailable") }
        if let expected = route.route.expectedBackendSnapshot, expected != invocation.snapshot { throw UIRouteError(.staleState, "backend_generation_changed") }
        if let revision = route.route.scene.expectedRevision, revision != scene.revision { throw UIRouteError(.staleState, "scene_revision_changed") }
        if let target = route.route.scene.sceneID, target != scene.sceneID { throw UIRouteError(.staleState, "scene_target_changed") }
        guard route.route.content == nil || route.route.presentation.tabID != nil else { throw UIRouteError(.failed, "route_not_prepared") }
        self.route = route; self.invocation = invocation; self.scene = scene
    }
    /// Structural stale/deadline check, not authorization. Native hosts use the
    /// authorized wrapper's final synchronous guard immediately before mutation.
    public func validateCurrent(_ current: UISceneSnapshot, now: UInt64) throws {
        try Task.checkCancellation()
        guard now < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        try validateScene(current)
    }
    private func validateScene(_ current: UISceneSnapshot) throws {
        guard current.sceneID == scene.sceneID, current.revision == scene.revision,
              current.backendSnapshot == invocation.snapshot else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
    }

    /// UI-only routes use canonical Core navigation permission, not a fabricated
    /// semantic action. Content must arrive through reader.open's existing sink.
    public func prepareNavigation(using core: ActionExecutor, context: ActionExecutionContext) async throws -> UIAuthorizedSceneCommand {
        guard route.descriptor.implementation == .implemented, route.descriptor.requiredCoreActions.isEmpty,
              route.route.content == nil, route.route.state.privateState == nil else {
            throw UIRouteError(.notSupported, "semantic_execution_required")
        }
        let authorization = try await core.prepareNavigation(sceneID: scene.sceneID.rawValue, invocation: invocation, context: context)
        return UIAuthorizedSceneCommand(command: self, authorization: authorization)
    }

    /// Content can only be prepared from the matching command delivered by the
    /// existing validated reader.open executor -> resolver -> sink path.
    public func prepareNavigation(readerCommand: ActionOpenReaderCommand) throws -> UIAuthorizedSceneCommand {
        guard route.route.content != nil, readerCommand.destination == route.route.content,
              readerCommand.invocation == invocation, readerCommand.sceneID == scene.sceneID.rawValue,
              let authorization = readerCommand.navigationAuthorization else {
            throw UIRouteError(.failed, "reader_command_authorization_required")
        }
        return UIAuthorizedSceneCommand(command: self, authorization: authorization)
    }

    /// Final synchronous native guard. Obtain reader authorization only from the
    /// Core-delivered ActionOpenReaderCommand after resolver validation. The
    /// authorization re-reads its retained exact Core authority and is one-use.
    /// Native host must mutate immediately after this returns, with no await.
    @MainActor fileprivate func authorizeCommit(current: UISceneSnapshot, using authorization: ActionNavigationPreparation) throws {
        guard route.descriptor.implementation == .implemented, !route.descriptor.mutatesUserData, route.descriptor.riskTier < 3 else {
            throw UIRouteError(.notSupported, "destination_not_implemented")
        }
        let required = route.descriptor.requiredCoreActions
        guard route.route.content == nil ? required.isEmpty : required == ["reader.open"] else {
            throw UIRouteError(.notSupported, "semantic_execution_required")
        }
        try validateScene(current)
        try route.publicLocalBinding?.validate(current: current)
        try authorization.authorizeCommit(invocation: invocation, sceneID: scene.sceneID.rawValue, destination: route.route.content)
    }
}

/// Trusted non-Codable preparation binds the complete immutable scene command.
/// No public initializer or replaceable route/authorization. Discovery and
/// decoded routes cannot construct this wrapper or a Core preparation.
public struct UIAuthorizedSceneCommand: Sendable {
    public let command: UISceneCommand
    private let authorization: ActionNavigationPreparation
    init(command: UISceneCommand, authorization: ActionNavigationPreparation) {
        self.command = command; self.authorization = authorization
    }
    /// Apply exactly command.route after this succeeds, synchronously with no
    /// await. It consumes the one-use preparation; observation/receipt follow.
    @MainActor public func authorizeCommit(current: UISceneSnapshot) throws {
        try command.authorizeCommit(current: current, using: authorization)
    }
    /// Check the exact observed native result AND current canonical authority
    /// after any layout/readiness await. This cannot authorize/repeat mutation.
    @MainActor public func validateCompletion(receipt: UISceneReceipt, observed: UISceneSnapshot) throws {
        try receipt.validate(for: command, observed: observed)
        try command.route.publicLocalBinding?.validate(current: observed, completion: true)
        try authorization.validateCompletion()
    }
}
public struct UISceneReceipt: Sendable, Equatable {
    public let requestId: UUID
    public let route: RouteSpec
    public let backendSnapshot: ActionBackendSnapshot
    public let sceneID: UIStableID
    public let basedOnSceneRevision: UInt64
    public let appliedSceneRevision: UInt64
    public let coreReceipt: ActionUIReceipt?
    public init(requestId: UUID, route: RouteSpec, backendSnapshot: ActionBackendSnapshot, sceneID: UIStableID,
                basedOnSceneRevision: UInt64, appliedSceneRevision: UInt64, coreReceipt: ActionUIReceipt? = nil) {
        self.requestId = requestId; self.route = route; self.backendSnapshot = backendSnapshot; self.sceneID = sceneID
        self.basedOnSceneRevision = basedOnSceneRevision; self.appliedSceneRevision = appliedSceneRevision; self.coreReceipt = coreReceipt
    }
    /// A receipt alone is insufficient: compare the trusted post-commit scene
    /// observation. Private route state must not be serialized as public output.
    public func validate(for command: UISceneCommand, observed: UISceneSnapshot) throws {
        guard requestId == command.invocation.requestId, route == command.route.route,
              backendSnapshot == command.invocation.snapshot, sceneID == command.scene.sceneID,
              basedOnSceneRevision == command.scene.revision, appliedSceneRevision > basedOnSceneRevision,
              observed.sceneID == sceneID, observed.revision == appliedSceneRevision,
              observed.backendSnapshot == backendSnapshot, observed.visibleRoute == route else { throw UIRouteError(.failed, "scene_receipt_mismatch") }
        if let content = route.content {
            guard let coreReceipt, coreReceipt.requestId == requestId, coreReceipt.snapshot == backendSnapshot,
                  coreReceipt.sceneID == sceneID.rawValue, coreReceipt.destination == content else { throw UIRouteError(.failed, "core_receipt_mismatch") }
        } else if coreReceipt != nil { throw UIRouteError(.failed, "unexpected_core_receipt") }
    }
}
public enum UISceneAcknowledgement: Sendable, Equatable {
    case acknowledged(UISceneReceipt), queued(handle: String), requiresForeground, requiresBackendSwitch(ActionBackendID)
    case notSupported(ActionFailure), unavailable(ActionFailure), staleState(ActionFailure), needsDisambiguation([UIStableID])
    case requiresConfirmation(ActionFailure), cancelled, failed(ActionFailure)
}
public protocol UISceneNavigationPort: Sendable {
    @MainActor func snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot
    @MainActor func commit(_ command: UISceneCommand, context: ActionExecutionContext) async throws -> UISceneAcknowledgement
}
public struct UIRouteEligibility: Sendable, Equatable {
    public let sceneID: UIStableID
    public let sceneRevision: UInt64
    public let backendSnapshot: ActionBackendSnapshot
    public let supported: Bool
    public let ready: Bool
    public let allowed: Bool
    public init(sceneID: UIStableID, sceneRevision: UInt64, backendSnapshot: ActionBackendSnapshot, supported: Bool, ready: Bool, allowed: Bool) {
        self.sceneID = sceneID; self.sceneRevision = sceneRevision; self.backendSnapshot = backendSnapshot
        self.supported = supported; self.ready = ready; self.allowed = allowed
    }
}
public protocol UIDestinationEligibilityPort: Sendable {
    /// Independently observe the EXACT authorized native scene selected by this
    /// trusted ID and the SAME current backend-state authority used by Core.
    /// Include current generation/RPC epoch and scene revision after relevant
    /// awaits. Never echo a captured/requested scene or choose a global/first
    /// scene fallback. Validate host context/lifetime and fail on missing state.
    ///
    /// All discovery port methods must cooperate with cancellation/deadline:
    /// promptly end waits and clean up their continuations/resources when the
    /// caller is cancelled. Registry's structured scope cannot hard-kill an
    /// uncooperative child. Native UI03 owns bounded admission, not Core's worker
    /// limit; this package creates no detached worker or independent executor.
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext,
                      invocation: ActionPortInvocation) async throws -> UISceneSnapshot
    /// Host-owned variant/readiness checks, additionally gated by Core discovery.
    /// Route/state JSON cannot construct or grant this trusted assessment.
    /// Must obey the same cancellation/deadline/cleanup obligation above.
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext,
                invocation: ActionPortInvocation) async throws -> UIRouteEligibility
}
