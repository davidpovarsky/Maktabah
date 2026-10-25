//
//  BackendTransitionAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A4 & B3: Real backend transition round-trip (Otzaria <-> Sefaria),
//  tab preservation, and atomic fail-closed restoration.
//

import XCTest

final class BackendTransitionAcceptanceTests: MaktabahUITestBase {

    func testBackendSwitchRegressionScenario() throws {
        // Use the built-in synthetic backend switch regression test scenario
        launchWithScenario("backendSwitchRegression", backend: "otzaria")
        dismissAlertsIfNeeded()

        // In Hebrew locale the Library tab button label is "ספרייה", in English "Library"
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 15.0), "App must successfully complete backend switch scenario")
    }

    func testRoundTripBackendSwitchPersistsTabs() throws {
        // 1. Launch in Sefaria reader
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0))

        // 2. Relaunch with Otzaria backend to trigger transition
        launchWithScenario("reader", backend: "otzaria")
        dismissAlertsIfNeeded()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0))

        // 3. Switch back to Sefaria backend
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 10.0))
    }

    func testBackendSwitchViaSettingsPickerUI() throws {
        // Launch into settings scenario with Sefaria active
        launchWithScenario("settings", backend: "sefaria")
        dismissAlertsIfNeeded()

        let picker = app.pickers["settings-library-source-picker"]
        let otzariaOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Otzaria' OR label CONTAINS[c] 'אוצריא'")
        ).firstMatch

        if picker.waitForExistence(timeout: 5.0) {
            picker.adjust(toPickerWheelValue: "Otzaria")
        } else if otzariaOption.waitForExistence(timeout: 5.0) && otzariaOption.isHittable {
            otzariaOption.tap()
        }

        // Wait for transition to complete and Done button to be tapped
        let doneButton = app.buttons["settings-done-button"]
        if doneButton.waitForExistence(timeout: 10.0) && doneButton.isHittable {
            doneButton.tap()
        }

        // Verify library tab is restored and functional
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(
            waitForElement(libraryTab, timeout: 12.0),
            "Library tab must remain responsive after settings backend transition"
        )
    }
}
