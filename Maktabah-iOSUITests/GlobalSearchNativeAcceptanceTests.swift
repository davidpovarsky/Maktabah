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
    private func launchSearch(backend: String? = nil, language: String? = nil, readerUnitMode: String? = nil) throws {
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
                                   "-lastSelectedTab", "0"] + readerArguments,
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
        try launchSearch()
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
    private func launchExplicitZayitFlexibleSearch(readerUnitMode: String? = nil) throws {
        try launchSearch(backend: "otzaria", readerUnitMode: readerUnitMode)
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
        let expectedHash = "9a623ea8805cc9a3c945c3ba05e48842a63b06805599ddc5e6ba18f599284b17"
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
}
