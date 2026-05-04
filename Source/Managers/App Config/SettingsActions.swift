//
//  SettingsActions.swift
//  Maktabah
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif
import Foundation

enum SettingsActions {
    private static let fullLibraryDownloadURL =
        "https://drive.google.com/file/d/1lAinUQ9Eh_W4_4r3MNfX84Ee3AOCVt_B/view?usp=share_link"
    #if os(macOS)
    private static var coreDownloadModal: CoreDownloadModalCenter?
    #elseif os(iOS)
    private static var documentPickerCoordinator: DocumentPickerCoordinator?
    #endif

    static func chooseAnnotationsAndResultsFolder() {
        #if os(macOS)
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
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        
        documentPickerCoordinator = DocumentPickerCoordinator(onPick: { url in
            do {
                try changeAnnotationsBaseUrl(to: url)
                AnnotationManager.shared.buildAnnotationTree()
            } catch {
                ReusableFunc.showAlert(
                    title: "errorFolderAnnotations".localized,
                    message: error.localizedDescription
                )
            }
            documentPickerCoordinator = nil
        }, onCancel: {
            documentPickerCoordinator = nil
        })
        picker.delegate = documentPickerCoordinator
        
        ReusableFunc.getTopViewController()?.present(picker, animated: true)
        #endif
    }

    static func selectLibraryFolder(
        showSuccessAlert: Bool,
        shouldTerminateOnCancel: Bool
    ) -> Bool {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.message = NSLocalizedString("appNeedAccess", comment: "")
        panel.prompt = NSLocalizedString("Choose Folder", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.level = .floating

        let response = panel.runModal()

        if response == .OK, let url = panel.url {
            return performLibraryFolderMigration(url: url, showSuccessAlert: showSuccessAlert)
        }

        if shouldTerminateOnCancel {
            showAccessNeededAlert()
            NSApp.terminate(nil)
        }

        return false
        #else
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        
        documentPickerCoordinator = DocumentPickerCoordinator(onPick: { url in
            _ = performLibraryFolderMigration(url: url, showSuccessAlert: showSuccessAlert)
            documentPickerCoordinator = nil
        }, onCancel: {
            documentPickerCoordinator = nil
        })
        picker.delegate = documentPickerCoordinator
        
        ReusableFunc.getTopViewController()?.present(picker, animated: true)
        return true // On iOS, we return true as we've shown the picker
        #endif
    }

    private static func performLibraryFolderMigration(url: URL, showSuccessAlert: Bool) -> Bool {
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

    private static func showAccessNeededAlert() {
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
    }
    
    #if os(macOS)
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
    #endif

    static func openFullLibraryDownloadURL() {
        guard let url = URL(string: fullLibraryDownloadURL) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
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

        #if os(macOS)
        guard newURL.startAccessingSecurityScopedResource() else {
            throw StorageError.cannotAccessSecurityScope
        }

        defer {
            newURL.stopAccessingSecurityScopedResource()
        }
        #endif

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

#if os(iOS)
class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
    var onPick: (URL) -> Void
    var onCancel: (() -> Void)?
    
    init(onPick: @escaping (URL) -> Void, onCancel: (() -> Void)? = nil) {
        self.onPick = onPick
        self.onCancel = onCancel
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            onCancel?()
            return
        }
        
        // Start accessing the security-scoped resource
        if url.startAccessingSecurityScopedResource() {
            onPick(url)
        } else {
            ReusableFunc.showAlert(title: "Access Denied", message: "Cannot access the selected folder.")
            onCancel?()
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onCancel?()
    }
}
#endif
