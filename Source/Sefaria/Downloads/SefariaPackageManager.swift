import Foundation
import ZIPFoundation

actor SefariaPackageManager: OfflineLibraryProviding, OfflineWorkProviding {
    private let configuration: SefariaNetworkConfiguration
    private let client: SefariaHTTPClient
    private let paths: SefariaOfflinePaths
    private let updates: SefariaUpdateManager
    private let bundles: SefariaBundleDownloadService
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
        self.bundles = SefariaBundleDownloadService(configuration: configuration, client: client, paths: paths)
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

    func installedWorkKeys() -> Set<String> {
        var state = loadState()
        var repaired = false
        var validStandalone = Set<String>()
        for title in Array(state.standaloneWorks.keys) {
            guard let work = state.standaloneWorks[title] else { continue }
            let archive = paths.standaloneWorks.appendingPathComponent(work.archiveFilename)
            if isValidBookArchive(archive, expectedTitle: title) {
                validStandalone.insert(title)
            } else {
                state.standaloneWorks.removeValue(forKey: title)
                repaired = true
            }
        }
        var validPackages: [String: Set<String>] = [:]
        for (id, var package) in Array(state.packages) {
            let directory = paths.packages.appendingPathComponent(
                SefariaOfflinePaths.safeComponent(id), isDirectory: true
            )
            let valid = validatedBookTitles(in: directory)
            let declared = package.titleUpdates.map { Set($0.keys) } ?? []
            let repairedTitles = declared.isEmpty ? valid : declared.intersection(valid)
            if repairedTitles != declared {
                let previous = package.titleUpdates ?? [:]
                package.titleUpdates = Dictionary(uniqueKeysWithValues: repairedTitles.map { ($0, previous[$0] ?? "") })
                state.packages[id] = package
                repaired = true
            }
            validPackages[id] = valid
        }
        if repaired { try? saveState(state) }
        return state.installedWorkKeys(
            validStandaloneWorkKeys: validStandalone,
            validPackageWorkKeys: validPackages
        )
    }

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

    func install(
        workKeys: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        cleanupStagingIfNeeded()
        guard activeInstall == nil else { throw LibraryBackendError.invalidResponse("an install is already running") }
        let task = Task { try await performWorkInstall(workKeys: workKeys, progress: progress) }
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

    func cancelWorkInstall() async { await cancelInstall() }

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

    func remove(workKeys: Set<String>) throws {
        var state = loadState()
        let manager = FileManager.default
        for title in workKeys {
            if let standalone = state.standaloneWorks.removeValue(forKey: title) {
                let archive = paths.standaloneWorks.appendingPathComponent(standalone.archiveFilename)
                if manager.fileExists(atPath: archive.path) { try manager.removeItem(at: archive) }
            }
            for id in Array(state.packages.keys) {
                guard var package = state.packages[id] else { continue }
                let packageDirectory = paths.packages.appendingPathComponent(
                    SefariaOfflinePaths.safeComponent(id), isDirectory: true
                )
                for archive in bookArchives(in: packageDirectory)
                    where archive.deletingPathExtension().lastPathComponent == title {
                    try manager.removeItem(at: archive)
                }
                var excluded = package.excludedTitles ?? []
                excluded.insert(title)
                package.excludedTitles = excluded
                package.titleUpdates?.removeValue(forKey: title)
                state.packages[id] = package
            }
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
            guard !bundlePaths.isEmpty else {
                throw LibraryBackendError.invalidResponse("package \(package.id) has no downloadable bundles")
            }
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
                let (downloaded, response) = try await downloadBundleWithRetry(remoteURL)
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
            guard !titles.isEmpty else {
                throw LibraryBackendError.corruptData("package \(package.id) contains no book archives")
            }
            let titleUpdates = try await updates.snapshot(for: titles)
            try SefariaFileTransaction.atomicReplace(payload, target: target)
            state.packages[package.id] = .init(id: package.id, installedAt: Date(),
                schemaVersion: SefariaExportContract.currentSchema, bundlePaths: bundlePaths,
                titleUpdates: titleUpdates, excludedTitles: [])
            try saveState(state)
            progress(.init(phase: .finished, packageID: package.id, completedBytes: package.compressedSize, totalBytes: package.compressedSize))
        }
    }

    private func performWorkInstall(
        workKeys: Set<String>,
        progress: @escaping @Sendable (OfflineInstallProgress) -> Void
    ) async throws {
        guard !workKeys.isEmpty else { return }
        let downloaded = try await bundles.download(workKeys: workKeys, progress: progress)
        defer { try? FileManager.default.removeItem(at: downloaded.transaction) }
        var archivesByTitle: [String: URL] = [:]
        for archive in downloaded.bookArchives {
            let title = archive.deletingPathExtension().lastPathComponent
            guard archivesByTitle.updateValue(archive, forKey: title) == nil else {
                throw LibraryBackendError.corruptData("bundle contains duplicate archive for \(title)")
            }
        }
        let missing = workKeys.subtracting(archivesByTitle.keys)
        guard missing.isEmpty else {
            throw LibraryBackendError.corruptData("bundle omitted requested works: \(missing.sorted().joined(separator: ", "))")
        }

        progress(.init(phase: .installing, packageID: nil, completedBytes: downloaded.downloadSize,
            totalBytes: downloaded.downloadSize))
        let manager = FileManager.default
        let staged = downloaded.transaction.appendingPathComponent("standalone-next", isDirectory: true)
        try manager.createDirectory(at: staged, withIntermediateDirectories: true)
        if manager.fileExists(atPath: paths.standaloneWorks.path) {
            for existing in try manager.contentsOfDirectory(at: paths.standaloneWorks,
                includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                try manager.copyItem(at: existing, to: staged.appendingPathComponent(existing.lastPathComponent))
            }
        }
        for title in workKeys {
            guard let archive = archivesByTitle[title] else { continue }
            let target = staged.appendingPathComponent(paths.standaloneArchive(for: title).lastPathComponent)
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            try manager.copyItem(at: archive, to: target)
            try SefariaArchiveValidator.validateBookArchive(target, expectedTitle: title)
        }

        let timestamps = try await updates.snapshot(for: workKeys)
        try manager.createDirectory(at: paths.schemaRoot, withIntermediateDirectories: true)
        try SefariaFileTransaction.atomicReplace(staged, target: paths.standaloneWorks)

        var state = loadState()
        let committedFilenames = Dictionary(uniqueKeysWithValues: workKeys.map {
            ($0, paths.standaloneArchive(for: $0).lastPathComponent)
        })
        try state.recordStandaloneInstall(
            workKeys: workKeys,
            committedArchiveFilenames: committedFilenames,
            timestamps: timestamps
        )
        for title in workKeys {
            for id in Array(state.packages.keys) {
                guard var package = state.packages[id] else { continue }
                package.excludedTitles?.remove(title)
                state.packages[id] = package
            }
        }
        try saveState(state)
        removeOrphanedExpandedBooks()
        progress(.init(phase: .finished, packageID: nil, completedBytes: downloaded.downloadSize,
            totalBytes: downloaded.downloadSize))
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

    private func downloadBundleWithRetry(_ url: URL, maximumAttempts: Int = 3) async throws -> (URL, HTTPURLResponse) {
        var lastError: Error?
        for attempt in 1...maximumAttempts {
            try Task.checkCancellation()
            do {
                return try await client.download(url: url)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                guard attempt < maximumAttempts else { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
            }
        }
        throw lastError ?? LibraryBackendError.invalidResponse("bundle download failed")
    }
    private func removeOrphanedExpandedBooks() { try? FileManager.default.removeItem(at: paths.expandedBooks) }

    private func validatedBookTitles(in directory: URL) -> Set<String> {
        Set(bookArchives(in: directory).compactMap { url in
            let title = url.deletingPathExtension().lastPathComponent
            return isValidBookArchive(url, expectedTitle: title) ? title : nil
        })
    }

    private func isValidBookArchive(_ url: URL, expectedTitle: String) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            try SefariaArchiveValidator.validateBookArchive(url, expectedTitle: expectedTitle)
            return true
        } catch {
            return false
        }
    }

    private func bookArchives(in directory: URL) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension.lowercased() == "zip" }
    }

    private func availableCapacity(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? -1
    }
}
