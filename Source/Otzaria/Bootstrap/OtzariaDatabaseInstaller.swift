import Foundation

struct OtzariaDatabaseStorage: Sendable {
    static let safetyReserve: Int64 = 1_073_741_824
    static let unknownOutputMultiplier: Int64 = 5

    let appSupportRoot: URL
    let downloadsRoot: URL

    init() throws {
        guard let appSupportRoot = AppConfig.appSupportDir else {
            throw OtzariaDatabaseAccessController.AccessError.applicationSupportUnavailable
        }
        self.appSupportRoot = appSupportRoot

        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        downloadsRoot = caches
            .appendingPathComponent("Maktabah", isDirectory: true)
            .appendingPathComponent("Otzaria", isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    init(appSupportRoot: URL, downloadsRoot: URL) {
        self.appSupportRoot = appSupportRoot
        self.downloadsRoot = downloadsRoot
    }

    var otzariaRoot: URL {
        appSupportRoot.appendingPathComponent("Otzaria", isDirectory: true)
    }

    var finalDatabaseURL: URL {
        otzariaRoot.appendingPathComponent("seforim.db")
    }

    var stagingDatabaseURL: URL {
        otzariaRoot.appendingPathComponent("seforim.db.installing")
    }

    var previousDatabaseURL: URL {
        otzariaRoot.appendingPathComponent("seforim.db.previous")
    }

    var installationManifestURL: URL {
        otzariaRoot.appendingPathComponent("seforim-installation.json")
    }

    func prepareDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: otzariaRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
        try excludeFromBackup(otzariaRoot)
        try excludeFromBackup(downloadsRoot)
    }

    func preflightDownload(release: OtzariaLibraryRelease, existingPart: Int64) throws {
        let remainingDownload = max(0, release.asset.compressedSize - existingPart)
        let outputEstimate = multipliedWithoutOverflow(
            release.asset.compressedSize,
            by: Self.unknownOutputMultiplier
        )
        try requireAvailableCapacity(
            remainingDownload + outputEstimate + Self.safetyReserve,
            at: downloadsRoot
        )
    }

    func preflightExtraction(compressedSize: Int64, expectedOutput: Int64?) throws {
        let outputEstimate = expectedOutput ?? multipliedWithoutOverflow(
            compressedSize,
            by: Self.unknownOutputMultiplier
        )
        try requireAvailableCapacity(outputEstimate + Self.safetyReserve, at: otzariaRoot)
    }

    func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }

    func availableCapacity(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        if let important = values.volumeAvailableCapacityForImportantUsage { return important }
        if let fallback = values.volumeAvailableCapacity { return Int64(fallback) }
        return 0
    }

    private func requireAvailableCapacity(_ required: Int64, at url: URL) throws {
        let available = availableCapacity(at: url)
        guard available > 0, available >= required else {
            throw OtzariaDatabaseBootstrapError.insufficientDiskSpace(
                required: required,
                available: max(0, available)
            )
        }
    }

    private func multipliedWithoutOverflow(_ value: Int64, by multiplier: Int64) -> Int64 {
        let (result, overflow) = value.multipliedReportingOverflow(by: multiplier)
        return overflow ? Int64.max / 2 : result
    }
}

struct OtzariaDatabaseInstaller: Sendable {
    private let extractor = OtzariaZstdStreamExtractor()

