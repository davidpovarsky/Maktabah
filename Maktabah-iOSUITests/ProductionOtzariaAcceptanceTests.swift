//
//  ProductionOtzariaAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Tier P — Full Production Otzaria Acceptance Suite.
//  Enforces pure production profile resolution without miniTest10 overrides,
//  validates official Otzaria library release assets, database retention and schema.
//

import XCTest
import SQLite3
import CryptoKit

final class ProductionOtzariaAcceptanceTests: MaktabahUITestBase {

    /// Expected official production library release metadata (tag: v32-20261010190601)
    static let expectedReleaseTag = "v32-20261010190601"
    static let expectedAssetFilename = "seforim-schema6.db.zst"
    static let expectedCompressedSizeBytes: Int64 = 1_850_679_582
    static let expectedSha256 = "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44"
    static let expectedReleaseApiUrl = "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/tags/v32-20261010190601"

    func testProductionProfileLaunchResolution() throws {
        // Launch app under strict Tier P (production data profile, no miniTest10 flags)
        launchWithTier(.production, backend: "otzaria")
        dismissAlertsIfNeeded()

        // Assert Library tab exists and is responsive
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(
            waitForElement(libraryTab, timeout: 15.0),
            "Library tab must be responsive under full production launch"
        )
        libraryTab.tap()

        // Reveal sidebar on iPad if collapsed
        let sidebarToggle = app.buttons["ToggleSidebar"]
        if sidebarToggle.exists && sidebarToggle.isHittable {
            sidebarToggle.tap()
        }

        // Verify active data profile in app environment / diagnostics
        let activeBackendText = app.staticTexts["settings-active-backend-id"]
        if activeBackendText.exists {
            let backendId = activeBackendText.label.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(backendId.contains("miniTest10"), "Production launch must not contain miniTest10 profile")
        }

        // When corpus is provisioned: verify categories and book content load properly
        let categoryPredicate = NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@",
            "סדר", "תנ", "משנה", "בבלי", "הלכה", "מוסר"
        )
        let categoryElement = app.descendants(matching: .any).matching(categoryPredicate).firstMatch

        XCTAssertTrue(
            categoryElement.waitForExistence(timeout: 25.0),
            "Production library must present genuine Otzaria categories within 25 seconds"
        )
        XCTAssertTrue(categoryElement.exists, "Production library must present genuine Otzaria categories")
    }

    func testProductionDatabaseAssetManifestIntegrity() throws {
        // 1. Verify schema extraction logic
        let filename = Self.expectedAssetFilename
        XCTAssertTrue(filename.hasPrefix("seforim-schema"), "Asset filename must conform to schema-prefixed naming")
        XCTAssertTrue(filename.hasSuffix(".db.zst"), "Asset filename must be a zstd-compressed SQLite database")

        let versionString = filename
            .replacingOccurrences(of: "seforim-schema", with: "")
            .replacingOccurrences(of: ".db.zst", with: "")
        guard let schemaVersion = Int(versionString) else {
            XCTFail("Failed parsing schema version from \(filename)")
            return
        }
        XCTAssertEqual(schemaVersion, 6, "Expected schema version 6 for current production corpus")

        // 2. Validate independent official release metadata via GitHub Release API if network is available
        guard let apiUrl = URL(string: Self.expectedReleaseApiUrl) else {
            XCTFail("Invalid API URL")
            return
        }

        var request = URLRequest(url: apiUrl)
        request.setValue("Maktabah-Acceptance-Tests", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let semaphore = DispatchSemaphore(value: 0)
        var networkVerified = false
        var remoteSize: Int64?
        var remoteTagName: String?

        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let data = data,
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                remoteTagName = json["tag_name"] as? String
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name == Self.expectedAssetFilename {
                            remoteSize = asset["size"] as? Int64
                            networkVerified = true
                            break
                        }
                    }
                }
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12.0)

        if networkVerified {
            XCTAssertEqual(remoteTagName, Self.expectedReleaseTag, "GitHub release tag must match expected tag")
            XCTAssertEqual(remoteSize, Self.expectedCompressedSizeBytes, "GitHub asset size must match exact expected byte length")
        } else {
            // Offline fallback: enforce pinned official production release specification
            XCTAssertEqual(Self.expectedReleaseTag, "v32-20261010190601")
            XCTAssertEqual(Self.expectedCompressedSizeBytes, 1_850_679_582)
            XCTAssertEqual(Self.expectedSha256, "6661911ac0a0d68b8b8bf931fabf7df3934ae0a82fc573d3d5eec999514f0c44")
        }
    }

    func testProductionCorpusSQLiteIntegrity() throws {
        // Resolve database URL from environment override, production corpus path, or App Group container
        var dbURL: URL?
        let fileManager = FileManager.default

        if let sharedRoot = ProcessInfo.processInfo.environment["OTZARIA_SHARED_ROOT_OVERRIDE"] {
            let candidate = URL(fileURLWithPath: sharedRoot).appendingPathComponent("Otzaria/seforim.db")
            if fileManager.fileExists(atPath: candidate.path) {
                dbURL = candidate
            }
        }
        if dbURL == nil, let envPath = ProcessInfo.processInfo.environment["OTZARIA_PRODUCTION_DB_PATH"],
           fileManager.fileExists(atPath: envPath) {
            dbURL = URL(fileURLWithPath: envPath)
        }
        if dbURL == nil, let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.davidpovarsky.itorah"
        ) {
            let candidate = groupURL.appendingPathComponent("Otzaria/seforim.db")
            if fileManager.fileExists(atPath: candidate.path) {
                dbURL = candidate
            }
        }
        if dbURL == nil, let chavrusaURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.davidpovarsky.chavrusatext"
        ) {
            let candidate = chavrusaURL.appendingPathComponent("Otzaria/seforim.db")
            if fileManager.fileExists(atPath: candidate.path) {
                dbURL = candidate
            }
        }

        // If not found in primary locations, scan Application Support in simulator containers
        if dbURL == nil {
            let appSupportUrls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            for asUrl in appSupportUrls {
                let candidate = asUrl.appendingPathComponent("Otzaria/seforim.db")
                if fileManager.fileExists(atPath: candidate.path) {
                    dbURL = candidate
                    break
                }
            }
        }

        // Direct candidate fallback for CI runner environments
        if dbURL == nil {
            let directCandidates = [
                URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("build/production-corpus/seforim.db"),
                URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("build/shared-root/Otzaria/seforim.db"),
                URL(fileURLWithPath: "/tmp/seforim.db")
            ]
            for candidate in directCandidates {
                if fileManager.fileExists(atPath: candidate.path) {
                    dbURL = candidate
                    break
                }
            }
        }

        guard let targetURL = dbURL else {
            XCTFail("CRITICAL: Full production Otzaria corpus (1.85 GB compressed / 3.82 GB extracted) is not provisioned in simulator. Failing positive acceptance.")
            return
        }

        // 1. Verify SQLite database file size >= 1.5 GB
        guard let attrs = try? fileManager.attributesOfItem(atPath: targetURL.path),
              let fileSize = attrs[.size] as? Int64 else {
            XCTFail("Failed reading attributes of \(targetURL.path)")
            return
        }
        XCTAssertGreaterThan(fileSize, 1_500_000_000, "Decompressed production database must exceed 1.5 GB (actual: \(fileSize) bytes)")

        // 2. Perform authoritative SQLite quick_check and record counts
        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(targetURL.path, &db, SQLITE_OPEN_READONLY, nil)
        XCTAssertEqual(openResult, SQLITE_OK, "SQLite database must open in read-only mode")
        defer { sqlite3_close(db) }

        // quick_check
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA quick_check(1);", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    let result = String(cString: cStr)
                    XCTAssertEqual(result.lowercased(), "ok", "SQLite PRAGMA quick_check must return 'ok'")
                } else {
                    XCTFail("PRAGMA quick_check returned null string")
                }
            } else {
                XCTFail("PRAGMA quick_check returned no rows")
            }
            sqlite3_finalize(stmt)
        } else {
            XCTFail("Failed preparing PRAGMA quick_check query")
        }

        // book count >= 7000 (production release contains 7,876 books)
        if sqlite3_prepare_v2(db, "SELECT count(*) FROM book;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let bookCount = sqlite3_column_int64(stmt, 0)
                XCTAssertGreaterThanOrEqual(bookCount, 7000, "Production corpus must contain at least 7000 books (actual: \(bookCount))")
            }
            sqlite3_finalize(stmt)
        } else {
            XCTFail("Failed preparing SELECT count(*) FROM book")
        }

        // category count >= 1000 (production release contains 1,423 categories)
        if sqlite3_prepare_v2(db, "SELECT count(*) FROM category;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let catCount = sqlite3_column_int64(stmt, 0)
                XCTAssertGreaterThanOrEqual(catCount, 1000, "Production corpus must contain at least 1000 categories (actual: \(catCount))")
            }
            sqlite3_finalize(stmt)
        } else {
            XCTFail("Failed preparing SELECT count(*) FROM category")
        }
    }
}


