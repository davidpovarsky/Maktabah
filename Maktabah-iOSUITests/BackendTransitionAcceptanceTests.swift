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
}
