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


// This selector resolves the fixed component through the actual system entity
// query; the target is the ORIGINAL selected Button, not an added AX marker.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemAppIntentCurrentTOCEntryFromHistoryPreservesReader() async throws {
        try await runOriginalComponentSystemIntent(expectedPad: true, destination: "native.reader.toc",
            title: "Current Table of Contents Entry", anchor: "native.reader.toc.currentSelection",
            identifier: "", expectedValue: "selected", originalTarget: { app in
                let selected = app.buttons.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@ AND value == %@", "toc-row-", "selected"))
                XCTAssertEqual(selected.count, 1,
                    "Exactly one original selected row must be resolved; duplicate legacy IDs cannot be guessed")
                return selected.firstMatch
            })
    }
}
