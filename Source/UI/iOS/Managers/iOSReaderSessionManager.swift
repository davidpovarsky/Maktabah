//
//  iOSReaderSessionManager.swift
//  Maktabah
//
//  Durable cross-process session persistence for the iOS/iPad reader.
//

import CoreGraphics
import Foundation
import OSLog
import SwiftUI

// MARK: - Session Data Models

/// Represents the durable versioned session for the iOS/iPad reader.
struct iOSReaderSession: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var activeTabId: UUID?
    var selectedTabModeRaw: Int
    var tabs: [iOSReaderTabSession]

    var selectedTabMode: AppMode {
        AppMode(rawValue: selectedTabModeRaw) ?? .viewer
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        savedAt: Date = Date(),
        activeTabId: UUID? = nil,
        selectedTabModeRaw: Int = AppMode.viewer.rawValue,
        tabs: [iOSReaderTabSession] = []
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.activeTabId = activeTabId
        self.selectedTabModeRaw = selectedTabModeRaw
        self.tabs = tabs
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

// MARK: - Session Manager

/// Coordinates durable atomic persistence and restoration of reader session state on iOS/iPad.
final class iOSReaderSessionManager: @unchecked Sendable {
    static let shared = iOSReaderSessionManager()

    private let fileManager = FileManager.default
    private let sessionWriter = SerializedSessionWriter(queueLabel: "com.maktabah.sessionManager.io")

    private var statesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Maktabah/States", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var sessionFileURL: URL {
        statesDirectory.appendingPathComponent("ios_reader_session.json")
    }

    private var legacyViewerStateURL: URL {
        statesDirectory.appendingPathComponent("viewer_state.json")
    }

    private init() {}

    // MARK: - Save Operations

    /// Schedules a debounced session save (useful during typing, layout updates, or scrolling).
    func scheduleSaveSession(_ session: iOSReaderSession, debounceInterval: TimeInterval = 0.5) {
        sessionWriter.scheduleSave(to: sessionFileURL, debounceInterval: debounceInterval) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(session)
        }
    }

    /// Flushes session to disk immediately and synchronously (required when app is backgrounding or quitting).
    func saveSessionImmediately(_ session: iOSReaderSession) {
        do {
            try sessionWriter.saveImmediately(to: sessionFileURL) {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                return try encoder.encode(session)
            }
            Logger.reader.debug("iOS reader session saved immediately with \(session.tabs.count) tabs.")
        } catch {
            Logger.reader.error("Failed to write iOS reader session immediately: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Load Operations

    /// Loads the saved session from disk with defensive fallbacks and legacy state migration.
    func loadSession() -> iOSReaderSession? {
        if fileManager.fileExists(atPath: sessionFileURL.path) {
            do {
                let data = try Data(contentsOf: sessionFileURL)
                let session = try JSONDecoder().decode(iOSReaderSession.self, from: data)
                if !session.tabs.isEmpty {
                    Logger.reader.info("Loaded iOS reader session with \(session.tabs.count) tabs.")
                    return session
                }
            } catch {
                Logger.reader.error("Failed to decode iOS reader session: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Defensive fallback: check for legacy single-book viewer state
        if let legacy = loadLegacyViewerState() {
            Logger.reader.info("Migrated legacy viewer state to iOS reader session.")
            saveSessionImmediately(legacy)
            return legacy
        }

        return nil
    }

    /// Clears the saved session from disk.
    func clearSession() {
        do {
            try sessionWriter.clear(at: sessionFileURL)
            Logger.reader.info("Cleared iOS reader session file.")
        } catch {
            Logger.reader.error("Failed to clear iOS reader session file: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Legacy Migration

    private func loadLegacyViewerState() -> iOSReaderSession? {
        guard fileManager.fileExists(atPath: legacyViewerStateURL.path),
              let data = try? Data(contentsOf: legacyViewerStateURL),
              let legacyState = try? JSONDecoder().decode(ReaderState.self, from: data),
              let book = legacyState.currentBook else {
            return nil
        }

        let tabSession = iOSReaderTabSession(
            id: UUID(),
            bookId: book.id,
            bookTitle: book.title,
            backendLocator: book.backendLocator ?? legacyState.currentLocator,
            contentId: legacyState.currentID,
            locator: legacyState.currentLocator,
            page: legacyState.currentPage,
            part: legacyState.currentPart,
            scrollPosition: legacyState.scrollPosition,
            selectedRange: legacyState.selectedRange,
            expandedNodeIDs: legacyState.expandedNodeIDs,
            sidebarScrollPosition: legacyState.sidebarScrollPosition,
            isSidebarCollapsed: legacyState.isSidebarCollapsed,
            searchText: legacyState.searchQuery,
            searchModeRaw: legacyState.searchModeRaw,
            nearDistance: legacyState.searchNearDistance,
            highlightTerms: nil
        )

        return iOSReaderSession(
            schemaVersion: iOSReaderSession.currentSchemaVersion,
            savedAt: Date(),
            activeTabId: tabSession.id,
            selectedTabModeRaw: AppMode.viewer.rawValue,
            tabs: [tabSession]
        )
    }
}
