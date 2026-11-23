import XCTest
import SQLite3

/// Runs only on the owned two-app simulator lane. No result or document fixture
/// is written by this test: both apps execute their actual public UI and bridge.
final class MiniAppsAnnotationAcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }

    private struct Content: Decodable { let text: String? }
    private struct Source: Decodable {
        let appID: String
        let documentID: String?
        let documentText: String?
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
    }
    private struct Receipt {
        let annotationID: Int64
        let annotationUUID: String
        let note: String
        let resultJSON: String
        let count: Int64
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
        let catalogReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: catalog),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = value["items"] as? [[String: Any]] else { return false }
            return items.contains { $0["id"] as? String == "nativeapp.textstudio" }
        }, object: nil)
        let catalogReadyOutcome = await XCTWaiter.fulfillment(of: [catalogReady], timeout: 30)
        XCTAssertEqual(catalogReadyOutcome, .completed,
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
        let additions = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            currentRows.allElementsBoundByIndex.filter { !priorRows.contains($0.identifier) }.count == 1
        }, object: nil)
        let additionsOutcome = await XCTWaiter.fulfillment(of: [additions], timeout: 15)
        XCTAssertEqual(additionsOutcome, .completed)
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
        let acknowledged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (try? self.records(in: shared).first { $0.request.id == pending.request.id }?.acknowledged) == true
        }, object: nil)
        let acknowledgedOutcome = await XCTWaiter.fulfillment(of: [acknowledged], timeout: 15)
        XCTAssertEqual(acknowledgedOutcome, .completed)
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
                   (SELECT COUNT(*) FROM miniapps_result_receipts WHERE request_id = ?)
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
                       note: string(2), resultJSON: string(3), count: sqlite3_column_int64(statement, 4))
    }

    private func attachReceipt(_ receipt: Receipt, requestID: UUID, name: String) {
        let value: [String: Any] = ["requestID": requestID.uuidString, "annotationID": receipt.annotationID,
            "annotationUUID": receipt.annotationUUID, "note": receipt.note, "receiptCount": receipt.count,
            "savedResultJSON": receipt.resultJSON]
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
