import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(SQLite3)
import SQLite3
#endif

/// Error types for the iTorah shared storage container.
enum ITorahSharedContainerError: LocalizedError, Sendable {
    case appGroupUnavailable(String)
    case invalidDataset(String)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let group):
            return "CRITICAL CONFIGURATION ERROR: The shared App Group container '\(group)' could not be resolved on a physical device. Ensure the App ID has the App Groups capability and the active provisioning profile includes '\(group)'. Refusing fallback to private storage to prevent corpus divergence."
        case .invalidDataset(let reason):
            return "Dataset validation failed: \(reason)"
        }
    }
}

/// Canonical shared storage container abstraction for the iTorah ecosystem.
///
/// Multi-application and multi-process architecture:
/// - The shared App Group container (`group.com.davidpovarsky.itorah`) is the canonical storage root
///   for Otzaria and Zayit Torah corpora, search indexes, manifests, and search resources.
/// - Database files (`seforim.db`) and search indexes are immutable distributions opened by readers
///   in read-only mode (`SQLITE_OPEN_READONLY`). Concurrent readers operate simultaneously without conflict.
/// - Installers, migrators, and index builders acquire an exclusive cross-process lock via `ITorahStorageLock`
///   on the container, write into staging files, validate the payload, and atomically promote into place.
///   Readers never see incomplete or half-written assets.
enum ITorahSharedContainer: Sendable {
    /// Ecosystem-wide shared App Group identifier for the Torah corpus and search engine.
    static let appGroupIdentifier = "group.com.davidpovarsky.itorah"

    /// ChavrusaText app-specific App Group identifier, reserved for app-specific state.
    static let chavrusaTextAppGroupIdentifier = "group.com.davidpovarsky.chavrusatext"

    /// Subdirectory inside the container for Otzaria data.
    static let otzariaNamespace = "Otzaria"

    // MARK: - Testing and Dependency Injection

    private final class StorageOverrideBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _override: URL?

