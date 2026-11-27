import Foundation

struct OtzariaDatabaseStorage: Sendable {
    static let safetyReserve: Int64 = 1_073_741_824
    // The current production frame expands slightly above 5x. Use 6x before
    // the archive header is available so the 1 GiB safety reserve stays intact.
    static let unknownOutputMultiplier: Int64 = 6

    let appSupportRoot: URL
    let downloadsRoot: URL
    let profileID: String

    init(profileID: String = OtzariaDataProfileRegistry.activeProfileID) throws {
        self.profileID = profileID
        self.appSupportRoot = ITorahSharedContainer.sharedRootURL
        self.downloadsRoot = OtzariaProfileStorage.downloadsRoot(
            base: ITorahSharedContainer.downloadsRootURL,
            component: .database,
            profileID: profileID
        )
    }

    init(appSupportRoot: URL, downloadsRoot: URL, profileID: String = OtzariaDataProfileRegistry.activeProfileID) {
        self.appSupportRoot = appSupportRoot
        self.downloadsRoot = downloadsRoot
        self.profileID = profileID
    }

    var otzariaRoot: URL {
        OtzariaProfileStorage.applicationSupportRoot(
            base: appSupportRoot,
            component: .database,
            profileID: profileID
        )
    }

    var finalDatabaseURL: URL {
        otzariaRoot.appendingPathComponent("seforim.db")
    }

    var stagingDatabaseURL: URL {
        otzariaRoot.appendingPathComponent("seforim.db.installing")
    }

    func uniqueStagingDatabaseURL() -> URL {
        otzariaRoot.appendingPathComponent("seforim.db.installing-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)")
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
        try requireAvailableCapacity(
            Self.requiredDownloadCapacity(release: release, existingPart: existingPart),
            at: downloadsRoot
        )
    }

    static func requiredDownloadCapacity(release: OtzariaLibraryRelease, existingPart: Int64) -> Int64 {
        let archiveBytes = max(0, release.compressedSize)
        let remaining = archiveBytes - min(max(0, existingPart), archiveBytes)
        let output = archiveBytes.multipliedReportingOverflow(by: unknownOutputMultiplier)
        guard !output.overflow else { return Int64.max }
        // Parts remain available for resume until the assembled archive is verified
        // and installed, so allow both copies at the peak of assembly.
        let assembly = release.multipart == nil ? 0 : archiveBytes
        return [remaining, output.partialValue, assembly, safetyReserve].reduce(0) { total, bytes in
            let sum = total.addingReportingOverflow(bytes)
            return sum.overflow ? Int64.max : sum.partialValue
        }
    }

    func preflightExtraction(compressedSize: Int64, expectedOutput: Int64?) throws {
        let outputEstimate = expectedOutput ?? multipliedWithoutOverflow(
            compressedSize,
            by: Self.unknownOutputMultiplier
        )
        let existingFinal = Self.fileSizeIfPresent(finalDatabaseURL)
        try requireAvailableCapacity(
            Self.requiredExtractionCapacity(
                outputEstimate: outputEstimate,
                existingFinalSize: existingFinal
            ),
            at: otzariaRoot
        )
    }

