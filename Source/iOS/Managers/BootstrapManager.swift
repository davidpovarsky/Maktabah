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

    private let downloader = CoreDatabaseDownloader()
    private var didPrepare = false

    func prepareIfNeeded() {
        guard !didPrepare else { return }
        didPrepare = true

        if downloader.areCoreFilesReady() || AppConfig.hasCustomDatabaseFolder() {
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
        TarjamahGlobalManager.shared.setupConnection()
        isChecking = false
        isReady = true
    }
}
