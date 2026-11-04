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

    func exerciseNativeWindowResize(enabled: Bool) {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: enabled, scenario: "readerDetail")
        assertReaderHasText()
        let originalFrame = app.frame
        let originalLocator = app.staticTexts["reader-current-locator"].label
        capture(enabled ? "candidate-window-wide" : "baseline-window-wide")
        defer {
            let current = app.frame
            if abs(current.width - originalFrame.width) > 2 || abs(current.height - originalFrame.height) > 2 {
                let corner = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -12, dy: -12))
                let originalCorner = app.coordinate(withNormalizedOffset: .zero).withOffset(
                    CGVector(dx: originalFrame.maxX - current.minX - 12, dy: originalFrame.maxY - current.minY - 12))
                corner.press(forDuration: 0.5, thenDragTo: originalCorner)
                let restored = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
                    MainActor.assumeIsolated {
                        abs(app.frame.width - originalFrame.width) < 2 && abs(app.frame.height - originalFrame.height) < 2
                    }
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 30), .completed,
                               "Restore the actual window before other baseline/candidate cases")
            }
        }
        // Apple's iPad windowing gesture: drag the system bottom-right handle.
        // This must change the actual window, not an injected size class/frame.
        let handle = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -12, dy: -12))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
        handle.press(forDuration: 0.5, thenDragTo: destination)
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            MainActor.assumeIsolated { app.frame.width < originalFrame.width - 80 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 30), .completed,
                       "The native iPad window must actually resize; a simulated width is not acceptance")
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator,
                       "Window reflow must preserve the actual navigation unit")
        XCTAssertTrue(app.buttons["reader-more-menu"].exists, "The original bottom toolbar must survive narrow window reflow")
        let geometry = XCTAttachment(string: "wide=\(originalFrame)\nnarrow=\(app.frame)")
        geometry.name = enabled ? "candidate-native-window-geometry" : "baseline-native-window-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        capture(enabled ? "candidate-window-narrow" : "baseline-window-narrow")
        if enabled {
            tap(app.textFields["reader-library-search-field"])
            let palette = app.descendants(matching: .any)["reader-library-command-palette"]
            XCTAssertTrue(palette.waitForExistence(timeout: 15))
            capture("candidate-window-narrow-palette")
            palette.textFields.firstMatch.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
            XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed)
        }
    }

    func selectStudyGroup(named name: String) {
        let selector = app.segmentedControls["study-group-selector"]
        if selector.exists {
            tap(selector.buttons[name])
        } else {
            // The source's public AdaptiveTabContent can choose its native
            // Menu in a compact sheet/window or accessibility text size.
            tap(app.buttons["study-group-selector"])
            tap(app.buttons[name])
        }
    }
}

