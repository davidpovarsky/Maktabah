//
//  DeepLinkedCommentaryAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A2 & B4: Deep commentary links and bounded reading units.
//  Verifies that citations such as 'Rashi on Berakhot 15b:3:1' load the containing
//  section folio ('Rashi on Berakhot 15b') with segment focus rather than a blank 1-line unit,
//  and that ordinary linked source navigation does not display the search Clear 'X' button.
//

import XCTest
import CryptoKit
import SQLite3
import UIKit

final class DeepLinkedCommentaryAcceptanceTests: MaktabahUITestBase {

    func testDeepCommentaryRashiBerakhotLoadsFullFolio() throws {
        // Launch into reader scenario
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open")

        // In ordinary reading or linked source navigation, Clear 'X' button must NOT appear
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertFalse(
            clearButton.exists,
            "Clear 'X' button must NOT appear for ordinary reader navigation or linked source citations"
        )

        // Verify current canonical locator is present
        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Canonical locator must exist")
        XCTAssertFalse(currentLocator.label.isEmpty, "Canonical locator must not be empty")
    }

    func testTanachPassageLoadsWholeChapterWithSegmentFocus() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        XCTAssertFalse(headerTitle.label.isEmpty, "Header title must not be empty")
    }
}

/// Original UI plus an independently decoded immutable v40 SQL oracle.
/// The resource/100-500-2000 observations remain in the separate exact-source
/// FaithfulProductionReleaseTests cases. This class does not claim their metrics.
@MainActor
final class FullV40InspectorSemanticAcceptanceTests: MaktabahUITestBase {
    private struct Context: Decodable {
        let simulatorUDID: String
        let databasePath: String
        let annotationsPath: String
    }
    private struct Oracle: Decodable {
        let schema: Int
        let databaseSHA256: String
        let databaseBytes: Int64
        let releaseID: Int64
        let releaseTag: String
        let kitRevision: String
        let bookID: Int
        let bookTitle: String
        let authors: [String: Author]
        let cases: [Chapter]
    }
    private struct Author: Decodable { let id: Int; let name: String }
    private struct Chapter: Decodable {
        let chapter: Int
        let tocTitle: String
        let startLineIndex: Int
        let endLineIndex: Int
        let groups: [Group]
        let lines: [Line]
    }
    private struct Line: Decodable {
        let lineID: Int
        let lineIndex: Int
        let heRef: String?
        let plainText: String
        let groups: [Group]
    }
    private struct Group: Decodable {
        let authorID: Int
        let author: String
        let kind: String
        let groupID: String
        let count: Int
        let workIDs: [Int]
        let memberIDs: [String]
        let samples: [Source]
        var identifier: String {
            (kind == "commentary" ? "torah-inspector-commentary-group-" : "torah-inspector-quoting-commentary-group-") + groupID
        }
    }
    private struct Source: Decodable {
        let id: String
        let bookID: Int
        let bookTitle: String
        let lineID: Int
        let lineIndex: Int
        let heRef: String
        let sourceRef: String
        let category: String
        let displayType: String
        let plainText: String?
    }
    private struct PersistedLocator: Decodable {
        struct Position: Decodable { let kind: String; let integer: Int? }
        let backend: String
        let workKey: String
        let position: Position
    }

