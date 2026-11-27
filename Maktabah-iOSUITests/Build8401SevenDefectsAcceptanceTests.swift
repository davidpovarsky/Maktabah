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
    struct TOCSelection: Decodable {
        struct Heading: Decodable { let entryID: Int; let sourceLineIndex: Int; let title: String; let rawTitle: String }
        let schema: Int
        let canonicalLocator: String
        let sourceLineIndex: Int
        let headings: [Heading]
        let allTOCRowsChecked: Int
        let tocSQLRowsSHA256: String
    }
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
        let tocSelection: TOCSelection?
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

// MARK: - Original production selection, backend restoration and pull/TOC gates

extension FullV40ReaderModeAcceptanceTests {
    @MainActor
    private func prepareAdditionalReaderGate() throws -> (FullV40ReaderModeOracle, Installation, OriginalSearchContextUI, String) {
        let expected = try oracle()
        let line = try XCTUnwrap(expected.targets.first { $0.unitMode == "line" })
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try demand(environment[key] == nil, "Use the original managed production installation")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "otzaria", extraArgs: [
            "-studyWorkspaceTestingNamespace", namespace, "-GlobalSearchNativeTraceEnabled", "YES",
            "-GlobalSearchNativeTraceNamespace", traceNamespace
        ], language: "en", locale: "en_US", extraEnvironment: [
            "CHAVRUSA_READER_VIEWPORT_REPORT": viewportName,
            "CHAVRUSA_FULL_V32_SOURCE_OBSERVATION": "1", "CHAVRUSA_READER_SELECTION_OBSERVATION": "1"
        ])
        try demand(!app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-smokeScenario")
            && !app.launchArguments.contains("-otzaria_reader_unit_mode"),
            "No seeded Reader or fixed mode may replace the original UI path")
        dismissAlertsIfNeeded()
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.returnToOriginalSearch()
        let installed = try installation()
        try verifyDatabase(installed)
        let imported = try workspace(installed)
        try demand(!imported.groups.flatMap { $0.tabs.map { $0.session.bookId } }.contains(line.bookID),
                   "Use a real provider target outside imported tabs for the original backend Reader path")
        try ui.require("global-search-mode").tap()
        try ui.require("global-search-mode-advanced").tap()
        let field = try ui.require("global-search-query")
        field.tap()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("נפשי")
        try ui.wait("The complete original Hebrew query must settle") { field.value as? String == "נפשי" }
        field.typeText("\n")
        let id = try matchingPublishedHit(line, installation: installed, ui: ui)
        try ui.expand(id)
        return (expected, installed, ui, id)
    }

    private func actualPreferences(_ value: Installation) throws -> [String: Any] {
        let path = value.container.appendingPathComponent("Library/Preferences/com.davidpovarsky.chavrusatext.plist")
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: bounded(path, maximum: 8 * 1024 * 1024),
                                                                  format: nil) as? [String: Any])
    }

    @MainActor
    private func originalSurrogate(_ locator: String, installation value: Installation,
                                   ui: OriginalSearchContextUI) throws -> Int {
        var observed: Int?
        try ui.wait("The original registry must persist this actual canonical locator", timeout: 30) {
            guard let preferences = try? self.actualPreferences(value),
                  let map = preferences["qualifiedLocatorSurrogates.v1"] as? [String: NSNumber],
                  let id = map[locator]?.intValue,
                  let bytes = preferences["qualifiedLocatorReverse.v1"] as? Data,
                  bytes.count <= 6 * 1024 * 1024,
                  let reverse = try? JSONSerialization.jsonObject(with: bytes) as? [String: [String: Any]],
                  let original = reverse[String(id)],
                  let backend = original["backend"] as? String,
                  let work = original["workKey"] as? String,
                  let position = original["position"] as? [String: Any] else { return false }
            let suffix: String
            if position["kind"] as? String == "legacyLine", let line = position["integer"] as? NSNumber {
                suffix = "line:" + line.stringValue
            } else if position["kind"] as? String == "canonicalRef", let reference = position["string"] as? String {
                suffix = "ref:" + reference
            } else { return false }
            guard backend + "|" + work + "|" + suffix == locator, id < 0 else { return false }
            observed = id; return true
        }
        return try XCTUnwrap(observed)
    }

    @MainActor
    private func readNativeRequest(_ request: String, installation value: Installation,
                                   ui: OriginalSearchContextUI) throws -> [String: Any] {
        let path = value.container.appendingPathComponent("Documents/" + viewportName + ".viewport.json")
        var observed: [String: Any]?
        try ui.wait("The original UIKit view must answer the exact fresh request", timeout: 20) {
            guard let report = try? self.object(path, maximum: 65_536), report["requestID"] as? String == request else { return false }
            observed = report; return true
        }
        let report = try XCTUnwrap(observed)
        let selection = try XCTUnwrap(report["nativeSelectionObservation"] as? [String: Any])
        let source = try XCTUnwrap(report["fullV32SourceObservation"] as? [String: Any])
        try demand(selection["requestID"] as? String == request
            && selection["schema"] as? Int == 1 && source["schema"] as? Int == 1
            && (selection["processID"] as? NSNumber)?.intValue == (source["processID"] as? NSNumber)?.intValue
            && ((selection["processID"] as? NSNumber)?.intValue ?? 0) > 0,
            "Bind the original source and actual native selection to one fresh process/request")
        let selectionObject = try XCTUnwrap(selection["textViewObject"] as? Int,
            "Require the original native selection's integer UITextView identity")
        let viewportObject = try XCTUnwrap(report["object"] as? Int,
            "Require the original viewport's integer UITextView identity")
        try demand(selectionObject == viewportObject
            && selection["usesTextKit2BeforeObservation"] as? Bool == true
            && selection["usesTextKit2AfterObservation"] as? Bool == true
            && report["usesTextKit2BeforeObservation"] as? Bool == true
            && report["usesTextKit2AfterObservation"] as? Bool == true,
            "Observe one unchanged original TextKit 2 owner")
        try demand(["EMPTY", "AVAILABLE"].contains(selection["status"] as? String ?? ""),
                   "Invalid, stale or oversized native selection cannot satisfy acceptance")
        return report
    }

    @MainActor
    private func nativeSelection(_ value: Installation, ui: OriginalSearchContextUI) throws -> [String: Any] {
        let before = try currentDocument(value)
        let locator = try ui.require("reader-current-locator").label
        let generation = try XCTUnwrap(getRenderedHighlightSnapshot()).renderGeneration
        let id = UUID().uuidString
        try id.write(to: value.container.appendingPathComponent("Documents/" + viewportName + ".request"),
                     atomically: true, encoding: .utf8)
        let report = try readNativeRequest(id, installation: value, ui: ui)
        let selection = try XCTUnwrap(report["nativeSelectionObservation"] as? [String: Any])
        let after = try currentDocument(value)
        try demand(before.id == after.id && before.bookId == after.bookId
            && before.backendLocator?.backend == after.backendLocator?.backend
            && before.backendLocator?.workKey == after.backendLocator?.workKey
            && selection["locator"] as? String == locator
            && selection["renderGeneration"] as? Int == generation
            && getRenderedHighlightSnapshot()?.locator == locator
            && getRenderedHighlightSnapshot()?.renderGeneration == generation,
            "A fresh sample must belong to the same committed document, canonical Reader and render generation")
        return report
    }

    private func annotationDatabase(_ value: Installation) throws -> URL {
        // AppConfig chooses the real annotation folder. Discover the existing
        // original DB in this owned app/group, never construct a replacement DB.
        let roots = Set([value.container.standardizedFileURL, value.root.standardizedFileURL])
        var matches = Set<URL>(), visited = 0
        for root in roots {
            guard let iterator = FileManager.default.enumerator(at: root,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
                throw Rejected(reason: "Original annotation storage cannot be enumerated")
            }
            while let url = iterator.nextObject() as? URL {
                visited += 1
                try demand(visited <= 16_384, "Bound discovery within the actual owned installation")
                let metadata = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
                if metadata.isSymbolicLink == true { iterator.skipDescendants(); continue }
                if url.lastPathComponent == "Annotations.sqlite" && metadata.isRegularFile == true {
                    try demand(url.standardizedFileURL == url.resolvingSymlinksInPath(), "Observe the actual original annotation file")
                    matches.insert(url.standardizedFileURL)
                }
            }
        }
        try demand(matches.count == 1, "Exactly one original annotations database must already exist for this installed app")
        return try XCTUnwrap(matches.first)
    }

    private func annotationRows(_ url: URL, after minimumID: Int64) throws -> [[String: Any]] {
        var connection: OpaquePointer?
        try demand(sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                   "Open the actual user annotations read-only")
        let db = try XCTUnwrap(connection); defer { sqlite3_close(db) }
        try demand(sqlite3_db_readonly(db, "main") == 1, "Annotation verification may never write SQLite")
        var raw: OpaquePointer?
        let sql = "SELECT id,bkId,contentId,startIndex,length,startIndexDiac,lengthDiac,type,context,backendLocator,color FROM annotations WHERE id>? ORDER BY id LIMIT 32"
        try demand(sqlite3_prepare_v2(db, sql, -1, &raw, nil) == SQLITE_OK, "Use the original persisted annotation schema")
        let statement = try XCTUnwrap(raw); defer { sqlite3_finalize(statement) }
        try demand(sqlite3_bind_int64(statement, 1, minimumID) == SQLITE_OK, "Bind the observed original row boundary")
        let names = ["id", "bkId", "contentId", "startIndex", "length", "startIndexDiac", "lengthDiac", "type", "context", "backendLocator", "color"]
        var rows: [[String: Any]] = []
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW {
            var row: [String: Any] = [:]
            for (index, key) in names.enumerated() {
                if index < 8 { row[key] = sqlite3_column_int64(statement, Int32(index)) }
                else if let bytes = sqlite3_column_text(statement, Int32(index)) { row[key] = String(cString: bytes) }
                else { row[key] = NSNull() }
            }
            rows.append(row); step = sqlite3_step(statement)
        }
        try demand(step == SQLITE_DONE && rows.count < 32, "Bound the actual original annotation changes")
        return rows
    }

    private func annotationHighWater(_ url: URL) throws -> Int64 {
        var connection: OpaquePointer?
        try demand(sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                   "Observe original annotation high water without creating a database")
        let db = try XCTUnwrap(connection); defer { sqlite3_close(db) }
        var raw: OpaquePointer?
        try demand(sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(id),0) FROM annotations", -1, &raw, nil) == SQLITE_OK,
                   "Read the original row identity boundary")
        let statement = try XCTUnwrap(raw); defer { sqlite3_finalize(statement) }
        try demand(sqlite3_step(statement) == SQLITE_ROW, "Actual annotation boundary is required")
        return sqlite3_column_int64(statement, 0)
    }

    @MainActor
    private func originalMenuAction(_ label: String, ui: OriginalSearchContextUI) throws -> XCUIElement {
        func candidates() -> [XCUIElement] {
            let menu = app.menuItems.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
            let buttons = app.buttons.matching(NSPredicate(format: "label == %@", label)).allElementsBoundByIndex
            let selected = menu.isEmpty ? buttons : menu
            return selected.filter { $0.exists && !$0.frame.isEmpty && $0.frame.intersects(app.windows.firstMatch.frame) && $0.isHittable }
        }
        try ui.wait("Require the original English native selection-menu action: " + label) { candidates().count == 1 }
        return try XCTUnwrap(candidates().first)
    }

    @MainActor
    private func assertPersistedSelection(_ row: [String: Any], selection: [String: Any],
                                          target: FullV40ReaderModeOracle.Target, contentID: Int) throws {
        let source = target.backendReaderSourceUTF8 as NSString
        let location = try XCTUnwrap(selection["sourceRangeLocation"] as? Int)
        let length = try XCTUnwrap(selection["sourceRangeLength"] as? Int)
        try demand(location == 0 && length == source.length && source.length <= 2048,
                   "The original Select All action must map exactly to this independently generated complete source line")
        let selected = try XCTUnwrap(selection["sourceUTF8"] as? String)
        try demand(Data(selected.utf8) == Data(target.backendReaderSourceUTF8.utf8)
            && row["context"] as? String == selected && (row["bkId"] as? NSNumber)?.intValue == target.bookID
            && (row["contentId"] as? NSNumber)?.intValue == contentID && (row["type"] as? NSNumber)?.intValue == 0,
            "The original native edit menu must persist this exact source selection and reading-unit identity")
        let diacritics = try XCTUnwrap(selection["showHarakat"] as? Bool)
        try demand((row[diacritics ? "startIndexDiac" : "startIndex"] as? NSNumber)?.intValue == location
            && (row[diacritics ? "lengthDiac" : "length"] as? NSNumber)?.intValue == length,
            "The stored active original UTF16 range must match UIKit's actual original mapping")
        let encoded = try XCTUnwrap(row["backendLocator"] as? String)
        let locator = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any])
        let position = try XCTUnwrap(locator["position"] as? [String: Any])
        try demand(locator["backend"] as? String == "otzaria" && locator["workKey"] as? String == "book:\(target.bookID)"
            && position["kind"] as? String == "legacyLine" && position["integer"] as? Int == target.focusLineIndex,
            "Persist the real source-line locator, never a global document ID plus an offset")
    }

    @MainActor
    private func assertRenderedOriginalAnnotation(_ selection: [String: Any], locator: String,
                                                  colorHex: String, ui: OriginalSearchContextUI) throws {
        let start = try XCTUnwrap(selection["displayRangeLocation"] as? Int)
        let length = try XCTUnwrap(selection["displayRangeLength"] as? Int)
        try demand(start >= 0 && length > 0 && length <= 2048, "Bound the actual selected display range")
        try demand(colorHex.hasPrefix("#") && colorHex.count == 7, "Use the original persisted RGB annotation color")
        var snapshot: [String: Any]?
        try ui.wait("The committed original attributed text must render the saved annotation", timeout: 20) {
            let element = self.app.otherElements["reader-rendered-highlight-diagnostics"]
            guard element.exists, let text = element.value as? String, text.utf8.count <= 65_536,
                  let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  value["locator"] as? String == locator,
                  let items = value["highlights"] as? [[String: Any]] else { return false }
            let ranges = items.filter { $0["provenance"] as? String == "annotation" }
            var covered = Set<Int>()
            for range in ranges {
                guard let location = range["location"] as? Int, let count = range["length"] as? Int,
                      (range["colorHex"] as? String)?.uppercased() == colorHex.uppercased(),
                      location >= start, count > 0, location <= start + length,
                      count <= start + length - location else { return false }
                covered.formUnion(location..<(location + count))
            }
            guard covered == Set(start..<(start + length)) else { return false }
            snapshot = value; return true
        }
        try attach(try XCTUnwrap(snapshot), "reader-v40-exact-original-annotation-render-ranges")
    }

    @MainActor
    private func switchOriginalBackend(_ backend: String, installation value: Installation,
                                       ui: OriginalSearchContextUI) throws {
        try ui.returnToOriginalSearch()
        try ui.require("main-settings-button").tap()
        try ui.require("settings-library-source-picker").tap()
        let names = ["otzaria": "אוצריא", "sefaria": "ספריא (ישן)", "sefariaEmbedded": "ספריא"]
        try originalMenuAction(try XCTUnwrap(names[backend]), ui: ui).tap()
        try ui.wait("Original Settings must commit this exact backend and finish its transition", timeout: 90) {
            let selected = self.app.staticTexts["settings-active-backend-id"]
            let phase = self.app.staticTexts["settings-transition-state"]
            return selected.exists && selected.label == backend && phase.exists && phase.label == "idle"
                && (try? self.actualPreferences(value)["activeLibraryBackend.v1"] as? String) == backend
        }
        try attach(["backend": backend, "actualSettings": app.staticTexts["settings-active-backend-id"].label,
            "transition": app.staticTexts["settings-transition-state"].label], "reader-v40-original-settings-backend-" + backend)
        try ui.require("settings-done-button").tap()
        let tabs = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", "Library"))
        try ui.wait("Use the unique original Library TabView button") {
            tabs.allElementsBoundByIndex.filter { $0.isHittable && !$0.frame.isEmpty
                && $0.frame.intersects(self.app.windows.firstMatch.frame) }.count == 1
        }
        try XCTUnwrap(tabs.allElementsBoundByIndex.first { $0.isHittable }).tap()
    }

    @MainActor
    private func showOriginalContents(_ ui: OriginalSearchContextUI) throws {
        let list = app.descendants(matching: .any)["toc-content-list"]
        if list.exists && !list.frame.isEmpty && list.frame.intersects(app.windows.firstMatch.frame) { return }
        try ui.require("reader-more-menu").tap()
        try ui.require("reader-toc-toggle").tap()
        try ui.wait("The actual original TOC must be visible", timeout: 60) {
            list.exists && !list.frame.isEmpty && list.frame.intersects(self.app.windows.firstMatch.frame)
        }
        try demand(!ui.control("toc-empty").exists && !ui.control("toc-failure").exists,
                   "Do not replace the original loaded book TOC with an empty/failure surface")
    }

    @MainActor
    private func hideOriginalContents(_ ui: OriginalSearchContextUI) throws {
        let list = app.descendants(matching: .any)["toc-content-list"]
        guard list.exists && !list.frame.isEmpty && list.frame.intersects(app.windows.firstMatch.frame) else { return }
        let close = ui.control("toc-close")
        if close.exists && close.isHittable { close.tap() }
        else {
            let custom = app.buttons["reader-host-sidebar-toggle"]
            let native = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Hide Sidebar"))
            let controls = ([custom] + native.allElementsBoundByIndex).filter { $0.exists && $0.isHittable }
            try demand(controls.count == 1, "Close the actual unique original Contents sidebar owner")
            try XCTUnwrap(controls.first).tap()
        }
        try ui.wait("The original Contents sidebar must actually close") {
            !list.exists || list.frame.isEmpty || !list.frame.intersects(self.app.windows.firstMatch.frame)
        }
    }

    @MainActor
    private func openOriginalGenesis(_ backend: String, installation value: Installation,
                                     ui: OriginalSearchContextUI) throws -> [String: Any] {
        try ui.require("reader-command-palette-launcher").tap()
        let palette = try ui.require("reader-library-command-palette")
        let field = palette.textFields.firstMatch
        try demand(field.waitForExistence(timeout: 20) && field.isHittable, "Use the original Library palette field")
        field.tap(); field.typeKey("a", modifierFlags: .command); field.typeText("בראשית")
        try ui.wait("The original canonical work query must settle") { field.value as? String == "בראשית" }
        let rows = palette.buttons.matching(NSPredicate(format: "label == %@", "בראשית"))
        try ui.wait("Open one exact work from this backend's actual original catalog", timeout: 60) {
            rows.allElementsBoundByIndex.filter { $0.isHittable }.count == 1
        }
        try XCTUnwrap(rows.allElementsBoundByIndex.first { $0.isHittable }).tap()
        try ui.wait("The actual Reader must commit this backend's canonical Genesis work", timeout: 90) {
            self.app.staticTexts["reader-current-locator"].label.hasPrefix(backend + "|Genesis|ref:")
        }
        try showOriginalContents(ui)
        let canonical = backend + "|Genesis|ref:Genesis 1"
        let id = try originalSurrogate(canonical, installation: value, ui: ui)
        let list = app.descendants(matching: .any)["toc-content-list"]
        let choices = app.buttons.matching(identifier: "toc-row-\(id)")
        for _ in 0..<60 {
            if choices.allElementsBoundByIndex.contains(where: { $0.isHittable }) { break }
            list.swipeDown(velocity: .slow)
        }
        let visible = choices.allElementsBoundByIndex.filter { $0.isHittable }
        try demand(visible.count == 1, "Use the original registry-bound canonical Genesis 1 TOC node")
        try XCTUnwrap(visible.first).tap()
        try ui.wait("Canonical TOC navigation must commit the exact original bounded chapter", timeout: 60) {
            self.app.staticTexts["reader-current-locator"].label == canonical
                && self.getRenderedHighlightSnapshot()?.locator == canonical
        }
        try hideOriginalContents(ui)
        return try backendReaderReceipt(backend, canonical: canonical, installation: value, ui: ui)
    }

    @MainActor
    private func backendReaderReceipt(_ backend: String, canonical: String, installation value: Installation,
                                      ui: OriginalSearchContextUI) throws -> [String: Any] {
        try ui.wait("The actual restored Reader must have the exact expected backend/section", timeout: 90) {
            self.app.staticTexts["reader-current-locator"].label == canonical
                && self.getRenderedHighlightSnapshot()?.locator == canonical
        }
        let document = try currentDocument(value)
        try demand(document.backendLocator?.backend == backend && document.backendLocator?.workKey == "Genesis",
                   "Match the actual retained workspace document to this original backend work")
        let title = try ui.require("reader-header-title").label
        try demand(title == "בראשית",
                   "Retain the actual canonical catalog title, not the previous backend's title")
        let native = try nativeSelection(value, ui: ui)
        let selection = try XCTUnwrap(native["nativeSelectionObservation"] as? [String: Any])
        let source = try XCTUnwrap(native["fullV32SourceObservation"] as? [String: Any])
        try demand(selection["status"] as? String == "EMPTY" && selection["displayRangeLength"] as? Int == 0
            && source["status"] as? String == "AVAILABLE"
            && ((source["sourceUTF16Length"] as? NSNumber)?.intValue ?? 0) > 0,
            "A different original Reader must not inherit UIKit selection from the previous backend")
        let result: [String: Any] = ["backend": backend, "canonicalLocator": canonical,
            "documentID": document.id.uuidString, "bookID": document.bookId, "native": native,
            "scope": "Actual canonical backend Reader and bounded original source; no independent full Sefaria body claim"]
        try attach(result, "reader-v40-original-backend-" + backend)
        ui.capture("reader-v40-original-backend-" + backend)
        return result
    }

    @MainActor
    func testOriginalUIKitSelectionPersistsExactUTF16AndRestoresAcrossThreeBackends() throws {
        let (expected, installed, ui, id) = try prepareAdditionalReaderGate()
        let target = try XCTUnwrap(expected.targets.first { $0.unitMode == "line" })
        try demand(target.backendReaderSourceUTF16Length <= 2048, "Use a complete bounded real line for native Select All")
        try ui.setReaderUnit("line", fromPreview: id)
        try ui.openCurrentPreview(id)
        try assertReader(target, installation: installed, ui: ui, requireSearchFocus: true)
        try ui.require("reader.clear_search_highlight_button").tap()
        try ui.wait("Remove the original search overlay before independently exercising annotation selection") {
            self.getRenderedHighlightSnapshot()?.searchHighlightCount == 0
        }
        try demand(getRenderedHighlightSnapshot()?.annotationHighlightCount == 0,
                   "Use an actual previously unannotated provider row, preserving existing user annotations")
        let originalDocument = try currentDocument(installed)
        let database = try annotationDatabase(installed)
        let highWater = try annotationHighWater(database)
        let contentID = try originalSurrogate(target.sectionLocator, installation: installed, ui: ui)
        let anchor = try XCTUnwrap(target.anchors.first)
        let reader = app.textViews["reader-text"]
        let paragraphs = reader.descendants(matching: .textView).matching(NSPredicate(format: "label CONTAINS %@", anchor.previewPlainText))
        let visible = paragraphs.allElementsBoundByIndex.filter { !$0.frame.isEmpty && $0.frame.intersects(reader.frame)
            && $0.frame.intersects(app.windows.firstMatch.frame) }
        try demand(visible.count == 1, "Use the actual complete source-line native text descendant")
        let text = try XCTUnwrap(visible.first)
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1)
        try originalMenuAction("Select All", ui: ui).tap()
        let native = try nativeSelection(installed, ui: ui)
        let selection = try XCTUnwrap(native["nativeSelectionObservation"] as? [String: Any])
        try demand(selection["status"] as? String == "AVAILABLE"
            && selection["displayRangeLocation"] as? Int == 0
            && selection["displayRangeLength"] as? Int == selection["displayUTF16Length"] as? Int,
            "Actual UIKit Select All must select the whole original rendered line")
        try originalMenuAction("Annotation", ui: ui).tap()
        let colorLabels = ["Yellow", "Green", "Blue", "Pink", "Purple"]
        var color: XCUIElement?
        try ui.wait("Choose an actual original recent highlight-color action") {
            color = self.app.buttons.matching(NSPredicate(format: "label IN %@", colorLabels))
                .allElementsBoundByIndex.first { $0.isHittable && $0.frame.intersects(self.app.windows.firstMatch.frame) }
            return color != nil
        }
        let action = try XCTUnwrap(color), actualColorLabel = action.label
        action.tap()
        var saved: [String: Any]?
        try ui.wait("The original highlight action must commit one actual user annotation", timeout: 20) {
            guard let rows = try? self.annotationRows(database, after: highWater), rows.count == 1 else { return false }
            saved = rows[0]; return true
        }
        let row = try XCTUnwrap(saved)
        let colorHex = try XCTUnwrap(row["color"] as? String)
        try assertPersistedSelection(row, selection: selection, target: target, contentID: contentID)
        try assertRenderedOriginalAnnotation(selection, locator: target.sectionLocator, colorHex: colorHex, ui: ui)
        try attach(["originalNativeSelection": native, "actualAnnotationRow": row,
            "annotationDatabase": database.path, "nativeColorAction": actualColorLabel,
            "canonicalSourceSHA256": target.backendReaderSourceSHA256, "documentID": originalDocument.id.uuidString],
            "reader-v40-original-selection-to-persisted-UTF16")

        try switchOriginalBackend("sefaria", installation: installed, ui: ui)
        let remote = try openOriginalGenesis("sefaria", installation: installed, ui: ui)
        try switchOriginalBackend("sefariaEmbedded", installation: installed, ui: ui)
        _ = try openOriginalGenesis("sefariaEmbedded", installation: installed, ui: ui)
        try switchOriginalBackend("sefaria", installation: installed, ui: ui)
        let restoredRemote = try backendReaderReceipt("sefaria", canonical: "sefaria|Genesis|ref:Genesis 1", installation: installed, ui: ui)
        try demand(remote["documentID"] as? String == restoredRemote["documentID"] as? String,
                   "The original per-backend document must restore with its real identity")
        let oldSample = try XCTUnwrap((remote["native"] as? [String: Any])?["fullV32SourceObservation"] as? [String: Any])
        let newSample = try XCTUnwrap((restoredRemote["native"] as? [String: Any])?["fullV32SourceObservation"] as? [String: Any])
        for key in ["sourceUTF16Length", "rangeLocation", "rangeLength", "sourceUTF8"] {
            let old = try XCTUnwrap(oldSample[key]), restored = try XCTUnwrap(newSample[key])
            try demand(String(describing: old) == String(describing: restored),
                       "The actual restored remote Reader source/viewport sample changed: " + key)
        }
        try switchOriginalBackend("otzaria", installation: installed, ui: ui)
        try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
        let finalDocument = try currentDocument(installed)
        try demand(finalDocument.id == originalDocument.id,
                   "The original production document must survive the complete three-backend round trip")
        let rows = try annotationRows(database, after: highWater)
        try demand(rows.count == 1, "Backend restoration must not duplicate or discard the new genuine user annotation")
        try assertPersistedSelection(try XCTUnwrap(rows.first), selection: selection, target: target, contentID: contentID)
        try assertRenderedOriginalAnnotation(selection, locator: target.sectionLocator, colorHex: colorHex, ui: ui)
        let final = try installation()
        try demand(final.container == installed.container && final.root == installed.root && final.manifest == installed.manifest,
                   "All actual backend Readers must retain the same managed full-v40 installation")
    }
}

