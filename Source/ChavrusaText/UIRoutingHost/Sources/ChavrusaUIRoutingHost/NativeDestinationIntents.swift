#if os(iOS)
import Foundation
import AppIntents
import OtzariaUIRouting

/// Include this package through the app's AppIntentsPackage registration only
/// after NativeIntentService and actual native destinations are installed.
public struct ChavrusaRoutingIntents: AppIntentsPackage {}

public struct NativeDestinationEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Maktabah destination"
    public static let defaultQuery = NativeDestinationEntityQuery()
    public let id: String
    public let title: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)") }
    public init(id: String, title: String) { self.id = id; self.title = title }
}

public struct NativeDestinationEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeDestinationEntity] {
        try await service.destinations(identifiers: identifiers).map { .init(id: $0.id, title: $0.title) }
    }
    public func entities(matching string: String) async throws -> [NativeDestinationEntity] {
        try await service.destinations(matching: string).map { .init(id: $0.id, title: $0.title) }
    }
    public func suggestedEntities() async throws -> [NativeDestinationEntity] {
        try await service.destinations().map { .init(id: $0.id, title: $0.title) }
    }
}

public struct OpenNativeDestinationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Maktabah destination"
    public static let description = IntentDescription("Open an available destination in the current Maktabah library.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Destination") public var destination: NativeDestinationEntity
    @Dependency private var service: NativeIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$destination)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let acknowledgement = try await service.open(identifier: destination.id)
        // Only the one orchestrator may produce an acknowledged visible route.
        // Queueing, launching the app or selecting a tab alone is not success.
        try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
        return .result()
    }
}
#endif