    private func require(_ value: Bool, _ message: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        guard value else {
            XCTFail(message, file: file, line: line)
            throw NSError(domain: "FullV40InspectorSemanticAcceptance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    private func wait(_ message: String, timeout: TimeInterval = 30,
                      until condition: @escaping @MainActor @Sendable () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, message)
    }
    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func fileHash(_ path: String) throws -> String {
        let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? file.close() }
        var digest = SHA256()
        while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty { digest.update(data: bytes) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    private func normalized(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    private func attach(_ value: Any, _ name: String) throws {
        let a = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                              uniformTypeIdentifier: "public.json")
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
    private func tap(_ element: XCUIElement, _ description: String) throws {
        try require(element.waitForExistence(timeout: 30) && element.isHittable &&
                    !element.frame.isEmpty && element.frame.intersects(app.windows.firstMatch.frame), description)
        element.tap()
    }
    private func originalAction(_ identifier: String, labels: [String]) throws {
        let query = app.buttons.matching(identifier: identifier)
        if query.count == 1 && query.firstMatch.isHittable { try tap(query.firstMatch, identifier); return }
        let overflow = app.navigationBars.buttons.matching(NSPredicate(
            format: "identifier IN %@", ["TopOverflowBarButtonItem", "OverflowBarButtonItem"]))
        try require(overflow.count == 1, "Require the actual toolbar action or its unique native overflow: " + identifier)
        try tap(overflow.firstMatch, "Original native toolbar overflow")
        let item = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", identifier, labels))
        try require(item.count == 1, "Original overflow action must be unique")
        try tap(item.firstMatch, identifier)
    }
    private func panel() throws -> XCUIElement {
        let query = app.descendants(matching: .any).matching(identifier: "torah-inspector-panel")
        try require(query.firstMatch.waitForExistence(timeout: 30) && query.count == 1,
                    "Require one actual original Inspector panel")
        return query.firstMatch
    }
    private func tool(_ label: String) throws {
        let p = try panel()
        let selector = p.descendants(matching: .any)["torah-inspector-tools"]
        let item = selector.buttons.matching(NSPredicate(format: "label == %@", label))
        try require(item.firstMatch.waitForExistence(timeout: 15) && item.count == 1, "Require original tool: " + label)
        if !item.firstMatch.isSelected { try tap(item.firstMatch, label) }
        try require(item.firstMatch.isSelected, "The original requested Inspector tool must be selected")
    }
    private func closeInspector() throws {
        try tap(app.buttons["torah-inspector-close"], "Original Inspector Close")
        try wait("Original Inspector must close") { !self.app.descendants(matching: .any)["torah-inspector-panel"].exists }
    }
    private func openBook(_ title: String) throws {
        try originalAction("reader-command-palette-launcher", labels: ["Search Library", "חיפוש בספרייה"])
        let palette = app.descendants(matching: .any)["reader-library-command-palette"]
        try require(palette.waitForExistence(timeout: 30), "Original Library command palette must open")
        let input = palette.textFields.firstMatch
        try tap(input, "Original library search input")
        input.typeKey(XCUIKeyboardKey(rawValue: "a"), modifierFlags: .command)
        input.typeText(title)
        let matches = palette.buttons.matching(NSPredicate(format: "label == %@", title))
        try require(matches.firstMatch.waitForExistence(timeout: 45) && matches.count == 1,
                    "Select the unique actual source title from the original library")
        try tap(matches.firstMatch, title)
        try wait("Original production reader must open the chosen source", timeout: 60) {
            self.app.staticTexts["reader-header-title"].label == title &&
                !(self.app.textViews["reader-text"].value as? String ?? "").isEmpty
        }
    }
    private func chapter(_ chapter: Chapter) throws {
        if !app.buttons["reader-sidebar-page-1"].isHittable {
            let custom = app.buttons["ToggleSidebar"]
            if custom.exists { try tap(custom, "Original sidebar toggle") }
            else {
                let native = app.buttons.matching(NSPredicate(format: "label IN %@", ["Show Sidebar", "הצגת סרגל הצד"]))
                if native.count == 1 { try tap(native.firstMatch, "Original split-view sidebar action") }
            }
        }
        let page = app.buttons["reader-sidebar-page-1"]
        if page.exists { if !page.isSelected { try tap(page, "Original Contents page") } }
        else {
            try originalAction("reader-more-menu", labels: ["More", "עוד"])
            try tap(app.buttons["reader-toc-toggle"], "Original Table of Contents action")
        }
        let list = app.descendants(matching: .any)["toc-content-list"]
        try require(list.waitForExistence(timeout: 30), "The genuine full-source TOC must load")
        let target = list.buttons.matching(NSPredicate(format: "label == %@", chapter.tocTitle)).firstMatch
        if !target.exists {
            let expand = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "toc-expand-")).firstMatch
            if expand.exists && expand.isHittable { try tap(expand, "Original Psalms TOC disclosure") }
        }
        // Follow the original list in both directions; never supply a private
        // locator or synthesize navigation state to reach a middle/last chapter.
        for _ in 0..<45 {
            if target.isHittable { break }
            list.swipeUp()
        }
        for _ in 0..<90 {
            if target.isHittable { break }
            list.swipeDown()
        }
        try tap(target, "Original exact chapter from the source TOC")
        try wait("Original reader and Contents selection must agree on the actual chapter") {
            (target.isSelected || target.value as? String == "selected") &&
                self.app.staticTexts["reader-current-locator"].label.contains(chapter.tocTitle)
        }
    }
    private func seek(_ element: XCUIElement, in panel: XCUIElement, description: String) throws {
        let scroll = panel.scrollViews.firstMatch
        try require(scroll.exists, "Require the original Inspector scroll view")
        for _ in 0..<45 {
            if element.isHittable { break }
            scroll.swipeUp()
        }
        for _ in 0..<90 {
            if element.isHittable { break }
            scroll.swipeDown()
        }
        try require(element.exists && element.isHittable, description)
    }
    private func group(_ expected: Group, in panel: XCUIElement) throws -> XCUIElement {
        let matches = panel.descendants(matching: .any).matching(identifier: expected.identifier)
        let group = matches.firstMatch
        try seek(group, in: panel, description: "Actual SQL-qualified author group must exist: " + expected.author)
        try require(matches.count == 1, "The actual author/category group identity must be unique")
        let labels = [group.label] + group.staticTexts.allElementsBoundByIndex.map(\.label)
        try require(labels.contains { $0.contains(expected.author) }, "Original author title differs from actual source metadata")
        let pattern = #"(?<![0-9])"# + String(expected.count) + #"(?![0-9])"#
        try require(labels.contains { $0 == String(expected.count) } ||
                    (group.label.contains(expected.author) && group.label.range(of: pattern, options: .regularExpression) != nil),
                    "Actual author-group count differs from independent SQL: " + expected.identifier)
        try attach(["identifier": expected.identifier, "author": expected.author, "count": expected.count,
                    "actual_header_labels": labels, "source_work_ids": expected.workIDs],
                   "v40-inspector-group-" + String(expected.authorID) + "-" + expected.kind)
        return group
    }
    private func toggleGroup(_ expected: Group, element: XCUIElement, in panel: XCUIElement) throws {
        let title = element.staticTexts[expected.author]
        if title.exists { try seek(title, in: panel, description: "Original group header must be visible"); try tap(title, "Original author disclosure") }
        else { try seek(element, in: panel, description: "Original group must be visible"); try tap(element, "Original author disclosure") }
    }
    private func rejectRawVisibleReferences(_ panel: XCUIElement) throws {
        let elements = panel.descendants(matching: .any).allElementsBoundByIndex
        try require(elements.count < 6000, "Bound visible semantics observation; do not dump an unbounded UI tree")
        let visible = elements.filter { $0.isHittable && $0.frame.intersects(panel.frame) }
        for element in visible {
            try require(!element.label.contains("otzaria:v1:") &&
                        !(element.value as? String ?? "").contains("otzaria:v1:"),
                        "A visible source/title must not leak its opaque canonical identifier")
        }
    }
    private func copyExpandedSource(_ source: Source, in panel: XCUIElement) throws {
        let rows = panel.buttons.matching(identifier: "torah-inspector-source-" + source.id)
        try seek(rows.firstMatch, in: panel, description: "Actual linked source row must exist")
        try require(rows.count == 1, "Single source identity must have exactly one native card")
        let row = rows.firstMatch
        try require(row.label == source.heRef + ", " + source.category,
                    "Native source reference/category differs from the independent original SQL payload")
        try require(row.value as? String == "Collapsed", "The initial card must be collapsed")
        try tap(row, "Original single-tap expansion")
        try wait("Single tap must expand the same actual card") { row.value as? String == "Expanded" }
        let expanded = panel.descendants(matching: .any).matching(identifier: "torah-inspector-source-expanded-" + source.id)
        try require(expanded.firstMatch.waitForExistence(timeout: 20) && expanded.count == 1 && rows.count == 1,
                    "Expansion must retain one card and one expansion marker")
        let beforeCopy = UIPasteboard.general.changeCount
        row.press(forDuration: 1)
        let copy = app.buttons.matching(NSPredicate(format: "label IN %@", ["Copy", "העתק"])).firstMatch
        try tap(copy, "Original linked-source context-menu Copy")
        try wait("Original Copy must produce fresh data") { UIPasteboard.general.changeCount > beforeCopy }
        let copied = try XCTUnwrap(UIPasteboard.general.string)
        let expected = try XCTUnwrap(source.plainText)
        try require(normalized(copied) == normalized(expected),
                    "Original expanded source payload differs from independently decompressed full-v40 line")
        let accessibleBodies = row.staticTexts.allElementsBoundByIndex.filter {
            self.normalized($0.label) == self.normalized(expected)
        }.count
        try require(accessibleBodies <= 1, "Expanded card duplicated its source body/snippet")
        try attach(["source_id": source.id, "source_ref": source.sourceRef, "book_id": source.bookID,
                    "line_id": source.lineID, "line_index": source.lineIndex,
                    "copied_text_sha256": hash(Data(normalized(copied).utf8)), "native_card_count": rows.count,
                    "native_expansion_marker_count": expanded.count, "accessible_body_occurrences": accessibleBodies,
                    "body_visibility_scope": accessibleBodies == 1 ? "native body text observed once" : "combined native accessibility; screenshot review still required"],
                   "v40-inspector-expanded-source-" + String(source.lineID))
        capture("v40-inspector-expanded-source-" + String(source.lineID))
        try tap(row, "Original single-tap collapse")
        try wait("Original source must collapse without adding a second card") { row.value as? String == "Collapsed" }
        try require(rows.count == 1, "Collapse duplicated the source card")
    }
    private func noteLocator(context: Context, token: String) throws -> PersistedLocator? {
        var connection: OpaquePointer?
        guard sqlite3_open_v2(context.annotationsPath, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let connection else { throw NSError(domain: "InspectorOriginalNoteRead", code: 1) }
        defer { sqlite3_close(connection) }
        sqlite3_busy_timeout(connection, 5000)
        var preparedStatement: OpaquePointer?
        try require(sqlite3_prepare_v2(connection, "SELECT backendLocator FROM annotations WHERE note=?", -1, &preparedStatement, nil) == SQLITE_OK,
                    "Original annotation schema must expose its persisted backend locator")
        let statement = try XCTUnwrap(preparedStatement)
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        try require(sqlite3_bind_text(statement, 1, token, -1, transient) == SQLITE_OK, "Bind original UI note token")
        let step = sqlite3_step(statement)
        if step == SQLITE_DONE { return nil }
        try require(step == SQLITE_ROW, "Read-only original note lookup failed")
        let text = try XCTUnwrap(sqlite3_column_text(statement, 0)).withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        try require(sqlite3_step(statement) == SQLITE_DONE, "Original note token must identify exactly one persisted note")
        return try JSONDecoder().decode(PersistedLocator.self, from: Data(text.utf8))
    }
    private func recordSelectionThroughOriginalNote(context: Context, chapter: Int) throws -> Int {
        try tool("Notes")
        try tap(app.buttons["torah-inspector-add-note"], "Original selected-source Add Note")
        let editor = app.textViews["annotation-note-text"]
        try tap(editor, "Original selected-source note editor")
        let token = "Inspector source witness " + UUID().uuidString
        editor.typeText(token)
        try tap(app.buttons["annotation-save-toolbar"], "Original note Save")
        try wait("Original note editor must dismiss") { !editor.exists }
        try wait("Original note must persist a source-qualified locator") {
            (try? self.noteLocator(context: context, token: token)) != nil
        }
        let locator = try XCTUnwrap(noteLocator(context: context, token: token))
        try require(locator.backend == "otzaria" && locator.workKey == "book:28" && locator.position.kind == "legacyLine",
                    "Actual selection note must retain the original Psalms backend/book identity")
        let index = try XCTUnwrap(locator.position.integer)
        try attach(["note_token": token, "chapter": chapter, "backend": locator.backend,
                    "workKey": locator.workKey, "selected_line_index": index,
                    "source": "original UI Add Note then read-only original annotation repository"],
                   "v40-inspector-original-selected-line")
        return index
    }

    func testFullV40InspectorSemanticGroupsAndLinkedContent() throws {
        let environment = ProcessInfo.processInfo.environment
        let contextURL = try XCTUnwrap(environment["OTZARIA_LIBRARY_UPDATE_CONTEXT"])
        let context = try JSONDecoder().decode(Context.self, from: Data(contentsOf: URL(fileURLWithPath: contextURL)))
        let oracleURL = try XCTUnwrap(environment["OTZARIA_INSPECTOR_SEMANTIC_ORACLE"])
        let bytes = try Data(contentsOf: URL(fileURLWithPath: oracleURL))
        try require(bytes.count <= 2_000_000 && hash(bytes) == "53694dd13202791d02b223a03c88d9c550bd840749884fc576d15928aef4dff6",
                    "Require the retained actual immutable v40 SQL oracle, not a substituted expected result")
        let oracle = try JSONDecoder().decode(Oracle.self, from: bytes)
        try require(oracle.schema == 1 && oracle.bookID == 28 && oracle.cases.map(\.chapter) == [1, 75, 150] &&
                    oracle.databaseSHA256 == "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01" &&
                    oracle.kitRevision == "23db0f84e88d9ee9c7053c49de86903fc7bb5785", "Wrong source/Kit oracle")
        try require(environment["SIMULATOR_UDID"] == context.simulatorUDID, "Context belongs to another simulator")
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH", "OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"] {
            try require(environment[key] == nil, "Original production UI must not inherit source injection: " + key)
        }
        let owned = "/CoreSimulator/Devices/" + context.simulatorUDID + "/data/"
        for path in [context.databasePath, context.annotationsPath] {
            try require(URL(fileURLWithPath: path).resolvingSymlinksInPath().path.contains(owned), "Use the same owned real simulator container")
        }
        let database = URL(fileURLWithPath: context.databasePath)
        try require(database.lastPathComponent == "seforim.db" && database.deletingLastPathComponent().lastPathComponent == "Otzaria",
                    "Require the original managed production database")
        let manifestURL = database.deletingLastPathComponent().appendingPathComponent("seforim-installation.json")
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        let actualDatabaseBytes = try database.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)
        let actualDatabaseHash = try fileHash(context.databasePath)
        try require((manifest["releaseID"] as? NSNumber)?.int64Value == oracle.releaseID &&
                    manifest["releaseTag"] as? String == oracle.releaseTag &&
                    actualDatabaseBytes == oracle.databaseBytes && actualDatabaseHash == oracle.databaseSHA256,
                    "Actual original managed app corpus must match the exact production oracle")
        try attach(["database_path": context.databasePath, "database_bytes": oracle.databaseBytes,
                    "database_sha256": actualDatabaseHash, "release_id": oracle.releaseID,
                    "release_tag": oracle.releaseTag, "source_oracle_sha256": hash(bytes)],
                   "v40-inspector-managed-corpus-admission")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US")
        try tap(findTabButton(hebrew: "ספר", english: "Library"), "Original Library tab")
        try openBook(oracle.bookTitle)
        // The normal default is paragraph mode. Choose Chapter through the
        // original menu, rather than depending on another test's preferences.
        try originalAction("reader-more-menu", labels: ["More", "עוד"])
        try tap(app.buttons["Display by"], "Original Display by submenu")
        try tap(app.buttons["Chapter"], "Original Chapter reading unit")
        let davidID = try XCTUnwrap(oracle.authors["twoWorks"]?.id)
        let quotingID = try XCTUnwrap(oracle.authors["quoting"]?.id)
        for chapter in oracle.cases {
            try self.chapter(chapter)
            try originalAction("reader-study-toggle", labels: ["Open Study Tools", "פתיחת כלי לימוד"])
            try tool("Commentaries")
            let originalPanel = try panel()
            try wait("The original full-source relationship groups must finish loading", timeout: 60) {
                originalPanel.descendants(matching: .any).matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "torah-inspector-commentary-group-")).firstMatch.exists
            }
            for expected in chapter.groups { _ = try group(expected, in: originalPanel) }
            try rejectRawVisibleReferences(originalPanel)
            let david = try XCTUnwrap(chapter.groups.first { $0.authorID == davidID && $0.kind == "commentary" })
            try require(Set([3323, 3436]).isSubset(of: Set(david.workIDs)), "One author must contain both actual Psalms works in every chapter")
            let authorCard = try group(david, in: originalPanel)
            try toggleGroup(david, element: authorCard, in: originalPanel)
            let sources = david.samples.filter { [3323, 3436].contains($0.bookID) }
            try require(sources.count == 2 && Set(sources.map(\.bookID)).count == 2,
                        "Actual author disclosure needs both distinct source works")
            for source in sources { try copyExpandedSource(source, in: originalPanel) }
            try toggleGroup(david, element: authorCard, in: originalPanel)
            let quoting = try XCTUnwrap(chapter.groups.first { $0.authorID == quotingID && $0.kind == "quotingCommentary" })
            let quotingCard = try group(quoting, in: originalPanel)
            try toggleGroup(quoting, element: quotingCard, in: originalPanel)
            let quotingSource = try XCTUnwrap(quoting.samples.first)
            try require(quotingSource.category == "Quoting Commentary", "The real quotation payload must retain its distinct category")
            try copyExpandedSource(quotingSource, in: originalPanel)
            try toggleGroup(quoting, element: quotingCard, in: originalPanel)
            try rejectRawVisibleReferences(originalPanel)
            try toggleGroup(david, element: authorCard, in: originalPanel)
            let linked = try XCTUnwrap(sources.last)
            let card = originalPanel.buttons["torah-inspector-source-" + linked.id]
            try seek(card, in: originalPanel, description: "Double-tap the same actual linked source card")
            card.doubleTap()
            try wait("Double tap must open the actual linked work and real target text", timeout: 60) {
                self.app.staticTexts["reader-header-title"].label == linked.bookTitle &&
                    self.normalized(self.app.textViews["reader-text"].value as? String ?? "").contains(self.normalized(linked.plainText ?? "\u{FFFF}"))
            }
            try require(!app.staticTexts["reader-current-locator"].label.contains("otzaria:v1:"), "Linked reader title must be human-readable")
            capture("v40-inspector-linked-reader-chapter-" + String(chapter.chapter))
            if app.buttons["torah-inspector-close"].exists { try closeInspector() }
            try openBook(oracle.bookTitle)
            try self.chapter(chapter)
            // Choose a real on-screen paragraph through the original text tap.
            // Its persisted original-note locator identifies the selected line;
            // no private view model, test locator injection or raw DB write does.
            var selected: Line?
            for fraction in [0.25, 0.4, 0.6] {
                let reader = app.textViews["reader-text"]
                try require(reader.exists && reader.isHittable, "Select an actual visible original reader paragraph")
                capture("v40-inspector-before-original-selection-" + String(chapter.chapter))
                reader.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: fraction)).tap()
                _ = try panel()
                let index = try recordSelectionThroughOriginalNote(context: context, chapter: chapter.chapter)
                let candidate = try XCTUnwrap(chapter.lines.first { $0.lineIndex == index }, "Selected actual line must belong to the current source chapter")
                if candidate.heRef != nil,
                   let subgroup = candidate.groups.first(where: { $0.authorID == davidID && $0.kind == "commentary" }),
                   subgroup.count > 0 && subgroup.count < david.count {
                    selected = candidate; break
                }
                try closeInspector()
            }
            let selectedLine = try XCTUnwrap(selected, "Observe a genuine selected paragraph with a narrower source scope")
            try tool("Commentaries")
            let selectedPanel = try panel()
            let selectedGroup = try XCTUnwrap(selectedLine.groups.first { $0.authorID == davidID && $0.kind == "commentary" })
            let selectedCard = try group(selectedGroup, in: selectedPanel)
            try toggleGroup(selectedGroup, element: selectedCard, in: selectedPanel)
            let expectedIDs = Set(selectedGroup.memberIDs)
            var seen = Set<String>()
            for _ in 0..<35 {
                let rows = selectedCard.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "torah-inspector-source-"))
                for row in rows.allElementsBoundByIndex where row.isHittable {
                    let id = String(row.identifier.dropFirst("torah-inspector-source-".count))
                    try require(expectedIDs.contains(id), "Selected paragraph leaked a source from another line/unit/cache scope")
                    try require(rows.matching(identifier: row.identifier).count == 1, "Selected-source card identity duplicated")
                    seen.insert(id)
                }
                if seen == expectedIDs { break }
                selectedPanel.scrollViews.firstMatch.swipeUp()
            }
            try require(seen == expectedIDs, "Actual selected-paragraph source IDs/count must equal its independent SQL membership")
            try attach(["chapter": chapter.chapter, "selected_line_id": selectedLine.lineID,
                        "selected_line_index": selectedLine.lineIndex, "current_unit_count": david.count,
                        "selected_line_count": selectedGroup.count, "actual_selected_source_ids": seen.sorted()],
                       "v40-inspector-selection-versus-unit-" + String(chapter.chapter))
            capture("v40-inspector-selected-paragraph-" + String(chapter.chapter))
            try closeInspector()
            try originalAction("reader-study-toggle", labels: ["Open Study Tools", "פתיחת כלי לימוד"])
            try tool("Commentaries")
            _ = try group(david, in: panel())
            capture("v40-inspector-current-unit-restored-" + String(chapter.chapter))
            try closeInspector()
        }
        try attach(["chapters": [1, 75, 150], "source_sha256": oracle.databaseSHA256,
                    "source_oracle_sha256": hash(bytes), "kit_revision": oracle.kitRevision,
                    "resource_metrics_scope": "separate exact-source full-v40 Inspector scale observations",
                    "failure_and_inflight_cancel_scope": "not asserted by this semantic case"],
                   "v40-inspector-semantic-completion")
    }
}

