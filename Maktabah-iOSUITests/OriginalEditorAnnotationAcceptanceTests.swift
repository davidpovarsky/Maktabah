import XCTest

/// Separate owned simulator acceptance. The standard Native116/Release114
/// catalogs do not select this case or create the SDK's qualification account.
final class OriginalEditorAnnotationAcceptanceTests: FaithfulReaderUIBase {
    private let qualificationMarker = "owned-local-only"
    override var readerTestTier: TestTier { .realUI }

    @discardableResult
    override func launchWithTier(
        _ tier: TestTier, scenario: String? = nil, backend: String = "sefaria",
        extraArgs: [String] = [], language: String = "he", locale: String = "he_IL",
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        var environment = extraEnvironment
        environment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"] = qualificationMarker
        return super.launchWithTier(tier, scenario: scenario, backend: backend,
            extraArgs: extraArgs, language: language, locale: locale,
            extraEnvironment: environment)
    }

    @MainActor
    func testSavedBlankAnnotationUsesOriginalEditorAndDurablyReopensTwoBlocks() async throws {
        XCTAssertEqual(ProcessInfo.processInfo.environment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"],
                       qualificationMarker, "The dedicated Native route must opt in explicitly")
        guard ProcessInfo.processInfo.environment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"] == qualificationMarker else {
            throw failure("Missing owned Native qualification marker")
        }
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "en", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        let beforeViewport = try viewport()
        try attachWorkspaceSnapshot("original-editor-workspace-before")

        try await openOriginalBookAnnotations()
        let bookRows = originalBookAnnotationRows()
        let previousRows = Set(bookRows.allElementsBoundByIndex.map(\.identifier))
        tap(app.navigationBars["Annotations"].buttons["Close"])

        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tap(tools.buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let quickNote = app.textViews["annotation-note-text"]
        XCTAssertTrue(quickNote.waitForExistence(timeout: 15))
        XCTAssertEqual(quickNote.value as? String ?? "", "")
        let entry = app.buttons["annotation-original-editor-open"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "An absent framework is a failed qualification, never a skip")
        XCTAssertFalse(app.staticTexts["annotation-original-editor-unavailable"].exists)
        XCTAssertFalse(entry.isEnabled, "An unsaved annotation must not create a native editor")

        // Establish the row through the original native Save, with no body seed.
        tap(app.buttons["annotation-save-toolbar"])
        let noteClosed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: quickNote)
        let noteDismissal = await XCTWaiter.fulfillment(of: [noteClosed], timeout: 15)
        XCTAssertEqual(noteDismissal, .completed)
        tap(app.buttons["torah-inspector-close"])
        try await openOriginalBookAnnotations()
        let savedRow = try await newlySavedRow(previous: previousRows)
        try editOriginalBookAnnotation(savedRow)
        XCTAssertTrue(quickNote.waitForExistence(timeout: 15))
        XCTAssertEqual(quickNote.value as? String ?? "", "")
        XCTAssertTrue(entry.isEnabled)

        // Exercise the original quick-note guard using real input and Cancel.
        // Its bytes must never be silently discarded by the native entry.
        let pending = "Uncommitted quick note " + UUID().uuidString
        tap(quickNote)
        quickNote.typeText(pending)
        XCTAssertEqual(quickNote.value as? String, pending)
        XCTAssertFalse(entry.isEnabled)
        XCTAssertFalse(app.otherElements["annotation-original-editor-host"].exists)
        tap(app.buttons["annotation-cancel-toolbar"])
        XCTAssertTrue(savedRow.waitForExistence(timeout: 15))
        try editOriginalBookAnnotation(savedRow)
        XCTAssertTrue(quickNote.waitForExistence(timeout: 15))
        XCTAssertEqual(quickNote.value as? String ?? "", "", "Original Cancel preserved the saved blank row")
        XCTAssertTrue(entry.isEnabled)
        tap(entry)

        let opened = try await waitForStage("editing", timeout: 120)
        XCTAssertEqual(try string(opened, "qualification"), qualificationMarker)
        XCTAssertEqual(try string(opened, "bundle_id"), "com.davidpovarsky.chavrusatext")
        XCTAssertNotNil(UUID(uuidString: try string(opened, "annotation_uuid")))
        XCTAssertEqual(opened["initial_note_blank"] as? Bool, true)
        XCTAssertEqual(opened["initial_rich_body_absent"] as? Bool, true)
        XCTAssertEqual(try number(opened, "initial_revision"), 0)
        XCTAssertGreaterThan(try number(opened, "annotation_id"), 0)
        XCTAssertEqual(opened["preview_derived_from_native_body"] as? Bool, false)

