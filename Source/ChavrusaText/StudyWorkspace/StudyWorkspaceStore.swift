//
//  StudyWorkspaceStore.swift
//  Maktabah
//
//  Downstream-owned authoritative store for Study Profiles, Tab Groups, and Document Tabs.
//

import Foundation
import Observation

/// Authoritative `@MainActor` store for ChavrusaText's 3-layer Study Workspace:
/// 1. `StudyProfile` (e.g., "אישי", "עיון", "דף היומי", "הלכה")
/// 2. `StudyTabGroup` (named sets of tabs within a profile)
/// 3. `ReaderDocumentTab` (independent document tab instances with unique `UUID`s)
@MainActor
@Observable
public final class StudyWorkspaceStore {
    private static var _shared: StudyWorkspaceStore?

    /// Indicates whether the shared `StudyWorkspaceStore` singleton has been instantiated.
    /// When `studyWorkspaceEnabled` and `duckTabStripEnabled` are `false`, this remains `false`
    /// so zero eager initialization, legacy session migration, or disk writes occur.
    public static var isSharedInstanceInitialized: Bool {
        _shared != nil
    }

    public static var shared: StudyWorkspaceStore {
        if let existing = _shared {
            return existing
        }
        let created = StudyWorkspaceStore()
        _shared = created
        return created
    }

    /// Resets the shared singleton reference for isolated unit testing.
    public static func resetSharedForTesting() {
        _shared = nil
    }

    public private(set) var profiles: [StudyProfile]
    public private(set) var groups: [StudyTabGroup]
    public private(set) var tabsByID: [UUID: ReaderDocumentTab]
    public private(set) var lastActiveProfileID: UUID
    public private(set) var lastActiveGroupID: UUID
    public private(set) var sceneStatesByID: [String: StudySceneSelectionState]
    public private(set) var migratedFromLegacySession: Bool
    public private(set) var didRecoverFromBackupOnLaunch: Bool = false

    private let persistence: StudyWorkspacePersistence

    public init(
        persistence: StudyWorkspacePersistence = .shared,
        legacySessionProvider: (() -> iOSReaderSession?)? = nil,
        fallbackBackend: BackendID = .otzaria
    ) {
        self.persistence = persistence

        let (loadedSnapshot, recovered) = persistence.loadSnapshotWithRecovery()
        self.didRecoverFromBackupOnLaunch = recovered

        let resolvedLegacySession: iOSReaderSession?
        if let legacySessionProvider {
            resolvedLegacySession = legacySessionProvider()
        } else if loadedSnapshot == nil {
            resolvedLegacySession = iOSReaderSessionManager.shared.loadSession()
        } else {
            resolvedLegacySession = nil
        }

        let initialSnapshot = StudyWorkspaceMigration.migrateIfNeeded(
            existingSnapshot: loadedSnapshot,
            legacySession: resolvedLegacySession,
            fallbackBackend: fallbackBackend
        )

        self.profiles = initialSnapshot.profiles.sorted { $0.sortOrder < $1.sortOrder }
        self.groups = initialSnapshot.groups.sorted { $0.sortOrder < $1.sortOrder }
        self.tabsByID = initialSnapshot.tabsByID
        self.lastActiveProfileID = initialSnapshot.lastActiveProfileID
        self.lastActiveGroupID = initialSnapshot.lastActiveGroupID
        self.sceneStatesByID = initialSnapshot.sceneStatesByID
        self.migratedFromLegacySession = initialSnapshot.migratedFromLegacySession
    }

    // MARK: - Queries

    public var defaultProfile: StudyProfile {
        profiles.first(where: \.isDefault)
            ?? profiles.first(where: { $0.id == StudyProfile.defaultProfileID })
            ?? profiles.first
            ?? StudyProfile.makeDefault()
    }

    public var activeProfile: StudyProfile {
        profile(for: lastActiveProfileID) ?? defaultProfile
    }

    public var activeGroup: StudyTabGroup {
        group(for: lastActiveGroupID)
            ?? groups(for: activeProfile.id).first
            ?? defaultGroup(for: activeProfile.id)
    }

    public var activeTabs: [ReaderDocumentTab] {
        tabs(in: activeGroup.id)
    }

    public var activeTab: ReaderDocumentTab? {
        guard let activeTabID = activeGroup.activeTabID else {
            return activeTabs.first
        }
        return tabsByID[activeTabID] ?? activeTabs.first
    }

    public func profile(for id: UUID) -> StudyProfile? {
        profiles.first { $0.id == id }
    }

