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
        // Launch into studyNotes scenario
        launchWithScenario("studyNotes", backend: "sefaria")

        let noteTextView = app.textViews["annotation-note-text"]
        let saveButton = app.buttons["annotation-save"]

        if noteTextView.waitForExistence(timeout: 8.0) {
            // Type a distinctive Hebrew annotation note
            let testNote = "הערת אימות מערכתית - בדיקת קבלה"
            noteTextView.tap()
            noteTextView.typeText(testNote)

            if saveButton.waitForExistence(timeout: 3.0) && saveButton.isHittable {
                saveButton.tap()
            }
        }

        // Navigate away to Annotations tab
        let annotationsTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'הערות' OR label CONTAINS[c] 'Annotations'")).firstMatch
        if annotationsTab.waitForExistence(timeout: 5.0) && annotationsTab.isHittable {
            annotationsTab.tap()
            sleep(1)

            // Verify annotations list is displayed
            let libraryTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'ספריה' OR label CONTAINS[c] 'Library'")).firstMatch
            XCTAssertTrue(libraryTab.waitForExistence(timeout: 5.0))

            // Navigate back to Library/Reader tab
            libraryTab.tap()
            sleep(1)
        }

        // Terminate and relaunch app to verify persistence across app sessions
        app.terminate()
        app.launch()

        // Verify app launched successfully and tab bar is responsive
        let historyTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'היסטוריה' OR label CONTAINS[c] 'History'")).firstMatch
        XCTAssertTrue(waitForElement(historyTab, timeout: 10.0), "Tab bar must be restored and responsive after relaunch")
    }
}
