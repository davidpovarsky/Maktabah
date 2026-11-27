import XCTest

enum OriginalHiddenWorkspaceKind: String { case group, profile }
enum OriginalHiddenWorkspaceEntry: String { case library, background, history, search }

// Six additive actual-system selectors. The existing Group/Profile, ReaderTab,
// Native116 and Release114 cases stay unchanged. These are miniTest10 controls;
// production, complete restoration, VoiceOver and physical QA remain separate.
extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhoneGroupIntentPresentsSameActiveHiddenReaderFromLibrary() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .group, entry: .library)
    }
    @MainActor func testPhoneProfileIntentPresentsSameActiveHiddenReaderFromLibrary() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .profile, entry: .library)
    }
    @MainActor func testPhoneGroupIntentPresentsSameActiveHiddenReaderFromBackground() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .group, entry: .background)
    }
    @MainActor func testPhoneProfileIntentPresentsSameActiveHiddenReaderFromBackground() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .profile, entry: .background)
    }
    @MainActor func testPhoneGroupIntentPresentsSameActiveHiddenReaderFromOriginalHistory() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .group, entry: .history)
    }
    @MainActor func testPhoneProfileIntentPresentsSameActiveHiddenReaderFromOriginalSearch() async throws {
        try await runOriginalHiddenWorkspaceSelection(kind: .profile, entry: .search)
    }
}
