#if os(iOS)
import AppIntents
import Foundation

public struct OpenAnnotationEditorIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open annotation editor"
    public static let description = IntentDescription("Open an existing annotation in its original editor.")
    public static let supportedModes: IntentModes = .foreground
    @Parameter(title: "Annotation record", query: NativeAnnotationRecordQuery())
    public var annotation: NativeAnnotationRecordEntity
    @Parameter(title: "Annotations window", query: NativeAnnotationWindowQuery())
    public var window: NativeDestinationEntity
    @Dependency private var service: NativeAnnotationEditorIntentService
    public static var parameterSummary: some ParameterSummary {
        Summary("Open annotation editor") { \.$annotation; \.$window }
    }
    public init() {}
    public func perform() async throws -> some IntentResult {
        let acknowledgement = try await service.open(identifier: annotation.id, windowIdentifier: window.id)
        try NativeIntentOutcome.requireVisibleAcknowledgement(acknowledgement)
        return .result()
    }
}
#endif
