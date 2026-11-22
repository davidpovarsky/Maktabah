import XCTest

/// The original SwiftUI Form exposes both a labelled row and its native switch.
/// Act on the single contained switch; the row's centre is a label hit target.
@MainActor
private func originalCurrentBookConsentSwitch(in row: XCUIElement,
                                              file: StaticString = #filePath,
                                              line: UInt = #line) throws -> XCUIElement {
    let controls = row.descendants(matching: .switch)
    guard row.identifier == "otzaria-hanlin-allow-current-book",
          row.elementType == .switch, controls.count == 1 else {
        XCTFail("Expected the one original switch inside the exact book-consent row", file: file, line: line)
        throw NSError(domain: "HanlinNativeConsent", code: 3)
    }
    let control = controls.element(boundBy: 0)
    guard !control.frame.isEmpty, row.frame.contains(control.frame),
          let rowValue = row.value as? String, ["0", "1"].contains(rowValue),
          control.value as? String == rowValue else {
        XCTFail("The original consent switch must belong to and agree with its row", file: file, line: line)
        throw NSError(domain: "HanlinNativeConsent", code: 4)
    }
    return control
}

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
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label == %@",
            "This conversation uses your messages and permitted catalog metadata. Book search is off unless you allow the displayed book. Selections are not shared."
        )).element.exists, "Opening the reader chat must not imply permission to read the current book")
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
    /// Reproduces the failed live consent interaction without creating a
    /// connection or supplying credentials, so native AX/screens can be kept.
    @MainActor
    func testOriginalIPadCurrentWorkConsentToggleWithoutConnection() throws {
        XCTAssertTrue(isPad)
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", language: "en")
        let originalLocator = try assertTarget(backend: "otzaria")
        let originalOwner = try originalWorkspaceOwner()
        let originalText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        let expectedTitle = try XCTUnwrap(ProcessInfo.processInfo.environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        func tapNative(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout: 30))
            XCTAssertTrue(element.isEnabled)
            XCTAssertTrue(element.isHittable, "Use the actual native control")
            element.tap()
        }

        tapNative(app.buttons["otzaria-hanlin-reader-launch"])
        let consent = app.switches["otzaria-hanlin-allow-current-book"]
        XCTAssertTrue(consent.waitForExistence(timeout: 30))
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertEqual(app.staticTexts["otzaria-hanlin-consent-book-title"].label, expectedTitle)
        let form = app.descendants(matching: .any)["otzaria-hanlin-connection-form"].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 20))
        let nativeConsent = try originalCurrentBookConsentSwitch(in: consent)
        for _ in 0..<4 where !nativeConsent.isHittable { form.swipeUp() }
        capture("hanlin-consent-no-connection-before-native-tap")
        tapNative(nativeConsent)
        let enabled = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "1"), object: consent
        )], timeout: 10)
        capture("hanlin-consent-no-connection-after-native-tap")
        XCTAssertEqual(enabled, .completed, "One actual consent switch tap must turn access ON")

        tapNative(nativeConsent)
        let disabled = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "0"), object: consent
        )], timeout: 10)
        capture("hanlin-consent-no-connection-after-native-revoke")
        XCTAssertEqual(disabled, .completed, "A second actual tap must turn the offer OFF")
        XCTAssertFalse(app.buttons["otzaria-hanlin-end-book-access"].exists,
                       "An unconnected offer must not create a source access session")
        let close = app.buttons["otzaria-hanlin-close"]
        tapNative(close)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: close
        )], timeout: 20), .completed)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), originalLocator)
        XCTAssertTrue(try XCTUnwrap(app.textViews["reader-text"].value as? String).utf8.elementsEqual(originalText.utf8))
        XCTAssertEqual(try originalWorkspaceOwner(), originalOwner)
    }

    @MainActor
    func testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending() throws {
        continueAfterFailure = false
        executionTimeAllowance = 600
        XCTAssertTrue(isPad, "This diagnostic requires the original declared iPad")
        let environment = ProcessInfo.processInfo.environment
        XCTAssertNil(environment["OTZARIA_HANLIN_LIVE_PROVIDER_CASE"])
        XCTAssertNil(environment["OTZARIA_HANLIN_LIVE_NONCE"])
        XCUIDevice.shared.orientation = .landscapeLeft
        launchReader(backend: "otzaria", language: "en")
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        let originalLocator = try assertTarget(backend: "otzaria")
        let originalOwner = try originalWorkspaceOwner()
        let originalText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        let expectedTitle = try XCTUnwrap(environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        func tapNative(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout: 30))
            XCTAssertTrue(element.isEnabled)
            XCTAssertTrue(element.isHittable, "Use the actual native control")
            element.tap()
        }

        tapNative(app.buttons["otzaria-hanlin-reader-launch"])
        let consent = app.switches["otzaria-hanlin-allow-current-book"]
        XCTAssertTrue(consent.waitForExistence(timeout: 30))
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertEqual(app.staticTexts["otzaria-hanlin-consent-book-title"].label, expectedTitle)
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/"
        let service = app.textFields["otzaria-hanlin-service-address"]
        tapNative(service)
        service.typeKey("a", modifierFlags: .command)
        service.typeText(endpoint)
        XCTAssertEqual(service.value as? String, endpoint)
        let model = app.textFields["otzaria-hanlin-model"]
        tapNative(model)
        model.typeText("unused-native-fresh-read-proof")
        XCTAssertEqual(model.value as? String, "unused-native-fresh-read-proof")
        let key = app.secureTextFields["otzaria-hanlin-api-key"]
        tapNative(key)
        key.typeText("ui-no-send-credential")
        let form = app.descendants(matching: .any)["otzaria-hanlin-connection-form"].firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 20))
        let nativeConsent = try originalCurrentBookConsentSwitch(in: consent)
        for _ in 0..<4 where !nativeConsent.isHittable { form.swipeUp() }
        tapNative(nativeConsent)
        XCTAssertEqual(consent.value as? String, "1")
        let connect = app.buttons["otzaria-hanlin-connect"]
        for _ in 0..<4 where !connect.isHittable { form.swipeDown() }
        capture("hanlin-fresh-read-no-send-before-original-connect")
        tapNative(connect)

        let revoke = app.buttons["otzaria-hanlin-end-book-access"]
        let accessAppeared = revoke.waitForExistence(timeout: 30)
        capture("hanlin-fresh-read-no-send-after-original-dismiss-reopen")
        XCTAssertTrue(accessAppeared, "The original native dismissal must issue the source-qualified read session")
        XCTAssertEqual(app.buttons.matching(identifier: "otzaria-hanlin-close").count, 1)
        XCTAssertTrue(app.textViews["otzaria-hanlin-composer"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["otzaria-hanlin-send"].isEnabled,
                       "The untouched fresh conversation has no message to send")
        XCTAssertFalse(app.buttons["otzaria-hanlin-stop"].exists)
        tapNative(app.buttons["otzaria-hanlin-close"])
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["otzaria-hanlin-close"]
        )], timeout: 30), .completed)
        XCTAssertEqual(try assertTarget(backend: "otzaria"), originalLocator)
        XCTAssertTrue(try XCTUnwrap(app.textViews["reader-text"].value as? String).utf8.elementsEqual(originalText.utf8))
        XCTAssertEqual(try originalWorkspaceOwner(), originalOwner)
        capture("hanlin-fresh-read-no-send-returned-to-original-reader")
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
        let nativeConsent = try originalCurrentBookConsentSwitch(in: consent)
        for _ in 0..<4 where !nativeConsent.isHittable { form.swipeUp() }
        tap(nativeConsent)
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

