import Foundation
import SwiftUI

@MainActor
@Observable
class iOSLibraryViewModel {
    var rootCategories: [CategoryData] = []

    /// We use a backing property so @Observable can track changes and trigger view updates
    var _showOnlyDownloadedTracker: Bool = false

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
        }
    }

    var searchText: String = "" {
        didSet {
            // Just updating the text will trigger SwiftUI if it's used, but let's make sure
        }
    }

    var isLoading = true

    var isSelectionMode = false
    var selectedBookIds: Set<Int> = []
    var isBulkDownloading = false
    private var bulkDownloadTask: Task<Void, Never>?

    private var hasLoadedLibrary = false

    init() {
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .bookIntegrated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rootCategories = LibraryDataManager.shared.allRootCategories
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
        var base = rootCategories
        if showOnlyDownloaded {
            base = LibraryDataManager.shared.filterIntegrated()
        }

        if searchText.isEmpty {
            return base
        } else {
            var filtered: [CategoryData] = []
            _ = LibraryDataManager.shared.filterContent(
                with: searchText,
                displayedCategories: &filtered,
                baseCategories: base
            )
            return filtered
        }
    }

    func loadLibrary() async {
        if hasLoadedLibrary { return }
        await load()
    }

    func refreshLibrary() async {
        await load()
    }

    private func load() async {
        isLoading = true
        await LibraryDataManager.shared.loadData()
        rootCategories = LibraryDataManager.shared.allRootCategories
        isLoading = false
        hasLoadedLibrary = LibraryDataManager.shared.isDataLoaded
    }

    func isBookDownloaded(_ book: BooksData) -> Bool {
        BookArchiveIntegrator.shared.isBookIntegrated(book)
    }

    var selectedDownloadBooks: [BooksData] {
        booksForSelectedIds(in: displayedCategories)
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
        !isBookDownloaded(book)
    }

    func isBookSelected(_ book: BooksData) -> Bool {
        selectedBookIds.contains(book.id)
    }

    func toggleBookSelection(_ book: BooksData) {
        guard isBookSelectable(book) else { return }
        if selectedBookIds.contains(book.id) {
            selectedBookIds.remove(book.id)
        } else {
            selectedBookIds.insert(book.id)
        }
    }

    func selectableBooks(in category: CategoryData) -> [BooksData] {
        getAllBooks(in: category).filter { isBookSelectable($0) }
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

    func cancelBulkDownload() {
        bulkDownloadTask?.cancel()
        bulkDownloadTask = nil
        isBulkDownloading = false
        Task {
            await BookDownloadManager.shared.cancelAllDownloads()
        }
    }

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

        await refreshLibrary()
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
