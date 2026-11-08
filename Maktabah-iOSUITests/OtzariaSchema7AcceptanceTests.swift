import XCTest

/// Uses the authenticated miniTest10 v9 corpus and the ordinary reader controls.
final class OtzariaSchema7AcceptanceTests: FaithfulReaderUIBase {
    func testNativeEditionSelectionMissingPassageAndMergedRecovery() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria")
        let reader = app.textViews["reader-text"]
        XCTAssertTrue(reader.waitForExistence(timeout: 60))
        let readable = NSPredicate { _, _ in
            (reader.value as? String ?? "").unicodeScalars.filter { (0x05D0...0x05EA).contains($0.value) }.count > 30
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: readable, object: reader)], timeout: 60), .completed)
        let locator = app.staticTexts["reader-current-locator"].label
        XCTAssertTrue(locator.contains("otzaria"))

        // v9's first actual relationship opens Sefer HaChinukh at lineIndex 523.
        // Its Torat Emet edition has real content there; Minchat Chinukh has no
        // version_line at that passage. These are original data, not substitutes.
        chooseEdition("ספר החינוך, תורת אמת", expecting: "נוסח משולב")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: readable, object: reader)], timeout: 30), .completed)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)

        chooseEdition("מנחת חינוך, וילנה, תרפ\"ג", expecting: "ספר החינוך, תורת אמת")
        let unavailable = NSPredicate { _, _ in
            (reader.value as? String ?? "").contains("למהדורה שנבחרה אין טקסט זמין במקטע זה")
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: unavailable, object: reader)], timeout: 30), .completed,
                       "An absent edition passage must show its error rather than merged or previous-edition text")
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)

        chooseEdition("נוסח משולב", expecting: "מנחת חינוך, וילנה, תרפ\"ג")
        let recovered = NSPredicate { _, _ in readable.evaluate(with: reader) && !unavailable.evaluate(with: reader) }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: recovered, object: reader)], timeout: 30), .completed)
        XCTAssertEqual(app.staticTexts["reader-current-locator"].label, locator)
        capture("otzaria-schema7-native-edition-recovered")
    }

    private func chooseEdition(_ title: String, expecting previous: String) {
        tap(readerBottomChromeAction())
        tap(app.buttons.matching(NSPredicate(format: "label IN %@", ["אפשרויות טקסט", "Text Options", "View Options"])).firstMatch)
        let popover = app.popovers.firstMatch
        XCTAssertTrue(popover.waitForExistence(timeout: 15))
        let picker = popover.buttons["reader-otzaria-edition"]
        for _ in 0..<6 {
            if picker.exists && picker.isHittable { break }
            let form = popover.collectionViews.firstMatch
            if form.exists { form.swipeUp() } else { popover.swipeUp() }
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let loaded = NSPredicate { _, _ in picker.isEnabled }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: loaded, object: picker)], timeout: 30), .completed,
                       "The actual metadata request must finish before choosing an edition")
        XCTAssertTrue(picker.label.contains(previous) || (picker.value as? String ?? "").contains(previous),
                      "The native control must retain the actual reader's edition choice")
        tap(picker)
        tap(app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch)
        XCTAssertTrue(picker.label.contains(title) || (picker.value as? String ?? "").contains(title))
        tap(popover.navigationBars.buttons.firstMatch)
        XCTAssertTrue(popover.waitForNonExistence(timeout: 10))
    }
}
