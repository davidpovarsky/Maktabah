import Foundation

public actor ActionExecutor {
    private let registry: ActionRegistry
    private let state: any ActionBackendStatePort
    private let resolver: any ActionResolverPort
    private let search: any ActionSearchPort
    private let ui: (any ActionUICommandSink)?
    private let clock: any ActionClock
    private let navigationAuthority: (any ActionNavigationAuthority)?
    private let capacity: Int
    private var workers = 0
    private let maxWorkers = 8
    private var ledger: [RequestKey: Entry] = [:]
    private var budgets: [BudgetKey: Int] = [:]
    private var resultBytes = 0
    private let maxRetainedResultBytes = 4 * 1024 * 1024

    private struct RequestKey: Hashable { let subject: String; let id: UUID }
    private struct BudgetKey: Hashable { let subject: String; let correlation: UUID }
    private struct Authority: Equatable {
        let origin: ActionOrigin
        let allowed: Set<ActionBackendID>
        let rights: Set<ActionBackendID>
        let scopes: Set<ActionScope>
        let works: [ActionBackendID: Set<String>]?
        let scene: String?
        let paired: Bool
        let correlation: UUID
        let bytes: Int
        init(_ context: ActionExecutionContext) {
            origin = context.origin; allowed = context.allowedBackends; rights = context.contentRights; scopes = context.scopes
            works = context.allowedWorkKeys; scene = context.foregroundSceneID; paired = context.pairedDeviceAvailable
            correlation = context.correlationID; bytes = context.maxResultBytes
        }
    }
    private struct Entry {
        let request: ActionRequest
        let authority: Authority
        var result: ActionResult?
        var snapshot: ActionBackendSnapshot?
    }

    public init(state: any ActionBackendStatePort, resolver: any ActionResolverPort, search: any ActionSearchPort,
                ui: (any ActionUICommandSink)? = nil, registry: ActionRegistry? = nil,
                clock: any ActionClock = SystemActionClock(), ledgerCapacity: Int = 256,
                navigationAuthority: (any ActionNavigationAuthority)? = nil) throws {
        guard (1...256).contains(ledgerCapacity) else { throw ActionContractError.invalid("ledgerCapacity") }
        self.registry = try registry ?? ActionRegistry(); self.state = state; self.resolver = resolver
        self.search = search; self.ui = ui; self.clock = clock; capacity = ledgerCapacity
        self.navigationAuthority = navigationAuthority
    }

    /// All untrusted transport adapters use this entry point and the same DTO.
    public func execute(data: Data, context: ActionExecutionContext) async -> ActionResult {
        do { return await execute(try ActionWireCodec.decodeRequest(data), context: context) }
        catch { return failure(ActionRequest(action: "system.invalid"), error: error) }
    }

    public func execute(_ request: ActionRequest, context: ActionExecutionContext) async -> ActionResult {
        let key = RequestKey(subject: context.subjectID, id: request.requestId)
        do {
            try Task.checkCancellation()
            let action = try ActionValidation.request(request, registry: registry)
            try ActionPolicy.authorize(action, context: context, backend: action.explicitBackend)
            // Metadata is not implementation. Mutations/counts never reach ports.
            if request.action == "search.countOccurrences" { throw ActionEngineFailure(.notSupported, "exact_count_unavailable") }
            guard ActionRegistry.implemented.contains(request.action), !action.descriptor.mutatesUserData, action.descriptor.riskTier < 3 else {
                throw ActionEngineFailure(.notSupported, "action_not_implemented")
            }
            if request.action == "reader.openCommentary", !(await commentaryNavigationAvailable()) {
                throw ActionEngineFailure(.notSupported, "commentary_navigation_unavailable")
            }
            let existing = ledger[key]
            if let existing {
                guard try equivalent(existing.request, request), existing.authority == Authority(context) else { throw ActionEngineFailure(.failed, "request_replay_conflict") }
                guard existing.result != nil else { throw ActionEngineFailure(.unavailable, "request_in_progress") }
            } else {
                guard ledger.count < capacity else { throw ActionEngineFailure(.unavailable, "request_ledger_full") }
                let budget = BudgetKey(subject: context.subjectID, correlation: context.correlationID)
                guard budgets[budget, default: 0] < context.maxActions else { throw ActionEngineFailure(.failed, "action_budget_exceeded") }
                guard budgets[budget] != nil || budgets.count < capacity else { throw ActionEngineFailure(.unavailable, "request_ledger_full") }
                budgets[budget, default: 0] += 1
                ledger[key] = Entry(request: request, authority: Authority(context))
            }
            guard workers < maxWorkers else {
                let result = failure(request, error: ActionEngineFailure(.unavailable, "executor_busy"))
                if existing == nil { ledger[key]?.result = result }
                return result
            }
            workers += 1
            let duration = UInt64(request.deadlineMs ?? 5_000) * 1_000_000
            let (sum, overflow) = clock.now().addingReportingOverflow(duration)
            let deadline = overflow ? UInt64.max : sum
            let result: ActionResult
            do {
                result = try await ActionDeadline.run(until: deadline, clock: clock, operation: { [self] in
                    try await perform(action, context: context, deadline: deadline, cached: existing)
                }, onWorkerFinished: { [weak self] in await self?.workerFinished() })
            } catch { result = failure(request, error: error) }
            let safe = checkedResult(result, request: request, context: context)
            if existing == nil {
                let cost = (try? JSONEncoder().encode(safe).count) ?? 0
                if resultBytes + cost <= maxRetainedResultBytes {
                    resultBytes += cost; ledger[key]?.result = safe
                } else { ledger[key]?.result = failure(request, error: ActionEngineFailure(.unavailable, "result_budget_exceeded")) }
            }
            return safe
        } catch { return failure(request, error: error) }
    }

    private func workerFinished() { workers -= 1 }

    /// UI-only preparation. No descriptor advertisement is a commit grant.
    /// Content preparations are minted ONLY inside validated reader.open below.
    public func prepareNavigation(sceneID: String, invocation: ActionPortInvocation,
                                  context: ActionExecutionContext) async throws -> ActionNavigationPreparation {
        try await prepareNavigationSynchronously(sceneID: sceneID, invocation: invocation, context: context)
    }

    /// Capture the SAME injected native/backend authority before a host's first
    /// await. This is still surface-only; it cannot issue a content grant.
    @MainActor public func prepareNavigationSynchronously(sceneID: String, invocation: ActionPortInvocation,
                                                                      context: ActionExecutionContext) throws -> ActionNavigationPreparation {
        guard let backendAuthority = state as? any ActionSynchronousBackendStatePort else {
            throw ActionNavigationError(.unavailable, "synchronous_navigation_authority_unavailable")
        }
        guard let navigationAuthority else { throw ActionNavigationError(.unavailable, "navigation_context_authority_unavailable") }
        return try ActionNavigationPreparation(authority: navigationAuthority, backendAuthority: backendAuthority, invocation: invocation, sceneID: sceneID,
            context: context, destination: nil, clock: clock)
    }

    /// Metadata only: verify policy AND actual live guard availability. No grant
    /// is returned/retained and no effect is authorized by discovery.
    public func checkNavigationDiscovery(sceneID: String, invocation: ActionPortInvocation,
                                        context: ActionExecutionContext) async throws {
        do { try ActionPolicy.navigation(context: context, backend: invocation.snapshot.backend, sceneID: sceneID, discovery: true) }
        catch let error as ActionEngineFailure { throw ActionNavigationError(error.status, error.code) }
        _ = try await prepareNavigation(sceneID: sceneID, invocation: invocation, context: context)
    }

    private func perform(_ action: ValidatedAction, context: ActionExecutionContext, deadline: UInt64, cached: Entry?) async throws -> ActionResult {
        let request = action.request
        try checkDeadline(deadline)
        let snapshot = try await state.snapshot()
        try checkDeadline(deadline)
        if snapshot.backend == .sefariaEmbedded && snapshot.rpcEpoch == nil { throw ActionEngineFailure(.unavailable, "rpc_unavailable") }
        let backend = action.explicitBackend ?? snapshot.backend
        try ActionPolicy.authorize(action, context: context, backend: backend)
        if backend != snapshot.backend {
            return ActionResult(request: request, status: .requiresBackendSwitch,
                data: ["activeBackend": .string(snapshot.backend.rawValue), "requestedBackend": .string(backend.rawValue)],
                error: safeError("backend_selection_required"), backend: backend)
        }
        if let generation = request.expectedGeneration, generation != snapshot.generation { throw ActionEngineFailure(.staleState, "backend_generation_changed") }
        if let cached, let result = cached.result {
            guard cached.snapshot == snapshot else { throw ActionEngineFailure(.staleState, "backend_generation_changed") }
            return result
        }
        let key = RequestKey(subject: context.subjectID, id: request.requestId)
        ledger[key]?.snapshot = snapshot
        let invocation = ActionPortInvocation(requestId: request.requestId, snapshot: snapshot, deadlineUptimeNanoseconds: deadline)
        func completed(_ data: ActionObject) -> ActionResult {
            ActionResult(request: request, status: .completed, data: data, backend: backend, backendGeneration: snapshot.generation)
        }
        if request.action == "system.listBackends" {
            // The report port has no variant contract yet. Refuse rather than
            // invent mode support from broad flags or silently ignore the flag.
            if request.arguments["includeModes"] == .bool(true) { throw ActionEngineFailure(.notSupported, "mode_discovery_unavailable") }
            let includeReadiness = request.arguments["includeReadiness"] == .bool(true)
            let commentaryAvailable = await commentaryNavigationAvailable()
            let searchResultsAvailable = ui is any ActionSearchResultsUICommandSink
            var reports: [ActionJSON] = []
            for target in ActionBackendID.allCases {
                let report: ActionBackendReport?
                if context.allowedBackends.contains(target) {
                    report = try await state.report(for: target)
                    guard report?.id == target else { throw ActionPortError.invalidResponse }
                    try await recheck(snapshot, deadline: deadline)
                } else { report = nil }
                var operations: ActionObject = [:]
                for descriptor in registry.descriptors {
                    let raw = report?.operations[descriptor.id]
                    let implemented = ActionRegistry.implemented.contains(descriptor.id)
                        && (descriptor.id != "reader.openCommentary" || commentaryAvailable)
                        && (descriptor.id != "search.openResults" || searchResultsAvailable)
                    let supported = implemented && raw?.registered == true && raw?.supported == true
                    var fields: ActionObject = ["registered": .bool(raw?.registered == true), "supported": .bool(supported)]
                    if includeReadiness { fields["availableNow"] = .bool(supported && raw?.availableNow == true && target == snapshot.backend) }
                    if !supported { fields["reasonCode"] = .string(implemented ? "capability_unavailable" : "action_not_implemented") }
                    else if includeReadiness && target != snapshot.backend { fields["reasonCode"] = .string("backend_selection_required") }
                    else if includeReadiness && raw?.availableNow != true {
                        fields["reasonCode"] = .string(ActionPolicy.safeReason(raw?.reasonCode, fallback: "backend_unavailable"))
                    }
                    operations[descriptor.id] = .object(fields)
                }
                reports.append(.object(["id": .string(target.rawValue), "operations": .object(operations)]))
            }
            return completed(["backends": .array(reports)])
        }

        let openResultsQuery = request.action == "search.openResults" ? try ActionSearchResultsQuery.arguments(request.arguments, backend: backend) : nil
        let searchQuery = request.action == "search.query" ? try ActionValidation.search(request.arguments, backend: backend) : openResultsQuery?.search
        if let searchQuery { try ActionPolicy.search(searchQuery, context: context) }
        // Assessment and execution see the exact same normalized search defaults.
        let effectiveArguments = try searchQuery.map { try ActionJSON.encoded($0).object ?? [:] } ?? request.arguments
        let assessment = try await state.assess(action: request.action, arguments: effectiveArguments, invocation: invocation)
        try await recheck(snapshot, deadline: deadline)
        try ActionPolicy.capability(assessment)
        let result: ActionResult
        var navigationCompletion: ActionNavigationPreparation? = nil
        var searchCompletion: ((any ActionSearchResultsUICommandSink), ActionOpenSearchResultsCommand, ActionSearchResultsReceipt)?
        switch request.action {
        case "catalog.resolveWork":
            let ref = try request.arguments["workRef"]?.decoded(as: ActionWorkRef.self)
            if let ref { try ActionValidation.work(ref, backend: backend); try ActionPolicy.work(ref.workKey, backend: backend, context: context) }
            let query = ActionResolveWorkQuery(backend: backend, query: request.arguments["query"]?.string, workRef: ref,
                limit: try ActionValidation.integer(request.arguments, key: "limit", default: 25, range: 1...25))
            if let text = query.query, !ActionValidation.nonempty(text, max: 512) { throw ActionContractError.invalid("query") }
            let resolution = try await resolver.resolveWork(query, invocation: invocation)
            try await recheck(snapshot, deadline: deadline)
            switch resolution {
            case .unique(let work):
                do { try ActionValidation.work(work, backend: backend) } catch { throw ActionPortError.invalidResponse }
                try ActionPolicy.work(work.workKey, backend: backend, context: context)
                guard ref == nil || ref?.workKey == work.workKey else { throw ActionPortError.invalidResponse }
                result = completed(["workRef": try ActionJSON.encoded(work)])
            case .ambiguous(let candidates): result = try ambiguity(candidates, limit: query.limit, request: request, context: context, snapshot: snapshot)
            case .notFound: throw ActionPortError.notFound
            }
        case "catalog.resolveReference":
            let ref = try request.arguments["workRef"]?.decoded(as: ActionWorkRef.self)
            if let ref { try ActionValidation.work(ref, backend: backend); try ActionPolicy.work(ref.workKey, backend: backend, context: context) }
            let query = ActionResolveReferenceQuery(backend: backend, text: request.arguments["text"]?.string, workRef: ref, section: request.arguments["section"]?.string)
            if let text = query.text, !ActionValidation.nonempty(text, max: 1000) { throw ActionContractError.invalid("text") }
            switch try await resolver.resolveReference(query, invocation: invocation) {
            case .unique(let resolved):
                do { try ActionValidation.text(resolved, backend: backend) } catch { throw ActionPortError.invalidResponse }
                try ActionPolicy.work(resolved.workKey, backend: backend, context: context)
                guard ref == nil || ref?.workKey == resolved.workKey else { throw ActionPortError.invalidResponse }
                result = completed(["locator": try ActionJSON.encoded(resolved)])
            case .ambiguous(let candidates): result = try ambiguity(candidates, limit: 25, request: request, context: context, snapshot: snapshot)
            case .notFound: throw ActionPortError.notFound
            }
        case "search.query":
            guard let query = searchQuery else { throw ActionPortError.invalidResponse }
            let page = try await search.search(query, invocation: invocation)
            try validate(page, query: query, context: context)
            result = completed(try ActionJSON.encoded(page).object ?? [:])
        case "search.openResults":
            guard let query = openResultsQuery else { throw ActionPortError.invalidResponse }
            if let reason = ActionSearchResultsQuery.unsupportedReason(query.search) {
                throw ActionEngineFailure(.notSupported, reason)
            }
            guard request.requestedPresentation != .headless, let scene = ActionPolicy.foregroundScene(context),
                  let searchUI = ui as? any ActionSearchResultsUICommandSink else {
                throw ActionEngineFailure(.requiresForeground, "app_scene_unavailable")
            }
            // Scope identities are resolved by the original canonical catalog,
            // never fabricated from a displayed label or an arbitrary integer.
            for ref in query.search.scopeWorkRefs {
                let resolution = try await resolver.resolveWork(.init(backend: backend, query: nil, workRef: ref, limit: 1), invocation: invocation)
                guard case .unique(let resolved) = resolution, resolved == ref else { throw ActionPortError.notFound }
                try await recheck(snapshot, deadline: deadline)
            }
            try await searchUI.prepareSearchResults(query, context: context, invocation: invocation)
            try await recheck(snapshot, deadline: deadline)
            guard let navigationAuthority, let backendAuthority = state as? any ActionSynchronousBackendStatePort else {
                throw ActionNavigationError(.unavailable, "synchronous_navigation_authority_unavailable")
            }
            let authorization = try await ActionNavigationPreparation(authority: navigationAuthority,
                backendAuthority: backendAuthority, invocation: invocation, sceneID: scene,
                context: context, destination: nil, clock: clock, searchQuery: query)
            let command = ActionOpenSearchResultsCommand(query: query, sceneID: scene, invocation: invocation,
                navigationAuthorization: authorization)
            switch try await searchUI.openSearchResults(command) {
            case .acknowledged(let receipt):
                guard receipt.requestId == request.requestId, receipt.snapshot == snapshot, receipt.sceneID == scene,
                      receipt.query == query, receipt.submissionRevision > 0 else { throw ActionPortError.invalidResponse }
                navigationCompletion = authorization
                searchCompletion = (searchUI, command, receipt)
                result = ActionResult(request: request, status: .completed, backend: backend,
                    backendGeneration: snapshot.generation, effects: ["search_results_opened"])
            case .queued(let handle):
                guard handle.range(of: "^[A-Za-z0-9_-]{8,128}$", options: .regularExpression) != nil else { throw ActionPortError.invalidResponse }
                result = ActionResult(request: request, status: .uiQueued, data: ["handle": .string(handle)],
                    backend: backend, backendGeneration: snapshot.generation, effects: ["search_command_queued"])
            case .requiresForeground:
                throw ActionEngineFailure(.requiresForeground, "app_scene_unavailable")
            }
        case "reader.open", "reader.openCommentary":
            let destination: ActionReaderDestination
            if request.action == "reader.openCommentary" {
                guard let commentary = resolver as? any ActionCommentaryResolverPort,
                      let rawBase = request.arguments["baseLocator"] else { throw ActionPortError.notSupported }
                let base = try rawBase.decoded(as: ActionTextRef.self)
                let selected = try request.arguments["workRef"]?.decoded(as: ActionWorkRef.self)
                try ActionPolicy.work(base.workKey, backend: backend, context: context)
                if let selected { try ActionPolicy.work(selected.workKey, backend: backend, context: context) }
                let resolved = try await commentary.resolveCommentary(.init(baseLocator: base, workRef: selected,
                    commentaryQuery: request.arguments["commentaryQuery"]?.string), invocation: invocation)
                try await recheck(snapshot, deadline: deadline)
                switch resolved {
                case .unique(let value):
                    do {
                        try ActionValidation.text(value.sectionLocator, backend: backend)
                        if let focus = value.focusLocator {
                            try ActionValidation.text(focus, backend: backend)
                            guard focus.workKey == value.sectionLocator.workKey else { throw ActionPortError.invalidResponse }
                        }
                    } catch { throw ActionPortError.invalidResponse }
                    guard value.presentationMode == .sameTab,
                          selected == nil || selected?.workKey == value.sectionLocator.workKey else { throw ActionPortError.invalidResponse }
                    // A commentary is another source. Preserve the base reader
                    // through the existing native new-tab reservation.
                    destination = ActionReaderDestination(sectionLocator: value.sectionLocator,
                        focusLocator: value.focusLocator, presentationMode: .newTab)
                case .ambiguous(let candidates):
                    return try ambiguity(candidates, limit: 25, request: request, context: context, snapshot: snapshot)
                case .notFound: throw ActionPortError.notFound
                }
            } else { destination = try ActionValidation.destination(request.arguments) }
            try ActionPolicy.work(destination.sectionLocator.workKey, backend: backend, context: context)
            guard request.requestedPresentation != .headless, let scene = ActionPolicy.foregroundScene(context),
                  let ui else { throw ActionEngineFailure(.requiresForeground, "app_scene_unavailable") }
            let validated = try await resolver.validateDestination(destination, invocation: invocation)
            guard validated == destination else { throw ActionPortError.invalidResponse }
            try await recheck(snapshot, deadline: deadline)
            if request.action == "reader.openCommentary" {
                guard let preparedUI = ui as? any ActionCommentaryUICommandSink else { throw ActionPortError.notSupported }
                try await preparedUI.prepareCommentaryReader(validated, context: context, invocation: invocation)
                try await recheck(snapshot, deadline: deadline)
            }
            let authorization: ActionNavigationPreparation?
            if let navigationAuthority {
                guard let backendAuthority = state as? any ActionSynchronousBackendStatePort else {
                    throw ActionNavigationError(.unavailable, "synchronous_navigation_authority_unavailable")
                }
                authorization = try await ActionNavigationPreparation(authority: navigationAuthority, backendAuthority: backendAuthority, invocation: invocation, sceneID: scene,
                    context: context, destination: validated, clock: clock)
            } else { authorization = nil }
            let command = ActionOpenReaderCommand(destination: validated, sceneID: scene, invocation: invocation, navigationAuthorization: authorization)
            let acknowledgement = try await ui.open(command)
            try await recheck(snapshot, deadline: deadline)
            switch acknowledgement {
            case .acknowledged(let receipt):
                guard receipt.requestId == request.requestId, receipt.snapshot == snapshot, receipt.sceneID == scene,
                      receipt.destination == validated else { throw ActionPortError.invalidResponse }
                navigationCompletion = authorization
                result = ActionResult(request: request, status: .completed, backend: backend, backendGeneration: snapshot.generation, effects: ["reader_opened"])
            case .queued(let handle):
                guard handle.range(of: "^[A-Za-z0-9_-]{8,128}$", options: .regularExpression) != nil else { throw ActionPortError.invalidResponse }
                result = ActionResult(request: request, status: .uiQueued, data: ["handle": .string(handle)], backend: backend, backendGeneration: snapshot.generation, effects: ["reader_command_queued"])
            case .requiresForeground: throw ActionEngineFailure(.requiresForeground, "app_scene_unavailable")
            }
        default: throw ActionEngineFailure(.notSupported, "action_not_implemented")
        }
        try await recheck(snapshot, deadline: deadline)
        // This synchronous MainActor check observes BOTH retained authorities
        // after the last backend/readiness await. Do not add another readiness
        // await after it; this is not an atomic cross-actor commit barrier.
        if let searchCompletion, let navigationCompletion {
            try await Self.validateSearchCompletion(searchCompletion, authorization: navigationCompletion)
        } else if let navigationCompletion { try await navigationCompletion.validateCompletion() }
        return result
    }

    @MainActor private static func validateSearchCompletion(
        _ completion: ((any ActionSearchResultsUICommandSink), ActionOpenSearchResultsCommand, ActionSearchResultsReceipt),
        authorization: ActionNavigationPreparation) throws {
        try authorization.validateCompletion()
        try completion.0.validateSearchResultsCompletion(completion.1, receipt: completion.2)
    }

    private func recheck(_ snapshot: ActionBackendSnapshot, deadline: UInt64) async throws {
        try checkDeadline(deadline)
        let current = try await state.snapshot()
        try checkDeadline(deadline)
        guard current == snapshot else { throw ActionEngineFailure(.staleState, "backend_generation_changed") }
    }
    private func checkDeadline(_ deadline: UInt64) throws {
        try Task.checkCancellation()
        guard clock.now() < deadline else { throw ActionEngineFailure(.cancelled, "deadline_exceeded") }
    }

    private func ambiguity(_ candidates: [ActionCandidate], limit: Int, request: ActionRequest,
                           context: ActionExecutionContext, snapshot: ActionBackendSnapshot) throws -> ActionResult {
        guard !candidates.isEmpty, candidates.count <= 10_000 else { throw ActionPortError.invalidResponse }
        let capped = Array(candidates.prefix(min(25, limit)))
        var safeCandidates: [ActionCandidate] = []
        for candidate in capped {
            guard ActionValidation.nonempty(candidate.title, max: 512), (candidate.reason?.unicodeScalars.count ?? 0) <= 500 else { throw ActionPortError.invalidResponse }
            try ActionValidation.bounded(.object(candidate.ref))
            let work: String
            switch candidate.kind {
            case .work, .commentary:
                guard let schema = registry.descriptor(for: "catalog.resolveWork")?.argumentsSchema.object?["properties"]?.object?["workRef"] else { throw ActionPortError.invalidResponse }
                do { try ActionSchemaValidator.validate(.object(candidate.ref), schema: schema) } catch { throw ActionPortError.invalidResponse }
                let ref = try ActionJSON.object(candidate.ref).decoded(as: ActionWorkRef.self)
                try ActionValidation.work(ref, backend: snapshot.backend); work = ref.workKey
            case .section, .segment:
                guard let schema = registry.descriptor(for: "reader.getSection")?.argumentsSchema.object?["properties"]?.object?["sectionLocator"] else { throw ActionPortError.invalidResponse }
                do { try ActionSchemaValidator.validate(.object(candidate.ref), schema: schema) } catch { throw ActionPortError.invalidResponse }
                let ref = try ActionJSON.object(candidate.ref).decoded(as: ActionTextRef.self)
                try ActionValidation.text(ref, backend: snapshot.backend); work = ref.workKey
            }
            try ActionPolicy.work(work, backend: snapshot.backend, context: context)
            // Explanations are optional. Do not relay opaque provider debug text
            // (paths, SQL or private notes) as a user-facing reason.
            safeCandidates.append(ActionCandidate(ref: candidate.ref, title: candidate.title, kind: candidate.kind, confidenceBand: candidate.confidenceBand))
        }
        return ActionResult(request: request, status: .needsDisambiguation, candidates: safeCandidates, backend: snapshot.backend, backendGeneration: snapshot.generation)
    }
    private func validate(_ page: ActionSearchPage, query: ActionSearchQuery, context: ActionExecutionContext) throws {
        guard page.hits.count <= query.limit, Set(page.hits.map(\.id)).count == page.hits.count,
              page.total == nil || page.total! >= 0, page.precision != .exact || page.total != nil else { throw ActionPortError.invalidResponse }
        if let next = page.nextOffset { guard next > query.offset, next <= 100_000 else { throw ActionPortError.invalidResponse } }
        if page.precision == .exact, page.totalSemantics == .matchingSegments, let total = page.total {
            guard total >= query.offset + page.hits.count || page.hits.isEmpty else { throw ActionPortError.invalidResponse }
        }
        let scope = Set(query.scopeWorkRefs.map(\.workKey))
        for hit in page.hits {
            do { try ActionValidation.text(hit.locator, backend: query.backend) } catch { throw ActionPortError.invalidResponse }
            try ActionPolicy.work(hit.locator.workKey, backend: query.backend, context: context)
            guard ActionValidation.nonempty(hit.id, max: 512), hit.title.unicodeScalars.count <= 512, hit.snippet.unicodeScalars.count <= 2000,
                  scope.isEmpty || scope.contains(hit.locator.workKey) else { throw ActionPortError.invalidResponse }
        }
    }

    /// Discovery is policy- and availability-filtered, never the raw29 catalog.
    private func commentaryNavigationAvailable() async -> Bool {
        guard ui is any ActionCommentaryUICommandSink,
              let commentary = resolver as? any ActionCommentaryResolverPort else { return false }
        return await commentary.canResolveCommentary()
    }

    public func advertisedActions(for backend: ActionBackendID, context: ActionExecutionContext) async -> [ActionDescriptor] {
        let request = ActionRequest(action: "system.listBackends", arguments: ["includeReadiness": .bool(true)], expectedBackend: backend)
        let result = await execute(request, context: context)
        guard result.status == .completed, let reports = result.data?["backends"]?.array,
              let report = reports.first(where: { $0.object?["id"] == .string(backend.rawValue) })?.object,
              let operations = report["operations"]?.object else { return [] }
        return registry.descriptors.filter { descriptor in
            guard ActionRegistry.implemented.contains(descriptor.id), operations[descriptor.id]?.object?["availableNow"] == .bool(true) else { return false }
            guard (try? ActionPolicy.authorize(descriptor, context: context, backend: backend)) != nil else { return false }
            return !["reader.open", "reader.openCommentary", "search.openResults"].contains(descriptor.id) || (ActionPolicy.foregroundScene(context) != nil && ui != nil)
        }
    }

    private func equivalent(_ lhs: ActionRequest, _ rhs: ActionRequest) throws -> Bool {
        if lhs == rhs { return true }
        // Already-validated signed/unsigned storage for the same JSON integer
        // must not turn a typed-to-wire retry into a different logical request.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(lhs) == encoder.encode(rhs)
    }

    private func checkedResult(_ result: ActionResult, request: ActionRequest, context: ActionExecutionContext) -> ActionResult {
        do {
            let data = try ActionWireCodec.encodeResult(result)
            guard data.count <= context.maxResultBytes else { throw ActionEngineFailure(.failed, "result_budget_exceeded") }
            return result
        } catch { return failure(request, error: error) }
    }
    private func safeError(_ code: String) -> ActionFailure {
        ActionFailure(code: code, message: "Action could not complete (\(code)).", retryable: ["backend_unavailable", "device_offline", "app_scene_unavailable", "backend_generation_changed", "executor_busy", "request_in_progress"].contains(code))
    }
    private func failure(_ request: ActionRequest, error: any Error) -> ActionResult {
        let status: ActionStatus, code: String
        if let e = error as? ActionEngineFailure { status = e.status; code = e.code }
        else if error is CancellationError { status = .cancelled; code = "cancelled" }
        else if error is ActionContractError || error is DecodingError { status = .failed; code = "invalid_arguments" }
        else if let e = error as? ActionNavigationError { status = e.status; code = e.code }
        else if let e = error as? ActionPortError {
            switch e {
            case .unavailable: status = .unavailable; code = "backend_unavailable"
            case .notSupported: status = .notSupported; code = "capability_unavailable"
            case .notFound: status = .failed; code = "not_found"
            case .staleState: status = .staleState; code = "backend_generation_changed"
            case .invalidResponse: status = .failed; code = "invalid_backend_response"
            }
        } else { status = .failed; code = "provider_failed" }
        // Never echo malformed action names or arbitrary provider descriptions.
        let safe = request.action.unicodeScalars.count <= 80 && request.action.range(of: "^[a-z][a-zA-Z0-9]*(\\.[a-zA-Z0-9]+)+$", options: .regularExpression) != nil
            ? request : ActionRequest(requestId: request.requestId, action: "system.invalid")
        return ActionResult(request: safe, status: status, error: safeError(code), backend: request.expectedBackend)
    }
}
