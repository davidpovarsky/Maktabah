import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(macOS)
extension UnifiedSearchSessionController: ObservableObject {}
#endif

#if os(iOS)
@Observable
#endif
@MainActor
final class UnifiedSearchSessionController {
    // MARK: - Search State

    var query: String = ""
    var scope: UnifiedSearchScope = .advanced
    var selectedBookIds: Set<Int> = []
    var results: [SearchResultItem] = []
    var isSearching: Bool = false
    var errorMessage: String? = nil
    var hasMore: Bool = false
    var isLoadingMore: Bool = false
    var hasSubmitted: Bool = false

    // MARK: - Presentation State

    var resultKitabFilter: String = ""

    // MARK: - Sheet / Disclosure Toggles

    var showsBookFilterSheet: Bool = false
    var showsAdvancedOptions: Bool = false
    var showsSearchDataSheet: Bool = false

    // MARK: - Engines

    let otzaria = OtzariaTextSearchViewModel()
    let zayitSession = ZayitSearchSessionController()
    weak var searchViewModel: SearchViewModel?

    // MARK: - Otzaria Advanced Options

    var otzariaOrder: OtzariaSearchOrder = .catalogue
    var otzariaNegativeQuery: String = ""
    var otzariaScope: OtzariaSearchScope = .wordDistance
    var otzariaNegativeScope: OtzariaSearchScope = .wordDistance
    var otzariaWordMatchMode: OtzariaWordMatchMode = .all
    var otzariaWordMatchCount: Int = 1
    var otzariaGrouping: OtzariaResultGrouping? = nil
    var otzariaDistance: Int = 0
    var otzariaNegativeDistance: Int = 0
    var otzariaMatchNikud: Bool = false
    var otzariaMatchTaamim: Bool = false
    var otzariaEnablesPrefixes: Bool = false
    var otzariaEnablesSuffixes: Bool = false
    var otzariaEnablesSpellingVariants: Bool = false
    var otzariaEnablesAramaic: Bool = false
    var otzariaIgnoresQuotes: Bool = false
    var otzariaCustomSpacingText: String = ""
    var otzariaAlternativeWordsText: String = ""

    // MARK: - Sefaria Advanced Options

    var sefariaMatchMode: LibrarySearchMatchMode = .exact
    var sefariaWordDistance: Int = 0
    var sefariaSortOrder: LibrarySearchSortOrder = .relevance
    var sefariaReverseSort: Bool = false

    // MARK: - Private State

    private var cancellables: Set<AnyCancellable> = []
    private var zayitHits: [Int64: ZayitSearchHit] = [:]

    init() {
        setupObservers()
    }

