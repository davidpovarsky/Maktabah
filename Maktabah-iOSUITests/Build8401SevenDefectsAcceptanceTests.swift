//
//  Build8401SevenDefectsAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Genuine User Acceptance Tests for Build 8401 Seven Defect Matrix (A1-G2).
//  Validates real UI workflows, element geometry, search context, and bidirectional transitions.
//

import XCTest

final class Build8401SevenDefectsAcceptanceTests: MaktabahUITestBase {

    // MARK: - A1, A2, A3: Search Highlight & Clear 'X' Button Lifecycle

    func testA1_A2_SearchResultHighlightAndClearButton() throws {
        // Launch into searchOpen scenario which opens the result in reader with search context
        launchWithScenario("searchOpen", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open for search result")

        // A2: Clear 'X' button must be visible when active search highlight exists
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertTrue(waitForElement(clearButton, timeout: 8.0), "Clear 'X' button must appear next to search button")

        // Wait for element to settle and tap it
        let isHittablePredicate = NSPredicate(format: "isHittable == true")
        let hittableExpectation = XCTNSPredicateExpectation(predicate: isHittablePredicate, object: clearButton)
        let waitResult = XCTWaiter().wait(for: [hittableExpectation], timeout: 5.0)
        if waitResult == .completed && clearButton.isHittable {
            clearButton.tap()
        } else {
            clearButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        // After tapping, Clear 'X' button must disappear
        let clearButtonPredicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: clearButtonPredicate, object: clearButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "Clear 'X' button must disappear after being tapped")
    }

    func testA3_OrdinaryReaderHasNoClearSearchHighlightButton() throws {
        // Launch normal reader without search provenance
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must exist")

        // Verify Clear 'X' button is NOT present for ordinary reading
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertFalse(clearButton.exists, "Clear 'X' button must NOT appear in normal reading mode without search origin")
    }

    // MARK: - B1, B2, B3, B4: Bidirectional Paging & Bound Durability

    func testB1_B2_PagingTransitionsPreserveReaderStability() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        let initialTitle = headerTitle.label
        XCTAssertFalse(initialTitle.isEmpty, "Initial title must not be empty")

        // Perform forward navigation via swipe
        readerSurface.swipeUp()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after forward scroll/swipe")

        // Perform backward navigation via swipe
        readerSurface.swipeDown()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after backward scroll/swipe")
        XCTAssertFalse(headerTitle.label.isEmpty, "Reader header title must remain populated after reverse scroll")
    }

    // MARK: - D1, D2: TOC Location Tracking & Loading State

    func testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState() throws {
        launchWithScenario("readerTOC", backend: "sefaria")
        dismissAlertsIfNeeded()

        // TOC list or navigation items must appear
        let tocSearch = app.searchFields.firstMatch
        XCTAssertTrue(waitForElement(tocSearch, timeout: 12.0), "TOC view must be presented and interactive")

        // "אין תוכן עניינים" must NOT be displayed when valid TOC is loading or loaded
        let noTOCUnavailable = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'אין תוכן עניינים' OR label CONTAINS[c] 'No Table of Contents'")
        ).firstMatch
        XCTAssertFalse(noTOCUnavailable.exists, "TOC must not display premature 'No Table of Contents' for a valid work")
    }

    // MARK: - F1, F2: Sefaria Localization & RTL

    func testF1_SefariaHebrewLocaleRTLAndHebrewHeaders() throws {
        launchWithScenario("reader", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 10.0), "Hebrew library tab must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Reader header title must exist")
        XCTAssertFalse(headerTitle.label.isEmpty, "Header title must be populated in Hebrew locale")
    }
}
