import Combine
import Foundation
import Observation
import SwiftUI
import UIKit

// MARK: - Workbench-only presentation state
//
// These facades intentionally mirror only the API surface consumed by the real
// production Views. They do not implement database, CloudKit, Rust/C, download,
// or filesystem behavior. The production app does not compile this file.

public enum ViewModelState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

enum LibraryFilterMode: Int {
    case all
    case favorites
    case history
    case downloaded
}

enum SearchMode: Int, CaseIterable, Identifiable {
    case phrase
    case contains
    case or

    var id: Int { rawValue }
}

enum RowiDisplayMode: Int, CaseIterable, Identifiable {
    case tilmidz = 0
    case syaikh = 1
    case takdil = 2
    case mulakhosh = 3

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .tilmidz: "التلاميذ"
        case .syaikh: "الشيوخ"
        case .takdil: "الجرح والتعديل"
        case .mulakhosh: "ملخص"
        }
    }
}

enum AnnotationSearchScope: Int, CaseIterable, Identifiable, Sendable {
    case all = 0
    case book = 1
    case context = 2
    case note = 3
    case tag = 4

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .all: "All".localized
        case .book: "Book".localized
        case .context: "Context".localized
        case .note: "Note".localized
        case .tag: "Tag".localized
        }
    }
}

struct SwiftUIAnnotationNode: Identifiable {
    let id: String
    let title: String
    let kind: AnnotationNodeKind
    let annotation: Annotation?
    var children: [SwiftUIAnnotationNode]?

    init(id: String, title: String, kind: AnnotationNodeKind, annotation: Annotation?, children: [SwiftUIAnnotationNode]? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.annotation = annotation
        self.children = children
    }

    static func id(from node: AnnotationNode) -> String {
        if node.kind == .annotation, let annotation = node.annotation, let annotationId = annotation.id {
            return "ann-\(annotationId)"
        }
        return "group-\(node.kind)-\(node.title)"
    }

    init(from node: AnnotationNode, parentId: String? = nil) {
        let baseId = Self.id(from: node)
        id = parentId != nil && node.kind == .annotation ? "\(parentId!)-\(baseId)" : baseId
        title = node.title
        kind = node.kind
        annotation = node.annotation
        children = node.children.isEmpty ? nil : node.children.map { SwiftUIAnnotationNode(from: $0, parentId: id) }
    }
}

enum AnnotationChangeType {
    case added
    case updated
    case deleted
}

enum AnnotationNotificationKeys {
    static let annotation = "annotation"
    static let annotationId = "annotationId"
    static let tagDiff = "tagDiff"
    static let oldParentIndex = "oldParentIndex"
    static let newParentIndex = "newParentIndex"
    static let changeType = "changeType"
}

struct TagUpdateDiff {
    struct Entry {
        let tagNode: AnnotationNode
        let annotationNode: AnnotationNode
        let tagNodeBecomesEmpty: Bool
    }

    var removed: [Entry] = []
    var added: [Entry] = []
    var updated: [AnnotationNode] = []
}

// MARK: - View models used by the real production Views

@Observable
final class LibraryViewModel {
    var displayedCategories: [CategoryData] = []
    var filterMode: LibraryFilterMode = .all
    var isFlatMode = false
    var selectedBookName: String?
    var rootCategories: [CategoryData] = []
    var selectedBookIds: Set<Int> = []
    var isSelectionMode = false
    var isBulkDownloading = false
    var isDownloadModal = false
    var singleBookToDelete: BooksData?
    var searchQuery = ""
    var state: ViewModelState = .loaded
    var showOnlyDownloaded = false
    var _showOnlyDownloadedTracker = false
    var showingDeleteConfirmation = false
    var showingImportSheet = false
    var importErrorMessage: String?
    var showImportSuccessAlert = false
    var viewMode: LibraryViewMode = .category
    var selectedAuthorId: Int?
    var availableAuthors: [(id: Int, muallif: Muallif)] = []
    var updateTrigger = 0

    var hasMoreAuthors: Bool { false }
    var totalAuthorCount: Int { displayedCategories.count }
    var selectedDownloadBooks: [BooksData] { [] }
    var selectedDownloadCount: Int { selectedDownloadBooks.count }
    var selectedDeleteBooks: [BooksData] { [] }
    var selectedDeleteCount: Int { selectedDeleteBooks.count }

