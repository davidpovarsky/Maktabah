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
let staleManagedIdentity = OtzariaIndexBuildIdentity(
    database: .init(databasePath: "/old/container/seforim.db", fileSize: 1_000, modificationTime: 1),
    upstreamCommit: build.upstreamCommit,
    engineVersion: build.engineVersion,
    indexSchemaVersion: build.indexSchemaVersion,
    defaultGenerationOrder: build.defaultGenerationOrder,
    adapterVersion: build.adapterVersion,
    resourceHashes: build.resourceHashes,
    catalogueHash: "catalogue",
    semanticArtifactIdentity: .init(
        modelID: "stale", modelSHA256: String(repeating: "1", count: 64),
        corpusIdentity: "old", sidecarRevision: build.semanticSidecarRevision,
        embeddingDimension: 384
    )
)
require(
    OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(
        staleManagedIdentity,
        currentDatabase: .init(databasePath: "/new/container/seforim.db", fileSize: 1_000, modificationTime: 99),
        build: build
    ),
    "managed v22 identity was invalidated by container path, mtime, or stale semantic registration"
)
require(
    !OtzariaSearchArtifactPolicy.managedIdentityMatchesCanonicalData(
        staleManagedIdentity,
        currentDatabase: .init(databasePath: "/new/container/seforim.db", fileSize: 999, modificationTime: 99),
        build: build
    ),
    "managed identity accepted a different canonical database size"
)
require(
    OtzariaSearchArtifactPolicy.managedDiscoveryDisposition(
        trustedArtifactIdentity: nil,
        availableArtifactIdentity: "A"
    ) == .available,
    "fresh install was not classified as available"
)
require(
    OtzariaSearchArtifactPolicy.managedDiscoveryDisposition(
        trustedArtifactIdentity: "A",
        availableArtifactIdentity: "A"
    ) == .repairRequired,
    "same trusted artifact was offered as a new download"
)
require(
    OtzariaSearchArtifactPolicy.managedDiscoveryDisposition(
        trustedArtifactIdentity: "A",
        availableArtifactIdentity: "B"
    ) == .updateAvailable,
    "different artifact was not classified as an update"
)
let fullRequest = OtzariaSearchRequest(
    query: "לחתוך צנון בסכין בשרי",
    mode: .advanced,
    facets: ["/"],
    limit: 25,
    offset: 3,
    order: .relevance,
    distance: 4,
    negativeQuery: "אסור",
    negativeDistance: 2,
    scope: .sameSection,
    negativeScope: .sameParagraph,
    wordMatchMode: .atLeast,
    wordMatchCount: 3,
    customSpacing: ["0-1": "2"],
    negativeCustomSpacing: ["0-1": "1"],
    alternativeWords: ["0": ["לקצוץ"]],
    negativeAlternativeWords: ["0": ["מותר"]],
    searchOptions: ["לחתוך_0": ["קידומות": true, "כתיב מלא/חסר": true]],
    negativeSearchOptions: ["אסור_0": ["סיומות": true]],
    matchNikud: true,
    matchTaamim: true,
    grouping: .identicalText
)
let fullRequestJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fullRequest)) as! [String: Any]
require(fullRequestJSON["mode"] as? String == "advanced", "advanced mode was not sent upstream")
require(fullRequestJSON["order"] as? String == "relevance", "ranking order was dropped")
require(fullRequestJSON["negativeQuery"] as? String == "אסור", "negative query was dropped")
require(fullRequestJSON["wordMatchMode"] as? String == "atLeast", "word match mode was dropped")
require(fullRequestJSON["wordMatchCount"] as? Int == 3, "word match count was dropped")
require((fullRequestJSON["customSpacing"] as? [String: Any])?["0-1"] as? String == "2", "custom spacing was dropped")
require((fullRequestJSON["alternativeWords"] as? [String: Any])?["0"] as? [String] == ["לקצוץ"], "alternatives were dropped")
require(fullRequestJSON["grouping"] as? String == "identicalText", "grouping was dropped")

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

if CommandLine.arguments.count == 2 {
    let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let captured = try JSONDecoder().decode(
        OtzariaSearchArtifactManifest.self,
        from: Data(contentsOf: fixtureURL)
    )
    let source = captured.sourceDatabase
    let capturedRelease = OtzariaLibraryRelease(
        id: source.releaseID,
        tag: source.releaseTag,
        asset: .init(
            id: source.assetID,
            name: source.assetName,
            downloadURL: URL(string: "https://example.invalid/\(source.assetName)")!,
            compressedSize: source.compressedBytes,
            digest: source.sourceAssetDigest,
            updatedAt: nil
        )
    )
    let capturedDatabase = OtzariaDatabaseInstallationManifest(
        release: capturedRelease,
        databaseFileSize: source.databaseBytes
    )
    let capturedEngine = captured.lexicalEngine
    let capturedBuild = OtzariaSearchEngineBuildInfo(
        upstreamRepository: capturedEngine.repository,
        upstreamBranch: "refactor",
        upstreamCommit: capturedEngine.commit,
        engineVersion: capturedEngine.engineVersion,
        indexSchemaVersion: capturedEngine.indexSchemaVersion,
        defaultGenerationOrder: capturedEngine.defaultGenerationOrder,
        semanticEnabled: true,
        semanticSidecarRevision: capturedEngine.semanticSidecarRevision,
        syncedAt: "captured-fixture",
        adapterVersion: capturedEngine.adapterVersion,
        resourceHashes: captured.resources.mapValues(\.sha256)
    )
    try OtzariaSearchArtifactPolicy.validate(
        captured,
        database: capturedDatabase,
        databaseBytes: source.databaseBytes,
        build: capturedBuild
    )
    require(captured.lexicalArtifact.parts.count == 14, "captured release part count changed")
    require(captured.lexicalArtifact.fileCount == 8, "captured extracted file count changed")

    let mismatched = OtzariaSearchArtifactManifest(
        formatVersion: captured.formatVersion,
        artifactIdentity: captured.artifactIdentity,
        sourceDatabase: captured.sourceDatabase,
        lexicalEngine: captured.lexicalEngine,
        resources: captured.resources,
        lexicalArtifact: .init(
            documentCount: captured.lexicalArtifact.documentCount,
            sourceCount: captured.lexicalArtifact.sourceCount,
            catalogueHash: captured.lexicalArtifact.catalogueHash,
            extractedBytes: captured.lexicalArtifact.extractedBytes,
            packagedBytes: captured.lexicalArtifact.packagedBytes,
            fileCount: 10,
            segmentsBeforeOptimize: captured.lexicalArtifact.segmentsBeforeOptimize,
            segmentsAfterOptimize: captured.lexicalArtifact.segmentsAfterOptimize,
            parts: captured.lexicalArtifact.parts
        ),
        semantic: captured.semantic
    )
    do {
        try OtzariaSearchArtifactPolicy.validate(
            mismatched,
            database: capturedDatabase,
            databaseBytes: source.databaseBytes,
            build: capturedBuild
        )
        fatalError("published file-count mismatch was accepted")
    } catch let error as OtzariaSearchArtifactError {
        require(
            error == .malformedManifest(
                "inconsistent extracted file layout: declaredFiles=10 representedPaths=8"
            ),
            "published mismatch did not report the exact failed invariant"
        )
    }
}

print("Otzaria search artifact manifest/storage/path tests passed")
