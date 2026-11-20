import XCTest

/// Actual app bootstrap, native scene presentation and durable history UI.
/// The explicit unused credential configures the original SDK without sending
/// a model request. Provider and source-opening acceptance are separate gates.
final class HanlinConsumerAcceptanceTests: FaithfulReaderUIBase {
    @MainActor
    private func launchOriginalApplication() {
        _ = launchWithTier(.realUI, backend: "sefaria", extraArgs: [
            "-preferredBackend", "sefaria", "-lastSelectedTab", "0",
            "-ChavrusaTextFaithfulReaderUIEnabled", "YES",
            "-studyWorkspaceTestingNamespace", workspaceNamespace
        ], language: "en", locale: "en_US")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
    }

    @MainActor
    private func tapOwned(_ element: XCUIElement, timeout: TimeInterval = 30,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
        XCTAssertTrue(element.isHittable, "The original native control must receive this action", file: file, line: line)
        element.tap()
    }

    @MainActor
    private func openOriginalChat() {
        let launch = app.buttons["otzaria-hanlin-global-launch"]
        tapOwned(launch, timeout: 90)
        XCTAssertTrue(app.buttons["otzaria-hanlin-close"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func closeOriginalChat() {
        tapOwned(app.buttons["otzaria-hanlin-close"])
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["otzaria-hanlin-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 20), .completed)
        XCTAssertTrue(app.buttons["otzaria-hanlin-global-launch"].isHittable)
    }

    @MainActor
    private func processIdentity() throws -> String {
        let first = app.debugDescription.split(separator: "\n").first.map(String.init) ?? ""
        let marker = try XCTUnwrap(first.range(of: "pid: "))
        let identifier = String(first[marker.upperBound...].prefix(while: { $0.isNumber }))
        XCTAssertFalse(identifier.isEmpty)
        return identifier
    }

    @MainActor
    private func retainEvidence(_ name: String) {
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = name + "-screen"; screen.lifetime = .keepAlways; add(screen)
    }

    @MainActor
    func testOriginalChatDraftReopensAcrossNativeDismissAndAppRestart() throws {
        launchOriginalApplication()
        let firstPID = try processIdentity()
        openOriginalChat()
        let model = app.textFields["otzaria-hanlin-model"]
        tapOwned(model); model.typeText("unused-native-history-proof")
        let key = app.secureTextFields["otzaria-hanlin-api-key"]
        tapOwned(key); key.typeText("ui-no-network-credential")
        tapOwned(app.buttons["otzaria-hanlin-connect"])

        let draft = "טיוטה שנכתבה בחלון הלימוד\nNative multiline history survives restart"
        let editor = app.textViews["otzaria-hanlin-composer"]
        tapOwned(editor)
        editor.typeText(draft)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", draft), object: editor)], timeout: 15), .completed,
            "The original editor must preserve every RTL and newline character")
        retainEvidence("hanlin-original-draft-before-dismiss")
        closeOriginalChat()

        openOriginalChat()
        tapOwned(app.buttons["otzaria-hanlin-history"])
        let history = app.descendants(matching: .any)["otzaria-hanlin-history-list"].firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        let rows = history.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "otzaria-hanlin-saved-"))
        XCTAssertEqual(rows.count, 1, "Opening the picker must not create another empty conversation")
        let saved = rows.firstMatch
        let identifier = saved.identifier
        XCTAssertNotNil(UUID(uuidString: String(identifier.dropFirst("otzaria-hanlin-saved-".count))))
        XCTAssertTrue(saved.label.contains("טיוטה שנכתבה בחלון הלימוד"))
        tapOwned(saved)
        XCTAssertTrue(editor.waitForExistence(timeout: 20))
        XCTAssertEqual(editor.value as? String, draft)
        XCTAssertTrue(app.buttons["otzaria-hanlin-reconnect"].exists,
            "Reopening history must not restore the discarded model credential")
        XCTAssertTrue(app.buttons["otzaria-hanlin-send"].exists)
        XCTAssertFalse(app.buttons["otzaria-hanlin-send"].isEnabled)
        closeOriginalChat()

        app.terminate()
        launchOriginalApplication()
        XCTAssertNotEqual(try processIdentity(), firstPID, "A fresh target process must restore the saved draft")
        openOriginalChat()
        tapOwned(app.buttons["otzaria-hanlin-history"])
        let restoredRow = app.buttons[identifier]
        tapOwned(restoredRow)
        XCTAssertTrue(editor.waitForExistence(timeout: 20))
        XCTAssertEqual(editor.value as? String, draft)
        XCTAssertTrue(app.buttons["otzaria-hanlin-reconnect"].exists)
        XCTAssertTrue(app.buttons["otzaria-hanlin-send"].exists)
        XCTAssertFalse(app.buttons["otzaria-hanlin-send"].isEnabled)
        retainEvidence("hanlin-original-draft-after-process-restart")
        closeOriginalChat()
    }
}


/// Uses the existing real-bootstrap reader and its original persisted workspace.
/// This is a native presentation/return proof; it sends no provider request.
final class HanlinReaderConsumerAcceptanceTests: R27NativeUIBase {
    private struct WorkspaceSnapshot: Decodable {
        struct Document: Decodable, Equatable {
            struct Session: Decodable, Equatable { let id: UUID; let bookId: Int }
            let backend: String
            let session: Session
        }
        struct Group: Decodable {
            let id: UUID; let profileID: UUID
            let activeTabID: UUID?; let tabs: [Document]
        }
        struct Scene: Decodable {
            let profileID: UUID; let groupID: UUID
            let activeTabIDsByGroup: [UUID: UUID]?
        }
        struct Owner: Equatable {
            let sceneID: String; let profileID: UUID; let groupID: UUID
            let activeTabID: UUID; let tabs: [Document]
        }
        let groups: [Group]; let scenes: [String: Scene]
        let lastActiveSceneID: String?

