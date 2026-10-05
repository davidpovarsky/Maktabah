import Foundation
import ZIPFoundation

struct SefariaDownloadedBundle: Sendable {
    let transaction: URL
    let payload: URL
    let bookArchives: [URL]
    let downloadSize: Int64
}

actor SefariaBundleDownloadService {
    private struct BundleRequest: Encodable, Sendable { let books: [String] }
    private struct BundleResponse: Decodable, Sendable {
        let bundleArray: [String]
        let downloadSize: Int64
    }

    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let paths: SefariaOfflinePaths

    init(configuration: SefariaNetworkConfiguration, client: SefariaHTTPClient, paths: SefariaOfflinePaths) {
        self.configuration = configuration
        self.client = client
        self.paths = paths
    }

    func download(
        workKeys: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws -> SefariaDownloadedBundle {
        guard !workKeys.isEmpty else {
            throw LibraryBackendError.invalidResponse("no works were requested")
        }
        let makeBundleURL = try configuration.readonlyURL(path: "/makeBundle", queryItems: [
            URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
        ])
        progress(.init(phase: .preparing, packageID: nil, completedBytes: 0, totalBytes: 0))
        let response = try await requestBundle(url: makeBundleURL, books: workKeys.sorted())
        guard !response.bundleArray.isEmpty else {
            throw LibraryBackendError.invalidResponse("makeBundle returned no archives")
        }

        let transaction = paths.staging.appendingPathComponent("bundle-\(UUID().uuidString)", isDirectory: true)
        let payload = transaction.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        do {
            var completed: Int64 = 0
            for (index, path) in response.bundleArray.enumerated() {
                try Task.checkCancellation()
                let url = try remoteBundleURL(path)
                let (temporary, http) = try await client.download(url: url)
                let archive = transaction.appendingPathComponent("bundle-\(index).zip")
                try FileManager.default.moveItem(at: temporary, to: archive)
                try SefariaArchiveValidator.validate(archive)
                progress(.init(phase: .validating, packageID: nil, completedBytes: completed,
                    totalBytes: response.downloadSize))
                try FileManager.default.unzipItem(at: archive, to: payload)
                completed += max(0, http.expectedContentLength)
                progress(.init(phase: .downloading, packageID: nil, completedBytes: completed,
                    totalBytes: response.downloadSize))
            }
            let archives = try SefariaArchiveValidator.bookArchives(in: payload)
            return SefariaDownloadedBundle(transaction: transaction, payload: payload,
                bookArchives: archives, downloadSize: response.downloadSize)
        } catch {
            try? FileManager.default.removeItem(at: transaction)
            throw error
        }
    }

    private func requestBundle(url: URL, books: [String]) async throws -> BundleResponse {
        while true {
            try Task.checkCancellation()
            let (data, response) = try await client.postData(url: url, body: BundleRequest(books: books))
            if response.statusCode == 202 {
                try await Task.sleep(for: .seconds(3))
                continue
            }
            do { return try JSONDecoder().decode(BundleResponse.self, from: data) }
            catch { throw LibraryBackendError.invalidResponse("invalid makeBundle response: \(error)") }
        }
    }

    private func remoteBundleURL(_ path: String) throws -> URL {
        if let absolute = URL(string: path), absolute.scheme != nil { return absolute }
        return try configuration.readonlyURL(path: path)
    }
}
