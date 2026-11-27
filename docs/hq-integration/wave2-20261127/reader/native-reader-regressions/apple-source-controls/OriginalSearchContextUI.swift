import XCTest
import CryptoKit

private enum SearchDataNativeFixtureError: Error { case rejected(String) }

private func requireSearchDataFixture(_ condition: Bool, _ reason: String) throws {
    guard condition else {
        XCTFail(reason)
        throw SearchDataNativeFixtureError.rejected(reason)
    }
}


struct SearchContextExpectedSegment: Decodable {
    let locator: String
    let sourceSHA256: String
    let translationSHA256: String?
    let sourceUTF8Bytes: Int
    let translationUTF8Bytes: Int?
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

