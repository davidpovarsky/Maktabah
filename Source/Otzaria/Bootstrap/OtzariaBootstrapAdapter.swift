import Foundation

@MainActor
enum OtzariaBootstrapAdapter {
    static func restoreForAppLaunch() async throws -> Bool {
        let storage = try OtzariaDatabaseStorage()
        let installer = OtzariaDatabaseInstaller()
        // Ambiguous interrupted promotion may require a full SQLite scan. Keep
        // that work off the main actor so iOS can finish creating the scene.
        try await Task.detached(priority: .utility) {
            try installer.recoverInterruptedInstallation(storage: storage)
        }.value
        let fileManager = FileManager.default
        let interruptedPromotion = fileManager.fileExists(
            atPath: storage.pendingInstallationManifestURL.path
        ) || fileManager.fileExists(atPath: storage.previousDatabaseURL.path)
        if interruptedPromotion,
           fileManager.fileExists(atPath: storage.finalDatabaseURL.path) {
            try OtzariaMaktabahBridge.shared.activateManagedDatabase(
                at: storage.finalDatabaseURL
            )
            installer.completePromotion(storage: storage)
            return true
        }
        let restored = try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()
        if restored {
            installer.completePromotion(storage: storage)
        }
        return restored
    }

    static var shouldSetupTarjamahConnection: Bool {
        !OtzariaMaktabahBridge.shared.isEnabled
    }

    static var shouldCheckCoreDatabaseUpdate: Bool {
        !OtzariaMaktabahBridge.shared.isEnabled
    }

    static func installDatabase(from url: URL) throws {
        try OtzariaMaktabahBridge.shared.installDatabase(from: url)
    }

    @discardableResult
    static func downloadAndInstallManagedDatabase(
        progress: @escaping OtzariaDatabaseBootstrapService.ProgressHandler
    ) async throws -> OtzariaManagedDatabaseInstallResult {
        let service = OtzariaDatabaseBootstrapService.shared
        let preparation = try await service.prepareManagedDatabase(progress: progress)
        let prepared = preparation.prepared
        let storage = preparation.storage

        // No active SQLite handle may survive replacement of the managed DB.
        OtzariaMaktabahBridge.shared.resetConnection()
        OtzariaTantivySearchRepository.shared.closeAllEngines()

        let finalURL = try await service.promote(
            prepared,
            storage: storage,
            progress: progress
        )
        do {
            try OtzariaMaktabahBridge.shared.activateManagedDatabase(at: finalURL)
        } catch {
            let activationError = error
            let hadPrevious = FileManager.default.fileExists(
                atPath: storage.previousDatabaseURL.path
            )
            do {
                try await service.rollbackFailedActivation(storage: storage)
            } catch {
                throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                    "activation failed (\(activationError.localizedDescription)); rollback failed (\(error.localizedDescription))"
                )
            }
            OtzariaMaktabahBridge.shared.resetConnection()
            if hadPrevious {
                do {
                    guard try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible() else {
                        throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                            "rollback restored the previous file but it could not be activated"
                        )
                    }
                } catch {
                    throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                        "activation failed (\(activationError.localizedDescription)); previous database restore failed (\(error.localizedDescription))"
                    )
                }
            }
            throw activationError
        }
        await service.finishSuccessfulInstall(storage: storage)
        return OtzariaManagedDatabaseInstallResult(
            release: prepared.release,
            finalURL: finalURL,
            resumeFromBytes: preparation.resumeFromBytes,
            downloadedBytes: prepared.release.asset.compressedSize,
            actualSHA256: preparation.actualSHA256,
            downloadElapsedSeconds: preparation.downloadElapsedSeconds,
            verificationElapsedSeconds: preparation.verificationElapsedSeconds,
            extractionElapsedSeconds: prepared.extractionElapsedSeconds,
            validationElapsedSeconds: prepared.validationElapsedSeconds,
            databaseFileSize: prepared.databaseFileSize
        )
    }

    static func cancelManagedDatabaseDownload() {
        Task {
            await OtzariaDatabaseBootstrapService.shared.cancel()
        }
    }
}
