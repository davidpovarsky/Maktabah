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

    func setBundleMode(_ enabled: Bool) {
        if enabled {
            SettingsActions.switchToBundleMode(
                onCompletion: { [weak self] in
                    self?.refreshPaths()
                }
            )
            return
        }
        let success = SettingsActions.selectLibraryFolder(
            showSuccessAlert: false,
            shouldTerminateOnCancel: false
        )
        if !success { isBundleMode = true }
        refreshPaths()
    }

    func chooseAnnotationsFolder() {
        SettingsActions.chooseAnnotationsAndResultsFolder()
        refreshPaths()
    }

    func chooseLibraryFolder() {
        let success = SettingsActions.selectLibraryFolder(
            showSuccessAlert: true,
            shouldTerminateOnCancel: false
        )
        if success { isBundleMode = false }
        refreshPaths()
    }

    func openFullLibraryDownload() {
        SettingsActions.openFullLibraryDownloadURL()
    }

    func openSelectiveDownload() {
        SettingsActions.downloadSelectiveLibrary()
    }

    func setICloud(_ enabled: Bool) {
        // Simpan nilai lama untuk rollback
        let previous = useICloud

        // Terapkan nilai baru optimistically, lalu disable toggle via flag terpisah
        useICloud = enabled
        isProcessingICloud = true

        AppConfig.setUseICloud(enabled) { [weak self] error in
            guard let self else { return }
            self.isProcessingICloud = false

            if let error {
                self.useICloud = previous  // rollback
                ReusableFunc.showAlert(
                    title: NSLocalizedString("errorICloud", comment: ""),
                    message: error.localizedDescription
                )
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
                PathRow(label: "Database Files", path: viewModel.databaseFilesPath)
                PathRow(label: "Archive Files", path: viewModel.archiveFilesPath)

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

                PathRow(label: "Current Path", path: viewModel.annotationsPath)

                Button("Choose Annotations Folder…") {
                    viewModel.chooseAnnotationsFolder()
                }
                .padding(.top, 4)
                .disabled(viewModel.useICloud)
            } header: {
                Text("Annotations & Search Results")
            }

            // MARK: Downloads
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
        .frame(minWidth: 520, minHeight: 480)
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
