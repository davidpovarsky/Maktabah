#if os(iOS)
import AppIntents
import Foundation

public struct NativeBookEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Maktabah book"
    public static let defaultQuery = NativeBookEntityQuery()
    public let id: String
    public let title: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)") }
    public init(id: String, title: String) { self.id = id; self.title = title }
}
public struct NativeBookEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeReaderIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeBookEntity] {
        try await service.works(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeBookEntity] {
        try await service.works(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeBookEntity] { [] }
}
public struct NativeBookLocationEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Book chapter or passage"
    public static let defaultQuery = NativeBookLocationEntityQuery()
    public let id: String
    public let title: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)") }
    public init(id: String, title: String) { self.id = id; self.title = title }
}
public struct NativeBookLocationEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeReaderIntentService
    @IntentParameterDependency<OpenBookAtLocationIntent>(\.$book) private var intent
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeBookLocationEntity] {
        try await service.locations(identifiers: identifiers, workIdentifier: intent?.book.id)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeBookLocationEntity] {
        guard let intent else { return [] }
        return try await service.locations(matching: string, workIdentifier: intent.book.id)
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeBookLocationEntity] { [] }
}
public struct NativeReaderWindowEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.destinations(identifiers: identifiers).filter { $0.destination.rawValue == "native.library" }
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.destinations(matching: string).filter { $0.destination.rawValue == "native.library" }
            .map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.destinations().filter { $0.destination.rawValue == "native.library" }
            .map { .init(id: $0.id, title: $0.title) }
    }
}
public struct OpenBookAtLocationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open a book at a chapter or passage"
    public static let description = IntentDescription("Choose a book and a source chapter or passage from the current library, then open it in the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Book") public var book: NativeBookEntity
    @Parameter(title: "Chapter or passage") public var location: NativeBookLocationEntity
    @Parameter(title: "Window", query: NativeReaderWindowEntityQuery()) public var window: NativeDestinationEntity
    @Parameter(title: "Open in a new tab", default: true) public var newTab: Bool
    @Dependency private var service: NativeReaderIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$book) at \(\.$location) in \(\.$window)") { \.$newTab }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.open(workIdentifier: book.id, locationIdentifier: location.id,
            windowIdentifier: window.id, newTab: newTab)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
