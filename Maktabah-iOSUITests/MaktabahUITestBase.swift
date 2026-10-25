//
//  MaktabahUITestBase.swift
//  Maktabah-iOSUITests
//
//  Shared test base for iPad / iOS acceptance tests.
//

import XCTest

class MaktabahUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        app.launchArguments = [
            "-OtzariaDataProfile", "miniTest10",
            "-smokeBypassBootstrap"
        ]
        app.launchEnvironment["OTZARIA_DATA_PROFILE"] = "miniTest10"
        app.launchEnvironment["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] = "miniTest10"

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
    func launchWithScenario(
        _ scenario: String,
        backend: String = "sefaria",
        extraArgs: [String] = [],
        language: String = "he",
        locale: String = "he_IL"
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        app.launchArguments = [
            "-OtzariaDataProfile", "miniTest10",
            "-smokeBypassBootstrap",
            "-smokeScenario", scenario,
            "-smokeBackend", backend,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ] + extraArgs
        app.launchEnvironment["OTZARIA_DATA_PROFILE"] = "miniTest10"
        app.launchEnvironment["SIMCTL_CHILD_OTZARIA_DATA_PROFILE"] = "miniTest10"
        app.launch()
        self.app = app
        return app
    }

    func dismissAlertsIfNeeded() {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 1.5) {
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
