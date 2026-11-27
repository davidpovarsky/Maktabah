

// Saved Results acceptance uses the ORIGINAL Search/Save/Folder controls.
// Its only measured navigation delivery is a cached system AppEntity. SQLite
// is opened read-only; no fixture database, result ID, query route or ACK is
// injected into the app. All six journeys require an already mounted tree.
import SQLite3

extension NativeRoutingAcceptanceTests {
    enum OriginalSavedResultsJourney {
        case folder, result, resultAfterReload, folderAfterDeletion
        var isFolder: Bool { self == .folder || self == .folderAfterDeletion }
        var refusesStale: Bool { self == .resultAfterReload || self == .folderAfterDeletion }
    }

    private enum OriginalSavedResultsFixtureError: Error {
        case rejected(String)
    }
    private struct OriginalSavedResultsCell: Codable, Equatable {
        let type: Int32
        let value: String
    }
    private typealias OriginalSavedResultsRow = [String: OriginalSavedResultsCell]
    private struct OriginalSavedResultsDatabase: Codable, Equatable {
        let folders: [OriginalSavedResultsRow]
        let results: [OriginalSavedResultsRow]
        var canonical: Data {
            get throws { try JSONEncoder.sortedSavedResults.encode(self) }
        }
    }
    private struct OriginalSavedResultsOwner {
        let container: URL
        let metadata: Data
        let bookmark: Data?
        let database: URL
    }
    private struct OriginalSavedResultsFixture {
        let parent: String
        let child: String
        let result: String
        let query: String
        let owner: OriginalSavedResultsOwner
        let parentID: String
        let childID: String
        let mode: String
        let books: String
    }

    private func requireOriginalSavedCondition(_ value: Bool, _ reason: String) throws {
        guard value else { throw OriginalSavedResultsFixtureError.rejected(reason) }
    }

