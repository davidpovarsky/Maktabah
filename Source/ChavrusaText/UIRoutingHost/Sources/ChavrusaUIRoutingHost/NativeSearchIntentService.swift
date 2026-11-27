import Foundation
import OtzariaActionCore
import OtzariaUIRouting

/// A system adapter for the original search.openResults action. Work entities are
/// source metadata, not search results, permissions or a replacement search engine.
@MainActor public final class NativeSearchIntentService {
    public struct OpenRequest: Sendable {
        public let requestId: UUID
        public let query: ActionSearchResultsQuery
        public let expectedSnapshot: ActionBackendSnapshot
        public let window: NativeIntentService.Destination
        init(query: ActionSearchResultsQuery, snapshot: ActionBackendSnapshot,
             window: NativeIntentService.Destination) {
            requestId = UUID(); self.query = query
            expectedSnapshot = snapshot; self.window = window
        }
    }
    /// Both values come from the SAME original Core invocation/native owner.
    /// A completed Core result without its actual native receipt is insufficient.
    public struct Observation: Sendable {
        public let result: ActionResult
        public let receipt: UISceneReceipt?
        public init(result: ActionResult, receipt: UISceneReceipt?) {
            self.result = result; self.receipt = receipt
        }
    }
    /// Keep an original refusal or uncertain effect inspectable. Never discard an
    /// already-observed effect just because the system wrapper cannot report success.
    public struct Failure: Error, LocalizedError, Sendable {
        public let observation: Observation
        public let status: ActionStatus
        public let code: String
        public var errorDescription: String? {
            NativeIntentOutcome(status: status, code: code).errorDescription
        }
        public init(_ observation: Observation, status: ActionStatus, code: String) {
            self.observation = observation; self.status = status; self.code = code
        }
    }

    public typealias Snapshot = @MainActor @Sendable () throws -> ActionBackendSnapshot
    public typealias Windows = @MainActor @Sendable () throws -> [NativeIntentService.Destination]
    public typealias Open = @MainActor @Sendable (OpenRequest) async throws -> Observation
    private let snapshot: Snapshot
    private let resolveWindows: Windows
    private let reader: NativeReaderIntentService
    private let navigate: Open

    public init(snapshot: @escaping Snapshot, windows: @escaping Windows,
                reader: NativeReaderIntentService, navigate: @escaping Open) {
        self.snapshot = snapshot; resolveWindows = windows
        self.reader = reader; self.navigate = navigate
    }

