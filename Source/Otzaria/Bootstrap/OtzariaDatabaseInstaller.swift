import Foundation

struct OtzariaDatabaseStorage: Sendable {
    static let safetyReserve = OtzariaInstallCapacityCalculator.defaultSafetyReserveBytes
    // The current production frame expands slightly above 5x. Use 6x before
    // the archive header is available so the 1 GiB safety reserve stays intact.
    static let unknownOutputMultiplier: Int64 = 6

    let appSupportRoot: URL
    let downloadsRoot: URL
    let profileID: String

    init() throws {
        guard let appSupportRoot = AppConfig.appSupportDir else {
            throw OtzariaDatabaseAccessController.AccessError.applicationSupportUnavailable
        }
        self.appSupportRoot = appSupportRoot
        profileID = OtzariaDataProfileRegistry.activeProfileID

        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        if profileID == OtzariaDataProfileRegistry.productionID {
            downloadsRoot = caches
                .appendingPathComponent("Maktabah", isDirectory: true)
                .appendingPathComponent("Otzaria", isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
        } else {
            downloadsRoot = caches
                .appendingPathComponent("Maktabah", isDirectory: true)
                .appendingPathComponent("Otzaria", isDirectory: true)
                .appendingPathComponent("Profiles", isDirectory: true)
                .appendingPathComponent(profileID, isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
        }
    }

    init(
        appSupportRoot: URL,
        downloadsRoot: URL,
        profileID: String = OtzariaDataProfileRegistry.productionID
    ) {
        self.appSupportRoot = appSupportRoot
        self.downloadsRoot = downloadsRoot
        self.profileID = profileID
    }

    var otzariaRoot: URL {
        let root = appSupportRoot.appendingPathComponent("Otzaria", isDirectory: true)
        guard profileID != OtzariaDataProfileRegistry.productionID else { return root }
        return root
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
            .appendingPathComponent("database", isDirectory: true)
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

    var pendingInstallationManifestURL: URL {
        otzariaRoot.appendingPathComponent("seforim-installation.json.installing")
    }

    var previousInstallationManifestURL: URL {
        otzariaRoot.appendingPathComponent("seforim-installation.json.previous")
    }

    func prepareDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: otzariaRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
        try excludeFromBackup(otzariaRoot)
        try excludeFromBackup(downloadsRoot)
    }

    func preflightDownload(release: OtzariaLibraryRelease, existingPart: Int64) throws {
        let outputEstimate = multipliedWithoutOverflow(
            release.asset.compressedSize,
            by: Self.unknownOutputMultiplier
        )
        let plan = OtzariaInstallCapacityCalculator.plan(
            compressedBytes: release.asset.compressedSize,
            extractedBytes: outputEstimate,
            existingInstallBytes: Self.fileSizeIfPresent(finalDatabaseURL),
            currentPartialDownloadBytes: existingPart,
            retainsRollbackCopy: false
        )
        try requireAvailableCapacity(
            plan.peakAdditionalBytes,
            at: downloadsRoot
        )
    }

    func preflightExtraction(compressedSize: Int64, expectedOutput: Int64?) throws {
        let outputEstimate = expectedOutput ?? multipliedWithoutOverflow(
            compressedSize,
            by: Self.unknownOutputMultiplier
        )
        let existingFinal = Self.fileSizeIfPresent(finalDatabaseURL)
        let plan = OtzariaInstallCapacityCalculator.plan(
            compressedBytes: compressedSize,
            extractedBytes: outputEstimate,
            existingInstallBytes: existingFinal,
            currentPartialDownloadBytes: compressedSize,
            retainsRollbackCopy: false
        )
        try requireAvailableCapacity(plan.peakAdditionalBytes, at: otzariaRoot)
    }

    // Available-capacity values already exclude the installed database. The
    // rollback promotion is a same-volume rename, so only staging output and
    // the safety reserve consume additional free bytes.
    static func requiredExtractionCapacity(
        outputEstimate: Int64,
        existingFinalSize: Int64
    ) -> Int64 {
        OtzariaInstallCapacityCalculator.plan(
            compressedBytes: 1,
            extractedBytes: outputEstimate,
            existingInstallBytes: existingFinalSize,
            currentPartialDownloadBytes: 1,
            retainsRollbackCopy: false
        ).peakAdditionalBytes
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
    private static func fileSizeIfPresent(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
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
        let extractionStarted = Date()
        var extractionElapsed: TimeInterval = 0
        var validationElapsed: TimeInterval = 0
        do {
            written = try extractor.extract(
                archiveURL: archiveURL,
                outputURL: storage.stagingDatabaseURL,
                progress: progress
            )
            extractionElapsed = Date().timeIntervalSince(extractionStarted)
            try storage.excludeFromBackup(storage.stagingDatabaseURL)
            validationStarted()
            let validationStartedAt = Date()
            try OtzariaDatabaseAccessController.shared.validateDatabase(
                at: storage.stagingDatabaseURL
            )
            validationElapsed = Date().timeIntervalSince(validationStartedAt)
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
            databaseFileSize: written,
            extractionElapsedSeconds: extractionElapsed,
            validationElapsedSeconds: validationElapsed
        )
    }

    func promote(
        _ prepared: OtzariaPreparedDatabaseInstallation,
        storage: OtzariaDatabaseStorage
    ) throws -> URL {
        let fileManager = FileManager.default
        var promotionCompleted = false
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
                    options: [.withoutDeletingBackupItem]
                )
            } else {
                try fileManager.moveItem(at: prepared.stagingURL, to: storage.finalDatabaseURL)
            }
            promotionCompleted = true

            guard fileManager.fileExists(atPath: storage.finalDatabaseURL.path) else {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "atomic promotion did not create the final database"
                )
            }
            try storage.excludeFromBackup(storage.finalDatabaseURL)
            do {
                try writeManifest(
                    prepared,
                    to: storage.pendingInstallationManifestURL,
                    storage: storage
                )
            } catch {
                // The pending manifest is diagnostic metadata. The validated database
                // and its rollback copy remain the source of truth for recovery.
                print("[OtzariaBootstrap] pending manifest write failed: \(error.localizedDescription)")
            }
            return storage.finalDatabaseURL
        } catch let error as OtzariaDatabaseBootstrapError {
            let promotionError = error
            do {
                if promotionCompleted {
                    try rollbackPromotion(storage: storage)
                } else {
                    try recoverInterruptedInstallation(storage: storage)
                }
            } catch {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "\(promotionError.localizedDescription); rollback also failed: \(error.localizedDescription)"
                )
            }
            throw promotionError
        } catch {
            let promotionError = error
            do {
                if promotionCompleted {
                    try rollbackPromotion(storage: storage)
                } else {
                    try recoverInterruptedInstallation(storage: storage)
                }
            } catch {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "\(promotionError.localizedDescription); rollback also failed: \(error.localizedDescription)"
                )
            }
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                promotionError.localizedDescription
            )
        }
    }

    func recoverInterruptedInstallation(storage: OtzariaDatabaseStorage) throws {
        try storage.prepareDirectories()
        try restorePreviousDatabaseIfNecessary(storage: storage)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storage.finalDatabaseURL.path),
           fileManager.fileExists(atPath: storage.previousDatabaseURL.path) {
            do {
                try OtzariaDatabaseAccessController.shared.validateDatabase(
                    at: storage.finalDatabaseURL
                )
            } catch {
                try rollbackPromotion(storage: storage)
            }
        }
    }

    func completePromotion(storage: OtzariaDatabaseStorage) {
        do {
            try promotePendingManifest(storage: storage)
        } catch {
            // Activation already reopened the validated database. Metadata failure
            // must not turn a safe install into an unusable one.
            print("[OtzariaBootstrap] installation manifest finalization failed: \(error.localizedDescription)")
        }
        for url in [storage.previousDatabaseURL, storage.previousInstallationManifestURL] {
            do {
                try removeManagedFileIfPresent(url)
            } catch {
                print("[OtzariaBootstrap] rollback cleanup failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    func rollbackPromotion(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storage.previousDatabaseURL.path) {
            try removeManagedFileIfPresent(storage.finalDatabaseURL)
            try fileManager.moveItem(
                at: storage.previousDatabaseURL,
                to: storage.finalDatabaseURL
            )
        } else {
            try removeManagedFileIfPresent(storage.finalDatabaseURL)
        }
        try? removeManagedFileIfPresent(storage.pendingInstallationManifestURL)
        if fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path) {
            try? removeManagedFileIfPresent(storage.installationManifestURL)
            try fileManager.moveItem(
                at: storage.previousInstallationManifestURL,
                to: storage.installationManifestURL
            )
        }
    }
}

