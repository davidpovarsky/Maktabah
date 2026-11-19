import XCTest

/// Registered from Tests/HQ/sidebar/BookHistoryScopeAcceptanceTests.swift.
/// Current native Search controls supply the original real-history precondition.
final class BookHistoryScopeAcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }

    @MainActor
    private func launchOriginalGlobalSearch() throws -> XCUIElement {
        launchWithTier(.realUI, backend: "otzaria",
                       extraArgs: ["-preferredBackend", "otzaria", "-smokeBackend", "otzaria",
                                   "-ChavrusaTextFaithfulReaderUIEnabled", "YES",
                                   "-studyWorkspaceTestingNamespace", workspaceNamespace,
                                   "-lastSelectedTab", "0"], language: "he", locale: "he_IL")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        let tab = findTabButton(hebrew: "חיפוש", english: "Search")
        XCTAssertTrue(tab.waitForExistence(timeout: 60))
        XCTAssertTrue(tab.isHittable)
        tab.tap()
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 40))
        let fields = app.descendants(matching: .any).matching(identifier: "global-search-query")
        XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(fields.count, 1)
        let field = try XCTUnwrap(fields.allElementsBoundByIndex.first)
        XCTAssertTrue(field.elementType == .searchField || field.elementType == .textField)
        XCTAssertTrue(field.isHittable)
        return field
    }

    @MainActor
    private func submitAndVerifyPersistedGlobalHistory() throws -> String {
        let query = "בדיקת היסטוריה " + UUID().uuidString
        let input = try launchOriginalGlobalSearch()
        input.tap()
        input.typeText(query + "\n")
        XCTAssertEqual(input.value as? String, query)
        let submitted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.app.collectionViews["global-search-history"].exists
                && !self.app.otherElements["global-search-loading"].exists
                && !self.app.buttons["global-search-cancel"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [submitted], timeout: 90), .completed,
                       "The actual Return action must submit and finish the original search")
        app.terminate()
        _ = try launchOriginalGlobalSearch()
        let history = app.collectionViews["global-search-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 20))
        let rows = history.buttons.matching(identifier: "global-search-history-" + query)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(rows.count, 1, "A real submitted query must survive relaunch in original global history")
        XCTAssertTrue(rows.firstMatch.isHittable)
        retainNativeEvidence("book-history-scope-real-global-submission-persisted")
        return query
    }

    @MainActor
    func testBookSearchRetainsControlsWithoutGlobalHistory() throws {
        XCTAssertTrue(isPad, "Required iPad Native acceptance must not skip on another device")
        let orientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = orientation }
        XCUIDevice.shared.orientation = .landscapeLeft

        let query = try submitAndVerifyPersistedGlobalHistory()
        app.terminate()
        launchReader()
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()

        let toolbar = app.toolbars.containing(.button, identifier: "reader-more-menu").firstMatch
        tap(toolbar.buttons.matching(NSPredicate(format:
            "label == 'חיפוש' OR label == 'Search'")).firstMatch)
        let input = app.searchFields.firstMatch
        tap(input)

        // A missing entire overlay must fail this positive loaded-component
        // oracle before its global-history absence can be accepted.
        let modes = app.segmentedControls.firstMatch
        XCTAssertTrue(modes.waitForExistence(timeout: 15))
        XCTAssertEqual(modes.buttons.count, 4, "Retain the four existing search modes")
        let help = app.buttons.matching(NSPredicate(format: "label IN %@", ["עזרה", "Help"])).firstMatch
        XCTAssertTrue(help.exists, "Retain native book-search help")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists,
                       "Book search must not expose the persisted global query")

        // The original fourth mode is Near. Its original distance input must
        // remain available without exposing the real persisted global query.
        tap(modes.buttons.element(boundBy: 3))
        let distance = app.textFields["10"]
        XCTAssertTrue(distance.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists)
        retainNativeEvidence("book-search-controls-without-global-history")
    }
}
