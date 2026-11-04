import XCTest

/// Runs the supplied prototype in its own app, never demo code in Maktabah.
final class SafariPrototypeReferenceTests: XCTestCase {
    func testOriginalCompactAndExpandedToolbarOracle() {
        continueAfterFailure = false
        let prototype = XCUIApplication(bundleIdentifier: "com.example.safaritoolbarsearch")
        prototype.launchArguments = ["-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        prototype.launch()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let field = prototype.textFields["חיפוש או הזנת כתובת"]
            XCTAssertTrue(field.waitForExistence(timeout: 30))
            let compact = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            compact.name = "prototype-compact-\(orientation.isLandscape ? "landscape" : "portrait")"
            compact.lifetime = .keepAlways
            add(compact)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        prototype.textFields["חיפוש או הזנת כתובת"].tap()
        let result = prototype.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15), "The original CommandPalette must actually expand")
        let expanded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        expanded.name = "prototype-expanded-command-palette"
        expanded.lifetime = .keepAlways
        add(expanded)
        prototype.terminate()
    }
}

/// Black-box tests use the actual production-default flags and original views.
/// A unique sidecar namespace isolates tests without changing canonical sessions/data.
class FaithfulReaderUIBase: MaktabahUITestBase {
    let workspaceNamespace = UUID().uuidString
    private var viewportURL: URL?
    struct Viewport: Decodable { let source: Int; let offset: Double; let object: Int }
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria", language: String = "he", background: Int = 0, recordViewport: Bool = false) {
        // The baseline's optional DEBUG file exporter asserts on write errors
        // during rotation. Enable it only for the source/object stability case
        // that consumes it; visual/rotation cases exercise ordinary rendering.
        let prefix = (recordViewport ? ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"] : nil).map {
            URL(fileURLWithPath: $0).appendingPathComponent("faithful-\(scenario)-" + UUID().uuidString).path
        }
        viewportURL = prefix.map { URL(fileURLWithPath: $0 + ".viewport.json") }
        launchWithTier(.smoke, scenario: scenario, backend: backend, extraArgs: [
            "-ChavrusaTextFaithfulReaderUIEnabled", enabled ? "YES" : "NO",
            "-studyWorkspaceTestingNamespace", workspaceNamespace,
            "-textViewBackgroundColorLight", String(background)
        ], language: language, locale: language == "he" ? "he_IL" : "en_US",
        extraEnvironment: prefix.map { ["MAKTABAH_SMOKE_READY_FILE": $0] } ?? [:])
        dismissAlertsIfNeeded()
    }
    func viewport() throws -> Viewport {
        let url = try XCTUnwrap(viewportURL, "The matrix must supply the original renderer's existing DEBUG report directory")
        let exists = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: url.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [exists], timeout: 15), .completed)
        return try JSONDecoder().decode(Viewport.self, from: Data(contentsOf: url))
    }
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 30), file: file, line: line)
        XCTAssertTrue(element.frame.intersects(app.frame), "Control must be inside the actual app viewport", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    func capture(_ name: String) {
        // Capture the display rather than XCTest's app-rectangle crop: the
        // iPadOS 27 landscape app crop can retain portrait dimensions and clip
        // the trailing toolbar. Preserve the complete system/window chrome.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
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
    func testOriginalReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(enabled: false, scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("baseline-reader-theme-\(name)")
        }
    }

    func testOriginalReaderLibrarySearchAnnotationsAndInspectorScreenshots() {
        for scenario in ["catalog", "reader", "readerDetail", "readerTOC", "search", "annotationsList", "studyCommentaries"] {
            launchReader(enabled: false, scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if ["reader", "readerDetail", "readerTOC", "studyCommentaries"].contains(scenario) { assertReaderHasText() }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("baseline-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        }
        launchReader(enabled: false, scenario: "readerDetail", language: "en")
        assertReaderHasText()
        capture("baseline-reader-detail-en")
    }
}

final class FaithfulReaderIPhoneTests: FaithfulReaderUIBase {
    func testIPhoneKeepsOriginalReaderWithEitherIPadFeatureSetting() {
        XCUIDevice.shared.orientation = .portrait
        for enabled in [false, true] {
            launchReader(enabled: enabled)
            assertReaderHasText()
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
            XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
            XCTAssertTrue(app.buttons["reader-more-menu"].exists)
            capture("iphone-original-reader-ipad-flag-\(enabled)")
        }
    }
}

/// Selected separately after CoreSimulator confirms the largest text setting.
final class FaithfulReaderLargeTextTests: FaithfulReaderUIBase {
    func testOriginalReaderAndPublicGroupSelectorRemainUsableAtLargeTextSize() {
        let baseline = ProcessInfo.processInfo.environment["FAITHFUL_BASELINE"] == "true"
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: !baseline)
        assertReaderHasText()
        capture(baseline ? "baseline-large-text-reader" : "candidate-large-text-reader")
        if baseline {
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        } else {
            tap(app.buttons["כל הכרטיסיות"])
            XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
            // The original safe AdaptiveTabContent uses a native menu for
            // accessibility text sizes. It must still expose real membership.
            tap(app.buttons["study-group-selector"])
            XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 10))
            capture("candidate-large-text-group-menu")
        }
    }
}

