import Foundation
import Observation

/// Passive publication metadata for an original owner retaining an inactive
/// group's order/documents. The scene mapping intentionally omits those fields.
/// This observer cannot veto, mutate or authorize a Store transaction.
@MainActor protocol StudyWorkspaceSnapshotObserver: AnyObject {
    func workspaceSnapshotWillPublish(before: StudyWorkspaceSnapshot?, after: StudyWorkspaceSnapshot)
    func workspaceSnapshotDidPublish(_ snapshot: StudyWorkspaceSnapshot)
    func workspaceSnapshotOwnerDidRetire()
}

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
    private final class WeakMappingSource {
        weak var value: StudyWorkspaceMappingSource?
        init(_ value: StudyWorkspaceMappingSource) { self.value = value }
    }
    @ObservationIgnored private var mappingSources: [String: WeakMappingSource] = [:]
    @ObservationIgnored private var isMutating = false
    @ObservationIgnored private var isPublishingMapping = false
    private final class WeakSnapshotObserver {
        weak var value: (any StudyWorkspaceSnapshotObserver)?
        init(_ value: any StudyWorkspaceSnapshotObserver) { self.value = value }
    }
    @ObservationIgnored private var snapshotObservers: [UUID: WeakSnapshotObserver] = [:]

    /// Install once for the real adapter lifetime, not once per publication.
    func observeSnapshotPublication(_ observer: any StudyWorkspaceSnapshotObserver) -> UUID {
        snapshotObservers = snapshotObservers.filter { $0.value.value != nil && $0.value.value !== observer }
        let token = UUID()
        snapshotObservers[token] = .init(observer)
        return token
    }
    func removeSnapshotPublicationObserver(_ token: UUID) { snapshotObservers.removeValue(forKey: token) }

    /// The persisted revision includes checkpoints. Consumers must retain this
    /// fixed scene source instead of observing the broad snapshot/revision.
    func mappingSource(scene: String) -> StudyWorkspaceMappingSource {
        mappingSources = mappingSources.filter { $0.value.value != nil }
        if let source = mappingSources[scene]?.value { return source }
        let source = StudyWorkspaceMappingSource(available: !isPublishingMapping && loadError == nil
            && StudyWorkspaceMappingPolicy.workspace(snapshot, scene: scene) != nil)
        mappingSources[scene] = .init(source)
        return source
    }

    func mappingObservation(scene: String) -> StudyWorkspaceMappingObservation? {
        let source = mappingSource(scene: scene)
        guard loadError == nil,
              let epoch = source.event.epoch,
              let projection = StudyWorkspaceMappingPolicy.workspace(snapshot, scene: scene) else { return nil }
        return .init(source: source, owner: ObjectIdentifier(self), scene: scene, epoch: epoch,
            coverage: .workspaceStoreOnly, projection: projection)
    }

    isolated deinit {
        for source in mappingSources.values { source.value?.retire() }
        for observer in snapshotObservers.values { observer.value?.workspaceSnapshotOwnerDidRetire() }
    }

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
            guard !isMutating else { throw StudyWorkspaceError.invalidMembership }
            isMutating = true
            defer { isMutating = false }
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
            publishSnapshot(initial)
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
        guard !isMutating, var candidate = snapshot else { throw StudyWorkspaceError.invalidMembership }
        isMutating = true
        defer { isMutating = false }
        try mutate(&candidate)
        guard candidate.revision < UInt64.max else { throw StudyWorkspaceError.invalidMembership }
        candidate.revision += 1
        try candidate.validate()
        try persistence.save(candidate)
        publishSnapshot(candidate)
    }

    /// All throwing validation/persistence finished before this synchronous
    /// fence. No observer can see the new snapshot with an old live admission.
    private func publishSnapshot(_ candidate: StudyWorkspaceSnapshot) {
        isPublishingMapping = true
        for token in Array(snapshotObservers.keys) {
            guard let observer = snapshotObservers[token]?.value else {
                snapshotObservers.removeValue(forKey: token); continue
            }
            observer.workspaceSnapshotWillPublish(before: snapshot, after: candidate)
        }
        mappingSources = mappingSources.filter { $0.value.value != nil }
        let beforeSources = mappingSources.compactMapValues(\.value)
        for (scene, source) in beforeSources {
            source.beginChange(StudyWorkspaceMappingPolicy.changes(
                from: StudyWorkspaceMappingPolicy.workspace(snapshot, scene: scene),
                to: StudyWorkspaceMappingPolicy.workspace(candidate, scene: scene)))
        }
        snapshot = candidate
        isPublishingMapping = false
        for (scene, source) in mappingSources.compactMapValues(\.value) {
            source.finishChange(available: StudyWorkspaceMappingPolicy.workspace(candidate, scene: scene) != nil)
        }
        for token in Array(snapshotObservers.keys) {
            snapshotObservers[token]?.value?.workspaceSnapshotDidPublish(candidate)
        }
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

    func reorderDocument(_ id: UUID, to destination: Int, groupID: UUID) throws {
        try transaction { value in
            guard let group = value.groups.firstIndex(where: { $0.id == groupID }),
                  let source = value.groups[group].tabs.firstIndex(where: { $0.id == id }),
                  value.groups[group].tabs.indices.contains(destination) else {
                throw StudyWorkspaceError.invalidMembership
            }
            let document = value.groups[group].tabs.remove(at: source)
            value.groups[group].tabs.insert(document, at: destination)
        }
    }

    @discardableResult
    func addProfile(name: String, symbol: String, color: StudyProfileColor? = nil) throws -> UUID {
        let id = UUID()
        try transaction { value in
            value.profiles.append(.init(id: id, name: name, symbol: symbol, order: value.profiles.count, color: color))
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
        guard let profile = snapshot?.profiles.first(where: { $0.id == id }) else {
            throw StudyWorkspaceError.invalidMembership
        }
        try updateProfile(id, name: name, symbol: symbol, color: profile.color)
    }

    /// One existing transaction commits the complete editor choice or none of it.
    func updateProfile(_ id: UUID, name: String, symbol: String, color: StudyProfileColor?) throws {
        try transaction { value in
            guard let index = value.profiles.firstIndex(where: { $0.id == id }) else { throw StudyWorkspaceError.invalidMembership }
            value.profiles[index].name = name
            value.profiles[index].symbol = symbol
            value.profiles[index].color = color
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