    // Replacing an existing managed database can temporarily retain the old
    // file as the rollback copy while the new staging file is present. Count
    // both conservatively; APFS clone/rename behavior is not assumed.
    static func requiredExtractionCapacity(
        outputEstimate: Int64,
        existingFinalSize: Int64
    ) -> Int64 {
        let (files, filesOverflow) = outputEstimate.addingReportingOverflow(existingFinalSize)
        let safeFiles = filesOverflow ? Int64.max / 2 : files
        let (total, totalOverflow) = safeFiles.addingReportingOverflow(safetyReserve)
        return totalOverflow ? Int64.max : total
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
        let stagingURL = storage.uniqueStagingDatabaseURL()
        try removeManagedFileIfPresent(stagingURL)
        for suffix in ["-wal", "-shm", "-journal"] {
            try removeManagedFileIfPresent(
                URL(fileURLWithPath: stagingURL.path + suffix)
            )
        }

        let expectedOutput = try extractor.frameContentSize(at: archiveURL)
        try storage.preflightExtraction(
            compressedSize: release.compressedSize,
            expectedOutput: expectedOutput
        )

        let written: Int64
        let extractionStarted = Date()
        var extractionElapsed: TimeInterval = 0
        var validationElapsed: TimeInterval = 0
        do {
            written = try extractor.extract(
                archiveURL: archiveURL,
                outputURL: stagingURL,
                progress: progress
            )
            extractionElapsed = Date().timeIntervalSince(extractionStarted)
            try Task.checkCancellation()
            try storage.excludeFromBackup(stagingURL)
            validationStarted()
            let validationStartedAt = Date()
            try OtzariaDatabaseAccessController.shared.validateDatabase(
                at: stagingURL
            )
            try Task.checkCancellation()
            validationElapsed = Date().timeIntervalSince(validationStartedAt)
        } catch is CancellationError {
            try? fileManager.removeItem(at: stagingURL)
            throw OtzariaDatabaseBootstrapError.cancelled
        } catch let error as OtzariaDatabaseBootstrapError {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw OtzariaDatabaseBootstrapError.sqliteValidationFailed(error.localizedDescription)
        }

        return OtzariaPreparedDatabaseInstallation(
            release: release,
            stagingURL: stagingURL,
            databaseFileSize: written,
            extractionElapsedSeconds: extractionElapsed,
            validationElapsedSeconds: validationElapsed
        )
    }

    func promote(
        _ prepared: OtzariaPreparedDatabaseInstallation,
        storage: OtzariaDatabaseStorage
    ) throws -> URL {
        try ITorahStorageLock.withLock(name: "database-mutation-\(storage.profileID)") {
            let fileManager = FileManager.default
            var promotionCompleted = false
            do {
                try recoverInterruptedInstallationUnderLock(storage: storage)
                guard fileManager.fileExists(atPath: prepared.stagingURL.path),
                      prepared.stagingURL.deletingLastPathComponent().standardizedFileURL == storage.otzariaRoot.standardizedFileURL else {
                    throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                        "the validated staging database is missing"
                    )
                }

                // A pending identity with a rollback database belongs to an
                // unfinished transaction. App-launch recovery must activate and
                // finish it before another replacement can consume its backup.
                guard !(fileManager.fileExists(atPath: storage.pendingInstallationManifestURL.path)
                        && fileManager.fileExists(atPath: storage.previousDatabaseURL.path)) else {
                    throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                        "the previous library update must finish recovery before another replacement"
                    )
                }

                for suffix in ["-wal", "-shm", "-journal"] {
                    try removeManagedFileIfPresent(
                        URL(fileURLWithPath: storage.finalDatabaseURL.path + suffix)
                    )
                }

                // Retire a completed transaction before reusing its backup
                // paths. Preserve its marker if database cleanup fails. Once
                // cleanup succeeds, no stale marker may authenticate a later
                // replacement whose pending identity never reached disk.
                try removeManagedFileIfPresent(storage.previousDatabaseURL)
                try removeManagedFileIfPresent(storage.previousInstallationManifestURL)

                if fileManager.fileExists(atPath: storage.finalDatabaseURL.path) {
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
                // A managed update must retain the official release identity. If the
                // manifest cannot be recorded, the outer rollback keeps the old database.
                try writeManifest(
                    prepared,
                    to: storage.pendingInstallationManifestURL,
                    storage: storage
                )
                return storage.finalDatabaseURL
            } catch let error as OtzariaDatabaseBootstrapError {
                let promotionError = error
                do {
                    if promotionCompleted {
                        try rollbackPromotionUnderLock(storage: storage)
                    } else {
                        try recoverInterruptedInstallationUnderLock(storage: storage)
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
                        try rollbackPromotionUnderLock(storage: storage)
                    } else {
                        try recoverInterruptedInstallationUnderLock(storage: storage)
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
    }

    func recoverInterruptedInstallation(storage: OtzariaDatabaseStorage) throws {
        try ITorahStorageLock.withLock(name: "database-mutation-\(storage.profileID)") {
            try recoverInterruptedInstallationUnderLock(storage: storage)
        }
    }

    private func recoverInterruptedInstallationUnderLock(storage: OtzariaDatabaseStorage) throws {
        try storage.prepareDirectories()
        try restorePreviousDatabaseIfNecessary(storage: storage)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: storage.finalDatabaseURL.path),
           fileManager.fileExists(atPath: storage.previousDatabaseURL.path) {
            do {
                // A crash can occur after replacement but before the pending
                // identity is written. SQLite integrity alone cannot bind that
                // new file to the previous release's stable manifest.
                guard fileManager.fileExists(atPath: storage.pendingInstallationManifestURL.path)
                        || fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path) else {
                    throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                        "interrupted replacement has no committed release identity"
                    )
                }
                try validateRecoveryManifest(storage: storage)
                try OtzariaDatabaseAccessController.shared.validateDatabase(
                    at: storage.finalDatabaseURL
                )
            } catch {
                try rollbackPromotionUnderLock(storage: storage)
            }
        } else if !fileManager.fileExists(atPath: storage.finalDatabaseURL.path) {
            try removeManagedFileIfPresent(storage.pendingInstallationManifestURL)
        }
    }