    func loadLibrary() async { state = .loaded }
    func refreshLibrary() async { state = .loaded }
    func updateDisplayedCategories() { updateTrigger += 1 }
    func loadMoreAuthors() {}
    func isBookDownloaded(_ book: BooksData) -> Bool { false }
    func isBookSelected(_ book: BooksData) -> Bool { selectedBookIds.contains(book.id) }
    func isCategorySelected(_ category: CategoryData) -> Bool { false }
    func isCategoryPartiallySelected(_ category: CategoryData) -> Bool { false }
    func toggleCategorySelection(_ category: CategoryData) {}
    func toggleBookSelection(_ book: BooksData) {
        if selectedBookIds.contains(book.id) { selectedBookIds.remove(book.id) }
        else { selectedBookIds.insert(book.id) }
        updateTrigger += 1
    }
    func enterSelectionMode(selecting book: BooksData? = nil) {
        isSelectionMode = true
        if let book { toggleBookSelection(book) }
    }
    func exitSelectionMode() {
        isSelectionMode = false
        selectedBookIds.removeAll()
        updateTrigger += 1
    }
    func notifySelectionChanged() { updateTrigger += 1 }
    func selectBook(_ book: BooksData, using navigationManager: iOSNavigationManager) { navigationManager.openBook(book) }
    func startBulkDeletion(onFinished: @escaping () -> Void) { onFinished() }
    func deleteSingleBook(_ book: BooksData) async {}
    func startBulkDownload(progressState: BundleArchiveDownloadProgressState, completion: @escaping (String?) -> Void) { completion(nil) }
    func importOfflineBook(from url: URL, metadata: PlaygroundOfflineBookMetadata, authorRow: PlaygroundOfflineAuthorRow?) async {}
}

@Observable
final class SearchViewModel {
    var query = ""
    var searchMode: SearchMode = .phrase
    var results: [SearchResultItem] = []
    var isSearching = false
    var isPaused = false
    var totalTables = 0
    var completedTables = 0
    var currentTable = ""
    var totalRowsInTable = 0
    var completedRowsInTable = 0
    var selectedBookIds: Set<Int> = []
    var state: ViewModelState = .loaded
    var filterText = ""
    var displayedCategories: [CategoryData] = []
    var updateTrigger = 0
    var searchHistory: [String] = []

    var progressPercentage: Double { totalTables == 0 ? 0 : Double(completedTables) / Double(totalTables) }
    var rowProgressPercentage: Double { totalRowsInTable == 0 ? 0 : Double(completedRowsInTable) / Double(totalRowsInTable) }

    func updateDisplayedCategories() { updateTrigger += 1 }
    func setSelectedBooks(_ ids: Set<Int>) { selectedBookIds = ids; updateTrigger += 1 }
    func toggleBookSelection(_ book: BooksData) {
        if selectedBookIds.contains(book.id) { selectedBookIds.remove(book.id) }
        else { selectedBookIds.insert(book.id) }
        updateTrigger += 1
    }
    func isBookSelected(_ book: BooksData) -> Bool { selectedBookIds.contains(book.id) }
    func addToHistory(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchHistory.removeAll { $0 == trimmed }
        searchHistory.insert(trimmed, at: 0)
    }
    func removeFromHistory(_ value: String) { searchHistory.removeAll { $0 == value } }
    func clearHistory() { searchHistory.removeAll() }
    func startSearch() { isSearching = false }
    func clearResults() { results.removeAll() }
    func pauseSearch() { isPaused = true }
    func resumeSearch() { isPaused = false }
    func stopSearch() { isSearching = false; isPaused = false }
}

@Observable
final class NarratorViewModel {
    var tabaqaGroups: [TabaqaGroup] = []
    var currentRowi: Rowi?
    var displayMode: RowiDisplayMode = .mulakhosh
    var rowiContentText: AttributedString = .init("")
    var state: ViewModelState = .loaded
    var isSearching = false
    var isPaused = false
    var sidebarTarjamahList: [TarjamahResult] = []
    var searchTarjamahList: [TarjamahResult] = []
    var searchText = "" { didSet { lastSearchQuery = searchText } }
    private(set) var lastSearchQuery = ""

