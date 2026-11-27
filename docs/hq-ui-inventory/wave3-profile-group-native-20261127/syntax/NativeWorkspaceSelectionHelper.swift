

// Typed Profile/Group selection is measured through the actual OS Intent API.
// Ordinary original controls below create setup state; they cannot satisfy the
// tested private route's canonical receipt or its exact persisted selection.
extension NativeRoutingAcceptanceTests {
    private struct OriginalWorkspaceSelectionSnapshot: Decodable {
        struct Profile: Decodable { let id: UUID; let name: String; let order: Int }
        struct Group: Decodable {
            let id: UUID; let profileID: UUID; let name: String; let order: Int
            let activeTabID: UUID?; let tabs: [ReaderWorkspaceSnapshot.Document]
        }
        let profiles: [Profile]
        let groups: [Group]
        let scenes: [String: ReaderWorkspaceSnapshot.Scene]
        let lastActiveSceneID: String?

        func selected() throws -> (String, Profile, Group, UUID?) {
            let sceneID = try XCTUnwrap(lastActiveSceneID)
            let scene = try XCTUnwrap(scenes[sceneID])
            let profile = try XCTUnwrap(profiles.first { $0.id == scene.profileID })
            let group = try XCTUnwrap(groups.first { $0.id == scene.groupID && $0.profileID == profile.id })
            let selected = scene.activeTabIDsByGroup?[group.id] ?? group.activeTabID
            return (sceneID, profile, group, selected)
        }
    }

    private func originalWorkspaceSelectionSnapshot() throws -> OriginalWorkspaceSelectionSnapshot {
        try JSONDecoder().decode(OriginalWorkspaceSelectionSnapshot.self,
            from: Data(contentsOf: workspaceSidecarURL()))
    }

