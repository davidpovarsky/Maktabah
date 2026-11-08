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

        let resultElement = app.descendants(matching: .any)["sefaria-embedded-acceptance-result"]
        XCTAssertTrue(resultElement.waitForExistence(timeout: 60.0), "sefaria-embedded-acceptance-result element must appear within 60s")

        // Wait until accessibilityValue or accessibilityLabel contains SUCCESS or FAILURE
        let predicate = NSPredicate(format: "value CONTAINS 'SUCCESS' OR value CONTAINS 'FAILURE' OR label CONTAINS 'SUCCESS' OR label CONTAINS 'FAILURE'")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: resultElement)
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: 120.0)
        XCTAssertEqual(waitResult, .completed, "Acceptance runner timed out waiting for diagnostic completion")

        let rawString: String? = {
            if let val = resultElement.value as? String, val.contains("{") {
                return val
            }
            if resultElement.label.contains("{") {
                return resultElement.label
            }
            return (resultElement.value as? String) ?? resultElement.label
        }()

        guard let jsonString = rawString,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Failed to parse sefaria-embedded-acceptance-result JSON: \(String(describing: rawString))")
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
            "lateGenerationRejected",
            "runtimeInitialize",
            "catalogTOC",
            "textLoadGenesis",
            "textLoadBerakhot",
            "textOriginRemote",
            "navigationTextToc",
            "relatedContent",
            "searchLive",
            "searchOpenResult",
            "fullReactSurface",
            "normalAppBootstrap",
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
        launchWithScenario("reader", backend: "sefariaEmbedded")
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60))
        let hebrewText = NSPredicate { _, _ in
            let value = text.value as? String ?? ""
            return value.unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) }.count > 30
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hebrewText, object: text)], timeout: 60), .completed)
        XCTAssertTrue(app.staticTexts["reader-current-locator"].label.contains("sefariaEmbedded"))
    }

    func testEmbeddedSefariaHebrewTOC() throws {
        try verifyTOC(language: "he", firstChapter: "פרק א׳", secondChapter: "פרק ב׳")
    }

    func testEmbeddedSefariaEnglishTOC() throws {
        try verifyTOC(language: "en", firstChapter: "Chapter 1", secondChapter: "Chapter 2")
    }

    private func verifyTOC(language: String, firstChapter: String, secondChapter: String) throws {
        launchWithScenario("readerTOC", backend: "sefariaEmbedded", language: language)
        let toggle = app.buttons["reader-toc-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 60))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons[firstChapter].waitForExistence(timeout: 30))
        let next = app.buttons[secondChapter]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let locator = app.staticTexts["reader-current-locator"]
        let expected = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "sefariaEmbedded", "Genesis 2")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: expected, object: locator)], timeout: 30), .completed)
    }

    func testEmbeddedSefariaInspectorRealContent() throws {
        launchWithScenario("studyCommentaries", backend: "sefariaEmbedded")
        let group = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'torah-inspector-commentary-group-'")).firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 60), "Genesis must have real commentary groups")
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let source = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'torah-inspector-source-'")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 30))
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'torah-inspector-open-'")).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 30), "A real related source must be openable")
        open.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let locator = app.staticTexts["reader-current-locator"]
        let expected = NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "sefariaEmbedded", "|Genesis|")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: expected, object: locator)], timeout: 30), .completed)
    }

    func testEmbeddedSefariaHebrewSearchExpansion() throws {
        launchWithScenario("searchResults", backend: "sefariaEmbedded")
        let toggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-result-preview-toggle'")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 60), "Live search must return a real result")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let preview = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'search-result-expanded-preview-'")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 20))
        let content = NSPredicate { _, _ in
            preview.staticTexts.allElementsBoundByIndex.contains { element in
                element.label.unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) }.count > 30
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: content, object: preview)], timeout: 60), .completed,
            "Expanded full text must contain actual Hebrew, not just a title or loading label")
        let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-result-open-'")).firstMatch
        XCTAssertTrue(open.exists)
        open.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.textViews["reader-text"].waitForExistence(timeout: 30))
    }

    func testThreeBackendSwitchRegression() throws {
        // Run full synthetic backend switch regression
        launchWithScenario("backendSwitchRegression", backend: "sefariaEmbedded")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 20.0), "App must complete backend switch scenario cleanly")
    }
}
