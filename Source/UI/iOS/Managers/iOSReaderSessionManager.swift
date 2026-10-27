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

// MARK: - Navigation Mode Convenience

extension iOSReaderSession {
    var selectedTabMode: TabMode {
        TabMode(rawValue: selectedTabModeRaw) ?? .book
    }
}
