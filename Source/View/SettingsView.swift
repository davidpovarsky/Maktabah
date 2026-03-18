//
//  SettingsView.swift
//  Maktabah
//

import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var isBundleMode: Bool = AppConfig.isUsingBundleMode
    @Published var databaseFilesPath: String = "N/A"
    @Published var archiveFilesPath: String = "N/A"
    @Published var annotationsPath: String = "N/A"

    init() {
        refreshPaths()
    }

    func refreshPaths() {
        databaseFilesPath = AppConfig.databaseFilesPath ?? "N/A"
        archiveFilesPath = AppConfig.archiveFilesPath ?? "N/A"
        annotationsPath =
            AppConfig.folder(for: AppConfig.annotationsAndResultsFolder)?
                .path ?? "N/A"
        isBundleMode = AppConfig.isUsingBundleMode
    }

    func setBundleMode(_ enabled: Bool) {
        if enabled {
            _ = SettingsActions.switchToBundleMode(showSuccessAlert: false)
            refreshPaths()
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
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

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
                PathRow(label: "Current Path", path: viewModel.annotationsPath)

                Button("Choose Annotations Folder…") {
                    viewModel.chooseAnnotationsFolder()
                }
                .padding(.top, 4)
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
