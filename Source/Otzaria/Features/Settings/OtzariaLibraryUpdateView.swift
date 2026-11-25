import Foundation
import SwiftUI

extension Notification.Name {
    static let otzariaManagedLibraryDidUpdate = Notification.Name("otzariaManagedLibraryDidUpdate")
}

/// One owner across every Settings window. No timer or background launch
/// automatically replaces the user's library.
@MainActor @Observable
final class OtzariaLibraryUpdateController {
    static let shared = OtzariaLibraryUpdateController()

    enum Status: Equatable {
        case idle, available, current, installed, cancelled
    }

    private(set) var status: Status = .idle
    private(set) var installedTag: String?
    private(set) var availableRelease: OtzariaLibraryRelease?
    private(set) var isChecking = false
    private(set) var isInstalling = false
    private(set) var canCancel = false
    private(set) var progress: OtzariaDatabaseBootstrapProgress?
    private(set) var errorMessage: String?

    private var checkedSelection: OtzariaDatabaseAccessController.SelectionObservation?
    private var checkedManifest: OtzariaDatabaseInstallationManifest?
    private var installTask: Task<Void, Never>?

    private init() {}

    func checkForUpdate() async {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        errorMessage = nil
        availableRelease = nil
        installedTag = nil
        status = .idle
        defer { isChecking = false }
        do {
            let (selection, manifest) = try installationContext()
            installedTag = manifest.releaseTag
            let release = try await OtzariaLibraryReleaseClient().fetchLatestRelease()
            try Task.checkCancellation()
            let (currentSelection, currentManifest) = try installationContext()
            guard selection == currentSelection, manifest == currentManifest else {
                throw OtzariaLibraryUpdatePolicy.UpdateError.changedSelection
            }
            let newer = try OtzariaLibraryUpdatePolicy.isNewer(release, than: manifest)
            checkedSelection = selection
            checkedManifest = manifest
            availableRelease = newer ? release : nil
            status = newer ? .available : .current
        } catch is CancellationError {
            return
        } catch {
            checkedSelection = nil
            checkedManifest = nil
            errorMessage = error.localizedDescription
        }
    }

