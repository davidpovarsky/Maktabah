//
//  ChavrusaTextiPadUIAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Runtime regression tests for ChavrusaText iPad UI with all feature flags enabled.
//  Guards against UICollectionViewDiffableDataSource section-index assertion crashes
//  and verifies tab lifecycle across 0, 1, and multiple tabs on iPad.
//

import XCTest

final class ChavrusaTextiPadUIAcceptanceTests: MaktabahUITestBase {

    private var allFeatureFlagsEnabled: [String: String] {
        [
            "CHAVRUSA_FEATURE_SIDEBARPAGERENABLED": "1",
            "CHAVRUSA_FEATURE_SAFARITOOLBARSEARCHENABLED": "1",
            "CHAVRUSA_FEATURE_STUDYWORKSPACEENABLED": "1",
            "CHAVRUSA_FEATURE_DUCKTABSTRIPENABLED": "1",
            "CHAVRUSA_FEATURE_INSPECTORHOSTREFINEMENTENABLED": "1",
            "CHAVRUSA_FEATURE_SEMANTICSLIDERPOLICYENABLED": "1"
        ]
    }

    /// Tests that launching with 0 tabs (Catalog) and transitioning to 1 tab (Reader)
    /// and multiple tabs does not trigger the UICollectionView section-index assertion.
    func testChavrusaText_iPad_AllFeatureFlagsON_ZeroToOneToMultipleTabs_NoSectionCrash() throws {
        // Step 1: Launch with 0 tabs (catalog scenario) and all feature flags ON
        launchWithScenario(
            "catalog",
            backend: "sefaria",
            extraEnv: allFeatureFlagsEnabled
        )
        dismissAlertsIfNeeded()

        XCTAssertEqual(app.state, .runningForeground, "App must remain running in foreground with 0 tabs and all flags enabled")

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 15.0), "Library tab must be present in catalog mode")

        // Step 2: Launch into Reader (1 tab open) with all feature flags ON
        launchWithScenario(
            "reader",
            backend: "sefaria",
            extraEnv: allFeatureFlagsEnabled
        )
        dismissAlertsIfNeeded()

        XCTAssertEqual(app.state, .runningForeground, "App must remain running in foreground upon opening reader tab")

        let readerSurface = app.descendants(matching: .any)["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 30.0), "Reader surface must appear without crashing")

        // Verify the app did not crash during diffing or collection view layout
        XCTAssertEqual(app.state, .runningForeground, "App must stay in foreground after reader surface is rendered")

        // Step 3: Exercise multiple tabs / navigation controls
        // If the DuckDuckGo-style plus button or library button is present, tap it
        let newTabButton = app.buttons["פתח ספר חדש מהספרייה"]
        if newTabButton.waitForExistence(timeout: 4.0) && newTabButton.isHittable {
            newTabButton.tap()
            XCTAssertEqual(app.state, .runningForeground, "Tapping new tab button must not crash the app")
        }

        // Switch to history tab and back to verify layout stability
        let historyButton = findTabButton(hebrew: "היסטוריה", english: "History")
        if historyButton.waitForExistence(timeout: 4.0) && historyButton.isHittable {
            historyButton.tap()
            XCTAssertEqual(app.state, .runningForeground, "App must remain running after switching to history tab")

            let returnLibrary = findTabButton(hebrew: "ספר", english: "Library")
            if returnLibrary.waitForExistence(timeout: 4.0) && returnLibrary.isHittable {
                returnLibrary.tap()
                XCTAssertEqual(app.state, .runningForeground, "App must remain running after returning to library/reader")
            }
        }
    }

    /// Verifies that when Duck Tab Strip is disabled (feature flag OFF) while other flags
    /// remain enabled, the reader operates correctly in the legacy presentation mode.
    func testChavrusaText_iPad_DuckTabStripDisabled_NoRegression() throws {
        var flagsWithTabStripOff = allFeatureFlagsEnabled
        flagsWithTabStripOff["CHAVRUSA_FEATURE_DUCKTABSTRIPENABLED"] = "0"

        launchWithScenario(
            "reader",
            backend: "sefaria",
            extraEnv: flagsWithTabStripOff
        )
        dismissAlertsIfNeeded()

        XCTAssertEqual(app.state, .runningForeground, "App must remain running in foreground with Duck Tab Strip OFF")

        let readerSurface = app.descendants(matching: .any)["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 30.0), "Reader surface must appear with Duck Tab Strip OFF")
        XCTAssertEqual(app.state, .runningForeground, "App process must stay healthy throughout reader session")
    }

    /// Verifies reader TOC and study inspector transitions with all feature flags enabled.
    func testChavrusaText_iPad_AllFlagsON_ReaderTOCAndInspectorTransitions() throws {
        launchWithScenario(
            "reader",
            backend: "sefaria",
            extraEnv: allFeatureFlagsEnabled
        )
        dismissAlertsIfNeeded()

        let readerSurface = app.descendants(matching: .any)["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 30.0), "Reader surface must appear")

        // Toggle Table of Contents if available
        let tocToggle = app.buttons["reader-toc-toggle"]
        if tocToggle.waitForExistence(timeout: 5.0) && tocToggle.isHittable {
            tocToggle.tap()
            XCTAssertEqual(app.state, .runningForeground, "Tapping TOC toggle must not crash the app")

            let tocClose = app.buttons["toc-close"]
            if tocClose.waitForExistence(timeout: 3.0) && tocClose.isHittable {
                tocClose.tap()
                XCTAssertEqual(app.state, .runningForeground, "Closing TOC must not crash the app")
            }
        }

        // Toggle Study / Inspector if available
        let studyToggle = app.buttons["reader-study-toggle"]
        if studyToggle.waitForExistence(timeout: 5.0) && studyToggle.isHittable {
            studyToggle.tap()
            XCTAssertEqual(app.state, .runningForeground, "Tapping study toggle must not crash the app")
        }

        XCTAssertEqual(app.state, .runningForeground, "App must remain alive after all transitions")
    }
}