        let firstText = "Original body alpha " + UUID().uuidString
        let secondText = "Original body beta " + UUID().uuidString
        let blank = try await uniqueBody(value: "")
        tap(blank)
        blank.typeText(firstText)
        let first = try await uniqueBody(value: firstText)
        // Return is processed by the original UITextView/delegate and creates
        // the second original block; no fixture RPC or body parser writes text.
        first.typeText("\n")
        let secondBlank = try await uniqueBody(value: "")
        tap(secondBlank)
        secondBlank.typeText(secondText)
        let second = try await uniqueBody(value: secondText)
        let currentFirst = try await uniqueBody(value: firstText)
        XCTAssertNotEqual(currentFirst.identifier, second.identifier,
                          "Two actual block identities are required, not two lines in one renderer")
        retainNativeEvidence("original-editor-two-typed-blocks")

        // The SDK must drain registered original UI writes and actual RPCs.
        // Visible optimistic text and endEditing are not treated as persistence.
        tap(app.buttons["annotation-original-editor-save"])
        let saved = try await waitForStage("saved", timeout: 120)
        let delivery = try string(saved, "commit_delivery")
        XCTAssertTrue(["committed", "completedWithoutOwnership"].contains(delivery))
        XCTAssertEqual(try string(saved, "annotation_uuid"), try string(opened, "annotation_uuid"))
        XCTAssertEqual(try number(saved, "annotation_id"), try number(opened, "annotation_id"))
        XCTAssertEqual(try number(saved, "commit_revision"), try number(opened, "initial_revision") + 1)
        XCTAssertEqual(saved["commit_replayed"] as? Bool, false)
        XCTAssertGreaterThan(try number(saved, "native_body_bytes"), 0)
        XCTAssertGreaterThan(try number(saved, "native_exported_object_count"), 0)
        XCTAssertEqual(try string(saved, "payload_digest").count, 64)
        XCTAssertEqual(try string(saved, "native_archive_sha256").count, 64)
        attachReceipt(saved, named: "original-editor-durable-same-uuid-receipt")
        XCTAssertFalse(app.buttons["annotation-save-toolbar"].isHittable,
                       "The stale quick-note Save must stay outside this captured-body journey")

        tap(app.buttons["annotation-original-editor-reopen"])
        let reopened = try await waitForStage("reopened", timeout: 120)
        XCTAssertEqual(try string(reopened, "reopened_annotation_uuid"), try string(opened, "annotation_uuid"))
        XCTAssertEqual(try number(reopened, "reopened_annotation_id"), try number(opened, "annotation_id"))
        XCTAssertEqual(try number(reopened, "reopened_revision"), try number(saved, "commit_revision"))
        XCTAssertEqual(try string(reopened, "reopened_payload_digest"), try string(saved, "payload_digest"))
        XCTAssertEqual(reopened["durable_body_verified_by_original_reopen"] as? Bool, true)
        XCTAssertEqual(reopened["preview_derived_from_native_body"] as? Bool, false)
        let restoredFirst = try await uniqueBody(value: firstText)
        let restoredSecond = try await uniqueBody(value: secondText)
        XCTAssertNotEqual(restoredFirst.identifier, restoredSecond.identifier)
        XCTAssertTrue(restoredFirst.isHittable && restoredSecond.isHittable,
                      "Both saved body blocks must be rendered by the newly opened original editor")
        retainNativeEvidence("original-editor-imported-two-rendered-blocks")
        attachReceipt(reopened, named: "original-editor-original-import-reopen-receipt")