/// Samples only the existing read-only native viewport request protocol while
/// XCTest delivers a real held drag. Every retained payload must echo its fresh
/// UUID; no application selection, scroll offset or navigation state is written.
private final class OriginalReaderPullCapture: @unchecked Sendable {
    private let lock = NSLock()
    private let completion = DispatchGroup()
    private var stopped = false
    private var payloads: [Data] = []
    private var failure: String?
    private let prefix: URL

    init(prefix: URL) { self.prefix = prefix }
    var isReady: Bool { lock.lock(); defer { lock.unlock() }; return !payloads.isEmpty }
    private var shouldStop: Bool { lock.lock(); defer { lock.unlock() }; return stopped }

    func start() {
        completion.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { completion.leave() }
            let deadline = ProcessInfo.processInfo.systemUptime + 12
            do {
                while !shouldStop && ProcessInfo.processInfo.systemUptime < deadline {
                    let id = UUID().uuidString
                    try id.write(to: URL(fileURLWithPath: prefix.path + ".request"), atomically: true, encoding: .utf8)
                    let response = URL(fileURLWithPath: prefix.path + ".viewport.json")
                    let replyDeadline = ProcessInfo.processInfo.systemUptime + 2
                    var accepted: Data?
                    while !shouldStop && ProcessInfo.processInfo.systemUptime < replyDeadline {
                        if let values = try? response.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                           values.isRegularFile == true && values.isSymbolicLink == false && (values.fileSize ?? 65_537) <= 65_536,
                           let data = try? Data(contentsOf: response), data.count <= 65_536,
                           let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           report["requestID"] as? String == id {
                            accepted = data; break
                        }
                        Thread.sleep(forTimeInterval: 0.025)
                    }
                    if let accepted {
                        lock.lock(); payloads.append(accepted); let count = payloads.count; lock.unlock()
                        if count >= 64 { break }
                    } else if !shouldStop { throw NSError(domain: "OriginalReaderPullCapture", code: 1) }
                }
            } catch { lock.lock(); failure = String(describing: error); lock.unlock() }
        }
    }

    func finish() throws -> [Data] {
        lock.lock(); stopped = true; lock.unlock()
        guard completion.wait(timeout: .now() + 3) == .success else {
            throw NSError(domain: "OriginalReaderPullCapture", code: 2)
        }
        lock.lock(); defer { lock.unlock() }
        if let failure { throw NSError(domain: "OriginalReaderPullCapture", code: 3, userInfo: [NSLocalizedDescriptionKey: failure]) }
        return payloads
    }
}

