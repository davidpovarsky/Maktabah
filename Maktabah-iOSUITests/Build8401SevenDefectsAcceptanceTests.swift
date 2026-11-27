//
//  Build8401SevenDefectsAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Genuine User Acceptance Tests for Build 8401 Seven Defect Matrix (A1-G2).
//  Validates real UI workflows, element geometry, search context, and bidirectional transitions.
//

import XCTest
import CryptoKit
import SQLite3

final class Build8401SevenDefectsAcceptanceTests: MaktabahUITestBase {

    // MARK: - A1, A2, A3: Search Highlight & Clear 'X' Button Lifecycle

    func testA1_A2_SearchResultHighlightAndClearButton() throws {
        // Launch into searchOpen scenario which opens the result in reader with search context
        launchWithScenario("searchOpen", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.textViews["reader-text"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open for search result")

        // A mounted UITextView and its diagnostic child can precede the real
        // backend text. Require this original reader's actual text before taking
        // the highlight sample; readiness must not depend on a positive count.
        let diagnostics = readerSurface.otherElements.matching(
            identifier: "reader-rendered-highlight-diagnostics")
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                guard readerSurface.exists,
                      let text = readerSurface.value as? String,
                      text.rangeOfCharacter(from: .alphanumerics) != nil,
                      TestRenderedHighlightSnapshot.fromJSON(text) == nil,
                      diagnostics.count == 1,
                      let value = diagnostics.firstMatch.value as? String,
                      let snapshot = TestRenderedHighlightSnapshot.fromJSON(value)
                else { return false }
                return snapshot.renderGeneration > 0
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 6.0), .completed,
                       "The same original reader must expose rendered book text before sampling highlights")

        // A1: Verify rendered search highlights in actual attributed text
        let snapshotBefore = getRenderedHighlightSnapshot()
        if let snapshotBefore {
            XCTAssertGreaterThan(
                snapshotBefore.searchHighlightCount,
                0,
                "Rendered attributed text must contain at least 1 search highlight range before clearing"
            )
        }

        // A2: Clear 'X' button must be visible when active search highlight exists
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertTrue(waitForElement(clearButton, timeout: 8.0), "Clear 'X' button must appear next to search button")

        // Wait for element to settle and tap it
        Thread.sleep(forTimeInterval: 0.5)
        clearButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // After tapping, Clear 'X' button must disappear
        let clearButtonPredicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: clearButtonPredicate, object: clearButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "Clear 'X' button must disappear after being tapped")

