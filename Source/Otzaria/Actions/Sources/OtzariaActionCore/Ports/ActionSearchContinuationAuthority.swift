import Foundation

/// Core-owned authority for one operation on an already retained native search.
/// A source DTO, loaded-hit token, or metadata observation cannot mint this
/// non-Codable object. The application must still prove its original owner and
/// consume the original source token immediately before its native operation.
@MainActor
public final class ActionSearchContinuationAuthority: Sendable {
    private enum Phase: Equatable { case ready, authorizing, active, retired }
    private let command: ActionSearchContinuationCommand
    private let preparation: ActionNavigationPreparation
    private var phase: Phase = .ready
    private var validating = false

    init(command: ActionSearchContinuationCommand, context: ActionExecutionContext,
         authority: any ActionNavigationAuthority,
         backendAuthority: any ActionSynchronousBackendStatePort,
         clock: any ActionClock) throws {
        guard ActionValidation.nonempty(command.source.sceneID, max: 256),
              command.source.snapshot == command.invocation.snapshot,
              command.source.submissionRevision > 0,
              command.source.cancellationRevision >= 0,
              command.source.paginationRevision >= 0,
              command.source.pageRevision > 0,
              !command.source.configuration.isEmpty,
              command.source.configuration.count <= 65_536 else {
            throw ActionNavigationError(.failed, "search_continuation_command_mismatch")
        }
        // The existing source's opaque configuration is not a canonical work
        // scope proof. Do not widen a limited-work context by treating it as one.
        // Ordinary local UI contexts already carry the original navigation
        // scope. This grants no headless query, reader open, or content payload.
        guard context.allowedWorkKeys == nil else {
            throw ActionNavigationError(.notSupported, "search_continuation_scope_unavailable")
        }
        self.command = command
        preparation = try ActionNavigationPreparation(authority: authority,
            backendAuthority: backendAuthority, invocation: command.invocation,
            sceneID: command.source.sceneID, context: context, destination: nil, clock: clock)
    }

    /// Read-only guard before and across host awaits. This never authorizes an
    /// effect and cannot be substituted for authorizeOriginalOperation below.
    public func validateFreshness(for command: ActionSearchContinuationCommand) throws {
        try requireCommand(command)
        guard phase == .ready || phase == .active else { throw retired() }
        try validateOwner(expected: phase, completion: false)
    }

    /// Consume once before the original bound native operation. Set the phase
    /// before calling any live guard, so a synchronous callback cannot obtain
    /// a second grant from the same authority, even with the same command.
    public func authorizeOriginalOperation(_ command: ActionSearchContinuationCommand) throws {
        try requireCommand(command)
        guard phase == .ready, !validating else { throw retired() }
        phase = .authorizing
        do {
            try preparation.authorizeCommit(invocation: command.invocation,
                                            sceneID: command.source.sceneID, destination: nil)
            guard phase == .authorizing else { throw retired() }
            phase = .active
        } catch {
            phase = .retired
            throw error
        }
    }

    /// The binding receives this live callback for every actual mutation and
    /// after every await. An unconsumed preparation always refuses execution.
    public func validateExecution(for command: ActionSearchContinuationCommand) throws {
        try requireCommand(command)
        guard phase == .active else { throw retired() }
        try validateOwner(expected: .active, completion: true)
    }

    /// Native receipt/model/layout validation remains independently mandatory.
    /// Successful completion does not rearm the one-use native effect grant.
    public func validateCompletion(for command: ActionSearchContinuationCommand) throws {
        try validateExecution(for: command)
    }

    public func retire() { phase = .retired }

    private func requireCommand(_ proposed: ActionSearchContinuationCommand) throws {
        guard proposed == command else {
            throw ActionNavigationError(.failed, "search_continuation_command_mismatch")
        }
    }

    private func validateOwner(expected: Phase, completion: Bool) throws {
        guard !validating, phase == expected else { throw retired() }
        validating = true
        defer { validating = false }
        if completion { try preparation.validateCompletion() }
        else { try preparation.validateFreshness() }
        guard phase == expected else { throw retired() }
    }

    private func retired() -> ActionNavigationError {
        ActionNavigationError(.staleState, "search_continuation_authority_consumed")
    }
}
