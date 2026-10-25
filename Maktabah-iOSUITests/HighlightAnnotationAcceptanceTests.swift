//
//  HighlightAnnotationAcceptanceTests.swift
//  Maktabah-iOSUITests
//
//  Priority A3.3: Highlight creation on Hebrew text, note editing,
//  persistence across navigation and app relaunch.
//

import XCTest

final class HighlightAnnotationAcceptanceTests: MaktabahUITestBase {

    func testAnnotationCreationPersistenceAndRelaunch() throws {
        // 1. Launch into studyNotes scenario
        launchWithScenario("studyNotes", backend: "sefaria")
        dismissAlertsIfNeeded()

        let noteTextView = app.textViews["annotation-note-text"]
        XCTAssertTrue(
            waitForElement(noteTextView, timeout: 15.0),
            "Annotation note text view must exist in studyNotes scenario"
        )

        // 2. Type a distinctive unique Hebrew annotation note
        let noteToken = UUID().uuidString.prefix(6)
        let testNote = "הערת אימות מערכתית \(noteToken)"
        noteTextView.tap()
        noteTextView.typeText(testNote)

        let saveButton = app.buttons["annotation-save"]
        XCTAssertTrue(
            waitForElement(saveButton, timeout: 5.0),
            "Annotation save button must exist"
        )
        XCTAssertTrue(saveButton.isHittable, "Annotation save button must be hittable")
        saveButton.tap()

        // 3. Navigate away to Annotations tab
        let annotationsTab = findTabButton(hebrew: "הערות", english: "Annotations")
        XCTAssertTrue(
            waitForElement(annotationsTab, timeout: 8.0),
            "Annotations tab button must exist and be accessible"
        )
        annotationsTab.tap()

        // 4. Verify annotation note is present in the annotations list BEFORE relaunch
        let createdNoteElement = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", testNote)
        ).firstMatch
        XCTAssertTrue(
            waitForElement(createdNoteElement, timeout: 8.0),
            "Annotation note must appear in the annotations list before relaunch"
        )

        // 5. Navigate back to Library/Reader tab using resilient Hebrew/English locator
        let libraryTab = findTabButton(hebrew: "ספר", english: "Library")
        XCTAssertTrue(
            waitForElement(libraryTab, timeout: 8.0),
            "Library tab button ('ספרייה' / 'Library') must exist"
        )
        libraryTab.tap()

        let readerSurface = app.otherElements["reader-surface"]
        XCTAssertTrue(
            waitForElement(readerSurface, timeout: 10.0),
            "Reader surface must be restored when returning to Library tab"
        )

        // 6. Terminate and relaunch app to verify persistence across app sessions
        app.terminate()
        app.launch()

        // 7. Verify tab bar is responsive and navigate to Annotations tab
        let annotationsTabAfterLaunch = findTabButton(hebrew: "הערות", english: "Annotations")
        XCTAssertTrue(
            waitForElement(annotationsTabAfterLaunch, timeout: 12.0),
            "Annotations tab must be responsive after app relaunch"
        )
        annotationsTabAfterLaunch.tap()

        // 8. Assert that the persisted annotation note survived relaunch
        let persistedNoteElement = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", testNote)
        ).firstMatch
        XCTAssertTrue(
            waitForElement(persistedNoteElement, timeout: 8.0),
            "Persisted annotation with note '\(testNote)' must survive app relaunch"
        )
    }
}
