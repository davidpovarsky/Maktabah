import XCTest
import CryptoKit
import SQLite3

/// Real application only. See qa-20261115/TEST_DESIGN.md for destination,
/// fixture, held-provider and independent operation-trace requirements.
/// UI feedback alone never establishes engine cancellation or no-request proof.
final class GlobalSearchNativeAcceptanceTests: FaithfulReaderUIBase {
    private enum SetupError: Error { case missing(String) }
    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    override func tearDownWithError() throws {
        if let app {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "global-search-final-native-hierarchy"
            tree.lifetime = .keepAlways
            add(tree)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "global-search-final-native-screen"
            screen.lifetime = .keepAlways
            add(screen)
        }
        try super.tearDownWithError()
    }

    @MainActor
    private func element(_ id: String) -> XCUIElement {
        // Use the actual native roles for the large root/list queries. An
        // untyped descendant snapshot during bootstrap timed out before the
        // accessibility audit could even start on the original candidate.
        switch id {
        case "global-search-screen", "global-search-header": return app.otherElements[id].firstMatch
        case "global-search-history", "global-search-options-content": return app.collectionViews[id].firstMatch
        default: break
        }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    @discardableResult
    private func require(_ id: String, timeout: TimeInterval = 15) throws -> XCUIElement {
        let target = element(id)
        guard target.waitForExistence(timeout: timeout) else {
            XCTFail("Required actual UI element absent: \(id)")
            throw SetupError.missing(id)
        }
        return target
    }

    @MainActor
    private func eventually(_ reason: String, timeout: TimeInterval = 20,
                            _ condition: @escaping @MainActor () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, reason)
    }

