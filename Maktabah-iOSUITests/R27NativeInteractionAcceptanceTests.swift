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
        // Reuse original measured resize/restore, palette typing/Escape and
        // Inspector open/close postconditions; no duplicate gesture harness.
        exerciseNativeWindowResize(enabled: true)
        _ = try assertTarget(backend: "otzaria")
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
