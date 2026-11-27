

// Same-active phone Group/Profile presentation is measured through the real
// system entity and public Intent. Original Back/root navigation only sets up
// the hidden Reader; a parent-only receipt cannot satisfy this selection.
extension NativeRoutingAcceptanceTests {
    @MainActor
    func runOriginalHiddenWorkspaceSelection(kind: OriginalHiddenWorkspaceKind,
                                              entry: OriginalHiddenWorkspaceEntry) async throws {
        let work = try launchCurrentCanonicalReader(expectedPad: false)
        let oracle = try systemReaderOracleDocument()
        let initial = try XCTUnwrap(oracle.rows.first { $0.id == oracle.bootstrapRowID })
        XCTAssertEqual(work, "book:\(initial.bookId)")
        let locator = "otzaria|\(work)|line:\(initial.lineIndex)"
        try requireReaderLocator(locator)
        XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, locator)
        let snapshot = try originalWorkspaceSelectionSnapshot()
        let original = try snapshot.selected()
        XCTAssertEqual(original.2.tabs.count, 1)
        let active = try XCTUnwrap(original.3)
        XCTAssertEqual(original.2.tabs.first?.session.id, active)
        XCTAssertEqual(original.2.tabs.first?.session.bookId, initial.bookId)
        XCTAssertEqual(original.2.tabs.first?.backend, "otzaria")
        if kind == .profile {
            let first = try XCTUnwrap(snapshot.groups.filter { $0.profileID == original.1.id }
                .sorted { $0.order < $1.order }.first)
            XCTAssertEqual(first.id, original.2.id,
                           "The original profile intent selects its first ordered group, which must be this same active group")
        }
        let documents = try originalWorkspaceSelectionDocuments()
        let originalReader = try actualReaderWorkspace().current()
        let process = try targetProcessIdentifier()
        let system = IntentDefinitions(bundleIdentifier: "com.davidpovarsky.chavrusatext")
        let entityName = kind == .profile ? "NativeStudyProfileEntity" : "NativeStudyTabGroupEntity"
        let intentName = kind == .profile ? "OpenStudyProfileIntent" : "OpenStudyTabGroupIntent"
        let title = kind == .profile ? original.1.name : original.2.name
        let matches = try await system.entities[entityName].entities(matching: title)
        XCTAssertEqual(matches.count, 1)
        let cached = try XCTUnwrap(matches.count == 1 ? matches.first : nil,
            "Retain one actual system-discovered original workspace entity while its Reader is visible")
        // Independently join the real metadata identity to the persisted scene
        // and original UUIDs. No constructed reference is used for delivery.
        let fields = [kind.rawValue, original.0, "otzaria", original.1.id.uuidString]
            + (kind == .group ? [original.2.id.uuidString] : [])
        let expectedID = "workspaceSelection.v1." + Data(fields.joined(separator: "\u{0}").utf8)
            .base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(cached.identifier.instanceIdentifier, expectedID)
        let beforeBack = try actualNativeReceiptLines()
        let back = app.navigationBars.buttons.matching(identifier: "BackButton")
            .matching(NSPredicate(format: "label == %@", "Library"))
        XCTAssertEqual(back.count, 1)
        let originalBack = try XCTUnwrap(back.count == 1 ? back.allElementsBoundByIndex.first : nil)
        XCTAssertTrue(originalBack.exists && originalBack.isHittable && !originalBack.frame.isEmpty)
        originalBack.tap()
        try requireOriginalHiddenPhoneReaderLibrary()
        try requirePreservedOriginalWorkspace(originalReader)
        XCTAssertEqual(try originalWorkspaceSelectionDocuments(), documents)
        XCTAssertEqual(try actualNativeReceiptLines(), beforeBack,
                       "Ordinary Back hides the original Reader without a selection receipt")
        XCTAssertEqual(try targetProcessIdentifier(), process)
        let hidden = try await system.entities[entityName].entities(matching: title)
        XCTAssertEqual(hidden.count, 1,
                       "The original same-active hidden workspace target must remain discoverable")
        XCTAssertEqual(hidden.first?.identifier.instanceIdentifier, expectedID)

