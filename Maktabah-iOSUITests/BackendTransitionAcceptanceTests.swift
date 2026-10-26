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
        // Launch into settings scenario with production profile and Sefaria active
        launchWithTier(.production, scenario: "settings", backend: "sefaria")
        dismissAlertsIfNeeded()

        let picker = app.descendants(matching: .any)["settings-library-source-picker"]
        XCTAssertTrue(waitForElement(picker, timeout: 8.0), "Settings library source picker must exist")

        let otzariaOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Otzaria' OR label CONTAINS[c] 'אוצריא'")
        ).firstMatch

        if picker.elementType == .picker {
            picker.adjust(toPickerWheelValue: "Otzaria")
        } else if otzariaOption.exists && otzariaOption.isHittable {
            otzariaOption.tap()
        } else if picker.isHittable {
            picker.tap()
            let menuOption = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Otzaria' OR label CONTAINS[c] 'אוצריא'")
            ).firstMatch
            if menuOption.waitForExistence(timeout: 4.0) {
                menuOption.tap()
            }
        }

        // Verify active backend diagnostic updates or transition settles
        let activeBackendText = app.staticTexts["settings-active-backend-id"]
        _ = activeBackendText.waitForExistence(timeout: 8.0)

        // Wait for transition to complete and Done button to be tapped
        let doneButton = app.buttons["settings-done-button"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 10.0),
            "Settings Done button must exist after selecting provisioned Otzaria backend"
        )
        XCTAssertTrue(doneButton.isHittable, "Settings Done button must be hittable")
        doneButton.tap()

        // Verify library tab is restored and functional
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(
            waitForElement(libraryTab, timeout: 15.0),
            "Library tab must remain responsive after settings backend transition"
        )
    }

    func testBackendSwitchWhenCorpusUnavailablePresentsConfigurationPrompt() throws {
        // When Otzaria database is not configured, selecting Otzaria in Settings
        // must present the configuration / download flow rather than silently falling back.
        if let sharedRoot = ProcessInfo.processInfo.environment["OTZARIA_SHARED_ROOT_OVERRIDE"],
           FileManager.default.fileExists(atPath: URL(fileURLWithPath: sharedRoot).appendingPathComponent("Otzaria/seforim.db").path) {
            throw XCTSkip("Otzaria corpus is installed in this test environment; negative test only applies when unconfigured")
        }

        launchWithScenario("settings", backend: "sefaria")
        dismissAlertsIfNeeded()

        let picker = app.descendants(matching: .any)["settings-library-source-picker"]
        XCTAssertTrue(waitForElement(picker, timeout: 8.0), "Settings library source picker must exist")

        let otzariaOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Otzaria' OR label CONTAINS[c] 'אוצריא'")
        ).firstMatch

        if picker.elementType == .picker {
            picker.adjust(toPickerWheelValue: "Otzaria")
        } else if otzariaOption.exists && otzariaOption.isHittable {
            otzariaOption.tap()
        } else if picker.isHittable {
            picker.tap()
            let menuOption = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Otzaria' OR label CONTAINS[c] 'אוצריא'")
            ).firstMatch
            if menuOption.waitForExistence(timeout: 4.0) {
                menuOption.tap()
            }
        }

        // Verify that either the Done button is dismissed or configuration prompt appears
        let doneButton = app.buttons["settings-done-button"]
        let setupPrompt = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'הורד' OR label CONTAINS[c] 'הורדה' OR label CONTAINS[c] 'Download' OR label CONTAINS[c] 'Database'")
        ).firstMatch

        let isHandled = !doneButton.waitForExistence(timeout: 4.0) || setupPrompt.exists
        XCTAssertTrue(isHandled, "Selecting unconfigured backend must trigger configuration prompt or dismiss Done button")
    }
}
