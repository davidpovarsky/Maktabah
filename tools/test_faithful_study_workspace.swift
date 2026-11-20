import Foundation

private struct CheckFailure: Error { let message: String }

@main
struct FaithfulStudyWorkspaceTests {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("study-workspace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var checks = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
            guard value() else { throw CheckFailure(message: message) }
            checks += 1
        }
        var chrome = ReaderNavigationChromeState()
        chrome.beginDragging()
        chrome.consume(translationY: -40, isAtTop: false)
        try expect(!chrome.isVisible, "Downward manual pan hides bars")
        for _ in 0..<20 { chrome.consume(translationY: -40, isAtTop: false) }
        try expect(!chrome.isVisible, "Layout changes with unchanged pan cannot reveal bars")
        chrome.beginDragging()
        chrome.consume(translationY: 10, isAtTop: false)
        try expect(!chrome.isVisible, "New gesture cannot inherit a stale direction")
        chrome.consume(translationY: 20, isAtTop: false)
        try expect(chrome.isVisible, "Upward manual pan restores bars")
        chrome.consume(translationY: -40, isAtTop: false)
        chrome.consume(translationY: -40, isAtTop: true)
        try expect(chrome.isVisible, "Book top restores bars")
        chrome.reveal()
        chrome.consume(translationY: -900, isAtTop: false)
        try expect(chrome.isVisible, "Explicit navigation reveal clears stale samples")
        let canonicalURL = directory.appendingPathComponent("ios_reader_session.json")
        let canonical = Data("canonical session must stay byte-identical".utf8)
        try canonical.write(to: canonicalURL)
        let priorSidecarURL = directory.appendingPathComponent("study_workspace_v1.json")
        let priorBackupURL = directory.appendingPathComponent("study_workspace_v1.bak.json")
        let priorSidecar = Data("opaque prior study workspace, schema deliberately not imported".utf8)
        let priorBackup = Data("opaque prior study backup".utf8)
        try priorSidecar.write(to: priorSidecarURL)
        try priorBackup.write(to: priorBackupURL)
        let persistence = StudyWorkspacePersistence(url: directory.appendingPathComponent("StudyWorkspace/workspace-v1.json"))
        let store = StudyWorkspaceStore(persistence: persistence, canonicalSessionURL: canonicalURL)
        try expect(!FileManager.default.fileExists(atPath: persistence.url.deletingLastPathComponent().path), "Constructing an unused store must not create files")

