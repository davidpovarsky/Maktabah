import Foundation

@MainActor
enum OtzariaBootstrapAdapter {
    private static var installationInProgress = false
    private static var preparationTask: Task<OtzariaDatabaseBootstrapService.Preparation, Error>?
    static func restoreForAppLaunch() async throws -> Bool {
        // A second scene must not recover/finalize another scene's live commit.
        if installationInProgress { return OtzariaMaktabahBridge.shared.isEnabled }
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
            do {
                try OtzariaMaktabahBridge.shared.activateManagedDatabase(
                    at: storage.finalDatabaseURL
                )
                try installer.completePromotion(storage: storage)
                return true
            } catch {
                let commitError = error
                OtzariaMaktabahBridge.shared.resetConnection()
                OtzariaTantivySearchRepository.shared.closeAllEngines()
                try installer.rollbackPromotion(storage: storage)
                if try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible() { return true }
                throw commitError
            }
        }
        let restored = try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()
        if restored {
            try installer.completePromotion(storage: storage)
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
        guard !installationInProgress else {
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                String(localized: "otzaria.update.error.running")
            )
        }
        try OtzariaMaktabahBridge.shared.installDatabase(from: url)
    }

    @discardableResult
    static func downloadAndInstallManagedDatabase(
        expectedRelease: OtzariaLibraryRelease? = nil,
        beforePromotion: @MainActor () throws -> Void = {},
        progress: @escaping OtzariaDatabaseBootstrapService.ProgressHandler
    ) async throws -> OtzariaManagedDatabaseInstallResult {
        guard !installationInProgress else {
            throw OtzariaDatabaseBootstrapError.atomicInstallFailed(
                String(localized: "otzaria.update.error.running")
            )
        }
        installationInProgress = true
        defer { installationInProgress = false }
        let service = OtzariaDatabaseBootstrapService.shared
        let task = Task {
            try await service.prepareManagedDatabase(expectedRelease: expectedRelease, progress: progress)
        }
        preparationTask = task
        defer { preparationTask = nil }
        let preparation: OtzariaDatabaseBootstrapService.Preparation
        do {
            preparation = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch is CancellationError {
            throw OtzariaDatabaseBootstrapError.cancelled
        }
        preparationTask = nil
        let prepared = preparation.prepared
        let storage = preparation.storage
        do {
            guard !task.isCancelled, !Task.isCancelled else {
                throw OtzariaDatabaseBootstrapError.cancelled
            }
            try beforePromotion()
        } catch {
            await service.discardPrepared(prepared, storage: storage)
            throw error
        }

        // No active SQLite handle may survive replacement of the managed DB.
        OtzariaMaktabahBridge.shared.resetConnection()
        OtzariaTantivySearchRepository.shared.closeAllEngines()

        let finalURL: URL
        do {
            finalURL = try await service.promote(prepared, storage: storage, progress: progress)
        } catch {
            // promote() already restored its own failed filesystem commit.
            // Do not invoke rollback a second time and delete that old file.
            _ = try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()
            throw error
        }
        do {
            try OtzariaMaktabahBridge.shared.activateManagedDatabase(at: finalURL)
            try await service.finishSuccessfulInstall(storage: storage)
        } catch {
            let activationError = error
            let hadPrevious = FileManager.default.fileExists(
                atPath: storage.previousDatabaseURL.path
            )
            OtzariaMaktabahBridge.shared.resetConnection()
            OtzariaTantivySearchRepository.shared.closeAllEngines()
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
        return OtzariaManagedDatabaseInstallResult(
            release: prepared.release,
            finalURL: finalURL,
            resumeFromBytes: preparation.resumeFromBytes,
            downloadedBytes: prepared.release.compressedSize,
            actualSHA256: preparation.actualSHA256,
            downloadElapsedSeconds: preparation.downloadElapsedSeconds,
            verificationElapsedSeconds: preparation.verificationElapsedSeconds,
            extractionElapsedSeconds: prepared.extractionElapsedSeconds,
            validationElapsedSeconds: prepared.validationElapsedSeconds,
            databaseFileSize: prepared.databaseFileSize
        )
    }

    static func cancelManagedDatabaseDownload() {
        preparationTask?.cancel()
    }
}
