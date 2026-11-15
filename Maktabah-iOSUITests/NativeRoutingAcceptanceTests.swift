import XCTest

/// Actual system URL entry + existing UI. These require the manager-applied
/// native registration packet. No smoke bypass or synthetic scene receipt.
final class NativeRoutingAcceptanceTests: FaithfulReaderUIBase {
    @MainActor private func configure(_ backend: String) {
        app.launchArguments = ["-OtzariaDataProfile", "miniTest10", "-preferredBackend", backend,
            "-ChavrusaTextFaithfulReaderUIEnabled", "YES", "-studyWorkspaceTestingNamespace", workspaceNamespace,
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
    private func invocation(_ request: UUID, backend: String, mode: String) throws {
        let data = try JSONSerialization.data(withJSONObject: ["request": request.uuidString, "backend": backend,
            "mode": mode, "workspaceNamespace": workspaceNamespace, "destination": "native.history"], options: [.sortedKeys])
        let value = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        value.name = "native-route-invocation-" + request.uuidString; value.lifetime = .keepAlways; add(value)
    }
    private nonisolated static func receiptFields(_ line: String, request: UUID, backend: String) -> [String: String]? {
        let parts = line.split(separator: " ", maxSplits: 2)
        guard parts.count == 3, parts[1] == "[NativeNavigationReceipt]" else { return nil }
        var fields: [String: String] = [:]
        for item in parts[2].split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, fields[String(pair[0])] == nil else { return nil }
            fields[String(pair[0])] = String(pair[1])
        }
        guard Set(fields.keys) == ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"],
              fields["request"].flatMap(UUID.init(uuidString:)) == request, fields["backend"] == backend,
              fields["destination"] == "native.history", fields["presentation"] == "currentTab",
              fields["generation"].flatMap(UInt64.init) != nil, fields["scene"]?.isEmpty == false,
              let revisions = fields["revision"]?.components(separatedBy: "->"), revisions.count == 2,
              let before = UInt64(revisions[0]), let after = UInt64(revisions[1]), after > before else { return nil }
        if backend == "sefariaEmbedded" { guard fields["epoch"].flatMap(UInt64.init) != nil else { return nil } }
        else { guard fields["epoch"] == "none" else { return nil } }
        return fields
    }
    @MainActor private func requireNativeReceipt(_ request: UUID, backend: String) throws {
        // Reuse the existing exact-namespace sidecar oracle to find the CURRENT
        // XCTest-installed app container, never the stale pre-install UUID.
        let sidecar = try workspaceSidecarURL().standardizedFileURL, parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let actualContainer = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(actualContainer).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        let written = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let text = try? String(contentsOf: log, encoding: .utf8) else { return false }
            return text.split(separator: "\n").filter { Self.receiptFields(String($0), request: request, backend: backend) != nil }.count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: 15), .completed, "Actual canonical native receipt did not reach the app's real reader log")
        let bytes = try Data(contentsOf: log), text = try XCTUnwrap(String(data: bytes, encoding: .utf8))
        let lines = text.split(separator: "\n").filter { Self.receiptFields(String($0), request: request, backend: backend) != nil }
        XCTAssertEqual(lines.count, 1)
        let fields = try XCTUnwrap(Self.receiptFields(String(try XCTUnwrap(lines.first)), request: request, backend: backend))
        let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: sidecar)) as? [String: Any])
        let scenes = try XCTUnwrap(snapshot["scenes"] as? [String: Any])
        XCTAssertNotNil(scenes[try XCTUnwrap(fields["scene"])], "Receipt must name a real scene in this test's actual workspace")
        let raw = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.plain-text")
        raw.name = "actual-native-reader-log-" + request.uuidString; raw.lifetime = .keepAlways; add(raw)
        let receipt = XCTAttachment(string: String(try XCTUnwrap(lines.first)))
        receipt.name = "actual-native-canonical-receipt-" + request.uuidString; receipt.lifetime = .keepAlways; add(receipt)
        try attachWorkspaceSnapshot("native-receipt-workspace-" + request.uuidString)
    }
    @MainActor private func warm(_ backend: String) throws {
        configure(backend); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40), "Real library/scene did not mount")
        XCTAssertFalse(app.navigationBars["History"].exists, "History must be absent before the URL entry")
        capture("native-route-before-" + backend)
        let request = UUID()
        try invocation(request, backend: backend, mode: "warm")
        app.open(try historyURL(backend, request: request))
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 20), "Exact History surface was not displayed")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireNativeReceipt(request, backend: backend)
        capture("native-route-after-" + backend)
    }
    @MainActor func testWarmHistoryURLUsesOtzariaNativeScene() throws { try warm("otzaria") }
    @MainActor func testWarmHistoryURLUsesLegacyNativeScene() throws { try warm("sefaria") }
    @MainActor func testWarmHistoryURLUsesEmbeddedNativeScene() throws { try warm("sefariaEmbedded") }
    @MainActor func testColdHistoryURLWaitsForActualSceneMount() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.navigationBars["History"].exists)
        capture("native-cold-before")
        app.terminate()
        let request = UUID(); try invocation(request, backend: "otzaria", mode: "cold")
        app.open(try historyURL("otzaria", request: request))
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 40), "Cold URL did not await the real mounted native scene")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireNativeReceipt(request, backend: "otzaria")
        capture("native-cold-after")
    }
    @MainActor func testUnknownURLVersionShowsErrorWithoutNavigatingToHistory() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCTAssertFalse(app.navigationBars["History"].exists)
        capture("native-invalid-before")
        let request = UUID(); try invocation(request, backend: "otzaria", mode: "invalid_version")
        let valid = try historyURL("otzaria", request: request)
        app.open(try XCTUnwrap(URL(string: valid.absoluteString.replacingOccurrences(of: "/v1/", with: "/v2/"))))
        XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.navigationBars["History"].exists)
        capture("native-invalid-after")
    }
}
