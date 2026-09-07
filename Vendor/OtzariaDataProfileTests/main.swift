import Foundation

func require(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError(message) }
}

let production = OtzariaDataProfileRegistry.productionID
let mini = OtzariaDataProfileRegistry.miniTest10ID
let bundled = try JSONDecoder().decode(
    OtzariaDataProfile.self,
    from: Data(contentsOf: URL(fileURLWithPath: "Source/Otzaria/DataProfiles/miniTest10.profile.json"))
)
try bundled.validate()
require(bundled.profileID == mini && bundled.bookIDs.count == 10, "bundled mini profile is invalid")
require(bundled.profileVersion == 2, "bundled mini profile version is not canonical v2")
require(bundled.sharedLexicalDatabase.releaseTag == "v0.3.0", "lexical release is not pinned")

require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [:], embeddedDefault: nil
    ) == production,
    "an ordinary production build must default to production"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [:], embeddedDefault: mini
    ) == mini,
    "an embedded mini build default was not selected"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah"], environment: [OtzariaDataProfileRegistry.environmentKey: production],
        embeddedDefault: mini
    ) == production,
    "environment override did not outrank the embedded default"
)
require(
    OtzariaDataProfileRegistry.resolvedProfileID(
        arguments: ["Maktabah", OtzariaDataProfileRegistry.launchArgument, mini],
        environment: [OtzariaDataProfileRegistry.environmentKey: production], embeddedDefault: production
    ) == mini,
    "launch argument did not have highest precedence"
)

require(
    OtzariaDataProfileCompatibility.matches(
        profileID: nil, profileVersion: nil, activeID: production, activeVersion: 1
    ),
    "legacy production metadata must remain compatible"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: nil, profileVersion: nil, activeID: mini, activeVersion: 1
    ),
    "legacy production metadata leaked into miniTest10"
)
require(
    OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 2, activeID: mini, activeVersion: 2
    ),
    "same miniTest10 profile did not survive relaunch validation"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 2, activeID: production, activeVersion: 1
    ),
    "miniTest10 metadata leaked into production"
)
require(
    !OtzariaDataProfileCompatibility.matches(
        profileID: mini, profileVersion: 1, activeID: mini, activeVersion: 2
    ),
    "mismatched profile version was accepted"
)

let base = URL(fileURLWithPath: "/tmp/profile-tests", isDirectory: true)
let miniDatabase = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .database, profileID: mini
)
let miniOtzaria = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .otzariaSearch, profileID: mini
)
let miniZayit = OtzariaProfileStorage.applicationSupportRoot(
    base: base, component: .zayitSearch, profileID: mini
)
require(miniDatabase.path != miniOtzaria.path && miniOtzaria.path != miniZayit.path,
        "partial component installs must use isolated roots")
require(miniDatabase.path.contains("/Profiles/miniTest10/"), "mini profile root is not namespaced")

// MARK: - ITorahSharedContainer Tests

require(ITorahSharedContainer.appGroupIdentifier == "group.com.davidpovarsky.itorah",
        "canonical iTorah App Group identifier is incorrect")
require(ITorahSharedContainer.chavrusaTextAppGroupIdentifier == "group.com.davidpovarsky.chavrusatext",
        "canonical ChavrusaText App Group identifier is incorrect")

let testContainerDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("itorah-test-\(UUID().uuidString)", isDirectory: true)
ITorahSharedContainer.sharedRootOverride = testContainerDir

let prodDB = ITorahSharedContainer.databaseURL(profileID: production)
let miniDB = ITorahSharedContainer.databaseURL(profileID: mini)
require(prodDB != miniDB, "production and mini databases must not have colliding URLs")
require(prodDB.path.contains("Otzaria") && prodDB.lastPathComponent == "seforim.db", "production db URL path mismatch")
require(miniDB.path.contains("miniTest10") && miniDB.lastPathComponent == "seforim.db", "mini db URL path mismatch")
require(ITorahSharedContainer.downloadsRootURL.path.hasSuffix("Otzaria/Downloads") || ITorahSharedContainer.downloadsRootURL.path.hasSuffix("Otzaria\\Downloads"), "downloads root path mismatch")
require(ITorahSharedContainer.searchResourcesRootURL.path.hasSuffix("Otzaria/SearchResources") || ITorahSharedContainer.searchResourcesRootURL.path.hasSuffix("Otzaria\\SearchResources"), "search resources root path mismatch")

