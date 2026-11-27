#if os(iOS)
import AppIntents
import Foundation

public struct NativeReaderTabEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Reader tab"
    public static let defaultQuery = NativeReaderTabEntityQuery()
    public let id: String
    public let title: String
    public let detail: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)", subtitle: "\(detail)") }
    public init(id: String, title: String, detail: String) { self.id = id; self.title = title; self.detail = detail }
}
public struct NativeReaderTabEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeReaderTabIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeReaderTabEntity] {
        try await service.tabs(identifiers: identifiers).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func entities(matching string: String) async throws -> [NativeReaderTabEntity] {
        try await service.tabs(matching: string).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func suggestedEntities() async throws -> [NativeReaderTabEntity] {
        try await service.tabs().map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
}
public struct OpenReaderTabIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open a reader tab"
    public static let description = IntentDescription(
        "Select an existing reader tab in the current study profile, group and library of the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Reader tab") public var tab: NativeReaderTabEntity
    @Dependency private var service: NativeReaderTabIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$tab)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.open(identifier: tab.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
