import CryptoKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OtzariaLibraryReleaseClient: Sendable {
    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/latest"
    )!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatestRelease() async throws -> OtzariaLibraryRelease {
        if OtzariaDataProfileRegistry.activeProfileID != OtzariaDataProfileRegistry.productionID {
            let profile = try OtzariaDataProfileRegistry.requireActiveProfile()
            return OtzariaLibraryRelease(
                id: profile.sourceDatabase.releaseID,
                tag: profile.sourceDatabase.releaseTag,
                asset: .init(
                    id: Int64(profile.profileVersion),
                    name: profile.databaseAssetName,
                    downloadURL: profile.databaseDownloadURL,
                    compressedSize: profile.databaseCompressedBytes,
                    digest: "sha256:\(profile.databaseCompressedSHA256)",
                    updatedAt: nil
                )
            )
        }
        let lookup = try Self.releaseLookup(environment: ProcessInfo.processInfo.environment)
        var request = URLRequest(url: lookup.url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Maktabah-iOS-Otzaria-Library", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OtzariaDatabaseBootstrapError.releaseLookupFailed("non-HTTP response")
            }
            guard http.statusCode == 200 else {
                throw OtzariaDatabaseBootstrapError.releaseLookupFailed("HTTP \(http.statusCode)")
            }
            let selected = try Self.selectRelease(data: data, expectedReleaseID: lookup.expectedReleaseID)
            var manifestData: Data?
            if selected.isMultipart {
                var manifestRequest = URLRequest(url: selected.asset.browserDownloadURL)
                manifestRequest.timeoutInterval = 30
                manifestRequest.cachePolicy = .reloadIgnoringLocalCacheData
                manifestRequest.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
                manifestRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                manifestRequest.setValue("Maktabah-iOS-Otzaria-Library", forHTTPHeaderField: "User-Agent")
                let (stream, manifestResponse) = try await session.bytes(for: manifestRequest)
                defer { stream.task.cancel() }
                guard let manifestHTTP = manifestResponse as? HTTPURLResponse,
                      manifestHTTP.statusCode == 200 else {
                    throw OtzariaDatabaseBootstrapError.releaseLookupFailed("multipart manifest HTTP response")
                }
                guard manifestResponse.expectedContentLength < 0
                        || manifestResponse.expectedContentLength == selected.asset.size else {
                    throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("multipart manifest content length differs")
                }
                var bytes = Data()
                bytes.reserveCapacity(Int(selected.asset.size))
                for try await byte in stream {
                    try Task.checkCancellation()
                    guard Int64(bytes.count) < selected.asset.size else {
                        throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("multipart manifest exceeds declared byte limit")
                    }
                    bytes.append(byte)
                }
                manifestData = bytes
            }
            return try Self.parseLatestRelease(
                data: data, expectedReleaseID: lookup.expectedReleaseID, multipartManifestData: manifestData
            )
        } catch let error as OtzariaDatabaseBootstrapError {
            throw error
        } catch {
            throw OtzariaDatabaseBootstrapError.releaseLookupFailed(error.localizedDescription)
        }
    }

    /// Every phase of a native observation uses the same selected official release.
    /// Release builds and ordinary app launches always retain the latest-release lookup.
    static func releaseLookup(environment: [String: String]) throws -> (url: URL, expectedReleaseID: Int64?) {
        #if DEBUG
        if let phase = environment["OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE"],
           ["cancel", "install", "restore"].contains(phase),
           let rawID = environment["OTZARIA_NATIVE_BOOTSTRAP_RELEASE_ID"] {
            guard environment["OTZARIA_DATA_PROFILE"] == OtzariaDataProfileRegistry.productionID,
                  let id = Int64(rawID), id > 0, String(id) == rawID else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                    "native production observation requires a canonical positive release ID"
                )
            }
            let url = URL(string: "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/\(id)")!
            return (url, id)
        }
        #endif
        return (latestReleaseURL, nil)
    }

    static func parseLatestRelease(
        data: Data,
        expectedReleaseID: Int64? = nil,
        multipartManifestData: Data? = nil
    ) throws -> OtzariaLibraryRelease {
        let selected = try selectRelease(data: data, expectedReleaseID: expectedReleaseID)
        var release = OtzariaLibraryRelease(
            id: selected.payload.id, tag: selected.payload.tagName, asset: selected.asset.record
        )
        guard selected.isMultipart else { return release }
        guard let manifestData = multipartManifestData,
              Int64(manifestData.count) == selected.asset.size,
              let expectedManifestSHA = OtzariaLibraryRelease.sha256Value(selected.asset.digest) else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("multipart manifest bytes are missing or differ")
        }
        let actualManifestSHA = SHA256.hash(data: manifestData)
            .map { String(format: "%02x", $0) }.joined()
        guard actualManifestSHA == expectedManifestSHA else {
            throw OtzariaDatabaseBootstrapError.digestMismatch(
                expected: expectedManifestSHA, actual: actualManifestSHA
            )
        }
        let manifest: MultipartPayload
        do {
            manifest = try JSONDecoder().decode(MultipartPayload.self, from: manifestData)
        } catch {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("malformed multipart manifest")
        }
        guard manifest.schemaVersion == 1, manifest.archive == selected.archiveName,
              manifest.size > 0, OtzariaLibraryRelease.sha256Value("sha256:" + manifest.sha256) != nil,
              manifest.githubAssetLimit == 2_147_483_648,
              manifest.partSizeLimit > 0, manifest.partSizeLimit < manifest.githubAssetLimit,
              !manifest.parts.isEmpty, manifest.parts.count <= 1_000 else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("unsupported multipart manifest contract")
        }
        var parts: [OtzariaLibraryRelease.Asset] = []
        for (index, part) in manifest.parts.enumerated() {
            let expectedName = manifest.archive + String(format: ".part-%03d", index)
            let matches = selected.payload.assets.filter { $0.name == part.name }
            guard part.name == expectedName, matches.count == 1, let asset = matches.first,
                  part.size > 0, part.size <= manifest.partSizeLimit,
                  part.size < manifest.githubAssetLimit, asset.size == part.size,
                  index == manifest.parts.count - 1 || part.size == manifest.partSizeLimit,
                  OtzariaLibraryRelease.sha256Value(asset.digest)
                    == OtzariaLibraryRelease.sha256Value("sha256:" + part.sha256),
                  OtzariaLibraryRelease.sha256Value(asset.digest) != nil else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                    "multipart asset differs from the same official release"
                )
            }
            parts.append(asset.record)
        }
        release.multipart = .init(
            manifest: selected.asset.record, archiveName: manifest.archive,
            compressedSize: manifest.size, digest: "sha256:" + manifest.sha256, parts: parts
        )
        _ = try release.validatedMultipart()
        return release
    }

    private static func selectRelease(
        data: Data, expectedReleaseID: Int64?
    ) throws -> (payload: ReleasePayload, asset: AssetPayload, isMultipart: Bool, archiveName: String) {
        let payload: ReleasePayload
        do {
            payload = try JSONDecoder().decode(ReleasePayload.self, from: data)
        } catch {
            throw OtzariaDatabaseBootstrapError.releaseLookupFailed(
                "malformed GitHub JSON (\(error.localizedDescription))"
            )
        }
        guard payload.id > 0, !payload.tagName.isEmpty else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("missing release ID or tag")
        }
        if let expectedReleaseID, payload.id != expectedReleaseID {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                "returned release ID differs from the frozen native observation"
            )
        }
        let manifestSuffix = ".manifest.json"
        let schemaAssets = payload.assets.compactMap { asset -> (Int, Bool, String, AssetPayload)? in
            let multipart = asset.name.hasSuffix(manifestSuffix)
            let archiveName = multipart ? String(asset.name.dropLast(manifestSuffix.count)) : asset.name
            guard let version = OtzariaLibraryRelease.schemaVersion(inAssetName: archiveName) else { return nil }
            return (version, multipart, archiveName, asset)
        }
        let selected = schemaAssets.max {
            if $0.0 != $1.0 { return $0.0 < $1.0 }
            if $0.2 != $1.2 { return $0.2 < $1.2 }
            // Preserve a direct archive when both transports describe the same schema.
            return $0.1 && !$1.1
        }
        let asset = selected?.3
            ?? payload.assets.first { $0.name == OtzariaLibraryRelease.databaseAssetName }
            ?? payload.assets.first { $0.name == OtzariaLibraryRelease.databaseAssetName + manifestSuffix }
        guard let asset else { throw OtzariaDatabaseBootstrapError.databaseAssetMissing }
        let isMultipart = asset.name.hasSuffix(manifestSuffix)
        let archiveName = isMultipart ? String(asset.name.dropLast(manifestSuffix.count)) : asset.name
        guard payload.assets.filter({ $0.name == asset.name }).count == 1,
              asset.id > 0, asset.size > 0, asset.browserDownloadURL.scheme == "https" else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                "the database asset is missing its unique ID, HTTPS URL, or size"
            )
        }
        guard let digest = asset.digest,
              digest.lowercased().hasPrefix("sha256:"),
              digest.count == 71, digest.dropFirst(7).allSatisfy({ $0.isHexDigit }) else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("malformed SHA-256 digest")
        }
        if isMultipart {
            guard asset.size <= 1_048_576,
                  OtzariaLibraryRelease.isOfficialAssetURL(
                    asset.browserDownloadURL, tag: payload.tagName, name: asset.name
                  ) else {
                throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("invalid official multipart manifest asset")
            }
        }
        return (payload, asset, isMultipart, archiveName)
    }

}