        let originalTabID = UUID()
        let original = ReaderDocumentTab(backend: .otzaria, session: .init(
            id: originalTabID, bookId: 17, bookTitle: "שבת", backendLocator: .init(backend: .otzaria, workKey: "book:17", position: .legacyLine(120)),
            contentId: 120, locator: .init(backend: .otzaria, workKey: "book:17", position: .legacyLine(120)),
            page: 3, scrollPosition: CGPoint(x: 0, y: 812), selectedRange: NSRange(location: 9, length: 4)))
        try store.attach(scene: "window-a", legacyTabs: [original], activeID: originalTabID)
        try expect(tryData(persistence.url.deletingLastPathComponent().appendingPathComponent("pre-workspace-ios-reader-session.json")) == canonical,
                   "Migration archives the original canonical bytes without modifying them")
        let priorArchiveURL = persistence.url.deletingLastPathComponent().appendingPathComponent("pre-rebuild-study-workspace-v1.json")
        try expect(tryData(priorArchiveURL) == priorSidecar, "Migration archives the actual previous experimental sidecar without interpreting it")
        try expect(tryData(persistence.url.deletingLastPathComponent().appendingPathComponent("pre-rebuild-study-workspace-v1.bak.json")) == priorBackup,
                   "Migration also preserves the previous experimental backup")
        try expect(tryData(priorSidecarURL) == priorSidecar && tryData(priorBackupURL) == priorBackup,
                   "Archival leaves both prior experimental files byte-identical")
        try Data("a later old-build write".utf8).write(to: priorSidecarURL)
        try persistence.archiveBeforeMigration(canonicalSessionURL: canonicalURL)
        try expect(tryData(priorArchiveURL) == priorSidecar, "Repeated attach never overwrites the pre-rebuild archive")
        try expect(store.snapshot?.migratedLegacySession == true, "Legacy migration is explicitly recorded")
        try expect(store.selectedGroup(scene: "window-a")?.tabs.first == original, "Migration preserves identity, locator, scroll and selection")
        let copied = original.reidentified()
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: .sefaria, requestedID: original.id, documents: [original], fallback: .otzaria) == .sefaria,
                   "Cold restore must not override the canonical committed library backend")
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: nil, requestedID: original.id, documents: [original], fallback: .sefaria) == .otzaria,
                   "An explicit group selection may request its saved document backend")
        try expect(StudyWorkspaceProjectionPolicy.backend(restoring: nil, requestedID: nil, documents: [original], fallback: .sefariaEmbedded) == .otzaria,
                   "A populated group with no active ID must open its genuine first document, not an empty foreign projection")
        try expect(copied.id != original.id && copied.session.bookId == original.session.bookId, "Copying the same book creates an independent document identity")
        try expect(copied.session.locator == original.session.locator && copied.session.scrollPosition == original.session.scrollPosition && copied.session.selectedRange == original.session.selectedRange,
                   "Copying preserves initial locator, viewport and selection without sharing a mutable session")
        let foreign = ReaderDocumentTab(backend: .sefariaEmbedded, session: .init(id: UUID(), bookId: 42, bookTitle: "Genesis"))
        let mixed = [original, foreign, copied]
        try expect(StudyWorkspaceProjectionPolicy.merging(live: [original, copied], into: mixed, backend: .otzaria) == mixed,
                   "Saving an unchanged backend must preserve interleaved foreign-book order")
        try expect(StudyWorkspaceProjectionPolicy.merging(live: [copied, original], into: mixed, backend: .otzaria) == [copied, foreign, original],
                   "Native strip reorder updates its own slots without moving foreign documents")
        try expect(StudyWorkspaceProjectionPolicy.merging(live: [], into: mixed, backend: .otzaria) == [foreign],
                   "Closing every live tab preserves foreign-source books")
        try expect(StudyWorkspaceProjectionPolicy.merging(live: [copied], into: mixed, backend: .otzaria) == [foreign, copied],
                   "Closing an early live tab must not pull a later tab across a foreign book")
        let mixedPersistence = StudyWorkspacePersistence(url: directory.appendingPathComponent("mixed-workspace.json"))
        let mixedStore = StudyWorkspaceStore(persistence: mixedPersistence, canonicalSessionURL: canonicalURL)
        try mixedStore.attach(scene: "mixed-window", legacyTabs: mixed, activeID: original.id)
        let mixedGroupID = mixedStore.selectedGroup(scene: "mixed-window")!.id
        try mixedStore.reorderDocument(foreign.id, to: 0, groupID: mixedGroupID)
        try expect(mixedStore.selectedGroup(scene: "mixed-window")?.tabs == [foreign, original, copied],
                   "Overview reorder moves a real foreign-source document without replacing sessions")
        try expect(mixedStore.selectedGroup(scene: "mixed-window")?.activeTabID == original.id,
                   "Overview reorder preserves active document identity")
        let mixedColdStore = StudyWorkspaceStore(persistence: mixedPersistence, canonicalSessionURL: canonicalURL)
        try expect(mixedColdStore.selectedGroup(scene: "mixed-window")?.tabs == [foreign, original, copied],
                   "Mixed-source overview order survives reload")
        let beforeBadOrder = mixedStore.snapshot
        do { try mixedStore.reorderDocument(foreign.id, to: 30, groupID: mixedGroupID) }
        catch StudyWorkspaceError.invalidMembership { }
        try expect(mixedStore.snapshot == beforeBadOrder, "Invalid reorder leaves persistent and visible state intact")
        let migrated = store.snapshot
        try store.attach(scene: "window-a", legacyTabs: [], activeID: nil)
        try expect(store.snapshot == migrated, "Attaching twice must not remigrate or erase the original tabs")

        // A cold launch must retain the selected group when the old build's
        // generated scene UUID is replaced by UIKit's persistent session ID.
        let scenePersistence = StudyWorkspacePersistence(url: directory.appendingPathComponent("scene-history/workspace.json"))
        let legacySceneStore = StudyWorkspaceStore(persistence: scenePersistence, canonicalSessionURL: canonicalURL)
        try legacySceneStore.attach(scene: "legacy-random-uuid", legacyTabs: [original], activeID: original.id)
        let sceneProfile = legacySceneStore.snapshot!.profiles[0].id
        let emptySceneGroup = try legacySceneStore.addGroup(profileID: sceneProfile, name: "empty selected group")
        try legacySceneStore.transaction { value in
            value.scenes["legacy-random-uuid"] = .init(profileID: sceneProfile, groupID: emptySceneGroup)
        }
        var oldSceneJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: scenePersistence.url)) as! [String: Any]
        oldSceneJSON.removeValue(forKey: "lastActiveSceneID")
        try JSONSerialization.data(withJSONObject: oldSceneJSON).write(to: scenePersistence.url)
        let nativeSceneStore = StudyWorkspaceStore(persistence: scenePersistence, canonicalSessionURL: canonicalURL)
        try nativeSceneStore.attach(scene: "native-session-a", legacyTabs: [original], activeID: original.id)
        try expect(nativeSceneStore.selectedGroup(scene: "native-session-a")?.id == emptySceneGroup,
                   "Migrating a v1 scene identity retains its selected empty group instead of reviving legacy tabs")
        try expect(nativeSceneStore.snapshot?.scenes["legacy-random-uuid"]?.groupID == emptySceneGroup,
                   "Scene identity handoff does not delete or rewrite the older scene's selection")
        try expect(nativeSceneStore.snapshot?.version == 1, "Optional scene continuity metadata reads existing v1 files")
        let positioned = ReaderDocumentTab(backend: .otzaria, session: .init(
            id: UUID(), bookId: 17, bookTitle: "שבת", contentId: 527,
            locator: .init(backend: .otzaria, workKey: "book:17", position: .legacyLine(527))))
        let positionedGroup = try nativeSceneStore.addGroup(profileID: sceneProfile, name: "independent position", tabs: [positioned], activeID: positioned.id)
        try nativeSceneStore.transaction { value in
            value.scenes["native-session-a"] = .init(profileID: sceneProfile, groupID: positionedGroup)
            value.lastActiveSceneID = "native-session-a"
        }
        let coldSceneStore = StudyWorkspaceStore(persistence: scenePersistence, canonicalSessionURL: canonicalURL)
        try coldSceneStore.attach(scene: "native-session-a", legacyTabs: [original], activeID: original.id)
        try expect(coldSceneStore.selectedGroup(scene: "native-session-a")?.tabs.first == positioned,
                   "Cold attach of the actual persistent session retains its document ID and independent locator")
        try coldSceneStore.attach(scene: "native-session-b", legacyTabs: [], activeID: nil)
        try coldSceneStore.transaction { value in
            value.scenes["native-session-b"] = .init(profileID: sceneProfile, groupID: emptySceneGroup)
            value.lastActiveSceneID = "native-session-b"
        }
        let twoWindowStore = StudyWorkspaceStore(persistence: scenePersistence, canonicalSessionURL: canonicalURL)
        try twoWindowStore.attach(scene: "native-session-a", legacyTabs: [], activeID: nil)
        try expect(twoWindowStore.selectedGroup(scene: "native-session-a")?.tabs.first == positioned,
                   "An existing window never adopts another window's last-active selection")
        try expect(twoWindowStore.selectedGroup(scene: "native-session-b")?.tabs.isEmpty == true,
                   "The second window retains its own empty group across the first window's cold attach")

        let profileID = try store.addProfile(name: "לימוד", symbol: "book.closed")
        let groupID = try store.addGroup(profileID: profileID, name: "קבוצה ריקה")
        try store.attach(scene: "window-b", legacyTabs: [], activeID: nil)
        try store.transaction { value in value.scenes["window-b"] = .init(profileID: profileID, groupID: groupID) }
        try expect(store.snapshot?.scenes["window-a"] != store.snapshot?.scenes["window-b"], "Each scene owns its selected profile/group")
        try expect(store.selectedGroup(scene: "window-b")?.tabs.isEmpty == true, "Empty groups remain genuinely empty")
        let thirdProfile = try store.addProfile(name: "שלישי", symbol: "star")
        for profile in store.snapshot!.profiles {
            while store.snapshot!.groups.filter({ $0.profileID == profile.id }).count < 3 {
                _ = try store.addGroup(profileID: profile.id, name: "קבוצה \(store.snapshot!.groups.count)")
            }
        }
        try expect(store.snapshot?.profiles.count == 3 && store.snapshot?.groups.count == 9, "Three profiles own three genuine groups each")
        let orderedIDs = store.snapshot!.groups.filter { $0.profileID == thirdProfile }.map(\.id).reversed()
        try store.orderGroups(Array(orderedIDs), profileID: thirdProfile)
        try expect(store.snapshot!.groups.filter { $0.profileID == thirdProfile }.sorted { $0.order < $1.order }.map(\.id) == Array(orderedIDs), "Reordering retains stable identities")
        let selectedBeforeMove = store.snapshot!.scenes["window-b"]!.groupID
        try store.moveGroup(selectedBeforeMove, to: thirdProfile)
        try expect(store.snapshot!.scenes["window-b"]!.profileID == thirdProfile, "Moving a selected group updates its scene's profile without changing the group")
        try expect(store.snapshot!.scenes["window-b"]!.groupID == selectedBeforeMove, "Moving a group retains the selected group UUID")

        let beforeInvalid = store.snapshot
        do {
            try store.transaction { value in value.groups[0].tabs.append(original) }
            throw CheckFailure(message: "Duplicate IDs must be rejected")
        } catch StudyWorkspaceError.invalidMembership { checks += 1 }
        try expect(store.snapshot == beforeInvalid, "Rejected transaction leaves observable state untouched")
        try expect(tryData(persistence.url) == JSONEncoderData(beforeInvalid!), "Rejected transaction leaves durable state untouched")

        let beforeFailure = store.snapshot
        let parent = persistence.url.deletingLastPathComponent()
        let movedParent = directory.appendingPathComponent("retained-workspace")
        try FileManager.default.moveItem(at: parent, to: movedParent)
        try Data("parent is deliberately a file".utf8).write(to: parent)
        do {
            _ = try store.addProfile(name: "must not commit", symbol: "star")
            throw CheckFailure(message: "I/O failure must propagate")
        } catch is CheckFailure { throw CheckFailure(message: "I/O failure did not propagate") }
        catch { checks += 1 }
        try expect(store.snapshot == beforeFailure, "I/O failure rolls back the in-memory transaction")
        try FileManager.default.removeItem(at: parent)
        try FileManager.default.moveItem(at: movedParent, to: parent)

        let validBackup = try Data(contentsOf: persistence.backupURL)
        try Data("{broken json".utf8).write(to: persistence.url)
        let recovered = try persistence.load()
        try expect(recovered != nil, "Corrupt sidecar recovers the validated .bak")
        try expect(tryData(persistence.backupURL) == validBackup, "Recovery never destroys the backup")
        let recoveryStore = StudyWorkspaceStore(persistence: persistence, canonicalSessionURL: canonicalURL)
        _ = try recoveryStore.addProfile(name: "after recovery", symbol: "star")
        try expect(tryData(persistence.backupURL) == validBackup, "A corrupt primary cannot overwrite the last good backup")
        var future = try JSONSerialization.jsonObject(with: Data(contentsOf: persistence.url)) as! [String: Any]
        future["version"] = 999
        let futureBytes = try JSONSerialization.data(withJSONObject: future)
        try futureBytes.write(to: persistence.url)
        do { _ = try persistence.load(); throw CheckFailure(message: "Future schema must be rejected") }
        catch StudyWorkspaceError.unsupportedVersion { checks += 1 }
        try expect(tryData(persistence.url) == futureBytes, "Unknown future schema must never be downgraded")
        try expect(tryData(canonicalURL) == canonical, "Canonical reader session remains byte-identical through migration, failures and recovery")

        try expect(ReaderNavigationDisplayPolicy.title(workTitle: "שבת", navigationUnitTitle: "ג:", explicitSelectionRef: nil) == "שבת, ג:", "Amud bet colon is retained")
        try expect(ReaderNavigationDisplayPolicy.title(workTitle: "שבת", navigationUnitTitle: "ג:", explicitSelectionRef: "שבת ג: פסקה ב") == "שבת ג: פסקה ב", "Only explicit selection may expose paragraph position")
        try expect(ReaderNavigationDisplayPolicy.title(workTitle: "שבת", navigationUnitTitle: nil, explicitSelectionRef: nil) == "שבת", "Missing unit never fabricates a paragraph")
        try expect(ReaderNavigationDisplayPolicy.title(workTitle: "תהילים", navigationUnitTitle: "פרק א", explicitSelectionRef: nil) == "תהילים, פרק א", "Book-specific unit titles are used without forcing Talmud structure")
        let ancestry: [ReaderNavigationDisplayPolicy.Entry] = [
            .init(id: 1, parentID: nil, title: "שבת"),
            .init(id: 2, parentID: 1, title: "פרק ראשון"),
            .init(id: 3, parentID: 2, title: "ג:"),
            .init(id: 4, parentID: 3, title: "פסקה ב")
        ]
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 4, entries: ancestry) == "ג:", "Actual ancestry chooses the nearest daf, not the highest chapter")
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 3, entries: ancestry) == "ג:", "A leaf daf retains its original amud punctuation")
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 2, entries: ancestry) == "פרק ראשון", "A genuine chapter uses its own canonical title")
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 1, entries: ancestry) == nil, "Root work metadata cannot fabricate a section")
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 2, entries: [.init(id: 1, parentID: nil, title: "ספר"), .init(id: 2, parentID: 1, title: "פסקה ב")]) == nil, "A paragraph leaf alone must not become a navigation unit")
        try expect(ReaderNavigationDisplayPolicy.navigationUnitTitle(containing: 4, entries: [.init(id: 1, parentID: nil, title: "ספר"), .init(id: 3, parentID: 1, title: "הלכות שבת"), .init(id: 4, parentID: 3, title: "פסקה א")]) == "הלכות שבת", "Book-specific branching section names need no fixed hierarchy depth")
        checks += try verifyHistoricalMigrationAndProfileColors(in: directory)
        print("PASS: \(checks) workspace persistence/migration/rollback/scene/semantic-location checks")
    }


    /// Starts from JSON emitted by the exact pre-workspace/pre-color Codable sources.
    /// No UIKit/DB hydration is claimed by this portable persistence boundary test.
    @MainActor
    static func verifyHistoricalMigrationAndProfileColors(in directory: URL) throws -> Int {
        var checks = 0
        func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
            guard value() else { throw CheckFailure(message: message) }
            checks += 1
        }
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("fixtures/study-workspace")
        let legacyBytes = try Data(contentsOf: fixtures.appendingPathComponent("legacy-reader-session-v1.json"))
        let legacy = try JSONDecoder().decode(iOSReaderSession.self, from: legacyBytes)
        try expect(legacy.schemaVersion == 1 && legacy.tabs.count == 10, "Decode ten historical session tabs with the real production Codable type")
        try expect(legacy.tabs[6].id == legacy.activeTabId, "Decode the independently fixed historical active tab")
        try expect(legacy.tabs[0].scrollPosition == CGPoint(x: 0, y: 120.5)
            && legacy.tabs[6].selectedRange == NSRange(location: 18, length: 7),
            "Historical JSON must retain actual encoded viewport and selection values")

        let migration = directory.appendingPathComponent("historical-migration")
        try FileManager.default.createDirectory(at: migration, withIntermediateDirectories: true)
        let canonicalURL = migration.appendingPathComponent("ios_reader_session.json")
        try legacyBytes.write(to: canonicalURL, options: .atomic)
        let originalRepair = BackendSessionIntegrityRepair()
        let repaired = originalRepair.repairSessionSnapshot(session: legacy, targetBackend: .otzaria)
        try expect(repaired.foreignTabs.isEmpty && repaired.sanitizedSession.tabs == legacy.tabs,
                   "The original backend repair retains every correctly qualified historical tab")
        let decodedDocuments = repaired.sanitizedSession.tabs.map {
            ReaderDocumentTab(backend: originalRepair.detectTabBackend($0), session: $0)
        }
        let migratedPersistence = StudyWorkspacePersistence(url: migration.appendingPathComponent("StudyWorkspace/workspace-v1.json"))
        let migratedStore = StudyWorkspaceStore(persistence: migratedPersistence, canonicalSessionURL: canonicalURL)
        try migratedStore.attach(scene: "migration-window", legacyTabs: decodedDocuments,
                                 activeID: repaired.sanitizedSession.activeTabId)
        let migratedGroup = migratedStore.selectedGroup(scene: "migration-window")
        try expect(migratedGroup?.tabs.map(\.session) == legacy.tabs,
                   "Production attach preserves all ten decoded tabs, not a hand-built replacement")
        try expect(migratedGroup?.activeTabID == legacy.activeTabId, "Migration preserves the decoded active UUID")
        try expect(migratedStore.snapshot?.profiles.first?.name == "אישי"
            && migratedStore.snapshot?.profiles.first?.color == nil,
            "Migration keeps the original default profile and implicit system color")
        let beforeReattach = migratedStore.snapshot
        try migratedStore.attach(scene: "migration-window", legacyTabs: [], activeID: nil)
        try expect(migratedStore.snapshot == beforeReattach, "Repeated migration cannot replace historical tabs with an empty input")
        try expect(tryData(canonicalURL) == legacyBytes, "Migration never rewrites historical canonical session bytes")
        try expect(tryData(migratedPersistence.url.deletingLastPathComponent().appendingPathComponent("pre-workspace-ios-reader-session.json")) == legacyBytes,
                   "The exact historical JSON bytes are preserved by the original archive")
        let coldMigration = StudyWorkspaceStore(persistence: migratedPersistence, canonicalSessionURL: canonicalURL)
        try expect(coldMigration.snapshot == migratedStore.snapshot, "Every migrated session field survives a cold workspace decode")

        let oldWorkspaceBytes = try Data(contentsOf: fixtures.appendingPathComponent("legacy-study-workspace-v1.json"))
        let legacyWorkspace = try JSONDecoder().decode(StudyWorkspaceSnapshot.self, from: oldWorkspaceBytes)
        try expect(legacyWorkspace.profiles.count == 2 && legacyWorkspace.profiles.allSatisfy { $0.color == nil },
                   "Exact pre-color workspace JSON decodes every absent optional color as nil")
        let colorParent = directory.appendingPathComponent("profile-colors")
        try FileManager.default.createDirectory(at: colorParent, withIntermediateDirectories: true)
        let colorPersistence = StudyWorkspacePersistence(url: colorParent.appendingPathComponent("workspace-v1.json"))
        try oldWorkspaceBytes.write(to: colorPersistence.url, options: .atomic)
        let colors = StudyWorkspaceStore(persistence: colorPersistence, canonicalSessionURL: canonicalURL)
        try expect(colors.snapshot == legacyWorkspace && tryData(colorPersistence.url) == oldWorkspaceBytes,
                   "Loading an existing sidecar neither migrates nor rewrites its bytes")
        let original = colors.snapshot!
        let selected = original.profiles[0]
        let untouched = original.profiles[1]
        try colors.updateProfile(selected.id, name: selected.name, symbol: selected.symbol, color: .blue)
        let changed = colors.snapshot!
        try expect(changed.profiles.first(where: { $0.id == selected.id })?.color == .blue,
                   "An explicit color edit updates the intended existing profile")
        try expect(changed.revision == original.revision + 1, "One editor Save uses one original transaction")
        try expect(changed.profiles.first(where: { $0.id == untouched.id }) == untouched
            && changed.groups == original.groups && changed.scenes == original.scenes,
            "Color edits preserve other profiles, all documents, both scene selections and group membership")
        let serialized = try Data(contentsOf: colorPersistence.url)
        let decoded = try JSONDecoder().decode(StudyWorkspaceSnapshot.self, from: serialized)
        try expect(decoded == changed, "Explicit profile color survives the actual persisted round trip")
        let json = try JSONSerialization.jsonObject(with: serialized) as! [String: Any]
        let serializedProfiles = json["profiles"] as! [[String: Any]]
        try expect(serializedProfiles.first(where: { $0["id"] as? String == selected.id.uuidString })?["color"] as? String == "blue",
                   "The new field is a stable semantic value, not a UIKit archive")
        try expect(serializedProfiles.first(where: { $0["id"] as? String == untouched.id.uuidString })?["color"] == nil,
                   "Untouched legacy profiles still omit the optional key")
        try colors.renameProfile(selected.id, name: "שם חדש", symbol: "book.closed")
        try expect(colors.snapshot?.profiles.first(where: { $0.id == selected.id })?.color == .blue,
                   "The existing rename API must not silently reset an explicitly chosen color")

        let beforeFailure = colors.snapshot
        let beforeFailureBytes = try Data(contentsOf: colorPersistence.url)
        let retained = directory.appendingPathComponent("retained-profile-colors")
        try FileManager.default.moveItem(at: colorParent, to: retained)
        try Data("deliberately unwritable parent".utf8).write(to: colorParent)
        do {
            try colors.updateProfile(selected.id, name: "must not commit", symbol: "star", color: .red)
            throw CheckFailure(message: "Failed color persistence must not report success")
        } catch is CheckFailure { throw CheckFailure(message: "Color I/O failure did not propagate") }
        catch { checks += 1 }
        try expect(colors.snapshot == beforeFailure, "Failed color Save rolls back name, symbol and color together")
        try FileManager.default.removeItem(at: colorParent)
        try FileManager.default.moveItem(at: retained, to: colorParent)
        try expect(tryData(colorPersistence.url) == beforeFailureBytes, "Failed color Save preserves every durable byte")
        try colors.updateProfile(selected.id, name: selected.name, symbol: selected.symbol, color: nil)
        let resetBytes = try Data(contentsOf: colorPersistence.url)
        let resetJSON = try JSONSerialization.jsonObject(with: resetBytes) as! [String: Any]
        let resetProfiles = resetJSON["profiles"] as! [[String: Any]]
        try expect(resetProfiles.allSatisfy { $0["color"] == nil },
                   "Explicit default selection removes the optional key and restores legacy serialization")
        let resetSnapshot = try JSONDecoder().decode(StudyWorkspaceSnapshot.self, from: resetBytes)
        try expect(resetSnapshot.version == 1,
                   "Profile colors do not change or migrate the workspace schema")
        let newID = try colors.addProfile(name: "צבע חדש", symbol: "star", color: .purple)
        try expect(colors.snapshot?.profiles.first(where: { $0.id == newID })?.color == .purple,
                   "The original create flow can atomically persist an explicit profile color")
        let defaultID = try colors.addProfile(name: "ברירת מחדל", symbol: "star")
        try expect(colors.snapshot?.profiles.first(where: { $0.id == defaultID })?.color == nil,
                   "Existing callers preserve the original default appearance")
        try expect(tryData(canonicalURL) == legacyBytes, "Profile creation and edits never rewrite the historical reader session")
        return checks
    }

    static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    static func JSONEncoderData(_ value: StudyWorkspaceSnapshot) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(value)
    }
}
