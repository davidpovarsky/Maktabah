import Foundation

/// Trusted, live adapter observation. This is neither a wire argument nor a
/// grant: every step still passes through the original Core policy and ports.
public struct ActionJourneyAuthority: Sendable, Equatable {
    public let context: ActionExecutionContext
    public let snapshot: ActionBackendSnapshot
    public init(context: ActionExecutionContext, snapshot: ActionBackendSnapshot) {
        self.context = context; self.snapshot = snapshot
    }
}

/// A reader may have opened even when its subsequent note draft was refused.
/// Preserve those individual results; only the complete fixed sequence is a
/// successful journey. No descriptor or transport capability is added here.
public struct ActionSemanticJourneyResult: Sendable, Equatable {
    public let plannedActions: [String]
    public let steps: [ActionResult]
    public var isComplete: Bool {
        steps.map(\.action) == plannedActions && steps.allSatisfy { $0.status == .completed }
    }
    fileprivate init(_ plannedActions: [String], _ steps: [ActionResult]) {
        self.plannedActions = plannedActions; self.steps = steps
    }
}

/// Three bounded, explicit sequences over existing actions. This does not parse
/// natural language, choose ambiguous candidates, invent aliases, or mint read
/// rights. Native execution must retain the original scene owners and receipts.
@MainActor public struct ActionSemanticJourneys {
    public typealias Authority = @MainActor () throws -> ActionJourneyAuthority
    public typealias NativeExecution = @MainActor (ActionRequest, ActionJourneyAuthority) async throws -> ActionResult

    private let core: ActionExecutor
    private let navigationAuthority: Authority
    private let readAuthority: Authority?
    private let executeNative: NativeExecution

    public init(core: ActionExecutor, navigationAuthority: @escaping Authority,
                readAuthority: Authority? = nil, executeNative: @escaping NativeExecution) {
        self.core = core; self.navigationAuthority = navigationAuthority
        self.readAuthority = readAuthority; self.executeNative = executeNative
    }

    public func countThenOpenResults(_ query: ActionOccurrenceQuery) async -> ActionSemanticJourneyResult {
        let plan = ["search.countOccurrences", "search.openResults"]
        var steps: [ActionResult] = []
        var request = ActionRequest(action: plan[0], expectedBackend: query.backend)
        var publication: (request: ActionRequest, authority: ActionJourneyAuthority)?
        do {
            guard let readAuthority else { throw ActionNavigationError(.unavailable, "trusted_read_authority_unavailable") }
            let read = try readAuthority()
            let navigation = try navigationAuthority()
            guard read.snapshot == navigation.snapshot,
                  let scene = navigation.context.foregroundSceneID,
                  read.context.foregroundSceneID == scene else { throw ActionPortError.staleState }
            request = pinned(request, arguments: ["text": .string(query.text),
                "scopeWorkRefs": try .encoded(query.scopeWorkRefs), "matchMode": .string(query.matchMode.rawValue),
                "countUnit": .string(query.countUnit.rawValue)], snapshot: read.snapshot)
            let counted = await executeRead(request, authority: read, observe: readAuthority)
            steps.append(counted)
            guard counted.status == .completed else { return .init(plan, steps) }
            publication = (request, read)

            // Use the original request, not a normalized token or page total.
            // The typed projection preserves every mode/scope/sort field and
            // removes only the validated UI-owned pagination defaults.
            request = ActionRequest(action: plan[1],
                expectedBackend: query.backend, expectedGeneration: read.snapshot.generation,
                requestedPresentation: .foreground)
            let resultsQuery = try ActionSearchResultsQuery(query.permissionQuery)
            request = pinned(request, arguments: try resultsQuery.actionArguments(), snapshot: read.snapshot, foreground: true)
            try require(read, observe: readAuthority)
            try require(navigation, observe: navigationAuthority)
            steps.append(await executeNativeStep(request, authority: navigation))
        } catch { steps.append(refused(request, error)) }
        // The caller receives this aggregate only now, after a possible UI await.
        // A revoked read must discard its number even if an independent native
        // effect already happened. Preserve that action's actual receipt/status.
        if let publication, let readAuthority {
            do { try require(publication.authority, observe: readAuthority) }
            catch { steps[0] = refused(publication.request, error) }
        }
        return .init(plan, steps)
    }

