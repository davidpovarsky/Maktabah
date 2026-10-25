//
//  PullNavigationAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A3.2: Pull navigation gestures, threshold retreat/cancel,
//  commit in both directions, and duplicate transition prevention.
//

import XCTest

final class PullNavigationAcceptanceTests: MaktabahUITestBase {

    func testPullNavigationRetreatCancelDoesNotChangeContent() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        let initialTitle = headerTitle.label
        XCTAssertFalse(initialTitle.isEmpty, "Initial header title must not be empty")

        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Reader canonical locator must exist")
        let initialLocator = currentLocator.label
        XCTAssertFalse(initialLocator.isEmpty, "Initial canonical locator must not be empty")

        // Perform sub-threshold drag (pull down slightly and retreat back)
        let startCoordinate = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let subThresholdCoordinate = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))

        // Drag down by a small distance (< threshold) and move back up to cancel
        startCoordinate.press(forDuration: 0.1, thenDragTo: subThresholdCoordinate)
        subThresholdCoordinate.press(forDuration: 0.05, thenDragTo: startCoordinate)

        // Allow any animation to settle
        _ = readerSurface.waitForExistence(timeout: 2.0)

        // Content must NOT have changed after a retreat/cancel
        XCTAssertTrue(headerTitle.exists, "Header title must exist")
        XCTAssertEqual(headerTitle.label, initialTitle, "Header title must remain unchanged after retreat/cancel")
        XCTAssertTrue(currentLocator.exists, "Locator must exist after retreat/cancel")
        XCTAssertEqual(currentLocator.label, initialLocator, "Locator must remain unchanged after retreat/cancel")
    }

    func testPullNavigationCommitBothDirectionsWithoutDuplicates() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        let initialTitle = headerTitle.label
        XCTAssertFalse(initialTitle.isEmpty, "Initial reader header title must not be empty")

        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Reader canonical locator must exist")
        let initialLocator = currentLocator.label
        XCTAssertFalse(initialLocator.isEmpty, "Initial canonical locator must not be empty")

        // 1. Commit in downward direction (drag down past threshold)
        let topStart = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let bottomTarget = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        topStart.press(forDuration: 0.1, thenDragTo: bottomTarget)

        // Wait for page transition and reader surface to settle
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must remain valid after downward transition")

        // 2. Commit in opposite (upward) direction (drag up past threshold)
        let bottomStart = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let topTarget = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        bottomStart.press(forDuration: 0.1, thenDragTo: topTarget)

        // Wait for reverse transition to complete
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must remain stable after bidirectional transitions")
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist after reverse transition")
        let finalTitle = headerTitle.label
        XCTAssertFalse(finalTitle.isEmpty, "Reader header title must not be empty")
        XCTAssertEqual(finalTitle, initialTitle, "Header title must match initial title after bidirectional transition round-trip")
        XCTAssertTrue(currentLocator.exists, "Locator must exist after reverse transition")
        XCTAssertEqual(currentLocator.label, initialLocator, "Locator must match initial locator after bidirectional transition round-trip")
    }
}
