import Foundation

/// The terminal half of one Core-issued parent/selection preparation. No
/// public initializer, Codable representation, renewal or target replacement
/// exists. A host must bind this to its SAME complete immutable UI command.
/// Observation and validateFreshness cannot construct this capability.
@MainActor
public final class ActionNavigationContinuation: Sendable {
    private let preparation: ActionNavigationPreparation
    private let token: UUID
    private var retired = false

    init(preparation: ActionNavigationPreparation, token: UUID) {
        self.preparation = preparation; self.token = token
    }

    /// Immediately precedes the one synchronous original selection. The
    /// parent wait consumes the ORIGINAL invocation deadline, never a reset
    /// budget. Actual parent/source proof remains the original host's duty.
    public func authorizeSelection(invocation: ActionPortInvocation, sceneID: String) throws {
        guard !retired else { throw ActionNavigationError(.staleState, "navigation_continuation_retired") }
        try preparation.authorizeSelection(token: token, invocation: invocation, sceneID: sceneID)
    }

    public func retire() {
        guard !retired else { return }
        retired = true
        preparation.retireContinuation(token: token)
    }
}
