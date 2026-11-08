import XCTest
import Vision

/// XCTest executes teardown blocks even when an assertion aborts a test method.
/// Keep Simulator-wide state restoration independent of that method's stack.
@MainActor
private final class NativeUIRestoration {
    let restore: @MainActor () -> Void
    init(_ restore: @escaping @MainActor () -> Void) { self.restore = restore }
    func run() { restore() }
}

/// Find only this test's unique sidecar after XCTest's app installation. The
/// pre-install container UUID is a hint to its parent, never a durable app ID.
private func matchingTestSidecars(in containers: URL, namespace: String) -> [URL] {
    guard UUID(uuidString: namespace) != nil,
          let candidates = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) else { return [] }
    return candidates.map {
        $0.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/UITests/\(namespace).json")
    }.filter { FileManager.default.fileExists(atPath: $0.path) }
}

/// Runs the supplied prototype in its own app, never demo code in Maktabah.
final class SafariPrototypeReferenceTests: XCTestCase {
    func testOriginalCompactAndExpandedToolbarOracle() {
        continueAfterFailure = false
        let prototype = XCUIApplication(bundleIdentifier: "com.example.safaritoolbarsearch")
        prototype.launchArguments = ["-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        prototype.launch()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let field = prototype.textFields["חיפוש או הזנת כתובת"]
            XCTAssertTrue(field.waitForExistence(timeout: 30))
            let compact = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            compact.name = "prototype-compact-\(orientation.isLandscape ? "landscape" : "portrait")"
            compact.lifetime = .keepAlways
            add(compact)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        prototype.textFields["חיפוש או הזנת כתובת"].tap()
        let result = prototype.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15), "The original CommandPalette must actually expand")
        let expanded = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        expanded.name = "prototype-expanded-command-palette"
        expanded.lifetime = .keepAlways
        add(expanded)
        prototype.terminate()
    }
}

