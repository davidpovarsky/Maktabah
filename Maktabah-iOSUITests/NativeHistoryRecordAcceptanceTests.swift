import XCTest

// Six additive, exact selectors. They reuse the original system/fixture helper;
// none replaces a historical Native116 or Release114+2 assertion or timeout.
// Native execution is pending an integrated, qualified original app build.
final class NativeHistoryRecordAcceptanceTests: NativeRoutingAcceptanceTests {
    @MainActor func testHistoryRecordFromOriginalLibraryShowsExactOriginalCardAndReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: true, favorite: false,
                                                       warm: false, fromBackground: false)
    }
    @MainActor func testFavoriteRecordOnWarmOriginalHistoryShowsExactOriginalCardAndReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: true, favorite: true,
                                                       warm: true, fromBackground: false)
    }
    @MainActor func testCachedFavoriteRemovedThroughOriginalControlIsRefusedWithoutReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: true, favorite: true,
                                                       warm: true, fromBackground: false, removeCachedFavorite: true)
    }
}

final class NativeHistoryRecordPhoneAcceptanceTests: NativeRoutingAcceptanceTests {
    @MainActor func testPhoneHistoryRecordFromOriginalLibraryShowsExactOriginalCardAndReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: false, favorite: false,
                                                       warm: false, fromBackground: false)
    }
    @MainActor func testPhoneFavoriteRecordReturnsFromBackgroundToExactOriginalCardAndReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: false, favorite: true,
                                                       warm: false, fromBackground: true)
    }
    @MainActor func testPhoneCachedFavoriteRemovedThroughOriginalControlIsRefusedWithoutReceipt() async throws {
        try await runOriginalHistoryRecordSystemIntent(expectedPad: false, favorite: true,
                                                       warm: true, fromBackground: false, removeCachedFavorite: true)
    }
}

extension NativeHistoryRecordAcceptanceTests {
    @MainActor func testFilteredHistoryRecordFromLibraryPreservesOriginalQueryAndExactCard() async throws {
        try await runOriginalFilteredHistoryRecordSystemIntent(expectedPad: true, favorite: false, fromBackground: false)
    }
}

extension NativeHistoryRecordPhoneAcceptanceTests {
    @MainActor func testPhoneFilteredFavoriteRecordFromBackgroundPreservesOriginalQueryAndExactCard() async throws {
        try await runOriginalFilteredHistoryRecordSystemIntent(expectedPad: false, favorite: true, fromBackground: true)
    }
}
