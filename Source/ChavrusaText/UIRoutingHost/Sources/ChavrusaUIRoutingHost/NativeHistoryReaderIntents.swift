#if os(iOS)
import AppIntents
import Foundation

public struct NativeHistoryReadingEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved reading position")
    public static let defaultQuery = NativeHistoryReadingEntityQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}

public struct NativeHistoryReadingEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeHistoryReaderIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeHistoryReadingEntity] {
        try await service.records(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeHistoryReadingEntity] {
        try await service.records(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeHistoryReadingEntity] {
        try await service.records().map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeHistoryReadingWindowQuery: EntityStringQuery {
    @Dependency private var service: NativeHistoryReaderIntentService
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

public struct ResumeHistoryReadingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Resume reading from history"
    public static let description = IntentDescription("Open the original Reader at an existing saved history position in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Saved reading position", query: NativeHistoryReadingEntityQuery())
    public var entry: NativeHistoryReadingEntity
    @Parameter(title: "Reader window", query: NativeHistoryReadingWindowQuery())
    public var window: NativeDestinationEntity
    @Parameter(title: "Open in a new tab", default: true)
    public var newTab: Bool
    @Dependency private var service: NativeHistoryReaderIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Resume reading from history") { \.$entry; \.$window; \.$newTab }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let execution = try await service.open(identifier: entry.id,
            windowIdentifier: window.id, newTab: newTab)
        guard let acknowledgement = execution.acknowledgement else {
            throw NativeIntentOutcome(status: .failed, code: "native_effect_uncertain")
        }
        try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
        return .result()
    }
}
#endif
