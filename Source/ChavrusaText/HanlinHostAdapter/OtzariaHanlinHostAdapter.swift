import Foundation
import HanlinPlatformContracts
import HanlinHostContracts
import OtzariaActionCore

/// Supplied by the existing app/scene authority, never decoded from model input.
/// A producer must read the canonical owner on every call and revoke generation
/// for account, backend, scene, selection, rights or source-revision changes.
public struct OtzariaHanlinBinding: Sendable, Equatable {
    public let context: HanlinHostContext
    public let executionContext: ActionExecutionContext
    /// Optional host-issued content authority for search only. Metadata and
    /// navigation keep their original context; model arguments cannot select it.
    public let searchExecutionContext: ActionExecutionContext?
    public let backend: ActionBackendSnapshot
    public let catalogRevision: HanlinCatalogRevision
    public let availableReadActions: Set<String>

    public init(context: HanlinHostContext, executionContext: ActionExecutionContext,
                backend: ActionBackendSnapshot, catalogRevision: HanlinCatalogRevision,
                availableReadActions: Set<String>, searchExecutionContext: ActionExecutionContext? = nil) {
        self.context = context; self.executionContext = executionContext
        self.backend = backend; self.catalogRevision = catalogRevision
        self.availableReadActions = availableReadActions
        self.searchExecutionContext = searchExecutionContext
    }

    // This dispatch is a fixed host mapping, never an argument or model field.
    fileprivate func executionContext(for action: String) -> ActionExecutionContext {
        action == "search.query" ? (searchExecutionContext ?? executionContext) : executionContext
    }
}

/// One original Otzaria work, confirmed by the native reader owner. A license
/// string, opening a chat, selection text, or model argument never constructs
/// this permission. The explicit native connection consent is its issuer.
struct OtzariaHanlinCurrentWorkReadScope: Sendable, Equatable {
    let workRef: ActionWorkRef
    let title: String

    init(workRef: ActionWorkRef, title: String) throws {
        guard workRef.backend == .otzaria, workRef.catalogRevision == nil,
              workRef.workKey.hasPrefix("book:"),
              let bookID = Int64(workRef.workKey.dropFirst(5)), bookID > 0,
              Int(exactly: bookID) != nil, workRef.workKey == "book:" + String(bookID),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.utf8.count <= 4_096 else { throw HanlinHostError.denied }
        self.workRef = workRef; self.title = title
    }

    func searchContext(from metadata: ActionExecutionContext) throws -> ActionExecutionContext {
        guard metadata.origin == .internalAI, metadata.allowedBackends == [.otzaria],
              metadata.scopes.contains(.discovery),
              let scene = metadata.foregroundSceneID, !scene.isEmpty,
              metadata.contentRights.isEmpty, !metadata.scopes.contains(.contentRead) else {
            throw HanlinHostError.denied
        }
        return .init(subjectID: metadata.subjectID, correlationID: metadata.correlationID,
            origin: metadata.origin, allowedBackends: [.otzaria], contentRights: [.otzaria],
            // Original Core discovery executes system.listBackends before it
            // advertises search. Retain that existing permission, without
            // carrying the metadata context's navigation authority.
            scopes: [.discovery, .contentRead], allowedWorkKeys: [.otzaria: [workRef.workKey]],
            foregroundSceneID: scene, maxActions: min(metadata.maxActions, 20),
            maxResultBytes: min(metadata.maxResultBytes, 32_768))
    }

    func modelInstructions() throws -> String {
        let scope = String(decoding: try JSONEncoder().encode([workRef]), as: UTF8.self)
        return "The user authorized bounded read-only search of exactly the current Otzaria work for this connection. "
            + "Use search.query only with backend \"otzaria\" and scopeWorkRefs " + scope
            + ". Include this exact scope in every search. Do not read selections, change library data, or infer access to other works. "
            + "Catalog metadata actions retain their original public metadata scope."
    }
}

/// A transient user-action continuation, not Codable and never persisted. The
/// native owner supplies its full original source observation as Source. Only
/// its exact sheet dismissal may consume this witness, once, for the exact
/// immutable model configuration selected at the user action.
@MainActor
final class OtzariaHanlinCurrentWorkReadConsent<Source: Equatable> {
    let session: HanlinHostSession
    let scope: OtzariaHanlinCurrentWorkReadScope
    let configurationID: UUID
    private let source: Source
    private var available = true