ITorahSharedContainer.sharedRootOverride = nil
try? FileManager.default.removeItem(at: testContainerDir)

// MARK: - Migration & Shared Storage Helpers

#if canImport(SQLite3)
import SQLite3
#endif

func makeTestSQLiteDatabase(at url: URL, tables: [String] = ["book", "line", "category"]) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    #if canImport(SQLite3)
    var db: OpaquePointer?
    if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let db = db {
        for t in tables {
            sqlite3_exec(db, "CREATE TABLE \(t) (id INTEGER PRIMARY KEY, content TEXT);", nil, nil, nil)
        }
        sqlite3_close(db)
    }
    #else
    var data = Data("SQLite format 3\0".utf8)
    data.append(Data(repeating: 0, count: 200))
    try? data.write(to: url)
    #endif
}

func makeCorruptSQLiteDatabase(at url: URL, mode: String = "bad_header") {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if mode == "zero_byte" {
        FileManager.default.createFile(atPath: url.path, contents: Data())
    } else {
        try? Data("NOT_SQLITE_CORRUPT_HEADER_BYTES".utf8).write(to: url)
    }
}

func makeTestDatabaseManifest(at url: URL, profileID: String, size: Int64) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let json: [String: Any] = [
        "profileID": profileID,
        "effectiveProfileID": profileID,
        "databaseFileSize": size
    ]
    if let data = try? JSONSerialization.data(withJSONObject: json) {
        try? data.write(to: url)
    }
}

func makeTestOtzariaIndex(at url: URL, profileID: String) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let meta: [String: Any] = [
        "segments": [["segment_id": "seg-1", "max_doc": 100]],
        "schema": [["name": "text", "type": "text"]]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: meta) {
        try? data.write(to: url.appendingPathComponent("meta.json"))
    }
    try? Data("dummy-seg-store".utf8).write(to: url.appendingPathComponent("seg-1.store"))
    let manifest: [String: Any] = ["profileID": profileID, "effectiveProfileID": profileID]
    if let data = try? JSONSerialization.data(withJSONObject: manifest) {
        try? data.write(to: url.appendingPathComponent("otzaria_prebuilt_installation.json"))
    }
}

func makeTestZayitIndex(at url: URL, profileID: String) {
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let meta: [String: Any] = [
        "segments": [["segment_id": "zayit-1", "max_doc": 50]],
        "schema": [["name": "content", "type": "text"]]
    ]
    if let data = try? JSONSerialization.data(withJSONObject: meta) {
        try? data.write(to: url.appendingPathComponent("meta.json"))
    }
    let zayitMeta: [String: Any] = ["schema_version": 1]
    if let data = try? JSONSerialization.data(withJSONObject: zayitMeta) {
        try? data.write(to: url.appendingPathComponent("zayit-index-metadata.json"))
    }
    try? Data("dummy-zayit-store".utf8).write(to: url.appendingPathComponent("zayit-seg-1.store"))
    let manifest: [String: Any] = ["profileID": profileID, "effectiveProfileID": profileID]
    if let data = try? JSONSerialization.data(withJSONObject: manifest) {
        try? data.write(to: url.deletingLastPathComponent().appendingPathComponent("zayit-installation.json"))
    }
}

func makeTestLexicalDB(at url: URL) {
    makeTestSQLiteDatabase(at: url, tables: ["terms"])
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 200
    let marker: [String: Any] = ["size": size]
    if let data = try? JSONSerialization.data(withJSONObject: marker) {
        try? data.write(to: url.appendingPathExtension("release.json"))
    }
}