    func startUpdate() {
        guard !isChecking, !isInstalling,
              let release = availableRelease,
              let selection = checkedSelection,
              let manifest = checkedManifest else { return }
        isInstalling = true
        canCancel = true
        errorMessage = nil
        progress = nil
        installTask = Task {
            var acquiredResourceOwner = false
            defer {
                isInstalling = false
                canCancel = false
                installTask = nil
                // Also resume interrupted readers after a cancelled/failed
                // download against the still-installed previous snapshot.
                if acquiredResourceOwner, BackendCoordinator.shared.activeBackendID == .otzaria {
                    LibraryDataManager.shared.resetState()
                    NotificationCenter.default.post(name: .otzariaManagedLibraryDidUpdate, object: nil)
                }
            }
            do {
                try validateContext(selection: selection, manifest: manifest)
                let result = try await BackendCoordinator.shared.withExclusiveResourceUpdate(for: .otzaria) {
                    acquiredResourceOwner = true
                    return try await OtzariaBootstrapAdapter.downloadAndInstallManagedDatabase(
                        expectedRelease: release,
                        beforePromotion: {
                            try self.validateContext(selection: selection, manifest: manifest)
                            // Promotion/activation/rollback is one non-cancellable commit.
                            self.canCancel = false
                        }
                    ) { [weak self] update in
                        Task { @MainActor [weak self] in
                            guard let self, self.isInstalling else { return }
                            self.progress = update
                        }
                    }
                }
                let (_, committed) = try installationContext()
                guard committed.releaseID == result.release.id,
                      committed.archiveDigest == result.release.archiveDigest,
                      committed.archiveCompressedSize == result.release.compressedSize else {
                    throw OtzariaLibraryUpdatePolicy.UpdateError.unverifiedInstallation
                }
                installedTag = committed.releaseTag
                availableRelease = nil
                checkedManifest = committed
                checkedSelection = OtzariaDatabaseAccessController.shared.selectionObservation()
                status = .installed
            } catch is CancellationError {
                status = .cancelled
            } catch let error as OtzariaDatabaseBootstrapError {
                if case .cancelled = error {
                    status = .cancelled
                } else {
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        guard isInstalling, canCancel else { return }
        canCancel = false
        installTask?.cancel()
        OtzariaBootstrapAdapter.cancelManagedDatabaseDownload()
    }

    private func validateContext(
        selection: OtzariaDatabaseAccessController.SelectionObservation,
        manifest: OtzariaDatabaseInstallationManifest
    ) throws {
        let (currentSelection, currentManifest) = try installationContext(allowTransition: true)
        guard selection == currentSelection, manifest == currentManifest else {
            throw OtzariaLibraryUpdatePolicy.UpdateError.changedSelection
        }
    }

    private func installationContext(
        allowTransition: Bool = false
    ) throws -> (OtzariaDatabaseAccessController.SelectionObservation, OtzariaDatabaseInstallationManifest) {
        let coordinator = BackendCoordinator.shared
        guard coordinator.activeBackendID == .otzaria,
              allowTransition || !coordinator.isTransitioning,
              OtzariaDataProfileRegistry.activeProfileID == OtzariaDataProfileRegistry.productionID else {
            throw OtzariaLibraryUpdatePolicy.UpdateError.changedSelection
        }
        let selection = OtzariaDatabaseAccessController.shared.selectionObservation()
        let storage = try OtzariaDatabaseStorage()
        guard selection.source == .managedInternal,
              selection.url?.standardizedFileURL == storage.finalDatabaseURL.standardizedFileURL else {
            throw OtzariaLibraryUpdatePolicy.UpdateError.unmanagedLibrary
        }
        let manifestSize = try storage.installationManifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard manifestSize > 0, manifestSize <= 1_048_576 else {
            throw OtzariaLibraryUpdatePolicy.UpdateError.unverifiedInstallation
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            OtzariaDatabaseInstallationManifest.self,
            from: Data(contentsOf: storage.installationManifestURL)
        )
        try OtzariaLibraryUpdatePolicy.validateInstalled(manifest)
        let fileSize = try storage.finalDatabaseURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard fileSize.map(Int64.init) == manifest.databaseFileSize else {
            throw OtzariaLibraryUpdatePolicy.UpdateError.unverifiedInstallation
        }
        return (selection, manifest)
    }
}

struct OtzariaLibraryUpdateView: View {
    @Bindable private var controller = OtzariaLibraryUpdateController.shared

    var body: some View {
        Form {
            Section {
                Text("otzaria.update.explanation")
                if let tag = controller.installedTag {
                    LabeledContent("otzaria.update.installedVersion", value: tag)
                }
            }
            if controller.isChecking {
                Section { ProgressView("otzaria.update.checking") }
            } else if controller.isInstalling {
                Section {
                    ProgressView(value: controller.progress?.fraction ?? 0)
                    Text(controller.progress?.detail ?? String(localized: "bootstrap.status.connecting"))
                        .font(.callout)
                        .accessibilityIdentifier("otzaria-update-progress")
                    if controller.canCancel {
                        Button("otzaria.update.cancel", role: .cancel) { controller.cancel() }
                            .accessibilityIdentifier("otzaria-update-cancel")
                    }
                }
            } else {
                if let release = controller.availableRelease {
                    Section {
                        LabeledContent("otzaria.update.availableVersion", value: release.tag)
                        LabeledContent(
                            "otzaria.update.downloadSize",
                            value: ByteCountFormatter.string(fromByteCount: release.compressedSize, countStyle: .file)
                        )
                        Button("otzaria.update.install") { controller.startUpdate() }
                            .accessibilityIdentifier("otzaria-update-install")
                    }
                }
                if let error = controller.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("otzaria-update-error")
                    }
                }
                if controller.status == .current {
                    Section { Label("otzaria.update.current", systemImage: "checkmark.circle") }
                } else if controller.status == .installed {
                    Section { Label("otzaria.update.completed", systemImage: "checkmark.circle") }
                } else if controller.status == .cancelled {
                    Section { Text("otzaria.update.cancelled") }
                }
                Section {
                    Button("otzaria.update.check") {
                        Task { await controller.checkForUpdate() }
                    }
                    .accessibilityIdentifier("otzaria-update-check")
                }
            }
        }
        .navigationTitle("otzaria.update.title")
        .accessibilityIdentifier("otzaria-library-update-view")
        .task { await controller.checkForUpdate() }
    }
}

#if os(iOS)
@MainActor
enum OtzariaLibraryUpdateNavigation {
    /// The ordinary reader resolves stable locators again against the new
    /// database. A missing book remains visible as an error, never a dropped tab.
    static func reload(_ manager: iOSNavigationManager) {
        guard BackendCoordinator.shared.activeBackendID == .otzaria else { return }
        let generation = BackendCoordinator.shared.generation
        manager.searchViewModel.stopSearch()
        manager.unifiedSearchSession.handleBackendChanged()
        let resolver = ChavrusaTextTargetBackendBookResolver.shared
        manager.openTabs = manager.openTabs.map { tab in
            let reader = tab.viewModel
            reader.saveCurrentState()
            reader.backendLoadTask?.cancel()
            do {
                let book = try resolver.resolveBook(
                    id: tab.book.id, backendLocator: tab.book.backendLocator?.workKey,
                    title: tab.book.title, in: .otzaria
                )
                let locator = reader.currentLocator ?? reader.readerState.currentLocator
                reader.currentBook = book
                reader.navigationItems = []
                reader.needsScrollRestore = true
                reader.recordHistory = false
                if let locator {
                    reader.loadBackendContent(locator)
                } else {
                    reader.loadInitialContent(initialContentId: tab.initialContentId)
                }
                reader.loadTOC(book: book)
                return .init(id: tab.id, book: book, initialContentId: tab.initialContentId, viewModel: reader)
            } catch {
                reader.state = .error(String(localized: "otzaria.update.bookUnavailable"))
                return tab
            }
        }
        if let active = manager.activeTab { manager.selectedBook = active.book }
        StudyWorkspaceNavigationAdapter.managedLibraryDidUpdate(manager)
        manager.persistCurrentSession(immediate: true)
        Task { @MainActor [weak manager] in
            guard let manager,
                  BackendCoordinator.shared.activeBackendID == .otzaria,
                  BackendCoordinator.shared.generation == generation else { return }
            await manager.libraryViewModel.refreshLibrary()
            guard BackendCoordinator.shared.activeBackendID == .otzaria,
                  BackendCoordinator.shared.generation == generation else { return }
            NotificationCenter.default.post(name: .libraryBackendDataDidReload, object: nil)
        }
    }
}
#endif
