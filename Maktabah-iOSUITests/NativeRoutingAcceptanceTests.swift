import XCTest
import AppIntentsTesting
import CryptoKit
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
        try runHistoryOnPhone(cold: false, rejectedBackend: false)
    }

    @MainActor
    func testPhoneColdHistoryWaitsForActualSceneMount() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try runHistoryOnPhone(cold: true, rejectedBackend: false)
    }

    @MainActor
    func testPhoneWrongBackendCannotNavigateOrIssueReceipt() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try runHistoryOnPhone(cold: false, rejectedBackend: true)
    }
}


extension NativeRoutingAcceptanceTests {
    private struct ReaderSourceMetadata: Decodable {
        let profileID: String
        let profileVersion: Int
        let databaseSHA256: String
        let books: [String: String]
        let rows: [[Int]]
    }

    private func readerSourceMetadata() throws -> ReaderSourceMetadata {
        let url = try XCTUnwrap(Bundle(for: NativeRoutingAcceptanceTests.self)
            .url(forResource: "canonical-miniTest10-metadata", withExtension: "json"))
        let bytes = try Data(contentsOf: url)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, "c6ca39044f6a62728f8f7e40e86d4080c89dc8927ced5ae6d724079efb5f896b")
        let metadata = try JSONDecoder().decode(ReaderSourceMetadata.self, from: bytes)
        XCTAssertEqual(metadata.profileID, "miniTest10")
        XCTAssertEqual(metadata.profileVersion, 6)
        XCTAssertEqual(metadata.databaseSHA256, "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef")
        XCTAssertEqual(metadata.rows.count, 18_879)
        let proof = XCTAttachment(string: "Installed UITest bundle resource: \(url.absoluteString)\nActual SHA256: \(hash)")
        proof.name = "native-reader-independent-source-metadata"; proof.lifetime = .keepAlways; add(proof)
        return metadata
    }

    @MainActor private func launchCurrentCanonicalReader(expectedPad: Bool = true) throws -> String {
        XCTAssertEqual(isPad, expectedPad, "Require the declared actual form factor and its original workspace; never skip")
        launchWithTier(.realUI, scenario: "reader", backend: "otzaria",
            extraArgs: ["-preferredBackend", "otzaria", "-smokeBackend", "otzaria",
                        "-ChavrusaTextFaithfulReaderUIEnabled", "YES", "-otzaria_reader_unit_mode", "line",
                        "-studyWorkspaceTestingNamespace", workspaceNamespace, "-lastSelectedTab", "0"],
            language: "en", locale: "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        dismissAlertsIfNeeded()
        let work = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"])
        let title = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        let oracle = try systemReaderOracleDocument()
        let initial = try XCTUnwrap(oracle.rows.first { $0.id == oracle.bootstrapRowID })
        XCTAssertEqual(work, "book:\(initial.bookId)")
        try requireReaderLocator("otzaria|\(work)|line:\(initial.lineIndex)", timeout: 60)
        XCTAssertTrue(app.staticTexts["reader-header-title"].label.contains(title))
        return work
    }

    private func readerURL(bookID: Int, lineIndex: Int, newTab: Bool = false) throws -> URL {
        let ref: [String: Any] = ["backend": "otzaria", "workKey": "book:\(bookID)",
                                  "position": ["kind": "legacyLine", "value": lineIndex]]
        let bytes = try JSONSerialization.data(withJSONObject: ["version": 2, "destination": "native.reader",
            "backend": "otzaria", "presentation": newTab ? "newTab" : "currentTab",
            "content": ["sectionLocator": ref, "focusLocator": ref,
                        "presentationMode": newTab ? "newTab" : "sameTab"]], options: [.sortedKeys])
        let token = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v2/native.reader?route=" + token))
    }

    private func actualReaderLogURL() throws -> URL {
        let sidecar = try workspaceSidecarURL().standardizedFileURL, parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        return parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
    }

    private func readerReceiptLines() throws -> [String] {
        let log = try actualReaderLogURL()
        if !FileManager.default.fileExists(atPath: log.path) { return [] }
        return try String(contentsOf: log, encoding: .utf8).split(separator: "\n")
            .map(String.init).filter { $0.contains("[NativeNavigationReceipt]") && $0.contains("destination=native.reader ") }
    }

    @MainActor private func requireNewReaderReceipt(after before: [String], presentation: String = "currentTab") throws {
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let actual = (try? self.readerReceiptLines()) ?? []
            return actual.count == before.count + 1 && Array(actual.prefix(before.count)) == before
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [observed], timeout: 15), .completed,
                       "Only a full canonical Core result may produce the one new native receipt")
        let lines = try readerReceiptLines()
        XCTAssertEqual(lines.count, before.count + 1)
        XCTAssertEqual(Array(lines.prefix(before.count)), before, "Prior receipt evidence must remain unchanged")
        let line = try XCTUnwrap(lines.last), parts = line.split(separator: " ", maxSplits: 2)
        XCTAssertEqual(parts.count, 3)
        var fields: [String: String] = [:]
        for item in parts[2].split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            XCTAssertEqual(pair.count, 2); XCTAssertNil(fields[String(pair[0])])
            fields[String(pair[0])] = String(pair[1])
        }
        XCTAssertEqual(Set(fields.keys), ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"])
        XCTAssertNotNil(fields["request"].flatMap(UUID.init(uuidString:)))
        XCTAssertEqual(fields["backend"], "otzaria"); XCTAssertEqual(fields["epoch"], "none")
        XCTAssertEqual(fields["destination"], "native.reader"); XCTAssertEqual(fields["presentation"], presentation)
        XCTAssertNotNil(fields["generation"].flatMap(UInt64.init))
        let revisions = try XCTUnwrap(fields["revision"]).components(separatedBy: "->")
        XCTAssertEqual(revisions.count, 2)
        XCTAssertGreaterThan(try XCTUnwrap(UInt64(revisions[1])), try XCTUnwrap(UInt64(revisions[0])))
        let snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: workspaceSidecarURL())) as? [String: Any])
        let scenes = try XCTUnwrap(snapshot["scenes"] as? [String: Any])
        XCTAssertNotNil(scenes[try XCTUnwrap(fields["scene"])])
        let receipt = XCTAttachment(string: line); receipt.name = "actual-current-reader-core-receipt"
        receipt.lifetime = .keepAlways; add(receipt)
        try attachWorkspaceSnapshot("native-current-reader-receipt")
    }

    @MainActor
    func testPublicV2CurrentReaderShowsTwoCanonicalSourceLines() throws {
        try runCurrentReaderSourceLines(expectedPad: true)
    }
    @MainActor func runCurrentReaderSourceLines(expectedPad: Bool) throws {
        let metadata = try readerSourceMetadata(), work = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let bookID = try XCTUnwrap(Int(work.replacingOccurrences(of: "book:", with: "")))
        let rows = metadata.rows.filter { $0.count == 3 && $0[1] == bookID && $0[2] > 0 }
        XCTAssertGreaterThan(rows.count, 10, "Require two independently known nonzero source lines")
        let targets = [rows[0], rows[9]]
        XCTAssertNotEqual(targets[0][2], targets[1][2])
        for target in targets {
            let before = try readerReceiptLines()
            try openInExistingProcess(readerURL(bookID: bookID, lineIndex: target[2]))
            XCTAssertFalse(app.alerts["Unable to open link"].exists)
            let expected = "otzaria|book:\(bookID)|line:\(target[2])"
            try requireReaderLocator(expected)
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, expected)
            let rendered = try XCTUnwrap(getRenderedHighlightSnapshot(), "Actual original TextKit diagnostic required")
            XCTAssertEqual(rendered.locator, expected)
            XCTAssertGreaterThan(rendered.segmentSelectionCount, 0, "Requested segment must be highlighted by the original renderer")
            XCTAssertTrue(app.staticTexts["reader-header-title"].label.contains(try XCTUnwrap(metadata.books[String(bookID)])))
            try requireNewReaderReceipt(after: before)
            capture("native-core-reader-source-line-\(target[2])")
        }
    }

    @MainActor
    func testPublicV2OtherBookCannotReplaceCurrentReaderOrAcknowledge() throws {
        try runCurrentReaderOtherBookRefusal(expectedPad: true)
    }
    @MainActor func runCurrentReaderOtherBookRefusal(expectedPad: Bool) throws {
        let metadata = try readerSourceMetadata(), work = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let bookID = try XCTUnwrap(Int(work.replacingOccurrences(of: "book:", with: "")))
        let other = try XCTUnwrap(metadata.rows.first { $0.count == 3 && $0[1] != bookID && $0[2] > 0 })
        let before = try readerReceiptLines(), locator = app.staticTexts["reader-current-locator"].label
        let rendered = try XCTUnwrap(getRenderedHighlightSnapshot())
        try openInExistingProcess(readerURL(bookID: other[1], lineIndex: other[2]))
        XCTAssertTrue(app.alerts["Unable to open link"].waitForExistence(timeout: 15))
        XCTAssertEqual(try readerReceiptLines(), before, "Unsupported cross-book binding must never produce an ACK")
        app.alerts["Unable to open link"].buttons.firstMatch.tap()
        try requireReaderLocator(locator)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, rendered.locator)
        capture("native-core-reader-cross-book-refusal")
    }

    private struct ReaderWorkspaceSnapshot: Decodable {
        struct Document: Decodable {
            struct Session: Decodable { let id: UUID; let bookId: Int }
            let backend: String
            let session: Session
        }
        struct Group: Decodable {
            let id: UUID; let profileID: UUID
            let activeTabID: UUID?; let tabs: [Document]
        }
        struct Scene: Decodable {
            let profileID: UUID; let groupID: UUID
            let activeTabIDsByGroup: [UUID: UUID]?
        }
        let groups: [Group]; let scenes: [String: Scene]
        let lastActiveSceneID: String?
        func current() throws -> (Group, UUID) {
            let scene = try XCTUnwrap(scenes[try XCTUnwrap(lastActiveSceneID)])
            let group = try XCTUnwrap(groups.first { $0.id == scene.groupID && $0.profileID == scene.profileID })
            return (group, try XCTUnwrap(scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID))
        }
    }
    private func actualReaderWorkspace() throws -> ReaderWorkspaceSnapshot {
        try JSONDecoder().decode(ReaderWorkspaceSnapshot.self, from: Data(contentsOf: workspaceSidecarURL()))
    }
    @MainActor private func requireReaderLocator(_ expected: String, timeout: TimeInterval = 15) throws {
        let fields = expected.components(separatedBy: "|")
        XCTAssertEqual(fields.count, 3)
        guard fields.count == 3 else { XCTFail("Require an independent canonical source locator"); return }
        XCTAssertEqual(fields[0], "otzaria")
        XCTAssertTrue(fields[1].hasPrefix("book:")); XCTAssertTrue(fields[2].hasPrefix("line:"))
        let bookID = try XCTUnwrap(Int(fields[1].dropFirst("book:".count)))
        let lineIndex = try XCTUnwrap(Int(fields[2].dropFirst("line:".count)))
        let oracle = try systemReaderOracleDocument()
        let rows = oracle.rows.filter { $0.bookId == bookID && $0.lineIndex == lineIndex }
        XCTAssertEqual(rows.count, 1, "Exact source text must come from the sealed original SQL fixture")
        let source = try XCTUnwrap(rows.first)
        let observation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let locator = self.app.staticTexts["reader-current-locator"]
            return locator.exists && locator.label == expected
                && self.getRenderedHighlightSnapshot()?.locator == expected
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [observation], timeout: timeout), .completed)
        assertReaderHasText(expectedSourceText: source.plainText)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, expected)
        XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, expected)
    }
    @MainActor func runNewTabReader(sameBook: Bool, expectedPad: Bool = true) throws {
        let metadata = try readerSourceMetadata(), work = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let currentBookID = try XCTUnwrap(Int(work.replacingOccurrences(of: "book:", with: "")))
        let source = try XCTUnwrap(metadata.rows.first {
            $0.count == 3 && $0[2] > 0 && (sameBook ? $0[1] == currentBookID : $0[1] != currentBookID)
        })
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let (beforeGroup, originalTabID) = try actualReaderWorkspace().current()
        XCTAssertEqual(try XCTUnwrap(beforeGroup.tabs.first { $0.session.id == originalTabID }).session.bookId, currentBookID)
        let beforeReceipts = try readerReceiptLines()
        try attachWorkspaceSnapshot("native-new-tab-before")
        try openInExistingProcess(readerURL(bookID: source[1], lineIndex: source[2], newTab: true))
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        let expected = "otzaria|book:\(source[1])|line:\(source[2])"
        try requireReaderLocator(expected)
        XCTAssertGreaterThan(try XCTUnwrap(getRenderedHighlightSnapshot()).segmentSelectionCount, 0)
        XCTAssertTrue(app.staticTexts["reader-header-title"].label.contains(try XCTUnwrap(metadata.books[String(source[1])])))
        try requireNewReaderReceipt(after: beforeReceipts, presentation: "newTab")
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let (group, selected) = try? self.actualReaderWorkspace().current() else { return false }
            return group.tabs.count == beforeGroup.tabs.count + 1 && selected != originalTabID
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 15), .completed)
        let (afterGroup, newTabID) = try actualReaderWorkspace().current()
        XCTAssertEqual(afterGroup.id, beforeGroup.id); XCTAssertEqual(afterGroup.profileID, beforeGroup.profileID)
        XCTAssertEqual(afterGroup.tabs.count, beforeGroup.tabs.count + 1)
        XCTAssertNotEqual(newTabID, originalTabID)
        XCTAssertEqual(try XCTUnwrap(afterGroup.tabs.first { $0.session.id == newTabID }).session.bookId, source[1])
        for original in beforeGroup.tabs {
            let preserved = try XCTUnwrap(afterGroup.tabs.first { $0.session.id == original.session.id })
            XCTAssertEqual(preserved.backend, original.backend)
            XCTAssertEqual(preserved.session.bookId, original.session.bookId)
        }
        capture(sameBook ? "native-new-tab-same-book-distinct-owner" : "native-new-tab-other-book")
        // Return through the original native tab control. No debug navigation
        // or direct model mutation can stand in for the old reading state.
        if expectedPad {
            let originalTab = app.descendants(matching: .any)
                .matching(identifier: "reader-document-tab-" + originalTabID.uuidString).firstMatch
            XCTAssertTrue(originalTab.waitForExistence(timeout: 10)); XCTAssertTrue(originalTab.isHittable)
            originalTab.tap()
        } else {
            let overview = app.buttons["reader-open-tabs-button"]
            XCTAssertTrue(overview.waitForExistence(timeout: 10)); XCTAssertTrue(overview.isHittable)
            overview.tap()
            let ids = ["tab-switcher-grid-cell-", "tab-switcher-list-cell-"].map { $0 + originalTabID.uuidString }
            let originals = app.descendants(matching: .cell).matching(NSPredicate(format: "identifier IN %@", ids))
            XCTAssertTrue(originals.firstMatch.waitForExistence(timeout: 10))
            XCTAssertEqual(originals.count, 1); XCTAssertTrue(originals.firstMatch.isHittable)
            originals.firstMatch.tap()
        }
        try requireReaderLocator(originalLocator)
        XCTAssertEqual(try readerReceiptLines().count, beforeReceipts.count + 1)
        try attachWorkspaceSnapshot("native-new-tab-returned-to-original")
        capture("native-new-tab-original-reader-restored")
    }

    @MainActor func testPublicV2NewTabOpensOtherBookAndPreservesOriginalReader() throws {
        try runNewTabReader(sameBook: false)
    }
    @MainActor func testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab() throws {
        try runNewTabReader(sameBook: true)
    }

}