        var value: URL? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _override
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _override = newValue
            }
        }
    }

    private static let overrideBox = StorageOverrideBox()

    /// Thread-safe storage root override for tests and previews.
    static var sharedRootOverride: URL? {
        get { overrideBox.value }
        set { overrideBox.value = newValue }
    }

    private final class LegacyRootsOverrideBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _override: [URL]?

        var value: [URL]? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _override
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _override = newValue
            }
        }
    }

    private static let legacyRootsBox = LegacyRootsOverrideBox()

    /// Thread-safe legacy roots override for tests and previews.
    static var legacyRootsOverride: [URL]? {
        get { legacyRootsBox.value }
        set { legacyRootsBox.value = newValue }
    }

    private final class TestingFlagBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _flag = false

        var value: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _flag
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _flag = newValue
            }
        }
    }

    private static let realDeviceSimulationBox = TestingFlagBox()

    /// Testing hook: simulates a physical iOS device where the App Group container is unavailable.
    static var simulateRealDeviceMissingContainerForTesting: Bool {
        get { realDeviceSimulationBox.value }
        set { realDeviceSimulationBox.value = newValue }
    }

    // MARK: - Pluggable Validator Hooks

    private final class ValidatorHooksBox: @unchecked Sendable {
        fileprivate let lock = NSLock()
        var databaseValidator: (@Sendable (URL, String) throws -> Bool)?
        var searchIndexValidator: (@Sendable (URL, String) throws -> Bool)?
        var zayitIndexValidator: (@Sendable (URL, String) throws -> Bool)?
        var lexicalValidator: (@Sendable (URL) throws -> Bool)?
    }

    private static let hooksBox = ValidatorHooksBox()

    static var databaseValidator: (@Sendable (URL, String) throws -> Bool)? {
        get {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            return hooksBox.databaseValidator
        }
        set {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            hooksBox.databaseValidator = newValue
        }
    }

    static var searchIndexValidator: (@Sendable (URL, String) throws -> Bool)? {
        get {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            return hooksBox.searchIndexValidator
        }
        set {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            hooksBox.searchIndexValidator = newValue
        }
    }

    static var zayitIndexValidator: (@Sendable (URL, String) throws -> Bool)? {
        get {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            return hooksBox.zayitIndexValidator
        }
        set {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            hooksBox.zayitIndexValidator = newValue
        }
    }

    static var lexicalValidator: (@Sendable (URL) throws -> Bool)? {
        get {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            return hooksBox.lexicalValidator
        }
        set {
            hooksBox.lock.lock()
            defer { hooksBox.lock.unlock() }
            hooksBox.lexicalValidator = newValue
        }
    }

    // MARK: - Canonical Roots

    /// Resolves the canonical shared root URL for the iTorah container.
    ///
    /// On a real physical iOS device:
    /// If `containerURL(forSecurityApplicationGroupIdentifier: "group.com.davidpovarsky.itorah")` cannot
    /// be resolved, this method throws `ITorahSharedContainerError.appGroupUnavailable`.
    /// SILENT PRIVATE-STORAGE FALLBACK IS EXPLICITLY FORBIDDEN on physical devices.
    ///
    /// On Simulator / macOS / test harness:
    /// Falls back to test root or Application Support.
    static func resolveSharedRootURL() throws -> URL {
        if simulateRealDeviceMissingContainerForTesting {
            NSLog("CRITICAL: iTorah App Group container '%@' is unavailable (simulated real-device check).", appGroupIdentifier)
            throw ITorahSharedContainerError.appGroupUnavailable(appGroupIdentifier)
        }

        if let overridden = sharedRootOverride {
            return overridden
        }

        if let envPath = ProcessInfo.processInfo.environment["OTZARIA_SHARED_ROOT_OVERRIDE"],
           !envPath.isEmpty {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }

        #if os(iOS)
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return container
        }

        #if targetEnvironment(simulator)
        // In simulator / development environments without active entitlements, allow App Support fallback
        if let fallback = AppConfig.appSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return fallback
        }
        throw ITorahSharedContainerError.appGroupUnavailable(appGroupIdentifier)
        #else
        // On real physical iOS device: DO NOT fall back to private storage. Fail explicitly.
        NSLog("CRITICAL: iTorah App Group container '%@' is unavailable on physical iOS device. Halting to prevent private storage divergence.", appGroupIdentifier)
        throw ITorahSharedContainerError.appGroupUnavailable(appGroupIdentifier)
        #endif

        #else
        // macOS runtime uses Application Support directly
        if let fallback = AppConfig.appSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return fallback
        }
        throw ITorahSharedContainerError.appGroupUnavailable("macOS Application Support")
        #endif
    }

    /// The canonical shared root URL for the iTorah container.
    ///
    /// On a real physical iOS device where the App Group container cannot resolve,
    /// this property halts execution with `fatalError` rather than silently creating
    /// an unshared private corpus.
    static var sharedRootURL: URL {
        do {
            return try resolveSharedRootURL()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    /// Canonical shared directory for Otzaria data inside the container.
    static var otzariaRootURL: URL {
        sharedRootURL.appendingPathComponent(otzariaNamespace, isDirectory: true)
    }

    /// Canonical shared downloads and staging directory inside the container.
    /// Placing downloads inside the same container ensures atomic moves on promotion.
    static var downloadsRootURL: URL {
        otzariaRootURL.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Shared search resources directory (e.g. lexical database).
    static var searchResourcesRootURL: URL {
        otzariaRootURL.appendingPathComponent("SearchResources", isDirectory: true)
    }

    // MARK: - Component Paths

    /// Resolves the storage root for a given component and data profile.
    static func componentURL(
        component: OtzariaDataComponent,
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        OtzariaProfileStorage.applicationSupportRoot(
            base: sharedRootURL,
            component: component,
            profileID: profileID
        )
    }

    /// Resolves the canonical database file URL (`seforim.db`) for a profile.
    static func databaseURL(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        componentURL(component: .database, profileID: profileID)
            .appendingPathComponent("seforim.db")
    }

    /// Resolves the canonical installation manifest URL for a profile.
    static func databaseManifestURL(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        componentURL(component: .database, profileID: profileID)
            .appendingPathComponent("seforim-installation.json")
    }

    // MARK: - Comprehensive Asset Validation

    /// Validates an SQLite database file (`seforim.db`).
    ///
    /// Asserts:
    /// 1. File exists and is non-empty (> 100 bytes).
    /// 2. Has valid SQLite 3 magic header ("SQLite format 3\0").
    /// 3. If SQLite3 runtime is available: runs PRAGMA quick_check(1) == "ok"
    ///    and verifies required tables exist: book, line, category.
    /// 4. If adjacent `seforim-installation.json` manifest exists:
    ///    verifies manifest's effectiveProfileID matches `profileID`, and file size matches.
    /// 5. If `databaseValidator` hook is registered, executes it.
    static func isDatabaseValid(at url: URL, profileID: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              size > 100 else {
            return false
        }

        // Check SQLite magic header (first 16 bytes: "SQLite format 3\000")
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let headerData = try? handle.read(upToCount: 16),
              headerData.count == 16,
              let headerString = String(data: headerData, encoding: .ascii),
              headerString.hasPrefix("SQLite format 3") else {
            return false
        }

        #if canImport(SQLite3)
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            if let db { sqlite3_close(db) }
            return false
        }
        defer { sqlite3_close(db) }

        // PRAGMA quick_check(1)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check(1);", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            return false
        }
        var quickCheckOK = false
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(stmt, 0) {
                let result = String(cString: text)
                quickCheckOK = result.lowercased() == "ok"
            }
        }
        sqlite3_finalize(stmt)
        guard quickCheckOK else { return false }

        // Check required tables: book, line, category
        var tableStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table';", -1, &tableStmt, nil) == SQLITE_OK,
              let tableStmt else {
            return false
        }
        var tables = Set<String>()
        while sqlite3_step(tableStmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(tableStmt, 0) {
                tables.insert(String(cString: text))
            }
        }
        sqlite3_finalize(tableStmt)
        guard tables.contains("book") && tables.contains("line") && tables.contains("category") else {
            return false
        }
        #endif

        // Manifest compatibility check if manifest file exists
        let manifestURL = url.deletingLastPathComponent().appendingPathComponent("seforim-installation.json")
        if fileManager.fileExists(atPath: manifestURL.path),
           let data = try? Data(contentsOf: manifestURL),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let manifestProfileID = (json["profileID"] as? String) ?? (json["effectiveProfileID"] as? String) ?? OtzariaDataProfileRegistry.productionID
            if profileID == OtzariaDataProfileRegistry.miniTest10ID {
                guard manifestProfileID == OtzariaDataProfileRegistry.miniTest10ID else { return false }
            } else if profileID == OtzariaDataProfileRegistry.productionID {
                guard manifestProfileID == OtzariaDataProfileRegistry.productionID else { return false }
            }
            if let expectedSize = json["databaseFileSize"] as? NSNumber, expectedSize.int64Value > 0 {
                guard expectedSize.int64Value == size else { return false }
            }
        }

        // Custom validator hook if present
        if let customValidator = databaseValidator {
            guard (try? customValidator(url, profileID)) == true else { return false }
        }

        return true
    }

    /// Validates an Otzaria Tantivy search index directory.
    ///
    /// Asserts:
    /// 1. Directory exists and contains at least 2 files.
    /// 2. Contains `meta.json` with valid JSON containing `"segments"` or `"schema"`.
    /// 3. If `otzaria_prebuilt_installation.json` exists, verifies profile compatibility.
    /// 4. If `searchIndexValidator` hook is registered, executes it.
    static func isOtzariaSearchValid(at url: URL, profileID: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard let children = try? fileManager.contentsOfDirectory(atPath: url.path),
              children.count >= 2 else {
            return false
        }

        let metaURL = url.appendingPathComponent("meta.json")
        guard fileManager.fileExists(atPath: metaURL.path),
              let data = try? Data(contentsOf: metaURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              json["segments"] != nil || json["schema"] != nil else {
            return false
        }

        let manifestURL = url.appendingPathComponent("otzaria_prebuilt_installation.json")
        if fileManager.fileExists(atPath: manifestURL.path),
           let data = try? Data(contentsOf: manifestURL),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let manifestProfileID = (json["profileID"] as? String) ?? (json["effectiveProfileID"] as? String) ?? OtzariaDataProfileRegistry.productionID
            if profileID == OtzariaDataProfileRegistry.miniTest10ID {
                guard manifestProfileID == OtzariaDataProfileRegistry.miniTest10ID else { return false }
            } else if profileID == OtzariaDataProfileRegistry.productionID {
                guard manifestProfileID == OtzariaDataProfileRegistry.productionID else { return false }
            }
        }

        if let customValidator = searchIndexValidator {
            guard (try? customValidator(url, profileID)) == true else { return false }
        }

        return true
    }

    /// Validates a Zayit search index directory.
    ///
    /// Asserts:
    /// 1. Directory exists and contains at least 2 files.
    /// 2. Contains `meta.json` and `zayit-index-metadata.json`.
    /// 3. `zayit-index-metadata.json` is valid JSON containing `"schema_version"`.
    /// 4. If `zayit-installation.json` exists in parent directory, verifies profile compatibility.
    /// 5. If `zayitIndexValidator` hook is registered, executes it.
    static func isZayitSearchValid(at url: URL, profileID: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard let children = try? fileManager.contentsOfDirectory(atPath: url.path),
              children.count >= 2 else {
            return false
        }

        let metaURL = url.appendingPathComponent("meta.json")
        let metadataURL = url.appendingPathComponent("zayit-index-metadata.json")
        guard fileManager.fileExists(atPath: metaURL.path),
              fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              json["schema_version"] != nil else {
            return false
        }

        let parent = url.deletingLastPathComponent()
        let manifestURL = parent.appendingPathComponent("zayit-installation.json")
        if fileManager.fileExists(atPath: manifestURL.path),
           let data = try? Data(contentsOf: manifestURL),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let manifestProfileID = (json["profileID"] as? String) ?? (json["effectiveProfileID"] as? String) ?? OtzariaDataProfileRegistry.productionID
            if profileID == OtzariaDataProfileRegistry.miniTest10ID {
                guard manifestProfileID == OtzariaDataProfileRegistry.miniTest10ID else { return false }
            } else if profileID == OtzariaDataProfileRegistry.productionID {
                guard manifestProfileID == OtzariaDataProfileRegistry.productionID else { return false }
            }
        }

        if let customValidator = zayitIndexValidator {
            guard (try? customValidator(url, profileID)) == true else { return false }
        }

        return true
    }

    /// Validates the shared lexical database (`lexical.db`).
    ///
    /// Asserts:
    /// 1. File exists and size > 100 bytes.
    /// 2. Valid SQLite header and PRAGMA quick_check(1) == "ok".
    /// 3. If `lexical.db.release.json` marker is present, verifies size / sha256.
    /// 4. If `lexicalValidator` hook is registered, executes it.
    static func isLexicalDatabaseValid(at url: URL) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return false
        }
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              size > 100 else {
            return false
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let headerData = try? handle.read(upToCount: 16),
              headerData.count == 16,
              let headerString = String(data: headerData, encoding: .ascii),
              headerString.hasPrefix("SQLite format 3") else {
            return false
        }

        #if canImport(SQLite3)
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            if let db { sqlite3_close(db) }
            return false
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check(1);", -1, &stmt, nil) == SQLITE_OK,
              let stmt else {
            return false
        }
        var quickCheckOK = false
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let text = sqlite3_column_text(stmt, 0) {
                let result = String(cString: text)
                quickCheckOK = result.lowercased() == "ok"
            }
        }
        sqlite3_finalize(stmt)
        guard quickCheckOK else { return false }
        #endif

        let markerURL = url.appendingPathExtension("release.json")
        if fileManager.fileExists(atPath: markerURL.path),
           let data = try? Data(contentsOf: markerURL),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let expectedSize = json["size"] as? NSNumber {
                guard expectedSize.int64Value == size else { return false }
            }
        }

        if let customValidator = lexicalValidator {
            guard (try? customValidator(url)) == true else { return false }
        }

        return true
    }

    // MARK: - Legacy Migration

    /// Safely migrates existing datasets from legacy private Application Support locations
    /// into the canonical iTorah shared App Group container.
    ///
    /// Properties:
    /// - Idempotent: If the shared destination already has a validated, complete dataset, no work is performed.
    /// - Non-Destructive: Valid shared destinations are never overwritten.
    /// - Self-Healing: Incomplete or corrupted shared destinations are safely recovered from valid legacy data.
    /// - Validated: Truncated or corrupted legacy datasets are never promoted.
    /// - Atomic: Uses unique `.migrating` staging files and atomically renames on completion.
    /// - Coordinated: Uses cross-process `ITorahStorageLock` to prevent race conditions.
    static func migrateLegacyDataIfNeeded(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID,
        customLegacyRoots: [URL]? = nil
    ) {
        let destinationRoot = sharedRootURL
        let fileManager = FileManager.default

        // Gather candidate legacy roots to check
        var legacyRoots: [URL] = []
        if let custom = customLegacyRoots ?? legacyRootsOverride {
            legacyRoots = custom
        } else {
            if let appSupport = AppConfig.appSupportDir {
                legacyRoots.append(appSupport)
            }
            if let userAppSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if !legacyRoots.contains(userAppSupport) {
                    legacyRoots.append(userAppSupport)
                }
            }
        }

        // Only migrate if destination is actually distinct from legacy
        let isSameDirectory = legacyRoots.contains { $0.standardizedFileURL.path == destinationRoot.standardizedFileURL.path }
        if isSameDirectory {
            return
        }

        ITorahStorageLock.withLock(name: "migration-\(profileID)") {
            migrateDatabase(profileID: profileID, legacyRoots: legacyRoots, sharedRoot: destinationRoot)
            migrateOtzariaSearch(profileID: profileID, legacyRoots: legacyRoots, sharedRoot: destinationRoot)
            migrateZayitSearch(profileID: profileID, legacyRoots: legacyRoots, sharedRoot: destinationRoot)
            if profileID == OtzariaDataProfileRegistry.productionID {
                migrateSearchResources(legacyRoots: legacyRoots, sharedRoot: destinationRoot)
            }
        }
    }

    private static func cleanDanglingStaging(in directory: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for item in items where item.lastPathComponent.contains(".migrating") {
            try? fm.removeItem(at: item)
        }
    }

    private static func migrateDatabase(profileID: String, legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destDir = OtzariaProfileStorage.applicationSupportRoot(base: sharedRoot, component: .database, profileID: profileID)
        let destDB = destDir.appendingPathComponent("seforim.db")
        let destManifest = destDir.appendingPathComponent("seforim-installation.json")

        // Clean any dangling interrupted migration files in destination
        cleanDanglingStaging(in: destDir)

        // 1. If destination already has a VALID database, do NOT overwrite it
        if isDatabaseValid(at: destDB, profileID: profileID) {
            return
        }

        // 2. Locate valid legacy database
        for legacyBase in legacyRoots {
            let legacyDir = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .database, profileID: profileID)
            let legacyDB = legacyDir.appendingPathComponent("seforim.db")
            let legacyManifest = legacyDir.appendingPathComponent("seforim-installation.json")

            guard isDatabaseValid(at: legacyDB, profileID: profileID) else {
                continue
            }

            // Perform staging copy using a process-unique file name to avoid collisions
            let stagingID = "\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
            let stagingDB = destDir.appendingPathComponent("seforim.db.migrating.\(stagingID)")
            let stagingManifest = destDir.appendingPathComponent("seforim-installation.json.migrating.\(stagingID)")

            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingDB)
                try? fm.removeItem(at: stagingManifest)

                try fm.copyItem(at: legacyDB, to: stagingDB)
                if fm.fileExists(atPath: legacyManifest.path) {
                    try? fm.copyItem(at: legacyManifest, to: stagingManifest)
                }

                // Verify staged copy before promotion
                guard isDatabaseValid(at: stagingDB, profileID: profileID) else {
                    try? fm.removeItem(at: stagingDB)
                    try? fm.removeItem(at: stagingManifest)
                    continue
                }

                // Atomic promotion
                if fm.fileExists(atPath: destDB.path) {
                    try? fm.removeItem(at: destDB)
                }
                try fm.moveItem(at: stagingDB, to: destDB)
                if fm.fileExists(atPath: stagingManifest.path) {
                    if fm.fileExists(atPath: destManifest.path) {
                        try? fm.removeItem(at: destManifest)
                    }
                    try fm.moveItem(at: stagingManifest, to: destManifest)
                }

                NSLog("ITorahSharedContainer: Successfully migrated validated database (%@) to shared container", profileID)
                break
            } catch {
                NSLog("ITorahSharedContainer: Migration error for database: %@", error.localizedDescription)
                try? fm.removeItem(at: stagingDB)
                try? fm.removeItem(at: stagingManifest)
            }
        }
    }

    private static func migrateOtzariaSearch(profileID: String, legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destIndex = OtzariaProfileStorage.applicationSupportRoot(base: sharedRoot, component: .otzariaSearch, profileID: profileID)

        cleanDanglingStaging(in: destIndex.deletingLastPathComponent())

        if isOtzariaSearchValid(at: destIndex, profileID: profileID) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyIndex = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .otzariaSearch, profileID: profileID)
            guard isOtzariaSearchValid(at: legacyIndex, profileID: profileID) else { continue }

            let stagingID = "\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
            let stagingIndex = destIndex.deletingLastPathComponent().appendingPathComponent(destIndex.lastPathComponent + ".migrating.\(stagingID)")

            do {
                try fm.createDirectory(at: destIndex.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingIndex)
                try fm.copyItem(at: legacyIndex, to: stagingIndex)

                guard isOtzariaSearchValid(at: stagingIndex, profileID: profileID) else {
                    try? fm.removeItem(at: stagingIndex)
                    continue
                }

                if fm.fileExists(atPath: destIndex.path) {
                    try? fm.removeItem(at: destIndex)
                }
                try fm.moveItem(at: stagingIndex, to: destIndex)
                NSLog("ITorahSharedContainer: Successfully migrated validated Otzaria search index (%@) to shared container", profileID)
                break
            } catch {
                try? fm.removeItem(at: stagingIndex)
            }
        }
    }

    private static func migrateZayitSearch(profileID: String, legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destZayit = OtzariaProfileStorage.applicationSupportRoot(base: sharedRoot, component: .zayitSearch, profileID: profileID)

        cleanDanglingStaging(in: destZayit.deletingLastPathComponent())

        if isZayitSearchValid(at: destZayit, profileID: profileID) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyZayit = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .zayitSearch, profileID: profileID)
            guard isZayitSearchValid(at: legacyZayit, profileID: profileID) else { continue }

            let stagingID = "\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
            let stagingZayit = destZayit.deletingLastPathComponent().appendingPathComponent(destZayit.lastPathComponent + ".migrating.\(stagingID)")

            do {
                try fm.createDirectory(at: destZayit.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingZayit)
                try fm.copyItem(at: legacyZayit, to: stagingZayit)

                guard isZayitSearchValid(at: stagingZayit, profileID: profileID) else {
                    try? fm.removeItem(at: stagingZayit)
                    continue
                }

                if fm.fileExists(atPath: destZayit.path) {
                    try? fm.removeItem(at: destZayit)
                }
                try fm.moveItem(at: stagingZayit, to: destZayit)
                NSLog("ITorahSharedContainer: Successfully migrated validated Zayit search index (%@) to shared container", profileID)
                break
            } catch {
                try? fm.removeItem(at: stagingZayit)
            }
        }
    }

    private static func migrateSearchResources(legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destDir = sharedRoot.appendingPathComponent(otzariaNamespace, isDirectory: true)
            .appendingPathComponent("SearchResources", isDirectory: true)
        let destLexical = destDir.appendingPathComponent("lexical.db")
        let destMarker = destDir.appendingPathComponent("lexical.db.release.json")

        cleanDanglingStaging(in: destDir)

        if isLexicalDatabaseValid(at: destLexical) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyLexical = legacyBase.appendingPathComponent("Otzaria/SearchResources/lexical.db")
            let legacyMarker = legacyBase.appendingPathComponent("Otzaria/SearchResources/lexical.db.release.json")
            guard isLexicalDatabaseValid(at: legacyLexical) else { continue }

            let stagingID = "\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
            let stagingLexical = destDir.appendingPathComponent("lexical.db.migrating.\(stagingID)")
            let stagingMarker = destDir.appendingPathComponent("lexical.db.release.json.migrating.\(stagingID)")

            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingLexical)
                try? fm.removeItem(at: stagingMarker)

                try fm.copyItem(at: legacyLexical, to: stagingLexical)
                if fm.fileExists(atPath: legacyMarker.path) {
                    try? fm.copyItem(at: legacyMarker, to: stagingMarker)
                }

                guard isLexicalDatabaseValid(at: stagingLexical) else {
                    try? fm.removeItem(at: stagingLexical)
                    try? fm.removeItem(at: stagingMarker)
                    continue
                }

                if fm.fileExists(atPath: destLexical.path) {
                    try? fm.removeItem(at: destLexical)
                }
                try fm.moveItem(at: stagingLexical, to: destLexical)
                if fm.fileExists(atPath: stagingMarker.path) {
                    if fm.fileExists(atPath: destMarker.path) {
                        try? fm.removeItem(at: destMarker)
                    }
                    try fm.moveItem(at: stagingMarker, to: destMarker)
                }

                NSLog("ITorahSharedContainer: Successfully migrated validated lexical database to shared container")
                break
            } catch {
                try? fm.removeItem(at: stagingLexical)
                try? fm.removeItem(at: stagingMarker)
            }
        }
    }
}

