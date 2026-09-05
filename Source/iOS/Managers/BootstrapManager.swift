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
    private var reconciliation: OtzariaDataReconciliationSnapshot?

    func prepareIfNeeded() async {
        guard !didPrepare else { return }
        didPrepare = true

        let snapshot = await OtzariaDataReconciliationService.shared.reconcile()
        reconciliation = snapshot
        updateComponentDetails(snapshot)

        if case .failed(let detail) = snapshot.database {
            isChecking = false
            coreDownloadState.phase = .error(
                "The saved Otzaria database could not be reopened. " +
                "Choose the database again.\n\n\(detail)"
            )
            return
        }

        if snapshot.isReady {
            finishSetup()
            return
        }

        // The iOS product is backed by Otzaria. Maktabah's legacy
        // main.sqlite/special.sqlite bundle is not a readiness gate here.
        isChecking = false
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
                let initial: OtzariaDataReconciliationSnapshot
                if let reconciliation {
                    initial = reconciliation
                } else {
                    initial = await OtzariaDataReconciliationService.shared.reconcile()
                }
                if !initial.database.isReady {
                    try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase { [weak self] update in
                        Task { @MainActor in
                            guard let self, self.managedDownloadGeneration == generation else { return }
                            self.coreDownloadState.phase = .downloading
                            self.coreDownloadState.progress = update.fraction * 0.25
                            self.coreDownloadState.detail = update.detail
                        }
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
        var snapshot = await OtzariaDataReconciliationService.shared.reconcile(
            restoreDatabase: false
        )
        if !snapshot.lexicalDatabase.isReady {
            coreDownloadState.detail = "Installing shared lexical data…"
            _ = try await OtzariaMagicDictionaryManager.shared.refreshIfNeeded(force: true)
        }
        coreDownloadState.progress = 0.35
        guard managedDownloadGeneration == generation,
              let databasePath = OtzariaMaktabahBridge.shared.databasePath,
              let databaseURL = OtzariaMaktabahBridge.shared.databaseURL,
              let lexicalURL = OtzariaMagicDictionaryManager.shared.validatedDatabaseURL else {
            throw CancellationError()
        }

        snapshot = await OtzariaDataReconciliationService.shared.reconcile(
            restoreDatabase: false
        )
        if !snapshot.otzariaIndex.isReady {
            _ = try await OtzariaSearchArtifactService.shared.install(databasePath: databasePath) { [weak self] update in
                Task { @MainActor in
                    guard let self, self.managedDownloadGeneration == generation else { return }
                    let fraction = update.totalBytes > 0
                        ? Double(update.completedBytes) / Double(update.totalBytes) : 0
                    self.coreDownloadState.progress = 0.35 + min(1, fraction) * 0.35
                    self.coreDownloadState.detail = "Installing Otzaria search data…"
                }
            }
        }

        snapshot = await OtzariaDataReconciliationService.shared.reconcile(
            restoreDatabase: false
        )
        if !snapshot.zayitIndex.isReady {
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
        }

        let final = await OtzariaDataReconciliationService.shared.reconcile(
            restoreDatabase: false
        )
        reconciliation = final
        updateComponentDetails(final)
        guard final.isReady else {
            throw NSError(
                domain: "OtzariaDataReconciliation",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "One or more data components did not become ready after installation."
                ]
            )
        }
        coreDownloadState.progress = 1
    }

    private func updateComponentDetails(_ snapshot: OtzariaDataReconciliationSnapshot) {
        let profile = OtzariaDataProfileRegistry.activeProfile
        let components: [(
            OtzariaArtifactComponent,
            String,
            Bool,
            OtzariaDataReconciliationSnapshot.ComponentState
        )] = [
            (.database, "Seforim DB", true, snapshot.database),
            (.lexicalDatabase, "Shared lexical.db", false, snapshot.lexicalDatabase),
            (.otzariaIndex, "Otzaria lexical index", false, snapshot.otzariaIndex),
            (.zayitIndex, "Zayit index", false, snapshot.zayitIndex),
        ]
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        coreDownloadState.componentDetails = components.map { component, title, required, state in
            let role = required ? "Required" : "Recommended"
            let status = state.isReady ? "Ready" : "Install or repair"
            let detail: String
            if let descriptor = profile?.artifact(component) {
                let plan = OtzariaInstallCapacityCalculator.plan(
                    descriptor: descriptor,
                    existingInstallBytes: 0,
                    retainsRollbackCopy: false
                )
                detail = "\(role) · \(formatter.string(fromByteCount: descriptor.compressedBytes)) download · " +
                    "\(formatter.string(fromByteCount: descriptor.extractedBytes)) installed · " +
                    "\(formatter.string(fromByteCount: plan.peakAdditionalBytes)) free required · \(status)"
            } else {
                detail = "\(role) · sizes loaded from the release manifest · \(status)"
            }
            return CoreDownloadComponentDetail(
                id: component.rawValue,
                title: title,
                detail: detail,
                isReady: state.isReady
            )
        }
        if let profile, !profile.artifacts.isEmpty {
            let totalDownload = profile.artifacts.reduce(Int64(0)) {
                $0 + $1.compressedBytes
            }
            coreDownloadState.totalSizeString = formatter.string(
                fromByteCount: totalDownload
            )
        } else {
            coreDownloadState.totalSizeString = ""
        }
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