    init(session: HanlinHostSession, scope: OtzariaHanlinCurrentWorkReadScope,
         configurationID: UUID, source: Source) {
        self.session = session; self.scope = scope
        self.configurationID = configurationID; self.source = source
    }

    func consume(dismissedSessionID: UUID, currentSource: Source,
                 namespace: HanlinConversationNamespace, configurationID: UUID) throws -> OtzariaHanlinCurrentWorkReadScope {
        guard available else { throw HanlinHostError.staleContext }
        // A late dismissal belonging to another sheet must not retire this one.
        guard dismissedSessionID == session.id else { throw HanlinHostError.staleContext }
        available = false
        guard currentSource == source, namespace == session.context.namespace,
              configurationID == self.configurationID else { throw HanlinHostError.staleContext }
        return scope
    }

    func revoke() { available = false }
}

/// App-owned seam, deliberately not an SDK permission store or second executor.
/// The installed producer must project the SAME ActionCore/backend/scene owner.
/// open must use the existing registry/orchestrator and actual native receipt;
/// queued is never a synthetic presented acknowledgment.
public protocol OtzariaHanlinHostAuthority: Sendable {
    func current(for session: HanlinHostSession) async throws -> OtzariaHanlinBinding
    func current(for context: HanlinHostContext) async throws -> OtzariaHanlinBinding
    func open(_ destination: HanlinHostDestination,
              binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationResult
}

/// Additive native-owner capability. A transition may only acknowledge the
/// original scene's observed destination and host-issued successor session.
public protocol OtzariaHanlinNavigationAuthority: OtzariaHanlinHostAuthority {
    func openWithContextTransition(_ destination: HanlinHostDestination,
        session: HanlinHostSession, binding: OtzariaHanlinBinding) async throws -> HanlinHostNavigationReceipt
}

/// Compatible with the real Hanlin HostIntegration contract. No chat, agent loop,
/// credentials, MCP transport, persistence or new business/permission engine.
/// The app links the original pinned SDK packages; runtime authority is supplied
/// only by its actual scene owner. Package linkage is not native acceptance.
public actor OtzariaHanlinHostAdapter: HanlinHostNavigationTransitionSource {
    public nonisolated let apiVersion = HanlinAPIVersion(major: 1, minor: 2)
    private let core: ActionExecutor
    private let authority: any OtzariaHanlinHostAuthority
    private let registry: ActionRegistry
    private var workers: [HanlinToolInvocationID: Task<ActionResult, Never>] = [:]
    private var seen = Set<HanlinToolInvocationID>()
    private var pending = Set<HanlinToolInvocationID>()
    private var cancelled = Set<HanlinToolInvocationID>()
    private struct NavigationKey: Hashable { let session: UUID; let request: UUID }
    private var navigationRequests = Set<NavigationKey>()
    private var navigationReceipts: [NavigationKey: HanlinHostNavigationReceipt] = [:]
    private let maximumInvocations = 256
    private let maximumConcurrentInvocations = 8

    /// Original risk-tier-zero actions suitable for the native metadata session.
    /// Core still decides availability for the active backend and scene.
    public static let metadataReadActions: Set<String> = [
        "system.listBackends", "catalog.listAuthors", "catalog.resolveWork", "catalog.resolveReference",
    ]

    // Explicit transport names. Do not sanitize arbitrary untrusted identifiers.
    private static let names: [String: String] = [
        "system.list-backends": "system.listBackends",
        "catalog.list-authors": "catalog.listAuthors",
        "catalog.resolve-work": "catalog.resolveWork",
        "catalog.resolve-reference": "catalog.resolveReference",
        "search.query": "search.query",
        "reader.get-toc": "reader.getTOC",
        "reader.get-navigation-structures": "reader.getNavigationStructures",
        "reader.navigation-items": "reader.navigationItems",
        "reader.list-versions": "reader.listVersions",
    ]

    public init(core: ActionExecutor, authority: any OtzariaHanlinHostAuthority) throws {
        self.core = core; self.authority = authority; registry = try ActionRegistry()
    }

    public func context(for session: HanlinHostSession) async throws -> HanlinHostContext {
        try Task.checkCancellation()
        let binding = try await authority.current(for: session)
        try validateAuthority(binding)
        guard binding.context.namespace == session.context.namespace,
              binding.context.sceneID == session.context.sceneID else { throw HanlinHostError.staleContext }
        try Task.checkCancellation()
        return binding.context
    }

    public func catalog(for context: HanlinHostContext) async throws -> HanlinHostCatalog {
        let binding = try await checkedBinding(context)
        // Policy and current backend readiness belong to the SAME original Core.
        // A local name allowlist is only this transport's read-only surface.
        let advertised = await core.advertisedActions(for: binding.backend.backend, context: binding.executionContext)
        var actionIDs = Set(advertised.map(\.id))
        if let searchContext = binding.searchExecutionContext {
            // Only the fixed search action may use this separately issued grant.
            // Ask the same Core policy/readiness implementation, not a host copy.
            actionIDs.remove("search.query")
            let readActions = await core.advertisedActionsWithExistingSearchPreparation(for: binding.backend.backend, context: searchContext)
            if readActions.contains(where: { $0.id == "search.query" }) { actionIDs.insert("search.query") }
        }
        let catalog = try makeCatalog(binding, advertised: actionIDs)
        // A projection is not a permission grant. Recheck after the Core await.
        guard try await checkedBinding(context) == binding else { throw HanlinHostError.staleContext }
        return catalog
    }

    public func execute(_ invocation: HanlinHostInvocation,
                        progress: @escaping HanlinHostProgressHandler) async throws -> HanlinHostExecutionResult {
        try Task.checkCancellation()
        guard invocation.writeGuarantee == .readOnly else { throw HanlinHostError.unsupportedConditionalWrite }
        let invocationID = invocation.request.id
        guard !seen.contains(invocationID), !pending.contains(invocationID) else {
            throw HanlinHostError.duplicateInvocation
        }
        guard seen.count < maximumInvocations, pending.count < maximumConcurrentInvocations else {
            throw HanlinHostError.storageLimitExceeded
        }
        // Admission itself may suspend. Bound it and remember explicit cancellation
        // before any canonical authority lookup, not only after a worker exists.
        pending.insert(invocationID)
        defer { pending.remove(invocationID); cancelled.remove(invocationID) }
        let binding = try await authority.current(for: invocation.session)
        try checkPendingCancellation(invocationID)
        try validateAuthority(binding)
        guard binding.context == invocation.session.context else { throw HanlinHostError.staleContext }
        if let revision = invocation.expectedRevision, !binding.context.matchesRevision(revision) {
            throw HanlinHostError.staleContext
        }
        let catalog = try makeCatalog(binding)
        let request = invocation.request
        guard request.routingTableRevision == catalog.revision,
              let tool = catalog.tools.first(where: { $0.route.logicalToolID == request.logicalToolID }),
              tool.route.alias == request.aliasUsed, tool.route.descriptorRevision == request.descriptorRevision,
              let action = Self.names[request.logicalToolID.localToolID.rawValue] else {
            throw HanlinHostError.unknownTool
        }
        guard let raw = invocation.originalArgumentsJSON, !raw.isEmpty, raw.count <= 65_536 else {
            throw HanlinHostError.invalidArguments
        }
        // Never reconstruct source arguments from Hanlin's numeric projection.
        // The canonical wire decoder validates duplicate keys, sizes and numbers.
        let now = Date()
        let remaining = request.deadline.map { $0.timeIntervalSince(now) * 1000 } ?? 30_000
        guard remaining.isFinite else { throw HanlinHostError.invalidArguments }
        let milliseconds = min(30_000, request.limits.timeoutMilliseconds, Int64(max(0, min(30_000, remaining))))
        guard milliseconds > 0 else { throw HanlinHostError.deadlineExceeded }
        let envelope = try actionEnvelope(invocation, action: action, binding: binding,
                                          arguments: raw, deadline: Int(milliseconds))
        let canonical = try ActionWireCodec.decodeRequest(envelope)
        // Reservation occurs after the final await, before creating any worker.
        guard try await checkedBinding(binding.context) == binding else { throw HanlinHostError.staleContext }
        try checkPendingCancellation(invocationID)
        guard !seen.contains(request.id) else { throw HanlinHostError.duplicateInvocation }
        guard seen.count < maximumInvocations, workers.count < maximumConcurrentInvocations else {
            throw HanlinHostError.storageLimitExceeded
        }
        seen.insert(request.id)
        let executionContext = binding.executionContext(for: action)
        let task = Task { [core] in await core.execute(canonical, context: executionContext) }
        workers[request.id] = task
        defer { workers.removeValue(forKey: request.id) }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        try Task.checkCancellation()
        guard try await checkedBinding(binding.context) == binding else { throw HanlinHostError.staleContext }
        if cancelled.contains(invocationID), result.status != .cancelled { throw CancellationError() }
        let encoded = try JSONEncoder().encode(result)
        guard encoded.count <= min(request.limits.maximumOutputBytes, executionContext.maxResultBytes) else {
            throw HanlinHostError.outputLimitExceeded
        }
        let outcome: HanlinToolOutcome
        if result.status == .completed {
            // Canonical JSON text preserves exact integer and metadata values.
            // Hanlin treats this as tool output, not trusted instructions.
            outcome = .completed([.text(String(decoding: encoded, as: UTF8.self))])
        } else {
            let code: HanlinErrorCode = result.status == .cancelled ? .cancelled
                : result.status == .failed ? .nativeFailure : .operationUnavailable
            outcome = .failed(.init(code: code, userMessage: result.error?.message ?? result.status.rawValue,
                details: .object(["actionStatus": .string(result.status.rawValue),
                                  "actionCode": .string(result.error?.code ?? result.status.rawValue)])))
        }
        return .init(result: .init(invocationID: request.id, logicalToolID: request.logicalToolID,
            outcome: outcome, startedAt: now, completedAt: Date()),
            effectState: .confirmedNoEffect, context: binding.context)
    }

    public func cancel(_ invocation: HanlinToolInvocationID) async {
        guard pending.contains(invocation) else { return }
        cancelled.insert(invocation)
        workers[invocation]?.cancel()
    }

    private func checkPendingCancellation(_ invocation: HanlinToolInvocationID) throws {
        try Task.checkCancellation()
        if cancelled.contains(invocation) { throw CancellationError() }
    }

    public func open(_ destination: HanlinHostDestination) async throws -> HanlinHostNavigationResult {
        let binding = try await checkedBinding(destination.context)
        guard binding.executionContext.scopes.contains(.navigation),
              let nativeSceneID = binding.executionContext.foregroundSceneID,
              !nativeSceneID.isEmpty, nativeSceneID.utf8.count <= 256 else {
            throw HanlinHostError.denied
        }
        // Native session identifiers are opaque strings, independent of the SDK
        // scene UUID. The trusted authority binds both lifetimes and the SAME
        // native registry/Core validates its real scene before any UI effect.
        // The existing scene owner performs its canonical final precommit/receipt
        // checks. This adapter cannot manufacture a native acknowledgment.
        let result = try await authority.open(destination, binding: binding)
        try result.validate(for: destination)
        return result
    }

    public func openWithContextTransition(_ destination: HanlinHostDestination,
                                          session: HanlinHostSession) async throws -> HanlinHostNavigationReceipt {
        try Task.checkCancellation()
        guard destination.context == session.context else { throw HanlinHostError.staleContext }
        let binding = try await authority.current(for: session)
        try validateAuthority(binding)
        guard binding.context == session.context else { throw HanlinHostError.staleContext }
        guard binding.executionContext.scopes.contains(.navigation),
              let scene = binding.executionContext.foregroundSceneID,
              !scene.isEmpty, scene.utf8.count <= 256 else { throw HanlinHostError.denied }
        guard let native = authority as? any OtzariaHanlinNavigationAuthority else {
            throw HanlinHostError.unsupportedVersion
        }
        try Task.checkCancellation()
        let key = NavigationKey(session: session.id, request: destination.requestID)
        guard !navigationRequests.contains(key) else { throw HanlinHostError.duplicateInvocation }
        guard navigationRequests.count < maximumInvocations else { throw HanlinHostError.storageLimitExceeded }
        navigationRequests.insert(key)
        // Once entered, the original native owner may already have changed UI.
        // Retain its reservation and correlated receipt even if delivery is
        // subsequently suppressed; callers must never retry an uncertain route.
        let receipt = try await native.openWithContextTransition(destination, session: session, binding: binding)
        try receipt.validate(for: destination, session: session)
        navigationReceipts[key] = receipt
        try Task.checkCancellation()
        let next = receipt.successorSession ?? session
        let current = try await authority.current(for: next)
        try validateAuthority(current)
        try Task.checkCancellation()
        guard current.context == next.context else { throw HanlinHostError.staleContext }
        return receipt
    }

    /// Reconciliation evidence only; this does not establish current authority.
    public func navigationReceipt(for requestID: UUID, session: HanlinHostSession) -> HanlinHostNavigationReceipt? {
        navigationReceipts[.init(session: session.id, request: requestID)]
    }

    private func checkedBinding(_ context: HanlinHostContext) async throws -> OtzariaHanlinBinding {
        try Task.checkCancellation()
        let value = try await authority.current(for: context)
        try validateAuthority(value)
        guard value.context == context else { throw HanlinHostError.staleContext }
        try Task.checkCancellation()
        return value
    }

    private func validateAuthority(_ value: OtzariaHanlinBinding) throws {
        guard [.internalAI, .mcp, .guide].contains(value.executionContext.origin),
              value.executionContext.scopes.contains(.discovery),
              value.executionContext.allowedBackends.contains(value.backend.backend),
              value.executionContext.maxResultBytes > 0 else { throw HanlinHostError.denied }
        if let read = value.searchExecutionContext {
            // A separate content context must still belong to this same native
            // subject, scene and invocation budget. Core alone checks its rights.
            guard read.subjectID == value.executionContext.subjectID,
                  read.correlationID == value.executionContext.correlationID,
                  read.origin == value.executionContext.origin,
                  read.foregroundSceneID == value.executionContext.foregroundSceneID,
                  read.allowedBackends == value.executionContext.allowedBackends else {
                throw HanlinHostError.denied
            }
        }
    }

    private func makeCatalog(_ binding: OtzariaHanlinBinding, advertised: Set<String>? = nil) throws -> HanlinHostCatalog {
        let backendName: String
        switch binding.backend.backend {
        case .otzaria: backendName = "otzaria"
        case .sefaria: backendName = "sefaria"
        case .sefariaEmbedded: backendName = "sefaria-embedded"
        }
        let provider = try HanlinProviderInstanceID(validating: "otzaria.actioncore." + backendName)
        let revision = try HanlinDescriptorRevision(1)
        var tools: [HanlinHostTool] = []
        for (wireName, action) in Self.names.sorted(by: { $0.key < $1.key }) {
            guard binding.availableReadActions.contains(action),
                  advertised?.contains(action) ?? true,
                  ActionRegistry.implemented.contains(action),
                  let descriptor = registry.descriptor(for: action), !descriptor.mutatesUserData else { continue }
            // Execution still uses Core's original schema/policy/readiness checks.
            // Do not reinterpret metadata risk tiers as a parallel permission policy.
            let logical = HanlinLogicalToolID(providerInstanceID: provider,
                localToolID: try HanlinToolID(validating: wireName))
            let schemaBytes = try JSONEncoder().encode(descriptor.argumentsSchema)
            let schema = try HanlinJSONSchemaDocument.decodeCanonicalJSON(schemaBytes, defaultDialect: .draft2020_12)
            let title = try LocalizedValue(["en": descriptor.title])
            let alias = "otzaria_" + wireName.replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: "-", with: "_")
            tools.append(.init(route: .init(alias: alias, logicalToolID: logical, descriptorRevision: revision),
                descriptor: .init(logicalID: logical, descriptorRevision: revision,
                    owner: .app(try HanlinAppID(validating: "otzaria")), title: title, summary: title,
                    inputSchema: schema, risk: .read, presentation: .init()),
                writeGuarantee: .readOnly, originalInputSchemaJSON: schemaBytes))
        }
        let value = HanlinHostCatalog(apiVersion: apiVersion, revision: binding.catalogRevision,
                                     context: binding.context, tools: tools)
        try value.validate()
        return value
    }

