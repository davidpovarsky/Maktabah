import Foundation
import SQLite3

/// Real filesystem transactions and SQLite validation. This is a focused
/// installer control, not production-corpus, Settings UI, or device acceptance.
@main enum LibraryRecoveryControls {
    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ message: String) { description = message }
    }

    private static let fm = FileManager.default

    private struct Fixture {
        let storage: OtzariaDatabaseStorage
        let oldBytes: Data
        let newBytes: Data
        let oldManifest: Data
        let userDataURL: URL
        let userDataBytes: Data
        let prepared: OtzariaPreparedDatabaseInstallation
        let installer = OtzariaDatabaseInstaller()

        func promote() throws { _ = try installer.promote(prepared, storage: storage) }

        func requireOld() throws {
            try require(Data(contentsOf: storage.finalDatabaseURL) == oldBytes, "Previous database bytes changed")
            try require(Data(contentsOf: storage.installationManifestURL) == oldManifest, "Previous release identity changed")
            try require(!fm.fileExists(atPath: storage.pendingInstallationManifestURL.path), "Abandoned pending identity survived rollback")
        }

        func requireNew() throws {
            try require(Data(contentsOf: storage.finalDatabaseURL) == newBytes, "New database bytes changed")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(OtzariaDatabaseInstallationManifest.self,
                                              from: Data(contentsOf: storage.installationManifestURL))
            try require(manifest.releaseID == prepared.release.id, "Committed release differs")
            try require(manifest.databaseFileSize == Int64(newBytes.count), "Committed database size differs")
        }

        func requireClean() throws {
            for url in [storage.previousDatabaseURL, storage.pendingInstallationManifestURL,
                        storage.previousInstallationManifestURL] {
                try require(!fm.fileExists(atPath: url.path), "Unexpected transaction remnant: \(url.lastPathComponent)")
            }
        }
    }

    static func main() {
        let cases: [(String, () throws -> Void)] = [
            ("manifest_commit_failure_retains_rollback", manifestCommitFailure),
            ("unrecorded_replacement_restores_old_identity", unrecordedReplacement),
            ("missing_final_restores_old_identity", missingFinal),
            ("malformed_pending_identity_rolls_back", malformedPending),
            ("valid_pending_recovers_forward", validPending),
            ("committed_manifest_recovers_forward", committedManifest),
            ("cleanup_failure_retains_commit_marker", cleanupFailure),
            ("normal_update_preserves_user_store", normalUpdate),
            ("failed_pending_write_restores_old_identity", failedPendingWrite),
        ]
        var failed = 0
        for (name, control) in cases {
            do {
                try control()
                emit(["case": name, "status": "PASS"])
            } catch {
                failed += 1
                emit(["case": name, "status": "FAIL", "error": String(describing: error)])
            }
        }
        emit(["scope": "real-filesystem-SQLite-component", "passed": cases.count - failed,
              "failed": failed, "skipped": 0, "ui_acceptance": false])
        exit(failed == 0 ? 0 : 1)
    }

    private static func emit(_ value: [String: Any]) {
        let bytes = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        print(String(decoding: bytes, as: UTF8.self))
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw Failure(message) }
    }

    private static func database(_ url: URL, label: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let db else { throw Failure("Cannot create isolated SQLite fixture") }
        defer { sqlite3_close(db) }
        let sql = "CREATE TABLE book(id INTEGER PRIMARY KEY, title TEXT); CREATE TABLE line(id INTEGER PRIMARY KEY); CREATE TABLE category(id INTEGER PRIMARY KEY); INSERT INTO book VALUES(1, '\(label)');"
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw Failure("Cannot populate isolated SQLite fixture") }
    }

    private static func release(_ id: Int64, version: Int) -> OtzariaLibraryRelease {
        let name = "seforim-schema\(version == 32 ? 6 : 7).db.zst"
        let tag = "v\(version)-20261123094345"
        return .init(id: id, tag: tag, asset: .init(
            id: id + 100, name: name,
            downloadURL: URL(string: "https://github.com/Otzaria/SeforimLibrary/releases/download/\(tag)/\(name)")!,
            compressedSize: 1024, digest: "sha256:" + String(repeating: "a", count: 64), updatedAt: nil
        ))
    }

    private static func withFixture(_ body: (Fixture) throws -> Void) throws {
        let root = fm.temporaryDirectory.appendingPathComponent("OtzariaLibraryRecovery-\(UUID())", isDirectory: true)
        ITorahSharedContainer.sharedRootOverride = root
        defer {
            for name in ["seforim.db.previous", "seforim-installation.json.previous", "seforim-installation.json.installing"] {
                try? fm.setAttributes([.immutable: false], ofItemAtPath: root.appendingPathComponent("Otzaria").appendingPathComponent(name).path)
            }
            ITorahSharedContainer.sharedRootOverride = nil
            try? fm.removeItem(at: root)
        }
        let storage = OtzariaDatabaseStorage(appSupportRoot: root, downloadsRoot: root.appendingPathComponent("Downloads"), profileID: "production")
        try storage.prepareDirectories()
        try database(storage.finalDatabaseURL, label: "old snapshot")
        let staging = storage.uniqueStagingDatabaseURL()
        try database(staging, label: "new snapshot")
        let old = try Data(contentsOf: storage.finalDatabaseURL)
        let new = try Data(contentsOf: staging)
        // Same-sized valid SQLite files expose identity mismatches that a size
        // check or quick_check alone cannot detect.
        try require(old.count == new.count && old != new, "Fixture must use distinct same-sized valid databases")
        try OtzariaDatabaseAccessController.shared.validateDatabase(at: storage.finalDatabaseURL)
        try OtzariaDatabaseAccessController.shared.validateDatabase(at: staging)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let oldManifest = try encoder.encode(OtzariaDatabaseInstallationManifest(release: release(32, version: 32), databaseFileSize: Int64(old.count)))
        try oldManifest.write(to: storage.installationManifestURL)
        let userDataURL = root.appendingPathComponent("user-notes-bookmarks-history.sqlite")
        try database(userDataURL, label: "user data retained")
        let fixture = Fixture(storage: storage, oldBytes: old, newBytes: new, oldManifest: oldManifest,
            userDataURL: userDataURL, userDataBytes: try Data(contentsOf: userDataURL),
            prepared: .init(release: release(40, version: 40), stagingURL: staging,
                            databaseFileSize: Int64(new.count), extractionElapsedSeconds: 0, validationElapsedSeconds: 0))
        try body(fixture)
        try require(Data(contentsOf: fixture.userDataURL) == fixture.userDataBytes, "Unrelated user SQLite bytes changed")
    }

    private static func manifestCommitFailure() throws {
        try withFixture { f in
            try f.promote()
            // Immutable owned obstruction provokes a real metadata move error
            // while the database's parent directory remains writable.
            let obstruction = f.storage.previousInstallationManifestURL
            try Data("owned metadata obstruction".utf8).write(to: obstruction)
            try fm.setAttributes([.immutable: true], ofItemAtPath: obstruction.path)
            var rejected = false
            do { try f.installer.completePromotion(storage: f.storage) } catch { rejected = true }
            try require(rejected, "Metadata commit failure was reported as successful")
            try require(Data(contentsOf: f.storage.previousDatabaseURL) == f.oldBytes, "Metadata failure deleted the rollback database")
            try require(Data(contentsOf: f.storage.installationManifestURL) == f.oldManifest, "Metadata failure changed the prior identity")
            // Exercise the caller's immediate rollback while the filesystem
            // obstruction still exists; it must keep the original identity.
            try f.installer.rollbackPromotion(storage: f.storage)
            try f.requireOld()
            try fm.setAttributes([.immutable: false], ofItemAtPath: obstruction.path)
            try fm.removeItem(at: obstruction)
            try f.requireClean()
        }
    }

    private static func unrecordedReplacement() throws {
        try withFixture { f in
            try f.promote()
            try fm.removeItem(at: f.storage.pendingInstallationManifestURL)
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.requireOld()
            try f.requireClean()
        }
    }

    private static func missingFinal() throws {
        try withFixture { f in
            try f.promote()
            try fm.removeItem(at: f.storage.finalDatabaseURL)
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.requireOld()
            try f.requireClean()
        }
    }

    private static func malformedPending() throws {
        try withFixture { f in
            try f.promote()
            try Data("{}".utf8).write(to: f.storage.pendingInstallationManifestURL)
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.requireOld()
            try f.requireClean()
        }
    }

    private static func validPending() throws {
        try withFixture { f in
            try f.promote()
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.installer.completePromotion(storage: f.storage)
            try f.requireNew()
            try f.requireClean()
        }
    }

    private static func committedManifest() throws {
        try withFixture { f in
            try f.promote()
            try fm.moveItem(at: f.storage.installationManifestURL, to: f.storage.previousInstallationManifestURL)
            try fm.moveItem(at: f.storage.pendingInstallationManifestURL, to: f.storage.installationManifestURL)
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.installer.completePromotion(storage: f.storage)
            try f.requireNew()
            try f.requireClean()
        }
    }

    private static func cleanupFailure() throws {
        try withFixture { f in
            try f.promote()
            try fm.setAttributes([.immutable: true], ofItemAtPath: f.storage.previousDatabaseURL.path)
            try f.installer.completePromotion(storage: f.storage)
            try f.requireNew()
            try require(Data(contentsOf: f.storage.previousInstallationManifestURL) == f.oldManifest,
                        "Cleanup failure lost the committed-state marker")
            try fm.setAttributes([.immutable: false], ofItemAtPath: f.storage.previousDatabaseURL.path)
            try f.installer.recoverInterruptedInstallation(storage: f.storage)
            try f.installer.completePromotion(storage: f.storage)
            try f.requireNew()
            try f.requireClean()
        }
    }

    private static func normalUpdate() throws {
        try withFixture { f in
            try f.promote()
            try f.installer.completePromotion(storage: f.storage)
            try f.requireNew()
            try f.requireClean()
        }
    }

    private static func failedPendingWrite() throws {
        try withFixture { f in
            try fm.createDirectory(at: f.storage.pendingInstallationManifestURL, withIntermediateDirectories: false)
            var rejected = false
            do { try f.promote() } catch { rejected = true }
            try require(rejected, "Pending manifest write failure accepted")
            try f.requireOld()
            try f.requireClean()
        }
    }
}