/// Explicit live-account selector, excluded from Native116 and Release114.
/// The runner stages a one-use private input; XCTest never receives the key.
final class HanlinLiveProviderAcceptanceTests: R27NativeUIBase {
    private struct Workspace: Decodable {
        struct Document: Decodable, Equatable {
            struct Session: Decodable, Equatable { let id: UUID; let bookId: Int }
            let backend: String; let session: Session
        }
        struct Group: Decodable {
            let id: UUID; let profileID: UUID; let activeTabID: UUID?; let tabs: [Document]
        }
        struct Scene: Decodable {
            let profileID: UUID; let groupID: UUID; let activeTabIDsByGroup: [UUID: UUID]?
        }
        struct Owner: Equatable {
            let sceneID: String; let profileID: UUID; let groupID: UUID
            let activeTabID: UUID; let tabs: [Document]
        }
        let groups: [Group]; let scenes: [String: Scene]; let lastActiveSceneID: String?
        func owner() throws -> Owner {
            let id = try XCTUnwrap(lastActiveSceneID)
            let scene = try XCTUnwrap(scenes[id])
            let group = try XCTUnwrap(groups.first { $0.id == scene.groupID && $0.profileID == scene.profileID })
            let tab = try XCTUnwrap(scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID)
            XCTAssertTrue(group.tabs.contains { $0.session.id == tab })
            return .init(sceneID: id, profileID: scene.profileID, groupID: group.id, activeTabID: tab, tabs: group.tabs)
        }
    }

