import Foundation
import SwiftUI
import UIKit

// MARK: - Minimal backend-shaped API used by real presentation files

final class BookConnection {
    init() {}
}

final class ResultsHandler: @unchecked Sendable {
    static let shared = ResultsHandler()
    private init() {}

    func fetchFolderTree() -> [FolderNode] { [] }
    func fetchResults(forFolder folderId: Int64?) -> [ResultNode] { [] }
    func insertRootFolder(name: String) throws -> Int64? { nil }
    func insertSubFolder(parentNode: FolderNode, name: String) throws -> Int64? { nil }
    func updateFolderName(id: Int64, newName: String) throws {}
    func updateResultQueryName(folderId: Int64?, oldName: String, newName: String) throws {}
    func deleteFolder(_ id: Int64) {}
    func deleteResult(_ folderId: Int64?, name: String) {}
    func insertResult(
        _ archive: Int,
        bkId: Int,
        contentId: String,
        folderId: Int64?,
        query: String,
        name: String
    ) throws {}
    func updateParent(of id: Int64, to parentId: Int64?) throws {}
    func updateResultsFolder(oldFolderId: Int64, newFolderId: Int64) {}
    func updateResultParent(newParentId: Int64?, oldParent: Int64?, name: String) throws {}
}

extension SearchViewModel {
    func loadSavedResults(_ items: [SavedResultsItem]) {
        // The workbench intentionally does not read saved-result storage.
        // Keeping the call surface lets the production Saved Results UI compile.
        results = []
    }
}

extension AnnotationViewModel {
    var onIncrementalUpdate: ((AnnotationChangeType, [AnyHashable: Any]) -> Void)? {
        get { nil }
        set {}
    }

    var onTreeUpdate: (([AnnotationNode], AnnotationGroupingMode) -> Void)? {
        get { nil }
        set {}
    }

    func deleteAnnotation(id: Int64) {}
}

extension BookTOCViewModel {
    var tocRanges: [TOCRange] { [] }
}

extension ReaderViewModel {
    var otzariaAvailableUnitModes: [OtzariaUnitLevelOption] {
        [
            .init(id: "line", title: "Line", level: nil, mode: .line),
            .init(id: "paragraph", title: "Paragraph", level: nil, mode: .paragraph),
            .init(id: "chapter", title: "Chapter", level: nil, mode: .chapter),
        ]
    }

    var otzariaUnitMode: OtzariaUnitMode {
        get { .paragraph }
        set {}
    }

    func setOtzariaUnitMode(_ mode: OtzariaUnitMode) {}

    func findBestAnnotation(for range: NSRange) -> Annotation? { nil }
}

extension AnnotationManager {
    func loadAnnotations(bkId: Int) -> [Annotation] { [] }
}

extension LibraryDataManager {
    var categoryMap: [Int: CategoryData] {
        var result: [Int: CategoryData] = [:]
        func walk(_ categories: [CategoryData]) {
            for category in categories {
                result[category.id] = category
                walk(category.children.compactMap { $0 as? CategoryData })
            }
        }
        walk(allRootCategories)
        return result
    }

    func loadBookInfo(_ bookId: Int, completion: @escaping () -> Void) {
        completion()
    }
}

extension DatabaseManager {
    func getAuthor(_ id: Int) -> Muallif? { nil }
}

extension ReusableFunc {
    @MainActor
    static func getTopViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        var current = root
        while let presented = current?.presentedViewController { current = presented }
        if let navigation = current as? UINavigationController { return navigation.visibleViewController ?? navigation }
        if let tab = current as? UITabBarController { return tab.selectedViewController ?? tab }
        return current
    }
}

extension UIColor {
    static var appBackground: UIColor { .systemBackground }
    static var appCellBackground: UIColor { .secondarySystemBackground }
}

// MARK: - Otzaria presentation compatibility

extension OtzariaMaktabahBridge {
    var databaseURL: URL? { nil }
    var databasePath: String? { databaseURL?.path }

    func fetchOtzariaAuthorsWithBookCounts() throws -> [OtzariaAuthor] { [] }
    func fetchBooksForOtzariaAuthor(authorId: Int) throws -> [BooksData] { [] }
}

extension PlaygroundOtzariaSearchStatus {
    static var paused: Self { .unavailable }
}

extension OtzariaTextSearchViewModel {
    var groupCount: Int? { grouping == nil ? nil : 0 }
    var isReady: Bool { status == .ready }

    func indexLogCopyText() -> String { OtzariaIndexFileLogger.readLog() }
    func installManagedArtifactAndWait() async -> Bool { true }
    func removeManagedIndex() {
        status = .unavailable
        results = []
        totalCount = 0
    }
}

extension OtzariaMagicDictionaryManager {
    func refreshIfNeeded(force: Bool) async throws -> URL? { validatedDatabaseURL }
}

enum OtzariaBootstrapAdapter {
    static func downloadAndInstallManagedDatabase(
        progress: @escaping (OtzariaDatabaseBootstrapProgress) -> Void
    ) async throws {
        progress(.init(stage: .ready, fraction: 1, detail: "UI workbench"))
    }
}

struct OtzariaDatabaseStorage {
    var installationManifestURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-ui-workbench-install.json")
    }
    init() throws {}
}

struct PlaygroundOtzariaSearchBuildInfo {
    let upstreamCommit = "ui-workbench"
    let indexSchemaVersion: UInt32 = 0
    let semanticEnabled = false
}

extension OtzariaSearchEngineBridge {
    static func buildInfo() throws -> PlaygroundOtzariaSearchBuildInfo {
        .init()
    }
}

final class OtzariaSearchIndexManager {
    static let shared = OtzariaSearchIndexManager()
    private init() {}
    func semanticArtifactURL(for databasePath: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("otzaria-ui-workbench-semantic")
    }
}

// MARK: - Zayit search-data UI compatibility

struct ZayitSearchArtifactManifest: Codable, Equatable {
    struct Engine: Codable, Equatable {
        var indexSchemaVersion: UInt32 = 0
        var builderVersion: String = "ui-workbench"
        var builderCommit: String = "ui-workbench"
        var upstreamCommit: String = "ui-workbench"
    }

    var version: String = "UI Workbench"
    var artifactIdentity: String = "ui-workbench"
    var engine: Engine = .init()
}

struct ZayitSearchArtifactStorage {
    var installedManifest: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("zayit-ui-workbench-manifest.json")
    }
    init() throws {}
}

@MainActor
final class ZayitSearchDataController: ObservableObject {
    enum State: Equatable {
        case notInstalled
        case discovering
        case available(download: Int64, installed: Int64)
        case downloading(completed: Int, total: Int)
        case installing(completed: Int, total: Int)
        case ready(ZayitSearchArtifactManifest)
        case updateAvailable
        case repairRequired(String)
        case incompatible(String)
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    static let shared = ZayitSearchDataController()
    @Published var state: State = .ready(.init())
    private init() {}

    func refresh(discover: Bool) async {}
    func install() async { state = .ready(.init()) }
    func remove() { state = .notInstalled }
}
