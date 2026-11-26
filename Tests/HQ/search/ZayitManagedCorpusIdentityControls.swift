import Foundation

private enum ControlFailure: Error { case acceptedWrongManagedCorpus, acceptedUnreadableIdentity }

@main struct ZayitManagedCorpusIdentityControls {
    static func main() {
        do {
            try run()
        } catch {
            print("FAIL \(error)")
            exit(1)
        }
    }

    private static func run() throws {
        let fixture = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ZayitCorpus-\(UUID())")
        ITorahSharedContainer.sharedRootOverride = root
        defer {
            ITorahSharedContainer.sharedRootOverride = nil
            try? FileManager.default.removeItem(at: root)
        }
        let storage = try OtzariaDatabaseStorage()
        try storage.prepareDirectories()
        let data = Data(repeating: 0, count: 32)
        try data.write(to: storage.finalDatabaseURL)
        let release = try OtzariaLibraryReleaseClient.parseLatestRelease(
            data: Data(contentsOf: fixture.appendingPathComponent("official-v40-release.json")),
            expectedReleaseID: 455390662,
            multipartManifestData: Data(contentsOf: fixture.appendingPathComponent("official-v40-manifest.json"))
        )
        let actual = OtzariaDatabaseInstallationManifest(release: release, databaseFileSize: Int64(data.count))
        let packageDigest = release.asset.digest!.replacingOccurrences(of: "sha256:", with: "")
        let archiveDigest = release.archiveDigest!.replacingOccurrences(of: "sha256:", with: "")
        func package(digest: String) -> ZayitSearchArtifactManifest {
            .init(manifestSchemaVersion: 1, artifactIdentity: "fixture", component: "zayitIndex", version: "fixture",
                requiredDatabase: .init(releaseTag: release.tag, compressedAssetSHA256: digest,
                                        canonicalSHA256: "fixture", bytes: Int64(data.count)),
                engine: .init(indexSchemaVersion: 2, builderVersion: "fixture", builderCommit: "fixture",
                              upstreamCommit: "fixture", tantivyVersion: "fixture"),
                counts: .init(books: 0, lines: 0, documents: 0, splitLines: 0),
                stableBookIdentity: .init(field: "fixture", fallback: "fixture"),
                sharedLexicalDatabase: .init(version: "fixture", sha256: "fixture", bytes: 0),
                extractedBytes: 0, packagedBytes: 0, parts: [])
        }
        let probe = ZayitCompatibilityProbe()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(actual).write(to: storage.installationManifestURL)
        try probe.validateCompatibility(package(digest: packageDigest), databaseURL: storage.finalDatabaseURL)
        do {
            try probe.validateCompatibility(package(digest: archiveDigest), databaseURL: storage.finalDatabaseURL)
            throw ControlFailure.acceptedWrongManagedCorpus
        } catch ZayitSearchDistributionError.incompatible {}
        print("PASS managed ISO-8601 installation accepts its own published-asset digest and rejects the archive digest")

        try JSONEncoder().encode(actual).write(to: storage.installationManifestURL)
        try probe.validateCompatibility(package(digest: packageDigest), databaseURL: storage.finalDatabaseURL)
        print("PASS older numeric installation date remains supported")

        try Data("bad JSON".utf8).write(to: storage.installationManifestURL)
        do {
            try probe.validateCompatibility(package(digest: packageDigest), databaseURL: storage.finalDatabaseURL)
            throw ControlFailure.acceptedUnreadableIdentity
        } catch is DecodingError {}
        let external = root.appendingPathComponent("external.db")
        try data.write(to: external)
        try probe.validateCompatibility(package(digest: packageDigest), databaseURL: external)
        print("PASS unreadable managed ownership is rejected without applying managed metadata to external databases")
    }
}
