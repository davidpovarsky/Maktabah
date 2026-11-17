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
    public let backend: ActionBackendSnapshot
    public let catalogRevision: HanlinCatalogRevision
    public let availableReadActions: Set<String>

    public init(context: HanlinHostContext, executionContext: ActionExecutionContext,
                backend: ActionBackendSnapshot, catalogRevision: HanlinCatalogRevision,
                availableReadActions: Set<String>) {
        self.context = context; self.executionContext = executionContext
        self.backend = backend; self.catalogRevision = catalogRevision
        self.availableReadActions = availableReadActions
    }
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

/// Compatible with the real Hanlin HostIntegration contract. No chat, agent loop,
/// credentials, MCP transport, persistence or new business/permission engine.
/// App target registration is blocked on an importable, pinned Hanlin SDK release.
public actor OtzariaHanlinHostAdapter: HanlinHostIntegration {
    public nonisolated let apiVersion = HanlinAPIVersion(major: 1, minor: 0)
    private let core: ActionExecutor
    private let authority: any OtzariaHanlinHostAuthority
    private let registry: ActionRegistry
    private var workers: [HanlinToolInvocationID: Task<ActionResult, Never>] = [:]
    private var seen = Set<HanlinToolInvocationID>()
    private var pending = Set<HanlinToolInvocationID>()
    private var cancelled = Set<HanlinToolInvocationID>()
    private let maximumInvocations = 256
    private let maximumConcurrentInvocations = 8

    // Explicit transport names. Do not sanitize arbitrary untrusted identifiers.
    private static let names: [String: String] = [
        "system.list-backends": "system.listBackends",
        "catalog.resolve-work": "catalog.resolveWork",
        "catalog.resolve-reference": "catalog.resolveReference",
        "search.query": "search.query",
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
        let catalog = try makeCatalog(binding)
        // A projection is not a permission grant. Recheck after any host await.
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
        let task = Task { [core] in await core.execute(canonical, context: binding.executionContext) }
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
        guard encoded.count <= min(request.limits.maximumOutputBytes, binding.executionContext.maxResultBytes) else {
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
              binding.executionContext.foregroundSceneID == destination.context.sceneID.uuidString else {
            throw HanlinHostError.denied
        }
        // The existing scene owner performs its canonical final precommit/receipt
        // checks. This adapter cannot manufacture a native acknowledgment.
        let result = try await authority.open(destination, binding: binding)
        try result.validate(for: destination)
        return result
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
    }

    private func makeCatalog(_ binding: OtzariaHanlinBinding) throws -> HanlinHostCatalog {
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
                  ActionRegistry.implemented.contains(action),
                  let descriptor = registry.descriptor(for: action), !descriptor.mutatesUserData else { continue }
            if action != "system.listBackends" {
                guard binding.executionContext.scopes.contains(.contentRead),
                      binding.executionContext.contentRights.contains(binding.backend.backend) else { continue }
            }
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
