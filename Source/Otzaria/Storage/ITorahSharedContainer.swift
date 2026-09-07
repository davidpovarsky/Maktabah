import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Canonical shared storage container abstraction for the iTorah ecosystem.
///
/// Multi-application and multi-process architecture:
/// - The shared App Group container (`group.com.davidpovarsky.itorah`) is the canonical storage root
///   for Otzaria and Zayit Torah corpora, search indexes, manifests, and search resources.
/// - Database files (`seforim.db`) and search indexes are immutable distributions opened by readers
///   in read-only mode (`SQLITE_OPEN_READONLY`). Concurrent readers operate simultaneously without conflict.
/// - Installers and migrators acquire an exclusive cross-process lock via `ITorahStorageLock` on the container,
///   write into staging files (`.installing` / `.migrating`), validate the payload, and atomically promote
///   into place. Readers never see incomplete or half-written assets.
public enum ITorahSharedContainer: Sendable {
    /// Ecosystem-wide shared App Group identifier for the Torah corpus and search engine.
    public static let appGroupIdentifier = "group.com.davidpovarsky.itorah"

    /// ChavrusaText app-specific App Group identifier, reserved for app-specific state.
    public static let chavrusaTextAppGroupIdentifier = "group.com.davidpovarsky.chavrusatext"

    /// Subdirectory inside the container for Otzaria data.
    public static let otzariaNamespace = "Otzaria"

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
    public static var sharedRootOverride: URL? {
        get { overrideBox.value }
        set { overrideBox.value = newValue }
    }

    // MARK: - Canonical Roots

    /// The canonical shared root URL for the iTorah container.
    ///
    /// On iOS runtime: resolves to `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.davidpovarsky.itorah")`.
    /// On macOS / fallback: resolves to the application support root.
    public static var sharedRootURL: URL {
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
        // In simulator / development environments without entitlements active, use app support fallback
        let fallback = AppConfig.appSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return fallback
        #else
        // On real iOS device: missing container is a critical configuration error.
        NSLog("CRITICAL: iTorah App Group container '%@' is unavailable. Check App ID capabilities and provisioning profile.", appGroupIdentifier)
        let fallback = AppConfig.appSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return fallback
        #endif

        #else
        // macOS runtime uses Application Support directly
        return AppConfig.appSupportDir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        #endif
    }

    /// Canonical shared directory for Otzaria data inside the container.
    public static var otzariaRootURL: URL {
        sharedRootURL.appendingPathComponent(otzariaNamespace, isDirectory: true)
    }

