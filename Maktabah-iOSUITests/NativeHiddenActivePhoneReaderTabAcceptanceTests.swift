import XCTest

enum OriginalHiddenPhoneReaderTabEntry: String {
    case library
    case background
    case history
}

// Additive actual-system selectors for the original already-active phone tab.
// Native116, Release114 and all existing Reader-tab selectors stay unchanged.
extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromLibrary() async throws {
        try await runOriginalHiddenActivePhoneReaderTabSystemIntent(entry: .library)
    }

    @MainActor
    func testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromBackground() async throws {
        try await runOriginalHiddenActivePhoneReaderTabSystemIntent(entry: .background)
    }

    @MainActor
    func testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromHistory() async throws {
        try await runOriginalHiddenActivePhoneReaderTabSystemIntent(entry: .history)
    }

    @MainActor
    func testPhoneSystemReaderTabIntentRejectsCachedHiddenReaderAfterOriginalGroupDeparture() async throws {
        try await runOriginalHiddenActivePhoneReaderTabSystemIntent(
            entry: .library, rejectPreviousGroupFromBackground: false)
    }

    @MainActor
    func testPhoneSystemReaderTabIntentRejectsCachedHiddenReaderAfterOriginalGroupDepartureFromBackground() async throws {
        try await runOriginalHiddenActivePhoneReaderTabSystemIntent(
            entry: .library, rejectPreviousGroupFromBackground: true)
    }
}
