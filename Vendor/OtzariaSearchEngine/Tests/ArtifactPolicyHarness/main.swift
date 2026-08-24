import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

let release = OtzariaLibraryRelease(
    id: 22,
    tag: "v22",
    asset: .init(
        id: 220,
        name: "seforim.db.zst",
        downloadURL: URL(string: "https://example.invalid/seforim.db.zst")!,
        compressedSize: 100,
        digest: "sha256:" + String(repeating: "a", count: 64),
        updatedAt: nil
    )
)
let database = OtzariaDatabaseInstallationManifest(release: release, databaseFileSize: 1_000)
let build = OtzariaSearchEngineBuildInfo(
    upstreamRepository: "Otzaria/otzaria_search_engine",
    upstreamBranch: "refactor",
    upstreamCommit: String(repeating: "b", count: 40),
    engineVersion: "0.1.0",
    indexSchemaVersion: 4,
    defaultGenerationOrder: 5,
    semanticEnabled: true,
    semanticSidecarRevision: String(repeating: "c", count: 40),
    syncedAt: "now",
    adapterVersion: "0.1.0",
    resourceHashes: ["dictionary.json": String(repeating: "d", count: 64)]
)
let part = OtzariaSearchArtifactManifest.Part(
    assetName: "part.zst",
    packagedBytes: 400,
    sha256: String(repeating: "e", count: 64),
    destinationPath: "segment.store",
    destinationOffset: 0,
    uncompressedBytes: 800,
    compression: "zstd"
)
func manifest(part: OtzariaSearchArtifactManifest.Part = part) -> OtzariaSearchArtifactManifest {
    OtzariaSearchArtifactManifest(
        formatVersion: 1,
        artifactIdentity: "identity",
        sourceDatabase: .init(
            repository: OtzariaLibraryRelease.repository,
            releaseTag: release.tag,
            releaseID: release.id,
            assetID: release.asset.id,
            assetName: release.asset.name,
            sourceAssetDigest: release.asset.digest!,
            compressedBytes: release.asset.compressedSize,
            databaseBytes: 1_000,
            databaseSHA256: String(repeating: "f", count: 64),
            bookCount: 2,
            documentCount: 3
        ),
        lexicalEngine: .init(
            repository: build.upstreamRepository,
            commit: build.upstreamCommit,
            engineVersion: build.engineVersion,
            indexSchemaVersion: build.indexSchemaVersion,
            defaultGenerationOrder: build.defaultGenerationOrder,
            tantivyVersion: "0.26.1",
            adapterVersion: build.adapterVersion,
            semanticSidecarRevision: build.semanticSidecarRevision
        ),
        resources: ["dictionary.json": .init(version: nil, bytes: 1, sha256: String(repeating: "d", count: 64))],
        lexicalArtifact: .init(
            documentCount: 3,
            sourceCount: 2,
            catalogueHash: "catalogue",
            extractedBytes: 800,
            packagedBytes: 400,
            fileCount: 1,
            segmentsBeforeOptimize: 2,
            segmentsAfterOptimize: 1,
            parts: [part]
        ),
        semantic: nil
    )
}

try OtzariaSearchArtifactPolicy.validate(manifest(), database: database, databaseBytes: 1_000, build: build)
require(OtzariaSearchArtifactPolicy.validateSafeRelativePath("a/b.store"), "safe nested path rejected")
require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("../escape"), "path traversal accepted")
require(!OtzariaSearchArtifactPolicy.validateSafeRelativePath("C:/escape"), "drive path accepted")
require(
    OtzariaSearchArtifactPolicy.requiredInstallCapacity(
        manifest: manifest(), alreadyDownloadedBytes: 100, existingFinalBytes: 999
    ) == 300 + 800 + OtzariaSearchArtifactPolicy.safetyReserve,
    "prebuilt capacity must use package/staging bytes, not DB or old-index multipliers"
)

var rejected = false
do {
    let bad = OtzariaSearchArtifactManifest.Part(
        assetName: part.assetName,
        packagedBytes: part.packagedBytes,
        sha256: part.sha256,
        destinationPath: "../escape",
        destinationOffset: 0,
        uncompressedBytes: part.uncompressedBytes,
        compression: part.compression
    )
    try OtzariaSearchArtifactPolicy.validate(manifest(part: bad), database: database, databaseBytes: 1_000, build: build)
} catch { rejected = true }
require(rejected, "unsafe package path must be rejected")

print("Otzaria search artifact manifest/storage/path tests passed")
