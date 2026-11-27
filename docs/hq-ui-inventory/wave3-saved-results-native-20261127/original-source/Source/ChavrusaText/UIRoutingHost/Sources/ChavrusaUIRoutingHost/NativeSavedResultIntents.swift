#if os(iOS)
import AppIntents
import Foundation

public struct NativeSavedResultFolderEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved results folder")
    public static let defaultQuery = NativeSavedResultFolderQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}
public struct NativeSavedResultEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved search result")
    public static let defaultQuery = NativeSavedResultQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}
public struct NativeSavedResultFolderQuery: EntityStringQuery {
    @Dependency private var service: NativeSavedResultIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSavedResultFolderEntity] {
        try await service.records(kind: .folder, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSavedResultFolderEntity] {
        try await service.records(kind: .folder, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSavedResultFolderEntity] {
        try await service.records(kind: .folder).map { .init(id: $0.id, title: $0.title) }
    }
}
public struct NativeSavedResultQuery: EntityStringQuery {
    @Dependency private var service: NativeSavedResultIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeSavedResultEntity] {
        try await service.records(kind: .result, identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeSavedResultEntity] {
        try await service.records(kind: .result, matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeSavedResultEntity] {
        try await service.records(kind: .result).map { .init(id: $0.id, title: $0.title) }
    }
}
public struct NativeSavedResultWindowQuery: EntityStringQuery {
    @Dependency private var service: NativeSavedResultIntentService
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
public struct RevealSavedResultsFolderIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show a saved results folder"
    public static let description = IntentDescription("Show an existing folder in Saved Results.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Saved results folder", query: NativeSavedResultFolderQuery())
    public var folder: NativeSavedResultFolderEntity
    @Parameter(title: "Saved results window", query: NativeSavedResultWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeSavedResultIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show a saved results folder") { \.$folder; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.reveal(kind: .folder, identifier: folder.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
public struct RevealSavedResultIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show a saved search result"
    public static let description = IntentDescription("Show a saved result without running its search.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Saved search result", query: NativeSavedResultQuery())
    public var result: NativeSavedResultEntity
    @Parameter(title: "Saved results window", query: NativeSavedResultWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeSavedResultIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show a saved search result") { \.$result; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let acknowledgement = try await service.reveal(kind: .result, identifier: result.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
        return .result()
    }
}
#endif