extension NativeRoutingAcceptanceTests {
    private func publicRootURL(_ destination: String, request: UUID) throws -> URL {
        XCTAssertTrue(["native.search", "native.annotations"].contains(destination))
        let bytes = try JSONSerialization.data(withJSONObject: [
            "version": 1, "requestId": request.uuidString, "destination": destination,
            "backend": "otzaria", "presentation": "currentTab"
        ], options: [.sortedKeys])
        let token = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v1/\(destination)?route=\(token)"))
    }

    private nonisolated static func rootReceiptFields(_ text: String, request: UUID, destination: String) -> [[String: String]] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2)
            guard parts.count == 3, parts[1] == "[NativeNavigationReceipt]" else { return nil }
            var fields: [String: String] = [:]
            for item in parts[2].split(separator: " ") {
                let pair = item.split(separator: "=", maxSplits: 1)
                guard pair.count == 2, fields[String(pair[0])] == nil else { return nil }
                fields[String(pair[0])] = String(pair[1])
            }
            guard Set(fields.keys) == ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"],
                  fields["request"].flatMap(UUID.init(uuidString:)) == request,
                  fields["destination"] == destination, fields["presentation"] == "currentTab",
                  fields["backend"] == "otzaria", fields["epoch"] == "none",
                  fields["generation"].flatMap(UInt64.init) != nil,
                  let revisions = fields["revision"]?.components(separatedBy: "->"), revisions.count == 2,
                  let before = UInt64(revisions[0]), let after = UInt64(revisions[1]), after > before else { return nil }
            return fields
        }
    }

    @MainActor
    private func requireRootReceipt(_ request: UUID, destination: String) throws {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let text = try? String(contentsOf: log, encoding: .utf8) else { return false }
            return Self.rootReceiptFields(text, request: request, destination: destination).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 15), .completed,
                       "Root opening needs one canonical actual visible receipt")
        let text = try String(contentsOf: log, encoding: .utf8), receipts = Self.rootReceiptFields(text, request: request, destination: destination)
        XCTAssertEqual(receipts.count, 1)
        let receipt = try XCTUnwrap(receipts.first)
        let workspace = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: sidecar)) as? [String: Any])
        let scenes = try XCTUnwrap(workspace["scenes"] as? [String: Any])
        XCTAssertNotNil(scenes[try XCTUnwrap(receipt["scene"])])
        let attachment = XCTAttachment(string: text)
        attachment.name = "actual-root-native-receipt-\(destination)-\(request)"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testGlobalSearchPublicRootPreservesOriginalPrivateQuery() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let first = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: first))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(field.elementType == .textField || field.elementType == .searchField)
        try requireRootReceipt(first, destination: "native.search")
        let privateQuery = "בראשית"
        field.tap(); field.typeText(privateQuery)
        XCTAssertEqual(field.value as? String, privateQuery)
        let historyRequest = UUID()
        try openInExistingProcess(historyURL("otzaria", request: historyRequest))
        XCTAssertTrue(history.waitForExistence(timeout: 20))
        try requireNativeReceipt(historyRequest, backend: "otzaria")
        let second = UUID(), url = try publicRootURL("native.search", request: second)
        XCTAssertFalse(url.absoluteString.contains(privateQuery))
        try openInExistingProcess(url)
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        XCTAssertEqual(field.value as? String, privateQuery, "Original unsubmitted query must survive root navigation")
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireRootReceipt(second, destination: "native.search")
        capture("native-search-root-private-query-preserved")
    }

    @MainActor
    func testAnnotationsPublicRootShowsOriginalScreenAndNativeReceipt() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let request = UUID()
        try openInExistingProcess(publicRootURL("native.annotations", request: request))
        XCTAssertTrue(app.navigationBars["Annotations"].waitForExistence(timeout: 20),
                      "Original annotation root must actually appear")
        XCTAssertFalse(history.exists)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try requireRootReceipt(request, destination: "native.annotations")
        capture("native-original-annotations-root")
    }
}


