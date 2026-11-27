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
    private let noteDraft: ActionNoteDraftRequest?
    private let searchQuery: ActionSearchResultsQuery?
    private let clock: any ActionClock
    private var consumed = false
    private enum ContinuationPhase: Equatable { case claimingParent, parentCommitted, claimingSelection, selectionCommitted, retired }
    private struct ContinuationState {
        let token: UUID
        var phase: ContinuationPhase
    }
    private var continuation: ContinuationState?

    public nonisolated static func == (lhs: ActionNavigationPreparation, rhs: ActionNavigationPreparation) -> Bool { lhs === rhs }

    init(authority: any ActionNavigationAuthority, backendAuthority: any ActionSynchronousBackendStatePort,
         invocation: ActionPortInvocation, sceneID: String,
         context: ActionExecutionContext, destination: ActionReaderDestination?, clock: any ActionClock,
         noteDraft: ActionNoteDraftRequest? = nil, searchQuery: ActionSearchResultsQuery? = nil) throws {
        guard [destination != nil, noteDraft != nil, searchQuery != nil].filter({ $0 }).count <= 1 else {
            throw ActionNavigationError(.failed, "navigation_command_mismatch")
        }
        self.authority = authority; self.backendAuthority = backendAuthority
        self.invocation = invocation; self.sceneID = sceneID
        self.destination = destination; self.clock = clock; self.noteDraft = noteDraft; self.searchQuery = searchQuery
        original = try authority.navigationState(sceneID: sceneID)
        preparedSnapshot = try backendAuthority.currentBackendSnapshot()
        guard original.context == context else { throw ActionNavigationError(.failed, "navigation_authority_changed") }
        try validateLive()
    }

    private func validateLive() throws {
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw ActionNavigationError(.cancelled, "deadline_exceeded") }
        // Bracket the native ownership read with the SAME live backend source:
        // native revocation during the first backend read must be observed,
        // and generation/epoch drift during the native read must still refuse.
        let beforeNative = try backendAuthority.currentBackendSnapshot()
        let live = try authority.navigationState(sceneID: sceneID)
        let backend = try backendAuthority.currentBackendSnapshot()
        guard live.active, original.active, live.lifetimeID == original.lifetimeID,
              live.authorityRevision == original.authorityRevision, live.context == original.context else {
            throw ActionNavigationError(.failed, "navigation_authority_changed")
        }
        guard live.sceneID == sceneID, original.sceneID == sceneID else { throw ActionNavigationError(.staleState, "scene_target_changed") }
        if (backend.backend == .sefariaEmbedded && backend.rpcEpoch == nil)
            || (beforeNative.backend == .sefariaEmbedded && beforeNative.rpcEpoch == nil) {
            throw ActionNavigationError(.unavailable, "rpc_epoch_unavailable")
        }
        guard beforeNative == invocation.snapshot, backend == invocation.snapshot,
              preparedSnapshot == invocation.snapshot else { throw ActionNavigationError(.staleState, "backend_generation_changed") }
        do {
            try ActionPolicy.navigation(context: live.context, backend: backend.backend, sceneID: sceneID, destination: destination)
            if let noteDraft {
                guard destination == nil, noteDraft.locator.backend == backend.backend else {
                    throw ActionNavigationError(.failed, "navigation_command_mismatch")
                }
                try ActionPolicy.work(noteDraft.locator.workKey, backend: backend.backend, context: live.context)
            }
            if let searchQuery {
                guard destination == nil, searchQuery.search.backend == backend.backend else { throw ActionPortError.invalidResponse }
                try ActionPolicy.search(searchQuery.search, context: live.context)
            }
        }
        catch let error as ActionEngineFailure { throw ActionNavigationError(error.status, error.code) }
        try Task.checkCancellation()
        guard clock.now() < invocation.deadlineUptimeNanoseconds else { throw ActionNavigationError(.cancelled, "deadline_exceeded") }
    }

    /// Nonconsuming freshness observation across host awaits. This grants no
    /// effect and never substitutes for authorizeCommit or validateCompletion.
    public func validateFreshness() throws {
        try validateLive()
    }

    /// Synchronous final guard: call once, immediately before native mutation on
    /// MainActor, with no intervening await. Failure never authorizes an effect.
    /// Fresh native context/rights/lifetime and backend snapshot come from their
    /// retained exact authorities, not caller-provided current-state arguments.
    public func authorizeCommit(invocation: ActionPortInvocation, sceneID: String,
                                destination: ActionReaderDestination? = nil, noteDraft: ActionNoteDraftRequest? = nil,
                                searchQuery: ActionSearchResultsQuery? = nil) throws {
        guard !consumed else { throw ActionNavigationError(.failed, "navigation_preparation_consumed") }
        guard invocation == self.invocation, sceneID == self.sceneID, destination == self.destination,
              noteDraft == self.noteDraft, searchQuery == self.searchQuery else {
            throw ActionNavigationError(.failed, "navigation_command_mismatch")
        }
        try validateLive()
        consumed = true
    }

    /// An additive, finite UI-only commit: select the ORIGINAL parent, then
    /// consume exactly one original selection after that parent's actual wait.
    /// The same preparation owns both effects. It cannot also perform the
    /// single-commit path or borrow a semantic reader/note/search preparation.
    public func authorizeParentSelection(invocation: ActionPortInvocation,
                                         sceneID: String) throws -> ActionNavigationContinuation {
        guard !consumed else { throw ActionNavigationError(.failed, "navigation_preparation_consumed") }
        guard invocation == self.invocation, sceneID == self.sceneID,
              destination == nil, noteDraft == nil, searchQuery == nil else {
            throw ActionNavigationError(.failed, "navigation_command_mismatch")
        }
        let token = UUID()
        // Claim BEFORE live authorities can invoke a synchronous callback.
        // Failure or reentry never rearms this preparation.
        consumed = true
        continuation = .init(token: token, phase: .claimingParent)
        do {
            try validateLive()
            guard continuation?.token == token, continuation?.phase == .claimingParent else {
                throw ActionNavigationError(.staleState, "navigation_continuation_retired")
            }
            continuation?.phase = .parentCommitted
            return ActionNavigationContinuation(preparation: self, token: token)
        } catch {
            retireContinuation(token: token)
            throw error
        }
    }

    func authorizeSelection(token: UUID, invocation: ActionPortInvocation, sceneID: String) throws {
        guard invocation == self.invocation, sceneID == self.sceneID else {
            throw ActionNavigationError(.failed, "navigation_command_mismatch")
        }
        guard continuation?.token == token, continuation?.phase == .parentCommitted else {
            throw ActionNavigationError(.failed, "navigation_continuation_consumed")
        }
        continuation?.phase = .claimingSelection
        do {
            try validateLive()
            guard continuation?.token == token, continuation?.phase == .claimingSelection else {
                throw ActionNavigationError(.staleState, "navigation_continuation_retired")
            }
            continuation?.phase = .selectionCommitted
        } catch {
            retireContinuation(token: token)
            throw error
        }
    }

    func retireContinuation(token: UUID) {
        guard continuation?.token == token else { return }
        // A completed effect may still need the original outer completion
        // check. Its one-use selection can never be claimed again. Retiring a
        // partial parent, however, permanently forbids terminal completion.
        if continuation?.phase != .selectionCommitted { continuation?.phase = .retired }
    }

    /// Freshness check after native observation/layout waits, not another grant.
    /// The commit guard must already have succeeded. Failure may follow an
    /// actual effect: it proves neither rollback nor absence of that effect.
    public func validateCompletion() throws {
        guard consumed else { throw ActionNavigationError(.failed, "navigation_commit_not_authorized") }
        if let continuation, continuation.phase != .selectionCommitted {
            throw ActionNavigationError(.failed, "navigation_selection_not_authorized")
        }
        try validateLive()
    }
}