final class FaithfulReaderUIAcceptanceTests: FaithfulReaderUIBase {
    func testNewManagementScreensExposeMeaningfulAccessibilityDescriptions() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
    }

    func testCandidateReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("candidate-reader-theme-\(name)")
        }
    }

    func testEnglishReaderAndOriginalPaletteInLeftToRightLayout() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", language: "en")
        assertReaderHasText()
        capture("candidate-reader-detail-en")
        tap(app.textFields["reader-library-search-field"])
        XCTAssertTrue(app.descendants(matching: .any)["reader-library-command-palette"].waitForExistence(timeout: 15))
        capture("candidate-command-palette-en")
    }

    func testCandidateUnchangedScreensAndTrimmedOriginalInspector() {
        for scenario in ["search", "annotationsList", "studyCommentaries"] {
            launchReader(scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if scenario == "studyCommentaries" {
                assertReaderHasText()
                XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-panel"].waitForExistence(timeout: 30), "The original Inspector must actually be presented")
                XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].waitForExistence(timeout: 15), "Original study-tool actions must remain available")
                XCTAssertFalse(app.staticTexts["כלי לימוד"].exists, "The redundant visual study-tools heading must be removed")
                XCTAssertFalse(app.staticTexts["קטע נבחר"].exists, "The redundant visual selected-segment heading must be removed")
            }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("candidate-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
        }
    }

    func testSourceToolbarPaletteSidebarAndOverview() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        capture("candidate-reader-landscape")
        let tocDot = app.buttons["reader-sidebar-page-1"]
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !tocDot.exists || !tocDot.frame.intersects(app.frame) || tocDot.frame.isEmpty {
            tap(app.buttons["reader-host-sidebar-toggle"])
        }
        let originalReaderWidth = app.textViews["reader-text"].frame.width
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalViewport = try viewport()
        for _ in 0..<20 {
            tap(tocDot)
            XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
            tap(libraryDot)
            XCTAssertTrue(app.descendants(matching: .any)["library-column"].exists)
            XCTAssertEqual(app.textViews["reader-text"].frame.width, originalReaderWidth, accuracy: 1, "Sidebar page changes must preserve reader width")
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator, "Sidebar page changes must not navigate the book")
            let actual = try viewport()
            XCTAssertEqual(actual.object, originalViewport.object, "The original TextKit view must survive sidebar page changes")
            XCTAssertEqual(actual.source, originalViewport.source, "The first visible source character must remain anchored")
            XCTAssertEqual(actual.offset, originalViewport.offset, accuracy: 1, "Sidebar page changes must not shift the book viewport")
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
        XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.textViews["reader-text"].exists, "The empty sidecar group must suppress stale legacy-session resurrection")
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Empty selection must survive app relaunch without importing old tabs again")
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
    }

    func testHistoryRemainsGlobalAndIsAbsentFromBookSearch() {
        let query = "בדיקת היסטוריה " + UUID().uuidString
        launchReader(scenario: "search")
        let globalInput = app.textFields.firstMatch
        tap(globalInput)
        globalInput.typeText(query + "\n")
        tap(globalInput)
        let historyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 20), "A submitted global query must appear in the original global history")
        capture("candidate-global-search-history")
        app.terminate()
        launchReader()
        assertReaderHasText()
        let bottomToolbar = app.toolbars.containing(.button, identifier: "reader-more-menu").firstMatch
        let bookSearch = bottomToolbar.buttons.matching(NSPredicate(format: "label == 'חיפוש' OR label == 'Search'")).firstMatch
        tap(bookSearch)
        let bookInput = app.searchFields.firstMatch
        tap(bookInput)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists,
                       "The same genuine history query must not be offered inside book-local search")
        capture("candidate-book-search-without-global-history")
    }

    func testSameBookRetainsIndependentLocationsAcrossGroupsAndRelaunch() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let locator = app.staticTexts["reader-current-locator"]
        let initial = locator.label
        XCTAssertFalse(initial.isEmpty)
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("מיקום שני")
        tap(alert.buttons["שמירה"])
        let selector = app.segmentedControls["study-group-selector"]
        XCTAssertTrue(selector.buttons["מיקום שני"].waitForExistence(timeout: 15))
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(locator.label, initial)
        let next = app.buttons.matching(NSPredicate(format: "label == 'העמוד הבא' OR label == 'Next Page'")).firstMatch
        XCTAssertTrue(next.isEnabled, "The genuine fixture book must have another navigation unit")
        tap(next)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initial), object: locator)], timeout: 30), .completed)
        let second = locator.label
        XCTAssertFalse(second.isEmpty)
        for _ in 0..<20 {
            for (name, expected) in [("כל הכרטיסיות", initial), ("מיקום שני", second)] {
                tap(app.buttons["כל הכרטיסיות"])
                tap(selector.buttons[name])
                tap(app.buttons["סיום"])
                assertReaderHasText()
                XCTAssertEqual(locator.label, expected, "Each group must restore its own actual canonical locator")
            }
        }
        capture("candidate-independent-group-locations")
        app.terminate()
        launchReader(scenario: "catalog")
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, second, "The selected group's actual locator must survive cold relaunch")
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

/// Run only against a Release binary over the full native production install.
/// No smoke scenario, bootstrap bypass, feature override or test namespace.
final class FaithfulProductionReleaseTests: FaithfulReaderUIBase {
    func testRealProductionLibraryReaderAndGroupRestore() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria")
        dismissAlertsIfNeeded()
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 30))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        input.typeText("ברכות")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ברכות")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 60), "Full production catalog must supply an actual book")
        capture("release-production-library-palette")
        tap(book)
        assertReaderHasText()
        for _ in 0..<20 {
            tap(findTabButton(hebrew: "היסטוריה", english: "History"))
            tap(findTabButton(hebrew: "ספר", english: "Library"))
            assertReaderHasText()
            XCTAssertTrue(app.buttons["reader-more-menu"].exists)
        }
        capture("release-production-reader")
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("בדיקת Release")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        tap(app.buttons["סיום"])
        app.terminate()
        launchWithTier(.production, backend: "otzaria")
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        XCTAssertFalse(app.textViews["reader-text"].exists)
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 30))
        capture("release-production-empty-group-restored")
    }
}