private extension OtzariaLibraryReleaseClient {
    struct MultipartPayload: Decodable {
        let schemaVersion: Int
        let archive: String
        let size: Int64
        let sha256: String
        let partSizeLimit: Int64
        let githubAssetLimit: Int64
        let parts: [Part]

        struct Part: Decodable {
            let name: String
            let size: Int64
            let sha256: String
        }
    }

    struct ReleasePayload: Decodable {
        let id: Int64
        let tagName: String
        let assets: [AssetPayload]

        enum CodingKeys: String, CodingKey {
            case id
            case tagName = "tag_name"
            case assets
        }
    }

    struct AssetPayload: Decodable {
        let id: Int64
        let name: String
        let browserDownloadURL: URL
        let size: Int64
        let digest: String?
        let updatedAt: Date?

        var record: OtzariaLibraryRelease.Asset {
            .init(id: id, name: name, downloadURL: browserDownloadURL,
                  compressedSize: size, digest: digest, updatedAt: updatedAt)
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case browserDownloadURL = "browser_download_url"
            case size
            case digest
            case updatedAt = "updated_at"
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(Int64.self, forKey: .id)
            name = try values.decode(String.self, forKey: .name)
            browserDownloadURL = try values.decode(URL.self, forKey: .browserDownloadURL)
            size = try values.decode(Int64.self, forKey: .size)
            digest = try values.decodeIfPresent(String.self, forKey: .digest)

            if let rawDate = try values.decodeIfPresent(String.self, forKey: .updatedAt) {
                updatedAt = ISO8601DateFormatter().date(from: rawDate)
            } else {
                updatedAt = nil
            }
        }
    }
}
