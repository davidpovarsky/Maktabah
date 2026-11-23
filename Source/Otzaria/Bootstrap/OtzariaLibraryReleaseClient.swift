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
            return try Self.parseLatestRelease(data: data, expectedReleaseID: lookup.expectedReleaseID)
        } catch let error as OtzariaDatabaseBootstrapError {
            throw error
        } catch {
            throw OtzariaDatabaseBootstrapError.releaseLookupFailed(error.localizedDescription)
        }
    }

    /// A native install observation may explicitly request its frozen official release.
    /// Release builds and ordinary app launches always retain the latest-release lookup.
    static func releaseLookup(environment: [String: String]) throws -> (url: URL, expectedReleaseID: Int64?) {
        #if DEBUG
        if environment["OTZARIA_NATIVE_BOOTSTRAP_ACCEPTANCE"] == "install",
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
        expectedReleaseID: Int64? = nil
    ) throws -> OtzariaLibraryRelease {
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
        let schemaAssets = payload.assets.compactMap { asset -> (Int, AssetPayload)? in
            guard let version = OtzariaLibraryRelease.schemaVersion(inAssetName: asset.name) else {
                return nil
            }
            return (version, asset)
        }
        let asset = schemaAssets.max {
            if $0.0 != $1.0 { return $0.0 < $1.0 }
            return $0.1.name < $1.1.name
        }?.1 ?? payload.assets.first(where: {
            $0.name == OtzariaLibraryRelease.databaseAssetName
        })
        guard let asset else {
            throw OtzariaDatabaseBootstrapError.databaseAssetMissing
        }
        guard asset.id > 0, asset.size > 0, asset.browserDownloadURL.scheme == "https" else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata(
                "the database asset is missing its ID, HTTPS URL, or size"
            )
        }
        guard let digest = asset.digest,
              digest.lowercased().hasPrefix("sha256:"),
              digest.count == 71,
              digest.dropFirst(7).allSatisfy({ $0.isHexDigit }) else {
            throw OtzariaDatabaseBootstrapError.invalidAssetMetadata("malformed SHA-256 digest")
        }

        return OtzariaLibraryRelease(
            id: payload.id,
            tag: payload.tagName,
            asset: .init(
                id: asset.id,
                name: asset.name,
                downloadURL: asset.browserDownloadURL,
                compressedSize: asset.size,
                digest: digest,
                updatedAt: asset.updatedAt
            )
        )
    }
}

private extension OtzariaLibraryReleaseClient {
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
