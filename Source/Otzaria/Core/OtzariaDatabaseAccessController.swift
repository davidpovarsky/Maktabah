import Foundation
import SQLite3

final class OtzariaDatabaseAccessController {
    static let shared = OtzariaDatabaseAccessController()

    enum Source: Equatable {
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
            try validateManagedDatabaseForRestore(at: managedURL)
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
        try validateManagedDatabaseForRestore(at: url)

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

        try validateRequiredSchema(in: database)
    }

    /// Managed databases have already passed the full SQLite integrity scan
    /// before atomic promotion. Cold launch must not repeat that multi-gigabyte
    /// scan on the scene-creation path.
    private func validateManagedDatabaseForRestore(at url: URL) throws {
        try verifyManagedInstallIdentityIfPresent(at: url)

        let database = try SQLiteDatabase(
            path: url.path,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )
        try validateRequiredSchema(in: database)
    }

    private func verifyManagedInstallIdentityIfPresent(at databaseURL: URL) throws {
        let root = databaseURL.deletingLastPathComponent()
        let pendingManifestURL = root.appendingPathComponent(
            "seforim-installation.json.installing"
        )
        let previousDatabaseURL = root.appendingPathComponent("seforim.db.previous")
        let manifestURLs = [
            pendingManifestURL,
            root.appendingPathComponent("seforim-installation.json"),
        ]
        // If promotion stopped before pending metadata was written, recovery
        // has already performed the full integrity scan off the main actor.
        // The stable manifest may still describe the rollback database.
        if FileManager.default.fileExists(atPath: previousDatabaseURL.path),
           !FileManager.default.fileExists(atPath: pendingManifestURL.path) {
            return
        }
        guard let manifestURL = manifestURLs.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            // Preserve compatibility with managed databases installed before
            // installation manifests were introduced. Their schema is still
            // checked below, without a full integrity scan during launch.
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(
                OtzariaDatabaseInstallationManifest.self,
                from: Data(contentsOf: manifestURL)
            )
            let attributes = try FileManager.default.attributesOfItem(atPath: databaseURL.path)
            let actualSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard manifest.repository == OtzariaLibraryRelease.repository,
                  manifest.assetName == OtzariaLibraryRelease.databaseAssetName,
                  manifest.databaseFileSize > 0,
                  manifest.databaseFileSize == actualSize else {
                throw AccessError.invalidDatabase
            }
        } catch let error as AccessError {
            throw error
        } catch {
            throw AccessError.invalidDatabase
        }
    }

    private func validateRequiredSchema(in database: SQLiteDatabase) throws {
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