/// Black-box tests use the actual production-default flags and original views.
/// A unique sidecar namespace isolates tests without changing canonical sessions/data.
class FaithfulReaderUIBase: MaktabahUITestBase {
    let workspaceNamespace = UUID().uuidString
    private var viewportURL: URL?
    struct Viewport: Decodable { let source: Int; let offset: Double; let object: Int; let requestID: String }
    func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria", language: String = "he", background: Int = 0, recordViewport: Bool = false) {
        // The downstream observer reads the actual original source anchor;
        // never activate the baseline renderer's crash-prone file exporter.
        let prefix = (recordViewport ? ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"] : nil).map {
            URL(fileURLWithPath: $0).appendingPathComponent("faithful-\(scenario)-" + UUID().uuidString).path
        }
        viewportURL = prefix.map { URL(fileURLWithPath: $0 + ".viewport.json") }
        launchWithTier(.smoke, scenario: scenario, backend: backend, extraArgs: [
            "-ChavrusaTextFaithfulReaderUIEnabled", enabled ? "YES" : "NO",
            "-studyWorkspaceTestingNamespace", workspaceNamespace,
            "-textViewBackgroundColorLight", String(background)
        ], language: language, locale: language == "he" ? "he_IL" : "en_US",
        extraEnvironment: prefix.map { ["CHAVRUSA_READER_VIEWPORT_REPORT": $0] } ?? [:])
        dismissAlertsIfNeeded()
    }
    func viewport() throws -> Viewport {
        let oldURL = try XCTUnwrap(viewportURL, "The matrix must supply the viewport observation directory")
        let sidecar = try workspaceSidecarURL()
        let container = sidecar.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = container.appendingPathComponent("Documents").appendingPathComponent(oldURL.lastPathComponent)
        let request = UUID().uuidString
        let prefix = String(url.path.dropLast(".viewport.json".count))
        try request.write(toFile: prefix + ".request", atomically: true, encoding: .utf8)
        let exists = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: url),
                  let report = try? JSONDecoder().decode(Viewport.self, from: data) else { return false }
            return report.requestID == request && report.offset.isFinite
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [exists], timeout: 15), .completed)
        return try JSONDecoder().decode(Viewport.self, from: Data(contentsOf: url))
    }
    func workspaceContainerParent() throws -> URL {
        let documents = try XCTUnwrap(ProcessInfo.processInfo.environment["FAITHFUL_VIEWPORT_DIRECTORY"])
        return URL(fileURLWithPath: documents).deletingLastPathComponent().deletingLastPathComponent()
    }
    func workspaceSidecarURL() throws -> URL {
        let containers = try workspaceContainerParent()
        let namespace = workspaceNamespace
        let created = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            matchingTestSidecars(in: containers, namespace: namespace).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 15), .completed,
                       "Exactly one real sidecar for this UUID must exist in the installed app's current container")
        let matches = matchingTestSidecars(in: containers, namespace: namespace)
        XCTAssertEqual(matches.count, 1)
        return try XCTUnwrap(matches.first)
    }
    func attachWorkspaceSnapshot(_ name: String) throws {
        let snapshot = XCTAttachment(data: try Data(contentsOf: workspaceSidecarURL()), uniformTypeIdentifier: "public.json")
        snapshot.name = name
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }
    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 30), file: file, line: line)
        XCTAssertTrue(element.frame.intersects(app.frame), "Control must be inside the actual app viewport", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    func readerBottomChromeAction() -> XCUIElement {
        let more = app.buttons["reader-more-menu"]
        if more.exists { return more }
        // The genuine 9401 compact-window hierarchy exposes UIKit's native
        // bottom overflow instead of the reader's overflowed More item. Use
        // that actual control to measure chrome, never the full-height Toolbar.
        let overflow = app.buttons.matching(identifier: "BottomOverflowBarButtonItem")
        XCTAssertEqual(overflow.count, 1, "The original bottom toolbar must expose one real native overflow action")
        return overflow.firstMatch
    }
    func readerSidebarToggle() -> XCUIElement {
        let custom = app.buttons["reader-host-sidebar-toggle"]
        let native = app.navigationBars.buttons.matching(NSPredicate(format:
            "label IN %@", ["הצגת סרגל הצד", "הסתרת סרגל הצד", "Show Sidebar", "Hide Sidebar"]))
        XCTAssertEqual((custom.exists ? 1 : 0) + native.count, 1,
                       "Use one actual split-view sidebar action; duplicate custom/native toggles are forbidden")
        return custom.exists ? custom : native.firstMatch
    }
    func capture(_ name: String, windowed: Bool = false) {
        let application = app!
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = application.frame
                let landscape = XCUIDevice.shared.orientation.isLandscape
                guard frame.width > 0, frame.height > 0,
                      (windowed || (frame.width > frame.height) == landscape) else { return false }
                let bottomMenu = application.buttons["reader-more-menu"]
                return !bottomMenu.exists || (windowed ? bottomMenu.frame.width > 0 && bottomMenu.frame.height > 0 : frame.contains(bottomMenu.frame))
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 20), .completed,
                       "Capture only after native rotation and the original bottom toolbar settle inside the window")
        // Capture the display rather than XCTest's app-rectangle crop: the
        // iPadOS 27 landscape app crop can retain portrait dimensions and clip
        // the trailing toolbar. Preserve the complete system/window chrome.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let hierarchy = XCTAttachment(string: "appFrame=\(app.frame)\norientation=\(XCUIDevice.shared.orientation.rawValue)\n\(app.debugDescription)")
        hierarchy.name = name + "-ui-tree"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
    func assertReaderHasText() {
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60), "The original TextKit reader must render")
        let application = app!
        let laidOut = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let frame = text.frame
                return frame.width > 80 && frame.height > 80 && frame.minX.isFinite && frame.minY.isFinite
                    && frame.width <= application.frame.width + 1 && frame.height <= application.frame.height + 1
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [laidOut], timeout: 30), .completed,
                       "The actual reader must finish native window reflow before inspecting its pixels")
        let predicate = NSPredicate(format: "value MATCHES %@", "(?s).{31,}")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: text)], timeout: 30), .completed,
                       "Wait for a populated reader; structured diagnostics alone are not text evidence")
        let title = app.staticTexts["reader-header-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertFalse(["", "ספר", "Book 1"].contains(title.label), "A fabricated placeholder is not a genuine loaded book")
        let rendered = text.value as? String ?? ""
        XCTAssertFalse(rendered.contains("Error Domain") || rendered.contains("Content ID not found") || rendered.contains("no such table"), "An error message must not count as book text")
        if TestRenderedHighlightSnapshot.fromJSON(rendered) != nil {
            // Immutable 9401 replaces the native value with diagnostic JSON.
            // Detect actual printed glyphs inside the reader body, excluding
            // headers/toolbars. This does not OCR Hebrew or infer book identity;
            // the canonical title and native screenshots remain separate proof.
            do {
                // The public element screenshot resolves its native window
                // context. App/element coordinates and a full display screenshot
                // diverge once iPadOS places a resized window over the desktop.
                let image = text.screenshot().image
                guard let rawImage = image.cgImage else { XCTFail("The native text screenshot has no pixels"); return }
                let rotated = [.left, .right, .leftMirrored, .rightMirrored].contains(image.imageOrientation)
                let displaySize = CGSize(width: CGFloat(rotated ? rawImage.height : rawImage.width) / image.scale,
                                         height: CGFloat(rotated ? rawImage.width : rawImage.height) / image.scale)
                let format = UIGraphicsImageRendererFormat()
                format.scale = image.scale
                let normalized = UIGraphicsImageRenderer(size: displaySize, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: displaySize))
                }
                let readerFrame = text.frame
                let navigationFrames = app.navigationBars.allElementsBoundByIndex.map { $0.frame }.filter {
                    $0.width > 0 && $0.height > 0 && $0.intersects(readerFrame)
                        && $0.intersection(readerFrame).width > readerFrame.width * 0.5
                }
                let bottomAction = readerBottomChromeAction()
                guard let navigationBottom = navigationFrames.map({ $0.maxY }).max(), bottomAction.exists else {
                    XCTFail("Cannot identify the original native chrome to isolate genuine book pixels"); return
                }
                // UITextView extends behind native bars. Exclude their actual
                // measured frames so title/status/tab labels cannot count as
                // loaded book text when the original value is diagnostic JSON.
                let top = max(readerFrame.minY, navigationBottom) + 12
                // On iPadOS 27 the accessibility Toolbar container spans the
                // whole content area. Its real bottom action has precise bounds.
                let bottom = min(readerFrame.maxY, bottomAction.frame.minY) - 12
                let frame = CGRect(x: 12, y: top - readerFrame.minY,
                                   width: readerFrame.width - 24, height: bottom - top)
                guard frame.width > 0, frame.height > 0 else {
                    XCTFail("The original reader has no visible book body between its native bars"); return
                }
                let pixelsPerPointX = displaySize.width * normalized.scale / readerFrame.width
                let pixelsPerPointY = displaySize.height * normalized.scale / readerFrame.height
                let pixels = CGRect(x: frame.minX * pixelsPerPointX, y: frame.minY * pixelsPerPointY,
                                    width: frame.width * pixelsPerPointX, height: frame.height * pixelsPerPointY)
                let geometry = XCTAttachment(string: "app=\(app.frame)\nreader=\(readerFrame)\nimageSize=\(image.size)\nimageOrientation=\(image.imageOrientation.rawValue)\ndisplaySize=\(displaySize)\nbookPixels=\(pixels)")
                geometry.name = "native-reader-pixel-observation-geometry"
                geometry.lifetime = .keepAlways
                add(geometry)
                guard let crop = normalized.cgImage?.cropping(to: pixels) else {
                    XCTFail("Cannot inspect the actual reader pixels"); return
                }
                let request = VNDetectTextRectanglesRequest()
                request.reportCharacterBoxes = true
                try VNImageRequestHandler(cgImage: crop).perform([request])
                let lines = request.results ?? []
                let body = XCTAttachment(image: UIImage(cgImage: crop))
                body.name = "immutable-baseline-actual-book-body"
                body.lifetime = .keepAlways
                add(body)
                XCTAssertGreaterThanOrEqual(lines.count, 2, "The immutable baseline must display multiple real text lines")
                XCTAssertGreaterThanOrEqual(lines.reduce(0) { $0 + ($1.characterBoxes?.count ?? 0) }, 30,
                                            "A JSON accessibility value or empty/loading reader is not rendered book-text evidence")
            } catch { XCTFail("Could not inspect actual reader text pixels: \(error)") }
        } else {
            XCTAssertFalse(rendered.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
                           "Native reader value must be book text, not diagnostic JSON")
        }
    }

    @MainActor
    func exerciseNativeWindowResize(enabled: Bool) {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: enabled, scenario: "readerDetail")
        assertReaderHasText()
        let originalFrame = app.frame
        let application = app!
        let originalLocator = app.staticTexts["reader-current-locator"].label
        capture(enabled ? "candidate-window-wide" : "baseline-window-wide")
        let restoration = NativeUIRestoration {
            let current = application.frame
            if abs(current.width - originalFrame.width) > 2 || abs(current.height - originalFrame.height) > 2 {
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                // The actual 9401 resize video locates the system window
                // controls at (42, 32) inside the resized native window.
                // Open Apple's controls, then select its public Full Screen
                // action; do not drag using mismatched desktop/app coordinates.
                application.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: 42, dy: 32)).tap()
                let labels = ["Full Screen", "Enter Full Screen", "Zoom", "מסך מלא", "הצג במסך מלא"]
                let predicate = NSPredicate(format: "label IN %@", labels)
                let candidates = [application.buttons, application.menuItems, springboard.buttons, springboard.menuItems]
                var selected = false
                for query in candidates {
                    let action = query.matching(predicate).firstMatch
                    if action.waitForExistence(timeout: 3), action.isHittable {
                        action.tap()
                        selected = true
                        break
                    }
                }
                if !selected {
                    XCTContext.runActivity(named: "Native window controls unavailable") { activity in
                        let tree = XCTAttachment(string: application.debugDescription + "\nSPRINGBOARD\n" + springboard.debugDescription)
                        tree.lifetime = .keepAlways
                        activity.add(tree)
                        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                        screen.lifetime = .keepAlways
                        activity.add(screen)
                    }
                    XCTFail("Cannot restore the actual window through its native Full Screen action")
                    return
                }
                let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    MainActor.assumeIsolated {
                        abs(application.frame.width - originalFrame.width) < 2 && abs(application.frame.height - originalFrame.height) < 2
                    }
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 30), .completed,
                               "Restore the actual window before other baseline/candidate cases")
            }
        }
        addTeardownBlock { await restoration.run() }
        // Apple's iPad windowing gesture: drag the system bottom-right handle.
        // This must change the actual window, not an injected size class/frame.
        let handle = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -12, dy: -12))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
        handle.press(forDuration: 0.5, thenDragTo: destination)
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { application.frame.width < originalFrame.width - 80 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 30), .completed,
                       "The native iPad window must actually resize; a simulated width is not acceptance")
        capture(enabled ? "candidate-window-narrow" : "baseline-window-narrow", windowed: true)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator,
                       "Window reflow must preserve the actual navigation unit")
        XCTAssertTrue(readerBottomChromeAction().exists, "The original bottom toolbar must survive narrow window reflow")
        let geometry = XCTAttachment(string: "wide=\(originalFrame)\nnarrow=\(app.frame)")
        geometry.name = enabled ? "candidate-native-window-geometry" : "baseline-native-window-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        if enabled {
            let field = app.textFields["reader-library-search-field"]
            XCTAssertTrue(field.waitForExistence(timeout: 15))
            XCTAssertTrue(field.isHittable, "The actual library field must remain reachable in the native narrow window")
            field.tap()
            let palette = app.descendants(matching: .any)["reader-library-command-palette"]
            XCTAssertTrue(palette.waitForExistence(timeout: 15))
            capture("candidate-window-narrow-palette", windowed: true)
            palette.textFields.firstMatch.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
            let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
            XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed)
            let beforeInspector = getRenderedHighlightSnapshot()
            XCTAssertNotNil(beforeInspector)
            let study = app.buttons["reader-study-toggle"]
            XCTAssertTrue(study.waitForExistence(timeout: 15), "Original study tools must remain available in a real compact window")
            study.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let inspector = app.descendants(matching: .any)["torah-inspector-panel"]
            XCTAssertTrue(inspector.waitForExistence(timeout: 30))
            XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].exists)
            capture("candidate-window-narrow-original-floating-inspector", windowed: true)
            study.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: inspector)
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 15), .completed)
            assertReaderHasText()
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
            let afterInspector = getRenderedHighlightSnapshot()
            XCTAssertNotNil(afterInspector)
            XCTAssertEqual(afterInspector?.segmentSelectionCount, beforeInspector?.segmentSelectionCount,
                           "Opening the original Inspector in a compact window must not manufacture a book selection")
        }
    }

    func selectStudyGroup(named name: String) {
        let selector = app.segmentedControls["study-group-selector"]
        if selector.exists {
            tap(selector.buttons[name])
        } else {
            // The source's public AdaptiveTabContent can choose its native
            // Menu in a compact sheet/window or accessibility text size.
            tap(app.buttons["study-group-selector"])
            // The native popover is a collection of cells. The underlying
            // overview toolbar also has a button named 'All Tabs'.
            let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label == %@", name))
            XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 15))
            XCTAssertEqual(options.count, 1, "Select the unique real group action in the native popover")
            tap(options.element(boundBy: 0))
        }
    }

    @discardableResult
    func exerciseGlobalHistorySubmission(enabled: Bool) -> String {
        let query = "בדיקת היסטוריה " + UUID().uuidString
        launchReader(enabled: enabled, scenario: "search")
        let globalInput = app.textFields.firstMatch
        tap(globalInput)
        globalInput.typeText(query)
        let start = app.buttons.matching(NSPredicate(format: "label == 'התחל חיפוש' OR label == 'Start Search'")).allElementsBoundByIndex
            .filter { $0.frame.intersects(globalInput.frame.insetBy(dx: -70, dy: -20)) }
        XCTAssertEqual(start.count, 1, "Identify the real input-bar submit action uniquely")
        guard let submit = start.first else { return query }
        tap(submit)
        tap(globalInput)
        // Capture the actual focused global screen even when the following
        // assertion fails, so immutable baseline behavior can be compared.
        capture(enabled ? "candidate-global-search-history" : "baseline-global-search-history")
        let historyRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch
        let historyIsVisible = historyRow.waitForExistence(timeout: 20)
        // Observe only these two known preferences. Never dump all app defaults
        // or seed a history entry: the native submit action remains the writer.
        do {
            let containers = try FileManager.default.contentsOfDirectory(at: workspaceContainerParent(), includingPropertiesForKeys: nil)
            var observations: [[String: Any]] = []
            for container in containers {
                let preference = container.appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
                guard let data = try? Data(contentsOf: preference),
                      let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
                let history = values["SearchHistory"] as? [String] ?? []
                observations.append(["historyCount": history.count, "submittedQueryPersisted": history.contains(query),
                                     "recordSearchHistory": values["recordSearchHistory"] as? Bool ?? true])
            }
            let data = try JSONSerialization.data(withJSONObject: ["matchingPreferenceFiles": observations.count,
                                                                   "observations": observations,
                                                                   "nativeHistoryRowVisible": historyIsVisible], options: [.prettyPrinted, .sortedKeys])
            let diagnostic = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            diagnostic.name = "global-history-native-persistence-diagnostic"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        } catch {
            let diagnostic = XCTAttachment(string: "Read-only history observation failed: \(error)")
            diagnostic.name = "global-history-native-persistence-diagnostic-error"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        XCTAssertTrue(historyIsVisible, "A submitted global query must appear in the original global history")
        XCTAssertTrue(historyRow.isHittable, "The submitted history row must actually be visible and usable above the native keyboard")
        return query
    }
}

