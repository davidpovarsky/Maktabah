import Foundation

/// A query for the original results UI. Paging belongs to that existing UI:
/// offset/limit and opaque handles are deliberately not accepted or discarded.
public struct ActionSearchResultsQuery: Sendable, Equatable {
    public let search: ActionSearchQuery
    public init(_ search: ActionSearchQuery) throws {
        try ActionSearchSemantics.validateBounds(search)
        guard search.offset == 0, search.limit == 20 else { throw ActionPortError.notSupported }
        self.search = search
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.search == rhs.search && lhs.search.text.utf8.elementsEqual(rhs.search.text.utf8)
    }
    /// Canonical projection into the existing strict UI action. Construction
    /// has already rejected nondefault pagination; every semantic field stays
    /// intact, including byte-exact text, scope revisions, mode and sort order.
    public func actionArguments() throws -> ActionObject {
        var fields = try ActionJSON.encoded(search).object ?? [:]
        fields.removeValue(forKey: "offset"); fields.removeValue(forKey: "limit")
        return ["searchQuery": .object(fields)]
    }
    public static func arguments(_ arguments: ActionObject, backend: ActionBackendID) throws -> Self {
        guard arguments["searchHandle"] == nil else { throw ActionPortError.notSupported }
        guard let object = arguments["searchQuery"]?.object else { throw ActionContractError.invalid("searchQuery") }
        let allowed: Set<String> = ["backend", "text", "scopeWorkRefs", "searchMode", "matchMode", "wordDistance", "sortOrder"]
        guard Set(object.keys).isSubset(of: allowed) else { throw ActionPortError.notSupported }
        if let specified = object["backend"] {
            guard specified.string == backend.rawValue else { throw ActionContractError.invalid("searchQuery.backend") }
        }
        if let scopes = object["scopeWorkRefs"]?.array {
            let scopeFields: Set<String> = ["backend", "workKey", "catalogRevision"]
            guard scopes.allSatisfy({ value in
                guard let fields = value.object else { return false }
                return Set(fields.keys).isSubset(of: scopeFields)
            }) else { throw ActionPortError.notSupported }
        }
        return try .init(ActionSearchArgumentMapping.query(object, backend: backend))
    }
    /// The current original global UI exposes this exact common subset. Other
    /// semantic query modes remain available through search.query where proven.
    public static func unsupportedReason(_ query: ActionSearchQuery) -> String? {
        if let reason = ActionSearchSemantics.unsupportedReason(query) { return reason }
        if query.searchMode != .phrase || query.matchMode != .exact || query.wordDistance != 0 {
            return "native_search_mode_not_supported"
        }
        if query.backend != .otzaria && !query.scopeWorkRefs.isEmpty {
            return "native_search_scope_not_supported"
        }
        return nil
    }
}

public struct ActionOpenSearchResultsCommand: Sendable, Equatable {
    public let query: ActionSearchResultsQuery
    public let sceneID: String
    public let invocation: ActionPortInvocation
    public let navigationAuthorization: ActionNavigationPreparation?
    public init(query: ActionSearchResultsQuery, sceneID: String, invocation: ActionPortInvocation,
                navigationAuthorization: ActionNavigationPreparation? = nil) {
        self.query = query; self.sceneID = sceneID; self.invocation = invocation
        self.navigationAuthorization = navigationAuthorization
    }
}
public struct ActionSearchResultsReceipt: Sendable, Equatable {
    public let requestId: UUID
    public let snapshot: ActionBackendSnapshot
    public let sceneID: String
    public let query: ActionSearchResultsQuery
    public let submissionRevision: Int
    public init(requestId: UUID, snapshot: ActionBackendSnapshot, sceneID: String,
                query: ActionSearchResultsQuery, submissionRevision: Int) {
        self.requestId = requestId; self.snapshot = snapshot; self.sceneID = sceneID
        self.query = query; self.submissionRevision = submissionRevision
    }
}
public enum ActionSearchResultsAcknowledgement: Sendable, Equatable {
    case acknowledged(ActionSearchResultsReceipt), queued(handle: String), requiresForeground
}
/// Optional host seam: uses the original scene's query/session/engine and visible
/// results surface. A query echo or a pending engine submission is not a receipt.
public protocol ActionSearchResultsUICommandSink: ActionUICommandSink {
    @MainActor func canOpenSearchResults(in sceneID: String) -> Bool
    @MainActor func prepareSearchResults(_ query: ActionSearchResultsQuery, context: ActionExecutionContext,
                                         invocation: ActionPortInvocation) async throws
    @MainActor func openSearchResults(_ command: ActionOpenSearchResultsCommand) async throws -> ActionSearchResultsAcknowledgement
    /// Runs synchronously after Core's final authority observation.
    @MainActor func validateSearchResultsCompletion(_ command: ActionOpenSearchResultsCommand,
                                                    receipt: ActionSearchResultsReceipt) throws
}