extension NativeRoutingAcceptanceTests {
    @MainActor
    private func requireOriginalPhoneLibrary(timeout: TimeInterval = 40) {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        // iPhoneLayout owns a NavigationStack titled Library. The ipad-only
        // library-column wrapper is absent on this real form factor.
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: timeout),
                      "Actual phone Library NavigationStack must be mounted")
        XCTAssertTrue(findTabButton(hebrew: "חיפוש", english: "Search").exists,
                      "Original phone TabView must be present after normal bootstrap")
        XCTAssertFalse(history.exists)
    }

    @MainActor
    func runHistoryOnPhone(cold: Bool, rejectedBackend: Bool) throws {
        configure("otzaria"); app.launch()
        requireOriginalPhoneLibrary()
        capture("native-phone-library-before")
        let request = UUID(), backend = rejectedBackend ? "sefaria" : "otzaria"
        try invocation(request, backend: backend, mode: rejectedBackend ? "phone_backend_denied" : (cold ? "phone_cold" : "phone_warm"))
        let url = try historyURL(backend, request: request)
        if cold { app.terminate(); app.open(url) }
        else { try openInExistingProcess(url) }
        if rejectedBackend {
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
                           "Refused backend must never produce a completion receipt")
            alert.buttons.firstMatch.tap()
            requireOriginalPhoneLibrary(timeout: 20)
        } else {
            XCTAssertTrue(history.waitForExistence(timeout: cold ? 40 : 20))
            XCTAssertFalse(app.alerts["Unable to open link"].exists)
            try requireNativeReceipt(request, backend: backend)
        }
        capture("native-phone-route-after")
    }
}


