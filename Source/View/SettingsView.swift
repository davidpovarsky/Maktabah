//
//  SettingsView.swift
//  Maktabah
//

import SwiftUI

final class SettingsViewModel: ObservableObject {
    static var shared: SettingsViewModel = .init()
    @Published var isBundleMode: Bool = AppConfig.isUsingBundleMode
    @Published var databaseFilesPath: String = "N/A"
    @Published var archiveFilesPath: String = "N/A"
    @Published var annotationsPath: String = "N/A"
    @Published var useICloud: Bool = AppConfig.useICloud
    @Published var isProcessingICloud = false
    @Published var showCollisionAlert = false
    
    enum PendingCollisionAction {
        case icloud(use: Bool, previous: Bool)
        case moveFolder(url: URL)
    }
    
    private var pendingCollisionAction: PendingCollisionAction?

    #if DIRECT_DISTRIBUTION
    @Published var autoCheckAppUpdates: Bool = true


    func setAutoCheckAppUpdates(_ enabled: Bool) {
        UserDefaults.standard.autoCheckAppUpdates = enabled
        refreshPaths()
    }
    #endif

    private init() {
        refreshPaths()
    }

    func refreshPaths() {
        databaseFilesPath = AppConfig.databaseFilesPath ?? "N/A"
        archiveFilesPath = AppConfig.archiveFilesPath ?? "N/A"
        annotationsPath =
            AppConfig.folder(for: AppConfig.annotationsAndResultsFolder)?
                .path ?? "N/A"
        isBundleMode = AppConfig.isUsingBundleMode
        useICloud = AppConfig.useICloud
        #if DIRECT_DISTRIBUTION
        autoCheckAppUpdates = UserDefaults.standard.autoCheckAppUpdates
        #endif
    }
    
    #if os(macOS)
    func setBundleMode(_ enabled: Bool) {
        if enabled {
            SettingsActions.switchToBundleMode(
                onCompletion: { [weak self] in
                    self?.refreshPaths()
                }
            )
            return
        }
        _ = SettingsActions.selectLibraryFolder(
            showSuccessAlert: false,
            shouldTerminateOnCancel: false
        ) { [weak self] success in
            DispatchQueue.main.async {
                if !success { self?.isBundleMode = true }
                self?.refreshPaths()
            }
        }
    }
    #endif

