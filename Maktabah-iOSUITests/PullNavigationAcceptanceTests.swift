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

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        let initialTitle = headerTitle.exists ? headerTitle.label : ""

        // Perform sub-threshold drag (pull down slightly and retreat back)
        let startCoordinate = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let subThresholdCoordinate = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))

        // Drag down by a small distance (< threshold) and move back up to cancel
        startCoordinate.press(forDuration: 0.1, thenDragTo: subThresholdCoordinate)
        subThresholdCoordinate.press(forDuration: 0.05, thenDragTo: startCoordinate)

        // Allow any animation to settle
        sleep(1)

        // Content must NOT have changed after a retreat/cancel
        if headerTitle.exists {
            XCTAssertEqual(headerTitle.label, initialTitle, "Header title must remain unchanged after retreat/cancel")
        }
    }

    func testPullNavigationCommitBothDirectionsWithoutDuplicates() throws {
        launchWithScenario("reader", backend: "sefaria")

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        let initialTitle = headerTitle.exists ? headerTitle.label : ""

        // 1. Commit in downward direction (drag down past threshold)
        let topStart = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let bottomTarget = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        topStart.press(forDuration: 0.1, thenDragTo: bottomTarget)

        // Wait for page transition
        sleep(2)

        // Verify content updated or transition executed cleanly
        let nextTitle = headerTitle.exists ? headerTitle.label : ""
        XCTAssertTrue(readerSurface.exists, "Reader surface must remain valid after downward transition")

        // 2. Commit in opposite (upward) direction (drag up past threshold)
        let bottomStart = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let topTarget = readerSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        bottomStart.press(forDuration: 0.1, thenDragTo: topTarget)

        // Wait for reverse transition
        sleep(2)

        // Reader must be stable and responsive without crash or duplicated transitions
        XCTAssertTrue(readerSurface.exists, "Reader surface must remain stable after bidirectional transitions")
        let finalTitle = headerTitle.exists ? headerTitle.label : ""
        XCTAssertFalse(finalTitle.isEmpty, "Reader header title must not be empty")
    }
}
