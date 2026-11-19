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
        // Restore the real list's height before expanding the fixture path;
        // the software keyboard can cover its child category and book.
        if app.keyboards.firstMatch.exists {
            let dismiss = app.buttons.matching(NSPredicate(format:
                "label IN %@", ["Hide keyboard", "הסתרת המקלדת", "הסתר מקלדת"]))
            XCTAssertTrue(dismiss.firstMatch.exists)
            tap(dismiss.firstMatch)
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "count == 0"), object: app.keyboards
            )], timeout: 15), .completed)
        }
        try revealBook(at: matchPath, in: library)
        XCTAssertTrue(bookLabel(matchPath.last!, in: library).exists)
        XCTAssertFalse(bookLabel(excludedPath.last!, in: library).exists)
        XCTAssertEqual(search.value as? String, query)
        let librarySearchPrompt = search.placeholderValue

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
            // The actual native TOC is a CollectionView; its navigation
            // title belongs to the surrounding NavigationBar, not its rows.
            let toc = app.descendants(matching: .any)["toc-column"].firstMatch
            XCTAssertTrue(toc.waitForExistence(timeout: 15))
            let column = sidebarColumnFrame(in: pager)
            let titles = app.navigationBars.staticTexts.matching(NSPredicate(
                format: "label == %@", language == "he" ? "תוכן עניינים" : "Table of Contents"
            )).allElementsBoundByIndex.filter {
                !$0.frame.isEmpty && column.insetBy(dx: -1, dy: 0).contains($0.frame)
            }
            XCTAssertEqual(titles.count, 1, "One actual native TOC title in this sidebar's NavigationBar")
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
        // Native evidence found another visible category named "אחרונים".
        // Target each complete independently supplied fixture path; do not tap
        // the first leaf-name match in a different expanded branch.
        func cell(at index: Int) throws -> XCUIElement {
            let components = path.prefix(index + 1).enumerated().map { offset, title in
                [offset + 1 == path.count ? "book" : "category", title, "0"]
            }
            let identifier = "library-tree-path-" + (try JSONEncoder().encode(components)).base64EncodedString()
            // XCTest's identifier convenience API rejects strings above 128
            // characters. Preserve the exact independently derived occurrence
            // identity through its supported predicate API, with no truncation.
            let matches = library.collectionViews.cells.matching(NSPredicate(format: "identifier == %@", identifier))
            XCTAssertLessThanOrEqual(matches.count, 1, "A complete catalog occurrence must be unique")
            return matches.firstMatch
        }
        for (index, title) in path.enumerated() {
            let target = try cell(at: index)
            // Scroll the actual original list when expansion places the child
            // outside its viewport. Never activate the leaf book.
            if index == 0 {
                for _ in 0..<4 {
                    if target.exists && target.isHittable { break }
                    library.collectionViews.firstMatch.swipeDown()
                }
            }
            for _ in 0..<6 {
                if target.exists && target.isHittable { break }
                library.collectionViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(target.waitForExistence(timeout: 15), "Fixture path is missing: \(title)")
            XCTAssertTrue(target.staticTexts[title].exists, "Canonical cell must retain the real title")
            XCTAssertTrue(target.isHittable, "Canonical catalog occurrence must be visible")
            if index + 1 < path.count {
                let child = try cell(at: index + 1)
                if !child.exists { target.tap() }
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
        if !old.isEmpty && old != field.placeholderValue {
            // A center tap can put the caret in the middle of a long/bidi
            // query. Use UIKit's actual field-owned clear action, observed in
            // both native locales, instead of assuming a deletion position.
            let clear = field.buttons.matching(NSPredicate(
                format: "label IN %@", ["Clear text", "מחיקת המלל"]
            ))
            XCTAssertEqual(clear.count, 1)
            XCTAssertTrue(clear.firstMatch.isHittable)
            tap(clear.firstMatch)
            let cleared = field.value as? String ?? ""
            XCTAssertTrue(cleared.isEmpty || cleared == field.placeholderValue)
        }
        if !query.isEmpty {
            // Clearing the native search can end editing on this OS. Refocus
            // the actual now-empty field before the next genuine input event.
            tap(field)
            field.typeText(query)
            XCTAssertEqual(field.value as? String, query,
                           "Functional filtering must exercise the exact intended query")
        }
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
        let column = sidebarColumnFrame(in: pager)
        let fields = app.searchFields.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && column.insetBy(dx: -1, dy: 0).contains($0.frame) && $0.isHittable
        }
        XCTAssertEqual(fields.count, 1, "One visible native search field in the actual sidebar column")
        return try XCTUnwrap(fields.first)
    }

    @MainActor
    private func sidebarColumnFrame(in pager: XCUIElement) -> CGRect {
        let body = pager.frame
        let window = app.windows.firstMatch.frame
        XCTAssertFalse(body.isEmpty)
        return CGRect(x: body.minX, y: window.minY,
                      width: body.width, height: window.height)
    }

    @MainActor
    private func dragBody(_ pager: XCUIElement, towardContents: Bool, isRTL: Bool) {
        let movesRight = towardContents == isRTL
        pager.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.25 : 0.75, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo:
                pager.coordinate(withNormalizedOffset: CGVector(dx: movesRight ? 0.75 : 0.25, dy: 0.5)))
    }
}
