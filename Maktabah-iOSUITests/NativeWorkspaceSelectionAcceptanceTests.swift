import XCTest

// Eight additive, focused system selectors. They preserve the complete existing
// NativeRouting file prefix, Native116/Release114+2 lists and all old assertions.
// These are original miniTest10 real-UI selectors; production/full-suite and
// physical acceptance remain separate. Actual native execution is NOT_RUN.
enum OriginalWorkspaceSelectionCase: String {
    case warmGroup
    case emptyGroup
    case firstProfileGroup
}

extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemTabGroupIntentReusesOriginalSavedReaders() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: true, selectionCase: .warmGroup)
    }

    @MainActor
    func testSystemTabGroupIntentShowsOriginalEmptyReader() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: true, selectionCase: .emptyGroup)
    }

    @MainActor
    func testSystemStudyProfileIntentSelectsOriginalFirstGroup() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: true, selectionCase: .firstProfileGroup)
    }

    @MainActor
    func testSystemTabGroupIntentRejectsActuallyDeletedCachedGroup() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: true, selectionCase: .warmGroup,
                                                           rejectDeletedGroup: true)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemTabGroupIntentReusesOriginalSavedReaders() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: false, selectionCase: .warmGroup)
    }

    @MainActor
    func testPhoneSystemTabGroupIntentShowsOriginalEmptyLibrary() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: false, selectionCase: .emptyGroup)
    }

    @MainActor
    func testPhoneSystemStudyProfileIntentSelectsOriginalFirstGroup() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: false, selectionCase: .firstProfileGroup)
    }

    @MainActor
    func testPhoneSystemTabGroupIntentReturnsFromBackgroundToOriginalReader() async throws {
        try await runOriginalWorkspaceSelectionSystemIntent(expectedPad: false, selectionCase: .warmGroup,
                                                           fromBackground: true)
    }
}
