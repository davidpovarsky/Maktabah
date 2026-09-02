import Foundation
import SwiftUI
import UIKit

final class LibraryDataManager {
    static let shared = LibraryDataManager()
    var allRootCategories: [CategoryData] = []
    var booksById: [Int: BooksData] = [:]
    var isDataLoaded = true

    func getBook(_ ids: [Int]) -> [BooksData] { ids.compactMap { booksById[$0] } }
    func categoryLevel(for book: BooksData) -> Int? { nil }
    func loadData() async {}
    func reloadAllData() async {}
    func resetState() {}
}

final class AnnotationManager {
    static let shared = AnnotationManager()
    var rootNode: AnnotationNode?
    func loadAnnotationById(_ id: Int64) -> Annotation? { nil }
    func loadAnnotations(bkId: Int, contentId: Int) -> [Annotation] { [] }
}

final class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    func resetChangeToken() {}
    func fetchChanges() {}
}

final class BookArchiveIntegrator {
    static let shared = BookArchiveIntegrator()
    var hasPendingVacuum = false
    func isBookIntegrated(_ book: BooksData) -> Bool { false }
    func vacuumPendingArchives() {}
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    var dbSpecial: Any?
    func getLocalVersionDisplay() -> String { "UI Workbench" }
}

enum ReusableFunc {
    static func showAlert(title: String, message: String) {}
}

enum AppConfig {
    enum MigrationResolution { case ask, keepDestination, overwriteDestination }

    static var isUsingBundleMode = true
    static var useICloud = false
    static var useCrossPlatformSync = false
    static var customWorkerURL = ""
    static var databaseFilesPath: String? { nil }
    static var archiveFilesPath: String? { nil }
    static var archiveCachePath: String? { nil }
    static let annotationsAndResultsFolder = "Annotations"

    static func folder(for name: String) -> URL? { nil }
    static func initializeMode() {}
    static func setupAnnotationsAndResults() {}
    static func setUseICloud(
        _ enabled: Bool,
        resolution: MigrationResolution,
        completion: @escaping (Error?) -> Void
    ) {
        useICloud = enabled
        completion(nil)
    }
    static func forceRefreshCoreVersion() {}
    static func markCoreVersionCheckDone(newVersion: String) {}
}

enum SettingsActions {
    @discardableResult
    static func selectLibraryFolder(
        showSuccessAlert: Bool,
        shouldTerminateOnCancel: Bool,
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        completion(false)
        return false
    }

    static func switchToBundleMode(onCompletion: @escaping () -> Void) { onCompletion() }
    static func chooseAnnotationsAndResultsFolder(
        resolution: AppConfig.MigrationResolution,
        retryURL: URL? = nil,
        completion: @escaping (Result<Void, Error>?) -> Void
    ) {
        completion(.success(()))
    }
    static func openFullLibraryDownloadURL() {}
    static func setUseCrossPlatformSync(_ enabled: Bool) {
        AppConfig.useCrossPlatformSync = enabled
    }
}

struct OfflineImportFormView: View {
    let onImport: (URL, PlaygroundOfflineBookMetadata, PlaygroundOfflineAuthorRow?) async -> Void

    init(
        onImport: @escaping (URL, PlaygroundOfflineBookMetadata, PlaygroundOfflineAuthorRow?) async -> Void
    ) {
        self.onImport = onImport
    }

    var body: some View {
        ContentUnavailableView(
            "Import Book",
            systemImage: "square.and.arrow.down",
            description: Text("Import is disabled in the UI-only workbench.")
        )
    }
}

final class CoreDownloadProgressState: ObservableObject {
    enum Phase: Equatable { case confirmation, downloading, error(String) }

    @Published var phase: Phase = .confirmation
    @Published var progress: Double = 0
    @Published var detail = ""
    @Published var totalSizeString = ""
}

enum MaktabahApp {
    static var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

extension Notification.Name {
    static let bookIntegrated = Notification.Name("ui-workbench.bookIntegrated")
    static let booksChanged = Notification.Name("ui-workbench.booksChanged")
    static let libraryFolderChanged = Notification.Name("ui-workbench.libraryFolderChanged")
    static let annotationTreeDidUpdate = Notification.Name("ui-workbench.annotationTreeDidUpdate")
    static let annotationDidChange = Notification.Name("ui-workbench.annotationDidChange")
    // annotationMissingBook is declared by the real iOSAnnotationViewController.
    static let savedResultsTreeDidUpdate = Notification.Name("ui-workbench.savedResultsTreeDidUpdate")
}
