#if os(iOS)
import AppIntents
import Foundation

public struct NativeHistoryRecordEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "History record")
    public static let defaultQuery = NativeHistoryRecordEntityQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}

public struct NativeHistoryRecordEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeHistoryRecordIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeHistoryRecordEntity] {
        try await service.records(kind: .history, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeHistoryRecordEntity] {
        try await service.records(kind: .history, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeHistoryRecordEntity] {
        try await service.records(kind: .history).map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeFavoriteRecordEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeHistoryRecordIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeFavoriteRecordEntity] {
        try await service.records(kind: .favorite, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeFavoriteRecordEntity] {
        try await service.records(kind: .favorite, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeFavoriteRecordEntity] {
        try await service.records(kind: .favorite).map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeFavoriteRecordEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorite record")
    public static let defaultQuery = NativeFavoriteRecordEntityQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}

public struct NativeHistoryRecordWindowQuery: EntityStringQuery {
    @Dependency private var service: NativeHistoryRecordIntentService
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

public struct RevealHistoryEntryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show a history entry"
    public static let description = IntentDescription("Reveal an existing reading-history card in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "History entry", query: NativeHistoryRecordEntityQuery())
    public var entry: NativeHistoryRecordEntity
    @Parameter(title: "History window", query: NativeHistoryRecordWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeHistoryRecordIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show a history entry") { \.$entry; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.reveal(kind: .history, identifier: entry.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}

public struct RevealFavoriteRecordIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show a favorite"
    public static let description = IntentDescription("Reveal an existing favorite card in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Favorite", query: NativeFavoriteRecordEntityQuery())
    public var favorite: NativeFavoriteRecordEntity
    @Parameter(title: "History window", query: NativeHistoryRecordWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeHistoryRecordIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show a favorite") { \.$favorite; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.reveal(kind: .favorite, identifier: favorite.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
