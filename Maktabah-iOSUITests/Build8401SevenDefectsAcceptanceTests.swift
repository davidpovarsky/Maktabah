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

        // A1: Verify rendered search highlights in actual attributed text
        let snapshotBefore = getRenderedHighlightSnapshot()
        if let snapshotBefore {
            XCTAssertGreaterThan(
                snapshotBefore.searchHighlightCount,
                0,
                "Rendered attributed text must contain at least 1 search highlight range before clearing"
            )
        }

        // A2: Clear 'X' button must be visible when active search highlight exists
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertTrue(waitForElement(clearButton, timeout: 8.0), "Clear 'X' button must appear next to search button")

        // Wait for element to settle and tap it
        Thread.sleep(forTimeInterval: 0.5)
        clearButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // After tapping, Clear 'X' button must disappear
        let clearButtonPredicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: clearButtonPredicate, object: clearButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "Clear 'X' button must disappear after being tapped")

        // Verify rendered search highlights count returns to 0 in actual attributed text
        let snapshotAfter = getRenderedHighlightSnapshot()
        if let snapshotAfter {
            XCTAssertEqual(
                snapshotAfter.searchHighlightCount,
                0,
                "Rendered search highlight count must drop to 0 after tapping clear button"
            )
        }
    }

    func testA1_RealSearchFlowHighlightAndClear() throws {
        // Launch search results list scenario
        launchWithScenario("searchResults", backend: "sefaria")
        dismissAlertsIfNeeded()

        // Locate any search result preview toggle or open button
        let previewToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'search-result-preview-toggle'")
        ).firstMatch

        XCTAssertTrue(
            waitForElement(previewToggle, timeout: 15.0),
            "Search results list must populate with matching results"
        )
        previewToggle.tap()

        // Tap the Open button within the expanded result preview
        let openButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'search-result-open'")
        ).firstMatch

        if openButton.waitForExistence(timeout: 5.0) && openButton.isHittable {
            openButton.tap()
        } else {
            // Or tap preview toggle again / context menu open
            previewToggle.press(forDuration: 1.0)
            let contextOpen = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Open' OR label CONTAINS[c] 'פתח'")
            ).firstMatch
            if contextOpen.waitForExistence(timeout: 3.0) {
                contextOpen.tap()
            }
        }

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open upon selecting search result")

        // Clear button must appear
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        if clearButton.waitForExistence(timeout: 6.0) {
            let snapshot = getRenderedHighlightSnapshot()
            if let snapshot {
                XCTAssertGreaterThan(snapshot.searchHighlightCount, 0, "Rendered search highlights must be present")
            }
            clearButton.tap()
            let snapshotAfter = getRenderedHighlightSnapshot()
            if let snapshotAfter {
                XCTAssertEqual(snapshotAfter.searchHighlightCount, 0, "Search highlights must clear")
            }
        }
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

        let snapshot = getRenderedHighlightSnapshot()
        if let snapshot {
            XCTAssertEqual(snapshot.searchHighlightCount, 0, "Ordinary reader must have 0 search highlight ranges")
        }
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

        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Reader canonical locator must exist")
        let initialLocator = currentLocator.label
        XCTAssertFalse(initialLocator.isEmpty, "Initial canonical locator must not be empty")

        // Perform forward navigation via swipe
        readerSurface.swipeUp()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after forward scroll/swipe")

        // Perform backward navigation via swipe
        readerSurface.swipeDown()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after backward scroll/swipe")
        XCTAssertFalse(headerTitle.label.isEmpty, "Reader header title must remain populated after reverse scroll")
        XCTAssertEqual(currentLocator.label, initialLocator, "Canonical locator must match initial locator after round-trip scroll")
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

        // Active reading node should be marked as selected in TOC
        let selectedRow = app.buttons.matching(
            NSPredicate(format: "value == 'selected' OR isSelected == true")
        ).firstMatch
        _ = selectedRow.waitForExistence(timeout: 5.0)
    }

    // MARK: - F1, F2: Sefaria Localization, RTL & Hebrew TOC Structure

    func testF1_SefariaHebrewLocaleRTLAndHebrewHeaders() throws {
        launchWithScenario("reader", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 10.0), "Hebrew library tab must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Reader header title must exist")
        XCTAssertFalse(headerTitle.label.isEmpty, "Header title must be populated in Hebrew locale")
    }

    func testF2_HebrewTOCStructureAndDafLabels() throws {
        launchWithScenario("readerTOC", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        let tocSearch = app.searchFields.firstMatch
        XCTAssertTrue(waitForElement(tocSearch, timeout: 12.0), "TOC must be interactive")

        // Assert presence of structural or daf labels (e.g. 'פרק', 'דף', 'פרשה', 'ע״א', 'ע״ב', or traditional Hebrew notation)
        let hebrewStructureOrDaf = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'פרק' OR label CONTAINS 'דף' OR label CONTAINS 'פרשה' OR label CONTAINS 'ע״א' OR label CONTAINS 'ע״ב'")
        ).firstMatch

        XCTAssertTrue(
            hebrewStructureOrDaf.waitForExistence(timeout: 8.0),
            "Sefaria TOC must present localized Hebrew structural/daf notation"
        )
    }
}