private extension OtzariaDatabaseInstaller {
    func restorePreviousDatabaseIfNecessary(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: storage.finalDatabaseURL.path),
              fileManager.fileExists(atPath: storage.previousDatabaseURL.path) else { return }
        try fileManager.moveItem(at: storage.previousDatabaseURL, to: storage.finalDatabaseURL)
        if fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path) {
            try? removeManagedFileIfPresent(storage.installationManifestURL)
            try fileManager.moveItem(
                at: storage.previousInstallationManifestURL,
                to: storage.installationManifestURL
            )
        }
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

    func promotePendingManifest(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storage.pendingInstallationManifestURL.path) else {
            return
        }
        if fileManager.fileExists(atPath: storage.installationManifestURL.path) {
            try removeManagedFileIfPresent(storage.previousInstallationManifestURL)
            try fileManager.moveItem(
                at: storage.installationManifestURL,
                to: storage.previousInstallationManifestURL
            )
        }
        do {
            try fileManager.moveItem(
                at: storage.pendingInstallationManifestURL,
                to: storage.installationManifestURL
            )
            try storage.excludeFromBackup(storage.installationManifestURL)
        } catch {
            if !fileManager.fileExists(atPath: storage.installationManifestURL.path),
               fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path) {
                try? fileManager.moveItem(
                    at: storage.previousInstallationManifestURL,
                    to: storage.installationManifestURL
                )
            }
            throw error
        }
    }
}
