//
//  SefariaEmbeddedAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Acceptance tests for Sefaria-Mobile embedded original runtime on iPad Simulator.
//

import XCTest

final class SefariaEmbeddedAcceptanceTests: MaktabahUITestBase {

    func testEmbeddedSefariaFullAcceptanceDiagnostic() throws {
        launchWithTier(
            .smoke,
            scenario: "embeddedAcceptance",
            backend: "sefariaEmbedded",
            extraArgs: ["-runSefariaEmbeddedAcceptance"]
        )
        dismissAlertsIfNeeded()

        let resultElement = app.otherElements["sefaria-embedded-acceptance-result"]
        XCTAssertTrue(resultElement.waitForExistence(timeout: 60.0), "sefaria-embedded-acceptance-result element must appear within 60s")

        // Wait until accessibilityValue contains status
        let predicate = NSPredicate(format: "value CONTAINS 'SUCCESS' OR value CONTAINS 'FAILURE'")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: resultElement)
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: 60.0)
        XCTAssertEqual(waitResult, .completed, "Acceptance runner timed out waiting for diagnostic completion")

        guard let jsonString = resultElement.value as? String,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse sefaria-embedded-acceptance-result JSON: \(String(describing: resultElement.value))")
            return
        }

        let status = json["status"] as? String
        let failedStage = json["failedStage"] as? String
        let errorMessage = json["errorMessage"] as? String
        let stages = json["stages"] as? [String: [String: Any]] ?? [:]

        print("=== Acceptance Diagnostics Report ===")
        print(jsonString)

        XCTAssertEqual(status, "SUCCESS", "Acceptance failed at stage '\(failedStage ?? "unknown")': \(errorMessage ?? "none")")

        // Assert all mandatory stages passed
        let requiredStages = [
            "waitForReady",
            "echoHebrew",
            "echoErrorInjection",
            "runtimeInitialize",
            "catalogTOC",
            "textLoadGenesis",
            "textLoadBerakhot",
            "navigationTextToc",
            "backendSwitchRegression"
        ]

        for stage in requiredStages {
            guard let stageDict = stages[stage], stageDict["passed"] as? Bool == true else {
                XCTFail("Mandatory acceptance stage '\(stage)' failed or was skipped in report: \(jsonString)")
                return
            }
        }
    }

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
