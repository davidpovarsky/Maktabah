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
    init(route: RouteSpec, descriptor: UIDestinationDescriptor) { self.route = route; self.descriptor = descriptor }
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
    /// Host must perform this and Core authorization immediately before native
    /// synchronous commit, not before an unrelated async wait/queue operation.
    public func validateCurrent(_ current: UISceneSnapshot, now: UInt64) throws {
        try Task.checkCancellation()
        guard now < invocation.deadlineUptimeNanoseconds else { throw UIRouteError(.cancelled, "deadline_exceeded") }
        guard current.sceneID == scene.sceneID, current.revision == scene.revision,
              current.backendSnapshot == invocation.snapshot else { throw UIRouteError(.staleState, "scene_or_backend_changed") }
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
    /// Host-owned variant/readiness checks, additionally gated by Core discovery.
    /// Route/state JSON cannot construct or grant this trusted assessment.
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot, context: ActionExecutionContext,
                invocation: ActionPortInvocation) async throws -> UIRouteEligibility
}
