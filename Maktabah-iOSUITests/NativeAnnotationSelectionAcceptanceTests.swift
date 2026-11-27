import XCTest

/// Additive original system-Intent acceptance for a warm mounted Annotation
/// list. These tests do not qualify editor/body/filter intents, cold routing,
/// production data, Siri/VoiceOver, device behavior or physical QA.
extension NativeRoutingAcceptanceTests {
    @MainActor func testOriginalIPadAnnotationRecordUsesActualSystemEntityAndSelectedCell() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: true, journey: .select)
    }
    @MainActor func testOriginalIPadAnnotationRecordForegroundsSameOriginalList() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: true, journey: .select, fromBackground: true)
    }
    @MainActor func testOriginalIPadCachedAnnotationRefusesOriginalSearchABAWithoutMutation() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: true, journey: .searchABA)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testOriginalIPhoneAnnotationRecordUsesActualSystemEntityAndSelectedCell() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: false, journey: .select)
    }
    @MainActor func testOriginalIPhoneAnnotationRecordForegroundsSameOriginalList() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: false, journey: .select, fromBackground: true)
    }
    @MainActor func testOriginalIPhoneCachedAnnotationRefusesSearchABAFromBackgroundWithoutMutation() async throws {
        try await runOriginalAnnotationSelectionSystemIntent(expectedPad: false, journey: .searchABA, fromBackground: true)
    }
}
