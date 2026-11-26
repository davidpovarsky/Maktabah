import XCTest
import CryptoKit
import SQLite3
import UIKit

/// Exercises the ordinary entry and canonical storage. The scale test seeds
/// historical rows only while its disposable simulator’s application is stopped.
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

        // Opening the real account UI requires an actual native local AccountStop.
        // Cancelling before the explicit send must preserve the saved note, then
        // reopening native editing must recover the SAME private localOnly account.
        try editAnnotation(resumedRows.firstMatch)
        let share = app.buttons["annotation-anytype-share-open"]
        try await waitForEnabled(share)
        tap(share)
        let originalAccount = app.descendants(matching: .any)["annotation-anytype-original-account"]
        XCTAssertTrue(originalAccount.waitForExistence(timeout: 120))
        XCTAssertFalse(app.buttons["annotation-anytype-share-confirm"].exists)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        retainNativeEvidence("normal-local-editor-to-original-account-presentation")
        tap(app.buttons["annotation-anytype-share-close"])
        try await waitForAbsence(originalAccount)
        XCTAssertTrue(resumedRows.firstMatch.waitForExistence(timeout: 120))
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        try editAnnotation(resumedRows.firstMatch)
        try await waitForEnabled(entry)
        tap(entry)
        let afterAccountClose = try await expandedHost()
        try await assertTwoBodies(firstText, secondText, in: afterAccountClose)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        retainNativeEvidence("normal-original-account-close-to-local-editor")
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(quick)

        // Cancelled Share has no native mapping: no target/body/ACK is invented.
        try editAnnotation(resumedRows.firstMatch)
        let receive = app.buttons["annotation-anytype-receive-open"]
        try await waitForEnabled(receive)
        tap(receive)
        XCTAssertTrue(app.staticTexts["No shared copy in this space"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["annotation-anytype-receive-read"].exists)
        XCTAssertFalse(app.buttons["annotation-anytype-receive-accept"].exists)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        retainNativeEvidence("normal-receive-without-native-mapping-preserves-body")
        tap(app.buttons["annotation-anytype-receive-close"])
        try await waitForAbsence(quick)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        tap(app.navigationBars["Annotations"].buttons["Close"])
        let finalViewport = try viewport()
        XCTAssertEqual(finalViewport.source, initialViewport.source)
        XCTAssertEqual(finalViewport.object, initialViewport.object)
        XCTAssertEqual(finalViewport.offset, initialViewport.offset, accuracy: 1)
    }


    @MainActor
    func testOrdinaryPreparationConvertsSavedNoteOnceAndReopensNativeBodyAfterColdLaunch() async throws {
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
        let initial = try viewport()

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
        let savedText = "Backfill שלום תורה " + UUID().uuidString
        tap(quick)
        quick.typeText(savedText)
        XCTAssertEqual(quick.value as? String, savedText)
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        let row = try await newAnnotationRow(previous: previous)
        let identifier = row.identifier
        let rowID = try XCTUnwrap(Int64(identifier.dropFirst("original-book-annotation-".count)))
        let before = try readCanonicalRow(rowID)
        XCTAssertEqual(before.preview, savedText)
        XCTAssertNil(before.body)
        attachStorage(before, stage: "backfill-saved-plain-row")
        tap(app.navigationBars["Annotations"].buttons["Close"])

        try await openOrdinaryNotePreparation()
        let preparation = app.buttons["annotation-backfill-start"]
        let conversion = app.buttons["annotation-native-backfill-start"]
        XCTAssertTrue(preparation.waitForExistence(timeout: 15))
        try revealPreparationControl(conversion)
        XCTAssertTrue(conversion.exists)
        XCTAssertFalse(conversion.isEnabled, "Native conversion requires the original preparation step")
        XCTAssertFalse(app.staticTexts["annotation-native-backfill-workspace-unavailable"].exists)
        XCTAssertEqual(try readCanonicalRow(rowID), before, "Opening Settings must not convert notes")

        try revealPreparationControl(preparation, towardsBottom: false)
        tap(preparation)
        XCTAssertTrue(app.descendants(matching: .any)["annotation-backfill-complete"].waitForExistence(timeout: 120))
        XCTAssertFalse(app.staticTexts["annotation-backfill-error"].exists)
        try revealPreparationControl(conversion)
        try await waitForEnabled(conversion)
        XCTAssertEqual(try readCanonicalRow(rowID), before, "Local planning must not replace a saved body")
        try revealPreparationControl(conversion)
        tap(conversion)
        let confirm = app.buttons["annotation-native-backfill-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        try await cancelNativeBackfillConfirmation(confirm)
        XCTAssertEqual(try readCanonicalRow(rowID), before, "Cancelled confirmation must preserve the saved row and envelope")
        attachStorage(try readCanonicalRow(rowID), stage: "backfill-confirmation-cancelled")

        tap(conversion)
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        tap(confirm)
        try await waitForBackfillCompletion()
        let saved = try readCanonicalRow(rowID)
        XCTAssertEqual(saved.id, before.id)
        XCTAssertEqual(saved.uuid, before.uuid)
        XCTAssertEqual(saved.revision, before.revision + 1)
        XCTAssertEqual(Data(saved.preview.utf8), Data(savedText.utf8))
        XCTAssertNotNil(saved.body)
        XCTAssertGreaterThan(saved.body?.count ?? 0, 16)
        XCTAssertNotEqual(saved.payloadDigest, before.payloadDigest)
        attachStorage(saved, stage: "backfill-native-body-saved")
        retainNativeEvidence("backfill-original-conversion-and-same-saved-identity")

        // A second actual scan must preserve this committed rich version. It
        // must not issue another local Save or silently downgrade its format.
        try revealPreparationControl(conversion)
        tap(conversion)
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        tap(confirm)
        let convertedCount = app.staticTexts["annotation-native-backfill-converted"]
        let repeatedScan = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", "0 notes converted"),
            object: convertedCount
        )], timeout: 30)
        XCTAssertEqual(repeatedScan, .completed)
        try await waitForBackfillCompletion()
        XCTAssertEqual(convertedCount.label, "0 notes converted")
        XCTAssertTrue(app.staticTexts["annotation-native-backfill-rich"].exists)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        attachStorage(try readCanonicalRow(rowID), stage: "backfill-repeat-kept-same-version")
        try closeOrdinaryNotePreparation()

        let arguments = app.launchArguments
        let environment = app.launchEnvironment
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertEqual(app.launchArguments, arguments)
        XCTAssertEqual(app.launchEnvironment, environment)
        assertReaderHasText()
        let reopenedViewport = try viewport()
        XCTAssertEqual(reopenedViewport.source, initial.source)
        XCTAssertEqual(reopenedViewport.object, initial.object)
        XCTAssertEqual(reopenedViewport.offset, initial.offset, accuracy: 1)
        try await openAnnotations()
        XCTAssertEqual(Set(annotationRows().allElementsBoundByIndex.map(\.identifier)),
                       previous.union([identifier]))
        let resumed = app.buttons.matching(identifier: identifier)
        XCTAssertEqual(resumed.count, 1)
        try editAnnotation(resumed.firstMatch)
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["annotation-save-toolbar"].isEnabled)
        let entry = app.buttons["annotation-expanded-editor-open"]
        try await waitForEnabled(entry)
        tap(entry)
        let host = try await expandedHost()
        _ = try await uniqueBody(savedText, in: host)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        attachStorage(try readCanonicalRow(rowID), stage: "backfill-cold-native-render-kept-body")
        retainNativeEvidence("backfill-cold-open-original-native-body")
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(quick)
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        tap(app.navigationBars["Annotations"].buttons["Close"])
    }

    #if targetEnvironment(simulator)
    @MainActor
    func testOrdinaryPreparationBackfillsFiveThousandSavedSQLiteNotes() async throws {
        executionTimeAllowance = 14_400
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        for key in ["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] {
            XCTAssertNil(ProcessInfo.processInfo.environment[key])
        }
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "en", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        try await openAnnotations()
        let previous = Set(annotationRows().allElementsBoundByIndex.map(\.identifier))
        _ = try XCTUnwrap(previous.isEmpty ? true : nil, "The scale fixture requires a fresh annotations store")
        tap(app.navigationBars["Annotations"].buttons["Close"])
        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tap(tools.buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let quick = app.textViews["annotation-note-text"]
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        let marker = "Backfill שלום " + UUID().uuidString
        tap(quick)
        quick.typeText(marker)
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        let reference = try await newAnnotationRow(previous: previous)
        let referenceID = try XCTUnwrap(Int64(reference.identifier.dropFirst("original-book-annotation-".count)))
        let referenceRow = try readCanonicalRow(referenceID)
        XCTAssertEqual(referenceRow.preview, marker)
        XCTAssertEqual(referenceRow.revision, 0)
        XCTAssertNil(referenceRow.body)

        let databaseURL = try canonicalAnnotationDatabase()
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        let seeds = try seedHistoricalPlainNotes(reference: referenceRow, marker: marker, databaseURL: databaseURL)
        XCTAssertEqual(seeds.count, 5_000)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        assertReaderHasText()

        try await openOrdinaryNotePreparation()
        let preparation = app.buttons["annotation-backfill-start"]
        let conversion = app.buttons["annotation-native-backfill-start"]
        try revealPreparationControl(preparation, towardsBottom: false)
        tap(preparation)
        XCTAssertTrue(app.descendants(matching: .any)["annotation-backfill-complete"].waitForExistence(timeout: 300))
        try revealPreparationControl(conversion)
        try await waitForEnabled(conversion)
        tap(conversion)
        let confirm = app.buttons["annotation-native-backfill-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        tap(confirm)
        let complete = app.descendants(matching: .any)["annotation-native-backfill-complete"]
        let failure = app.descendants(matching: .any)["annotation-native-backfill-failed"]
        let closeFailure = app.descendants(matching: .any)["annotation-native-backfill-close-failed"]
        let paused = app.descendants(matching: .any)["annotation-native-backfill-paused"]
        let deadline = Date().addingTimeInterval(12_000)
        while !complete.exists && !failure.exists && !closeFailure.exists && !paused.exists && Date() < deadline {
            try await Task.sleep(for: .seconds(5))
        }
        guard complete.exists && !failure.exists && !closeFailure.exists && !paused.exists else {
            retainNativeEvidence("scale-backfill-terminal-error")
            XCTFail("The original bulk migration did not finish")
            return
        }
        let converted = app.staticTexts["annotation-native-backfill-converted"]
        XCTAssertEqual(converted.label.filter(\.isNumber), "5000")

        let convertedDatabase = try canonicalAnnotationDatabase()
        var payloadDigests = Set<String>()
        for seed in seeds {
            let row = try readCanonicalRow(seed.id, databaseURL: convertedDatabase)
            XCTAssertEqual(row.uuid, seed.uuid)
            XCTAssertEqual(row.preview, seed.text)
            XCTAssertEqual(row.revision, 1)
            XCTAssertNotNil(row.body)
            payloadDigests.insert(try XCTUnwrap(row.payloadDigest))
        }
        XCTAssertEqual(payloadDigests.count, 5_000)
        let samples = try [0, 2_499, 4_999].map { try readCanonicalRow(seeds[$0].id, databaseURL: convertedDatabase) }
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        assertReaderHasText()
        for row in samples {
            let persisted = try readCanonicalRow(row.id)
            XCTAssertEqual(persisted, row)
            attachStorage(persisted, stage: "scale-after-cold-relaunch")
        }
    }

    /// Seed historical inputs inside the owned simulator while its application is stopped.
    private func seedHistoricalPlainNotes(reference: CanonicalRow, marker: String, databaseURL: URL) throws
        -> [(id: Int64, uuid: UUID, text: String)] {
        let segments = databaseURL.standardizedFileURL.pathComponents
        guard let devices = segments.firstIndex(of: "Devices"), devices > 0, segments.count > devices + 2,
              segments[devices - 1] == "CoreSimulator", segments[devices + 2] == "data",
              UUID(uuidString: segments[devices + 1]) != nil,
              databaseURL.lastPathComponent == "Annotations.sqlite",
              databaseURL.resolvingSymlinksInPath() == databaseURL else {
            throw NSError(domain: "OriginalSQLiteBackfillFixture", code: Int(SQLITE_MISUSE),
                          userInfo: [NSLocalizedDescriptionKey: "Scale fixture is outside the installed simulator"])
        }
        var connection: OpaquePointer?
        let openResult = sqlite3_open_v2(databaseURL.path, &connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard openResult == SQLITE_OK, let database = connection else {
            if let connection { sqlite3_close(connection) }
            throw NSError(domain: "OriginalSQLiteBackfillFixture", code: Int(openResult))
        }
        defer { sqlite3_close(database) }
        func check(_ actual: Int32, _ expected: Int32 = SQLITE_OK) throws {
            guard actual == expected else {
                throw NSError(domain: "OriginalSQLiteBackfillFixture", code: Int(actual),
                              userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
            }
        }
        try check(sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil))
        var committed = false
        defer { if !committed { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) } }
        let sql = """
            INSERT INTO annotations (bkId, contentId, startIndex, length, startIndexDiac, lengthDiac,
                color, type, note, createdAt, context, part, page, ckRecordId, lastModified, backendLocator)
            SELECT bkId, contentId, startIndex, length, startIndexDiac, lengthDiac,
                color, type, ?, createdAt, context, part, page, ?, lastModified, backendLocator
            FROM annotations WHERE id = ?;
            """
        var statement: OpaquePointer?
        try check(sqlite3_prepare_v2(database, sql, -1, &statement, nil))
        guard let insert = statement else {
            throw NSError(domain: "OriginalSQLiteBackfillFixture", code: Int(SQLITE_INTERNAL))
        }
        defer { sqlite3_finalize(insert) }
        var rows: [(Int64, UUID, String)] = [(reference.id, reference.uuid, marker)]
        rows.reserveCapacity(5_000)
        let copyString = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for index in 1..<5_000 {
            let uuid = UUID()
            let text = "\(marker) \(index) 📖"
            try check(sqlite3_bind_text(insert, 1, text, -1, copyString))
            try check(sqlite3_bind_text(insert, 2, uuid.uuidString, -1, copyString))
            try check(sqlite3_bind_int64(insert, 3, reference.id))
            try check(sqlite3_step(insert), SQLITE_DONE)
            guard sqlite3_changes(database) == 1 else {
                throw NSError(domain: "OriginalSQLiteBackfillFixture", code: Int(SQLITE_NOTFOUND))
            }
            rows.append((sqlite3_last_insert_rowid(database), uuid, text))
            try check(sqlite3_reset(insert))
        }
        try check(sqlite3_exec(database, "COMMIT", nil, nil, nil))
        committed = true
        return rows
    }
    #endif

    @MainActor
    private func openOrdinaryNotePreparation() async throws {
        let settings = app.buttons["main-settings-button"]
        if !settings.exists || !settings.isHittable {
            let libraryPage = app.buttons["reader-sidebar-page-0"]
            if !libraryPage.exists || !libraryPage.isHittable {
                tap(readerSidebarToggle())
            }
            tap(libraryPage)
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        XCTAssertTrue(settings.isHittable)
        tap(settings)
        XCTAssertTrue(app.buttons["settings-done-button"].waitForExistence(timeout: 15))
        let entry = app.buttons["annotation-backfill-settings"]
        for _ in 0..<8 {
            if entry.exists && entry.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(entry.exists && entry.isHittable)
        tap(entry)
        XCTAssertTrue(app.buttons["annotation-backfill-start"].waitForExistence(timeout: 15))
    }

    @MainActor
    private func revealPreparationControl(_ control: XCUIElement, towardsBottom: Bool = true) throws {
        for _ in 0..<6 {
            if control.exists && control.isHittable { break }
            if towardsBottom { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(control.exists && control.isHittable)
    }

    @MainActor
    private func cancelNativeBackfillConfirmation(_ confirm: XCUIElement) async throws {
        let cancel = app.buttons["annotation-native-backfill-cancel-confirmation"]
        if cancel.exists && cancel.isHittable {
            tap(cancel)
        } else {
            // In a regular iOS size class SwiftUI omits the cancel action and
            // presents this confirmation as a popover. Dismiss the actual
            // presented container by a point proven outside its current frame.
            let windows = app.windows.allElementsBoundByIndex.filter {
                $0.exists && !$0.frame.isEmpty && $0.frame.contains(confirm.frame)
            }
            let window = try XCTUnwrap(windows.min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
            let presentations = app.descendants(matching: .popover)
                .containing(.button, identifier: "annotation-native-backfill-confirm")
                .allElementsBoundByIndex
                + app.sheets.containing(.button, identifier: "annotation-native-backfill-confirm")
                .allElementsBoundByIndex
            let frames = Set(presentations.filter {
                $0.exists && !$0.frame.isEmpty && $0.frame.contains(confirm.frame)
                    && $0.frame.width < window.frame.width - 32
                    && $0.frame.height < window.frame.height - 32
            }.map { NSValue(cgRect: $0.frame) })
            XCTAssertEqual(frames.count, 1, "Require one actual original confirmation popover")
            let popoverFrame = try XCTUnwrap(frames.first).cgRectValue
            let safeBounds = window.frame.insetBy(dx: 32, dy: 32)
            XCTAssertFalse(safeBounds.isEmpty)
            let points = [
                CGPoint(x: safeBounds.minX, y: safeBounds.minY),
                CGPoint(x: safeBounds.maxX, y: safeBounds.minY),
                CGPoint(x: safeBounds.minX, y: safeBounds.maxY),
                CGPoint(x: safeBounds.maxX, y: safeBounds.maxY)
            ]
            let outside = try XCTUnwrap(points.first {
                !popoverFrame.insetBy(dx: -16, dy: -16).contains($0)
            }, "A visible window point must be outside the presented popover")
            XCTAssertFalse(popoverFrame.contains(outside))
            retainNativeEvidence("backfill-original-confirmation-before-outside-dismissal")
            window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: outside.x - window.frame.minX, dy: outside.y - window.frame.minY
            )).tap()
        }
        try await waitForAbsence(confirm)
        XCTAssertFalse(confirm.exists)
    }

    @MainActor
    private func waitForBackfillCompletion() async throws {
        let complete = app.descendants(matching: .any)["annotation-native-backfill-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 180))
        XCTAssertFalse(app.staticTexts["annotation-native-backfill-failed"].exists)
        XCTAssertFalse(app.staticTexts["annotation-native-backfill-close-failed"].exists)
        XCTAssertTrue(app.staticTexts["annotation-native-backfill-converted"].exists)
    }

    @MainActor
    private func closeOrdinaryNotePreparation() throws {
        let done = app.buttons["settings-done-button"]
        if !done.exists || !done.isHittable {
            let back = app.navigationBars["Prepare existing notes"].buttons["Settings"]
            XCTAssertTrue(back.exists && back.isHittable)
            tap(back)
        }
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        tap(done)
        assertReaderHasText()
    }

    @MainActor
    private func annotationRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT (identifier BEGINSWITH %@)",
            "original-book-annotation-", "original-book-annotation-edit-"))
    }

    @MainActor
    private func openAnnotations() async throws {
        tap(app.buttons["reader-more-menu"])
        let action = app.collectionViews.cells.buttons.matching(
            NSPredicate(format: "label == %@", "Annotations")
        )
        XCTAssertTrue(action.firstMatch.waitForExistence(timeout: 15))
        let menuAction = try XCTUnwrap(action.count == 1 ? action.allElementsBoundByIndex.first : nil,
            "Expected the reader's Annotations action in its native menu")
        XCTAssertTrue(menuAction.isHittable)
        tap(menuAction)
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


    // These journeys use the original account UI and a dedicated real-network
    // development account. Its recovery key is never an app launch argument,
    // SDK constructor input, log message, attachment, or committed fixture.
    @MainActor
    func testOrdinarySharedNoteUpdatesSameObjectAndReceivesSavedContent() async throws {
        var context = try await createAndShareOrdinaryNativeNote(prefix: "Exchange")
        let shared = context.saved
        try editAnnotation(app.buttons[context.rowIdentifier])
        tap(app.buttons["annotation-expanded-editor-open"])
        let host = try await expandedHost()
        let discarded = " private-only-" + UUID().uuidString
        let second = try await uniqueBody(context.secondText, in: host)
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        second.typeText(discarded)
        try await requireTypedFragment(discarded, in: host)
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        XCTAssertEqual(try readCanonicalRow(context.rowID), shared)

        // Read the actual original copy after discarding the private edit.
        // Reading/closing the review must not modify the local canonical row.
        try await openOrdinaryNativeRead(context, updating: false)
        let review = app.descendants(matching: .any)["annotation-anytype-receive-review"]
        XCTAssertTrue(review.waitForExistence(timeout: 120))
        XCTAssertFalse(review.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", discarded)).firstMatch.exists)
        XCTAssertTrue(review.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", context.secondText)).firstMatch.exists)
        tap(app.buttons["annotation-anytype-receive-close"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        XCTAssertEqual(try readCanonicalRow(context.rowID), shared)
        attachExchangeStorage(shared, stage: "discard-remained-private", objectID: context.objectID)

        context = try await editAndSaveOrdinaryNativeNote(context, suffix: " saved-update")
        let beforeUpdate = try nativeHistoryRecords(context.saved.uuid,
            suffix: ".native-revision-history",
            schema: "otzaria.original.annotation.revision-result.v1")
        try await openOrdinaryNativeRead(context, updating: true)
        let accept = app.buttons["annotation-anytype-update-accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 120))
        tap(accept)
        let confirm = app.buttons.matching(NSPredicate(
            format: "label == %@", "Update this copy in Anytype")).allElementsBoundByIndex.filter(\.isHittable)
        try nativeRequire(confirm.count == 1, "Require one actual update confirmation")
        tap(try XCTUnwrap(confirm.first))
        let verified = app.descendants(matching: .any)["annotation-anytype-update-verified"]
        XCTAssertTrue(verified.waitForExistence(timeout: 120))
        XCTAssertFalse(app.descendants(matching: .any)["annotation-anytype-update-unverified"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["annotation-anytype-update-conflict"].exists)
        _ = try verifyNewNativeHistory(context, previous: beforeUpdate,
            suffix: ".native-revision-history", schema: "otzaria.original.annotation.revision-result.v1")
        XCTAssertEqual(try readCanonicalRow(context.rowID), context.saved)
        tap(app.buttons["annotation-anytype-receive-close"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        attachExchangeStorage(context.saved, stage: "same-object-update", objectID: context.objectID)

        try await openOrdinaryNativeRead(context, updating: false)
        let receive = app.buttons["annotation-anytype-receive-accept"]
        XCTAssertTrue(receive.waitForExistence(timeout: 120))
        tap(receive)
        let use = app.buttons.matching(NSPredicate(
            format: "label == %@", "Use the Anytype version here")).allElementsBoundByIndex.filter(\.isHittable)
        try nativeRequire(use.count == 1, "Require one actual receive confirmation")
        tap(try XCTUnwrap(use.first))
        XCTAssertTrue(app.descendants(matching: .any)["annotation-anytype-receive-saved"]
            .waitForExistence(timeout: 120))
        let received = try readCanonicalRow(context.rowID)
        XCTAssertEqual(received.id, context.saved.id)
        XCTAssertEqual(received.uuid, context.saved.uuid)
        XCTAssertEqual(received.revision, context.saved.revision + 1)
        XCTAssertNotNil(received.body)
        XCTAssertTrue(received.preview.contains(context.firstText))
        XCTAssertTrue(received.preview.contains(context.secondText))
        tap(app.buttons["annotation-anytype-receive-close"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        context.saved = received
        try await coldReopenOrdinaryNativeNote(context)
        attachExchangeStorage(received, stage: "received-and-cold-reopened", objectID: context.objectID)
    }

    @MainActor
    func testOrdinaryNativeCopyChiddushLifecyclePreservesIdentity() async throws {
        try await exerciseOrdinaryNativeLifecycle(role: "chiddush", title: "Chiddush",
            promotion: "Turn into a chiddush")
    }

    @MainActor
    func testOrdinaryNativeCopyArticleLifecyclePreservesIdentity() async throws {
        try await exerciseOrdinaryNativeLifecycle(role: "article", title: "Article",
            promotion: "Turn into an article")
    }

    @MainActor
    func testOrdinaryNativeCopyResearchLifecyclePreservesIdentity() async throws {
        try await exerciseOrdinaryNativeLifecycle(role: "research", title: "Research",
            promotion: "Turn into research")
    }

    private struct OrdinaryNativeExchangeContext {
        let rowIdentifier: String
        let rowID: Int64
        let firstText: String
        var secondText: String
        var saved: CanonicalRow
        let objectID: String
    }

    private enum OrdinaryNetworkFixture {
        static let accountID = "AA5y2wipdZPPGiMoK3hckf6DUJQHHehNPt6BgyenPamSnfQm"
        static let spaceID = "bafyreigdy7rjfil42wczgnam5njdwy5e2pcio23p2jls4ycgtzmp3usdqa.2xu9o61hnno0b"
        static let spaceTitle = "Otzaria original network acceptance"
        // Reserved for the independent peer CAS regression. UI creates new notes.
        static let protectedRoot = "bafyreiarjeh5gi2eb6cespoglsvraum4ku226iainadbhfkncyvsavgadm"
        static let keyPath = "/Users/m1/builds/anytype-original-network-acceptance-20261125/run-1-private/development-mnemonic.private"
    }

    private enum OrdinaryNativeAcceptanceError: Error { case failed(String) }

    private func nativeRequire(_ value: Bool, _ message: String) throws {
        guard value else {
            XCTFail(message)
            throw OrdinaryNativeAcceptanceError.failed(message)
        }
    }

    @MainActor
    private func createAndShareOrdinaryNativeNote(prefix: String) async throws -> OrdinaryNativeExchangeContext {
        try nativeRequire(ProcessInfo.processInfo.environment["OTZARIA_ANYTYPE_NETWORK_UI"] == "test-owned-original-account",
            "This journey requires the explicit private development-account route")
        for key in ["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] {
            XCTAssertNil(ProcessInfo.processInfo.environment[key])
        }
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(scenario: "readerDetail", backend: "otzaria", language: "en", recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        XCTAssertNil(app.launchEnvironment["OTZARIA_ANYTYPE_NETWORK_UI"])
        XCTAssertNil(app.launchEnvironment["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION"])
        XCTAssertNil(app.launchEnvironment["OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"])
        assertReaderHasText()
        try await openAnnotations()
        let previous = Set(annotationRows().allElementsBoundByIndex.map(\.identifier))
        tap(app.navigationBars["Annotations"].buttons["Close"])
        tap(try originalStudyToolsActionInWindow())
        tap(app.segmentedControls["torah-inspector-tools"].buttons["Notes"])
        tap(app.buttons["torah-inspector-add-note"])
        let quick = app.textViews["annotation-note-text"]
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        let first = prefix + " original UI " + UUID().uuidString
        let second = "Hebrew source \u{05ea}\u{05d5}\u{05e8}\u{05d4} " + UUID().uuidString
        tap(quick); quick.typeText(first)
        tap(app.buttons["annotation-save-toolbar"])
        try await waitForAbsence(quick)
        tap(app.buttons["torah-inspector-close"])
        try await openAnnotations()
        let row = try await newAnnotationRow(previous: previous)
        let identifier = row.identifier
        let rowID = try XCTUnwrap(Int64(identifier.dropFirst("original-book-annotation-".count)))
        try editAnnotation(row)
        try await waitForEnabled(app.buttons["annotation-expanded-editor-open"])
        tap(app.buttons["annotation-expanded-editor-open"])
        let host = try await expandedHost()
        let body = try await uniqueBody(first, in: host)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        body.typeText("\n")
        let blank = try await blankBody(after: first, in: host)
        tap(blank); blank.typeText(second)
        try await assertTwoBodies(first, second, in: host)
        tap(app.buttons["annotation-expanded-editor-save"])
        XCTAssertTrue(app.staticTexts["Note saved"].waitForExistence(timeout: 120))
        let saved = try readCanonicalRow(rowID)
        try nativeRequire(saved.body != nil, "The ordinary native editor must save an actual rich body")
        tap(app.buttons["annotation-expanded-editor-close"])
        try await waitForAbsence(quick)
        try editAnnotation(app.buttons[identifier])
        try await waitForEnabled(app.buttons["annotation-anytype-share-open"])
        tap(app.buttons["annotation-anytype-share-open"])
        try await selectOriginalDevelopmentSpace(accountViewID: "annotation-anytype-original-account")
        let selected = app.staticTexts["annotation-anytype-selected-space"]
        XCTAssertTrue(selected.waitForExistence(timeout: 120))
        try nativeRequire(selected.label == OrdinaryNetworkFixture.spaceID,
            "Refuse to send unless the original UI selected the exact test-owned Space")
        let send = app.buttons["annotation-anytype-share-confirm"]
        try await waitForEnabled(send)
        tap(send)
        XCTAssertTrue(app.descendants(matching: .any)["annotation-anytype-native-copy-verified"]
            .waitForExistence(timeout: 120))
        let imports = try nativeHistoryRecords(saved.uuid, suffix: ".native-import-history",
            schema: "otzaria.original.annotation.native-commit.v1")
        try nativeRequire(imports.count == 1, "One ordinary send must produce one actual import receipt")
        let record = try XCTUnwrap(imports.values.first)
        try nativeRequire(record["status"] as? String == "LOCAL_NATIVE_IMPORT_READBACK_VERIFIED",
            "The original import must have genuine readback")
        try nativeRequire(record["accountID"] as? String == OrdinaryNetworkFixture.accountID
            && record["spaceID"] as? String == OrdinaryNetworkFixture.spaceID,
            "The receipt must belong to the genuine test-owned account and Space")
        try nativeRequire(record["annotationUUID"] as? String == saved.uuid.uuidString
            && (record["savedRevision"] as? NSNumber)?.int64Value == saved.revision
            && record["payloadDigest"] as? String == saved.payloadDigest
            && record["bodyDigest"] as? String == saved.body.map(Self.sha256),
            "The actual import must bind the saved local note exactly")
        try verifyNativeResponse(record)
        let objectID = try XCTUnwrap(record["objectID"] as? String)
        try nativeRequire(!objectID.isEmpty && objectID != OrdinaryNetworkFixture.protectedRoot,
            "UI must create its own root and preserve the independent peer regression object")
        XCTAssertEqual(try readCanonicalRow(rowID), saved)
        tap(app.buttons["annotation-anytype-share-close"])
        try await waitForAbsence(quick)
        attachExchangeStorage(saved, stage: "ordinary-native-copy", objectID: objectID)
        return .init(rowIdentifier: identifier, rowID: rowID, firstText: first,
            secondText: second, saved: saved, objectID: objectID)
    }

    @MainActor
    private func selectOriginalDevelopmentSpace(accountViewID: String) async throws {
        let account = app.descendants(matching: .any)[accountViewID]
        XCTAssertTrue(account.waitForExistence(timeout: 120))
        let login = account.buttons["I already have a key"]
        let space = account.buttons.matching(NSPredicate(format: "label == %@", OrdinaryNetworkFixture.spaceTitle))
        let ready = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in login.exists || space.count > 0 }, object: nil)], timeout: 120)
        XCTAssertEqual(ready, .completed)
        if login.exists {
            tap(login)
            let fields = account.textViews
            XCTAssertTrue(fields.firstMatch.waitForExistence(timeout: 30))
            try nativeRequire(fields.count == 1, "Require the original single recovery-key field")
            let file = URL(fileURLWithPath: OrdinaryNetworkFixture.keyPath)
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            try nativeRequire(values.isRegularFile == true && values.isSymbolicLink != true
                && (values.fileSize ?? 0) > 0 && (values.fileSize ?? 0) < 2048
                && ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o077 == 0,
                "Only the retained private development fixture may enter the original login UI")
            let phrase = try String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            // Paste through the original UIKit editing menu. No typeText call,
            // assertion, attachment or test log receives the recovery-key value.
            UIPasteboard.general.setItems([["public.utf8-plain-text": phrase]], options: [
                .localOnly: true, .expirationDate: Date().addingTimeInterval(120)
            ])
            defer { UIPasteboard.general.items = [] }
            let field = fields.firstMatch
            tap(field); field.press(forDuration: 1)
            let menuPaste = app.menuItems["Paste"]
            let buttonPaste = app.buttons["Paste"]
            let pasteReady = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in menuPaste.exists || buttonPaste.exists }, object: nil)], timeout: 15)
            XCTAssertEqual(pasteReady, .completed)
            if menuPaste.exists && menuPaste.isHittable { tap(menuPaste) }
            else { try nativeRequire(buttonPaste.exists && buttonPaste.isHittable, "Original Paste must be visible"); tap(buttonPaste) }
            if app.alerts.buttons["Allow Paste"].waitForExistence(timeout: 2) {
                tap(app.alerts.buttons["Allow Paste"])
            }
            let enter = account.buttons["Enter"]
            try await waitForEnabled(enter)
            tap(enter)
            XCTAssertTrue(space.firstMatch.waitForExistence(timeout: 120))
        }
        try nativeRequire(space.count == 1, "Require one real original picker row for the owned Space")
        tap(space.firstMatch)
        // Evidence may resume only after the credential UI has gone away.
        let closed = await XCTWaiter.fulfillment(of: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: account)], timeout: 120)
        XCTAssertEqual(closed, .completed)
    }

    @MainActor
    private func openOrdinaryNativeRead(_ context: OrdinaryNativeExchangeContext, updating: Bool) async throws {
        try editAnnotation(app.buttons[context.rowIdentifier])
        let open = app.buttons[updating ? "annotation-anytype-update-open" : "annotation-anytype-receive-open"]
        try await waitForEnabled(open); tap(open)
        try await selectOriginalDevelopmentSpace(accountViewID: "annotation-anytype-receive-account")
        let read = app.buttons["annotation-anytype-receive-read"]
        try await waitForEnabled(read)
        tap(read)
    }

    @MainActor
    private func editAndSaveOrdinaryNativeNote(_ original: OrdinaryNativeExchangeContext,
                                              suffix: String) async throws -> OrdinaryNativeExchangeContext {
        var context = original
        try editAnnotation(app.buttons[context.rowIdentifier])
        try await waitForEnabled(app.buttons["annotation-expanded-editor-open"])
        tap(app.buttons["annotation-expanded-editor-open"])
        let host = try await expandedHost()
        let second = try await uniqueBody(context.secondText, in: host)
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        second.typeText(suffix)
        context.secondText += suffix
        try await assertTwoBodies(context.firstText, context.secondText, in: host)
        tap(app.buttons["annotation-expanded-editor-save"])
        XCTAssertTrue(app.staticTexts["Note saved"].waitForExistence(timeout: 120))
        context.saved = try readCanonicalRow(context.rowID)
        XCTAssertEqual(context.saved.uuid, original.saved.uuid)
        XCTAssertEqual(context.saved.revision, original.saved.revision + 1)
        XCTAssertNotEqual(context.saved.body, original.saved.body)
        tap(app.buttons["annotation-expanded-editor-close"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        return context
    }

    @MainActor
    private func exerciseOrdinaryNativeLifecycle(role: String, title: String, promotion: String) async throws {
        var context = try await createAndShareOrdinaryNativeNote(prefix: title)
        try await manageOrdinaryNativeCopy(context, currentType: "Annotation",
            action: "Archive this copy", wireAction: "archive", archived: true, resultingRole: nil)
        try await manageOrdinaryNativeCopy(context, currentType: "Annotation",
            action: "Restore this copy", wireAction: "restore", archived: false, resultingRole: nil)
        try await manageOrdinaryNativeCopy(context, currentType: "Annotation",
            action: promotion, wireAction: "promote", archived: false, resultingRole: role)
        context = try await editAndSaveOrdinaryNativeNote(context, suffix: " updated-" + role)
        try await manageOrdinaryNativeCopy(context, currentType: title,
            action: "Update this document from the saved note", wireAction: "replace-promoted-document",
            archived: false, resultingRole: role)
        try await manageOrdinaryNativeCopy(context, currentType: title,
            action: "Archive this copy", wireAction: "archive", archived: true, resultingRole: role)
        try await manageOrdinaryNativeCopy(context, currentType: title,
            action: "Restore this copy", wireAction: "restore", archived: false, resultingRole: role)
        try await manageOrdinaryNativeCopy(context, currentType: title,
            action: "Return to an annotation", wireAction: "revert-promotion", archived: false, resultingRole: nil)
        try await coldReopenOrdinaryNativeNote(context)
        attachExchangeStorage(context.saved, stage: role + "-lifecycle-cold", objectID: context.objectID)
    }

    @MainActor
    private func chooseOriginalManagePicker(_ identifier: String, option: String) throws {
        let picker = app.descendants(matching: .any)[identifier]
        try nativeRequire(picker.exists && picker.isHittable, "Require the original manage picker")
        tap(picker)
        let choices = app.buttons.matching(NSPredicate(format: "label == %@", option))
            .allElementsBoundByIndex.filter(\.isHittable)
        try nativeRequire(choices.count == 1, "Require one actual picker option: " + option)
        tap(try XCTUnwrap(choices.first))
    }

    @MainActor
    private func manageOrdinaryNativeCopy(_ context: OrdinaryNativeExchangeContext,
        currentType: String, action: String, wireAction: String, archived: Bool, resultingRole: String?) async throws {
        let previous = try nativeHistoryRecords(context.saved.uuid, suffix: ".native-lifecycle-history",
            schema: "otzaria.original.annotation.lifecycle-result.v1")
        try editAnnotation(app.buttons[context.rowIdentifier])
        let open = app.buttons["annotation-anytype-manage-open"]
        try await waitForEnabled(open); tap(open)
        try await selectOriginalDevelopmentSpace(accountViewID: "annotation-anytype-manage-account")
        try chooseOriginalManagePicker("annotation-anytype-manage-copy", option: "Shared copy 1")
        try chooseOriginalManagePicker("annotation-anytype-manage-type", option: currentType)
        try chooseOriginalManagePicker("annotation-anytype-manage-action", option: action)
        tap(app.buttons["annotation-anytype-manage-read"])
        XCTAssertTrue(app.descendants(matching: .any)["annotation-anytype-manage-review"]
            .waitForExistence(timeout: 120))
        let apply = app.buttons["annotation-anytype-manage-apply"]
        try await waitForEnabled(apply); tap(apply)
        let confirm = app.buttons["annotation-anytype-manage-confirm"]
        try await waitForEnabled(confirm); tap(confirm)
        XCTAssertTrue(app.descendants(matching: .any)["annotation-anytype-manage-verified"]
            .waitForExistence(timeout: 120))
        let record = try verifyNewNativeHistory(context, previous: previous,
            suffix: ".native-lifecycle-history", schema: "otzaria.original.annotation.lifecycle-result.v1")
        let actualAction = try XCTUnwrap(record["action"] as? [String: Any])
        XCTAssertEqual(actualAction["name"] as? String, wireAction)
        XCTAssertEqual(actualAction["role"] as? String, wireAction == "promote" ? resultingRole : nil)
        XCTAssertEqual(record["isArchived"] as? Bool, archived)
        XCTAssertEqual(record["documentRole"] as? String, resultingRole)
        XCTAssertEqual(try readCanonicalRow(context.rowID), context.saved,
            "Managing the original shared copy must not replace the private saved local note")
        tap(app.buttons["annotation-anytype-manage-close"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
        attachExchangeStorage(context.saved, stage: (resultingRole ?? "annotation") + "-" + wireAction,
            objectID: context.objectID)
    }

    @MainActor
    private func coldReopenOrdinaryNativeNote(_ context: OrdinaryNativeExchangeContext) async throws {
        let args = app.launchArguments, environment = app.launchEnvironment
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        XCTAssertEqual(app.launchArguments, args); XCTAssertEqual(app.launchEnvironment, environment)
        assertReaderHasText()
        try await openAnnotations()
        try editAnnotation(app.buttons[context.rowIdentifier])
        try await waitForEnabled(app.buttons["annotation-expanded-editor-open"])
        tap(app.buttons["annotation-expanded-editor-open"])
        let host = try await expandedHost()
        try await assertTwoBodies(context.firstText, context.secondText, in: host)
        XCTAssertEqual(try readCanonicalRow(context.rowID), context.saved)
        tap(app.buttons["annotation-expanded-editor-close"])
        tap(app.buttons["Discard draft"])
        try await waitForAbsence(app.textViews["annotation-note-text"])
    }

    @MainActor
    private func nativeHistoryRecords(_ annotation: UUID, suffix: String,
                                      schema: String) throws -> [String: [String: Any]] {
        try nativeRequire([".native-import-history", ".native-revision-history", ".native-lifecycle-history"]
            .contains(suffix), "The reader is restricted to the original local history directories")
        let sidecar = try workspaceSidecarURL()
        let container = (0..<6).reduce(sidecar) { value, _ in value.deletingLastPathComponent() }
        let parent = container.appendingPathComponent("Library/Application Support/Maktabah-Debug")
        let directory = parent.appendingPathComponent("Annotations.sqlite" + suffix)
            .appendingPathComponent(annotation.uuidString)
        try nativeRequire(directory.standardizedFileURL.resolvingSymlinksInPath() == directory.standardizedFileURL,
            "No history path alias may redirect this read")
        guard FileManager.default.fileExists(atPath: directory.path) else { return [:] }
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: directory,
            includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]))
        var result: [String: [String: Any]] = [:]
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            try nativeRequire(visited <= 160, "Bound the history of this fresh UI-owned note")
            let values = try url.resourceValues(forKeys: Set(keys))
            try nativeRequire(values.isSymbolicLink != true, "History readers do not follow aliases")
            if values.isDirectory == true { continue }
            try nativeRequire(values.isRegularFile == true && (values.fileSize ?? 0) <= 64 * 1024 * 1024,
                "Require a bounded actual history file")
            guard url.pathExtension == "json" else { continue }
            let bytes = try Data(contentsOf: url)
            let record = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            if record["schema"] as? String == schema { result[url.path] = record }
        }
        return result
    }

    private func verifyNativeResponse(_ record: [String: Any]) throws {
        try nativeRequire(record["remoteDeviceAcknowledgement"] as? Bool == false,
            "A local native readback must not manufacture a remote-device acknowledgement")
        let bytes = try XCTUnwrap((record["nativeResponseBytes"] as? String).flatMap { Data(base64Encoded: $0) })
        try nativeRequire(!bytes.isEmpty && Self.sha256(bytes) == record["nativeResponseSHA256"] as? String,
            "The retained original native response must match its digest")
    }

    @MainActor
    private func verifyNewNativeHistory(_ context: OrdinaryNativeExchangeContext,
        previous: [String: [String: Any]], suffix: String, schema: String) throws -> [String: Any] {
        let after = try nativeHistoryRecords(context.saved.uuid, suffix: suffix, schema: schema)
        let added = Set(after.keys).subtracting(previous.keys)
        try nativeRequire(added.count == 1, "One explicit UI action must produce one new result")
        let record = try XCTUnwrap(after[try XCTUnwrap(added.first)])
        try nativeRequire(record["kind"] as? String == "verified"
            && record["objectID"] as? String == context.objectID,
            "The actual original readback must verify the same native root")
        let source = try XCTUnwrap(record["source"] as? [String: Any])
        try nativeRequire(source["accountID"] as? String == OrdinaryNetworkFixture.accountID
            && source["spaceID"] as? String == OrdinaryNetworkFixture.spaceID
            && source["annotationUUID"] as? String == context.saved.uuid.uuidString
            && (source["savedRevision"] as? NSNumber)?.int64Value == context.saved.revision,
            "The action must retain the captured real account, Space and local note")
        try verifyNativeResponse(record)
        return record
    }

    private func attachExchangeStorage(_ row: CanonicalRow, stage: String, objectID: String) {
        let value: [String: Any] = [
            "stage": stage, "annotation_id": row.id, "annotation_uuid": row.uuid.uuidString,
            "revision": row.revision, "payload_sha256": row.payloadDigest ?? "",
            "native_body_sha256": row.body.map(Self.sha256) ?? "",
            "native_object_id": objectID, "remote_device_acknowledgement": false,
            "sqlite_open_mode": "read-only", "qualification_mode": false
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            XCTFail("The actual exchange observation must serialize"); return
        }
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "ordinary-exchange-" + stage; attachment.lifetime = .keepAlways; add(attachment)
        print("ORDINARY_NATIVE_EXCHANGE " + String(decoding: bytes, as: UTF8.self))
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
    private func canonicalAnnotationDatabase() throws -> URL {
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
        return databaseURL
    }

    @MainActor
    private func readCanonicalRow(_ rowID: Int64, databaseURL: URL? = nil) throws -> CanonicalRow {
        let databaseURL = try databaseURL ?? canonicalAnnotationDatabase()
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
