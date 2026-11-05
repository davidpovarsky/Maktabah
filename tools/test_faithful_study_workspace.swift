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
        print("PASS: \(checks) workspace persistence/migration/rollback/scene/semantic-location checks")
    }

    static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }
    static func JSONEncoderData(_ value: StudyWorkspaceSnapshot) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(value)
    }
}
