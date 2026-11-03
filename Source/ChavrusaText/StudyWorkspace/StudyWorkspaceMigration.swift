//
//  StudyWorkspaceMigration.swift
//  Maktabah
//
//  Downstream-owned idempotent migration from legacy `iOSReaderSession` into `StudyWorkspaceSnapshot`.
//

import Foundation

/// Handles one-way idempotent import of `iOSReaderSession` (`ios_reader_session.json`)
/// into the default `"אישי"` `StudyProfile` and default `StudyTabGroup` without modifying or deleting
/// the legacy `ios_reader_session.json` file.
enum StudyWorkspaceMigration {
    /// Migrates a legacy `iOSReaderSession` into a fresh or existing `StudyWorkspaceSnapshot`.
    /// Calling this multiple times with the same session is idempotent and will not duplicate tabs.
    static func migrateIfNeeded(
        existingSnapshot: StudyWorkspaceSnapshot?,
        legacySession: iOSReaderSession?,
        fallbackBackend: BackendID = .otzaria,
        now: Date = Date()
    ) -> StudyWorkspaceSnapshot {
        if let existingSnapshot, existingSnapshot.migratedFromLegacySession {
            return StudyWorkspacePersistence.normalize(existingSnapshot, now: now)
        }

        let defaultProfile = StudyProfile.makeDefault(now: now)
        guard let legacySession, !legacySession.tabs.isEmpty else {
            var base = existingSnapshot ?? StudyWorkspaceSnapshot(
                savedAt: now,
                migratedFromLegacySession: true,
                lastActiveProfileID: defaultProfile.id,
                lastActiveGroupID: StudyTabGroup.defaultGroupID,
                profiles: [defaultProfile],
                groups: [StudyTabGroup.makeDefault(profileID: defaultProfile.id, now: now)],
                tabsByID: [:]
            )
            base.migratedFromLegacySession = true
            return StudyWorkspacePersistence.normalize(base, now: now)
        }

        let sessionBackend = legacySession.backend.flatMap(BackendID.init(rawValue:)) ?? fallbackBackend
        var tabsByID: [UUID: ReaderDocumentTab] = existingSnapshot?.tabsByID ?? [:]
        var orderedTabIDs: [UUID] = []

        for sessionTab in legacySession.tabs {
            let docTab = ReaderDocumentTab(
                from: sessionTab,
                fallbackBackend: sessionBackend,
                now: now
            )
            tabsByID[docTab.id] = docTab
            if !orderedTabIDs.contains(docTab.id) {
                orderedTabIDs.append(docTab.id)
            }
        }

        let resolvedActiveTabID: UUID?
        if let savedActive = legacySession.activeTabId, orderedTabIDs.contains(savedActive) {
            resolvedActiveTabID = savedActive
        } else {
            resolvedActiveTabID = orderedTabIDs.first
        }

        let defaultGroup = StudyTabGroup.makeDefault(
            profileID: defaultProfile.id,
            name: StudyTabGroup.defaultGroupName,
            tabIDs: orderedTabIDs,
            activeTabID: resolvedActiveTabID,
            now: now
        )

        var profiles = existingSnapshot?.profiles ?? [defaultProfile]
        if !profiles.contains(where: { $0.id == defaultProfile.id }) {
            profiles.insert(defaultProfile, at: 0)
        }

        var groups = existingSnapshot?.groups ?? []
        if let idx = groups.firstIndex(where: { $0.id == defaultGroup.id || ($0.profileID == defaultProfile.id && $0.sortOrder == 0) }) {
            var updatedGroup = groups[idx]
            for id in orderedTabIDs where !updatedGroup.tabIDs.contains(id) {
                updatedGroup.tabIDs.append(id)
            }
            if updatedGroup.activeTabID == nil {
                updatedGroup.activeTabID = resolvedActiveTabID
            }
            groups[idx] = updatedGroup
        } else {
            groups.insert(defaultGroup, at: 0)
        }

        let snapshot = StudyWorkspaceSnapshot(
            schemaVersion: StudyWorkspaceSnapshot.currentSchemaVersion,
            savedAt: now,
            migratedFromLegacySession: true,
            lastActiveProfileID: defaultProfile.id,
            lastActiveGroupID: groups.first(where: { $0.profileID == defaultProfile.id })?.id ?? defaultGroup.id,
            profiles: profiles,
            groups: groups,
            tabsByID: tabsByID,
            sceneStatesByID: existingSnapshot?.sceneStatesByID ?? [:]
        )

        return StudyWorkspacePersistence.normalize(snapshot, now: now)
    }
}
