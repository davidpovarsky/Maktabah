#if os(iOS)
import AppIntents
import Foundation

/// System-visible metadata only. The exact original source and operation
/// tokens stay inside the host and are resolved again at execution.
public struct NativeSearchContinuationEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Search target"
    public static let defaultQuery = NativeSearchContinuationEntityQuery()
    public let id: String
    public let title: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)") }
    public init(id: String, title: String) { self.id = id; self.title = title }
}

public struct NativeSearchContinuationEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeSearchContinuationIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSearchContinuationEntity] {
        try await service.targets().map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeLoadedSearchResultEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeSearchContinuationIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .result, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .result, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .result).map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeNextSearchPageEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeSearchContinuationIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .nextPage, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .nextPage, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSearchContinuationEntity] {
        try await service.targets(kind: .nextPage).map { .init(id: $0.id, title: $0.title) }
    }
}

public struct RevealLoadedSearchResultIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show a loaded search result"
    public static let description = IntentDescription(
        "Reveal an existing result in its original search window. The current query and filters are preserved.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Search result", query: NativeLoadedSearchResultEntityQuery())
    public var result: NativeSearchContinuationEntity
    @Dependency private var service: NativeSearchContinuationIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Show \(\.$result)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = try await service.open(identifier: result.id, kind: .result)
        return .result()
    }
}

public struct LoadNextOriginalSearchPageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Load the next search page"
    public static let description = IntentDescription(
        "Load the next page of the selected existing search. The original search determines the next page.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Search page", query: NativeNextSearchPageEntityQuery())
    public var page: NativeSearchContinuationEntity
    @Dependency private var service: NativeSearchContinuationIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Load \(\.$page)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = try await service.open(identifier: page.id, kind: .nextPage)
        return .result()
    }
}

public struct GetOriginalSearchLinkIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get a search link"
    public static let description = IntentDescription(
        "Create a link to a current search result or next page. The link contains no query text and expires when the original search changes.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Search target") public var target: NativeSearchContinuationEntity
    @Dependency private var service: NativeSearchContinuationIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Get a link to \(\.$target)") }
    public init() {}
    public func perform() async throws -> some IntentResult & ReturnsValue<URL> {
        let url = try await service.link(identifier: target.id)
        return .result(value: url)
    }
}
#endif