    /// Canonical shared downloads and staging directory inside the container.
    /// Placing downloads inside the same container ensures atomic moves on promotion.
    public static var downloadsRootURL: URL {
        otzariaRootURL.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Shared search resources directory (e.g. lexical database).
    public static var searchResourcesRootURL: URL {
        otzariaRootURL.appendingPathComponent("SearchResources", isDirectory: true)
    }

    // MARK: - Component Paths

    /// Resolves the storage root for a given component and data profile.
    public static func componentURL(
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
    public static func databaseURL(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        componentURL(component: .database, profileID: profileID)
            .appendingPathComponent("seforim.db")
    }

    /// Resolves the canonical installation manifest URL for a profile.
    public static func databaseManifestURL(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) -> URL {
        componentURL(component: .database, profileID: profileID)
            .appendingPathComponent("seforim-installation.json")
    }

    // MARK: - Legacy Migration

    /// Safely migrates existing datasets from the legacy private Application Support location
    /// into the canonical iTorah shared App Group container.
    ///
    /// Properties:
    /// - Idempotent: If the shared destination already has complete data, no work is performed.
    /// - Atomic: Copies into `.migrating` staging files and atomically renames on completion.
    /// - Safe: Legacy source is never modified or removed before verification.
    /// - Coordinated: Uses cross-process file locking to prevent race conditions across app instances.
    public static func migrateLegacyDataIfNeeded(
        profileID: String = OtzariaDataProfileRegistry.activeProfileID
    ) {
        let destinationRoot = sharedRootURL
        let fileManager = FileManager.default

        // Gather candidate legacy roots to check
        var legacyRoots: [URL] = []
        if let appSupport = AppConfig.appSupportDir {
            legacyRoots.append(appSupport)
        }
        if let userAppSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !legacyRoots.contains(userAppSupport) {
                legacyRoots.append(userAppSupport)
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

    private static func migrateDatabase(profileID: String, legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destDir = OtzariaProfileStorage.applicationSupportRoot(base: sharedRoot, component: .database, profileID: profileID)
        let destDB = destDir.appendingPathComponent("seforim.db")
        let destManifest = destDir.appendingPathComponent("seforim-installation.json")

        // 1. If destination already has a valid database, do not overwrite
        if fm.fileExists(atPath: destDB.path),
           let attrs = try? fm.attributesOfItem(atPath: destDB.path),
           let size = (attrs[.size] as? NSNumber)?.int64Value,
           size > 0 {
            return
        }

        // 2. Locate valid legacy database
        for legacyBase in legacyRoots {
            let legacyDir = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .database, profileID: profileID)
            let legacyDB = legacyDir.appendingPathComponent("seforim.db")
            let legacyManifest = legacyDir.appendingPathComponent("seforim-installation.json")

            guard fm.fileExists(atPath: legacyDB.path),
                  let attrs = try? fm.attributesOfItem(atPath: legacyDB.path),
                  let size = (attrs[.size] as? NSNumber)?.int64Value,
                  size > 0 else {
                continue
            }

            // Perform staging copy
            let stagingDB = destDir.appendingPathComponent("seforim.db.migrating")
            let stagingManifest = destDir.appendingPathComponent("seforim-installation.json.migrating")

            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingDB)
                try? fm.removeItem(at: stagingManifest)

                try fm.copyItem(at: legacyDB, to: stagingDB)
                if fm.fileExists(atPath: legacyManifest.path) {
                    try? fm.copyItem(at: legacyManifest, to: stagingManifest)
                }

                // Verify copied staging file size matches
                let stagedAttrs = try fm.attributesOfItem(atPath: stagingDB.path)
                guard let stagedSize = (stagedAttrs[.size] as? NSNumber)?.int64Value,
                      stagedSize == size else {
                    try? fm.removeItem(at: stagingDB)
                    try? fm.removeItem(at: stagingManifest)
                    continue
                }

                // Atomic promotion
                try? fm.removeItem(at: destDB)
                try fm.moveItem(at: stagingDB, to: destDB)
                if fm.fileExists(atPath: stagingManifest.path) {
                    try? fm.removeItem(at: destManifest)
                    try? fm.moveItem(at: stagingManifest, to: destManifest)
                }

                NSLog("ITorahSharedContainer: Successfully migrated database (%@) to shared container", profileID)
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

        if fm.fileExists(atPath: destIndex.path) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyIndex = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .otzariaSearch, profileID: profileID)
            guard fm.fileExists(atPath: legacyIndex.path) else { continue }

            let stagingIndex = destIndex.deletingLastPathComponent().appendingPathComponent(destIndex.lastPathComponent + ".migrating")
            do {
                try fm.createDirectory(at: destIndex.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingIndex)
                try fm.copyItem(at: legacyIndex, to: stagingIndex)
                try fm.moveItem(at: stagingIndex, to: destIndex)
                NSLog("ITorahSharedContainer: Successfully migrated Otzaria search index (%@) to shared container", profileID)
                break
            } catch {
                try? fm.removeItem(at: stagingIndex)
            }
        }
    }

    private static func migrateZayitSearch(profileID: String, legacyRoots: [URL], sharedRoot: URL) {
        let fm = FileManager.default
        let destZayit = OtzariaProfileStorage.applicationSupportRoot(base: sharedRoot, component: .zayitSearch, profileID: profileID)

        if fm.fileExists(atPath: destZayit.path) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyZayit = OtzariaProfileStorage.applicationSupportRoot(base: legacyBase, component: .zayitSearch, profileID: profileID)
            guard fm.fileExists(atPath: legacyZayit.path) else { continue }

            let stagingZayit = destZayit.deletingLastPathComponent().appendingPathComponent(destZayit.lastPathComponent + ".migrating")
            do {
                try fm.createDirectory(at: destZayit.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingZayit)
                try fm.copyItem(at: legacyZayit, to: stagingZayit)
                try fm.moveItem(at: stagingZayit, to: destZayit)
                NSLog("ITorahSharedContainer: Successfully migrated Zayit search index (%@) to shared container", profileID)
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

        if fm.fileExists(atPath: destLexical.path) {
            return
        }

        for legacyBase in legacyRoots {
            let legacyLexical = legacyBase.appendingPathComponent("Otzaria/SearchResources/lexical.db")
            guard fm.fileExists(atPath: legacyLexical.path) else { continue }

            let stagingLexical = destDir.appendingPathComponent("lexical.db.migrating")
            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? fm.removeItem(at: stagingLexical)
                try fm.copyItem(at: legacyLexical, to: stagingLexical)
                try fm.moveItem(at: stagingLexical, to: destLexical)
                NSLog("ITorahSharedContainer: Successfully migrated lexical database to shared container")
                break
            } catch {
                try? fm.removeItem(at: stagingLexical)
            }
        }
    }
}

// MARK: - Cross-Process File Lock

/// Lightweight Darwin flock-based locking mechanism for cross-process synchronization.
public enum ITorahStorageLock {
    public static func withLock<T>(name: String, block: () throws -> T) rethrows -> T {
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
