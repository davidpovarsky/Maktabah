import Foundation
import SwiftUI
import Combine

@MainActor
@Observable
class iOSLibraryViewModel {
    var rootCategories: [CategoryData] = []

    /// We use a backing property so @Observable can track changes and trigger view updates
    var _showOnlyDownloadedTracker: Bool = false
    var _authorFilterTracker: Int = 0
    var _viewModeTracker: Int = 0

    var viewMode: LibraryViewMode {
        didSet {
            UserDefaults.standard.set(viewMode.rawValue, forKey: "libraryViewMode")
            _viewModeTracker += 1

            // Lazy load author hierarchy when switching to author mode
            if viewMode == .author && !_hasBuiltAuthorHierarchy {
                _authorHierarchy = LibraryDataManager.shared.buildAuthorHierarchy()
                _hasBuiltAuthorHierarchy = true
            }

            updateDisplayedCategories()
        }
    }

    var showOnlyDownloaded: Bool {
        get {
            // Read from UserDefaults but also access the tracker to register the dependency in @Observable
            _ = _showOnlyDownloadedTracker
            return UserDefaults.standard.integer(forKey: "filterSegmentIndex") == 1
        }
        set {
            UserDefaults.standard.set(newValue ? 1 : 0, forKey: "filterSegmentIndex")
            // Update the tracker to notify SwiftUI that displayedCategories needs to be recomputed
            _showOnlyDownloadedTracker = newValue
            updateDisplayedCategories()
        }
    }

    var selectedAuthorId: Int? = nil {
        didSet {
            _authorFilterTracker += 1
            updateDisplayedCategories()
        }
    }

    var availableAuthors: [(id: Int, muallif: Muallif)] = []

    func loadAuthorsIfNeeded() {
        guard availableAuthors.isEmpty else { return }
        availableAuthors = LibraryDataManager.shared.getAllAuthors()
    }

    var searchText: String = "" {
        didSet {
            if oldValue != searchText {
                searchSubject.send(searchText)
            }
        }
    }

    var isLoading = true

    var isSelectionMode = false
    var selectedBookIds: Set<Int> = [] {
        didSet {
            // Perubahan seleksi tidak perlu updateDisplayedCategories()
            // karena displayedCategories hanya peduli pada struktur data (filter/search)
        }
    }
    var isBulkDownloading = false
    private var bulkDownloadTask: Task<Void, Never>?

    // MARK: - MVVM Refactoring Properties
    var singleBookToDelete: BooksData? = nil
    var showingDeleteConfirmation = false
    var showingImportSheet = false
    var importErrorMessage: String? = nil
    var showImportSuccessAlert = false

    private var hasLoadedLibrary = false
    private var _cachedDisplayedCategories: [CategoryData] = []
    private var _authorHierarchy: [CategoryData] = []
    private var _hasBuiltAuthorHierarchy = false

    // Pagination for author mode
    private let authorPageSize = 100
    private var _displayedAuthorCount: Int = 0
    private var _allFilteredAuthors: [CategoryData] = []
    private var _displayedFilteredCount: Int = 0