    public func group(for id: UUID) -> StudyTabGroup? {
        groups.first { $0.id == id }
    }

    public func groups(for profileID: UUID) -> [StudyTabGroup] {
        groups
            .filter { $0.profileID == profileID }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
    }

    public func defaultGroup(for profileID: UUID) -> StudyTabGroup {
        if let existing = groups(for: profileID).first {
            return existing
        }
        let created = StudyTabGroup.makeDefault(profileID: profileID)
        groups.append(created)
        scheduleSave()
        return created
    }

    public func tab(for id: UUID) -> ReaderDocumentTab? {
        tabsByID[id]
    }

    public func tabs(in groupID: UUID) -> [ReaderDocumentTab] {
        guard let group = group(for: groupID) else { return [] }
        return group.tabIDs.compactMap { tabsByID[$0] }
    }

    // MARK: - Scene Coordination

    public func sceneSelection(for sceneID: String) -> StudySceneSelectionState {
        if let existing = sceneStatesByID[sceneID],
           profile(for: existing.activeProfileID) != nil,
           let grp = group(for: existing.activeGroupID),
           grp.profileID == existing.activeProfileID {
            return existing
        }
        let state = StudySceneSelectionState(
            sceneID: sceneID,
            activeProfileID: activeProfile.id,
            activeGroupID: activeGroup.id,
            isOverviewPresented: false
        )
        sceneStatesByID[sceneID] = state
        return state
    }

    public func updateSceneSelection(_ state: StudySceneSelectionState) {
        sceneStatesByID[state.sceneID] = state
        if profile(for: state.activeProfileID) != nil {
            lastActiveProfileID = state.activeProfileID
        }
        if let grp = group(for: state.activeGroupID), grp.profileID == lastActiveProfileID {
            lastActiveGroupID = grp.id
        }
        scheduleSave()
    }

    // MARK: - Profile Operations

    @discardableResult
    public func createProfile(
        name: String,
        icon: String = "books.vertical",
        colorName: String = "accentBlue",
        initialGroupName: String = StudyTabGroup.defaultGroupName,
        activateImmediately: Bool = true
    ) -> StudyProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "פרופיל לימוד" : trimmed
        let nextOrder = (profiles.map(\.sortOrder).max() ?? -1) + 1
        let now = Date()
        let newProfile = StudyProfile(
            name: resolvedName,
            icon: icon,
            colorName: colorName,
            sortOrder: nextOrder,
            createdAt: now,
            updatedAt: now,
            isDefault: false
        )
        profiles.append(newProfile)

        let initialGroup = StudyTabGroup(
            profileID: newProfile.id,
            name: initialGroupName,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now
        )
        groups.append(initialGroup)

        if activateImmediately {
            lastActiveProfileID = newProfile.id
            lastActiveGroupID = initialGroup.id
            normalizeSceneSelections()
        }

