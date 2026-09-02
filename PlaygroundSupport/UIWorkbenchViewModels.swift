import Foundation
import Observation
import SwiftUI
import UIKit

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
    func selectBook(_ book: BooksData, using navigationManager: iOSNavigationManager) {
        navigationManager.openBook(book)
    }
    func startBulkDeletion(onFinished: @escaping () -> Void) { onFinished() }
    func deleteSingleBook(_ book: BooksData) async {}
    func startBulkDownload(
        progressState: BundleArchiveDownloadProgressState,
        completion: @escaping (String?) -> Void
    ) { completion(nil) }
    func importOfflineBook(
        from url: URL,
        metadata: PlaygroundOfflineBookMetadata,
        authorRow: PlaygroundOfflineAuthorRow?
    ) async {}
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

    var progressPercentage: Double {
        totalTables == 0 ? 0 : Double(completedTables) / Double(totalTables)
    }
    var rowProgressPercentage: Double {
        totalRowsInTable == 0 ? 0 : Double(completedRowsInTable) / Double(totalRowsInTable)
    }

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

    init() {}
    init(connFactory: @escaping () -> BookConnection) {}

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
        if contentText.isEmpty {
            contentText = "תצוגת UI של הקורא — נתוני הספר אינם נטענים ב־Playground."
        }
        if let currentBook { tocViewModel.loadTOC(book: currentBook) }
    }
    func fetchContentById(_ id: Int) { currentContentId = id }
    func saveCurrentState() {}
    func addAnnotation(
        in range: NSRange,
        mode: AnnotationMode,
        sourceText: String,
        color: UIColor
    ) throws {}
    func addAnnotation(
        in range: NSRange,
        mode: AnnotationMode,
        sourceText: String,
        color: String
    ) throws {}
    func updateAnnotation(_ annotation: Annotation) throws {}
    func deleteAnnotation(id: Int64) throws {
        currentAnnotations.removeAll { $0.id == id }
    }
    func didTapOtzariaText(at index: Int) {}
    func goToNextPage() { currentContentId += 1 }
    func goToPrevPage() { currentContentId = max(0, currentContentId - 1) }
    func didSelectSearch(query: String, contentId: Int) {
        searchText = query
        fetchContentById(contentId)
    }
    func didSelectTOCNode(id: Int) { fetchContentById(id) }
    func didSelectAnnotation(_ annotation: Annotation) { targetAnnotation = annotation }
    func closeOtzariaSourcesInspector() { otzariaSourcesInspectorVisible = false }
    func getCopyReference(for selectedText: String) -> String { selectedText }
    func getShareReference(for selectedText: String) -> String { selectedText }
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
        return books.filter {
            $0.book.normalizeArabic(false).contains(searchText.normalizeArabic(false))
        }
    }

    func toggleFavorite(_ bookId: Int) {
        if let index = favoriteBookIds.firstIndex(of: bookId) { favoriteBookIds.remove(at: index) }
        else { favoriteBookIds.append(bookId) }
    }
    func removeHistory(for bookId: Int) { historyBooks.removeAll { $0.id == bookId } }
    func addBookToHistory(_ bookId: Int) {}
    func updateLastContentId(_ contentId: Int, for bookId: Int) {
        entriesByBookId[bookId] = .init(lastContentId: contentId)
    }
}

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

    func openBook(
        _ book: BooksData,
        initialContentId: Int? = nil,
        searchText: String? = nil,
        targetAnnotation: Annotation? = nil
    ) {
        let viewModel: ReaderViewModel
        if let index = openTabs.firstIndex(where: { $0.book.id == book.id }) {
            viewModel = openTabs[index].viewModel
            openTabs[index].initialContentId = initialContentId
        } else {
            viewModel = ReaderViewModel(book: book)
            let tab = ReaderTab(
                id: UUID(),
                book: book,
                initialContentId: initialContentId,
                viewModel: viewModel
            )
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
        if activeTabId == id {
            activeTabId = openTabs.last?.id
            selectedBook = openTabs.last?.book
        }
    }
    func clearAllTabs() {
        openTabs.removeAll()
        activeTabId = nil
        selectedBook = nil
        selectedContentId = nil
    }
    func selectTab(id: UUID) {
        activeTabId = id
        if let tab = openTabs.first(where: { $0.id == id }) {
            selectedBook = tab.book
            selectedContentId = tab.initialContentId
        }
    }
    func confirmPendingBookIntegration(state: BundleArchiveDownloadProgressState) {
        activeIntegrationStates.removeAll { $0.id == state.id }
    }
    func cancelPendingBookIntegration(state: BundleArchiveDownloadProgressState) {
        activeIntegrationStates.removeAll { $0.id == state.id }
    }
    func showBookIntegrationConfirmation(for book: BooksData, initialContentId: Int?) {
        openBook(book, initialContentId: initialContentId)
    }
    func showBulkDownloadConfirmation(books: [BooksData]) {}
}