    func prepare(
        archiveURL: URL,
        release: OtzariaLibraryRelease,
        storage: OtzariaDatabaseStorage,
        progress: @escaping OtzariaZstdStreamExtractor.ProgressHandler,
        validationStarted: @escaping @Sendable () -> Void
    ) throws -> OtzariaPreparedDatabaseInstallation {
        try storage.prepareDirectories()
        try recoverInterruptedInstallation(storage: storage)

        let fileManager = FileManager.default
        try removeManagedFileIfPresent(storage.stagingDatabaseURL)
        for suffix in ["-wal", "-shm", "-journal"] {
            try removeManagedFileIfPresent(
                URL(fileURLWithPath: storage.stagingDatabaseURL.path + suffix)
            )
        }

        let expectedOutput = try extractor.frameContentSize(at: archiveURL)
        try storage.preflightExtraction(
            compressedSize: release.asset.compressedSize,
            expectedOutput: expectedOutput
        )

        let written: Int64
        do {
            written = try extractor.extract(
                archiveURL: archiveURL,
                outputURL: storage.stagingDatabaseURL,
                progress: progress
            )
            try storage.excludeFromBackup(storage.stagingDatabaseURL)
            validationStarted()
            try OtzariaDatabaseAccessController.shared.validateDatabase(
                at: storage.stagingDatabaseURL
            )
        } catch let error as OtzariaDatabaseBootstrapError {
            try? fileManager.removeItem(at: storage.stagingDatabaseURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: storage.stagingDatabaseURL)
            throw OtzariaDatabaseBootstrapError.sqliteValidationFailed(error.localizedDescription)
        }

        return OtzariaPreparedDatabaseInstallation(
            release: release,
            stagingURL: storage.stagingDatabaseURL,
            databaseFileSize: written
        )
    }

    func promote(
        _ prepared: OtzariaPreparedDatabaseInstallation,
        storage: OtzariaDatabaseStorage
    ) throws -> URL {
        let fileManager = FileManager.default
        do {
            try recoverInterruptedInstallation(storage: storage)
            guard prepared.stagingURL.standardizedFileURL == storage.stagingDatabaseURL.standardizedFileURL,
                  fileManager.fileExists(atPath: prepared.stagingURL.path) else {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "the validated staging database is missing"
                )
            }

            for suffix in ["-wal", "-shm", "-journal"] {
                try removeManagedFileIfPresent(
                    URL(fileURLWithPath: storage.finalDatabaseURL.path + suffix)
                )
            }

            if fileManager.fileExists(atPath: storage.finalDatabaseURL.path) {
                try removeManagedFileIfPresent(storage.previousDatabaseURL)
                _ = try fileManager.replaceItemAt(
                    storage.finalDatabaseURL,
                    withItemAt: prepared.stagingURL,
                    backupItemName: storage.previousDatabaseURL.lastPathComponent,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: prepared.stagingURL, to: storage.finalDatabaseURL)
            }

            guard fileManager.fileExists(atPath: storage.finalDatabaseURL.path) else {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "atomic promotion did not create the final database"
                )
            }
            try storage.excludeFromBackup(storage.finalDatabaseURL)
            try? removeManagedFileIfPresent(storage.previousDatabaseURL)
            do {
                try writeManifest(prepared, to: storage.installationManifestURL, storage: storage)
            } catch {
                // The manifest is diagnostic metadata, not a prerequisite for opening a
                // database that was already validated and promoted successfully.
                print("[OtzariaBootstrap] installation manifest write failed: \(error.localizedDescription)")
            }
            return storage.finalDatabaseURL
        } catch let error as OtzariaDatabaseBootstrapError {
            try? restorePreviousDatabaseIfNecessary(storage: storage)
            throw error
        } catch {
            try? restorePreviousDatabaseIfNecessary(storage: storage)
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed(error.localizedDescription)
        }
    }

    func recoverInterruptedInstallation(storage: OtzariaDatabaseStorage) throws {
        try storage.prepareDirectories()
        try restorePreviousDatabaseIfNecessary(storage: storage)
        if FileManager.default.fileExists(atPath: storage.finalDatabaseURL.path) {
            try? removeManagedFileIfPresent(storage.previousDatabaseURL)
        }
    }
}

private extension OtzariaDatabaseInstaller {
    func restorePreviousDatabaseIfNecessary(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: storage.finalDatabaseURL.path),
              fileManager.fileExists(atPath: storage.previousDatabaseURL.path) else { return }
        try fileManager.moveItem(at: storage.previousDatabaseURL, to: storage.finalDatabaseURL)
    }

    func removeManagedFileIfPresent(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func writeManifest(
        _ prepared: OtzariaPreparedDatabaseInstallation,
        to url: URL,
        storage: OtzariaDatabaseStorage
    ) throws {
        let manifest = OtzariaDatabaseInstallationManifest(
            release: prepared.release,
            databaseFileSize: prepared.databaseFileSize
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: url, options: .atomic)
        try storage.excludeFromBackup(url)
    }
}
