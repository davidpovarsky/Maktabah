import Foundation

public enum ActionSearchSemantics {
    public static func validateBounds(_ query: ActionSearchQuery) throws {
        guard !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.text.count <= 1_000, query.scopeWorkRefs.count <= 200,
              (0...100_000).contains(query.offset), (1...100).contains(query.limit),
              (0...100).contains(query.wordDistance),
              query.scopeWorkRefs.allSatisfy({ $0.backend == query.backend && !$0.workKey.isEmpty }) else {
            throw ActionContractError.invalid("search.query")
        }
    }

    /// Reject ignored request fields before touching an existing provider.
    public static func unsupportedReason(_ query: ActionSearchQuery) -> String? {
        if query.scopeWorkRefs.contains(where: { $0.catalogRevision != nil }) { return "scope_revision_not_supported" }
        if query.searchMode != .near && query.wordDistance != 0 { return "word_distance_not_supported" }
        if query.searchMode == .near && query.wordDistance == 0 { return "word_distance_not_supported" }
        switch query.backend {
        case .otzaria:
            // The shared adapter's index and SQLite fallback do not interpret
            // contains/OR/near/morphology identically. Expose the verified seam.
            if query.searchMode != .phrase || query.matchMode != .exact { return "search_mode_not_supported" }
            if query.sortOrder == .chronological { return "search_sort_not_supported" }
        case .sefaria:
            if [.or, .contains].contains(query.searchMode), query.sortOrder != .relevance {
                return "boolean_search_sort_not_supported"
            }
            if query.matchMode == .hebrewLemmatized,
               !query.text.unicodeScalars.contains(where: { (0x0590...0x05FF).contains($0.value) }) {
                return "search_match_not_supported"
            }
        case .sefariaEmbedded:
            if query.searchMode != .phrase || query.matchMode != .exact { return "search_mode_not_supported" }
            if query.sortOrder != .relevance { return "search_sort_not_supported" }
            if !query.scopeWorkRefs.isEmpty { return "search_scope_not_supported" }
        }
        return nil
    }
}

/// A filter is source-owned catalog data, not a localized category label.
public struct ActionSearchScopeEntry: Sendable, Equatable {
    public let workRef: ActionWorkRef
    public let authoritativeFilter: String?
    public init(workRef: ActionWorkRef, authoritativeFilter: String? = nil) {
        self.workRef = workRef; self.authoritativeFilter = authoritativeFilter
    }
}

public enum ActionSearchScopeMapping {
    public static func filters(for query: ActionSearchQuery, catalog: [ActionSearchScopeEntry]) throws -> [String] {
        try ActionSearchSemantics.validateBounds(query)
        if query.scopeWorkRefs.isEmpty { return [] }
        guard query.backend != .sefariaEmbedded else { throw ActionPortError.notSupported }
        var filters: [String] = []
        for ref in query.scopeWorkRefs {
            guard ref.catalogRevision == nil else { throw ActionPortError.notSupported }
            let entries = catalog.filter { $0.workRef.backend == ref.backend && $0.workRef.workKey == ref.workKey }
            guard !entries.isEmpty else { throw ActionPortError.notFound }
            let filter: String
            if query.backend == .otzaria {
                guard ref.workKey.hasPrefix("book:"), let id = Int64(ref.workKey.dropFirst(5)), id > 0,
                      Int(exactly: id) != nil, String(id) == String(ref.workKey.dropFirst(5)) else {
                    throw ActionPortError.notSupported
                }
                filter = ref.workKey
            } else {
                let paths = Set(entries.compactMap(\.authoritativeFilter).filter { !$0.isEmpty })
                guard paths.count == 1, entries.allSatisfy({ $0.authoritativeFilter != nil }) else {
                    throw ActionPortError.notSupported
                }
                filter = paths.first!
            }
            if !filters.contains(filter) { filters.append(filter) }
        }
        return filters
    }
}

public enum ActionBackendInvocationGuard {
    public static func check(_ invocation: ActionPortInvocation, current: ActionBackendSnapshot,
                             target: ActionBackendID, uptime: UInt64 = DispatchTime.now().uptimeNanoseconds) throws {
        try Task.checkCancellation()
        guard uptime < invocation.deadlineUptimeNanoseconds else { throw CancellationError() }
        guard invocation.snapshot == current, target == current.backend else { throw ActionPortError.staleState }
    }
}
