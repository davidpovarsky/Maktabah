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
            "This conversation uses your messages and permitted catalog metadata. Book text and selections are not shared."
        ].exists, "Opening the reader chat must not imply permission to read the current book")
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
}