        func currentOwner() throws -> Owner {
            let sceneID = try XCTUnwrap(lastActiveSceneID)
            let scene = try XCTUnwrap(scenes[sceneID])
            let group = try XCTUnwrap(groups.first { $0.id == scene.groupID && $0.profileID == scene.profileID })
            let activeTabID = try XCTUnwrap(scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID)
            XCTAssertTrue(group.tabs.contains { $0.session.id == activeTabID })
            return Owner(sceneID: sceneID, profileID: scene.profileID, groupID: scene.groupID,
                         activeTabID: activeTabID, tabs: group.tabs)
        }
    }

    @MainActor
    private func originalWorkspaceOwner() throws -> WorkspaceSnapshot.Owner {
        try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(contentsOf: workspaceSidecarURL())).currentOwner()
    }

    @MainActor
    func testOriginalReaderChatReturnsToSameNativeWorkspace() throws {
        XCTAssertTrue(isPad, "This original reader toolbar case requires the declared iPad owner")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", language: "en")
        let originalLocator = try assertTarget(backend: "otzaria")
        let originalTitle = app.staticTexts["reader-header-title"].label
        let originalText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        XCTAssertFalse(originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let originalOwner = try originalWorkspaceOwner()
        capture("hanlin-reader-original-before-chat")

        let launch = app.buttons["otzaria-hanlin-reader-launch"]
        XCTAssertTrue(launch.waitForExistence(timeout: 20))
        XCTAssertTrue(launch.isHittable)
        launch.tap()
        let close = app.buttons["otzaria-hanlin-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        XCTAssertEqual(app.buttons.matching(identifier: "otzaria-hanlin-close").count, 1,
                       "The native reader must present one original scene-owned chat")
        XCTAssertTrue(app.textFields["otzaria-hanlin-model"].waitForExistence(timeout: 20),
                      "The real reader entry must expose the explicit original model configuration")
        XCTAssertTrue(app.staticTexts[
            "This conversation uses your messages and permitted catalog metadata. Book search is off unless you allow the displayed book. Selections are not shared."
        ].exists, "Opening the reader chat must not imply permission to read the current book")
        XCTAssertEqual(app.switches["otzaria-hanlin-allow-current-book"].value as? String, "0",
                       "The actual source-bound read offer must default to OFF")
        capture("hanlin-reader-original-chat-presented")

        XCTAssertTrue(close.isHittable)
        close.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 20), .completed)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), originalLocator)
        XCTAssertEqual(app.staticTexts["reader-header-title"].label, originalTitle)
        let returnedText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        XCTAssertTrue(returnedText.utf8.elementsEqual(originalText.utf8),
                      "Dismissal must retain the exact original book text, including its Unicode representation")
        XCTAssertEqual(try originalWorkspaceOwner(), originalOwner,
                       "The original scene, profile, group, selected tab and all document identities must remain unchanged")
        XCTAssertTrue(app.buttons["otzaria-hanlin-reader-launch"].isHittable)
        capture("hanlin-reader-original-after-chat-dismissal")
    }
    @MainActor
    private func exerciseCurrentWorkReadConsent() throws {
        if isPad { XCUIDevice.shared.orientation = .landscapeLeft }
        launchReader(backend: "otzaria", language: "en")
        let originalLocator = try assertTarget(backend: "otzaria")
        let originalText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        let originalOwner = try originalWorkspaceOwner()
        let expectedTitle = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        let launchID = "otzaria-hanlin-reader-launch"
        func tap(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout: 30))
            XCTAssertTrue(element.isHittable, "Use the real native control")
            element.tap()
        }
        func openChatFromOriginalReader() throws {
            let direct = app.buttons.matching(identifier: launchID)
            let overflow = app.navigationBars.buttons.matching(identifier: "TopOverflowBarButtonItem")
            func visible(_ query: XCUIElementQuery) -> [XCUIElement] {
                query.allElementsBoundByIndex.filter {
                    $0.exists && $0.isHittable && !$0.frame.isEmpty
                        && app.frame.intersection($0.frame).width > 1
                        && app.frame.intersection($0.frame).height > 1
                }
            }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated { !visible(direct).isEmpty || !visible(overflow).isEmpty }
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
            var actions = visible(direct)
            if actions.isEmpty {
                let nativeOverflow = visible(overflow)
                guard nativeOverflow.count == 1 else {
                    XCTFail("Expected one original reader toolbar overflow")
                    throw NSError(domain: "HanlinNativeConsent", code: 1)
                }
                nativeOverflow[0].tap()
                // UIKit may surface an original toolbar action by its source
                // label inside the menu. This fallback exists only after the
                // exact native overflow was opened, with a unique hittable item.
                let menuAction = app.buttons.matching(NSPredicate(
                    format: "identifier == %@ OR label == %@", launchID, "Study chat"))
                let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    MainActor.assumeIsolated { !visible(menuAction).isEmpty }
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 10), .completed)
                actions = visible(menuAction)
            }
            guard actions.count == 1 else {
                XCTFail("Expected one original reader Study chat action")
                throw NSError(domain: "HanlinNativeConsent", code: 2)
            }
            actions[0].tap()
        }

        func closeChat() {
            let close = app.buttons["otzaria-hanlin-close"]
            tap(close)
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: close)], timeout: 30), .completed)
        }
        func fillConnection() {
            let model = app.textFields["otzaria-hanlin-model"]
            tap(model); model.typeText("unused-native-consent-proof")
            let key = app.secureTextFields["otzaria-hanlin-api-key"]
            tap(key); key.typeText("ui-no-send-credential")
        }
        func requireDraft(_ editor: XCUIElement, _ draft: String) {
            XCTAssertTrue(editor.waitForExistence(timeout: 30))
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", draft), object: editor)], timeout: 20), .completed)
        }

        try openChatFromOriginalReader()
        let consent = app.switches["otzaria-hanlin-allow-current-book"]
        XCTAssertTrue(consent.waitForExistence(timeout: 20))
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertEqual(app.staticTexts["otzaria-hanlin-consent-book-title"].label, expectedTitle)
        fillConnection()
        tap(app.buttons["otzaria-hanlin-connect"])
        let editor = app.textViews["otzaria-hanlin-composer"]
        let draft = "טיוטה נשמרת במתן ובביטול הרשאה\nOriginal current-work consent draft"
        tap(editor); editor.typeText(draft); requireDraft(editor, draft)
        XCTAssertFalse(app.buttons["otzaria-hanlin-end-book-access"].exists)
        closeChat()

        // Reopen the exact saved SDK conversation through its existing history UI.
        try openChatFromOriginalReader()
        tap(app.buttons["otzaria-hanlin-history"])
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "otzaria-hanlin-saved-"))
        XCTAssertEqual(rows.count, 1)
        let savedID = rows.firstMatch.identifier
        tap(rows.firstMatch)
        requireDraft(editor, draft)
        tap(app.buttons["otzaria-hanlin-reconnect"])
        XCTAssertTrue(consent.waitForExistence(timeout: 20))
        XCTAssertEqual(consent.value as? String, "0", "History must not restore read consent")
        let form = app.descendants(matching: .any)["otzaria-hanlin-connection-form"].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 20))
        for _ in 0..<4 where !consent.isHittable { form.swipeUp() }
        tap(consent)
        XCTAssertEqual(consent.value as? String, "1")
        let model = app.textFields["otzaria-hanlin-model"]
        for _ in 0..<4 where !model.isHittable { form.swipeDown() }
        fillConnection()
        tap(app.buttons["otzaria-hanlin-connect"])

        // No test action invokes Send. This uses the real local SDK constructor;
        // network silence is not instrumented or claimed by this UI case.
        let revoke = app.buttons["otzaria-hanlin-end-book-access"]
        XCTAssertTrue(revoke.waitForExistence(timeout: 30),
                      "A grant must be issued only through the actual old sheet dismissal and new source-qualified session")
        requireDraft(editor, draft)
        XCTAssertEqual(app.buttons.matching(identifier: "otzaria-hanlin-close").count, 1)
        let send = app.buttons["otzaria-hanlin-send"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: send)], timeout: 30), .completed,
            "The original SDK must configure the exact carried connection without a fake success flag")
        capture("hanlin-current-work-consent-after-original-dismiss-reopen")

        tap(revoke)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: revoke)], timeout: 30), .completed)
        requireDraft(editor, draft)
        XCTAssertTrue(app.buttons["otzaria-hanlin-reconnect"].waitForExistence(timeout: 20))
        XCTAssertFalse(send.isEnabled, "Revocation must discard the model connection and require explicit reconnection")
        tap(app.buttons["otzaria-hanlin-history"])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.firstMatch.identifier, savedID, "Grant/revoke must preserve the exact saved conversation UUID")
        capture("hanlin-current-work-consent-revoked-same-saved-conversation")
        closeChat()
        XCTAssertEqual(try assertTarget(backend: "otzaria"), originalLocator)
        XCTAssertTrue(try XCTUnwrap(app.textViews["reader-text"].value as? String).utf8.elementsEqual(originalText.utf8))
        XCTAssertEqual(try originalWorkspaceOwner(), originalOwner)
    }

    @MainActor
    func testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending() throws {
        XCTAssertTrue(isPad, "Select this case only on the declared iPad destination")
        try exerciseCurrentWorkReadConsent()
    }

    @MainActor
    func testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending() throws {
        XCTAssertFalse(isPad, "Select this case only on the declared phone destination")
        try exerciseCurrentWorkReadConsent()
    }

}