// These use Apple's iOS27 out-of-process App Intents infrastructure. They do
// not call perform() directly, import app internals or add a testing-only intent.
extension NativeRoutingAcceptanceTests {
    @MainActor
    private func actualNativeReceiptLines() throws -> Set<String> {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        guard FileManager.default.fileExists(atPath: log.path) else { return [] }
        return Set(try String(contentsOf: log, encoding: .utf8).split(separator: "\n")
            .filter { $0.contains(" [NativeNavigationReceipt] ") }.map(String.init))
    }

    @MainActor
    private func requireNewSystemIntentReceipt(destination: String, presentation: String, before: Set<String>) throws {
        let after = try actualNativeReceiptLines(), added = after.subtracting(before)
        XCTAssertTrue(before.isSubset(of: after), "Original receipt evidence must not be replaced")
        XCTAssertEqual(added.count, 1, "One system invocation must produce exactly one new native receipt")
        let line = try XCTUnwrap(added.first), parts = line.split(separator: " ", maxSplits: 2)
        XCTAssertEqual(parts.count, 3)
        guard parts.count == 3 else { return }
        XCTAssertEqual(parts[1], "[NativeNavigationReceipt]")
        var fields: [String: String] = [:]
        for item in parts[2].split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            XCTAssertEqual(pair.count, 2)
            guard pair.count == 2 else { return }
            XCTAssertNil(fields[String(pair[0])], "No duplicate receipt field is accepted")
            fields[String(pair[0])] = String(pair[1])
        }
        XCTAssertEqual(Set(fields.keys), ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"])
        XCTAssertNotNil(fields["request"].flatMap(UUID.init(uuidString:)))
        XCTAssertEqual(fields["destination"], destination)
        XCTAssertEqual(fields["presentation"], presentation)
        XCTAssertEqual(fields["backend"], "otzaria")
        XCTAssertEqual(fields["epoch"], "none")
        XCTAssertNotNil(fields["generation"].flatMap(UInt64.init))
        let revisions = try XCTUnwrap(fields["revision"]?.components(separatedBy: "->"))
        XCTAssertEqual(revisions.count, 2)
        guard revisions.count == 2 else { return }
        XCTAssertGreaterThan(try XCTUnwrap(UInt64(revisions[1])), try XCTUnwrap(UInt64(revisions[0])))
        let sidecar = try workspaceSidecarURL()
        let workspace = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: sidecar)) as? [String: Any])
        let scenes = try XCTUnwrap(workspace["scenes"] as? [String: Any])
        XCTAssertNotNil(scenes[try XCTUnwrap(fields["scene"])], "Receipt must name this app's actual scene")
        let attachment = XCTAttachment(string: line)
        attachment.name = "actual-system-intent-native-receipt-\(destination)"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    func testSystemAppIntentSettingsShowsOriginalSheetAndReceipt() async throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let matches = try await system.entities["NativeDestinationEntity"].entities(matching: "Settings")
        XCTAssertEqual(matches.count, 1, "Real entity query must resolve one eligible exact current scene")
        let destination = try XCTUnwrap(matches.first), before = try actualNativeReceiptLines()
        _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: destination).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        try requireNewSystemIntentReceipt(destination: "native.settings", presentation: "sheet", before: before)
        capture("system-intent-original-settings-sheet")
    }

    @MainActor
    func testSystemAppIntentSearchReturnsFromBackgroundToOriginalScreen() async throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let matches = try await system.entities["NativeDestinationEntity"].entities(matching: "Search")
        XCTAssertEqual(matches.count, 1)
        let destination = try XCTUnwrap(matches.first), before = try actualNativeReceiptLines()
        XCUIDevice.shared.press(.home)
        _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: destination).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 15))
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.exists && (field.elementType == .searchField || field.elementType == .textField))
        try requireNewSystemIntentReceipt(destination: "native.search", presentation: "currentTab", before: before)
        capture("system-intent-search-after-background")
    }

    @MainActor
    func testSystemAppIntentRejectsUnknownEntityWithoutNativeAcknowledgement() async throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let invalid = system.entities["NativeDestinationEntity"].makeReference(identifier: "not-a-registered-native-entity")
        let before = try actualNativeReceiptLines()
        var rejected = false
        do {
            _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: invalid).run()
        } catch {
            rejected = true
            let evidence = XCTAttachment(string: String(describing: error))
            evidence.name = "actual-system-intent-unknown-entity-error"
            evidence.lifetime = .keepAlways; add(evidence)
        }
        XCTAssertTrue(rejected, "An unknown system entity must never complete")
        XCTAssertEqual(try actualNativeReceiptLines(), before)
        XCTAssertTrue(app.otherElements["library-column"].exists)
        XCTAssertFalse(history.exists)
        capture("system-intent-unknown-entity-refusal")
    }
}


extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhonePublicV2CurrentReaderShowsCanonicalSourceLines() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try runCurrentReaderSourceLines(expectedPad: false)
    }
    @MainActor func testPhonePublicV2NewTabPreservesOriginalReader() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try runNewTabReader(sameBook: false, expectedPad: false)
    }
    @MainActor func testPhonePublicV2OtherBookCannotReplaceCurrentReader() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .phone)
        try runCurrentReaderOtherBookRefusal(expectedPad: false)
    }
}


// Real existing Library / TOC surfaces, entered through the original public
// parser and Core authorization. No input query or private owner IDs are in URLs.
extension NativeRoutingAcceptanceTests {
    private func publicSidebarRootURL(_ destination: String) throws -> URL {
        XCTAssertTrue(["native.library", "native.reader.toc"].contains(destination))
        let payload: [String: Any] = ["version": 2, "destination": destination,
                                     "backend": "otzaria", "presentation": "currentTab"]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let token = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v2/\(destination)?route=\(token)"))
    }