final class FaithfulReaderVisualBaselineTests: FaithfulReaderUIBase {
    func testOriginalGlobalSearchHistoryThroughNativeControls() {
        exerciseGlobalHistorySubmission(enabled: false)
    }

    @MainActor
    func testOriginalWindowResizePreservesReader() {
        exerciseNativeWindowResize(enabled: false)
    }

    func testOriginalReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(enabled: false, scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("baseline-reader-theme-\(name)")
        }
    }

    func testOriginalReaderLibrarySearchAnnotationsAndInspectorScreenshots() {
        for scenario in ["catalog", "reader", "readerDetail", "readerTOC", "search", "annotationsList", "studyCommentaries"] {
            launchReader(enabled: false, scenario: scenario)
            XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
            if ["reader", "readerDetail", "readerTOC", "studyCommentaries"].contains(scenario) { assertReaderHasText() }
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                XCUIDevice.shared.orientation = orientation
                capture("baseline-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
            }
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        }
        launchReader(enabled: false, scenario: "readerDetail", language: "en")
        assertReaderHasText()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            capture("baseline-reader-detail-en-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
    }
}

final class FaithfulReaderIPhoneTests: FaithfulReaderUIBase {
    func testIPhoneKeepsOriginalReaderWithEitherIPadFeatureSetting() {
        XCUIDevice.shared.orientation = .portrait
        for enabled in [false, true] {
            launchReader(enabled: enabled)
            assertReaderHasText()
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
            XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
            XCTAssertTrue(app.buttons["reader-more-menu"].exists)
            capture("iphone-original-reader-ipad-flag-\(enabled)")
            if enabled && ProcessInfo.processInfo.environment["FAITHFUL_BASELINE"] != "true" {
                tap(app.buttons["reader-book-tabs-overview"])
                let overview = app.descendants(matching: .any)["study-groups-overview"]
                XCTAssertTrue(overview.waitForExistence(timeout: 20))
                let toggle = app.buttons["study-tabs-layout-toggle"]
                XCTAssertTrue(toggle.waitForExistence(timeout: 15))
                if toggle.label == "תצוגת רשת" { tap(toggle) }
                let grid = overview.collectionViews.cells.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")).firstMatch
                XCTAssertTrue(grid.waitForExistence(timeout: 15))
                XCTAssertGreaterThan(grid.frame.width, 0)
                XCTAssertGreaterThanOrEqual(grid.frame.minX, app.frame.minX)
                XCTAssertLessThanOrEqual(grid.frame.maxX, app.frame.maxX)
                capture("iphone-compact-original-tab-grid")
                tap(toggle)
                XCTAssertTrue(overview.collectionViews.cells.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")).firstMatch.waitForExistence(timeout: 15))
                capture("iphone-compact-original-tab-list")
                tap(app.buttons["סיום"])
                assertReaderHasText()
                XCTAssertFalse(app.descendants(matching: .any)["reader-document-tabs"].exists)
            }
        }
    }
}

/// Selected separately after CoreSimulator confirms the largest text setting.
final class FaithfulReaderLargeTextTests: FaithfulReaderUIBase {
    func testOriginalReaderAndPublicGroupSelectorRemainUsableAtLargeTextSize() {
        let baseline = ProcessInfo.processInfo.environment["FAITHFUL_BASELINE"] == "true"
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(enabled: !baseline)
        assertReaderHasText()
        capture(baseline ? "baseline-large-text-reader" : "candidate-large-text-reader")
        if baseline {
            XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        } else {
            tap(app.buttons["כל הכרטיסיות"])
            XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
            // The original safe AdaptiveTabContent uses a native menu for
            // accessibility text sizes. It must still expose real membership.
            tap(app.buttons["study-group-selector"])
            XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 10))
            capture("candidate-large-text-group-menu")
        }
    }
}

