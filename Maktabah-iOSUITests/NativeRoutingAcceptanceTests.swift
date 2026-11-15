import XCTest

/// Actual system URL entry + existing UI. These require the manager-applied
/// native registration packet. No smoke bypass or synthetic scene receipt.
final class NativeRoutingAcceptanceTests: MaktabahUITestBase {
    @MainActor private func configure(_ backend: String) {
        app.launchArguments = ["-OtzariaDataProfile", "miniTest10", "-preferredBackend", backend,
            "-ChavrusaTextFaithfulReaderUIEnabled", "YES", "-studyWorkspaceTestingNamespace", UUID().uuidString,
            "-lastSelectedTab", "0", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["OTZARIA_DATA_PROFILE"] = "miniTest10"
    }
    private func historyURL(_ backend: String, request: UUID = UUID()) throws -> URL {
        let bytes = try JSONSerialization.data(withJSONObject: ["version": 1, "requestId": request.uuidString,
            "destination": "native.history", "backend": backend, "presentation": "currentTab"], options: [.sortedKeys])
        let token = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v1/native.history?route=" + token))
    }
    @MainActor private func capture(_ name: String) {
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = name + "-screen"; image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func warm(_ backend: String) throws {
        configure(backend); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40), "Real library/scene did not mount")
        capture("native-route-before-" + backend)
        let request = UUID()
        let invocation = XCTAttachment(string: "systemURL request=\(request) backend=\(backend)")
        invocation.name = "native-route-invocation"; invocation.lifetime = .keepAlways; add(invocation)
        app.open(try historyURL(backend, request: request))
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 20), "Exact History surface was not displayed")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        capture("native-route-after-" + backend)
    }
    @MainActor func testWarmHistoryURLUsesOtzariaNativeScene() throws { try warm("otzaria") }
    @MainActor func testWarmHistoryURLUsesLegacyNativeScene() throws { try warm("sefaria") }
    @MainActor func testWarmHistoryURLUsesEmbeddedNativeScene() throws { try warm("sefariaEmbedded") }
    @MainActor func testColdHistoryURLWaitsForActualSceneMount() throws {
        configure("otzaria"); app.launch(); app.terminate()
        capture("native-cold-before")
        app.open(try historyURL("otzaria"))
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 40), "Cold URL did not await the real mounted native scene")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        capture("native-cold-after")
    }
    @MainActor func testUnknownURLVersionShowsErrorWithoutNavigatingToHistory() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        capture("native-invalid-before")
        let valid = try historyURL("otzaria")
        app.open(try XCTUnwrap(URL(string: valid.absoluteString.replacingOccurrences(of: "/v1/", with: "/v2/"))))
        XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["History"].exists)
        capture("native-invalid-after")
    }
}