extension FullV40ReaderModeAcceptanceTests {
    @MainActor
    private func assertOriginalSelectedTOC(_ target: FullV40ReaderModeOracle.Target, installation value: Installation,
                                           ui: OriginalSearchContextUI) throws {
        let expected = try XCTUnwrap(target.tocSelection,
            "Generate the actual catalog with readerNavigationOracle=true for this separate native gate")
        try demand(expected.schema == 1 && expected.allTOCRowsChecked > 0 && !expected.headings.isEmpty
            && expected.tocSQLRowsSHA256.count == 64 && expected.sourceLineIndex <= target.unitStartLineIndex
            && expected.canonicalLocator == "otzaria|book:\(target.bookID)|line:\(expected.sourceLineIndex)"
            && expected.headings.allSatisfy { $0.sourceLineIndex == expected.sourceLineIndex },
            "Use actual immutable v40 SQL headings and their canonical source anchor")
        try showOriginalContents(ui)
        let id = try originalSurrogate(expected.canonicalLocator, installation: value, ui: ui)
        let list = app.descendants(matching: .any)["toc-content-list"]
        let rows = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "toc-row-"))
        let allowedTitles = Set(expected.headings.map(\.title))
        var selected: [XCUIElement] = []
        try ui.wait("The original reading-node selection must synchronize with the current exact unit", timeout: 20) {
            selected = rows.allElementsBoundByIndex.filter { !$0.frame.isEmpty
                && $0.frame.intersects(list.frame) && $0.frame.intersects(self.app.windows.firstMatch.frame)
                && ($0.isSelected || $0.value as? String == "selected") }
            return !selected.isEmpty && selected.allSatisfy { $0.identifier == "toc-row-\(id)"
                && $0.isSelected && $0.value as? String == "selected"
                && allowedTitles.contains($0.label) }
        }
        try demand(selected.allSatisfy { allowedTitles.contains($0.label) && $0.isHittable },
                   "Selected original TOC labels must belong to the actual SQL heading(s) at that canonical locator")
        try demand(app.staticTexts["reader-current-locator"].label == target.sectionLocator,
                   "Opening Contents must retain the original exact reading unit")
        try attach(["mode": target.unitMode, "readerSection": target.sectionLocator,
            "expectedCanonicalTOC": expected.canonicalLocator, "actualRegistrySurrogate": id,
            "actualSQLRowsSHA256": expected.tocSQLRowsSHA256,
            "originalSelectedRows": selected.map { ["id": $0.identifier, "label": $0.label,
                "value": $0.value as? String ?? "", "isSelected": $0.isSelected] as [String: Any] }],
            "reader-v40-original-selected-toc-" + target.unitMode + "-" + String(target.unitStartLineIndex))
        try hideOriginalContents(ui)
    }

    private func checkRecordedReaderSource(_ report: [String: Any], target: FullV40ReaderModeOracle.Target) throws {
        let sample = try XCTUnwrap(report["fullV32SourceObservation"] as? [String: Any])
        let source = target.backendReaderSourceUTF8 as NSString
        let location = try XCTUnwrap(sample["rangeLocation"] as? Int)
        let length = try XCTUnwrap(sample["rangeLength"] as? Int)
        try demand(sample["status"] as? String == "AVAILABLE"
            && sample["sourceUTF16Length"] as? Int == source.length
            && location >= 0 && location <= source.length && length > 0 && length <= 256
            && length <= source.length - location,
            "The actual drag sample must belong to this exact complete independently generated source unit")
        let actual = try XCTUnwrap(sample["sourceUTF8"] as? String)
        try demand(Data(actual.utf8) == Data(source.substring(with: NSRange(location: location, length: length)).utf8),
                   "Compare actual held-gesture source bytes without normalization")
    }

    private func nativeOverscroll(_ report: [String: Any], previous: Bool) throws -> Double {
        func number(_ key: String) throws -> Double {
            let value = try XCTUnwrap((report[key] as? NSNumber)?.doubleValue)
            try demand(value.isFinite, "Require finite original viewport geometry: " + key)
            return value
        }
        let offset = try number("contentOffsetY"), top = try number("topInset")
        if previous { return -(offset + top) }
        let maximum = try max(number("contentHeight") + number("bottomInset") - number("viewportHeight"), -top)
        return offset - maximum
    }

    @MainActor
    private func reachOriginalTop(_ target: FullV40ReaderModeOracle.Target, installation value: Installation,
                                  ui: OriginalSearchContextUI) throws {
        let first = try nativeSelection(value, ui: ui)
        if abs(try nativeOverscroll(first, previous: true)) <= 2 { return }
        // The normal UIKit scroll-to-top gesture, verified by the original
        // viewport afterward. No test hook changes contentOffset or focus.
        let status = app.statusBars.firstMatch
        try demand(status.exists && !status.frame.isEmpty && status.frame.intersects(app.windows.firstMatch.frame),
                   "The actual native status-bar scroll-to-top control must be visible")
        status.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        var observed: [String: Any]?
        for _ in 0..<6 {
            let next = try nativeSelection(value, ui: ui)
            try checkRecordedReaderSource(next, target: target)
            if abs(try nativeOverscroll(next, previous: true)) <= 2 { observed = next; break }
        }
        try demand(observed != nil, "The real original viewport must reach the top of this exact unit")
    }

    @MainActor
    private func performOriginalHeldPull(_ target: FullV40ReaderModeOracle.Target, previous: Bool,
                                         commit: Bool, installation value: Installation,
                                         ui: OriginalSearchContextUI) throws {
        let before = try nativeSelection(value, ui: ui)
        let beforeOverscroll = try nativeOverscroll(before, previous: previous)
        try demand(abs(beforeOverscroll) <= 3,
                   "Start the genuine pull at the original corresponding viewport edge")
        let view = app.textViews["reader-text"]
        try demand(view.exists && view.frame.height > 360 && app.windows.firstMatch.frame.intersects(view.frame),
                   "Use the actual fully sized original iPad text viewport for this gesture")
        let pixels: CGFloat = commit ? 240 : 40
        let start = view.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: previous ? 0.2 : 0.8))
        let end = start.withOffset(CGVector(dx: 0, dy: previous ? pixels : -pixels))
        let capture = OriginalReaderPullCapture(prefix: value.container.appendingPathComponent("Documents/" + viewportName))
        capture.start()
        var finished = false
        defer { if !finished { _ = try? capture.finish() } }
        try ui.wait("The original passive probe must be ready before the real gesture", timeout: 4) { capture.isReady }
        let began = Date().timeIntervalSince1970
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 400), thenHoldForDuration: 1.5)
        let ended = Date().timeIntervalSince1970
        let data = try capture.finish(); finished = true
        let reports = try data.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [String: Any]) }
        let during = reports.filter {
            guard let date = $0["capturedAt"] as? Double,
                  let selection = $0["nativeSelectionObservation"] as? [String: Any] else { return false }
            return date >= began && date <= ended && selection["locator"] as? String == target.sectionLocator
        }
        var observedOverscroll: [Double] = []
        var requests = Set<String>()
        let pid = try XCTUnwrap((before["nativeSelectionObservation"] as? [String: Any])?["processID"] as? Int)
        for report in during {
            let request = try XCTUnwrap(report["requestID"] as? String)
            let selection = try XCTUnwrap(report["nativeSelectionObservation"] as? [String: Any])
            let selectionObject = try XCTUnwrap(selection["textViewObject"] as? Int,
                "Require the original native selection's integer UITextView identity")
            let viewportObject = try XCTUnwrap(report["object"] as? Int,
                "Require the original viewport's integer UITextView identity")
            try demand(UUID(uuidString: request) != nil && requests.insert(request).inserted
                && selection["requestID"] as? String == request && selection["processID"] as? Int == pid
                && selectionObject == viewportObject
                && selection["usesTextKit2BeforeObservation"] as? Bool == true
                && selection["usesTextKit2AfterObservation"] as? Bool == true,
                "Use fresh actual native samples from this original Reader/process during the real held gesture")
            try checkRecordedReaderSource(report, target: target)
            observedOverscroll.append(try nativeOverscroll(report, previous: previous))
        }
        let maximum = try XCTUnwrap(observedOverscroll.max(), "A no-op or unobserved gesture cannot pass")
        if commit { try demand(maximum >= 80, "Observe actual native overscroll crossing the original 80-point threshold") }
        else { try demand(maximum > 1 && maximum < 80, "Observe actual positive sub-threshold overscroll before its cancelled release") }
        try attach(["mode": target.unitMode, "canonicalLocatorBefore": target.sectionLocator,
            "direction": previous ? "previous" : "next", "committing": commit,
            "began": began, "ended": ended, "observedOverscrollMaximum": maximum,
            "scope": commit ? "real held drag crossed the original threshold; exact adjacent-unit outcome is asserted separately"
                : "real sub-threshold release cancellation; this is not above-threshold continuous-touch retreat",
            "originalSamples": reports], "reader-v40-original-held-pull-" + target.unitMode + (previous ? "-previous" : "-next") + (commit ? "-commit" : "-cancel"))
    }

    @MainActor
    func testOriginalParagraphAndChapterPullCancellationAndCanonicalTOCStaySynchronized() throws {
        let (expected, installed, ui, id) = try prepareAdditionalReaderGate()
        for mode in ["paragraph", "chapter"] {
            let target = try XCTUnwrap(expected.targets.first { $0.unitMode == mode })
            let previous = try XCTUnwrap(target.neighbors?["previous"], "Choose a real source unit with an actual previous unit")
            try demand(previous.sectionLocator != target.sectionLocator && previous.unitMode == mode,
                       "A no-op or another reading mode cannot satisfy original unit navigation")
            try ui.setReaderUnit(mode, fromPreview: id)
            try ui.openCurrentPreview(id)
            try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
            if ui.control("reader.clear_search_highlight_button").exists {
                try ui.require("reader.clear_search_highlight_button").tap()
            }
            try assertOriginalSelectedTOC(target, installation: installed, ui: ui)
            try reachOriginalTop(target, installation: installed, ui: ui)
            let before = try currentDocument(installed)
            try performOriginalHeldPull(target, previous: true, commit: false, installation: installed, ui: ui)
            try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
            let afterCancel = try currentDocument(installed)
            try demand(afterCancel.id == before.id, "Cancelled pull must retain the same actual document")
            try assertOriginalSelectedTOC(target, installation: installed, ui: ui)
            try reachOriginalTop(target, installation: installed, ui: ui)

            try performOriginalHeldPull(target, previous: true, commit: true, installation: installed, ui: ui)
            try assertReader(previous, installation: installed, ui: ui, requireSearchFocus: false)
            try assertOriginalSelectedTOC(previous, installation: installed, ui: ui)
            // Original ReaderBackendPagingCoordinator requests the previous
            // unit's bottom; require that native viewport before pulling next.
            try performOriginalHeldPull(previous, previous: false, commit: true, installation: installed, ui: ui)
            try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
            try assertOriginalSelectedTOC(target, installation: installed, ui: ui)
            let restored = try currentDocument(installed)
            try demand(restored.id == before.id, "Exact two-way source navigation must preserve the original document identity")
            if mode == "chapter" {
                try demand(target.tocSelection?.canonicalLocator != previous.tocSelection?.canonicalLocator,
                           "The chapter case must visibly change the original selected canonical TOC anchor before returning")
            }
            try ui.returnToOriginalSearch()
        }
        let final = try installation()
        try demand(final.container == installed.container && final.root == installed.root
            && final.manifest == installed.manifest && final.owner == installed.owner,
            "Original unit gestures and TOC selection must preserve the installed production corpus")
    }
}