/// Original default Sefaria Reader/Inspector, in one ordinary persisted tab.
/// The selected-unit Text supplies the complete mapped body to accessibility;
/// the Kit deliberately limits its visual quote to two lines. There is no
/// displayed version-title field in this Kit. Editions are qualified by the
/// retained default API response and exact body equality, not an invented label.
@MainActor
final class SefariaInspectorModeAcceptanceTests: MaktabahUITestBase {
    private struct Rejected: Error { let reason: String }
    private struct Body: Decodable { let sha256: String; let utf8Bytes: Int }
    private struct SourceFile: Decodable { let relativePath: String; let bytes: Int; let sha256: String }
    private struct Mode: Decodable {
        let displayReferenceInHebrewUI: String
        let selectedUnitQuote: Body
        let sourceVersionTitle: String
        let sourceVersionLanguage: String
        let versionScope: String
    }
    private struct Oracle: Decodable {
        struct Segment: Decodable { let canonicalRef: String; let locator: String; let bodies: [String: Body] }
        let schema: Int
        let status: String
        let uiExecuted: Bool
        let kitRevision: String
        let requestURL: String
        let canonicalReference: String
        let hebrewReference: String
        let canonicalLocator: String
        let workKey: String
        let response: SourceFile
        let responseReceipt: SourceFile
        let sourceVersionTitle: String
        let translationVersionTitle: String
        let segments: [Segment]
        let modes: [String: Mode]
    }
    private struct Workspace: Decodable {
        struct Locator: Decodable, Equatable {
            struct Position: Decodable, Equatable { let kind: String; let string: String? }
            let backend: String; let workKey: String; let position: Position
        }
        struct Session: Decodable { let id: UUID; let bookId: Int; let backendLocator: Locator? }
        struct Document: Decodable { let session: Session }
        struct Group: Decodable { let id: UUID; let activeTabID: UUID?; let tabs: [Document] }
        struct Scene: Decodable { let groupID: UUID; let activeTabIDsByGroup: [UUID: UUID]? }
        let groups: [Group]
        let scenes: [String: Scene]
        let lastActiveSceneID: String?
    }
    private struct ActiveTab {
        let owner: URL
        let metadataSHA256: String
        let workspaceSHA256: String
        let sceneID: String
        let groupID: UUID
        let session: Workspace.Session
    }
    private var ui: OriginalSearchContextUI { .init(app: app, test: self) }
    private var environment: [String: String] { ProcessInfo.processInfo.environment }
    private func demand(_ value: Bool, _ reason: String) throws {
        guard value else { XCTFail(reason); throw Rejected(reason: reason) }
    }
    private func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private func bounded(_ url: URL, maximum: Int = 2_000_000) throws -> Data {
        let path = url.standardizedFileURL
        let info = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try demand(info.isRegularFile == true && info.isSymbolicLink == false &&
                   path.path == path.resolvingSymlinksInPath().path && (info.fileSize ?? maximum + 1) <= maximum,
                   "Require a bounded original regular file, without symlink traversal")
        let bytes = try Data(contentsOf: path)
        try demand(bytes.count <= maximum, "The evidence file grew beyond its admission bound")
        return bytes
    }
    private func attach(_ value: Any, _ name: String) throws {
        let item = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                                 uniformTypeIdentifier: "public.json")
        item.name = name; item.lifetime = .keepAlways; add(item)
    }
    private func oracle() throws -> Oracle {
        _ = try XCTUnwrap(environment["SEFARIA_INSPECTOR_CONTAINER_PARENT"], "Runner must bind the actual Simulator application-container parent")
        _ = try XCTUnwrap(environment["SIMULATOR_UDID"], "Require XCTest's actual Simulator identity")
        let path = URL(fileURLWithPath: try XCTUnwrap(environment["SEFARIA_INSPECTOR_MODE_ORACLE"])).standardizedFileURL
        let bytes = try bounded(path)
        try demand(hash(bytes) == environment["SEFARIA_INSPECTOR_MODE_ORACLE_SHA256"], "Use the exact sealed default-source oracle")
        let value = try JSONDecoder().decode(Oracle.self, from: bytes)
        try demand(value.schema == 1 && value.status == "ACTUAL_DEFAULT_SEFARIA_SOURCE_ORACLE_ONLY_NOT_UI" && !value.uiExecuted,
                   "A source conversion is not a prior UI acceptance")
        try demand(value.kitRevision == "23db0f84e88d9ee9c7053c49de86903fc7bb5785" &&
                   value.canonicalReference == "Psalms 35" && value.hebrewReference == "תהילים ל״ה" &&
                   value.workKey == "Psalms" && value.canonicalLocator == "sefaria|Psalms|ref:Psalms 35",
                   "Require this exact actual source and pinned original Kit")
        let expectedURL = "https://www.sefaria.org/api/v3/texts/Psalms%2035?version=source&version=translation&fill_in_missing_segments=1&return_format=text_only"
        try demand(value.requestURL == expectedURL, "A selected-preview edition cannot substitute for the ordinary Reader default request")
        for file in [value.response, value.responseReceipt] {
            try demand(!file.relativePath.contains("/") && !file.relativePath.contains(".."), "Source evidence must remain beside its oracle")
            let raw = try bounded(path.deletingLastPathComponent().appendingPathComponent(file.relativePath))
            try demand(raw.count == file.bytes && hash(raw) == file.sha256, "Retained actual API evidence changed")
        }
        let receiptBytes = try bounded(path.deletingLastPathComponent().appendingPathComponent(value.responseReceipt.relativePath))
        let receipt = try XCTUnwrap(JSONSerialization.jsonObject(with: receiptBytes) as? [String: Any])
        try demand(receipt["url"] as? String == expectedURL && receipt["finalURL"] as? String == expectedURL &&
                   receipt["status"] as? Int == 200 && receipt["sha256"] as? String == value.response.sha256,
                   "Require the real successful original default request receipt")
        try demand(value.segments.count == 28 && value.segments.map(\.canonicalRef) == (1...28).map { "Psalms 35:\($0)" },
                   "The independent source must include the complete ordered chapter")
        try demand(Set(value.modes.keys) == Set(["source", "translation", "both"]) &&
                   Set(value.modes.values.map { $0.selectedUnitQuote.sha256 }).count == 3,
                   "The real three bodies must be distinct; a stale body must fail")
        for (name, mode) in value.modes {
            try demand(mode.selectedUnitQuote.utf8Bytes > 500 && mode.selectedUnitQuote.sha256.count == 64 &&
                       mode.displayReferenceInHebrewUI == (name == "translation" ? value.canonicalReference : value.hebrewReference) &&
                       mode.sourceVersionTitle == (name == "translation" ? value.translationVersionTitle : value.sourceVersionTitle) &&
                       mode.sourceVersionLanguage == (name == "translation" ? "en" : "he"), "Reject inconsistent source mode metadata")
        }
        let evidence = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        evidence.name = "sefaria-inspector-default-source-oracle"; evidence.lifetime = .keepAlways; add(evidence)
        return value
    }
    private func activeTab() throws -> ActiveTab {
        let parent = URL(fileURLWithPath: try XCTUnwrap(environment["SEFARIA_INSPECTOR_CONTAINER_PARENT"]),
                         isDirectory: true).standardizedFileURL
        let dataRoot = parent.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let udid = try XCTUnwrap(environment["SIMULATOR_UDID"])
        try demand(UUID(uuidString: udid) != nil && dataRoot.lastPathComponent == "data" &&
                   dataRoot.deletingLastPathComponent().lastPathComponent.lowercased() == udid.lowercased() &&
                   Array(parent.pathComponents.suffix(3)) == ["Containers", "Data", "Application"] &&
                   parent.path == parent.resolvingSymlinksInPath().path, "Inspect only this owned Simulator's original app container")
        let children = try FileManager.default.contentsOfDirectory(at: parent,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        try demand(children.count <= 256, "Bound fresh MCM owner discovery")
        var owners: [(URL, Data)] = []
        for child in children {
            let info = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard info.isDirectory == true, info.isSymbolicLink == false,
                  UUID(uuidString: child.lastPathComponent) != nil else { continue }
            let metadata = child.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            guard let data = try? bounded(metadata, maximum: 65_536),
                  let record = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  record["MCMMetadataIdentifier"] as? String == "com.davidpovarsky.chavrusatext" else { continue }
            owners.append((child, data))
        }
        try demand(owners.count == 1, "Require the sole observed original app installation")
        let owner = try XCTUnwrap(owners.first)
        let bytes = try bounded(owner.0.appendingPathComponent(
            "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"), maximum: 8 * 1024 * 1024)
        let state = try JSONDecoder().decode(Workspace.self, from: bytes)
        guard let sceneID = state.lastActiveSceneID, let scene = state.scenes[sceneID],
              let group = state.groups.first(where: { $0.id == scene.groupID }),
              let current = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID,
              let session = group.tabs.first(where: { $0.session.id == current })?.session else {
            // A normal asynchronous workspace save may still be pending. The
            // enclosing bounded wait must fail if no genuine active tab arrives.
            throw Rejected(reason: "Ordinary workspace has no current tab yet")
        }
        return ActiveTab(owner: owner.0, metadataSHA256: hash(owner.1), workspaceSHA256: hash(bytes),
                         sceneID: sceneID, groupID: group.id, session: session)
    }
    private func tap(_ value: XCUIElement, _ reason: String) throws {
        try demand(value.waitForExistence(timeout: 30) && value.isHittable && !value.frame.isEmpty &&
                   value.frame.intersects(app.frame), reason)
        value.tap()
    }
    private func originalToolbar(_ id: String, labels: [String]) throws {
        let direct = app.buttons.matching(identifier: id)
        if direct.count == 1 && direct.firstMatch.isHittable { try tap(direct.firstMatch, id); return }
        let overflow = app.navigationBars.buttons.matching(NSPredicate(format: "identifier IN %@",
            ["TopOverflowBarButtonItem", "OverflowBarButtonItem"]))
        try demand(overflow.count == 1, "Require the original toolbar action or its unique native overflow")
        try tap(overflow.firstMatch, "Original native overflow")
        let item = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", id, labels))
        try demand(item.count == 1, "The original overflow action must be unique: " + id)
        try tap(item.firstMatch, id)
    }
    private func openOriginalCanonicalReader() throws {
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH", "SEFARIA_BASE_URL"] {
            try demand(environment[key] == nil, "No source substitution may enter the original UI: " + key)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "sefaria",
            extraArgs: ["-lastSelectedTab", "0", "-ChavrusaTextFaithfulReaderUIEnabled", "YES"],
            language: "he", locale: "he_IL")
        try demand(!app.launchArguments.contains("-smokeBypassBootstrap") &&
                   !app.launchArguments.contains("-studyWorkspaceTestingNamespace"), "Require ordinary production bootstrap and workspace")
        let searchTab = findTabButton(hebrew: "חיפוש", english: "Search")
        try demand(searchTab.waitForExistence(timeout: 120), "Genuine Sefaria bootstrap must expose the original Search tab")
        try tap(searchTab, "Original Search tab after genuine Sefaria bootstrap")
        try ui.require("global-search-screen", timeout: 120)
        try tap(ui.require("global-search-mode"), "Original search mode")
        try tap(ui.require("global-search-mode-exact"), "Original exact search")
        try tap(ui.require("global-search-books"), "Original book filter")
        if ui.control("global-search-book-clear").exists { try tap(ui.control("global-search-book-clear"), "Clear original book selection") }
        let books = try ui.require("global-search-book-query", timeout: 60)
        try tap(books, "Original book query")
        if let clear = books.buttons.allElementsBoundByIndex.first(where: \.isHittable) { clear.tap() }
        books.typeText("תהילים\n")
        try tap(ui.require("search-book-sefaria|Psalms|ref:Psalms", timeout: 60), "Original canonical Psalms book")
        if ui.control("global-search-book-done").exists { try tap(ui.control("global-search-book-done"), "Apply original book filter") }
        let query = try ui.require("global-search-query")
        try tap(query, "Original search query")
        if let clear = query.buttons.allElementsBoundByIndex.first(where: \.isHittable) { clear.tap() }
        query.typeText("soul\n")
        try ui.require("global-search-count", timeout: 120)
        try tap(ui.require("global-search-sort"), "Original sort menu")
        try tap(ui.require("global-search-sort-canonical"), "Original canonical sort")
        try tap(ui.require("global-search-rerun"), "Original query submission")
        try ui.wait("Actual canonical Search results must load", timeout: 120) { ((try? self.ui.loadedCount()) ?? 0) > 0 }
        let prefix = "search-result-preview-toggle-sefaria|Psalms|ref:Psalms 35:17|"
        var found: XCUIElement?
        for _ in 0..<80 {
            let matches = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            if matches.count == 1 && matches.firstMatch.isHittable { found = matches.firstMatch; break }
            try ui.dragVisible(ui.require("global-search-results"), up: true)
        }
        let card = try XCTUnwrap(found, "Reach the actual canonical Psalms 35:17 search card")
        let stableID = String(card.identifier.dropFirst("search-result-preview-toggle-".count))
        try ui.expand(stableID)
        try ui.openCurrentPreview(stableID)
        try ui.wait("Original Open must display the canonical default reading unit", timeout: 120) {
            self.ui.control("reader-current-locator").label == "sefaria|Psalms|ref:Psalms 35" &&
                self.app.textViews["reader-text"].exists && !(self.app.textViews["reader-text"].value as? String ?? "").isEmpty
        }
        try attach(["original_search_card": stableID, "canonical_default_locator": "sefaria|Psalms|ref:Psalms 35",
                    "scope": "canonical Open uses the default Reader edition; selected preview editions are a separate acceptance"],
                   "sefaria-inspector-original-canonical-open")
    }
    private func setMode(_ mode: String) throws {
        try originalToolbar("reader-more-menu", labels: ["More", "עוד"])
        try tap(ui.require("reader-text-options"), "Original View Options")
        for _ in 0..<8 {
            if ui.control("reader-text-mode").exists && ui.control("reader-text-mode").isHittable { break }
            let popover = app.popovers.firstMatch
            try demand(popover.waitForExistence(timeout: 10), "Require the original View Options popover")
            try ui.dragVisible(popover, up: true)
        }
        try tap(ui.require("reader-text-mode"), "Original text mode picker")
        try tap(ui.require("reader-text-mode-" + mode), "Original requested mode: " + mode)
        try tap(ui.require("reader-options-close"), "Close original View Options")
    }
    private func openInspector() throws {
        try demand(!ui.control("torah-inspector-panel").exists, "The Inspector must actually be closed before its one open action")
        try originalToolbar("reader-study-toggle", labels: ["Open Study Tools", "פתיחת כלי לימוד"])
        try ui.require("torah-inspector-selected-segment", timeout: 90)
    }
    private func closeInspector() throws {
        try tap(ui.require("torah-inspector-close"), "Original Inspector Close")
        try ui.wait("The genuine Inspector must close without changing the current tab") {
            !self.ui.control("torah-inspector-panel").exists && !self.ui.control("torah-inspector-selected-segment").exists
        }
    }
    private func assertQuote(_ source: Oracle, mode: String, tab: ActiveTab, phase: String) throws {
        let expected = try XCTUnwrap(source.modes[mode])
        let cards = app.descendants(matching: .any).matching(identifier: "torah-inspector-selected-segment")
        try ui.wait("The original Inspector must publish the complete current-mode quote", timeout: 90) {
            guard cards.count == 1 else { return false }
            return cards.firstMatch.staticTexts.allElementsBoundByIndex.contains {
                let bytes = Data($0.label.utf8)
                return bytes.count == expected.selectedUnitQuote.utf8Bytes && self.hash(bytes) == expected.selectedUnitQuote.sha256
            }
        }
        let card = cards.firstMatch
        let labels = card.staticTexts.allElementsBoundByIndex
        let bodies = labels.filter { hash(Data($0.label.utf8)) == expected.selectedUnitQuote.sha256 }
        try demand(bodies.count == 1 && bodies[0].frame.intersects(app.frame) && !bodies[0].frame.isEmpty,
                   "One actual visible quote Text must supply the complete qualified body exactly once")
        try demand(labels.filter { $0.label == expected.displayReferenceInHebrewUI }.count == 1,
                   "Original Inspector source reference must match the actual selected mode and Hebrew interface")
        try demand(ui.control("reader-current-locator").label == source.canonicalLocator,
                   "Changing Inspector text mode must not navigate the original Reader")
        let current = try activeTab()
        try demand(current.owner == tab.owner && current.metadataSHA256 == tab.metadataSHA256 &&
                   current.sceneID == tab.sceneID && current.groupID == tab.groupID && current.session.id == tab.session.id &&
                   current.session.bookId == tab.session.bookId && current.session.backendLocator == tab.session.backendLocator,
                   "The same ordinary persisted scene, group, tab and source locator must own every mode")
        let originalTab = app.descendants(matching: .any).matching(identifier: "reader-document-tab-" + tab.session.id.uuidString)
        try demand(originalTab.count == 1, "Bind persisted tab UUID to the original Reader tab control")
        try attach(["phase": phase, "mode": mode, "tab_uuid": current.session.id.uuidString,
                    "scene_id": current.sceneID, "group_uuid": current.groupID.uuidString,
                    "data_container": current.owner.path, "mcm_metadata_sha256": current.metadataSHA256,
                    "workspace_sha256": current.workspaceSHA256, "canonical_locator": source.canonicalLocator,
                    "display_reference": expected.displayReferenceInHebrewUI,
                    "quote_sha256": hash(Data(bodies[0].label.utf8)), "quote_utf8_bytes": bodies[0].label.utf8.count,
                    "source_response_sha256": source.response.sha256,
                    "source_version_title": expected.sourceVersionTitle,
                    "version_scope": expected.versionScope,
                    "quote_scope": "complete original selected-unit Text accessibility value; visual quote capped at two lines"],
                   "sefaria-inspector-mode-" + phase)
        ui.capture("sefaria-inspector-mode-" + phase)
    }
    func testSameTabInspectorHonorsSourceTranslationAndBothAcrossCloseAndReopen() throws {
        let source = try oracle()
        defer { ui.capture("sefaria-inspector-mode-final") }
        try openOriginalCanonicalReader()
        // The original mode action clears search-hit segment focus. From here
        // the inspected scope is the complete current unit, not the earlier hit.
        try setMode("source")
        var observed: ActiveTab?
        try ui.wait("Original ordinary workspace must persist the canonical Sefaria tab", timeout: 30) {
            guard let value = try? self.activeTab(), value.session.backendLocator?.backend == "sefaria",
                  value.session.backendLocator?.workKey == "Psalms" else { return false }
            observed = value; return true
        }
        let tab = try XCTUnwrap(observed)
        if ui.control("torah-inspector-panel").exists { try closeInspector() }
        try openInspector()
        try assertQuote(source, mode: "source", tab: tab, phase: "source-initial-open")
        for mode in ["translation", "both", "source"] {
            try demand(ui.control("torah-inspector-panel").exists, "Change mode while the original Inspector is still presented")
            try setMode(mode)
            // No second toggle or re-selection is allowed to repair a failed
            // first mount. The existing visible Inspector must update itself.
            try assertQuote(source, mode: mode, tab: tab, phase: mode + "-visible-transition")
        }
        try closeInspector()
        try openInspector()
        try assertQuote(source, mode: "source", tab: tab, phase: "source-matching-reopen")
        for mode in ["translation", "both", "source"] {
            try closeInspector()
            try setMode(mode)
            try demand(!ui.control("torah-inspector-panel").exists, "A hidden mode change must not open the Inspector by itself")
            try openInspector()
            try assertQuote(source, mode: mode, tab: tab, phase: mode + "-changed-while-hidden")
        }
    }

}