        scheduleSave()
        return newProfile
    }

    public func updateProfile(
        _ profileID: UUID,
        name: String? = nil,
        icon: String? = nil,
        colorName: String? = nil
    ) {
        guard let idx = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                profiles[idx].name = trimmed
            }
        }
        if let icon, !icon.isEmpty {
            profiles[idx].icon = icon
        }
        if let colorName, !colorName.isEmpty {
            profiles[idx].colorName = colorName
        }
        profiles[idx].updatedAt = Date()
        scheduleSave()
    }

    public func selectProfile(_ profileID: UUID) {
        guard let target = profile(for: profileID) else { return }
        lastActiveProfileID = target.id
        let targetGroups = groups(for: target.id)
        if !targetGroups.contains(where: { $0.id == lastActiveGroupID }) {
            lastActiveGroupID = targetGroups.first?.id ?? defaultGroup(for: target.id).id
        }
        normalizeSceneSelections()
        scheduleSave()
    }

    /// Deletes a non-default profile and safely falls back to the default `"אישי"` profile.
    /// Default profile `"אישי"` cannot be deleted.
    @discardableResult
    public func deleteProfile(_ profileID: UUID) -> Bool {
        guard let target = profile(for: profileID), !target.isDefault, target.id != StudyProfile.defaultProfileID else {
            return false
        }

        let removedGroups = groups.filter { $0.profileID == profileID }
        let removedTabIDs = Set(removedGroups.flatMap(\.tabIDs))
        groups.removeAll { $0.profileID == profileID }
        profiles.removeAll { $0.id == profileID }

        // Remove tabs that are no longer referenced by any remaining group
        let remainingReferencedTabIDs = Set(groups.flatMap(\.tabIDs))
        for tabID in removedTabIDs where !remainingReferencedTabIDs.contains(tabID) {
            tabsByID.removeValue(forKey: tabID)
        }

        if lastActiveProfileID == profileID {
            let fallback = defaultProfile
            lastActiveProfileID = fallback.id
            lastActiveGroupID = groups(for: fallback.id).first?.id ?? defaultGroup(for: fallback.id).id
        }
        normalizeSceneSelections()
        scheduleSave()
        return true
    }

    // MARK: - Tab Group Operations

    @discardableResult
    public func createGroup(
        name: String,
        inProfile profileID: UUID? = nil,
        fromCurrentTabsIn sourceGroupID: UUID? = nil,
        activateImmediately: Bool = true
    ) -> StudyTabGroup {
        let targetProfileID = profileID ?? activeProfile.id
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? "קבוצת לימוד" : trimmed
        let existingGroups = groups(for: targetProfileID)
        let nextOrder = (existingGroups.map(\.sortOrder).max() ?? -1) + 1
        let now = Date()

        var copiedTabIDs: [UUID] = []
        var activeCopiedTabID: UUID?

        if let sourceGroupID, let sourceGroup = group(for: sourceGroupID) {
            for sourceTabID in sourceGroup.tabIDs {
                guard let sourceTab = tabsByID[sourceTabID] else { continue }
                let duplicatedTab = sourceTab.duplicated(now: now)
                tabsByID[duplicatedTab.id] = duplicatedTab
                copiedTabIDs.append(duplicatedTab.id)
                if sourceGroup.activeTabID == sourceTabID {
                    activeCopiedTabID = duplicatedTab.id
                }
            }
        }

        let newGroup = StudyTabGroup(
            profileID: targetProfileID,
            name: resolvedName,
            sortOrder: nextOrder,
            createdAt: now,
            updatedAt: now,
            tabIDs: copiedTabIDs,
            activeTabID: activeCopiedTabID ?? copiedTabIDs.first
        )
        groups.append(newGroup)

        if activateImmediately {
            lastActiveProfileID = targetProfileID
            lastActiveGroupID = newGroup.id
            normalizeSceneSelections()
        }

        scheduleSave()
        return newGroup
    }

    public func renameGroup(_ groupID: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].name = trimmed
        groups[idx].updatedAt = Date()
        scheduleSave()
    }

    public func togglePinGroup(_ groupID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].isPinned.toggle()
        groups[idx].updatedAt = Date()
        scheduleSave()
    }

    public func selectGroup(_ groupID: UUID) {
        guard let target = group(for: groupID) else { return }
        lastActiveProfileID = target.profileID
        lastActiveGroupID = target.id
        normalizeSceneSelections()
        scheduleSave()
    }

    public func moveGroup(_ groupID: UUID, toProfile targetProfileID: UUID) {
        guard profile(for: targetProfileID) != nil,
              let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let oldProfileID = groups[idx].profileID
        guard oldProfileID != targetProfileID else { return }

        let nextOrder = (groups(for: targetProfileID).map(\.sortOrder).max() ?? -1) + 1
        groups[idx].profileID = targetProfileID
        groups[idx].sortOrder = nextOrder
        groups[idx].updatedAt = Date()

        // Ensure old profile still has at least one group
        if groups(for: oldProfileID).isEmpty {
            let fallback = StudyTabGroup.makeDefault(profileID: oldProfileID)
            groups.append(fallback)
            if lastActiveProfileID == oldProfileID {
                lastActiveGroupID = fallback.id
            }
        }

        normalizeSceneSelections()
        scheduleSave()
    }

    public func reorderGroups(inProfile profileID: UUID, orderedGroupIDs: [UUID]) {
        for (order, groupID) in orderedGroupIDs.enumerated() {
            if let idx = groups.firstIndex(where: { $0.id == groupID && $0.profileID == profileID }) {
                groups[idx].sortOrder = order
                groups[idx].updatedAt = Date()
            }
        }
        scheduleSave()
    }

    /// Deletes a tab group and ensures its parent profile always retains at least one valid group.
    @discardableResult
    public func deleteGroup(_ groupID: UUID) -> StudyTabGroup {
        guard let target = group(for: groupID) else {
            return activeGroup
        }
        let profileID = target.profileID
        let removedTabIDs = Set(target.tabIDs)
        groups.removeAll { $0.id == groupID }

        let remainingReferenced = Set(groups.flatMap(\.tabIDs))
        for tabID in removedTabIDs where !remainingReferenced.contains(tabID) {
            tabsByID.removeValue(forKey: tabID)
        }

        let remainingInProfile = groups(for: profileID)
        let fallbackGroup: StudyTabGroup
        if let first = remainingInProfile.first {
            fallbackGroup = first
        } else {
            let created = StudyTabGroup.makeDefault(profileID: profileID)
            groups.append(created)
            fallbackGroup = created
        }

        if lastActiveGroupID == groupID {
            lastActiveGroupID = fallbackGroup.id
        }
        normalizeSceneSelections()
        scheduleSave()
        return fallbackGroup
    }

    // MARK: - Document Tab Operations

    /// Appends or inserts a document tab into the specified group (defaults to `activeGroup.id`) and optionally activates it.
    @discardableResult
    public func addTab(
        _ tab: ReaderDocumentTab,
        toGroup groupID: UUID? = nil,
        at index: Int? = nil,
        activate: Bool = true
    ) -> ReaderDocumentTab {
        let targetGroupID = groupID ?? activeGroup.id
        guard let groupIdx = groups.firstIndex(where: { $0.id == targetGroupID }) else {
            return tab
        }

        tabsByID[tab.id] = tab
        if !groups[groupIdx].tabIDs.contains(tab.id) {
            if let index, index >= 0, index <= groups[groupIdx].tabIDs.count {
                groups[groupIdx].tabIDs.insert(tab.id, at: index)
            } else {
                groups[groupIdx].tabIDs.append(tab.id)
            }
        }
        if activate || groups[groupIdx].activeTabID == nil {
            groups[groupIdx].activeTabID = tab.id
        }
        groups[groupIdx].updatedAt = Date()
        scheduleSave()
        return tab
    }

    /// Updates an existing `ReaderDocumentTab` in place without mutating other tabs of the same book.
    public func updateTab(_ tabID: UUID, mutate: (inout ReaderDocumentTab) -> Void) {
        guard var existing = tabsByID[tabID] else { return }
        mutate(&existing)
        existing.updatedAt = Date()
        tabsByID[tabID] = existing
        scheduleSave()
    }

    public func setActiveTab(_ tabID: UUID, inGroup groupID: UUID? = nil) {
        let targetGroupID = groupID ?? activeGroup.id
        guard let groupIdx = groups.firstIndex(where: { $0.id == targetGroupID }),
              groups[groupIdx].tabIDs.contains(tabID) else { return }
        groups[groupIdx].activeTabID = tabID
        groups[groupIdx].updatedAt = Date()
        scheduleSave()
    }

    /// Reorders tabs within a group (used by drag-and-drop in the DuckDuckGo-style tab strip).
    public func reorderTabs(inGroup groupID: UUID? = nil, from sourceIndex: Int, to destinationIndex: Int) {
        let targetGroupID = groupID ?? activeGroup.id
        guard let groupIdx = groups.firstIndex(where: { $0.id == targetGroupID }) else { return }
        var ids = groups[groupIdx].tabIDs
        guard ids.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex < ids.count,
              sourceIndex != destinationIndex else { return }
        let moved = ids.remove(at: sourceIndex)
        ids.insert(moved, at: destinationIndex)
        groups[groupIdx].tabIDs = ids
        groups[groupIdx].updatedAt = Date()
        scheduleSave()
    }

    /// Closes a tab in the specified group and selects the nearest remaining neighbor.
    public func closeTab(_ tabID: UUID, inGroup groupID: UUID? = nil) {
        let targetGroupID = groupID ?? activeGroup.id
        guard let groupIdx = groups.firstIndex(where: { $0.id == targetGroupID }),
              let removedIndex = groups[groupIdx].tabIDs.firstIndex(of: tabID) else { return }

        groups[groupIdx].tabIDs.remove(at: removedIndex)

        if groups[groupIdx].activeTabID == tabID {
            let remaining = groups[groupIdx].tabIDs
            if remaining.isEmpty {
                groups[groupIdx].activeTabID = nil
            } else {
                let nextIndex = min(removedIndex, remaining.count - 1)
                groups[groupIdx].activeTabID = remaining[nextIndex]
            }
        }
        groups[groupIdx].updatedAt = Date()

        // Remove from dictionary if no other group references this tab UUID
        let stillReferenced = groups.contains { $0.tabIDs.contains(tabID) }
        if !stillReferenced {
            tabsByID.removeValue(forKey: tabID)
        }
        scheduleSave()
    }

    /// Closes all tabs in the group except `keepTabID`.
    public func closeOtherTabs(keeping keepTabID: UUID, inGroup groupID: UUID? = nil) {
        let targetGroupID = groupID ?? activeGroup.id
        guard let groupIdx = groups.firstIndex(where: { $0.id == targetGroupID }),
              groups[groupIdx].tabIDs.contains(keepTabID) else { return }

        let removedIDs = groups[groupIdx].tabIDs.filter { $0 != keepTabID }
        groups[groupIdx].tabIDs = [keepTabID]
        groups[groupIdx].activeTabID = keepTabID
        groups[groupIdx].updatedAt = Date()

        let stillReferenced = Set(groups.flatMap(\.tabIDs))
        for id in removedIDs where !stillReferenced.contains(id) {
            tabsByID.removeValue(forKey: id)
        }
        scheduleSave()
    }

    /// Moves a tab from `sourceGroupID` to `destinationGroupID` (preserving its `UUID` and state).
    public func moveTab(
        _ tabID: UUID,
        fromGroup sourceGroupID: UUID,
        toGroup destinationGroupID: UUID,
        activateInDestination: Bool = true
    ) {
        guard sourceGroupID != destinationGroupID,
              tabsByID[tabID] != nil,
              let srcIdx = groups.firstIndex(where: { $0.id == sourceGroupID }),
              let dstIdx = groups.firstIndex(where: { $0.id == destinationGroupID }),
              let pos = groups[srcIdx].tabIDs.firstIndex(of: tabID) else { return }

        groups[srcIdx].tabIDs.remove(at: pos)
        if groups[srcIdx].activeTabID == tabID {
            let remaining = groups[srcIdx].tabIDs
            groups[srcIdx].activeTabID = remaining.isEmpty ? nil : remaining[min(pos, remaining.count - 1)]
        }
        groups[srcIdx].updatedAt = Date()

        if !groups[dstIdx].tabIDs.contains(tabID) {
            groups[dstIdx].tabIDs.append(tabID)
        }
        if activateInDestination || groups[dstIdx].activeTabID == nil {
            groups[dstIdx].activeTabID = tabID
        }
        groups[dstIdx].updatedAt = Date()
        scheduleSave()
    }

    /// Copies a tab into `destinationGroupID` with a new independent `UUID` so both groups can evolve independently.
    @discardableResult
    public func copyTab(
        _ tabID: UUID,
        toGroup destinationGroupID: UUID,
        activateInDestination: Bool = true
    ) -> ReaderDocumentTab? {
        guard let original = tabsByID[tabID],
              let dstIdx = groups.firstIndex(where: { $0.id == destinationGroupID }) else { return nil }

        let copy = original.duplicated()
        tabsByID[copy.id] = copy
        groups[dstIdx].tabIDs.append(copy.id)
        if activateInDestination || groups[dstIdx].activeTabID == nil {
            groups[dstIdx].activeTabID = copy.id
        }
        groups[dstIdx].updatedAt = Date()
        scheduleSave()
        return copy
    }

    /// Marks a tab dormant/unavailable instead of deleting it when its book or backend is temporarily missing.
    public func setTabDormantUnavailable(_ tabID: UUID, isDormant: Bool) {
        updateTab(tabID) { tab in
            tab.isDormantUnavailable = isDormant
        }
    }

    // MARK: - Persistence Helpers

    public func currentSnapshot() -> StudyWorkspaceSnapshot {
        StudyWorkspaceSnapshot(
            schemaVersion: StudyWorkspaceSnapshot.currentSchemaVersion,
            savedAt: Date(),
            migratedFromLegacySession: migratedFromLegacySession,
            lastActiveProfileID: lastActiveProfileID,
            lastActiveGroupID: lastActiveGroupID,
            profiles: profiles,
            groups: groups,
            tabsByID: tabsByID,
            sceneStatesByID: sceneStatesByID
        )
    }

    public func scheduleSave() {
        persistence.scheduleSave(currentSnapshot())
    }

    public func saveImmediately() throws {
        try persistence.saveImmediately(currentSnapshot())
    }

    private func normalizeSceneSelections() {
        for (sceneID, var state) in sceneStatesByID {
            if profile(for: state.activeProfileID) == nil {
                state.activeProfileID = lastActiveProfileID
            }
            if let grp = group(for: state.activeGroupID), grp.profileID == state.activeProfileID {
                // valid
            } else {
                state.activeGroupID = groups(for: state.activeProfileID).first?.id ?? lastActiveGroupID
            }
            sceneStatesByID[sceneID] = state
        }
    }
}
