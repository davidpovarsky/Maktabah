import XCTest
import CryptoKit

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