    public func commentaryThenPrepareDraft(baseLocator: ActionTextRef, workRef: ActionWorkRef? = nil,
                                           commentaryQuery: String? = nil, proposedText: String? = nil) async -> ActionSemanticJourneyResult {
        let plan = ["reader.openCommentary", "notes.prepareDraft"]
        var request = ActionRequest(action: plan[0], expectedBackend: baseLocator.backend)
        do {
            let authority = try navigationAuthority()
            var arguments: ActionObject = ["baseLocator": try .encoded(baseLocator)]
            if let workRef { arguments["workRef"] = try .encoded(workRef) }
            if let commentaryQuery { arguments["commentaryQuery"] = .string(commentaryQuery) }
            request = pinned(request, arguments: arguments, snapshot: authority.snapshot, foreground: true)
            return .init(plan, await commentaryAndDraft(request, authority: authority, proposedText: proposedText))
        } catch { return .init(plan, [refused(request, error)]) }
    }

    /// The caller supplies structured names and an actual section label. Work,
    /// TOC reference and commentary links are resolved by the existing catalog
    /// resolver; an ambiguous or absent step stops before any later action.
    public func resolveCommentaryThenPrepareDraft(backend: ActionBackendID, baseWorkQuery: String,
                                                  section: String, commentaryQuery: String,
                                                  proposedText: String? = nil) async -> ActionSemanticJourneyResult {
        let plan = ["catalog.resolveWork", "catalog.resolveReference", "reader.openCommentary", "notes.prepareDraft"]
        var steps: [ActionResult] = []
        var request = ActionRequest(action: plan[0], arguments: ["query": .string(baseWorkQuery)], expectedBackend: backend)
        do {
            let authority = try navigationAuthority()
            request = pinned(request, arguments: request.arguments, snapshot: authority.snapshot)
            let workResult = await executeRead(request, authority: authority, observe: navigationAuthority)
            steps.append(workResult)
            guard workResult.status == .completed else { return .init(plan, steps) }
            request = ActionRequest(action: plan[1], expectedBackend: backend, expectedGeneration: authority.snapshot.generation)
            guard let work = try workResult.data?["workRef"]?.decoded(as: ActionWorkRef.self) else { throw ActionPortError.invalidResponse }
            request = pinned(request, arguments: ["workRef": try .encoded(work), "section": .string(section)], snapshot: authority.snapshot)
            let reference = await executeRead(request, authority: authority, observe: navigationAuthority)
            steps.append(reference)
            guard reference.status == .completed else { return .init(plan, steps) }
            request = ActionRequest(action: plan[2], expectedBackend: backend, expectedGeneration: authority.snapshot.generation,
                requestedPresentation: .foreground)
            guard let base = try reference.data?["locator"]?.decoded(as: ActionTextRef.self) else { throw ActionPortError.invalidResponse }
            request = pinned(request, arguments: ["baseLocator": try .encoded(base), "commentaryQuery": .string(commentaryQuery)],
                snapshot: authority.snapshot, foreground: true)
            steps += await commentaryAndDraft(request, authority: authority, proposedText: proposedText)
        } catch { steps.append(refused(request, error)) }
        return .init(plan, steps)
    }

    private func commentaryAndDraft(_ request: ActionRequest, authority: ActionJourneyAuthority,
                                    proposedText: String?) async -> [ActionResult] {
        let opened = await executeNativeStep(request, authority: authority)
        guard opened.status == .completed else { return [opened] }
        var next = ActionRequest(action: "notes.prepareDraft", expectedBackend: request.expectedBackend,
            expectedGeneration: authority.snapshot.generation, requestedPresentation: .foreground)
        do {
            guard let destination = try opened.data?["destination"]?.decoded(as: ActionReaderDestination.self),
                  let locator = try opened.data?["locator"]?.decoded(as: ActionTextRef.self),
                  destination.presentationMode == .newTab,
                  locator == (destination.focusLocator ?? destination.sectionLocator) else {
                throw ActionPortError.invalidResponse
            }
            try ActionValidation.text(locator, backend: authority.snapshot.backend)
            var arguments: ActionObject = ["locator": try .encoded(locator)]
            if let proposedText { arguments["proposedText"] = .string(proposedText) }
            next = pinned(next, arguments: arguments, snapshot: authority.snapshot, foreground: true)
            // The native owner may advance its retained source observation only
            // after the exact commentary receipt. The next admission verifies
            // that new reader and its original visible segment again.
            return [opened, await executeNativeStep(next, authority: authority)]
        } catch { return [opened, refused(next, error)] }
    }

