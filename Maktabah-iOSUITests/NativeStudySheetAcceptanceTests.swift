import XCTest
import UIKit

// Additive real-app acceptance. These cases do not replace the original
// Native116/Release114 cases. Each process uses the normal realUI bootstrap.
private struct StudySheetObservation: Decodable, Sendable {
    struct Event: Decodable, Sendable {
        let event: String
        let sequence: Int
        let commandID: String?
        let deliveryID: String?
        let presentationID: String?
        let noteID: String?
    }
    let namespace: String
    let ownerID: String
    let presentationID: String?
    let noteID: String?
    let contentID: String
    let sessionIdentity: String
    let readerIdentity: String
    let sourceToken: String
    let selectionToken: String
    let selectedTool: String
    let detent: String
    let systemSheet: Bool
    let appeared: Bool
    let actualClosing: Bool
    let actualChild: Bool
    let sheetIdentity: String?
    let systemDetentIdentifier: String?
    let contentLayoutDirection: Int?
    let sceneID: String?
    let sheetFrame: [Double]?
    let windowBounds: [Double]?
    let events: [Event]

    func contains(_ name: String, command: String? = nil, delivery: String? = nil, parent: String? = nil, note: String? = nil) -> Bool {
        events.contains {
            $0.event == name && (command == nil || $0.commandID == command)
                && (delivery == nil || $0.deliveryID == delivery)
                && (parent == nil || $0.presentationID == parent) && (note == nil || $0.noteID == note)
        }
    }
}

private struct StudySheetCommand: Encodable {
    let deliveryID: String
    let id: String
    let ownerID: String
    let presentationID: String
    let noteID: String?
    let sourceToken: String
    let action: String
}

@MainActor
private final class StudySheetWindowCleanup {
    let restore: @MainActor () -> Void
    init(_ restore: @escaping @MainActor () -> Void) { self.restore = restore }
    func run() { restore() }
}

class NativeStudySheetUIBase: R27NativeUIBase {
    fileprivate var readerWidthBeforeOpen: CGFloat = 0
    override var readerAdditionalLaunchArguments: [String] {
        super.readerAdditionalLaunchArguments + ["-NativeStudySheetAcceptanceEnabled", "YES"]
    }

    override func launchReader(enabled: Bool = true, scenario: String = "reader", backend: String = "otzaria",
                               language: String = "he", background: Int = 0, recordViewport: Bool = false,
                               fontSize: Float? = nil) {
        // The existing tier overload configures the actual TextKit observation
        // channel; R27's ordinary subset intentionally has no such channel.
        super.launchReader(enabled: enabled, scenario: scenario, backend: backend, language: language,
                           background: background, recordViewport: recordViewport, fontSize: fontSize, tier: .realUI)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
    }

    private func observationURL(command: Bool = false) throws -> URL {
        var container = try workspaceSidecarURL()
        for _ in 0..<6 { container.deleteLastPathComponent() }
        return container.appendingPathComponent("Documents/native-study-sheet-" + workspaceNamespace
            + (command ? ".command.json" : ".json"))
    }

