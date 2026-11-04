//
//  StudyWorkspacePersistence.swift
//  Maktabah
//
//  Downstream-owned versioned, atomic sidecar persistence for Study Profiles, Tab Groups, and Document Tabs.
//  Preserves legacy `ios_reader_session.json` untouched as a fallback.
//

import Foundation

/// Versioned snapshot of the entire study workspace across profiles, tab groups, and document tabs.
struct StudyWorkspaceSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var migratedFromLegacySession: Bool
    var lastActiveProfileID: UUID
    var lastActiveGroupID: UUID
    var profiles: [StudyProfile]
    var groups: [StudyTabGroup]
    var tabsByID: [UUID: ReaderDocumentTab]
    var sceneStatesByID: [String: StudySceneSelectionState]

    init(
        schemaVersion: Int = StudyWorkspaceSnapshot.currentSchemaVersion,
        savedAt: Date = Date(),
        migratedFromLegacySession: Bool = false,
        lastActiveProfileID: UUID = StudyProfile.defaultProfileID,
        lastActiveGroupID: UUID = StudyTabGroup.defaultGroupID,
        profiles: [StudyProfile] = [StudyProfile.makeDefault()],
        groups: [StudyTabGroup] = [StudyTabGroup.makeDefault()],
        tabsByID: [UUID: ReaderDocumentTab] = [:],
        sceneStatesByID: [String: StudySceneSelectionState] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.migratedFromLegacySession = migratedFromLegacySession
        self.lastActiveProfileID = lastActiveProfileID
        self.lastActiveGroupID = lastActiveGroupID
        self.profiles = profiles
        self.groups = groups
        self.tabsByID = tabsByID
        self.sceneStatesByID = sceneStatesByID
    }
}

/// Per-scene/window active profile and group selection state.
struct StudySceneSelectionState: Codable, Equatable, Sendable {
    let sceneID: String
    var activeProfileID: UUID
    var activeGroupID: UUID
    var isOverviewPresented: Bool
    var updatedAt: Date

    init(
        sceneID: String,
        activeProfileID: UUID = StudyProfile.defaultProfileID,
        activeGroupID: UUID = StudyTabGroup.defaultGroupID,
        isOverviewPresented: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.sceneID = sceneID
        self.activeProfileID = activeProfileID
        self.activeGroupID = activeGroupID
        self.isOverviewPresented = isOverviewPresented
        self.updatedAt = updatedAt
    }
}

/// Coordinates atomic persistence, last-good backup recovery, and sidecar separation from `ios_reader_session.json`.
final class StudyWorkspacePersistence: @unchecked Sendable {
    static let shared = StudyWorkspacePersistence()

    static let workspaceFilename = "study_workspace_v1.json"
    static let backupFilename = "study_workspace_v1.bak.json"
    static let legacySessionFilename = "ios_reader_session.json"