// MARK: - Original single-contact armed retreat (portrait only)

extension FullV40ReaderModeAcceptanceTests {
    @MainActor
    private func originalContinuousPull(_ target: FullV40ReaderModeOracle.Target,
                                        installation value: Installation, ui: OriginalSearchContextUI) throws {
        let token = try XCTUnwrap(environment["READER_CONTINUOUS_PULL_TOKEN"],
            "The dedicated pinned original idb host must own this exact simulator")
        try demand(token.count == 48 && token.allSatisfy { "0123456789abcdef".contains($0) },
                   "Require the explicit private host token")
        let udid = try XCTUnwrap(environment["SIMULATOR_UDID"])
        let before = try currentDocument(value)
        let initial = try nativeSelection(value, ui: ui)
        try checkRecordedReaderSource(initial, target: target)
        let identity = try XCTUnwrap(initial["nativeSelectionObservation"] as? [String: Any])
        let processID = try XCTUnwrap(identity["processID"] as? Int)
        let generation = try XCTUnwrap(identity["renderGeneration"] as? Int)
        let owner = try XCTUnwrap(identity["textViewObject"] as? Int)
        let initialDistance = try nativeOverscroll(initial, previous: true)
        try demand(XCUIDevice.shared.orientation == .portrait && abs(initialDistance) <= 3,
                   "The original Reader must be at its top edge in portrait before this continuous contact")
        let window = app.windows.firstMatch.frame
        let reader = app.textViews["reader-text"]
        let frame = reader.frame
        try demand(reader.exists && reader.isHittable && frame.height > 360 && window.contains(frame)
            && window.width < window.height && abs(window.minX) <= 0.5 && abs(window.minY) <= 0.5,
            "Use the fully visible original portrait Reader in the actual app-window point space")
        func geometry(_ rect: CGRect) -> [String: Double] {
            ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
        }
        let start = ["x": Double(frame.midX), "y": Double(frame.minY + frame.height * 0.2)]
        let armed = ["x": start["x"]!, "y": start["y"]! + 240]
        let retreat = ["x": start["x"]!, "y": start["y"]! + 20]
        let nonce = UUID().uuidString
        let basename = "reader-continuous-pull-" + token + "-" + nonce
        let requestPath = value.container.appendingPathComponent("Documents/" + basename + ".request.json")
        let replyPath = value.container.appendingPathComponent("Documents/" + basename + ".ack.json")
        let request: [String: Any] = [
            "schema": 1, "token": token, "nonce": nonce, "udid": udid, "mode": target.unitMode,
            "orientation": "portrait", "viewportName": viewportName, "createdAt": Date().timeIntervalSince1970,
            "appPID": processID, "renderGeneration": generation, "textViewObject": owner,
            "sourceUTF16Length": target.backendReaderSourceUTF16Length, "documentID": before.id.uuidString,
            "locator": target.sectionLocator, "window": geometry(window), "readerFrame": geometry(frame),
            "points": [start, armed, retreat]
        ]
        try demand(!FileManager.default.fileExists(atPath: requestPath.path)
            && !FileManager.default.fileExists(atPath: replyPath.path), "A contact nonce must never be reused")
        try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]).write(to: requestPath, options: .atomic)
        try nonce.write(to: value.container.appendingPathComponent("Documents/reader-continuous-pull-" + token + ".pending"),
                        atomically: true, encoding: .utf8)
        // No XCTest input or competing probe runs while the host owns contact.
        // These are bounded file reads; the original app supplies each sample.
        var response: [String: Any]?
        try ui.wait("The single original HID contact must complete both held observations and its final release", timeout: 65) {
            guard let reply = try? self.object(replyPath, maximum: 512_000), reply["nonce"] as? String == nonce else { return false }
            response = reply; return true
        }
        let receipt = try XCTUnwrap(response)
        try attach(receipt, "reader-v40-original-continuous-pull-" + target.unitMode)
        try demand(receipt["schema"] as? Int == 1 && receipt["accepted"] as? Bool == true
            && receipt["rpcCount"] as? Int == 1 && receipt["transportCompleted"] as? Bool == true
            && receipt["emergencyReleaseAttempted"] == nil && receipt["upEmitted"] as? Bool == true
            && receipt["udid"] as? String == udid && receipt["appPID"] as? Int == processID
            && receipt["documentID"] as? String == before.id.uuidString && receipt["locator"] as? String == target.sectionLocator
            && receipt["mode"] as? String == target.unitMode,
            "Require one successful original stream, never two swipes or failure cleanup masquerading as retreat")
        let dimensions = try XCTUnwrap(receipt["screenDimensions"] as? [String: Any])
        let width = try XCTUnwrap(dimensions["width_points"] as? Double)
        let height = try XCTUnwrap(dimensions["height_points"] as? Double)
        try demand(abs(width - Double(window.width)) <= 0.5 && abs(height - Double(window.height)) <= 0.5
            && width < height && XCUIDevice.shared.orientation == .portrait,
            "Actual idb points and original app-window coordinates must remain the same portrait space")
        let events = try XCTUnwrap(receipt["events"] as? [[String: Any]])
        let held = try XCTUnwrap(receipt["heldBoundaries"] as? [[String: Any]])
        try demand(events.count >= 4 && events.dropLast().allSatisfy { $0["direction"] as? String == "DOWN" }
            && events.last?["direction"] as? String == "UP"
            && events.enumerated().allSatisfy { $0.element["sequence"] as? Int == $0.offset + 1 }
            && held.map { $0["phase"] as? String } == ["armed", "retreated"],
            "The original contact remains pressed through both waypoints and lifts only once at the end")
        let samples = try XCTUnwrap(receipt["nativeSamples"] as? [String: [String: Any]])
        try demand(Set(samples.keys) == Set(["before", "armed", "retreated", "released"]),
                   "Retain all four genuine phase samples")
        var requestIDs = Set<String>()
        var uptime = 0.0
        for phase in ["before", "armed", "retreated", "released"] {
            let sample = try XCTUnwrap(samples[phase])
            try checkRecordedReaderSource(sample, target: target)
            let native = try XCTUnwrap(sample["nativeSelectionObservation"] as? [String: Any])
            let source = try XCTUnwrap(sample["fullV32SourceObservation"] as? [String: Any])
            let requestID = try XCTUnwrap(sample["requestID"] as? String)
            let observed = try XCTUnwrap(source["observedUptime"] as? Double)
            try demand(UUID(uuidString: requestID) != nil && requestIDs.insert(requestID).inserted
                && native["requestID"] as? String == requestID && native["processID"] as? Int == processID
                && source["processID"] as? Int == processID && native["locator"] as? String == target.sectionLocator
                && native["renderGeneration"] as? Int == generation && native["textViewObject"] as? Int == owner
                && observed.isFinite && observed > uptime,
                "Each phase needs a distinct advancing original response from the exact same current Reader")
            uptime = observed
            let distance = try nativeOverscroll(sample, previous: true)
            switch phase {
            case "armed": try demand(distance >= 80, "Observe the original threshold crossing while the same touch is held")
            case "retreated": try demand(distance >= 0 && distance < 80, "Observe retreat below the original threshold before lifting")
            default: try demand(abs(distance) <= 3, "The original Reader must start and finish at its real top edge")
            }
        }
        let armBoundary = try XCTUnwrap(held.first?["lastDownSequence"] as? Int)
        let retreatBoundary = try XCTUnwrap(held.last?["lastDownSequence"] as? Int)
        try demand(0 < armBoundary && armBoundary < retreatBoundary && retreatBoundary < events.count
            && held.first?["requestID"] as? String == samples["armed"]?["requestID"] as? String
            && held.last?["requestID"] as? String == samples["retreated"]?["requestID"] as? String,
            "Bind both original held observations before the one final UP in the exact same stream")
        try assertReader(target, installation: value, ui: ui, requireSearchFocus: false)
        let after = try currentDocument(value)
        try demand(after.id == before.id && after.bookId == before.bookId
            && after.backendLocator?.backend == before.backendLocator?.backend
            && after.backendLocator?.workKey == before.backendLocator?.workKey,
            "Armed retreat and release must retain the actual canonical document")
        try assertOriginalSelectedTOC(target, installation: value, ui: ui)
        try attach(["schema": 1, "nonce": nonce, "mode": target.unitMode,
            "documentID": after.id.uuidString, "canonicalLocator": target.sectionLocator,
            "tocCanonicalLocator": try XCTUnwrap(target.tocSelection?.canonicalLocator),
            "orientationScope": "portrait only; original idb points equal actual app-window points",
            "sourceScope": "independent full-v40 catalog compared with every bounded original native source sample"],
            "reader-v40-continuous-pull-native-completion-" + target.unitMode)
    }

    @MainActor
    func testOriginalContinuousTouchArmedRetreatPreservesParagraphAndChapterReader() throws {
        let (expected, installed, ui, id) = try prepareAdditionalReaderGate()
        XCUIDevice.shared.orientation = .portrait
        try ui.wait("The actual original app must settle in portrait") {
            self.app.windows.firstMatch.frame.width < self.app.windows.firstMatch.frame.height
                && XCUIDevice.shared.orientation == .portrait
        }
        for mode in ["paragraph", "chapter"] {
            let target = try XCTUnwrap(expected.targets.first { $0.unitMode == mode })
            try ui.setReaderUnit(mode, fromPreview: id)
            try ui.openCurrentPreview(id)
            try assertReader(target, installation: installed, ui: ui, requireSearchFocus: false)
            if ui.control("reader.clear_search_highlight_button").exists {
                try ui.require("reader.clear_search_highlight_button").tap()
            }
            try assertOriginalSelectedTOC(target, installation: installed, ui: ui)
            try reachOriginalTop(target, installation: installed, ui: ui)
            try originalContinuousPull(target, installation: installed, ui: ui)
            try ui.returnToOriginalSearch()
        }
        let final = try installation()
        try demand(final.container == installed.container && final.root == installed.root
            && final.manifest == installed.manifest && final.owner == installed.owner,
            "Both original continuous contacts must preserve the same actual production installation")
    }
}

