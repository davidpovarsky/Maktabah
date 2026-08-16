import CryptoKit
import Foundation

/// Maintains the optional SeforimMagicIndexer lexical database outside the
/// application bundle. Search always keeps working with the last validated
/// file (or without morphology) when release discovery/download fails.
actor OtzariaMagicDictionaryManager {
    static let shared = OtzariaMagicDictionaryManager()

    private struct Release: Decodable {
        let tagName: String
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private struct Asset: Decodable {
        let id: UInt64
        let name: String
        let size: UInt64
        let browserDownloadURL: URL
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case id, name, size, digest
            case browserDownloadURL = "browser_download_url"
        }
    }

    private struct Marker: Codable {
        let tagName: String
        let assetID: UInt64
        let assetURL: URL
        let size: UInt64
        let sha256: String
        let installedAt: Date
        var checkedAt: Date
    }

    private let releaseURL = URL(
        string: "https://api.github.com/repos/Otzaria/SeforimMagicIndexer/releases/latest"
    )!
    private let refreshInterval: TimeInterval = 24 * 60 * 60

    nonisolated var databaseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Otzaria/SearchResources", isDirectory: true)
            .appendingPathComponent("lexical.db")
    }

    nonisolated var validatedDatabaseURL: URL? {
        let url = databaseURL
        let markerURL = url.appendingPathExtension("release.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let marker = Self.decodeMarker(at: markerURL),
              (try? Self.sha256(url)) == marker.sha256 else { return nil }
        return url
    }

    /// Returns true only when the installed database changed.
    func refreshIfNeeded(force: Bool = false) async throws -> Bool {
        let markerURL = databaseURL.appendingPathExtension("release.json")
        var marker = Self.decodeMarker(at: markerURL)
        if !force, let checkedAt = marker?.checkedAt,
           Date().timeIntervalSince(checkedAt) < refreshInterval,
           validatedDatabaseURL != nil {
            return false
        }

        let release: Release = try await json(request: request(for: releaseURL))
        guard let asset = release.assets.first(where: { $0.name == "lexical.db" }) else {
            throw OtzariaSearchError.invalidEngineResponse("Latest SeforimMagicIndexer release has no lexical.db asset")
        }
        try requireHTTPS(asset.browserDownloadURL)

        if marker?.assetID == asset.id,
           marker?.size == asset.size,
           FileManager.default.fileExists(atPath: databaseURL.path),
           try Self.sha256(databaseURL) == marker?.sha256 {
            marker?.checkedAt = Date()
            if let marker { try atomicWrite(marker, to: markerURL) }
            return false
        }

        let expectedHash = try await expectedSHA256(for: asset, assets: release.assets)
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let partURL = databaseURL.appendingPathExtension("part")
        if FileManager.default.fileExists(atPath: partURL.path) {
            try FileManager.default.removeItem(at: partURL)
        }

        let (temporaryURL, response) = try await URLSession.shared.download(for: request(for: asset.browserDownloadURL))
        try validateHTTP(response)
        try FileManager.default.moveItem(at: temporaryURL, to: partURL)
        do {
            let values = try partURL.resourceValues(forKeys: [.fileSizeKey])
            let actualSize = UInt64(values.fileSize ?? 0)
            guard actualSize == asset.size else {
                throw OtzariaSearchError.invalidEngineResponse(
                    "lexical.db size mismatch: expected \(asset.size), received \(actualSize)"
                )
            }
            let actualHash = try Self.sha256(partURL)
            guard actualHash.caseInsensitiveCompare(expectedHash) == .orderedSame else {
                throw OtzariaSearchError.invalidEngineResponse("lexical.db SHA-256 mismatch")
            }

            if FileManager.default.fileExists(atPath: databaseURL.path) {
                _ = try FileManager.default.replaceItemAt(databaseURL, withItemAt: partURL)
            } else {
                try FileManager.default.moveItem(at: partURL, to: databaseURL)
            }
            try atomicWrite(Marker(
                tagName: release.tagName,
                assetID: asset.id,
                assetURL: asset.browserDownloadURL,
                size: asset.size,
                sha256: actualHash,
                installedAt: Date(),
                checkedAt: Date()
            ), to: markerURL)
            return true
        } catch {
            try? FileManager.default.removeItem(at: partURL)
            throw error
        }
    }

    private func expectedSHA256(for asset: Asset, assets: [Asset]) async throws -> String {
        if let digest = asset.digest?.lowercased(), digest.hasPrefix("sha256:") {
            let value = String(digest.dropFirst("sha256:".count))
            if value.count == 64 { return value }
        }
        let checksumNames = ["lexical.db.sha256", "SHA256SUMS", "sha256sums.txt"]
        guard let checksum = assets.first(where: { checksumNames.contains($0.name) }) else {
            throw OtzariaSearchError.invalidEngineResponse(
                "SeforimMagicIndexer release does not publish a SHA-256 digest for lexical.db"
            )
        }
        let (data, response) = try await URLSession.shared.data(for: request(for: checksum.browserDownloadURL))
        try validateHTTP(response)
        guard data.count <= 1_024 * 1_024,
              let text = String(data: data, encoding: .utf8),
              let hash = text
                .split(whereSeparator: \.isNewline)
                .first(where: { $0.contains("lexical.db") || text.split(whereSeparator: \.isWhitespace).count == 1 })?
                .split(whereSeparator: \.isWhitespace).first,
              hash.count == 64 else {
            throw OtzariaSearchError.invalidEngineResponse("Invalid lexical.db checksum asset")
        }
        return String(hash)
    }

    nonisolated private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_024 * 1_024), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func request(for url: URL) throws -> URLRequest {
        try requireHTTPS(url)
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Maktabah-Otzaria-Search", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func requireHTTPS(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw OtzariaSearchError.invalidEngineResponse("Refusing a non-HTTPS lexical database URL")
        }
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw OtzariaSearchError.invalidEngineResponse("lexical.db server returned a non-success response")
        }
    }

    private func json<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    nonisolated private static func decodeMarker(at url: URL) -> Marker? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Marker.self, from: data)
    }

    private func atomicWrite<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