    nonisolated private static func readObservation(_ url: URL) -> StudySheetObservation? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink == false,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let bytes = try? handle.read(upToCount: 32769), bytes.count <= 32768 else { return nil }
        return try? JSONDecoder().decode(StudySheetObservation.self, from: bytes)
    }

    fileprivate func observe(_ predicate: @escaping @Sendable (StudySheetObservation) -> Bool,
                              timeout: TimeInterval = 15) throws -> StudySheetObservation {
        let url = try observationURL()
        let namespace = workspaceNamespace
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = Self.readObservation(url), value.namespace == namespace else { return false }
            return predicate(value)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Require the actual original sheet/view observation, not a command acknowledgement")
        let value = try XCTUnwrap(Self.readObservation(url))
        XCTAssertEqual(value.namespace, namespace)
        XCTAssertTrue(predicate(value))
        return value
    }

    fileprivate func retainSheet(_ name: String) throws {
        retainNativeEvidence("system-study-" + name)
        let data = try Data(contentsOf: observationURL())
        XCTAssertLessThanOrEqual(data.count, 32768)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "system-study-" + name + "-actual-views"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    override func tearDownWithError() throws {
        if app != nil { try? retainSheet("final") }
        try super.tearDownWithError()
    }

    @MainActor
    fileprivate func nativeTap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        XCTAssertTrue(element.isHittable)
        let frame = element.frame
        XCTAssertTrue([frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite))
        XCTAssertGreaterThan(frame.width, 0); XCTAssertGreaterThan(frame.height, 0)
        XCTAssertTrue(app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1).contains(frame))
        element.tap()
    }

    @discardableResult
    @MainActor
    fileprivate func startSheet(language: String = "en", backend: String = "otzaria",
                                fontSize: Float? = nil) throws -> StudySheetObservation {
        XCTAssertTrue(isPad, "Required iPad execution cannot be replaced by an iPhone screenshot")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", backend: backend, language: language,
                     recordViewport: true, fontSize: fontSize)
        _ = try assertTarget(backend: backend)
        capture("system-study-reader-before-open")
        readerWidthBeforeOpen = app.textViews["reader-text"].frame.width
        nativeTap(try originalStudyToolsActionInWindow())
        let actual = try observe { $0.systemSheet && $0.appeared && !$0.actualClosing && $0.presentationID != nil }
        XCTAssertTrue(app.otherElements["torah-inspector-panel"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.segmentedControls["torah-inspector-tools"].exists)
        try retainSheet("opened")
        return actual
    }

    fileprivate func frame(_ values: [Double]?) throws -> CGRect {
        let a = try XCTUnwrap(values)
        XCTAssertEqual(a.count, 4)
        guard a.count == 4, a.allSatisfy(\.isFinite), a[2] > 0, a[3] > 0 else {
            throw NSError(domain: "NativeStudySheetAcceptance", code: 1)
        }
        return CGRect(x: a[0], y: a[1], width: a[2], height: a[3])
    }

    fileprivate func assertSameOwner(_ a: StudySheetObservation, _ b: StudySheetObservation,
                                     presentation: Bool = true, selection: Bool = true) {
        XCTAssertEqual(a.ownerID, b.ownerID); XCTAssertEqual(a.contentID, b.contentID)
        XCTAssertEqual(a.readerIdentity, b.readerIdentity); XCTAssertEqual(a.sessionIdentity, b.sessionIdentity)
        XCTAssertEqual(a.sourceToken, b.sourceToken); XCTAssertEqual(a.sceneID, b.sceneID)
        if selection { XCTAssertEqual(a.selectionToken, b.selectionToken) }
        if presentation {
            XCTAssertEqual(a.presentationID, b.presentationID)
            XCTAssertEqual(a.sheetIdentity, b.sheetIdentity)
        }
    }

    fileprivate func assertAnchor(_ a: Viewport, _ b: Viewport) {
        XCTAssertEqual(a.object, b.object, "Keep the actual original TextKit instance")
        XCTAssertEqual(a.source, b.source, "Keep the original source anchor")
        XCTAssertEqual(a.offset, b.offset, accuracy: 1, "Keep the original viewport anchor")
    }

    @MainActor
    fileprivate func dragDetent(_ name: String) throws -> StudySheetObservation {
        let current = try observe { $0.systemSheet && $0.appeared && !$0.actualClosing }
        let sheet = try frame(current.sheetFrame), bounds = try frame(current.windowBounds)
        let window = app.windows.firstMatch
        let top = window.coordinate(withNormalizedOffset: .zero)
        let start = top.withOffset(CGVector(dx: sheet.midX - bounds.minX, dy: sheet.minY - bounds.minY + 8))
        let targetY: CGFloat
        switch name {
        case "large": targetY = 65
        case "medium": targetY = bounds.height * 0.5
        case "peek": targetY = bounds.height - 165
        default: throw NSError(domain: "NativeStudySheetAcceptance", code: 2)
        }
        start.press(forDuration: 0.2, thenDragTo: top.withOffset(CGVector(dx: sheet.midX - bounds.minX, dy: targetY)))
        let after = try observe { $0.systemSheet && $0.appeared && !$0.actualClosing && $0.detent == name }
        XCTAssertNotNil(after.systemDetentIdentifier, "Read the actual UIKit detent as well as SwiftUI selection")
        try retainSheet("drag-" + name)
        return after
    }

    @MainActor
    fileprivate func closeSheet(_ parent: String) throws {
        let peek = app.buttons["reader-study-peek-close"]
        nativeTap(peek.exists ? peek : app.buttons["torah-inspector-close"])
        _ = try observe { !$0.systemSheet && $0.presentationID == nil && $0.contains("study_onDismiss", parent: parent) }
        XCTAssertFalse(app.otherElements["torah-inspector-panel"].exists)
        XCTAssertFalse(app.otherElements["reader-study-peek"].exists)
    }

    @MainActor
    fileprivate func selectNotes() throws -> StudySheetObservation {
        nativeTap(app.segmentedControls["torah-inspector-tools"].buttons["Notes"])
        return try observe { $0.selectedTool == "notes" && $0.systemSheet && $0.appeared }
    }

    @MainActor
    fileprivate func openNote() throws -> StudySheetObservation {
        _ = try selectNotes()
        nativeTap(app.buttons["torah-inspector-add-note"])
        XCTAssertTrue(app.textViews["annotation-note-text"].waitForExistence(timeout: 15))
        let actual = try observe { $0.actualChild && $0.noteID != nil }
        // The child really blocks background taps. Programmatic lifecycle tests
        // below never pretend that a blocked parent control was tapped.
        XCTAssertFalse(app.buttons["torah-inspector-close"].isHittable)
        XCTAssertTrue(app.buttons["annotation-cancel-toolbar"].isHittable)
        try retainSheet("original-note-child")
        return actual
    }

    @discardableResult
    fileprivate func command(_ action: String, from value: StudySheetObservation,
                              id: String = UUID().uuidString, delivery: String = UUID().uuidString, parent: String? = nil) throws -> String {
        let request = StudySheetCommand(deliveryID: delivery, id: id, ownerID: value.ownerID,
            presentationID: try parent ?? XCTUnwrap(value.presentationID), noteID: value.noteID,
            sourceToken: value.sourceToken, action: action)
        let bytes = try JSONEncoder().encode(request)
        XCTAssertLessThanOrEqual(bytes.count, 4096)
        try bytes.write(to: observationURL(command: true), options: .atomic)
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "system-study-lifecycle-input-" + action
        attachment.lifetime = .keepAlways; add(attachment)
        return id
    }

    @MainActor
    fileprivate func shrinkWindow() throws -> CGSize {
        let window = app.windows.firstMatch
        let size = window.frame.size
        XCTAssertGreaterThan(size.width, 748)
        window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -12, dy: -12))
            .press(forDuration: 0.5, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7)))
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { window.frame.width < 748 && window.frame.width < size.width - 80 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 30), .completed,
                       "Require a measured narrow window on this same iPad")
        return size
    }

    @MainActor
    fileprivate func restoreWindow(_ size: CGSize) {
        let application = app!, window = application.windows.firstMatch
        if abs(window.frame.width - size.width) < 2, abs(window.frame.height - size.height) < 2 { return }
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let controls = system.buttons["window-controls:com.davidpovarsky.chavrusatext"]
        XCTAssertTrue(controls.waitForExistence(timeout: 10)); XCTAssertTrue(controls.isHittable); controls.tap()
        let labels = ["Full Screen", "Enter Full Screen", "Zoom", "מסך מלא", "הצג במסך מלא"]
        let predicate = NSPredicate(format: "label IN %@", labels)
        let choices = [system.buttons, system.menuItems, application.buttons, application.menuItems]
            .map { $0.matching(predicate).firstMatch }
        let menu = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { choices.contains { $0.exists && $0.isHittable } }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [menu], timeout: 10), .completed)
        guard let action = choices.first(where: { $0.exists && $0.isHittable }) else {
            XCTFail("Restore through the original native full-screen control"); return
        }
        action.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { abs(window.frame.width - size.width) < 2 && abs(window.frame.height - size.height) < 2 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 30), .completed)
    }
}

