//
//  iPadTabBarAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A3.1: iPad Tab Bar persistence & visibility verification.
//

import XCTest

final class iPadTabBarAcceptanceTests: MaktabahUITestBase {

    func testiPadTabBarVisibleAndHittableInReader() throws {
        launchWithScenario("reader", backend: "sefaria")

        if isPad {
            dismissAlertsIfNeeded()

            // On iPad, TabView renders either as floating tab bar or top bar.
            // Verify tab buttons exist and have valid visible geometry.
            let libraryButton = findTabButton(hebrew: "ספר", english: "Library")
            let historyButton = findTabButton(hebrew: "היסטוריה", english: "History")

            XCTAssertTrue(waitForElement(libraryButton, timeout: 10.0), "Library tab button must exist on iPad in reader")
            XCTAssertTrue(libraryButton.frame.width > 0 && libraryButton.frame.height > 0, "Library tab button must have valid geometry")

            XCTAssertTrue(waitForElement(historyButton, timeout: 5.0), "History tab button must exist on iPad in reader")
            XCTAssertTrue(historyButton.frame.width > 0 && historyButton.frame.height > 0, "History tab button must have valid geometry")

            // Verify reader workspace is also visible simultaneously
            let readerSurface = app.otherElements["reader-surface"]
            XCTAssertTrue(readerSurface.waitForExistence(timeout: 5.0), "Reader surface must be visible alongside iPad tab bar")
        } else {
            // On iPhone, verify reader occupies full screen and tab bar is hidden
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists {
                XCTAssertFalse(tabBar.isHittable, "Tab bar must not be hittable in full-screen reader on iPhone")
            }
        }
    }

    func testiPadTabBarPersistsAcrossTOCAndInspectorTransitions() throws {
        guard isPad else {
            throw XCTSkip("This test specifically verifies iPad multi-column tab bar persistence")
        }

        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        // 1. Initial reader state - tab bar is visible
        let historyButton = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(waitForElement(historyButton, timeout: 10.0), "History tab button must exist")
        XCTAssertTrue(historyButton.frame.width > 0 && historyButton.frame.height > 0, "History tab button must be visible on iPad")

        // 2. Open TOC
        let tocToggle = app.buttons["reader-toc-toggle"]
        if tocToggle.waitForExistence(timeout: 5.0) {
            tocToggle.tap()

            // Verify tab bar remains visible while TOC is presented
            XCTAssertTrue(historyButton.exists, "History tab button must remain present with TOC open")
            XCTAssertTrue(historyButton.frame.width > 0, "History tab button must remain visible with TOC open")

            // Close TOC
            let tocClose = app.buttons["toc-close"]
            if tocClose.waitForExistence(timeout: 3.0) {
                tocClose.tap()
            }
        }

        // 3. Open Study/Inspector
        let studyToggle = app.buttons["reader-study-toggle"]
        if studyToggle.waitForExistence(timeout: 5.0) {
            studyToggle.tap()

            // Verify tab bar remains visible while Inspector is presented
            XCTAssertTrue(historyButton.exists, "History tab button must remain present with Inspector open")
            XCTAssertTrue(historyButton.frame.width > 0, "History tab button must remain visible with Inspector open")
        }
    }
}