    private func setupObservers() {
        otzaria.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if !self.isSefaria && self.scope != .zayit {
                    self.results = self.otzaria.results
                    self.isSearching = self.otzaria.isSearching
                    self.errorMessage = self.otzaria.errorMessage
                    self.hasMore = self.otzaria.hasMore
                    self.isLoadingMore = self.otzaria.isLoadingMore
                }
            }
        }.store(in: &cancellables)

        zayitSession.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if !self.isSefaria && self.scope == .zayit {
                    let hits = self.zayitSession.model.hits
                    self.cacheZayitHits(hits)
                    self.results = self.mapZayitHits(hits)
                    self.isSearching = self.zayitSession.model.isLoading
                    self.errorMessage = self.zayitSession.model.errorMessage
                    self.hasMore = false
                    self.isLoadingMore = false
                }
            }
        }.store(in: &cancellables)
    }

    // MARK: - Backend Awareness

    var isSefaria: Bool {
        !BackendCoordinator.shared.usesNativeMaktabahDataPath
    }

    var availableScopes: [UnifiedSearchScope] {
        isSefaria ? [.exact, .advanced] : UnifiedSearchScope.allCases
    }

    var packageMissing: Bool {
        if isSefaria { return false }
        if scope == .zayit { return zayitSession.state != .ready }
        return switch otzaria.status {
        case .ready: false
        case .checkingPackage, .building, .finalizing, .downloadingPackage, .installingPackage: false
        default: true
        }
    }

    var statusText: String {
        if isSefaria {
            let backendName = BackendCoordinator.shared.activeBackendID.displayName
            if isSearching { return "מחפש ב־\(backendName)…" }
            if !results.isEmpty {
                let total = searchViewModel?.totalTables ?? results.count
                return "\(results.count) מתוך \(total) תוצאות"
            }
            return selectedBookIds.isEmpty ? backendName : "סינון ל־\(selectedBookIds.count) ספרים"
        }
        if scope == .zayit {
            if let error = zayitSession.model.errorMessage { return error }
            return zayitSession.model.hits.isEmpty ? "זית" : "תוצאות זית (\(results.count))"
        }
        if isSearching { return "מחפש באוצריא…" }
        if !results.isEmpty { return "\(results.count) תוצאות" }
        return otzaria.status.label
    }

    // MARK: - Search Execution

    func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }
        hasSubmitted = true
        errorMessage = nil

        if isSefaria {
            runSefariaSearch(query: trimmed)
        } else if scope == .zayit {
            runZayitSearch(query: trimmed)
        } else {
            runOtzariaSearch(query: trimmed)
        }
    }

    private func runSefariaSearch(query: String) {
        guard let searchViewModel else { return }
        isSearching = true
        results = []
        hasMore = false
        isLoadingMore = false

        searchViewModel.query = query
        searchViewModel.setSelectedBooks(selectedBookIds)
        if scope == .exact {
            searchViewModel.backendSearchOptions.matchMode = .exact
            searchViewModel.backendSearchOptions.wordDistance = 0
            searchViewModel.backendSearchOptions.sortOrder = sefariaSortOrder
            searchViewModel.backendSearchOptions.reverseSort = sefariaReverseSort
        } else {
            searchViewModel.backendSearchOptions.matchMode = sefariaMatchMode
            searchViewModel.backendSearchOptions.wordDistance = sefariaWordDistance
            searchViewModel.backendSearchOptions.sortOrder = sefariaSortOrder
            searchViewModel.backendSearchOptions.reverseSort = sefariaReverseSort
        }
        searchViewModel.addToHistory(query)

        Task {
            await searchViewModel.startSearch()
            await MainActor.run {
                self.results = searchViewModel.results
                self.isSearching = searchViewModel.isSearching
                self.hasMore = searchViewModel.hasMoreBackendResults
                self.isLoadingMore = searchViewModel.isLoadingMoreBackendResults
                if case .error(let msg) = searchViewModel.state {
                    self.errorMessage = msg
                }
            }
        }
    }

    private func runZayitSearch(query: String) {
        isSearching = true
        results = []
        hasMore = false
        isLoadingMore = false

        Task {
            await zayitSession.restoreIfNeeded(existingSeforimDB: ZayitSearchExistingDatabaseProvider.currentURL)
            zayitSession.model.query = query
            let filters = ZayitSearchFilters(bookIds: selectedBookIds.map { Int64($0) })
            zayitSession.model.runSearch(filters: filters)
        }
    }

    private func runOtzariaSearch(query: String) {
        isSearching = true
        results = []
        hasMore = false
        isLoadingMore = false

        otzaria.query = query
        otzaria.mode = {
            switch scope {
            case .exact: .exact
            case .advanced: .advanced
            case .fuzzy: .fuzzy
            case .zayit: .advanced
            }
        }()
        otzaria.order = otzariaOrder
        otzaria.negativeQuery = otzariaNegativeQuery
        otzaria.scope = otzariaScope
        otzaria.negativeScope = otzariaNegativeScope
        otzaria.wordMatchMode = otzariaWordMatchMode
        otzaria.wordMatchCount = otzariaWordMatchCount
        otzaria.grouping = otzariaGrouping
        otzaria.distance = otzariaDistance
        otzaria.negativeDistance = otzariaNegativeDistance
        otzaria.matchNikud = otzariaMatchNikud
        otzaria.matchTaamim = otzariaMatchTaamim
        otzaria.selectedBookIds = selectedBookIds

        if scope == .advanced {
            applyOtzariaAdvancedWordOptions(to: query)
        }

        otzaria.search()
    }

    private func applyOtzariaAdvancedWordOptions(to text: String) {
        let words = (try? OtzariaSearchEngineBridge.splitQueryWords(text))
            ?? text.split(whereSeparator: \.isWhitespace).map(String.init)
        var options: [String: [String: Bool]] = [:]
        for (index, word) in words.enumerated() {
            options["\(word)_\(index)"] = [
                "קידומות": otzariaEnablesPrefixes,
                "סיומות": otzariaEnablesSuffixes,
                "קידומות דקדוקיות": otzariaEnablesPrefixes,
                "סיומות דקדוקיות": otzariaEnablesSuffixes,
                "כתיב מלא/חסר": otzariaEnablesSpellingVariants,
                "קידומות ארמיות": otzariaEnablesAramaic,
                "סיומות ארמיות": otzariaEnablesAramaic,
                "תרגום ארמי": otzariaEnablesAramaic,
                "ראשי תיבות": otzariaIgnoresQuotes,
                "התעלם מגרשיים": otzariaIgnoresQuotes,
            ]
        }
        otzaria.searchOptions = options
        otzaria.customSpacing = Dictionary(uniqueKeysWithValues: otzariaCustomSpacingText
            .split(separator: ",", omittingEmptySubsequences: false)
            .enumerated()
            .map { ("\($0.offset)-\($0.offset + 1)", String($0.element).trimmingCharacters(in: .whitespaces)) })
        otzaria.alternativeWords = Dictionary(uniqueKeysWithValues: otzariaAlternativeWordsText
            .split(separator: ";", omittingEmptySubsequences: false)
            .enumerated()
            .map {
                (String($0.offset), $0.element.split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
            })
    }

    // MARK: - Pagination

    func loadNextPage() {
        if isSefaria {
            guard let searchViewModel, hasMore, !isLoadingMore else { return }
            isLoadingMore = true
            searchViewModel.loadNextBackendPage()
            Task { @MainActor in
                self.results = searchViewModel.results
                self.hasMore = searchViewModel.hasMoreBackendResults
                self.isLoadingMore = searchViewModel.isLoadingMoreBackendResults
            }
        } else if scope == .zayit {
            // Zayit single page
        } else {
            otzaria.loadNextPage()
        }
    }

    // MARK: - Actions

    func searchInBook(_ item: SearchResultItem) {
        let resolvedBookId: Int?
        if let book = resolveBook(from: item) {
            resolvedBookId = book.id
        } else if item.bookId > 0 {
            resolvedBookId = item.bookId
        } else {
            let table: String
            if item.tableName.hasPrefix("otzaria:") {
                table = String(item.tableName.dropFirst("otzaria:".count))
            } else if item.tableName.hasPrefix("b") {
                table = String(item.tableName.dropFirst())
            } else {
                table = item.tableName
            }
            resolvedBookId = Int(table)
        }

        guard let bookId = resolvedBookId, bookId > 0 else { return }
        selectedBookIds = [bookId]
        resultKitabFilter = ""
        searchViewModel?.setSelectedBooks([bookId])
        runSearch()
    }

    func openResult(_ item: SearchResultItem, using manager: iOSNavigationManager) {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        if scope == .zayit, let hit = zayitHits[Int64(item.bookId)] ?? zayitHits.values.first(where: { $0.lineIndex == item.page && $0.bookTitle == item.bookTitle }) {
            ZayitSearchReaderNavigationAdapter.open(hit, using: manager)
            return
        }

        if let book = resolveBook(from: item) {
            let shouldRecord = UserDefaults.standard.recordSearchHistory
            let targetContentId = item.backendLocator != nil ? item.bookId : item.page
            let mode = searchModeForReader
            let dist = nearDistanceForReader
            manager.openBook(
                book,
                initialContentId: targetContentId,
                searchText: query,
                searchMode: mode,
                nearDistance: dist,
                recordHistory: shouldRecord
            )
            return
        }

        Task {
            let table: String
            let contentId: Int
            if item.tableName.hasPrefix("otzaria:") {
                table = String(item.tableName.dropFirst("otzaria:".count))
                contentId = item.page
            } else if item.tableName.hasPrefix("b") {
                table = String(item.tableName.dropFirst())
                contentId = item.bookId
            } else {
                table = item.tableName
                contentId = item.bookId
            }

            if let tableInt = Int(table), let bookData = LibraryDataManager.shared.getBook([tableInt]).first {
                let shouldRecord = UserDefaults.standard.recordSearchHistory
                await MainActor.run {
                    manager.openBook(
                        bookData,
                        initialContentId: contentId,
                        searchText: self.query,
                        searchMode: self.searchModeForReader,
                        nearDistance: self.nearDistanceForReader,
                        recordHistory: shouldRecord
                    )
                }
            }
        }
    }

    func resolveBook(from item: SearchResultItem) -> BooksData? {
        if let locator = item.backendLocator {
            return MaktabahBackendAdapter.resolveBook(for: locator, in: LibraryDataManager.shared)
        }
        return OtzariaSearchResultResolver.resolveBook(
            from: item,
            libraryDataManager: LibraryDataManager.shared
        )
    }

    func clearResults() {
        results = []
        errorMessage = nil
        hasMore = false
        isLoadingMore = false
        hasSubmitted = false
        otzaria.clear()
        searchViewModel?.clearResults()
    }

    func clearFilter() {
        selectedBookIds.removeAll()
        searchViewModel?.setSelectedBooks([])
    }

    func handleBackendChanged() {
        scope = .advanced
        clearFilter()
        clearResults()
        query = ""
        resultKitabFilter = ""
    }

    // MARK: - Zayit Mapping Helpers

    private func cacheZayitHits(_ hits: [ZayitSearchHit]) {
        zayitHits.removeAll(keepingCapacity: true)
        for hit in hits {
            zayitHits[hit.id] = hit
        }
    }

    private func mapZayitHits(_ hits: [ZayitSearchHit]) -> [SearchResultItem] {
        hits.map { hit in
            let segments = SearchInlineMarkupSanitizer.segments(from: hit.snippetHtml)
            let attr = NSMutableAttributedString()
            for segment in segments {
                var attrs: [NSAttributedString.Key: Any] = [:]
                #if canImport(UIKit)
                if segment.highlighted {
                    attrs[.foregroundColor] = UIColor.systemRed
                    attrs[.font] = UIFont.boldSystemFont(ofSize: 17)
                }
                #endif
                attr.append(NSAttributedString(string: segment.text, attributes: attrs))
            }
            return SearchResultItem(
                archive: "Zayit",
                tableName: "zayit:\(hit.stableBookKey)",
                bookId: Int(hit.bookId),
                bookTitle: hit.bookTitle,
                page: hit.lineIndex,
                part: 1,
                attributedText: attr
            )
        }
    }

    // MARK: - Reader Parameter Helpers

    private var searchModeForReader: SearchMode {
        switch scope {
        case .exact: return .phrase
        case .fuzzy: return .contains
        case .advanced: return .near
        case .zayit: return .near
        }
    }

    private var nearDistanceForReader: Int {
        if isSefaria {
            return sefariaWordDistance > 0 ? sefariaWordDistance : 10
        }
        return otzariaDistance > 0 ? otzariaDistance : 10
    }
}

// MARK: - Option Enum Extensions

extension OtzariaSearchOrder: CaseIterable, Identifiable {
    public static var allCases: [OtzariaSearchOrder] { [.catalogue, .relevance] }
    public var id: String { rawValue }
    var label: String {
        switch self {
        case .catalogue: return "לפי סדר הקטלוג"
        case .relevance: return "רלוונטיות"
        }
    }
}

extension OtzariaWordMatchMode: Identifiable {
    public var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "כל המילים"
        case .anyWord: return "כל מילה שהיא"
        case .mostWords: return "רוב המילים"
        case .atLeast: return "לפחות X מילים"
        }
    }
}