    @MainActor
    private func ownedContainer() throws -> URL {
        // Resolve the actual UUID sidecar, including an XCTest reinstall.
        var value = try workspaceSidecarURL()
        for _ in 0..<6 { value.deleteLastPathComponent() }
        return value
    }

    private nonisolated static func readerReceiptLines(_ log: URL) throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: log.path) else { return [] }
        return Set(try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
            .filter { $0.contains("[NativeNavigationReceipt]") && $0.contains("destination=native.reader ") })
    }

    @MainActor
    private func savedConversation(prompt: String) throws -> [String: Any] {
        let root = try ownedContainer().appendingPathComponent("Library/Application Support/ChavrusaText/HanlinConversations/v1")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]))
        var matches: [[String: Any]] = []
        var count = 0
        for case let file as URL in files where file.pathExtension == "json" {
            count += 1
            XCTAssertLessThanOrEqual(count, 256, "Only the bounded fresh Simulator conversation store may be inspected")
            let attributes = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard attributes.isRegularFile == true else { continue }
            XCTAssertLessThanOrEqual(try XCTUnwrap(attributes.fileSize), 8 * 1024 * 1024)
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
            guard let history = value["history"] as? [String: Any],
                  let messages = history["messages"] as? [[String: Any]],
                  messages.contains(where: { ($0["role"] as? String) == "user" && ($0["content"] as? String) == prompt }) else { continue }
            matches.append(value)
        }
        XCTAssertEqual(matches.count, 1, "Exactly one original saved conversation must contain this live challenge")
        return try XCTUnwrap(matches.first)
    }

    @MainActor
    func testOriginalLiveProviderUsesCanonicalCoreAndRevokesReadConsent() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["OTZARIA_HANLIN_LIVE_PROVIDER_CASE"] == "1",
            "This separate live-account selector requires the explicit owned private-input route")
        continueAfterFailure = false
        executionTimeAllowance = 600
        XCTAssertTrue(isPad, "The separate live selector declares the original 11-inch iPad")
        let nonce = try XCTUnwrap(environment["OTZARIA_HANLIN_LIVE_NONCE"])
        XCTAssertNotNil(UUID(uuidString: nonce))
        let workKey = try XCTUnwrap(environment["R27_EXPECTED_OTZARIA_WORK_KEY"])
        let title = try XCTUnwrap(environment["R27_EXPECTED_OTZARIA_BOOK_TITLE"])
        let query = try XCTUnwrap(environment["OTZARIA_HANLIN_LIVE_QUERY"])
        let section = try XCTUnwrap(environment["OTZARIA_HANLIN_LIVE_SECTION"])
        let model = try XCTUnwrap(environment["OTZARIA_HANLIN_LIVE_MODEL"])
        XCTAssertLessThanOrEqual(model.utf8.count, 128)
        XCTAssertNotNil(model.range(of: #"\Agemini-[a-z0-9][a-z0-9._-]*\z"#, options: .regularExpression))
        XCTAssertFalse(query.isEmpty)
        XCTAssertNotNil(Int64(section), "CI must independently derive the original current fixture line")
        XCUIDevice.shared.orientation = .landscapeLeft
        launchWithTier(.realUI, scenario: "reader", backend: "otzaria", extraArgs: [
            "-preferredBackend", "otzaria", "-smokeBackend", "otzaria",
            "-ChavrusaTextFaithfulReaderUIEnabled", "YES", "-studyWorkspaceTestingNamespace", workspaceNamespace
        ], language: "en", locale: "en_US", extraEnvironment: [
            "OTZARIA_HANLIN_LIVE_PROVIDER_CASE": "1", "OTZARIA_HANLIN_LIVE_NONCE": nonce
        ])
        XCTAssertFalse(app.launchArguments.contains("-smokeBypassBootstrap"))
        dismissAlertsIfNeeded()
        let originalLocator = try assertTarget(backend: "otzaria")
        XCTAssertEqual(originalLocator, "otzaria|" + workKey + "|line:" + section,
            "The live source must resolve the independently selected current fixture line")
        let originalText = try XCTUnwrap(app.textViews["reader-text"].value as? String)
        func owner() throws -> Workspace.Owner {
            try JSONDecoder().decode(Workspace.self, from: Data(contentsOf: workspaceSidecarURL())).owner()
        }
        let originalOwner = try owner()
        func press(_ element: XCUIElement, timeout: TimeInterval = 30) {
            XCTAssertTrue(element.waitForExistence(timeout: timeout))
            XCTAssertTrue(element.isHittable, "The actual native control must perform this action")
            element.tap()
        }
        press(app.buttons["otzaria-hanlin-reader-launch"])
        let consent = app.switches["otzaria-hanlin-allow-current-book"]
        XCTAssertTrue(consent.waitForExistence(timeout: 30))
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertEqual(app.staticTexts["otzaria-hanlin-consent-book-title"].label, title)
        XCTAssertEqual(app.textFields["otzaria-hanlin-service-address"].value as? String,
                       "https://generativelanguage.googleapis.com/v1beta/openai/")
        XCTAssertEqual(app.textFields["otzaria-hanlin-model"].value as? String, model)
        // Never inspect, attach, type or assert the SecureField's credential value.
        let form = app.descendants(matching: .any)["otzaria-hanlin-connection-form"].firstMatch
        let nativeConsent = try originalCurrentBookConsentSwitch(in: consent)
        for _ in 0..<4 where !nativeConsent.isHittable { form.swipeUp() }
        press(nativeConsent)
        XCTAssertEqual(consent.value as? String, "1")
        let connect = app.buttons["otzaria-hanlin-connect"]
        for _ in 0..<4 where !connect.isHittable { form.swipeDown() }
        press(connect)
        let revoke = app.buttons["otzaria-hanlin-end-book-access"]
        XCTAssertTrue(revoke.waitForExistence(timeout: 30), "The original native dismissal must issue the source-qualified read session")
        XCTAssertEqual(app.buttons.matching(identifier: "otzaria-hanlin-close").count, 1)

        let work: [String: Any] = ["backend": "otzaria", "workKey": workKey]
        let searchArguments: [String: Any] = ["backend": "otzaria", "text": query,
            "scopeWorkRefs": [work], "limit": 1, "offset": 0, "matchMode": "exact"]
        let referenceArguments: [String: Any] = ["backend": "otzaria", "workRef": work, "section": section]
        func json(_ value: Any) throws -> String {
            String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), as: UTF8.self)
        }
        let marker = "OTZARIA_LIVE_" + nonce
        let prompt = try "Call otzaria_search_query exactly once with this JSON: " + json(searchArguments)
            + ". After its actual result, call otzaria_catalog_resolve_reference exactly once with this JSON: "
            + json(referenceArguments) + ". Use only these two advertised tools. Never invent a tool result. "
            + "After both real tools succeed reply with exactly " + marker + " as plain text; do not emit OpenUI."
        let editor = app.textViews["otzaria-hanlin-composer"]
        press(editor); editor.typeText(prompt)
        let send = app.buttons["otzaria-hanlin-send"]
        XCTAssertTrue(send.isEnabled)
        press(send)
        let links = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "otzaria-hanlin-source-"))
        XCTAssertTrue(links.firstMatch.waitForExistence(timeout: 180),
            "Only the original Host result callback may create the native source receipt")
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["otzaria-hanlin-stop"])
        XCTAssertEqual(XCTWaiter.wait(for: [completed], timeout: 90), .completed)
        XCTAssertEqual(links.count, 1)
        XCTAssertTrue(links.firstMatch.isHittable)
        let sourceID = try XCTUnwrap(UUID(uuidString: String(links.firstMatch.identifier.dropFirst("otzaria-hanlin-source-".count))))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", marker))
            .firstMatch.waitForExistence(timeout: 30), "The actual live continuation must reach the original transcript")

        let saved = try savedConversation(prompt: prompt)
        let conversationID = try XCTUnwrap(saved["conversationID"] as? String)
        let history = try XCTUnwrap(saved["history"] as? [String: Any])
        let messages = try XCTUnwrap(history["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        let assistant = try XCTUnwrap(messages.first { ($0["role"] as? String) == "assistant" })
        XCTAssertEqual(assistant["content"] as? String, marker)
        let savedSources = try XCTUnwrap(history["sources"] as? [[String: Any]])
        XCTAssertEqual(savedSources.count, 1)
        let savedSource = try XCTUnwrap(savedSources.first)
        XCTAssertEqual(UUID(uuidString: try XCTUnwrap(savedSource["id"] as? String)), sourceID)
        XCTAssertEqual(savedSource["messageID"] as? String, assistant["id"] as? String)
        let destination = try XCTUnwrap(URL(string: try XCTUnwrap(savedSource["destination"] as? String)))
        XCTAssertEqual(destination.scheme, "maktabah")
        XCTAssertEqual(destination.host, "action")
        XCTAssertNil(destination.user); XCTAssertNil(destination.password); XCTAssertNil(destination.fragment)
        let activities = try XCTUnwrap(history["activities"] as? [[String: Any]])
        XCTAssertEqual(activities.count, 2, "Exactly the two requested original Core tools must run")
        func receipt(_ alias: String, action: String, arguments: [String: Any]) throws -> [String: Any] {
            let rows = activities.filter { ($0["name"] as? String) == alias }
            XCTAssertEqual(rows.count, 1)
            let activity = try XCTUnwrap(rows.first)
            XCTAssertEqual(activity["status"] as? String, "Completed")
            XCTAssertEqual(activity["isActive"] as? Bool, false)
            let actualArguments = try XCTUnwrap(activity["arguments"] as? String)
            let decodedArguments = try JSONSerialization.jsonObject(with: Data(actualArguments.utf8))
            XCTAssertEqual(try json(decodedArguments), try json(arguments))
            let raw = try XCTUnwrap(activity["result"] as? String)
            let result = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            XCTAssertEqual(result["action"] as? String, action)
            XCTAssertEqual(result["status"] as? String, "completed")
            XCTAssertEqual(result["backend"] as? String, "otzaria")
            return result
        }
        let search = try receipt("otzaria_search_query", action: "search.query", arguments: searchArguments)
        let resolved = try receipt("otzaria_catalog_resolve_reference", action: "catalog.resolveReference", arguments: referenceArguments)
        let hits = try XCTUnwrap((search["data"] as? [String: Any])?["hits"] as? [[String: Any]])
        XCTAssertEqual(hits.count, 1, "A real hit from the permitted fixture book must reach the original transcript")
        let hitLocator = try XCTUnwrap(hits.first?["locator"] as? [String: Any])
        XCTAssertEqual(hitLocator["backend"] as? String, "otzaria")
        XCTAssertEqual(hitLocator["workKey"] as? String, workKey)
        XCTAssertEqual(UUID(uuidString: try XCTUnwrap(resolved["requestId"] as? String)), sourceID,
            "The visible native source button must bind the actual canonical Core result")
        let resolvedLocator = try XCTUnwrap((resolved["data"] as? [String: Any])?["locator"] as? [String: Any])
        XCTAssertEqual(resolvedLocator["backend"] as? String, "otzaria")
        XCTAssertEqual(resolvedLocator["workKey"] as? String, workKey)

        let draft = "UNSENT_LIVE_" + nonce
        press(editor); editor.typeText(draft)
        press(revoke)
        XCTAssertTrue(app.buttons["otzaria-hanlin-reconnect"].waitForExistence(timeout: 30))
        XCTAssertFalse(revoke.exists)
        XCTAssertEqual(editor.value as? String, draft)
        XCTAssertFalse(send.isEnabled, "Native revocation must discard the original model connection")
        let after = try savedConversation(prompt: prompt)
        XCTAssertEqual(after["conversationID"] as? String, conversationID)
        XCTAssertEqual(try json(try XCTUnwrap((after["history"] as? [String: Any])?["activities"])), try json(activities))
        XCTAssertEqual(try json(try XCTUnwrap((after["history"] as? [String: Any])?["sources"])), try json(savedSources))
        let readerLog = try ownedContainer().appendingPathComponent("Documents/OtzariaLogs/otzaria-reader.log")
        let beforeNavigation = try Self.readerReceiptLines(readerLog)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(UUID(uuidString: String(links.firstMatch.identifier.dropFirst("otzaria-hanlin-source-".count))), sourceID)
        for _ in 0..<4 where !links.firstMatch.isHittable { app.scrollViews.firstMatch.swipeDown() }
        press(links.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["otzaria-hanlin-close"])], timeout: 30), .completed)
        let acknowledged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? Self.readerReceiptLines(readerLog) else { return false }
            return beforeNavigation.isSubset(of: actual) && actual.subtracting(beforeNavigation).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [acknowledged], timeout: 30), .completed,
            "Open source must reach the original native Reader acknowledgement after actual chat dismissal")
        let navigationLine = try XCTUnwrap(Self.readerReceiptLines(readerLog).subtracting(beforeNavigation).first)
        let parts = navigationLine.split(separator: " ", maxSplits: 2)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[1], "[NativeNavigationReceipt]")
        var fields: [String: String] = [:]
        for part in parts[2].split(separator: " ") {
            let pair = part.split(separator: "=", maxSplits: 1)
            XCTAssertEqual(pair.count, 2)
            XCTAssertNil(fields[String(pair[0])])
            fields[String(pair[0])] = String(pair[1])
        }
        XCTAssertEqual(Set(fields.keys), ["request", "scene", "backend", "generation", "epoch", "revision", "destination", "presentation"])
        XCTAssertNotNil(fields["request"].flatMap(UUID.init(uuidString:)))
        XCTAssertEqual(fields["scene"], originalOwner.sceneID)
        XCTAssertEqual(fields["backend"], "otzaria")
        XCTAssertEqual(fields["destination"], "native.reader")
        XCTAssertEqual(fields["presentation"], "currentTab")
        XCTAssertEqual(fields["epoch"], "none")
        XCTAssertNotNil(fields["generation"].flatMap(UInt64.init))
        let revisions = try XCTUnwrap(fields["revision"]).components(separatedBy: "->")
        XCTAssertEqual(revisions.count, 2)
        XCTAssertGreaterThan(try XCTUnwrap(UInt64(revisions[1])), try XCTUnwrap(UInt64(revisions[0])))
        XCTAssertEqual(try assertTarget(backend: "otzaria"), originalLocator)
        XCTAssertTrue(try XCTUnwrap(app.textViews["reader-text"].value as? String).utf8.elementsEqual(originalText.utf8))
        XCTAssertEqual(try owner(), originalOwner, "The live read and native revocation must preserve the exact source/workspace owner")
        let proof: [String: Any] = ["status": "NATIVE_ASSERTIONS_COMPLETED", "nonce": nonce,
            "conversationID": conversationID, "workKey": workKey, "query": query, "section": section, "model": model,
            "visibleSourceResultID": sourceID.uuidString, "searchResult": search, "referenceResult": resolved,
            "nativeReaderReceipt": navigationLine,
            "nativeConsentGranted": true, "nativeConsentRevoked": true, "workspacePreserved": true,
            "credentialTypedOrExported": false]
        let file = try ownedContainer().appendingPathComponent("Documents/otzaria-hanlin-live-" + nonce + ".json")
        try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys]).write(to: file, options: .atomic)
        print("OTZARIA_HANLIN_LIVE_COMPLETED=" + nonce)
    }
}
