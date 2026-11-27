import XCTest

// Additive focused selectors. These do not alter Native116/Release114 or
// replace the original first-page Search, RTL, accessibility or Reader suites.
extension NativeRoutingAcceptanceTests {
    @MainActor func testOriginalSearchContinuationRevealsLoadedHitInEnglishAndHebrew() throws {
        try runOriginalSearchContinuation(expectedPad: true, page: false)
    }
    @MainActor func testOriginalSearchContinuationCommitsOneActualNextPage() throws {
        try runOriginalSearchContinuation(expectedPad: true, page: true)
    }
    @MainActor func testOriginalSearchContinuationLoadedHitAboveOriginalKeyboard() throws {
        try runOriginalSearchContinuation(expectedPad: true, page: false, keyboard: true)
    }
    @MainActor func testOriginalSearchContinuationActualVoiceOverTraversal() throws {
        try runOriginalSearchContinuation(expectedPad: true, page: false, voiceOver: true)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhoneOriginalSearchContinuationRevealsLoadedHitInEnglishAndHebrew() throws {
        try runOriginalSearchContinuation(expectedPad: false, page: false)
    }
    @MainActor func testPhoneOriginalSearchContinuationCommitsOneActualNextPage() throws {
        try runOriginalSearchContinuation(expectedPad: false, page: true)
    }
    @MainActor func testPhoneOriginalSearchContinuationLoadedHitAboveOriginalKeyboard() throws {
        try runOriginalSearchContinuation(expectedPad: false, page: false, keyboard: true)
    }
    @MainActor func testPhoneOriginalSearchContinuationActualVoiceOverTraversal() throws {
        try runOriginalSearchContinuation(expectedPad: false, page: false, voiceOver: true)
    }
}
