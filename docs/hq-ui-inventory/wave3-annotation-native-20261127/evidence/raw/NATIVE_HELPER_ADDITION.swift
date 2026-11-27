

// Original Annotation record selection: actual UI-created persistent note,
// actual system entity/Intent, actual original selected collection cell. This
// is a warm-list contract; no editor/Reader action or injected ID/ACK is used.
extension NativeRoutingAcceptanceTests {
    enum OriginalAnnotationSelectionJourney: Equatable { case select, searchABA }
    private enum OriginalAnnotationFixtureError: Error { case rejected(String) }
    private struct OriginalAnnotationSQLCell: Codable, Equatable {
        let type: Int32
        let value: String
    }
    private typealias OriginalAnnotationSQLRow = [String: OriginalAnnotationSQLCell]
    private struct OriginalAnnotationDatabase: Codable, Equatable {
        let schema: [OriginalAnnotationSQLRow]
        let tables: [String: [OriginalAnnotationSQLRow]]
        var canonical: Data {
            get throws {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                return try encoder.encode(self)
            }
        }
    }
    private struct OriginalAnnotationOwner {
        let container: URL
        let metadata: Data
        let bookmark: Data?
        let database: URL
    }
    private struct OriginalAnnotationFixture {
        let note: String
        let originalBookID: Int
        let originalWork: String
        let owner: OriginalAnnotationOwner
        let row: OriginalAnnotationSQLRow
    }

    private func requireOriginalAnnotationCondition(_ value: Bool, _ message: String) throws {
        guard value else { throw OriginalAnnotationFixtureError.rejected(message) }
    }

