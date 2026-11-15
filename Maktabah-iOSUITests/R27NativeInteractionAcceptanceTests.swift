import XCTest

/// Real native app/fixtures with the existing black-box oracles. These cases
/// intentionally do not claim new RouteSpec, AppIntent or Hanlin integration.
class R27NativeUIBase: FaithfulReaderUIBase {
    override func launchReader(
        enabled: Bool = true,
        scenario: String = "reader",
        backend: String = "otzaria",
        language: String = "he",
        background: Int = 0,
        recordViewport: Bool = false,
        fontSize: Float? = nil
    ) {
        XCTAssertFalse(recordViewport, "This subset uses existing UI oracles, not an unconfigured viewport exporter")
        launchWithTier(
            .realUI,
            scenario: scenario,
            backend: backend,
            extraArgs: [
                "-preferredBackend", backend,
                "-smokeBackend", backend,
                "-ChavrusaTextFaithfulReaderUIEnabled", enabled ? "YES" : "NO",
                "-studyWorkspaceTestingNamespace", workspaceNamespace,
                "-textViewBackgroundColorLight", String(background)
            ] + (fontSize.map { ["-textViewFontSize", String($0)] } ?? []),
            language: language,
            locale: language == "he" ? "he_IL" : "en_US"
        )
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        dismissAlertsIfNeeded()
    }

    override func tearDownWithError() throws {
        // XCTest calls teardown after an assertion aborts a case. Retain the
        // actual native state on both success and failure before releasing app.
        if let app {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "r27-final-native-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "r27-final-native-screen"
            screen.lifetime = .keepAlways
            add(screen)
        }
        XCUIDevice.shared.orientation = .portrait
        try super.tearDownWithError()
    }

    @discardableResult
    func assertTarget(backend: String) throws -> String {
        assertReaderHasText() // Existing genuine TextKit/pixel/title oracle.
        let locator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(locator.waitForExistence(timeout: 15))
        let key = locator.label
        let parts = key.split(separator: "|", maxSplits: 2).map(String.init)
        XCTAssertEqual(parts.count, 3, "Require backend-qualified real reader identity")
        let work: String
        if backend == "otzaria" {
            work = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"],
                                "CI must derive the selected real book from the installed fixture, before UI execution")
            let title = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
            XCTAssertFalse(title.isEmpty)
            XCTAssertTrue(app.staticTexts["reader-header-title"].label.contains(title),
                          "Native title must identify the independently selected fixture book")
        } else {
            work = "Genesis" // Existing openSmokeBook scenario requests Genesis1:1.
        }
        XCTAssertTrue(work.hasPrefix(backend == "otzaria" ? "book:" : "Genesis"))
        XCTAssertEqual(parts.first, backend)
        XCTAssertEqual(parts.dropFirst().first, work)
        XCTAssertFalse(parts.last?.isEmpty ?? true)
        return key
    }

    func exerciseGenesis(backend: String) throws {
        launchReader(backend: backend)
        let initial = try assertTarget(backend: backend)
        let before = app.frame
        let application = app!
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { application.frame.width > application.frame.height }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 20), .completed,
                       "Rotation must change the actual native window, not merely return success")
        XCTAssertNotEqual(app.frame.size, before.size)
        XCTAssertEqual(try assertTarget(backend: backend), initial)
        capture("r27-\(backend)-native-genesis-landscape")
    }
}

@MainActor
private final class R27WindowCleanup {
    let restore: @MainActor () -> Void
    init(_ restore: @escaping @MainActor () -> Void) { self.restore = restore }
    func run() { restore() }
}

