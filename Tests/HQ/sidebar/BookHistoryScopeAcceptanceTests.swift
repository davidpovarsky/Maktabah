import XCTest

/// Prepared NOT_RUN; include in the existing UI-test target alongside
/// FaithfulReaderUIBase only for an authorized isolated miniTest10 runtime run.
final class BookHistoryScopeAcceptanceTests: FaithfulReaderUIBase {
    @MainActor
    func testBookSearchRetainsControlsWithoutGlobalHistory() throws {
        guard isPad else { throw XCTSkip("Physical iPad acceptance remains separate") }
        let orientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = orientation }
        XCUIDevice.shared.orientation = .landscapeLeft

        // Submits a unique real query through global native controls and
        // requires the actual global history row to be visible/hittable.
        let query = exerciseGlobalHistorySubmission(enabled: true)
        app.terminate()
        launchReader()
        assertReaderHasText()

        let toolbar = app.toolbars.containing(.button, identifier: "reader-more-menu").firstMatch
        tap(toolbar.buttons.matching(NSPredicate(format:
            "label == 'חיפוש' OR label == 'Search'")).firstMatch)
        let input = app.searchFields.firstMatch
        tap(input)

        // Positive component-loaded oracle before checking absence: removing
        // the entire overlay must fail rather than hiding history by accident.
        let modes = app.segmentedControls.firstMatch
        XCTAssertTrue(modes.waitForExistence(timeout: 15))
        XCTAssertEqual(modes.buttons.count, 4, "Retain the four existing search modes")
        let help = app.buttons.matching(NSPredicate(format: "label IN %@", ["עזרה", "Help"])).firstMatch
        XCTAssertTrue(help.exists, "Retain native book-search help")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists,
                       "Book search must not expose the persisted global query")

        // The original fourth mode is Near. Its distance input must still
        // appear after suppressing history; no result/engine is substituted.
        tap(modes.buttons.element(boundBy: 3))
        let distance = app.textFields["10"]
        XCTAssertTrue(distance.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists)
        retainNativeEvidence("book-search-controls-without-global-history")
    }
}
