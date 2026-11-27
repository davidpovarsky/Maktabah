#if os(iOS)
import AppIntents
import Foundation

public struct NativeAnnotationRecordEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Annotation record")
    public static let defaultQuery = NativeAnnotationRecordQuery()
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
    public var displayRepresentation: DisplayRepresentation {
        .init(title: LocalizedStringResource(stringLiteral: title))
    }
}

public struct NativeAnnotationRecordQuery: EntityStringQuery {
    @Dependency private var service: NativeAnnotationSelectionIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeAnnotationRecordEntity] {
        try await service.records(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeAnnotationRecordEntity] {
        try await service.records(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeAnnotationRecordEntity] {
        try await service.records().map { .init(id: $0.id, title: $0.title) }
    }
}

public struct NativeAnnotationWindowQuery: EntityStringQuery {
    @Dependency private var service: NativeAnnotationSelectionIntentService
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

public struct RevealAnnotationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show an annotation"
    public static let description = IntentDescription("Select an existing annotation in its original list.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Annotation record", query: NativeAnnotationRecordQuery())
    public var annotation: NativeAnnotationRecordEntity
    @Parameter(title: "Annotations window", query: NativeAnnotationWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeAnnotationSelectionIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Show an annotation") { \.$annotation; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let acknowledgement = try await service.reveal(identifier: annotation.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
        return .result()
    }
}
#endif