    @MainActor
    private func launchSearch(backend: String? = nil, language: String? = nil, readerUnitMode: String? = nil, recordNativePages: Bool = false, recordNativeFonts: Bool = false) throws {
        let backend = backend ?? environment["GLOBAL_SEARCH_TEST_BACKEND"] ?? "otzaria"
        let language = language ?? environment["GLOBAL_SEARCH_TEST_LANGUAGE"] ?? "he"
        XCTAssertTrue(["otzaria", "sefaria", "sefariaEmbedded"].contains(backend))
        XCTAssertTrue(["he", "en"].contains(language))
        // An explicit original reader preference is only used by the line-mode
        // search-to-reader case; it does not replace data, search or bootstrap.
        let readerArguments = readerUnitMode.map {
            ["-otzaria_reader_unit_mode", $0, "-ChavrusaTextFaithfulReaderUIEnabled", "YES"]
        } ?? []
        launchWithTier(.realUI, backend: backend,
                       extraArgs: ["-preferredBackend", backend, "-smokeBackend", backend,
                                   "-studyWorkspaceTestingNamespace", workspaceNamespace,
                                   "-lastSelectedTab", "0"] + readerArguments + (recordNativePages ? ["-GlobalSearchNativeTraceEnabled", "YES"] : [])
                           + (recordNativeFonts ? ["-GlobalSearchFontDiagnosticsEnabled", "YES"] : []),
                       language: language, locale: language == "he" ? "he_IL" : "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        let tab = findTabButton(hebrew: "חיפוש", english: "Search")
        guard tab.waitForExistence(timeout: 60) else {
            XCTFail("Normal bootstrap did not expose the real Search tab")
            throw SetupError.missing("Search tab")
        }
        XCTAssertTrue(tab.isHittable)
        tab.tap()
        try require("global-search-screen", timeout: 40)
        try require("global-search-header")
        try require("global-search-history")
        _ = try queryField()
    }

    @MainActor
    private func queryField() throws -> XCUIElement {
        let field = try require("global-search-query")
        XCTAssertTrue(field.elementType == .searchField || field.elementType == .textField,
                      "The main input must be the native editable field")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "global-search-query").count, 1)
        XCTAssertEqual(element("global-search-header").descendants(matching: .any)
            .matching(identifier: "global-search-query").count, 1)
        return field
    }

    private func fixtureQuery(_ key: String = "GLOBAL_SEARCH_TEST_QUERY") throws -> String {
        let query = try XCTUnwrap(environment[key], "Runner must derive \(key) from the installed real source fixture")
        XCTAssertFalse(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return query
    }

    @MainActor
    private func chooseMode(_ mode: String) throws {
        try require("global-search-mode").tap()
        try require("global-search-mode-\(mode)").tap()
        eventually("Native mode menu must dismiss and return control to the header") {
            self.element("global-search-mode").isHittable && !self.element("global-search-mode-\(mode)").exists
        }
    }

    @MainActor
    private func openOptions() throws {
        try require("global-search-options").tap()
        try require("global-search-options-content")
        XCTAssertTrue(try require("global-search-options-done").isHittable)
    }

    @MainActor
    private func dismissOptions() throws {
        try require("global-search-options-done").tap()
        eventually("Options must actually dismiss; persistent header must become usable") {
            !self.element("global-search-options-content").exists && self.element("global-search-query").isHittable
        }
    }

    @MainActor
    private func revealOption(_ id: String) throws -> XCUIElement {
        for _ in 0..<8 {
            let control = element(id)
            if control.exists && control.isHittable { return control }
            try require("global-search-options-content").swipeUp()
        }
        XCTFail("Required advanced form control not reachable: \(id)")
        throw SetupError.missing(id)
    }

    @MainActor
    private func submit(_ query: String) throws {
        let field = try queryField()
        field.tap()
        field.typeText(query + "\n")
    }

    @MainActor
    private func firstOriginalRow() throws -> XCUIElement {
        let row = app.buttons.matching(NSPredicate(format:
            "identifier BEGINSWITH %@", "search-result-preview-toggle-")).firstMatch
        guard row.waitForExistence(timeout: 90) else {
            XCTFail("Real source query did not produce an original stable result row")
            throw SetupError.missing("original result row")
        }
        XCTAssertFalse(row.identifier.replacingOccurrences(of: "search-result-preview-toggle-", with: "").isEmpty)
        return row
    }

    @MainActor
    private func applyNoMatchFilter() throws -> String {
        try require("global-search-result-filter-toggle").tap()
        let filter = try require("global-search-result-filter")
        let token = "qa-no-book-" + UUID().uuidString
        filter.tap()
        filter.typeText(token + "\n")
        try require("global-search-filter-empty")
        XCTAssertEqual(filter.value as? String, token)
        try require("global-search-results")
        return token
    }

    @MainActor
    private func loadMoreButton() -> XCUIElement {
        // Existing source label; no invented tree/row/paging identifier.
        app.buttons.matching(NSPredicate(format: "label == %@", "Load more results")).firstMatch
    }

    @MainActor
    private func unfilteredLoadedCount() throws -> Int {
        XCTAssertFalse(element("global-search-result-filter").exists,
                       "Read the loaded count after leaving the local projection")
        let label = try require("global-search-count").label
        let first = try XCTUnwrap(label.split(separator: " ").first)
        return try XCTUnwrap(Int(first), "Actual unfiltered summary must identify loaded results: \(label)")
    }

    @MainActor
    private func assertHeaderGeometry(rtl: Bool) throws {
        let query = try queryField()
        let options = try require("global-search-options")
        let books = try require("global-search-books")
        let mode = try require("global-search-mode")
        for target in [query, options, books, mode] {
            XCTAssertFalse(target.frame.isEmpty)
            XCTAssertTrue(target.frame.intersects(app.frame))
            XCTAssertTrue(target.isHittable)
        }
        XCTAssertGreaterThanOrEqual(books.frame.minY, query.frame.maxY - 1)
        XCTAssertGreaterThanOrEqual(mode.frame.minY, query.frame.maxY - 1)
        XCTAssertFalse(query.frame.intersects(options.frame))
        if rtl {
            XCTAssertLessThanOrEqual(options.frame.maxX, query.frame.minX + 1)
            XCTAssertGreaterThan(books.frame.midX, mode.frame.midX)
        } else {
            XCTAssertGreaterThanOrEqual(options.frame.minX, query.frame.maxX - 1)
            XCTAssertLessThan(books.frame.midX, mode.frame.midX)
        }
    }

    @MainActor
    func testHebrewHeaderUsesActualRTLGeometry() throws {
        try launchSearch(backend: "otzaria", language: "he")
        try assertHeaderGeometry(rtl: true)
    }

    @MainActor
    func testEnglishHeaderUsesActualLTRGeometry() throws {
        try launchSearch(backend: "otzaria", language: "en")
        try assertHeaderGeometry(rtl: false)
    }

    @MainActor
    func testTypingKeepsInlineHistoryAndSingleNativeFieldWithRealClear() throws {
        try launchSearch(backend: "otzaria")
        let query = try queryField()
        let marker = "qa-" + UUID().uuidString
        query.tap()
        query.typeText(marker)
        XCTAssertEqual(query.value as? String, marker)
        XCTAssertTrue(element("global-search-history").exists)
        XCTAssertFalse(element("global-search-loading").exists)
        let editableOwners = app.searchFields.allElementsBoundByIndex + app.textFields.allElementsBoundByIndex
        XCTAssertEqual(editableOwners.filter { $0.isHittable && ($0.value as? String) == marker }.count, 1)
        let clearButtons = query.buttons.allElementsBoundByIndex.filter(\.isHittable)
        XCTAssertEqual(clearButtons.count, 1, "Use the native field clear control, without a duplicate button")
        try XCTUnwrap(clearButtons.first).tap()
        eventually("Native clear must empty the main binding") {
            let value = query.value as? String
            return value == "" || value == query.placeholderValue
        }
        XCTAssertTrue(element("global-search-history").exists)
        XCTAssertFalse(element("global-search-results-header").exists)
    }

    @MainActor
    func testOtzariaDefaultAdvancedFormExposesRealConditionalControls() throws {
        try launchSearch(backend: "otzaria")
        XCTAssertEqual(try require("global-search-mode").value as? String, "מתקדם",
                       "Preserve the existing Advanced default before any menu action")
        try require("global-search-mode").tap()
        let advanced = try require("global-search-mode-advanced")
        let selectedTitle = advanced.label
        advanced.tap()
        XCTAssertFalse(selectedTitle.isEmpty)
        try openOptions()
        for id in ["positive-scope", "distance", "word-match", "negative-query"] {
            _ = try revealOption("global-search-" + id)
        }
        XCTAssertFalse(element("global-search-negative-scope").exists)
        let negative = try revealOption("global-search-negative-query")
        negative.tap()
        negative.typeText("שלילה\n")
        _ = try revealOption("global-search-negative-scope")
        _ = try revealOption("global-search-negative-distance")
        for id in ["spacing", "alternatives", "grouping"] {
            _ = try revealOption("global-search-" + id)
        }
        try dismissOptions()
        XCTAssertFalse(element("global-search-loading").exists)
        XCTAssertTrue(element("global-search-history").exists)
    }

    @MainActor
    func testExactAndFuzzyHideAdvancedOtzariaBindings() throws {
        try launchSearch(backend: "otzaria")
        for mode in ["exact", "fuzzy"] {
            try chooseMode(mode)
            try openOptions()
            for suffix in ["positive-scope", "negative-query", "negative-scope", "grouping", "sefaria-match", "zayit-match"] {
                XCTAssertFalse(element("global-search-" + suffix).exists)
            }
            try dismissOptions()
        }
    }

    @MainActor
    func testEmbeddedOffersExactOnlyAndNoIgnoredOptions() throws {
        try launchSearch(backend: "sefariaEmbedded")
        try require("global-search-mode").tap()
        try require("global-search-mode-exact")
        for mode in ["advanced", "fuzzy", "zayit"] {
            XCTAssertFalse(element("global-search-mode-" + mode).exists)
        }
        try require("global-search-mode-exact").tap()
        try openOptions()
        for suffix in ["sefaria-match", "sefaria-distance", "positive-scope", "distance", "grouping", "zayit-match"] {
            XCTAssertFalse(element("global-search-" + suffix).exists)
        }
        try dismissOptions()
    }

    @MainActor
    func testLegacyAdvancedUsesItsOwnSourceControls() throws {
        try launchSearch(backend: "sefaria")
        try openOptions()
        _ = try revealOption("global-search-sefaria-match")
        _ = try revealOption("global-search-sefaria-distance")
        XCTAssertFalse(element("global-search-positive-scope").exists)
        XCTAssertFalse(element("global-search-grouping").exists)
        try dismissOptions()
    }

    @MainActor
    func testOptionsDismissalReturnsToSameQueryWithoutSubmission() throws {
        try launchSearch(backend: "otzaria")
        let query = try queryField()
        query.tap()
        query.typeText("qa-preserved-" + UUID().uuidString)
        let before = query.value as? String
        try openOptions()
        try dismissOptions()
        XCTAssertEqual(try queryField().value as? String, before)
        XCTAssertTrue(element("global-search-history").exists)
        XCTAssertFalse(element("global-search-loading").exists)
    }

    @MainActor
    func testReturnProducesOriginalRowsWithPersistentHeader() throws {
        try launchSearch()
        let query = try fixtureQuery()
        try submit(query)
        _ = try firstOriginalRow()
        XCTAssertEqual(try queryField().value as? String, query)
        XCTAssertTrue(try require("global-search-query").isHittable)
        try require("global-search-results-header")
        XCTAssertFalse(try require("global-search-count").label.isEmpty)
        XCTAssertFalse(element("global-search-history").exists)
    }

    @MainActor
    func testModeEditRequiresExplicitRerun() throws {
        try launchSearch(backend: "otzaria")
        let query = try fixtureQuery()
        try submit(query)
        _ = try firstOriginalRow()
        try chooseMode("exact")
        try require("global-search-dirty")
        XCTAssertFalse(element("global-search-loading").exists)
        XCTAssertFalse(element("global-search-results").exists)
        XCTAssertEqual(try queryField().value as? String, query)
        try require("global-search-rerun").tap()
        _ = try firstOriginalRow()
        XCTAssertFalse(element("global-search-dirty").exists)
    }

    @MainActor
    func testLocalTitleFilterPreservesInputsAndRestoresOriginalIdentity() throws {
        try launchSearch()
        let query = try fixtureQuery()
        try submit(query)
        let originalID = try firstOriginalRow().identifier
        let mode = try require("global-search-mode").value as? String
        let books = try require("global-search-books").label
        _ = try applyNoMatchFilter()
        XCTAssertEqual(try queryField().value as? String, query)
        XCTAssertEqual(element("global-search-mode").value as? String, mode)
        XCTAssertEqual(element("global-search-books").label, books)
        XCTAssertFalse(element("global-search-dirty").exists)
        XCTAssertFalse(element("global-search-loading").exists)
        try require("global-search-result-filter-done").tap()
        XCTAssertTrue(app.buttons[originalID].waitForExistence(timeout: 20))
        XCTAssertFalse(element("global-search-filter-empty").exists)
        XCTAssertFalse(element("global-search-result-filter").exists)
    }

    @MainActor
    func testZeroMatchProjectionRetainsExplicitLoadMore() throws {
        try launchSearch()
        try submit(fixtureQuery("GLOBAL_SEARCH_PAGING_QUERY"))
        _ = try firstOriginalRow()
        _ = try applyNoMatchFilter()
        let more = loadMoreButton()
        XCTAssertTrue(more.waitForExistence(timeout: 30), "Fixture must retain another actual page")
        XCTAssertTrue(more.isHittable)
        let before = try require("global-search-count").label
        more.tap()
        eventually("Explicit paging must change actual loaded count or expose a real page error", timeout: 90) {
            self.element("global-search-count").label != before || self.element("global-search-page-error").exists
        }
        XCTAssertTrue(element("global-search-filter-empty").exists)
        XCTAssertFalse(element("global-search-dirty").exists)
    }

    @MainActor
    func testActualPageFailurePreservesRowsAndRetryAppends() throws {
        try launchSearch()
        try submit(fixtureQuery("GLOBAL_SEARCH_PAGE_FAILURE_QUERY"))
        let originalID = try firstOriginalRow().identifier
        // The authorized runner holds/fails the actual next provider request.
        // A source/model error assignment is expressly not this test's setup.
        _ = try applyNoMatchFilter()
        let more = loadMoreButton()
        XCTAssertTrue(more.waitForExistence(timeout: 30))
        more.tap()
        try require("global-search-page-error", timeout: 90)
        try require("global-search-result-filter-done").tap()
        XCTAssertTrue(app.buttons[originalID].waitForExistence(timeout: 15))
        let failedCount = try unfilteredLoadedCount()
        try require("global-search-page-retry").tap()
        eventually("Real retry must dismiss page error and append results", timeout: 90) {
            guard !self.element("global-search-page-error").exists,
                  let first = self.element("global-search-count").label.split(separator: " ").first,
                  let count = Int(first) else { return false }
            return count > failedCount
        }
        XCTAssertTrue(app.buttons[originalID].exists, "Page failure/retry must preserve the existing stable row")
    }

    @MainActor
    func testOriginalResultPreviewOpensExpectedNativeLocator() throws {
        let expected = try XCTUnwrap(environment["GLOBAL_SEARCH_EXPECTED_LOCATOR"],
                                    "Runner must independently derive the first canonical result locator")
        XCTAssertFalse(expected.isEmpty)
        try launchSearch()
        try submit(fixtureQuery())
        let row = try firstOriginalRow()
        let stableID = String(row.identifier.dropFirst("search-result-preview-toggle-".count))
        row.tap()
        try require("search-result-expanded-preview-" + stableID)
        try require("search-result-open-" + stableID).tap()
        assertReaderHasText() // Existing real native TextKit/pixel/title oracle.
        XCTAssertEqual(try require("reader-current-locator").label, expected)
    }

    @MainActor
    func testSubmittedCanonicalQueryReturnsInInlineHistoryAfterRelaunch() throws {
        let canonical = try fixtureQuery().trimmingCharacters(in: .whitespacesAndNewlines)
        try launchSearch()
        try submit("  " + canonical + "  ")
        _ = try firstOriginalRow()
        app.terminate()
        try launchSearch()
        let historyID = "global-search-history-" + canonical
        let row = try require(historyID)
        XCTAssertEqual(element("global-search-history").descendants(matching: .button)
            .matching(identifier: historyID).count, 1, "Canonical history must not duplicate the same query")
        row.tap()
        _ = try firstOriginalRow()
        XCTAssertEqual(try queryField().value as? String, canonical)
        // No global-history deletion or fabricated UserDefaults seed.
    }

    @MainActor
    func testHeldSearchCanBeCancelledWithQueryVisible() throws {
        try launchSearch()
        let query = try fixtureQuery("GLOBAL_SEARCH_HELD_QUERY")
        try submit(query)
        try require("global-search-loading", timeout: 30)
        XCTAssertEqual(try queryField().value as? String, query)
        XCTAssertTrue(try queryField().isHittable)
        try require("global-search-cancel").tap()
        try require("global-search-cancelled")
        XCTAssertFalse(element("global-search-loading").exists)
        XCTAssertEqual(try queryField().value as? String, query)
        // Full acceptance separately requires actual engine/task cancellation
        // and release/rejection of the held late response, not this UI state.
    }

    @MainActor
    func testHeaderAndHistoryNativeAccessibilityAudit() throws {
        try launchSearch(recordNativeFonts: true)
        let heading = try require("global-search-history-heading")
        XCTAssertEqual(heading.elementType, .staticText)
        XCTAssertEqual(heading.label, "חיפושים אחרונים")
        XCTAssertFalse(heading.frame.isEmpty)
        // The actual field/options bounds belong to the Search detail column.
        // A full-window heading frame would include unrelated sidebar pixels
        // during the native contrast audit and be wrong for VoiceOver as well.
        let controls = try queryField().frame.union(require("global-search-options").frame)
        XCTAssertGreaterThanOrEqual(heading.frame.minX, controls.minX - 1)
        XCTAssertLessThanOrEqual(heading.frame.maxX, controls.maxX + 1)
        try app.performAccessibilityAudit { issue in
            // Keep every system-reported failure. Attach its element while
            // the audit is active, before transient trait-change AX expires.
            let detail = XCTAttachment(string: issue.compactDescription + "\n" + issue.detailedDescription
                + "\nelement=" + (issue.element?.debugDescription ?? "unavailable"))
            detail.name = "actual-unfiltered-accessibility-issue"
            detail.lifetime = .keepAlways
            self.add(detail)
            return false
        }
    }

    // Separate future selection. These methods explicitly select Zayit through
    // the existing native UI; backend=otzaria alone still means Advanced above.
    // Recorded full-v32 totals/ranking are deliberately not UI expectations.
    private struct ZayitCanonicalMetadata: Decodable {
        let kind: String
        let profileID: String
        let profileVersion: Int
        let databaseSHA256: String
        let sourcePacketSHA256: String
        let books: [String: String]
        let rows: [[Int]]
    }

    private let zayitMetadataSHA256 = "c6ca39044f6a62728f8f7e40e86d4080c89dc8927ced5ae6d724079efb5f896b"

    private func canonicalZayitMetadata() throws -> ZayitCanonicalMetadata {
        let path = try XCTUnwrap(environment["GLOBAL_SEARCH_ZAYIT_CANONICAL_FIXTURE"],
                                "Runner must supply the byte-sealed independent canonical metadata file")
        guard path == "test-bundle:canonical-miniTest10-metadata.json" else {
            XCTFail("Future runner must deliver the sealed metadata as a UITest bundle resource")
            throw SetupError.missing("canonical metadata test-bundle delivery")
        }
        let testBundle = Bundle(for: GlobalSearchNativeAcceptanceTests.self)
        let url = try XCTUnwrap(testBundle.url(forResource: "canonical-miniTest10-metadata", withExtension: "json"),
                                "Metadata must be inside the installed test bundle, not a guessed host path")
        let bytes = try Data(contentsOf: url)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hash, zayitMetadataSHA256, "Do not accept a fabricated or normalized oracle file")
        guard hash == zayitMetadataSHA256 else { throw SetupError.missing("sealed canonical metadata hash") }
        let delivery = XCTAttachment(string: "Read by UITest process from installed test bundle\nBundle: \(testBundle.bundleIdentifier ?? "<unknown>")\nURL: \(url.absoluteString)\nActual bytes: \(bytes.count)\nActual SHA256: \(hash)\nMetadata delivery only; no app/index readiness established")
        delivery.name = "zayit-canonical-metadata-test-process-read"
        delivery.lifetime = .keepAlways
        add(delivery)
        let metadata = try JSONDecoder().decode(ZayitCanonicalMetadata.self, from: bytes)
        XCTAssertEqual(metadata.kind, "CANONICAL_MINITEST10_METADATA_NOT_ENGINE_RESULTS_OR_READINESS")
        XCTAssertEqual(metadata.profileID, "miniTest10")
        XCTAssertEqual(metadata.profileVersion, 6)
        XCTAssertEqual(metadata.databaseSHA256, "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef")
        XCTAssertEqual(metadata.sourcePacketSHA256, "702e89a066c27084f72c03ff826a1bf72328ef6ccf05f34aae70ef553cf13709")
        XCTAssertEqual(metadata.rows.count, 18879)
        XCTAssertEqual(metadata.books.count, 10)
        // This seals the independent oracle, not the installed app/index.
        // The manager must separately verify the actual installed profile pair.
        return metadata
    }

    @MainActor
    private func launchExplicitZayitFlexibleSearch(readerUnitMode: String? = nil, recordNativePages: Bool = false) throws {
        try launchSearch(backend: "otzaria", readerUnitMode: readerUnitMode, recordNativePages: recordNativePages)
        try chooseMode("zayit")
        XCTAssertEqual(try require("global-search-mode").value as? String, "זית")
        try openOptions()
        let picker = try revealOption("global-search-zayit-match")
        picker.tap()
        // Actual existing Picker option label; no added production selector.
        let flexibleLabel = "גמיש — מרחק 5 מילים"
        let flexible = app.buttons[flexibleLabel]
        XCTAssertTrue(flexible.waitForExistence(timeout: 15))
        flexible.tap()
        eventually("Native Zayit Picker must visibly select its existing flexible/near5 mode") {
            let selected = self.element("global-search-zayit-match")
            return selected.value as? String == flexibleLabel || selected.label.contains(flexibleLabel)
        }
        try dismissOptions()
        XCTAssertEqual(element("global-search-mode").value as? String, "זית")
        XCTAssertEqual(element("global-search-books").label, "כל הספרים",
                       "Require the actual all-books scope of the installed ten-book profile")
    }

    @MainActor
    private func requireCanonicalZayitRow(_ row: XCUIElement,
                                          metadata: ZayitCanonicalMetadata) throws -> [Int] {
        let prefix = "search-result-preview-toggle-zayit:miniTest10:"
        XCTAssertTrue(row.identifier.hasPrefix(prefix), "Actual native row must belong to Zayit and the required profile")
        let lineID = try XCTUnwrap(Int(row.identifier.dropFirst(prefix.count)))
        let canonical = try XCTUnwrap(metadata.rows.first { $0.first == lineID },
                                      "Observed engine line ID must exist in independently decoded canonical SQL")
        XCTAssertEqual(canonical.count, 3)
        XCTAssertNotNil(metadata.books[String(canonical[1])])
        XCTAssertGreaterThanOrEqual(canonical[2], 0)
        return canonical
    }

    @MainActor
    private func actualLoadedProjection() throws -> (matched: Int, loaded: Int) {
        let label = try require("global-search-count").label
        let numbers = label.split { !$0.isNumber }.compactMap { Int($0) }
        XCTAssertGreaterThanOrEqual(numbers.count, 2, "Require actual filtered-of-loaded presentation")
        guard numbers.count >= 2 else { throw SetupError.missing("filtered loaded count") }
        XCTAssertGreaterThanOrEqual(numbers[1], numbers[0])
        return (numbers[0], numbers[1])
    }

    @MainActor
    func testZayitExplicitFlexibleScopeProducesCanonicalMiniTestRow() throws {
        let metadata = try canonicalZayitMetadata()
        try launchExplicitZayitFlexibleSearch()
        try submit("בראשית") // Positive full-v32 candidate; installed mini index still a real prerequisite.
        let row = try firstOriginalRow()
        let canonical = try requireCanonicalZayitRow(row, metadata: metadata)
        XCTAssertEqual(try queryField().value as? String, "בראשית")
        XCTAssertEqual(element("global-search-mode").value as? String, "זית")
        XCTAssertFalse(element("global-search-sort").exists)
        let evidence = XCTAttachment(string: "Actual observed stable ID: \(row.identifier)\nIndependent SQL [lineID,bookID,lineIndex]: \(canonical)\nOracle SHA256: \(zayitMetadataSHA256)")
        evidence.name = "zayit-observed-row-independent-canonical-identity"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private struct ZayitReaderLineOracle: Decodable {
        struct Row: Decodable {
            let id: Int
            let bookId: Int
            let lineIndex: Int
            let plainText: String
            let plainSHA256: String
        }
        let profileID: String
        let profileVersion: Int
        let databaseSHA256: String
        let rows: [Row]
    }

    @MainActor
    func testZayitCanonicalRowOpensOriginalReaderAtExactSourceLine() throws {
        try assertZayitReaderSourceLine(lineID: 1)
    }

    @MainActor
    func testZayitNonzeroSourceLineRetainsExactOriginalTextAndHighlight() throws {
        try assertZayitReaderSourceLine(lineID: 2634912)
    }

    @MainActor
    private func assertZayitReaderSourceLine(lineID: Int) throws {
        let metadata = try canonicalZayitMetadata()
        let bundle = Bundle(for: GlobalSearchNativeAcceptanceTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "canonical-miniTest10-reader-lines", withExtension: "json"))
        let bytes = try Data(contentsOf: url)
        let oracleHash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let expectedHash = "51632762100689aa2da6a6d360a6434d4fa4caf5e57971f4ad8e327ab6e173dc"
        XCTAssertEqual(oracleHash, expectedHash, "The exact SQL source-text oracle must be in the installed test bundle")
        guard oracleHash == expectedHash else { throw SetupError.missing("canonical Reader source hash") }
        let oracle = try JSONDecoder().decode(ZayitReaderLineOracle.self, from: bytes)
        XCTAssertEqual(oracle.profileID, metadata.profileID)
        XCTAssertEqual(oracle.profileVersion, metadata.profileVersion)
        XCTAssertEqual(oracle.databaseSHA256, metadata.databaseSHA256)
        let source = try XCTUnwrap(oracle.rows.first { $0.id == lineID })
        XCTAssertFalse(source.plainText.isEmpty)
        XCTAssertEqual(SHA256.hash(data: Data(source.plainText.utf8)).map { String(format: "%02x", $0) }.joined(),
                       source.plainSHA256)
        let delivery = XCTAttachment(string: "Actual installed oracle URL: \(url.absoluteString)\nBytes: \(bytes.count)\nSHA256: \(oracleHash)\nSource line ID: \(lineID)")
        delivery.name = "zayit-canonical-reader-source-test-process-read"
        delivery.lifetime = .keepAlways
        add(delivery)

        try launchExplicitZayitFlexibleSearch(readerUnitMode: "line")
        try submit("בראשית")
        _ = try firstOriginalRow() // Require a completed real engine result list.
        let stableID = "zayit:miniTest10:\(lineID)"
        let row = app.buttons["search-result-preview-toggle-" + stableID]
        for _ in 0..<8 {
            if row.exists && row.isHittable { break }
            try require("global-search-results").swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(row.isHittable)
        let canonical = try requireCanonicalZayitRow(row, metadata: metadata)
        XCTAssertEqual(canonical, [source.id, source.bookId, source.lineIndex])
        let expected = "otzaria|book:\(canonical[1])|line:\(canonical[2])"
        let expectedTitle = try XCTUnwrap(metadata.books[String(canonical[1])])
        row.tap()
        try require("search-result-expanded-preview-" + stableID)
        let open = try require("search-result-open-" + stableID)
        for _ in 0..<6 {
            if open.isHittable { break }
            try require("global-search-results").swipeUp()
        }
        XCTAssertTrue(open.isHittable, "The original result Open control must be reachable")
        open.tap()
        let textView = app.textViews["reader-text"]
        XCTAssertTrue(textView.waitForExistence(timeout: 60))
        // The genuine line-zero source is a six-letter title. A generic
        // >30-character paragraph heuristic rejects correct source content.
        // Compare the full actual TextKit text with independently sealed SQL,
        // stripping only presentation bidi controls and outer whitespace.
        let directionControls: Set<UInt32> = [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
                                             0x2066, 0x2067, 0x2068, 0x2069]
        func canonicalText(_ value: String) -> String {
            value.unicodeScalars.filter { !directionControls.contains($0.value) }
                .map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        eventually("The original TextKit view must contain the exact independently decoded source line", timeout: 30) {
            guard let actual = textView.value as? String else { return false }
            return canonicalText(actual) == source.plainText
        }
        if source.lineIndex > 0 { assertReaderHasText() }
        XCTAssertEqual(try require("reader-current-locator").label, expected)
        XCTAssertTrue(try require("reader-header-title").label.contains(expectedTitle))
        let rendered = try XCTUnwrap(getRenderedHighlightSnapshot(),
            "Require diagnostics from the actual original TextKit view")
        XCTAssertEqual(rendered.locator, expected)
        XCTAssertGreaterThan(rendered.searchHighlightCount, 0,
            "The search terms must be highlighted in the rendered original reader")
        let evidence = XCTAttachment(string: "Observed engine row: \(stableID)\nIndependent expected line-mode locator: \(expected)\nActual rendered locator: \(rendered.locator ?? "<missing>")\nMetadata SHA256: \(zayitMetadataSHA256)\nReader source SHA256: \(source.plainSHA256)")
        evidence.name = "zayit-real-search-to-reader-independent-source-line"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    @MainActor
    func testZayitLoadedTitleSubstringUsesActualMountedProjection() throws {
        let metadata = try canonicalZayitMetadata()
        try launchExplicitZayitFlexibleSearch()
        try submit("בראשית")
        let original = try firstOriginalRow()
        _ = try requireCanonicalZayitRow(original, metadata: metadata)
        let originalID = original.identifier
        eventually("Initial native request/paging must finish before measuring the local projection") {
            !self.element("global-search-loading").exists && !self.element("global-search-cancel").exists
        }
        let loadedBefore = try unfilteredLoadedCount()
        let booksBefore = try require("global-search-books").label
        try require("global-search-result-filter-toggle").tap()
        let filter = try require("global-search-result-filter")
        filter.tap()
        filter.typeText("ברכות\n")
        let actual = try actualLoadedProjection()
        XCTAssertEqual(actual.loaded, loadedBefore)
        XCTAssertGreaterThan(actual.matched, 0, "Actual mounted page must supply a positive projection before accepting this case")
        let mounted = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                       "search-result-preview-toggle-")).allElementsBoundByIndex.filter(\.isHittable)
        XCTAssertFalse(mounted.isEmpty)
        for row in mounted {
            let canonical = try requireCanonicalZayitRow(row, metadata: metadata)
            let title = try XCTUnwrap(metadata.books[String(canonical[1])])
            XCTAssertTrue(title.contains("ברכות"), "Substring includes both ברכות and משנה ברכות where actually loaded")
        }
        XCTAssertEqual(try queryField().value as? String, "בראשית")
        XCTAssertEqual(element("global-search-mode").value as? String, "זית")
        XCTAssertEqual(element("global-search-books").label, booksBefore)
        XCTAssertFalse(element("global-search-dirty").exists)
        XCTAssertFalse(element("global-search-loading").exists)
        // Never assert the retained full-index first50 count11 against this List.
        try require("global-search-result-filter-done").tap()
        for _ in 0..<8 {
            if app.buttons[originalID].exists { break }
            try require("global-search-results").swipeDown()
        }
        XCTAssertTrue(app.buttons[originalID].exists)
        XCTAssertEqual(try unfilteredLoadedCount(), loadedBefore)
    }

    @MainActor
    func testZayitZeroMatchProjectionRetainsRealExplicitPaging() throws {
        let metadata = try canonicalZayitMetadata()
        try launchExplicitZayitFlexibleSearch()
        try submit("אמר")
        _ = try requireCanonicalZayitRow(firstOriginalRow(), metadata: metadata)
        _ = try applyNoMatchFilter()
        let before = try actualLoadedProjection()
        XCTAssertEqual(before.matched, 0)
        let more = loadMoreButton()
        XCTAssertTrue(more.waitForExistence(timeout: 30), "Require actual installed-index hasMore after native prefetch")
        XCTAssertTrue(more.isHittable)
        more.tap()
        eventually("Actual Zayit explicit page must increase loaded count with no matching titles", timeout: 90) {
            let numbers = self.element("global-search-count").label.split { !$0.isNumber }.compactMap { Int($0) }
            return numbers.count >= 2 && numbers[0] == 0 && numbers[1] > before.loaded
        }
        XCTAssertEqual(try queryField().value as? String, "אמר")
        XCTAssertEqual(element("global-search-mode").value as? String, "זית")
        XCTAssertTrue(element("global-search-filter-empty").exists)
        XCTAssertFalse(element("global-search-page-error").exists)
        XCTAssertFalse(element("global-search-dirty").exists)
        // Provider request/cursor/cancellation traces remain separate prerequisites.
    }

    // Full native page evidence: the observer sees completed original provider
    // pages and the actual published UI model. It cannot provide or replace data.
    @MainActor
    func testZayitThreeNativePagesRetainCanonicalIdentityAndOriginalMetadata() throws {
        try assertNativePages(engine: "zayit", minimumPages: 3, minimumRows: 150)
    }

    @MainActor
    func testOtzariaNativePagesRetainCanonicalMetadataBeyondOneHundred() throws {
        try assertNativePages(engine: "otzaria", minimumPages: 2, minimumRows: 200)
    }

    private func nativeSearchObservationURL() throws -> URL {
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let parent = try workspaceContainerParent().standardizedFileURL
        XCTAssertTrue(sidecar.pathComponents.starts(with: parent.pathComponents))
        let container = try XCTUnwrap(sidecar.pathComponents.dropFirst(parent.pathComponents.count).first)
        return parent.appendingPathComponent(container)
            .appendingPathComponent("Documents/OtzariaLogs/search-native-" + workspaceNamespace + ".jsonl")
    }

    private func nativeSearchObservations(at url: URL) throws -> [[String: Any]] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }

    private func canonicalObservationBytes(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    @MainActor
    private func assertNativePages(engine: String, minimumPages: Int, minimumRows: Int) throws {
        let metadata = try canonicalZayitMetadata() // Same independently sealed original DB.
        if engine == "zayit" {
            try launchExplicitZayitFlexibleSearch(readerUnitMode: "line", recordNativePages: true)
        } else {
            try launchSearch(backend: "otzaria", readerUnitMode: "line", recordNativePages: true)
        }
        try submit("אמר")
        let originalID = try firstOriginalRow().identifier
        _ = try applyNoMatchFilter() // Stops automatic prefetch through an actual user control.
        let url = try nativeSearchObservationURL()
        for _ in 0..<5 {
            let before = try actualLoadedProjection()
            XCTAssertEqual(before.matched, 0)
            let events = (try? nativeSearchObservations(at: url)) ?? []
            let pages = events.filter { $0["event"] as? String == "provider" && $0["engine"] as? String == engine }
            if pages.count >= minimumPages && before.loaded >= minimumRows { break }
            let more = loadMoreButton()
            XCTAssertTrue(more.waitForExistence(timeout: 30), "The original engine must offer another real page")
            XCTAssertTrue(more.isHittable)
            more.tap()
            eventually("A real next page must increase the native loaded count without an error", timeout: 90) {
                guard !self.element("global-search-page-error").exists,
                      let projection = try? self.actualLoadedProjection() else { return false }
                return projection.matched == 0 && projection.loaded > before.loaded
            }
        }
        eventually("The committed original UI model and actual loaded count must agree", timeout: 30) {
            guard !self.element("global-search-cancel").exists,
                  let projection = try? self.actualLoadedProjection(),
                  let events = try? self.nativeSearchObservations(at: url),
                  let last = events.last(where: { $0["event"] as? String == "published" && $0["engine"] as? String == engine }),
                  let items = last["items"] as? [[String: Any]] else { return false }
            return items.count == projection.loaded && items.count >= minimumRows
        }
        let events = try nativeSearchObservations(at: url)
        let selected = events.filter { $0["engine"] as? String == engine }
        XCTAssertFalse(selected.isEmpty)
        XCTAssertEqual(Set(selected.compactMap { $0["sessionID"] as? String }).count, 1)
        XCTAssertEqual(Set(selected.compactMap { ($0["searchGeneration"] as? NSNumber)?.intValue }).count, 1)
        for event in selected {
            XCTAssertEqual(event["namespace"] as? String, workspaceNamespace)
            XCTAssertEqual(event["profileID"] as? String, metadata.profileID)
            XCTAssertEqual((event["schemaVersion"] as? NSNumber)?.intValue, 1)
            XCTAssertEqual((event["submissionRevision"] as? NSNumber)?.intValue, 1,
                           "Explicit paging must not silently resubmit or substitute the query")
        }
        let pages = selected.filter { $0["event"] as? String == "provider" }
        XCTAssertGreaterThanOrEqual(pages.count, minimumPages)
        let expectedQueryHash = SHA256.hash(data: Data("אמר".utf8)).map { String(format: "%02x", $0) }.joined()
        let canonicalRows = Dictionary(uniqueKeysWithValues: metadata.rows.map { ($0[0], $0) })
        let canonicalPositions = Set(metadata.rows.map { "\($0[1]):\($0[2])" })
        var expectedOffset = 0
        var sourceByID: [String: [String: Any]] = [:]
        var sourceOrder: [String] = []
        var retainedItemByID: [String: [String: Any]] = [:]
        var laterPageIDs: [String] = []
        for (pageIndex, event) in pages.enumerated() {
            let request = try XCTUnwrap(event["request"] as? [String: Any])
            XCTAssertEqual(request["querySHA256"] as? String, expectedQueryHash)
            XCTAssertNil(request["query"], "The diagnostic must not export query text")
            XCTAssertEqual((request["offset"] as? NSNumber)?.intValue, expectedOffset)
            XCTAssertEqual((request["limit"] as? NSNumber)?.intValue, engine == "zayit" ? 50 : 100)
            let page = try XCTUnwrap(event["page"] as? [String: Any])
            let rows = try XCTUnwrap(page[engine == "zayit" ? "hits" : "results"] as? [[String: Any]])
            XCTAssertFalse(rows.isEmpty)
            XCTAssertLessThanOrEqual(rows.count, engine == "zayit" ? 50 : 100)
            for row in rows {
                let id: String
                let book: Int
                let line: Int
                let title: String
                if engine == "zayit" {
                    let lineID = try XCTUnwrap((row["line_id"] as? NSNumber)?.intValue)
                    let canonical = try XCTUnwrap(canonicalRows[lineID])
                    book = try XCTUnwrap((row["book_id"] as? NSNumber)?.intValue)
                    line = try XCTUnwrap((row["line_index"] as? NSNumber)?.intValue)
                    title = try XCTUnwrap(row["book_title"] as? String)
                    XCTAssertEqual([lineID, book, line], canonical)
                    id = "zayit:miniTest10:\(lineID)"
                } else {
                    let path = try XCTUnwrap(row["filePath"] as? String)
                    XCTAssertTrue(path.hasPrefix("otzaria-book:"))
                    book = try XCTUnwrap(Int(path.dropFirst("otzaria-book:".count)))
                    line = try XCTUnwrap((row["segment"] as? NSNumber)?.intValue)
                    let rawID = try XCTUnwrap((row["id"] as? NSNumber)?.uint64Value)
                    title = try XCTUnwrap(row["title"] as? String)
                    XCTAssertTrue(canonicalPositions.contains("\(book):\(line)"))
                    id = "otzaria:\(path):\(rawID):\(line)"
                }
                XCTAssertEqual(title, metadata.books[String(book)])
                if sourceByID[id] == nil {
                    sourceByID[id] = row
                    sourceOrder.append(id)
                    if pageIndex > 0 { laterPageIDs.append(id) }
                } else {
                    XCTAssertEqual(try canonicalObservationBytes(try XCTUnwrap(sourceByID[id])),
                                   try canonicalObservationBytes(row),
                                   "A repeated engine identity cannot change its original metadata")
                }
            }
            expectedOffset += rows.count
            XCTAssertEqual((event["nextOffset"] as? NSNumber)?.intValue, expectedOffset,
                           "Cursor must consume actual raw engine rows, including any duplicate identities")
            if engine == "zayit" {
                let accumulated = try XCTUnwrap(event["accumulatedSource"] as? [[String: Any]])
                XCTAssertEqual(accumulated.count, sourceOrder.count)
                for (id, retained) in zip(sourceOrder, accumulated) {
                    XCTAssertEqual(try canonicalObservationBytes(try XCTUnwrap(sourceByID[id])),
                                   try canonicalObservationBytes(retained),
                                   "Earlier pages must retain every original provider field")
                }
            } else {
                let retained = try XCTUnwrap(event["retainedRecords"] as? [[String: Any]])
                XCTAssertEqual(retained.count, sourceOrder.count)
                for (id, record) in zip(sourceOrder, retained) {
                    XCTAssertEqual(try canonicalObservationBytes(try XCTUnwrap(sourceByID[id])),
                                   try canonicalObservationBytes(try XCTUnwrap(record["metadata"])),
                                   "Metadata must remain paired with its original identity after every page")
                    let item = try XCTUnwrap(record["item"] as? [String: Any])
                    XCTAssertEqual(item["id"] as? String, id)
                    if let prior = retainedItemByID[id] {
                        XCTAssertEqual(try canonicalObservationBytes(item), try canonicalObservationBytes(prior))
                    }
                    retainedItemByID[id] = item
                }
            }
        }
        let published = try XCTUnwrap(selected.last { $0["event"] as? String == "published" })
        let items = try XCTUnwrap(published["items"] as? [[String: Any]])
        let ids = try items.map { try XCTUnwrap($0["id"] as? String) }
        XCTAssertEqual(ids, sourceOrder, "The original UI must publish the real accumulated provider order")
        XCTAssertEqual(Set(ids).count, ids.count, "No duplicate identity may appear in the real UI model")
        XCTAssertGreaterThanOrEqual(ids.count, minimumRows)
        for item in items {
            let id = try XCTUnwrap(item["id"] as? String)
            let raw = try XCTUnwrap(sourceByID[id])
            let book = try XCTUnwrap((item["bookID"] as? NSNumber)?.intValue)
            let line = try XCTUnwrap((item["lineIndex"] as? NSNumber)?.intValue)
            XCTAssertTrue(canonicalPositions.contains("\(book):\(line)"))
            XCTAssertEqual(item["bookTitle"] as? String, metadata.books[String(book)])
            XCTAssertEqual(item["locator"] as? String, "otzaria|book:\(book)|line:\(line)")
            XCTAssertEqual(item["reference"] as? String, raw["reference"] as? String ?? "")
            if engine == "zayit" {
                XCTAssertEqual(item["highlightTerms"] as? [String], raw["matched_terms"] as? [String])
                XCTAssertEqual((raw["book_id"] as? NSNumber)?.intValue, book)
                XCTAssertEqual((raw["line_index"] as? NSNumber)?.intValue, line)
            } else {
                XCTAssertEqual(try canonicalObservationBytes(item),
                               try canonicalObservationBytes(try XCTUnwrap(retainedItemByID[id])))
            }
        }
        let evidence = XCTAttachment(data: try Data(contentsOf: url), uniformTypeIdentifier: "public.plain-text")
        evidence.name = "actual-" + engine + "-provider-pages-and-native-published-results"
        evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(try queryField().value as? String, "אמר")
        XCTAssertFalse(element("global-search-page-error").exists)
        XCTAssertFalse(element("global-search-dirty").exists)
        try require("global-search-result-filter-done").tap()
        XCTAssertEqual(try unfilteredLoadedCount(), items.count)
        XCTAssertTrue(ids.contains(String(originalID.dropFirst("search-result-preview-toggle-".count))))

        // Open a genuine later-page result, using independently sealed SQL for
        // its expected book/line rather than trusting the UI's own title.
        let chosenID = try XCTUnwrap(laterPageIDs.first { id in
            guard let raw = sourceByID[id] else { return false }
            let snippet = raw[engine == "zayit" ? "snippet_html" : "text"] as? String ?? ""
            return snippet.count > 100
        })
        let chosen = try XCTUnwrap(items.first { $0["id"] as? String == chosenID })
        let book = try XCTUnwrap((chosen["bookID"] as? NSNumber)?.intValue)
        let line = try XCTUnwrap((chosen["lineIndex"] as? NSNumber)?.intValue)
        let row = app.buttons["search-result-preview-toggle-" + chosenID]
        for _ in 0..<24 {
            if row.exists && row.isHittable { break }
            try require("global-search-results").swipeUp()
        }
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.isHittable, "An actual later-page result must remain reachable")
        row.tap()
        try require("search-result-expanded-preview-" + chosenID)
        let open = try require("search-result-open-" + chosenID)
        for _ in 0..<6 {
            if open.isHittable { break }
            try require("global-search-results").swipeUp()
        }
        XCTAssertTrue(open.isHittable)
        open.tap()
        let expectedLocator = "otzaria|book:\(book)|line:\(line)"
        let targetRendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let locator = self.app.staticTexts["reader-current-locator"]
            return locator.exists && locator.label == expectedLocator
                && self.getRenderedHighlightSnapshot()?.locator == expectedLocator
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [targetRendered], timeout: 30), .completed,
                       "Opening a later page must finish rendering that exact source, not a retained reader")
        assertReaderHasText()
        XCTAssertEqual(try require("reader-current-locator").label, expectedLocator)
        XCTAssertTrue(try require("reader-header-title").label.contains(try XCTUnwrap(metadata.books[String(book)])))
        let rendered = try XCTUnwrap(getRenderedHighlightSnapshot())
        XCTAssertEqual(rendered.locator, expectedLocator)
        XCTAssertGreaterThan(rendered.searchHighlightCount, 0)
    }

}


