//
//  MaktabahUITestBase.swift
//  Maktabah-iOSUITests
//
//  Shared test base for iPad / iOS acceptance tests.
//

import XCTest

public enum TestTier: String, Sendable {
    case smoke = "smoke"         // Tier S: fast smoke fixture
    case realUI = "realUI"       // Tier R: normal app bootstrap, no smoke bypass
    case production = "production" // Tier P: full production Otzaria data profile
}

public struct TestRenderedHighlightSnapshot: Codable, Sendable {
    public let searchHighlightCount: Int
    public let annotationHighlightCount: Int
    public let segmentSelectionCount: Int
    public let totalHighlights: Int
    public let locator: String?
    public let renderGeneration: Int

    public static func fromJSON(_ jsonString: String) -> TestRenderedHighlightSnapshot? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TestRenderedHighlightSnapshot.self, from: data)
    }
}

class MaktabahUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.davidpovarsky.chavrusatext")

        addUIInterruptionMonitor(withDescription: "Dismiss Alerts") { alert in
            let button = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'אישור' OR label CONTAINS[c] 'OK' OR label CONTAINS[c] 'Allow'")).firstMatch
            if button.exists {
                button.tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @discardableResult
    func launchWithTier(
        _ tier: TestTier,
        scenario: String? = nil,
        backend: String = "sefaria",
        extraArgs: [String] = [],
        language: String = "he",
        locale: String = "he_IL"
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        var args: [String] = []
        var env: [String: String] = [:]

        switch tier {
        case .smoke:
            args += [
                "-OtzariaDataProfile", "miniTest10",
                "-smokeBypassBootstrap"
            ]
            if let scenario {
                args += ["-smokeScenario", scenario]
            }
            args += ["-smokeBackend", backend]
            env["OTZARIA_DATA_PROFILE"] = "miniTest10"
            env["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] = "miniTest10"

        case .realUI:
            if let scenario {
                args += ["-smokeScenario", scenario]
            }
            args += [
                "-OtzariaDataProfile", "miniTest10"
            ]
            env["OTZARIA_DATA_PROFILE"] = "miniTest10"
            env["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] = "miniTest10"

        case .production:
            args += [
                "-OtzariaDataProfile", "production"
            ]
            env["OTZARIA_DATA_PROFILE"] = "production"
            env["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] = "production"
            if let sharedRoot = ProcessInfo.processInfo.environment["OTZARIA_SHARED_ROOT_OVERRIDE"] {
                env["OTZARIA_SHARED_ROOT_OVERRIDE"] = sharedRoot
                env["SIMCTL_CHILD_OTZARIA_SHARED_ROOT_OVERRIDE"] = sharedRoot
            }
            if let dbPath = ProcessInfo.processInfo.environment["OTZARIA_PRODUCTION_DB_PATH"] {
                env["OTZARIA_PRODUCTION_DB_PATH"] = dbPath
                env["SIMCTL_CHILD_OTZARIA_PRODUCTION_DB_PATH"] = dbPath
            }
        }

        args += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ] + extraArgs

        app.launchArguments = args
        for (k, v) in env {
            app.launchEnvironment[k] = v
        }
        app.launch()
        self.app = app
        return app
    }

    @discardableResult
    func launchWithScenario(
        _ scenario: String,
        backend: String = "sefaria",
        extraArgs: [String] = [],
        language: String = "he",
        locale: String = "he_IL"
    ) -> XCUIApplication {
        launchWithTier(
            .smoke,
            scenario: scenario,
            backend: backend,
            extraArgs: extraArgs,
            language: language,
            locale: locale
        )
    }

    func getRenderedHighlightSnapshot() -> TestRenderedHighlightSnapshot? {
        let diagnostics = app.otherElements["reader-rendered-highlight-diagnostics"]
        if diagnostics.waitForExistence(timeout: 6.0), let val = diagnostics.value as? String {
            return TestRenderedHighlightSnapshot.fromJSON(val)
        }
        let textView = app.textViews["reader-text"]
        if textView.waitForExistence(timeout: 6.0), let val = textView.value as? String {
            return TestRenderedHighlightSnapshot.fromJSON(val)
        }
        return nil
    }

    func dismissAlertsIfNeeded() {
        if app.alerts.count > 0 {
            let alert = app.alerts.firstMatch
            let okButton = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'אישור' OR label CONTAINS[c] 'OK' OR label CONTAINS[c] 'Allow'")).firstMatch
            if okButton.exists {
                okButton.tap()
            }
        }
    }

    func findTabButton(hebrew: String, english: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", hebrew, english)
        let candidates = app.buttons.matching(predicate)
        let count = candidates.count
        if count > 1 {
            for i in 0..<count {
                let candidate = candidates.element(boundBy: i)
                if candidate.exists && candidate.isHittable {
                    return candidate
                }
            }
        }
        return candidates.firstMatch
    }

    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 12.0,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Expected element to exist: \(element.description)", file: file, line: line)
        return exists
    }

    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