    /// Compare all original group membership and saved source/location/search
    /// semantics. Viewport/selection/TOC restoration remains the original full
    /// Reader suite's separate obligation, not a claim of this focused route.
    private func originalWorkspaceSelectionDocuments() throws -> Data {
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: workspaceSidecarURL())) as? [String: Any])
        let profiles = try XCTUnwrap(raw["profiles"] as? [[String: Any]])
        let snapshot = try originalWorkspaceSelectionSnapshot()
        let groups: [[String: Any]] = try snapshot.groups.map { group in
            let documents: Data
            if group.tabs.isEmpty { documents = Data("[]".utf8) }
            else { documents = try actualSiriReaderDocuments(groupID: group.id) }
            return ["id": group.id.uuidString, "profileID": group.profileID.uuidString,
                    "name": group.name, "order": group.order,
                    "documents": try JSONSerialization.jsonObject(with: documents)]
        }
        return try JSONSerialization.data(withJSONObject: ["profiles": profiles, "groups": groups],
                                          options: [.sortedKeys])
    }

    @MainActor
    private func originalSelectionButton(_ label: String) throws -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            query.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && !$0.frame.isEmpty }.count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let visible = query.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && !$0.frame.isEmpty }
        XCTAssertEqual(visible.count, 1, "Use one actual visible original control, without coordinate fallback")
        return try XCTUnwrap(visible.count == 1 ? visible.first : nil)
    }

    @MainActor
    private func openOriginalSelectionOverview(expectedPad: Bool) throws {
        let overview = app.descendants(matching: .any).matching(identifier: "study-groups-overview").firstMatch
        XCTAssertFalse(overview.exists, "Setup must open the real original overview exactly once")
        if expectedPad {
            try originalTopBarActionInWindow(identifier: "reader-tabs-overview", labels: ["All Tabs"]).tap()
        } else {
            let title = app.staticTexts["reader-header-title"].label
            XCTAssertFalse(title.isEmpty)
            try originalTopBarActionInWindow(identifier: "reader-open-tabs-button", labels: [title]).tap()
        }
        XCTAssertTrue(overview.waitForExistence(timeout: 15))
        XCTAssertTrue(overview.isHittable && !overview.frame.isEmpty)
    }

    @MainActor
    private func closeOriginalSelectionSheet(_ identifier: String) throws {
        let sheet = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(sheet.exists)
        try originalSelectionButton("Done").tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: sheet)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 15), .completed)
    }

    @MainActor
    private func createOriginalEmptySelectionGroup(name: String, profileID: UUID) throws -> UUID {
        let before = try originalWorkspaceSelectionSnapshot()
        let priorIDs = Set(before.groups.map(\.id))
        let actions = app.buttons["study-group-actions-menu"]
        XCTAssertTrue(actions.exists && actions.isHittable); actions.tap()
        try originalSelectionButton("New empty group").tap()
        let prompt = app.alerts["Tab group name"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        let field = prompt.textFields["Name"]
        XCTAssertTrue(field.isHittable); field.tap(); field.typeText(name)
        let save = prompt.buttons["Save"]
        XCTAssertTrue(save.isHittable); save.tap()
        let stored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let selected = try? self.originalWorkspaceSelectionSnapshot().selected() else { return false }
            return selected.1.id == profileID && selected.2.profileID == profileID
                && selected.2.name == name && !priorIDs.contains(selected.2.id)
                && selected.2.tabs.isEmpty && selected.3 == nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stored], timeout: 15), .completed)
        XCTAssertTrue(app.staticTexts["No tabs in this group"].waitForExistence(timeout: 15))
        let selected = try originalWorkspaceSelectionSnapshot().selected()
        XCTAssertEqual(selected.1.id, profileID); XCTAssertEqual(selected.2.name, name)
        XCTAssertTrue(selected.2.tabs.isEmpty); XCTAssertNil(selected.3)
        return selected.2.id
    }

    @MainActor
    private func selectOriginalProfileForSetup(_ profileID: UUID) throws {
        let before = try originalWorkspaceSelectionSnapshot()
        let profile = try XCTUnwrap(before.profiles.first { $0.id == profileID })
        let first = try XCTUnwrap(before.groups.filter { $0.profileID == profileID }.sorted { $0.order < $1.order }.first)
        try originalTopBarActionInWindow(identifier: "study-profile-menu", labels: ["Study Profile"]).tap()
        try originalSelectionButton(profile.name).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.originalWorkspaceSelectionSnapshot().selected() else { return false }
            return current.1.id == profileID && current.2.id == first.id
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
    }

    @MainActor
    private func requireOriginalSelectionEmptySurface(expectedPad: Bool) throws -> XCUIElement {
        let empty: XCUIElement
        if expectedPad {
            // The actual original Library.xcstrings/selectBookToRead English
            // translation, rather than a testing-only placeholder or marker.
            empty = app.staticTexts["Select a book to read"]
        } else {
            requireOriginalPhoneLibrary(timeout: 15)
            empty = app.descendants(matching: .any).matching(identifier: "library-contents-list").firstMatch
        }
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            empty.exists && empty.isHittable && !empty.frame.isEmpty
                && self.app.windows.firstMatch.frame.intersects(empty.frame)
                && !self.app.staticTexts["reader-current-locator"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 15), .completed,
                       "An empty original group requires its actual empty Reader or original phone Library")
        return empty
    }

    @MainActor
    func runOriginalWorkspaceSelectionSystemIntent(expectedPad: Bool,
        selectionCase: OriginalWorkspaceSelectionCase, fromBackground: Bool = false,
        rejectDeletedGroup: Bool = false) async throws {
        let work = try launchCurrentCanonicalReader(expectedPad: expectedPad)
        let oracle = try systemReaderOracleDocument()
        let initial = try XCTUnwrap(oracle.rows.first { $0.id == oracle.bootstrapRowID })
        XCTAssertEqual(work, "book:\(initial.bookId)")
        let locator = "otzaria|\(work)|line:\(initial.lineIndex)"
        let start = try originalWorkspaceSelectionSnapshot().selected()
        XCTAssertEqual(start.2.tabs.count, 1)
        XCTAssertEqual(start.2.tabs.first?.session.bookId, initial.bookId)
        let pid = try targetProcessIdentifier()
        let setupReceipts = try actualNativeReceiptLines()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let targetProfile: UUID
        let targetGroup: UUID
        let entityTitle: String
        let isProfile = selectionCase == .firstProfileGroup

        if isProfile {
            if !expectedPad { try openOriginalSelectionOverview(expectedPad: false) }
            try originalTopBarActionInWindow(identifier: "study-profile-menu", labels: ["Study Profile"]).tap()
            try originalSelectionButton("Manage Study Profiles").tap()
            let profiles = app.descendants(matching: .any).matching(identifier: "study-profile-management").firstMatch
            XCTAssertTrue(profiles.waitForExistence(timeout: 15))
            let create = app.buttons["study-profile-create"]
            XCTAssertTrue(create.exists && create.isHittable); create.tap()
            let name = "System profile " + UUID().uuidString
            let field = app.textFields["Profile name"]
            XCTAssertTrue(field.waitForExistence(timeout: 15)); XCTAssertTrue(field.isHittable)
            field.tap(); field.typeText(name)
            try originalSelectionButton("Save").tap()
            let created = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                (try? self.originalWorkspaceSelectionSnapshot().profiles.filter { $0.name == name }.count) == 1
                    && !self.app.textFields["Profile name"].exists
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 15), .completed)
            let saved = try originalWorkspaceSelectionSnapshot()
            let profile = try XCTUnwrap(saved.profiles.first { $0.name == name })
            let first = try XCTUnwrap(saved.groups.filter { $0.profileID == profile.id }.sorted { $0.order < $1.order }.first)
            XCTAssertTrue(first.tabs.isEmpty); XCTAssertNil(first.activeTabID)
            try closeOriginalSelectionSheet("study-profile-management")
            // Select the actual newly created profile through its original menu,
            // then add a second group. The tested profile intent must later pick
            // the original FIRST group, not that profile's most recently used one.
            try selectOriginalProfileForSetup(profile.id)
            if expectedPad { try openOriginalSelectionOverview(expectedPad: true) }
            let second = try createOriginalEmptySelectionGroup(name: "Second group " + UUID().uuidString,
                                                               profileID: profile.id)
            XCTAssertNotEqual(second, first.id)
            if expectedPad { try closeOriginalSelectionSheet("study-groups-overview") }
            try selectOriginalProfileForSetup(start.1.id)
            if !expectedPad { try closeOriginalSelectionSheet("study-groups-overview") }
            try requireReaderLocator(locator)
            targetProfile = profile.id; targetGroup = first.id; entityTitle = profile.name
        } else {
            try openOriginalSelectionOverview(expectedPad: expectedPad)
            let name = "System group " + UUID().uuidString
            let emptyID = try createOriginalEmptySelectionGroup(name: name, profileID: start.1.id)
            if expectedPad { try closeOriginalSelectionSheet("study-groups-overview") }
            if selectionCase == .emptyGroup {
                try selectOriginalProfileForSetup(start.1.id)
                if !expectedPad { try closeOriginalSelectionSheet("study-groups-overview") }
                try requireReaderLocator(locator)
                targetGroup = emptyID; entityTitle = name
            } else {
                if !expectedPad { try closeOriginalSelectionSheet("study-groups-overview") }
                _ = try requireOriginalSelectionEmptySurface(expectedPad: expectedPad)
                targetGroup = start.2.id; entityTitle = start.2.name
            }
            targetProfile = start.1.id
        }
        XCTAssertEqual(try actualNativeReceiptLines(), setupReceipts,
                       "Only ordinary original controls create the setup; they produce no canonical target ACK")
        let beforeState = try originalWorkspaceSelectionSnapshot()
        let beforeSelected = try beforeState.selected()
        XCTAssertEqual(beforeSelected.0, start.0)
        XCTAssertNotEqual(beforeSelected.2.id, targetGroup, "Require a genuine selection, not a root/no-op proxy")
        let target = try XCTUnwrap(beforeState.groups.first { $0.id == targetGroup && $0.profileID == targetProfile })
        let expectedTab = beforeState.scenes[start.0]?.activeTabIDsByGroup?[targetGroup]
            ?? target.activeTabID ?? target.tabs.first?.session.id
        let savedDocuments = try originalWorkspaceSelectionDocuments()
        let entityName = isProfile ? "NativeStudyProfileEntity" : "NativeStudyTabGroupEntity"
        let intentName = isProfile ? "OpenStudyProfileIntent" : "OpenStudyTabGroupIntent"
        let matches = try await system.entities[entityName].entities(matching: entityTitle)
        XCTAssertEqual(matches.count, 1, "Retain one actual system-discovered source entity in the exact original window")
        let cached = try XCTUnwrap(matches.count == 1 ? matches.first : nil)
        let before = try actualNativeReceiptLines()
        try attachWorkspaceSnapshot("system-workspace-selection-before")
        if fromBackground {
            XCUIDevice.shared.press(.home)
            let background = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.app.state == .runningBackground || self.app.state == .runningBackgroundSuspended
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 15), .completed)
        }

        // Sole measured delivery. There is no URL, makeReference(), direct
        // perform(), app.activate() fallback or testing-only product route.
        _ = try await system.intents[intentName].makeIntent(selection: cached).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertEqual(try targetProcessIdentifier(), pid)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.originalWorkspaceSelectionSnapshot().selected() else { return false }
            return current.0 == start.0 && current.1.id == targetProfile && current.2.id == targetGroup
                && current.3 == expectedTab && current.2.tabs.map { $0.session.id } == target.tabs.map { $0.session.id }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
        let visible: XCUIElement
        if target.tabs.isEmpty {
            XCTAssertNil(expectedTab)
            visible = try requireOriginalSelectionEmptySurface(expectedPad: expectedPad)
        } else {
            XCTAssertEqual(target.id, start.2.id)
            try requireReaderLocator(locator)
            XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, locator)
            visible = app.staticTexts["reader-header-title"]
            XCTAssertTrue(visible.exists && visible.isHittable && !visible.frame.isEmpty)
        }
        let receipted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let lines = try? self.actualNativeReceiptLines() else { return false }
            return before.isSubset(of: lines) && lines.subtracting(before).count == 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [receipted], timeout: 15), .completed)
        try requireNewSystemIntentReceipt(destination: "native.workspace.selection", presentation: "currentTab", before: before)
        let line = try XCTUnwrap(actualNativeReceiptLines().subtracting(before).first)
        XCTAssertTrue(line.split(separator: " ").contains(Substring("scene=" + start.0)))
        XCTAssertEqual(try originalWorkspaceSelectionDocuments(), savedDocuments,
                       "Selection preserves every original profile/group and saved document's source semantics")
        XCTAssertFalse(app.alerts["Unable to change the study workspace"].exists)
        let stableReceipts = try actualNativeReceiptLines(), frame = visible.frame
        let drift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.originalWorkspaceSelectionSnapshot().selected(),
                  let documents = try? self.originalWorkspaceSelectionDocuments(),
                  let receipts = try? self.actualNativeReceiptLines() else { return true }
            return current.0 != start.0 || current.1.id != targetProfile || current.2.id != targetGroup
                || current.3 != expectedTab || documents != savedDocuments || receipts != stableReceipts
                || !visible.exists || !visible.isHittable || visible.frame != frame
        }, object: nil)
        drift.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [drift], timeout: 2), .completed)
        try attachWorkspaceSnapshot("system-workspace-selection-after")
        capture("system-workspace-selection-" + selectionCase.rawValue)

        guard rejectDeletedGroup else { return }
        XCTAssertTrue(expectedPad); XCTAssertEqual(selectionCase, .warmGroup)
        try openOriginalSelectionOverview(expectedPad: true)
        let actions = app.buttons["study-group-actions-menu"]
        XCTAssertTrue(actions.exists && actions.isHittable); actions.tap()
        try originalSelectionButton("Delete group").tap()
        let question = app.staticTexts["Delete this group and its tabs?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        try originalSelectionButton("Delete group").tap()
        let deleted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = try? self.originalWorkspaceSelectionSnapshot(),
                  let current = try? value.selected() else { return false }
            return !value.groups.contains { $0.id == targetGroup }
                && current.1.id == start.1.id && current.2.id != targetGroup
                && current.2.tabs.isEmpty && current.3 == nil
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [deleted], timeout: 15), .completed)
        try closeOriginalSelectionSheet("study-groups-overview")
        _ = try requireOriginalSelectionEmptySurface(expectedPad: true)
        XCTAssertEqual(try actualNativeReceiptLines(), stableReceipts)
        let unavailable = try await system.entities[entityName].entities(matching: entityTitle)
        XCTAssertTrue(unavailable.isEmpty)
        let stableState = try originalReaderTabWorkspaceSemantics()
        let beforeRefusal = try actualNativeReceiptLines()
        var rejected = false
        do { _ = try await system.intents[intentName].makeIntent(selection: cached).run() }
        catch {
            rejected = true
            let evidence = XCTAttachment(string: String(describing: error))
            evidence.name = "system-workspace-deleted-group-actual-refusal"; evidence.lifetime = .keepAlways; add(evidence)
        }
        XCTAssertTrue(rejected, "The same actually successful cached entity must now be refused")
        XCTAssertEqual(try actualNativeReceiptLines(), beforeRefusal)
        XCTAssertEqual(try originalReaderTabWorkspaceSemantics(), stableState)
        let lateEffect = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let receipts = try? self.actualNativeReceiptLines(),
                  let state = try? self.originalReaderTabWorkspaceSemantics() else { return true }
            return receipts != beforeRefusal || state != stableState
        }, object: nil)
        lateEffect.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [lateEffect], timeout: 5), .completed,
                       "The full original command bound must produce no late stale selection or ACK")
        XCTAssertEqual(try targetProcessIdentifier(), pid)
        _ = try requireOriginalSelectionEmptySurface(expectedPad: true)
        try attachWorkspaceSnapshot("system-workspace-deleted-group-refused")
        capture("system-workspace-deleted-group-refused")
    }
}
