import XCTest

/// Black-box tests use the actual production-default flags and original views.
/// A unique sidecar namespace isolates tests without changing canonical sessions/data.
class FaithfulReaderUIBase: MaktabahUITestBase {
    let workspaceNamespace = UUID().uuidString
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria") {
        launchWithTier(.smoke, scenario: scenario, backend: backend, extraArgs: [
            "-ChavrusaTextFaithfulReaderUIEnabled", enabled ? "YES" : "NO",
            "-studyWorkspaceTestingNamespace", workspaceNamespace
        ])
        dismissAlertsIfNeeded()
    }
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 30), file: file, line: line)
        XCTAssertTrue(element.frame.intersects(app.frame), "Control must be inside the actual app viewport", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func assertReaderHasText() {
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60), "The original TextKit reader must render")
        let predicate = NSPredicate(format: "value MATCHES %@", "(?s).{31,}")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: text)], timeout: 30), .completed,
                       "The original reader must contain genuine book text, not only a host identifier")
        let title = app.staticTexts["reader-header-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertFalse(["", "ספר", "Book 1"].contains(title.label), "A fabricated placeholder is not a genuine loaded book")
        let rendered = text.value as? String ?? ""
        XCTAssertFalse(rendered.contains("Error Domain") || rendered.contains("Content ID not found") || rendered.contains("no such table"), "An error message must not count as book text")
    }
}

final class FaithfulReaderVisualBaselineTests: FaithfulReaderUIBase {
    func testOriginalReaderLibrarySearchAnnotationsAndInspectorScreenshots() {
        for scenario in ["catalog", "reader", "readerTOC", "search", "annotationsList", "studyCommentaries"] {
            launchReader(enabled: false, scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if ["reader", "readerTOC", "studyCommentaries"].contains(scenario) { assertReaderHasText() }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("baseline-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        }
    }
}

final class FaithfulReaderUIAcceptanceTests: FaithfulReaderUIBase {
    func testCandidateUnchangedScreensAndTrimmedOriginalInspector() {
        for scenario in ["search", "annotationsList", "studyCommentaries"] {
            launchReader(scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if scenario == "studyCommentaries" { assertReaderHasText() }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("candidate-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
        }
    }

    func testSourceToolbarPaletteSidebarAndOverview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        capture("candidate-reader-landscape")
        let tocDot = app.buttons["reader-sidebar-page-1"]
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !tocDot.exists { tap(app.buttons["reader-host-sidebar-toggle"]) }
        for _ in 0..<20 {
            tap(tocDot)
            XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
            tap(libraryDot)
            XCTAssertTrue(app.descendants(matching: .any)["library-column"].exists)
        }
        let pager = app.descendants(matching: .any)["reader-sidebar-pager"]
        for _ in 0..<20 {
            let wasContents = tocDot.isSelected
            pager.swipeLeft()
            if tocDot.isSelected == wasContents { pager.swipeRight() }
            XCTAssertNotEqual(tocDot.isSelected, wasContents, "A sidebar swipe must change pages without changing the reader")
        }
        capture("candidate-library-sidebar")
        tap(tocDot)
        capture("candidate-toc-sidebar")
        tap(libraryDot)
        let field = app.textFields["reader-library-search-field"]
        tap(field)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let paletteField = palette.textFields.firstMatch
        XCTAssertTrue(paletteField.waitForExistence(timeout: 10))
        paletteField.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Actual canonical-library books must appear in original CommandPalette")
        capture("candidate-command-palette-keyboard")
        tap(result)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
        capture("candidate-all-tabs-public-fallback")
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        capture("candidate-profile-management")
    }

    func testTwentyGlobalTabRoundTripsKeepOriginalReaderAndBottomBar() {
        launchReader()
        assertReaderHasText()
        for _ in 0..<20 {
            tap(findTabButton(hebrew: "היסטוריה", english: "History"))
            tap(findTabButton(hebrew: "ספר", english: "Library"))
            assertReaderHasText()
            XCTAssertTrue(app.buttons["reader-more-menu"].exists, "Original bottom toolbar must remain present")
        }
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertReaderHasText()
            capture("candidate-reader-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
    }

    func testNewEmptyGroupAndRelaunchPersistence() {
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("קבוצת בדיקה")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        capture("candidate-empty-group")
        tap(app.buttons["סיום"])
        app.terminate()
        launchReader(scenario: "catalog")
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Empty selection must survive app relaunch without importing old tabs again")
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
    }

    func testThreeProfilesWithThreeGroupsThroughNativeManagement() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        for name in ["לימוד א", "לימוד ב"] {
            tap(app.buttons["פרופיל לימוד חדש"])
            let field = app.textFields["שם הפרופיל"]
            tap(field)
            field.typeText(name)
            tap(app.buttons["שמירה"])
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10))
        }
        tap(app.buttons["סיום"])
        for profileName in ["אישי", "לימוד א", "לימוד ב"] {
            tap(app.buttons["study-profile-menu"])
            tap(app.buttons[profileName])
            tap(app.buttons["כל הכרטיסיות"])
            for suffix in ["א", "ב"] {
                tap(app.buttons["קבוצות כרטיסיות"])
                tap(app.buttons["קבוצה ריקה"])
                let alert = app.alerts["שם קבוצת הכרטיסיות"]
                XCTAssertTrue(alert.waitForExistence(timeout: 10))
                alert.textFields.firstMatch.typeText("\(profileName) \(suffix)")
                tap(alert.buttons["שמירה"])
                XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
            }
            let selector = app.segmentedControls["study-group-selector"]
            XCTAssertTrue(selector.waitForExistence(timeout: 15), "The original public-safe segmented selector must render in a regular iPad window")
            XCTAssertEqual(selector.buttons.count, 3)
            capture("candidate-profile-groups-\(profileName)")
            tap(app.buttons["סיום"])
        }
    }
}