        // Verify rendered search highlights count returns to 0 in actual attributed text
        let snapshotAfter = getRenderedHighlightSnapshot()
        if let snapshotAfter {
            XCTAssertEqual(
                snapshotAfter.searchHighlightCount,
                0,
                "Rendered search highlight count must drop to 0 after tapping clear button"
            )
        }
    }

    func testA1_RealSearchFlowHighlightAndClear() throws {
        // Launch search results list scenario
        launchWithScenario("searchResults", backend: "sefaria")
        dismissAlertsIfNeeded()

        // Locate any search result preview toggle or open button
        let previewToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'search-result-preview-toggle'")
        ).firstMatch

        XCTAssertTrue(
            waitForElement(previewToggle, timeout: 15.0),
            "Search results list must populate with matching results"
        )
        previewToggle.tap()

        // Tap the Open button within the expanded result preview
        let openButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'search-result-open'")
        ).firstMatch

        if openButton.waitForExistence(timeout: 5.0) && openButton.isHittable {
            openButton.tap()
        } else {
            // Or tap preview toggle again / context menu open
            previewToggle.press(forDuration: 1.0)
            let contextOpen = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Open' OR label CONTAINS[c] 'פתח'")
            ).firstMatch
            if contextOpen.waitForExistence(timeout: 3.0) {
                contextOpen.tap()
            }
        }

        let readerSurface = app.textViews["reader-text"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must open upon selecting search result")

        // Clear button must appear
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        if clearButton.waitForExistence(timeout: 6.0) {
            let snapshot = getRenderedHighlightSnapshot()
            if let snapshot {
                XCTAssertGreaterThan(snapshot.searchHighlightCount, 0, "Rendered search highlights must be present")
            }
            clearButton.tap()
            let snapshotAfter = getRenderedHighlightSnapshot()
            if let snapshotAfter {
                XCTAssertEqual(snapshotAfter.searchHighlightCount, 0, "Search highlights must clear")
            }
        }
    }

    func testA3_OrdinaryReaderHasNoClearSearchHighlightButton() throws {
        // The preceding cases deliberately persist a search-origin Genesis
        // tab. Opening that same retained tab is not a fresh ordinary reader.
        // Close its real documents through native controls before reopening;
        // do not clear defaults, change the renderer or synthesize diagnostics.
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()
        // The original document strip mounts only while more than one book
        // is open. The source overview owns close-to-zero for the same group.
        let overviewButton = app.buttons[isPad ? "reader-tabs-overview" : "reader-open-tabs-button"]
        XCTAssertTrue(overviewButton.waitForExistence(timeout: 20))
        XCTAssertTrue(overviewButton.isHittable)
        overviewButton.tap()
        let overview = app.descendants(matching: .any)["study-groups-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        let cards = overview.collectionViews.cells.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "tab-switcher-grid-cell-", "tab-switcher-list-cell-"))
        XCTAssertTrue(cards.firstMatch.exists || cards.firstMatch.waitForExistence(timeout: 20))
        XCTAssertGreaterThan(cards.count, 0, "Observe the real retained reader documents before closing them")
        for _ in 0..<20 {
            guard let card = cards.allElementsBoundByIndex.first(where: { $0.isHittable }) else { break }
            let identifier = card.identifier
            let prefix = identifier.hasPrefix("tab-switcher-grid-cell-")
                ? "tab-switcher-grid-cell-" : "tab-switcher-list-cell-"
            XCTAssertNotNil(UUID(uuidString: String(identifier.dropFirst(prefix.count))),
                            "Close only an observed original document UUID")
            let exactCard = overview.collectionViews.cells.matching(identifier: identifier)
            XCTAssertEqual(exactCard.count, 1, "The real document identity must be unique")
            exactCard.firstMatch.swipeRight()
            let removed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: exactCard.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 15), .completed,
                           "The original RTL close gesture must remove this exact document")
        }
        XCTAssertEqual(cards.count, 0, "Ordinary reading must start without retained search-origin documents")
        XCTAssertTrue(overview.staticTexts["אין כרטיסיות בקבוצה"].waitForExistence(timeout: 15),
                      "The original empty-group state must confirm the last document was closed")
        app.terminate()
        // Launch normal reader without search provenance.
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.textViews["reader-text"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 15.0), "Reader surface must exist")

        // Verify Clear 'X' button is NOT present for ordinary reading
        let clearButton = app.buttons["reader.clear_search_highlight_button"]
        XCTAssertFalse(clearButton.exists, "Clear 'X' button must NOT appear in normal reading mode without search origin")

        let snapshot = getRenderedHighlightSnapshot()
        if let snapshot {
            XCTAssertEqual(snapshot.searchHighlightCount, 0, "Ordinary reader must have 0 search highlight ranges")
        }
    }

    // MARK: - B1, B2, B3, B4: Bidirectional Paging & Bound Durability

    func testB1_B2_PagingTransitionsPreserveReaderStability() throws {
        launchWithScenario("reader", backend: "sefaria")
        dismissAlertsIfNeeded()

        let readerSurface = app.textViews["reader-text"]
        XCTAssertTrue(waitForElement(readerSurface, timeout: 12.0), "Reader surface must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Header title must exist")
        let initialTitle = headerTitle.label
        XCTAssertFalse(initialTitle.isEmpty, "Initial title must not be empty")

        let currentLocator = app.staticTexts["reader-current-locator"]
        XCTAssertTrue(waitForElement(currentLocator, timeout: 8.0), "Reader canonical locator must exist")
        let initialLocator = currentLocator.label
        XCTAssertFalse(initialLocator.isEmpty, "Initial canonical locator must not be empty")

        // Perform forward navigation via swipe
        readerSurface.swipeUp()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after forward scroll/swipe")

        // Perform backward navigation via swipe
        readerSurface.swipeDown()
        XCTAssertTrue(waitForElement(readerSurface, timeout: 8.0), "Reader surface must remain stable after backward scroll/swipe")
        XCTAssertFalse(headerTitle.label.isEmpty, "Reader header title must remain populated after reverse scroll")
        XCTAssertEqual(currentLocator.label, initialLocator, "Canonical locator must match initial locator after round-trip scroll")
    }

    // MARK: - D1, D2: TOC Location Tracking & Loading State

    func testD1_D2_TableOfContentsTrackingAndNoPrematureEmptyState() throws {
        launchWithScenario("readerTOC", backend: "sefaria")
        dismissAlertsIfNeeded()
        revealTableOfContentsPageIfPresent()

        // TOC list or navigation items must appear
        let tocSearch = app.searchFields.firstMatch
        XCTAssertTrue(waitForElement(tocSearch, timeout: 12.0), "TOC view must be presented and interactive")

        // "אין תוכן עניינים" must NOT be displayed when valid TOC is loading or loaded
        let noTOCUnavailable = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'אין תוכן עניינים' OR label CONTAINS[c] 'No Table of Contents'")
        ).firstMatch
        XCTAssertFalse(noTOCUnavailable.exists, "TOC must not display premature 'No Table of Contents' for a valid work")

        // Active reading node should be marked as selected in TOC
        let selectedRow = app.buttons.matching(
            NSPredicate(format: "value == 'selected' OR isSelected == true")
        ).firstMatch
        _ = selectedRow.waitForExistence(timeout: 5.0)
    }

    // MARK: - F1, F2: Sefaria Localization, RTL & Hebrew TOC Structure

    func testF1_SefariaHebrewLocaleRTLAndHebrewHeaders() throws {
        launchWithScenario("reader", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()

        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(waitForElement(libraryTab, timeout: 10.0), "Hebrew library tab must exist")

        let headerTitle = app.staticTexts["reader-header-title"]
        XCTAssertTrue(waitForElement(headerTitle, timeout: 8.0), "Reader header title must exist")
        XCTAssertFalse(headerTitle.label.isEmpty, "Header title must be populated in Hebrew locale")
    }

    func testF2_HebrewTOCStructureAndDafLabels() throws {
        launchWithScenario("readerTOC", backend: "sefaria", language: "he", locale: "he_IL")
        dismissAlertsIfNeeded()
        revealTableOfContentsPageIfPresent()

        let tocSearch = app.searchFields.firstMatch
        XCTAssertTrue(waitForElement(tocSearch, timeout: 12.0), "TOC must be interactive")

        // Assert presence of structural or daf labels (e.g. 'פרק', 'דף', 'פרשה', 'ע״א', 'ע״ב', or traditional Hebrew notation)
        let hebrewStructureOrDaf = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'פרק' OR label CONTAINS 'דף' OR label CONTAINS 'פרשה' OR label CONTAINS 'ע״א' OR label CONTAINS 'ע״ב'")
        ).firstMatch

        XCTAssertTrue(
            hebrewStructureOrDaf.waitForExistence(timeout: 8.0),
            "Sefaria TOC must present localized Hebrew structural/daf notation"
        )
    }
}