// MARK: - Original Search Data status and repair on the owned miniature fixture

private enum SearchDataNativeFixtureError: Error { case rejected(String) }

private func requireSearchDataFixture(_ condition: Bool, _ reason: String) throws {
    guard condition else {
        XCTFail(reason)
        throw SearchDataNativeFixtureError.rejected(reason)
    }
}

private func searchDataFileBytes(_ url: URL, maximum: Int = 128 * 1024 * 1024) throws -> Data {
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    try requireSearchDataFixture(values.isRegularFile == true && values.isSymbolicLink == false,
                                 "The owned fixture file must be regular and must not be a symbolic link")
    try requireSearchDataFixture((values.fileSize ?? maximum + 1) <= maximum, "Bound the miniature fixture read")
    return try Data(contentsOf: url)
}

private func searchDataDigest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

// MARK: - Original engine metadata after an explicit fixture reinstallation

private struct SearchDataNativeEngineMetadata: Decodable {
    let format: String
    let schema_version: UInt32
    let engine_version: String
    let tantivy_version: String
    let created_at_unix_seconds: UInt64
}

private enum SearchDataNativeMetadataError: Error { case rejected(String) }

/// The original miniTest10 artifact contains seven Tantivy files, not this
/// sidecar. The unchanged Rust engine creates it when opening a fresh install.
/// Only that original creation second may change during an explicit reinstall;
/// every other byte and the complete nine-file inventory remain checked.
private func searchDataVerifyRegeneratedEngineMetadata(
    original: Data,
    repaired: Data,
    reinstallationStartedAt: Date,
    observedAt: Date
) throws {
    func require(_ valid: Bool, _ reason: String) throws {
        if !valid { throw SearchDataNativeMetadataError.rejected(reason) }
    }
    let keys: Set<String> = [
        "format", "schema_version", "engine_version", "tantivy_version", "created_at_unix_seconds"
    ]
    func decode(_ data: Data) throws -> (SearchDataNativeEngineMetadata, String) {
        guard let text = String(data: data, encoding: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SearchDataNativeMetadataError.rejected("Original engine metadata must be a UTF-8 JSON object")
        }
        try require(Set(object.keys) == keys, "Retain exactly the original five metadata fields")
        for key in keys {
            try require(text.components(separatedBy: "\"" + key + "\"").count == 2,
                        "Each original metadata field must occur exactly once")
        }
        let value = try JSONDecoder().decode(SearchDataNativeEngineMetadata.self, from: data)
        try require(value.format == "otzaria-search-index" && value.schema_version == 4
            && value.engine_version == "0.1.0" && value.tantivy_version == "0.26.1"
            && value.created_at_unix_seconds > 0,
            "Require the original source-pinned miniTest10 v6 engine metadata")
        return (value, text)
    }
    let (before, beforeText) = try decode(original)
    let (after, afterText) = try decode(repaired)
    let start = reinstallationStartedAt.timeIntervalSince1970
    let end = observedAt.timeIntervalSince1970
    try require(start.isFinite && end.isFinite && start > 0 && end >= start
        && end < Double(UInt64.max), "Require an actual bounded observation interval")
    let lower = UInt64(start.rounded(.down))
    let upper = UInt64(end.rounded(.down))
    try require(after.created_at_unix_seconds >= before.created_at_unix_seconds
        && (lower...upper).contains(after.created_at_unix_seconds),
        "The original engine creation second must fall within this real reinstallation")
    let beforeField = "\"created_at_unix_seconds\": \(before.created_at_unix_seconds)"
    let afterField = "\"created_at_unix_seconds\": \(after.created_at_unix_seconds)"
    try require(beforeText.components(separatedBy: beforeField).count == 2
        && afterText.components(separatedBy: afterField).count == 2,
        "Require the original engine's exact metadata field serialization")
    try require(afterText.replacingOccurrences(of: afterField, with: beforeField).utf8.elementsEqual(beforeText.utf8),
                "Every metadata byte except the bounded creation second must remain identical")
}

