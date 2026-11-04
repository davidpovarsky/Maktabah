//
//  StudyWorkspaceSceneCoordinator.swift
//  Maktabah
//
//  Downstream-owned per-window/scene coordinator for active StudyProfile and StudyTabGroup selection.
//

import Foundation
import Observation

/// Coordinates per-scene/window active `StudyProfile`, `StudyTabGroup`, and `StudyGroupsOverview` presentation
/// while synchronizing with the shared `StudyWorkspaceStore`.
/// Each iPad window/scene owns a distinct `sceneID` and a scene-isolated `StudyWorkspaceNavigationAdapter`.
@MainActor
@Observable
final class StudyWorkspaceSceneCoordinator {
    let sceneID: String
    private(set) var activeProfileID: UUID
    private(set) var activeGroupID: UUID
    var isOverviewPresented: Bool = false
    var isProfileManagementPresented: Bool = false

    private unowned let store: StudyWorkspaceStore

    #if os(iOS)
    /// Scene-isolated navigation adapter so multiple iPad windows never share or collide on live `ReaderViewModel` caches.
    let navigationAdapter: StudyWorkspaceNavigationAdapter
    #endif

    init(
        sceneID: String = UUID().uuidString,
        store: StudyWorkspaceStore? = nil
    ) {
        let resolvedStore = store ?? .shared
        let normalizedSceneID = sceneID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? UUID().uuidString
            : sceneID
        self.sceneID = normalizedSceneID
        self.store = resolvedStore
        let state = resolvedStore.sceneSelection(for: normalizedSceneID)
        self.activeProfileID = state.activeProfileID
        self.activeGroupID = state.activeGroupID
        self.isOverviewPresented = state.isOverviewPresented
        #if os(iOS)
        self.navigationAdapter = StudyWorkspaceNavigationAdapter(
            sceneID: normalizedSceneID,
            store: resolvedStore
        )
        #endif
    }

    /// Resolves a deterministic, stable `sceneID` across SwiftUI view re-renders and window switches.
    /// - If `persistedSceneID` (`@SceneStorage`) is non-empty, returns it immediately.
    /// - Otherwise returns `sessionFallbackID` (`@State` UUID created once per view lifetime)
    ///   so repeated `body` evaluations never generate transient scene IDs.
    static func resolveStableSceneID(
        persistedSceneID: String,
        sessionFallbackID: String
    ) -> String {
        let trimmedPersisted = persistedSceneID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPersisted.isEmpty {
            return trimmedPersisted
        }
        let trimmedFallback = sessionFallbackID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFallback.isEmpty ? UUID().uuidString : trimmedFallback
    }

    /// Lazily acquires a `StudyWorkspaceSceneCoordinator` ONLY when `effectiveStudyWorkspaceEnabled` is active.
    /// When `studyWorkspaceEnabled` is disabled (`false`), returns `nil` without initializing `StudyWorkspaceStore`,
    /// running `StudyWorkspaceMigration`, or performing any disk I/O, even if standalone Duck Tab Strip is active.
    static func acquireIfEnabled(
        persistedSceneID: inout String,
        sessionFallbackID: String,
        existingCoordinator: StudyWorkspaceSceneCoordinator?,
        featureFlags: ChavrusaTextFeatureFlags? = nil,
        storeProvider: (() -> StudyWorkspaceStore)? = nil
    ) -> StudyWorkspaceSceneCoordinator? {
        let resolvedFlags = featureFlags ?? .shared
        guard resolvedFlags.effectiveStudyWorkspaceEnabled else {
            return nil
        }
        let stableID = resolveStableSceneID(
            persistedSceneID: persistedSceneID,
            sessionFallbackID: sessionFallbackID
        )
        if persistedSceneID != stableID {
            persistedSceneID = stableID
        }
        if let existingCoordinator, existingCoordinator.sceneID == stableID {
            return existingCoordinator
        }
        let resolvedStore = storeProvider?() ?? .shared
        return StudyWorkspaceSceneCoordinator(sceneID: stableID, store: resolvedStore)
    }

    var activeProfile: StudyProfile {
        store.profile(for: activeProfileID) ?? store.defaultProfile
    }

    var activeGroup: StudyTabGroup {
        store.group(for: activeGroupID)
            ?? store.groups(for: activeProfile.id).first
            ?? store.defaultGroup(for: activeProfile.id)
    }

    var groupsInActiveProfile: [StudyTabGroup] {
        store.groups(for: activeProfile.id)
    }

    var tabsInActiveGroup: [ReaderDocumentTab] {
        store.tabs(in: activeGroup.id)
    }

    var activeTab: ReaderDocumentTab? {
        guard let activeTabID = activeGroup.activeTabID else {
            return tabsInActiveGroup.first
        }
        return store.tab(for: activeTabID) ?? tabsInActiveGroup.first
    }

    func selectProfile(_ profileID: UUID) {
        guard let profile = store.profile(for: profileID) else { return }
        activeProfileID = profile.id
        let profileGroups = store.groups(for: profile.id)
        if !profileGroups.contains(where: { $0.id == activeGroupID }),
           let firstGroup = profileGroups.first {
            activeGroupID = firstGroup.id
        }
        syncToStore()
    }

    func selectGroup(_ groupID: UUID) {
        guard let group = store.group(for: groupID) else { return }
        activeProfileID = group.profileID
        activeGroupID = group.id
        syncToStore()
    }

    #if os(iOS)
    /// Performs an ACID-compliant transaction to switch to a target study tab group:
    /// 1. Verifies the target group exists in `store`.
    /// 2. Snapshots previous group and profile IDs.
    /// 3. Captures live state of the previous group and projects target group onto `navigationManager` via `navigationAdapter`.
    /// 4. If projection succeeds: commits `activeProfileID`, `activeGroupID`, syncs to store, and returns `true`.
    /// 5. If projection fails: rolls back `navigationManager` and coordinator selection to snapshot, syncs to store, and returns `false`.
    @discardableResult func transitionToGroup(
        _ targetGroupID: UUID,
        in navigationManager: iOSNavigationManager,
        forceWhenDisabled: Bool = false
    ) -> Bool {
        guard targetGroupID != activeGroupID else {
            return true
        }
        guard let targetGroup = store.group(for: targetGroupID) else {
            return false
        }

        let previousGroupID = activeGroupID
        let previousProfileID = activeProfileID

        let success = navigationAdapter.projectGroup(
            targetGroupID,
            onto: navigationManager,
            previousGroupID: previousGroupID,
            forceWhenDisabled: forceWhenDisabled
        )

        guard success else {
            activeProfileID = previousProfileID
            activeGroupID = previousGroupID
            syncToStore()
            return false
        }

        activeProfileID = targetGroup.profileID
        activeGroupID = targetGroup.id
        syncToStore()
        return true
    }
    #endif

    func selectTab(_ tabID: UUID, closeOverviewIfNeeded: Bool = false) {
        store.setActiveTab(tabID, inGroup: activeGroup.id)
        if closeOverviewIfNeeded {
            isOverviewPresented = false
        }
        syncToStore()
    }

    func toggleOverview() {
        isOverviewPresented.toggle()
        syncToStore()
    }

    func refreshFromStore() {
        let state = store.sceneSelection(for: sceneID)
        activeProfileID = state.activeProfileID
        activeGroupID = state.activeGroupID
    }

    private func syncToStore() {
        store.updateSceneSelection(
            StudySceneSelectionState(
                sceneID: sceneID,
                activeProfileID: activeProfileID,
                activeGroupID: activeGroupID,
                isOverviewPresented: isOverviewPresented,
                updatedAt: Date()
            )
        )
    }
}