    func loadData() async { state = .loaded }
    func searchRowis(query: String) { lastSearchQuery = query }
    func loadMore(group: TabaqaGroup, completion: @escaping (Int?) -> Void) { completion(nil) }
    func selectRowi(_ rowi: Rowi) { currentRowi = rowi }
    func setDisplayMode(_ mode: RowiDisplayMode) { displayMode = mode }
    func reset() { currentRowi = nil; rowiContentText = .init("") }
}

@Observable
final class AnnotationViewModel {
    var state: ViewModelState = .loaded
    var searchText = ""
    var searchScope: AnnotationSearchScope = .all
    var groupingMode: AnnotationGroupingMode = .book
    var sortField: AnnotationSortField = .createdAt
    var sortAscending = true
    var swiftUINodes: [SwiftUIAnnotationNode] = []

    func loadAnnotations() async { state = .loaded }
    func applyFilter() {}
    func deleteAnnotation(_ node: SwiftUIAnnotationNode) {}
}

@Observable
final class BookTOCViewModel {
    var tocNodes: [TOCNode] = []
    var onTOCLoadingStateChanged: ((Bool) -> Void)?
    var onTOCLoaded: (([TOCNode]) -> Void)?

    func loadTOC(book: BooksData) { onTOCLoaded?(tocNodes) }
    func findNode(forContentId contentId: Int) -> TOCNode? { findNodeById(contentId) }
    func findNodeById(_ id: Int) -> TOCNode? {
        func walk(_ nodes: [TOCNode]) -> TOCNode? {
            for node in nodes {
                if node.id == id { return node }
                if let found = walk(node.children) { return found }
            }
            return nil
        }
        return walk(tocNodes)
    }
    func pathToNode(_ target: TOCNode) -> [TOCNode]? { [target] }
    func cleanUp() { tocNodes.removeAll() }
}

@Observable
class ReaderViewModel {
    enum PendingReaderScrollTarget { case top, bottom }

    static let kfgqpc = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 16)
    static let kfgqpcTitle = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 18)
    static let kfgqpcList = Font.custom(ArabicFont.kfgqpcUthmanTahaNaskh.rawValue, size: 20)

    var currentBook: BooksData?
    var currentPage: Int?
    var currentPart: Int?
    var currentHeRef: String?
    var currentContentId = 0
    var contentText = ""
    var state: ViewModelState = .loaded
    var totalParts = 0
    var minPageInPart = 0
    var maxPageInPart = 0
    var searchText = ""
    var targetAnnotation: Annotation?
    var searchViewModel = SearchViewModel()
    var readerState: ReaderState = .init()
    var needsScrollRestore = false
    var pendingReaderScrollTarget: PendingReaderScrollTarget?
    var fetchScrollPosition: (() -> CGPoint?)?
    var fetchSelectedRange: (() -> NSRange?)?
    var currentAnnotations: [Annotation] = []
    var otzariaSelectedLineAnchor: OtzariaLineAnchor?
    var otzariaLinkedSources: [OtzariaLinkedSource] = []
    var otzariaSourcesInspectorVisible = false
    var otzariaSourcesIsLoading = false
    var otzariaSourcesError: String?
    var otzariaSourcesSelectedGroupID: String?
    var otzariaSourcesSelectedBookID: String?
    var otzariaSourcesExpandedSourceIDs: Set<Int> = []
    var tocViewModel = BookTOCViewModel()

    init(book: BooksData? = nil) { currentBook = book }

    var statusSubtitle: String {
        if let currentPage { return "ص \(currentPage)" }
        return "صفحة"
    }

    func consumePendingReaderScrollTarget() -> PendingReaderScrollTarget? {
        defer { pendingReaderScrollTarget = nil }
        return pendingReaderScrollTarget
    }
    func loadInitialContent(initialContentId: Int? = nil) {
        if let initialContentId { currentContentId = initialContentId }
        contentText = contentText.isEmpty ? "תצוגת UI של הקורא — נתוני הספר אינם נטענים ב־Playground." : contentText
        if let currentBook { tocViewModel.loadTOC(book: currentBook) }
    }
    func fetchContentById(_ id: Int) { currentContentId = id }
    func saveCurrentState() {}
    func addAnnotation(in range: NSRange, mode: AnnotationMode, sourceText: String, color: String) throws {}
    func updateAnnotation(_ annotation: Annotation) throws {}
    func deleteAnnotation(id: Int64) throws { currentAnnotations.removeAll { $0.id == id } }
    func didTapOtzariaText(at index: Int) {}
    func goToNextPage() { currentContentId += 1 }
    func goToPrevPage() { currentContentId = max(0, currentContentId - 1) }
    func didSelectSearch(query: String, contentId: Int) { searchText = query; fetchContentById(contentId) }
    func didSelectTOCNode(id: Int) { fetchContentById(id) }
    func didSelectAnnotation(_ annotation: Annotation) { targetAnnotation = annotation }
    func closeOtzariaSourcesInspector() { otzariaSourcesInspectorVisible = false }
    func getCopyReference(for selectedText: String) -> String { selectedText }
    func getShareReference(for selectedText: String) -> String { selectedText }
}

