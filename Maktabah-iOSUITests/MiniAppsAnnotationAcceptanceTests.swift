import XCTest
import SQLite3
import CryptoKit

/// Runs only on the owned two-app simulator lane. No result or document fixture
/// is written by this test: both apps execute their actual public UI and bridge.
final class MiniAppsAnnotationAcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }


    private struct PickerPreferences: Decodable, Equatable {
        let favorites: [String]
        let hidden: Set<String>
        let opensInNewWindow: Bool
    }

    private struct PickerPreferencesEnvelope: Decodable {
        let schemaVersion: Int
        let value: PickerPreferences
    }

    private func pickerPreferences(in shared: URL) throws -> PickerPreferences {
        let path = shared.appendingPathComponent("preferences.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            return PickerPreferences(favorites: [], hidden: [], opensInNewWindow: true)
        }
        let envelope = try JSONDecoder().decode(PickerPreferencesEnvelope.self, from: Data(contentsOf: path))
        XCTAssertEqual(envelope.schemaVersion, 1)
        return envelope.value
    }

    @MainActor
    private func retainPickerSnapshot(named name: String, shared: URL) throws {
        retainScreenshot(app, named: name)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let path = shared.appendingPathComponent("preferences.json")
        if FileManager.default.fileExists(atPath: path.path) {
            let preferences = XCTAttachment(data: try Data(contentsOf: path), uniformTypeIdentifier: "public.json")
            preferences.name = name + "-actual-preferences"
            preferences.lifetime = .keepAlways
            add(preferences)
        }
    }

    private enum PickerLanguage {
        case english, hebrew

        var code: String { self == .hebrew ? "he" : "en" }
        var locale: String { self == .hebrew ? "he_IL" : "en_US" }
        var isRTL: Bool { self == .hebrew }
        var more: String { self == .hebrew ? "עוד" : "More" }
        var edit: String { self == .hebrew ? "עריכה" : "Edit" }
        var done: String { self == .hebrew ? "סיום" : "Done" }
        var addFavorite: String { self == .hebrew ? "הוספה למועדפים" : "Add to Favorites" }
        // UIKit.axbundle/he.lproj/Accessibility.strings and UIKitCore's
        // Localizable.strings in the installed iOS 27 runtime, not translated
        // guesses or positional substitutes for native editing controls.
        var reorder: String { self == .hebrew ? "שינוי הסדר" : "Reorder" }
        var delete: String { self == .hebrew ? "מחיקה" : "Delete" }
    }

    @MainActor
    private func verifyPickerEditing(shared: URL, language: PickerLanguage = .english) async throws {
        let original = try pickerPreferences(in: shared)
        let suffix = (isPad ? "ipad-" : "iphone-") + language.code
        func snapshot(_ stage: String) throws {
            try retainPickerSnapshot(named: "otzaria-picker-" + stage + "-" + suffix, shared: shared)
        }
        XCTAssertEqual(app.buttons["miniapps-more"].label, language.more)
        try snapshot("original-chooser")
        tap(app.buttons["miniapps-more"])
        let edit = app.buttons["miniapps-editor-edit"]
        let dismiss = app.buttons["miniapps-editor-dismiss"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15) && dismiss.waitForExistence(timeout: 15))
        XCTAssertEqual(edit.label, language.edit)
        XCTAssertEqual(dismiss.label, language.done)
        XCTAssertTrue(edit.isHittable && dismiss.isHittable)
        if language.isRTL {
            XCTAssertLessThan(edit.frame.midX, dismiss.frame.midX,
                "The real Hebrew confirmation action must mirror to the left of dismissal")
        } else {
            XCTAssertGreaterThan(edit.frame.midX, dismiss.frame.midX)
        }
        let windowFrame = app.windows.firstMatch.frame
        let localeEvidence: [String: Any] = [
            "language": language.code, "locale": language.locale,
            "device": isPad ? "iPad" : "iPhone", "orientation": XCUIDevice.shared.orientation.rawValue,
            "launchArguments": app.launchArguments,
            "windowCount": app.windows.count,
            "windowFrame": ["x": windowFrame.minX, "y": windowFrame.minY,
                            "width": windowFrame.width, "height": windowFrame.height],
            "actualEditLabel": edit.label, "actualDismissLabel": dismiss.label,
            "actualEditMidX": edit.frame.midX, "actualDismissMidX": dismiss.frame.midX,
            "rtlToolbarGeometryObserved": edit.frame.midX < dismiss.frame.midX
        ]
        let localeAttachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: localeEvidence, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        localeAttachment.name = "otzaria-picker-actual-locale-scene-" + suffix
        localeAttachment.lifetime = .keepAlways
        add(localeAttachment)
        try snapshot("more")
        let catalog = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: shared.appendingPathComponent("catalog.json")))
                as? [String: Any])
        let items = try XCTUnwrap(catalog["items"] as? [[String: Any]])
        let candidates = try items.compactMap { item -> (id: String, title: String)? in
            let id = try XCTUnwrap(item["id"] as? String)
            guard !original.favorites.contains(id), !original.hidden.contains(id),
                  app.buttons["miniapps-launch-" + id].exists else { return nil }
            let localized = item["localizedTitles"] as? [String: String] ?? [:]
            let title = try XCTUnwrap(localized[language.locale] ?? localized[language.code]
                ?? item["title"] as? String)
            return (id, title)
        }
        XCTAssertGreaterThanOrEqual(candidates.count, 2,
            "The real producer must expose two compatible suggestions through this native chooser")
        let first = try XCTUnwrap(candidates.first)
        let second = try XCTUnwrap(candidates.dropFirst().first)
        tap(edit)
        XCTAssertEqual(edit.label, language.done)
        XCTAssertFalse(dismiss.exists, "Edit mode has one native Done action")
        try snapshot("native-edit")

        let visible = app.switches["miniapps-visible-" + first.id]
        XCTAssertTrue(visible.waitForExistence(timeout: 15))
        tap(visible)
        try await requireNativeCondition(timeout: 15) {
            try self.pickerPreferences(in: shared).hidden.contains(first.id) != original.hidden.contains(first.id)
        }
        tap(visible)
        try await requireNativeCondition(timeout: 15) {
            try self.pickerPreferences(in: shared).hidden == original.hidden
        }
        for item in [first, second] {
            let addFavorite = app.buttons[language.addFavorite + ": " + item.title]
            XCTAssertTrue(addFavorite.waitForExistence(timeout: 15))
            tap(addFavorite)
            try await requireNativeCondition(timeout: 15) {
                try self.pickerPreferences(in: shared).favorites.contains(item.id)
            }
        }
        for _ in 0..<3 { app.swipeDown() }
        let firstCell = app.cells.containing(.staticText, identifier: first.title).firstMatch
        let secondCell = app.cells.containing(.staticText, identifier: second.title).firstMatch
        let reorderPredicate = NSPredicate(format: "label BEGINSWITH %@", language.reorder)
        let firstHandles = firstCell.buttons.matching(reorderPredicate)
        let secondHandles = secondCell.buttons.matching(reorderPredicate)
        XCTAssertTrue(firstHandles.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(secondHandles.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(firstHandles.count, 1)
        XCTAssertEqual(secondHandles.count, 1)
        let firstHandle = firstHandles.firstMatch
        let secondHandle = secondHandles.firstMatch
        XCTAssertTrue(firstHandle.isHittable && secondHandle.isHittable)
        if language.isRTL {
            XCTAssertLessThan(firstHandle.frame.midX, firstCell.frame.midX,
                "The Hebrew native list must place its trailing reorder handle on the left")
        } else {
            XCTAssertGreaterThan(firstHandle.frame.midX, firstCell.frame.midX)
        }
        try snapshot("favorites-before-native-drag")
        secondHandle.press(forDuration: 0.7, thenDragTo: firstHandle)
        try await requireNativeCondition(timeout: 15) {
            let ordered = try self.pickerPreferences(in: shared).favorites
            guard let a = ordered.firstIndex(of: first.id), let b = ordered.firstIndex(of: second.id) else { return false }
            return b < a
        }
        try snapshot("favorites-after-native-drag")
        tap(edit)
        XCTAssertTrue(dismiss.waitForExistence(timeout: 15))
        tap(dismiss)
        XCTAssertTrue(app.buttons["miniapps-more"].waitForExistence(timeout: 15))
        tap(app.buttons["miniapps-more"])
        XCTAssertEqual(edit.label, language.edit)
        try snapshot("reopened-persisted-order")
        tap(edit)
        for item in [second, first] {
            let cell = app.cells.containing(.staticText, identifier: item.title).firstMatch
            let removes = cell.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", language.delete))
            XCTAssertTrue(removes.firstMatch.waitForExistence(timeout: 15))
            XCTAssertEqual(removes.count, 1)
            tap(removes.firstMatch)
            let removedImmediately = try await waitUntil(timeout: 1) {
                try !self.pickerPreferences(in: shared).favorites.contains(item.id)
            }
            if !removedImmediately {
                let confirm = cell.buttons[language.delete]
                XCTAssertTrue(confirm.waitForExistence(timeout: 5))
                tap(confirm)
            }
            try await requireNativeCondition(timeout: 15) {
                try !self.pickerPreferences(in: shared).favorites.contains(item.id)
            }
        }
        let window = app.switches["miniapps-new-window"]
        for _ in 0..<6 {
            if window.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(window.isHittable)
        tap(window)
        try await requireNativeCondition(timeout: 15) {
            try self.pickerPreferences(in: shared).opensInNewWindow != original.opensInNewWindow
        }
        try snapshot("window-preference-changed")
        tap(window)
        try await requireNativeCondition(timeout: 15) {
            try self.pickerPreferences(in: shared) == original
        }
        tap(edit)
        XCTAssertEqual(edit.label, language.edit)
        tap(dismiss)
        XCTAssertTrue(app.buttons["miniapps-more"].waitForExistence(timeout: 15))
    }

    private struct Content: Decodable { let text: String? }
    private struct Selection: Decodable { let location: Int; let length: Int; let text: String }
    private struct Source: Decodable {
        let appID: String
        let documentID: String?
        let documentText: String?
        let kind: String?
        let selection: Selection?
        let metadata: [String: String]
    }
    private struct Callbacks: Decodable { let success: URL? }
    private struct Request: Decodable {
        let id: UUID
        let callbacks: Callbacks
        let appID: String
        let operation: String
        let source: Source
        let inputs: [Content]
    }
    private struct Result: Decodable {
        let requestID: UUID
        let status: String
        let operation: String
        let items: [Content]
    }
    private struct Record: Decodable {
        let request: Request
        let result: Result?
        let acknowledged: Bool
    }
    private struct Document: Decodable {
        let profile: String
        let annotationID: Int64?
        let annotationUUID: String
        let draftNote: String
        let bookID: Int
        let contentID: Int
        let rangeLocation: Int
        let rangeLength: Int
        let context: String
        let isReaderSelection: Bool
    }
    private struct Receipt {
        let annotationID: Int64
        let annotationUUID: String
        let note: String
        let resultJSON: String
        let count: Int64
        let bookID: Int
        let contentID: Int
        let rangeLocation: Int
        let rangeLength: Int
        let context: String
    }

    /// Run this selector with the same qualified app/test bundle on iPhone
    /// Hebrew, then iPad Hebrew. It exercises real chooser preferences without
    /// repeating the five independent callback/document acceptance journeys.
    @MainActor
    func testSharedPickerHebrewRTLUsesNativeEditingAndPersistsPreferences() async throws {
        XCTAssertEqual(ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_PRODUCER_BUNDLE"],
                       "com.itorah.hanlinminiapps")
        let shared = URL(fileURLWithPath: try XCTUnwrap(
            ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_SHARED_GROUP"]
        )).appendingPathComponent("MiniAppsBridge/v1", isDirectory: true)
        if let requiredDevice = ProcessInfo.processInfo.environment["MINIAPPS_PICKER_EXPECTED_DEVICE"] {
            XCTAssertEqual(requiredDevice, isPad ? "ipad" : "iphone")
        }
        let producer = XCUIApplication(bundleIdentifier: "com.itorah.hanlinminiapps")
        producer.launchArguments = ["-AppleLanguages", "(he)", "-AppleLocale", "he_IL"]
        producer.launch()
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let ready = try await waitUntil(timeout: 30) {
            guard let data = try? Data(contentsOf: shared.appendingPathComponent("catalog.json")),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = value["items"] as? [[String: Any]] else { return false }
            return items.count >= 2 && items.contains { $0["id"] as? String == "nativeapp.textstudio" }
        }
        XCTAssertTrue(ready, "Use the installed original producer's actual catalog")
        let before = Set(try records(in: shared).map { $0.request.id })
        XCUIDevice.shared.orientation = isPad ? .landscapeLeft : .portrait
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "he", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        tap(try originalStudyToolsActionInWindow())
        let tools = app.descendants(matching: .any)["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        let notes = tools.buttons.matching(NSPredicate(format: "label == %@", "הערות"))
        XCTAssertEqual(notes.count, 1, "Use the source-owned Hebrew Notes action")
        tap(notes.firstMatch)
        tap(app.buttons["torah-inspector-add-note"])
        let note = app.textViews["annotation-note-text"]
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        XCTAssertEqual(note.value as? String ?? "", "")
        tap(app.buttons["otzaria-note-miniapps"])
        try await verifyPickerEditing(shared: shared, language: .hebrew)
        tap(app.buttons["miniapps-picker-dismiss"])
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        tap(app.buttons["annotation-cancel-toolbar"])
        try await requireNativeCondition(timeout: 15) { !note.exists }
        XCTAssertEqual(Set(try records(in: shared).map { $0.request.id }), before,
            "Editing and dismissing the chooser must not enqueue a MiniApp invocation")
    }

    @MainActor
    func testOriginalNoteReturnsTextFromActualMiniAppsAndPersistsAfterRelaunch() async throws {
        XCTAssertTrue(isPad)
        XCTAssertEqual(ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_PRODUCER_BUNDLE"],
                       "com.itorah.hanlinminiapps")
        let shared = URL(fileURLWithPath: try XCTUnwrap(
            ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_SHARED_GROUP"]
        )).appendingPathComponent("MiniAppsBridge/v1", isDirectory: true)
        let producer = XCUIApplication(bundleIdentifier: "com.itorah.hanlinminiapps")
        producer.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        producer.launch()
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let catalog = shared.appendingPathComponent("catalog.json")
        let catalogReady = try await waitUntil(timeout: 30) {
            guard let data = try? Data(contentsOf: catalog),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = value["items"] as? [[String: Any]] else { return false }
            return items.contains { $0["id"] as? String == "nativeapp.textstudio" }
        }
        XCTAssertTrue(catalogReady,
                       "The actual producer must publish its TextStudio catalog")

        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "en", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        try await openAnnotations()
        let priorRows = Set(annotationRows().allElementsBoundByIndex.map(\.identifier))
        tap(app.navigationBars["Annotations"].buttons["Close"])

        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tap(tools.buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let note = app.textViews["annotation-note-text"]
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        XCTAssertEqual(note.value as? String ?? "", "")
        tap(app.buttons["annotation-save-toolbar"])
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: note)
        let closedOutcome = await XCTWaiter.fulfillment(of: [closed], timeout: 30)
        XCTAssertEqual(closedOutcome, .completed)
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        let currentRows = annotationRows()
        let additions = try await waitUntil(timeout: 15) {
            currentRows.allElementsBoundByIndex.filter { !priorRows.contains($0.identifier) }.count == 1
        }
        XCTAssertTrue(additions)
        let row = try XCTUnwrap(annotationRows().allElementsBoundByIndex.first { !priorRows.contains($0.identifier) })
        let rowIdentifier = row.identifier
        let rowID = try XCTUnwrap(Int64(rowIdentifier.dropFirst("original-book-annotation-".count)))
        editAnnotation(row)
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        XCTAssertEqual(note.value as? String ?? "", "")

        let existingRequests = Set(try records(in: shared).map { $0.request.id })
        tap(app.buttons["otzaria-note-miniapps"])
        try await verifyPickerEditing(shared: shared)
        let textStudio = app.buttons["miniapps-launch-nativeapp.textstudio"]
        if !textStudio.waitForExistence(timeout: 3) {
            tap(app.buttons["miniapps-more"])
        }
        XCTAssertTrue(textStudio.waitForExistence(timeout: 15))
        tap(textStudio)
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30),
                      "The real URL must launch the separate producer app")
        let text = producer.textViews["miniapps.textstudio.editor"]
        XCTAssertTrue(text.waitForExistence(timeout: 30))
        XCTAssertEqual(text.value as? String ?? "", "", "Caret invocation starts an insertion, not a duplicate note")
        let pending = try XCTUnwrap(try records(in: shared).first { !existingRequests.contains($0.request.id) })
        XCTAssertEqual(pending.request.appID, "nativeapp.textstudio")
        XCTAssertEqual(pending.request.operation, "insert")
        XCTAssertEqual(pending.request.inputs.compactMap(\.text).joined(separator: "\n"), "")
        XCTAssertEqual(pending.request.source.appID, "com.davidpovarsky.chavrusatext")
        XCTAssertEqual(pending.request.source.documentText, "")
        XCTAssertFalse(pending.acknowledged)
        let documentData = Data(try XCTUnwrap(pending.request.source.metadata["otzaria.annotation.v1"]).utf8)
        let document = try JSONDecoder().decode(Document.self, from: documentData)
        XCTAssertEqual(document.annotationID, rowID)
        XCTAssertEqual(pending.request.source.documentID, document.annotationUUID)

        let returnedText = "MiniApps original note שלום " + UUID().uuidString
        XCTAssertTrue(text.isHittable)
        text.tap()
        text.typeText(returnedText)
        XCTAssertEqual(text.value as? String, returnedText)
        retainScreenshot(producer, named: "miniapps-real-textstudio-typed-result")
        let returnButton = producer.buttons["miniapps.textstudio.return"]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 15) && returnButton.isHittable)
        returnButton.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30),
                      "The producer must invoke the real source callback")
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", returnedText), object: note)
        let updatedOutcome = await XCTWaiter.fulfillment(of: [updated], timeout: 30)
        XCTAssertEqual(updatedOutcome, .completed)
        let acknowledged = try await waitUntil(timeout: 15) {
            (try? self.records(in: shared).first { $0.request.id == pending.request.id }?.acknowledged) == true
        }
        XCTAssertTrue(acknowledged)
        let delivered = try XCTUnwrap(try records(in: shared).first { $0.request.id == pending.request.id })
        XCTAssertEqual(delivered.result?.requestID, pending.request.id)
        XCTAssertEqual(delivered.result?.status, "success")
        XCTAssertEqual(delivered.result?.operation, "insert")
        XCTAssertEqual(delivered.result?.items.compactMap(\.text).joined(separator: "\n"), returnedText)
        let receipt = try persistedReceipt(requestID: pending.request.id, databasePath: document.profile)
        XCTAssertEqual(receipt.annotationID, rowID)
        XCTAssertEqual(receipt.annotationUUID, document.annotationUUID)
        XCTAssertEqual(receipt.note, returnedText)
        XCTAssertEqual(receipt.count, 1)
        retainScreenshot(app, named: "otzaria-original-note-after-miniapps-callback")
        attachReceipt(receipt, requestID: pending.request.id, name: "miniapps-original-durable-ack")

        // The MiniApps result is already durably saved before the editor's Save.
        // Closing this sheet and recreating the source process must retain it.
        tap(app.buttons["annotation-cancel-toolbar"])
        XCTAssertTrue(app.navigationBars["Annotations"].waitForExistence(timeout: 15))
        tap(app.navigationBars["Annotations"].buttons["Close"])
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        assertReaderHasText()
        try await openAnnotations()
        XCTAssertEqual(Set(annotationRows().allElementsBoundByIndex.map(\.identifier)), priorRows.union([rowIdentifier]))
        let restored = app.buttons[rowIdentifier]
        XCTAssertTrue(restored.waitForExistence(timeout: 15))
        editAnnotation(restored)
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        XCTAssertEqual(note.value as? String, returnedText,
                       "The same original row must reopen after a real source process restart")
        let after = try persistedReceipt(requestID: pending.request.id, databasePath: document.profile)
        XCTAssertEqual(after.annotationID, rowID)
        XCTAssertEqual(after.annotationUUID, document.annotationUUID)
        XCTAssertEqual(after.note, returnedText)
        XCTAssertEqual(after.count, 1, "Foreground recovery must not duplicate the persisted edit")
        retainScreenshot(app, named: "otzaria-original-note-after-process-relaunch")
        attachReceipt(after, requestID: pending.request.id, name: "miniapps-original-reopened-note")


        // A second actual invocation returns through Apple's URL delivery after
        // the source process is gone. No launch/activate/navigation assists it.
        let beforeCold = Set(try records(in: shared).map { $0.request.id })
        tap(app.buttons["otzaria-note-miniapps"])
        if !textStudio.waitForExistence(timeout: 3) { tap(app.buttons["miniapps-more"]) }
        XCTAssertTrue(textStudio.waitForExistence(timeout: 15))
        tap(textStudio)
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let coldEditors = producer.textViews.matching(identifier: "miniapps.textstudio.editor")
        XCTAssertTrue(coldEditors.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(coldEditors.count, 1, "Completed invocation must release its original editor")
        let coldEditor = coldEditors.element(boundBy: 0)
        XCTAssertEqual(coldEditor.value as? String ?? "", "")
        let coldPending = try XCTUnwrap(try records(in: shared).first { !beforeCold.contains($0.request.id) })
        XCTAssertEqual(coldPending.request.operation, "insert")
        XCTAssertEqual(coldPending.request.inputs.compactMap(\.text).joined(separator: "\n"), "")
        XCTAssertEqual(coldPending.request.source.documentText, returnedText)
        let coldDocument = try JSONDecoder().decode(Document.self, from:
            Data(try XCTUnwrap(coldPending.request.source.metadata["otzaria.annotation.v1"]).utf8))
        XCTAssertEqual(coldDocument.annotationID, rowID)
        XCTAssertEqual(coldDocument.annotationUUID, document.annotationUUID)
        XCTAssertEqual(coldDocument.profile, document.profile)
        XCTAssertEqual(coldDocument.draftNote, returnedText)
        let coldText = "MiniApps cold note שלום " + UUID().uuidString
        let original = returnedText as NSString
        let insertion = coldPending.request.source.selection.map { $0.location + $0.length } ?? original.length
        XCTAssertEqual(coldPending.request.source.selection?.length ?? 0, 0)
        XCTAssertGreaterThanOrEqual(insertion, 0)
        XCTAssertLessThanOrEqual(insertion, original.length)
        let expectedColdText = original.replacingCharacters(in: NSRange(location: insertion, length: 0), with: coldText)
        coldEditor.tap()
        coldEditor.typeText(coldText)
        XCTAssertEqual(coldEditor.value as? String, coldText)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15), "Source must really terminate before Return")
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 15))
        retainScreenshot(producer, named: "miniapps-cold-source-terminated-before-return")
        let coldReturn = producer.buttons["miniapps.textstudio.return"]
        XCTAssertTrue(coldReturn.waitForExistence(timeout: 15) && coldReturn.isHittable)
        coldReturn.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60),
                      "Only the actual producer callback may cold-launch the source")
        XCTAssertTrue(note.waitForExistence(timeout: 60),
                      "The original saved annotation editor must open without manual navigation")
        let coldUpdated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedColdText), object: note)
        let coldUpdatedOutcome = await XCTWaiter.fulfillment(of: [coldUpdated], timeout: 30)
        XCTAssertEqual(coldUpdatedOutcome, .completed)
        let coldAcknowledged = try await waitUntil(timeout: 15) {
            (try? self.records(in: shared).first { $0.request.id == coldPending.request.id }?.acknowledged) == true
        }
        XCTAssertTrue(coldAcknowledged)
        let coldDelivered = try XCTUnwrap(try records(in: shared).first { $0.request.id == coldPending.request.id })
        XCTAssertEqual(coldDelivered.result?.requestID, coldPending.request.id)
        XCTAssertEqual(coldDelivered.result?.status, "success")
        XCTAssertEqual(coldDelivered.result?.operation, "insert")
        XCTAssertEqual(coldDelivered.result?.items.compactMap(\.text).joined(separator: "\n"), coldText)
        let coldReceipt = try persistedReceipt(requestID: coldPending.request.id, databasePath: document.profile)
        XCTAssertEqual(coldReceipt.annotationID, rowID)
        XCTAssertEqual(coldReceipt.annotationUUID, document.annotationUUID)
        XCTAssertEqual(coldReceipt.note, expectedColdText)
        XCTAssertEqual(coldReceipt.count, 1)
        let firstReceiptAfterCold = try persistedReceipt(requestID: pending.request.id, databasePath: document.profile)
        XCTAssertEqual(firstReceiptAfterCold.annotationID, rowID)
        XCTAssertEqual(firstReceiptAfterCold.count, 1, "Cold recovery must not replay the already acknowledged insertion")
        XCTAssertEqual(firstReceiptAfterCold.resultJSON, receipt.resultJSON)
        retainScreenshot(app, named: "otzaria-original-note-restored-by-cold-callback")
        attachReceipt(coldReceipt, requestID: coldPending.request.id, name: "miniapps-original-cold-callback-note")
        try await verifyReaderSelectionRoundTrip(producer: producer, shared: shared, original: document,
            expectedRows: priorRows.union([rowIdentifier]))
        let editorAfterReader = try persistedReceipt(requestID: coldPending.request.id, databasePath: document.profile)
        XCTAssertEqual(editorAfterReader.note, expectedColdText, "Reader output must create its own linked note")
        try await verifyOriginalRichEditorRoundTrips(producer: producer, shared: shared)
        XCTAssertEqual(try persistedReceipt(requestID: coldPending.request.id,
            databasePath: document.profile).note, expectedColdText,
            "The separate rich note must not change the first original note")
    }

    private struct NativeContext: Decodable {
        struct Node: Decodable { let id: String; let bodyText: String? }
        let documentText: String
        let selectedText: String?
        let selectionLocation: Int?
        let selectionLength: Int?
        let blockIDs: [String]
        let nodes: [Node]
    }

    private struct RichState: Equatable {
        let revision: Int64
        let mutationID: UUID
        let payloadSHA256: String
        let bodySHA256: String
        let bodyBytes: Int
        let preview: String
    }

    @MainActor
    private func verifyOriginalRichEditorRoundTrips(producer: XCUIApplication, shared: URL) async throws {
        for key in ["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] {
            XCTAssertNil(app.launchEnvironment[key], "Use the ordinary original editor")
        }
        try await openAnnotations()
        let previous = Set(annotationRows().allElementsBoundByIndex.map(\.identifier))
        tap(app.navigationBars["Annotations"].buttons["Close"])
        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tap(tools.buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let quick = app.textViews["annotation-note-text"]
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        let first = "Original rich Alpha " + UUID().uuidString
        let second = "Original rich Beta שלום " + UUID().uuidString
        tap(quick); quick.typeText(first)
        tap(app.buttons["annotation-save-toolbar"])
        try await requireNativeCondition(timeout: 30) { !quick.exists }
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        try await requireNativeCondition(timeout: 20) {
            self.annotationRows().allElementsBoundByIndex.filter { !previous.contains($0.identifier) }.count == 1
        }
        let row = try XCTUnwrap(annotationRows().allElementsBoundByIndex.first { !previous.contains($0.identifier) })
        let rowID = try XCTUnwrap(Int64(row.identifier.dropFirst("original-book-annotation-".count)))
        editAnnotation(row)
        let open = app.buttons["annotation-expanded-editor-open"]
        try await requireNativeCondition(timeout: 30) { open.exists && open.isEnabled }
        tap(open)
        var host = try await richHost()
        let firstBody = try await richBody(first, host: host)
        firstBody.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        firstBody.typeText("\n")
        let blanks = host.textViews.matching(NSPredicate(format: "value == %@", ""))
        try await requireNativeCondition(timeout: 20) {
            blanks.allElementsBoundByIndex.filter { $0.isHittable }.count == 1
        }
        let blank = try XCTUnwrap(blanks.allElementsBoundByIndex.first { $0.isHittable })
        tap(blank); blank.typeText(second)
        _ = try await richBody(second, host: host)
        // Capture a real caret from the first native block. If the original
        // toolbar ends focus, the SDK's no-selection insertion adds a block;
        // expected topology is derived from its actual native context below.
        tap(try await richBody(first, host: host))
        let beforeWarm = Set(try records(in: shared).map { $0.request.id })
        tap(app.buttons["annotation-expanded-editor-miniapps"])
        try await openActualTextStudio(producer)
        let warm = try XCTUnwrap(try records(in: shared).first { !beforeWarm.contains($0.request.id) })
        let warmDocument = try JSONDecoder().decode(Document.self,
            from: Data(try XCTUnwrap(warm.request.source.metadata["otzaria.annotation.v1"]).utf8))
        XCTAssertEqual(warmDocument.annotationID, rowID)
        XCTAssertEqual(warm.request.source.kind, "native-annotation")
        XCTAssertEqual(warm.request.operation, "insert")
        XCTAssertEqual(warm.request.source.documentText, first + "\n" + second)
        let launch = try richState(rowID: rowID, databasePath: warmDocument.profile)
        XCTAssertGreaterThan(launch.revision, 0, "Leaving the app must save the complete native launch baseline")

        // Edit another real native block while the result is pending. Only
        // application activation is assisted; the result itself returns by URL.
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        host = try await richHost()
        let newerSecond = "Newer unsaved rich Beta שלום " + UUID().uuidString
        let other = try await richBody(second, host: host)
        tap(other); other.typeKey("a", modifierFlags: .command); other.typeText(newerSecond)
        _ = try await richBody(newerSecond, host: host)
        XCTAssertEqual(try richState(rowID: rowID, databasePath: warmDocument.profile), launch,
            "The newer native draft is genuinely unsaved before the callback")
        producer.activate()
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let warmText = "MiniApps rich warm שלום " + UUID().uuidString
        try typeActualStudioResult(warmText, producer: producer)
        let expectedWarm = try expectedNativeBodies(request: warm.request, text: warmText,
            bodyOverrides: [second: newerSecond])
        tap(producer.buttons["miniapps.textstudio.return"])
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
        host = try await richHost()
        try await assertNativeBodies(expectedWarm, host: host)
        try await requireNativeCondition(timeout: 60) {
            (try? self.records(in: shared).first { $0.request.id == warm.request.id }?.acknowledged) == true
        }
        let warmSaved = try richState(rowID: rowID, databasePath: warmDocument.profile)
        XCTAssertEqual(warmSaved.revision, launch.revision + 1)
        XCTAssertEqual(warmSaved.mutationID, warm.request.id)
        XCTAssertEqual(warmSaved.preview, expectedWarm.joined(separator: "\n"))
        XCTAssertNotEqual(warmSaved.bodySHA256, launch.bodySHA256)
        XCTAssertEqual(try persistedReceipt(requestID: warm.request.id,
            databasePath: warmDocument.profile).count, 1)
        retainScreenshot(app, named: "miniapps-rich-warm-preserved-newer-native-block")
        attachRichState(warmSaved, name: "miniapps-rich-warm-native-archive")

        // A second launch records a fresh native baseline, then the source is
        // terminated. No manual launch assists the callback or remount.
        tap(try await richBody(expectedWarm[0], host: host))
        let beforeCold = Set(try records(in: shared).map { $0.request.id })
        tap(app.buttons["annotation-expanded-editor-miniapps"])
        try await openActualTextStudio(producer)
        let cold = try XCTUnwrap(try records(in: shared).first { !beforeCold.contains($0.request.id) })
        let coldDocument = try JSONDecoder().decode(Document.self,
            from: Data(try XCTUnwrap(cold.request.source.metadata["otzaria.annotation.v1"]).utf8))
        XCTAssertEqual(coldDocument.annotationID, rowID)
        XCTAssertEqual(coldDocument.annotationUUID, warmDocument.annotationUUID)
        XCTAssertEqual(coldDocument.profile, warmDocument.profile)
        XCTAssertEqual(cold.request.source.kind, "native-annotation")
        XCTAssertEqual(cold.request.source.documentText, expectedWarm.joined(separator: "\n"))
        XCTAssertEqual(cold.request.operation, "insert")
        let coldBaseline = try richState(rowID: rowID, databasePath: coldDocument.profile)
        XCTAssertEqual(coldBaseline.revision, warmSaved.revision + 1)
        let coldText = "MiniApps rich cold שלום " + UUID().uuidString
        try typeActualStudioResult(coldText, producer: producer)
        let expectedCold = try expectedNativeBodies(request: cold.request, text: coldText)
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 20))
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 15))
        tap(producer.buttons["miniapps.textstudio.return"])
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 90),
            "Only the actual MiniApps callback may cold-launch the original source")
        host = try await richHost()
        try await assertNativeBodies(expectedCold, host: host)
        try await requireNativeCondition(timeout: 60) {
            (try? self.records(in: shared).first { $0.request.id == cold.request.id }?.acknowledged) == true
        }
        let coldSaved = try richState(rowID: rowID, databasePath: coldDocument.profile)
        XCTAssertEqual(coldSaved.revision, coldBaseline.revision + 1)
        XCTAssertEqual(coldSaved.mutationID, cold.request.id)
        XCTAssertEqual(coldSaved.preview, expectedCold.joined(separator: "\n"))
        XCTAssertTrue(expectedCold.contains(newerSecond))
        XCTAssertEqual(try persistedReceipt(requestID: cold.request.id,
            databasePath: coldDocument.profile).count, 1)
        XCTAssertEqual(try persistedReceipt(requestID: warm.request.id,
            databasePath: warmDocument.profile).count, 1)
        retainScreenshot(app, named: "miniapps-rich-cold-native-remount")
        attachRichState(coldSaved, name: "miniapps-rich-cold-native-archive")

        // Repeat the actual acknowledged callback URL; never fabricate a result.
        var callback = try XCTUnwrap(URLComponents(url: try XCTUnwrap(cold.request.callbacks.success),
            resolvingAgainstBaseURL: false))
        callback.queryItems = (callback.queryItems ?? []) + [
            .init(name: "request", value: cold.request.id.uuidString)
        ]
        retainScreenshot(app, named: "miniapps-rich-before-duplicate-callback")
        XCUIDevice.shared.press(.home)
        // Deliver through the OS. XCUIApplication.open is launch-equivalent and
        // would replace a warm replay with an unintended process relaunch.
        XCUIDevice.shared.system.open(try XCTUnwrap(callback.url))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 60))
        retainScreenshot(app, named: "miniapps-rich-duplicate-callback")
        XCTAssertEqual(try richState(rowID: rowID, databasePath: coldDocument.profile), coldSaved,
            "A duplicate callback must not create another native revision or rewrite its archive")
        XCTAssertEqual(try persistedReceipt(requestID: cold.request.id,
            databasePath: coldDocument.profile).count, 1)
    }

    @MainActor
    private func openActualTextStudio(_ producer: XCUIApplication) async throws {
        let action = app.buttons["miniapps-launch-nativeapp.textstudio"]
        if !action.waitForExistence(timeout: 3) { tap(app.buttons["miniapps-more"]) }
        XCTAssertTrue(action.waitForExistence(timeout: 30) && action.isHittable)
        tap(action)
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let editors = producer.textViews.matching(identifier: "miniapps.textstudio.editor")
        XCTAssertTrue(editors.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(editors.count, 1)
        XCTAssertEqual(editors.firstMatch.value as? String ?? "", "")
    }

    @MainActor
    private func typeActualStudioResult(_ text: String, producer: XCUIApplication) throws {
        let editor = producer.textViews["miniapps.textstudio.editor"]
        XCTAssertTrue(editor.exists && editor.isHittable)
        editor.tap(); editor.typeKey("a", modifierFlags: .command); editor.typeText(text)
        XCTAssertEqual(editor.value as? String, text)
        XCTAssertTrue(producer.buttons["miniapps.textstudio.return"].isHittable)
    }

    private func expectedNativeBodies(request: Request, text: String,
                                      bodyOverrides: [String: String] = [:]) throws -> [String] {
        let context = try JSONDecoder().decode(NativeContext.self, from:
            Data(try XCTUnwrap(request.source.metadata["otzaria.original-editor.miniapps.v1"]).utf8))
        let nodes = context.nodes.filter { $0.bodyText != nil }
        XCTAssertEqual(context.documentText, nodes.compactMap(\.bodyText).joined(separator: "\n"))
        var bodies = nodes.compactMap(\.bodyText).map { bodyOverrides[$0] ?? $0 }
        if context.blockIDs.isEmpty {
            XCTAssertNil(context.selectionLocation); XCTAssertNil(context.selectionLength)
            bodies.append(text)
        } else {
            XCTAssertEqual(context.blockIDs.count, 1)
            let index = try XCTUnwrap(nodes.firstIndex { $0.id == context.blockIDs.first })
            XCTAssertEqual(index, 0, "The actual first native body owns the selected insertion")
            let location = try XCTUnwrap(context.selectionLocation)
            let length = try XCTUnwrap(context.selectionLength)
            XCTAssertEqual(length, 0)
            let range = try XCTUnwrap(Range(NSRange(location: location, length: length), in: bodies[index]))
            bodies[index].insert(contentsOf: text, at: range.upperBound)
        }
        return bodies
    }

    @MainActor
    private func requireNativeCondition(timeout: TimeInterval,
                                        condition: @escaping @MainActor () throws -> Bool) async throws {
        let satisfied = try await waitUntil(timeout: timeout, condition: condition)
        XCTAssertTrue(satisfied)
    }

    @MainActor
    private func richHost() async throws -> XCUIElement {
        let hosts = app.descendants(matching: .any).matching(identifier: "annotation-expanded-editor-host")
        let save = app.buttons["annotation-expanded-editor-save"]
        try await requireNativeCondition(timeout: 120) {
            hosts.count == 1 && save.exists && save.isEnabled
        }
        XCTAssertEqual(hosts.count, 1)
        XCTAssertFalse(app.staticTexts["The editor could not finish"].exists)
        return hosts.firstMatch
    }

    @MainActor
    private func richBody(_ text: String, host: XCUIElement) async throws -> XCUIElement {
        let bodies = host.textViews.matching(NSPredicate(format: "value == %@", text))
        try await requireNativeCondition(timeout: 30) { bodies.count == 1 && bodies.firstMatch.isHittable }
        XCTAssertEqual(bodies.count, 1)
        XCTAssertFalse(bodies.firstMatch.frame.isEmpty)
        return bodies.firstMatch
    }

    @MainActor
    private func assertNativeBodies(_ expected: [String], host: XCUIElement) async throws {
        XCTAssertEqual(Set(expected).count, expected.count)
        for text in expected { _ = try await richBody(text, host: host) }
        XCTAssertEqual(host.textViews.matching(NSPredicate(format: "value IN %@", expected)).count, expected.count,
            "The actual original editor must retain the separate native blocks")
    }

    private func richState(rowID: Int64, databasePath: String) throws -> RichState {
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(databasePath, &connection,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        let database = try XCTUnwrap(connection)
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_db_readonly(database, "main"), 1)
        let sql = """
            SELECT h.revision, v.mutation_id, v.payload_digest, v.payload_base64, a.note
            FROM annotations a
            JOIN otzaria_annotation_exchange_heads h
              ON h.namespace = 'otzaria.local.annotation' AND lower(h.annotation_uuid) = lower(a.ckRecordId)
            JOIN otzaria_annotation_exchange_versions v
              ON v.namespace = h.namespace AND v.annotation_uuid = h.annotation_uuid AND v.revision = h.revision
            WHERE a.id = ?;
            """
        var prepared: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &prepared, nil), SQLITE_OK)
        let statement = try XCTUnwrap(prepared)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_bind_int64(statement, 1, rowID), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        func string(_ column: Int32) throws -> String {
            XCTAssertEqual(sqlite3_column_type(statement, column), SQLITE_TEXT)
            return String(cString: try XCTUnwrap(sqlite3_column_text(statement, column)))
        }
        let revision = sqlite3_column_int64(statement, 0)
        let mutationID = try XCTUnwrap(UUID(uuidString: try string(1)))
        let payloadDigest = try string(2)
        let encoded = try string(3)
        let preview = try string(4)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        let payload = try XCTUnwrap(Data(base64Encoded: encoded))
        XCTAssertEqual(payload.base64EncodedString(), encoded)
        XCTAssertEqual(SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined(), payloadDigest)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(envelope["namespace"] as? String, "otzaria.local.annotation")
        XCTAssertEqual(envelope["textPreview"] as? String, preview)
        let rich = try XCTUnwrap(envelope["richBody"] as? [String: Any])
        XCTAssertEqual(rich["format"] as? String, "anytype.native-protobuf-archive")
        XCTAssertEqual(rich["formatVersion"] as? Int, 1)
        let body = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(rich["bytesBase64"] as? String)))
        XCTAssertEqual(body.prefix(8), Data([0x41, 0x54, 0x4f, 0x53, 0x4e, 0x41, 0x50, 0]))
        return .init(revision: revision, mutationID: mutationID, payloadSHA256: payloadDigest,
            bodySHA256: SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined(),
            bodyBytes: body.count, preview: preview)
    }

    private func attachRichState(_ state: RichState, name: String) {
        let value: [String: Any] = ["revision": state.revision, "mutationID": state.mutationID.uuidString,
            "payloadSHA256": state.payloadSHA256, "bodySHA256": state.bodySHA256,
            "bodyBytes": state.bodyBytes, "preview": state.preview]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            XCTFail("Actual rich archive evidence is invalid"); return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    private func verifyReaderSelectionRoundTrip(producer: XCUIApplication, shared: URL,
                                               original: Document, expectedRows: Set<String>) async throws {
        let note = app.textViews["annotation-note-text"]
        tap(app.buttons["annotation-cancel-toolbar"])
        let originalEditorClosed = try await waitUntil(timeout: 20) { !note.exists }
        XCTAssertTrue(originalEditorClosed)
        let annotationsClose = app.navigationBars["Annotations"].buttons["Close"]
        if annotationsClose.exists { tap(annotationsClose) }
        assertReaderHasText()
        let reader = app.textViews["reader-text"]
        let renderedBefore = try XCTUnwrap(reader.value as? String)
        let corpus = try sourceCorpusDatabase()
        let beforeHash = try fileSHA256(corpus)
        let expectedHash = try XCTUnwrap(ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_CORPUS_SHA256"])
        XCTAssertEqual(beforeHash, expectedHash, "Read the actual canonical miniTest10 corpus")
        let beforeRequests = Set(try records(in: shared).map { $0.request.id })

        try await openMiniAppsFromNativeReaderSelection(reader)
        let studio = app.buttons["miniapps-launch-nativeapp.textstudio"]
        if !studio.waitForExistence(timeout: 3) { tap(app.buttons["miniapps-more"]) }
        XCTAssertTrue(studio.waitForExistence(timeout: 15))
        retainScreenshot(app, named: "otzaria-reader-selection-miniapps-chooser")
        tap(studio)
        XCTAssertTrue(producer.wait(for: .runningForeground, timeout: 30))
        let editors = producer.textViews.matching(identifier: "miniapps.textstudio.editor")
        XCTAssertTrue(editors.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(editors.count, 1)
        let editor = editors.element(boundBy: 0)
        let pending = try XCTUnwrap(try records(in: shared).first { !beforeRequests.contains($0.request.id) })
        let document = try JSONDecoder().decode(Document.self, from:
            Data(try XCTUnwrap(pending.request.source.metadata["otzaria.annotation.v1"]).utf8))
        let selection = try XCTUnwrap(pending.request.source.selection)
        let sourceText = try XCTUnwrap(pending.request.source.documentText)
        XCTAssertEqual(pending.request.source.kind, "reader")
        XCTAssertEqual(pending.request.appID, "nativeapp.textstudio")
        XCTAssertEqual(pending.request.operation, "insert")
        XCTAssertTrue(document.isReaderSelection)
        XCTAssertNil(document.annotationID)
        XCTAssertNotEqual(document.annotationUUID, original.annotationUUID)
        XCTAssertEqual(document.profile, original.profile)
        XCTAssertEqual(document.bookID, original.bookID)
        XCTAssertGreaterThan(selection.length, 0)
        XCTAssertEqual(document.rangeLocation, selection.location)
        XCTAssertEqual(document.rangeLength, selection.length)
        let selectedRange = try XCTUnwrap(Range(NSRange(location: selection.location, length: selection.length),
                                               in: sourceText))
        XCTAssertEqual(String(sourceText[selectedRange]), selection.text)
        XCTAssertEqual(pending.request.inputs.compactMap(\.text).joined(separator: "\n"), selection.text)
        XCTAssertEqual(editor.value as? String, selection.text)
        XCTAssertEqual(document.draftNote, "")

        let returnedText = "MiniApps reader note שלום " + UUID().uuidString
        editor.tap()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText(returnedText)
        XCTAssertEqual(editor.value as? String, returnedText)
        retainScreenshot(producer, named: "miniapps-reader-quotation-actual-textstudio-result")
        let returnButton = producer.buttons["miniapps.textstudio.return"]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 15) && returnButton.isHittable)
        returnButton.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertTrue(note.waitForExistence(timeout: 30))
        let readerNoteReturned = try await waitUntil(timeout: 30) { note.value as? String == returnedText }
        XCTAssertTrue(readerNoteReturned)
        let readerAcknowledged = try await waitUntil(timeout: 15) {
            (try? self.records(in: shared).first { $0.request.id == pending.request.id }?.acknowledged) == true
        }
        XCTAssertTrue(readerAcknowledged)
        let receipt = try persistedReceipt(requestID: pending.request.id, databasePath: document.profile)
        XCTAssertGreaterThan(receipt.annotationID, 0)
        XCTAssertNotEqual(receipt.annotationID, try XCTUnwrap(original.annotationID))
        XCTAssertEqual(receipt.annotationUUID, document.annotationUUID)
        XCTAssertEqual(receipt.bookID, document.bookID)
        XCTAssertEqual(receipt.contentID, document.contentID)
        XCTAssertEqual(receipt.rangeLocation, document.rangeLocation)
        XCTAssertEqual(receipt.rangeLength, document.rangeLength)
        XCTAssertEqual(receipt.context, document.context)
        XCTAssertEqual(receipt.note, returnedText)
        XCTAssertEqual(receipt.count, 1)
        retainScreenshot(app, named: "otzaria-reader-result-original-linked-note")
        attachReceipt(receipt, requestID: pending.request.id, name: "miniapps-reader-original-source-linked-receipt")

        tap(app.buttons["annotation-cancel-toolbar"])
        let readerNoteClosed = try await waitUntil(timeout: 20) { !note.exists }
        XCTAssertTrue(readerNoteClosed)
        assertReaderHasText()
        let renderedAfter = try XCTUnwrap(reader.value as? String)
        XCTAssertTrue(renderedBefore.utf8.elementsEqual(renderedAfter.utf8),
                      "Creating the linked note must preserve the actual displayed source")
        let afterHash = try fileSHA256(corpus)
        XCTAssertEqual(afterHash, beforeHash, "The original corpus database must remain byte-identical")
        let proof: [String: Any] = ["profileID": "miniTest10", "databaseName": corpus.lastPathComponent,
            "beforeSHA256": beforeHash, "afterSHA256": afterHash, "expectedSHA256": expectedHash,
            "readerTextUnchanged": renderedBefore.utf8.elementsEqual(renderedAfter.utf8),
            "requestID": pending.request.id.uuidString, "annotationID": receipt.annotationID]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]),
                                      uniformTypeIdentifier: "public.json")
        attachment.name = "miniapps-reader-original-corpus-unchanged"; attachment.lifetime = .keepAlways; add(attachment)
        retainScreenshot(app, named: "otzaria-reader-corpus-unchanged-after-miniapps")
        try await openAnnotations()
        XCTAssertEqual(Set(annotationRows().allElementsBoundByIndex.map(\.identifier)),
                       expectedRows.union(["original-book-annotation-" + String(receipt.annotationID)]))
        tap(app.navigationBars["Annotations"].buttons["Close"])
    }

    @MainActor
    private func nativeSelectionMiniAppsAction() -> XCUIElement? {
        let predicate = NSPredicate(format: "identifier == %@ OR label == %@",
                                    "otzaria-reader-miniapps", "Mini Apps")
        for query in [app.buttons, app.menuItems] {
            if let action = query.matching(predicate).allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable }) {
                return action
            }
        }
        return nil
    }

    @MainActor
    private func openMiniAppsFromNativeReaderSelection(_ reader: XCUIElement) async throws {
        // Real text gestures only: no programmatic selection or callback fixture.
        // The visible page can begin with short headings, so use bounded visible
        // text positions if the first long press lands in paragraph whitespace.
        let positions = [CGVector(dx: 0.78, dy: 0.14), CGVector(dx: 0.52, dy: 0.22),
                         CGVector(dx: 0.66, dy: 0.34)]
        for position in positions {
            XCTAssertTrue(reader.isHittable)
            reader.coordinate(withNormalizedOffset: position).press(forDuration: 1.2)
            let menuReady = try await waitUntil(timeout: 4) {
                self.nativeSelectionMiniAppsAction() != nil
                    || self.app.buttons["Copy"].firstMatch.exists || self.app.menuItems["Copy"].firstMatch.exists
            }
            if menuReady {
                for _ in 0..<3 {
                    if let action = nativeSelectionMiniAppsAction() {
                        retainScreenshot(app, named: "otzaria-reader-native-selection-miniapps-action")
                        tap(action)
                        return
                    }
                    let predicate = NSPredicate(format: "label IN %@ AND NOT (identifier BEGINSWITH %@)",
                        NSArray(array: ["More", "Show More", "Show more items", "More Actions", "Next"]), "reader-")
                    let candidates = app.menuItems.matching(predicate).allElementsBoundByIndex
                        + app.buttons.matching(predicate).allElementsBoundByIndex
                    guard let more = candidates.first(where: { $0.exists && $0.isHittable }) else { break }
                    tap(more)
                    _ = try await waitUntil(timeout: 3) { self.nativeSelectionMiniAppsAction() != nil }
                }
            }
            reader.tap()
        }
        retainScreenshot(app, named: "otzaria-reader-native-selection-menu-failure")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "otzaria-reader-selection-actual-accessibility-tree"; tree.lifetime = .keepAlways; add(tree)
        throw error("The actual original reader selection menu did not expose Mini Apps")
    }

    private func sourceCorpusDatabase() throws -> URL {
        let root = URL(fileURLWithPath: try XCTUnwrap(
            ProcessInfo.processInfo.environment["MINIAPPS_NATIVE_CORPUS_GROUP"]))
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])).allObjects.compactMap { $0 as? URL }
        let candidates = files.filter { url in
            guard url.lastPathComponent == "seforim.db",
                  let data = try? Data(contentsOf: url.deletingLastPathComponent()
                    .appendingPathComponent("seforim-installation.json")),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return (manifest["profileID"] as? String ?? manifest["effectiveProfileID"] as? String) == "miniTest10"
        }
        XCTAssertEqual(candidates.count, 1, "Use exactly the installed original miniTest10 corpus")
        return try XCTUnwrap(candidates.first)
    }

    private func fileSHA256(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url, options: [.mappedIfSafe]))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// XCTest may evaluate NSPredicate blocks off the main executor. Keep
    /// captured UI state and file observations on the test's explicit actor.
    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: @escaping @MainActor () throws -> Bool) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if try condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        } while Date() < deadline
        return false
    }

    @MainActor
    private func annotationRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT (identifier BEGINSWITH %@)",
            "original-book-annotation-", "original-book-annotation-edit-"))
    }

    @MainActor
    private func openAnnotations() async throws {
        tap(app.buttons["reader-more-menu"])
        // The original iPad tab bar also exposes Annotations. Select only
        // the reader's native Menu popover, using the same cell scope as the
        // original study-group menu acceptance helper.
        let action = app.collectionViews.cells.buttons.matching(
            NSPredicate(format: "label == %@", "Annotations")
        )
        XCTAssertTrue(action.firstMatch.waitForExistence(timeout: 15))
        retainScreenshot(app, named: "miniapps-original-reader-annotations-menu")
        let menuTree = XCTAttachment(string: app.debugDescription)
        menuTree.name = "miniapps-original-reader-annotations-menu-ax"
        menuTree.lifetime = .keepAlways
        add(menuTree)
        XCTAssertEqual(action.count, 1, "Require the unique Annotations action in the original reader popup")
        let menuAction = try XCTUnwrap(action.count == 1 ? action.allElementsBoundByIndex.first : nil)
        XCTAssertTrue(menuAction.isHittable)
        tap(menuAction)
        XCTAssertTrue(app.navigationBars["Annotations"].waitForExistence(timeout: 15))
        let list = app.descendants(matching: .any)["original-book-annotations-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "loaded"), object: list)
        let loadedOutcome = await XCTWaiter.fulfillment(of: [loaded], timeout: 15)
        XCTAssertEqual(loadedOutcome, .completed)
    }

    @MainActor
    private func editAnnotation(_ row: XCUIElement) {
        XCTAssertTrue(row.isHittable)
        let id = String(row.identifier.dropFirst("original-book-annotation-".count))
        XCTAssertNotNil(Int64(id))
        row.press(forDuration: 1)
        tap(app.buttons["original-book-annotation-edit-" + id])
    }

    private func records(in root: URL) throws -> [Record] {
        let directory = root.appendingPathComponent("requests", isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.map { try JSONDecoder().decode(Record.self, from: Data(contentsOf: $0)) }
            .filter { $0.request.source.appID == "com.davidpovarsky.chavrusatext" }
    }

    private func persistedReceipt(requestID: UUID, databasePath: String) throws -> Receipt {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databasePath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else { throw error("Cannot read original annotation database") }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        let sql = """
            SELECT r.annotation_id, a.ckRecordId, a.note, r.result_json,
                   (SELECT COUNT(*) FROM miniapps_result_receipts WHERE request_id = ?),
                   a.bkId, a.contentId, a.startIndex, a.length, a.context
            FROM miniapps_result_receipts r JOIN annotations a ON a.id = r.annotation_id
            WHERE r.request_id = ? AND r.annotation_uuid = a.ckRecordId;
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw error("Original durable receipt table/query is unavailable")
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, requestID.uuidString, -1, transient)
        sqlite3_bind_text(statement, 2, requestID.uuidString, -1, transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { throw error("Acknowledged result has no original saved row") }
        func string(_ column: Int32) -> String {
            sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
        }
        return Receipt(annotationID: sqlite3_column_int64(statement, 0), annotationUUID: string(1),
                       note: string(2), resultJSON: string(3), count: sqlite3_column_int64(statement, 4),
                       bookID: Int(sqlite3_column_int64(statement, 5)), contentID: Int(sqlite3_column_int64(statement, 6)),
                       rangeLocation: Int(sqlite3_column_int64(statement, 7)),
                       rangeLength: Int(sqlite3_column_int64(statement, 8)), context: string(9))
    }

    private func attachReceipt(_ receipt: Receipt, requestID: UUID, name: String) {
        let value: [String: Any] = ["requestID": requestID.uuidString, "annotationID": receipt.annotationID,
            "annotationUUID": receipt.annotationUUID, "note": receipt.note, "receiptCount": receipt.count,
            "savedResultJSON": receipt.resultJSON, "bookID": receipt.bookID, "contentID": receipt.contentID,
            "rangeLocation": receipt.rangeLocation, "rangeLength": receipt.rangeLength, "context": receipt.context]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            XCTFail("Actual receipt attachment is invalid"); return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor
    private func retainScreenshot(_ application: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: application.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func error(_ message: String) -> NSError {
        NSError(domain: "MiniAppsNativeAcceptance", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