    private let fileManager: FileManager
    private let writer: SerializedSessionWriter
    private let customDirectoryURL: URL?

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        writer: SerializedSessionWriter = SerializedSessionWriter(queueLabel: "org.maktabah.studyWorkspace.writer")
    ) {
        self.customDirectoryURL = directoryURL
        self.fileManager = fileManager
        self.writer = writer
    }

    var statesDirectoryURL: URL {
        if let customDirectoryURL {
            if !fileManager.fileExists(atPath: customDirectoryURL.path) {
                try? fileManager.createDirectory(at: customDirectoryURL, withIntermediateDirectories: true)
            }
            return customDirectoryURL
        }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Maktabah/States", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    var workspaceFileURL: URL {
        statesDirectoryURL.appendingPathComponent(Self.workspaceFilename)
    }

    var backupFileURL: URL {
        statesDirectoryURL.appendingPathComponent(Self.backupFilename)
    }

    var legacySessionFileURL: URL {
        statesDirectoryURL.appendingPathComponent(Self.legacySessionFilename)
    }

    /// Schedules a debounced atomic write of the snapshot and updates the `.bak` last-good copy.
    func scheduleSave(_ snapshot: StudyWorkspaceSnapshot, debounceInterval: TimeInterval = 0.4) {
        let targetURL = workspaceFileURL
        let bakURL = backupFileURL
        let fm = fileManager
        writer.scheduleSave(to: targetURL, debounceInterval: debounceInterval) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try? Self.writeBackupCopy(data: data, to: bakURL, fileManager: fm)
            return data
        }
    }

    /// Saves the snapshot immediately and synchronously (e.g., on scene backgrounding or explicit group mutation).
    func saveImmediately(_ snapshot: StudyWorkspaceSnapshot) throws {
        let targetURL = workspaceFileURL
        let bakURL = backupFileURL
        let fm = fileManager
        try writer.saveImmediately(to: targetURL) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try? Self.writeBackupCopy(data: data, to: bakURL, fileManager: fm)
            return data
        }
    }

    /// Loads the workspace snapshot from disk, falling back to `.bak` if the primary file is corrupted.
    /// Returns `(snapshot, didRecoverFromBackup)`.
    func loadSnapshotWithRecovery() -> (snapshot: StudyWorkspaceSnapshot?, didRecoverFromBackup: Bool) {
        let decoder = JSONDecoder()

        if fileManager.fileExists(atPath: workspaceFileURL.path) {
            if let data = try? Data(contentsOf: workspaceFileURL),
               let decoded = try? decoder.decode(StudyWorkspaceSnapshot.self, from: data) {
                return (Self.normalize(decoded), false)
            }
        }

        // Fallback to last-good backup if primary file is missing or corrupted
        if fileManager.fileExists(atPath: backupFileURL.path) {
            if let bakData = try? Data(contentsOf: backupFileURL),
               let recovered = try? decoder.decode(StudyWorkspaceSnapshot.self, from: bakData) {
                let normalized = Self.normalize(recovered)
                try? saveImmediately(normalized)
                return (normalized, true)
            }
        }

        return (nil, false)
    }

    /// Normalizes a snapshot so that the default profile `"אישי"` and at least one group per profile always exist.
    static func normalize(_ snapshot: StudyWorkspaceSnapshot, now: Date = Date()) -> StudyWorkspaceSnapshot {
        var result = snapshot

        if !result.profiles.contains(where: { $0.isDefault || $0.id == StudyProfile.defaultProfileID }) {
            result.profiles.insert(StudyProfile.makeDefault(now: now), at: 0)
        }

        // Ensure every profile has at least one group
        for profile in result.profiles {
            if !result.groups.contains(where: { $0.profileID == profile.id }) {
                let fallbackGroup = StudyTabGroup.makeDefault(profileID: profile.id, now: now)
                result.groups.append(fallbackGroup)
            }
        }

        // Validate lastActiveProfileID
        if !result.profiles.contains(where: { $0.id == result.lastActiveProfileID }) {
            result.lastActiveProfileID = result.profiles.first(where: \.isDefault)?.id
                ?? result.profiles.first?.id
                ?? StudyProfile.defaultProfileID
        }

        // Validate lastActiveGroupID belongs to lastActiveProfileID
        let activeProfileGroups = result.groups
            .filter { $0.profileID == result.lastActiveProfileID }
            .sorted { $0.sortOrder < $1.sortOrder }

        if !activeProfileGroups.contains(where: { $0.id == result.lastActiveGroupID }),
           let firstGroup = activeProfileGroups.first {
            result.lastActiveGroupID = firstGroup.id
        }

        // Normalize each group's tabIDs and activeTabID against existing tabsByID
        for idx in result.groups.indices {
            let validTabIDs = result.groups[idx].tabIDs.filter { result.tabsByID[$0] != nil }
            result.groups[idx].tabIDs = validTabIDs
            if let active = result.groups[idx].activeTabID, !validTabIDs.contains(active) {
                result.groups[idx].activeTabID = validTabIDs.first
            } else if result.groups[idx].activeTabID == nil {
                result.groups[idx].activeTabID = validTabIDs.first
            }
        }

        return result
    }

    private static func writeBackupCopy(data: Data, to backupURL: URL, fileManager: FileManager) throws {
        let parent = backupURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try data.write(to: backupURL, options: [.atomic])
    }
}