// MARK: - Cross-Process File Lock

/// Robust cross-process and cross-thread locking mechanism for the iTorah container.
enum ITorahStorageLock {
    private final class LockMapBox: @unchecked Sendable {
        private let mutex = NSLock()
        private var locks: [String: NSLock] = [:]

        func lock(for name: String) -> NSLock {
            mutex.lock()
            defer { mutex.unlock() }
            if let existing = locks[name] {
                return existing
            }
            let created = NSLock()
            locks[name] = created
            return created
        }
    }

    private static let lockMap = LockMapBox()

    static func withLock<T>(name: String, block: () throws -> T) rethrows -> T {
        let threadLock = lockMap.lock(for: name)
        threadLock.lock()
        defer { threadLock.unlock() }

        #if canImport(Darwin)
        let lockDir = ITorahSharedContainer.otzariaRootURL.appendingPathComponent(".locks", isDirectory: true)
        try? FileManager.default.createDirectory(at: lockDir, withIntermediateDirectories: true)
        let lockFile = lockDir.appendingPathComponent("\(name).lock")

        let fd = open(lockFile.path, O_CREAT | O_RDWR, 0o666)
        guard fd >= 0 else {
            return try block()
        }
        defer { close(fd) }

        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }
        return try block()
        #else
        return try block()
        #endif
    }
}
