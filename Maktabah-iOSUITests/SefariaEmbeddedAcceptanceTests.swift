//
//  SefariaEmbeddedAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Acceptance tests for Sefaria-Mobile embedded original runtime on iPad Simulator.
//

import XCTest

final class SefariaEmbeddedAcceptanceTests: MaktabahUITestBase {

    func testEmbeddedSefariaCatalogAndAppLaunch() throws {
        // Launch with sefariaEmbedded backend and catalog scenario
        launchWithScenario("catalog", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 20.0), "Library tab must be present when launching with sefariaEmbedded")
    }

    func testEmbeddedSefariaReaderPresentation() throws {
        // Launch with sefariaEmbedded backend and reader scenario
        launchWithScenario("reader", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 20.0), "Reader surface must be presented for sefariaEmbedded")
    }

    func testThreeBackendSwitchRegression() throws {
        // Run full synthetic backend switch regression
        launchWithScenario("backendSwitchRegression", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 20.0), "App must complete backend switch scenario cleanly")
    }
}