    var updateTrigger: Int = 0
    private let refreshSubject = PassthroughSubject<Void, Never>()
    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        viewMode = LibraryViewMode(
            rawValue: UserDefaults.standard.integer(forKey: "libraryViewMode")
        ) ?? .category
        setupObservers()
    }

    private func setupObservers() {
        refreshSubject
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    rootCategories = Array(LibraryDataManager.shared.allRootCategories)

                    // Only rebuild author hierarchy when in author mode
                    if viewMode == .author {
                        _authorHierarchy = LibraryDataManager.shared.buildAuthorHierarchy()
                        _hasBuiltAuthorHierarchy = true
                    }

                    updateDisplayedCategories()
                }
            }
            .store(in: &cancellables)

        searchSubject
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDisplayedCategories()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .bookIntegrated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSubject.send(())
            }
        }

        NotificationCenter.default.addObserver(
            forName: .booksChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSubject.send(())
            }
        }

        NotificationCenter.default.addObserver(
            forName: .libraryFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.refreshLibrary()
            }
        }
    }

    var displayedCategories: [CategoryData] {
        // No search and no filter
        if _cachedDisplayedCategories.isEmpty && !rootCategories.isEmpty && searchText.isEmpty && !showOnlyDownloaded {
            if viewMode == .author {
                // Paginated display for author mode (no search)
                let endIndex = min(_displayedAuthorCount, _authorHierarchy.count)
                return Array(_authorHierarchy.prefix(endIndex))
            }
            return rootCategories
        }

        // No search but with showOnlyDownloaded filter - paginated
        if searchText.isEmpty && showOnlyDownloaded && viewMode == .author {
            let endIndex = min(_displayedAuthorCount, _cachedDisplayedCategories.count)
            return Array(_cachedDisplayedCategories.prefix(endIndex))
        }

        // Search mode - use paginated filtered results
        if viewMode == .author && !searchText.isEmpty {
            let endIndex = min(_displayedFilteredCount, _allFilteredAuthors.count)
            return Array(_allFilteredAuthors.prefix(endIndex))
        }

        return _cachedDisplayedCategories
    }

    var hasMoreAuthors: Bool {
        let total = showOnlyDownloaded ? _cachedDisplayedCategories.count : (searchText.isEmpty ? _authorHierarchy.count : _allFilteredAuthors.count)
        let displayed = searchText.isEmpty ? _displayedAuthorCount : _displayedFilteredCount
        return viewMode == .author && displayed < total
    }

    var totalAuthorCount: Int {
        if searchText.isEmpty {
            return showOnlyDownloaded ? _cachedDisplayedCategories.count : _authorHierarchy.count
        } else {
            return _allFilteredAuthors.count
        }
    }

    func loadMoreAuthors() {
        let total = showOnlyDownloaded ? _cachedDisplayedCategories.count : (searchText.isEmpty ? _authorHierarchy.count : _allFilteredAuthors.count)
        if searchText.isEmpty {
            if showOnlyDownloaded {
                _displayedAuthorCount = min(_displayedAuthorCount + authorPageSize, total)
            } else {
                _displayedAuthorCount = min(_displayedAuthorCount + authorPageSize, _authorHierarchy.count)
            }
        } else {
            _displayedFilteredCount = min(_displayedFilteredCount + authorPageSize, _allFilteredAuthors.count)
        }
        updateTrigger += 1
    }

    private func updateDisplayedCategories() {
        var base: [CategoryData] = []
        if viewMode == .author {
            // Lazy build author hierarchy if not yet built
            if !_hasBuiltAuthorHierarchy {
                _authorHierarchy = LibraryDataManager.shared.buildAuthorHierarchy()
                _hasBuiltAuthorHierarchy = true
            }
            base = _authorHierarchy
        } else {
            base = rootCategories
        }

        if showOnlyDownloaded {
            base = LibraryDataManager.shared.filterIntegrated(base: base)
        }

        if searchText.isEmpty {
            // No search - use filtered base directly
            if showOnlyDownloaded {
                // Filtered by downloaded status
                _cachedDisplayedCategories = base
            } else {
                _cachedDisplayedCategories = []
            }
            // Reset pagination for author mode
            if viewMode == .author {
                _displayedAuthorCount = authorPageSize
            }
        } else {
            if viewMode == .author {
                // Use optimized author filter
                _allFilteredAuthors = LibraryDataManager.shared.filterAuthorHierarchy(base, searchText: searchText)
                _cachedDisplayedCategories = []
                _displayedFilteredCount = authorPageSize
            } else {
                // Use category filter
                var filtered: [CategoryData] = []
                _ = LibraryDataManager.shared.filterContent(
                    with: searchText,
                    displayedCategories: &filtered,
                    baseCategories: base
                )
                _cachedDisplayedCategories = filtered
            }
        }
        updateTrigger += 1
    }

    func loadLibrary() async {
        if hasLoadedLibrary { return }
        await load()
    }

    func refreshLibrary() async {
        hasLoadedLibrary = false
        await load()
    }

    private func load() async {
        isLoading = true
        await LibraryDataManager.shared.loadData()
        rootCategories = LibraryDataManager.shared.allRootCategories

        // Only build author hierarchy when in author mode
        if viewMode == .author {
            _authorHierarchy = LibraryDataManager.shared.buildAuthorHierarchy()
            _hasBuiltAuthorHierarchy = true
        }

        updateDisplayedCategories()
        isLoading = false
        hasLoadedLibrary = LibraryDataManager.shared.isDataLoaded
    }

    func isBookDownloaded(_ book: BooksData) -> Bool {
        BookArchiveIntegrator.shared.isBookIntegrated(book)
    }

    var selectedDownloadBooks: [BooksData] {
        booksForSelectedIds(in: displayedCategories).filter { !isBookDownloaded($0) }
    }

    var selectedDownloadCount: Int {
        selectedDownloadBooks.count
    }

    func enterSelectionMode(selecting book: BooksData? = nil) {
        isSelectionMode = true
        if let book {
            toggleBookSelection(book)
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedBookIds.removeAll()
    }

    func isBookSelectable(_ book: BooksData) -> Bool {
        true
    }

    func isBookSelected(_ book: BooksData) -> Bool {
        selectedBookIds.contains(book.id)
    }

    func toggleBookSelection(_ book: BooksData) {
        if selectedBookIds.contains(book.id) {
            selectedBookIds.remove(book.id)
        } else {
            selectedBookIds.insert(book.id)
        }
    }

    func selectableBooks(in category: CategoryData) -> [BooksData] {
        getAllBooks(in: category)
    }

    func isCategorySelected(_ category: CategoryData) -> Bool {
        let books = selectableBooks(in: category)
        return !books.isEmpty && books.allSatisfy { selectedBookIds.contains($0.id) }
    }

    func isCategoryPartiallySelected(_ category: CategoryData) -> Bool {
        let books = selectableBooks(in: category)
        guard !books.isEmpty else { return false }
        let selectedCount = books.filter { selectedBookIds.contains($0.id) }.count
        return selectedCount > 0 && selectedCount < books.count
    }

    func toggleCategorySelection(_ category: CategoryData) {
        let books = selectableBooks(in: category)
        guard !books.isEmpty else { return }

        if books.allSatisfy({ selectedBookIds.contains($0.id) }) {
            books.forEach { selectedBookIds.remove($0.id) }
        } else {
            books.forEach { selectedBookIds.insert($0.id) }
        }
    }

    var selectedDeleteBooks: [BooksData] {
        booksForSelectedIds(in: displayedCategories).filter { isBookDownloaded($0) }
    }

    var selectedDeleteCount: Int {
        selectedDeleteBooks.count
    }

    func startBulkDeletion(onFinished: @escaping () -> Void) {
        let books = selectedDeleteBooks
        guard !books.isEmpty else { return }

        Task {
            for book in books {
                try? await BookArchiveIntegrator.shared.removeBookFromArchive(book)
            }

            exitSelectionMode()

            onFinished()
        }
    }

    // MARK: - MVVM Refactoring Methods

    func notifySelectionChanged() {
        selectedBookIds = selectedBookIds
    }

    func selectBook(_ book: BooksData, using navigationManager: iOSNavigationManager) {
        let lastId = HistoryViewModel.shared.entriesByBookId[book.id]?.lastContentId
        navigationManager.openBook(book, initialContentId: lastId)
    }

    func deleteSingleBook(_ book: BooksData) async {
        try? await BookArchiveIntegrator.shared.removeBookFromArchive(book)
    }

    func importOfflineBook(from url: URL, metadata: BookMetadata, authorRow: [String: Any]?) async {
        let updateManager = BookUpdateManager.shared
        do {
            let result = try await updateManager.importOfflineUpdate(
                from: url,
                providedMetadata: metadata,
                authorRow: authorRow
            )
            try await LibraryDataManager.shared.processBookUpdates([result])
            updateManager.integrateBooks(metadata: metadata)

            await MainActor.run {
                showImportSuccessAlert = true
                showingImportSheet = false
            }
        } catch {
            await MainActor.run {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    func cancelBulkDownload() {
        bulkDownloadTask?.cancel()
        bulkDownloadTask = nil
        isBulkDownloading = false
        Task {
            await BookDownloadManager.shared.cancelAllDownloads()
        }
    }

    @MainActor
    func startBulkDownload(
        progressState: BundleArchiveDownloadProgressState,
        onFinished: @escaping (String?) -> Void
    ) {
        let books = selectedDownloadBooks
        guard !books.isEmpty else { return }

        isBulkDownloading = true
        progressState.mode = .downloading
        progressState.title = NSLocalizedString(
            "Download Book",
            comment: "Bulk download window title"
        )
        progressState.message = String(localized: "Begin downloading...")
        progressState.detail = "0 / \(books.count)"
        progressState.progress = 0

        bulkDownloadTask = Task { [weak self] in
            guard let self else { return }
            await self.runBulkDownload(
                books: books,
                progressState: progressState,
                onFinished: onFinished
            )
        }
    }

    @MainActor
    private func runBulkDownload(
        books: [BooksData],
        progressState: BundleArchiveDownloadProgressState,
        onFinished: @escaping (String?) -> Void
    ) async {
        let total = books.count
        var downloadedCount = 0
        var completedIntegrations = 0
        var downloadResults: [Int: Result<URL, Error>] = [:]
        var stoppedByNetwork = false

        if !NetworkMonitor.shared.isConnected {
            stoppedByNetwork = true
        } else {
            await withTaskGroup(of: (Int, Result<URL, Error>).self) { group in
                for book in books {
                    guard !Task.isCancelled else { break }
                    group.addTask {
                        do {
                            let url = try await BookDownloadManager.shared
                                .ensureBookDownloaded(bookId: book.id)
                            return (book.id, .success(url))
                        } catch {
                            return (book.id, .failure(error))
                        }
                    }
                }

                for await (bookId, result) in group {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }

                    downloadResults[bookId] = result
                    downloadedCount += 1
                    progressState.message = String(
                        localized: "Downloading \(downloadedCount) of \(total) books..."
                    )
                    progressState.detail = "\(downloadedCount) / \(total)"
                    progressState.progress = total > 0 ? Double(downloadedCount) / Double(total) : 0

                    if case .failure(let error) = result, isNetworkFailure(error) {
                        stoppedByNetwork = true
                        group.cancelAll()
                    }
                }
            }
        }

        let successfulDownloads = books.filter {
            if case .success = downloadResults[$0.id] { return true }
            return false
        }
        let integrateTotal = successfulDownloads.count

        progressState.mode = .integrating
        progressState.message = String(localized: "Download Complete. Begin integrating...")
        progressState.detail = "0 / \(integrateTotal)"
        progressState.progress = 0

        for book in successfulDownloads {
            guard !Task.isCancelled else { break }

            if !BookArchiveIntegrator.shared.isBookIntegrated(book) {
                do {
                    try await BookArchiveIntegrator.shared.ensureBookIntegrated(
                        book,
                        onIntegrating: {},
                        onProgress: { phase in
                            await MainActor.run {
                                let prefix: String
                                switch phase {
                                case .fts:
                                    prefix = "FTS"
                                case .data:
                                    prefix = "Data"
                                }
                                progressState.message = "\(prefix): \(book.book)"
                            }
                        }
                    )
                } catch {
                    downloadResults[book.id] = .failure(error)
                }
            }

            completedIntegrations += 1
            progressState.detail = "\(completedIntegrations) / \(integrateTotal)"
            progressState.progress = integrateTotal > 0
                ? Double(completedIntegrations) / Double(integrateTotal)
                : 0
        }

        let failedCount = books.filter {
            if case .failure = downloadResults[$0.id] { return true }
            return false
        }.count

        selectedBookIds.subtract(books.map(\.id))
        isBulkDownloading = false
        bulkDownloadTask = nil

        let message: String?
        if Task.isCancelled {
            message = String(localized: "Stopped. \(completedIntegrations) books completed.", comment: "Status message when the task is cancelled")
        } else if stoppedByNetwork {
            message = NSLocalizedString(
                "Please check your internet connection",
                comment: "Network error message"
            )
        } else if failedCount > 0 {
            message = String(localized: "\(completedIntegrations) completed, \(failedCount) failed.", comment: "Status message showing count of completed and failed downloads")
        } else {
            message = String(localized: "All \(completedIntegrations) books processed successfully.", comment: "Status message when all tasks finished successfully")
        }

        onFinished(message)
    }

    private func getAllBooks(in category: CategoryData) -> [BooksData] {
        var books: [BooksData] = []
        for child in category.children {
            if let book = child as? BooksData {
                books.append(book)
            } else if let sub = child as? CategoryData {
                books.append(contentsOf: getAllBooks(in: sub))
            }
        }
        return books
    }

    private func booksForSelectedIds(in categories: [CategoryData]) -> [BooksData] {
        var result: [BooksData] = []
        for category in categories {
            result.append(contentsOf: getAllBooks(in: category).filter { selectedBookIds.contains($0.id) })
        }
        return result
    }

    private func isNetworkFailure(_ error: Error) -> Bool {
        if let bookError = error as? BookDownloadError {
            if case .networkUnavailable = bookError { return true }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .timedOut:
                return true
            default:
                return false
            }
        }

        return false
    }

}
