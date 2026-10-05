import Foundation
import ZIPFoundation

actor SefariaUpdateManager {
    private enum Destination: Hashable, Sendable {
        case package(String)
        case standalone
    }
    private struct PendingUpdate {
        let manifest: SefariaLastUpdatedManifest
        let titles: Set<String>
        let packages: Set<String>
        let destinations: [String: Set<Destination>]
    }

    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let paths: SefariaOfflinePaths
    private let bundles: SefariaBundleDownloadService
    private var cancelled = false

    init(configuration: SefariaNetworkConfiguration, client: SefariaHTTPClient, paths: SefariaOfflinePaths) {
        self.configuration = configuration
        self.client = client
        self.paths = paths
        self.bundles = SefariaBundleDownloadService(configuration: configuration, client: client, paths: paths)
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
        let downloaded = try await bundles.download(workKeys: pending.titles, progress: progress)
        defer { try? FileManager.default.removeItem(at: downloaded.transaction) }
        let updatedBooks = downloaded.bookArchives
        try checkCancellation()
        progress(.init(phase: .installing, packageID: nil, completedBytes: downloaded.downloadSize,
            totalBytes: downloaded.downloadSize))
        let installedTitles = try replaceInstalledBooks(with: updatedBooks, destinations: pending.destinations)
        try updateState(manifest: pending.manifest, titles: installedTitles, destinations: pending.destinations)
        progress(.init(phase: .finished, packageID: nil, completedBytes: downloaded.downloadSize,
            totalBytes: downloaded.downloadSize))
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
        var destinations: [String: Set<Destination>] = [:]
        for id in state.packages.keys {
            guard let packageState = state.packages[id],
                  let package = packageManifest.first(where: { $0.en == id }) else { continue }
            let desired = state.desiredWorkKeys(
                forPackageID: id,
                packageIndexTitles: package.indexes,
                manifestWorkKeys: Set(manifest.titles.keys)
            )
            let installedUpdates = packageState.titleUpdates ?? [:]
            let packageChanges = desired.filter { title in
                guard let remote = manifest.titles[title] else { return false }
                return installedUpdates[title] != remote
            }
            if !packageChanges.isEmpty {
                changed.formUnion(packageChanges)
                affected.insert(id)
                for title in packageChanges { destinations[title, default: []].insert(.package(id)) }
            }
        }
        for (title, standalone) in state.standaloneWorks {
            guard let remote = manifest.titles[title], standalone.lastUpdated != remote else { continue }
            changed.insert(title)
            destinations[title, default: []].insert(.standalone)
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

    private func replaceInstalledBooks(
        with updates: [URL],
        destinations: [String: Set<Destination>]
    ) throws -> Set<String> {
        let manager = FileManager.default
        var installedByName: [String: [URL]] = [:]
        if let walker = manager.enumerator(at: paths.packages, includingPropertiesForKeys: nil) {
            for case let url as URL in walker where url.pathExtension.lowercased() == "zip" {
                installedByName[url.lastPathComponent, default: []].append(url)
            }
        }
        var installed = Set<String>()
        for update in updates {
            let title = update.deletingPathExtension().lastPathComponent
            var targets = installedByName[update.lastPathComponent] ?? []
            for destination in destinations[title] ?? [] {
                let target: URL
                switch destination {
                case .package(let packageID):
                    target = paths.packages.appendingPathComponent(
                        SefariaOfflinePaths.safeComponent(packageID), isDirectory: true
                    ).appendingPathComponent(update.lastPathComponent)
                case .standalone:
                    target = paths.standaloneArchive(for: title)
                }
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
        destinations: [String: Set<Destination>]
    ) throws {
        var state = loadState()
        for id in Array(state.packages.keys) {
            guard var package = state.packages[id] else { continue }
            var timestamps = package.titleUpdates ?? [:]
            for title in titles where destinations[title]?.contains(.package(id)) == true {
                timestamps[title] = manifest.titles[title]
            }
            package.titleUpdates = timestamps
            state.packages[id] = package
        }
        for title in titles where destinations[title]?.contains(.standalone) == true {
            guard let existing = state.standaloneWorks[title] else { continue }
            state.standaloneWorks[title] = .init(
                title: title,
                installedAt: existing.installedAt,
                lastUpdated: manifest.titles[title],
                archiveFilename: paths.standaloneArchive(for: title).lastPathComponent
            )
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
