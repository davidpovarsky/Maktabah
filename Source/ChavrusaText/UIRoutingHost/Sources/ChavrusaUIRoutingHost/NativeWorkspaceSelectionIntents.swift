#if os(iOS)
import AppIntents
import Foundation

public struct NativeStudyProfileEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Study profile"
    public static let defaultQuery = NativeStudyProfileEntityQuery()
    public let id: String
    public let title: String
    public let detail: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)", subtitle: "\(detail)") }
    public init(id: String, title: String, detail: String) { self.id = id; self.title = title; self.detail = detail }
}
public struct NativeStudyProfileEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeWorkspaceSelectionIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeStudyProfileEntity] {
        try await service.selections(kind: .profile, identifiers: identifiers).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func entities(matching string: String) async throws -> [NativeStudyProfileEntity] {
        try await service.selections(kind: .profile, matching: string).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func suggestedEntities() async throws -> [NativeStudyProfileEntity] {
        try await service.selections(kind: .profile).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
}
public struct OpenStudyProfileIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open a study profile"
    public static let description = IntentDescription(
        "Select the first tab group of an original study profile in the current library of the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Study profile") public var selection: NativeStudyProfileEntity
    @Dependency private var service: NativeWorkspaceSelectionIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$selection)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.open(kind: .profile, identifier: selection.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}

public struct NativeStudyTabGroupEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tab group"
    public static let defaultQuery = NativeStudyTabGroupEntityQuery()
    public let id: String
    public let title: String
    public let detail: String
    public var displayRepresentation: DisplayRepresentation { .init(title: "\(title)", subtitle: "\(detail)") }
    public init(id: String, title: String, detail: String) { self.id = id; self.title = title; self.detail = detail }
}
public struct NativeStudyTabGroupEntityQuery: EntityStringQuery {
    @Dependency private var service: NativeWorkspaceSelectionIntentService
    public init() {}
    public func entities(for identifiers: [String]) async throws -> [NativeStudyTabGroupEntity] {
        try await service.selections(kind: .group, identifiers: identifiers).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func entities(matching string: String) async throws -> [NativeStudyTabGroupEntity] {
        try await service.selections(kind: .group, matching: string).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
    public func suggestedEntities() async throws -> [NativeStudyTabGroupEntity] {
        try await service.selections(kind: .group).map { .init(id: $0.id, title: $0.title, detail: $0.detail) }
    }
}
public struct OpenStudyTabGroupIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open a tab group"
    public static let description = IntentDescription(
        "Select an original tab group in the current study profile and library of the selected Maktabah window.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Tab group") public var selection: NativeStudyTabGroupEntity
    @Dependency private var service: NativeWorkspaceSelectionIntentService
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$selection)") }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let result = try await service.open(kind: .group, identifier: selection.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(result)
        return .result()
    }
}
#endif
