import XCTest
import SQLite3
import CryptoKit

/// Runs only on the owned two-app simulator lane. No result or document fixture
/// is written by this test: both apps execute their actual public UI and bridge.
final class MiniAppsAnnotationAcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }

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
    private struct Request: Decodable {
        let id: UUID
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
        let action = app.buttons.matching(NSPredicate(format: "label == %@", "Annotations"))
        XCTAssertTrue(action.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(action.count, 1)
        tap(action.firstMatch)
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