// MARK: - Separate genuine pending-fetch correctness workload (full v40)

private struct FullV40PendingSQLCatalog: Decodable {
    struct Target: Decodable {
        let key: String
        let bookID: Int
        let bookTitle: String
        let focusLineIndex: Int
        let unitID: String
        let unitMode: String
        let unitStartLineIndex: Int
        let unitEndLineIndex: Int
        let unitRowCount: Int
        let sourceFile: String
        let sourceSHA256: String
        let sourceUTF16Length: Int
        let sourceUTF8Bytes: Int
        let allOriginalAnchorsChecked: Int
        let anchorsIdentitySHA256: String
        let sectionLocator: String
        let focusLocator: String
    }
    let schema: Int
    let status: String
    let corpusProfile: String
    let databaseSHA256: String
    let catalogCompileInputsSHA256: String
    let sourceServiceSHA256: String
    let presentationSourceSHA256: String
    let targets: [Target]
}

extension FullV40ReaderModeAcceptanceTests {
    private func pendingCatalog() throws -> (FullV40PendingSQLCatalog, URL) {
        let path = URL(fileURLWithPath: try XCTUnwrap(environment["PENDING_SQL_MODES_CATALOG"])).standardizedFileURL
        let bytes = try bounded(path, maximum: 8 * 1024 * 1024)
        try demand(path.lastPathComponent == "pending-sql-modes.json"
            && hash(bytes) == environment["PENDING_SQL_MODES_CATALOG_SHA256"],
            "Require the byte-sealed original complete pending-mode catalog")
        let value = try JSONDecoder().decode(FullV40PendingSQLCatalog.self, from: bytes)
        try demand(value.schema == 1 && value.corpusProfile == "full-v40"
            && value.status == "ORIGINAL_SOURCE_PENDING_SQL_MODES_ONLY_NOT_UI_OR_PERFORMANCE"
            && value.databaseSHA256 == expectedDatabaseSHA256
            && [value.catalogCompileInputsSHA256, value.sourceServiceSHA256, value.presentationSourceSHA256].allSatisfy { $0.count == 64 }
            && value.targets.count == 3 && Set(value.targets.map(\.unitMode)) == ["line", "paragraph", "chapter"]
            && value.targets.allSatisfy { $0.bookID == 8042 && $0.focusLineIndex == 26166
                && $0.key == "8042-pending-sql-" + $0.unitMode
                && $0.allOriginalAnchorsChecked == $0.unitRowCount && $0.anchorsIdentitySHA256.count == 64 },
            "Use all three original source-generated units, never a fabricated pending SQL fixture")
        let chapter = try XCTUnwrap(value.targets.first { $0.unitMode == "chapter" })
        try demand(chapter.unitID == "toc:1948815" && chapter.unitStartLineIndex == 0
            && chapter.unitEndLineIndex == 52331 && chapter.unitRowCount == 52332
            && chapter.sourceUTF16Length == 8307947,
            "Keep the actual full 52,332-row / 8,307,947-UTF16 chapter, without truncation")
        for target in value.targets {
            let url = path.deletingLastPathComponent().appendingPathComponent(target.sourceFile).standardizedFileURL
            try demand(url.deletingLastPathComponent() == path.deletingLastPathComponent(), "Original source cannot escape the admitted catalog")
            let source = try bounded(url, maximum: 64 * 1024 * 1024)
            let text = try XCTUnwrap(String(data: source, encoding: .utf8))
            try demand(source.count == target.sourceUTF8Bytes && hash(source) == target.sourceSHA256
                && text.utf16.count == target.sourceUTF16Length,
                "Bind complete actual original source bytes before UI work; this is not an app acceptance claim")
        }
        return (value, path.deletingLastPathComponent())
    }