    private func executeRead(_ request: ActionRequest, authority: ActionJourneyAuthority,
                             observe: Authority) async -> ActionResult {
        do {
            try require(authority, observe: observe)
            let result = await core.execute(request, context: authority.context)
            // Revoke before publishing: no count, candidates or text survive a
            // changed credential/grant, source observation, or cancellation.
            try require(authority, observe: observe)
            try validate(result, request: request, authority: authority)
            return result
        } catch { return refused(request, error) }
    }

    private func executeNativeStep(_ request: ActionRequest, authority: ActionJourneyAuthority) async -> ActionResult {
        do {
            try require(authority, observe: navigationAuthority)
            let result = try await executeNative(request, authority)
            do { try validate(result, request: request, authority: authority) }
            catch { throw ActionNativeUIFailure(status: .failed, failure: .init(code: "native_effect_uncertain", message: "", retryable: false)) }
            // The original Core's final synchronous receipt owns completion.
            // A note sheet legitimately changes generic scene/chat readiness.
            return result
        } catch { return refused(request, error) }
    }

    private func require(_ expected: ActionJourneyAuthority, observe: Authority) throws {
        try Task.checkCancellation()
        guard try observe() == expected else { throw ActionPortError.staleState }
    }
    private func validate(_ result: ActionResult, request: ActionRequest, authority: ActionJourneyAuthority) throws {
        guard result.requestId == request.requestId, result.action == request.action else { throw ActionPortError.invalidResponse }
        if result.status == .completed {
            guard result.backend == request.expectedBackend, result.backend == authority.snapshot.backend,
                  result.backendGeneration == authority.snapshot.generation else { throw ActionPortError.invalidResponse }
        }
    }
    private func pinned(_ request: ActionRequest, arguments: ActionObject, snapshot: ActionBackendSnapshot,
                        foreground: Bool = false) -> ActionRequest {
        .init(requestId: request.requestId, action: request.action, arguments: arguments,
            expectedBackend: request.expectedBackend ?? snapshot.backend, expectedGeneration: snapshot.generation,
            requestedPresentation: foreground ? .foreground : request.requestedPresentation)
    }
    private func refused(_ request: ActionRequest, _ error: any Error) -> ActionResult {
        let status: ActionStatus
        let failure: ActionFailure
        if let native = error as? ActionNativeUIFailure { status = native.status; failure = native.failure }
        else if let navigation = error as? ActionNavigationError {
            status = navigation.status; failure = .init(code: navigation.code, message: "")
        } else if error is CancellationError { status = .cancelled; failure = .init(code: "cancelled", message: "") }
        else if let port = error as? ActionPortError {
            switch port {
            case .staleState: status = .staleState; failure = .init(code: "backend_generation_changed", message: "")
            case .unavailable: status = .unavailable; failure = .init(code: "backend_unavailable", message: "")
            case .notSupported: status = .notSupported; failure = .init(code: "capability_unavailable", message: "")
            case .notFound: status = .failed; failure = .init(code: "not_found", message: "")
            case .invalidResponse: status = .failed; failure = .init(code: "invalid_backend_response", message: "")
            }
        } else if error is ActionContractError || error is DecodingError {
            status = .failed; failure = .init(code: "invalid_arguments", message: "")
        } else { status = .failed; failure = .init(code: "journey_failed", message: "") }
        return .init(request: request, status: status, error: failure, backend: request.expectedBackend)
    }
}
