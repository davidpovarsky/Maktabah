import Foundation
import OtzariaActionCore

/// An explicit trusted observation, not an omitted mapping/default. Never wire data.
public enum UIPublicNavigationObservedID: Sendable, Equatable {
    case absent
    case present(UIStableID)
    var value: UIStableID? { if case .present(let id) = self { id } else { nil } }
}

/// Narrow actual local selection/reservation evidence. No arbitrary UI state,
/// context, permission or lifetime can be supplied through this value.
public struct UIPublicNavigationLocalBinding: Sendable, Equatable {
    public let sceneID: UIStableID
    public let sceneRevision: UInt64
    public let backendSnapshot: ActionBackendSnapshot
    public let mappingRevision: UInt64
    public let workspace: UIPublicNavigationObservedID
    public let profile: UIPublicNavigationObservedID
    public let tab: UIPublicNavigationObservedID
    /// nil means this exact independent surface witness projects no such field,
    /// never that a required observation was unavailable. Reader false is kept.
    public let sidebarVisible: Bool?
    public let inspectorVisible: Bool?
    public init(sceneID: UIStableID, sceneRevision: UInt64, backendSnapshot: ActionBackendSnapshot, mappingRevision: UInt64,
                workspace: UIPublicNavigationObservedID, profile: UIPublicNavigationObservedID, tab: UIPublicNavigationObservedID,
                sidebarVisible: Bool?, inspectorVisible: Bool?) {
        self.sceneID = sceneID; self.sceneRevision = sceneRevision; self.backendSnapshot = backendSnapshot
        self.mappingRevision = mappingRevision; self.workspace = workspace; self.profile = profile; self.tab = tab
        self.sidebarVisible = sidebarVisible; self.inspectorVisible = inspectorVisible
    }
}

/// Mandatory binder seam; discovery eligibility alone cannot provide it.
/// Read the real selected scene/model and an existing scene-owned reservation.
/// Never allocate/mutate visible state, echo desired state, or default a missing
/// mapping to absence. Throw when unavailable. Invalidate the existing admitted
/// native authority on selection/reservation/lifetime invalidation, including ABA.
/// mappingRevision is the real owner's monotonic invalidation revision, never a
/// mirrored backend/context cache. Preserve it across an intended reservation's
/// transition to the same committed tab, and release unused reservations in N.
public protocol UIPublicNavigationBindingPort: UIPublicNavigationEligibilityPort, AnyObject {
    @MainActor func observePublicNavigationBinding(_ intent: PublicNavigationSpecV2, requestId: UUID,
                                                   sceneID: UIStableID) throws -> UIPublicNavigationLocalBinding
}

/// Retained by the structural route as well as the prepared surface. A reader's
/// later Core grant cannot erase the original import's local/lifetime boundary.
@MainActor final class UIPublicNavigationLocalBindingGuard: Sendable, Equatable {
    nonisolated static func == (lhs: UIPublicNavigationLocalBindingGuard, rhs: UIPublicNavigationLocalBindingGuard) -> Bool { lhs === rhs }
    private let host: any UIPublicNavigationBindingPort
    private let intent: PublicNavigationSpecV2
    private let invocation: ActionPortInvocation
    private let original: UIPublicNavigationLocalBinding
    private let authority: ActionNavigationPreparation
    init(host: any UIPublicNavigationBindingPort, intent: PublicNavigationSpecV2, invocation: ActionPortInvocation,
         binding: UIPublicNavigationLocalBinding, authority: ActionNavigationPreparation) {
        self.host = host; self.intent = intent; self.invocation = invocation; original = binding; self.authority = authority
    }
    func validate(current: UISceneSnapshot, completion: Bool = false) throws {
        try authority.validateFreshness()
        let live = try host.observePublicNavigationBinding(intent, requestId: invocation.requestId, sceneID: original.sceneID)
        guard live.sceneID == original.sceneID, current.sceneID == original.sceneID,
              live.backendSnapshot == original.backendSnapshot, current.backendSnapshot == original.backendSnapshot,
              live.sceneRevision == current.revision,
              completion ? current.revision >= original.sceneRevision : current.revision == original.sceneRevision,
              live.mappingRevision == original.mappingRevision,
              live.workspace == original.workspace, live.profile == original.profile, live.tab == original.tab,
              live.sidebarVisible == original.sidebarVisible,
              live.inspectorVisible == (completion && intent.presentation == .inspector ? true : original.inspectorVisible) else {
            throw UIRouteError(.staleState, "public_local_binding_changed")
        }
        try authority.validateFreshness()
    }
}
