import XCTest
import UIKit

/// Actual system URL entry + existing UI. These require the manager-applied
/// native registration packet. No smoke bypass or synthetic scene receipt.
class NativeRoutingAcceptanceTests: FaithfulReaderUIBase {
    private enum SystemURLConfirmationError: Error {
        case unexpectedOrAmbiguousDialog
        case missingOpenAction
        case dialogDidNotDismiss
    }

    private static let expectedSpringBoardOpenTitles: Set<String> = [
        "Open in \u{201C}ChavrusaText\u{201D}?",
        "Open in \"ChavrusaText\"?",
    ]

    // The original iOSHistoryView owns this localized navigation title
    // (Library.xcstrings/historyAndFavorites), including on the iPad History tab.
    @MainActor private var history: XCUIElement { app.navigationBars["History & Favorites"] }

    private func captureSystemDialogEvidence(_ name: String, springboard: XCUIApplication) {
        let appDescription = app?.debugDescription ?? "app=nil"
        let tree = XCTAttachment(string: "APP\n\(appDescription)\nSPRINGBOARD\n\(springboard.debugDescription)")
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = name + "-screen"; screen.lifetime = .keepAlways; add(screen)
    }

    private static func matchesExpectedSpringBoardOpenTitle(_ alert: XCUIElement) -> Bool {
        expectedSpringBoardOpenTitles.contains(alert.label)
            || expectedSpringBoardOpenTitles.contains { alert.staticTexts[$0].exists }
    }