    /// Original mounted-window metadata only. Queries do not activate a scene,
    /// submit a search, choose a first window, or acquire navigation authority.
    public func windows(identifiers: [String]? = nil, matching query: String? = nil) throws
        -> [NativeIntentService.Destination] {
        try Task.checkCancellation()
        guard identifiers == nil || identifiers!.count <= 64 else {
            throw UIRouteError(.failed, "too_many_intent_entities")
        }
        guard query == nil || query!.utf8.count <= 512 else {
            throw UIRouteError(.failed, "intent_query_too_large")
        }
        let source = try snapshot()
        var values = try windowValues(source)
        if let identifiers { values = values.filter { identifiers.contains($0.id) } }
        if let query, !query.isEmpty { values = values.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        try Task.checkCancellation()
        guard try snapshot() == source else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        return values
    }

    /// Book filters are advertised only where the ORIGINAL results UI supports
    /// them. NativeReaderIntentService still resolves every entity through Core.
    public func scopeBooks(matching query: String) async throws -> [NativeReaderIntentService.Work] {
        try Task.checkCancellation()
        let source = try snapshot()
        guard source.backend == .otzaria else { return [] }
        let values = try await reader.works(matching: query)
        try Task.checkCancellation()
        return try scopeValues(values, source: source)
    }
    public func scopeBooks(identifiers: [String]) async throws -> [NativeReaderIntentService.Work] {
        try Task.checkCancellation()
        guard identifiers.count <= 64 else { throw UIRouteError(.failed, "too_many_intent_entities") }
        let source = try snapshot()
        guard source.backend == .otzaria else { return [] }
        let values = try await reader.works(identifiers: identifiers)
        try Task.checkCancellation()
        return try scopeValues(values, source: source)
    }

    public func open(query text: String, scopeIdentifiers: [String] = [],
                     mode: ActionSearchQuery.Mode = .phrase,
                     match: ActionSearchQuery.Match = .exact, wordDistance: Int = 0,
                     sort: ActionSearchQuery.Sort = .relevance,
                     selectedHit: String? = nil, cursor: String? = nil,
                     windowIdentifier: String) async throws -> UISceneAcknowledgement {
        try Task.checkCancellation()
        // Neither optional field exists in the original UI action contract yet.
        // Reject presence, including "", rather than silently discard meaning.
        guard selectedHit == nil else { throw UIRouteError(.notSupported, "native_search_hit_not_supported") }
        guard cursor == nil else { throw UIRouteError(.notSupported, "native_search_cursor_not_supported") }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= 1_000, text.utf8.count <= 4_000 else {
            throw UIRouteError(.failed, "invalid_intent_query")
        }
        guard !windowIdentifier.isEmpty, windowIdentifier.utf8.count <= 512 else {
            throw UIRouteError(.failed, "invalid_intent_window")
        }
        guard scopeIdentifiers.count <= 200, Set(scopeIdentifiers).count == scopeIdentifiers.count else {
            throw UIRouteError(.failed, "invalid_intent_search_scope")
        }
        let source = try snapshot()
        let scopes: [ActionWorkRef] = try scopeIdentifiers.map {
            try NativeReaderEntityIdentifier.decode($0, prefix: "maktabah.work.v1.")
        }
        guard scopes.allSatisfy({ $0.backend == source.backend }) else {
            throw UIRouteError(.requiresBackendSwitch, "intent_search_scope_backend_mismatch")
        }
        let query = try ActionSearchResultsQuery(.init(backend: source.backend, text: text,
            scopeWorkRefs: scopes, searchMode: mode, matchMode: match,
            wordDistance: wordDistance, sortOrder: sort))
        if let reason = ActionSearchResultsQuery.unsupportedReason(query.search) {
            throw UIRouteError(.notSupported, reason)
        }
        let windows = try windowValues(source).filter { $0.id == windowIdentifier }
        guard windows.count == 1, let window = windows.first else {
            throw UIRouteError(.staleState, "intent_window_no_longer_available")
        }
        guard try snapshot() == source else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        try Task.checkCancellation()
        // Scope IDs are not trusted catalog evidence here. The original Core
        // resolves each exact WorkRef again before it prepares the native command.
        let request = OpenRequest(query: query, snapshot: source, window: window)
        let observed = try await navigate(request)
        return try acknowledgement(observed, for: request)
    }

    private func windowValues(_ source: ActionBackendSnapshot) throws -> [NativeIntentService.Destination] {
        let values = try resolveWindows()
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else {
            throw UIRouteError(.failed, "invalid_live_intent_catalog")
        }
        return values.filter {
            $0.backend == source.backend && $0.destination.rawValue == "native.search" && $0.component == nil
        }
    }
    private func scopeValues(_ values: [NativeReaderIntentService.Work], source: ActionBackendSnapshot) throws
        -> [NativeReaderIntentService.Work] {
        guard try snapshot() == source else {
            throw UIRouteError(.staleState, "intent_source_generation_changed")
        }
        guard values.allSatisfy({ $0.reference.backend == source.backend }) else {
            throw UIRouteError(.failed, "invalid_core_metadata_result")
        }
        // A source revision that the original scope owner cannot honor is not an
        // eligible suggestion. A cached unsupported selection still fails in open.
        return values.filter { $0.reference.catalogRevision == nil }
    }

    private func acknowledgement(_ observed: Observation, for request: OpenRequest) throws -> UISceneAcknowledgement {
        func refuse(_ status: ActionStatus, _ code: String) -> Failure {
            .init(observed, status: status, code: code)
        }
        let result = observed.result
        guard result.apiVersion == 1, result.requestId == request.requestId,
              result.action == "search.openResults" else {
            throw refuse(.failed, "native_effect_uncertain")
        }
        guard result.status == .completed else {
            throw refuse(result.status, result.error?.code ?? "native_search_not_completed")
        }
        if Task.isCancelled { throw refuse(.cancelled, "native_effect_uncertain") }
        guard (try? snapshot()) == request.expectedSnapshot else {
            throw refuse(.staleState, "intent_source_generation_changed")
        }
        guard result.backend == request.expectedSnapshot.backend,
              result.backendGeneration == request.expectedSnapshot.generation,
              result.error == nil, result.next == nil, result.effects == ["search_results_opened"],
              let receipt = observed.receipt,
              receipt.requestId == request.requestId, receipt.route.requestId == request.requestId,
              receipt.backendSnapshot == request.expectedSnapshot,
              receipt.sceneID == request.window.sceneID,
              receipt.route.backend == request.expectedSnapshot.backend,
              receipt.route.expectedBackendSnapshot == request.expectedSnapshot,
              receipt.route.destination.rawValue == "native.search.results",
              receipt.route.presentation.kind == .currentTab,
              receipt.route.scene.kind == .specific, receipt.route.scene.sceneID == receipt.sceneID,
              receipt.route.scene.expectedRevision == receipt.basedOnSceneRevision,
              receipt.appliedSceneRevision > receipt.basedOnSceneRevision,
              receipt.route.content == nil, receipt.route.focus == nil,
              receipt.route.state.privateState == nil, receipt.coreReceipt == nil else {
            throw refuse(.failed, "native_effect_uncertain")
        }
        return .acknowledged(receipt)
    }
}
