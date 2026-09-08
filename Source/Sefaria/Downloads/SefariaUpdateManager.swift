import Foundation
import ZIPFoundation

actor SefariaUpdateManager {
    private struct BundleRequest: Encodable, Sendable { let books: [String] }
    private struct BundleResponse: Decodable, Sendable {
        let bundleArray: [String]
        let downloadSize: Int64
    }
    private struct PendingUpdate {
        let manifest: SefariaLastUpdatedManifest
        let titles: Set<String>
        let packages: Set<String>
        let destinations: [String: Set<String>]
    }

    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let paths: SefariaOfflinePaths
    private var cancelled = false

    init(configuration: SefariaNetworkConfiguration, client: SefariaHTTPClient, paths: SefariaOfflinePaths) {
        self.configuration = configuration
        self.client = client
        self.paths = paths
    }

    func availableUpdates() async throws -> OfflineUpdateSummary {
        let update = try await pendingUpdate()
        return .init(changedWorkCount: update.titles.count, affectedPackageIDs: update.packages)
    }

    func snapshot(for titles: Set<String>) async throws -> [String: String] {
        let manifest = try await fetchLastUpdated()
        guard SefariaExportContract.supportedSchemas.contains(manifest.schemaVersion) else {
            throw LibraryBackendError.unsupportedSchema(found: manifest.schemaVersion,
                supported: SefariaExportContract.supportedSchemas.sorted())
        }
        return manifest.titles.filter { titles.contains($0.key) }
    }

    func update(progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        cancelled = false
        let pending = try await pendingUpdate()
        guard !pending.titles.isEmpty else { return }
        try checkCancellation()
        progress(.init(phase: .preparing, packageID: nil, completedBytes: 0, totalBytes: 0))
        let makeBundleURL = try configuration.readonlyURL(path: "/makeBundle", queryItems: [
            URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
        ])
        let response = try await requestBundle(url: makeBundleURL, books: pending.titles.sorted())
        let transaction = paths.staging.appendingPathComponent("update-\(UUID().uuidString)", isDirectory: true)
        let payload = transaction.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: transaction) }

        var completed: Int64 = 0
        for (index, path) in response.bundleArray.enumerated() {
            try checkCancellation()
            let url = try remoteBundleURL(path)
            let (temporary, http) = try await client.download(url: url)
            let archive = transaction.appendingPathComponent("bundle-\(index).zip")
            try FileManager.default.moveItem(at: temporary, to: archive)
            try SefariaArchiveValidator.validate(archive)
            try FileManager.default.unzipItem(at: archive, to: payload)
            completed += max(0, http.expectedContentLength)
            progress(.init(phase: .downloading, packageID: nil, completedBytes: completed,
                totalBytes: response.downloadSize))
        }
        let updatedBooks = try SefariaArchiveValidator.bookArchives(in: payload)
        try checkCancellation()
        progress(.init(phase: .installing, packageID: nil, completedBytes: completed,
            totalBytes: response.downloadSize))
        let installedTitles = try replaceInstalledBooks(with: updatedBooks, destinations: pending.destinations)
        try updateState(manifest: pending.manifest, titles: installedTitles, destinations: pending.destinations)
        progress(.init(phase: .finished, packageID: nil, completedBytes: response.downloadSize,
            totalBytes: response.downloadSize))
    }

    func cancel() { cancelled = true }

    private func pendingUpdate() async throws -> PendingUpdate {
        let manifest = try await fetchLastUpdated()
        guard SefariaExportContract.supportedSchemas.contains(manifest.schemaVersion) else {
            throw LibraryBackendError.unsupportedSchema(found: manifest.schemaVersion,
                supported: SefariaExportContract.supportedSchemas.sorted())
        }
        let state = loadState()
        let packageManifest = try await fetchPackages()
        var changed = Set<String>()
        var affected = Set<String>()
        var destinations: [String: Set<String>] = [:]
        for (id, packageState) in state.packages {
            guard let package = packageManifest.first(where: { $0.en == id }) else { continue }
            let desired = package.indexes.map { Set($0) } ?? Set(manifest.titles.keys)
            let installedUpdates = packageState.titleUpdates ?? [:]
            let packageChanges = desired.filter { title in
                guard let remote = manifest.titles[title] else { return false }
                return installedUpdates[title] != remote
            }
            if !packageChanges.isEmpty {
                changed.formUnion(packageChanges)
                affected.insert(id)
                for title in packageChanges { destinations[title, default: []].insert(id) }
            }
        }
        return PendingUpdate(manifest: manifest, titles: changed, packages: affected,
            destinations: destinations)
    }

    private func fetchLastUpdated() async throws -> SefariaLastUpdatedManifest {
        let path = "\(SefariaExportContract.rootPath(schema: SefariaExportContract.currentSchema))/last_updated.json"
        return try await client.get(SefariaLastUpdatedManifest.self,
            url: configuration.readonlyURL(path: path))
    }

    private func fetchPackages() async throws -> [SefariaPackageManifestEntry] {
        let path = "\(SefariaExportContract.rootPath(schema: SefariaExportContract.currentSchema))/packages.json"
        return try await client.get([SefariaPackageManifestEntry].self,
            url: configuration.readonlyURL(path: path))
    }

    private func requestBundle(url: URL, books: [String]) async throws -> BundleResponse {
        while true {
            try checkCancellation()
            let (data, response) = try await client.postData(url: url, body: BundleRequest(books: books))
            if response.statusCode == 202 {
                try await Task.sleep(nanoseconds: 3_000_000_000)
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

    private func replaceInstalledBooks(
        with updates: [URL],
        destinations: [String: Set<String>]
    ) throws -> Set<String> {
        let manager = FileManager.default
        guard let walker = manager.enumerator(at: paths.packages, includingPropertiesForKeys: nil) else {
            throw LibraryBackendError.unavailableOffline
        }
        var installedByName: [String: [URL]] = [:]
        for case let url as URL in walker where url.pathExtension.lowercased() == "zip" {
            installedByName[url.lastPathComponent, default: []].append(url)
        }
        var installed = Set<String>()
        for update in updates {
            let title = update.deletingPathExtension().lastPathComponent
            var targets = installedByName[update.lastPathComponent] ?? []
            for packageID in destinations[title] ?? [] {
                let target = paths.packages.appendingPathComponent(
                    SefariaOfflinePaths.safeComponent(packageID), isDirectory: true
                ).appendingPathComponent(update.lastPathComponent)
                if !targets.contains(target) { targets.append(target) }
            }
            for target in targets {
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let staged = target.deletingLastPathComponent()
                    .appendingPathComponent(".update-\(UUID().uuidString).zip")
                try manager.copyItem(at: update, to: staged)
                if manager.fileExists(atPath: target.path) {
                    _ = try manager.replaceItemAt(target, withItemAt: staged)
                } else {
                    try manager.moveItem(at: staged, to: target)
                }
                installed.insert(title)
            }
        }
        try? manager.removeItem(at: paths.expandedBooks)
        return installed
    }

    private func updateState(
        manifest: SefariaLastUpdatedManifest,
        titles: Set<String>,
        destinations: [String: Set<String>]
    ) throws {
        var state = loadState()
        for id in state.packages.keys {
            guard var package = state.packages[id] else { continue }
            var timestamps = package.titleUpdates ?? [:]
            for title in titles where destinations[title]?.contains(id) == true {
                timestamps[title] = manifest.titles[title]
            }
            package.titleUpdates = timestamps
            state.packages[id] = package
        }
        try saveState(state)
    }

    private func loadState() -> SefariaInstalledState {
        guard let data = try? Data(contentsOf: paths.state),
              let state = try? JSONDecoder().decode(SefariaInstalledState.self, from: data) else {
            return SefariaInstalledState()
        }
        return state
    }

    private func saveState(_ state: SefariaInstalledState) throws {
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: paths.state, options: .atomic)
    }

    private func checkCancellation() throws {
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
    }
}
