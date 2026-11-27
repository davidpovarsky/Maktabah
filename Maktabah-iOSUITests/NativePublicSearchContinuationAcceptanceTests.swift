import XCTest

// These eight focused selectors require the DEBUG observation-only evidence
// hook and disposable miniTest10 original Search. They make no Release,
// production-corpus, cold/restored-source or physical-device acceptance claim.
extension NativeRoutingAcceptanceTests {
    @MainActor func testPadPublicLoadedSearchHitIntentEnglish() async throws {
        try await runPublicSearchContinuation(expectedPad: true, page: false, delivery: "intent", language: "en")
    }
    @MainActor func testPadPublicNextSearchPageIntentHebrew() async throws {
        try await runPublicSearchContinuation(expectedPad: true, page: true, delivery: "intent", language: "he")
    }
    @MainActor func testPadPublicLoadedSearchHitHTTPSHebrew() async throws {
        try await runPublicSearchContinuation(expectedPad: true, page: false, delivery: "https", language: "he")
    }
    @MainActor func testPadPublicNextSearchPageCustomURLEnglish() async throws {
        try await runPublicSearchContinuation(expectedPad: true, page: true, delivery: "customURL", language: "en")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhonePublicLoadedSearchHitIntentHebrew() async throws {
        try await runPublicSearchContinuation(expectedPad: false, page: false, delivery: "intent", language: "he")
    }
    @MainActor func testPhonePublicNextSearchPageIntentEnglish() async throws {
        try await runPublicSearchContinuation(expectedPad: false, page: true, delivery: "intent", language: "en")
    }
    @MainActor func testPhonePublicNextSearchPageHTTPSHebrew() async throws {
        try await runPublicSearchContinuation(expectedPad: false, page: true, delivery: "https", language: "he")
    }
    @MainActor func testPhonePublicLoadedSearchHitCustomURLEnglish() async throws {
        try await runPublicSearchContinuation(expectedPad: false, page: false, delivery: "customURL", language: "en")
    }
}
