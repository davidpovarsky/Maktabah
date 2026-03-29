//
//  SettingsActions.swift
//  Maktabah
//

import Cocoa
import Foundation

enum SettingsActions {
    private static let fullLibraryDownloadURL =
        "https://drive.google.com/file/d/1lAinUQ9Eh_W4_4r3MNfX84Ee3AOCVt_B/view?usp=share_link"
    private static var coreDownloadModal: CoreDownloadModalCenter?

    static func chooseAnnotationsAndResultsFolder() {
        let panel = NSOpenPanel()
        panel.message = NSLocalizedString("personalFolder", comment: "")
        panel.prompt = NSLocalizedString("Choose Folder", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.level = .floating

        let response = panel.runModal()

        if response == .OK, let url = panel.url {
            do {
                try changeAnnotationsBaseUrl(to: url)
            } catch {
                ReusableFunc.showAlert(
                    title: "errorFolderAnnotations".localized,
                    message: error.localizedDescription
                )
            }

            AnnotationManager.shared.buildAnnotationTree()
        }
    }

    static func selectLibraryFolder(
        showSuccessAlert: Bool,
        shouldTerminateOnCancel: Bool
    ) -> Bool {
        let panel = NSOpenPanel()
        panel.message = NSLocalizedString("appNeedAccess", comment: "")
        panel.prompt = NSLocalizedString("Choose Folder", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.level = .floating

        let response = panel.runModal()

        if response == .OK, let url = panel.url {
            let migrateSuccess = AppConfig.migrateToCustomMode(folderUrl: url)

            if !migrateSuccess {
                ReusableFunc.showAlert(
                    title: String(localized: "migrationFailed"),
                    message: String(localized: "migrationFailedInfo")
                )
                return false
            }

            LibraryDataManager.shared.resetState()
            DatabaseManager.shared.setupFolders()
            TarjamahGlobalManager.shared.setupConnection()

            if showSuccessAlert {
                ReusableFunc.showAlert(
                    title: "masterFolderRenewed".localized,
                    message: "masterFolderRenewedInfo".localized
                )
            }

            NotificationCenter.default.post(
                name: .libraryFolderChanged,
                object: nil
            )

            #if DEBUG
                print("Custom folder selected and migrated: \(url.path)")
            #endif
            return true
        }

        if shouldTerminateOnCancel {
            ReusableFunc.showAlert(
                title: NSLocalizedString(
                    "AccessNeeded",
                    comment: "Alert Memilih Folder Master"
                ),
                message: NSLocalizedString(
                    "FolderMasterPenjelasan",
                    comment: "Informasi Alert Memilih Folder Master"
                )
            )
            NSApp.terminate(nil)
        }

        return false
    }

    static func switchToBundleMode(onCompletion: (() -> Void)? = nil) {
        let wasBundleMode = AppConfig.isUsingBundleMode
        let previousCustomBookmark = UserDefaults.standard.data(
            forKey: AppConfig.customDatabaseFolderKey
        )

        AppConfig.migrateToBundleMode()

        let finishSetup = {
            LibraryDataManager.shared.resetState()
            DatabaseManager.shared.setupFolders()
            TarjamahGlobalManager.shared.setupConnection()
            NotificationCenter.default.post(
                name: .libraryFolderChanged,
                object: nil
            )
        }

        let restorePreviousMode = {
            if let previousCustomBookmark {
                UserDefaults.standard.set(
                    previousCustomBookmark,
                    forKey: AppConfig.customDatabaseFolderKey
                )
                AppConfig.isUsingBundleMode = false
            } else {
                AppConfig.isUsingBundleMode = wasBundleMode
            }
        }

        let downloader = CoreDatabaseDownloader()
        if !downloader.areBundleCoreFilesReady() {
            let modal = CoreDownloadModalCenter(downloader: downloader)
            coreDownloadModal = modal
            modal.runNonBlocking { result in
                switch result {
                case .downloaded:
                    finishSetup()
                case .choseFolder:
                    break
                case .quit:
                    restorePreviousMode()
                }
                onCompletion?()
                coreDownloadModal = nil
            }
        } else {
            finishSetup()
            onCompletion?()
        }
    }

    static func downloadSelectiveLibrary() {
        BulkDownloadModalCenter.shared.presentModal()
    }

    static func openFullLibraryDownloadURL() {
        guard let url = URL(string: fullLibraryDownloadURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func changeAnnotationsBaseUrl(to newURL: URL) throws {
        let fm = FileManager.default

        let oldURL = AppConfig.folder(
            for: AppConfig.annotationsAndResultsFolder
        )

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: newURL.path, isDirectory: &isDir),
              isDir.boolValue
        else {
            throw StorageError.invalidDirectory
        }

        guard newURL.startAccessingSecurityScopedResource() else {
            throw StorageError.cannotAccessSecurityScope
        }

        defer {
            newURL.stopAccessingSecurityScopedResource()
        }

        if let oldURL, fm.fileExists(atPath: oldURL.path) {
            let filesToMove = ["Annotations.sqlite", "SearchResults.sqlite"]

            for fileName in filesToMove {
                let sourceFile = oldURL.appendingPathComponent(fileName)
                let destFile = newURL.appendingPathComponent(fileName)

                if fm.fileExists(atPath: sourceFile.path)
                    && !fm.fileExists(atPath: destFile.path)
                {
                    try fm.moveItem(at: sourceFile, to: destFile)
                } else {
                    try fm.removeItem(at: sourceFile)
                }
            }
        }

        AppConfig.saveBookmark(
            url: newURL,
            key: AppConfig.annotationsAndResultsFolder
        )

        try AnnotationManager.shared.setupAnnotations(at: newURL)
        try ResultsHandler.shared.setupResultDatabase(at: newURL)
    }
}