    @MainActor
    private func requirePublicRootReceipt(_ destination: String, before: Set<String>) throws {
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? self.actualNativeReceiptLines() else { return false }
            return before.isSubset(of: actual) && actual.subtracting(before).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 15), .completed,
                       "The actual original UIKit surface must acknowledge through Core")
        try requireNewSystemIntentReceipt(destination: destination, presentation: "currentTab", before: before)
    }

    private func requirePreservedOriginalWorkspace(_ original: (ReaderWorkspaceSnapshot.Group, UUID)) throws {
        let current = try actualReaderWorkspace().current()
        XCTAssertEqual(current.0.id, original.0.id)
        XCTAssertEqual(current.0.profileID, original.0.profileID)
        XCTAssertEqual(current.1, original.1, "Opening a root must not replace the selected original Reader owner")
        XCTAssertEqual(current.0.tabs.map(\.session.id), original.0.tabs.map(\.session.id))
        XCTAssertEqual(current.0.tabs.map(\.backend), original.0.tabs.map(\.backend))
        XCTAssertEqual(current.0.tabs.map(\.session.bookId), original.0.tabs.map(\.session.bookId))
    }

    @MainActor private func originalVisibleSidebarSearch() throws -> XCUIElement {
        let pager = app.descendants(matching: .any).matching(identifier: "reader-sidebar-pager").firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 10))
        let column = CGRect(x: pager.frame.minX, y: app.windows.firstMatch.frame.minY,
                            width: pager.frame.width, height: app.windows.firstMatch.frame.height)
        let fields = app.searchFields.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && column.insetBy(dx: -1, dy: 0).contains($0.frame) && $0.isHittable
        }
        XCTAssertEqual(fields.count, 1, "Use the original native field belonging to the actual sidebar")
        return try XCTUnwrap(fields.first)
    }

    @MainActor func testPublicV2LibraryPreservesPrivateQueryAndOriginalReader() throws {
        _ = try launchCurrentCanonicalReader()
        let original = try actualReaderWorkspace().current()
        let locator = app.staticTexts["reader-current-locator"].label
        var before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSidebarRootURL("native.library"))
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 15))
        try requirePublicRootReceipt("native.library", before: before)
        let field = try originalVisibleSidebarSearch(), privateQuery = "בראשית"
        field.tap(); field.typeText(privateQuery)
        XCTAssertEqual(field.value as? String, privateQuery)
        let historyRequest = UUID()
        try openInExistingProcess(historyURL("otzaria", request: historyRequest))
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        try requireNativeReceipt(historyRequest, backend: "otzaria")
        before = try actualNativeReceiptLines()
        let root = try publicSidebarRootURL("native.library")
        XCTAssertFalse(root.absoluteString.contains(privateQuery))
        try openInExistingProcess(root)
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 15))
        try requirePublicRootReceipt("native.library", before: before)
        XCTAssertEqual(try originalVisibleSidebarSearch().value as? String, privateQuery)
        try requirePreservedOriginalWorkspace(original)
        try requireReaderLocator(locator)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        capture("native-library-root-original-reader-and-private-query")
    }

    @MainActor func testPublicV2TOCPreservesPrivateFilterAndOriginalReader() throws {
        _ = try launchCurrentCanonicalReader()
        let original = try actualReaderWorkspace().current()
        let locator = app.staticTexts["reader-current-locator"].label
        var before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSidebarRootURL("native.reader.toc"))
        let toc = app.descendants(matching: .any).matching(identifier: "toc-column").firstMatch
        XCTAssertTrue(toc.waitForExistence(timeout: 15))
        let row = toc.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "toc-row-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(row.isHittable, "An actual original TOC row must be rendered")
        try requirePublicRootReceipt("native.reader.toc", before: before)
        let privateFilter = row.label
        XCTAssertFalse(privateFilter.isEmpty)
        let field = try originalVisibleSidebarSearch()
        field.tap(); field.typeText(privateFilter)
        XCTAssertEqual(field.value as? String, privateFilter)
        before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSidebarRootURL("native.library"))
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 15))
        try requirePublicRootReceipt("native.library", before: before)
        before = try actualNativeReceiptLines()
        let root = try publicSidebarRootURL("native.reader.toc")
        XCTAssertFalse(root.absoluteString.contains(privateFilter))
        try openInExistingProcess(root)
        XCTAssertTrue(toc.waitForExistence(timeout: 15))
        try requirePublicRootReceipt("native.reader.toc", before: before)
        XCTAssertEqual(try originalVisibleSidebarSearch().value as? String, privateFilter)
        XCTAssertTrue(toc.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "toc-row-")).firstMatch.exists)
        try requirePreservedOriginalWorkspace(original)
        try requireReaderLocator(locator)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        capture("native-toc-root-original-reader-and-private-filter")
    }

    @MainActor func testPublicV2TOCWithoutOriginalReaderCannotAcknowledge() throws {
        XCTAssertTrue(isPad)
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        // A fresh sidecar namespace must not erase the original restored tabs.
        // Establish the empty-reader precondition through the real profile UI.
        let originalWorkspace = try actualReaderWorkspace()
        let emptyProfile = "בדיקת תוכן ללא ספר"
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        tap(app.buttons["פרופיל לימוד חדש"])
        let name = app.textFields["שם הפרופיל"]
        tap(name); name.typeText(emptyProfile)
        tap(app.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts[emptyProfile].waitForExistence(timeout: 10))
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons[emptyProfile])
        let emptyReader = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !self.app.staticTexts["reader-current-locator"].exists,
                  let snapshot = try? self.actualReaderWorkspace(),
                  let sceneID = snapshot.lastActiveSceneID,
                  let scene = snapshot.scenes[sceneID],
                  let group = snapshot.groups.first(where: { $0.id == scene.groupID && $0.profileID == scene.profileID })
            else { return false }
            return group.tabs.isEmpty && group.activeTabID == nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [emptyReader], timeout: 15), .completed)
        XCTAssertFalse(app.staticTexts["reader-current-locator"].exists)
        let preservedWorkspace = try actualReaderWorkspace()
        for original in originalWorkspace.groups {
            let preserved = try XCTUnwrap(preservedWorkspace.groups.first { $0.id == original.id })
            XCTAssertEqual(preserved.profileID, original.profileID)
            XCTAssertEqual(Set(preserved.tabs.map(\.session.id)), Set(original.tabs.map(\.session.id)))
            for tab in original.tabs {
                let kept = try XCTUnwrap(preserved.tabs.first { $0.session.id == tab.session.id })
                XCTAssertEqual(kept.backend, tab.backend); XCTAssertEqual(kept.session.bookId, tab.session.bookId)
            }
        }
        try attachWorkspaceSnapshot("native-toc-empty-profile-original-tabs-preserved")
        let before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSidebarRootURL("native.reader.toc"))
        let alert = app.alerts["Unable to open link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "No original selected Reader/TOC must be an explicit refusal")
        XCTAssertEqual(try actualNativeReceiptLines(), before, "An unavailable TOC cannot produce a visible receipt")
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.otherElements["library-column"].exists)
        XCTAssertFalse(app.staticTexts["reader-current-locator"].exists)
        capture("native-toc-without-original-reader-refused")
    }

    @MainActor func runPhoneLibraryRootPreservesOriginalReader() throws {
        _ = try launchCurrentCanonicalReader(expectedPad: false)
        let original = try actualReaderWorkspace().current()
        let before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSidebarRootURL("native.library"))
        requireOriginalPhoneLibrary(timeout: 15)
        XCTAssertFalse(app.staticTexts["reader-current-locator"].exists,
                       "The original phone NavigationStack must pop its visible Reader")
        try requirePublicRootReceipt("native.library", before: before)
        try requirePreservedOriginalWorkspace(original)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        try attachWorkspaceSnapshot("native-phone-library-preserved-original-reader-owner")
        capture("native-phone-original-library-root")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhonePublicV2LibraryPreservesOriginalReaderOwner() throws {
        try runPhoneLibraryRootPreservesOriginalReader()
    }
}