// MARK: - Complete owned index payload inventory

private func searchDataIndexInventory(_ root: URL, includeSecondaryIdentity: Bool = false) throws -> [String: String] {
    try requireSearchDataFixture(root.standardizedFileURL.path == root.resolvingSymlinksInPath().path,
                                 "Do not follow a fixture path through symbolic links")
    let files = try XCTUnwrap(FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]))
    var result: [String: String] = [:]
    var bytes = 0
    for case let file as URL in files {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
        try requireSearchDataFixture(values.isSymbolicLink == false, "Index fixtures cannot contain symbolic links")
        if values.isDirectory == true { continue }
        try requireSearchDataFixture(values.isRegularFile == true, "Index fixtures must contain only regular files")
        let path = Array(file.standardizedFileURL.pathComponents.dropFirst(root.standardizedFileURL.pathComponents.count))
        try requireSearchDataFixture(file.standardizedFileURL.pathComponents.starts(with: root.standardizedFileURL.pathComponents)
            && !path.isEmpty && !path.contains(".."), "Every inventory item must remain inside the exact owned index")
        let relative = path.joined(separator: "/")
        let data = try searchDataFileBytes(file)
        bytes += data.count
        try requireSearchDataFixture(bytes <= 256 * 1024 * 1024 && result.count < 256,
                                     "Only the bounded miniTest10 index may be inventoried")
        // Tantivy owns these empty OS lock files. They are not index payload.
        if [".tantivy-meta.lock", ".tantivy-writer.lock"].contains(relative) {
            try requireSearchDataFixture(data.isEmpty, "Only empty original Tantivy lock files may be excluded")
            continue
        }
        if relative == "otzaria_search_identity.json" && !includeSecondaryIdentity { continue }
        result[relative] = searchDataDigest(data)
    }
    try requireSearchDataFixture(result["meta.json"] != nil && result["otzaria_prebuilt_installation.json"] != nil,
                                 "The original Tantivy index and trusted installation manifest must both exist")
    return result
}

private struct SearchDataNativeFixture {
    let appContainer: URL
    let root: URL
    let index: URL
    let database: URL
    let databaseManifest: URL
    let ownerMetadata: URL
    let ownerMetadataBytes: Data
    let databaseDigest: String
    let databaseManifestBytes: Data
    let indexPayload: [String: String]
    let engineMetadataBytes: Data
    let documentCount: Int

    func verifyOwner() throws {
        for directory in [root, index.deletingLastPathComponent(), database.deletingLastPathComponent(),
                          appContainer.appendingPathComponent("Documents", isDirectory: true)] {
            try requireSearchDataFixture(directory.standardizedFileURL.path == directory.resolvingSymlinksInPath().path,
                                         "Every fixture and backup parent must retain its canonical owned path")
        }
        try requireSearchDataFixture(try searchDataFileBytes(ownerMetadata, maximum: 65536) == ownerMetadataBytes,
                                     "The original owned Simulator container must be unchanged")
    }

    func verifyBooksAndOwner() throws {
        try verifyOwner()
        try requireSearchDataFixture(searchDataDigest(try searchDataFileBytes(database)) == databaseDigest,
                                     "Search repair must preserve the exact canonical miniature book database")
        try requireSearchDataFixture(try searchDataFileBytes(databaseManifest, maximum: 1024 * 1024) == databaseManifestBytes,
                                     "Search repair must preserve the original database installation manifest")
    }
}

@MainActor
private final class SearchDataNativeRestoration {
    let restore: @MainActor () throws -> Void
    init(_ restore: @escaping @MainActor () throws -> Void) { self.restore = restore }
    func run() throws { try restore() }
}

/// Actual status text, original controls, original engine and real miniature
/// artifact installation. No readiness override or replacement engine is used.
final class SearchDataNativeAcceptanceTests: R27NativeUIBase {
    override var readerTestTier: TestTier { .realUI }

    @MainActor
    private func launchSearchDataReader() throws {
        XCTAssertTrue(isPad, "This additional source-bound gate requires an iPad Simulator")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria")
        _ = try assertTarget(backend: "otzaria")
        try requireSearchDataFixture(app.launchEnvironment["OTZARIA_DATA_PROFILE"] == "miniTest10"
            && !app.launchArguments.contains("-smokeBypassBootstrap")
            && !app.launchArguments.contains("-OTZARIA_SHARED_ROOT_OVERRIDE")
            && app.launchEnvironment["OTZARIA_SHARED_ROOT_OVERRIDE"] == nil,
            "Only the normal miniature bootstrap with original storage ownership is allowed")
        for (key, value) in [("-OtzariaDataProfile", "miniTest10"),
                             ("-studyWorkspaceTestingNamespace", workspaceNamespace),
                             ("-preferredBackend", "otzaria")] {
            let matches = app.launchArguments.indices.filter { app.launchArguments[$0] == key }
            try requireSearchDataFixture(matches.count == 1, "Require one explicit original launch argument: \(key)")
            let index = try XCTUnwrap(matches.first)
            try requireSearchDataFixture(app.launchArguments.indices.contains(index + 1)
                && app.launchArguments[index + 1] == value, "Reject an unexpected fixture or namespace")
        }
    }