    /// Preserve SQLite NULL, integer, floating point, text and blob identity.
    /// Both original tables are read in ONE read transaction, including their
    /// sync metadata. No expected result is supplied by the app under test.
    private func readOriginalSavedDatabase(_ url: URL) throws -> OriginalSavedResultsDatabase {
        var database: OpaquePointer?
        let opened = sqlite3_open_v2(url.path, &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard opened == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw OriginalSavedResultsFixtureError.rejected("Cannot open the original Saved Results database read-only")
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 1_000)
        try requireOriginalSavedCondition(sqlite3_db_readonly(database, "main") == 1,
                                         "The Saved Results oracle must be read-only")
        try requireOriginalSavedCondition(sqlite3_exec(database, "BEGIN DEFERRED TRANSACTION", nil, nil, nil) == SQLITE_OK,
                                         "Could not begin one original database read snapshot")
        defer { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) }
        func rows(_ sql: String) throws -> [OriginalSavedResultsRow] {
            var statement: OpaquePointer?
            try requireOriginalSavedCondition(sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
                                             "The original Saved Results schema is unavailable")
            guard let statement else { throw OriginalSavedResultsFixtureError.rejected("Missing original read statement") }
            defer { sqlite3_finalize(statement) }
            var values: [OriginalSavedResultsRow] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return values }
                try requireOriginalSavedCondition(status == SQLITE_ROW, "Original Saved Results read did not complete")
                var row: OriginalSavedResultsRow = [:]
                for column in 0..<sqlite3_column_count(statement) {
                    guard let name = sqlite3_column_name(statement, column) else {
                        throw OriginalSavedResultsFixtureError.rejected("Original SQL column has no name")
                    }
                    let key = String(cString: name), type = sqlite3_column_type(statement, column)
                    let value: String
                    switch type {
                    case SQLITE_NULL: value = ""
                    case SQLITE_INTEGER: value = String(sqlite3_column_int64(statement, column))
                    case SQLITE_FLOAT: value = String(sqlite3_column_double(statement, column).bitPattern)
                    case SQLITE_TEXT:
                        guard let text = sqlite3_column_text(statement, column) else {
                            throw OriginalSavedResultsFixtureError.rejected("Original SQL text is unreadable")
                        }
                        value = String(decoding: UnsafeBufferPointer(start: text,
                            count: Int(sqlite3_column_bytes(statement, column))), as: UTF8.self)
                    case SQLITE_BLOB:
                        let count = Int(sqlite3_column_bytes(statement, column))
                        if count == 0 { value = "" }
                        else {
                            guard let bytes = sqlite3_column_blob(statement, column) else {
                                throw OriginalSavedResultsFixtureError.rejected("Original SQL blob is unreadable")
                            }
                            value = Data(bytes: bytes, count: count).base64EncodedString()
                        }
                    default: throw OriginalSavedResultsFixtureError.rejected("Unknown original SQLite value type")
                    }
                    try requireOriginalSavedCondition(row[key] == nil, "Duplicate original SQL column")
                    row[key] = .init(type: type, value: value)
                }
                values.append(row)
            }
        }
        return try .init(folders: rows("SELECT * FROM folders ORDER BY id"),
                         results: rows("SELECT * FROM results ORDER BY id"))
    }

    private func originalSavedBookmark(in container: URL) throws -> Data? {
        let preferences = container.appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
        guard FileManager.default.fileExists(atPath: preferences.path) else { return nil }
        let dictionary = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: Data(contentsOf: preferences), format: nil) as? [String: Any])
        guard let value = dictionary["annotations_FolderPath"] else { return nil }
        return try XCTUnwrap(value as? Data, "The original AppConfig bookmark must retain its actual stored type")
    }

    @MainActor private func resolveOriginalSavedOwner(parentName: String, childName: String,
                                                     resultName: String) throws -> OriginalSavedResultsOwner {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        try requireOriginalSavedCondition(Array(sidecar.pathComponents.suffix(suffix.count)) == suffix,
                                         "Require this test's actual original workspace path")
        var container = sidecar
        for _ in suffix { container.deleteLastPathComponent() }
        try requireOriginalSavedCondition(container.deletingLastPathComponent() == workspaceContainerParent().standardizedFileURL,
                                         "Original workspace must belong to the actual simulator data-container parent")
        try requireOriginalSavedCondition(UUID(uuidString: container.lastPathComponent) != nil,
                                         "Require the actual MCM container identity")
        let metadata = try Data(contentsOf: container.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist"))
        let identity = try XCTUnwrap(PropertyListSerialization.propertyList(from: metadata, format: nil) as? [String: Any])
        try requireOriginalSavedCondition(identity["MCMMetadataIdentifier"] as? String == "com.davidpovarsky.chavrusatext",
                                         "The Saved Results oracle must use the actual target app owner")
        try requireOriginalSavedCondition(!app.launchArguments.contains("-annotations_FolderPath"),
                                         "No launch-domain Saved Results storage override is allowed")
        let bookmark = try originalSavedBookmark(in: container)
        let candidates: [URL]
        if let bookmark, !bookmark.isEmpty {
            var stale = false
            let original = try URL(resolvingBookmarkData: bookmark, options: [],
                                   relativeTo: nil, bookmarkDataIsStale: &stale)
            try requireOriginalSavedCondition(!stale, "Do not repair or rewrite a stale original folder bookmark in the test")
            candidates = [original.appendingPathComponent("SearchResults.sqlite").standardizedFileURL]
        } else {
            // These are the two exact AppConfig.appSupportDir compile branches.
            // The unique UI-created rows, not a guessed build configuration,
            // select the one actual database. Ambiguity is a fixture failure.
            candidates = ["Maktabah-Debug", "Maktabah"].map {
                container.appendingPathComponent("Library/Application Support/" + $0 + "/SearchResults.sqlite")
            }
        }
        var matches: [URL] = []
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            let resource = try candidate.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            try requireOriginalSavedCondition(resource.isRegularFile == true && resource.isSymbolicLink != true,
                                             "Require an original regular database, not a test redirect")
            let data = try readOriginalSavedDatabase(candidate)
            if data.folders.filter({ $0["name"]?.value == parentName }).count == 1,
               data.folders.filter({ $0["name"]?.value == childName }).count == 1,
               !data.results.filter({ $0["name"]?.value == resultName }).isEmpty { matches.append(candidate) }
        }
        try requireOriginalSavedCondition(matches.count == 1,
                                         "Exactly one original AppConfig location must contain the rows created through UI")
        return .init(container: container, metadata: metadata, bookmark: bookmark, database: try XCTUnwrap(matches.first))
    }

    private func validateOriginalSavedOwner(_ owner: OriginalSavedResultsOwner) throws {
        try requireOriginalSavedCondition(try Data(contentsOf: owner.container.appendingPathComponent(
            ".com.apple.mobile_container_manager.metadata.plist")) == owner.metadata,
            "Actual Saved Results container owner changed")
        try requireOriginalSavedCondition(originalSavedBookmark(in: owner.container) == owner.bookmark,
                                         "Original Saved Results folder selection changed")
    }

    @MainActor private func requireOriginalSavedButton(_ name: String) throws -> XCUIElement {
        let candidates = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name))
        try requireOriginalSavedCondition(candidates.firstMatch.waitForExistence(timeout: 15),
                                         "The uniquely named original Saved Results control is absent")
        try requireOriginalSavedCondition(candidates.count == 1,
                                         "Require one exact original control for the unique UI-created name")
        let button = candidates.element(boundBy: 0)
        try requireOriginalSavedVisible(button)
        return button
    }

    @MainActor private func requireOriginalSavedVisible(_ element: XCUIElement) throws {
        let frame = element.frame, visible = frame.intersection(app.windows.firstMatch.frame)
        try requireOriginalSavedCondition(element.exists && element.isHittable && !frame.isEmpty
            && !visible.isNull && visible.width * visible.height >= frame.width * frame.height * 0.9,
            "Require the actual original control inside its visible native window")
    }

    @MainActor private func replaceOriginalSavedText(_ field: XCUIElement, with value: String) throws {
        try requireOriginalSavedVisible(field)
        field.tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value)
        try requireOriginalSavedCondition(field.value as? String == value, "Original field did not receive the complete fixture input")
    }

    @MainActor private func createOriginalSavedFolderInWriter(_ name: String) throws {
        let writer = app.navigationBars["Save Results"]
        try requireOriginalSavedCondition(writer.exists, "Only the original result writer may create this fixture")
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", "New Folder"))
        try requireOriginalSavedCondition(buttons.count == 1, "Require the original writer's single New Folder action")
        try requireOriginalSavedVisible(buttons.element(boundBy: 0)); buttons.element(boundBy: 0).tap()
        let alert = app.alerts["Create Folder"]
        try requireOriginalSavedCondition(alert.waitForExistence(timeout: 10) && alert.textFields.count == 1,
                                         "Require the original Create Folder prompt")
        try replaceOriginalSavedText(alert.textFields.element(boundBy: 0), with: name)
        alert.buttons["Create"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        try requireOriginalSavedCondition(XCTWaiter.wait(for: [gone], timeout: 10) == .completed,
                                         "The original folder creation must finish")
        try requireOriginalSavedButton(name).tap()
    }

    @MainActor private func openOriginalSavedResults() throws {
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.require("global-search-saved").tap()
        try requireOriginalSavedCondition(app.navigationBars["Saved Results"].waitForExistence(timeout: 20),
                                         "Require the original Saved Results sheet")
    }

    @MainActor private func closeOriginalSavedResults() throws {
        let close = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Close"))
        try requireOriginalSavedCondition(close.count == 1, "Require the original Saved Results Close control")
        try requireOriginalSavedVisible(close.element(boundBy: 0)); close.element(boundBy: 0).tap()
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.wait("The original Saved Results sheet must dismiss to its same Search parent") {
            ui.control("global-search-query").isHittable && !close.firstMatch.exists
        }
    }

    @MainActor private func requireOriginalSavedSearchUnchanged(_ fixture: OriginalSavedResultsFixture) throws {
        let ui = OriginalSearchContextUI(app: app, test: self)
        try requireOriginalSavedCondition(try ui.require("global-search-query").value as? String == fixture.query,
                                         "Revealing a saved node must not execute or replace the original query")
        try requireOriginalSavedCondition(try ui.require("global-search-mode").value as? String == fixture.mode,
                                         "Saved node reveal must preserve original search mode")
        try requireOriginalSavedCondition(try ui.require("global-search-books").label == fixture.books,
                                         "Saved node reveal must preserve original book filter")
        try requireOriginalSavedCondition(!ui.control("global-search-loading").exists
            && !ui.control("global-search-error").exists && !ui.control("global-search-dirty").exists,
            "Saved node reveal must not start or invalidate the original search")
    }

    @MainActor private func createOriginalSavedFixture(expectedPad: Bool) throws -> OriginalSavedResultsFixture {
        _ = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let receipts = try actualNativeReceiptLines()
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.returnToOriginalSearch()
        let query = try XCTUnwrap(ProcessInfo.processInfo.environment["GLOBAL_SEARCH_TEST_QUERY"],
                                 "Use the original runner's query derived from its installed search fixture")
        try requireOriginalSavedCondition(!query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                         "The original search fixture query cannot be empty")
        try ui.require("global-search-mode").tap(); try ui.require("global-search-mode-advanced").tap()
        let field = try ui.require("global-search-query")
        try requireOriginalSavedCondition(app.descendants(matching: .any).matching(identifier: "global-search-query").count == 1,
                                         "Require the actual single original query field")
        try replaceOriginalSavedText(field, with: query); field.typeText("\n")
        try ui.wait("The real original search must finish with saveable rows", timeout: 90) {
            let rows = self.app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-result-preview-toggle-"))
            return rows.count > 0 && !ui.control("global-search-loading").exists
                && !ui.control("global-search-cancel").exists && !ui.control("global-search-error").exists
                && !ui.control("global-search-dirty").exists
        }
        let mode = try XCTUnwrap(ui.require("global-search-mode").value as? String)
        let books = try ui.require("global-search-books").label
        let token = UUID().uuidString.lowercased()
        let parent = "Saved parent " + token, child = "Saved child " + token, result = "Saved result " + token
        try ui.require("global-search-more").tap(); try ui.require("global-search-save").tap()
        let writer = app.navigationBars["Save Results"]
        try requireOriginalSavedCondition(writer.waitForExistence(timeout: 15), "Require the original result writer")
        try createOriginalSavedFolderInWriter(parent)
        try createOriginalSavedFolderInWriter(child)
        let name = app.textFields["Name"]
        try replaceOriginalSavedText(name, with: result)
        let save = writer.buttons["Save"]
        try requireOriginalSavedVisible(save); save.tap()
        try ui.wait("The original save must return to Search") {
            !writer.exists && ui.control("global-search-saved").isHittable
        }
        let owner = try resolveOriginalSavedOwner(parentName: parent, childName: child, resultName: result)
        let data = try readOriginalSavedDatabase(owner.database)
        let parentRow = try XCTUnwrap(data.folders.first { $0["name"]?.value == parent })
        let childRow = try XCTUnwrap(data.folders.first { $0["name"]?.value == child })
        let parentID = try XCTUnwrap(parentRow["id"]?.value), childID = try XCTUnwrap(childRow["id"]?.value)
        try requireOriginalSavedCondition(parentRow["parent"]?.type == SQLITE_NULL
            && childRow["parent"]?.value == parentID, "Require the exact original nested folder relationship")
        let saved = data.results.filter { $0["name"]?.value == result }
        try requireOriginalSavedCondition(!saved.isEmpty && saved.allSatisfy {
            $0["folder_id"]?.value == childID && $0["query"]?.value == query
                && $0["archives"]?.type == SQLITE_INTEGER && $0["bkId"]?.type == SQLITE_INTEGER
                && !($0["contentId"]?.value ?? "").isEmpty
        }, "Require original persisted search rows, without assuming one SQL row per grouped result")
        try requireOriginalSavedCondition(actualNativeReceiptLines() == receipts,
                                         "Original fixture UI must not fabricate a measured navigation receipt")
        let fixture = OriginalSavedResultsFixture(parent: parent, child: child, result: result, query: query,
            owner: owner, parentID: parentID, childID: childID, mode: mode, books: books)
        try requireOriginalSavedSearchUnchanged(fixture)
        try openOriginalSavedResults()
        try requireOriginalSavedButton(parent).tap()
        try requireOriginalSavedCondition(app.navigationBars[parent].waitForExistence(timeout: 15),
                                         "The original parent folder must be mounted before entity discovery")
        try requireOriginalSavedVisible(requireOriginalSavedButton(child))
        return fixture
    }

    @MainActor private func requireOriginalSavedTarget(_ fixture: OriginalSavedResultsFixture) throws {
        let page = app.navigationBars[fixture.child]
        try requireOriginalSavedCondition(page.waitForExistence(timeout: 15),
                                         "A root-only Saved Results receipt cannot satisfy the exact original folder")
        try requireOriginalSavedVisible(page.staticTexts[fixture.child])
        let row = try requireOriginalSavedButton(fixture.result)
        try requireOriginalSavedCondition(row.label.contains(fixture.result), "Require the actual saved result row")
        // Do NOT tap this original row: its legitimate action executes the search.
    }

    @MainActor private func deleteOriginalSavedChild(_ fixture: OriginalSavedResultsFixture) throws {
        let back = app.navigationBars[fixture.child].buttons[fixture.parent]
        try requireOriginalSavedVisible(back); back.tap()
        try requireOriginalSavedCondition(app.navigationBars[fixture.parent].waitForExistence(timeout: 10),
                                         "Use the original navigation Back to keep the same mounted tree")
        let child = try requireOriginalSavedButton(fixture.child)
        child.swipeLeft()
        let deletes = app.buttons.matching(NSPredicate(format: "label == %@", "Delete"))
        try requireOriginalSavedCondition(deletes.count == 1, "Require the original swiped child's sole Delete action")
        try requireOriginalSavedVisible(deletes.element(boundBy: 0)); deletes.element(boundBy: 0).tap()
        let alert = app.alerts["Delete Folder"]
        try requireOriginalSavedCondition(alert.waitForExistence(timeout: 10)
            && alert.staticTexts.allElementsBoundByIndex.contains(where: { $0.label.contains(fixture.child) }),
            "Deletion must explicitly identify only the test-owned child")
        alert.buttons["Delete"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !alert.exists, let data = try? self.readOriginalSavedDatabase(fixture.owner.database) else { return false }
            return !data.folders.contains { $0["id"]?.value == fixture.childID }
                && !data.results.contains { $0["folder_id"]?.value == fixture.childID }
                && data.folders.contains { $0["id"]?.value == fixture.parentID && $0["name"]?.value == fixture.parent }
        }, object: nil)
        try requireOriginalSavedCondition(XCTWaiter.wait(for: [gone], timeout: 15) == .completed,
                                         "Require the original committed delete and its surviving parent")
    }

    @MainActor private func cleanupOriginalSavedFixture(_ fixture: OriginalSavedResultsFixture) throws {
        // Cleanup starts ONLY after the measured proof/refusal window. An
        // explicit cleanup activation never counts as system foreground ACK.
        if app.state == .runningBackground || app.state == .runningBackgroundSuspended { app.activate() }
        try requireOriginalSavedCondition(app.state == .runningForeground && app.alerts.count == 0,
                                         "Cleanup will not dismiss an unknown original alert")
        try validateOriginalSavedOwner(fixture.owner)
        if app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Close")).count == 1 {
            try closeOriginalSavedResults()
        }
        try requireOriginalSavedSearchUnchanged(fixture)
        try openOriginalSavedResults()
        let data = try readOriginalSavedDatabase(fixture.owner.database)
        let parents = data.folders.filter { $0["name"]?.value == fixture.parent }
        try requireOriginalSavedCondition(parents.count == 1 && parents[0]["id"]?.value == fixture.parentID
            && parents[0]["parent"]?.type == SQLITE_NULL, "Cleanup may delete only this exact original owned folder")
        let parent = try requireOriginalSavedButton(fixture.parent); parent.swipeLeft()
        let deletes = app.buttons.matching(NSPredicate(format: "label == %@", "Delete"))
        try requireOriginalSavedCondition(deletes.count == 1, "Require one original cleanup Delete action")
        try requireOriginalSavedVisible(deletes.element(boundBy: 0)); deletes.element(boundBy: 0).tap()
        let alert = app.alerts["Delete Folder"]
        try requireOriginalSavedCondition(alert.waitForExistence(timeout: 10)
            && alert.staticTexts.allElementsBoundByIndex.contains(where: { $0.label.contains(fixture.parent) }),
            "Original cleanup prompt must name only the test-owned parent")
        alert.buttons["Delete"].tap()
        let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !alert.exists, let after = try? self.readOriginalSavedDatabase(fixture.owner.database) else { return false }
            return !after.folders.contains { $0["name"]?.value == fixture.parent || $0["name"]?.value == fixture.child }
                && !after.results.contains { $0["name"]?.value == fixture.result }
        }, object: nil)
        try requireOriginalSavedCondition(XCTWaiter.wait(for: [removed], timeout: 15) == .completed,
                                         "Original cleanup must remove all test-owned saved nodes")
        try closeOriginalSavedResults()
    }

    @MainActor
    func runOriginalSavedResultsSystemIntent(expectedPad: Bool, journey: OriginalSavedResultsJourney,
                                             fromBackground: Bool = false) async throws {
        let fixture = try createOriginalSavedFixture(expectedPad: expectedPad)
        defer {
            capture("original-saved-results-before-owned-cleanup")
            do { try cleanupOriginalSavedFixture(fixture) }
            catch { XCTFail("Original test-owned Saved Results cleanup failed: \(error)") }
        }
        let pid = try targetProcessIdentifier(), workspace = try actualReaderWorkspace().current()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let entityType = journey.isFolder ? "NativeSavedResultFolderEntity" : "NativeSavedResultEntity"
        let title = journey.isFolder ? fixture.child : fixture.result
        let matches = try await system.entities[entityType].entities(matching: title)
        try requireOriginalSavedCondition(matches.count == 1, "Require one actual system-discovered saved node")
        let cached = try XCTUnwrap(matches.first), cachedID = cached.identifier.instanceIdentifier
        let windows = try await system.entities["NativeDestinationEntity"].entities(matching: "Saved Results")
        try requireOriginalSavedCondition(windows.count == 1, "Require the actual current Saved Results window entity")
        let window = try XCTUnwrap(windows.first)
        try requireOriginalSavedCondition(!app.navigationBars[fixture.child].exists,
                                         "The exact target page must be hidden before the measured reveal")
        let positiveBackground = fromBackground && !journey.refusesStale
        if positiveBackground { backgroundOriginalHiddenPhoneReader() }
        let before = try actualNativeReceiptLines(), database = try readOriginalSavedDatabase(fixture.owner.database)
        let stableWorkspace = try originalReaderTabWorkspaceSemantics()
        try validateOriginalSavedOwner(fixture.owner)
        // Sole measured positive delivery: real system entity, real window,
        // original AppIntent. No direct perform(), service call, probe or URL.
        if journey.isFolder {
            _ = try await system.intents["RevealSavedResultsFolderIntent"].makeIntent(folder: cached, window: window).run()
        } else {
            _ = try await system.intents["RevealSavedResultIntent"].makeIntent(result: cached, window: window).run()
        }
        try requireOriginalSavedCondition(app.wait(for: .runningForeground, timeout: 15),
                                         "The actual system intent must foreground its original app")
        try requireOriginalSavedTarget(fixture)
        try requireNewSystemIntentReceipt(destination: "native.savedResults", presentation: "sheet", before: before)
        XCTAssertEqual(try targetProcessIdentifier(), pid)
        try requirePreservedOriginalWorkspace(workspace)
        XCTAssertEqual(try originalReaderTabWorkspaceSemantics(), stableWorkspace)
        try validateOriginalSavedOwner(fixture.owner)
        XCTAssertEqual(try readOriginalSavedDatabase(fixture.owner.database), database,
                       "Reveal must preserve every original folders/results row and sync field")
        let successful = try actualNativeReceiptLines()
        let recordEvidence: [String: Any] = ["entity": cachedID, "kind": journey.isFolder ? "folder" : "result",
            "parentSQLID": fixture.parentID, "folderSQLID": fixture.childID,
            "folders": database.folders.count, "resultRows": database.results.count,
            "databaseSnapshotSHA256": SHA256.hash(data: try database.canonical).map { String(format: "%02x", $0) }.joined(),
            "scope": "warm mounted original tree; result revealed without activation"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: recordEvidence, options: [.sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "actual-original-saved-node-system-selection"; attachment.lifetime = .keepAlways; add(attachment)
        capture("original-saved-results-exact-target")
        guard journey.refusesStale else {
            try closeOriginalSavedResults(); try requireOriginalSavedSearchUnchanged(fixture)
            XCTAssertEqual(try actualNativeReceiptLines(), successful)
            return
        }

        if journey == .resultAfterReload {
            try closeOriginalSavedResults(); try requireOriginalSavedSearchUnchanged(fixture)
            try openOriginalSavedResults()
            try requireOriginalSavedButton(fixture.parent).tap()
            let refreshed = try await system.entities[entityType].entities(matching: title)
            try requireOriginalSavedCondition(refreshed.count == 1
                && refreshed[0].identifier.instanceIdentifier != cachedID,
                "The original reload must publish a real new entity, not merely make all discovery unavailable")
        } else {
            try deleteOriginalSavedChild(fixture)
            let withdrawn = try await system.entities[entityType].entities(matching: title)
            try requireOriginalSavedCondition(withdrawn.isEmpty, "The original deletion must withdraw the cached folder")
            let surviving = try await system.entities["NativeSavedResultFolderEntity"].entities(matching: fixture.parent)
            try requireOriginalSavedCondition(surviving.count == 1,
                                             "The actual surviving original tree must still support discovery")
        }
        XCTAssertEqual(try actualNativeReceiptLines(), successful,
                       "Original reload/delete may not manufacture a canonical navigation receipt")
        if fromBackground { backgroundOriginalHiddenPhoneReader() }
        let refusedDatabase = try readOriginalSavedDatabase(fixture.owner.database)
        let refusedWorkspace = try originalReaderTabWorkspaceSemantics()
        let refusedReceipts = try actualNativeReceiptLines()
        var rejected = false
        do {
            // Reuse the SAME system entity and window that just succeeded.
            if journey.isFolder {
                _ = try await system.intents["RevealSavedResultsFolderIntent"].makeIntent(folder: cached, window: window).run()
            } else {
                _ = try await system.intents["RevealSavedResultIntent"].makeIntent(result: cached, window: window).run()
            }
        } catch {
            rejected = true
            let evidence = XCTAttachment(string: String(describing: error))
            evidence.name = "actual-stale-saved-node-system-refusal"; evidence.lifetime = .keepAlways; add(evidence)
        }
        XCTAssertTrue(rejected, "The previously successful stale original entity must now be refused")
        let mutation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard (try? self.validateOriginalSavedOwner(fixture.owner)) != nil,
                  let actualReceipts = try? self.actualNativeReceiptLines(),
                  let actualWorkspace = try? self.originalReaderTabWorkspaceSemantics(),
                  let actualDatabase = try? self.readOriginalSavedDatabase(fixture.owner.database) else { return true }
            return actualReceipts != refusedReceipts || actualWorkspace != refusedWorkspace || actualDatabase != refusedDatabase
        }, object: nil)
        mutation.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [mutation], timeout: 5), .completed,
                       "A refused cached node must produce neither a receipt nor a deferred mutation across the original five-second bound")
        XCTAssertEqual(try targetProcessIdentifier(), pid)
        XCTAssertEqual(try actualNativeReceiptLines(), refusedReceipts)
        XCTAssertEqual(try originalReaderTabWorkspaceSemantics(), refusedWorkspace)
        XCTAssertEqual(try readOriginalSavedDatabase(fixture.owner.database), refusedDatabase)
        try validateOriginalSavedOwner(fixture.owner)
        if app.state == .runningForeground {
            try requireOriginalSavedCondition(app.navigationBars[fixture.parent].exists
                && !app.navigationBars[fixture.child].exists, "Refusal must leave the actual original parent page unchanged")
        } else {
            XCTAssertTrue(fromBackground)
            XCTAssertTrue(app.state == .runningBackground || app.state == .runningBackgroundSuspended,
                          "A real system refusal may leave the app background; no activation can satisfy the measured journey")
        }
        let state = XCTAttachment(string: "Actual post-refusal app state: \(app.state.rawValue)")
        state.name = "actual-stale-saved-node-process-state"; state.lifetime = .keepAlways; add(state)
    }
}

private extension JSONEncoder {
    static var sortedSavedResults: JSONEncoder {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return encoder
    }
}
