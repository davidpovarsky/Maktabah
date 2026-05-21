import Combine
import SwiftUI

@Observable
class iOSSearchViewModel {
    var query: String = ""
    var searchMode: SearchMode = .phrase

    var results: [SearchResultItem] = []
    var isSearching: Bool = false
    var isPaused: Bool = false

    var totalTables: Int = 0
    var completedTables: Int = 0

    var currentTable: String = ""
    var totalRowsInTable: Int = 0
    var completedRowsInTable: Int = 0

    var selectedBookIds: Set<Int> = []
    var filterText: String = ""
    var displayedCategories: [CategoryData] = []
    var updateTrigger: Int = 0

    var searchHistory: [String] = []
    private let historyKey = "iOSSearchHistory"

    private let searchEngine = SearchEngine()
    private let ldm = LibraryDataManager.shared

    private var observerTokens: [NSObjectProtocol] = []

    init() {
        setupObservers()
        loadLibraryData()
        loadHistory()
    }

    deinit {
        removeObservers()
    }

    private func setupObservers() {
        let token1 = NotificationCenter.default.addObserver(
            forName: .bookIntegrated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDisplayedCategories()
        }
        observerTokens.append(token1)

        let token2 = NotificationCenter.default.addObserver(
            forName: .booksChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDisplayedCategories()
        }
        observerTokens.append(token2)

        let token3 = NotificationCenter.default.addObserver(
            forName: .libraryFolderChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadLibraryData()
        }
        observerTokens.append(token3)
    }

    private func removeObservers() {
        observerTokens.forEach { token in
            NotificationCenter.default.removeObserver(token)
        }
    }

    func loadHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    func addToHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var current = searchHistory
        current.removeAll { $0 == trimmed }
        current.insert(trimmed, at: 0)

        // Limit to 20 items
        if current.count > 20 {
            current = Array(current.prefix(20))
        }

        searchHistory = current
        UserDefaults.standard.set(current, forKey: historyKey)
    }

    func removeFromHistory(_ query: String) {
        var current = searchHistory
        current.removeAll { $0 == query }
        searchHistory = current
        UserDefaults.standard.set(current, forKey: historyKey)
    }

    func loadLibraryData() {
        Task {
            await ldm.loadData()
            await ldm.buildArchive()
            updateDisplayedCategories()
        }
    }

    func updateDisplayedCategories() {
        var base: [CategoryData] = []
        if AppConfig.isUsingBundleMode {
            base = ldm.filterIntegrated()
        } else {
            base = ldm.allRootCategories
        }

        if filterText.isEmpty {
            displayedCategories = base
        } else {
            displayedCategories = base.compactMap { root in
                ldm.filterCategory(root, searchText: filterText)
            }
        }

        updateTrigger += 1
    }

    func startSearch() {
        if query.isEmpty { return }
        if searchEngine.isRunning() {
            if searchEngine.currentlyPaused() {
                searchEngine.resume()
                isPaused = false
            } else {
                searchEngine.pause()
                isPaused = true
            }
            return
        }

        if ldm.searchIsRunning {
            return
        }

        isSearching = true
        isPaused = false
        results = []
        totalTables = 0
        completedTables = 0
        completedRowsInTable = 0
        totalRowsInTable = 0

        var tablesToScan: Set<String> = []
        if selectedBookIds.isEmpty {
            tablesToScan = ldm.getCheckedTables(displayedCategories)
        } else {
            tablesToScan = Set(selectedBookIds.map { "b\($0)" })
        }

        Task.detached { [weak self] in
            guard let self else { return }

            await ldm.performSearch(
                tableToScan: tablesToScan,
                searchEngine: searchEngine,
                query: query,
                mode: searchMode,
                onInitialize: { total in
                    Task { @MainActor in self.totalTables = total; self.completedTables = 0 }
                },
                onTableProgress: { completed in
                    Task { @MainActor in self.completedTables = completed }
                },
                onRowProgress: { _, tableName, current, total in
                    Task { @MainActor in
                        self.currentTable = tableName
                        self.completedRowsInTable = current
                        self.totalRowsInTable = total
                    }
                },
                completion: { item in
                    Task { @MainActor in self.results.append(item) }
                },
                onComplete: {
                    Task { @MainActor in
                        self.isSearching = false
                        self.isPaused = false
                        self.searchEngine.stop()
                    }
                }
            )
        }
    }

    func stopSearch() {
        searchEngine.stop()
        ldm.stopSearch()
        isSearching = false
        isPaused = false
    }
}