    @MainActor
    private func fixture() throws -> SearchDataNativeFixture {
        try requireSearchDataFixture(UUID(uuidString: workspaceNamespace) != nil, "Require this test's isolated UUID")
        let sidecar = try workspaceSidecarURL().standardizedFileURL
        let suffix = ["Library", "Application Support", "ChavrusaText", "StudyWorkspace", "UITests", workspaceNamespace + ".json"]
        try requireSearchDataFixture(Array(sidecar.pathComponents.suffix(suffix.count)) == suffix, "Require the exact owned sidecar")
        var container = sidecar
        for _ in suffix { container.deleteLastPathComponent() }
        let parent = try workspaceContainerParent().standardizedFileURL
        try requireSearchDataFixture(container.deletingLastPathComponent() == parent
            && UUID(uuidString: container.lastPathComponent) != nil, "Require the current original app installation")
        let simulatorData = parent.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_UDID"])
        try requireSearchDataFixture(UUID(uuidString: udid) != nil
            && simulatorData.lastPathComponent == "data"
            && simulatorData.deletingLastPathComponent().lastPathComponent.lowercased() == udid.lowercased()
            && Array(parent.pathComponents.suffix(3)) == ["Containers", "Data", "Application"],
            "Never access data outside this owned disposable Simulator")
        func metadata(_ owner: URL) throws -> (URL, Data, String?) {
            let url = owner.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            let bytes = try searchDataFileBytes(url, maximum: 65536)
            let value = try XCTUnwrap(PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any])
            return (url, bytes, value["MCMMetadataIdentifier"] as? String)
        }
        let appOwner = try metadata(container)
        try requireSearchDataFixture(appOwner.2 == "com.davidpovarsky.chavrusatext", "The sidecar must belong to the original app")
        let groups = simulatorData.appendingPathComponent("Containers/Shared/AppGroup", isDirectory: true)
        let children = (try? FileManager.default.contentsOfDirectory(
            at: groups, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])) ?? []
        try requireSearchDataFixture(children.count <= 256, "Bound App Group discovery to this Simulator")
        var owners: [(URL, URL, Data)] = []
        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink == false,
                  UUID(uuidString: child.lastPathComponent) != nil,
                  let value = try? metadata(child), value.2 == "group.com.davidpovarsky.itorah" else { continue }
            owners.append((child, value.0, value.1))
        }
        try requireSearchDataFixture(owners.count <= 1, "Ambiguous original App Group ownership is a failure")
        let owner = owners.first ?? (container.appendingPathComponent("Library/Application Support/Maktabah-Debug", isDirectory: true),
                                     appOwner.0, appOwner.1)
        let root = owner.0.standardizedFileURL
        try requireSearchDataFixture(root.pathComponents.starts(with: simulatorData.pathComponents)
            && root.path == root.resolvingSymlinksInPath().path, "Do not follow storage outside the exact Simulator")
        let profile = root.appendingPathComponent("Otzaria/Profiles/miniTest10", isDirectory: true)
        let database = profile.appendingPathComponent("database/seforim.db")
        let databaseManifest = profile.appendingPathComponent("database/seforim-installation.json")
        let databaseBytes = try searchDataFileBytes(database)
        let digest = searchDataDigest(databaseBytes)
        try requireSearchDataFixture(databaseBytes.count == 15470592
            && digest == "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef",
            "Only the existing source-pinned miniTest10 v6 database is eligible for fault injection")
        let databaseManifestBytes = try searchDataFileBytes(databaseManifest, maximum: 1024 * 1024)
        let databaseRecord = try XCTUnwrap(JSONSerialization.jsonObject(with: databaseManifestBytes) as? [String: Any])
        try requireSearchDataFixture(databaseRecord["profileID"] as? String == "miniTest10"
            && databaseRecord["profileVersion"] as? Int == 6, "The original database manifest must corroborate the profile")
        let index = profile.appendingPathComponent("otzariaSearch/managed-library", isDirectory: true)
        for extensionName in ["previous", "building", "installing"] {
            try requireSearchDataFixture(!FileManager.default.fileExists(atPath: index.appendingPathExtension(extensionName).path),
                                         "Do not mutate a fixture with an existing pending replacement")
        }
        let install = try XCTUnwrap(JSONSerialization.jsonObject(with: searchDataFileBytes(
            index.appendingPathComponent("otzaria_prebuilt_installation.json"), maximum: 1024 * 1024)) as? [String: Any])
        let source = try XCTUnwrap(install["sourceDatabase"] as? [String: Any])
        let lexical = try XCTUnwrap(install["lexicalArtifact"] as? [String: Any])
        let count = try XCTUnwrap(lexical["documentCount"] as? Int)
        try requireSearchDataFixture(install["profileID"] as? String == "miniTest10"
            && install["profileVersion"] as? Int == 6
            && source["databaseSHA256"] as? String == digest && count == 18879,
            "Require the genuine installed miniature artifact, never a manufactured index")
        let payload = try searchDataIndexInventory(index)
        let parts = try XCTUnwrap(lexical["parts"] as? [[String: Any]])
        let paths = try parts.map { try XCTUnwrap($0["destinationPath"] as? String) }
        try requireSearchDataFixture(lexical["fileCount"] as? Int == 7 && paths.count == 7
            && Set(paths).count == 7 && paths.contains("meta.json")
            && !paths.contains("otzaria_index_meta.json")
            && Set(payload.keys) == Set(paths).union([
                "otzaria_index_meta.json", "otzaria_prebuilt_installation.json"
            ]), "Require the exact original seven-file artifact and both retained metadata files")
        let engineMetadata = try searchDataFileBytes(
            index.appendingPathComponent("otzaria_index_meta.json"), maximum: 65536)
        try requireSearchDataFixture(searchDataDigest(engineMetadata) == payload["otzaria_index_meta.json"],
                                     "Capture the exact inventoried original engine metadata")
        let metadataAttachment = XCTAttachment(data: engineMetadata, uniformTypeIdentifier: "public.json")
        metadataAttachment.name = "search-data-original-engine-metadata"
        metadataAttachment.lifetime = .keepAlways
        add(metadataAttachment)
        let result = SearchDataNativeFixture(appContainer: container, root: root, index: index,
            database: database, databaseManifest: databaseManifest, ownerMetadata: owner.1,
            ownerMetadataBytes: owner.2, databaseDigest: digest, databaseManifestBytes: databaseManifestBytes,
            indexPayload: payload, engineMetadataBytes: engineMetadata, documentCount: count)
        try result.verifyBooksAndOwner()
        let proof: [String: Any] = ["simulatorUDID": udid, "namespace": workspaceNamespace,
            "storageRoot": root.path, "databaseSHA256": digest,
            "indexPayloadSHA256": result.indexPayload, "expectedDocuments": count,
            "scope": "owned miniature fixture identity; actual UI status and query are separate assertions"]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "search-data-original-fixture-ownership"
        attachment.lifetime = .keepAlways
        add(attachment)
        return result
    }

    @MainActor
    @discardableResult
    private func backupForMutation(_ value: SearchDataNativeFixture) throws -> Int {
        app.terminate()
        try requireSearchDataFixture(app.state == .notRunning, "Close every app engine before changing an owned fixture")
        try value.verifyBooksAndOwner()
        let original = try searchDataIndexInventory(value.index, includeSecondaryIdentity: true)
        let permissions = try XCTUnwrap((try FileManager.default.attributesOfItem(
            atPath: value.index.deletingLastPathComponent().path)[.posixPermissions]) as? NSNumber).intValue
        try requireSearchDataFixture(permissions & 0o222 != 0, "The original owned index parent must be writable")
        let backup = value.appContainer.appendingPathComponent("Documents/search-data-" + workspaceNamespace, isDirectory: true)
        try requireSearchDataFixture(!FileManager.default.fileExists(atPath: backup.path), "Never overwrite another backup")
        try FileManager.default.copyItem(at: value.index, to: backup)
        try requireSearchDataFixture(try searchDataIndexInventory(backup, includeSecondaryIdentity: true) == original,
                                     "The complete original index backup must be byte-verified before any mutation")
        let application = app!
        let restore = SearchDataNativeRestoration {
            application.terminate()
            try requireSearchDataFixture(application.state == .notRunning, "Stop the original app before fixture restoration")
            // Book-integrity failures must not prevent cleanup of this test's
            // index fault. Changed storage ownership still forbids any write.
            try value.verifyOwner()
            try FileManager.default.setAttributes([.posixPermissions: permissions],
                ofItemAtPath: value.index.deletingLastPathComponent().path)
            try requireSearchDataFixture(try searchDataIndexInventory(backup, includeSecondaryIdentity: true) == original,
                                         "Never restore an altered or unverified backup")
            for extensionName in ["previous", "building", "installing"] {
                let temporary = value.index.appendingPathExtension(extensionName)
                if FileManager.default.fileExists(atPath: temporary.path) {
                    // fixture() proved these exact sibling paths absent before
                    // the test. Never touch downloads or another profile.
                    let values = try temporary.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    try requireSearchDataFixture(values.isDirectory == true && values.isSymbolicLink == false
                        && temporary.deletingLastPathComponent() == value.index.deletingLastPathComponent()
                        && temporary.standardizedFileURL.path == temporary.resolvingSymlinksInPath().path,
                        "Only this test's exact original staging/previous directories may be removed")
                    try FileManager.default.removeItem(at: temporary)
                }
            }
            if FileManager.default.fileExists(atPath: value.index.path) { try FileManager.default.removeItem(at: value.index) }
            try FileManager.default.moveItem(at: backup, to: value.index)
            try requireSearchDataFixture(try searchDataIndexInventory(value.index, includeSecondaryIdentity: true) == original,
                                         "Restore the exact original fixture bytes even after a test failure")
            let restoredMode = try XCTUnwrap((try FileManager.default.attributesOfItem(
                atPath: value.index.deletingLastPathComponent().path)[.posixPermissions]) as? NSNumber).intValue
            try requireSearchDataFixture(restoredMode == permissions, "Restore the exact original POSIX permissions")
            try value.verifyBooksAndOwner()
        }
        addTeardownBlock { try await restore.run() }
        return permissions
    }

    @MainActor
    private func openSearchData() throws {
        let tab = findTabButton(hebrew: "חיפוש", english: "Search")
        XCTAssertTrue(tab.exists || tab.waitForExistence(timeout: 30))
        tap(tab)
        let more = app.buttons["global-search-more"]
        XCTAssertTrue(more.exists || more.waitForExistence(timeout: 30))
        tap(more)
        tap(app.buttons["global-search-data"])
        XCTAssertTrue(app.staticTexts["search-data-otzaria-status"].waitForExistence(timeout: 30))
    }

    @MainActor
    private func status(_ predicate: NSPredicate, named name: String, timeout: TimeInterval = 60) {
        let target = app.staticTexts["search-data-otzaria-status"]
        let list = app.descendants(matching: .any)["search-data-screen"]
        for _ in 0..<6 {
            if target.exists && target.isHittable { break }
            XCTAssertTrue(list.exists)
            list.swipeDown()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Observe the visible original status row")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: target)], timeout: timeout), .completed,
                       "The original Search Data status must reflect the actual engine and on-disk fixture")
        let attachment = XCTAttachment(string: target.label + "\n" + app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        capture(name)
    }

    @MainActor
    private func ready(_ value: SearchDataNativeFixture, named name: String, timeout: TimeInterval = 60) {
        status(NSPredicate(format: "label == %@", "האינדקס מוכן (\(value.documentCount) מסמכים)"), named: name, timeout: timeout)
    }

    @MainActor
    private func dataAction(_ identifier: String, earlier: Bool = false) throws -> XCUIElement {
        let action = app.buttons[identifier]
        let list = app.descendants(matching: .any)["search-data-screen"]
        for _ in 0..<6 {
            if action.exists && action.isHittable { return action }
            XCTAssertTrue(list.exists)
            if earlier { list.swipeDown() } else { list.swipeUp() }
        }
        XCTFail("The original Search Data action must be reachable: \(identifier)")
        throw SearchDataNativeFixtureError.rejected(identifier)
    }

    @MainActor
    private func actualQueryAfterClosingData() throws {
        tap(try dataAction("search-data-close", earlier: true))
        let field = app.descendants(matching: .any)["global-search-query"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        tap(field)
        if let value = field.value as? String, !value.isEmpty, value != field.placeholderValue {
            let clear = field.buttons.allElementsBoundByIndex.filter(\.isHittable)
            XCTAssertEqual(clear.count, 1)
            tap(try XCTUnwrap(clear.first))
        }
        field.typeText("בראשית ברא\n") // Existing canonical miniTest10 golden query.
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-result-preview-toggle-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 90), "A ready label alone cannot establish real search results")
        XCTAssertTrue(row.isHittable)
        capture("search-data-original-query-results")
    }

    @MainActor
    private func verifyRecoveredAndCold(
        _ value: SearchDataNativeFixture,
        reinstallationStartedAt: Date? = nil
    ) throws {
        ready(value, named: "search-data-after-recovery", timeout: 180)
        try value.verifyBooksAndOwner()
        var expectedPayload = value.indexPayload
        if let reinstallationStartedAt {
            let repairedMetadata = try searchDataFileBytes(
                value.index.appendingPathComponent("otzaria_index_meta.json"), maximum: 65536)
            let observedAt = Date()
            let metadataAttachment = XCTAttachment(data: repairedMetadata, uniformTypeIdentifier: "public.json")
            metadataAttachment.name = "search-data-reinstalled-engine-metadata"
            metadataAttachment.lifetime = .keepAlways
            add(metadataAttachment)
            let proof: [String: Any] = [
                "reinstallationStartedAt": reinstallationStartedAt.timeIntervalSince1970,
                "observedAt": observedAt.timeIntervalSince1970,
                "originalSHA256": searchDataDigest(value.engineMetadataBytes),
                "repairedSHA256": searchDataDigest(repairedMetadata),
                "scope": "original engine-generated creation second; every other metadata byte and all nine files remain checked"
            ]
            let attachment = XCTAttachment(
                data: try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]),
                uniformTypeIdentifier: "public.json")
            attachment.name = "search-data-reinstallation-metadata-interval"
            attachment.lifetime = .keepAlways
            add(attachment)
            try searchDataVerifyRegeneratedEngineMetadata(
                original: value.engineMetadataBytes, repaired: repairedMetadata,
                reinstallationStartedAt: reinstallationStartedAt, observedAt: observedAt)
            expectedPayload["otzaria_index_meta.json"] = searchDataDigest(repairedMetadata)
        }
        XCTAssertEqual(try searchDataIndexInventory(value.index), expectedPayload)
        try actualQueryAfterClosingData()
        app.terminate()
        try launchSearchDataReader()
        try openSearchData()
        ready(value, named: "search-data-after-repaired-cold-launch")
        try actualQueryAfterClosingData()
        try value.verifyBooksAndOwner()
        XCTAssertEqual(try searchDataIndexInventory(value.index), expectedPayload,
                       "Cold validation must preserve every repaired index and metadata byte")
    }

    @MainActor
    func testHealthySearchDataAndColdLaunchMatchInstalledDocumentCount() throws {
        try launchSearchDataReader()
        let value = try fixture()
        try openSearchData()
        ready(value, named: "search-data-healthy-original-status")
        try actualQueryAfterClosingData()
        app.terminate()
        try launchSearchDataReader()
        try openSearchData()
        ready(value, named: "search-data-healthy-cold-status")
        try actualQueryAfterClosingData()
        try value.verifyBooksAndOwner()
        XCTAssertEqual(try searchDataIndexInventory(value.index), value.indexPayload)
    }

    @MainActor
    func testMissingSecondaryIdentityRecoversOriginalIndexAndColdLaunch() throws {
        try launchSearchDataReader()
        let value = try fixture()
        try openSearchData()
        ready(value, named: "search-data-before-secondary-metadata-loss")
        try backupForMutation(value)
        let identity = value.index.appendingPathComponent("otzaria_search_identity.json")
        _ = try searchDataFileBytes(identity, maximum: 1024 * 1024)
        try FileManager.default.removeItem(at: identity)
        XCTAssertFalse(FileManager.default.fileExists(atPath: identity.path))
        try launchSearchDataReader()
        try openSearchData()
        ready(value, named: "search-data-trusted-secondary-metadata-recovered")
        let recovered = try searchDataFileBytes(identity, maximum: 1024 * 1024)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: recovered) as? [String: Any])
        try verifyRecoveredAndCold(value)
        XCTAssertEqual(try searchDataFileBytes(identity, maximum: 1024 * 1024), recovered,
                       "A second cold validation must retain the recovered canonical identity")
    }

    @MainActor
    func testCorruptIndexShowsRepairRequiredAndOriginalRepairSurvivesColdLaunch() throws {
        try launchSearchDataReader()
        let value = try fixture()
        try openSearchData()
        ready(value, named: "search-data-before-corrupt-owned-meta")
        try backupForMutation(value)
        let meta = value.index.appendingPathComponent("meta.json")
        _ = try searchDataFileBytes(meta)
        let corrupt = Data("owned miniTest10 Native negative fixture; deliberately invalid JSON\n".utf8)
        try corrupt.write(to: meta, options: .atomic)
        XCTAssertEqual(try searchDataFileBytes(meta), corrupt)
        try launchSearchDataReader()
        try openSearchData()
        status(NSPredicate(format: "label BEGINSWITH %@", "נדרש תיקון לאינדקס:"), named: "search-data-real-corruption-fails-closed")
        try value.verifyBooksAndOwner()
        let repair = try dataAction("search-data-repair-otzaria")
        let reinstallationStartedAt = Date()
        tap(repair)
        try verifyRecoveredAndCold(value, reinstallationStartedAt: reinstallationStartedAt)
    }

    @MainActor
    func testMissingIndexUsesOriginalRemoveAndInstallWithoutChangingBooks() throws {
        try launchSearchDataReader()
        let value = try fixture()
        try openSearchData()
        ready(value, named: "search-data-before-original-remove")
        try backupForMutation(value)
        try launchSearchDataReader()
        try openSearchData()
        ready(value, named: "search-data-original-remove-precondition")
        tap(try dataAction("search-data-remove-otzaria"))
        status(NSPredicate(format: "label == %@", "האינדקס עדיין לא נבנה"), named: "search-data-original-removal-is-not-ready")
        XCTAssertFalse(FileManager.default.fileExists(atPath: value.index.path))
        try value.verifyBooksAndOwner()
        let repair = try dataAction("search-data-repair-otzaria")
        let reinstallationStartedAt = Date()
        tap(repair)
        try verifyRecoveredAndCold(value, reinstallationStartedAt: reinstallationStartedAt)
    }

    @MainActor
    func testRepairFailureKeepsOriginalIndexAndExposesAWorkingRetry() throws {
        try launchSearchDataReader()
        let value = try fixture()
        try openSearchData()
        ready(value, named: "search-data-before-owned-install-write-denial")
        let permissions = try backupForMutation(value)
        let meta = value.index.appendingPathComponent("meta.json")
        try Data("owned miniTest10 repair failure fixture; deliberately invalid JSON\n".utf8)
            .write(to: meta, options: .atomic)
        try launchSearchDataReader()
        try openSearchData()
        status(NSPredicate(format: "label BEGINSWITH %@", "נדרש תיקון לאינדקס:"), named: "search-data-before-real-install-failure")
        let beforeFailure = try searchDataIndexInventory(value.index, includeSecondaryIdentity: true)
        let parent = value.index.deletingLastPathComponent()
        // Actual filesystem denial on this disposable miniature index parent.
        // The teardown registered before the mutation restores both permissions
        // and complete original bytes, including after assertion failure.
        try FileManager.default.setAttributes([.posixPermissions: permissions & ~0o222], ofItemAtPath: parent.path)
        try requireSearchDataFixture(!FileManager.default.isWritableFile(atPath: parent.path),
                                     "Require an actual OS write denial; never inject a fake failed status")
        tap(try dataAction("search-data-repair-otzaria"))
        status(NSPredicate(format: "label BEGINSWITH %@", "שגיאת אינדוקס:"), named: "search-data-real-install-failure-is-visible", timeout: 180)
        try value.verifyBooksAndOwner()
        XCTAssertEqual(try searchDataIndexInventory(value.index, includeSecondaryIdentity: true), beforeFailure,
                       "A failed replacement must preserve even the original damaged index for recovery")
        let retry = try dataAction("search-data-repair-otzaria")
        XCTAssertTrue(retry.isEnabled && retry.isHittable, "The original repair control must remain actionable after failure")
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: parent.path)
        try requireSearchDataFixture(FileManager.default.isWritableFile(atPath: parent.path), "Restore the real write precondition")
        let reinstallationStartedAt = Date()
        tap(retry)
        try verifyRecoveredAndCold(value, reinstallationStartedAt: reinstallationStartedAt)
    }

}


// MARK: - Published production v40 through the original application

/// These gates use the already installed, managed production v40 database.
/// Nothing is copied into the app or substituted for an engine. The runner must
/// keep this app installation between the install gate and the page gates.
final class PublishedProductionSearchDataTests: MaktabahUITestBase {
    private let traceNamespace = UUID().uuidString
    private let v40Digest = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
    private let otzariaArtifact = "f8fea8efcac5fc06b272a061b44f0e0ee66d16ae12f1e864f9510e437e929139"
    private let zayitArtifact = "17cabb80e86ac8c2d1a3ce16a4e1457d4351709798f2b91a84120d4dd0c6c480"

    private struct Installation {
        let container: URL
        let root: URL
        let owner: URL
        let ownerBytes: Data
        let manifestBytes: Data
        var database: URL { root.appendingPathComponent("Otzaria/seforim.db") }
        var manifest: URL { root.appendingPathComponent("Otzaria/seforim-installation.json") }
        var otzariaManifest: URL {
            root.appendingPathComponent("Otzaria/TantivySearchIndex/managed-library/otzaria_prebuilt_installation.json")
        }
        var zayitManifest: URL { root.appendingPathComponent("Otzaria/Zayit/zayit-installation.json") }
    }

    private func bytes(_ url: URL, maximum: Int = 1024 * 1024) throws -> Data {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try requireSearchDataFixture(info.isRegularFile == true && info.isSymbolicLink == false
            && url.standardizedFileURL.path == url.resolvingSymlinksInPath().path
            && (info.fileSize ?? maximum + 1) <= maximum, "Require a bounded, regular original file: \(url.lastPathComponent)")
        return try Data(contentsOf: url)
    }

