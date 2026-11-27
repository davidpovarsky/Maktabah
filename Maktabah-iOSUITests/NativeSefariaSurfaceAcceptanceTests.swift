import XCTest
import AppIntentsTesting

// Additive selectors only. Historical Native116/Release114 selections and
// original assertions remain unchanged. These require the real React SDK,
// original bootstrap/resources, real system Intent execution and app log.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func testSystemSefariaOriginalSurfaceColdAndWarmPreserveWorkspace() async throws {
        try await runOriginalSefariaSurface(expectedPad: true, warmFromBackground: false)
    }

    @MainActor
    func testSystemSefariaSurfaceUnavailableForOtzariaBackend() async throws {
        try await requireOriginalSefariaUnavailable(expectedPad: true)
    }

    @MainActor
    private func sefariaNativeReceiptLines() throws -> Set<String> {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        let log = parent.appendingPathComponent(container).appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        guard FileManager.default.fileExists(atPath: log.path) else { return [] }
        return Set(try String(contentsOf: log, encoding: .utf8).split(separator: "\n")
            .filter { $0.contains(" [NativeNavigationReceipt] ") }.map(String.init))
    }

    /// Original persisted document semantics, excluding geometry and timestamps.
    /// Opening the RN sheet must preserve every group/tab/current scene choice.
    @MainActor
    private func sefariaUnderlyingWorkspace() throws -> Data {
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: workspaceSidecarURL())) as? [String: Any])
        let groups = try XCTUnwrap(raw["groups"] as? [[String: Any]])
        let scenes = try XCTUnwrap(raw["scenes"] as? [String: Any])
        XCTAssertFalse(groups.isEmpty); XCTAssertFalse(scenes.isEmpty)
        let fields: Set<String> = ["id", "bookId", "bookTitle", "backendLocator", "locator", "contentId",
            "page", "part", "searchText", "searchModeRaw", "nearDistance", "highlightTerms"]
        let documents: [[String: Any]] = try groups.map { group in
            let tabs = try XCTUnwrap(group["tabs"] as? [[String: Any]])
            return ["id": try XCTUnwrap(group["id"] as? String),
                    "profileID": try XCTUnwrap(group["profileID"] as? String),
                    "activeTabID": group["activeTabID"] ?? NSNull(),
                    "tabs": try tabs.map { tab -> [String: Any] in
                        let session = try XCTUnwrap(tab["session"] as? [String: Any])
                        return ["backend": try XCTUnwrap(tab["backend"] as? String),
                                "session": session.filter { fields.contains($0.key) }]
                    }]
        }
        let choices = try scenes.mapValues { value -> [String: Any] in
            let scene = try XCTUnwrap(value as? [String: Any])
            return ["profileID": try XCTUnwrap(scene["profileID"] as? String),
                    "groupID": try XCTUnwrap(scene["groupID"] as? String),
                    "activeTabIDsByGroup": scene["activeTabIDsByGroup"] ?? NSNull()]
        }
        return try JSONSerialization.data(withJSONObject: ["groups": documents, "scenes": choices], options: [.sortedKeys])
    }

    @MainActor
    private func requireSefariaCanonicalReceipt(before: Set<String>) throws {
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? self.sefariaNativeReceiptLines() else { return false }
            return before.isSubset(of: actual) && actual.subtracting(before).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 15), .completed)
        let actual = try sefariaNativeReceiptLines(), added = actual.subtracting(before)
        XCTAssertTrue(before.isSubset(of: actual)); XCTAssertEqual(added.count, 1)
        let line = try XCTUnwrap(added.first), parts = line.split(separator: " ", maxSplits: 2)
        XCTAssertEqual(parts.count, 3)
        let payload = try XCTUnwrap(parts.last)
        var fields: [String: String] = [:]
        for item in payload.split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            XCTAssertEqual(pair.count, 2)
            guard pair.count == 2 else { XCTFail("Malformed real receipt"); return }
            let key = String(pair[0]); XCTAssertNil(fields[key]); fields[key] = String(pair[1])
        }
        XCTAssertEqual(Set(fields.keys), ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"])
        XCTAssertEqual(fields["destination"], "native.sefariaEmbedded")
        XCTAssertEqual(fields["presentation"], "sheet")
        XCTAssertEqual(fields["backend"], "sefariaEmbedded")
        XCTAssertNotNil(fields["request"].flatMap(UUID.init(uuidString:)))
        XCTAssertNotNil(fields["generation"].flatMap(UInt64.init))
        XCTAssertGreaterThan(try XCTUnwrap(fields["epoch"].flatMap(UInt64.init)), 0)
        let revisions = try XCTUnwrap(fields["revision"]?.components(separatedBy: "->"))
        XCTAssertEqual(revisions.count, 2)
        guard revisions.count == 2 else { XCTFail("Malformed revision receipt"); return }
        XCTAssertGreaterThan(try XCTUnwrap(UInt64(revisions[1])), try XCTUnwrap(UInt64(revisions[0])))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: workspaceSidecarURL())) as? [String: Any])
        let scenes = try XCTUnwrap(raw["scenes"] as? [String: Any])
        XCTAssertNotNil(scenes[try XCTUnwrap(fields["scene"])])
        let evidence = XCTAttachment(string: line); evidence.name = "original-rn-canonical-system-receipt"
        evidence.lifetime = .keepAlways; add(evidence)
    }

    @MainActor
    private func requireOriginalReactControls() {
        let root = app.descendants(matching: .any).matching(identifier: "chavrusa-original-sefaria-surface").firstMatch
        XCTAssertTrue(root.waitForExistence(timeout: 15)); XCTAssertFalse(root.frame.isEmpty)
        // Exact original FooterTabBar / PageHistory controls from pinned
        // SefariaMobile. Container allocation or the native Close button alone
        // cannot satisfy these assertions. Native runner uses the English UI.
        for title in ["Texts", "Topics", "Saved", "Account"] {
            let control = root.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 15), "Original RN footer control '\(title)' is missing")
            XCTAssertTrue(control.isHittable); XCTAssertFalse(control.frame.isEmpty)
        }
        XCTAssertFalse(app.alerts["Unable to open link"].exists)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); screen.name = "original-sefaria-visible-surface"
        screen.lifetime = .keepAlways; add(screen)
        let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.name = "original-sefaria-hierarchy"
        hierarchy.lifetime = .keepAlways; add(hierarchy)
    }

    @MainActor
    func runOriginalSefariaSurface(expectedPad: Bool, warmFromBackground: Bool) async throws {
        XCTAssertEqual(isPad, expectedPad)
        launchReader(backend: "sefariaEmbedded", language: "en", tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        let locator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(locator.waitForExistence(timeout: 60))
        let originalLocator = locator.label
        XCTAssertTrue(originalLocator.hasPrefix("sefariaEmbedded|"))
        let originalWorkspace = try sefariaUnderlyingWorkspace()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chavrusa-original-sefaria-surface").firstMatch.exists)
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        for warm in [false, true] {
            let entities = try await system.entities["NativeDestinationEntity"].entities(matching: "Sefaria")
            XCTAssertEqual(entities.count, 1, "One actual eligible original RN root in this scene")
            let destination = try XCTUnwrap(entities.first), before = try sefariaNativeReceiptLines()
            if warm && warmFromBackground { XCUIDevice.shared.press(.home) }
            _ = try await system.intents["OpenNativeDestinationIntent"].makeIntent(destination: destination).run()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
            requireOriginalReactControls()
            try requireSefariaCanonicalReceipt(before: before)
            XCTAssertEqual(try sefariaUnderlyingWorkspace(), originalWorkspace)
        }
        let close = app.buttons["sefaria-original-surface-close"]
        XCTAssertTrue(close.isHittable); close.tap()
        XCTAssertTrue(locator.waitForExistence(timeout: 15)); XCTAssertEqual(locator.label, originalLocator)
        XCTAssertEqual(try sefariaUnderlyingWorkspace(), originalWorkspace)
    }

    @MainActor
    func requireOriginalSefariaUnavailable(expectedPad: Bool) async throws {
        XCTAssertEqual(isPad, expectedPad)
        launchReader(backend: "otzaria", language: "en", tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        XCTAssertTrue(app.staticTexts["reader-current-locator"].waitForExistence(timeout: 60))
        let before = try sefariaNativeReceiptLines(), original = try sefariaUnderlyingWorkspace()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let entities = try await system.entities["NativeDestinationEntity"].entities(matching: "Sefaria")
        XCTAssertTrue(entities.isEmpty, "A different backend must not advertise an unavailable RN selection")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chavrusa-original-sefaria-surface").firstMatch.exists)
        XCTAssertEqual(try sefariaNativeReceiptLines(), before)
        XCTAssertEqual(try sefariaUnderlyingWorkspace(), original)
    }
}

extension NativeRoutingPhoneAcceptanceTests {
    @MainActor
    func testPhoneSystemSefariaOriginalSurfaceColdAndBackgroundWarmPreserveWorkspace() async throws {
        try await runOriginalSefariaSurface(expectedPad: false, warmFromBackground: true)
    }

    @MainActor
    func testPhoneSystemSefariaSurfaceUnavailableForOtzariaBackend() async throws {
        try await requireOriginalSefariaUnavailable(expectedPad: false)
    }
}
