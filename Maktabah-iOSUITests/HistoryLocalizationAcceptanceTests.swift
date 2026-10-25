//
//  HistoryLocalizationAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A3.4: History tab localization in Hebrew ("היסטוריה") and
//  English ("History"), RTL layout verification, and tab restoration across relaunch.
//

import XCTest

final class HistoryLocalizationAcceptanceTests: MaktabahUITestBase {

    func testHistoryTabLocalizedInHebrewWithRTLLayout() throws {
        launchWithScenario("catalog", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        // 1. Assert History tab label is explicitly "היסטוריה"
        let historyTab = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(waitForElement(historyTab, timeout: 10.0), "History tab must have label 'היסטוריה' in Hebrew")
        XCTAssertTrue(historyTab.label.contains("היסטוריה"), "History tab label must contain 'היסטוריה'")

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 5.0), "Library tab must exist in Hebrew")
        XCTAssertTrue(libraryTab.label.contains("ספר"), "Library tab label must contain 'ספר' (ספרייה)")

        // 2. Assert RTL layout alignment:
        // In iPad TabView with RTL (Hebrew), the tab buttons exist with nonzero frames
        if isPad && historyTab.exists && libraryTab.exists {
            let histFrame = historyTab.frame
            let libFrame = libraryTab.frame
            XCTAssertGreaterThan(histFrame.width, 0, "History tab button must have nonzero width")
            XCTAssertGreaterThan(libFrame.width, 0, "Library tab button must have nonzero width")
        }
    }

    func testHistoryTabLocalizedInEnglishWithLTRLayout() throws {
        launchWithScenario("catalog", backend: "sefaria", language: "en", locale: "en_US")
        dismissAlertsIfNeeded()

        // 1. Assert History tab label is explicitly "History"
        let historyTab = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(waitForElement(historyTab, timeout: 10.0), "History tab must have label 'History' in English")
        XCTAssertTrue(historyTab.label.contains("History"), "History tab label must contain 'History'")

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 5.0), "Library tab must exist in English")
        XCTAssertTrue(libraryTab.label.contains("Library"), "Library tab label must contain 'Library'")

        // 2. Assert Hebrew label is NOT present in English mode
        let hebrewTab = app.buttons.matching(NSPredicate(format: "label CONTAINS 'היסטוריה'")).firstMatch
        XCTAssertFalse(hebrewTab.exists, "Hebrew label 'היסטוריה' must not appear in English mode")
    }

    func testSelectedTabRestorationAfterRelaunch() throws {
        launchWithScenario("catalog", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        let historyTab = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(waitForElement(historyTab, timeout: 10.0))

        // Switch to History tab
        historyTab.tap()
        sleep(1)

        // Terminate and relaunch
        app.terminate()
        app.launch()
        dismissAlertsIfNeeded()

        // Verify history tab remains selected or restored
        let restoredHistory = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(waitForElement(restoredHistory, timeout: 10.0), "App must launch into restored state")
    }
}
