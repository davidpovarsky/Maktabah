#if os(iOS)
import AppIntents
import Foundation

/// Each original passage query is bound to its own explicit Book parameter.
/// Entity identifiers and metadata resolution are shared with Open Book.
public struct NativeCommentaryBaseLocationQuery: EntityStringQuery {
    @Dependency private var service: NativeReaderIntentService
    @IntentParameterDependency<OpenCommentaryAtLocationIntent>(\.$book) private var intent
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

public struct NativeNoteDraftLocationQuery: EntityStringQuery {
    @Dependency private var service: NativeReaderIntentService
    @IntentParameterDependency<PrepareReaderNoteDraftIntent>(\.$book) private var intent
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

public struct OpenCommentaryAtLocationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open commentary at a passage"
    public static let description = IntentDescription("Choose a source passage, a commentary book and an existing Maktabah window. Open the original commentary reader in a new tab.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Book") public var book: NativeBookEntity
    @Parameter(title: "Chapter or passage", query: NativeCommentaryBaseLocationQuery()) public var location: NativeBookLocationEntity
    @Parameter(title: "Commentary book") public var commentaryBook: NativeBookEntity
    @Parameter(title: "Window", query: NativeReaderWindowEntityQuery()) public var window: NativeDestinationEntity
    @Dependency private var service: NativeReaderToolIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$commentaryBook) for \(\.$book) at \(\.$location) in \(\.$window)")
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = try await service.openCommentary(workIdentifier: book.id, locationIdentifier: location.id,
            commentaryWorkIdentifier: commentaryBook.id, windowIdentifier: window.id)
        return .result()
    }
}

public struct PrepareReaderNoteDraftIntent: AppIntent {
    public static let title: LocalizedStringResource = "Prepare an unsaved note for a selected passage"
    public static let description = IntentDescription("Choose the exact passage already selected in the original reader and its Maktabah window. Open an unsaved draft in the original note editor for review.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Book") public var book: NativeBookEntity
    @Parameter(title: "Selected passage", query: NativeNoteDraftLocationQuery()) public var location: NativeBookLocationEntity
    @Parameter(title: "Window", query: NativeReaderWindowEntityQuery()) public var window: NativeDestinationEntity
    @Parameter(title: "Unsaved note proposal") public var proposedNote: String?
    @Dependency private var service: NativeReaderToolIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Prepare a note for \(\.$book) at \(\.$location) in \(\.$window)") {
            \.$proposedNote
        }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        _ = try await service.prepareDraft(workIdentifier: book.id, locationIdentifier: location.id,
            windowIdentifier: window.id, proposedText: proposedNote)
        return .result()
    }
}
#endif
