import Foundation

struct OtzariaSearchArtifactReleaseClient: Sendable {
    static let repository = "davidpovarsky/Maktabah"
    static let tagPrefix = "otzaria-search-data-"
    static let manifestAssetName = "otzaria-search-manifest.json"
    static let releasesURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases?per_page=30"
    )!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func matchingArtifact(
        database: OtzariaDatabaseInstallationManifest,
        databaseBytes: Int64,
        build: OtzariaSearchEngineBuildInfo
    ) async throws -> OtzariaResolvedSearchArtifact {
        let (data, response) = try await session.data(for: request(url: Self.releasesURL))
        try requireSuccess(response)
        return try await matchingArtifact(
            releasesData: data,
            database: database,
            databaseBytes: databaseBytes,
            build: build
        ) { url in
            let (manifestData, manifestResponse) = try await session.data(
                for: request(url: url)
            )
            try requireSuccess(manifestResponse)
            return manifestData
        }
    }

    func matchingArtifact(
        releasesData: Data,
        database: OtzariaDatabaseInstallationManifest,
        databaseBytes: Int64,
        build: OtzariaSearchEngineBuildInfo,
        manifestLoader: @escaping @Sendable (URL) async throws -> Data
    ) async throws -> OtzariaResolvedSearchArtifact {
        let releases: [Release]
        do {
            releases = try JSONDecoder().decode([Release].self, from: releasesData)
        } catch {
            throw OtzariaSearchArtifactError.downloadFailed("malformed GitHub release response")
        }

        for release in releases where !release.draft && release.tagName.hasPrefix(Self.tagPrefix) {
            guard let manifestAsset = release.assets.first(where: { $0.name == Self.manifestAssetName }) else {
                continue
            }
            OtzariaIndexFileLogger.log(
                "search artifact discovery candidate releaseTag=\(release.tagName) " +
                "releaseID=\(release.id) manifestAsset=\(manifestAsset.name)"
            )
            do {
                let manifestData = try await manifestLoader(manifestAsset.browserDownloadURL)
                let manifest = try JSONDecoder().decode(
                    OtzariaSearchArtifactManifest.self,
                    from: manifestData
                )
                let artifact = manifest.lexicalArtifact
                OtzariaIndexFileLogger.log(
                    "search artifact manifest decoded stage=production-policy " +
                    "releaseTag=\(release.tagName) manifestAsset=\(manifestAsset.name) " +
                    "formatVersion=\(manifest.formatVersion) " +
                    "artifactIdentity=\(String(manifest.artifactIdentity.prefix(12))) " +
                    "parts=\(artifact.parts.count) files=\(artifact.fileCount) " +
                    "extractedBytes=\(artifact.extractedBytes) packagedBytes=\(artifact.packagedBytes)"
                )
                try OtzariaSearchArtifactPolicy.validate(
                    manifest,
                    database: database,
                    databaseBytes: databaseBytes,
                    build: build
                )
                OtzariaIndexFileLogger.log(
                    "search artifact manifest validated stage=production-policy " +
                    "releaseTag=\(release.tagName) artifactIdentity=\(String(manifest.artifactIdentity.prefix(12)))"
                )
                var assets: [String: URL] = [:]
                for asset in release.assets { assets[asset.name] = asset.browserDownloadURL }
                var partURLs: [String: URL] = [:]
                for part in manifest.lexicalArtifact.parts {
                    guard let url = assets[part.assetName] else {
                        throw OtzariaSearchArtifactError.missingPart(part.assetName)
                    }
                    partURLs[part.assetName] = url
                }
                return OtzariaResolvedSearchArtifact(
                    releaseID: release.id,
                    releaseTag: release.tagName,
                    manifest: manifest,
                    partURLs: partURLs
                )
            } catch let error as OtzariaSearchArtifactError {
                if case .incompatible = error { continue }
                OtzariaIndexFileLogger.logError(
                    "search artifact manifest validation failed stage=production-policy " +
                    "releaseTag=\(release.tagName) manifestAsset=\(manifestAsset.name)",
                    error: error
                )
                throw error
            } catch {
                OtzariaIndexFileLogger.logError(
                    "search artifact manifest decode failed stage=decode " +
                    "releaseTag=\(release.tagName) manifestAsset=\(manifestAsset.name)",
                    error: error
                )
                throw OtzariaSearchArtifactError.malformedManifest(error.localizedDescription)
            }
        }
        throw OtzariaSearchArtifactError.unavailable
    }
}

private extension OtzariaSearchArtifactReleaseClient {
    struct Release: Decodable {
        let id: Int64
        let tagName: String
        let draft: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case id, draft, assets
            case tagName = "tag_name"
        }
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Maktabah-iOS-Otzaria-Search", forHTTPHeaderField: "User-Agent")
        return request
    }

    func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OtzariaSearchArtifactError.downloadFailed("HTTP \(status)")
        }
    }
}
