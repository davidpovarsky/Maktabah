import Foundation
import SQLite3

enum OtzariaPrebuiltSearchAcceptanceRunner {
    private struct Check: Codable {
        let mode: String
        let query: String
        let count: UInt32
        let firstFilePath: String?
    }

    private struct Report: Codable {
        let passed: Bool
        let phase: String
        let artifactIdentity: String
        let documentCount: UInt64
        let sourceCount: Int
        let checks: [Check]
        let golden: GoldenCheck?
        let localIndexingRan: Bool
        let stagingAbsent: Bool
        let nativeDownloadRan: Bool
        let resumedDownloadBytes: Int64
        let productionDiscoveryRan: Bool
        let productionValidatorRan: Bool
        let selectedReleaseTag: String?
        let error: String?
    }

    private struct GoldenCheck: Codable {
        let query: String
        let normalizedQuery: String
        let orderedResultIDs: [UInt64]
        let stableSourceIDs: [String]
        let references: [String]
        let highlightedTopResults: Int
    }

    @MainActor
    static func run(environment: [String: String]) async {
        guard let manifestPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_MANIFEST"],
              let databasePath = environment["OTZARIA_PREBUILT_ACCEPTANCE_DATABASE"],
              let resultPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_RESULT"] else { return }
        let partsPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_PARTS"]
        let releasesPath = environment["OTZARIA_PREBUILT_ACCEPTANCE_RELEASES"]
        let releaseBaseURL = environment["OTZARIA_PREBUILT_ACCEPTANCE_RELEASE_BASE_URL"]
            .flatMap { $0.isEmpty ? nil : $0 }
        guard partsPath != nil || releaseBaseURL != nil else { return }
        let phase = environment["OTZARIA_PREBUILT_ACCEPTANCE_PHASE"] ?? "install"
        var identity = "unknown"
        var nativeDownloadRan = false
        var resumedDownloadBytes: Int64 = 0
        var productionDiscoveryRan = false
        var productionValidatorRan = false
        var selectedReleaseTag: String?
        do {
            let localManifest = try JSONDecoder().decode(
                OtzariaSearchArtifactManifest.self,
                from: Data(contentsOf: URL(fileURLWithPath: manifestPath))
            )
            identity = localManifest.artifactIdentity
            let databaseBytes = ((try FileManager.default.attributesOfItem(atPath: databasePath)[.size]) as? NSNumber)?.int64Value ?? 0
            let source = localManifest.sourceDatabase
            let sourceRelease = OtzariaLibraryRelease(
                id: source.releaseID,
                tag: source.releaseTag,
                asset: .init(
                    id: source.assetID,
                    name: source.assetName,
                    downloadURL: URL(string: "https://example.invalid/\(source.assetName)")!,
                    compressedSize: source.compressedBytes,
                    digest: source.sourceAssetDigest.isEmpty ? nil : source.sourceAssetDigest,
                    updatedAt: nil
                )
            )
            let databaseManifest = OtzariaDatabaseInstallationManifest(
                release: sourceRelease,
                databaseFileSize: databaseBytes
            )
            let build = try OtzariaSearchEngineBridge.buildInfo()
            try OtzariaSearchArtifactPolicy.validate(
                localManifest,
                database: databaseManifest,
                databaseBytes: databaseBytes,
                build: build
            )
            productionValidatorRan = true

            let resolved: OtzariaResolvedSearchArtifact
            if let releaseBaseURL, let base = URL(string: releaseBaseURL), let releasesPath {
                let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
                let releasesData = try Data(contentsOf: URL(fileURLWithPath: releasesPath))
                let discovered = try await OtzariaSearchArtifactReleaseClient().matchingArtifact(
                    releasesData: releasesData,
                    database: databaseManifest,
                    databaseBytes: databaseBytes,
                    build: build
                ) { requestedURL in
                    guard requestedURL.lastPathComponent == OtzariaSearchArtifactReleaseClient.manifestAssetName else {
                        throw OtzariaSearchArtifactError.missingPart(requestedURL.lastPathComponent)
                    }
                    return manifestData
                }
                guard discovered.releaseTag == base.lastPathComponent,
                      discovered.manifest == localManifest else {
                    throw OtzariaSearchArtifactError.validationFailed(
                        "production release discovery did not select the acceptance manifest"
                    )
                }
                productionDiscoveryRan = true
                selectedReleaseTag = discovered.releaseTag
                resolved = discovered
            } else if releaseBaseURL != nil {
                throw OtzariaSearchArtifactError.validationFailed(
                    "captured production release metadata is required for native download acceptance"
                )
            } else {
                resolved = OtzariaResolvedSearchArtifact(
                    releaseID: 0,
                    releaseTag: "acceptance-local",
                    manifest: localManifest,
                    partURLs: [:]
                )
            }
            let manifest = resolved.manifest
            let storage = try OtzariaSearchArtifactStorage()
            if phase == "install" {
                let parts: [String: URL]
                if releaseBaseURL != nil {
                    let downloader = OtzariaSearchArtifactDownloader()
                    try storage.prepare()
                    let workspace = storage.workspaceURL(artifactIdentity: manifest.artifactIdentity)
                    resumedDownloadBytes = await downloader.existingBytes(
                        manifest: manifest,
                        workspaceURL: workspace
                    )
                    parts = try await downloader.downloadAndVerify(
                        artifact: resolved,
                        workspaceURL: workspace,
                        progress: { _, _ in }
                    )
                    nativeDownloadRan = true
                } else {
                    let root = URL(fileURLWithPath: partsPath!)
                    parts = Dictionary(uniqueKeysWithValues: manifest.lexicalArtifact.parts.map {
                        ($0.assetName, root.appendingPathComponent($0.assetName))
                    })
                }
                _ = try await Task.detached(priority: .utility) {
                    try OtzariaSearchArtifactInstaller().install(
                        artifact: resolved,
                        downloadedParts: parts,
                        databasePath: databasePath,
                        storage: storage,
                        progress: { _, _ in }
                    )
                }.value
                if nativeDownloadRan {
                    let downloader = OtzariaSearchArtifactDownloader()
                    await downloader.cleanup(
                        workspaceURL: storage.workspaceURL(artifactIdentity: manifest.artifactIdentity)
                    )
                }
            }
            let manager = OtzariaSearchIndexManager.shared
            let finalURL = manager.indexURL(for: databasePath)
            let engine = try OtzariaSearchEngineBridge(indexURL: finalURL)
            defer { engine.close() }
            let documentCount = try engine.documentCount()
            let paths = try engine.indexedFilePaths()
            guard documentCount == manifest.lexicalArtifact.documentCount,
                  paths.count == manifest.lexicalArtifact.sourceCount else {
                throw OtzariaSearchArtifactError.validationFailed("portable count mismatch")
            }
            let query = try sampleQuery(databasePath: databasePath)
            var checks: [Check] = []
            for mode in [OtzariaSearchMode.exact, .fuzzy, .advanced] {
                let page = try engine.search(OtzariaSearchRequest(
                    query: query,
                    mode: mode,
                    facets: ["/"],
                    limit: 10
                ))
                guard page.totalCount > 0,
                      page.results.first?.filePath.hasPrefix("otzaria-book:") == true,
                      page.results.first?.text.isEmpty == false else {
                    throw OtzariaSearchArtifactError.validationFailed("\(mode.rawValue) search failed")
                }
                checks.append(Check(
                    mode: mode.rawValue,
                    query: query,
                    count: page.totalCount,
                    firstFilePath: page.results.first?.filePath
                ))
            }
            let goldenQuery = "לחתוך צנון בסכין בשרי"
            let normalizedGolden = try OtzariaSearchEngineBridge.sanitizeQuery(goldenQuery)
            let goldenPage = try engine.search(OtzariaSearchRequest(
                query: goldenQuery,
                mode: .advanced,
                facets: ["/"],
                limit: 25,
                order: .relevance,
                wordMatchMode: .all
            ))
            let orderedIDs = goldenPage.results.map(\.id)
            let stableIDs = goldenPage.results.map(\.filePath)
            let references = goldenPage.results.map(\.reference)
            let highlighted = goldenPage.results.filter {
                $0.text.localizedCaseInsensitiveContains("<b>") ||
                    $0.text.localizedCaseInsensitiveContains("<strong>")
            }.count
            guard !orderedIDs.isEmpty,
                  Set(orderedIDs).count == orderedIDs.count,
                  stableIDs.allSatisfy({ !$0.isEmpty }),
                  references.contains(where: { !$0.isEmpty }),
                  highlighted > 0 else {
                throw OtzariaSearchArtifactError.validationFailed("golden parity result contract failed")
            }
            let golden = GoldenCheck(
                query: goldenQuery,
                normalizedQuery: normalizedGolden,
                orderedResultIDs: orderedIDs,
                stableSourceIDs: stableIDs,
                references: references,
                highlightedTopResults: highlighted
            )
            let stagingAbsent = !FileManager.default.fileExists(
                atPath: storage.stagingURL(databasePath: databasePath).path
            )
            let localIndexingRan = FileManager.default.fileExists(
                atPath: manager.sentinelURL(for: databasePath).path
            ) || FileManager.default.fileExists(
                atPath: manager.buildingIndexURL(for: databasePath).path
            )
            guard stagingAbsent, !localIndexingRan else {
                throw OtzariaSearchArtifactError.validationFailed("local build/staging evidence exists")
            }
            try write(Report(
                passed: true,
                phase: phase,
                artifactIdentity: identity,
                documentCount: documentCount,
                sourceCount: paths.count,
                checks: checks,
                golden: golden,
                localIndexingRan: false,
                stagingAbsent: true,
                nativeDownloadRan: nativeDownloadRan,
                resumedDownloadBytes: resumedDownloadBytes,
                productionDiscoveryRan: productionDiscoveryRan,
                productionValidatorRan: productionValidatorRan,
                selectedReleaseTag: selectedReleaseTag,
                error: nil
            ), path: resultPath)
        } catch {
            try? write(Report(
                passed: false,
                phase: phase,
                artifactIdentity: identity,
                documentCount: 0,
                sourceCount: 0,
                checks: [],
                golden: nil,
                localIndexingRan: false,
                stagingAbsent: false,
                nativeDownloadRan: nativeDownloadRan,
                resumedDownloadBytes: resumedDownloadBytes,
                productionDiscoveryRan: productionDiscoveryRan,
                productionValidatorRan: productionValidatorRan,
                selectedReleaseTag: selectedReleaseTag,
                error: error.localizedDescription
            ), path: resultPath)
        }
    }

    private static func sampleQuery(databasePath: String) throws -> String {
        let database = try SQLiteDatabase(
            path: databasePath,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )
        let lines = try database.fetch(
            query: "SELECT COALESCE(content, '') FROM line WHERE length(content) > 12 ORDER BY bookId, lineIndex LIMIT 100"
        ) { $0.string(at: 0) ?? "" }
        for line in lines {
            if let word = try OtzariaSearchEngineBridge.splitQueryWords(line).first(where: { $0.count >= 4 }) {
                return word
            }
        }
        throw OtzariaSearchArtifactError.validationFailed("no acceptance query")
    }

    private static func write<T: Encodable>(_ value: T, path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}