func runMigrationTests() {
    let testTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("itorah-mig-suite-\(UUID().uuidString)", isDirectory: true)
    let sharedRoot = testTemp.appendingPathComponent("shared", isDirectory: true)
    let legacyRoot = testTemp.appendingPathComponent("legacy", isDirectory: true)

    defer {
        ITorahSharedContainer.sharedRootOverride = nil
        try? FileManager.default.removeItem(at: testTemp)
    }

    ITorahSharedContainer.sharedRootOverride = sharedRoot

    // MARK: Case A: Empty shared directory, valid legacy directory
    do {
        let legDB = OtzariaProfileStorage.applicationSupportRoot(base: legacyRoot, component: .database, profileID: production)
            .appendingPathComponent("seforim.db")
        makeTestSQLiteDatabase(at: legDB)
        let dbSize = (try? FileManager.default.attributesOfItem(atPath: legDB.path)[.size] as? NSNumber)?.int64Value ?? 200
        makeTestDatabaseManifest(at: legDB.deletingLastPathComponent().appendingPathComponent("seforim-installation.json"), profileID: production, size: dbSize)

        let legSearch = OtzariaProfileStorage.applicationSupportRoot(base: legacyRoot, component: .otzariaSearch, profileID: production)
        makeTestOtzariaIndex(at: legSearch, profileID: production)

        let legZayit = OtzariaProfileStorage.applicationSupportRoot(base: legacyRoot, component: .zayitSearch, profileID: production)
        makeTestZayitIndex(at: legZayit, profileID: production)

        let legLex = legacyRoot.appendingPathComponent("Otzaria/SearchResources/lexical.db")
        makeTestLexicalDB(at: legLex)

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [legacyRoot])

        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        let destSearch = ITorahSharedContainer.componentURL(component: .otzariaSearch, profileID: production)
        let destZayit = ITorahSharedContainer.componentURL(component: .zayitSearch, profileID: production)
        let destLex = ITorahSharedContainer.searchResourcesRootURL.appendingPathComponent("lexical.db")

        require(ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case A: dest DB not valid")
        require(ITorahSharedContainer.isOtzariaSearchValid(at: destSearch, profileID: production), "Case A: dest Otzaria index not valid")
        require(ITorahSharedContainer.isZayitSearchValid(at: destZayit, profileID: production), "Case A: dest Zayit index not valid")
        require(ITorahSharedContainer.isLexicalDatabaseValid(at: destLex), "Case A: dest Lexical DB not valid")

        require(ITorahSharedContainer.isDatabaseValid(at: legDB, profileID: production), "Case A: legacy DB should remain valid")
    }

    // MARK: Case B: Valid shared directory already exists -> no-op
    do {
        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        let destAttrs = try? FileManager.default.attributesOfItem(atPath: destDB.path)
        let origMtime = destAttrs?[.modificationDate] as? Date

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [legacyRoot])

        let newAttrs = try? FileManager.default.attributesOfItem(atPath: destDB.path)
        let newMtime = newAttrs?[.modificationDate] as? Date
        require(origMtime == newMtime, "Case B: existing valid shared DB must not be modified")
    }

    // MARK: Case C: Corrupt shared DB exists, valid legacy exists -> repaired
    do {
        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        makeCorruptSQLiteDatabase(at: destDB, mode: "bad_header")
        require(!ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case C: corrupt DB was not recognized as invalid")

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [legacyRoot])
        require(ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case C: shared DB was not repaired from legacy")
    }

    // MARK: Case D: Valid shared DB exists, corrupt legacy DB exists -> preserved
    do {
        let badLegacyRoot = testTemp.appendingPathComponent("bad_legacy", isDirectory: true)
        let badLegDB = OtzariaProfileStorage.applicationSupportRoot(base: badLegacyRoot, component: .database, profileID: production)
            .appendingPathComponent("seforim.db")
        makeCorruptSQLiteDatabase(at: badLegDB, mode: "zero_byte")

        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        require(ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case D: shared DB must be valid before test")

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [badLegacyRoot])
        require(ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case D: valid shared DB must not be corrupted by bad legacy")
    }

    // MARK: Case E: Both corrupt -> fails safely
    do {
        let bothCorruptShared = testTemp.appendingPathComponent("both_corrupt_shared", isDirectory: true)
        let bothCorruptLegacy = testTemp.appendingPathComponent("both_corrupt_legacy", isDirectory: true)
        ITorahSharedContainer.sharedRootOverride = bothCorruptShared

        let corruptDest = ITorahSharedContainer.databaseURL(profileID: production)
        makeCorruptSQLiteDatabase(at: corruptDest, mode: "bad_header")

        let corruptLeg = OtzariaProfileStorage.applicationSupportRoot(base: bothCorruptLegacy, component: .database, profileID: production)
            .appendingPathComponent("seforim.db")
        makeCorruptSQLiteDatabase(at: corruptLeg, mode: "zero_byte")

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [bothCorruptLegacy])
        require(!ITorahSharedContainer.isDatabaseValid(at: corruptDest, profileID: production), "Case E: corrupt DB must not be marked valid")

        ITorahSharedContainer.sharedRootOverride = sharedRoot
    }

    // MARK: Case F: Interrupted migration with dangling staging -> cleaned up
    do {
        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        let leftoverStaging = destDB.deletingLastPathComponent().appendingPathComponent("seforim.db.migrating.interrupted-test-staging")
        try? Data("leftover-garbage".utf8).write(to: leftoverStaging)
        require(FileManager.default.fileExists(atPath: leftoverStaging.path), "Case F: leftover file must exist initially")

        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [legacyRoot])
        require(!FileManager.default.fileExists(atPath: leftoverStaging.path), "Case F: dangling staging must be cleaned up")
    }

    // MARK: Case G: Concurrent migrations -> serialized, no corruption
    do {
        DispatchQueue.concurrentPerform(iterations: 6) { _ in
            ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [legacyRoot])
        }
        let destDB = ITorahSharedContainer.databaseURL(profileID: production)
        require(ITorahSharedContainer.isDatabaseValid(at: destDB, profileID: production), "Case G: concurrent migrations corrupted destination")
    }

    // MARK: Case H: Multi-profile isolation
    do {
        let isoShared = testTemp.appendingPathComponent("iso_shared", isDirectory: true)
        let isoLegacy = testTemp.appendingPathComponent("iso_legacy", isDirectory: true)
        ITorahSharedContainer.sharedRootOverride = isoShared

        let legMiniDB = OtzariaProfileStorage.applicationSupportRoot(base: isoLegacy, component: .database, profileID: mini)
            .appendingPathComponent("seforim.db")
        makeTestSQLiteDatabase(at: legMiniDB)
        let miniSize = (try? FileManager.default.attributesOfItem(atPath: legMiniDB.path)[.size] as? NSNumber)?.int64Value ?? 200
        makeTestDatabaseManifest(at: legMiniDB.deletingLastPathComponent().appendingPathComponent("seforim-installation.json"), profileID: mini, size: miniSize)

        let legProdDB = OtzariaProfileStorage.applicationSupportRoot(base: isoLegacy, component: .database, profileID: production)
            .appendingPathComponent("seforim.db")
        makeTestSQLiteDatabase(at: legProdDB)
        let prodSize = (try? FileManager.default.attributesOfItem(atPath: legProdDB.path)[.size] as? NSNumber)?.int64Value ?? 200
        makeTestDatabaseManifest(at: legProdDB.deletingLastPathComponent().appendingPathComponent("seforim-installation.json"), profileID: production, size: prodSize)

        // Migrate only mini
        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: mini, customLegacyRoots: [isoLegacy])
        let destMiniDB = ITorahSharedContainer.databaseURL(profileID: mini)
        let destProdDB = ITorahSharedContainer.databaseURL(profileID: production)

        require(ITorahSharedContainer.isDatabaseValid(at: destMiniDB, profileID: mini), "Case H: mini DB must be valid")
        require(!FileManager.default.fileExists(atPath: destProdDB.path), "Case H: production DB must not exist after mini migration")

        // Now migrate production
        ITorahSharedContainer.migrateLegacyDataIfNeeded(profileID: production, customLegacyRoots: [isoLegacy])
        require(ITorahSharedContainer.isDatabaseValid(at: destProdDB, profileID: production), "Case H: production DB must be valid")
        require(ITorahSharedContainer.isDatabaseValid(at: destMiniDB, profileID: mini), "Case H: mini DB must remain valid")

        ITorahSharedContainer.sharedRootOverride = sharedRoot
    }

    // MARK: Case I: Real-device missing container simulation
    do {
        ITorahSharedContainer.sharedRootOverride = nil
        ITorahSharedContainer.simulateRealDeviceMissingContainerForTesting = true

        var caughtExpectedError = false
        do {
            _ = try ITorahSharedContainer.resolveSharedRootURL()
        } catch ITorahSharedContainerError.appGroupUnavailable {
            caughtExpectedError = true
        } catch {
            fatalError("Case I: unexpected error type: \(error)")
        }
        require(caughtExpectedError, "Case I: resolveSharedRootURL must throw appGroupUnavailable when container missing on real device")

        ITorahSharedContainer.simulateRealDeviceMissingContainerForTesting = false
    }
}

runMigrationTests()

print("Otzaria data profile isolation/relaunch/partial/mismatch and ITorahSharedContainer migration tests (Cases A-I) passed")

