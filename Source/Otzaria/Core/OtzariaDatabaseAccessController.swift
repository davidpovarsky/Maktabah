import Foundation
import SQLite3

final class OtzariaDatabaseAccessController {
    static let shared = OtzariaDatabaseAccessController()

    enum Source {
        case externalBookmark
        case managedInternal
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
    private let managedSelectionKey = "goldcreative.otzaria.managedInternalSelected.v3"
    private var scopedAccess: OtzariaSecurityScopedAccess?

    private init() {}

    var hasPersistedSelection: Bool {
        if bookmarkStore.hasBookmark { return true }
        guard let managedURL = try? managedInternalDatabaseURL() else { return false }
        return FileManager.default.fileExists(atPath: managedURL.path)
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
        let managedURL = try managedInternalDatabaseURL()
        // This path was used by the legacy internal-copy flow and is also the
        // stable destination for managed downloads. Its presence is sufficient
        // for crash recovery even if the selection marker was not yet persisted.
        if FileManager.default.fileExists(atPath: managedURL.path) {
            try verifyExistsAndIsReadable(managedURL)
            try validateDatabase(at: managedURL)
            defaults.set(true, forKey: managedSelectionKey)
            defaults.set(false, forKey: legacySelectionKey)
            defaults.set(true, forKey: legacyMigrationCompletedKey)
            defaults.removeObject(forKey: legacyPathKey)
            currentURL = managedURL
            source = .managedInternal
            return managedURL
        }

        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(false, forKey: managedSelectionKey)
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

    func activateManagedDatabase(at url: URL) throws -> URL {
        let expectedURL = try managedInternalDatabaseURL().standardizedFileURL
        guard url.standardizedFileURL == expectedURL else {
            throw AccessError.invalidDatabase
        }
        try verifyExistsAndIsReadable(url)
        try validateDatabase(at: url)

        scopedAccess?.stop()
        scopedAccess = nil
        bookmarkStore.forget()
        currentURL = url
        source = .managedInternal

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: managedSelectionKey)
        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)
        return url
    }

    func clearSelection(deleteManagedInternalDatabase: Bool = false) {
        scopedAccess?.stop()
        scopedAccess = nil
        currentURL = nil
        source = nil
        bookmarkStore.forget()
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(false, forKey: managedSelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)

        if deleteManagedInternalDatabase, let managedURL = try? managedInternalDatabaseURL() {
            try? FileManager.default.removeItem(at: managedURL)
        }
    }

    private func markExternalSelection() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: legacySelectionKey)
        defaults.set(false, forKey: managedSelectionKey)
        defaults.set(true, forKey: legacyMigrationCompletedKey)
        defaults.removeObject(forKey: legacyPathKey)
    }

    func managedInternalDatabaseURL() throws -> URL {
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

    func validateDatabase(at url: URL) throws {
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
