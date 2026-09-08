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
    var isChecking: Bool
    var requiresInitialSourceSelection: Bool
    var isUpdating = false
    var isCancellable = false

    // Core update alert state
    var showCoreUpdateAlert = false
    var availableCoreVersion: String?

    private let downloader = CoreDatabaseDownloader()
    private var didPrepare = false
    private var managedDownloadTask: Task<Void, Never>?
    private var managedDownloadGeneration = UUID()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let requiresSelection = defaults.object(
            forKey: BackendCoordinator.selectionDefaultsKey
        ) == nil
        requiresInitialSourceSelection = requiresSelection
        isChecking = !requiresSelection
    }

    func prepareIfNeeded() async {
        guard !didPrepare else { return }
        guard !requiresInitialSourceSelection else {
            isChecking = false
            return
        }
        didPrepare = true

        if !BackendCoordinator.shared.usesNativeMaktabahDataPath {
            finishSetup()
            return
        }

        do {
            if try await OtzariaBootstrapAdapter.restoreForAppLaunch() {
                finishSetup()
                return
            }
        } catch {
            presentError(
                title: String(localized: "bootstrap.error.savedDatabase.title"),
                detail: String(localized: "bootstrap.error.savedDatabase.detail")
            )
            return
        }

        // The iOS product is backed by Otzaria. Maktabah's legacy
        // main.sqlite/special.sqlite bundle is not a readiness gate here.
        isChecking = false
        coreDownloadState.totalSizeString = ""
        coreDownloadState.errorPresentation = nil
        coreDownloadState.phase = .confirmation
    }

    func selectInitialSource(_ source: BackendID) {
        defaults.set(source.rawValue, forKey: BackendCoordinator.selectionDefaultsKey)
        if BackendCoordinator.shared.activeBackendID != source {
            BackendCoordinator.shared.select(source)
        }
        requiresInitialSourceSelection = false
        didPrepare = false
        isChecking = true
        Task { [weak self] in
            await self?.prepareIfNeeded()
        }
    }

    func installOtzariaDatabase(from url: URL) {
        do {
            try OtzariaBootstrapAdapter.installDatabase(from: url)
            finishSetup()
        } catch {
            presentError(
                title: String(localized: "bootstrap.error.selectedDatabase.title"),
                detail: String(localized: "bootstrap.error.selectedDatabase.detail")
            )
        }
    }

    func handleDatabaseImportFailure() {
        presentError(
            title: String(localized: "bootstrap.error.selectedDatabase.title"),
            detail: String(localized: "bootstrap.error.selectedDatabase.detail")
        )
    }

    func startDownload() {
        managedDownloadTask?.cancel()
        managedDownloadGeneration = UUID()
        let generation = managedDownloadGeneration
        isChecking = false
        coreDownloadState.phase = .downloading
        coreDownloadState.progress = 0
        coreDownloadState.errorPresentation = nil
        coreDownloadState.detail = String(localized: "bootstrap.status.connecting")

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
                    coreDownloadState.errorPresentation = nil
                } else {
                    presentBootstrapError(error)
                }
            } catch is CancellationError {
                guard managedDownloadGeneration == generation else { return }
                coreDownloadState.phase = .confirmation
                coreDownloadState.progress = 0
                coreDownloadState.detail = ""
                coreDownloadState.errorPresentation = nil
            } catch {
                guard managedDownloadGeneration == generation else { return }
                presentInstallError(error)
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
        coreDownloadState.errorPresentation = nil
    }

    func continueWithLibraryOnly() {
        if OtzariaMaktabahBridge.shared.isEnabled {
            finishSetup()
        } else {
            presentError(
                title: String(localized: "bootstrap.error.databaseRequired.title"),
                detail: String(localized: "bootstrap.error.databaseRequired.detail")
            )
        }
    }

    private func installRecommendedSearchData(generation: UUID) async throws {
        coreDownloadState.detail = String(localized: "bootstrap.status.sharedLexical")
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
                self.coreDownloadState.detail = String(localized: "bootstrap.status.otzariaSearch")
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
                self.coreDownloadState.detail = String(localized: "bootstrap.status.zayitSearch")
            }
        }
        coreDownloadState.progress = 1
    }

    private func presentBootstrapError(_ error: OtzariaDatabaseBootstrapError) {
        if case let .insufficientDiskSpace(required, available) = error {
            presentInsufficientSpace(required: required, available: available)
        } else {
            presentError(
                title: String(localized: "bootstrap.error.install.title"),
                detail: String(localized: "bootstrap.error.install.detail")
            )
        }
    }

    private func presentInstallError(_ error: Error) {
        if let error = error as? OtzariaSearchArtifactError,
           case let .insufficientStorage(required, available) = error {
            presentInsufficientSpace(required: required, available: available)
        } else if let error = error as? ZayitSearchDistributionError,
                  case let .insufficientStorage(required, available) = error {
            presentInsufficientSpace(required: required, available: available)
        } else {
            presentError(
                title: String(localized: "bootstrap.error.install.title"),
                detail: String(localized: "bootstrap.error.install.detail")
            )
        }
    }

    private func presentInsufficientSpace(required: Int64, available: Int64) {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let requiredText = formatter.string(fromByteCount: required)
        let availableText = formatter.string(fromByteCount: available)
        let format = String(localized: "bootstrap.error.space.detail")
        presentError(
            title: String(localized: "bootstrap.error.space.title"),
            detail: String(format: format, locale: .current, requiredText, availableText),
            guidance: String(localized: "bootstrap.error.space.guidance")
        )
    }

    private func presentError(title: String, detail: String, guidance: String? = nil) {
        isChecking = false
        coreDownloadState.progress = 0
        coreDownloadState.errorPresentation = CoreDownloadErrorPresentation(
            title: title,
            detail: detail,
            guidance: guidance
        )
        coreDownloadState.phase = .error(detail)
    }

    private func finishSetup() {
        if BackendCoordinator.shared.usesNativeMaktabahDataPath {
            DatabaseManager.shared.reloadConnectionAndLibrary()
        } else {
            LibraryDataManager.shared.resetState()
        }
        isChecking = false
        coreDownloadState.errorPresentation = nil
        isReady = true

        // Check for core database updates (non-blocking, throttled 6 months)
        if BackendCoordinator.shared.usesNativeMaktabahDataPath,
           OtzariaBootstrapAdapter.shouldCheckCoreDatabaseUpdate {
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
