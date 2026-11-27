import XCTest

/// Additional UI-03 selectors. Run each on its declared actual form factor;
/// the historical Native116 and Release114 selector sets are unchanged.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemAppIntentLibraryContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.library",
            title: "Library contents", anchor: "native.library.contents", identifier: "library-contents-list")
    }

    @MainActor
    func testSystemAppIntentLibraryGroupingFromHistoryDoesNotOpenMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.library",
            title: "Group By", anchor: "native.library.grouping", identifier: "library-grouping")
        XCTAssertFalse(app.menus.firstMatch.exists, "Revealing the existing control must not execute its action")
    }

    @MainActor
    func testSystemAppIntentTOCContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.reader.toc",
            title: "Table of contents list", anchor: "native.reader.toc.contents", identifier: "toc-content-list")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemAppIntentLibraryContentsFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false, destination: "native.library",
            title: "Library contents", anchor: "native.library.contents", identifier: "library-contents-list")
    }

    @MainActor
    func testPhoneSystemAppIntentLibraryOptionsFromBackgroundDoesNotOpenMenu() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: false, destination: "native.library",
            title: "Library Options", anchor: "native.library.options", identifier: "library-options",
            fromBackground: true)
        XCTAssertFalse(app.menus.firstMatch.exists, "Revealing the existing control must not execute its action")
    }
}
