import Foundation

@MainActor
enum OtzariaBootstrapAdapter {
    static func restoreForAppLaunch() throws -> Bool {
        let storage = try OtzariaDatabaseStorage()
        try OtzariaDatabaseInstaller().recoverInterruptedInstallation(storage: storage)
        return try OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()
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

    static func downloadAndInstallManagedDatabase(
        progress: @escaping OtzariaDatabaseBootstrapService.ProgressHandler
    ) async throws {
        let service = OtzariaDatabaseBootstrapService.shared
        let (prepared, storage) = try await service.prepareManagedDatabase(progress: progress)

        // No active SQLite handle may survive replacement of the managed DB.
        OtzariaMaktabahBridge.shared.resetConnection()
        OtzariaTantivySearchRepository.shared.closeAllEngines()

        let finalURL = try await service.promote(
            prepared,
            storage: storage,
            progress: progress
        )
        try OtzariaMaktabahBridge.shared.activateManagedDatabase(at: finalURL)
        await service.finishSuccessfulInstall(storage: storage)
    }

    static func cancelManagedDatabaseDownload() {
        Task {
            await OtzariaDatabaseBootstrapService.shared.cancel()
        }
    }
}
