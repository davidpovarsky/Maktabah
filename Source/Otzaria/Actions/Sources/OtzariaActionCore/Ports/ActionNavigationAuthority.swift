import Foundation

/// Synchronous facet of the EXACT object injected as Core's backend-state port.
/// Both snapshot() and currentBackendSnapshot() must read the same live source
/// and real RPC epoch, never a delayed/echoed cache or a second coordinator.
public protocol ActionSynchronousBackendStatePort: ActionBackendStatePort, AnyObject {
    @MainActor func currentBackendSnapshot() throws -> ActionBackendSnapshot
}

/// Separate trusted native context/scene/lifetime owner, injected once into Core
/// composition. It supplies no backend snapshot and cannot replace S's source.
/// No await may occur between the final guard and synchronous native mutation.
public protocol ActionNavigationAuthority: AnyObject, Sendable {
    @MainActor func navigationState(sceneID: String) throws -> ActionNavigationState
}

/// Trusted non-Codable host observation. A route cannot issue this authority.
/// Change lifetimeID on replacement and authorityRevision on every permission/
/// revocation change, including revoke/restore ABA; never reuse/wrap revisions.
public struct ActionNavigationState: Sendable {
    public let context: ActionExecutionContext
    public let sceneID: String
    public let lifetimeID: UUID
    public let authorityRevision: UInt64
    public let active: Bool
    public init(context: ActionExecutionContext, sceneID: String,
                lifetimeID: UUID, authorityRevision: UInt64, active: Bool) {
        self.context = context; self.sceneID = sceneID
        self.lifetimeID = lifetimeID; self.authorityRevision = authorityRevision; self.active = active
    }
}

public struct ActionNavigationError: Error, Sendable, Equatable {
    public let status: ActionStatus
    public let code: String
    init(_ status: ActionStatus, _ code: String) { self.status = status; self.code = code }
}

/// Core-issued, one-use, non-Codable preparation, never a serialized grant.
/// UI-only callers cannot mint a reader preparation: only validated reader.open
/// execution can attach one to its existing ActionOpenReaderCommand.
@MainActor public final class ActionNavigationPreparation: Sendable, Equatable {
    private let authority: any ActionNavigationAuthority
    private let backendAuthority: any ActionSynchronousBackendStatePort
    private let preparedSnapshot: ActionBackendSnapshot
    private let original: ActionNavigationState
    private let invocation: ActionPortInvocation
    private let sceneID: String
    private let destination: ActionReaderDestination?
    private let clock: any ActionClock
    private var consumed = false

    public nonisolated static func == (lhs: ActionNavigationPreparation, rhs: ActionNavigationPreparation) -> Bool { lhs === rhs }

    init(authority: any ActionNavigationAuthority, backendAuthority: any ActionSynchronousBackendStatePort,
         invocation: ActionPortInvocation, sceneID: String,
         context: ActionExecutionContext, destination: ActionReaderDestination?, clock: any ActionClock) throws {
        self.authority = authority; self.backendAuthority = backendAuthority
        self.invocation = invocation; self.sceneID = sceneID
        self.destination = destination; self.clock = clock
        original = try authority.navigationState(sceneID: sceneID)
        preparedSnapshot = try backendAuthority.currentBackendSnapshot()
        guard original.context == context else { throw ActionNavigationError(.failed, "navigation_authority_changed") }
        try validateLive()
    }

    private func validateLive() throws {
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw ActionNavigationError(.cancelled, "deadline_exceeded") }
        let live = try authority.navigationState(sceneID: sceneID)
        let backend = try backendAuthority.currentBackendSnapshot()
        guard live.active, original.active, live.lifetimeID == original.lifetimeID,
              live.authorityRevision == original.authorityRevision, live.context == original.context else {
            throw ActionNavigationError(.failed, "navigation_authority_changed")
        }
        guard live.sceneID == sceneID, original.sceneID == sceneID else { throw ActionNavigationError(.staleState, "scene_target_changed") }
        if backend.backend == .sefariaEmbedded && backend.rpcEpoch == nil {
            throw ActionNavigationError(.unavailable, "rpc_epoch_unavailable")
        }
        guard backend == invocation.snapshot, preparedSnapshot == invocation.snapshot else { throw ActionNavigationError(.staleState, "backend_generation_changed") }
        do { try ActionPolicy.navigation(context: live.context, backend: backend.backend, sceneID: sceneID, destination: destination) }
        catch let error as ActionEngineFailure { throw ActionNavigationError(error.status, error.code) }
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw ActionNavigationError(.cancelled, "deadline_exceeded") }
    }

    /// Synchronous final guard: call once, immediately before native mutation on
    /// MainActor, with no intervening await. Failure never authorizes an effect.
    /// Fresh context/rights/lifetime and snapshot come from the retained SAME
    /// authority object, not from caller-provided current-state arguments.
    public func authorizeCommit(invocation: ActionPortInvocation, sceneID: String,
                                destination: ActionReaderDestination? = nil) throws {
        guard !consumed else { throw ActionNavigationError(.failed, "navigation_preparation_consumed") }
        guard invocation == self.invocation, sceneID == self.sceneID, destination == self.destination else {
            throw ActionNavigationError(.failed, "navigation_command_mismatch")
        }
        try validateLive()
        consumed = true
    }
}
