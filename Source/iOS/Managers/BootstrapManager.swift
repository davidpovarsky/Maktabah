//
//  BootstrapManager.swift
//  Maktabah-iOS
//
//  Created by Ghoys Mawahib on 03/05/26.
//

import SwiftUI

// MARK: - Bootstrap

@MainActor
@Observable
final class iOSBootstrapManager {
    var isReady = false
    var coreDownloadState = CoreDownloadProgressState()
    var isChecking = true
    var isUpdating = false
    var isCancellable = false

    // Core update alert state
    var showCoreUpdateAlert = false
    var availableCoreVersion: String?

    private let downloader = CoreDatabaseDownloader()
    private var didPrepare = false
    private var managedDownloadTask: Task<Void, Never>?
    private var managedDownloadGeneration = UUID()

    func prepareIfNeeded() async {
        guard !didPrepare else { return }
        didPrepare = true

        do {
            if try await OtzariaBootstrapAdapter.restoreForAppLaunch() {
                finishSetup()
                return
            }
        } catch {
            isChecking = false
            coreDownloadState.phase = .error(
                "The saved Otzaria database could not be reopened. " +
                "Choose the database again.\n\n\(error.localizedDescription)"
            )
            return
        }

        // The iOS product is backed by Otzaria. Maktabah's legacy
        // main.sqlite/special.sqlite bundle is not a readiness gate here.
        isChecking = false
        coreDownloadState.totalSizeString = ""
        coreDownloadState.phase = .confirmation
    }

    func installOtzariaDatabase(from url: URL) {
        do {
            try OtzariaBootstrapAdapter.installDatabase(from: url)
            finishSetup()
        } catch {
            coreDownloadState.phase = .error(error.localizedDescription)
            isChecking = false
        }
    }