    private func object(_ url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: bytes(url)) as? [String: Any])
    }

    private func databaseDigest(_ url: URL) throws -> String {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        try requireSearchDataFixture(info.isRegularFile == true && info.isSymbolicLink == false
            && info.fileSize == 4_355_063_808
            && url.standardizedFileURL.path == url.resolvingSymlinksInPath().path,
            "Only the exact installed production v40 database is eligible")
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        var count: Int64 = 0
        while let block = try handle.read(upToCount: 4 * 1024 * 1024), !block.isEmpty {
            digest.update(data: block)
            count += Int64(block.count)
            try requireSearchDataFixture(count <= 4_355_063_808, "The database cannot grow during observation")
        }
        XCTAssertEqual(count, 4_355_063_808)
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func installation() throws -> Installation {
        let supplied = try XCTUnwrap(ProcessInfo.processInfo.environment["PRODUCTION_SEARCH_CONTAINER_PARENT"],
            "Runner must supply this owned Simulator's Containers/Data/Application directory")
        let parent = URL(fileURLWithPath: supplied, isDirectory: true).standardizedFileURL
        let simulatorData = parent.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let udid = try XCTUnwrap(ProcessInfo.processInfo.environment["SIMULATOR_UDID"])
        try requireSearchDataFixture(UUID(uuidString: udid) != nil
            && simulatorData.lastPathComponent == "data"
            && simulatorData.deletingLastPathComponent().lastPathComponent.lowercased() == udid.lowercased()
            && Array(parent.pathComponents.suffix(3)) == ["Containers", "Data", "Application"],
            "Never inspect another Simulator or an external corpus")
        func owners(_ parent: URL, identifier: String) throws -> [(URL, URL, Data)] {
            let children = (try? FileManager.default.contentsOfDirectory(at: parent,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])) ?? []
            try requireSearchDataFixture(children.count <= 256, "Bound original container discovery")
            return try children.compactMap { child in
                let info = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard info.isDirectory == true, info.isSymbolicLink == false,
                      UUID(uuidString: child.lastPathComponent) != nil else { return nil }
                let metadata = child.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                guard let data = try? bytes(metadata, maximum: 65536),
                      let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      value["MCMMetadataIdentifier"] as? String == identifier else { return nil }
                return (child, metadata, data)
            }
        }
        let apps = try owners(parent, identifier: "com.davidpovarsky.chavrusatext")
        try requireSearchDataFixture(apps.count == 1, "Require exactly one original app installation")
        let appOwner = try XCTUnwrap(apps.first)
        let groups = try owners(simulatorData.appendingPathComponent("Containers/Shared/AppGroup"),
                                identifier: "group.com.davidpovarsky.itorah")
        try requireSearchDataFixture(groups.count <= 1, "Ambiguous App Group ownership is a failure")
        let owner = groups.first ?? (appOwner.0.appendingPathComponent("Library/Application Support/Maktabah-Debug"),
                                     appOwner.1, appOwner.2)
        let root = owner.0.standardizedFileURL
        try requireSearchDataFixture(root.pathComponents.starts(with: simulatorData.pathComponents)
            && root.path == root.resolvingSymlinksInPath().path, "Storage must remain inside this exact installation")
        let manifest = root.appendingPathComponent("Otzaria/seforim-installation.json")
        let record = try object(manifest)
        XCTAssertEqual(record["profileID"] as? String ?? "production", "production")
        XCTAssertEqual(record["releaseTag"] as? String, "v40-20261123094345")
        XCTAssertEqual((record["releaseID"] as? NSNumber)?.int64Value, 455_390_662)
        XCTAssertEqual((record["databaseFileSize"] as? NSNumber)?.int64Value, 4_355_063_808)
        return Installation(container: appOwner.0, root: root, owner: owner.1,
                            ownerBytes: owner.2, manifestBytes: try bytes(manifest))
    }

    private func verifyUnchanged(_ value: Installation, hashDatabase: Bool = true) throws {
        XCTAssertEqual(try bytes(value.owner, maximum: 65536), value.ownerBytes, "Retain original storage ownership")
        XCTAssertEqual(try bytes(value.manifest), value.manifestBytes, "Index operations must preserve the installed v40 manifest")
        if hashDatabase { XCTAssertEqual(try databaseDigest(value.database), v40Digest) }
    }

    private func verifyPackages(_ value: Installation) throws {
        let otzaria = try object(value.otzariaManifest)
        let zayit = try object(value.zayitManifest)
        XCTAssertEqual(otzaria["artifactIdentity"] as? String, otzariaArtifact)
        XCTAssertEqual(zayit["artifactIdentity"] as? String, zayitArtifact)
        for manifest in [otzaria, zayit] {
            XCTAssertEqual(manifest["profileID"] as? String ?? "production", "production")
        }
        let source = try XCTUnwrap(otzaria["sourceDatabase"] as? [String: Any])
        XCTAssertEqual(source["releaseTag"] as? String, "v40-20261123094345")
        XCTAssertEqual(source["databaseSHA256"] as? String, v40Digest)
        XCTAssertEqual((source["bookCount"] as? NSNumber)?.intValue, 8259)
        XCTAssertEqual((source["documentCount"] as? NSNumber)?.intValue, 7_925_185)
        let lexical = try XCTUnwrap(otzaria["lexicalArtifact"] as? [String: Any])
        XCTAssertEqual((lexical["documentCount"] as? NSNumber)?.intValue, 7_925_185)
        XCTAssertEqual((lexical["parts"] as? [Any])?.count, 15)
        let required = try XCTUnwrap(zayit["requiredDatabase"] as? [String: Any])
        XCTAssertEqual(required["releaseTag"] as? String, "v40-20261123094345")
        XCTAssertEqual(required["canonicalSHA256"] as? String, v40Digest)
        let counts = try XCTUnwrap(zayit["counts"] as? [String: Any])
        XCTAssertEqual((counts["books"] as? NSNumber)?.intValue, 8259)
        XCTAssertEqual((counts["lines"] as? NSNumber)?.intValue, 7_920_224)
        XCTAssertEqual((counts["documents"] as? NSNumber)?.intValue, 7_930_286)
        XCTAssertEqual((zayit["parts"] as? [Any])?.count, 74)
        for (name, path) in [("otzaria", value.otzariaManifest), ("zayit", value.zayitManifest)] {
            let attachment = XCTAttachment(data: try bytes(path), uniformTypeIdentifier: "public.json")
            attachment.name = "published-v40-" + name + "-actual-installed-manifest"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func control(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    @discardableResult
    private func required(_ id: String, timeout: TimeInterval = 30) throws -> XCUIElement {
        let value = control(id)
        try requireSearchDataFixture(value.waitForExistence(timeout: timeout), "Original UI control is absent: " + id)
        return value
    }

    @MainActor
    private func eventually(_ reason: String, timeout: TimeInterval = 90,
                            _ condition: @escaping @MainActor () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, reason)
    }

    @MainActor
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    @MainActor
    private func launchProduction(unitMode: String? = "line") throws {
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            try requireSearchDataFixture(ProcessInfo.processInfo.environment[key] == nil,
                "Real managed installation acceptance forbids external storage override " + key)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let unitArguments = unitMode.map { ["-otzaria_reader_unit_mode", $0] } ?? []
        launchWithTier(.production, backend: "otzaria", extraArgs: [
            "-GlobalSearchNativeTraceEnabled", "YES", "-GlobalSearchNativeTraceNamespace", traceNamespace,
            "-lastSelectedTab", "0", "-ChavrusaTextFaithfulReaderUIEnabled", "YES"
        ] + unitArguments)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        XCTAssertFalse(app.launchArguments.contains("-studyWorkspaceTestingNamespace"))
        XCTAssertEqual(app.launchEnvironment["OTZARIA_DATA_PROFILE"], "production")
        let tab = findTabButton(hebrew: "חיפוש", english: "Search")
        try requireSearchDataFixture(tab.waitForExistence(timeout: 120), "Normal production bootstrap must expose Search")
        tab.tap()
        try required("global-search-screen", timeout: 60)
        try required("global-search-query")
    }

    @MainActor
    private func openData() throws {
        try required("global-search-more").tap()
        try required("global-search-data").tap()
        try required("search-data-otzaria-status")
        try required("search-data-zayit-status")
    }

    @MainActor
    private func reachDataAction(_ id: String) throws -> XCUIElement {
        for _ in 0..<8 {
            let value = control(id)
            if value.exists && value.isHittable { return value }
            try required("search-data-screen").swipeUp()
        }
        throw SearchDataNativeFixtureError.rejected("Original action is not reachable: " + id)
    }

    @MainActor
    private func assertReady() {
        eventually("The original UI must recognize both actual installed v40 packages", timeout: 180) {
            self.app.staticTexts["search-data-otzaria-status"].label == "האינדקס מוכן (7925185 מסמכים)"
                && self.app.staticTexts["search-data-zayit-status"].label.hasPrefix("מוכן · ")
        }
    }

    @MainActor
    func testPublishedV40PackagesInstallThroughOriginalSearchDataAndColdReopen() throws {
        try launchProduction()
        let value = try installation()
        try verifyUnchanged(value)
        XCTAssertFalse(FileManager.default.fileExists(atPath: value.otzariaManifest.path),
                       "An existing index cannot be credited as a new UI installation")
        XCTAssertFalse(FileManager.default.fileExists(atPath: value.zayitManifest.path),
                       "An existing Zayit installation cannot be credited as a new UI installation")
        try openData()
        XCTAssertNotEqual(try required("search-data-otzaria-status").label, "האינדקס מוכן (7925185 מסמכים)")
        capture("published-v40-before-original-install")
        try reachDataAction("search-data-install-missing").tap()
        eventually("The original sequential installer must download, validate and activate both published packages",
                   timeout: 5400) {
            let message = self.app.staticTexts["search-data-install-message"]
            return message.exists && message.label == "כל הרכיבים שנבחרו מוכנים."
        }
        try verifyPackages(value)
        try verifyUnchanged(value)
        try required("search-data-screen").swipeDown()
        assertReady()
        capture("published-v40-original-install-ready")
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        try launchProduction()
        let reopened = try installation()
        XCTAssertEqual(reopened.root, value.root)
        XCTAssertEqual(reopened.container, value.container)
        try verifyUnchanged(value, hashDatabase: false)
        try verifyPackages(reopened)
        try openData()
        assertReady()
        capture("published-v40-cold-reopen-ready")
    }

    private func events(_ value: Installation) throws -> [[String: Any]] {
        let url = value.container.appendingPathComponent("Documents/OtzariaLogs/search-native-" + traceNamespace + ".jsonl")
        let data = try bytes(url, maximum: 8 * 1024 * 1024)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        return try text.split(separator: "\n").map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }

    private func canonical(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Reads the exact installed production database with SQLite's read-only flag.
    /// Only the test owns this connection; it cannot write or supply app results.
    private func sqlLine(database: OpaquePointer, book: Int, line: Int) throws -> [String: Any] {
        var statement: OpaquePointer?
        let query = "SELECT l.id, l.bookId, l.lineIndex, b.title, COALESCE(l.heRef, '') FROM line l JOIN book b ON b.id=l.bookId WHERE l.bookId=? AND l.lineIndex=?"
        XCTAssertEqual(sqlite3_prepare_v2(database, query, -1, &statement, nil), SQLITE_OK)
        let statementValue = try XCTUnwrap(statement)
        defer { sqlite3_finalize(statementValue) }
        XCTAssertEqual(sqlite3_bind_int64(statementValue, 1, Int64(book)), SQLITE_OK)
        XCTAssertEqual(sqlite3_bind_int64(statementValue, 2, Int64(line)), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(statementValue), SQLITE_ROW, "Every result must address an actual SQL line")
        let title = try XCTUnwrap(sqlite3_column_text(statementValue, 3))
        let reference = try XCTUnwrap(sqlite3_column_text(statementValue, 4))
        let row: [String: Any] = [
            "lineID": sqlite3_column_int64(statementValue, 0),
            "bookID": sqlite3_column_int64(statementValue, 1),
            "lineIndex": sqlite3_column_int64(statementValue, 2),
            "bookTitle": String(cString: title), "reference": String(cString: reference)
        ]
        XCTAssertEqual(sqlite3_step(statementValue), SQLITE_DONE, "SQL position must be unambiguous")
        return row
    }

    @MainActor
    private func chooseEngine(_ engine: String) throws {
        try required("global-search-mode").tap()
        try required("global-search-mode-" + (engine == "zayit" ? "zayit" : "advanced")).tap()
        if engine == "zayit" {
            try required("global-search-options").tap()
            let picker = try required("global-search-zayit-match")
            for _ in 0..<6 {
                if picker.isHittable { break }
                try required("global-search-options-content").swipeUp()
            }
            picker.tap()
            let flexible = app.buttons["גמיש — מרחק 5 מילים"]
            XCTAssertTrue(flexible.waitForExistence(timeout: 20))
            flexible.tap()
            try required("global-search-options-done").tap()
        }
    }

    @MainActor
    private func loadedCount(filtered: Bool) throws -> Int {
        let label = try required("global-search-count").label
        let numbers = label.split { !$0.isNumber }.compactMap { Int($0) }
        if filtered {
            XCTAssertGreaterThanOrEqual(numbers.count, 2)
            XCTAssertEqual(numbers.first, 0)
            return try XCTUnwrap(numbers.dropFirst().first)
        }
        return try XCTUnwrap(numbers.first)
    }

    @MainActor
    private func assertPublishedPages(engine: String, pages: Int, pageSize: Int) throws {
        try launchProduction()
        let value = try installation()
        try verifyUnchanged(value)
        try verifyPackages(value)
        try chooseEngine(engine)
        let field = try required("global-search-query")
        field.tap()
        if let previous = field.value as? String, !previous.isEmpty && previous != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText("בראשית")
        eventually("Original native field must contain the whole submitted query") { field.value as? String == "בראשית" }
        field.typeText("\n")
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "search-result-preview-toggle-")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 180))
        XCTAssertEqual(try loadedCount(filtered: false), pageSize,
                       "The first visible count must represent the actual first page")
        capture("published-v40-" + engine + "-page-" + String(pageSize))
        try required("global-search-result-filter-toggle").tap()
        let filter = try required("global-search-result-filter")
        let token = "no-production-book-" + UUID().uuidString
        filter.tap()
        filter.typeText(token + "\n")
        try required("global-search-filter-empty")
        XCTAssertEqual(try loadedCount(filtered: true), pageSize)
        for page in 2...pages {
            let more = app.buttons.matching(NSPredicate(format: "label == %@", "Load more results")).firstMatch
            XCTAssertTrue(more.waitForExistence(timeout: 30))
            XCTAssertTrue(more.isHittable)
            more.tap()
            eventually("Original native loaded count must advance to \(page * pageSize)", timeout: 180) {
                (try? self.loadedCount(filtered: true)) == page * pageSize
                    && !self.control("global-search-page-error").exists
                    && !self.control("global-search-cancel").exists
            }
            capture("published-v40-" + engine + "-page-" + String(page * pageSize))
        }
        eventually("Published original model must settle at the visible native count") {
            guard let event = try? self.events(value).last(where: {
                $0["event"] as? String == "published" && $0["engine"] as? String == engine
            }), let items = event["items"] as? [Any] else { return false }
            return items.count == pages * pageSize
        }
        let observed = try events(value).filter { $0["engine"] as? String == engine }
        XCTAssertEqual(Set(observed.compactMap { $0["sessionID"] as? String }).count, 1)
        XCTAssertEqual(Set(observed.compactMap { ($0["processID"] as? NSNumber)?.intValue }).count, 1)
        let provider = observed.filter { $0["event"] as? String == "provider" }
        XCTAssertEqual(provider.count, pages)
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(value.database.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil), SQLITE_OK)
        let db = try XCTUnwrap(database)
        defer { sqlite3_close(db) }
        var order: [String] = []
        var source: [String: [String: Any]] = [:]
        var sql: [String: [String: Any]] = [:]
        var retainedItems: [String: [String: Any]] = [:]
        for (index, event) in provider.enumerated() {
            XCTAssertEqual(event["namespace"] as? String, traceNamespace)
            XCTAssertEqual(event["profileID"] as? String, "production")
            XCTAssertEqual((event["submissionRevision"] as? NSNumber)?.intValue, 1)
            let request = try XCTUnwrap(event["request"] as? [String: Any])
            XCTAssertEqual(request["querySHA256"] as? String, searchDataDigest(Data("בראשית".utf8)))
            XCTAssertNil(request["query"])
            XCTAssertEqual((request["offset"] as? NSNumber)?.intValue, index * pageSize)
            XCTAssertEqual((request["limit"] as? NSNumber)?.intValue, pageSize)
            let page = try XCTUnwrap(event["page"] as? [String: Any])
            let rows = try XCTUnwrap(page[engine == "zayit" ? "hits" : "results"] as? [[String: Any]])
            XCTAssertEqual(rows.count, pageSize)
            for row in rows {
                let book: Int
                let line: Int
                let id: String
                if engine == "zayit" {
                    book = try XCTUnwrap((row["book_id"] as? NSNumber)?.intValue)
                    line = try XCTUnwrap((row["line_index"] as? NSNumber)?.intValue)
                    id = "zayit:production:\(try XCTUnwrap((row["line_id"] as? NSNumber)?.intValue))"
                } else {
                    let path = try XCTUnwrap(row["filePath"] as? String)
                    XCTAssertTrue(path.hasPrefix("otzaria-book:"))
                    book = try XCTUnwrap(Int(path.dropFirst("otzaria-book:".count)))
                    line = try XCTUnwrap((row["segment"] as? NSNumber)?.intValue)
                    id = "otzaria:\(path):\(try XCTUnwrap((row["id"] as? NSNumber)?.uint64Value)):\(line)"
                }
                let original = try sqlLine(database: db, book: book, line: line)
                XCTAssertEqual(row[engine == "zayit" ? "book_title" : "title"] as? String, original["bookTitle"] as? String)
                if engine == "zayit" {
                    XCTAssertEqual((row["line_id"] as? NSNumber)?.int64Value, (original["lineID"] as? NSNumber)?.int64Value)
                }
                XCTAssertEqual(row["reference"] as? String ?? "", original["reference"] as? String ?? "")
                XCTAssertNil(source[id], "The first real pages must retain unique original identities")
                order.append(id)
                source[id] = row
                sql[id] = original
            }
            XCTAssertEqual((event["nextOffset"] as? NSNumber)?.intValue, (index + 1) * pageSize)
            if engine == "zayit" {
                let accumulated = try XCTUnwrap(event["accumulatedSource"] as? [[String: Any]])
                XCTAssertEqual(accumulated.count, order.count)
                for (id, row) in zip(order, accumulated) {
                    XCTAssertEqual(try canonical(try XCTUnwrap(source[id])), try canonical(row))
                }
            } else {
                let records = try XCTUnwrap(event["retainedRecords"] as? [[String: Any]])
                XCTAssertEqual(records.count, order.count)
                for (id, record) in zip(order, records) {
                    XCTAssertEqual(try canonical(try XCTUnwrap(source[id])), try canonical(try XCTUnwrap(record["metadata"])))
                    let item = try XCTUnwrap(record["item"] as? [String: Any])
                    if let prior = retainedItems[id] { XCTAssertEqual(try canonical(item), try canonical(prior)) }
                    retainedItems[id] = item
                }
            }
        }
        let publication = try XCTUnwrap(observed.last { $0["event"] as? String == "published" })
        let items = try XCTUnwrap(publication["items"] as? [[String: Any]])
        XCTAssertEqual(items.compactMap { $0["id"] as? String }, order)
        XCTAssertEqual(Set(order).count, pages * pageSize)
        for item in items {
            let id = try XCTUnwrap(item["id"] as? String)
            let original = try XCTUnwrap(sql[id])
            let raw = try XCTUnwrap(source[id])
            let book = try XCTUnwrap((original["bookID"] as? NSNumber)?.intValue)
            let line = try XCTUnwrap((original["lineIndex"] as? NSNumber)?.intValue)
            XCTAssertEqual((item["bookID"] as? NSNumber)?.intValue, book)
            XCTAssertEqual((item["lineIndex"] as? NSNumber)?.intValue, line)
            XCTAssertEqual(item["bookTitle"] as? String, original["bookTitle"] as? String)
            XCTAssertEqual(item["reference"] as? String, raw["reference"] as? String ?? "")
            XCTAssertEqual(item["locator"] as? String, "otzaria|book:\(book)|line:\(line)")
            if engine == "zayit" {
                XCTAssertEqual(item["highlightTerms"] as? [String], raw["matched_terms"] as? [String])
            } else {
                XCTAssertEqual(try canonical(item), try canonical(try XCTUnwrap(retainedItems[id])))
            }
        }
        let evidence = XCTAttachment(data: try canonical(["events": observed, "independentSQL": sql]),
                                     uniformTypeIdentifier: "public.json")
        evidence.name = "published-v40-" + engine + "-original-pages-and-independent-sql"
        evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(field.value as? String, "בראשית")
        XCTAssertFalse(control("global-search-dirty").exists)
        XCTAssertFalse(control("global-search-page-error").exists)
        try required("global-search-result-filter-done").tap()
        XCTAssertEqual(try loadedCount(filtered: false), pages * pageSize)
        try verifyUnchanged(value, hashDatabase: false)
    }

    @MainActor
    func testPublishedV40ZayitPages50_100_150RetainSQLIdentity() throws {
        try assertPublishedPages(engine: "zayit", pages: 3, pageSize: 50)
    }

    @MainActor
    func testPublishedV40OtzariaPagesRetainCumulativeSQLMetadata() throws {
        try assertPublishedPages(engine: "otzaria", pages: 2, pageSize: 100)
    }
}


