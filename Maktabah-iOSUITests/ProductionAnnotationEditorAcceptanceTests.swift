import XCTest
import CryptoKit
import SQLite3

/// Exercises the ordinary entry and canonical storage. It never activates the
/// SDK qualification account, injects native bodies, or writes SQLite directly.
final class ProductionAnnotationEditorAcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }

    @MainActor
    func testOrdinaryEditorSavesSameAnnotationDiscardsDraftAndRecoversAfterTermination() async throws {
        for key in ["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] {
            XCTAssertNil(ProcessInfo.processInfo.environment[key])
        }
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "en", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        XCTAssertNil(app.launchEnvironment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"])
        XCTAssertNil(app.launchEnvironment["OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"])
        XCTAssertNil(app.launchEnvironment["OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE"])
        assertReaderHasText()
        let initialViewport = try viewport()

        try await openAnnotations()
        let previousRows = Set(annotationRows().allElementsBoundByIndex.map(\.identifier))
        tap(app.navigationBars["Annotations"].buttons["Close"])
        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tap(tools.buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let quick = app.textViews["annotation-note-text"]
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        let entry = app.buttons["annotation-expanded-editor-open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        XCTAssertFalse(entry.isEnabled, "A new note must first obtain its real saved UUID")
        XCTAssertFalse(app.buttons["annotation-original-editor-open"].exists)

        let firstText = "Alpha שלום " + UUID().uuidString
        let secondText = "דברי תורה Beta " + UUID().uuidString
        tap(quick)
        quick.typeText(firstText)
        XCTAssertEqual(quick.value as? String, firstText)
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        let row = try await newAnnotationRow(previous: previousRows)
        let rowIdentifier = row.identifier
        let rowID = try XCTUnwrap(Int64(rowIdentifier.dropFirst("original-book-annotation-".count)))
        try editAnnotation(row)
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        XCTAssertEqual(quick.value as? String, firstText)
        try await waitForEnabled(entry)
        let originalPlain = try readCanonicalRow(rowID)
        XCTAssertEqual(originalPlain.preview, firstText)
        XCTAssertNil(originalPlain.body)
        attachStorage(originalPlain, stage: "saved-plain-row")

        // Clearing uses actual native selection and keyboard deletion. Empty
        // text is a real edit, not permission to restore a global cached draft.
        tap(quick)
        quick.typeKey("a", modifierFlags: .command)
        quick.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertEqual(quick.value as? String, "")
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        let cleared = try readCanonicalRow(rowID)
        XCTAssertEqual(cleared.id, originalPlain.id)
        XCTAssertEqual(cleared.uuid, originalPlain.uuid)
        XCTAssertEqual(cleared.preview, "")
        XCTAssertNil(cleared.body)
        attachStorage(cleared, stage: "native-clear-kept-same-uuid")
        try editAnnotation(row)
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        try await waitForEnabled(entry)
        XCTAssertEqual(quick.value as? String, "")
        tap(quick)
        quick.typeText(firstText)
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        try editAnnotation(row)
        try await waitForEnabled(entry)
        let before = try readCanonicalRow(rowID)
        XCTAssertEqual(before.id, originalPlain.id)
        XCTAssertEqual(before.uuid, originalPlain.uuid)
        XCTAssertEqual(before.preview, firstText)
        XCTAssertNil(before.body)

        // Real unsaved quick input must block expansion, and Cancel must leave
        // the canonical row unchanged. No helper resets the body for the test.
        tap(quick)
        quick.typeText(" pending")
        XCTAssertFalse(entry.isEnabled)
        tap(app.buttons["annotation-cancel-toolbar"])
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertEqual(try readCanonicalRow(rowID), before)
        try editAnnotation(row)
        try await waitForEnabled(entry)
        tap(entry)
        let host = try await expandedHost()
        let first = try await uniqueBody(firstText, in: host)
        // The known single-line body is selected through the actual UITextView.
        // The original Return delegate creates the second native block.
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        first.typeText("\n")
        let secondBlank = try await blankBody(after: firstText, in: host)
        tap(secondBlank)
        secondBlank.typeText(secondText)
        try await assertTwoBodies(firstText, secondText, in: host)
        retainNativeEvidence("normal-editor-two-original-blocks")
        tap(app.buttons["annotation-expanded-editor-save"])
        XCTAssertTrue(app.staticTexts["Note saved"].waitForExistence(timeout: 120))
        XCTAssertFalse(app.buttons["annotation-expanded-editor-save"].exists)
        let saved = try readCanonicalRow(rowID)
        XCTAssertEqual(saved.id, before.id)
        XCTAssertEqual(saved.uuid, before.uuid)
        XCTAssertEqual(saved.revision, before.revision + 1)
        XCTAssertNotNil(saved.body)
        XCTAssertGreaterThan(saved.body?.count ?? 0, 16)
        XCTAssertTrue(saved.preview.contains(firstText) && saved.preview.contains(secondText))
        XCTAssertNotEqual(saved.payloadDigest, before.payloadDigest)
        attachStorage(saved, stage: "native-body-saved-same-uuid")
        tap(app.buttons["annotation-expanded-editor-close"])
        try await waitForAbsence(quick)
        XCTAssertTrue(row.waitForExistence(timeout: 15))

        // Opening normally must restore the actual complete body. The legacy
        // quick Save stays disabled so its secondary preview cannot replace it.
        try editAnnotation(row)
        try await waitForEnabled(entry)
        XCTAssertFalse(app.buttons["annotation-save-toolbar"].isEnabled)
        tap(entry)
        let reopened = try await expandedHost()
        try await assertTwoBodies(firstText, secondText, in: reopened)
        let discardSuffix = " discarded-" + UUID().uuidString
        let second = try await uniqueBody(secondText, in: reopened)
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        second.typeText(discardSuffix)
        try await requireTypedFragment(discardSuffix, in: reopened)
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(quick)
        XCTAssertEqual(try readCanonicalRow(rowID), saved, "Discard never commits the private native draft")
        attachStorage(try readCanonicalRow(rowID), stage: "discard-preserved-canonical-bytes")

        // Terminate with an actual unsaved native edit, without an SDK resume
        // marker or a prepare-for-test hook. Reopening must use saved SQLite.
        try editAnnotation(row)
        try await waitForEnabled(entry)
        tap(entry)
        let beforeTermination = try await expandedHost()
        try await assertTwoBodies(firstText, secondText, in: beforeTermination)
        let interruptedSuffix = " interrupted-" + UUID().uuidString
        let interrupted = try await uniqueBody(secondText, in: beforeTermination)
        interrupted.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        interrupted.typeText(interruptedSuffix)
        try await requireTypedFragment(interruptedSuffix, in: beforeTermination)
        let arguments = app.launchArguments
        let environment = app.launchEnvironment
        retainNativeEvidence("normal-editor-uncommitted-before-termination")
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertEqual(app.launchArguments, arguments)
        XCTAssertEqual(app.launchEnvironment, environment)
        assertReaderHasText()
        let relaunchedViewport = try viewport()
        XCTAssertEqual(relaunchedViewport.source, initialViewport.source)
        XCTAssertEqual(relaunchedViewport.object, initialViewport.object)
        XCTAssertEqual(relaunchedViewport.offset, initialViewport.offset, accuracy: 1)
        try await openAnnotations()
        XCTAssertEqual(Set(annotationRows().allElementsBoundByIndex.map(\.identifier)),
                       previousRows.union([rowIdentifier]))
        let resumedRows = app.buttons.matching(identifier: rowIdentifier)
        XCTAssertEqual(resumedRows.count, 1)
        try editAnnotation(resumedRows.firstMatch)
        try await waitForEnabled(entry)
        XCTAssertFalse(app.buttons["annotation-save-toolbar"].isEnabled)
        tap(entry)
        let relaunched = try await expandedHost()
        try await assertTwoBodies(firstText, secondText, in: relaunched)
        XCTAssertFalse(relaunched.textViews.matching(NSPredicate(
            format: "value CONTAINS %@ OR value CONTAINS %@", discardSuffix, interruptedSuffix
        )).firstMatch.exists)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        attachStorage(try readCanonicalRow(rowID), stage: "cold-open-preserved-same-rich-body")
        retainNativeEvidence("normal-editor-cold-open-two-original-blocks")
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(quick)
        tap(app.navigationBars["Annotations"].buttons["Close"])
        let finalViewport = try viewport()
        XCTAssertEqual(finalViewport.source, initialViewport.source)
        XCTAssertEqual(finalViewport.object, initialViewport.object)
        XCTAssertEqual(finalViewport.offset, initialViewport.offset, accuracy: 1)
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
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "loaded"), object: list
        )], timeout: 15)
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    private func editAnnotation(_ row: XCUIElement) throws {
        XCTAssertTrue(row.isHittable)
        let rawID = String(row.identifier.dropFirst("original-book-annotation-".count))
        XCTAssertNotNil(Int64(rawID))
        row.press(forDuration: 1)
        tap(app.buttons["original-book-annotation-edit-" + rawID])
    }

    @MainActor
    private func newAnnotationRow(previous: Set<String>) async throws -> XCUIElement {
        let rows = annotationRows()
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                rows.allElementsBoundByIndex.filter { !previous.contains($0.identifier) }.count == 1
            }, object: nil
        )], timeout: 15)
        XCTAssertEqual(result, .completed)
        let additions = rows.allElementsBoundByIndex.filter { !previous.contains($0.identifier) }
        XCTAssertEqual(additions.count, 1)
        return try XCTUnwrap(additions.first)
    }

    @MainActor
    private func waitForEnabled(_ element: XCUIElement) async throws {
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: element
        )], timeout: 20)
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    private func waitForAbsence(_ element: XCUIElement) async throws {
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element
        )], timeout: 20)
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    private func expandedHost() async throws -> XCUIElement {
        let host = app.descendants(matching: .any).matching(identifier: "annotation-expanded-editor-host")
        let save = app.buttons["annotation-expanded-editor-save"]
        let failed = app.staticTexts["The editor could not finish"]
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in (host.count == 1 && save.isEnabled) || failed.exists }, object: nil
        )], timeout: 120)
        XCTAssertEqual(result, .completed)
        XCTAssertFalse(failed.exists)
        XCTAssertEqual(host.count, 1)
        XCTAssertTrue(save.isEnabled)
        return host.firstMatch
    }

    @MainActor
    private func uniqueBody(_ value: String, in host: XCUIElement) async throws -> XCUIElement {
        let query = host.textViews.matching(NSPredicate(format: "value == %@", value))
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 1"), object: query
        )], timeout: 20)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(query.count, 1)
        let body = query.firstMatch
        XCTAssertTrue(body.isHittable)
        XCTAssertFalse(body.frame.isEmpty)
        XCTAssertFalse(body.identifier == "annotation-note-text" || body.identifier == "reader-text")
        XCTAssertEqual(body.value as? String, value)
        return body
    }

    @MainActor
    private func assertTwoBodies(_ first: String, _ second: String, in host: XCUIElement) async throws {
        let a = try await uniqueBody(first, in: host)
        let b = try await uniqueBody(second, in: host)
        XCTAssertNotEqual(a.frame, b.frame, "Two real original UITextViews must render the saved blocks")
        XCTAssertEqual(host.textViews.matching(NSPredicate(format: "value IN %@", [first, second])).count, 2)
    }

    @MainActor
    private func requireTypedFragment(_ fragment: String, in host: XCUIElement) async throws {
        // RTL insertion need not be at the visual right edge. This assertion
        // observes the actual unsaved edit without assuming its caret position.
        let query = host.textViews.matching(NSPredicate(format: "value CONTAINS %@", fragment))
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count == 1"), object: query
        )], timeout: 20)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(query.count, 1)
        XCTAssertTrue(query.firstMatch.isHittable)
    }

    @MainActor
    private func blankBody(after text: String, in host: XCUIElement) async throws -> XCUIElement {
        let preceding = host.textViews.matching(NSPredicate(format: "value == %@", text))
        let empty = host.textViews.matching(NSPredicate(format: "value == %@ OR value == nil", ""))
        func candidates() -> [XCUIElement] {
            guard preceding.count == 1 else { return [] }
            let bottom = preceding.firstMatch.frame.maxY
            return empty.allElementsBoundByIndex.filter {
                $0.isHittable && !$0.frame.isEmpty && $0.frame.minY >= bottom - 1
            }
        }
        // The normal editor may also have an empty title. Require the newly
        // rendered body below the previous block, never the title above it.
        let result = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in candidates().count == 1 }, object: nil
        )], timeout: 20)
        XCTAssertEqual(result, .completed)
        let actual = candidates()
        XCTAssertEqual(actual.count, 1)
        return try XCTUnwrap(actual.first)
    }

    private struct CanonicalRow: Equatable {
        let id: Int64
        let uuid: UUID
        let preview: String
        let revision: Int64
        let payloadDigest: String?
        let payload: Data?
        let body: Data?
        let mutationID: String?
        let sourceDigest: String?
    }

    @MainActor
    private func readCanonicalRow(_ rowID: Int64) throws -> CanonicalRow {
        let initialPath = try XCTUnwrap(ProcessInfo.processInfo.environment["OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE"])
        XCTAssertTrue(initialPath.hasPrefix("/"))
        let initialDatabase = URL(fileURLWithPath: initialPath)
        let initialContainer = (0..<4).reduce(initialDatabase) { value, _ in value.deletingLastPathComponent() }
        // XCTest can relocate the installed app's data container. Reuse the
        // original UUID-bound workspace observer to resolve its current home.
        let sidecar = try workspaceSidecarURL()
        let container = (0..<6).reduce(sidecar) { value, _ in value.deletingLastPathComponent() }
        XCTAssertEqual(container.deletingLastPathComponent(), initialContainer.deletingLastPathComponent())
        XCTAssertEqual(container.resolvingSymlinksInPath().standardizedFileURL, container.standardizedFileURL)
        let databaseURL = container.appendingPathComponent("Library/Application Support/Maktabah-Debug/Annotations.sqlite")
        XCTAssertEqual(initialDatabase.lastPathComponent, databaseURL.lastPathComponent)
        let preferences = container.appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
        if FileManager.default.fileExists(atPath: preferences.path) {
            let values = try XCTUnwrap(PropertyListSerialization.propertyList(
                from: Data(contentsOf: preferences), format: nil) as? [String: Any])
            XCTAssertTrue(values["annotations_FolderPath"] == nil, "No selected-folder bookmark may be replaced")
            XCTAssertFalse(values["use_icloud_for_annotations"] as? Bool ?? false)
        }
        let path = databaseURL.path
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        let database = try XCTUnwrap(connection)
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_db_readonly(database, "main"), 1)
        // The original read path does not create exchange tables. A newly
        // saved plain note can therefore have no ledger until its first rich
        // commit. Observe that absence; never install a fixture schema here.
        var schemaStatement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database,
            "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name IN ('otzaria_annotation_exchange_heads', 'otzaria_annotation_exchange_versions')",
            -1, &schemaStatement, nil), SQLITE_OK)
        let schema = try XCTUnwrap(schemaStatement)
        defer { sqlite3_finalize(schema) }
        XCTAssertEqual(sqlite3_step(schema), SQLITE_ROW)
        let schemaCount = sqlite3_column_int(schema, 0)
        XCTAssertTrue(schemaCount == 0 || schemaCount == 2, "Partial native ledger schema is not a plain note")
        XCTAssertEqual(sqlite3_step(schema), SQLITE_DONE)
        let sql = schemaCount == 0 ? """
            SELECT id, ckRecordId, COALESCE(note, ''), NULL, NULL, NULL, NULL, NULL
            FROM annotations WHERE id = ?
            """ : """
            SELECT a.id, a.ckRecordId, COALESCE(a.note, ''), h.revision,
                   v.payload_digest, v.payload_base64, v.mutation_id, v.source_digest
            FROM annotations AS a
            LEFT JOIN otzaria_annotation_exchange_heads AS h
              ON h.namespace = 'otzaria.local.annotation' AND lower(h.annotation_uuid) = lower(a.ckRecordId)
            LEFT JOIN otzaria_annotation_exchange_versions AS v
              ON v.namespace = h.namespace AND v.annotation_uuid = h.annotation_uuid AND v.revision = h.revision
            WHERE a.id = ?
            """
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, sql, -1, &statement, nil), SQLITE_OK)
        let prepared = try XCTUnwrap(statement)
        defer { sqlite3_finalize(prepared) }
        XCTAssertEqual(sqlite3_bind_int64(prepared, 1, rowID), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(prepared), SQLITE_ROW)
        func text(_ column: Int32) throws -> String? {
            if sqlite3_column_type(prepared, column) == SQLITE_NULL { return nil }
            XCTAssertEqual(sqlite3_column_type(prepared, column), SQLITE_TEXT)
            XCTAssertLessThanOrEqual(sqlite3_column_bytes(prepared, column), 2_200_000)
            return String(cString: try XCTUnwrap(sqlite3_column_text(prepared, column)))
        }
        let id = sqlite3_column_int64(prepared, 0)
        let uuid = try XCTUnwrap(UUID(uuidString: try XCTUnwrap(text(1))))
        let preview = try XCTUnwrap(text(2))
        let revision = sqlite3_column_type(prepared, 3) == SQLITE_NULL ? 0 : sqlite3_column_int64(prepared, 3)
        let payloadDigest = try text(4)
        let encoded = try text(5)
        let mutationID = try text(6)
        let sourceDigest = try text(7)
        XCTAssertEqual(sqlite3_step(prepared), SQLITE_DONE, "Exactly one actual current version is allowed")
        var payload: Data?
        var body: Data?
        if let encoded {
            let bytes = try XCTUnwrap(Data(base64Encoded: encoded))
            XCTAssertEqual(bytes.base64EncodedString(), encoded)
            XCTAssertEqual(Self.sha256(bytes), payloadDigest)
            let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(envelope["schemaVersion"] as? Int, 1)
            XCTAssertEqual(envelope["namespace"] as? String, "otzaria.local.annotation")
            XCTAssertEqual(UUID(uuidString: try XCTUnwrap(envelope["annotationUUID"] as? String)), uuid)
            XCTAssertEqual(envelope["deletionState"] as? String, "active")
            XCTAssertEqual(envelope["textPreview"] as? String, preview)
            let rich = try XCTUnwrap(envelope["richBody"] as? [String: Any])
            XCTAssertEqual(rich["format"] as? String, "anytype.native-protobuf-archive")
            XCTAssertEqual(rich["formatVersion"] as? Int, 1)
            let richEncoded = try XCTUnwrap(rich["bytesBase64"] as? String)
            let richBytes = try XCTUnwrap(Data(base64Encoded: richEncoded))
            XCTAssertEqual(richBytes.base64EncodedString(), richEncoded)
            XCTAssertEqual(richBytes.prefix(8), Data([0x41, 0x54, 0x4f, 0x53, 0x4e, 0x41, 0x50, 0]))
            XCTAssertEqual(sourceDigest?.count, 64)
            XCTAssertNotNil(mutationID.flatMap(UUID.init(uuidString:)))
            payload = bytes
            body = richBytes
        } else {
            XCTAssertEqual(revision, 0, "An existing head cannot lose its committed envelope")
            XCTAssertNil(payloadDigest)
        }
        return CanonicalRow(id: id, uuid: uuid, preview: preview, revision: revision,
                            payloadDigest: payloadDigest, payload: payload, body: body,
                            mutationID: mutationID, sourceDigest: sourceDigest)
    }

    private static func sha256(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func attachStorage(_ row: CanonicalRow, stage: String) {
        let receipt: [String: Any] = [
            "stage": stage, "annotation_id": row.id, "annotation_uuid": row.uuid.uuidString,
            "revision": row.revision, "payload_sha256": row.payloadDigest ?? "",
            "native_body_bytes": row.body?.count ?? 0,
            "native_body_sha256": row.body.map(Self.sha256) ?? "",
            "source_sha256": row.sourceDigest ?? "", "mutation_id": row.mutationID ?? "",
            "sqlite_open_mode": "read-only", "qualification_mode": false
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]) else {
            XCTFail("Actual SQLite observation must be serializable"); return
        }
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "normal-annotation-" + stage
        attachment.lifetime = .keepAlways
        add(attachment)
        print("NORMAL_ANNOTATION_STORAGE " + String(decoding: bytes, as: UTF8.self))
    }
}