    /// One read-only SQLite transaction observes the whole original logical
    /// database, including native-body/exchange tables if the original app has
    /// created them. No table/schema, annotation, ID or receipt is injected.
    private func readOriginalAnnotationDatabase(_ url: URL) throws -> OriginalAnnotationDatabase {
        var opened: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &opened, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard status == SQLITE_OK, let database = opened else {
            if let opened { sqlite3_close(opened) }
            throw OriginalAnnotationFixtureError.rejected("Cannot read the original annotation database")
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1_000)
        try requireOriginalAnnotationCondition(sqlite3_db_readonly(database, "main") == 1,
                                              "Annotation oracle must be read-only")
        try requireOriginalAnnotationCondition(sqlite3_exec(database, "BEGIN DEFERRED TRANSACTION", nil, nil, nil) == SQLITE_OK,
                                              "Require one original SQLite read snapshot")
        defer { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) }
        var totalRows = 0
        func read(_ sql: String) throws -> [OriginalAnnotationSQLRow] {
            var prepared: OpaquePointer?
            try requireOriginalAnnotationCondition(sqlite3_prepare_v2(database, sql, -1, &prepared, nil) == SQLITE_OK,
                                                  "Original annotation schema/read is unavailable")
            guard let statement = prepared else { throw OriginalAnnotationFixtureError.rejected("Missing read statement") }
            defer { sqlite3_finalize(statement) }
            var result: [(Data, OriginalAnnotationSQLRow)] = []
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_DONE { return result.sorted { $0.0.lexicographicallyPrecedes($1.0) }.map(\.1) }
                try requireOriginalAnnotationCondition(step == SQLITE_ROW, "Original annotation snapshot did not complete")
                totalRows += 1
                try requireOriginalAnnotationCondition(totalRows <= 100_000, "Original annotation fixture exceeds the bounded read envelope")
                var row: OriginalAnnotationSQLRow = [:]
                for column in 0..<sqlite3_column_count(statement) {
                    let name = try XCTUnwrap(sqlite3_column_name(statement))
                    let key = String(cString: name), kind = sqlite3_column_type(statement, column)
                    let value: String
                    switch kind {
                    case SQLITE_NULL: value = ""
                    case SQLITE_INTEGER: value = String(sqlite3_column_int64(statement, column))
                    case SQLITE_FLOAT: value = String(sqlite3_column_double(statement, column).bitPattern)
                    case SQLITE_TEXT:
                        let bytes = try XCTUnwrap(sqlite3_column_text(statement, column))
                        value = try XCTUnwrap(String(bytes: UnsafeBufferPointer(start: bytes,
                            count: Int(sqlite3_column_bytes(statement, column))), encoding: .utf8),
                            "Original stored annotation text must decode without lossy replacement")
                    case SQLITE_BLOB:
                        let count = Int(sqlite3_column_bytes(statement, column))
                        value = count == 0 ? "" : Data(bytes: try XCTUnwrap(sqlite3_column_blob(statement, column)), count: count).base64EncodedString()
                    default: throw OriginalAnnotationFixtureError.rejected("Unknown original SQLite value type")
                    }
                    try requireOriginalAnnotationCondition(row[key] == nil, "Duplicate original SQLite column")
                    row[key] = .init(type: kind, value: value)
                }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                result.append((try encoder.encode(row), row))
            }
        }
        let schema = try read("SELECT name, type, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' AND type IN ('table','index','trigger','view')")
        let names = schema.filter { $0["type"]?.value == "table" }.compactMap { $0["name"]?.value }
        try requireOriginalAnnotationCondition(names.count <= 64 && Set(names).count == names.count
            && Set(["annotations", "tags", "annotation_tags"]).isSubset(of: Set(names)),
            "Require the actual original annotation/tag schema within the bounded fixture")
        var tables: [String: [OriginalAnnotationSQLRow]] = [:]
        for name in names {
            let quoted = "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            tables[name] = try read("SELECT * FROM " + quoted)
        }
        let result = OriginalAnnotationDatabase(schema: schema, tables: tables)
        try requireOriginalAnnotationCondition(try result.canonical.count <= 32 * 1024 * 1024,
                                              "Original annotation snapshot exceeds the bounded read envelope")
        return result
    }

    private func originalAnnotationRow(_ database: OriginalAnnotationDatabase, note: String) throws -> OriginalAnnotationSQLRow {
        let rows = (database.tables["annotations"] ?? []).filter { $0["note"]?.type == SQLITE_TEXT && $0["note"]?.value == note }
        try requireOriginalAnnotationCondition(rows.count == 1, "Require exactly one persistent row created through the original note UI")
        let row = try XCTUnwrap(rows.first)
        try requireOriginalAnnotationCondition(row["id"]?.type == SQLITE_INTEGER
            && row["id"].flatMap { Int64($0.value) }.map { $0 > 0 } == true,
            "Require the original saved SQL identity, never an invented entity ID")
        return row
    }

    @MainActor private func resolveOriginalAnnotationOwner(note: String) throws -> OriginalAnnotationOwner {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        try requireOriginalAnnotationCondition(Array(sidecar.pathComponents.suffix(suffix.count)) == suffix,
                                              "Require this actual original test workspace")
        var container = sidecar
        for _ in suffix { container.deleteLastPathComponent() }
        try requireOriginalAnnotationCondition(container.deletingLastPathComponent() == workspaceContainerParent().standardizedFileURL
            && UUID(uuidString: container.lastPathComponent) != nil,
            "Require the actual same-device MCM app container")
        let metadata = try Data(contentsOf: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
        let owner = try XCTUnwrap(PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        try requireOriginalAnnotationCondition(owner["MCMMetadataIdentifier"] as? String == "com.davidpovarsky.chavrusatext",
                                              "Annotation oracle must belong to the target app")
        try requireOriginalAnnotationCondition(!app.launchArguments.contains("-annotations_FolderPath")
            && app.launchEnvironment["OTZARIA_ANNOTATION_ACCEPTANCE_DATABASE"] == nil,
            "No annotation database or folder override is allowed")
        // The original Saved Results and Annotation repositories share this
        // exact AppConfig folder bookmark; reuse its existing read-only decoder.
        let bookmark = try originalSavedBookmark(in: container)
        let candidates: [URL]
        if let bookmark, !bookmark.isEmpty {
            var stale = false
            let directory = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            try requireOriginalAnnotationCondition(!stale, "Do not repair an original folder bookmark in acceptance")
            candidates = [directory.appendingPathComponent("Annotations.sqlite").standardizedFileURL]
        } else {
            // Exact original AppConfig.appSupportDir Debug/Release branches.
            // The unique UI-created note selects the actual branch; ambiguity
            // is a fixture failure, never a guessed configuration or fallback.
            candidates = ["Maktabah-Debug", "Maktabah"].map {
                container.appendingPathComponent("Library/Application Support/" + $0 + "/Annotations.sqlite")
            }
        }
        var matches: [URL] = []
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            try requireOriginalAnnotationCondition(resource.isRegularFile == true && resource.isSymbolicLink != true,
                                                  "Require the original regular annotation database")
            let snapshot = try readOriginalAnnotationDatabase(url)
            if (snapshot.tables["annotations"] ?? []).filter({ $0["note"]?.value == note }).count == 1 { matches.append(url) }
        }
        try requireOriginalAnnotationCondition(matches.count == 1,
                                              "Exactly one original AppConfig database must contain the actual UI-created note")
        return .init(container: container, metadata: metadata, bookmark: bookmark, database: try XCTUnwrap(matches.first))
    }

    private func validateOriginalAnnotationOwner(_ owner: OriginalAnnotationOwner) throws {
        try requireOriginalAnnotationCondition(try Data(contentsOf: owner.container.appendingPathComponent(
            ".com.apple.mobile_container_manager.metadata.plist")) == owner.metadata,
            "The actual original annotation container owner changed")
        try requireOriginalAnnotationCondition(try originalSavedBookmark(in: owner.container) == owner.bookmark,
                                              "The original annotation folder selection changed")
    }

    @MainActor private func openOriginalAnnotationGlobalList() throws {
        let annotations = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", "Annotations"))
        try requireOriginalAnnotationCondition(annotations.firstMatch.waitForExistence(timeout: 15)
            && annotations.count == 1 && annotations.firstMatch.isHittable,
            "Require the actual original global Annotations tab")
        annotations.firstMatch.tap()
        _ = try originalAnnotationQueryField()
    }

    @MainActor private func originalAnnotationQueryField() throws -> XCUIElement {
        try requireOriginalAnnotationCondition(app.navigationBars["Annotations"].waitForExistence(timeout: 15)
            && app.buttons["original-annotations-file-menu"].exists,
            "Require the original global Annotation list, not its per-book sheet")
        let fields = app.searchFields
        try requireOriginalAnnotationCondition(fields.firstMatch.waitForExistence(timeout: 15) && fields.count == 1,
                                              "Require the one original native Annotation search field")
        return fields.element(boundBy: 0)
    }

    @MainActor private func setOriginalAnnotationQuery(_ text: String) throws {
        let field = try originalAnnotationQueryField()
        try requireOriginalAnnotationCondition(field.isHittable, "Original Annotation search field is not visible")
        field.tap(); field.typeKey("a", modifierFlags: .command)
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        if !text.isEmpty { field.typeText(text) }
        field.typeText("\n")
        let value = field.value as? String ?? ""
        try requireOriginalAnnotationCondition(text.isEmpty ? (value.isEmpty || value == field.placeholderValue) : value == text,
                                              "Original search input must contain the exact requested fixture text")
    }

    @MainActor private func originalAnnotationCells(note: String) -> XCUIElementQuery {
        app.collectionViews.cells.containing(.staticText, identifier: note)
    }

    @MainActor private func requireOriginalAnnotationCell(note: String, selected: Bool? = nil) throws -> XCUIElement {
        let cells = originalAnnotationCells(note: note)
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            guard cells.count == 1 else { return false }
            let cell = cells.element(boundBy: 0), frame = cell.frame
            let visible = frame.intersection(self.app.windows.firstMatch.frame)
            return cell.exists && cell.isHittable && !frame.isEmpty && !visible.isNull
                && visible.width * visible.height >= frame.width * frame.height * 0.98
                && (selected == nil || cell.isSelected == selected!)
        } }, object: nil)
        try requireOriginalAnnotationCondition(XCTWaiter.wait(for: [expected], timeout: 15) == .completed,
                                              "Require the exact original annotation cell, visible and in the expected selection state")
        let cell = cells.element(boundBy: 0)
        if selected == true {
            let collections = app.collectionViews.containing(.staticText, identifier: note)
            try requireOriginalAnnotationCondition(collections.count == 1, "Require the exact original target collection")
            let selectedCells = collections.element(boundBy: 0).cells.allElementsBoundByIndex.filter(\.isSelected)
            try requireOriginalAnnotationCondition(selectedCells.count == 1
                && selectedCells[0].staticTexts[note].exists,
                "Only the actual original configured note row may be selected")
        }
        return cell
    }

    @MainActor private func createOriginalAnnotationSelectionFixture(expectedPad: Bool) throws -> OriginalAnnotationFixture {
        let work = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let locator = app.staticTexts["reader-current-locator"].label
        try requireReaderLocator(locator)
        let workspace = try actualReaderWorkspace().current()
        let active = try XCTUnwrap(workspace.0.tabs.first { $0.session.id == workspace.1 })
        for key in ["OTZARIA_ORIGINAL_EDITOR_QUALIFICATION", "OTZARIA_ORIGINAL_EDITOR_PROCESS_RESUME"] {
            try requireOriginalAnnotationCondition(app.launchEnvironment[key] == nil,
                                                  "No editor qualification body/account may be injected")
        }
        let note = "Original annotation " + UUID().uuidString
        tap(try originalStudyToolsActionInWindow())
        let tools = app.segmentedControls["torah-inspector-tools"]
        try requireOriginalAnnotationCondition(tools.waitForExistence(timeout: 15), "Original Study Tools did not appear")
        tap(tools.buttons["Notes"]); tap(app.buttons["torah-inspector-add-note"])
        let editor = app.textViews["annotation-note-text"]
        try requireOriginalAnnotationCondition(editor.waitForExistence(timeout: 15) && editor.isHittable,
                                              "Require the original new-note editor")
        editor.tap(); editor.typeText(note)
        try requireOriginalAnnotationCondition(editor.value as? String == note, "Original note text differs")
        let save = app.buttons["annotation-save-toolbar"]
        try requireOriginalAnnotationCondition(save.exists && save.isEnabled && save.isHittable,
                                              "The original new-note save gate must permit this plain note")
        save.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            !editor.exists
        } }, object: nil)
        try requireOriginalAnnotationCondition(XCTWaiter.wait(for: [closed], timeout: 15) == .completed,
                                              "Original note save did not finish")
        tap(app.buttons["torah-inspector-close"])
        let owner = try resolveOriginalAnnotationOwner(note: note)
        let row = try originalAnnotationRow(readOriginalAnnotationDatabase(owner.database), note: note)
        try requireOriginalAnnotationCondition(row["bkId"]?.value == String(active.session.bookId),
                                              "The actual persistent annotation must belong to the original active Reader document")
        if let stored = row["backendLocator"], stored.type != SQLITE_NULL {
            let actual = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(stored.value.utf8)) as? [String: Any])
            try requireOriginalAnnotationCondition(actual["backend"] as? String == "otzaria"
                && actual["workKey"] as? String == work,
                "The saved qualified locator must match the independently observed original Reader work")
        }
        let fixture = OriginalAnnotationFixture(note: note, originalBookID: active.session.bookId,
            originalWork: work, owner: owner, row: row)
        do {
            try openOriginalAnnotationGlobalList()
            try setOriginalAnnotationQuery(note)
            _ = try requireOriginalAnnotationCell(note: note, selected: false)
            try requireOriginalAnnotationCondition(!app.textViews["annotation-note-text"].exists
                && !app.otherElements["original-book-annotations-list"].exists,
                "Setup must finish in the original global list with no editor or per-book sheet")
            return fixture
        } catch {
            // Preserve the real setup error. Cleanup is possible only after
            // the original persisted row and actual container were proven.
            capture("original-annotation-selection-setup-failed")
            do { try cleanupOriginalAnnotationSelectionFixture(fixture) }
            catch { XCTFail("Original unique-note cleanup after setup failure failed: \(error)") }
            throw error
        }
    }

    @MainActor private func cleanupOriginalAnnotationSelectionFixture(_ fixture: OriginalAnnotationFixture) throws {
        if app.state != .runningForeground { app.activate() }
        try validateOriginalAnnotationOwner(fixture.owner)
        try openOriginalAnnotationGlobalList()
        try setOriginalAnnotationQuery(fixture.note)
        let before = try readOriginalAnnotationDatabase(fixture.owner.database)
        try requireOriginalAnnotationCondition(try originalAnnotationRow(before, note: fixture.note) == fixture.row,
                                              "Cleanup must identify the unchanged exact UI-created original annotation")
        let cell = try requireOriginalAnnotationCell(note: fixture.note)
        cell.swipeLeft()
        let deletes = app.buttons.matching(NSPredicate(format: "label == %@", "Delete"))
        try requireOriginalAnnotationCondition(deletes.firstMatch.waitForExistence(timeout: 10)
            && deletes.count == 1 && deletes.firstMatch.isHittable,
            "Require the original selected row's one destructive swipe action")
        deletes.firstMatch.tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            guard let actual = try? self.readOriginalAnnotationDatabase(fixture.owner.database) else { return false }
            return (actual.tables["annotations"] ?? []).allSatisfy { $0["id"] != fixture.row["id"] }
                && !self.originalAnnotationCells(note: fixture.note).firstMatch.exists
        } }, object: nil)
        try requireOriginalAnnotationCondition(XCTWaiter.wait(for: [removed], timeout: 15) == .completed,
                                              "Original cleanup must remove the exact test-owned saved row")
        try setOriginalAnnotationQuery("")
        try validateOriginalAnnotationOwner(fixture.owner)
    }

    @MainActor
    func runOriginalAnnotationSelectionSystemIntent(expectedPad: Bool,
        journey: OriginalAnnotationSelectionJourney, fromBackground: Bool = false) async throws {
        let fixture = try createOriginalAnnotationSelectionFixture(expectedPad: expectedPad)
        defer {
            capture("original-annotation-selection-before-owned-cleanup")
            do { try cleanupOriginalAnnotationSelectionFixture(fixture) }
            catch { XCTFail("Original unique-note cleanup failed: \(error)") }
        }
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        var matches = try await system.entities["NativeAnnotationRecordEntity"].entities(matching: fixture.note)
        let discoveryEnd = ProcessInfo.processInfo.systemUptime + 15
        while matches.count != 1 && ProcessInfo.processInfo.systemUptime < discoveryEnd {
            // Read-only discovery waits for the original 0.3s filter task and
            // original collection publication. No effect/grant is requested.
            try await Task.sleep(for: .milliseconds(100))
            matches = try await system.entities["NativeAnnotationRecordEntity"].entities(matching: fixture.note)
        }
        try requireOriginalAnnotationCondition(matches.count == 1, "Require one real system-discovered original annotation record")
        let cached = try XCTUnwrap(matches.first), cachedID = cached.identifier.instanceIdentifier
        let windows = try await system.entities["NativeDestinationEntity"].entities(matching: "Annotations")
        try requireOriginalAnnotationCondition(windows.count == 1, "Require the actual original Annotations window entity")
        let window = try XCTUnwrap(windows.first)
        let process = try targetProcessIdentifier(), workspace = try actualReaderWorkspace().current()
        let workspaceBytes = try originalReaderTabWorkspaceSemantics()
        let database = try readOriginalAnnotationDatabase(fixture.owner.database)
        try requireOriginalAnnotationCondition(try originalAnnotationRow(database, note: fixture.note) == fixture.row,
                                              "The discovered metadata must retain the exact original persistent row")
        let before = try actualNativeReceiptLines()
        if fromBackground && journey == .select { backgroundOriginalHiddenPhoneReader() }
        // Sole measured positive delivery: cached real system AppEntity and
        // real window through the public original AppIntent. No direct perform,
        // private service call, route probe, synthesized entity or injected ACK.
        _ = try await system.intents["RevealAnnotationIntent"].makeIntent(annotation: cached, window: window).run()
        try requireOriginalAnnotationCondition(app.wait(for: .runningForeground, timeout: 15),
                                              "The original system handler must foreground the same app")
        _ = try requireOriginalAnnotationCell(note: fixture.note, selected: true)
        try requireNewSystemIntentReceipt(destination: "native.annotations.record", presentation: "currentTab", before: before)
        try requireOriginalAnnotationCondition(try targetProcessIdentifier() == process, "The original process changed")
        try requirePreservedOriginalWorkspace(workspace)
        try requireOriginalAnnotationCondition(try originalReaderTabWorkspaceSemantics() == workspaceBytes,
                                              "Record selection must preserve the full original workspace except its checkpoint revision")
        try validateOriginalAnnotationOwner(fixture.owner)
        try requireOriginalAnnotationCondition(try readOriginalAnnotationDatabase(fixture.owner.database) == database,
                                              "Reveal may not edit any original persistent annotation/body/tag/sync row or schema")
        try requireOriginalAnnotationCondition(try originalAnnotationQueryField().value as? String == fixture.note
            && !app.textViews["annotation-note-text"].exists && !app.otherElements["original-book-annotations-list"].exists,
            "Reveal must preserve the original filter and global list without invoking its ordinary editor/Reader tap")
        let evidence: [String: Any] = ["entity": cachedID, "sqlID": try XCTUnwrap(fixture.row["id"]?.value),
            "bookID": fixture.originalBookID, "originalWork": fixture.originalWork,
            "databaseSnapshotSHA256": SHA256.hash(data: try database.canonical).map { String(format: "%02x", $0) }.joined(),
            "scope": "actual warm global list, original selected visible note cell; no editor or Reader action"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "actual-original-annotation-system-selection"; attachment.lifetime = .keepAlways; add(attachment)
        capture("original-annotation-system-selected-cell")
        guard journey == .searchABA else { return }

        let successful = try actualNativeReceiptLines()
        let excluded = "Absent original annotation " + UUID().uuidString
        try setOriginalAnnotationQuery(excluded)
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            !self.originalAnnotationCells(note: fixture.note).firstMatch.exists
        } }, object: nil)
        try requireOriginalAnnotationCondition(XCTWaiter.wait(for: [absent], timeout: 15) == .completed,
                                              "The actual original search B must remove the original row")
        let withdrawn = try await system.entities["NativeAnnotationRecordEntity"].entities(matching: fixture.note)
        try requireOriginalAnnotationCondition(withdrawn.isEmpty, "The original filter must withdraw the successful cached reference")
        try setOriginalAnnotationQuery(fixture.note)
        _ = try requireOriginalAnnotationCell(note: fixture.note)
        var refreshed = try await system.entities["NativeAnnotationRecordEntity"].entities(matching: fixture.note)
        let refreshEnd = ProcessInfo.processInfo.systemUptime + 15
        while (refreshed.count != 1 || refreshed.first?.identifier.instanceIdentifier == cachedID)
            && ProcessInfo.processInfo.systemUptime < refreshEnd {
            try await Task.sleep(for: .milliseconds(100))
            refreshed = try await system.entities["NativeAnnotationRecordEntity"].entities(matching: fixture.note)
        }
        try requireOriginalAnnotationCondition(refreshed.count == 1
            && refreshed.first?.identifier.instanceIdentifier != cachedID,
            "Restored original search A must supply a different LIVE reference, not merely disable discovery")
        try requireOriginalAnnotationCondition(try actualNativeReceiptLines() == successful,
                                              "Original search setters may not manufacture navigation receipts")
        try requireOriginalAnnotationCondition(try readOriginalAnnotationDatabase(fixture.owner.database) == database,
                                              "The original filter cycle must not mutate annotation storage")
        if fromBackground { backgroundOriginalHiddenPhoneReader() }
        let refusedWorkspace = try originalReaderTabWorkspaceSemantics(), refusedReceipts = try actualNativeReceiptLines()
        var refused = false
        do {
            _ = try await system.intents["RevealAnnotationIntent"].makeIntent(annotation: cached, window: window).run()
        } catch {
            refused = true
            let proof = XCTAttachment(string: String(describing: type(of: error)))
            proof.name = "actual-cached-annotation-system-refusal-type"; proof.lifetime = .keepAlways; add(proof)
        }
        try requireOriginalAnnotationCondition(refused, "The SAME previously successful cached entity must now be refused")
        let mutation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated {
            guard (try? self.validateOriginalAnnotationOwner(fixture.owner)) != nil,
                  let receipts = try? self.actualNativeReceiptLines(),
                  let workspace = try? self.originalReaderTabWorkspaceSemantics(),
                  let snapshot = try? self.readOriginalAnnotationDatabase(fixture.owner.database) else { return true }
            return receipts != refusedReceipts || workspace != refusedWorkspace || snapshot != database
        } }, object: nil)
        mutation.isInverted = true
        try requireOriginalAnnotationCondition(XCTWaiter.wait(for: [mutation], timeout: 5) == .completed,
                                              "No late effect or receipt may follow refusal across the original five-second command bound")
        try requireOriginalAnnotationCondition(try actualNativeReceiptLines() == refusedReceipts
            && originalReaderTabWorkspaceSemantics() == refusedWorkspace
            && readOriginalAnnotationDatabase(fixture.owner.database) == database
            && targetProcessIdentifier() == process,
            "Refusal must preserve original process, workspace, complete persistent content and receipts")
        try validateOriginalAnnotationOwner(fixture.owner)
        if app.state == .runningForeground {
            try requireOriginalAnnotationCondition(try originalAnnotationQueryField().value as? String == fixture.note,
                                                  "Refusal may not change the restored original filter")
            _ = try requireOriginalAnnotationCell(note: fixture.note)
        }
        // A real system refusal is permitted to leave the original app in the
        // background. Cleanup foregrounds it only AFTER all refusal evidence.
        capture("original-annotation-cached-reference-refused")
    }
}
