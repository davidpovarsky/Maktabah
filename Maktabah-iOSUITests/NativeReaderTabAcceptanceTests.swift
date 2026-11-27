import XCTest

// Six additive, explicit system selectors. Historical Native116 / Release114+2
// source, assertions and timeout values remain unchanged. Native execution is
// pending the exact integrated qualified app; source parsing is not acceptance.
enum OriginalReaderTabRefusal: String {
    case closed
    case previousGroup
}

extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemReaderTabIntentReusesOriginalLiveTab() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: true)
    }

    @MainActor
    func testSystemReaderTabIntentDistinguishesOriginalDuplicateBookTabs() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: true, duplicateBook: true)
    }

    @MainActor
    func testSystemReaderTabIntentRejectsCachedClosedTabWithoutReceipt() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: true, refusal: .closed)
    }

    @MainActor
    func testSystemReaderTabIntentRejectsCachedOtherGroupTabWithoutReceipt() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: true, refusal: .previousGroup)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemReaderTabIntentReusesOriginalLiveTab() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: false)
    }

    @MainActor
    func testPhoneSystemReaderTabIntentReturnsFromBackgroundToOriginalLiveTab() async throws {
        try await runOriginalReaderTabSystemIntent(expectedPad: false, fromBackground: true)
    }
}
