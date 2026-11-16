import XCTest

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
    private func launchSearch(backend: String? = nil, language: String? = nil) throws {
        let backend = backend ?? environment["GLOBAL_SEARCH_TEST_BACKEND"] ?? "otzaria"
        let language = language ?? environment["GLOBAL_SEARCH_TEST_LANGUAGE"] ?? "he"
        XCTAssertTrue(["otzaria", "sefaria", "sefariaEmbedded"].contains(backend))
        XCTAssertTrue(["he", "en"].contains(language))
        launchWithTier(.realUI, backend: backend,
                       extraArgs: ["-preferredBackend", backend, "-smokeBackend", backend,
                                   "-studyWorkspaceTestingNamespace", workspaceNamespace,
                                   "-lastSelectedTab", "0"],
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
}