// Real Apple system invocation, source-owned Core entities, original Reader owner.
// These cases never invoke perform directly or replace a source/scene/receipt.
extension NativeRoutingAcceptanceTests {
    private struct SystemReaderOracle: Decodable {
        struct Row: Decodable {
            let id: Int; let bookId: Int; let lineIndex: Int
            let plainText: String; let plainSHA256: String
        }
        let profileID: String; let profileVersion: Int; let databaseSHA256: String
        let bootstrapRowID: Int
        let rows: [Row]
    }
    private func systemReaderOracleDocument() throws -> SystemReaderOracle {
        let url = try XCTUnwrap(Bundle(for: NativeRoutingAcceptanceTests.self)
            .url(forResource: "canonical-miniTest10-reader-lines", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "51632762100689aa2da6a6d360a6434d4fa4caf5e57971f4ad8e327ab6e173dc")
        let original = try JSONDecoder().decode(SystemReaderOracle.self, from: data)
        XCTAssertEqual(original.profileID, "miniTest10"); XCTAssertEqual(original.profileVersion, 6)
        XCTAssertEqual(original.databaseSHA256, "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef")
        XCTAssertEqual(Set(original.rows.map(\.id)).count, original.rows.count)
        XCTAssertTrue(original.rows.contains { $0.id == original.bootstrapRowID })
        for row in original.rows {
            XCTAssertFalse(row.plainText.isEmpty)
            XCTAssertEqual(SHA256.hash(data: Data(row.plainText.utf8)).map { String(format: "%02x", $0) }.joined(), row.plainSHA256)
        }
        let evidence = XCTAttachment(string: "Installed original SQL oracle: \(url.absoluteString)\nSHA256: \(digest)\nBootstrap row: \(original.bootstrapRowID)\nSealed source rows: \(original.rows.map(\.id))")
        evidence.name = "native-reader-independent-text-source"; evidence.lifetime = .keepAlways; add(evidence)
        return original
    }
    private func systemReaderOracle(lineID: Int) throws -> SystemReaderOracle.Row {
        try XCTUnwrap(systemReaderOracleDocument().rows.first { $0.id == lineID })
    }
    private func systemEntityIdentifier(_ fields: [String: Any], kind: String) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        return "maktabah.\(kind).v1." + data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    @MainActor private func requireSystemReaderSource(_ row: SystemReaderOracle.Row) throws {
        let expected = "otzaria|book:\(row.bookId)|line:\(row.lineIndex)"
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 45))
        let controls: Set<UInt32> = [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069]
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = text.value as? String else { return false }
            let plain = actual.unicodeScalars.filter { !controls.contains($0.value) }.map(String.init)
                .joined().trimmingCharacters(in: .whitespacesAndNewlines)
            return plain == row.plainText
                && self.app.staticTexts["reader-current-locator"].label == expected
                && self.getRenderedHighlightSnapshot()?.locator == expected
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 30), .completed,
                       "The original TextKit text and exact source locator must both match independent SQL")
        XCTAssertGreaterThan(text.frame.width, 80); XCTAssertGreaterThan(text.frame.height, 80)
        XCTAssertGreaterThan(try XCTUnwrap(getRenderedHighlightSnapshot()).segmentSelectionCount, 0)
    }
    @MainActor func runSystemBookIntent(namedChapter: Bool, expectedPad: Bool = true) async throws {
        let row = try systemReaderOracle(lineID: namedChapter ? 2 : 2634912)
        let metadata = try readerSourceMetadata()
        _ = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let original = try actualReaderWorkspace().current()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let books = try await system.entities["NativeBookEntity"].entities(matching: try XCTUnwrap(metadata.books[String(row.bookId)]))
        XCTAssertEqual(books.count, 1, "Book must resolve through original Core and the installed actual catalog")
        let windows = try await system.entities["NativeDestinationEntity"].entities(matching: "Library")
        XCTAssertEqual(windows.count, 1)
        let book = try XCTUnwrap(books.first), window = try XCTUnwrap(windows.first)
        let before = try actualNativeReceiptLines()
        if namedChapter {
            // Apple resolves the typed source name using the location entity's
            // dependency on this selected book. This exercises the original TOC.
            XCTAssertEqual(row.bookId, 1); XCTAssertEqual(row.lineIndex, 1); XCTAssertEqual(row.plainText, "פרק א")
            _ = try await system.intents["OpenBookAtLocationIntent"]
                .makeIntent(book: book, location: row.plainText, window: window, newTab: true).run()
        } else {
            let id = try systemEntityIdentifier(["backend": "otzaria", "workKey": "book:\(row.bookId)",
                "position": ["kind": "legacyLine", "value": row.lineIndex]], kind: "location")
            let location = system.entities["NativeBookLocationEntity"].makeReference(identifier: id)
            XCUIDevice.shared.press(.home)
            _ = try await system.intents["OpenBookAtLocationIntent"]
                .makeIntent(book: book, location: location, window: window, newTab: true).run()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        try requireSystemReaderSource(row)
        XCTAssertTrue(app.staticTexts["reader-header-title"].label.contains(try XCTUnwrap(metadata.books[String(row.bookId)])))
        try requireNewSystemIntentReceipt(destination: "native.reader", presentation: "newTab", before: before)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.actualReaderWorkspace().current() else { return false }
            return current.0.tabs.count == original.0.tabs.count + 1 && current.1 != original.1
        }, object: nil)
        let savedResult = await XCTWaiter.fulfillment(of: [saved], timeout: 15)
        XCTAssertEqual(savedResult, .completed)
        let current = try actualReaderWorkspace().current()
        XCTAssertEqual(current.0.id, original.0.id); XCTAssertEqual(current.0.profileID, original.0.profileID)
        XCTAssertEqual(try XCTUnwrap(current.0.tabs.first { $0.session.id == current.1 }).session.bookId, row.bookId)
        for old in original.0.tabs {
            let retained = try XCTUnwrap(current.0.tabs.first { $0.session.id == old.session.id })
            XCTAssertEqual(retained.session.bookId, old.session.bookId); XCTAssertEqual(retained.backend, old.backend)
        }
        capture(namedChapter ? "system-book-intent-original-named-chapter" : "system-book-intent-original-source-after-background")
        if expectedPad {
            let tab = app.descendants(matching: .any).matching(identifier: "reader-document-tab-" + original.1.uuidString).firstMatch
            XCTAssertTrue(tab.isHittable); tab.tap()
        } else {
            let overview = app.buttons["reader-open-tabs-button"]
            XCTAssertTrue(overview.waitForExistence(timeout: 10)); XCTAssertTrue(overview.isHittable); overview.tap()
            let ids = ["tab-switcher-grid-cell-", "tab-switcher-list-cell-"].map { $0 + original.1.uuidString }
            let cell = app.descendants(matching: .cell).matching(NSPredicate(format: "identifier IN %@", ids))
            XCTAssertTrue(cell.firstMatch.waitForExistence(timeout: 10)); XCTAssertEqual(cell.count, 1)
            XCTAssertTrue(cell.firstMatch.isHittable); cell.firstMatch.tap()
        }
        try requireReaderLocator(originalLocator)
        XCTAssertEqual(try actualNativeReceiptLines().count, before.count + 1)
        try attachWorkspaceSnapshot("system-book-intent-original-reader-returned")
    }
    @MainActor func testSystemBookIntentResolvesNamedChapterThroughOriginalCore() async throws {
        try await runSystemBookIntent(namedChapter: true)
    }
    @MainActor func testSystemBookIntentCachedSourceReturnsFromBackgroundAndPreservesReader() async throws {
        try await runSystemBookIntent(namedChapter: false)
    }
    @MainActor private func refuseSystemBookIntent(stale: Bool) async throws {
        let row = try systemReaderOracle(lineID: 2634912)
        _ = try launchCurrentCanonicalReader()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let original = try actualReaderWorkspace().current(), before = try actualNativeReceiptLines()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let id = try systemEntityIdentifier(["backend": "otzaria", "workKey": "book:\(stale ? row.bookId : 1)"], kind: "work")
        let book = system.entities["NativeBookEntity"].makeReference(identifier: id)
        let sourceID = try systemEntityIdentifier(["backend": "otzaria", "workKey": "book:\(row.bookId)",
            "position": ["kind": "legacyLine", "value": stale ? 999_999_999 : row.lineIndex]], kind: "location")
        let location = system.entities["NativeBookLocationEntity"].makeReference(identifier: sourceID)
        let windows = try await system.entities["NativeDestinationEntity"].entities(matching: "Library")
        XCTAssertEqual(windows.count, 1)
        let window = try XCTUnwrap(windows.first)
        var refused = false
        do {
            _ = try await system.intents["OpenBookAtLocationIntent"]
                .makeIntent(book: book, location: location, window: window, newTab: true).run()
        } catch {
            refused = true
            let evidence = XCTAttachment(string: String(describing: error))
            evidence.name = "system-book-intent-explicit-source-refusal"; evidence.lifetime = .keepAlways; add(evidence)
        }
        XCTAssertTrue(refused, "A stale or different-book source entity must not execute")
        XCTAssertEqual(try actualNativeReceiptLines(), before)
        try requirePreservedOriginalWorkspace(original)
        try requireReaderLocator(originalLocator)
    }
    @MainActor func testSystemBookIntentRejectsDifferentBookLocationWithoutMutation() async throws {
        try await refuseSystemBookIntent(stale: false)
    }
    @MainActor func testSystemBookIntentRejectsMissingSourceWithoutMutation() async throws {
        try await refuseSystemBookIntent(stale: true)
    }
}
extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhoneSystemBookIntentUsesOriginalReaderOwner() async throws {
        try await runSystemBookIntent(namedChapter: false, expectedPad: false)
    }
}


