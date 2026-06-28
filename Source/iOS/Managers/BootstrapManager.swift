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

    // Core update alert state
    var showCoreUpdateAlert = false
    var availableCoreVersion: String?

    private let downloader = CoreDatabaseDownloader()
    private var didPrepare = false

    func prepareIfNeeded() {
        guard !didPrepare else { return }
        didPrepare = true

        if OtzariaMaktabahBridge.shared.isEnabled || downloader.areCoreFilesReady() || AppConfig.hasCustomDatabaseFolder() {
            finishSetup()
            return
        }

        downloader.fetchTotalDownloadSize { [weak self] size in
            Task { @MainActor in
                if size > 0 {
                    let mb = Double(size) / 1_048_576
                    self?.coreDownloadState.totalSizeString = String(format: "%.1f MB", mb)
                }
                self?.isChecking = false
                self?.coreDownloadState.phase = .confirmation
            }
        }
    }

    func installOtzariaDatabase(from url: URL) {
        do {
            try OtzariaMaktabahBridge.shared.installDatabase(from: url)
            finishSetup()
        } catch {
            coreDownloadState.phase = .error(error.localizedDescription)
            isChecking = false
        }
    }

    func startDownload() {
        isChecking = false
        coreDownloadState.phase = .downloading
        coreDownloadState.progress = 0
        coreDownloadState.detail = ""

        downloader.startDownload(
            onProgress: { [weak self] progress, detail in
                self?.coreDownloadState.progress = progress
                self?.coreDownloadState.detail = detail
            },
            onCompletion: { [weak self] error in
                guard let self else { return }
                if let error {
                    coreDownloadState.phase = .error(error.localizedDescription)
                    coreDownloadState.progress = 0
                    return
                }
                finishSetup()
            }
        )
    }

    private func finishSetup() {
        DatabaseManager.shared.setupFolders()
        if !OtzariaMaktabahBridge.shared.isEnabled {
            TarjamahGlobalManager.shared.setupConnection()
        }
        isChecking = false
        isReady = true

        // Check for core database updates (non-blocking, throttled 6 months)
        if !OtzariaMaktabahBridge.shared.isEnabled {
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
}