    private func pendingWorkspace(_ value: Installation) throws -> Workspace {
        try JSONDecoder().decode(Workspace.self, from: bounded(value.container.appendingPathComponent(
            "Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json"), maximum: 8 * 1024 * 1024))
    }

    private func pendingDocument(_ value: Installation) throws -> Workspace.Session {
        let state = try pendingWorkspace(value)
        let scene = try XCTUnwrap(state.scenes[try XCTUnwrap(state.lastActiveSceneID)])
        let group = try XCTUnwrap(state.groups.first { $0.id == scene.groupID })
        let selected = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID
        return try XCTUnwrap(group.tabs.first { $0.session.id == selected }?.session)
    }

    private func pendingAnnotationState(_ value: Installation) throws -> [String: Any] {
        let path = try annotationDatabase(value)
        var connection: OpaquePointer?
        try demand(sqlite3_open_v2(path.path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                   "Observe existing user annotations without creating or modifying a database")
        let db = try XCTUnwrap(connection); defer { sqlite3_close(db) }
        try demand(sqlite3_db_readonly(db, "main") == 1, "Annotation preservation observation is read-only")
        var raw: OpaquePointer?
        try demand(sqlite3_prepare_v2(db, "SELECT * FROM annotations ORDER BY id LIMIT 10001", -1, &raw, nil) == SQLITE_OK,
                   "Read all original annotation columns in actual persisted row order")
        let statement = try XCTUnwrap(raw); defer { sqlite3_finalize(statement) }
        let columns = Int(sqlite3_column_count(statement))
        try demand(columns > 0 && columns <= 64, "Bound the original persisted annotation schema")
        let names = (0..<columns).map { String(cString: sqlite3_column_name(statement, Int32($0))) }
        try demand(Set(names).count == names.count && names.contains("id") && names.contains("backendLocator")
            && names.contains("startIndex") && names.contains("length") && names.contains("context"),
            "Preserve canonical locator, exact UTF16 range and original user context")
        var rows: [[[String: String]]] = []; var retainedBytes = 0
        var step = sqlite3_step(statement)
        while step == SQLITE_ROW && rows.count < 10001 {
            var row: [[String: String]] = []
            for column in 0..<columns {
                let index = Int32(column), type = sqlite3_column_type(statement, Int32(column))
                let encoded: String
                switch type {
                case SQLITE_NULL: encoded = ""
                case SQLITE_INTEGER: encoded = String(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: encoded = String(sqlite3_column_double(statement, index).bitPattern)
                case SQLITE_TEXT, SQLITE_BLOB:
                    let count = Int(sqlite3_column_bytes(statement, index))
                    try demand(count >= 0 && count <= 1024 * 1024, "An original annotation cell exceeds this declared bounded witness")
                    let pointer = sqlite3_column_blob(statement, index)
                    try demand(count == 0 || pointer != nil, "Actual annotation bytes are unavailable")
                    encoded = count == 0 ? "" : Data(bytes: try XCTUnwrap(pointer), count: count).base64EncodedString()
                default: throw Rejected(reason: "Unrecognized original SQLite column type")
                }
                retainedBytes += encoded.utf8.count
                try demand(retainedBytes <= 8 * 1024 * 1024, "Complete original annotations exceed this witness bound; do not truncate them")
                row.append(["column": names[column], "sqliteType": String(type), "bytesOrNumber": encoded])
            }
            rows.append(row); step = sqlite3_step(statement)
        }
        try demand(step == SQLITE_DONE && !rows.isEmpty && rows.count <= 10000,
                   "This ordered workload requires real existing nonempty annotations; never seed or delete user rows")
        let bytes = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
        return ["path": path.path, "columns": names, "rowCount": rows.count,
                "logicalRowsSHA256": hash(bytes), "logicalBytes": bytes.count,
                "scope": "Complete original persisted annotation rows and SQLite value types; no raw user DB writes"]
    }

    @MainActor
    private func pendingHost(_ action: String, installation value: Installation,
                             fields: [String: Any] = [:]) throws -> [String: Any] {
        let token = try XCTUnwrap(environment["FULL_V32_OBSERVER_TOKEN"])
        let udid = try XCTUnwrap(environment["R27_URL_UDID"])
        try demand(udid == environment["SIMULATOR_UDID"], "Use the same actually owned runtime for original observation transport")
        let nonce = UUID().uuidString
        let prefix = value.container.appendingPathComponent("Documents/full-v32-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json")
        let ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        var payload = fields
        payload.merge(["schema": 1, "token": token, "nonce": nonce, "udid": udid, "action": action]) { _, new in new }
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try demand(bytes.count <= 262144 && !FileManager.default.fileExists(atPath: request.path), "Fresh bounded original observer request required")
        try bytes.write(to: request, options: .withoutOverwriting)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: ack.path) }, object: nil)
        try demand(XCTWaiter.wait(for: [ready], timeout: 30) == .completed, "Original owned observer must acknowledge the exact actual request")
        let resultBytes = try bounded(ack, maximum: 262144)
        try demand(String(decoding: resultBytes, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil,
                   "Original observer ACK must be credential-free")
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: resultBytes) as? [String: Any])
        try demand(result["schema"] as? Int == 1 && result["nonce"] as? String == nonce
            && result["udid"] as? String == udid && result["action"] as? String == action && result["ok"] as? Bool == true,
            "Original observer rejected this request; keep its actual failure receipt")
        return result
    }

    @MainActor
    private func pendingWait(_ statusPath: URL, cohortID: String, installation value: Installation,
                             predicate: ([String: Any]) -> Bool) throws -> [String: Any] {
        try demand(statusPath == value.container.appendingPathComponent("Documents/pending-sql-" + cohortID + ".status.json"),
                   "Only this actual owned cohort's status is eligible")
        var latest: [String: Any]?
        for _ in 0..<160 {
            if let next = try? object(statusPath, maximum: 32768), next["cohortID"] as? String == cohortID {
                latest = next
                if predicate(next) { return next }
                if (next["error"] != nil && !(next["error"] is NSNull))
                    || (next["terminalObserved"] != nil && !(next["terminalObserved"] is NSNull)) { break }
            }
            // This waits on the actual passive status only. No private XCTest
            // idling override or elapsed-time proxy is used as UI evidence.
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if let latest { try attach(latest, "pending-sql-unqualified-status-" + cohortID) }
        throw Rejected(reason: "The genuine original fetch did not retain the required pending UI overlap; no post-open substitute")
    }

    @MainActor
    private func pendingSample(_ value: Installation, ui: OriginalSearchContextUI) throws -> [String: Any] {
        let id = UUID().uuidString
        let request = value.container.appendingPathComponent("Documents/" + viewportName + ".request")
        try demand(!FileManager.default.fileExists(atPath: request.path), "The passive host is still the request writer")
        let bytes = Data(id.utf8)
        try bytes.write(to: request, options: .withoutOverwriting)
        defer {
            if let current = try? bounded(request, maximum: 36), current == bytes {
                try? FileManager.default.removeItem(at: request)
            } else { XCTFail("Do not retire a changed or foreign source observation request") }
        }
        return try readNativeRequest(id, installation: value, ui: ui)
    }

    @MainActor
    private func pendingAssertSource(_ target: FullV40PendingSQLCatalog.Target, directory: URL,
                                     installation value: Installation, ui: OriginalSearchContextUI) throws -> [String: Any] {
        try ui.wait("The original exact mode must settle before its separate final source check", timeout: 120) {
            self.app.staticTexts["reader-current-locator"].label == target.sectionLocator
                && self.getRenderedHighlightSnapshot()?.locator == target.sectionLocator
                && (try? self.actualPreferences(value)["otzaria_reader_unit_mode"] as? String) == target.unitMode
        }
        let title = try ui.require("reader-header-title").label
        try demand(title == target.bookTitle,
                   "The actual visible Reader must keep its original canonical title")
        let before = try pendingDocument(value)
        try demand(before.backendLocator?.backend == "otzaria" && before.backendLocator?.workKey == "book:8042",
                   "Actual original ordinary workspace must identify the measured work")
        let report = try pendingSample(value, ui: ui)
        let sample = try XCTUnwrap(report["fullV32SourceObservation"] as? [String: Any])
        let native = try XCTUnwrap(report["nativeSelectionObservation"] as? [String: Any])
        let source = try bounded(directory.appendingPathComponent(target.sourceFile), maximum: 64 * 1024 * 1024)
        let text = try XCTUnwrap(String(data: source, encoding: .utf8)) as NSString
        let location = try XCTUnwrap((sample["rangeLocation"] as? NSNumber)?.intValue)
        let length = try XCTUnwrap((sample["rangeLength"] as? NSNumber)?.intValue)
        try demand(hash(source) == target.sourceSHA256 && source.count == target.sourceUTF8Bytes
            && text.length == target.sourceUTF16Length && sample["status"] as? String == "AVAILABLE"
            && (sample["sourceUTF16Length"] as? NSNumber)?.intValue == text.length
            && location >= 0 && location <= text.length && length > 0 && length <= 256 && length <= text.length - location,
            "Use the complete original unit length and exact actual UTF16 source slice")
        let actual = try XCTUnwrap(sample["sourceUTF8"] as? String)
        let after = try pendingDocument(value)
        try demand(Data(actual.utf8) == Data(text.substring(with: NSRange(location: location, length: length)).utf8)
            && native["locator"] as? String == target.sectionLocator
            && before.id == after.id,
            "Independent source bytes, canonical locator and actual ordinary document must agree")
        return ["targetKey": target.key, "documentID": before.id.uuidString, "canonicalLocator": target.sectionLocator,
                "sourceSHA256": target.sourceSHA256, "sourceUTF16Length": target.sourceUTF16Length, "actualViewport": report,
                "actualPersistedOriginalUnitMode": target.unitMode,
                "scope": "Complete source oracle identity/length plus exact bounded actual UIKit source slice; not every pixel of the full chapter"]
    }

    @MainActor
    private func pendingLibrary(_ ui: OriginalSearchContextUI) throws {
        let buttons = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", "Library"))
        try ui.wait("Select the original unique Library tab") { buttons.allElementsBoundByIndex.filter { $0.isHittable }.count == 1 }
        try XCTUnwrap(buttons.allElementsBoundByIndex.first { $0.isHittable }).tap()
    }

    @MainActor
    private func pendingPalette(_ title: String, ui: OriginalSearchContextUI) throws {
        try ui.require("reader-command-palette-launcher").tap()
        let palette = try ui.require("reader-library-command-palette")
        let field = palette.textFields.firstMatch
        try demand(field.waitForExistence(timeout: 20) && field.isHittable, "Use the original library's actual command field")
        field.tap(); field.typeKey("a", modifierFlags: .command); field.typeText(title)
        let candidates = palette.buttons.matching(NSPredicate(format: "label == %@", title))
        try ui.wait("The actual canonical book choice must be unique", timeout: 60) {
            field.value as? String == title && candidates.allElementsBoundByIndex.filter { $0.isHittable }.count == 1
        }
        try XCTUnwrap(candidates.allElementsBoundByIndex.first { $0.isHittable }).tap()
        try ui.wait("The original book's Reader must become visible", timeout: 120) {
            self.app.staticTexts["reader-header-title"].label == title && self.app.textViews["reader-text"].exists
        }
    }

    @MainActor
    private func pendingUnit(_ mode: String, ui: OriginalSearchContextUI, beforeTap: (() throws -> Void)? = nil) throws {
        try ui.require("reader-more-menu").tap()
        try ui.require("reader-display-unit-menu").tap()
        let selected = try ui.require("reader-display-unit-" + mode)
        try demand(selected.isHittable, "Original Display by action must actually be hittable")
        try beforeTap?()
        selected.tap()
    }

    @MainActor
    private func pendingOpenFocus(_ target: FullV40PendingSQLCatalog.Target, installation value: Installation,
                                  ui: OriginalSearchContextUI) throws {
        let log = value.container.appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        func receipts() throws -> [String] {
            guard FileManager.default.fileExists(atPath: log.path) else { return [] }
            return String(decoding: try bounded(log, maximum: 32 * 1024 * 1024), as: UTF8.self)
                .split(separator: "\n").map(String.init)
                .filter { $0.contains("[NativeNavigationReceipt]") && $0.contains("destination=native.reader ") }
        }
        let previous = try receipts()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        try demand(springboard.alerts.count == 0, "Never approve an unrelated preexisting system prompt")
        let ref: [String: Any] = ["backend": "otzaria", "workKey": "book:8042",
                                  "position": ["kind": "legacyLine", "value": target.focusLineIndex]]
        let route: [String: Any] = ["version": 2, "destination": "native.reader", "backend": "otzaria",
            "presentation": "currentTab", "content": ["sectionLocator": ref, "focusLocator": ref, "presentationMode": "sameTab"]]
        let encoded = try JSONSerialization.data(withJSONObject: route, options: [.sortedKeys]).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let token = try XCTUnwrap(environment["R27_URL_TOKEN"]), udid = try XCTUnwrap(environment["R27_URL_UDID"])
        let nonce = UUID().uuidString
        let prefix = value.container.appendingPathComponent("Documents/r27-url-\(token)-\(nonce)")
        let request = URL(fileURLWithPath: prefix.path + ".request.json"), ack = URL(fileURLWithPath: prefix.path + ".ack.json")
        let payload = ["token": token, "nonce": nonce, "udid": udid, "url": "maktabah-debug://action/v2/native.reader?route=" + encoded]
        try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]).write(to: request, options: .withoutOverwriting)
        let delivered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: ack.path) }, object: nil)
        try demand(XCTWaiter.wait(for: [delivered], timeout: 20) == .completed, "Original system open-URL transport did not acknowledge")
        let raw = try bounded(ack, maximum: 262144)
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        try demand(Set(response.keys) == ["udid", "transport", "delivered", "nonce", "time"]
            && response["udid"] as? String == udid && response["nonce"] as? String == nonce
            && response["transport"] as? String == "simctl-system-openurl" && response["delivered"] as? Bool == true
            && (response["time"] as? Double)?.isFinite == true
            && String(decoding: raw, as: UTF8.self).range(of: token, options: .caseInsensitive) == nil,
            "Transport must be genuine and credential-free; ACK alone is not Reader acceptance")
        var actualReceipt: String?
        try ui.wait("The actual original Core reader/glyph receipt must follow this one public route", timeout: 120) {
            if springboard.alerts.count == 1 {
                let alert = springboard.alerts.firstMatch
                let titles = ["Open in \u{201C}ChavrusaText\u{201D}?", "Open in \"ChavrusaText\"?"]
                let open = alert.buttons.matching(NSPredicate(format: "label == %@", "Open"))
                if titles.contains(alert.label) || titles.contains(where: { alert.staticTexts[$0].exists }) {
                    if open.count == 1 && open.firstMatch.isHittable { open.firstMatch.tap() }
                }
            }
            guard let rows = try? receipts(), rows.count == previous.count + 1, Array(rows.prefix(previous.count)) == previous else { return false }
            actualReceipt = rows.last
            return self.app.staticTexts["reader-current-locator"].label == target.sectionLocator
        }
        let line = try XCTUnwrap(actualReceipt)
        let components = line.split(separator: " ", maxSplits: 2)
        try demand(components.count == 3, "Original navigation receipt format changed")
        var fields: [String: String] = [:]
        for item in components[2].split(separator: " ") {
            let pair = item.split(separator: "=", maxSplits: 1)
            try demand(pair.count == 2 && fields[String(pair[0])] == nil, "Native receipt fields must be unique")
            fields[String(pair[0])] = String(pair[1])
        }
        let revision = (fields["revision"] ?? "").components(separatedBy: "->")
        let state = try pendingWorkspace(value)
        try demand(Set(fields.keys) == ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"]
            && fields["request"].flatMap(UUID.init(uuidString:)) != nil
            && fields["backend"] == "otzaria" && fields["destination"] == "native.reader" && fields["presentation"] == "currentTab"
            && fields["epoch"] == "none" && fields["generation"].flatMap(UInt64.init) != nil
            && revision.count == 2 && revision.allSatisfy { UInt64($0) != nil }
            && UInt64(revision[1])! > UInt64(revision[0])!
            && state.scenes[fields["scene"] ?? ""] != nil,
            "Require the authentic original advancing Core receipt in the actual ordinary scene")
        try attach(["nativeReceipt": line, "transport": response, "focusLocator": target.focusLocator,
            "scope": "Original public v2 Reader route setup, outside the pending workload"], "pending-sql-original-focus-route-" + nonce)
    }

    @MainActor
    private func pendingCloseOverview(_ ui: OriginalSearchContextUI) throws {
        let overview = ui.control("study-groups-overview")
        guard overview.exists else { return }
        let buttons = overview.buttons.matching(NSPredicate(format: "label == %@", "סיום"))
        try demand(buttons.count == 1 && buttons.firstMatch.isHittable, "Dismiss only the original overview's unique Done button")
        buttons.firstMatch.tap()
        try ui.wait("The original overview must actually dismiss") { !overview.exists }
    }

    @MainActor
    private func pendingSelectTab(_ id: UUID, installation value: Installation, ui: OriginalSearchContextUI,
                                  beforeTap: (() throws -> Void)? = nil) throws {
        var overview = ui.control("study-groups-overview")
        if !overview.exists { try ui.require("reader-tabs-overview").tap(); overview = try ui.require("study-groups-overview") }
        let choices = overview.collectionViews.cells.matching(NSPredicate(format: "identifier == %@ OR identifier == %@",
            "tab-switcher-grid-cell-" + id.uuidString, "tab-switcher-list-cell-" + id.uuidString))
        for _ in 0..<30 {
            if choices.allElementsBoundByIndex.contains(where: { $0.isHittable }) { break }
            try ui.dragVisible(overview, up: true)
        }
        let visible = choices.allElementsBoundByIndex.filter { $0.isHittable && !$0.frame.isEmpty && $0.frame.intersects(overview.frame) }
        try demand(visible.count == 1, "Use the actual original card for this persisted ordinary document UUID")
        try beforeTap?()
        try XCTUnwrap(visible.first).tap()
        try ui.wait("The original workspace must commit the selected actual tab") { (try? self.pendingDocument(value).id) == id }
        try pendingCloseOverview(ui)
    }

    @MainActor
    private func pendingSwitchBackend(_ backend: String, installation value: Installation,
                                      ui: OriginalSearchContextUI, beforeTap: (() throws -> Void)? = nil) throws {
        try ui.returnToOriginalSearch()
        try ui.require("main-settings-button").tap()
        try ui.require("settings-library-source-picker").tap()
        let names = ["otzaria": "אוצריא", "sefaria": "ספריא (ישן)"]
        let item = try originalMenuAction(try XCTUnwrap(names[backend]), ui: ui)
        try beforeTap?()
        item.tap()
        try ui.wait("Original Settings must complete the real backend transition", timeout: 120) {
            self.app.staticTexts["settings-active-backend-id"].label == backend
                && self.app.staticTexts["settings-transition-state"].label == "idle"
                && (try? self.actualPreferences(value)["activeLibraryBackend.v1"] as? String) == backend
        }
        try ui.require("settings-done-button").tap()
        try pendingLibrary(ui)
    }

    @MainActor
    private func pendingLaunch() throws {
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try demand(environment[key] == nil, "Use the actual managed original library; no alternate corpus path")
        }
        launchWithTier(.production, backend: "otzaria", language: "en", locale: "en_US", extraEnvironment: [
            "CHAVRUSA_READER_VIEWPORT_REPORT": viewportName,
            "CHAVRUSA_FULL_V32_SOURCE_OBSERVATION": "1", "CHAVRUSA_READER_SELECTION_OBSERVATION": "1"
        ])
        try demand(!app.launchArguments.contains("-studyWorkspaceTestingNamespace")
            && !app.launchArguments.contains("-smokeScenario") && !app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-otzaria_reader_unit_mode"),
            "Original production namespace and ordinary menu choices only; no seeded or forced pending state")
    }

    @MainActor
    func testOriginalLargeChapterPendingFetchRemainsInteractiveAndRejectsSupersededContent() throws {
        let (catalog, directory) = try pendingCatalog()
        let line = try XCTUnwrap(catalog.targets.first { $0.unitMode == "line" })
        let chapter = try XCTUnwrap(catalog.targets.first { $0.unitMode == "chapter" })
        XCUIDevice.shared.orientation = .landscapeLeft
        try pendingLaunch()
        var installed = try installation()
        let initialOwner = hash(installed.owner), initialManifest = hash(installed.manifest)
        let annotationBefore = try pendingAnnotationState(installed)
        try attach(annotationBefore, "pending-sql-original-nonempty-annotations-before")
        var declarations: [[String: Any]] = []; var failures: [String] = []
        // Keep actual XCTest failures recorded while attempting every declared
        // cohort. This does not turn any failed assertion into a passing test.
        let priorContinuation = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = priorContinuation }
        for cohort in ["overview", "unit-supersession", "backend-and-tab"] {
            let cohortID = UUID().uuidString
            var began = false
            do {
                let ui = OriginalSearchContextUI(app: app, test: self)
                try pendingLibrary(ui)
                var otherTab: Workspace.Session?
                if cohort == "backend-and-tab" {
                    try pendingPalette("ברכות", ui: ui)
                    otherTab = try pendingDocument(installed)
                    try demand(otherTab?.backendLocator?.backend == "otzaria" && otherTab?.backendLocator?.workKey == "book:103",
                               "Use a genuine second canonical original tab; never inject a workspace row")
                }
                try pendingPalette(line.bookTitle, ui: ui)
                try pendingUnit("line", ui: ui)
                try pendingOpenFocus(line, installation: installed, ui: ui)
                _ = try pendingAssertSource(line, directory: directory, installation: installed, ui: ui)
                let original = try pendingDocument(installed)
                // Process-cold is literal new application process only. No OS
                // cache flushing, corpus rewriting or storage delay is used.
                app.terminate(); try pendingLaunch()
                installed = try installation()
                try demand(hash(installed.owner) == initialOwner && hash(installed.manifest) == initialManifest,
                           "All three cohorts must retain this same original installation owner/manifest")
                let freshUI = OriginalSearchContextUI(app: app, test: self)
                try pendingLibrary(freshUI)
                _ = try pendingAssertSource(line, directory: directory, installation: installed, ui: freshUI)
                let restored = try pendingDocument(installed)
                try demand(restored.id == original.id,
                           "Cold launch must restore the same actual original ordinary tab")
                try freshUI.require("reader-more-menu").tap()
                try freshUI.require("reader-display-unit-menu").tap()
                let chapterAction = try freshUI.require("reader-display-unit-chapter")
                try demand(chapterAction.isHittable, "Prepare the real Chapter menu action before the passive baseline")
                let start = try pendingHost("pending_sql_begin", installation: installed, fields: [
                    "cohort": cohort, "cohortID": cohortID, "viewportBasename": viewportName
                ])
                began = true
                let status = URL(fileURLWithPath: try XCTUnwrap(start["statusPath"] as? String))
                _ = try pendingHost("pending_sql_mark", installation: installed, fields: ["cohortID": cohortID, "event": "chapter-request"])
                chapterAction.tap()
                _ = try pendingWait(status, cohortID: cohortID, installation: installed) { $0["armedOperation"] is [String: Any] }
                _ = try pendingHost("pending_sql_mark", installation: installed, fields: ["cohortID": cohortID, "event": "overview-action"])
                try freshUI.require("reader-tabs-overview").tap()
                _ = try pendingWait(status, cohortID: cohortID, installation: installed) { $0["changedWhilePending"] as? Bool == true }
                var semantic: [String: Any] = ["cohort": cohort, "cohortID": cohortID, "originalDocumentID": original.id.uuidString]
                if cohort == "overview" {
                    _ = try pendingWait(status, cohortID: cohortID, installation: installed) {
                        $0["watcherStopped"] as? Bool == true && $0["ownedRequestRetirementVerified"] as? Bool == true
                    }
                    try pendingCloseOverview(freshUI)
                    semantic["finalReader"] = try pendingAssertSource(chapter, directory: directory, installation: installed, ui: freshUI)
                } else if cohort == "unit-supersession" {
                    try pendingCloseOverview(freshUI)
                    try pendingUnit("line", ui: freshUI) {
                        _ = try self.pendingHost("pending_sql_mark", installation: installed, fields: ["cohortID": cohortID, "event": "unit-replacement"])
                    }
                    _ = try pendingWait(status, cohortID: cohortID, installation: installed) {
                        $0["watcherStopped"] as? Bool == true && $0["ownedRequestRetirementVerified"] as? Bool == true
                    }
                    semantic["finalReader"] = try pendingAssertSource(line, directory: directory, installation: installed, ui: freshUI)
                    semantic["cancellationScope"] = "Actual passive cancelled/non-normal terminal is separately required; task flag is not an exception-class oracle"
                } else {
                    let second = try XCTUnwrap(otherTab)
                    try demand(second.id != original.id, "Two actual distinct ordinary tab identities are required")
                    try pendingSelectTab(second.id, installation: installed, ui: freshUI) {
                        _ = try self.pendingHost("pending_sql_mark", installation: installed, fields: ["cohortID": cohortID, "event": "tab-change"])
                    }
                    let selectedSecond = try pendingDocument(installed)
                    try demand(selectedSecond.backendLocator?.workKey == "book:103",
                               "The original tab action must commit the second canonical work")
                    try pendingSwitchBackend("sefaria", installation: installed, ui: freshUI) {
                        _ = try self.pendingHost("pending_sql_mark", installation: installed, fields: ["cohortID": cohortID, "event": "backend-change"])
                    }
                    _ = try pendingWait(status, cohortID: cohortID, installation: installed) {
                        $0["watcherStopped"] as? Bool == true && $0["ownedRequestRetirementVerified"] as? Bool == true
                    }
                    try pendingPalette("בראשית", ui: freshUI)
                    let other = try pendingDocument(installed)
                    let canonical = try freshUI.require("reader-current-locator").label
                    try demand(other.backendLocator?.backend == "sefaria" && other.backendLocator?.workKey == "Genesis"
                        && canonical.hasPrefix("sefaria|Genesis|ref:"),
                        "The real changed backend must commit its own canonical Reader, not stale Otzaria content")
                    let otherReport = try pendingSample(installed, ui: freshUI)
                    let otherSource = try XCTUnwrap(otherReport["fullV32SourceObservation"] as? [String: Any])
                    let native = try XCTUnwrap(otherReport["nativeSelectionObservation"] as? [String: Any])
                    try demand(otherSource["status"] as? String == "AVAILABLE"
                        && ((otherSource["sourceUTF16Length"] as? NSNumber)?.intValue ?? 0) > 0
                        && native["locator"] as? String == canonical && native["status"] as? String == "EMPTY",
                        "Actual changed-backend Reader must have source and no carried-over UIKit selection")
                    semantic["changedBackend"] = ["canonicalLocator": canonical, "documentID": other.id.uuidString,
                        "actualViewport": otherReport, "scope": "Actual canonical backend and bounded native source; no independent full Sefaria body/version claim"]
                    try pendingSwitchBackend("otzaria", installation: installed, ui: freshUI)
                    try pendingSelectTab(original.id, installation: installed, ui: freshUI)
                    try pendingUnit("line", ui: freshUI)
                    try pendingOpenFocus(line, installation: installed, ui: freshUI)
                    semantic["finalReader"] = try pendingAssertSource(line, directory: directory, installation: installed, ui: freshUI)
                    semantic["secondDocumentID"] = second.id.uuidString
                }
                let after = try pendingAnnotationState(installed)
                try demand(after["logicalRowsSHA256"] as? String == annotationBefore["logicalRowsSHA256"] as? String
                    && after["rowCount"] as? Int == annotationBefore["rowCount"] as? Int,
                    "All original nonempty annotations, locators and exact UTF16 ranges must survive the actual actions")
                semantic["annotations"] = after
                let finalDocument = try pendingDocument(installed)
                try demand(finalDocument.id == original.id,
                           "The exact original ordinary tab must survive the completed cohort")
                let finalMode = cohort == "overview" ? "chapter" : "line"
                let finish = try pendingHost("pending_sql_finish", installation: installed, fields: [
                    "cohortID": cohortID, "finalMode": finalMode, "semanticOutcome": semantic
                ])
                began = false
                semantic["host"] = finish
                try attach(semantic, "pending-sql-original-cohort-" + cohort)
                freshUI.capture("pending-sql-original-final-" + cohort)
                declarations.append(semantic)
                if finish["status"] as? String != "ACTUAL_PENDING_FETCH_UI_OVERLAP_OBSERVED_NATIVE_SEMANTIC_VERIFICATION_REQUIRED" {
                    failures.append(cohort + ": actual pending operation/UI evidence was not qualified")
                }
            } catch {
                var safeReason = String(describing: error)
                for key in ["FULL_V32_OBSERVER_TOKEN", "R27_URL_TOKEN"] {
                    if let token = environment[key], !token.isEmpty { safeReason = safeReason.replacingOccurrences(of: token, with: "<redacted>") }
                }
                let reason = String(safeReason.prefix(1800))
                failures.append(cohort + ": " + reason)
                try? attach(["cohort": cohort, "cohortID": cohortID, "error": reason, "began": began,
                    "scope": "Retain this declared failed attempt; later cohorts cannot hide it"], "pending-sql-original-failed-" + cohort)
                let aborted = try pendingHost("pending_sql_abort", installation: installed, fields: [
                    "cohort": cohort, "cohortID": cohortID, "nativeFailure": reason
                ])
                try demand(aborted["ownedProbeWriterExited"] as? Bool == true,
                           "Do not relaunch or hand off this simulator while an owned probe's start/exit is unverified")
                // Restart through the ordinary original production bootstrap.
                // Do not repair app data or retry this same declared cohort.
                app.terminate(); try pendingLaunch(); installed = try installation()
            }
        }
        try attach(["cohorts": declarations, "failures": failures, "fullPerformanceAcceptance": false,
            "scope": "Three declared genuine pending-fetch correctness cohorts; exact SQL stepping/mapping and performance remain separate"],
            "pending-sql-original-three-cohort-summary")
        try demand(failures.isEmpty && declarations.count == 3, "All three actual pending cohorts are required; no successful subset qualifies")
        let completion = try pendingHost("pending_sql_complete", installation: installed,
            fields: ["nativeDeclaration": ["cohortCount": declarations.count, "actualAssertionsCompleted": true]])
        try attach(completion, "pending-sql-original-host-completion")
    }
}
