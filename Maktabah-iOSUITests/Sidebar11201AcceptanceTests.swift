import XCTest

/// Actual native acceptance through the existing synchronized UI-test target.
/// Requires its isolated miniTest10 fixture and FAITHFUL_VIEWPORT_DIRECTORY.
final class Sidebar11201AcceptanceTests: FaithfulReaderUIBase {
    override var readerTestTier: TestTier { .realUI }
    override var readerAdditionalLaunchArguments: [String] {
        ["-preferredBackend", "otzaria", "-smokeBackend", "otzaria", "-libraryViewMode", "0"]
    }

    override func tearDownWithError() throws {
        if app != nil { retainNativeEvidence("sidebar-11201-final") }
        XCUIDevice.shared.orientation = .portrait
        try super.tearDownWithError()
    }

    @MainActor
    func testSidebarBodyPagingRTL() throws {
        try exerciseBodyPaging(language: "he", isRTL: true)
    }

    @MainActor
    func testSidebarBodyPagingLTR() throws {
        try exerciseBodyPaging(language: "en", isRTL: false)
    }

    @MainActor
    func testOriginalBottomTOCActionUsesActualSidebarPage() throws {
        XCTAssertTrue(isPad)
        exerciseOriginalBottomTOCAction()
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        let expectedWork = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"])
        let parts = app.staticTexts["reader-current-locator"].label.split(separator: "|", maxSplits: 2).map(String.init)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.first, "otzaria")
        XCTAssertEqual(parts.dropFirst().first, expectedWork)
    }

    @MainActor
    func testSidebarSceneStateSurvivesBackgroundAndRotation() throws {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let text = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        let expectedWork = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"])
        let parts = locator.split(separator: "|", maxSplits: 2).map(String.init)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.first, "otzaria")
        XCTAssertEqual(parts.dropFirst().first, expectedWork)

        let contents = app.buttons["reader-sidebar-page-1"]
        if !contents.exists || !contents.isHittable { tap(readerSidebarToggle()) }
        tap(contents)
        waitSelected(contents)
        let original = try viewport()
        retainNativeEvidence("sidebar-scene-before-background")
        XCUIDevice.shared.press(.home)
        app.activate()
        waitSelected(contents)
        XCTAssertEqual(try viewport().object, original.object)

        let application = app!
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated { application.frame.height > application.frame.width }
            }, object: nil
        )], timeout: 20), .completed, "The actual native window must rotate")
        if !contents.exists || !contents.isHittable { tap(readerSidebarToggle()) }
        waitSelected(contents)
        tap(readerSidebarToggle())
        assertReaderHasText()
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        XCTAssertEqual(app.textViews["reader-text"].value as? String, text)
        let after = try viewport()
        XCTAssertEqual(after.object, original.object)
        XCTAssertEqual(after.source, original.source)
        XCTAssertEqual(after.offset, original.offset, accuracy: 1)
        retainNativeEvidence("sidebar-scene-after-portrait-and-close")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated { application.frame.width > application.frame.height }
            }, object: nil
        )], timeout: 20), .completed)
        if !contents.exists || !contents.isHittable { tap(readerSidebarToggle()) }
        waitSelected(contents)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        retainNativeEvidence("sidebar-scene-restored-landscape")
    }

    @MainActor
    private func exerciseBodyPaging(language: String, isRTL: Bool) throws {
        XCTAssertTrue(isPad, "Required native iPad execution must not be skipped")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(language: language, recordViewport: true)
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        assertReaderHasText()
        let expectedWork = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_WORK_KEY"])
        let initialParts = app.staticTexts["reader-current-locator"].label.split(separator: "|", maxSplits: 2).map(String.init)
        XCTAssertEqual(initialParts.count, 3)
        XCTAssertEqual(initialParts.first, "otzaria")
        XCTAssertEqual(initialParts.dropFirst().first, expectedWork)
        retainNativeEvidence("sidebar-11201-\(language)-opening")

        let libraryDot = app.buttons["reader-sidebar-page-0"]
        let contentsDot = app.buttons["reader-sidebar-page-1"]
        if !libraryDot.exists || libraryDot.frame.isEmpty || !libraryDot.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryDot)
        waitSelected(libraryDot)

        let pager = app.descendants(matching: .any)["reader-sidebar-pager"].firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 15))
        let library = app.otherElements["library-column"].firstMatch
        // Paths are exported from the pinned miniTest10 fixture's real category
        // hierarchy. Fail closed when absent, never guess ancestor labels.
        let matchPath = try fixturePath("HQ_SIDEBAR_MATCH_PATH", endingIn: "מסילת ישרים")
        let excludedPath = try fixturePath("HQ_SIDEBAR_EXCLUDED_PATH", endingIn: "בראשית")
        try revealBook(at: matchPath, in: library)
        try revealBook(at: excludedPath, in: library)
        let query = "מסילת"
        let search = try visibleSidebarSearch(in: pager)
        tap(search)
        let originalCatalog = catalogRows(in: library)
        XCTAssertFalse(originalCatalog.isEmpty)
        // A disconnected field cannot pass this empty-result oracle, even if
        // it faithfully echoes and preserves every character typed into it.
        replaceQuery(in: search, with: "__HQ_NO_CATALOG_MATCH_151126__")
        waitForCatalog { library.collectionViews.cells.count == 0 }
        replaceQuery(in: search, with: query)
        waitForCatalog { !self.bookLabel(excludedPath.last!, in: library).exists }
        try revealBook(at: matchPath, in: library)
        XCTAssertTrue(bookLabel(matchPath.last!, in: library).exists)
        XCTAssertFalse(bookLabel(excludedPath.last!, in: library).exists)
        XCTAssertEqual(search.value as? String, query)
        let librarySearchPrompt = search.placeholderValue
        // Dismiss the keyboard without clearing the canonical query.
        if app.keyboards.firstMatch.exists {
            let dismiss = app.buttons.matching(NSPredicate(format:
                "label IN %@", ["Hide keyboard", "הסתרת המקלדת", "הסתר מקלדת"]))
            if dismiss.firstMatch.exists { tap(dismiss.firstMatch) }
        }

        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let original = try viewport()
        for _ in 0..<10 { // Twenty body transitions per language.
            // Fixed physical direction, center of the BODY. Do not retry in
            // the opposite direction or touch the bottom page-control strip.
            dragBody(pager, towardContents: true, isRTL: isRTL)
            waitSelected(contentsDot)
            XCTAssertFalse(libraryDot.isSelected)
            XCTAssertFalse(app.buttons["toc-close"].exists,
                           "The original split owns the sidebar toggle")
            let toc = app.otherElements["toc-column"].firstMatch
            XCTAssertTrue(toc.waitForExistence(timeout: 15))
            XCTAssertTrue(toc.staticTexts[language == "he" ? "תוכן עניינים" : "Table of Contents"].exists)
            let tocSearch = try visibleSidebarSearch(in: pager)
            XCTAssertEqual(tocSearch.placeholderValue,
                           language == "he" ? "חיפוש בתוכן" : "Search Contents")
            XCTAssertNotEqual(tocSearch.placeholderValue, librarySearchPrompt,
                              "TOC owns its search; Library search must not leak")
            XCTAssertNotEqual(tocSearch.value as? String, query)
            _ = readerSidebarToggle() // Asserts exactly one native/custom owner.
            dragBody(pager, towardContents: false, isRTL: isRTL)
            waitSelected(libraryDot)
            XCTAssertEqual(try visibleSidebarSearch(in: pager).value as? String, query)
            XCTAssertTrue(bookLabel(matchPath.last!, in: library).exists)
            XCTAssertFalse(bookLabel(excludedPath.last!, in: library).exists)
            XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
            let actual = try viewport()
            XCTAssertEqual(actual.object, original.object, "Reader must not remount")
            XCTAssertEqual(actual.source, original.source)
            XCTAssertEqual(actual.offset, original.offset, accuracy: 1)
        }

        replaceQuery(in: try visibleSidebarSearch(in: pager), with: "")
        waitForCatalog { self.catalogRows(in: library) == originalCatalog }
        try revealBook(at: matchPath, in: library)
        try revealBook(at: excludedPath, in: library)
        XCTAssertTrue(bookLabel(matchPath.last!, in: library).exists)
        XCTAssertTrue(bookLabel(excludedPath.last!, in: library).exists,
                      "Clearing the canonical query restores the excluded book")

        // Twenty dot transitions are covered here too, independently of the
        // historical suite that permits opposite-direction swipe retries.
        for _ in 0..<10 {
            tap(contentsDot)
            waitSelected(contentsDot)
            tap(libraryDot)
            waitSelected(libraryDot)
            XCTAssertEqual(try viewport().object, original.object)
        }

        // A vertical body scroll must not be interpreted as page navigation.
        pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            .press(forDuration: 0.05, thenDragTo:
                pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        XCTAssertTrue(libraryDot.isSelected)
        retainNativeEvidence("sidebar-11201-\(language)-body-paging")
    }

    @MainActor
    private func fixturePath(_ key: String, endingIn title: String) throws -> [String] {
        let json = try XCTUnwrap(ProcessInfo.processInfo.environment[key],
                                "Supply the actual miniTest10 category/book path as JSON")
        let path = try JSONDecoder().decode([String].self, from: Data(json.utf8))
        let leaf = try XCTUnwrap(path.last)
        XCTAssertEqual(leaf, title, "Expected seeded fixture book, not arbitrary UI text")
        XCTAssertTrue(path.allSatisfy { !$0.isEmpty })
        return path
    }

    @MainActor
    private func bookLabel(_ title: String, in library: XCUIElement) -> XCUIElement {
        library.collectionViews.cells.staticTexts[title].firstMatch
    }

    @MainActor
    private func revealBook(at path: [String], in library: XCUIElement) throws {
        for (index, title) in path.enumerated() {
            let label = bookLabel(title, in: library)
            XCTAssertTrue(label.waitForExistence(timeout: 15), "Fixture path is missing: \(title)")
            if index + 1 < path.count && !bookLabel(path[index + 1], in: library).exists {
                tap(label) // Category ancestor only; never open the leaf book.
            }
        }
    }

    @MainActor
    private func catalogRows(in library: XCUIElement) -> [String] {
        library.collectionViews.cells.staticTexts.allElementsBoundByIndex.map { $0.label }
    }

    @MainActor
    private func replaceQuery(in field: XCUIElement, with query: String) {
        tap(field)
        let old = field.value as? String ?? ""
        // The last entered query leaves the caret at the end. Empty fields
        // expose their placeholder as value, which must not be deleted.
        if !old.isEmpty && old != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        if !query.isEmpty { field.typeText(query) }
    }

    @MainActor
    private func waitForCatalog(_ condition: @escaping @MainActor () -> Bool) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }, object: nil
        )], timeout: 15), .completed)
    }

    @MainActor
    private func waitSelected(_ dot: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"), object: dot
        )], timeout: 15), .completed)
    }

    @MainActor
    private func visibleSidebarSearch(in pager: XCUIElement) throws -> XCUIElement {
        // UIKit places .navigationBarDrawer above the page body's AX bounds.
        // Observe the visible native field in this sidebar's horizontal column,
        // including its NavigationBar; keep offscreen/other-column fields out.
        let body = pager.frame
        let window = app.windows.firstMatch.frame
        XCTAssertFalse(body.isEmpty)
        let column = CGRect(x: body.minX, y: window.minY,
                            width: body.width, height: window.height)
        let fields = app.searchFields.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && column.insetBy(dx: -1, dy: 0).contains($0.frame) && $0.isHittable
        }
        XCTAssertEqual(fields.count, 1, "One visible native search field in the actual sidebar column")
        return try XCTUnwrap(fields.first)
    }

    @MainActor
    private func dragBody(_ pager: XCUIElement, towardContents: Bool, isRTL: Bool) {
        let movesRight = towardContents == isRTL
        pager.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.25 : 0.75, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo:
                pager.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.75 : 0.25, dy: 0.5)))
    }
}