// The component borrows the already visible, scene-owned UISearchTextField.
// Actual keyboard input without another tap proves responder ownership;
// the canonical receipt alone is not the acceptance oracle.
extension NativeRoutingAcceptanceTests {
    private func publicSearchComponentURL(_ component: String = "native.search.query") throws -> URL {
        let payload: [String: Any] = [
            "version": 2, "destination": "native.search", "backend": "otzaria",
            "presentation": "currentTab", "component": component
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let token = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v2/native.search?route=\(token)"))
    }

    @MainActor
    private func requireSearchComponentReceipt(before: Set<String>) throws {
        try requirePublicRootReceipt("native.search", before: before)
        let native = try XCTUnwrap(actualNativeReceiptLines().subtracting(before).first)
        // The original helper above validates every field and duplicate.
        // Extract only the two correlation fields without trapping on a broken
        // diagnostic line after an XCTest assertion has already failed.
        let fields = native.split(separator: " ")
        let request = String(try XCTUnwrap(fields.first(where: { $0.hasPrefix("request=") })).dropFirst(8))
        let scene = String(try XCTUnwrap(fields.first(where: { $0.hasPrefix("scene=") })).dropFirst(6))
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        let text = try String(contentsOf: log, encoding: .utf8)
        let exact = "[NativeFocusReceipt] request=\(request) scene=\(scene) component=native.search.query"
        XCTAssertEqual(text.split(separator: "\n").filter { $0.hasSuffix(exact) }.count, 1,
                       "The same original Core receipt must include the verified component")
        let evidence = XCTAttachment(string: text)
        evidence.name = "actual-search-first-responder-receipt"; evidence.lifetime = .keepAlways; add(evidence)
    }

    @MainActor
    fileprivate func runOriginalSearchComponentFocus(expectedPad: Bool) throws {
        configure("otzaria"); app.launch()
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom == .pad, expectedPad)
        if expectedPad { XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40)) }
        else { requireOriginalPhoneLibrary() }
        let first = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: first))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        try requireRootReceipt(first, destination: "native.search")
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let originalQuery = "בראשית"
        field.tap(); field.typeText(originalQuery)
        XCTAssertEqual(field.value as? String, originalQuery)
        let historyRequest = UUID()
        try openInExistingProcess(historyURL("otzaria", request: historyRequest))
        XCTAssertTrue(history.waitForExistence(timeout: 20))
        try requireNativeReceipt(historyRequest, backend: "otzaria")
        let returnRequest = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: returnRequest))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        try requireRootReceipt(returnRequest, destination: "native.search")
        XCTAssertEqual(field.value as? String, originalQuery)
        let keyboardGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                     object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardGone], timeout: 10), .completed,
                       "The test must start with the actual field unfocused")
        let before = try actualNativeReceiptLines(), url = try publicSearchComponentURL()
        XCTAssertFalse(url.absoluteString.contains(originalQuery))
        try openInExistingProcess(url)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, originalQuery, "Focusing must not change or submit private input")
        try requireSearchComponentReceipt(before: before)
        // Do not tap the field here. Type through the system's current responder.
        app.typeText(" בדיקה")
        XCTAssertEqual(field.value as? String, originalQuery + " בדיקה")
        XCTAssertTrue(app.otherElements["global-search-history"].exists)
        XCTAssertFalse(app.otherElements["global-search-loading"].exists)
        capture("native-search-component-actual-keyboard")
    }

    @MainActor
    func testSystemAppIntentFocusesOriginalSearchComponent() async throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let request = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: request))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        try requireRootReceipt(request, destination: "native.search")
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let entities = try await system.entities["NativeDestinationEntity"].entities(matching: "Search field")
        XCTAssertEqual(entities.count, 1, "Only the live field in this exact original scene may be discovered")
        let entity = try XCTUnwrap(entities.first), before = try actualNativeReceiptLines()
        _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: entity).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        try requireSearchComponentReceipt(before: before)
        app.typeText("בראשית")
        XCTAssertEqual(field.value as? String, "בראשית")
        XCTAssertTrue(app.otherElements["global-search-history"].exists)
        XCTAssertFalse(app.otherElements["global-search-loading"].exists)
        capture("system-intent-original-search-first-responder")
    }

    @MainActor
    func testPublicV2SearchQueryFocusUsesOriginalFirstResponder() throws {
        try runOriginalSearchComponentFocus(expectedPad: true)
    }

    @MainActor
    func testPublicV2SearchComponentRequiresAlreadyVisibleOriginalField() throws {
        _ = try launchCurrentCanonicalReader()
        let title = app.staticTexts["reader-header-title"].label
        let original = try actualReaderWorkspace().current()
        let locator = app.staticTexts["reader-current-locator"].label
        let before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSearchComponentURL())
        let alert = app.alerts["Unable to open link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertEqual(try actualNativeReceiptLines(), before, "An absent field cannot acknowledge focus")
        alert.buttons.firstMatch.tap()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        try requirePreservedOriginalWorkspace(original)
        XCTAssertFalse(app.otherElements["global-search-screen"].exists)
        capture("native-search-component-unavailable-preserves-reader")
    }

    @MainActor
    func testPublicV2UnknownSearchComponentCannotFocusOrSubmit() throws {
        configure("otzaria"); app.launch()
        XCTAssertTrue(app.otherElements["library-column"].waitForExistence(timeout: 40))
        let root = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: root))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        try requireRootReceipt(root, destination: "native.search")
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let originalValue = field.value as? String
        let before = try actualNativeReceiptLines()
        try openInExistingProcess(publicSearchComponentURL("native.search.unregistered"))
        let alert = app.alerts["Unable to open link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertEqual(try actualNativeReceiptLines(), before)
        alert.buttons.firstMatch.tap()
        XCTAssertEqual(field.value as? String, originalValue)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.otherElements["global-search-history"].exists)
        XCTAssertFalse(app.otherElements["global-search-loading"].exists)
        capture("native-search-component-unknown-denied")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhonePublicV2SearchQueryFocusUsesOriginalFirstResponder() throws {
        try runOriginalSearchComponentFocus(expectedPad: false)
    }
}