        if entry == .history || entry == .search {
            let request = UUID()
            let destination = entry == .history ? "native.history" : "native.search"
            let url = try entry == .history ? historyURL("otzaria", request: request)
                : publicRootURL("native.search", request: request)
            try openInExistingProcess(url)
            let root = entry == .history ? history : app.otherElements["global-search-screen"]
            XCTAssertTrue(root.waitForExistence(timeout: 15))
            XCTAssertTrue(root.isHittable && !root.frame.isEmpty
                && app.windows.firstMatch.frame.intersects(root.frame))
            try requireRootReceipt(request, destination: destination)
            XCTAssertFalse(app.staticTexts["reader-current-locator"].exists)
            try requirePreservedOriginalWorkspace(originalReader)
            XCTAssertEqual(try originalWorkspaceSelectionDocuments(), documents)
        }
        let before = try actualNativeReceiptLines()
        try attachWorkspaceSnapshot("hidden-original-workspace-\(kind.rawValue)-\(entry.rawValue)-before")
        if entry == .background { backgroundOriginalHiddenPhoneReader() }

        // Sole measured delivery: this exact real cached entity through the
        // production AppIntent. No direct perform, private probe, activation
        // fallback, synthetic reference, source mutation or renewed command.
        _ = try await system.intents[intentName].makeIntent(selection: cached).run()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertEqual(try targetProcessIdentifier(), process)
        try requireReaderLocator(locator)
        XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, locator)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.originalWorkspaceSelectionSnapshot().selected() else { return false }
            return current.0 == original.0 && current.1.id == original.1.id
                && current.2.id == original.2.id && current.3 == active
                && current.2.tabs.map { $0.session.id } == original.2.tabs.map { $0.session.id }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed,
                       "Present the exact existing active Reader without changing original profile/group/tab ownership")
        try requirePreservedOriginalWorkspace(originalReader)
        XCTAssertEqual(try originalWorkspaceSelectionDocuments(), documents)
        try requireNewSystemIntentReceipt(destination: "native.workspace.selection", presentation: "currentTab", before: before)
        let receipt = try XCTUnwrap(actualNativeReceiptLines().subtracting(before).first)
        XCTAssertTrue(receipt.split(separator: " ").contains(Substring("scene=" + original.0)))
        XCTAssertFalse(app.alerts["Unable to change the study workspace"].exists)
        let header = app.staticTexts["reader-header-title"]
        XCTAssertTrue(header.exists && header.isHittable && !header.frame.isEmpty)
        let frame = header.frame, receipts = try actualNativeReceiptLines()
        let drift = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.originalWorkspaceSelectionSnapshot().selected(),
                  let saved = try? self.originalWorkspaceSelectionDocuments(),
                  let lines = try? self.actualNativeReceiptLines() else { return true }
            return current.0 != original.0 || current.1.id != original.1.id
                || current.2.id != original.2.id || current.3 != active || saved != documents || lines != receipts
                || !header.exists || !header.isHittable || header.frame != frame
                || self.app.staticTexts["reader-current-locator"].label != locator
        }, object: nil)
        drift.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [drift], timeout: 2), .completed)
        XCTAssertEqual(try XCTUnwrap(getRenderedHighlightSnapshot()).locator, locator)
        try attachWorkspaceSnapshot("hidden-original-workspace-\(kind.rawValue)-\(entry.rawValue)-after")
        capture("hidden-original-workspace-\(kind.rawValue)-\(entry.rawValue)-after")
        // Saved source/search/membership and actual TextKit locator are tested.
        // This selector does not claim complete viewport/selection/TOC restore,
        // process relaunch, production, multiwindow or physical acceptance.
    }
}