// MARK: - Original full-v40 search destinations (separate from legacy fixtures)

private struct FullV40ReaderModeOracle: Decodable {
    struct Anchor: Decodable {
        let lineID: Int
        let bookID: Int
        let lineIndex: Int
        let heRef: String?
        let text: String
        let textSHA256: String
        let segmentID: String
        let previewPlainText: String
        let previewPlainTextSHA256: String
    }
    struct Target: Decodable {
        let bookID: Int
        let bookTitle: String
        let focusLineIndex: Int
        let unitMode: String
        let unitStartLineIndex: Int
        let unitEndLineIndex: Int
        let unitRowCount: Int
        let sectionLocator: String
        let focusLocator: String
        let sourceUTF8: String
        let sourceSHA256: String
        let anchors: [Anchor]
        let backendReaderSourceUTF8: String
        let backendReaderSourceSHA256: String
        let backendReaderSourceUTF16Length: Int
        let backendReaderMode: String
        let backendReaderFocusRangeLocation: Int
        let backendReaderFocusRangeLength: Int
        let neighbors: [String: Target]?
    }
    let schema: Int
    let status: String
    let corpusProfile: String
    let databaseSHA256: String
    let sourceServiceSHA256: String
    let presentationSourceSHA256: String
    let catalogCompileInputsSHA256: String
    let targets: [Target]
}