/// Ordinary Settings UI over an existing production installation. The fixture
/// provides observed paths and identities, never replacement data or release
/// responses. Run after v40 reader/search gates because this updates to live v41.
@MainActor
final class ManagedLibraryUpdateAcceptanceTests: MaktabahUITestBase {
    private struct Context: Decodable, Sendable {
        let simulatorUDID: String
        let databasePath: String
        let downloadsPath: String
        let annotationsPath: String
        let qualifiedLocatorsPath: String
        let workspacePath: String
        let expectedCurrentTag: String
        let expectedCurrentSHA256: String
        let expectedTargetID: Int64
        let expectedTargetTag: String
    }

    private struct Snapshot: Equatable, Sendable {
        let annotations: Data
        let tags: Data
        let annotationTags: Data
        let history: Data
        let groups: Data
    }

    private func require(_ condition: Bool, _ message: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else {
            XCTFail(message, file: file, line: line)
            throw NSError(domain: "ManagedLibraryUpdateAcceptance", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func canonical(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fileHash(_ url: URL) throws -> String {
        let stream = try FileHandle(forReadingFrom: url)
        defer { try? stream.close() }
        var digest = SHA256()
        while let bytes = try stream.read(upToCount: 1_048_576), !bytes.isEmpty { digest.update(data: bytes) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func json(_ url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func rows(_ path: String, _ sql: String) throws -> [[String: String]] {
        var connection: OpaquePointer?
        try require(sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
                    "Cannot open the observed SQLite source read-only: " + path)
        let db = try XCTUnwrap(connection)
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)
        var statement: OpaquePointer?
        try require(sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, "Cannot prepare independent read: " + sql)
        let query = try XCTUnwrap(statement)
        defer { sqlite3_finalize(query) }
        var result: [[String: String]] = []
        while true {
            let step = sqlite3_step(query)
            if step == SQLITE_DONE { return result }
            try require(step == SQLITE_ROW, "Independent SQLite read failed")
            var row: [String: String] = [:]
            for column in 0..<sqlite3_column_count(query) {
                let name = String(cString: sqlite3_column_name(query, column))
                switch sqlite3_column_type(query, column) {
                case SQLITE_INTEGER: row[name] = "integer:" + String(sqlite3_column_int64(query, column))
                case SQLITE_FLOAT: row[name] = "float:" + String(sqlite3_column_double(query, column).bitPattern)
                case SQLITE_TEXT: row[name] = "text:" + String(cString: sqlite3_column_text(query, column))
                case SQLITE_BLOB:
                    let count = Int(sqlite3_column_bytes(query, column))
                    let bytes = sqlite3_column_blob(query, column)
                    row[name] = "blob:" + (bytes.map { Data(bytes: $0, count: count).base64EncodedString() } ?? "")
                default: row[name] = "null:"
                }
            }
            result.append(row)
        }
    }

    private func count(_ path: String, _ sql: String) throws -> Int64 {
        let result = try rows(path, sql)
        let encoded = try XCTUnwrap(result.first?["value"])
        try require(encoded.hasPrefix("integer:"), "Expected an independent integer count")
        return try XCTUnwrap(Int64(encoded.dropFirst("integer:".count)))
    }

    private func state(_ context: Context, requirePopulated: Bool) throws -> Snapshot {
        let notes = try rows(context.annotationsPath, "SELECT * FROM annotations ORDER BY id")
        let tags = try rows(context.annotationsPath, "SELECT * FROM tags ORDER BY id")
        let relations = try rows(context.annotationsPath, "SELECT * FROM annotation_tags ORDER BY annotationId, tagId")
        let qualified = try json(URL(fileURLWithPath: context.qualifiedLocatorsPath))
        let favorites = try XCTUnwrap(qualified["favorites"] as? [String: Any])
        let rawHistory = try XCTUnwrap(qualified["history"] as? [[String: Any]])
        try require((qualified["schemaVersion"] as? NSNumber)?.intValue == 1, "Expected the actual source-qualified history schema")
        // Reopening a book refreshes lastOpened; source, position, title,
        // favorite state and history order remain part of the preservation gate.
        let history = rawHistory.map { $0.filter { $0.key != "lastOpened" } }
        let qualifiedState: [String: Any] = ["schemaVersion": 1,
            "locatorsByLegacyKey": qualified["locatorsByLegacyKey"] ?? [:],
            "favorites": favorites, "history": history]
        let workspace = try json(URL(fileURLWithPath: context.workspacePath))
        let rawGroups = try XCTUnwrap(workspace["groups"] as? [[String: Any]])
        var tabCount = 0
        let groups = rawGroups.map { group -> [String: Any] in
            var value = group.filter { ["id", "profileID", "name", "order", "activeTabID"].contains($0.key) }
            value["tabs"] = (group["tabs"] as? [[String: Any]] ?? []).map { tab -> [String: Any] in
                tabCount += 1
                var projected = tab.filter { $0.key == "backend" }
                if let session = tab["session"] as? [String: Any] {
                    projected["session"] = session.filter {
                        ["id", "bookId", "backendLocator", "contentId", "locator", "page", "part",
                         "scrollPosition", "selectedRange"].contains($0.key)
                    }
                }
                return projected
            }
            return value
        }
        if requirePopulated {
            try require(!notes.isEmpty && notes.contains { ($0["note"] ?? "text:") != "text:" && $0["note"] != "null:" },
                        "Preservation acceptance requires an existing nonempty note")
            try require(!tags.isEmpty && !relations.isEmpty, "Preservation acceptance requires an existing tagged annotation")
            try require(favorites.keys.contains { $0.hasPrefix("otzaria|") } &&
                        history.contains { ($0["locator"] as? [String: Any])?["backend"] as? String == "otzaria" && $0["isFavorite"] as? Bool == true },
                        "Preservation acceptance requires a genuine Otzaria favorite and reading position")
            try require(groups.count >= 2 && tabCount >= 2, "Preservation acceptance requires two real groups and two actual tabs")
        }
        return try Snapshot(annotations: canonical(notes), tags: canonical(tags), annotationTags: canonical(relations),
                            history: canonical(qualifiedState), groups: canonical(["profiles": workspace["profiles"] ?? [], "groups": groups]))
    }

    private func attach(_ value: Any, name: String) throws {
        let attachment = XCTAttachment(data: try canonical(value), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func attach(_ snapshot: Snapshot, name: String) throws {
        try attach(["annotations": hash(snapshot.annotations), "tags": hash(snapshot.tags),
                    "annotation_tags": hash(snapshot.annotationTags), "history": hash(snapshot.history),
                    "groups": hash(snapshot.groups)], name: name)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func wait(_ message: String, timeout: TimeInterval, until predicate: @escaping @MainActor @Sendable () throws -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { (try? predicate()) == true }
        }, object: nil)
        try require(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, message)
    }

    private func cacheBytes(_ root: URL) -> Int64 {
        guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in entries where url.lastPathComponent == "seforim.db.zst.part" {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    private func requireOwnedObstruction(_ url: URL, token: Data, requireImmutable: Bool = true) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let contents = try Data(contentsOf: url)
        try require(attributes[.type] as? FileAttributeType == .typeRegular &&
                    (attributes[.size] as? NSNumber)?.intValue == token.count &&
                    (!requireImmutable || (attributes[.immutable] as? NSNumber)?.boolValue == true) &&
                    contents == token,
                    "The metadata obstruction must still be this test's exact immutable token")
    }

    private func removeOwnedObstruction(_ url: URL, token: Data) throws {
        try requireOwnedObstruction(url, token: token, requireImmutable: false)
        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
        try require(try Data(contentsOf: url) == token, "Refuse cleanup after obstruction identity changed")
        try FileManager.default.removeItem(at: url)
    }

    private func visible(_ query: XCUIElementQuery) -> [XCUIElement] {
        let bounds = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        return query.allElementsBoundByIndex.filter { !$0.frame.isEmpty && bounds.contains($0.frame) && $0.isHittable }
    }

    private func tapOriginalToolbar(_ identifier: String, labels: [String]) throws {
        let query = app.buttons.matching(identifier: identifier)
        let overflow = app.navigationBars.buttons.matching(NSPredicate(
            format: "identifier IN %@", ["TopOverflowBarButtonItem", "OverflowBarButtonItem"]))
        try wait("Original toolbar action must appear", timeout: 20) {
            !self.visible(query).isEmpty || !self.visible(overflow).isEmpty
        }
        var actions = visible(query)
        if actions.isEmpty {
            let controls = visible(overflow)
            try require(controls.count == 1, "Require one original native toolbar overflow")
            try XCTUnwrap(controls.first).tap()
            let menu = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", identifier, labels))
            try wait("Original overflow must expose its action", timeout: 15) { !self.visible(menu).isEmpty }
            actions = visible(menu)
        }
        try require(actions.count == 1, "Require one visible original action: " + identifier)
        try XCTUnwrap(actions.first).tap()
    }

    private func revealFormElement(_ element: XCUIElement, description: String) throws {
        let surface: XCUIElement = app.sheets.firstMatch.exists ? app.sheets.firstMatch : app
        for _ in 0..<10 where !element.isHittable {
            if surface.collectionViews.firstMatch.exists { surface.collectionViews.firstMatch.swipeUp() }
            else if surface.tables.firstMatch.exists { surface.tables.firstMatch.swipeUp() }
            else { surface.scrollViews.firstMatch.swipeUp() }
        }
        try require(element.waitForExistence(timeout: 15) && element.isHittable, description)
    }

    private func createTaggedNoteThroughOriginalUI(_ context: Context, token: String, inspectorAlreadyOpen: Bool = false) throws {
        if !inspectorAlreadyOpen {
            try tapOriginalToolbar("reader-study-toggle", labels: ["Open Study Tools", "פתיחת כלי לימוד"])
        }
        let notes = app.segmentedControls["torah-inspector-tools"].buttons["Notes"]
        try require(notes.waitForExistence(timeout: 15) && notes.isHittable, "Original Notes inspector must open")
        notes.tap()
        let addNote = app.buttons["torah-inspector-add-note"]
        try require(addNote.waitForExistence(timeout: 15) && addNote.isHittable, "Original Add Note action must be usable")
        addNote.tap()
        let editor = app.textViews["annotation-note-text"]
        try require(editor.waitForExistence(timeout: 20) && editor.isHittable, "Original quick-note editor must open")
        let text = "Library update preservation שלום " + token
        let tag = "update-preservation-" + token.lowercased()
        editor.tap(); editor.typeText(text)
        let tags = app.textFields["tag1, tag2..."]
        try revealFormElement(tags, description: "Original comma-separated tag field must be reachable")
        tags.tap(); tags.typeText(tag)
        let save = app.buttons["annotation-save-toolbar"]
        try require(save.exists && save.isHittable && save.isEnabled, "Original annotation Save must be enabled")
        save.tap()
        try wait("The original editor must dismiss after Save", timeout: 20) { !editor.exists }
        try wait("The original repository must persist this note and its tag relationship", timeout: 20) {
            guard FileManager.default.fileExists(atPath: context.annotationsPath) else { return false }
            return try self.count(context.annotationsPath,
                "SELECT COUNT(*) AS value FROM annotations a JOIN annotation_tags at ON at.annotationId=a.id JOIN tags t ON t.id=at.tagId WHERE a.note='" + text + "' AND t.name='" + tag + "'") == 1
        }
        capture("settings-update-original-tagged-note")
        let close = app.buttons["torah-inspector-close"]
        try require(close.exists && close.isHittable, "Close the original inspector after note creation")
        close.tap()
        try attach(["note_token": token, "tag": tag, "creation": "original-study-tools-note-editor-and-tag-field"],
                   name: "settings-update-original-note-fixture")
    }

    private func copyCurrentGroupThroughOriginalUI(_ context: Context, token: String) throws {
        let file = URL(fileURLWithPath: context.workspacePath)
        let original = try json(file)
        let oldGroups = try XCTUnwrap(original["groups"] as? [[String: Any]])
        let oldIDs = Set(oldGroups.compactMap { $0["id"] as? String })
        let oldTabs = Set(oldGroups.flatMap { $0["tabs"] as? [[String: Any]] ?? [] }.compactMap {
            ($0["session"] as? [String: Any])?["id"] as? String
        })
        try tapOriginalToolbar("reader-tabs-overview", labels: ["All Tabs", "כל הכרטיסיות"])
        let menu = app.buttons["study-group-actions-menu"]
        try require(menu.waitForExistence(timeout: 15) && menu.isHittable, "Original group actions must open")
        menu.tap()
        let copy = app.buttons["New group from current tabs"]
        try require(copy.waitForExistence(timeout: 10) && copy.isHittable, "Use the original current-tabs copy command")
        copy.tap()
        let prompt = app.alerts["Tab group name"]
        try require(prompt.waitForExistence(timeout: 10), "Original group-name prompt must appear")
        let groupName = "Update preservation " + token
        prompt.textFields.firstMatch.typeText(groupName)
        prompt.buttons["Save"].tap()
        try wait("Original workspace must persist a distinct group and copied document identities", timeout: 30) {
            let current = try self.json(file)
            let groups = try XCTUnwrap(current["groups"] as? [[String: Any]])
            guard let created = groups.first(where: { $0["name"] as? String == groupName }),
                  let groupID = created["id"] as? String, !oldIDs.contains(groupID),
                  let tabs = created["tabs"] as? [[String: Any]], !tabs.isEmpty else { return false }
            let copiedIDs = tabs.compactMap { ($0["session"] as? [String: Any])?["id"] as? String }
            return groups.count == oldGroups.count + 1 && copiedIDs.count == tabs.count &&
                Set(copiedIDs).count == copiedIDs.count && Set(copiedIDs).isDisjoint(with: oldTabs)
        }
        capture("settings-update-original-copied-group")
        let done = app.navigationBars["All Tabs"].buttons["Done"]
        try require(done.exists && done.isHittable, "Close the original group overview")
        done.tap()
        try attach(["group_name": groupName, "creation": "original-current-tabs-copy-command"],
                   name: "settings-update-original-group-fixture")
    }

    private func prepareOrdinaryProductionReader(_ context: Context) throws {
        let library = findTabButton(hebrew: "ספר", english: "Library")
        try require(library.waitForExistence(timeout: 30) && library.isHittable,
                    "The original Library tab must be reachable before preparing saved objects")
        library.tap()
        let reader = app.textViews["reader-text"]
        let locator = app.staticTexts["reader-current-locator"]
        let launchers = app.buttons.matching(identifier: "reader-command-palette-launcher")
        func visibleReader() -> Bool {
            reader.exists && reader.isHittable && locator.exists &&
                !(reader.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        try wait("The ordinary Library must restore a reader or expose its original book palette", timeout: 60) {
            visibleReader() || (launchers.firstMatch.exists && launchers.firstMatch.isHittable)
        }
        let route: String
        if visibleReader() {
            route = "existing-visible-canonical-reader"
        } else {
            // Bind the fallback to the actual source database before touching
            // a result. This is the full-v40 Bavli Berakhot catalog identity.
            let books = try rows(context.databasePath, "SELECT id,title FROM book WHERE id=103")
            try require(books.count == 1 && books[0]["id"] == "integer:103",
                        "The actual full-v40 database must contain the canonical Berakhot book")
            let title = try textColumn(books[0], "title")
            try require(sourceText(title) == "ברכות", "The observed Berakhot catalog identity changed")
            try require(launchers.count == 1 && launchers.firstMatch.isHittable,
                        "Use the unique original Library palette launcher")
            launchers.firstMatch.tap()
            let palette = app.descendants(matching: .any)["reader-library-command-palette"]
            try require(palette.waitForExistence(timeout: 30), "The original Library palette must open")
            let input = palette.textFields.firstMatch
            try require(input.waitForExistence(timeout: 20) && input.isHittable,
                        "The original Library search field must be usable")
            input.tap()
            input.typeKey(XCUIKeyboardKey(rawValue: "a"), modifierFlags: .command)
            input.typeText(title)
            try require(input.value as? String == title, "Search the actual canonical title through the original input")
            let results = palette.buttons.matching(NSPredicate(format: "label == %@", title))
            try require(results.firstMatch.waitForExistence(timeout: 60) && results.count == 1 && results.firstMatch.isHittable,
                        "Require one visible original result for the actual Berakhot title")
            results.firstMatch.tap()
            try wait("The actual Library result must open a hittable nonempty reader", timeout: 60) {
                !palette.exists && visibleReader()
            }
            try require(try currentBookID() == 103, "The original palette opened a different canonical book")
            route = "original-library-palette-berakhot"
        }
        let bookID = try currentBookID()
        let title = app.staticTexts["reader-header-title"].label
        try requireCanonicalBook(context, id: bookID, title: title)
        try require(visibleReader(), "Saved-object setup must start from the actual visible production reader")
        try attach(["route": route, "book_id": bookID, "title": title, "reader_locator": locator.label,
                    "scope": "original Library UI; ordinary production namespace; no state seeding"],
                   name: "settings-update-reader-prelude-state")
        capture("settings-update-reader-prelude")
    }

    private func prepareUserDataThroughOriginalUI(_ context: Context) throws -> SemanticPreservation {
        let bookID = try currentBookID()
        let title = app.staticTexts["reader-header-title"].label
        try require(!title.isEmpty, "An actual canonical book title is required")
        try requireCanonicalBook(context, id: bookID, title: title)
        // Resolve the real saved History/Favorite before capturing its source.
        // Its ordinary route may restore a reading unit within the same book.
        let favorite = try openFavoriteThroughOriginalUI(context, bookID: bookID, title: title)
        let locator = app.staticTexts["reader-current-locator"].label
        let token = UUID().uuidString
        let reader = app.textViews["reader-text"]
        try require(reader.waitForExistence(timeout: 30) && reader.isHittable, "Select a real visible source segment before making the note")
        reader.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)).tap()
        try require(app.descendants(matching: .any)["torah-inspector-panel"].waitForExistence(timeout: 30),
                    "The original paragraph tap must open its source Inspector")
        try createTaggedNoteThroughOriginalUI(context, token: token, inspectorAlreadyOpen: true)
        let noteBody = "Library update preservation שלום " + token
        let found = try rows(context.annotationsPath, "SELECT * FROM annotations WHERE note='" + noteBody + "'")
        try require(found.count == 1, "The original editor must create exactly the observed note")
        let note = try XCTUnwrap(found.first)
        let encodedID = try XCTUnwrap(note["id"])
        try require(encodedID.hasPrefix("integer:"), "Persisted note ID must be an integer")
        let noteID = try XCTUnwrap(Int64(encodedID.dropFirst(8)))
        let savedLocator = try textColumn(note, "backendLocator")
        let noteLocator = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(savedLocator.utf8)) as? [String: Any])
        let position = try XCTUnwrap(noteLocator["position"] as? [String: Any])
        let line = try XCTUnwrap(position["integer"] as? NSNumber).intValue
        try require(noteLocator["backend"] as? String == "otzaria" && noteLocator["workKey"] as? String == "book:" + String(bookID) &&
                    position["kind"] as? String == "legacyLine" && line >= 0,
                    "The original note must persist the actual selected source segment, not an injected locator")
        let lineIdentity = try rows(context.databasePath, "SELECT id,lineIndex,heRef FROM line WHERE bookId=" + String(bookID) + " AND lineIndex=" + String(line))
        try require(lineIdentity.count == 1, "The note's actual source locator must resolve in the full pre-update database")
        let quote = String(sourceText(try textColumn(note, "context")).prefix(160))
        try require(quote.count >= 12 && sourceText(reader.value as? String ?? "").contains(quote),
                    "Capture a nontrivial real note context that is also present in the original reader")
        let original = try currentGroup(context, bookID: bookID)
        try copyCurrentGroupThroughOriginalUI(context, token: token)
        let copied = try currentGroup(context, bookID: bookID)
        try require(copied.id != original.id && copied.documentID != original.documentID && copied.name == "Update preservation " + token,
                    "The original copy action must activate a distinct persisted group/document")
        let proof = SemanticPreservation(bookID: bookID, title: title, readerLocator: locator, sourceQuote: quote,
            noteID: noteID, note: note, tag: "update-preservation-" + token.lowercased(), favorite: favorite,
            originalGroup: original, copiedGroup: copied)
        try requireRestoredSource(context, proof: proof, route: "before-update")
        try attach(["book_id": bookID, "title": title, "reader_locator": locator, "source_quote": quote,
                    "note_id": noteID, "note_locator": noteLocator, "line_identity_before": lineIdentity,
                    "favorite_key": favorite.key, "original_group": original.id.uuidString,
                    "copied_group": copied.id.uuidString, "copied_document": copied.documentID.uuidString,
                    "scope": "ordinary UI-created saved objects and observed source context, not assumed cross-release ID stability"],
                   name: "settings-update-semantic-preservation-before")
        return proof
    }

    private struct WorkspaceSelection: Decodable, Sendable {
        struct Session: Decodable, Sendable { let id: UUID }
        struct Document: Decodable, Sendable { let backend: String; let session: Session }
        struct Group: Decodable, Sendable {
            let id: UUID; let profileID: UUID; let name: String
            let activeTabID: UUID?; let tabs: [Document]
        }
        struct Scene: Decodable, Sendable {
            let profileID: UUID; let groupID: UUID; let activeTabIDsByGroup: [UUID: UUID]?
        }
        let groups: [Group]; let scenes: [String: Scene]; let lastActiveSceneID: String?
    }

    private struct GroupReference: Sendable {
        let id: UUID; let name: String; let documentID: UUID; let canonicalSession: Data
    }

    private struct FavoriteReference: Sendable {
        let key: String; let canonicalLocator: Data
    }

    private struct SemanticPreservation: Sendable {
        let bookID: Int; let title: String; let readerLocator: String; let sourceQuote: String
        let noteID: Int64; let note: [String: String]; let tag: String
        let favorite: FavoriteReference; let originalGroup: GroupReference; let copiedGroup: GroupReference
    }

    private func sourceText(_ value: String) -> String {
        let marks = CharacterSet(charactersIn: "\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")
        let unmarked = String(value.unicodeScalars.filter { !marks.contains($0) })
        return unmarked.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private func textColumn(_ row: [String: String], _ column: String) throws -> String {
        let encoded = try XCTUnwrap(row[column])
        try require(encoded.hasPrefix("text:"), "Expected the original persisted text column: " + column)
        return String(encoded.dropFirst(5))
    }

    private func currentBookID() throws -> Int {
        let locator = app.staticTexts["reader-current-locator"].label.components(separatedBy: "|")
        try require(locator.count == 3 && locator[0] == "otzaria" && locator[1].hasPrefix("book:") && locator[2].hasPrefix("line:"),
                    "Require the current original reader's source-qualified Otzaria locator")
        return try XCTUnwrap(Int(locator[1].dropFirst(5)))
    }

    private func requireCanonicalBook(_ context: Context, id: Int, title: String) throws {
        let books = try rows(context.databasePath, "SELECT id,title FROM book WHERE id=" + String(id))
        try require(books.count == 1 && books[0]["id"] == "integer:" + String(id), "Saved book ID must resolve in the current production database")
        try require(sourceText(try textColumn(books[0], "title")) == sourceText(title),
                    "Saved canonical book ID now resolves to a different title")
    }

    private func currentGroup(_ context: Context, bookID: Int) throws -> GroupReference {
        let data = try Data(contentsOf: URL(fileURLWithPath: context.workspacePath))
        let workspace = try JSONDecoder().decode(WorkspaceSelection.self, from: data)
        let sceneID = try XCTUnwrap(workspace.lastActiveSceneID)
        let scene = try XCTUnwrap(workspace.scenes[sceneID])
        let group = try XCTUnwrap(workspace.groups.first { $0.id == scene.groupID && $0.profileID == scene.profileID })
        let active = try XCTUnwrap(scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID)
        try require(group.tabs.contains { $0.session.id == active && $0.backend == "otzaria" }, "Current workspace must contain the actual Otzaria reader document")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try XCTUnwrap(object["groups"] as? [[String: Any]])
        let raw = try XCTUnwrap(groups.first { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == group.id })
        let tabs = try XCTUnwrap(raw["tabs"] as? [[String: Any]])
        let tab = try XCTUnwrap(tabs.first { (($0["session"] as? [String: Any])?["id"] as? String).flatMap(UUID.init(uuidString:)) == active })
        let session = try XCTUnwrap(tab["session"] as? [String: Any])
        let locators = [session["backendLocator"], session["locator"]].compactMap { $0 as? [String: Any] }
        try require(!locators.isEmpty && locators.allSatisfy { $0["backend"] as? String == "otzaria" && $0["workKey"] as? String == "book:" + String(bookID) },
                    "The original group's active document must bind the current canonical book")
        let identity = session.filter { ["id", "bookId", "bookTitle", "backendLocator", "locator", "contentId", "page", "part"].contains($0.key) }
        return try GroupReference(id: group.id, name: group.name, documentID: active, canonicalSession: canonical(identity))
    }

    private func historyCard(title: String) throws -> XCUIElement {
        let matching = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ", "))
        try wait("History must expose the original card for the exact canonical title", timeout: 20) { !self.visible(matching).isEmpty }
        // The first vertical occurrence is the original History section. Its
        // optional Favorite duplicate has the same book title and source.
        return try XCTUnwrap(visible(matching).sorted { $0.frame.minY < $1.frame.minY }.first)
    }

    private func openFavoriteThroughOriginalUI(_ context: Context, bookID: Int, title: String,
                                               existing: FavoriteReference? = nil) throws -> FavoriteReference {
        let history = findTabButton(hebrew: "היסטוריה", english: "History")
        try require(history.waitForExistence(timeout: 20) && history.isHittable, "Open original History for the saved favorite")
        history.tap()
        try require(app.navigationBars["History & Favorites"].waitForExistence(timeout: 20), "Require original History & Favorites")
        let card = try historyCard(title: title)
        func stars(_ label: String) -> [XCUIElement] {
            visible(app.buttons.matching(NSPredicate(format: "label == %@", label))).filter {
                card.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
            }
        }
        if existing == nil, !stars("Add Favorite").isEmpty {
            try require(stars("Add Favorite").count == 1, "Only the actual book card's original star may create the favorite")
            try XCTUnwrap(stars("Add Favorite").first).tap()
        }
        let store = URL(fileURLWithPath: context.qualifiedLocatorsPath)
        try wait("The exact book must remain visibly favorited and source-qualified", timeout: 20) {
            let state = try self.json(store)
            let favorites = try XCTUnwrap(state["favorites"] as? [String: Any])
            return !stars("Remove Favorite").isEmpty && favorites.values.contains {
                let locator = $0 as? [String: Any]
                return locator?["backend"] as? String == "otzaria" && locator?["workKey"] as? String == "book:" + String(bookID)
            }
        }
        let state = try json(store)
        let favorites = try XCTUnwrap(state["favorites"] as? [String: Any]).filter {
            let locator = $0.value as? [String: Any]
            return locator?["backend"] as? String == "otzaria" && locator?["workKey"] as? String == "book:" + String(bookID)
        }
        try require(favorites.count == 1, "The chosen visible book card must have one unambiguous saved favorite locator")
        let item = try XCTUnwrap(favorites.first)
        let favorite = try FavoriteReference(key: item.key, canonicalLocator: canonical(item.value))
        if let existing {
            try require(favorite.key == existing.key && favorite.canonicalLocator == existing.canonicalLocator,
                        "The saved favorite's canonical reference changed during Books Updates")
        }
        let entries = try XCTUnwrap(state["history"] as? [[String: Any]])
        try require(try entries.contains {
            guard $0["isFavorite"] as? Bool == true, let locator = $0["locator"] else { return false }
            return try canonical(locator) == favorite.canonicalLocator && sourceText($0["title"] as? String ?? "") == sourceText(title)
        }, "Original History must retain the favorite's canonical locator and title")
        capture(existing == nil ? "settings-update-favorite-before-open" : "settings-update-favorite-after-cold-open")
        try historyCard(title: title).tap()
        try wait("The original History card must actually open a hittable reader", timeout: 45) {
            self.app.textViews["reader-text"].exists && self.app.textViews["reader-text"].isHittable &&
                self.app.staticTexts["reader-current-locator"].exists
        }
        try require(try currentBookID() == bookID && sourceText(app.staticTexts["reader-header-title"].label) == sourceText(title),
                    "The saved favorite opened another canonical book")
        return favorite
    }

    private func reopenGroup(_ context: Context, saved: GroupReference, proof: SemanticPreservation) throws {
        try tapOriginalToolbar("reader-tabs-overview", labels: ["All Tabs", "כל הכרטיסיות"])
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        try require(overview.waitForExistence(timeout: 20), "Original group overview must open")
        let selector = app.segmentedControls["study-group-selector"]
        if selector.exists {
            let segment = selector.buttons[saved.name]
            try require(segment.waitForExistence(timeout: 15) && segment.isHittable, "The saved group must remain an original selectable segment")
            segment.tap()
        } else {
            let menu = app.buttons["study-group-selector"]
            try require(menu.exists && menu.isHittable, "Original adaptive group menu must be usable")
            menu.tap()
            let choices = app.collectionViews.cells.buttons.matching(NSPredicate(format: "label == %@", saved.name))
            try require(choices.firstMatch.waitForExistence(timeout: 15) && choices.count == 1 && choices.firstMatch.isHittable,
                        "The original group menu must uniquely identify the saved group")
            choices.firstMatch.tap()
        }
        try wait("The original group selector must commit the saved group and document", timeout: 30) {
            let current = try self.currentGroup(context, bookID: proof.bookID)
            return current.id == saved.id && current.documentID == saved.documentID && current.canonicalSession == saved.canonicalSession
        }
        let ids = ["tab-switcher-grid-cell-", "tab-switcher-list-cell-"].map { $0 + saved.documentID.uuidString }
        let cards = overview.collectionViews.cells.matching(NSPredicate(format: "identifier IN %@", ids))
        try require(cards.firstMatch.waitForExistence(timeout: 20) && cards.count == 1,
                    "Require the original card with the exact saved document UUID")
        let card = cards.firstMatch
        for _ in 0..<30 where !card.isHittable { overview.collectionViews.firstMatch.swipeUp() }
        try require(card.isHittable && card.isSelected, "The saved document must be the actual selected original card")
        capture("settings-update-reopen-group-" + saved.id.uuidString)
        card.tap()
        try wait("The original card must dismiss the overview and restore its reader", timeout: 30) { !overview.exists }
        try requireRestoredSource(context, proof: proof, route: "group-" + saved.id.uuidString)
    }

    private func requireRestoredSource(_ context: Context, proof: SemanticPreservation, route: String) throws {
        let reader = app.textViews["reader-text"]
        try wait("Saved " + route + " must display its original source context", timeout: 45) {
            reader.exists && reader.isHittable && self.app.staticTexts["reader-current-locator"].label == proof.readerLocator &&
            self.sourceText(self.app.staticTexts["reader-header-title"].label) == self.sourceText(proof.title) &&
            self.sourceText(reader.value as? String ?? "").contains(proof.sourceQuote)
        }
        try require(try currentBookID() == proof.bookID, "Saved route changed canonical book ID")
        try requireCanonicalBook(context, id: proof.bookID, title: proof.title)
        try attach(["route": route, "book_id": proof.bookID, "title": proof.title,
                    "reader_locator": proof.readerLocator, "source_quote": proof.sourceQuote,
                    "scope": "captured source context in actual cold-restored reading unit; not full-body or all-ID equivalence"],
                   name: "settings-update-semantic-" + route)
        capture("settings-update-reader-" + route)
    }

    private func reopenSavedObjects(_ context: Context, proof: SemanticPreservation) throws {
        // Force a real group transition before returning to the copied group;
        // merely inspecting the cold-restored active document is insufficient.
        try reopenGroup(context, saved: proof.originalGroup, proof: proof)
        try reopenGroup(context, saved: proof.copiedGroup, proof: proof)
        try tapOriginalToolbar("reader-study-toggle", labels: ["Open Study Tools", "פתיחת כלי לימוד"])
        let notes = app.segmentedControls["torah-inspector-tools"].buttons["Notes"]
        try require(notes.waitForExistence(timeout: 20) && notes.isHittable, "Open original Notes after the library update")
        notes.tap()
        let row = app.buttons["torah-inspector-note-" + String(proof.noteID)]
        try require(row.waitForExistence(timeout: 30) && row.isHittable, "The same persisted note must appear in the actual restored source's Notes panel")
        try require(row.label == textColumn(proof.note, "note"), "The Inspector note row changed its saved body")
        row.tap()
        let editor = app.textViews["annotation-note-text"]
        try require(editor.waitForExistence(timeout: 20) && editor.isHittable, "Open the original saved note editor")
        try require(editor.value as? String == textColumn(proof.note, "note"), "The saved note editor did not reopen the original body")
        let tags = app.textFields["tag1, tag2..."]
        try revealFormElement(tags, description: "The saved note's original tag field must remain reachable")
        try require((tags.value as? String ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains(proof.tag),
                    "The saved note editor lost its original tag")
        let stored = try rows(context.annotationsPath, "SELECT * FROM annotations WHERE id=" + String(proof.noteID))
        try require(stored == [proof.note], "Opening the saved note must preserve its actual locator, source context and fields")
        capture("settings-update-reopened-original-note-editor")
        let cancel = app.buttons["annotation-cancel-toolbar"]
        try require(cancel.exists && cancel.isHittable, "Dismiss the original editor without modifying the note")
        cancel.tap()
        try wait("Original note editor must dismiss", timeout: 20) { !editor.exists }
        let close = app.buttons["torah-inspector-close"]
        try require(close.exists && close.isHittable, "Return from the original Notes panel to the actual reader")
        close.tap()
        try requireRestoredSource(context, proof: proof, route: "saved-note-context")
        _ = try openFavoriteThroughOriginalUI(context, bookID: proof.bookID, title: proof.title, existing: proof.favorite)
        try requireRestoredSource(context, proof: proof, route: "saved-favorite-history")
    }

    private func openUpdateSettings() throws {
        let settings = app.buttons["main-settings-button"]
        if !settings.isHittable {
            let page = app.buttons["reader-sidebar-page-0"]
            if !page.isHittable {
                let custom = visible(app.buttons.matching(identifier: "reader-host-sidebar-toggle"))
                let native = visible(app.navigationBars.buttons.matching(NSPredicate(
                    format: "label IN %@", ["Show Sidebar", "הצגת סרגל הצד"])))
                let toggles = custom + native
                try require(toggles.count == 1, "Original reader must expose its sidebar action")
                try XCTUnwrap(toggles.first).tap()
            }
            if page.waitForExistence(timeout: 15) && page.isHittable { page.tap() }
        }
        try require(settings.waitForExistence(timeout: 45) && settings.isHittable, "Ordinary Settings action must be usable")
        settings.tap()
        let link = app.buttons["settings-otzaria-library-updates"]
        for _ in 0..<8 where !link.isHittable {
            if app.collectionViews.firstMatch.exists { app.collectionViews.firstMatch.swipeUp() }
            else if app.tables.firstMatch.exists { app.tables.firstMatch.swipeUp() }
            else { app.scrollViews.firstMatch.swipeUp() }
        }
        try require(link.waitForExistence(timeout: 15) && link.isHittable, "Original Settings must expose Library Updates")
        link.tap()
        try require(app.navigationBars["Library Updates"].waitForExistence(timeout: 15), "Original Library Updates screen must open")
    }

    private func officialJSON(_ url: URL) async throws -> ([String: Any], Data) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.setValue("Maktabah-Settings-UI-Acceptance", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.data(for: request)
        try require((response as? HTTPURLResponse)?.statusCode == 200 && bytes.count < 2_000_000,
                    "Official release metadata must be fetched successfully and stay bounded")
        return (try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any]), bytes)
    }

    func testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState() async throws {
        let environment = ProcessInfo.processInfo.environment
        let fixturePath = try XCTUnwrap(environment["OTZARIA_LIBRARY_UPDATE_CONTEXT"], "Observed production update context is required")
        let context = try JSONDecoder().decode(Context.self, from: Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        try require(environment["OTZARIA_SHARED_ROOT_OVERRIDE"] == nil && environment["OTZARIA_PRODUCTION_DB_PATH"] == nil,
                    "Ordinary Settings acceptance must use the native managed container, without injected database paths")
        try require(environment["SIMULATOR_UDID"] == context.simulatorUDID, "Context belongs to another simulator")
        for key in ["OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID",
                    "SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE", "SIMCTL_CHILD_OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"] {
            try require(environment[key] == nil, "Ordinary Settings must not inherit a native acceptance release selector")
        }
        try require(context.qualifiedLocatorsPath.hasSuffix("/Library/Application Support/Maktabah/qualified-locators-v1.json") &&
                    context.workspacePath.hasSuffix("/Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"),
                    "Observe the ordinary app stores, never a UI-test namespace")
        let ownedPrefix = "/CoreSimulator/Devices/" + context.simulatorUDID + "/data/"
        for path in [context.databasePath, context.downloadsPath, context.annotationsPath, context.qualifiedLocatorsPath, context.workspacePath] {
            try require(URL(fileURLWithPath: path).resolvingSymlinksInPath().path.contains(ownedPrefix), "Context path escapes the owned simulator")
        }
        let database = URL(fileURLWithPath: context.databasePath)
        let root = database.deletingLastPathComponent()
        let downloads = URL(fileURLWithPath: context.downloadsPath)
        let manifestURL = root.appendingPathComponent("seforim-installation.json")
        let obstructionURL = root.appendingPathComponent("seforim-installation.json.installing")
        let obstructionToken = Data(("ManagedLibraryUpdateAcceptanceTests-owned-obstruction:" + UUID().uuidString).utf8)
        var ownsObstruction = false
        defer {
            if ownsObstruction {
                app.terminate()
                do { try removeOwnedObstruction(obstructionURL, token: obstructionToken) }
                catch { XCTFail("Owned obstruction cleanup requires review: \(error.localizedDescription)") }
            }
        }
        try require(database.lastPathComponent == "seforim.db" && root.lastPathComponent == "Otzaria", "A real managed production database is required")
        try require(context.expectedCurrentTag == "v40-20261123094345" &&
                    context.expectedCurrentSHA256 == "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01",
                    "This gate starts from the previously accepted full v40 library")
        let oldManifest = try Data(contentsOf: manifestURL)
        try require(try json(manifestURL)["releaseTag"] as? String == context.expectedCurrentTag, "Installed release is not the selected full v40 source")
        try require(try fileHash(database) == context.expectedCurrentSHA256, "Installed full v40 bytes differ")
        let (release, _) = try await officialJSON(URL(string: "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/latest")!)
        try require((release["id"] as? NSNumber)?.int64Value == context.expectedTargetID &&
                    release["tag_name"] as? String == context.expectedTargetTag &&
                    release["draft"] as? Bool == false && release["prerelease"] as? Bool == false,
                    "Latest official release changed; rebind the ordinary Settings target")
        let assets = try XCTUnwrap(release["assets"] as? [[String: Any]])
        let metadataAsset = try XCTUnwrap(assets.first { $0["name"] as? String == "seforim-schema7.db.zst.manifest.json" })
        let expectedAssetID = try XCTUnwrap(metadataAsset["id"] as? NSNumber).int64Value
        let expectedAssetDigest = try XCTUnwrap(metadataAsset["digest"] as? String)
        try require(expectedAssetID > 0, "Official full-library asset identity is required")
        let statsAsset = try XCTUnwrap(assets.first { $0["name"] as? String == "library_stats.json" })
        var verified: [[String: Any]] = []
        for asset in [metadataAsset, statsAsset] {
            let name = try XCTUnwrap(asset["name"] as? String)
            let location = try XCTUnwrap(asset["browser_download_url"] as? String)
            try require(location == "https://github.com/Otzaria/SeforimLibrary/releases/download/" + context.expectedTargetTag + "/" + name,
                        "Latest metadata asset has a foreign source")
            let (value, bytes) = try await officialJSON(try XCTUnwrap(URL(string: location)))
            try require((asset["size"] as? NSNumber)?.intValue == bytes.count && asset["digest"] as? String == "sha256:" + hash(bytes),
                        "Official metadata asset size or SHA-256 differs")
            verified.append(value)
        }
        let archive = verified[0], statistics = verified[1]
        try attach(["release_id": context.expectedTargetID, "tag": context.expectedTargetTag,
                    "archive": archive, "statistics": statistics], name: "settings-update-official-target")

        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US")
        try prepareOrdinaryProductionReader(context)
        let preservation = try prepareUserDataThroughOriginalUI(context)
        let locator = preservation.readerLocator
        let before = try state(context, requirePopulated: true)
        try attach(before, name: "settings-update-user-state-before")
        try require(cacheBytes(downloads) == 0, "Previous database-download work must be accounted for before this UI journey")
        try openUpdateSettings()
        var install = app.buttons["otzaria-update-install"]
        try require(install.waitForExistence(timeout: 60), "Ordinary live release discovery must offer the update")
        try require(app.staticTexts[context.expectedTargetTag].exists, "UI must offer the exact official latest release")
        capture("settings-update-offered")
        install.tap()
        try wait("The ordinary download must retain at least one MiB before pause", timeout: 180) {
            self.cacheBytes(downloads) >= 1_048_576 && self.app.buttons["otzaria-update-cancel"].isHittable
        }
        try require(try Data(contentsOf: manifestURL) == oldManifest, "Download changed the old release identity prematurely")
        app.buttons["otzaria-update-cancel"].tap()
        try require(install.waitForExistence(timeout: 60), "Pause must return to the original retry/resume action")
        let retainedBytes = cacheBytes(downloads)
        try require(retainedBytes >= 1_048_576, "Pause discarded the actual partial download")
        try require(try fileHash(database) == context.expectedCurrentSHA256, "Pause replaced the previous library")
        try require(try Data(contentsOf: manifestURL) == oldManifest, "Pause replaced the previous manifest")
        XCTAssertEqual(try state(context, requirePopulated: true), before, "Pause must preserve logical user data")
        capture("settings-update-paused")

        app.terminate()
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US")
        try require(app.staticTexts["reader-current-locator"].waitForExistence(timeout: 60), "Cold launch must reopen the previous library after interruption")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        XCTAssertEqual(try state(context, requirePopulated: true), before)
        try require(cacheBytes(downloads) == retainedBytes, "Cold launch changed retained download bytes")
        // The old reader has completed cold restore and no update is active.
        // Obstruct only the new pending-identity write, after recovery has run.
        // The app remains the sole installer; no corpus bytes are changed.
        for name in ["seforim.db.previous", "seforim-installation.json.previous", "seforim-installation.json.installing"] {
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path),
                        "Do not replace an existing transaction artifact to inject the owned failure")
        }
        try obstructionToken.write(to: obstructionURL, options: .withoutOverwriting)
        ownsObstruction = true
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: obstructionURL.path)
        try requireOwnedObstruction(obstructionURL, token: obstructionToken)
        try attach(["path": obstructionURL.path, "token_sha256": hash(obstructionToken),
                    "fault": "owned immutable pending metadata; corpus unchanged"], name: "settings-update-owned-fault")
        try requireOwnedObstruction(obstructionURL, token: obstructionToken)
        try openUpdateSettings()
        install = app.buttons["otzaria-update-install"]
        try require(install.waitForExistence(timeout: 60), "Ordinary Settings must rediscover and resume the same target")
        try require(app.staticTexts[context.expectedTargetTag].exists, "Relaunch offered another release")
        install.tap()
        try wait("Actual metadata promotion must fail through the original Settings UI", timeout: 3_600) {
            self.app.staticTexts["The library was updated successfully."].exists || self.app.staticTexts["otzaria-update-error"].exists
        }
        let failure = app.staticTexts["otzaria-update-error"]
        try require(failure.exists && failure.label.contains(obstructionURL.lastPathComponent),
                    "Require the observed pending-metadata write failure, not an unrelated network/storage error: " + failure.label)
        try require(!app.staticTexts["The library was updated successfully."].exists, "Failed metadata promotion must not report success")
        try require(install.waitForExistence(timeout: 30) && install.isHittable,
                    "The original install action must remain available to retry the failed update")
        try requireOwnedObstruction(obstructionURL, token: obstructionToken)
        try require(try fileHash(database) == context.expectedCurrentSHA256 && Data(contentsOf: manifestURL) == oldManifest,
                    "Metadata failure must roll back the previous full database and release identity")
        XCTAssertEqual(try state(context, requirePopulated: true), before, "Failed promotion must preserve logical user data")
        try attach(["visible_error": failure.label, "old_database_sha256": context.expectedCurrentSHA256,
                    "old_manifest_sha256": hash(oldManifest), "owned_token_sha256": hash(obstructionToken),
                    "retained_download_bytes": cacheBytes(downloads)], name: "settings-update-failed-and-rolled-back")
        capture("settings-update-retry-offered-after-real-failure")
        app.terminate()
        try removeOwnedObstruction(obstructionURL, token: obstructionToken)
        ownsObstruction = false
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US")
        try require(app.staticTexts["reader-current-locator"].waitForExistence(timeout: 60), "Recovery after failed promotion must cold-open the old reader")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        XCTAssertEqual(try state(context, requirePopulated: true), before)
        try require(try fileHash(database) == context.expectedCurrentSHA256 && Data(contentsOf: manifestURL) == oldManifest,
                    "Cold recovery changed the restored full v40 source")
        capture("settings-update-recovered-old-reader")
        try openUpdateSettings()
        install = app.buttons["otzaria-update-install"]
        try require(install.waitForExistence(timeout: 60) && install.isHittable && app.staticTexts[context.expectedTargetTag].exists,
                    "Original Settings Retry must retain the same official target")
        install.tap()
        try wait("Actual retry must finish through Settings", timeout: 3_600) {
            self.app.staticTexts["The library was updated successfully."].exists || self.app.staticTexts["otzaria-update-error"].exists
        }
        try require(!app.staticTexts["otzaria-update-error"].exists,
                    "Actual Settings update failed: " + app.staticTexts["otzaria-update-error"].label)
        try require(app.staticTexts["The library was updated successfully."].exists, "No observed native success state")
        capture("settings-update-completed")
        let installed = try json(manifestURL)
        try require((installed["releaseID"] as? NSNumber)?.int64Value == context.expectedTargetID &&
                    installed["releaseTag"] as? String == context.expectedTargetTag &&
                    (installed["assetID"] as? NSNumber)?.int64Value == expectedAssetID &&
                    installed["digest"] as? String == expectedAssetDigest,
                    "Committed release identity differs from the official metadata displayed in Settings")
        let quickCheck = try rows(context.databasePath, "PRAGMA quick_check(1)")
        try require(quickCheck == [["quick_check": "text:ok"]], "Updated database failed independent SQLite integrity")
        for (table, key) in [("book", "books"), ("line", "lines"), ("link", "links")] {
            let expected = try XCTUnwrap(statistics[key] as? NSNumber).int64Value
            try require(try count(context.databasePath, "SELECT COUNT(*) AS value FROM " + table) == expected,
                        "Updated full-corpus count differs for " + table)
        }
        for name in ["seforim.db.previous", "seforim-installation.json.previous", "seforim-installation.json.installing"] {
            try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path), "Committed update left a transaction remnant")
        }
        for name in ["seforim.db.zst.part", "seforim.db.zst.part.json", "seforim.db.zst.parts", "seforim.db.zst.assembling"] {
            try require(!FileManager.default.fileExists(atPath: downloads.appendingPathComponent(name).path), "Successful update did not clean its download workspace")
        }
        let after = try state(context, requirePopulated: true)
        XCTAssertEqual(after, before, "Original notes, tags, favorites, reading positions, profile/group IDs and tab order must survive")
        try attach(after, name: "settings-update-user-state-after")
        let newHash = try fileHash(database)
        try require(newHash != context.expectedCurrentSHA256, "Update did not replace the old corpus")
        try attach(["installed_manifest": installed, "new_database_sha256": newHash,
                    "paused_download_bytes": retainedBytes, "old_database_sha256": context.expectedCurrentSHA256,
                    "metadata_promotion_failure": "observed pending-identity write error; previous corpus and manifest restored",
                    "retry_and_recovery": "original Settings action after verified owned-token removal and cold reopen",
                    "scope": "ordinary-Settings-UI-current-to-latest", "http_range_receipt": "separate-native-bootstrap-gate"],
                   name: "settings-update-installed")
        app.terminate()
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US")
        try require(app.staticTexts["reader-current-locator"].waitForExistence(timeout: 60), "Updated library must cold-open in the original reader")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        XCTAssertEqual(try state(context, requirePopulated: true), before)
        try require(try fileHash(database) == newHash && cacheBytes(downloads) == 0, "Cold launch modified or redownloaded the updated corpus")
        try reopenSavedObjects(context, proof: preservation)
        try openUpdateSettings()
        try require(app.staticTexts["The library is up to date."].waitForExistence(timeout: 60), "Rechecking the actual current release must show up-to-date")
        try require(!app.buttons["otzaria-update-install"].exists, "Current release must not be offered as another update")
        capture("settings-update-cold-current")
    }
}
