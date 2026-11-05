import Foundation
import Observation

@MainActor @Observable
final class StudyWorkspaceStore {
    static let shared = StudyWorkspaceStore(persistence: StudyWorkspacePersistence(
        url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChavrusaText/StudyWorkspace/workspace-v1.json")))

    static func forCurrentProcess() -> StudyWorkspaceStore {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-studyWorkspaceTestingNamespace"), args.indices.contains(index + 1),
           UUID(uuidString: args[index + 1]) != nil {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ChavrusaText/StudyWorkspace/UITests/\(args[index + 1]).json")
            return StudyWorkspaceStore(persistence: .init(url: url))
        }
        #endif
        return .shared
    }

    private(set) var snapshot: StudyWorkspaceSnapshot?
    private(set) var loadError: String?
    private let persistence: StudyWorkspacePersistence
    private let canonicalSessionURL: URL

    init(persistence: StudyWorkspacePersistence, canonicalSessionURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Maktabah/States/ios_reader_session.json")) {
        self.persistence = persistence
        self.canonicalSessionURL = canonicalSessionURL
        do { snapshot = try persistence.load() }
        catch { loadError = error.localizedDescription }
    }

    /// Called only by the enabled host, after canonical session restore has finished.
    func attach(scene: String, legacyTabs: [ReaderDocumentTab], activeID: UUID?) throws {
        guard loadError == nil else { throw StudyWorkspaceError.invalidMembership }
        try persistence.archiveBeforeMigration(canonicalSessionURL: canonicalSessionURL)
        if snapshot == nil {
            let profile = StudyProfile(id: UUID(), name: "אישי", symbol: "person.crop.circle", order: 0)
            let group = StudyTabGroup(id: UUID(), profileID: profile.id, name: "כל הכרטיסיות", order: 0,
                                      tabs: legacyTabs, activeTabID: activeID)
            var initial = StudyWorkspaceSnapshot()
            initial.profiles = [profile]
            initial.groups = [group]
            initial.migratedLegacySession = true
            initial.scenes[scene] = .init(profileID: profile.id, groupID: group.id)
            initial.lastActiveSceneID = scene
            try persistence.save(initial)
            snapshot = initial
        } else if snapshot?.scenes[scene] == nil {
            try transaction { value in
                let previous = value.lastActiveSceneID.flatMap { value.scenes[$0] }
                    ?? (value.scenes.count == 1 ? value.scenes.values.first : nil)
                if let previous {
                    // Preserve an older UUID-based scene's selected group,
                    // including an empty group, without touching its records.
                    value.scenes[scene] = previous
                } else {
                    guard let group = value.groups.sorted(by: { $0.order < $1.order }).first else {
                        throw StudyWorkspaceError.invalidMembership
                    }
                    value.scenes[scene] = .init(profileID: group.profileID, groupID: group.id)
                }
                value.lastActiveSceneID = scene
            }
        }
    }

    func transaction(_ mutate: (inout StudyWorkspaceSnapshot) throws -> Void) throws {
        guard var candidate = snapshot else { throw StudyWorkspaceError.invalidMembership }
        try mutate(&candidate)
        candidate.revision += 1
        try candidate.validate()
        try persistence.save(candidate)
        snapshot = candidate
    }

    func selectedGroup(scene: String) -> StudyTabGroup? {
        guard let snapshot, let id = snapshot.scenes[scene]?.groupID else { return nil }
        return snapshot.groups.first { $0.id == id }
    }

    func saveTabs(_ tabs: [ReaderDocumentTab], activeID: UUID?, groupID: UUID) throws {
        try transaction { value in
            guard let index = value.groups.firstIndex(where: { $0.id == groupID }) else {
                throw StudyWorkspaceError.invalidMembership
            }
            value.groups[index].tabs = tabs
            value.groups[index].activeTabID = activeID.flatMap { id in tabs.contains { $0.id == id } ? id : nil }
        }
    }

    @discardableResult
    func addProfile(name: String, symbol: String) throws -> UUID {
        let id = UUID()
        try transaction { value in
            value.profiles.append(.init(id: id, name: name, symbol: symbol, order: value.profiles.count))
            value.groups.append(.init(id: UUID(), profileID: id, name: "כל הכרטיסיות", order: 0, tabs: [], activeTabID: nil))
        }
        return id
    }

    @discardableResult
    func addGroup(profileID: UUID, name: String, tabs: [ReaderDocumentTab] = [], activeID: UUID? = nil) throws -> UUID {
        let id = UUID()
        try transaction { value in
            guard value.profiles.contains(where: { $0.id == profileID }) else { throw StudyWorkspaceError.invalidMembership }
            value.groups.append(.init(id: id, profileID: profileID, name: name,
                                      order: value.groups.filter { $0.profileID == profileID }.count,
                                      tabs: tabs, activeTabID: activeID))
        }
        return id
    }

    func renameProfile(_ id: UUID, name: String, symbol: String) throws {
        try transaction { value in
            guard let index = value.profiles.firstIndex(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
            value.profiles[index].name = name
            value.profiles[index].symbol = symbol
        }
    }

    func renameGroup(_ id: UUID, name: String) throws {
        try transaction { value in
            guard let index = value.groups.firstIndex(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
            value.groups[index].name = name
        }
    }

    func moveGroup(_ id: UUID, to profileID: UUID) throws {
        try transaction { value in
            guard let index = value.groups.firstIndex(where: { $0.id == id }),
                  value.profiles.contains(where: { $0.id == profileID }) else { throw StudyWorkspaceError.invalidMembership }
            let oldProfileID = value.groups[index].profileID
            guard oldProfileID != profileID else { return }
            value.groups[index].profileID = profileID
            value.groups[index].order = value.groups.filter { $0.profileID == profileID && $0.id != id }.count
            if !value.groups.contains(where: { $0.profileID == oldProfileID }) {
                value.groups.append(.init(id: UUID(), profileID: oldProfileID, name: "כל הכרטיסיות", order: 0, tabs: [], activeTabID: nil))
            }
            for scene in Array(value.scenes.keys) where value.scenes[scene]?.groupID == id {
                value.scenes[scene]?.profileID = profileID
            }
        }
    }

    func orderGroups(_ ids: [UUID], profileID: UUID) throws {
        try transaction { value in
            let currentIDs = Set(value.groups.filter { $0.profileID == profileID }.map(\.id))
            guard Set(ids) == currentIDs, Set(ids).count == ids.count else { throw StudyWorkspaceError.invalidMembership }
            for (order, id) in ids.enumerated() {
                if let index = value.groups.firstIndex(where: { $0.id == id }) { value.groups[index].order = order }
            }
        }
    }

    func deleteGroup(_ id: UUID) throws {
        try transaction { value in
            guard let group = value.groups.first(where: { $0.id == id }),
                  let replacement = value.groups.first(where: { $0.profileID == group.profileID && $0.id != id })
            else { throw StudyWorkspaceError.lastGroup }
            value.groups.removeAll { $0.id == id }
            for scene in Array(value.scenes.keys) where value.scenes[scene]?.groupID == id {
                value.scenes[scene] = .init(profileID: replacement.profileID, groupID: replacement.id)
            }
        }
    }

    func deleteProfile(_ id: UUID) throws {
        try transaction { value in
            guard let profile = value.profiles.first(where: { $0.id != id }),
                  let group = value.groups.first(where: { $0.profileID == profile.id }) else { throw StudyWorkspaceError.lastProfile }
            value.profiles.removeAll { $0.id == id }
            value.groups.removeAll { $0.profileID == id }
            for scene in Array(value.scenes.keys) where value.scenes[scene]?.profileID == id {
                value.scenes[scene] = .init(profileID: profile.id, groupID: group.id)
            }
        }
    }
}
