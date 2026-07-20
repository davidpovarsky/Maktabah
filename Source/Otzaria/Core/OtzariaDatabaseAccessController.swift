import Foundation
import SQLite3

final class OtzariaDatabaseAccessController {
    static let shared = OtzariaDatabaseAccessController()

    enum Source {
        case externalBookmark
        case legacyInternalCopy
    }

    enum AccessError: LocalizedError {
        case applicationSupportUnavailable
        case databaseMissing
        case databaseUnreadable
        case invalidDatabase
        case missingRequiredTables([String])

        var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                return "The Application Support folder is not available."
            case .databaseMissing:
                return "The saved Otzaria database could not be found. Choose the database again."
            case .databaseUnreadable:
                return "The saved Otzaria database is not readable. Choose the database again."
            case .invalidDatabase:
                return "The selected file is not a valid SQLite database."
            case .missingRequiredTables(let tables):
                return "The selected Otzaria database is missing required tables: \(tables.joined(separator: ", "))."
            }
        }
    }

    private(set) var currentURL: URL?
    private(set) var source: Source?

    private let bookmarkStore = OtzariaSecurityScopedBookmarkStore()
    private let legacyPathKey = "otzaria_seforim_database_path"
    private let legacySelectionKey = "goldcreative.otzaria.legacyInternalCopySelected.v2"
    private let legacyMigrationCompletedKey = "goldcreative.otzaria.legacyInternalCopyMigrationCompleted.v2"
    private var scopedAccess: OtzariaSecurityScopedAccess?

    private init() {}

    var hasPersistedSelection: Bool {
        if bookmarkStore.hasBookmark { return true }
        guard let legacyURL = try? legacyInternalCopyURL() else { return false }
        let defaults = UserDefaults.standard
        let shouldMigrate = !defaults.bool(forKey: legacyMigrationCompletedKey)
        return (defaults.bool(forKey: legacySelectionKey) || shouldMigrate) &&
            FileManager.default.fileExists(atPath: legacyURL.path)
    }

    func restoreIfNeeded() throws -> URL? {
        if let currentURL { return currentURL }

        if let restored = try bookmarkStore.restore() {
            let access = try OtzariaSecurityScopedAccess.start(for: restored.url)
            do {
                try verifyExistsAndIsReadable(restored.url)
                if restored.isStale {
                    try bookmarkStore.save(url: restored.url)
                }
                scopedAccess = access
                currentURL = restored.url
                source = .externalBookmark
                markExternalSelection()
                return restored.url
            } catch {
                access.stop()
                throw error
            }
        }

        let defaults = UserDefaults.standard
        let legacyURL = try legacyInternalCopyURL()
        let shouldUseLegacyCopy = defaults.bool(forKey: legacySelectionKey) ||
            !defaults.bool(forKey: legacyMigrationCompletedKey)
        if shouldUseLegacyCopy, FileManager.default.fileExists(atPath: legacyURL.path) {
            try verifyExistsAndIsReadable(legacyURL)
            defaults.set(true, forKey: legacySelectionKey)
            defaults.set(true, forKey: legacyMigrationCompletedKey)
            defaults.removeObject(forKey: legacyPathKey)
            currentURL = legacyURL
            source = .legacyInternalCopy
            return legacyURL
        }

        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)
        return nil
    }

    func selectExternalDatabase(_ url: URL) throws -> URL {
        let access = try OtzariaSecurityScopedAccess.start(for: url)
        do {
            try verifyExistsAndIsReadable(url)
            try validateDatabase(at: url)
            try bookmarkStore.save(url: url)

            scopedAccess?.stop()
            scopedAccess = access
            currentURL = url
            source = .externalBookmark
            markExternalSelection()
            return url
        } catch {
            access.stop()
            throw error
        }
    }

    func clearSelection(deleteLegacyInternalCopy: Bool = false) {
        scopedAccess?.stop()
        scopedAccess = nil
        currentURL = nil
        source = nil
        bookmarkStore.forget()
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)

        if deleteLegacyInternalCopy, let legacyURL = try? legacyInternalCopyURL() {
            try? FileManager.default.removeItem(at: legacyURL)
        }
    }

    private func markExternalSelection() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)
    }

    private func legacyInternalCopyURL() throws -> URL {
        guard let appSupport = AppConfig.appSupportDir else {
            throw AccessError.applicationSupportUnavailable
        }
        return appSupport
            .appendingPathComponent("Otzaria", isDirectory: true)
            .appendingPathComponent("seforim.db", isDirectory: false)
    }

    private func verifyExistsAndIsReadable(_ url: URL) throws {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw AccessError.databaseMissing
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw AccessError.databaseUnreadable
        }
    }

    private func validateDatabase(at url: URL) throws {
        let database = try SQLiteDatabase(
            path: url.path,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )

        let integrity = try database.fetch(query: "PRAGMA quick_check(1)") { row in
            row.string(at: 0) ?? ""
        }
        guard integrity.first?.lowercased() == "ok" else {
            throw AccessError.invalidDatabase
        }

        let requiredTables = Set(["book", "line", "category"])
        let availableTables = Set(try database.fetch(
            query: "SELECT name FROM sqlite_master WHERE type = 'table'"
        ) { row in
            row.string(at: 0) ?? ""
        })
        let missingTables = requiredTables.subtracting(availableTables).sorted()
        guard missingTables.isEmpty else {
            throw AccessError.missingRequiredTables(missingTables)
        }
    }
}
