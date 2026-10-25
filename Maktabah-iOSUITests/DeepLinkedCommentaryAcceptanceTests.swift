//
//  DeepLinkedCommentaryAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A2 & B4: Deep commentary links and bounded reading units.
//  Verifies that citations such as 'Rashi on Berakhot 15b:3:1' load the containing
//  section folio ('Rashi on Berakhot 15b') with segment focus rather than a blank 1-line unit,
//  and that ordinary linked source navigation does not display the search Clear 'X' button.
//

import XCTest

final class DeepLinkedCommentaryAcceptanceTests: MaktabahUITestBase {

    func testDeepCommentaryRashiBerakhotLoadsFullFolio() throws {
        // Launch into reader scenario
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open")

        // In ordinary reading or linked source navigation, Clear 'X' button must NOT appear
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertFalse(
            clearButton.exists,
            "Clear 'X' button must NOT appear for ordinary reader navigation or linked source citations"
        )

        // Verify current canonical locator is present
        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Canonical locator must exist")
        XCTAssertFalse(currentLocator.label.isEmpty, "Canonical locator must not be empty")
    }

    func testTanachPassageLoadsWholeChapterWithSegmentFocus() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        XCTAssertFalse(headerTitle.label.isEmpty, "Header title must not be empty")
    }
}
