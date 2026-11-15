import XCTest

/// Prepared, NOT_RUN. Include alongside FaithfulReaderUIAcceptanceTests.swift
/// in the existing UI-test target only for an explicitly authorized runtime run.
/// Requires its isolated miniTest10 fixture and FAITHFUL_VIEWPORT_DIRECTORY.
final class Sidebar11201AcceptanceTests: FaithfulReaderUIBase {
    @MainActor
    func testSidebarBodyPagingRTL() throws {
        try exerciseBodyPaging(language: "he", isRTL: true)
    }

    @MainActor
    func testSidebarBodyPagingLTR() throws {
        try exerciseBodyPaging(language: "en", isRTL: false)
    }

    @MainActor
    private func exerciseBodyPaging(language: String, isRTL: Bool) throws {
        guard isPad else { throw XCTSkip("iPad sidebar acceptance") }
        let orientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = orientation }
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(language: language, recordViewport: true)
        assertReaderHasText()

        let libraryDot = app.buttons["reader-sidebar-page-0"]
        let contentsDot = app.buttons["reader-sidebar-page-1"]
        if !libraryDot.exists || libraryDot.frame.isEmpty || !libraryDot.frame.intersects(app.frame) {
            tap(readerSidebarToggle())
        }
        tap(libraryDot)
        waitSelected(libraryDot)

        let pager = app.descendants(matching: .any)["reader-sidebar-pager"].firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 15))
        let query = "בראשית"
        let search = try visibleSidebarSearch(in: pager)
        tap(search)
        search.typeText(query)
        XCTAssertEqual(search.value as? String, query)
        // Dismiss the keyboard without clearing the canonical query.
        if app.keyboards.firstMatch.exists {
            let dismiss = app.buttons.matching(NSPredicate(format:
                "label IN %@", ["Hide keyboard", "הסתרת המקלדת", "הסתר מקלדת"]))
            if dismiss.firstMatch.exists { tap(dismiss.firstMatch) }
        }

        let title = app.staticTexts["reader-header-title"].label
        let locator = app.staticTexts["reader-current-locator"].label
        let original = try viewport()
        for _ in 0..<5 {
            // Fixed physical direction, center of the BODY. Do not retry in
            // the opposite direction or touch the bottom page-control strip.
            dragBody(pager, towardContents: true, isRTL: isRTL)
            waitSelected(contentsDot)
            XCTAssertFalse(libraryDot.isSelected)
            XCTAssertFalse(app.buttons["toc-close"].exists,
                           "The original split owns the sidebar toggle")
            _ = readerSidebarToggle() // Asserts exactly one native/custom owner.
            dragBody(pager, towardContents: false, isRTL: isRTL)
            waitSelected(libraryDot)
            XCTAssertEqual(try visibleSidebarSearch(in: pager).value as? String, query)
            XCTAssertEqual(app.staticTexts["reader-header-title"].label, title)
            XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
            let actual = try viewport()
            XCTAssertEqual(actual.object, original.object, "Reader must not remount")
            XCTAssertEqual(actual.source, original.source)
            XCTAssertEqual(actual.offset, original.offset, accuracy: 1)
        }

        // A vertical body scroll must not be interpreted as page navigation.
        pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            .press(forDuration: 0.05, thenDragTo:
                pager.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        XCTAssertTrue(libraryDot.isSelected)
        retainNativeEvidence("sidebar-11201-\(language)-body-paging")
    }

    @MainActor
    private func waitSelected(_ dot: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isSelected == true"), object: dot
        )], timeout: 15), .completed)
    }

    @MainActor
    private func visibleSidebarSearch(in pager: XCUIElement) throws -> XCUIElement {
        let fields = app.searchFields.allElementsBoundByIndex.filter {
            !$0.frame.isEmpty && pager.frame.contains($0.frame) && $0.isHittable
        }
        XCTAssertEqual(fields.count, 1, "One visible native Library search field")
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
