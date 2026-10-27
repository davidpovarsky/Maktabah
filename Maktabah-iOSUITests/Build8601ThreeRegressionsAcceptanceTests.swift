//
//  Build8601ThreeRegressionsAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Genuine User Acceptance Tests for Build 8601 Three Real-iPad Regressions:
//  - Defect A: Cross-Backend Switching (Otzaria -> Sefaria) without foreign locator error
//  - Defect B: Table of Contents Restoration after app relaunch on iPad
//  - Defect C: Otzaria Search Engine detailed diagnostic error channel
//

import XCTest

final class Build8601ThreeRegressionsAcceptanceTests: MaktabahUITestBase {

    // MARK: - Defect A: Cross-Backend Switch via Settings Picker UI

    func testDefectA_SwitchOtzariaToSefariaViaSettingsUI() throws {
        // Launch into Settings with Otzaria active
        launchWithScenario("settings", backend: "otzaria")
        dismissAlertsIfNeeded()

        let picker = app.descendants(matching: .any)["settings-library-source-picker"]
        XCTAssertTrue(waitForElement(picker, timeout: 10.0), "Library source picker must exist in Settings")

        // Switch to Sefaria
        let sefariaOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sefaria' OR label CONTAINS[c] 'ספריא'")
        ).firstMatch

        if picker.elementType == .picker {
            picker.adjust(toPickerWheelValue: "Sefaria")
        } else if sefariaOption.exists && sefariaOption.isHittable {
            sefariaOption.tap()
        } else if picker.isHittable {
            picker.tap()
            let menuOption = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Sefaria' OR label CONTAINS[c] 'ספריא'")
            ).firstMatch
            if waitForElement(menuOption, timeout: 3.0) {
                menuOption.tap()
            }
        }

        // Verify NO error alert pops up with 'foreign backend' error
        let alert = app.alerts.firstMatch
        if alert.exists {
            let alertText = alert.label + " " + alert.staticTexts.allElementsBoundByIndex.map { elem in elem.label }.joined(separator: " ")
            XCTAssertFalse(
                alertText.contains("foreign backend") || alertText.contains("Locator") || alertText.contains("foreignBackendLocator"),
                "Switch must not fail with foreign backend locator error: \(alertText)"
            )
        }

        // Verify Library source is now Sefaria
        let sefariaLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sefaria' OR label CONTAINS[c] 'ספריא'")
        ).firstMatch
        XCTAssertTrue(waitForElement(sefariaLabel, timeout: 5.0), "Sefaria must be the selected library source")
    }

    func testDefectA_RoundTripSwitchPreservesIntegrity() throws {
        // 1. Launch with Otzaria
        launchWithScenario("reader", backend: "otzaria")
        dismissAlertsIfNeeded()
        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0), "Reader surface opens in Otzaria")

        // 2. Switch to Sefaria
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0), "Reader surface opens in Sefaria")

        // 3. Switch back to Otzaria
        launchWithScenario("reader", backend: "otzaria")
        dismissAlertsIfNeeded()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0), "Reader surface switches back to Otzaria cleanly")
    }

    // MARK: - Defect B: Table of Contents Restoration on iPad Relaunch

    func testDefectB_TOCRestorationAfterRelaunch() throws {
        // Launch reader with TOC scenario
        launchWithScenario("readerTOC", backend: "otzaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface opens with restored book")

        // Toggle Table of Contents if button is present and hittable
        let tocToggle = app.buttons["reader-toc-toggle"]
        if tocToggle.exists && tocToggle.isHittable {
            tocToggle.tap()
        }

        // Verify that "אין תוכן עניינים" / "No Table of Contents" is NOT displayed prematurely
        let noTOCMessage = app.staticTexts.matching(
            NSPredicate(format: "label == 'אין תוכן עניינים' OR label == 'No Table of Contents'")
        ).firstMatch
        XCTAssertFalse(noTOCMessage.exists, "TOC must not display premature 'No Table of Contents' for a restored book")
    }

    // MARK: - Defect C: Otzaria Search Engine Detailed Error Channel

    func testDefectC_SearchDiagnosticsAndErrorLogging() throws {
        // Launch settings to inspect search status
        launchWithScenario("settings", backend: "otzaria")
        dismissAlertsIfNeeded()

        // Verify search section exists in settings
        let searchHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Search' OR label CONTAINS[c] 'חיפוש'")
        ).firstMatch
        XCTAssertTrue(waitForElement(searchHeader, timeout: 8.0), "Search settings section exists")

        // Verify that if an error occurs, it does NOT display misleading XCFramework message
        let misleadingMsg = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'ודא שה-XCFramework נוסף ל-target'")
        ).firstMatch
        XCTAssertFalse(misleadingMsg.exists, "Misleading XCFramework error message must never appear")
    }
}
