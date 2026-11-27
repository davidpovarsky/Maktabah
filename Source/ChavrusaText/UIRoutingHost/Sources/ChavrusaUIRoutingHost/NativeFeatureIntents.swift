#if os(iOS)
import AppIntents
import Foundation

/// Entity IDs are the existing backend/window/component-qualified identities.
/// Each query only projects the original host catalog for its named action.
public struct NativeSettingsSectionEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.settingsSection, identifiers: identifiers)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.settingsSection, matching: string)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.settingsSection)
            .map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeReaderContentsEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readerContents, identifiers: identifiers)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readerContents, matching: string)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readerContents)
            .map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeReadingHistoryEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readingHistory, identifiers: identifiers)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readingHistory, matching: string)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.featureDestinations(.readingHistory)
            .map { .init(id: $0.id, title: $0.title) }
    }
}

public struct OpenSettingsSectionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open a Settings section"
    public static let description = IntentDescription(
        "Open a Settings section or control in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Settings section", query: NativeSettingsSectionEntityQuery())
    public var section: NativeDestinationEntity
    @Dependency private var service: NativeIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open a Settings section") { \.$section }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.openFeature(.settingsSection, identifier: section.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}

public struct OpenReaderContentsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open the table of contents"
    public static let description = IntentDescription(
        "Show the book's table of contents or selected entry in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Table of contents", query: NativeReaderContentsEntityQuery())
    public var contents: NativeDestinationEntity
    @Dependency private var service: NativeIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open the table of contents") { \.$contents }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.openFeature(.readerContents, identifier: contents.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}

public struct OpenReadingHistoryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open reading history"
    public static let description = IntentDescription(
        "Open reading history in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "History window", query: NativeReadingHistoryEntityQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open reading history") { \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.openFeature(.readingHistory, identifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
