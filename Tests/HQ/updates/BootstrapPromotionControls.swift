import Foundation

private enum ControlFailure: Error { case acceptedUnrecordedUpdate, rollbackChangedOldLibrary }

@main struct BootstrapPromotionControls {
    static func main() {
        do {
            try run()
        } catch {
            print("FAIL \(error)")
            exit(1)
        }
    }

    private static func run() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("OtzariaBootstrapPromotion-\(UUID())", isDirectory: true)
        ITorahSharedContainer.sharedRootOverride = root
        defer {
            ITorahSharedContainer.sharedRootOverride = nil
            try? FileManager.default.removeItem(at: root)
        }
        let storage = OtzariaDatabaseStorage(
            appSupportRoot: root, downloadsRoot: root.appendingPathComponent("Downloads"), profileID: "production"
        )
        try storage.prepareDirectories()
        let oldBytes = Data("previous validated payload".utf8)
        let newBytes = Data("new validated payload".utf8)
        let oldManifest = Data("previous verified manifest".utf8)
        try oldBytes.write(to: storage.finalDatabaseURL)
        try oldManifest.write(to: storage.installationManifestURL)
        let staging = storage.uniqueStagingDatabaseURL()
        try newBytes.write(to: staging)
        // A directory at the pending-manifest destination provokes an actual atomic write failure.
        try FileManager.default.createDirectory(at: storage.pendingInstallationManifestURL, withIntermediateDirectories: false)
        let release = OtzariaLibraryRelease(id: 42, tag: "v40-control", asset: .init(
            id: 7, name: "seforim-schema7.db.zst",
            downloadURL: URL(string: "https://example.invalid/seforim-schema7.db.zst")!,
            compressedSize: Int64(newBytes.count), digest: nil, updatedAt: nil
        ))
        let prepared = OtzariaPreparedDatabaseInstallation(
            release: release, stagingURL: staging, databaseFileSize: Int64(newBytes.count),
            extractionElapsedSeconds: 0, validationElapsedSeconds: 0
        )
        do {
            _ = try OtzariaDatabaseInstaller().promote(prepared, storage: storage)
            throw ControlFailure.acceptedUnrecordedUpdate
        } catch OtzariaDatabaseBootstrapError.atomicInstallFailed {
            guard try Data(contentsOf: storage.finalDatabaseURL) == oldBytes,
                  try Data(contentsOf: storage.installationManifestURL) == oldManifest,
                  !FileManager.default.fileExists(atPath: storage.previousDatabaseURL.path),
                  !FileManager.default.fileExists(atPath: storage.pendingInstallationManifestURL.path) else {
                throw ControlFailure.rollbackChangedOldLibrary
            }
            print("PASS a failed manifest write rolled database and release identity back together")
        }
    }
}