    func completePromotion(storage: OtzariaDatabaseStorage) throws {
        try ITorahStorageLock.withLock(name: "database-mutation-\(storage.profileID)") {
            // Metadata is part of the commit. Keep both rollback files until
            // it succeeds, and let the caller close the active connection and
            // restore them on failure.
            try promotePendingManifest(storage: storage)
            do {
                try removeManagedFileIfPresent(storage.previousDatabaseURL)
            } catch {
                // Retain the previous manifest as the committed-state marker
                // while the previous database awaits a later cleanup attempt.
                print("[OtzariaBootstrap] rollback cleanup failed for \(storage.previousDatabaseURL.lastPathComponent): \(error.localizedDescription)")
                return
            }
            do {
                try removeManagedFileIfPresent(storage.previousInstallationManifestURL)
            } catch {
                print("[OtzariaBootstrap] rollback cleanup failed for \(storage.previousInstallationManifestURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    func rollbackPromotion(storage: OtzariaDatabaseStorage) throws {
        try ITorahStorageLock.withLock(name: "database-mutation-\(storage.profileID)") {
            try rollbackPromotionUnderLock(storage: storage)
        }
    }

    private func rollbackPromotionUnderLock(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        // If pending metadata still exists, it was not moved to the stable
        // name. An existing stable manifest is still the old identity; a stale
        // or unwritable .previous entry must never overwrite it on rollback.
        let restorePreviousManifest = fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path)
            && (!fileManager.fileExists(atPath: storage.pendingInstallationManifestURL.path)
                || !fileManager.fileExists(atPath: storage.installationManifestURL.path))
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
        if restorePreviousManifest {
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
        // Roll back the identity too; an abandoned pending manifest must not
        // be used to validate or advertise the restored previous database.
        try rollbackPromotionUnderLock(storage: storage)
    }

    func validateRecoveryManifest(storage: OtzariaDatabaseStorage) throws {
        let fileManager = FileManager.default
        let url = fileManager.fileExists(atPath: storage.pendingInstallationManifestURL.path)
            ? storage.pendingInstallationManifestURL : storage.installationManifestURL
        let metadata = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard metadata.isRegularFile == true,
              let bytes = metadata.fileSize, bytes > 0, bytes <= 1_048_576 else {
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed("invalid recovery manifest")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(OtzariaDatabaseInstallationManifest.self, from: Data(contentsOf: url))
        let size = try storage.finalDatabaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard manifest.repository == OtzariaLibraryRelease.repository,
              manifest.effectiveProfileID == storage.profileID,
              manifest.databaseFileSize > 0,
              size.map(Int64.init) == manifest.databaseFileSize,
              storage.profileID != OtzariaDataProfileRegistry.productionID
                || manifest.hasValidProductionArchiveIdentity else {
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed("recovery manifest does not identify the promoted database")
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
            guard !fileManager.fileExists(atPath: storage.previousDatabaseURL.path)
                    || fileManager.fileExists(atPath: storage.previousInstallationManifestURL.path) else {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "promoted database is missing its pending release identity"
                )
            }
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