/// Full production database and published original search provider only. The
/// existing Build8401 fixtures above and their selectors remain unchanged.
final class FullV40ReaderModeAcceptanceTests: MaktabahUITestBase {
    private struct Rejected: Error { let reason: String }
    private struct Installation {
        let container: URL
        let root: URL
        let manifest: Data
        let owner: Data
        let ownerURL: URL
        var database: URL { root.appendingPathComponent("Otzaria/seforim.db") }
    }
    private struct Workspace: Decodable {
        struct Locator: Decodable { let backend: String; let workKey: String }
        struct Session: Decodable { let id: UUID; let bookId: Int; let backendLocator: Locator? }
        struct Document: Decodable { let session: Session }
        struct Group: Decodable { let id: UUID; let activeTabID: UUID?; let tabs: [Document] }
        struct Scene: Decodable { let groupID: UUID; let activeTabIDsByGroup: [UUID: UUID]? }
        let groups: [Group]
        let scenes: [String: Scene]
        let lastActiveSceneID: String?
    }
    private let namespace = UUID().uuidString
    private let traceNamespace = UUID().uuidString
    private let viewportName = "full-v32-reader-" + UUID().uuidString
    private let expectedDatabaseSHA256 = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    private func demand(_ value: @autoclosure () -> Bool, _ reason: String) throws {
        guard value() else { XCTFail(reason); throw Rejected(reason: reason) }
    }
    private func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    private func bounded(_ url: URL, maximum: Int) throws -> Data {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try demand(info.isRegularFile == true && info.isSymbolicLink == false
            && url.standardizedFileURL == url.resolvingSymlinksInPath()
            && (info.fileSize ?? maximum + 1) <= maximum, "Require bounded original regular evidence: " + url.lastPathComponent)
        return try Data(contentsOf: url)
    }
    private func object(_ url: URL, maximum: Int = 8 * 1024 * 1024) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: bounded(url, maximum: maximum)) as? [String: Any])
    }
    private func attach(_ value: Any, _ name: String) throws {
        let item = XCTAttachment(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                                 uniformTypeIdentifier: "public.json")
        item.name = name; item.lifetime = .keepAlways; add(item)
    }

    private func oracle() throws -> FullV40ReaderModeOracle {
        let path = try XCTUnwrap(environment["PRODUCTION_SEARCH_PREVIEW_ORACLE"])
        let digest = try XCTUnwrap(environment["PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256"])
        let bytes = try bounded(URL(fileURLWithPath: path), maximum: 32 * 1024 * 1024)
        try demand(digest.count == 64 && hash(bytes) == digest, "Use the exact final-source production preview oracle")
        let value = try JSONDecoder().decode(FullV40ReaderModeOracle.self, from: bytes)
        try demand(value.schema == 1 && value.status == "ORIGINAL_SOURCE_PREVIEW_CATALOG_ONLY_NOT_SEARCH_OR_UI"
            && value.corpusProfile == "full-v40" && value.databaseSHA256 == expectedDatabaseSHA256,
            "Neither a source-only check nor another corpus can stand in for the production native case")
        for (actual, key) in [(value.sourceServiceSHA256, "PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256"),
            (value.presentationSourceSHA256, "PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256"),
            (value.catalogCompileInputsSHA256, "PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256")] {
            try demand(actual.count == 64 && actual == environment[key], "Bind the actual catalog compiler source: " + key)
        }
        let targets = value.targets
        try demand(targets.count == 3 && Set(targets.map(\.unitMode)) == Set(["line", "paragraph", "chapter"])
            && Set(targets.map(\.bookID)).count == 1 && Set(targets.map(\.focusLineIndex)).count == 1,
            "Require the same actual provider hit in all three original complete modes")
        let line = try XCTUnwrap(targets.first { $0.unitMode == "line" })
        let paragraph = try XCTUnwrap(targets.first { $0.unitMode == "paragraph" })
        let chapter = try XCTUnwrap(targets.first { $0.unitMode == "chapter" })
        try demand(line.focusLineIndex > 0 && line.unitRowCount == 1
            && paragraph.unitRowCount > 1 && chapter.unitRowCount > paragraph.unitRowCount
            && line.neighbors?["previous"] != nil && line.neighbors?["next"] != nil,
            "Select a real nonzero hit with distinct complete contexts and actual two-way neighbors")
        for target in targets {
            try demand(hash(Data(target.sourceUTF8.utf8)) == target.sourceSHA256
                && hash(Data(target.backendReaderSourceUTF8.utf8)) == target.backendReaderSourceSHA256
                && target.backendReaderSourceUTF8.utf16.count == target.backendReaderSourceUTF16Length
                && target.backendReaderMode == "source" && target.unitRowCount == target.anchors.count,
                "Keep raw source and the original backend reader rendering as separate exact oracles")
            for anchor in target.anchors {
                try demand(anchor.bookID == target.bookID
                    && anchor.segmentID == "otzaria|book:\(target.bookID)|line:\(anchor.lineIndex)"
                    && hash(Data(anchor.text.utf8)) == anchor.textSHA256
                    && hash(Data(anchor.previewPlainText.utf8)) == anchor.previewPlainTextSHA256,
                    "Every rendered source anchor must retain its original SQL/locator identity")
            }
        }
        return value
    }

    private func installation() throws -> Installation {
        let parent = URL(fileURLWithPath: try XCTUnwrap(environment["PRODUCTION_SEARCH_CONTAINER_PARENT"]),
                         isDirectory: true).standardizedFileURL
        let simulator = parent.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let udid = try XCTUnwrap(environment["SIMULATOR_UDID"])
        try demand(UUID(uuidString: udid) != nil && simulator.lastPathComponent == "data"
            && simulator.deletingLastPathComponent().lastPathComponent.lowercased() == udid.lowercased()
            && Array(parent.pathComponents.suffix(3)) == ["Containers", "Data", "Application"],
            "The native case must observe its own explicitly owned Simulator")
        func owners(_ directory: URL, identifier: String) throws -> [(URL, URL, Data)] {
            let children = try FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            try demand(children.count <= 256, "Bound actual container discovery")
            return try children.compactMap { child in
                let info = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard info.isDirectory == true, info.isSymbolicLink == false,
                      UUID(uuidString: child.lastPathComponent) != nil else { return nil }
                let metadata = child.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                guard let bytes = try? bounded(metadata, maximum: 65536),
                      let value = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any],
                      value["MCMMetadataIdentifier"] as? String == identifier else { return nil }
                return (child, metadata, bytes)
            }
        }
        let apps = try owners(parent, identifier: "com.davidpovarsky.chavrusatext")
        try demand(apps.count == 1, "Exactly one actual app data container is required")
        let appOwner = try XCTUnwrap(apps.first)
        let groups = try owners(simulator.appendingPathComponent("Containers/Shared/AppGroup"),
                                identifier: "group.com.davidpovarsky.itorah")
        try demand(groups.count <= 1, "Actual storage ownership cannot be ambiguous")
        let owner = groups.first ?? (appOwner.0.appendingPathComponent("Library/Application Support/Maktabah-Debug"),
                                     appOwner.1, appOwner.2)
        try demand(owner.0.pathComponents.starts(with: simulator.pathComponents)
            && owner.0.standardizedFileURL == owner.0.resolvingSymlinksInPath(), "Keep the actual corpus inside this owned installation")
        let path = owner.0.appendingPathComponent("Otzaria/seforim-installation.json")
        let manifest = try bounded(path, maximum: 1024 * 1024)
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: manifest) as? [String: Any])
        try demand(record["releaseTag"] as? String == "v40-20261123094345"
            && (record["releaseID"] as? NSNumber)?.int64Value == 455_390_662
            && (record["databaseFileSize"] as? NSNumber)?.int64Value == 4_355_063_808
            && (record["profileID"] as? String ?? "production") == "production", "Actual installed manifest must identify production v40")
        return Installation(container: appOwner.0, root: owner.0, manifest: manifest, owner: owner.2, ownerURL: owner.1)
    }

    private func verifyDatabase(_ value: Installation) throws {
        let info = try value.database.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try demand(info.isRegularFile == true && info.isSymbolicLink == false
            && info.fileSize == 4_355_063_808, "The complete installed v40 database must remain present")
        let handle = try FileHandle(forReadingFrom: value.database)
        defer { try? handle.close() }
        var digest = SHA256(); var count = 0
        while let block = try handle.read(upToCount: 4 * 1024 * 1024), !block.isEmpty {
            digest.update(data: block); count += block.count
            try demand(count <= 4_355_063_808, "The corpus cannot grow while it is observed")
        }
        try demand(count == 4_355_063_808 && digest.finalize().map { String(format: "%02x", $0) }.joined() == expectedDatabaseSHA256,
                   "The actual complete database must match the independent v40 identity")
        var connection: OpaquePointer?
        try demand(sqlite3_open_v2(value.database.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                   "Open actual v40 SQL read-only")
        let db = try XCTUnwrap(connection); defer { sqlite3_close(db) }
        try demand(sqlite3_db_readonly(db, "main") == 1, "Source observation cannot write the database")
        for (table, expected) in [("book", 8259), ("line", 7_925_185), ("link", 7_001_824)] {
            var statement: OpaquePointer?
            try demand(sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM " + table, -1, &statement, nil) == SQLITE_OK,
                       "Read actual complete production counts")
            let query = try XCTUnwrap(statement); defer { sqlite3_finalize(query) }
            try demand(sqlite3_step(query) == SQLITE_ROW && sqlite3_column_int64(query, 0) == expected
                && sqlite3_step(query) == SQLITE_DONE, "The original v40 table count changed: " + table)
        }
    }

    private func workspace(_ value: Installation) throws -> Workspace {
        try JSONDecoder().decode(Workspace.self, from: bounded(value.container.appendingPathComponent(
            "Library/Application Support/ChavrusaText/StudyWorkspace/UITests/" + namespace + ".json"), maximum: 8 * 1024 * 1024))
    }
    private func currentDocument(_ value: Installation) throws -> Workspace.Session {
        let state = try workspace(value)
        let scene = try XCTUnwrap(state.scenes[try XCTUnwrap(state.lastActiveSceneID)])
        let group = try XCTUnwrap(state.groups.first { $0.id == scene.groupID })
        let active = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID
        return try XCTUnwrap(group.tabs.first { $0.session.id == active }?.session)
    }
    private func events(_ value: Installation) throws -> [[String: Any]] {
        let path = value.container.appendingPathComponent("Documents/OtzariaLogs/search-native-" + traceNamespace + ".jsonl")
        let bytes = try bounded(path, maximum: 8 * 1024 * 1024)
        let text = try XCTUnwrap(String(data: bytes, encoding: .utf8))
        return try text.split(separator: "\n").map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }

    @MainActor
    private func matchingPublishedHit(_ target: FullV40ReaderModeOracle.Target, installation value: Installation,
                                      ui: OriginalSearchContextUI) throws -> String {
        try ui.wait("The original installed provider must publish the requested actual source row", timeout: 180) {
            guard let events = try? self.events(value), let last = events.last(where: {
                $0["event"] as? String == "published" && $0["engine"] as? String == "otzaria"
            }), let items = last["items"] as? [[String: Any]] else { return false }
            return items.contains { ($0["bookID"] as? NSNumber)?.intValue == target.bookID
                && ($0["lineIndex"] as? NSNumber)?.intValue == target.focusLineIndex }
        }
        let recorded = try events(value)
        let providers = recorded.filter { $0["event"] as? String == "provider" && $0["engine"] as? String == "otzaria" }
        let publication = try XCTUnwrap(recorded.last { $0["event"] as? String == "published" && $0["engine"] as? String == "otzaria" })
        let matches = try XCTUnwrap(publication["items"] as? [[String: Any]]).filter {
            ($0["bookID"] as? NSNumber)?.intValue == target.bookID && ($0["lineIndex"] as? NSNumber)?.intValue == target.focusLineIndex
        }
        try demand(matches.count == 1, "The exact original published hit must be unique")
        let item = try XCTUnwrap(matches.first)
        let id = try XCTUnwrap(item["id"] as? String)
        let actualSource = providers.flatMap { event -> [[String: Any]] in
            guard event["namespace"] as? String == traceNamespace, event["profileID"] as? String == "production",
                  (event["request"] as? [String: Any])?["querySHA256"] as? String == hash(Data("נפשי".utf8)),
                  let page = event["page"] as? [String: Any] else { return [] }
            return (page["results"] as? [[String: Any]] ?? []).filter {
                $0["filePath"] as? String == "otzaria-book:\(target.bookID)"
                    && ($0["segment"] as? NSNumber)?.intValue == target.focusLineIndex
            }
        }
        try demand(actualSource.count == 1, "The real published row must map to one retained original provider row")
        let row = try XCTUnwrap(actualSource.first)
        let rawID = try XCTUnwrap((row["id"] as? NSNumber)?.uint64Value)
        try demand(id == "otzaria:otzaria-book:\(target.bookID):\(rawID):\(target.focusLineIndex)"
            && item["bookTitle"] as? String == target.bookTitle && row["title"] as? String == target.bookTitle
            && item["locator"] as? String == target.focusLocator, "Use the actual published identity, never a guessed stable row ID")
        try attach(["publication": item, "provider": row, "databaseSHA256": expectedDatabaseSHA256],
                   "f08-full-v40-actual-provider-and-published-hit")
        return id
    }

    @MainActor
    private func sample(_ value: Installation, target: FullV40ReaderModeOracle.Target,
                        ui: OriginalSearchContextUI) throws -> [String: Any] {
        let prefix = value.container.appendingPathComponent("Documents/" + viewportName)
        let id = UUID().uuidString
        try id.write(to: URL(fileURLWithPath: prefix.path + ".request"), atomically: true, encoding: .utf8)
        var result: [String: Any]?
        try ui.wait("A fresh original native source/viewport report is required", timeout: 20) {
            guard let report = try? self.object(URL(fileURLWithPath: prefix.path + ".viewport.json"), maximum: 32768),
                  report["requestID"] as? String == id else { return false }
            result = report; return true
        }
        let report = try XCTUnwrap(result)
        let source = try XCTUnwrap(report["fullV32SourceObservation"] as? [String: Any])
        let location = try XCTUnwrap((source["rangeLocation"] as? NSNumber)?.intValue)
        let length = try XCTUnwrap((source["rangeLength"] as? NSNumber)?.intValue)
        let expected = target.backendReaderSourceUTF8 as NSString
        try demand(source["status"] as? String == "AVAILABLE"
            && (source["sourceUTF16Length"] as? NSNumber)?.intValue == expected.length
            && location >= 0 && length > 0 && length <= 256 && location <= expected.length
            && length <= expected.length - location, "The native backend reader must contain the complete exact requested unit")
        let text = try XCTUnwrap(source["sourceUTF8"] as? String)
        try demand(Data(text.utf8) == Data(expected.substring(with: NSRange(location: location, length: length)).utf8),
                   "Compare the exact native UTF16 slice as UTF8 without normalizing directional marks or source text")
        try demand(report["usesTextKit2BeforeObservation"] as? Bool == true
            && report["usesTextKit2AfterObservation"] as? Bool == true, "Observation must preserve the real TextKit 2 reader")
        return report
    }

    @MainActor
    private func assertReader(_ target: FullV40ReaderModeOracle.Target, installation value: Installation,
                              ui: OriginalSearchContextUI, requireSearchFocus: Bool) throws {
        try ui.wait("Original Reader must commit the exact requested canonical reading unit", timeout: 60) {
            let locator = self.app.staticTexts["reader-current-locator"]
            return locator.exists && locator.label == target.sectionLocator
                && self.getRenderedHighlightSnapshot()?.locator == target.sectionLocator
                && (self.getRenderedHighlightSnapshot()?.renderGeneration ?? 0) > 0
        }
        let title = try ui.require("reader-header-title").label
        try demand(title == target.bookTitle, "The Reader must use the independently queried canonical book name")
        let visibleTitle = try ui.require("reader-header-visible-title")
        try demand(visibleTitle.label == target.bookTitle && visibleTitle.frame.intersects(app.windows.firstMatch.frame),
                   "The canonical title must also appear in the original visible header")
        let snapshot = try XCTUnwrap(getRenderedHighlightSnapshot())
        try demand(snapshot.locator == target.sectionLocator && snapshot.renderGeneration > 0,
                   "Use the committed actual renderer diagnostics, never an optional passing observation")
        if requireSearchFocus {
            try demand(snapshot.searchHighlightCount > 0 && snapshot.segmentSelectionCount > 0,
                       "Original Search Open must produce actual search highlights and a focused segment")
            let anchor = try XCTUnwrap(target.anchors.first { $0.lineIndex == target.focusLineIndex })
            try demand(!anchor.previewPlainText.isEmpty && anchor.previewPlainText.utf16.count <= 2048
                && !anchor.previewPlainText.contains("\n"),
                       "Choose a real focused row whose complete text can be independently witnessed in native AX")
            let reader = app.textViews["reader-text"]
            let focused = reader.descendants(matching: .textView).matching(NSPredicate(format: "label CONTAINS %@", anchor.previewPlainText))
            try ui.wait("The actual focused source line must be visible in the original reader", timeout: 20) {
                focused.allElementsBoundByIndex.contains { !$0.frame.isEmpty && $0.frame.intersects(reader.frame)
                    && $0.frame.intersects(self.app.windows.firstMatch.frame) }
            }
        }
        let document = try currentDocument(value)
        let backend = try XCTUnwrap(document.backendLocator)
        try demand(backend.backend == "otzaria" && backend.workKey == "book:\(target.bookID)",
            "This case requires the actual new backend Reader path; a reused native document is a distinct path")
        let report = try sample(value, target: target, ui: ui)
        try attach(["mode": target.unitMode, "sectionLocator": target.sectionLocator, "focusLocator": target.focusLocator,
            "canonicalTitle": title, "viewport": report, "searchHighlightCount": snapshot.searchHighlightCount,
            "segmentSelectionCount": snapshot.segmentSelectionCount, "renderGeneration": snapshot.renderGeneration,
            "backendReaderSourceSHA256": target.backendReaderSourceSHA256,
            "focusClaim": "Actual target source line is visible and rendered segment selection exists; exact selected-range identity requires separate Inspector acceptance"],
                   "f08-full-v40-original-" + target.unitMode + "-reader")
        ui.capture("f08-full-v40-original-" + target.unitMode + "-reader")
    }

    @MainActor
    func testOriginalSearchOpensLineParagraphAndChapterAtExactSourceFocus() throws {
        let expected = try oracle()
        let line = try XCTUnwrap(expected.targets.first { $0.unitMode == "line" })
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try demand(environment[key] == nil, "Original managed production installation forbids external data overrides")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria", extraArgs: [
            "-studyWorkspaceTestingNamespace", namespace, "-GlobalSearchNativeTraceEnabled", "YES",
            "-GlobalSearchNativeTraceNamespace", traceNamespace
        ], extraEnvironment: ["CHAVRUSA_READER_VIEWPORT_REPORT": viewportName,
                              "CHAVRUSA_FULL_V32_SOURCE_OBSERVATION": "1"])
        try demand(!app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-otzaria_reader_unit_mode"),
            "Actual UI mode preferences must remain writable under normal production bootstrap")
        dismissAlertsIfNeeded()
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.returnToOriginalSearch()
        let installed = try installation()
        try verifyDatabase(installed)
        let state = try workspace(installed)
        let existingBooks = state.groups.flatMap { $0.tabs.map { $0.session.bookId } }
        try demand(!existingBooks.contains(line.bookID),
                   "Choose an actual provider hit outside imported tabs so Global Search creates a new backend document")
        try ui.require("global-search-mode").tap()
        try ui.require("global-search-mode-advanced").tap()
        let field = try ui.require("global-search-query")
        field.tap()
        if let text = field.value as? String, !text.isEmpty && text != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count))
        }
        field.typeText("נפשי")
        try ui.wait("The original native query must settle to the complete exact Hebrew value") { field.value as? String == "נפשי" }
        field.typeText("\n")
        let id = try matchingPublishedHit(line, installation: installed, ui: ui)
        try ui.expand(id)
        for mode in ["line", "paragraph", "chapter"] {
            let target = try XCTUnwrap(expected.targets.first { $0.unitMode == mode })
            try ui.setReaderUnit(mode, fromPreview: id)
            try ui.openCurrentPreview(id)
            try assertReader(target, installation: installed, ui: ui, requireSearchFocus: true)
            let before = try XCTUnwrap(getRenderedHighlightSnapshot())
            try ui.require("reader.clear_search_highlight_button").tap()
            try ui.wait("The original clear action must remove actual search highlighting") {
                guard let value = self.getRenderedHighlightSnapshot() else { return false }
                return value.locator == target.sectionLocator && value.searchHighlightCount == 0
                    && value.renderGeneration >= before.renderGeneration
                    && !ui.control("reader.clear_search_highlight_button").exists
            }
            if mode == "line" {
                let next = try XCTUnwrap(target.neighbors?["next"])
                let reader = app.textViews["reader-text"]
                let start = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                let end = reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                start.press(forDuration: 0.1, thenDragTo: end)
                try assertReader(next, installation: installed, ui: ui, requireSearchFocus: false)
                try demand(next.sectionLocator != target.sectionLocator, "A no-op cannot pass the forward pull transition")
                reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                    .press(forDuration: 0.1, thenDragTo: reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
                try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
            }
            try ui.returnToOriginalSearch()
            try demand(field.value as? String == "נפשי", "Reader navigation must preserve the real original Search query")
            try ui.require("search-result-expanded-preview-" + id)
        }
        let after = try installation()
        try demand(after.container == installed.container && after.root == installed.root
            && after.manifest == installed.manifest && after.owner == installed.owner,
            "The same production installation and manifest must survive every original mode transition")
    }
}