    private func cleanupLeftoverSpringBoardOpenAlertsInTeardown() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let initialCount = springboard.alerts.count
        guard initialCount > 0 else { return }
        captureSystemDialogEvidence("native-route-teardown-springboard", springboard: springboard)
        var cancelledCount = 0
        for _ in 0..<8 {
            let alerts = springboard.alerts.allElementsBoundByIndex
            let beforeCount = alerts.count
            guard let alert = alerts.first, Self.matchesExpectedSpringBoardOpenTitle(alert) else { break }
            let cancelMatches = alert.buttons.matching(NSPredicate(format: "label == %@", "Cancel")).allElementsBoundByIndex
            guard cancelMatches.count == 1, let cancelButton = cancelMatches.first,
                  cancelButton.exists, cancelButton.isHittable else { break }
            cancelButton.tap()
            let reduced = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "count < %d", beforeCount),
                object: springboard.alerts
            )
            guard XCTWaiter.wait(for: [reduced], timeout: 5) == .completed else { break }
            cancelledCount += 1
            if springboard.alerts.count == 0 {
                let nextAppeared = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "count > 0"),
                    object: springboard.alerts
                )
                _ = XCTWaiter.wait(for: [nextAppeared], timeout: 0.5)
            }
        }
        let remainingCount = springboard.alerts.count
        XCTFail("Leftover SpringBoard alert(s) remained at teardown (initialCount=\(initialCount), cancelledChavrusaPrompts=\(cancelledCount), remainingCount=\(remainingCount))")
    }

    override func tearDownWithError() throws {
        // XCTest teardown is nonisolated. Retain its standard thread-safe
        // diagnostics directly, as the existing Search teardown does.
        if let app {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "native-route-final-hierarchy"; tree.lifetime = .keepAlways; add(tree)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "native-route-final-screen"; screen.lifetime = .keepAlways; add(screen)
        }
        cleanupLeftoverSpringBoardOpenAlertsInTeardown()
        try super.tearDownWithError()
    }
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
    @MainActor private func targetProcessIdentifier() throws -> String {
        let first = app.debugDescription.split(separator: "\n").first.map(String.init) ?? ""
        let marker = try XCTUnwrap(first.range(of: "pid: "))
        let value = String(first[marker.upperBound...].prefix(while: { $0.isNumber }))
        XCTAssertFalse(value.isEmpty, "Require the actual native target process identity")
        return value
    }
    @MainActor private func confirmSpringBoardOpenDialog(springboard: XCUIApplication) throws {
        // Allow SpringBoard's presentation transition to settle briefly before failing
        // closed on transient !isHittable, without approving unexpected or ambiguous alerts.
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let alerts = sb.alerts.allElementsBoundByIndex
                guard alerts.count == 1, let alert = alerts.first,
                      Self.matchesExpectedSpringBoardOpenTitle(alert) else {
                    return false
                }
                let openMatches = alert.buttons.matching(NSPredicate(format: "label == %@", "Open")).allElementsBoundByIndex
                guard openMatches.count == 1, let openButton = openMatches.first else {
                    return false
                }
                return openButton.exists && openButton.isHittable
            }
        }, object: nil)
        _ = XCTWaiter.wait(for: [settled], timeout: 2)

        let alerts = springboard.alerts.allElementsBoundByIndex
        guard alerts.count == 1, let alert = alerts.first else {
            captureSystemDialogEvidence("ambiguous-springboard-alerts", springboard: springboard)
            XCTFail("Expected exactly one SpringBoard Open-in confirmation alert, found \(alerts.count)")
            throw SystemURLConfirmationError.unexpectedOrAmbiguousDialog
        }
        let alertTitle = alert.label
        guard Self.matchesExpectedSpringBoardOpenTitle(alert) else {
            captureSystemDialogEvidence("unexpected-springboard-alert", springboard: springboard)
            XCTFail("Unexpected SpringBoard alert '\(alertTitle)' during system URL delivery")
            throw SystemURLConfirmationError.unexpectedOrAmbiguousDialog
        }
        let openMatches = alert.buttons.matching(NSPredicate(format: "label == %@", "Open")).allElementsBoundByIndex
        guard openMatches.count == 1, let openButton = openMatches.first,
              openButton.exists, openButton.isHittable else {
            captureSystemDialogEvidence("missing-springboard-open-button", springboard: springboard)
            XCTFail("Expected unique hittable 'Open' action on SpringBoard confirmation alert")
            throw SystemURLConfirmationError.missingOpenAction
        }
        openButton.tap()
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 0"),
            object: springboard.alerts
        )
        let dismissResult = XCTWaiter.wait(for: [dismissed], timeout: 10)
        if dismissResult != .completed {
            captureSystemDialogEvidence("springboard-open-alert-stuck", springboard: springboard)
            XCTFail("SpringBoard Open-in confirmation remained visible after tapping Open")
            throw SystemURLConfirmationError.dialogDidNotDismiss
        }
        let confirmed = XCTAttachment(string: "confirmedAlert=\(alertTitle) action=Open")
        confirmed.name = "actual-system-open-confirmation"; confirmed.lifetime = .keepAlways; add(confirmed)
    }
    @MainActor private func openInExistingProcess(_ url: URL) throws {
        // Xcode27.1's XCUIApplication.open actually launched a NEW target PID
        // on every call in43844345630. The background Runner's UIApplication
        // open was rejected in43863125434. Ask the owned host to run real
        // simctl openurl; its ACK proves transport only, never UI completion.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let originalPID = try targetProcessIdentifier()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.count > 0 {
            captureSystemDialogEvidence("preexisting-springboard-alert", springboard: springboard)
            XCTFail("Unexpected SpringBoard alert present before system URL delivery")
            throw SystemURLConfirmationError.unexpectedOrAmbiguousDialog
        }
        let hadHistoryBefore = history.exists
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_URL_TOKEN"])
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_URL_UDID"])
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let nonce = UUID().uuidString
        let prefix = parent.appendingPathComponent(container).appendingPathComponent("Documents/r27-url-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json")
        let ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        do {
            let payload = ["token": token, "nonce": nonce, "udid": udid, "url": url.absoluteString]
            try JSONSerialization.data(withJSONObject: payload).write(to: request, options: .atomic)
        } catch {
            XCTFail("Could not write owned system URL request")
            return
        }
        let delivered = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: ack.path) }, object: nil
        )], timeout: 20)
        XCTAssertEqual(delivered, .completed, "Owned system URL transport must acknowledge the exact request")
        guard delivered == .completed, let bytes = try? Data(contentsOf: ack),
              let response = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              Set(response.keys) == ["udid", "transport", "delivered", "nonce", "time"],
              String(decoding: bytes, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil else {
            XCTFail("System URL acknowledgement must have the exact credential-free schema")
            return
        }
        XCTAssertEqual(response["nonce"] as? String, nonce)
        XCTAssertEqual(response["udid"] as? String, udid)
        XCTAssertEqual(response["transport"] as? String, "simctl-system-openurl")
        XCTAssertEqual(response["delivered"] as? Bool, true)
        let transport = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        transport.name = "actual-system-url-transport-only"; transport.lifetime = .keepAlways; add(transport)
        let dialogOrDirectDelivery = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let targetApp = XCUIApplication(bundleIdentifier: "com.davidpovarsky.chavrusatext")
                return sb.alerts.count > 0
                    || targetApp.alerts["Unable to open link"].exists
                    || (!hadHistoryBefore && targetApp.navigationBars["History & Favorites"].exists)
            }
        }, object: nil)
        _ = XCTWaiter.wait(for: [dialogOrDirectDelivery], timeout: 10)
        if springboard.alerts.count > 0 {
            try confirmSpringBoardOpenDialog(springboard: springboard)
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        let actualPID = try targetProcessIdentifier()
        XCTAssertEqual(actualPID, originalPID, "A warm URL must not restart the target app")
        let proof = XCTAttachment(string: "beforePID=\(originalPID) afterPID=\(actualPID)")
        proof.name = "actual-warm-system-url-process-identity"; proof.lifetime = .keepAlways; add(proof)
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
        XCTAssertFalse(history.exists, "History must be absent before the URL entry")
        capture("native-route-before-" + backend)
        let request = UUID()
        try invocation(request, backend: backend, mode: "warm")
        try openInExistingProcess(historyURL(backend, request: request))
        XCTAssertTrue(history.waitForExistence(timeout: 20), "Exact History surface was not displayed")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireNativeReceipt(request, backend: backend)
        capture("native-route-after-" + backend)
    }
    @MainActor
    func testWarmHistoryURLUsesOtzariaNativeScene() throws { try warm("otzaria") }
    @MainActor
    func testWarmHistoryURLUsesLegacyNativeScene() throws { try warm("sefaria") }
    @MainActor
    func testWarmHistoryURLUsesEmbeddedNativeScene() throws { try warm("sefariaEmbedded") }
    @MainActor
    func testColdHistoryURLWaitsForActualSceneMount() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCTAssertFalse(history.exists)
        capture("native-cold-before")
        app.terminate()
        let request = UUID(); try invocation(request, backend: "otzaria", mode: "cold")
        app.open(try historyURL("otzaria", request: request))
        XCTAssertTrue(history.waitForExistence(timeout: 40), "Cold URL did not await the real mounted native scene")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireNativeReceipt(request, backend: "otzaria")
        capture("native-cold-after")
    }
    @MainActor
    func testUnknownURLVersionShowsErrorWithoutNavigatingToHistory() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCTAssertFalse(history.exists)
        capture("native-invalid-before")
        let request = UUID(); try invocation(request, backend: "otzaria", mode: "invalid_version")
        let valid = try historyURL("otzaria", request: request)
        try openInExistingProcess(XCTUnwrap(URL(string: valid.absoluteString.replacingOccurrences(of: "/v1/", with: "/v2/"))))
        XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 15))
        XCTAssertFalse(history.exists)
        capture("native-invalid-after")
    }

    @MainActor
    func testHistoryURLAfterBackgroundRequiresActualVisibleReceipt() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        XCTAssertFalse(history.exists)
        let request = UUID()
        try invocation(request, backend: "otzaria", mode: "post_background")
        try openInExistingProcess(historyURL("otzaria", request: request))
        XCTAssertTrue(history.waitForExistence(timeout: 20))
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireNativeReceipt(request, backend: "otzaria")
    }

    @MainActor
    func testWrongBackendURLCannotNavigateOrIssueNativeReceipt() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let request = UUID()
        try invocation(request, backend: "sefaria", mode: "backend_denied")
        try openInExistingProcess(historyURL("sefaria", request: request))
        let alert = app.alerts["Unable to open link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts["Select the requested library in Maktabah before continuing."].exists)
        XCTAssertFalse(history.exists)
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("[NativeNavigationReceipt] request=" + request.uuidString),
                       "A refused backend must never produce a completion receipt")
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testReplayCannotIssueSecondNativeReceipt() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let request = UUID(), url = try historyURL("otzaria", request: request)
        try invocation(request, backend: "otzaria", mode: "replay")
        try openInExistingProcess(url)
        XCTAssertTrue(history.waitForExistence(timeout: 20))
        try requireNativeReceipt(request, backend: "otzaria")
        try openInExistingProcess(url)
        XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 15))
        XCTAssertTrue(history.exists)
        // The original exact-one receipt oracle also rejects a second ACK.
        try requireNativeReceipt(request, backend: "otzaria")
    }
}


// Reuse the full system-entry, same-process, real visible-surface and canonical
// receipt/refusal oracles. No phone-specific shortcut bypasses scene validation.
final class NativeRoutingPhoneAcceptanceTests: NativeRoutingAcceptanceTests {
    @MainActor
    func testPhoneWarmHistoryUsesActualForegroundScene() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try testWarmHistoryURLUsesOtzariaNativeScene()
    }

    @MainActor
    func testPhoneColdHistoryWaitsForActualSceneMount() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try testColdHistoryURLWaitsForActualSceneMount()
    }

    @MainActor
    func testPhoneWrongBackendCannotNavigateOrIssueReceipt() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try testWrongBackendURLCannotNavigateOrIssueNativeReceipt()
    }
}