    private func actionEnvelope(_ invocation: HanlinHostInvocation, action: String,
                                binding: OtzariaHanlinBinding, arguments: Data, deadline: Int) throws -> Data {
        let encoder = JSONEncoder()
        func json<T: Encodable>(_ value: T) throws -> String {
            String(decoding: try encoder.encode(value), as: UTF8.self)
        }
        let prefix = try "{\"apiVersion\":1,\"requestId\":" + json(invocation.resultID)
            + ",\"action\":" + json(action) + ",\"arguments\":"
        let suffix = try ",\"expectedBackend\":" + json(binding.backend.backend)
            + ",\"expectedGeneration\":" + json(binding.backend.generation)
            + ",\"requestedPresentation\":\"headless\",\"deadlineMs\":" + json(deadline)
            + (try invocation.request.idempotencyKey.map { ",\"idempotencyKey\":" + (try json($0)) } ?? "")
            + "}"
        var bytes = Data(prefix.utf8)
        bytes.append(arguments); bytes.append(Data(suffix.utf8))
        return bytes
    }
}


/// Combines the two original authorities without executing tools or storing grants.
/// Only catalog routing revisions are translated; business input, permissions,
/// invocation/result identity and each owner's effect receipt stay unchanged.
actor OtzariaHanlinComposedHost: HanlinHostNavigationTransitionSource, HanlinHostCapabilitySource {
    nonisolated let apiVersion = HanlinAPIVersion(major: 1, minor: 2)
    let identity: HanlinHostSession
    private let library: any HanlinHostIntegration
    private let assistant: any HanlinHostIntegration & HanlinHostCapabilitySource
    private enum Owner { case library, assistant }
    private struct Snapshot {
        let library: HanlinHostCatalog
        let assistant: HanlinHostCatalog
        let combined: HanlinHostCatalog
    }
    private var snapshot: Snapshot?
    private var revision: UInt64 = 0
    private var revoked = false
    private var pending = Set<HanlinToolInvocationID>()
    private var cancelled = Set<HanlinToolInvocationID>()
    private var routes: [HanlinToolInvocationID: Owner] = [:]

    init(identity: HanlinHostSession, library: any HanlinHostIntegration,
         assistant: any HanlinHostIntegration & HanlinHostCapabilitySource) {
        self.identity = identity; self.library = library; self.assistant = assistant
    }

    func context(for session: HanlinHostSession) async throws -> HanlinHostContext {
        try Task.checkCancellation()
        guard !revoked, session == identity else { throw HanlinHostError.staleContext }
        let local = try await library.context(for: session)
        let capabilities = try await assistant.context(for: session)
        try Task.checkCancellation()
        guard !revoked, local == identity.context, capabilities == identity.context else {
            throw HanlinHostError.staleContext
        }
        return identity.context
    }

    func catalog(for context: HanlinHostContext) async throws -> HanlinHostCatalog {
        try await currentSnapshot(for: context).combined
    }

    private func currentSnapshot(for context: HanlinHostContext) async throws -> Snapshot {
        guard context == identity.context else { throw HanlinHostError.staleContext }
        _ = try await self.context(for: identity)
        let local = try await library.catalog(for: context)
        let capabilities = try await assistant.catalog(for: context)
        try local.validate(); try capabilities.validate()
        guard local.context == context, capabilities.context == context else { throw HanlinHostError.staleContext }
        _ = try await self.context(for: identity)
        if let snapshot, Self.sameCatalog(snapshot.library, local),
           Self.sameCatalog(snapshot.assistant, capabilities) {
            return snapshot
        }
        guard revision < UInt64.max else { throw HanlinHostError.storageLimitExceeded }
        let combined = HanlinHostCatalog(apiVersion: apiVersion, revision: .init(revision + 1),
            context: context, tools: local.tools + capabilities.tools)
        // The original SDK rejects both duplicate aliases and duplicate logical identities.
        try combined.validate()
        revision += 1
        let value = Snapshot(library: local, assistant: capabilities, combined: combined)
        snapshot = value
        return value
    }

    private static func sameCatalog(_ lhs: HanlinHostCatalog, _ rhs: HanlinHostCatalog) -> Bool {
        guard lhs.apiVersion.major == rhs.apiVersion.major, lhs.apiVersion.minor == rhs.apiVersion.minor,
              lhs.revision == rhs.revision, lhs.context == rhs.context, lhs.tools.count == rhs.tools.count else { return false }
        return zip(lhs.tools, rhs.tools).allSatisfy { a, b in
            a.route == b.route && a.descriptor == b.descriptor
                && a.writeGuarantee == b.writeGuarantee && a.originalInputSchemaJSON == b.originalInputSchemaJSON
        }
    }

    func prepareStep(_ step: Int, session: HanlinHostSession) async throws -> HanlinHostStepPreparation {
        _ = try await context(for: session)
        let prepared = try await assistant.prepareStep(step, session: session)
        let current = try await currentSnapshot(for: session.context)
        let allowed = Set(current.combined.tools.map(\.route.alias))
        guard prepared.activeAliases.allSatisfy(allowed.contains),
              Set(prepared.activeAliases).count == prepared.activeAliases.count else { throw HanlinHostError.unknownTool }
        // Existing Core metadata/read authority remains independent of skill/MCP exposure.
        let nativeAliases = current.library.tools.map(\.route.alias)
        let nativeSet = Set(nativeAliases)
        return .init(activeAliases: nativeAliases + prepared.activeAliases.filter { !nativeSet.contains($0) },
            skillIDs: prepared.skillIDs, instructions: prepared.instructions)
    }

    func execute(_ invocation: HanlinHostInvocation,
                 progress: @escaping HanlinHostProgressHandler) async throws -> HanlinHostExecutionResult {
        guard !revoked, invocation.session == identity else { throw HanlinHostError.staleContext }
        let id = invocation.request.id
        guard pending.insert(id).inserted else { throw HanlinHostError.duplicateInvocation }
        defer { pending.remove(id); cancelled.remove(id); routes[id] = nil }
        let current = try await currentSnapshot(for: invocation.session.context)
        try Task.checkCancellation()
        guard !revoked, !cancelled.contains(id) else { throw CancellationError() }
        guard invocation.request.routingTableRevision == current.combined.revision else { throw HanlinHostError.staleContext }
        let local = current.library.tools.first { $0.route.alias == invocation.request.aliasUsed }
        let tool = local ?? current.assistant.tools.first { $0.route.alias == invocation.request.aliasUsed }
        guard let tool, tool.route.logicalToolID == invocation.request.logicalToolID,
              tool.route.descriptorRevision == invocation.request.descriptorRevision,
              tool.writeGuarantee == invocation.writeGuarantee else { throw HanlinHostError.unknownTool }
        let owner: Owner = local == nil ? .assistant : .library
        let originalRevision = local == nil ? current.assistant.revision : current.library.revision
        let original = Self.forward(invocation, revision: originalRevision)
        routes[id] = owner
        // Original owners revalidate schemas, consent, context and cancellation
        // at their existing dispatch boundary. Do not infer rollback or replace
        // an uncertain/committed receipt after an operation has entered there.
        switch owner {
        case .library: return try await library.execute(original, progress: progress)
        case .assistant: return try await assistant.execute(original, progress: progress)
        }
    }

    private static func forward(_ invocation: HanlinHostInvocation,
                                revision: HanlinCatalogRevision) -> HanlinHostInvocation {
        let value = invocation.request
        let request = HanlinToolInvocationRequest(id: value.id, logicalToolID: value.logicalToolID,
            aliasUsed: value.aliasUsed, descriptorRevision: value.descriptorRevision,
            routingTableRevision: revision, arguments: value.arguments, origin: value.origin,
            appSessionID: value.appSessionID, runtimeSessionID: value.runtimeSessionID,
            grantIDs: value.grantIDs, idempotencyKey: value.idempotencyKey,
            deadline: value.deadline, limits: value.limits)
        return .init(request: request, session: invocation.session, runID: invocation.runID,
            step: invocation.step, providerCallID: invocation.providerCallID,
            writeGuarantee: invocation.writeGuarantee, expectedRevision: invocation.expectedRevision,
            originalArgumentsJSON: invocation.originalArgumentsJSON, resultID: invocation.resultID)
    }

    func cancel(_ invocation: HanlinToolInvocationID) async {
        guard pending.contains(invocation) else { return }
        cancelled.insert(invocation)
        switch routes[invocation] {
        case .library: await library.cancel(invocation)
        case .assistant: await assistant.cancel(invocation)
        case nil: break
        }
    }

    func revoke() async {
        guard !revoked else { return }
        revoked = true; snapshot = nil
        cancelled.formUnion(pending)
        let active = routes
        for (id, owner) in active {
            switch owner {
            case .library: await library.cancel(id)
            case .assistant: await assistant.cancel(id)
            }
        }
    }

    func open(_ destination: HanlinHostDestination) async throws -> HanlinHostNavigationResult {
        guard destination.context == identity.context else { throw HanlinHostError.staleContext }
        _ = try await context(for: identity)
        return try await library.open(destination)
    }

    func openWithContextTransition(_ destination: HanlinHostDestination,
                                   session: HanlinHostSession) async throws -> HanlinHostNavigationReceipt {
        guard destination.context == identity.context else { throw HanlinHostError.staleContext }
        _ = try await context(for: session)
        guard let native = library as? any HanlinHostNavigationTransitionSource else {
            throw HanlinHostError.unsupportedVersion
        }
        return try await native.openWithContextTransition(destination, session: session)
    }
}
