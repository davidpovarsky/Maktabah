#if os(iOS)
import AppIntents
import Foundation
import OtzariaActionCore

public struct NativeSearchScopeEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Search book filter"
    public static let defaultQuery = NativeSearchScopeEntityQuery()
    public let id: String
    public let title: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)") }
    public init(id: String, title: String) { self.id = id; self.title = title }
}
public struct NativeSearchScopeEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeSearchIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSearchScopeEntity] {
        try await service.scopeBooks(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSearchScopeEntity] {
        try await service.scopeBooks(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSearchScopeEntity] { [] }
}
public struct NativeSearchWindowEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeSearchIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.windows(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.windows(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.windows().map { .init(id: $0.id, title: $0.title) }
    }
}
/// Only the common original native mode is advertised. The service still
/// rejects unsupported semantic modes from non-AppIntents callers explicitly.
public enum NativeSearchIntentMode: String, AppEnum {
    case exactPhrase
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Search mode"
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [.exactPhrase: "Exact phrase"]
}
public enum NativeSearchIntentSort: String, AppEnum {
    case relevance, canonical, chronological
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Search order"
    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .relevance: "Relevance", .canonical: "Book order", .chronological: "Chronological"
    ]
    var original: ActionSearchQuery.Sort {
        switch self {
        case .relevance: .relevance
        case .canonical: .canonical
        case .chronological: .chronological
        }
    }
}
public struct ShowSearchResultsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show search results"
    public static let description = IntentDescription(
        "Search for an exact phrase in the current library and display its results in the selected Maktabah window. Book filters are available in the Otzaria library. Sorting choices depend on the selected library.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Search phrase") public var query: String
    @Parameter(title: "Books (optional)") public var books: [NativeSearchScopeEntity]?
    @Parameter(title: "Search mode", default: .exactPhrase) public var mode: NativeSearchIntentMode
    @Parameter(title: "Sort results", default: .relevance) public var sort: NativeSearchIntentSort
    @Parameter(title: "Window", query: NativeSearchWindowEntityQuery()) public var window: NativeDestinationEntity
    @Dependency private var service: NativeSearchIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show results for \(\.$query) in \(\.$window)") {
            \.$books
            \.$mode
            \.$sort
        }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        // The enum is exhaustive; no ignored mode/hit/cursor parameter is exposed.
        let originalMode: ActionSearchQuery.Mode
        switch mode { case .exactPhrase: originalMode = .phrase }
        let result = try await service.open(query: query, scopeIdentifiers: books?.map(\.id) ?? [],
            mode: originalMode, sort: sort.original, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
