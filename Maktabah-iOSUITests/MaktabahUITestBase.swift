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
        app = XCUIApplication()
        app.launchArguments = [
            "-OtzariaDataProfile", "miniTest10",
            "-smokeBypassBootstrap"
        ]
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
        app = XCUIApplication()
        app.launchArguments = [
            "-OtzariaDataProfile", "miniTest10",
            "-smokeBypassBootstrap",
            "-smokeScenario", scenario,
            "-smokeBackend", backend,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ] + extraArgs
        app.launch()
        return app
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