final class NativeStudySheetPadTests: NativeStudySheetUIBase {
    @MainActor
    private func exerciseDetents(language: String) throws {
        let first = try startSheet(language: language)
        let initial = try viewport(), locator = app.staticTexts["reader-current-locator"].label
        let readerWidth = readerWidthBeforeOpen
        XCTAssertEqual(app.textViews["reader-text"].frame.width, readerWidth, accuracy: 1)
        let initialBounds = try frame(first.windowBounds)
        XCTAssertGreaterThan(initialBounds.width, 748)
        XCTAssertEqual(first.contentLayoutDirection, language == "he" ? 1 : 0)
        let large = try dragDetent("large"), medium = try dragDetent("medium"), peek = try dragDetent("peek")
        for value in [large, medium, peek] {
            assertSameOwner(first, value)
            XCTAssertEqual(first.selectedTool, value.selectedTool)
            let actual = try frame(value.sheetFrame), bounds = try frame(value.windowBounds)
            XCTAssertGreaterThan(actual.midX, bounds.midX, "The actual system sheet must be physically right in both locales")
            XCTAssertLessThan(actual.width, bounds.width * 0.8)
            XCTAssertTrue(bounds.insetBy(dx: -1, dy: -1).contains(actual))
            XCTAssertEqual(app.textViews["reader-text"].frame.width, readerWidth, accuracy: 1)
        }
        XCTAssertGreaterThan(try frame(large.sheetFrame).height, try frame(medium.sheetFrame).height)
        XCTAssertGreaterThan(try frame(medium.sheetFrame).height, try frame(peek.sheetFrame).height)
        XCTAssertEqual(Set([large, medium, peek].compactMap(\.systemDetentIdentifier)).count, 3)
        XCTAssertTrue(app.buttons["reader-study-peek-expand"].isHittable)
        let passage = app.staticTexts["reader-study-peek-passage"]
        XCTAssertTrue(passage.exists); XCTAssertFalse(passage.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        assertAnchor(initial, try viewport())
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        nativeTap(app.buttons["reader-study-peek-expand"])
        let expanded = try observe { $0.detent == "medium" && $0.systemSheet && $0.appeared }
        assertSameOwner(first, expanded)
        try closeSheet(try XCTUnwrap(first.presentationID))
        assertAnchor(initial, try viewport())
    }

    @MainActor
    func testSystemStudySheetThreeDetentsPhysicallyRightRTL() throws { try exerciseDetents(language: "he") }
    @MainActor
    func testSystemStudySheetThreeDetentsPhysicallyRightLTR() throws { try exerciseDetents(language: "en") }

    @MainActor
    func testSystemStudySheetSameIPadNarrowAndWideRetainsOwnerAndAnchor() throws {
        let first = try startSheet()
        let notes = try selectNotes(), initial = try viewport()
        XCTAssertEqual(initial.usesTextKit2BeforeObservation, true)
        XCTAssertEqual(initial.usesTextKit2AfterObservation, true)
        let originalSize = app.windows.firstMatch.frame.size
        let cleanup = StudySheetWindowCleanup { [self] in restoreWindow(originalSize) }
        addTeardownBlock { await cleanup.run() }
        _ = try shrinkWindow()
        let narrow = try observe { $0.systemSheet && $0.appeared && ($0.windowBounds?[2] ?? .infinity) < 748 }
        assertSameOwner(first, narrow); XCTAssertEqual(narrow.selectedTool, notes.selectedTool)
        let actual = try frame(narrow.sheetFrame), bounds = try frame(narrow.windowBounds)
        XCTAssertEqual(actual.midX, bounds.midX, accuracy: 2, "The same iPad must adapt to a centered bottom sheet")
        XCTAssertGreaterThan(actual.width, bounds.width * 0.85)
        XCTAssertGreaterThanOrEqual(actual.maxY, bounds.maxY - 32)
        let narrowViewport = try viewport()
        XCTAssertEqual(narrowViewport.usesTextKit2BeforeObservation, true)
        XCTAssertEqual(narrowViewport.usesTextKit2AfterObservation, true)
        try retainSheet("same-ipad-narrow"); assertAnchor(initial, narrowViewport)
        restoreWindow(originalSize)
        let wide = try observe { $0.systemSheet && $0.appeared && ($0.windowBounds?[2] ?? 0) > 748 }
        assertSameOwner(first, wide); XCTAssertEqual(wide.selectedTool, notes.selectedTool)
        XCTAssertGreaterThan(try frame(wide.sheetFrame).midX, try frame(wide.windowBounds).midX)
        let wideViewport = try viewport()
        XCTAssertEqual(wideViewport.usesTextKit2BeforeObservation, true)
        XCTAssertEqual(wideViewport.usesTextKit2AfterObservation, true)
        assertAnchor(initial, wideViewport); try retainSheet("same-ipad-wide-again")
    }

    @MainActor
    func testSystemStudySheetPeekAllowsOriginalReaderScrollBehindIt() throws {
        // The same original passage fits at the default font on this iPad.
        // Use the existing Reader font setting to make real scrolling possible.
        _ = try startSheet(fontSize: 48)
        let first = try dragDetent("peek"), before = try viewport()
        try attachViewport(before, named: "system-study-background-scroll-before")
        XCTAssertEqual(before.usesTextKit2BeforeObservation, true, "The original Reader must retain TextKit 2")
        XCTAssertEqual(before.usesTextKit2AfterObservation, true, "Viewport observation must preserve the active engine")
        let contentHeight = try XCTUnwrap(before.contentHeight)
        let viewportHeight = try XCTUnwrap(before.viewportHeight)
        let topInset = try XCTUnwrap(before.topInset), bottomInset = try XCTUnwrap(before.bottomInset)
        XCTAssertTrue([contentHeight, viewportHeight, topInset, bottomInset].allSatisfy(\.isFinite))
        XCTAssertGreaterThan(contentHeight + topInset + bottomInset - viewportHeight, 80,
                             "The original Reader must have actual scrollable overflow before the gesture")
        let reader = app.textViews["reader-text"], actual = try frame(first.sheetFrame)
        let bounds = try frame(first.windowBounds), window = app.windows.firstMatch
        let top = window.coordinate(withNormalizedOffset: .zero)
        let localReader = reader.frame.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
        let x = localReader.minX + min(localReader.width * 0.25, 100)
        let startY = localReader.minY + localReader.height * 0.75
        let endY = localReader.minY + localReader.height * 0.35
        XCTAssertFalse(actual.contains(CGPoint(x: x + bounds.minX, y: startY + bounds.minY)))
        XCTAssertTrue(reader.isHittable)
        top.withOffset(CGVector(dx: x, dy: startY)).press(forDuration: 0.2,
            thenDragTo: top.withOffset(CGVector(dx: x, dy: endY)))
        let moved = try viewport()
        try attachViewport(moved, named: "system-study-background-scroll-after")
        XCTAssertEqual(moved.usesTextKit2BeforeObservation, true)
        XCTAssertEqual(moved.usesTextKit2AfterObservation, true)
        XCTAssertEqual(before.object, moved.object)
        let previousY = try XCTUnwrap(before.contentOffsetY), actualY = try XCTUnwrap(moved.contentOffsetY)
        XCTAssertGreaterThan(abs(actualY - previousY), 20, "Original Reader must actually scroll behind Peek")
        let after = try observe { $0.systemSheet && $0.appeared && $0.detent == "peek" }
        assertSameOwner(first, after)
        try closeSheet(try XCTUnwrap(first.presentationID))
        assertAnchor(moved, try viewport())
        try retainSheet("actual-background-reader-scroll")
    }

    @MainActor
    func testSystemStudySheetOriginalNotesSaveEditDeleteAndCancel() throws {
        let first = try startSheet()
        let initial = try viewport(), text = "StudySheet-" + UUID().uuidString
        let child = try openNote()
        let editor = app.textViews["annotation-note-text"]
        nativeTap(editor); editor.typeText(text)
        nativeTap(app.buttons["annotation-save-toolbar"])
        let noteID = try XCTUnwrap(child.noteID)
        _ = try observe { !$0.actualChild && $0.noteID == nil && $0.contains("note_onDismiss", note: noteID) }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "torah-inspector-note-", text))
        XCTAssertTrue(row.firstMatch.waitForExistence(timeout: 15)); XCTAssertEqual(row.count, 1)
        nativeTap(row.firstMatch)
        XCTAssertEqual(app.textViews["annotation-note-text"].value as? String, text)
        nativeTap(app.textViews["annotation-note-text"])
        // Use the existing native Select All input; a center tap does not promise an end caret.
        app.textViews["annotation-note-text"].typeKey("a", modifierFlags: .command)
        app.textViews["annotation-note-text"].typeText(text + " unsaved")
        XCTAssertEqual(app.textViews["annotation-note-text"].value as? String, text + " unsaved")
        nativeTap(app.buttons["annotation-cancel-toolbar"])
        _ = try observe { !$0.actualChild && $0.noteID == nil }
        nativeTap(row.firstMatch)
        XCTAssertEqual(app.textViews["annotation-note-text"].value as? String, text, "Cancel must not persist edited bytes")
        nativeTap(app.textViews["annotation-note-text"])
        // Use the existing native Select All input; a center tap does not promise an end caret.
        app.textViews["annotation-note-text"].typeKey("a", modifierFlags: .command)
        app.textViews["annotation-note-text"].typeText(text + " saved")
        XCTAssertEqual(app.textViews["annotation-note-text"].value as? String, text + " saved")
        nativeTap(app.buttons["annotation-save-toolbar"])
        _ = try observe { !$0.actualChild && $0.noteID == nil }
        let editedRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "torah-inspector-note-", text + " saved"))
        XCTAssertTrue(editedRow.firstMatch.waitForExistence(timeout: 15)); XCTAssertEqual(editedRow.count, 1)
        nativeTap(editedRow.firstMatch)
        XCTAssertEqual(app.textViews["annotation-note-text"].value as? String, text + " saved")
        nativeTap(app.buttons["annotation-delete-toolbar"])
        _ = try observe { !$0.actualChild && $0.noteID == nil }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: editedRow)], timeout: 15), .completed)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: row)], timeout: 15), .completed)
        let after = try observe { $0.systemSheet && $0.appeared }
        assertSameOwner(first, after); assertAnchor(initial, try viewport())
        try retainSheet("original-notes-completed")
    }

    @MainActor
    func testSystemStudySheetOriginalTOCWaitsForActualSheetDismissal() throws {
        let first = try startSheet(), initial = try viewport()
        let locator = app.staticTexts["reader-current-locator"].label
        nativeTap(app.buttons["reader-more-menu"]); nativeTap(app.buttons["reader-toc-toggle"])
        let parent = try XCTUnwrap(first.presentationID)
        _ = try observe { !$0.systemSheet && $0.presentationID == nil && $0.contains("study_onDismiss", parent: parent) }
        XCTAssertTrue(app.descendants(matching: .any)["toc-column"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["reader-sidebar-page-1"].isSelected)
        XCTAssertFalse(app.otherElements["torah-inspector-panel"].exists)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        assertAnchor(initial, try viewport()); try retainSheet("original-toc")
    }

    @MainActor
    func testSystemStudySheetOriginalEmbeddedSefariaOwnerAndAnchor() throws {
        let first = try startSheet(backend: "sefariaEmbedded"), initial = try viewport()
        let large = try dragDetent("large"), peek = try dragDetent("peek")
        assertSameOwner(first, large); assertSameOwner(first, peek)
        XCTAssertTrue(try assertTarget(backend: "sefariaEmbedded").hasPrefix("sefariaEmbedded|Genesis|"))
        try closeSheet(try XCTUnwrap(first.presentationID)); assertAnchor(initial, try viewport())
    }

    // These next three are explicitly programmatic Native lifecycle races.
    // Commands invoke original actions only after observing the actual current
    // parent/child; they are not gesture, transport or Core receipt evidence.
    @MainActor
    func testSystemStudySheetParentCloseWhileOriginalNoteChildIsVisible() throws {
        _ = try startSheet()
        let child = try openNote(), parent = try XCTUnwrap(child.presentationID), note = try XCTUnwrap(child.noteID)
        let id = try command("closeParent", from: child)
        let ended = try observe { !$0.systemSheet && $0.presentationID == nil && !$0.actualChild
            && $0.contains("actual_child_before_action", command: id, parent: parent, note: note)
            && $0.contains("note_onDismiss", note: note) && $0.contains("study_onDismiss", parent: parent) }
        XCTAssertFalse(app.textViews["annotation-note-text"].exists)
        XCTAssertFalse(app.otherElements["torah-inspector-panel"].exists)
        nativeTap(try originalStudyToolsActionInWindow())
        let next = try observe { $0.systemSheet && $0.appeared && $0.presentationID != parent }
        assertSameOwner(child, next, presentation: false, selection: false)
        let nextChild = try openNote(); XCTAssertNotEqual(nextChild.noteID, note)
        XCTAssertEqual(ended.ownerID, nextChild.ownerID)
        nativeTap(app.buttons["annotation-cancel-toolbar"])
        try retainSheet("programmatic-parent-close-with-child")
    }

    @MainActor
    func testSystemStudySheetTOCWhileOriginalNoteChildIsVisible() throws {
        _ = try startSheet()
        let child = try openNote(), parent = try XCTUnwrap(child.presentationID), note = try XCTUnwrap(child.noteID)
        let locator = app.staticTexts["reader-current-locator"].label
        let id = try command("openContents", from: child)
        _ = try observe { !$0.systemSheet && !$0.actualChild && $0.presentationID == nil
            && $0.contains("actual_child_before_action", command: id, parent: parent, note: note)
            && $0.contains("note_onDismiss", note: note) && $0.contains("study_onDismiss", parent: parent) }
        XCTAssertFalse(app.textViews["annotation-note-text"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["toc-column"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["reader-sidebar-page-1"].isSelected)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        try retainSheet("programmatic-toc-with-child")
    }

    @MainActor
    func testSystemStudySheetReopenDuringActualDismissalRejectsStaleAndReplayedInput() throws {
        let first = try startSheet(), parent = try XCTUnwrap(first.presentationID)
        let id = try command("reopenDuringDismiss", from: first)
        let next = try observe { $0.systemSheet && $0.appeared && $0.presentationID != parent
            && $0.contains("actual_closing_before_toggle", command: id, parent: parent)
            && $0.contains("study_onDismiss", parent: parent) }
        assertSameOwner(first, next, presentation: false, selection: false)
        XCTAssertNotEqual(first.sheetIdentity, next.sheetIdentity)
        let nextParent = try XCTUnwrap(next.presentationID)
        // Exact replay cannot invoke another original action.
        let replayDelivery = UUID().uuidString
        try command("reopenDuringDismiss", from: first, id: id, delivery: replayDelivery)
        let replayRefused = try observe { $0.systemSheet && $0.appeared && $0.presentationID == nextParent
            && $0.contains("refused_replayed_command", command: id, delivery: replayDelivery) }
        assertSameOwner(next, replayRefused)
        let stale = try command("reopenDuringDismiss", from: next, parent: parent)
        let refused = try observe { $0.systemSheet && $0.appeared && $0.presentationID == nextParent
            && $0.contains("refused_stale_or_unmounted", command: stale) }
        assertSameOwner(next, refused)
        XCTAssertEqual(refused.events.filter { $0.commandID == id && $0.event == "actual_sheet_before_close" }.count, 1)
        try retainSheet("programmatic-reopen-stale-input")
    }

    @MainActor
    func testSystemStudySheetInteractiveDismissThenSameIPadResizeDoesNotReopen() throws {
        let first = try startSheet(), parent = try XCTUnwrap(first.presentationID)
        let originalSize = app.windows.firstMatch.frame.size
        let cleanup = StudySheetWindowCleanup { [self] in restoreWindow(originalSize) }
        addTeardownBlock { await cleanup.run() }
        let current = try dragDetent("peek"), sheet = try frame(current.sheetFrame), bounds = try frame(current.windowBounds)
        let top = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        top.withOffset(CGVector(dx: sheet.midX - bounds.minX, dy: sheet.minY - bounds.minY + 8))
            .press(forDuration: 0.2, thenDragTo: top.withOffset(CGVector(dx: sheet.midX - bounds.minX, dy: bounds.height - 2)))
        _ = try observe { !$0.systemSheet && $0.presentationID == nil && $0.contains("study_onDismiss", parent: parent) }
        _ = try shrinkWindow()
        XCTAssertFalse(app.otherElements["torah-inspector-panel"].exists)
        XCTAssertFalse(app.otherElements["reader-study-peek"].exists)
        _ = try observe { !$0.systemSheet && $0.presentationID == nil }
        restoreWindow(originalSize)
        XCTAssertFalse(app.otherElements["torah-inspector-panel"].exists)
        _ = try observe { !$0.systemSheet && $0.presentationID == nil }
        try retainSheet("interactive-dismiss-layout-no-reopen")
    }
}

final class NativeStudySheetPhoneFallbackTests: NativeStudySheetUIBase {
    @MainActor
    func testOriginalPhoneInspectorFallbackRetainsReader() throws {
        XCTAssertFalse(isPad)
        launchReader(scenario: "reader", language: "en", recordViewport: true)
        let locator = try assertTarget(backend: "otzaria"), initial = try viewport()
        nativeTap(try originalStudyToolsActionInWindow())
        XCTAssertTrue(app.otherElements["torah-inspector-panel"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.otherElements["reader-study-peek"].exists)
        nativeTap(app.buttons["torah-inspector-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.otherElements["torah-inspector-panel"])], timeout: 15), .completed)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        assertAnchor(initial, try viewport())
        retainNativeEvidence("system-study-phone-original-fallback")
    }
}