// The existing Inspector is opened through public-v2/Core/Registry only. These
// tests neither instantiate an Inspector nor call an App Intent perform method.
extension NativeRoutingAcceptanceTests {
    private func publicInspectorURL() throws -> URL {
        let destination = "native.reader.inspector"
        let payload: [String: Any] = ["version": 2, "destination": destination,
                                     "backend": "otzaria", "presentation": "inspector"]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let token = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: "maktabah-debug://action/v2/\(destination)?route=\(token)"))
    }

    @MainActor private func requireOriginalInspectorReceipt(before: Set<String>) throws {
        let panel = app.descendants(matching: .any).matching(identifier: "torah-inspector-panel").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 30), "The original TorahInspectorKit panel must actually mount")
        XCTAssertTrue(panel.isHittable, "A hidden panel or model flag is not visible presentation")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "torah-inspector-tools").firstMatch.exists)
        let receipt = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? self.actualNativeReceiptLines() else { return false }
            return before.isSubset(of: actual) && actual.subtracting(before).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [receipt], timeout: 15), .completed)
        try requireNewSystemIntentReceipt(destination: "native.reader.inspector", presentation: "inspector", before: before)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
    }

    @MainActor private func closeOriginalInspectorAndRequireReader(_ locator: String) throws {
        tap(app.buttons["torah-inspector-close"])
        let panel = app.descendants(matching: .any).matching(identifier: "torah-inspector-panel").firstMatch
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: panel)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed)
        try requireReaderLocator(locator)
    }

    @MainActor func runOriginalInspectorPublic(expectedPad: Bool) throws {
        _ = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let original = try actualReaderWorkspace().current()
        let locator = app.staticTexts["reader-current-locator"].label
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "torah-inspector-panel").firstMatch.exists)
        var before = try actualNativeReceiptLines()
        let url = try publicInspectorURL()
        XCTAssertFalse(url.absoluteString.contains(locator), "Public panel navigation must not serialize private Reader state")
        try openInExistingProcess(url)
        try requireOriginalInspectorReceipt(before: before)
        try requirePreservedOriginalWorkspace(original)
        // Reopening an already displayed original panel is a separate exact
        // request, with one receipt and no replacement Reader/tab or selection.
        before = try actualNativeReceiptLines()
        try openInExistingProcess(url)
        try requireOriginalInspectorReceipt(before: before)
        try requirePreservedOriginalWorkspace(original)
        capture("native-inspector-original-current-reader")
        try closeOriginalInspectorAndRequireReader(locator)
        try requirePreservedOriginalWorkspace(original)
    }

    @MainActor func runOriginalInspectorSystemIntent(expectedPad: Bool) async throws {
        _ = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let original = try actualReaderWorkspace().current()
        let locator = app.staticTexts["reader-current-locator"].label
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let entities = try await system.entities["NativeDestinationEntity"].entities(matching: "Study Tools")
        XCTAssertEqual(entities.count, 1, "Only the actual visible original Reader in this window may advertise its panel")
        let entity = try XCTUnwrap(entities.first), before = try actualNativeReceiptLines()
        _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: entity).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        try requireOriginalInspectorReceipt(before: before)
        try requirePreservedOriginalWorkspace(original)
        capture("system-intent-original-inspector")
        try closeOriginalInspectorAndRequireReader(locator)
        try requirePreservedOriginalWorkspace(original)
    }

    @MainActor func testPublicV2InspectorPreservesOriginalReaderAndWorkspace() throws {
        try runOriginalInspectorPublic(expectedPad: true)
    }

    @MainActor func testSystemAppIntentShowsOriginalReaderInspector() async throws {
        try await runOriginalInspectorSystemIntent(expectedPad: true)
    }

    @MainActor func testPublicV2InspectorRequiresVisibleOriginalReader() throws {
        _ = try launchCurrentCanonicalReader()
        let original = try actualReaderWorkspace().current()
        let request = UUID()
        try openInExistingProcess(publicRootURL("native.search", request: request))
        XCTAssertTrue(app.otherElements["global-search-screen"].waitForExistence(timeout: 20))
        try requireRootReceipt(request, destination: "native.search")
        let field = app.descendants(matching: .any).matching(identifier: "global-search-query").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let privateQuery = "בדיקת מפרשים ללא מעבר"
        field.tap(); field.typeText(privateQuery)
        XCTAssertEqual(field.value as? String, privateQuery)
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        let before = try actualNativeReceiptLines()
        try openInExistingProcess(publicInspectorURL())
        let alert = app.alerts["Unable to open link"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "A background Reader owner must not authorize presentation")
        XCTAssertEqual(try actualNativeReceiptLines(), before)
        alert.buttons.firstMatch.tap()
        XCTAssertTrue(app.otherElements["global-search-screen"].exists)
        XCTAssertEqual(field.value as? String, privateQuery)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "torah-inspector-panel").firstMatch.exists)
        try requirePreservedOriginalWorkspace(original)
        capture("native-inspector-hidden-reader-refused")
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor func testPhonePublicV2InspectorPreservesOriginalReaderAndWorkspace() throws {
        try runOriginalInspectorPublic(expectedPad: false)
    }

    @MainActor func testPhoneSystemAppIntentShowsOriginalReaderInspector() async throws {
        try await runOriginalInspectorSystemIntent(expectedPad: false)
    }
}
