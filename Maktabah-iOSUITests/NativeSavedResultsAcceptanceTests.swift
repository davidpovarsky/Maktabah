import XCTest

// Additive, real-system acceptance selectors. The original synchronized
// iOS UI-test target includes this file; Apple discovery/execution is pending.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSavedResultsSystemFolderRevealsOriginalNestedPageOnPad() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: true, journey: .folder)
    }

    @MainActor
    func testSavedResultsSystemResultRevealsOriginalRowWithoutExecutingOnPad() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: true, journey: .result)
    }

    @MainActor
    func testSavedResultsCachedResultRefusesAfterOriginalTreeReloadOnPad() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: true, journey: .resultAfterReload)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testSavedResultsSystemFolderRevealsOriginalNestedPageOnPhone() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: false, journey: .folder)
    }

    @MainActor
    func testSavedResultsSystemResultForegroundsOriginalRowOnPhone() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: false, journey: .result, fromBackground: true)
    }

    @MainActor
    func testSavedResultsCachedFolderRefusesFromBackgroundAfterOriginalDeleteOnPhone() async throws {
        try await runOriginalSavedResultsSystemIntent(expectedPad: false, journey: .folderAfterDeletion, fromBackground: true)
    }
}
