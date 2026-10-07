import Foundation

enum UnifiedSearchPresentationState: Equatable, Sendable {
    case results
    case loading
    case error(String)
    case missingIndex
    case empty
    case notSearched
}

enum UnifiedSearchPresentationPolicy {
    static func resolve(
        resultCount: Int,
        isLoading: Bool,
        errorMessage: String?,
        hasSubmitted: Bool,
        indexReady: Bool
    ) -> UnifiedSearchPresentationState {
        if resultCount > 0 { return .results }
        if isLoading { return .loading }
        if let errorMessage, !errorMessage.isEmpty { return .error(errorMessage) }
        if !indexReady { return .missingIndex }
        return hasSubmitted ? .empty : .notSearched
    }
}

enum SearchDataComponent: String, CaseIterable, Hashable, Sendable {
    case database
    case lexicalDatabase
    case otzariaIndex
    case zayitIndex
}

enum SearchDataInstallPlanner {
    static func missingComponents(ready: Set<SearchDataComponent>) -> [SearchDataComponent] {
        SearchDataComponent.allCases.filter { !ready.contains($0) }
    }
}