    func chooseAnnotationsFolder() {
        SettingsActions.chooseAnnotationsAndResultsFolder(resolution: .ask) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.refreshPaths()
                case .failure(let error):
                    if let storageError = error as? StorageError, case .collision(let url) = storageError, let safeUrl = url {
                        self.pendingCollisionAction = .moveFolder(url: safeUrl)
                        self.showCollisionAlert = true
                    } else {
                        ReusableFunc.showAlert(
                            title: NSLocalizedString("errorFolderAnnotations", comment: ""),
                            message: error.localizedDescription
                        )
                    }
                case .none:
                    break // Cancelled
                }
            }
        }
    }

    func chooseLibraryFolder() {
        _ = SettingsActions.selectLibraryFolder(
            showSuccessAlert: true,
            shouldTerminateOnCancel: false
        ) { [weak self] success in
            DispatchQueue.main.async {
                if success { self?.isBundleMode = false }
                self?.refreshPaths()
            }
        }
    }

    #if os(macOS)
    func openFullLibraryDownload() {
        SettingsActions.openFullLibraryDownloadURL()
    }

    func openSelectiveDownload() {
        SettingsActions.downloadSelectiveLibrary()
    }
    #endif

    func setICloud(_ enabled: Bool) {
        let previous = useICloud
        if enabled {
            // Terapkan nilai baru optimistically, lalu disable toggle via flag terpisah
            useICloud = true
            isProcessingICloud = true

            AppConfig.setUseICloud(true, resolution: .ask) { [weak self] error in
                guard let self else { return }
                self.isProcessingICloud = false

                if let storageError = error as? StorageError, case .collision = storageError {
                    self.pendingCollisionAction = .icloud(use: true, previous: previous)
                    self.showCollisionAlert = true
                } else if let error {
                    self.useICloud = previous  // rollback
                    ReusableFunc.showAlert(
                        title: NSLocalizedString("errorICloud", comment: ""),
                        message: error.localizedDescription
                    )
                } else {
                    AnnotationManager.shared.buildAnnotationTree()
                }
                self.refreshPaths()
            }
        } else {
            useICloud = false
            isProcessingICloud = true
            SettingsActions.selectLocalFolderForICloudDisable { [weak self] url in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let url = url {
                        AppConfig.saveBookmark(url: url, key: AppConfig.annotationsAndResultsFolder)
                        
                        AppConfig.setUseICloud(false, resolution: .ask) { [weak self] error in
                            guard let self = self else { return }
                            self.isProcessingICloud = false
                            if let storageError = error as? StorageError, case .collision = storageError {
                                self.pendingCollisionAction = .icloud(use: false, previous: previous)
                                self.showCollisionAlert = true
                            } else if let error {
                                self.useICloud = previous
                                ReusableFunc.showAlert(
                                    title: NSLocalizedString("errorICloud", comment: ""),
                                    message: error.localizedDescription
                                )
                            } else {
                                AnnotationManager.shared.buildAnnotationTree()
                            }
                            self.refreshPaths()
                        }
                    } else {
                        self.useICloud = previous
                        self.isProcessingICloud = false
                        self.refreshPaths()
                    }
                }
            }
        }
    }

    func resolveCollision(_ resolution: AppConfig.MigrationResolution) {
        guard let action = pendingCollisionAction else { return }
        
        switch action {
        case .icloud(let use, let previous):
            if resolution == .ask {
                self.useICloud = previous
                self.refreshPaths()
                self.pendingCollisionAction = nil
                return
            }
            
            self.isProcessingICloud = true
            AppConfig.setUseICloud(use, resolution: resolution) { [weak self] error in
                guard let self = self else { return }
                self.isProcessingICloud = false
                self.pendingCollisionAction = nil
                if let error {
                    self.useICloud = previous
                    ReusableFunc.showAlert(
                        title: NSLocalizedString("errorICloud", comment: ""),
                        message: error.localizedDescription
                    )
                } else {
                    AnnotationManager.shared.buildAnnotationTree()
                }
                self.refreshPaths()
            }
            
        case .moveFolder(let url):
            if resolution == .ask {
                self.pendingCollisionAction = nil
                return
            }
            
            SettingsActions.chooseAnnotationsAndResultsFolder(resolution: resolution, retryURL: url) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.pendingCollisionAction = nil
                    switch result {
                    case .success:
                        self.refreshPaths()
                    case .failure(let error):
                        ReusableFunc.showAlert(
                            title: NSLocalizedString("errorFolderAnnotations", comment: ""),
                            message: error.localizedDescription
                        )
                    case .none:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        Form {
            // MARK: Database Mode
            #if os(macOS)
            Section {
                Toggle(isOn: Binding(
                    get: { viewModel.isBundleMode },
                    set: { viewModel.setBundleMode($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bundle Mode")
                        Text("Use the app's built-in database (read-only). For the Full Library, disable this and choose a custom folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }.controlSize(.regular)
            } header: {
                Text("Database Mode")
            }

            // MARK: Library Storage
            Section {
                if !viewModel.isBundleMode {
                    PathRow(label: "Database Files", path: viewModel.databaseFilesPath)
                    PathRow(label: "Archive Files", path: viewModel.archiveFilesPath)
                }

                HStack(spacing: 8) {
                    Button("Choose Library Folder…") {
                        viewModel.chooseLibraryFolder()
                    }
                    Button("Switch to Bundle Mode") {
                        viewModel.setBundleMode(true)
                    }
                    .disabled(viewModel.isBundleMode)
                }
                .padding(.top, 4)
            } header: {
                Text("Library Storage")
            }
            #endif

            // MARK: Annotations & Search Results
            Section {
                Toggle(isOn: Binding(
                    get: { viewModel.useICloud },
                    set: { viewModel.setICloud($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use iCloud")
                        Text("Sync annotations and search results across devices using iCloud Drive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .controlSize(.regular)
                .disabled(viewModel.isProcessingICloud)

                if !viewModel.useICloud {
                    PathRow(label: "Current Path", path: viewModel.annotationsPath)
                }

                Button("Choose Annotations Folder…") {
                    viewModel.chooseAnnotationsFolder()
                }
                .padding(.top, 4)
                .disabled(viewModel.useICloud)
            } header: {
                Text("Annotations & Search Results")
            }

            // MARK: Downloads
            #if os(macOS)
            Section {
                HStack(spacing: 8) {
                    Button("Download Full Library (Google Drive)") {
                        viewModel.openFullLibraryDownload()
                    }
                    Button("Download Selective Library…") {
                        viewModel.openSelectiveDownload()
                    }
                }
                Label {
                    Text("Full Library will open the download link in your browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Downloads")
            }
            #endif

            // MARK: Updates
            #if DIRECT_DISTRIBUTION
            Section {
                Toggle(isOn: Binding(
                    get: { viewModel.autoCheckAppUpdates },
                    set: { viewModel.setAutoCheckAppUpdates($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Application Update")
                        Text("Check at Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }.controlSize(.regular)
            } header: {
                Text("Updates")
            }
            #endif
        }
        .formStyle(.grouped)
        .controlSize(.large)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 480)
        #endif
        .alert(.annotationMoveFolderFileExistsTitle, isPresented: $viewModel.showCollisionAlert) {
            Button(.keepExistingDeleteOld) {
                viewModel.resolveCollision(.keepDestination)
            }
            Button(.overwriteExisting, role: .destructive) {
                viewModel.resolveCollision(.overwriteDestination)
            }
            Button("Cancel", role: .cancel) {
                viewModel.resolveCollision(.ask) // used as cancel
            }
        } message: {
            Text(.annotationsMoveFolderFileExistsDesc)
        }
    }
}

// MARK: - Helpers

private struct PathRow: View {
    let label: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(path)
                .font(.footnote)
                .monospaced()
                .textSelection(.enabled)
                .foregroundStyle(path == "N/A" ? .tertiary : .primary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
