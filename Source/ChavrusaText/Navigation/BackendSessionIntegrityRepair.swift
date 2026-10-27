//
//  BackendSessionIntegrityRepair.swift
//  Maktabah
//
//  Created by Antigravity on 27/10/2026.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

// MARK: - Session Data Models

/// Represents the durable versioned session for the iOS/iPad reader.
struct iOSReaderSession: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var activeTabId: UUID?
    var selectedTabModeRaw: Int
    var tabs: [iOSReaderTabSession]
    var backend: String?

    init(
        schemaVersion: Int = currentSchemaVersion,
        savedAt: Date = Date(),
        activeTabId: UUID? = nil,
        selectedTabModeRaw: Int = 0,
        tabs: [iOSReaderTabSession] = [],
        backend: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.activeTabId = activeTabId
        self.selectedTabModeRaw = selectedTabModeRaw
        self.tabs = tabs
        self.backend = backend
    }
}

/// Represents the state of a single reader tab in the session.
struct iOSReaderTabSession: Codable, Equatable, Sendable {
    let id: UUID
    let bookId: Int
    let bookTitle: String?
    let backendLocator: TextLocator?
    let contentId: Int?
    let locator: TextLocator?
    let page: Int?
    let part: Int?
    let scrollPosition: CGPoint?
    let selectedRange: NSRange?
    let expandedNodeIDs: [Int]?
    let sidebarScrollPosition: CGPoint?
    let isSidebarCollapsed: Bool?
    let searchText: String?
    let searchModeRaw: Int?
    let nearDistance: Int?
    let highlightTerms: [String]?

    init(
        id: UUID = UUID(),
        bookId: Int,
        bookTitle: String? = nil,
        backendLocator: TextLocator? = nil,
        contentId: Int? = nil,
        locator: TextLocator? = nil,
        page: Int? = nil,
        part: Int? = nil,
        scrollPosition: CGPoint? = nil,
        selectedRange: NSRange? = nil,
        expandedNodeIDs: [Int]? = nil,
        sidebarScrollPosition: CGPoint? = nil,
        isSidebarCollapsed: Bool? = nil,
        searchText: String? = nil,
        searchModeRaw: Int? = nil,
        nearDistance: Int? = nil,
        highlightTerms: [String]? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.backendLocator = backendLocator
        self.contentId = contentId
        self.locator = locator
        self.page = page
        self.part = part
        self.scrollPosition = scrollPosition
        self.selectedRange = selectedRange
        self.expandedNodeIDs = expandedNodeIDs
        self.sidebarScrollPosition = sidebarScrollPosition
        self.isSidebarCollapsed = isSidebarCollapsed
        self.searchText = searchText
        self.searchModeRaw = searchModeRaw
        self.nearDistance = nearDistance
        self.highlightTerms = highlightTerms
    }
}

// MARK: - Backend Session Integrity Repair

/// Repairs and defends against cross-backend session contamination.
/// Detects foreign locators in session snapshots, safely quarantines raw contaminated files,
/// purges foreign tabs, and returns a sanitized snapshot for the active or incoming backend.
final class BackendSessionIntegrityRepair: @unchecked Sendable {
    static let shared = BackendSessionIntegrityRepair()

    init() {}

    /// Detects the target backend for a given tab session.
    func detectTabBackend(_ tab: iOSReaderTabSession) -> BackendID {
        if let locator = tab.locator {
            return locator.backend
        }
        if let backendLocator = tab.backendLocator {
            return backendLocator.backend
        }
        return .otzaria
    }

    /// Evaluates if a tab session belongs to the specified backend.
    func isTabMatchingBackend(_ tab: iOSReaderTabSession, backend: BackendID) -> Bool {
        if let locator = tab.locator {
            return locator.backend == backend
        }
        if let backendLocator = tab.backendLocator {
            return backendLocator.backend == backend
        }
        return backend == .otzaria
    }

    /// Repairs a decoded session for the given target backend.
    /// Separates matching tabs from foreign tabs, resets activeTabId if needed,
    /// sets the session's backend tag to `targetBackend`, and creates a quarantine
    /// backup of the raw data if foreign tabs were found.
    func repairSessionSnapshot(
        session: iOSReaderSession,
        targetBackend: BackendID,
        rawIncomingData: Data? = nil,
        quarantineDirectory: URL? = nil
    ) -> (sanitizedSession: iOSReaderSession, foreignTabs: [iOSReaderTabSession], quarantinedBackupURL: URL?) {
        var matchingTabs: [iOSReaderTabSession] = []
        var foreignTabs: [iOSReaderTabSession] = []

        for tab in session.tabs {
            if isTabMatchingBackend(tab, backend: targetBackend) {
                matchingTabs.append(tab)
            } else {
                foreignTabs.append(tab)
            }
        }

        var backupURL: URL? = nil
        if !foreignTabs.isEmpty, let rawData = rawIncomingData {
            backupURL = backupCorruptedData(
                rawData,
                targetBackend: targetBackend,
                foreignCount: foreignTabs.count,
                quarantineDirectory: quarantineDirectory
            )
        }

        var activeTabId = session.activeTabId
        if let currentActive = activeTabId, !matchingTabs.contains(where: { $0.id == currentActive }) {
            activeTabId = matchingTabs.first?.id
        }

        var sanitized = session
        sanitized.tabs = matchingTabs
        sanitized.activeTabId = activeTabId
        sanitized.backend = targetBackend.rawValue

        return (sanitized, foreignTabs, backupURL)
    }

    private func backupCorruptedData(
        _ data: Data,
        targetBackend: BackendID,
        foreignCount: Int,
        quarantineDirectory: URL?
    ) -> URL? {
        let baseDir: URL
        if let customDir = quarantineDirectory {
            baseDir = customDir
        } else if let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            baseDir = doc.appendingPathComponent("QuarantinedSessions", isDirectory: true)
        } else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let fileURL = baseDir.appendingPathComponent("quarantine_\(targetBackend.rawValue)_\(timestamp)_foreign\(foreignCount).json")
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}