// Full text assertions use source-qualified hashes for each complete native Text.
// A provider receipt alone never counts as a visible full-context acceptance.
struct SearchContextExpectedSegment: Decodable {
    let locator: String
    let sourceSHA256: String
    let translationSHA256: String?
    let sourceUTF8Bytes: Int
    let translationUTF8Bytes: Int?
}

private struct SefariaContextSourceReceipt: Decodable {
    struct Section: Decodable {
        let versionTitle: String
        let language: String
        let reference: String
        let stableID: String
        let segments: [SearchContextExpectedSegment]
    }
    struct Page: Decodable {
        struct Row: Decodable {
            let offset: Int
            let ref: String
            let versionTitle: String
            let language: String
        }
        let offset: Int
        let rows: [Row]
    }
    let schema: Int
    let status: String
    let uiExecuted: Bool
    let query: String
    let filters: [String]
    let limit: Int
    let sortOrder: String
    let targetRef: String
    let pages: [Page]
    let sections: [Section]
}

func originalSearchOracleBytes(pathKey: String, digestKey: String) throws -> Data {
    let environment = ProcessInfo.processInfo.environment
    let supplied = try XCTUnwrap(environment[pathKey], "Runner must supply the qualified source oracle " + pathKey)
    let digest = try XCTUnwrap(environment[digestKey], "Runner must seal the exact oracle bytes")
    let url = URL(fileURLWithPath: supplied).standardizedFileURL
    let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    try requireSearchDataFixture(info.isRegularFile == true && info.isSymbolicLink == false
        && url.path == url.resolvingSymlinksInPath().path
        && (info.fileSize ?? 2_000_001) <= 2_000_000 && digest.count == 64,
        "Only a bounded, regular, byte-sealed source oracle is eligible")
    let bytes = try Data(contentsOf: url)
    let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    try requireSearchDataFixture(actual == digest, "Reject changed or different-source acceptance inputs")
    return bytes
}

@MainActor
struct OriginalSearchContextUI {
    let app: XCUIApplication
    let test: XCTestCase

    func control(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    func require(_ id: String, timeout: TimeInterval = 30) throws -> XCUIElement {
        let value = control(id)
        try requireSearchDataFixture(value.waitForExistence(timeout: timeout), "Original control absent: " + id)
        return value
    }

    func wait(_ reason: String, timeout: TimeInterval = 60,
              _ condition: @escaping @MainActor () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { condition() }
        }, object: nil)
        try requireSearchDataFixture(XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed, reason)
    }

    func capture(_ name: String) {
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = name; screen.lifetime = .keepAlways; test.add(screen)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; test.add(tree)
    }

    func dragVisible(_ element: XCUIElement, up: Bool) throws {
        let rect = element.frame.intersection(app.frame)
        try requireSearchDataFixture(rect.width > 40 && rect.height > 100, "The original scroll owner must have a visible viewport")
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let x = rect.midX - app.frame.minX
        let high = rect.minY + rect.height * 0.22 - app.frame.minY
        let low = rect.minY + rect.height * 0.78 - app.frame.minY
        let start = origin.withOffset(CGVector(dx: x, dy: up ? low : high))
        let end = origin.withOffset(CGVector(dx: x, dy: up ? high : low))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func reach(_ id: String, maximumSwipes: Int = 50) throws -> XCUIElement {
        for _ in 0...maximumSwipes {
            let value = control(id)
            if value.exists && value.isHittable && value.frame.intersects(app.frame) { return value }
            try dragVisible(require("global-search-results"), up: true)
        }
        throw SearchDataNativeFixtureError.rejected("Original result not reachable: " + id)
    }

    func loadedCount(filtered: Bool = false) throws -> Int {
        let label = try require("global-search-count").label
        let values = label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        try requireSearchDataFixture(!values.isEmpty && (!filtered || values.count >= 2), "Read the original loaded counter: " + label)
        return filtered ? values[1] : values[0]
    }

    func suppressAutomaticPaging() throws {
        try require("global-search-result-filter-toggle").tap()
        let filter = try require("global-search-result-filter")
        filter.tap(); filter.typeText("source-acceptance-no-book-" + UUID().uuidString + "\n")
        try require("global-search-filter-empty")
    }

    func closeResultFilter() throws { try require("global-search-result-filter-done").tap() }

    func expand(_ id: String) throws {
        let toggle = try reach("search-result-preview-toggle-" + id)
        if toggle.value as? String != "Expanded" { toggle.tap() }
        try require("search-result-expanded-preview-" + id)
    }

    func originalPreviewScroll(_ id: String) throws -> XCUIElement {
        let scroll = app.scrollViews.matching(identifier: "search-result-expanded-preview-" + id).firstMatch
        try requireSearchDataFixture(scroll.waitForExistence(timeout: 45),
            "Full context must be the original native scroll view, not a synthetic witness")
        return scroll
    }

    func openCurrentPreview(_ id: String) throws {
        let scroll = try originalPreviewScroll(id)
        for _ in 0..<100 {
            let button = control("search-result-open-" + id)
            if button.exists && button.isHittable { button.tap(); return }
            try dragVisible(scroll, up: true)
        }
        throw SearchDataNativeFixtureError.rejected("Original Open action was not reachable")
    }

    func returnToOriginalSearch() throws {
        // The original TabView has no invented route ID. Scope to its native
        // tab bar, not Reader's separate in-book magnifying-glass button.
        let labels = NSPredicate(format: "label == %@ OR label == %@", "Search", "חיפוש")
        let back = app.navigationBars.buttons.matching(labels)
        if back.count == 1, back.firstMatch.isHittable {
            back.firstMatch.tap()
            if control("global-search-screen").waitForExistence(timeout: 5) { return }
        }
        var tabs = app.tabBars.buttons.matching(labels).allElementsBoundByIndex.filter(\.isHittable)
        if tabs.isEmpty {
            let reader = app.textViews["reader-text"].firstMatch
            try requireSearchDataFixture(reader.waitForExistence(timeout: 15), "Reveal the original Reader chrome")
            reader.tap()
            try wait("Original root Search tab must become visible") {
                self.app.tabBars.buttons.matching(labels).allElementsBoundByIndex.filter(\.isHittable).count == 1
            }
            tabs = app.tabBars.buttons.matching(labels).allElementsBoundByIndex.filter(\.isHittable)
        }
        try requireSearchDataFixture(tabs.count == 1 && tabs[0].frame.intersects(app.frame),
            "Require one visible original root Search tab")
        tabs[0].tap()
        try require("global-search-screen")
    }

    func setReaderTextMode(_ mode: String, fromPreview id: String) throws {
        try openCurrentPreview(id)
        try require("reader-more-menu", timeout: 60).tap()
        try require("reader-text-options").tap()
        for _ in 0..<8 {
            if control("reader-text-mode").exists && control("reader-text-mode").isHittable { break }
            let popover = app.popovers.firstMatch
            try requireSearchDataFixture(popover.waitForExistence(timeout: 10), "Original View Options popover must be present")
            try dragVisible(popover, up: true)
        }
        try require("reader-text-mode").tap()
        try require("reader-text-mode-" + mode).tap()
        try require("reader-options-close").tap()
        try returnToOriginalSearch()
        try require("search-result-expanded-preview-" + id)
    }

    func setReaderUnit(_ mode: String, fromPreview id: String) throws {
        try openCurrentPreview(id)
        try require("reader-more-menu", timeout: 60).tap()
        try require("reader-display-unit-menu").tap()
        try require("reader-display-unit-" + mode).tap()
        try returnToOriginalSearch()
        try require("search-result-expanded-preview-" + id)
    }

    func assertOriginalSearchResize(rtl: Bool, query: String, firstStableID: String) throws {
        let count = try loadedCount()
        let bookLabel = try require("global-search-books").label
        let modeLabel = try require("global-search-mode").label
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            try wait("The original app must actually change viewport orientation") {
                let frame = self.app.frame
                return orientation == .portrait ? frame.height > frame.width : frame.width > frame.height
            }
            try wait("All persistent header controls must remain usable after actual resize") {
                ["global-search-query", "global-search-options", "global-search-books", "global-search-mode"]
                    .allSatisfy { self.control($0).isHittable && self.control($0).frame.intersects(self.app.frame) }
            }
            let field = try require("global-search-query")
            let options = try require("global-search-options")
            let books = try require("global-search-books")
            let mode = try require("global-search-mode")
            XCTAssertEqual(field.value as? String, query)
            XCTAssertEqual(books.label, bookLabel)
            XCTAssertEqual(mode.label, modeLabel)
            XCTAssertEqual(try loadedCount(), count)
            XCTAssertFalse(field.frame.intersects(options.frame))
            XCTAssertGreaterThanOrEqual(books.frame.minY, field.frame.maxY - 1)
            if rtl {
                XCTAssertLessThanOrEqual(options.frame.maxX, field.frame.minX + 1)
                XCTAssertGreaterThan(books.frame.midX, mode.frame.midX)
            } else {
                XCTAssertGreaterThanOrEqual(options.frame.minX, field.frame.maxX - 1)
                XCTAssertLessThan(books.frame.midX, mode.frame.midX)
            }
            try require("search-result-preview-toggle-" + firstStableID)
            XCTAssertFalse(control("global-search-dirty").exists)
            XCTAssertFalse(control("global-search-error").exists)
            capture("original-search-resize-" + (rtl ? "he-" : "en-") + String(orientation.rawValue))
        }
    }

    func assertCompleteContext(id: String, segments: [SearchContextExpectedSegment], mode: String) throws {
        try requireSearchDataFixture(!segments.isEmpty && Set(segments.map(\.locator)).count == segments.count,
            "Independent source must identify every segment uniquely")
        let scroll = try originalPreviewScroll(id)
        let sourcePrefix = "search-preview-source-" + id + "-"
        let translationPrefix = "search-preview-translation-" + id + "-"
        var expected: [String: (String, Int)] = [:]
        for segment in segments {
            if mode == "source" || mode == "both" {
                expected[sourcePrefix + segment.locator] = (segment.sourceSHA256, segment.sourceUTF8Bytes)
            }
            if mode == "translation" || mode == "both" {
                let hash = try XCTUnwrap(segment.translationSHA256, "Bilingual acceptance requires a real translation slot")
                let count = try XCTUnwrap(segment.translationUTF8Bytes)
                expected[translationPrefix + segment.locator] = (hash, count)
            }
        }
        try wait("The original full body must finish loading", timeout: 90) {
            !self.control("search-preview-loading-" + id).exists
                && self.app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                    sourcePrefix, translationPrefix)).count > 0
        }
        let firstID = (mode == "translation" ? translationPrefix : sourcePrefix) + segments[0].locator
        for _ in 0..<(segments.count * 4 + 20) {
            let first = app.staticTexts[firstID].firstMatch
            if first.exists && first.frame.intersects(app.frame) && !first.frame.isEmpty { break }
            try dragVisible(scroll, up: false)
        }
        var seen: [String: String] = [:]
        for step in 0..<(segments.count * 5 + 20) {
            let elements = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                                                               sourcePrefix, translationPrefix)).allElementsBoundByIndex
            try requireSearchDataFixture(Set(elements.map(\.identifier)).count == elements.count,
                "An original segment may not be duplicated in the expanded card")
            for element in elements {
                let wanted = try XCTUnwrap(expected[element.identifier],
                    "The selected language mode must not show an extra source/translation segment")
                let text = element.label
                let hash = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
                XCTAssertEqual(hash, wanted.0, "Complete native Text must match independent source: " + element.identifier)
                XCTAssertEqual(text.utf8.count, wanted.1)
                if element.frame.intersects(app.frame) && !element.frame.isEmpty { seen[element.identifier] = hash }
            }
            XCTAssertFalse(control("search-preview-error-" + id).exists)
            if step == 0 { capture("full-context-" + mode + "-first") }
            let open = control("search-result-open-" + id)
            if seen.count == expected.count && open.exists && open.isHittable { break }
            try dragVisible(scroll, up: true)
        }
        XCTAssertEqual(Set(seen.keys), Set(expected.keys), "Every complete original source segment must become visible")
        capture("full-context-" + mode + "-last")
        let receipt = XCTAttachment(data: try JSONSerialization.data(withJSONObject: [
            "stableID": id, "mode": mode, "visibleSegmentHashes": seen,
            "expectedSegmentCount": expected.count
        ], options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        receipt.name = "actual-native-complete-context-" + mode
        receipt.lifetime = .keepAlways; test.add(receipt)
    }
}

final class SefariaFullSearchContextAcceptanceTests: MaktabahUITestBase {
    @MainActor private var ui: OriginalSearchContextUI { .init(app: app, test: self) }

    private func oracle() throws -> SefariaContextSourceReceipt {
        let bytes = try originalSearchOracleBytes(pathKey: "SEFARIA_SEARCH_CONTEXT_ORACLE",
                                                   digestKey: "SEFARIA_SEARCH_CONTEXT_ORACLE_SHA256")
        let source = try JSONDecoder().decode(SefariaContextSourceReceipt.self, from: bytes)
        XCTAssertEqual(source.schema, 1)
        XCTAssertEqual(source.status, "ACTUAL_SOURCE_ORACLE_ONLY_NOT_UI")
        XCTAssertFalse(source.uiExecuted)
        XCTAssertEqual(source.query, "soul")
        XCTAssertEqual(source.filters, ["Tanakh/Writings/Psalms"])
        XCTAssertEqual(source.limit, 100)
        XCTAssertEqual(source.sortOrder, "canonical")
        XCTAssertEqual(source.targetRef, "Psalms 35:17")
        XCTAssertEqual(source.pages.map(\.offset), [0, 100])
        let target = source.pages.flatMap(\.rows).filter { $0.ref == source.targetRef }
        XCTAssertEqual(target.map(\.offset), [98, 99, 100])
        XCTAssertEqual(target.map(\.versionTitle), source.sections.map(\.versionTitle))
        XCTAssertEqual(Set(source.sections.map { $0.segments.compactMap(\.translationSHA256).joined() }).count, 3,
                       "Three real editions must have distinguishable complete bodies")
        for section in source.sections {
            XCTAssertEqual(section.language, "en")
            XCTAssertEqual(section.segments.count, 28)
            XCTAssertEqual(section.stableID, "sefaria|Psalms|ref:Psalms 35:17|\(section.versionTitle)|en")
        }
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "independent-sefaria-pages-and-complete-context-oracle"
        attachment.lifetime = .keepAlways; add(attachment)
        return source
    }