final class FaithfulReaderUIAcceptanceTests: FaithfulReaderUIBase {
    @MainActor
    func testOriginalLibraryMenusSelectionSettingsAndBookInfoRemainUsable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(language: "en")
        assertReaderHasText()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !libraryDot.exists || !libraryDot.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryDot)
        let library = app.otherElements["library-column"]
        XCTAssertTrue(library.waitForExistence(timeout: 15))
        let bar = app.navigationBars["Library"]
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Category"])
        let categoryLabels = Set(library.staticTexts.allElementsBoundByIndex.map { $0.label })
        XCTAssertFalse(categoryLabels.isEmpty, "Observe the real canonical library tree")
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Author"])
        let regrouped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let authors = Set(library.staticTexts.allElementsBoundByIndex.map { $0.label })
                return !authors.isEmpty && authors != categoryLabels
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [regrouped], timeout: 30), .completed,
                       "The original grouping action must actually change the library's visible membership")
        tap(bar.buttons["Group By"])
        tap(app.collectionViews.cells.buttons["Category"])
        let downloaded = bar.buttons["Downloaded"]
        if downloaded.exists {
            // The original control is conditional on bundle mode. Exercise
            // its real native state only where the original source offers it.
            let selected = downloaded.isSelected
            let value = downloaded.value as? String
            tap(downloaded)
            XCTAssertTrue(downloaded.isSelected != selected || (downloaded.value as? String) != value)
            tap(downloaded)
            XCTAssertEqual(downloaded.isSelected, selected)
            XCTAssertEqual(downloaded.value as? String, value)
        }
        tap(bar.buttons["Library Options"])
        let options = app.collectionViews.containing(.button, identifier: "Select…").firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 15))
        XCTAssertEqual(options.cells.buttons.count, 3, "Retain original Select, book-update and import actions")
        tap(options.cells.buttons["Select…"])
        XCTAssertTrue(bar.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(bar.buttons["Delete"].exists)
        XCTAssertFalse(bar.buttons["Delete"].isEnabled, "No unselected book may be deleted")
        capture("candidate-original-library-selection-actions")
        tap(bar.buttons["Done"])
        tap(app.buttons["main-settings-button"])
        XCTAssertTrue(app.buttons["settings-done-button"].waitForExistence(timeout: 15))
        capture("candidate-original-settings")
        tap(app.buttons["settings-done-button"])
        tap(app.buttons["Book Info"])
        let close = app.navigationBars.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 30))
        XCTAssertTrue(app.segmentedControls.firstMatch.exists, "The genuine unified book-info view must load")
        capture("candidate-original-book-info")
        tap(close)
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, originalTitle)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        XCTAssertTrue(app.buttons["reader-more-menu"].exists)
    }

    func testOriginalBottomTOCActionOpensContentsFromLibraryPage() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let libraryPage = app.buttons["reader-sidebar-page-0"]
        if !libraryPage.exists || !libraryPage.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryPage)
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let readerWidth = app.textViews["reader-text"].frame.width
        tap(app.buttons["reader-more-menu"])
        tap(app.buttons["reader-toc-toggle"])
        let contentsPage = app.buttons["reader-sidebar-page-1"]
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: contentsPage)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed,
                       "The original TOC action must select Contents, rather than hiding an open Library page")
        XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
        XCTAssertTrue(app.frame.contains(contentsPage.frame), "Contents must actually remain on screen")
        XCTAssertEqual(app.textViews["reader-text"].frame.width, readerWidth, accuracy: 1)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        capture("candidate-original-bottom-toc-action")
    }

    @MainActor
    func testNativeVoiceOverSpeaksRealOverviewAndPaletteControls() throws {
        guard #available(iOS 27.0, *) else {
            XCTFail("The required iPadOS 27 VoiceOver service is unavailable"); return
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let bookTitle = app.staticTexts["reader-header-title"].label
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        addTeardownBlock {
            try await MainActor.run {
                let service = XCUIDevice.shared.voiceOverService
                if wasEnabled { if !service.isEnabled { XCTAssertNoThrow(try service.enable()) } }
                else { XCTAssertNoThrow(try service.disable()) }
            }
        }

        @MainActor
        func assertSpoken(_ expected: [String], name: String) throws {
            if !service.isEnabled { try service.enable() }
            XCTAssertTrue(service.isEnabled, "VoiceOver itself must actually run")
            var speech: [String] = []
            // Enabling VoiceOver can focus the Done action rather than the
            // first RTL toolbar control. Forward navigation need not wrap;
            // exercise both native directions before declaring a label absent.
            for forward in [true, false] {
                var previous: String?
                var repeats = 0
                for _ in 0..<80 {
                    let utterance = try (forward ? service.moveForward() : service.moveBackward()).utterance
                    speech.append(utterance)
                    XCTContext.runActivity(named: name) { activity in
                        let output = XCTAttachment(string: utterance)
                        output.name = name + "-\(speech.count)"
                        output.lifetime = .keepAlways
                        activity.add(output)
                    }
                    if expected.allSatisfy({ phrase in speech.contains { $0.contains(phrase) } }) { break }
                    repeats = previous == utterance ? repeats + 1 : 0
                    previous = utterance
                    if repeats >= 4 { break }
                }
                if expected.allSatisfy({ phrase in speech.contains { $0.contains(phrase) } }) { break }
            }
            for phrase in expected {
                XCTAssertTrue(speech.contains { $0.contains(phrase) }, "Actual VoiceOver speech must include \(phrase)")
            }
            // Return to ordinary XCTest pointer/touch interaction between
            // surfaces. Never substitute an accessibility audit for speech.
            try service.disable()
        }

        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        try assertSpoken(["סיום", "פעולות בקבוצת הכרטיסיות", bookTitle], name: "candidate-native-voiceover-overview-speech")
        tap(app.buttons["סיום"])
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        XCTAssertTrue(palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch.waitForExistence(timeout: 30))
        try assertSpoken(["בראשית", "Clear search"], name: "candidate-native-voiceover-palette-speech")
    }

    func testActualSidecarWriteFailureRollsBackVisibleGroupAndRecovers() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let originalTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        let sidecar = try workspaceSidecarURL()
        let saved = sidecar.appendingPathExtension("ui-failure-original")
        let originalBytes = try Data(contentsOf: sidecar)
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.path))
        // Block only this UUID-scoped test sidecar's atomic destination. The
        // canonical session, corpus, notes and every other sidecar stay intact.
        try FileManager.default.moveItem(at: sidecar, to: saved)
        addTeardownBlock {
            if FileManager.default.fileExists(atPath: saved.path) {
                if FileManager.default.fileExists(atPath: sidecar.path) {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: sidecar.path)
                    XCTAssertTrue(contents.isEmpty, "Only remove the empty directory created by this test")
                    guard contents.isEmpty else { return }
                    try FileManager.default.removeItem(at: sidecar)
                }
                try FileManager.default.moveItem(at: saved, to: sidecar)
            }
        }
        try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: false)
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let prompt = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.textFields.firstMatch.typeText("קבוצה שאסור לשמור")
        tap(prompt.buttons["שמירה"])
        let error = app.alerts["לא ניתן לשנות את סביבת הלימוד"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "The actual atomic-write error must be surfaced")
        capture("candidate-actual-sidecar-write-failure")
        tap(error.buttons["אישור"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15), "Failure must retain the original group's real document")
        XCTAssertEqual(try Data(contentsOf: saved), originalBytes, "The pre-failure bytes must remain intact")
        try FileManager.default.removeItem(at: sidecar)
        try FileManager.default.moveItem(at: saved, to: sidecar)
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator)
        // Reopening synchronizes through the same real persistence path again.
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts[originalTitle].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["לא ניתן לשנות את סביבת הלימוד"].exists)
        XCTAssertNoThrow(try Data(contentsOf: sidecar))
        capture("candidate-sidecar-write-recovery")
    }

    func testFeatureOffCreatesNoSidecarAndPreservesAnExistingWorkspace() throws {
        let containers = try workspaceContainerParent()
        launchReader(enabled: false)
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        let originalHighlights = try XCTUnwrap(getRenderedHighlightSnapshot())
        capture("candidate-before-workspace-migration-original-reader")
        app.terminate()
        XCTAssertTrue(matchingTestSidecars(in: containers, namespace: workspaceNamespace).isEmpty,
                      "Disabled startup/shutdown must not create workspace state in any installed app container")
        launchReader()
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["chavrusa-reader-host"].waitForExistence(timeout: 30))
        let migratedHighlights = try XCTUnwrap(getRenderedHighlightSnapshot())
        XCTAssertEqual(migratedHighlights.searchHighlightCount, originalHighlights.searchHighlightCount)
        XCTAssertEqual(migratedHighlights.annotationHighlightCount, originalHighlights.annotationHighlightCount)
        XCTAssertEqual(migratedHighlights.segmentSelectionCount, originalHighlights.segmentSelectionCount,
                       "Enabling the workspace must not create a fake paragraph selection")
        capture("candidate-after-workspace-migration-original-reader")
        let sidecar = try workspaceSidecarURL()
        app.terminate()
        let enabledBytes = try Data(contentsOf: sidecar)
        launchReader(enabled: false)
        assertReaderHasText()
        XCTAssertFalse(app.descendants(matching: .any)["chavrusa-reader-host"].exists)
        XCTAssertFalse(app.textFields["reader-library-search-field"].exists)
        capture("candidate-disabled-original-reader")
        app.terminate()
        XCTAssertEqual(try Data(contentsOf: workspaceSidecarURL()), enabledBytes,
                       "Disabled startup/shutdown must leave an existing workspace byte-identical")
    }

    func testPointerHoverClickAndHardwareKeyboardDismissal() {
        XCTAssertTrue(XCUIDevice.shared.supportsPointerInteraction,
                      "The required iPad Simulator must support real pointer events")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let field = app.textFields["reader-library-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 30))
        let originalFieldFrame = field.frame
        let fieldPoint = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldPoint.hover()
        capture("candidate-pointer-over-compact-search")
        fieldPoint.click()
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        input.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: palette)
        XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed,
                       "The original palette's Escape handler must dismiss through keyboard focus")
        XCTAssertEqual(field.value as? String, "בראשית", "Collapse must retain the canonical library query")
        let restoredFieldFrame = field.frame
        XCTAssertEqual(restoredFieldFrame.minX, originalFieldFrame.minX, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.minY, originalFieldFrame.minY, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.width, originalFieldFrame.width, accuracy: 1)
        XCTAssertEqual(restoredFieldFrame.height, originalFieldFrame.height, accuracy: 1)
        fieldPoint.click()
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let resultPoint = result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        resultPoint.hover()
        capture("candidate-pointer-over-library-result")
        resultPoint.click()
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
    }

    func testGroupCopyMoveRenameAndDeleteThroughRealMenus() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let bookTitle = app.staticTexts["reader-header-title"].label
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let nameAlert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        nameAlert.textFields.firstMatch.typeText("יעד העברה")
        tap(nameAlert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        let card = app.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "tab-switcher-", bookTitle)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.press(forDuration: 1)
        tap(app.buttons["העתקה לקבוצה"])
        tap(app.collectionViews.cells.buttons["יעד העברה"])
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Copy must create a real document card in its destination")
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        tap(overview.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ AND label CONTAINS %@", "סגור ", bookTitle)).firstMatch)
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Closing the copied document must preserve its source")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.press(forDuration: 1)
        tap(app.buttons["העברה לקבוצה"])
        tap(app.collectionViews.cells.buttons["יעד העברה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Move must remove the source card")
        selectStudyGroup(named: "יעד העברה")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["שינוי שם הקבוצה"])
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 10))
        let nameField = nameAlert.textFields.firstMatch
        nameField.tap()
        nameField.press(forDuration: 1)
        let selectAll = app.menuItems.matching(NSPredicate(format: "label == 'בחר הכול' OR label == 'Select All'")).firstMatch
        if selectAll.exists { selectAll.tap() }
        else {
            let selectAllButton = app.buttons.matching(NSPredicate(format: "label == 'בחר הכול' OR label == 'Select All'")).firstMatch
            tap(selectAllButton)
        }
        nameField.typeText("יעד ששמו עודכן")
        XCTAssertEqual(nameField.value as? String, "יעד ששמו עודכן")
        tap(nameAlert.buttons["שמירה"])
        selectStudyGroup(named: "יעד ששמו עודכן")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Rename must preserve membership")
        capture("candidate-group-move-copy-rename")
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["מחיקת קבוצה"])
        // The second tap is the native destructive confirmation, not the Menu.
        tap(app.buttons["מחיקת קבוצה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        selectStudyGroup(named: "כל הכרטיסיות")
        XCTAssertFalse(card.exists)
        capture("candidate-deleted-group-retains-replacement")
    }

    @MainActor
    func testSystemReduceMotionKeepsOriginalPaletteUsable() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        let accessibility = settings.staticTexts["Accessibility"].firstMatch
        for _ in 0..<6 {
            if accessibility.exists && accessibility.isHittable { break }
            settings.swipeUp()
        }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 15))
        accessibility.tap()
        let motion = settings.staticTexts["Motion"].firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 15))
        motion.tap()
        let toggle = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        let wasEnabled = (toggle.value as? String) == "1"
        if !wasEnabled { toggle.tap() }
        let restoration = NativeUIRestoration {
            settings.activate()
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            if ((toggle.value as? String) == "1") != wasEnabled { toggle.tap() }
            let restored = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", wasEnabled ? "1" : "0"), object: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed)
            settings.terminate()
        }
        addTeardownBlock { await restoration.run() }
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 15), .completed,
                       "The actual system preference must be enabled")
        let reduced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { UIAccessibility.isReduceMotionEnabled }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reduced], timeout: 15), .completed,
                       "The native accessibility setting must actually reach this Simulator")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.typeText("בראשית")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "בראשית")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        capture("candidate-system-reduce-motion-palette")
        tap(book)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        XCTAssertTrue(app.textFields["reader-library-search-field"].exists)
    }

    @MainActor
    func testWindowResizePreservesOriginalReaderAndSearch() {
        exerciseNativeWindowResize(enabled: true)
    }

    func testNewManagementScreensExposeMeaningfulAccessibilityDescriptions() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.descendants(matching: .any)["study-groups-overview"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["פרופיל לימוד חדש"])
        XCTAssertTrue(app.textFields["שם הפרופיל"].waitForExistence(timeout: 15))
        try app.performAccessibilityAudit(for: .sufficientElementDescription)
        tap(app.buttons["ביטול"])
    }

    func testCandidateReaderThemes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        for (name, index) in [("light", 0), ("dark", 4), ("sepia", 1)] {
            launchReader(scenario: "readerDetail", background: index)
            assertReaderHasText()
            capture("candidate-reader-theme-\(name)")
        }
    }

    func testEnglishReaderAndOriginalPaletteInLeftToRightLayout() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", language: "en")
        assertReaderHasText()
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            capture("candidate-reader-detail-en-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        tap(app.textFields["reader-library-search-field"])
        XCTAssertTrue(app.descendants(matching: .any)["reader-library-command-palette"].waitForExistence(timeout: 15))
        capture("candidate-command-palette-en")
    }

    func testCandidateGlobalSearchLandscapeMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("search", orientation: .landscapeLeft)
    }
    func testCandidateGlobalSearchPortraitMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("search", orientation: .portrait)
    }
    func testCandidateAnnotationsLandscapeMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("annotationsList", orientation: .landscapeLeft)
    }
    func testCandidateAnnotationsPortraitMatchesOriginalNavigation() {
        exerciseUnchangedOriginalScreen("annotationsList", orientation: .portrait)
    }
    func testCandidateTrimmedOriginalInspectorLandscape() {
        exerciseTrimmedOriginalInspector(orientation: .landscapeLeft)
    }
    func testCandidateTrimmedOriginalInspectorPortrait() {
        exerciseTrimmedOriginalInspector(orientation: .portrait)
    }

    private func exerciseUnchangedOriginalScreen(_ scenario: String, orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        launchReader(enabled: false, scenario: scenario)
        capture("candidate-flags-off-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
        let originalBars = app.navigationBars.allElementsBoundByIndex.map { ($0.identifier, $0.frame) }
            .sorted { $0.0 < $1.0 }
        XCTAssertFalse(originalBars.isEmpty, "Observe the actual original navigation geometry")
        launchReader(scenario: scenario)
        capture("candidate-\(scenario)-\(orientation.isLandscape ? "landscape" : "portrait")")
        let candidateBars = app.navigationBars.allElementsBoundByIndex.map { ($0.identifier, $0.frame) }
            .sorted { $0.0 < $1.0 }
        XCTAssertEqual(candidateBars.count, originalBars.count)
        for (original, candidate) in zip(originalBars, candidateBars) {
            XCTAssertEqual(candidate.0, original.0)
            XCTAssertEqual(candidate.1.minX, original.1.minX, accuracy: 1)
            XCTAssertEqual(candidate.1.minY, original.1.minY, accuracy: 1,
                           "A viewer-only document strip must not shift another global tab's native navigation")
            XCTAssertEqual(candidate.1.width, original.1.width, accuracy: 1)
            XCTAssertEqual(candidate.1.height, original.1.height, accuracy: 1)
        }
    }

    private func exerciseTrimmedOriginalInspector(orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        launchReader(scenario: "studyCommentaries")
        XCTAssertTrue(findTabButton(hebrew: "ספר", english: "Library").waitForExistence(timeout: 60))
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-panel"].waitForExistence(timeout: 30), "The original Inspector must actually be presented")
        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-tools"].waitForExistence(timeout: 15), "Original study-tool actions must remain available")
        XCTAssertFalse(app.staticTexts["כלי לימוד"].exists, "The redundant visual study-tools heading must be removed")
        XCTAssertFalse(app.staticTexts["קטע נבחר"].exists, "The redundant visual selected-segment heading must be removed")
        capture("candidate-studyCommentaries-\(orientation.isLandscape ? "landscape" : "portrait")")
    }

    @MainActor
    func testSidebarPreservesOriginalTextKitViewport() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        capture("candidate-reader-landscape")
        let tocDot = app.buttons["reader-sidebar-page-1"]
        let libraryDot = app.buttons["reader-sidebar-page-0"]
        if !tocDot.exists || !tocDot.frame.intersects(app.frame) || tocDot.frame.isEmpty {
            tap(readerSidebarToggle())
        }
        let originalReaderWidth = app.textViews["reader-text"].frame.width
        let originalLocator = app.staticTexts["reader-current-locator"].label
        let library = app.otherElements["library-column"]
        XCTAssertTrue(library.waitForExistence(timeout: 15))
        library.swipeUp()
        @MainActor func visibleLibraryLabels() -> [String] {
            library.staticTexts.allElementsBoundByIndex.filter {
                !$0.frame.isEmpty && $0.frame.intersects(library.frame)
            }.map { $0.label }
        }
        let originalLibraryLabels = visibleLibraryLabels()
        XCTAssertFalse(originalLibraryLabels.isEmpty, "Observe the actual scrolled library before changing sidebar pages")
        let originalViewport = try viewport()
        for _ in 0..<20 {
            tap(tocDot)
            XCTAssertTrue(app.descendants(matching: .any)["toc-column"].exists)
            tap(libraryDot)
            XCTAssertTrue(app.descendants(matching: .any)["library-column"].exists)
            XCTAssertEqual(visibleLibraryLabels(), originalLibraryLabels,
                           "Changing only the sidebar page must retain the original library's visible rows and scroll")
            XCTAssertEqual(app.textViews["reader-text"].frame.width, originalReaderWidth, accuracy: 1, "Sidebar page changes must preserve reader width")
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, originalLocator, "Sidebar page changes must not navigate the book")
            let actual = try viewport()
            XCTAssertEqual(actual.object, originalViewport.object, "The original TextKit view must survive sidebar page changes")
            XCTAssertEqual(actual.source, originalViewport.source, "The first visible source character must remain anchored")
            XCTAssertEqual(actual.offset, originalViewport.offset, accuracy: 1, "Sidebar page changes must not shift the book viewport")
        }
        let pager = app.descendants(matching: .any)["reader-sidebar-pager"]
        for _ in 0..<20 {
            let wasContents = tocDot.isSelected
            func changedPage() -> XCTNSPredicateExpectation {
                XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    MainActor.assumeIsolated { tocDot.isSelected != wasContents }
                }, object: nil)
            }
            pager.swipeLeft()
            // Wait for the real page transition before trying the opposite
            // RTL direction; an immediate reverse gesture can undo it.
            if XCTWaiter.wait(for: [changedPage()], timeout: 3) != .completed {
                pager.swipeRight()
                XCTAssertEqual(XCTWaiter.wait(for: [changedPage()], timeout: 15), .completed,
                               "A genuine sidebar swipe must change the selected page")
            }
            XCTAssertNotEqual(tocDot.isSelected, wasContents, "A sidebar swipe must change pages without changing the reader")
        }
        capture("candidate-library-sidebar")
        tap(tocDot)
        capture("candidate-toc-sidebar")
        tap(libraryDot)
    }

    func testSourceToolbarPaletteAndOverview() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let initialTitle = app.staticTexts["reader-header-title"].label
        XCTAssertFalse(initialTitle.isEmpty)
        _ = readerSidebarToggle()
        XCTAssertTrue(app.descendants(matching: .any)["reader-document-tabs"].waitForExistence(timeout: 30))
        let field = app.textFields["reader-library-search-field"]
        tap(field)
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 15))
        let paletteField = palette.textFields.firstMatch
        XCTAssertTrue(paletteField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15), "Capture the genuine full software keyboard, not a keyboard-free preview")
        XCTAssertGreaterThan(app.keyboards.firstMatch.frame.height, 160,
                             "A keyboard accessory strip alone does not prove the full software keyboard is visible")
        paletteField.typeText("בראשית")
        let result = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "בראשית", initialTitle)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Actual canonical-library books must appear in original CommandPalette")
        capture("candidate-command-palette-keyboard")
        tap(result)
        assertReaderHasText()
        XCTAssertFalse(palette.exists)
        capture("candidate-library-opened-reader-no-fixture-selection")
        tap(app.buttons["כל הכרטיסיות"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
        let layoutToggle = app.buttons["study-tabs-layout-toggle"]
        XCTAssertTrue(layoutToggle.waitForExistence(timeout: 15))
        if layoutToggle.label == "תצוגת רשת" { tap(layoutToggle) }
        XCTAssertTrue(overview.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")
        ).firstMatch.waitForExistence(timeout: 15), "The original DuckDuckGo grid cell must render the open book")
        capture("candidate-all-tabs-public-fallback")
        tap(app.buttons["study-tabs-layout-toggle"])
        XCTAssertTrue(overview.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "tab-switcher-list-cell-")
        ).firstMatch.waitForExistence(timeout: 15), "The original DuckDuckGo list cell must replace the grid cell")
        capture("candidate-all-tabs-list")
        tap(layoutToggle)
        let card = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let closedID = try XCTUnwrap(UUID(uuidString: String(card.identifier.dropFirst("tab-switcher-grid-cell-".count))))
        let sidecarURL = try workspaceSidecarURL()
        func persistedTabs(containing id: UUID) throws -> (groupID: String, ids: Set<UUID>)? {
            let value = try JSONSerialization.jsonObject(with: Data(contentsOf: sidecarURL)) as? [String: Any]
            let groups = value?["groups"] as? [[String: Any]] ?? []
            for group in groups {
                let tabs = group["tabs"] as? [[String: Any]] ?? []
                let ids = Set(tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:)))
                if ids.contains(id), let groupID = group["id"] as? String { return (groupID, ids) }
            }
            return nil
        }
        let original = try XCTUnwrap(persistedTabs(containing: closedID))
        let closedCard = overview.collectionViews.cells["tab-switcher-grid-cell-" + closedID.uuidString]
        @Sendable func persistedOrder() -> [UUID]? {
            guard let bytes = try? Data(contentsOf: sidecarURL),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]],
                  let group = groups.first(where: { $0["id"] as? String == original.groupID }),
                  let tabs = group["tabs"] as? [[String: Any]] else { return nil }
            return tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:))
        }
        let beforeDrag = try XCTUnwrap(persistedOrder())
        let gridCells = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "tab-switcher-grid-cell-"))
        XCTAssertGreaterThanOrEqual(gridCells.count, 2, "Open two distinct canonical books before testing actual source drag reorder")
        let destination = gridCells.element(boundBy: gridCells.count - 1)
        closedCard.press(forDuration: 0.6, thenDragTo: destination)
        let reordered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let order = persistedOrder() else { return false }
            return Set(order) == Set(beforeDrag) && order != beforeDrag
                && order.filter { $0 != closedID } == beforeDrag.filter { $0 != closedID }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reordered], timeout: 15), .completed,
                       "A real source drag must persist a new order without losing IDs or disturbing the other books")
        capture("candidate-overview-original-drag-reorder")
        closedCard.swipeRight()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: closedCard)
        XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 15), .completed,
                       "The source RTL swipe must remove the exact original card")
        let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let bytes = try? Data(contentsOf: sidecarURL),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]],
                  let group = groups.first(where: { $0["id"] as? String == original.groupID }),
                  let tabs = group["tabs"] as? [[String: Any]] else { return false }
            let ids = Set(tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }.compactMap(UUID.init(uuidString:)))
            return ids == original.ids.subtracting([closedID])
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 15), .completed,
                       "Swipe close must persist the exact surviving document IDs")
        capture("candidate-overview-original-swipe-close")
        tap(app.buttons["סיום"])
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        XCTAssertTrue(app.descendants(matching: .any)["study-profile-management"].waitForExistence(timeout: 15))
        capture("candidate-profile-management")
    }

    func testReaderDocumentAndGlobalBarsCollapseAndRestoreOnManualScroll() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        assertReaderHasText()
        let text = app.textViews["reader-text"]
        let originalObject = try viewport().object
        let strip = app.descendants(matching: .any)["reader-document-tabs"]
        XCTAssertTrue(strip.waitForExistence(timeout: 30))

        text.swipeUp()
        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: strip
        )
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 15), .completed,
                       "A deliberate downward reader scroll must collapse the document strip")
        let globalHistory = findTabButton(hebrew: "היסטוריה", english: "History")
        XCTAssertTrue(!globalHistory.exists || !globalHistory.isHittable,
                      "The system global tab bar should collapse with reader chrome when supported")

        XCTAssertEqual(try viewport().object, originalObject, "Collapsing chrome must retain the original TextKit instance")
        capture("candidate-reader-scroll-chrome-hidden")
        text.swipeDown()
        XCTAssertTrue(strip.waitForExistence(timeout: 15),
                      "Upward reader scrolling must restore the document strip")
        XCTAssertTrue(findTabButton(hebrew: "היסטוריה", english: "History").waitForExistence(timeout: 15))

        text.swipeUp()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: strip
        )], timeout: 15), .completed)
        tap(readerSidebarToggle())
        XCTAssertTrue(strip.waitForExistence(timeout: 15),
                      "Opening the sidebar must restore reader navigation chrome")
        XCTAssertEqual(try viewport().object, originalObject, "Restoring chrome must retain the original TextKit instance")
        capture("candidate-reader-scroll-chrome-restored")
    }

    func testTwentyGlobalTabRoundTripsKeepOriginalReaderAndBottomBar() {
        launchReader()
        assertReaderHasText()
        for _ in 0..<20 {
            for (hebrew, english) in [("היסטוריה", "History"), ("חיפוש", "Search"), ("מוסרים", "Narrators")] {
                tap(findTabButton(hebrew: hebrew, english: english))
                tap(findTabButton(hebrew: "ספר", english: "Library"))
                assertReaderHasText()
                XCTAssertTrue(app.buttons["reader-more-menu"].exists, "Original bottom toolbar must remain present after every global-tab round trip")
            }
        }
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertReaderHasText()
            capture("candidate-reader-\(orientation.isLandscape ? "landscape" : "portrait")")
        }
    }

    func testNewEmptyGroupAndRelaunchPersistence() throws {
        launchReader()
        assertReaderHasText()
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("קבוצת בדיקה")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        capture("candidate-empty-group")
        tap(app.buttons["סיום"])
        try attachWorkspaceSnapshot("empty-group-sidecar-before-cold-launch")
        app.terminate()
        launchReader(scenario: "catalog")
        XCTAssertTrue(app.buttons["כל הכרטיסיות"].waitForExistence(timeout: 30))
        let emptyReader = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.textViews["reader-text"])
        let restored = XCTWaiter.wait(for: [emptyReader], timeout: 30)
        try attachWorkspaceSnapshot("empty-group-sidecar-after-cold-launch")
        XCTAssertEqual(restored, .completed, "Wait for the actual asynchronous sidecar projection, retaining the empty-reader requirement")
        XCTAssertFalse(app.textViews["reader-text"].exists, "The empty sidecar group must suppress stale legacy-session resurrection")
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15), "Empty selection must survive app relaunch without importing old tabs again")
        XCTAssertTrue(app.descendants(matching: .any)["study-group-selector"].exists)
    }

    func testHistoryRemainsGlobalAndIsAbsentFromBookSearch() {
        let query = exerciseGlobalHistorySubmission(enabled: true)
        app.terminate()
        launchReader()
        assertReaderHasText()
        let bottomToolbar = app.toolbars.containing(.button, identifier: "reader-more-menu").firstMatch
        let bookSearch = bottomToolbar.buttons.matching(NSPredicate(format: "label == 'חיפוש' OR label == 'Search'")).firstMatch
        tap(bookSearch)
        let bookInput = app.searchFields.firstMatch
        tap(bookInput)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", query)).firstMatch.exists,
                       "The same genuine history query must not be offered inside book-local search")
        capture("candidate-book-search-without-global-history")
    }

    func testSameBookRetainsIndependentLocationsAcrossGroupsAndRelaunch() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        let locator = app.staticTexts["reader-current-locator"]
        let initial = locator.label
        XCTAssertFalse(initial.isEmpty)
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה מהכרטיסיות הנוכחיות"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("מיקום שני")
        tap(alert.buttons["שמירה"])
        selectStudyGroup(named: "מיקום שני")
        tap(app.buttons["סיום"])
        assertReaderHasText()
        XCTAssertEqual(locator.label, initial)
        let next = app.buttons.matching(NSPredicate(format: "label == 'העמוד הבא' OR label == 'Next Page'")).firstMatch
        XCTAssertTrue(next.isEnabled, "The genuine fixture book must have another navigation unit")
        tap(next)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", initial), object: locator)], timeout: 30), .completed)
        let second = locator.label
        XCTAssertFalse(second.isEmpty)
        for _ in 0..<20 {
            for (name, expected) in [("כל הכרטיסיות", initial), ("מיקום שני", second)] {
                tap(app.buttons["כל הכרטיסיות"])
                selectStudyGroup(named: name)
                tap(app.buttons["סיום"])
                assertReaderHasText()
                XCTAssertEqual(locator.label, expected, "Each group must restore its own actual canonical locator")
            }
        }
        capture("candidate-independent-group-locations")
        try attachWorkspaceSnapshot("independent-locations-sidecar-before-cold-launch")
        app.terminate()
        launchReader(scenario: "catalog")
        assertReaderHasText()
        let restored = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", second), object: app.staticTexts["reader-current-locator"])], timeout: 30)
        try attachWorkspaceSnapshot("independent-locations-sidecar-after-cold-launch")
        XCTAssertEqual(restored, .completed, "The asynchronously hydrated reader must reach the exact independently retained locator")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, second, "The selected group's actual locator must survive cold relaunch")
    }

    func testThreeProfilesWithThreeGroupsThroughNativeManagement() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader()
        assertReaderHasText()
        tap(app.buttons["study-profile-menu"])
        tap(app.buttons["ניהול פרופילי לימוד"])
        for name in ["לימוד א", "לימוד ב"] {
            tap(app.buttons["פרופיל לימוד חדש"])
            let field = app.textFields["שם הפרופיל"]
            tap(field)
            field.typeText(name)
            tap(app.buttons["שמירה"])
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10))
        }
        tap(app.buttons["סיום"])
        for profileName in ["אישי", "לימוד א", "לימוד ב"] {
            tap(app.buttons["study-profile-menu"])
            tap(app.buttons[profileName])
            tap(app.buttons["כל הכרטיסיות"])
            for suffix in ["א", "ב"] {
                tap(app.buttons["study-group-actions-menu"])
                tap(app.buttons["קבוצה ריקה"])
                let alert = app.alerts["שם קבוצת הכרטיסיות"]
                XCTAssertTrue(alert.waitForExistence(timeout: 10))
                alert.textFields.firstMatch.typeText("\(profileName) \(suffix)")
                tap(alert.buttons["שמירה"])
                XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
            }
            let selector = app.segmentedControls["study-group-selector"]
            let expected = ["כל הכרטיסיות", "\(profileName) א", "\(profileName) ב"]
            if selector.exists {
                XCTAssertEqual(selector.buttons.count, 3)
                for name in expected { XCTAssertTrue(selector.buttons[name].exists) }
            } else {
                // A native page sheet has compact traits even on a wide iPad.
                // Inspect the original public fallback's actual menu membership.
                let menu = app.buttons["study-group-selector"]
                XCTAssertTrue(menu.waitForExistence(timeout: 15))
                let selected = menu.value as? String
                XCTAssertEqual(selected, "\(profileName) ב")
                tap(menu)
                let options = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label IN %@", expected))
                XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 15))
                XCTAssertEqual(options.count, 3)
                for name in expected { XCTAssertEqual(options.matching(NSPredicate(format: "label == %@", name)).count, 1) }
                tap(options.matching(NSPredicate(format: "label == %@", "\(profileName) ב")).element(boundBy: 0))
            }
            capture("candidate-profile-groups-\(profileName)")
            tap(app.buttons["סיום"])
        }
    }
}

