import Foundation
import ZIPFoundation

actor SefariaPackageManager: OfflineLibraryProviding {
    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let paths: SefariaOfflinePaths
    private let updates: SefariaUpdateManager
    private var activeInstall: Task<Void, Error>?
    private var didCleanupStaging = false

    init(
        configuration: SefariaNetworkConfiguration = .production,
        client: SefariaHTTPClient = SefariaHTTPClient(),
        paths: SefariaOfflinePaths = SefariaOfflinePaths(),
        updates: SefariaUpdateManager? = nil
    ) {
        self.configuration = configuration
        self.client = client
        self.paths = paths
        self.updates = updates ?? SefariaUpdateManager(configuration: configuration, client: client, paths: paths)
    }

    func packages(forceRefresh: Bool) async throws -> [OfflinePackage] {
        cleanupStagingIfNeeded()
        if !forceRefresh,
           let data = try? Data(contentsOf: paths.manifestCache),
           let cached = try? JSONDecoder().decode([SefariaPackageManifestEntry].self, from: data) {
            return cached.map(\.package)
        }
        let url = try configuration.readonlyURL(path:
            "\(SefariaExportContract.rootPath(schema: SefariaExportContract.currentSchema))/packages.json")
        let manifest = try await client.get([SefariaPackageManifestEntry].self, url: url)
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try JSONEncoder().encode(manifest).write(to: paths.manifestCache, options: .atomic)
        return manifest.map(\.package)
    }

    func installedPackageIDs() -> Set<String> { Set(loadState().packages.keys) }

    func install(
        packageIDs: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        cleanupStagingIfNeeded()
        guard activeInstall == nil else { throw LibraryBackendError.invalidResponse("an install is already running") }
        let task = Task { try await performInstall(packageIDs: packageIDs, progress: progress) }
        activeInstall = task
        defer { activeInstall = nil }
        try await task.value
    }

    func availableUpdates() async throws -> OfflineUpdateSummary {
        try await updates.availableUpdates()
    }

    func update(progress: @escaping @Sendable (OfflineInstallProgress) -> Void) async throws {
        guard activeInstall == nil else { throw LibraryBackendError.invalidResponse("an install is already running") }
        let task = Task { try await updates.update(progress: progress) }
        activeInstall = task
        defer { activeInstall = nil }
        try await task.value
    }

    func cancelInstall() async {
        activeInstall?.cancel()
        await updates.cancel()
    }

    func remove(packageIDs: Set<String>) throws {
        var state = loadState()
        for id in packageIDs {
            let target = paths.packages.appendingPathComponent(SefariaOfflinePaths.safeComponent(id), isDirectory: true)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            state.packages.removeValue(forKey: id)
        }
        try saveState(state)
        removeOrphanedExpandedBooks()
    }

    private func performInstall(
        packageIDs: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        let available = try await packages(forceRefresh: true)
        let selected = SefariaPackagePolicy.resolve(packageIDs, from: available)
        var state = loadState()
        for package in selected {
            try Task.checkCancellation()
            let capacity = availableCapacity(at: paths.root.deletingLastPathComponent())
            let required = package.compressedSize > 0 ? package.compressedSize * 2 : 0
            if required > 0, capacity > 0, capacity < required {
                throw LibraryBackendError.insufficientDiskSpace(required: required, available: capacity)
            }
            progress(.init(phase: .preparing, packageID: package.id, completedBytes: 0, totalBytes: package.compressedSize))
            let query = [
                URLQueryItem(name: "package", value: package.id),
                URLQueryItem(name: "schema_version", value: SefariaExportContract.currentSchema)
            ]
            let listURL = try configuration.readonlyURL(path: "/packageData", queryItems: query)
            let bundlePaths = try await client.get([String].self, url: listURL)
            let transaction = paths.staging.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let payload = transaction.appendingPathComponent("payload", isDirectory: true)
            try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: transaction) }

            var completed: Int64 = 0
            for (index, bundlePath) in bundlePaths.enumerated() {
                try Task.checkCancellation()
                let remoteURL: URL
                if let absolute = URL(string: bundlePath), absolute.scheme != nil {
                    remoteURL = absolute
                } else {
                    remoteURL = try configuration.readonlyURL(path: bundlePath)
                }
                let (downloaded, response) = try await client.download(url: remoteURL)
                let expected = response.expectedContentLength
                let availableBytes = availableCapacity(at: paths.root)
                if expected > 0, availableBytes > 0, availableBytes < expected * 2 {
                    throw LibraryBackendError.insufficientDiskSpace(required: expected * 2, available: availableBytes)
                }
                let archiveURL = transaction.appendingPathComponent("bundle-\(index).zip")
                try FileManager.default.moveItem(at: downloaded, to: archiveURL)
                try SefariaArchiveValidator.validate(archiveURL)
                progress(.init(phase: .validating, packageID: package.id, completedBytes: completed, totalBytes: package.compressedSize))
                try FileManager.default.unzipItem(at: archiveURL, to: payload)
                _ = try SefariaArchiveValidator.bookArchives(in: payload)
                completed += max(0, expected)
                progress(.init(phase: .downloading, packageID: package.id, completedBytes: completed, totalBytes: package.compressedSize))
            }

            try Task.checkCancellation()
            progress(.init(phase: .installing, packageID: package.id, completedBytes: completed, totalBytes: package.compressedSize))
            try FileManager.default.createDirectory(at: paths.packages, withIntermediateDirectories: true)
            let target = paths.packages.appendingPathComponent(SefariaOfflinePaths.safeComponent(package.id), isDirectory: true)
            let titles = Set(try SefariaArchiveValidator.bookArchives(in: payload).map {
                $0.deletingPathExtension().lastPathComponent
            })
            let titleUpdates = try await updates.snapshot(for: titles)
            try SefariaFileTransaction.atomicReplace(payload, target: target)
            state.packages[package.id] = .init(id: package.id, installedAt: Date(),
                schemaVersion: SefariaExportContract.currentSchema, bundlePaths: bundlePaths,
                titleUpdates: titleUpdates)
            try saveState(state)
            progress(.init(phase: .finished, packageID: package.id, completedBytes: package.compressedSize, totalBytes: package.compressedSize))
        }
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

    private func cleanupStagingIfNeeded() {
        guard !didCleanupStaging else { return }
        didCleanupStaging = true
        try? FileManager.default.removeItem(at: paths.staging)
    }
    private func removeOrphanedExpandedBooks() { try? FileManager.default.removeItem(at: paths.expandedBooks) }

    private func availableCapacity(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? -1
    }
}