    @MainActor
    private func launchPsalms(_ source: SefariaContextSourceReceipt, language: String) throws {
        for key in ["OTZARIA_SHARED_ROOT_OVERRIDE", "OTZARIA_PRODUCTION_DB_PATH"] {
            XCTAssertNil(ProcessInfo.processInfo.environment[key], "Do not substitute application data")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.production, backend: "sefaria",
            extraArgs: ["-lastSelectedTab", "0", "-ChavrusaTextFaithfulReaderUIEnabled", "YES"],
            language: language, locale: language == "he" ? "he_IL" : "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        XCTAssertFalse(app.launchArguments.contains("-studyWorkspaceTestingNamespace"))
        let tab = findTabButton(hebrew: "חיפוש", english: "Search")
        try requireSearchDataFixture(tab.waitForExistence(timeout: 120), "Original Sefaria bootstrap must expose Search")
        tab.tap()
        try ui.require("global-search-screen", timeout: 60)
        try ui.require("global-search-mode").tap()
        try ui.require("global-search-mode-exact").tap()
        try ui.require("global-search-books").tap()
        if ui.control("global-search-book-clear").exists { ui.control("global-search-book-clear").tap() }
        let books = try ui.require("global-search-book-query", timeout: 60)
        books.tap()
        if let clear = books.buttons.allElementsBoundByIndex.first(where: \.isHittable) { clear.tap() }
        books.typeText(language == "he" ? "תהילים\n" : "Psalms\n")
        let psalms = try ui.require("search-book-sefaria|Psalms|ref:Psalms", timeout: 60)
        XCTAssertTrue(psalms.isHittable); psalms.tap()
        if ui.control("global-search-book-done").exists { ui.control("global-search-book-done").tap() }
        let query = try ui.require("global-search-query")
        query.tap()
        if let clear = query.buttons.allElementsBoundByIndex.first(where: \.isHittable) { clear.tap() }
        query.typeText(source.query + "\n")
        try ui.require("global-search-count", timeout: 120)
        try ui.require("global-search-sort").tap()
        try ui.require("global-search-sort-canonical").tap()
        try ui.require("global-search-rerun").tap()
        try ui.wait("The original canonical first page must contain exactly 100 results", timeout: 120) {
            (try? self.ui.loadedCount()) == 100
        }
        try ui.suppressAutomaticPaging()
        XCTAssertEqual(try ui.loadedCount(filtered: true), 100)
        try ui.closeResultFilter()
        let first = try XCTUnwrap(source.pages.first?.rows.first)
        let firstID = "sefaria|Psalms|ref:\(first.ref)|\(first.versionTitle)|\(first.language)"
        try ui.assertOriginalSearchResize(rtl: language == "he", query: source.query, firstStableID: firstID)
    }

    @MainActor
    private func appendSecondPage(_ source: SefariaContextSourceReceipt) throws {
        let group = "search-result-versions-sefaria|Psalms|ref:Psalms 35:17"
        let menu = try ui.reach(group)
        XCTAssertEqual(menu.value as? String, "2", "Only the first two real editions belong to page one")
        menu.tap()
        for section in source.sections.prefix(2) { try ui.require("search-result-version-" + section.stableID) }
        XCTAssertFalse(ui.control("search-result-version-" + source.sections[2].stableID).exists)
        try ui.require("search-result-version-" + source.sections[0].stableID).tap()
        ui.capture("same-source-two-editions-page-one")
        try ui.suppressAutomaticPaging()
        let load = app.buttons.matching(NSPredicate(format: "label == %@", "Load more results")).firstMatch
        try requireSearchDataFixture(load.waitForExistence(timeout: 20) && load.isHittable, "Original explicit paging action must remain reachable")
        load.tap()
        try ui.wait("The original second page must append cumulatively to 200") {
            (try? self.ui.loadedCount(filtered: true)) == 200
        }
        try ui.closeResultFilter()
        let updated = try ui.reach(group)
        XCTAssertEqual(updated.value as? String, "3")
        XCTAssertEqual(app.buttons.matching(identifier: group).count, 1,
            "The later-page edition must merge into one canonical source card")
        ui.capture("same-source-three-editions-across-original-pages")
    }

    @MainActor
    func testThreeActualSefariaEditionsAcrossTwoPagesKeepDistinctCompleteBodies() throws {
        let source = try oracle()
        try launchPsalms(source, language: "en")
        try appendSecondPage(source)
        let first = source.sections[0]
        try ui.expand(first.stableID)
        try ui.setReaderTextMode("translation", fromPreview: first.stableID)
        var activeID = first.stableID
        for section in source.sections {
            // Return to the result header before changing the original version menu.
            let scroll = try ui.originalPreviewScroll(activeID)
            for _ in 0..<80 {
                if ui.control("search-result-versions-sefaria|Psalms|ref:Psalms 35:17").isHittable { break }
                try ui.dragVisible(scroll, up: false)
            }
            try ui.require("search-result-versions-sefaria|Psalms|ref:Psalms 35:17").tap()
            try ui.require("search-result-version-" + section.stableID).tap()
            activeID = section.stableID
            try ui.require("search-result-expanded-preview-" + section.stableID)
            XCTAssertEqual(ui.control("search-result-preview-toggle-" + section.stableID).value as? String, "Expanded")
            try ui.assertCompleteContext(id: section.stableID, segments: section.segments, mode: "translation")
        }
        XCTAssertEqual(try ui.loadedCount(), 200)
    }

    @MainActor
    func testHebrewUIEnglishResultHonorsOriginalSourceTranslationAndBothControls() throws {
        let source = try oracle()
        try launchPsalms(source, language: "he")
        try appendSecondPage(source)
        let section = source.sections[0]
        try ui.expand(section.stableID)
        for mode in ["source", "translation", "both"] {
            try ui.setReaderTextMode(mode, fromPreview: section.stableID)
            try ui.assertCompleteContext(id: section.stableID, segments: section.segments, mode: mode)
        }
        XCTAssertEqual(try ui.require("global-search-query").value as? String, source.query)
        XCTAssertFalse(ui.control("global-search-dirty").exists)
    }

    override func tearDownWithError() throws {
        if let app {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "full-context-final-native-hierarchy"; tree.lifetime = .keepAlways; add(tree)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "full-context-final-native-screen"; screen.lifetime = .keepAlways; add(screen)
        }
        try super.tearDownWithError()
    }
}


private struct ProductionSearchPreviewSourceReceipt: Decodable {
    struct Target: Decodable {
        struct Anchor: Decodable {
            let lineID: Int64
            let bookID: Int
            let lineIndex: Int
            let heRef: String?
            let text: String
            let textSHA256: String
            let segmentID: String
            let previewPlainText: String
            let previewPlainTextSHA256: String
            let previewUTF16Length: Int
        }
        let bookID: Int
        let bookTitle: String
        let focusLineIndex: Int
        let unitID: String
        let unitMode: String
        let unitStartLineIndex: Int
        let unitEndLineIndex: Int
        let unitRowCount: Int
        let sourceUTF8: String
        let sourceSHA256: String
        let allOriginalAnchorsChecked: Int
        let focusLocator: String
        let anchors: [Anchor]
    }
    let schema: Int
    let status: String
    let corpusProfile: String
    let databaseSHA256: String
    let sourceServiceSHA256: String
    let presentationSourceSHA256: String
    let catalogCompileInputsSHA256: String
    let uiExecuted: Int
    let searchProviderExecuted: Bool
    let targets: [Target]
}

extension PublishedProductionSearchDataTests {
    @MainActor
    private func submitNafshiOriginalFirstPage() throws -> (Installation, [[String: Any]]) {
        try launchProduction(unitMode: nil) // The real UI must be able to persist mode changes.
        let value = try installation()
        try verifyUnchanged(value)
        try verifyPackages(value)
        let ui = OriginalSearchContextUI(app: app, test: self)
        try chooseEngine("otzaria")
        let field = try required("global-search-query")
        field.tap()
        if let clear = field.buttons.allElementsBoundByIndex.first(where: \.isHittable) { clear.tap() }
        field.typeText("נפשי\n")
        try ui.wait("The requested real production query must publish its first 100 results", timeout: 180) {
            (try? self.loadedCount(filtered: false)) == 100
        }
        try ui.suppressAutomaticPaging()
        XCTAssertEqual(try loadedCount(filtered: true), 100)
        try ui.closeResultFilter()
        let observed = try events(value)
        let queryHash = searchDataDigest(Data("נפשי".utf8))
        let providers = observed.filter {
            $0["engine"] as? String == "otzaria" && $0["event"] as? String == "provider"
                && ($0["request"] as? [String: Any])?["querySHA256"] as? String == queryHash
        }
        XCTAssertEqual(providers.count, 1, "Only the original first page of the requested query is eligible")
        let provider = try XCTUnwrap(providers.first)
        XCTAssertEqual(provider["namespace"] as? String, traceNamespace)
        XCTAssertEqual(provider["profileID"] as? String, "production")
        let request = try XCTUnwrap(provider["request"] as? [String: Any])
        XCTAssertEqual(request["querySHA256"] as? String, queryHash)
        XCTAssertNil(request["query"], "Preserve passive trace query privacy")
        XCTAssertEqual((request["offset"] as? NSNumber)?.intValue, 0)
        XCTAssertEqual((request["limit"] as? NSNumber)?.intValue, 100)
        let page = try XCTUnwrap(provider["page"] as? [String: Any])
        let rows = try XCTUnwrap(page["results"] as? [[String: Any]])
        let publication = try XCTUnwrap(observed.last {
            $0["engine"] as? String == "otzaria" && $0["event"] as? String == "published"
                && ($0["items"] as? [[String: Any]])?.count == 100
        })
        let items = try XCTUnwrap(publication["items"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 100)
        XCTAssertEqual(items.count, 100)
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(value.database.path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        let database = try XCTUnwrap(handle)
        defer { sqlite3_close(database) }
        XCTAssertEqual(sqlite3_db_readonly(database, "main"), 1)
        var sql: [[String: Any]] = []
        for (row, item) in zip(rows, items) {
            let path = try XCTUnwrap(row["filePath"] as? String)
            try requireSearchDataFixture(path.hasPrefix("otzaria-book:"), "Actual source must retain its qualified book identity")
            let book = try XCTUnwrap(Int(path.dropFirst("otzaria-book:".count)))
            let line = try XCTUnwrap((row["segment"] as? NSNumber)?.intValue)
            let id = "otzaria:\(path):\(try XCTUnwrap((row["id"] as? NSNumber)?.uint64Value)):\(line)"
            let actual = try sqlLine(database: database, book: book, line: line)
            XCTAssertEqual(item["id"] as? String, id)
            XCTAssertEqual((item["bookID"] as? NSNumber)?.intValue, book)
            XCTAssertEqual((item["lineIndex"] as? NSNumber)?.intValue, line)
            XCTAssertEqual(item["locator"] as? String, "otzaria|book:\(book)|line:\(line)")
            XCTAssertEqual(item["bookTitle"] as? String, actual["bookTitle"] as? String)
            XCTAssertEqual(row["title"] as? String, actual["bookTitle"] as? String)
            XCTAssertEqual(item["reference"] as? String, row["reference"] as? String ?? "")
            XCTAssertEqual(row["reference"] as? String ?? "", actual["reference"] as? String ?? "")
            sql.append(actual)
        }
        XCTAssertEqual(Set(items.compactMap { $0["id"] as? String }).count, 100)
        XCTAssertEqual(field.value as? String, "נפשי")
        let receipt = XCTAttachment(data: try canonical([
            "scope": "actual original UI query and provider page plus immutable SQL, not full-context acceptance",
            "provider": provider, "publication": publication, "independentSQL": sql
        ]), uniformTypeIdentifier: "public.json")
        receipt.name = "published-v40-nafshi-source-selection-for-independent-context-oracle"
        receipt.lifetime = .keepAlways; add(receipt)
        let firstID = try XCTUnwrap(items.first?["id"] as? String)
        try ui.assertOriginalSearchResize(rtl: true, query: "נפשי", firstStableID: firstID)
        let afterResizeProviders = try events(value).filter {
            $0["engine"] as? String == "otzaria" && $0["event"] as? String == "provider"
                && ($0["request"] as? [String: Any])?["querySHA256"] as? String == queryHash
        }
        XCTAssertEqual(afterResizeProviders.count, providers.count, "Viewport changes must not submit another source request")
        ui.capture("published-v40-nafshi-original-first-page")
        return (value, items)
    }

    @MainActor
    func testPublishedV40NafshiFirstPageForIndependentFullContextOracle() throws {
        let (value, _) = try submitNafshiOriginalFirstPage()
        try verifyUnchanged(value, hashDatabase: false)
    }

    @MainActor
    func testPublishedV40NafshiFullParagraphAndChapterMatchEveryOriginalSourceSegment() throws {
        let oracleBytes = try originalSearchOracleBytes(pathKey: "PRODUCTION_SEARCH_PREVIEW_ORACLE",
                                                        digestKey: "PRODUCTION_SEARCH_PREVIEW_ORACLE_SHA256")
        let oracle = try JSONDecoder().decode(ProductionSearchPreviewSourceReceipt.self, from: oracleBytes)
        XCTAssertEqual(oracle.schema, 1)
        XCTAssertEqual(oracle.status, "ORIGINAL_SOURCE_PREVIEW_CATALOG_ONLY_NOT_SEARCH_OR_UI")
        XCTAssertEqual(oracle.corpusProfile, "full-v40")
        XCTAssertEqual(oracle.databaseSHA256, v40Digest)
        XCTAssertEqual(oracle.uiExecuted, 0)
        XCTAssertFalse(oracle.searchProviderExecuted)
        let environment = ProcessInfo.processInfo.environment
        for (actual, key) in [
            (oracle.sourceServiceSHA256, "PRODUCTION_SEARCH_PREVIEW_SERVICE_SHA256"),
            (oracle.presentationSourceSHA256, "PRODUCTION_SEARCH_PREVIEW_PRESENTATION_SHA256"),
            (oracle.catalogCompileInputsSHA256, "PRODUCTION_SEARCH_PREVIEW_COMPILE_SHA256")
        ] {
            let expected = try XCTUnwrap(environment[key], "Bind the oracle to the independently retained actual source/compile closure")
            XCTAssertEqual(expected.count, 64); XCTAssertEqual(actual, expected)
        }
        let paragraph = try XCTUnwrap(oracle.targets.first { $0.unitMode == "paragraph" })
        let chapter = try XCTUnwrap(oracle.targets.first { $0.unitMode == "chapter" })
        XCTAssertEqual(oracle.targets.filter { $0.unitMode == "paragraph" }.count, 1)
        XCTAssertEqual(oracle.targets.filter { $0.unitMode == "chapter" }.count, 1)
        XCTAssertEqual(paragraph.bookID, chapter.bookID)
        XCTAssertEqual(paragraph.focusLineIndex, chapter.focusLineIndex)
        XCTAssertGreaterThan(chapter.unitRowCount, paragraph.unitRowCount,
            "Select an actual hit whose genuine paragraph and chapter have different complete bounds")
        let (value, items) = try submitNafshiOriginalFirstPage()
        let hit = try XCTUnwrap(items.first {
            ($0["bookID"] as? NSNumber)?.intValue == paragraph.bookID
                && ($0["lineIndex"] as? NSNumber)?.intValue == paragraph.focusLineIndex
        }, "The original submitted page must actually contain the source-qualified target")
        let id = try XCTUnwrap(hit["id"] as? String)
        XCTAssertEqual(hit["locator"] as? String, paragraph.focusLocator)
        let ui = OriginalSearchContextUI(app: app, test: self)
        try ui.expand(id)
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(value.database.path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil), SQLITE_OK)
        let database = try XCTUnwrap(handle)
        defer { sqlite3_close(database) }
        for target in [paragraph, chapter] {
            XCTAssertEqual(target.focusLocator, "otzaria|book:\(target.bookID)|line:\(target.focusLineIndex)")
            XCTAssertEqual(target.unitRowCount, target.anchors.count)
            XCTAssertEqual(target.allOriginalAnchorsChecked, target.anchors.count)
            XCTAssertEqual(target.sourceSHA256,
                SHA256.hash(data: Data(target.sourceUTF8.utf8)).map { String(format: "%02x", $0) }.joined())
            XCTAssertEqual(Set(target.anchors.map(\.lineID)).count, target.anchors.count)
            var expected: [SearchContextExpectedSegment] = []
            for anchor in target.anchors {
                let row = try sqlLine(database: database, book: anchor.bookID, line: anchor.lineIndex)
                XCTAssertEqual((row["lineID"] as? NSNumber)?.int64Value, anchor.lineID)
                XCTAssertEqual(anchor.bookID, target.bookID)
                XCTAssertEqual(row["bookTitle"] as? String, target.bookTitle)
                XCTAssertEqual(row["reference"] as? String ?? "", anchor.heRef ?? "")
                XCTAssertEqual(anchor.segmentID, "otzaria|book:\(anchor.bookID)|line:\(anchor.lineIndex)")
                XCTAssertEqual(anchor.textSHA256,
                    SHA256.hash(data: Data(anchor.text.utf8)).map { String(format: "%02x", $0) }.joined())
                XCTAssertEqual(anchor.previewPlainTextSHA256,
                    SHA256.hash(data: Data(anchor.previewPlainText.utf8)).map { String(format: "%02x", $0) }.joined())
                XCTAssertEqual(anchor.previewUTF16Length, (anchor.previewPlainText as NSString).length)
                if !anchor.previewPlainText.isEmpty {
                    expected.append(.init(locator: anchor.segmentID, sourceSHA256: anchor.previewPlainTextSHA256,
                        translationSHA256: nil, sourceUTF8Bytes: anchor.previewPlainText.utf8.count,
                        translationUTF8Bytes: nil))
                }
            }
            try ui.setReaderUnit(target.unitMode, fromPreview: id)
            try ui.assertCompleteContext(id: id, segments: expected, mode: "source")
        }
        let receipt = XCTAttachment(data: oracleBytes, uniformTypeIdentifier: "public.json")
        receipt.name = "independent-v40-complete-paragraph-and-chapter-source"
        receipt.lifetime = .keepAlways; add(receipt)
        XCTAssertEqual(try required("global-search-query").value as? String, "נפשי")
        try verifyUnchanged(value, hashDatabase: false)
    }
}