final class PlaygroundHistoryEntry {
    var lastContentId: Int?
    init(lastContentId: Int? = nil) { self.lastContentId = lastContentId }
}

final class HistoryViewModel: ObservableObject {
    static let shared = HistoryViewModel()
    @Published var favoriteBooks: [BooksData] = []
    @Published var historyBooks: [BooksData] = []
    @Published var favoriteBookIds: [Int] = []
    @Published var entriesByBookId: [Int: PlaygroundHistoryEntry] = [:]
    @Published var searchText = ""

    var filteredFavorites: [BooksData] { filter(favoriteBooks) }
    var filteredHistory: [BooksData] { filter(historyBooks) }

    private func filter(_ books: [BooksData]) -> [BooksData] {
        guard !searchText.isEmpty else { return books }
        return books.filter { $0.book.normalizeArabic(false).contains(searchText.normalizeArabic(false)) }
    }

    func toggleFavorite(_ bookId: Int) {
        if let index = favoriteBookIds.firstIndex(of: bookId) { favoriteBookIds.remove(at: index) }
        else { favoriteBookIds.append(bookId) }
    }
    func removeHistory(for bookId: Int) { historyBooks.removeAll { $0.id == bookId } }
    func addBookToHistory(_ bookId: Int) {}
    func updateLastContentId(_ contentId: Int, for bookId: Int) { entriesByBookId[bookId] = .init(lastContentId: contentId) }
}

// MARK: - Navigation facade

@Observable
final class iOSNavigationManager {
    struct AlertMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    struct ReaderTab: Identifiable, Equatable {
        let id: UUID
        let book: BooksData
        var initialContentId: Int?
        var viewModel: ReaderViewModel
        static func == (lhs: ReaderTab, rhs: ReaderTab) -> Bool { lhs.id == rhs.id }
    }

    var currentMode: AppMode = .viewer
    var selectedBook: BooksData?
    var selectedContentId: Int?
    var searchText = ""
    var showViewOptions = false
    var activeIntegrationStates: [BundleArchiveDownloadProgressState] = []
    var alertMessage: AlertMessage?
    var libraryViewModel = LibraryViewModel()
    var searchViewModel = SearchViewModel()
    var authorViewModel = NarratorViewModel()
    var annotationViewModel = AnnotationViewModel()
    var openTabs: [ReaderTab] = []
    var activeTabId: UUID?

    func switchToMode(_ mode: AppMode) { currentMode = mode }

    func openBook(_ book: BooksData, initialContentId: Int? = nil, searchText: String? = nil, targetAnnotation: Annotation? = nil) {
        let viewModel: ReaderViewModel
        if let index = openTabs.firstIndex(where: { $0.book.id == book.id }) {
            viewModel = openTabs[index].viewModel
            openTabs[index].initialContentId = initialContentId
        } else {
            viewModel = ReaderViewModel(book: book)
            let tab = ReaderTab(id: UUID(), book: book, initialContentId: initialContentId, viewModel: viewModel)
            openTabs.append(tab)
            activeTabId = tab.id
        }
        viewModel.searchText = searchText ?? ""
        viewModel.targetAnnotation = targetAnnotation
        viewModel.loadInitialContent(initialContentId: initialContentId)
        selectedContentId = initialContentId
        selectedBook = book
    }