final class FaithfulReaderVisualBaselineTests: FaithfulReaderUIBase {
    func testOriginalWindowResizePreservesReader() {
        exerciseNativeWindowResize(enabled: false)
    }

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
    func testActualSidecarWriteFailureRollsBackVisibleGroupAndRecovers() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        let documents = try XCTUnwrap(ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"])
        let container = URL(fileURLWithPath: documents).deletingLastPathComponent()
        let sidecar = container.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/\(workspaceNamespace).json")
        let saved = sidecar.appendingPathExtension("ui-failure-original")
        let originalBytes = try Data(contentsOf: sidecar)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
        // Block only this UUID-scoped test sidecar's atomic destination. The
        // canonical session, corpus, notes and every other sidecar stay intact.
        try FileManager.default.moveItem(at: sidecar, to: saved)
        var blocked = false
        var savedNeedsRestore = true
        defer {
            if savedNeedsRestore {
                if blocked { XCTAssertNoThrow(try FileManager.default.removeItem(at: sidecar)) }
                XCTAssertNoThrow(try FileManager.default.moveItem(at: saved, to: sidecar))
            }
        }
        try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: false)
        blocked = true
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["קבוצה ריקה"])
        let prompt = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.textFields.firstMatch.typeText("קבוצה שאסור לשמור")
        tap(prompt.buttons["שמירה"])
        let error = app.alerts["לא ניתן לשנות את סביבת הלימוד"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "The actual atomic-write error must be surfaced")
        capture("candidate-actual-sidecar-write-failure")
        tap(error.buttons["אישור"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15), "Failure must retain the original group's real document")
        XCTAssertEqual(try Data(contentsOf: saved), originalBytes, "The pre-failure bytes must remain intact")
        try FileManager.default.removeItem(at: sidecar)
        blocked = false
        try FileManager.default.moveItem(at: saved, to: sidecar)
        savedNeedsRestore = false
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        // Reopening synchronizes through the same real persistence path again.
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["לא ניתן לשנות את סביבת הלימוד"].exists)
        XCTAssertNoThrow(try Data(contentsOf: sidecar))
        capture("candidate-sidecar-write-recovery")
    }

    func testFeatureOffCreatesNoSidecarAndPreservesAnExistingWorkspace() throws {
        let documents = try XCTUnwrap(ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"])
        let container = URL(fileURLWithPath: documents).deletingLastPathComponent()
        let sidecar = container.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/\(workspaceNamespace).json")
        launchReader(enabled: false)
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        app.terminate()
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path), "Disabled startup/shutdown must not create workspace state")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.appendingPathExtension("bak").path))
        launchReader()
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["chavrusa-reader-host"].waitForExistence(timeout: 30))
        let created = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: sidecar.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 15), .completed)
        app.terminate()
        let enabledBytes = try Data(contentsOf: sidecar)
        launchReader(enabled: false)
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
        capture("candidate-disabled-original-reader")
        app.terminate()
        XCTAssertEqual(try Data(contentsOf: sidecar), enabledBytes,
                       "Disabled startup/shutdown must leave an existing workspace byte-identical")
    }

    func testPointerHoverClickAndHardwareKeyboardDismissal() {
        XCTAssertTrue(XCUIDevice.shared.supportsPointerInteraction,
                      "The required iPad Simulator must support real pointer events")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let field = app.textFields["reader-library-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        let fieldPoint = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldPoint.hover()
        capture("candidate-pointer-over-compact-search")
        fieldPoint.click()
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        input.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
        XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed,
                       "The original palette's Escape handler must dismiss through keyboard focus")
        XCTAssertEqual(field.value as? String, "בראשית", "Collapse must retain the canonical library query")
        fieldPoint.click()
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let resultPoint = result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        resultPoint.hover()
        capture("candidate-pointer-over-library-result")
        resultPoint.click()
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
    }

    func testGroupCopyMoveRenameAndDeleteThroughRealMenus() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let bookTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["קבוצה ריקה"])
        let nameAlert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        nameAlert.textFields.firstMatch.typeText("יעד העברה")
        tap(nameAlert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        let cardActions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "פעולות בכרטיסייה ")).firstMatch
        tap(cardActions)
        tap(app.buttons["העתק אל יעד העברה"])
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(app.staticTexts[bookTitle].waitForExistence(timeout: 15), "Copy must create a real document card in its destination")
        tap(app.buttons["סגור \(bookTitle)"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertTrue(app.staticTexts[bookTitle].waitForExistence(timeout: 15), "Closing the copied document must preserve its source")
        tap(cardActions)
        tap(app.buttons["העבר אל יעד העברה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Move must remove the source card")
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(app.staticTexts[bookTitle].waitForExistence(timeout: 15))
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["שינוי שם הקבוצה"])
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        let nameField = nameAlert.textFields.firstMatch
        nameField.tap()
        nameField.press(forDuration: 1)
        let selectAll = app.menuItems.matching(NSPredicate(format: "label == 'בחר הכול' OR label == 'Select All'")).firstMatch
        if selectAll.exists { selectAll.tap() }
        else {
            let selectAllButton = app.buttons.matching(NSPredicate(format: "label == 'בחר הכול' OR label == 'Select All'")).firstMatch
            tap(selectAllButton)
        }
        nameField.typeText("יעד ששמו עודכן")
        XCTAssertEqual(nameField.value as? String, "יעד ששמו עודכן")
        tap(nameAlert.buttons["שמירה"])
        selectStudyGroup(named: "יעד ששמו עודכן")
        XCTAssertTrue(app.staticTexts[bookTitle].waitForExistence(timeout: 15), "Rename must preserve membership")
        capture("candidate-group-move-copy-rename")
        tap(app.buttons["קבוצות כרטיסיות"])
        tap(app.buttons["מחיקת קבוצה"])
        // The second tap is the native destructive confirmation, not the Menu.
        tap(app.buttons["מחיקת קבוצה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertFalse(app.staticTexts[bookTitle].exists)
        capture("candidate-deleted-group-retains-replacement")
    }

    func testSystemReduceMotionKeepsOriginalPaletteUsable() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        let accessibility = settings.staticTexts["Accessibility"].firstMatch
        for _ in 0..<6 {
            if accessibility.exists && accessibility.isHittable { break }
            settings.swipeUp()
        }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 15))
        accessibility.tap()
        let motion = settings.staticTexts["Motion"].firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 15))
        motion.tap()
        let toggle = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        let wasEnabled = (toggle.value as? String) == "1"
        if !wasEnabled { toggle.tap() }
        defer {
            settings.activate()
            if !wasEnabled && (toggle.value as? String) == "1" { toggle.tap() }
            settings.terminate()
        }
        XCTAssertEqual(toggle.value as? String, "1", "The actual system preference must be enabled")
        let reduced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { UIAccessibility.isReduceMotionEnabled }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reduced], timeout: 15), .completed,
                       "The native accessibility setting must actually reach this Simulator")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        capture("candidate-system-reduce-motion-palette")
        tap(book)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        XCTAssertTrue(app.textFields["reader-library-search-field"].exists)
    }

    func testWindowResizePreservesOriginalReaderAndSearch() {
        exerciseNativeWindowResize(enabled: true)
    }

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
        tap(app.buttons["פרופיל לימוד חדש"])
        XCTAssertTrue(app.textFields["שם הפרופיל"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["ביטול"])
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

    func testSidebarPreservesOriginalTextKitViewport() throws {
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
    }

    func testSourceToolbarPaletteAndOverview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        let field = app.textFields["reader-library-search-field"]
        tap(field)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let paletteField = palette.textFields.firstMatch
        XCTAssertTrue(paletteField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15), "Capture the genuine full software keyboard, not a keyboard-free preview")
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
            for (hebrew, english) in [("היסטוריה", "History"), ("חיפוש", "Search"), ("מוסרים", "Narrators")] {
                tap(findTabButton(hebrew: hebrew, english: english))
                tap(findTabButton(hebrew: "ספר", english: "Library"))
                assertReaderHasText()
                XCTAssertTrue(app.buttons["reader-more-menu"].exists, "Original bottom toolbar must remain present after every global-tab round trip")
            }
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
        let count = palette.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ commands?$")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 30), "The original palette must expose its genuine command membership")
        let commandCount = Int(count.label.split(separator: " ").first.map(String.init) ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(commandCount, 100, "The production UI must exercise at least 100 real library results")
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