/// Run only against a Release binary over the full native production install.
/// No smoke scenario, bootstrap bypass, feature override or test namespace.
final class FaithfulProductionReleaseTests: FaithfulReaderUIBase {
    private var observedProductionWorkspace: (url: URL, groupID: UUID)?

    private static func documentCount(in url: URL, groupID: UUID) -> Int? {
        guard let bytes = try? Data(contentsOf: url),
              let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              let groups = value["groups"] as? [[String: Any]],
              let group = groups.first(where: { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == groupID }),
              let tabs = group["tabs"] as? [[String: Any]] else { return nil }
        return tabs.count
    }

    private static func productionWorkspaces(in containers: URL, containing documentID: UUID) -> [(url: URL, groupID: UUID)] {
        guard let directories = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: nil) else { return [] }
        return directories.flatMap { directory -> [(url: URL, groupID: UUID)] in
            let file = directory.appendingPathComponent("Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json")
            guard let bytes = try? Data(contentsOf: file),
                  let value = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
                  let groups = value["groups"] as? [[String: Any]] else { return [] }
            return groups.compactMap { group in
                guard let id = (group["id"] as? String).flatMap(UUID.init(uuidString:)),
                      let tabs = group["tabs"] as? [[String: Any]],
                      tabs.contains(where: { tab in
                          let session = tab["session"] as? [String: Any]
                          return (session?["id"] as? String).flatMap(UUID.init(uuidString:)) == documentID
                      }) else { return nil }
                return (file, id)
            }
        }
    }

    private func requireProductionDocumentCount(_ count: Int) {
        if observedProductionWorkspace == nil {
            guard let hint = ProcessInfo.processInfo.environment["FAITHFUL_PRODUCTION_WORKSPACE_FILE"] else {
                XCTFail("The production matrix must provide its native installation container hint"); return
            }
            let title = app.staticTexts["reader-header-title"].label
            let tab = app.descendants(matching: .any).matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label == %@", "reader-document-tab-", title)).firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 15))
            guard let documentID = UUID(uuidString: String(tab.identifier.dropFirst("reader-document-tab-".count))) else {
                XCTFail("Observe the actual original-source tab's document identity"); return
            }
            var containers = URL(fileURLWithPath: hint)
            for _ in 0..<6 { containers.deleteLastPathComponent() }
            let root = containers
            let located = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                Self.productionWorkspaces(in: root, containing: documentID).count == 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [located], timeout: 30), .completed,
                           "Resolve the actual ordinary sidecar by the independently observed UI document, after XCTest installation")
            let matches = Self.productionWorkspaces(in: root, containing: documentID)
            XCTAssertEqual(matches.count, 1, "Do not choose a stale container or an arbitrary scene")
            observedProductionWorkspace = matches.first
        }
        guard let observed = observedProductionWorkspace else {
            XCTFail("The production workspace was not independently located"); return
        }
        let persisted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            Self.documentCount(in: observed.url, groupID: observed.groupID) == count
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [persisted], timeout: 30), .completed,
                       "The actual production projection must persist exactly \(count) documents")
    }

    private func replacePaletteQuery(_ query: String, in input: XCUIElement) {
        input.typeKey(XCUIKeyboardKey(rawValue: "a"), modifierFlags: .command)
        input.typeText(query)
        XCTAssertEqual(input.value as? String, query)
    }

    private func openProductionBook(named title: String) {
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 20))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        replacePaletteQuery(title, in: input)
        let result = palette.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30), "Select an actual title obtained from the production palette")
        tap(result)
        let text = app.textViews["reader-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 60))
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value MATCHES %@", "(?s).+"), object: text)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 30), .completed)
        let value = text.value as? String ?? ""
        XCTAssertFalse(value.contains("Error Domain") || value.contains("Content ID not found") || value.contains("no such table"))
        let strip = app.descendants(matching: .any)["reader-document-tabs"]
        let selectedTitle = strip.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "reader-document-tab-", title)).firstMatch
        XCTAssertTrue(selectedTitle.waitForExistence(timeout: 15), "The genuine selected document must appear in the original-source tab strip")
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !selectedTitle.frame.isEmpty && selectedTitle.frame.intersects(strip.frame) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 15), .completed, "The selected real book tab must be inside the strip viewport")
    }

    private func exerciseThirtyRealProductionDocuments(initialTitle: String) {
        requireProductionDocumentCount(1)
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 20))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        replacePaletteQuery("משנה", in: input)
        let results = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "משנה"))
        XCTAssertTrue(results.firstMatch.waitForExistence(timeout: 30))
        var titles: [String] = []
        for _ in 0..<20 {
            for result in results.allElementsBoundByIndex {
                let title = result.label
                if title != initialTitle && !titles.contains(title) { titles.append(title) }
            }
            if titles.count >= 29 { break }
            palette.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertGreaterThanOrEqual(titles.count, 29, "Obtain 29 distinct genuine titles from the visible production UI; no invented book IDs")
        input.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let chosen = Array(titles.prefix(29))
        let membership = XCTAttachment(string: chosen.joined(separator: "\n"))
        membership.name = "release-production-thirty-real-document-titles"
        membership.lifetime = .keepAlways
        add(membership)
        for repetition in 1...2 {
            requireProductionDocumentCount(1)
            for (index, title) in chosen.enumerated() {
                openProductionBook(named: title)
                requireProductionDocumentCount(index + 2)
                if index == 0 { capture("release-production-tabs-2-cycle-\(repetition)") }
            }
            requireProductionDocumentCount(30)
            capture("release-production-tabs-30-cycle-\(repetition)")
            tap(app.buttons["כל הכרטיסיות"])
            let overview = app.descendants(matching: .any)["study-groups-overview"]
            XCTAssertTrue(overview.waitForExistence(timeout: 15))
            for remaining in stride(from: 29, through: 0, by: -1) {
                let close = overview.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "סגור ")).firstMatch
                tap(close)
                requireProductionDocumentCount(remaining)
                if remaining <= 1 { capture("release-production-tabs-\(remaining)-cycle-\(repetition)") }
            }
            XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
            tap(app.buttons["סיום"])
            XCTAssertFalse(app.textViews["reader-text"].exists)
            openProductionBook(named: initialTitle)
            requireProductionDocumentCount(1)
        }
    }

    func testRealProductionLibraryReaderAndGroupRestore() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria")
        dismissAlertsIfNeeded()
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        tap(app.textFields["reader-library-search-field"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 30))
        let input = palette.textFields.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        let count = palette.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ commands?$")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 30), "The original palette must expose its genuine command membership")
        let commandCount = Int(count.label.split(separator: " ").first.map(String.init) ?? "") ?? 0
        XCTAssertGreaterThanOrEqual(commandCount, 100, "The production UI must exercise at least 100 real library results")
        input.typeText("ברכות")
        let book = palette.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ברכות")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 60), "Full production catalog must supply an actual book")
        capture("release-production-library-palette")
        tap(book)
        assertReaderHasText()
        let initialTitle = app.staticTexts["reader-header-title"].label
        for _ in 0..<20 {
            tap(findTabButton(hebrew: "היסטוריה", english: "History"))
            tap(findTabButton(hebrew: "ספר", english: "Library"))
            assertReaderHasText()
            XCTAssertTrue(app.buttons["reader-more-menu"].exists)
        }
        capture("release-production-reader")
        exerciseThirtyRealProductionDocuments(initialTitle: initialTitle)
        tap(app.buttons["כל הכרטיסיות"])
        tap(app.buttons["study-group-actions-menu"])
        tap(app.buttons["קבוצה ריקה"])
        let alert = app.alerts["שם קבוצת הכרטיסיות"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("בדיקת Release")
        tap(alert.buttons["שמירה"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15))
        tap(app.buttons["סיום"])
        app.terminate()
        launchWithTier(.production, backend: "otzaria")
        tap(findTabButton(hebrew: "ספר", english: "Library"))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.textViews["reader-text"])], timeout: 30), .completed,
                       "The ordinary production sidecar must finish restoring its empty group")
        XCTAssertFalse(app.textViews["reader-text"].exists)
        tap(app.buttons["כל הכרטיסיות"])
        XCTAssertTrue(app.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 30))
        capture("release-production-empty-group-restored")
    }
}