    func closeTab(id: UUID) {
        openTabs.removeAll { $0.id == id }
        if activeTabId == id { activeTabId = openTabs.last?.id; selectedBook = openTabs.last?.book }
    }
    func clearAllTabs() { openTabs.removeAll(); activeTabId = nil; selectedBook = nil; selectedContentId = nil }
    func selectTab(id: UUID) {
        activeTabId = id
        if let tab = openTabs.first(where: { $0.id == id }) { selectedBook = tab.book; selectedContentId = tab.initialContentId }
    }
    func confirmPendingBookIntegration(state: BundleArchiveDownloadProgressState) { activeIntegrationStates.removeAll { $0.id == state.id } }
    func cancelPendingBookIntegration(state: BundleArchiveDownloadProgressState) { activeIntegrationStates.removeAll { $0.id == state.id } }
    func showBookIntegrationConfirmation(for book: BooksData, initialContentId: Int?) { openBook(book, initialContentId: initialContentId) }
    func showBulkDownloadConfirmation(books: [BooksData]) {}
}

// MARK: - Backend facades consumed directly by presentation files

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
    static func setUseICloud(_ enabled: Bool, resolution: MigrationResolution, completion: @escaping (Error?) -> Void) { useICloud = enabled; completion(nil) }
    static func forceRefreshCoreVersion() {}
    static func markCoreVersionCheckDone(newVersion: String) {}
}

enum SettingsActions {
    @discardableResult
    static func selectLibraryFolder(showSuccessAlert: Bool, shouldTerminateOnCancel: Bool, completion: @escaping (Bool) -> Void) -> Bool {
        completion(false)
        return false
    }
    static func switchToBundleMode(onCompletion: @escaping () -> Void) { onCompletion() }
    static func chooseAnnotationsAndResultsFolder(resolution: AppConfig.MigrationResolution, retryURL: URL? = nil, completion: @escaping (Result<Void, Error>?) -> Void) { completion(.success(())) }
    static func openFullLibraryDownloadURL() {}
    static func setUseCrossPlatformSync(_ enabled: Bool) { AppConfig.useCrossPlatformSync = enabled }
}

struct PlaygroundOfflineBookMetadata {}
struct PlaygroundOfflineAuthorRow {}

struct OfflineImportFormView: View {
    let onImport: (URL, PlaygroundOfflineBookMetadata, PlaygroundOfflineAuthorRow?) async -> Void
    init(onImport: @escaping (URL, PlaygroundOfflineBookMetadata, PlaygroundOfflineAuthorRow?) async -> Void) { self.onImport = onImport }
    var body: some View {
        ContentUnavailableView("Import Book", systemImage: "square.and.arrow.down", description: Text("Import is disabled in the UI-only workbench."))
    }
}

final class OtzariaMaktabahBridge {
    static let shared = OtzariaMaktabahBridge()
    var isEnabled = false
}

enum OtzariaLibraryImportActions {
    static var isEnabled: Bool { false }
    static func handleSelectionChange(viewModel: LibraryViewModel, navigationManager: iOSNavigationManager) {}
    static func handleDownloadSingleBook(_ book: BooksData, viewModel: LibraryViewModel, navigationManager: iOSNavigationManager) { navigationManager.openBook(book) }
    static func disconnectDatabase(viewModel: LibraryViewModel) {}
    static func installDatabase(from result: Result<[URL], Error>, viewModel: LibraryViewModel) throws {}
}

final class OtzariaDatabaseAccessController {
    enum Source { case managedInternal, external }
    static let shared = OtzariaDatabaseAccessController()
    var source: Source = .managedInternal
}

enum OtzariaIndexFileLogger {
    static func logFileURL() -> URL? { nil }
    static func readLog() -> String { "UI workbench — indexing disabled." }
}

struct PlaygroundHighlightPattern { let combinedPattern: String }

enum OtzariaSearchEngineBridge {
    static func splitQueryWords(_ query: String) throws -> [String] { query.split(whereSeparator: \.isWhitespace).map(String.init) }
    static func highlightPattern(for request: OtzariaSearchRequest) throws -> PlaygroundHighlightPattern? { nil }
}

enum PlaygroundOtzariaSearchStatus: Equatable {
    case ready
    case checkingPackage
    case building
    case finalizing
    case downloadingPackage
    case installingPackage
    case unavailable