        tap(app.buttons["annotation-original-editor-close"])
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: app.buttons["annotation-save-toolbar"])
        let waitResult = await XCTWaiter.fulfillment(of: [gone], timeout: 15)
        XCTAssertEqual(waitResult, .completed)
        XCTAssertFalse(app.buttons["annotation-original-editor-save"].exists)
        XCTAssertFalse(app.textViews["annotation-note-text"].exists,
                       "Closing the native journey must also close the stale quick-note sheet")
        XCTAssertTrue(savedRow.waitForExistence(timeout: 15), "The original saved annotation row remains")
        tap(app.navigationBars["Annotations"].buttons["Close"])
        let afterViewport = try viewport()
        XCTAssertEqual(afterViewport.source, beforeViewport.source)
        XCTAssertEqual(afterViewport.object, beforeViewport.object)
        XCTAssertEqual(afterViewport.offset, beforeViewport.offset, accuracy: 1)
        try attachWorkspaceSnapshot("original-editor-workspace-after")
    }

    @MainActor
    private func originalBookAnnotationRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT (identifier BEGINSWITH %@)",
            "original-book-annotation-", "original-book-annotation-edit-"))
    }

    @MainActor
    private func openOriginalBookAnnotations() async throws {
        tap(app.buttons["reader-more-menu"])
        let action = app.buttons.matching(NSPredicate(format: "label == %@", "Annotations"))
        XCTAssertTrue(action.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(action.count, 1)
        tap(action.firstMatch)
        XCTAssertTrue(app.navigationBars["Annotations"].waitForExistence(timeout: 15))
        let list = app.descendants(matching: .any)["original-book-annotations-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "loaded"), object: list)
        let result = await XCTWaiter.fulfillment(of: [loaded], timeout: 15)
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    private func editOriginalBookAnnotation(_ row: XCUIElement) throws {
        XCTAssertTrue(row.isHittable)
        let rawID = String(row.identifier.dropFirst("original-book-annotation-".count))
        XCTAssertNotNil(Int64(rawID))
        row.press(forDuration: 1)
        tap(app.buttons["original-book-annotation-edit-" + rawID])
    }

    @MainActor
    private func newlySavedRow(previous: Set<String>) async throws -> XCUIElement {
        let rows = originalBookAnnotationRows()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            rows.allElementsBoundByIndex.filter { !previous.contains($0.identifier) }.count == 1
        }, object: nil)
        let waitResult = await XCTWaiter.fulfillment(of: [ready], timeout: 15)
        XCTAssertEqual(waitResult, .completed)
        let additions = rows.allElementsBoundByIndex.filter { !previous.contains($0.identifier) }
        XCTAssertEqual(additions.count, 1)
        return try XCTUnwrap(additions.first)
    }

    @MainActor
    private func uniqueBody(value: String) async throws -> XCUIElement {
        let predicate = value.isEmpty
            ? NSPredicate(format: "identifier BEGINSWITH %@ AND (value == %@ OR value == nil)", "original-editor-block-text:", "")
            : NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "original-editor-block-text:", value)
        let query = app.textViews.matching(predicate)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 1"), object: query)
        let waitResult = await XCTWaiter.fulfillment(of: [ready], timeout: 20)
        XCTAssertEqual(waitResult, .completed)
        XCTAssertEqual(query.count, 1)
        let view = query.firstMatch
        XCTAssertFalse(view.identifier == "annotation-note-text" || view.identifier == "reader-text")
        XCTAssertTrue(view.isHittable)
        XCTAssertTrue(!view.frame.isEmpty && app.windows.firstMatch.frame.contains(view.frame))
        XCTAssertEqual(view.value as? String ?? "", value)
        return view
    }

    @MainActor
    private func waitForStage(_ expected: String, timeout: TimeInterval) async throws -> [String: Any] {
        let status = app.staticTexts["annotation-original-editor-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value IN %@",
            [expected, "failed", "committed-without-current-view"]), object: status)
        let waitResult = await XCTWaiter.fulfillment(of: [ready], timeout: timeout)
        XCTAssertEqual(waitResult, .completed)
        let evidence = app.staticTexts["annotation-original-editor-receipt"]
        let bytes = try XCTUnwrap((evidence.value as? String)?.data(using: .utf8))
        XCTAssertLessThanOrEqual(bytes.count, 32_768)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        attachReceipt(report, named: "original-editor-stage-" + expected)
        XCTAssertEqual(status.value as? String, expected)
        guard status.value as? String == expected else { throw failure("Original native stage failed") }
        return report
    }

    private func string(_ report: [String: Any], _ key: String) throws -> String {
        try XCTUnwrap(report[key] as? String, "Missing actual receipt field: " + key)
    }
    private func number(_ report: [String: Any], _ key: String) throws -> Int64 {
        try XCTUnwrap(report[key] as? NSNumber, "Missing actual receipt field: " + key).int64Value
    }
    private func attachReceipt(_ report: [String: Any], named name: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) else {
            XCTFail("Actual receipt must remain valid JSON"); return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func failure(_ reason: String) -> NSError {
        NSError(domain: "OriginalEditorAnnotationAcceptance", code: 1,
                userInfo: [NSLocalizedDescriptionKey: reason])
    }
}