final class R27NativePadTests: R27NativeUIBase {
    func testNormalBootstrapOtzariaRotationPreservesExactLocator() throws {
        XCTAssertTrue(isPad, "Required iPad execution must not be silently skipped")
        XCUIDevice.shared.orientation = .portrait
        launchReader()
        let initial = try assertTarget(backend: "otzaria")
        capture("r27-otzaria-native-portrait")
        let application = app!
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { application.frame.width > application.frame.height }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 20), .completed)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initial)
        capture("r27-otzaria-native-landscape")
    }

    func testNormalBootstrapGlobalHistoryUsesActualSubmit() {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .portrait
        _ = exerciseGlobalHistorySubmission(enabled: true)
    }

    @MainActor
    func testNormalBootstrapNativeWindowResizePaletteAndInspector() throws {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail")
        let initialLocator = try assertTarget(backend: "otzaria")
        let initialText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        let window = app.windows.firstMatch
        let original = window.frame
        XCTAssertGreaterThan(original.width, original.height, "Require a real full-width landscape start")
        let cleanup = R27WindowCleanup { [self] in restoreNativeWindow(to: original.size) }
        addTeardownBlock { await cleanup.run() }

        // Same native resize gesture as the existing suite. Postconditions use
        // this actual window, not an assumed principal StaticText ancestor.
        window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -12, dy: -12))
            .press(forDuration: 0.5, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7)))
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { window.frame.width < original.width - 80 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 30), .completed,
                       "The native window must actually resize")
        recordWindowEvidence("r27-real-narrow-window")
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initialLocator)

        // These are the controls actually wired by Exact9401ViewerToolbar and
        // observed in run43681096257; ChavrusaReaderHost is not instantiated.
        let launcher = app.navigationBars.buttons["reader-command-palette-launcher"]
        let nativeBar = app.navigationBars.containing(.button, identifier: "reader-command-palette-launcher")
        XCTAssertEqual(nativeBar.count, 1, "Identify the actual wired native toolbar")
        XCTAssertTrue(nativeBar.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(launcher.frame))
        tapInWindow(launcher)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        tapInWindow(input)
        let title = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        input.typeText(title)
        XCTAssertEqual(input.value as? String, title)
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15), "Typing must filter a real fixture-book result, not only echo the query")
        XCTAssertTrue(result.isHittable)
        recordWindowEvidence("r27-real-narrow-palette-filtered")
        input.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        recordWindowEvidence("r27-after-synthesized-escape")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: palette
        )], timeout: 15), .completed)

        tapInWindow(app.buttons["reader-study-toggle"])
        let inspector = app.descendants(matching: .any)["torah-inspector-panel"]
        XCTAssertTrue(inspector.waitForExistence(timeout: 30))
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].exists)
        recordWindowEvidence("r27-real-narrow-inspector-open")
        tapInWindow(app.buttons["torah-inspector-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: inspector
        )], timeout: 15), .completed)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initialLocator)
        XCTAssertEqual(app.textViews["reader-text"].value as? String, initialText)
        restoreNativeWindow(to: original.size)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initialLocator)
    }

    @MainActor
    private func tapInWindow(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        XCTAssertTrue(element.isHittable)
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(element.frame),
                      "The actual action must be inside its current native window")
        element.tap()
    }

    @MainActor
    private func recordWindowEvidence(_ name: String) {
        let tree = XCTAttachment(string: "actualWindow=\(app.windows.firstMatch.frame)\n\(app.debugDescription)")
        tree.name = name + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name + "-screen"
        image.lifetime = .keepAlways
        add(image)
    }

    @MainActor
    private func restoreNativeWindow(to originalSize: CGSize) {
        let window = app.windows.firstMatch
        if abs(window.frame.width - originalSize.width) < 2 && abs(window.frame.height - originalSize.height) < 2 { return }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // This public accessibility identifier is present in the actual failed
        // restore's SpringBoard hierarchy. App-local (42,32) was not this control.
        let controls = springboard.buttons["window-controls:com.davidpovarsky.chavrusatext"]
        XCTAssertTrue(controls.waitForExistence(timeout: 10))
        XCTAssertTrue(controls.isHittable)
        controls.tap()
        let labels = ["Full Screen", "Enter Full Screen", "Zoom", "מסך מלא", "הצג במסך מלא"]
        let predicate = NSPredicate(format: "label IN %@", labels)
        let choices = [springboard.buttons, springboard.menuItems, app.buttons, app.menuItems]
            .map { $0.matching(predicate).firstMatch }
        let menu = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { choices.contains { $0.exists && $0.isHittable } }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [menu], timeout: 10), .completed,
                       "Native window controls must expose the real full-screen action")
        guard let action = choices.first(where: { $0.exists && $0.isHittable }) else {
            recordWindowEvidence("r27-native-fullscreen-action-missing")
            XCTFail("No actual full-screen action; do not leave a contaminated window for later cases")
            return
        }
        action.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                abs(window.frame.width - originalSize.width) < 2 && abs(window.frame.height - originalSize.height) < 2
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 30), .completed,
                       "Verify original native window size; successful tap return is insufficient")
        recordWindowEvidence("r27-native-fullscreen-restored")
    }

    func testNormalBootstrapLegacyGenesisAndRotation() throws {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .portrait
        try exerciseGenesis(backend: "sefaria")
    }

    func testNormalBootstrapEmbeddedGenesisAndRotation() throws {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .portrait
        try exerciseGenesis(backend: "sefariaEmbedded")
    }
}

final class R27NativePhoneTests: R27NativeUIBase {
    func testNormalBootstrapOtzariaBackgroundAndColdRestoration() throws {
        XCTAssertFalse(isPad, "Required conventional iPhone execution must not be silently skipped")
        XCUIDevice.shared.orientation = .portrait
        launchReader()
        let initial = try assertTarget(backend: "otzaria")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initial)
        capture("r27-phone-background-restored")

        // Remove the setup route before relaunch. Reopening the scenario would
        // hide a broken persisted restoration behind automatic test navigation.
        var arguments = app.launchArguments
        let scenario = try XCTUnwrap(arguments.firstIndex(of: "-smokeScenario"))
        XCTAssertLessThan(scenario + 1, arguments.count)
        arguments.removeSubrange(scenario...(scenario + 1))
        app.launchArguments = arguments
        app.terminate()
        app.launch()
        dismissAlertsIfNeeded()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), initial)
        capture("r27-phone-cold-restored-without-setup-route")
    }

    func testNormalBootstrapGlobalHistoryUsesActualSubmit() {
        XCTAssertFalse(isPad)
        XCUIDevice.shared.orientation = .portrait
        _ = exerciseGlobalHistorySubmission(enabled: true)
    }

    func testNormalBootstrapLegacyGenesisAndRotation() throws {
        XCTAssertFalse(isPad)
        XCUIDevice.shared.orientation = .portrait
        try exerciseGenesis(backend: "sefaria")
    }

    func testNormalBootstrapEmbeddedGenesisAndRotation() throws {
        XCTAssertFalse(isPad)
        XCUIDevice.shared.orientation = .portrait
        try exerciseGenesis(backend: "sefariaEmbedded")
    }
}