    var label: String {
        switch self {
        case .ready: "מוכן"
        case .checkingPackage: "בודק חבילה…"
        case .building: "בונה אינדקס…"
        case .finalizing: "מסיים…"
        case .downloadingPackage: "מוריד…"
        case .installingPackage: "מתקין…"
        case .unavailable: "לא מותקן"
        }
    }
}

final class OtzariaTextSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var mode: OtzariaSearchMode = .advanced
    @Published var order: OtzariaSearchOrder = .catalogue
    @Published var negativeQuery = ""
    @Published var scope: OtzariaSearchScope = .wordDistance
    @Published var negativeScope: OtzariaSearchScope = .wordDistance
    @Published var wordMatchMode: OtzariaWordMatchMode = .all
    @Published var wordMatchCount = 1
    @Published var distance = 0
    @Published var negativeDistance = 0
    @Published var matchNikud = false
    @Published var matchTaamim = false
    @Published var grouping: OtzariaResultGrouping?
    @Published var customSpacing: [String: String] = [:]
    @Published var alternativeWords: [String: [String]] = [:]
    @Published var searchOptions: [String: [String: Bool]] = [:]
    @Published var results: [SearchResultItem] = []
    @Published var enginePage: OtzariaSearchPage?
    @Published var isSearching = false
    @Published var isIndexing = false
    @Published var errorMessage: String?
    @Published var indexStatusDetail: String?
    @Published var totalCount = 0
    @Published var resultsTruncated = false
    @Published var status: PlaygroundOtzariaSearchStatus = .ready

    func refreshStatus() { status = .ready }
    func search() { isSearching = false }
    func rebuildIndex() { isIndexing = false }
    func cancelIndexing() { isIndexing = false }
}

actor ZayitSearchRepository {
    private(set) var configured = false
    func configure(paths: ZayitSearchDataPaths) throws { configured = true }
    func reset() { configured = false }
    func search(query: String, near: UInt32, offset: Int, limit: Int, filters: ZayitSearchFilters) throws -> ZayitSearchPage {
        ZayitSearchPage(total: 0, offset: offset, limit: limit, hits: [])
    }
}

@MainActor
final class ZayitSearchSessionController: ObservableObject {
    enum State: Equatable { case notConfigured, restoring, ready, failed(String) }
    @Published private(set) var state: State = .ready
    let model = ZayitSearchViewModel(repository: ZayitSearchRepository())
    func restoreIfNeeded(existingSeforimDB: URL?) async { state = .ready }
    func chooseFolder(_ url: URL, existingSeforimDB: URL?) async { state = .ready }
    func forget() async { await model.reset(); state = .notConfigured }
}

enum ZayitSearchExistingDatabaseProvider { static var currentURL: URL? { nil } }

enum ZayitSearchReaderNavigationAdapter {
    static func open(_ hit: ZayitSearchHit, using navigationManager: iOSNavigationManager) -> Bool { false }
}

final class OtzariaMagicDictionaryManager {
    static let shared = OtzariaMagicDictionaryManager()
    var validatedDatabaseURL: URL? { nil }
}

struct CoreDownloadProgressState {
    enum Phase: Equatable { case confirmation, downloading, error(String) }
    var phase: Phase = .confirmation
    var progress: Double = 0
    var detail = ""
    var totalSizeString = ""
}

enum MaktabahApp { static var isIpad: Bool { UIDevice.current.userInterfaceIdiom == .pad } }

struct OtzariaReaderSourcesInspectorHost: View {
    let viewModel: ReaderViewModel
    let navigationManager: iOSNavigationManager
    var body: some View {
        ContentUnavailableView("Sources", systemImage: "link", description: Text("Source lookup is disabled in the UI-only workbench."))
    }
}

extension Notification.Name {
    static let bookIntegrated = Notification.Name("ui-workbench.bookIntegrated")
    static let booksChanged = Notification.Name("ui-workbench.booksChanged")
    static let libraryFolderChanged = Notification.Name("ui-workbench.libraryFolderChanged")
    static let annotationTreeDidUpdate = Notification.Name("ui-workbench.annotationTreeDidUpdate")
    static let annotationDidChange = Notification.Name("ui-workbench.annotationDidChange")
    static let annotationMissingBook = Notification.Name("ui-workbench.annotationMissingBook")
    static let savedResultsTreeDidUpdate = Notification.Name("ui-workbench.savedResultsTreeDidUpdate")
}
