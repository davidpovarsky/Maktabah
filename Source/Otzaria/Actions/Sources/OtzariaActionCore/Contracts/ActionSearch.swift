import Foundation

public struct ActionSearchQuery: Sendable, Equatable, Codable {
    public enum Mode: String, Sendable, Codable { case phrase, contains, or, near }
    public enum Match: String, Sendable, Codable { case exact, hebrewLemmatized }
    public enum Sort: String, Sendable, Codable { case relevance, canonical, chronological }
    public let backend: ActionBackendID
    public let text: String
    public let scopeWorkRefs: [ActionWorkRef]
    public let searchMode: Mode
    public let matchMode: Match
    public let wordDistance: Int
    public let sortOrder: Sort
    public let offset: Int
    public let limit: Int
    public init(backend: ActionBackendID, text: String, scopeWorkRefs: [ActionWorkRef] = [], searchMode: Mode = .phrase,
                matchMode: Match = .exact, wordDistance: Int = 0, sortOrder: Sort = .relevance, offset: Int = 0, limit: Int = 20) {
        self.backend = backend; self.text = text; self.scopeWorkRefs = scopeWorkRefs; self.searchMode = searchMode
        self.matchMode = matchMode; self.wordDistance = wordDistance; self.sortOrder = sortOrder; self.offset = offset; self.limit = limit
    }
}
public struct ActionSearchHit: Sendable, Equatable, Codable {
    public let id: String
    public let locator: ActionTextRef
    public let title: String
    public let snippet: String
    public init(id: String, locator: ActionTextRef, title: String, snippet: String) {
        self.id = id; self.locator = locator; self.title = title; self.snippet = snippet
    }
}
public struct ActionSearchPage: Sendable, Equatable, Codable {
    public enum Precision: String, Codable, Sendable { case exact, lowerBound = "lower_bound", unknown }
    public enum TotalSemantics: String, Codable, Sendable { case matchingSegments = "matching_segments", matchingDocuments = "matching_documents" }
    public let hits: [ActionSearchHit]
    public let total: Int?
    public let precision: Precision
    public let totalSemantics: TotalSemantics
    public let nextOffset: Int?
    public init(hits: [ActionSearchHit], total: Int? = nil, precision: Precision = .unknown,
                totalSemantics: TotalSemantics = .matchingSegments, nextOffset: Int? = nil) {
        self.hits = hits; self.total = total; self.precision = precision; self.totalSemantics = totalSemantics; self.nextOffset = nextOffset
    }
}