    func startDownload() {
        managedDownloadTask?.cancel()
        managedDownloadGeneration = UUID()
        let generation = managedDownloadGeneration
        isChecking = false
        coreDownloadState.phase = .downloading
        coreDownloadState.progress = 0
        coreDownloadState.detail = "Connecting to Otzaria Library…"

        managedDownloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase { [weak self] update in
                    Task { @MainActor in
                        guard let self, self.managedDownloadGeneration == generation else { return }
                        self.coreDownloadState.phase = .downloading
                        self.coreDownloadState.progress = update.fraction * 0.25
                        self.coreDownloadState.detail = update.detail
                    }
                }
                guard !Task.isCancelled, managedDownloadGeneration == generation else { return }
                try await installRecommendedSearchData(generation: generation)
                finishSetup()
            } catch let error as OtzariaDatabaseBootstrapError {
                guard managedDownloadGeneration == generation else { return }
                if case .cancelled = error {
                    coreDownloadState.phase = .confirmation
                    coreDownloadState.progress = 0
                    coreDownloadState.detail = ""
                } else {
                    coreDownloadState.phase = .error(error.localizedDescription)
                    coreDownloadState.progress = 0
                }
            } catch is CancellationError {
                guard managedDownloadGeneration == generation else { return }
                coreDownloadState.phase = .confirmation
                coreDownloadState.progress = 0
                coreDownloadState.detail = ""
            } catch {
                guard managedDownloadGeneration == generation else { return }
                coreDownloadState.phase = .error(error.localizedDescription)
                coreDownloadState.progress = 0
            }
            managedDownloadTask = nil
        }
    }

    func cancelManagedDownload() {
        managedDownloadGeneration = UUID()
        OtzariaBootstrapAdapter.cancelManagedDatabaseDownload()
        Task {
            await OtzariaSearchArtifactService.shared.cancel()
            await ZayitSearchArtifactService.shared.cancel()
        }
        managedDownloadTask?.cancel()
        managedDownloadTask = nil
        coreDownloadState.phase = .confirmation
        coreDownloadState.progress = 0
        coreDownloadState.detail = ""
    }

    func continueWithLibraryOnly() {
        if OtzariaMaktabahBridge.shared.isEnabled {
            finishSetup()
        } else {
            coreDownloadState.phase = .error("Install or choose the required Seforim database first.")
        }
    }

    private func installRecommendedSearchData(generation: UUID) async throws {
        coreDownloadState.detail = "Installing shared lexical data…"
        _ = try await OtzariaMagicDictionaryManager.shared.refreshIfNeeded(force: true)
        coreDownloadState.progress = 0.35
        guard managedDownloadGeneration == generation,
              let databasePath = OtzariaMaktabahBridge.shared.databasePath,
              let databaseURL = OtzariaMaktabahBridge.shared.databaseURL,
              let lexicalURL = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL else {
            throw CancellationError()
        }

        _ = try await OtzariaSearchArtifactService.shared.install(databasePath: databasePath) { [weak self] update in
            Task { @MainActor in
                guard let self, self.managedDownloadGeneration == generation else { return }
                let fraction = update.totalBytes > 0
                    ? Double(update.completedBytes) / Double(update.totalBytes) : 0
                self.coreDownloadState.progress = 0.35 + min(1, fraction) * 0.35
                self.coreDownloadState.detail = "Installing Otzaria search data…"
            }
        }

        try await ZayitSearchArtifactService.shared.install(
            databaseURL: databaseURL,
            lexicalDatabaseURL: lexicalURL
        ) { [weak self] state in
            Task { @MainActor in
                guard let self, self.managedDownloadGeneration == generation else { return }
                switch state {
                case .downloading(let completed, let total), .installing(let completed, let total):
                    let fraction = total > 0 ? Double(completed) / Double(total) : 0
                    self.coreDownloadState.progress = 0.70 + min(1, fraction) * 0.30
                default: break
                }
                self.coreDownloadState.detail = "Installing Zayit search data…"
            }
        }
        coreDownloadState.progress = 1
    }

    private func finishSetup() {
        DatabaseManager.shared.reloadConnectionAndLibrary()
        isChecking = false
        isReady = true

        // Check for core database updates (non-blocking, throttled 6 months)
        if OtzariaBootstrapAdapter.shouldCheckCoreDatabaseUpdate {
            checkCoreDatabaseUpdate()
        }
    }

    private func checkCoreDatabaseUpdate() {
        // Hanya check jika di bundle mode dan core files sudah ada
        guard AppConfig.isUsingBundleMode, downloader.areCoreFilesReady() else { return }

        Task.detached(priority: .low) { [weak self] in
            let result = await CoreUpdateChecker.checkAsync()

            guard case .updateAvailable(let newVersion) = result else { return }

            await MainActor.run { [weak self] in
                self?.availableCoreVersion = newVersion
                self?.showCoreUpdateAlert = true
            }
        }
    }

    func performCoreUpdate() {
        guard let version = availableCoreVersion else { return }
        isUpdating = true

        // Reset state untuk download
        coreDownloadState.phase = .downloading
        coreDownloadState.progress = 0
        coreDownloadState.detail = ""

        downloader.updateToVersion(
            version,
            onProgress: { [weak self] progress, detail in
                self?.coreDownloadState.progress = progress
                self?.coreDownloadState.detail = detail
            },
            onCompletion: { [weak self] error in
                guard let self else { return }

                if let error {
                    coreDownloadState.phase = .error(error.localizedDescription)
                    coreDownloadState.progress = 0
                    showCoreUpdateAlert = false
                    isUpdating = false
                    return
                }

                // Berhasil - reload database
                DatabaseManager.shared.reloadConnectionAndLibrary()
                showCoreUpdateAlert = false
                availableCoreVersion = nil
                isUpdating = false
            }
        )
    }

    func reloadLibrary(isCancellable: Bool = false) {
        self.isCancellable = isCancellable
        didPrepare = false
        isReady = false
        Task { [weak self] in
            await self?.prepareIfNeeded()
        }
    }

    func cancelDownload() {
        SettingsActions.cancelBundleModeSwitch()
        isChecking = false
        isReady = true
    }

    func chooseLibraryFolder() {
        _ = SettingsActions.selectLibraryFolder(showSuccessAlert: false, shouldTerminateOnCancel: false) { [weak self] success in
            if success {
                Task { @MainActor in
                    self?.finishSetup()
                }
            }
        }
    }
}
