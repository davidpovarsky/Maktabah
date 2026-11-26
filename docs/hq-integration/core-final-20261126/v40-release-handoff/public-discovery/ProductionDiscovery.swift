import CryptoKit
import Foundation

@main
struct ProductionDiscovery {
    struct NativeInstallReceipt: Decodable {
        let passed: Bool
        let artifactIdentity: String
        let consumerBuild: OtzariaSearchEngineBuildInfo
    }

    @MainActor
    static func main() async throws {
        do {
            try await observeProductionDiscovery()
        } catch {
            let technical = (error as? OtzariaSearchArtifactError)?.failureReason ?? error.localizedDescription
            print("FAIL original production release discovery \(technical)")
            Foundation.exit(1)
        }
    }

    @MainActor
    private static func observeProductionDiscovery() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let fixtureRoot = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        ITorahSharedContainer.sharedRootOverride = fixtureRoot
        let storage = try OtzariaDatabaseStorage()
        let databaseURL = storage.finalDatabaseURL
        try require(OtzariaDataProfileRegistry.activeProfileID == "production", "The production profile is required")
        try require(databaseURL == fixtureRoot.appendingPathComponent("Otzaria/seforim.db"), "Wrong real managed DB path")
        let databaseInstall = try Data(contentsOf: storage.installationManifestURL)
        let databaseDecoder = JSONDecoder()
        databaseDecoder.dateDecodingStrategy = .iso8601
        let database = try databaseDecoder.decode(OtzariaDatabaseInstallationManifest.self, from: databaseInstall)
        let databaseBytes = try Int64(databaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        let sourceDigest = "sha256:ab51577bad2f457e24ab5f28082ba830597951ab5738a39652dec821e1dff2e3"
        try require(database.repository == "Otzaria/SeforimLibrary" && database.releaseTag == "v40-20261123094345"
                    && database.releaseID == 455390662 && database.assetID == 782942035
                    && database.assetName == "seforim-schema7.db.zst.manifest.json"
                    && database.digest == sourceDigest && database.compressedSize == 589
                    && databaseBytes == 4_355_063_808, "Wrong genuine installed v40 library identity")

        let evidence = root.appendingPathComponent("docs/hq-integration/core-final-20261126", isDirectory: true)
        let native = try Data(contentsOf: evidence.appendingPathComponent("native-v40-otzaria/ACTUAL_NATIVE_INSTALL.json"))
        try require(digest(native) == "31212cc8f943ffaea0f83811a3e4a6b7571b80c1ea80eea570a993d7650c7b7c", "D5 installed ABI receipt mismatch")
        let receipt = try JSONDecoder().decode(NativeInstallReceipt.self, from: native)
        try require(receipt.passed && receipt.consumerBuild.upstreamCommit == "d5d59d1269bdf87fb0a6901cf31941726a0c699b"
                    && receipt.consumerBuild.indexSchemaVersion == 4 && receipt.consumerBuild.defaultGenerationOrder == 5,
                    "The actual already verified d5 ABI is required")

        let handoff = evidence.appendingPathComponent("v40-release-handoff", isDirectory: true)
        let otzariaBytes = try Data(contentsOf: handoff.appendingPathComponent("otzaria/otzaria-search-manifest.json"))
        let zayitBytes = try Data(contentsOf: handoff.appendingPathComponent("zayit/zayit-search-manifest.json"))
        try require(digest(otzariaBytes) == "c10824ac3cc38514b64cb59e0c588c8b56d5d86ac3213bcd56bd75048cfb2b8b"
                    && digest(zayitBytes) == "577176375f735af240d8a1e84f0a1ad23bf18018ae4c0f716e8acb142d8d8691",
                    "The release manifests must be the verified original native-install package inputs")
        let originalOtzaria = try JSONDecoder().decode(OtzariaSearchArtifactManifest.self, from: otzariaBytes)
        let originalZayit = try JSONDecoder().decode(ZayitSearchArtifactManifest.self, from: zayitBytes)
        let upstreamZayit = try String(contentsOf: root.appendingPathComponent("Vendor/ZayitSearchPort/Upstream/UPSTREAM_COMMIT"), encoding: .utf8)
        let expectedZayitABI = ZayitSearchArtifactManifest.currentIndexSchemaVersion
        try require(expectedZayitABI == 2 && originalZayit.engine.indexSchemaVersion == expectedZayitABI
                    && upstreamZayit.contains(originalZayit.engine.upstreamCommit),
                    "Wrong original Zayit index schema or engine pin")

        let otzaria = try await OtzariaSearchArtifactReleaseClient().matchingArtifact(
            database: database, databaseBytes: databaseBytes, build: receipt.consumerBuild
        )
        let otzariaTag = "otzaria-search-data-v40-20261123094345-f8fea8efcac5"
        try require(otzaria.releaseID == 458964363 && otzaria.releaseTag == otzariaTag
                    && otzaria.manifest == originalOtzaria && otzaria.manifest.artifactIdentity == receipt.artifactIdentity,
                    "Original Otzaria client selected a different release or manifest")
        try checkPartURLs(otzaria.partURLs, actualAssetNames: originalOtzaria.lexicalArtifact.parts.map(\.assetName), expectedCount: 15, tag: otzariaTag)
        print("PASS original Otzaria HTTPS client selected \(otzaria.releaseTag)")

        let zayit = try await ZayitSearchArtifactService.shared.observeProductionReleaseForSmoke(databaseURL: databaseURL)
        let zayitTag = "zayit-search-data-v40-20261123094345-17cabb80e86a"
        try require(zayit.tag == zayitTag && zayit.manifest == originalZayit,
                    "Original Zayit client selected a different release or manifest")
        let uploadPartURLs = zayit.partURLs.filter { asset in originalZayit.parts.contains { $0.assetName == asset.key } }
        try checkPartURLs(uploadPartURLs, actualAssetNames: originalZayit.parts.map(\.assetName), expectedCount: 74, tag: zayitTag)
        print("PASS original Zayit HTTPS client selected \(zayit.tag)")

        let result: [String: Any] = [
            "passed": true,
            "sourceCommit": "44100265611efb96a33d7f650f1b845a6a7a4e1e",
            "profile": "production",
            "releaseListURL": OtzariaSearchArtifactReleaseClient.releasesURL.absoluteString,
            "managedDatabaseBytes": databaseBytes, "managedDatabaseManifestSHA256": digest(databaseInstall),
            "libraryReleaseID": database.releaseID, "libraryAssetID": database.assetID,
            "libraryMultipartManifestSHA256": String(sourceDigest.dropFirst("sha256:".count)),
            "otzaria": [
                "tag": otzaria.releaseTag, "releaseID": otzaria.releaseID,
                "artifactIdentity": otzaria.manifest.artifactIdentity,
                "equalsVerifiedPackageManifest": true,
                "verifiedManifestSHA256": digest(otzariaBytes),
                "consumerNativeInstallReceiptSHA256": digest(native),
                "consumerCommit": receipt.consumerBuild.upstreamCommit,
                "generationOrder": receipt.consumerBuild.defaultGenerationOrder,
                "indexSchemaVersion": receipt.consumerBuild.indexSchemaVersion,
                "verifiedPartURLs": otzaria.partURLs.count,
            ],
            "zayit": [
                "tag": zayit.tag, "artifactIdentity": zayit.manifest.artifactIdentity,
                "equalsVerifiedPackageManifest": true,
                "verifiedManifestSHA256": digest(zayitBytes),
                "expectedIndexSchemaVersion": expectedZayitABI,
                "builderCommit": zayit.manifest.engine.builderCommit,
                "upstreamCommit": zayit.manifest.engine.upstreamCommit,
                "verifiedPartURLs": uploadPartURLs.count,
            ],
            "performedIndexPartDownloads": false,
            "performedSimulatorOrUI": false,
            "scope": "real anonymous HTTPS release discovery and native client compatibility only",
        ]
        let output = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: root.appendingPathComponent("RESULT.json"), options: [.atomic])
    }

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ detail: String) throws {
        guard condition() else { throw NSError(domain: "ProductionReleaseDiscovery", code: 1, userInfo: [NSLocalizedDescriptionKey: detail]) }
    }

    private static func checkPartURLs(_ parts: [String: URL], actualAssetNames: [String], expectedCount: Int, tag: String) throws {
        let base = "https://github.com/davidpovarsky/Maktabah/releases/download/\(tag)/"
        try require(Set(parts.keys)==Set(actualAssetNames) && parts.count==expectedCount,
                    "Wrong number of original release part URLs")
        try require(parts.allSatisfy { name, url in url.absoluteString == base + name },
                    "Asset URL escapes the selected release")
    }
}
