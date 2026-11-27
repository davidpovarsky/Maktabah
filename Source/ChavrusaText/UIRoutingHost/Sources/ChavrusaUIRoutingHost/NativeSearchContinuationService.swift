import Foundation
import OtzariaActionCore

/// Thin adapter for a separate retained-search operation. The original
/// first-page intent/service/query are untouched. The apply closure MUST use
/// the supplied live authority check before each mutation and after awaits.
@MainActor
public final class NativeSearchContinuationService {
    public typealias Check = @MainActor () throws -> Void
    public typealias Observe = @MainActor (String, ActionPortInvocation) throws -> ActionSearchContinuationObservation
    public typealias Apply = @MainActor (ActionSearchContinuationCommand, @escaping Check) async -> ActionSearchContinuationOutcome
    public typealias Validate = @MainActor (ActionSearchContinuationCommand, ActionSearchContinuationReceipt) throws -> Void
    public typealias Authority = @MainActor (String, ActionPortInvocation) throws -> Void
    private let observeOriginal: Observe
    private let applyOriginal: Apply
    private let validateOriginal: Validate
    private let authority: Authority
    private let now: @MainActor () -> UInt64

    public init(observe: @escaping Observe, apply: @escaping Apply, validate: @escaping Validate,
                authority: @escaping Authority,
                now: @escaping @MainActor () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
        observeOriginal = observe; applyOriginal = apply; validateOriginal = validate
        self.authority = authority; self.now = now
    }

    public func observe(in sceneID: String, invocation: ActionPortInvocation) throws -> ActionSearchContinuationObservation {
        try check(sceneID, invocation)
        let observation = try observeOriginal(sceneID, invocation)
        try check(sceneID, invocation)
        guard Data(observation.source.sceneID.utf8) == Data(sceneID.utf8),
              observation.source.snapshot == invocation.snapshot,
              Set(observation.loadedHits.map(\.token)).count == observation.loadedHits.count,
              observation.nextPageToken.map({ token in !observation.loadedHits.contains { $0.token == token } }) ?? true else {
            throw ActionPortError.invalidResponse
        }
        return observation
    }

    public func continueSearch(_ command: ActionSearchContinuationCommand) async -> ActionSearchContinuationOutcome {
        let validateAuthority: Check = { [self] in
            guard command.source.snapshot == command.invocation.snapshot else { throw ActionPortError.staleState }
            try check(command.source.sceneID, command.invocation)
        }
        do { try validateAuthority() }
        catch { return refusal(command, error: error, effects: []) }

        let result = await applyOriginal(command, validateAuthority)
        switch result {
        case .refused(let failure):
            // Join the recorded operation before any live check can throw and
            // turn this response into a refusal for the current command.
            guard failure.requestID == command.invocation.requestId,
                  failure.source == command.source, failure.operation == command.operation else {
                return .unqualified(command: command, originalResponse: result)
            }
            // An exactly joined original operation retains its actual partial
            // effects even if current authority or cancellation changes later.
            do { try validateAuthority() }
            catch { return refusal(command, error: error, effects: failure.effects) }
            return result
        case .acknowledged(let receipt):
            // A malformed or foreign response remains raw evidence under its
            // original origin. It cannot donate effects to this command.
            do { try Self.validateShape(command, receipt) }
            catch { return .unqualified(command: command, originalResponse: result) }
            do {
                try validateAuthority()
                try validateOriginal(command, receipt)
                try validateAuthority()
                return result
            } catch { return refusal(command, error: error, effects: receipt.effects) }
        case .unqualified:
            return .unqualified(command: command, originalResponse: result)
        }
    }

    private func check(_ scene: String, _ invocation: ActionPortInvocation) throws {
        try Task.checkCancellation()
        guard now() < invocation.deadlineUptimeNanoseconds else { throw ContinuationDeadline.expired }
        try authority(scene, invocation)
        try Task.checkCancellation()
        guard now() < invocation.deadlineUptimeNanoseconds else { throw ContinuationDeadline.expired }
    }

    private enum ContinuationDeadline: Error { case expired }
    private func refusal(_ command: ActionSearchContinuationCommand, error: Error,
                         effects: [ActionSearchContinuationEffect]) -> ActionSearchContinuationOutcome {
        let reason: ActionSearchContinuationRefusal
        if error is CancellationError { reason = .cancelled }
        else if error is ContinuationDeadline { reason = .deadlineExceeded }
        else if error as? ActionPortError == .invalidResponse { reason = .invalidCompletion }
        else { reason = .staleSource }
        return .refused(.init(requestID: command.invocation.requestId, reason: reason, effects: effects,
                              source: command.source, operation: command.operation))
    }

    /// Structural validation supplements, and never substitutes for, the
    /// retained original view/model/scene and final live authority check.
    static func validateShape(_ command: ActionSearchContinuationCommand,
                              _ receipt: ActionSearchContinuationReceipt) throws {
        let before = receipt.before, after = receipt.after
        guard receipt.requestID == command.invocation.requestId, before == command.source,
              receipt.operation == command.operation, before.snapshot == command.invocation.snapshot,
              Data(after.sceneID.utf8) == Data(before.sceneID.utf8), after.snapshot == before.snapshot,
              after.sessionID == before.sessionID, after.modelID == before.modelID,
              after.generation == before.generation, after.submissionRevision == before.submissionRevision,
              after.cancellationRevision == before.cancellationRevision,
              after.configuration == before.configuration, receipt.visible.layoutRevision > 0 else {
            throw ActionPortError.invalidResponse
        }
        switch command.operation {
        case .revealLoadedHit(let token):
            guard before == after, receipt.effects.count == 1,
                  case .hitSelectionApplied(let hit) = receipt.effects[0], hit.token == token,
                  receipt.visible.rowID != nil, receipt.visible.identity == hit.identity else {
                throw ActionPortError.invalidResponse
            }
        case .nextOriginalPage:
            guard before.paginationRevision < Int.max, before.pageRevision < UInt64.max,
                  after.paginationRevision == before.paginationRevision + 1,
                  after.pageRevision == before.pageRevision + 1,
                  after.sourceRevision == before.sourceRevision,
                  receipt.visible.rowID == nil, receipt.visible.identity == nil,
                  receipt.effects.count == 2,
                  case .pageRequested(let attemptID) = receipt.effects[0],
                  case .pageCommitted(let page) = receipt.effects[1], page.attemptID == attemptID,
                  page.modelID == before.modelID, page.generation == before.generation,
                  page.pageRevision == after.pageRevision,
                  page.requestOffset >= 0, page.requestLimit > 0, !page.request.isEmpty,
                  page.rawRowCount >= 0, page.mappedRowCount >= 0,
                  page.consumedBefore >= 0, page.consumedAfter >= page.consumedBefore,
                  page.cursorBefore == page.requestOffset,
                  page.hasMore == (page.normalizedNextOffset != nil) else {
                throw ActionPortError.invalidResponse
            }
            // An accepted empty terminal page is valid even with no cursor or
            // displayed-count advance. Only an advertised continuation must
            // advance beyond the accepted request to avoid a replay loop.
            if let next = page.normalizedNextOffset, next <= page.requestOffset {
                throw ActionPortError.invalidResponse
            }
        }
    }
}
