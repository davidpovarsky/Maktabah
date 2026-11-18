import Combine
import Foundation
import Observation
#if DEBUG
import CryptoKit
#endif
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
    private(set) var submittedConfiguration: [String]?
    private(set) var configurationInvalidated = false
    private(set) var wasCancelled = false
    /// Counts accepted engine submissions, never keystrokes or local result filtering.
    private(set) var submissionRevision = 0
    private(set) var cancellationRevision = 0
    private(set) var paginationRevision = 0

    // MARK: - Presentation State

    var resultKitabFilter: String = "" {
        didSet {
            // Clearing a loaded filter also remounts rows; it must not initiate a provider page.
            if oldValue != resultKitabFilter { allowsAutomaticPaging = false }
        }
    }
    private(set) var allowsAutomaticPaging = true

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
    private var zayitHits: [String: ZayitSearchHit] = [:]
    private var zayitSearchTask: Task<Void, Never>?
    private var sefariaSearchTask: Task<Void, Never>?
    private var acceptsEngineUpdates = false
    private var searchGeneration = 0
    private var isPreparingZayitSearch = false

    init() {
        setupObservers()
        #if DEBUG
        installNativeSearchPageObservation()
        #endif
    }

    private func setupObservers() {
        otzaria.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.acceptsEngineUpdates && !self.resultsAreDirty && self.hasSubmitted && !self.isSefaria && self.scope != .zayit {
                    self.results = self.otzaria.results
                    self.isSearching = self.otzaria.isSearching
                    self.errorMessage = self.otzaria.errorMessage
                    self.hasMore = self.otzaria.hasMore
                    self.isLoadingMore = self.otzaria.isLoadingMore
                    #if DEBUG
                    self.recordNativePublishedSearchResults()
                    #endif
                }
            }
        }.store(in: &cancellables)

        zayitSession.objectWillChange.sink { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.acceptsEngineUpdates && !self.resultsAreDirty && self.hasSubmitted && !self.isSefaria && self.scope == .zayit {
                    let hits = self.zayitSession.model.hits
                    self.cacheZayitHits(hits)
                    self.results = self.mapZayitHits(hits)
                    self.isSearching = self.isPreparingZayitSearch || self.zayitSession.model.isLoading || self.zayitSession.state == .restoring
                    if let modelError = self.zayitSession.model.errorMessage, !modelError.isEmpty {
                        self.errorMessage = modelError
                    } else if case .failed(let sessionError) = self.zayitSession.state {
                        self.errorMessage = sessionError
                    } else {
                        self.errorMessage = nil
                    }
                    self.hasMore = self.zayitSession.model.hasMore
                    self.isLoadingMore = self.zayitSession.model.isLoadingMore
                    #if DEBUG
                    self.recordNativePublishedSearchResults()
                    #endif
                }
            }
        }.store(in: &cancellables)
    }

    #if DEBUG
    private let nativeSearchObservationID = UUID()
    #if os(iOS)
    @ObservationIgnored
    #endif
    private var nativePublishedSearchBytes: Data?

    /// Explicit disposable-fixture diagnostics. Release builds contain no hook.
    /// Request query fields are hashed; only fixture provider metadata is retained.
    /// No observer can alter a result or supply a response.
    private var nativeSearchObservationNamespace: String? {
        guard UserDefaults.standard.bool(forKey: "GlobalSearchNativeTraceEnabled"),
              OtzariaDataProfileRegistry.activeProfileID == "miniTest10",
              let value = UserDefaults.standard.string(forKey: "studyWorkspaceTestingNamespace"),
              UUID(uuidString: value) != nil else { return nil }
        return value
    }

    private func nativeJSONObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private func nativeResultObservation(_ item: SearchResultItem) -> [String: Any] {
        ["id": item.id, "bookID": item.bookId, "bookTitle": item.bookTitle,
         "lineIndex": item.page, "locator": item.backendLocator?.persistenceKey ?? "",
         "reference": item.locationDisplayText ?? "",
         "highlightTerms": item.highlightTerms ?? [],
         "snippetSHA256": SHA256.hash(data: Data(item.attributedText.string.utf8))
            .map { String(format: "%02x", $0) }.joined()]
    }

    private func nativeRequestObservation<T: Encodable>(_ request: T, query: String) throws -> [String: Any] {
        guard var object = try nativeJSONObject(request) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        object.removeValue(forKey: "query")
        object["querySHA256"] = SHA256.hash(data: Data(query.utf8)).map { String(format: "%02x", $0) }.joined()
        return object
    }

    private func installNativeSearchPageObservation() {
        zayitSession.model.nativePageObserver = { [weak self] request, page, accumulated, nextOffset in
            guard let self, self.nativeSearchObservationNamespace != nil else { return }
            do {
                try self.writeNativeSearchObservation([
                    "event": "provider", "engine": "zayit",
                    "request": self.nativeRequestObservation(request, query: request.query),
                    "page": self.nativeJSONObject(page),
                    "accumulatedSource": self.nativeJSONObject(accumulated),
                    "nextOffset": nextOffset
                ])
            } catch { NSLog("[GlobalSearchNativeObservation] page observation failed: %@", String(describing: error)) }
        }
        otzaria.nativePageObserver = { [weak self] request, page, records, consumed in
            guard let self, self.nativeSearchObservationNamespace != nil else { return }
            do {
                let retained = try records.map { record in
                    ["metadata": try self.nativeJSONObject(record.metadata),
                     "item": self.nativeResultObservation(record.item)] as [String: Any]
                }
                try self.writeNativeSearchObservation([
                    "event": "provider", "engine": "otzaria",
                    "request": self.nativeRequestObservation(request, query: request.query),
                    "page": self.nativeJSONObject(page), "retainedRecords": retained,
                    "nextOffset": consumed
                ])
            } catch { NSLog("[GlobalSearchNativeObservation] page observation failed: %@", String(describing: error)) }
        }
    }

    private func recordNativePublishedSearchResults() {
        guard nativeSearchObservationNamespace != nil, acceptsEngineUpdates, !resultsAreDirty,
              !isSearching, !isLoadingMore, !results.isEmpty else { return }
        let event: [String: Any] = [
            "event": "published", "engine": scope == .zayit ? "zayit" : "otzaria",
            "items": results.map(nativeResultObservation),
            "hasMore": hasMore, "submissionRevision": submissionRevision,
            "searchGeneration": searchGeneration
        ]
        do {
            let bytes = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
            guard nativePublishedSearchBytes != bytes else { return }
            try writeNativeSearchObservation(event)
            nativePublishedSearchBytes = bytes
        } catch { NSLog("[GlobalSearchNativeObservation] UI observation failed: %@", String(describing: error)) }
    }

    private func writeNativeSearchObservation(_ event: [String: Any]) throws {
        guard let namespace = nativeSearchObservationNamespace else { return }
        var record = event
        record["schemaVersion"] = 1
        record["namespace"] = namespace
        record["sessionID"] = nativeSearchObservationID.uuidString
        record["submissionRevision"] = submissionRevision
        record["searchGeneration"] = searchGeneration
        record["backendGeneration"] = BackendCoordinator.shared.generation
        record["profileID"] = OtzariaDataProfileRegistry.activeProfileID
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
            .appendingPathComponent("OtzariaLogs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("search-native-" + namespace + ".jsonl")
        if !FileManager.default.fileExists(atPath: file.path) { try Data().write(to: file, options: .atomic) }
        let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size < 8 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        var bytes = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        bytes.append(10)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: bytes)
    }
    #endif

    // MARK: - Backend Awareness

    var isSefaria: Bool {
        !BackendCoordinator.shared.usesNativeMaktabahDataPath
    }

    var availableScopes: [UnifiedSearchScope] {
        if BackendCoordinator.shared.activeBackendID == .sefariaEmbedded { return [.exact] }
        return isSefaria ? [.exact, .advanced] : UnifiedSearchScope.allCases
    }

    var hasConfigurableOptions: Bool {
        scope == .advanced && (!isSefaria || supportsSefariaOptions)
    }

    var showsSearchFeedback: Bool { !isSefaria && hasSubmitted }

    var feedbackState: UnifiedSearchPresentationState {
        UnifiedSearchPresentationPolicy.resolve(resultCount: results.count, isLoading: isSearching,
            errorMessage: errorMessage, hasSubmitted: hasSubmitted, indexReady: !packageMissing)
    }

    func refreshSearchData() {
        guard !isSefaria else { return }
        otzaria.refreshStatus()
        Task { await zayitSession.restoreIfNeeded(existingSeforimDB: ZayitSearchExistingDatabaseProvider.currentURL) }
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
            if case .failed(let error) = zayitSession.state { return error }
            if zayitSession.state == .restoring { return "משחזר את מנוע זית…" }
            if zayitSession.state == .notConfigured { return "חבילת אינדקס זית אינה מותקנת." }
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
        guard !(isSearching && submittedConfiguration == requestConfiguration) else { return }
        stopEngineWork()
        submittedConfiguration = requestConfiguration
        configurationInvalidated = false
        hasSubmitted = true
        wasCancelled = false
        errorMessage = nil
        hasMore = false
        guard availableScopes.contains(scope) else {
            results = []
            errorMessage = "שיטת חיפוש זו אינה נתמכת במקור הפעיל. בחרו שיטה זמינה."
            return
        }
        if let message = optionsValidationMessage {
            results = []
            errorMessage = message
            return
        }
        submissionRevision += 1
        acceptsEngineUpdates = true
        resultKitabFilter = ""
        allowsAutomaticPaging = true
        #if os(iOS)
        searchViewModel?.addToHistory(trimmed)
        #endif
        #if DEBUG
        NSLog("[GlobalSearch] submit revision=%d generation=%d backend=%@ scope=%@", submissionRevision, searchGeneration,
              BackendCoordinator.shared.activeBackendID.rawValue, scope.rawValue)
        #endif

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
        searchViewModel.state = .loading
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
        // Preserve provider fidelity through SearchViewModel.effectiveBackendSearchOptions().
        // Phrase enforces exact; contains enforces Hebrew lemmatization; near preserves match mode.
        if !supportsSefariaOptions || scope == .exact {
            searchViewModel.searchMode = .phrase
        } else if sefariaWordDistance > 0 {
            searchViewModel.searchMode = .near
            searchViewModel.nearDistance = sefariaWordDistance
        } else {
            searchViewModel.searchMode = sefariaMatchMode == .exact ? .phrase : .contains
        }
        if !supportsSefariaOptions {
            searchViewModel.backendSearchOptions.matchMode = .exact
            searchViewModel.backendSearchOptions.wordDistance = 0
            searchViewModel.backendSearchOptions.sortOrder = .relevance
            searchViewModel.backendSearchOptions.reverseSort = false
        }

        let generation = searchGeneration
        sefariaSearchTask = Task {
            await searchViewModel.startSearch()
            guard !Task.isCancelled else { return }
            self.observeSefariaState(generation: generation)
        }
    }

    private func observeSefariaState(generation: Int) {
        guard generation == searchGeneration, acceptsEngineUpdates, !resultsAreDirty,
              isSefaria, let model = searchViewModel else { return }
        withObservationTracking {
            results = model.results
            isSearching = model.isSearching
            hasMore = model.hasMoreBackendResults
            isLoadingMore = model.isLoadingMoreBackendResults
            if case .error(let message) = model.state { errorMessage = message }
            else { errorMessage = model.backendPaginationErrorMessage }
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeSefariaState(generation: generation) }
        }
    }

    private func runZayitSearch(query: String) {
        isPreparingZayitSearch = true
        isSearching = true
        results = []
        hasMore = false
        isLoadingMore = false

        let generation = searchGeneration
        let backendGeneration = BackendCoordinator.shared.generation
        let profile = OtzariaDataProfileRegistry.activeProfileID
        let database = ZayitSearchExistingDatabaseProvider.currentURL
        let filters = ZayitSearchFilters(bookIds: selectedBookIds.sorted().map { Int64($0) })
        zayitSearchTask = Task {
            await zayitSession.restoreIfNeeded(existingSeforimDB: ZayitSearchExistingDatabaseProvider.currentURL)
            guard !Task.isCancelled, generation == self.searchGeneration else { return }
            guard !self.isSefaria, self.scope == .zayit,
                  backendGeneration == BackendCoordinator.shared.generation,
                  profile == OtzariaDataProfileRegistry.activeProfileID,
                  database == ZayitSearchExistingDatabaseProvider.currentURL else {
                self.clearResults()
                return
            }
            if case .failed(let error) = zayitSession.state {
                self.isPreparingZayitSearch = false
                await MainActor.run {
                    self.isSearching = false
                    self.errorMessage = error
                }
                return
            }
            guard zayitSession.state == .ready else {
                self.isPreparingZayitSearch = false
                await MainActor.run {
                    self.isSearching = false
                    if self.packageMissing {
                        self.errorMessage = String(localized: "Zayit index package is not installed.", defaultValue: "חבילת אינדקס זית אינה מותקנת.")
                    }
                }
                return
            }
            zayitSession.model.query = query
            self.isPreparingZayitSearch = false
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
        let advanced = scope == .advanced
        otzaria.negativeQuery = advanced ? otzariaNegativeQuery : ""
        otzaria.scope = advanced ? otzariaScope : .wordDistance
        otzaria.negativeScope = advanced ? otzariaNegativeScope : .wordDistance
        otzaria.wordMatchMode = advanced ? otzariaWordMatchMode : .all
        otzaria.wordMatchCount = advanced ? otzariaWordMatchCount : 1
        otzaria.grouping = advanced ? otzariaGrouping : nil
        otzaria.distance = advanced ? otzariaDistance : 0
        otzaria.negativeDistance = advanced ? otzariaNegativeDistance : 0
        otzaria.matchNikud = advanced && otzariaMatchNikud
        otzaria.matchTaamim = advanced && otzariaMatchTaamim
        otzaria.selectedBookIds = selectedBookIds

        if scope == .advanced {
            applyOtzariaAdvancedWordOptions(to: query)
        } else {
            otzaria.searchOptions = [:]
            otzaria.customSpacing = [:]
            otzaria.alternativeWords = [:]
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
        otzaria.customSpacing = otzariaCustomSpacingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? [:] : Dictionary(uniqueKeysWithValues: otzariaCustomSpacingText
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
        guard acceptsEngineUpdates, !resultsAreDirty, !isSearching, hasMore, !isLoadingMore else { return }
        paginationRevision += 1
        #if DEBUG
        NSLog("[GlobalSearch] page revision=%d generation=%d backend=%@ scope=%@", paginationRevision, searchGeneration,
              BackendCoordinator.shared.activeBackendID.rawValue, scope.rawValue)
        #endif
        if isSefaria {
            guard let searchViewModel, hasMore, !isLoadingMore else { return }
            isLoadingMore = true
            searchViewModel.loadNextBackendPage()
        } else if scope == .zayit {
            zayitSession.model.loadNextPage()
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
        guard !resultsAreDirty, !wasCancelled else { return }
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        if item.archive == "Zayit" {
            guard scope == .zayit, let hitID = item.backendHitID,
                  let hit = zayitHits[hitID] else {
                errorMessage = "תוצאת זית אינה שייכת לחיפוש הנוכחי. יש לחפש שוב."
                return
            }
            ZayitSearchReaderNavigationAdapter.open(hit, using: manager)
            return
        }

        if let book = resolveBook(from: item) {
            let shouldRecord = UserDefaults.standard.recordSearchHistory
            let targetContentId: Int
            if let backendLocator = item.backendLocator {
                let resolved = ReaderDestinationResolver.resolve(locator: backendLocator)
                targetContentId = LegacyIdentityRegistry.shared.id(for: resolved.sectionLocator)
            } else {
                targetContentId = item.page
            }
            let mode = searchModeForReader
            let dist = nearDistanceForReader
            manager.openBook(
                book,
                initialContentId: targetContentId,
                searchText: query,
                searchMode: mode,
                nearDistance: dist,
                recordHistory: shouldRecord,
                highlightTerms: item.highlightTerms
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
                        recordHistory: shouldRecord,
                        highlightTerms: item.highlightTerms
                    )
                }
            }
        }
    }

    func resolveBook(from item: SearchResultItem) -> BooksData? {
        if let locator = item.backendLocator {
            let resolved = ReaderDestinationResolver.resolve(locator: locator)
            return MaktabahBackendAdapter.resolveBook(for: resolved.sectionLocator, in: LibraryDataManager.shared)
        }
        return OtzariaSearchResultResolver.resolveBook(
            from: item,
            libraryDataManager: LibraryDataManager.shared
        )
    }

    func clearResults() {
        stopEngineWork()
        results = []
        errorMessage = nil
        hasMore = false
        isLoadingMore = false
        hasSubmitted = false
        submittedConfiguration = nil
        configurationInvalidated = false
        wasCancelled = false
        resultKitabFilter = ""
        allowsAutomaticPaging = true
        searchViewModel?.clearResults()
    }

    private func stopEngineWork() {
        acceptsEngineUpdates = false
        searchGeneration += 1
        isPreparingZayitSearch = false
        sefariaSearchTask?.cancel()
        sefariaSearchTask = nil
        zayitSearchTask?.cancel()
        zayitSearchTask = nil
        zayitSession.model.cancelSearch()
        otzaria.clear()
        searchViewModel?.stopSearch()
        zayitHits.removeAll()
        isSearching = false
        isLoadingMore = false
    }

    func cancelSearch() {
        guard isSearching || isLoadingMore else { return }
        cancellationRevision += 1
        stopEngineWork()
        results = []
        errorMessage = nil
        hasMore = false
        wasCancelled = true
        #if DEBUG
        NSLog("[GlobalSearch] cancel revision=%d generation=%d", cancellationRevision, searchGeneration)
        #endif
    }

    func configurationDidChange() {
        guard resultsAreDirty else { return }
        configurationInvalidated = true
        if isSearching || isLoadingMore { stopEngineWork() }
    }

    func clearFilter() {
        selectedBookIds.removeAll()
        searchViewModel?.setSelectedBooks([])
    }

    func handleBackendChanged() {
        scope = BackendCoordinator.shared.activeBackendID == .sefariaEmbedded ? .exact : .advanced
        clearFilter()
        clearResults()
        query = ""
        resultKitabFilter = ""
    }

    // MARK: - Zayit Mapping Helpers

    private func cacheZayitHits(_ hits: [ZayitSearchHit]) {
        zayitHits.removeAll(keepingCapacity: true)
        for hit in hits {
            zayitHits[zayitHitID(hit)] = hit
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
            let locator = TextLocator(
                backend: .otzaria,
                workKey: "book:\(hit.bookId)",
                position: .legacyLine(hit.lineIndex)
            )
            return SearchResultItem(
                archive: "Zayit",
                tableName: "zayit:\(hit.stableBookKey)",
                bookId: Int(hit.bookId),
                bookTitle: hit.bookTitle,
                page: hit.lineIndex,
                part: 1,
                attributedText: attr,
                backendLocator: locator,
                locationDisplayText: hit.reference.isEmpty ? nil : hit.reference,
                highlightTerms: hit.matchedTerms,
                backendHitID: zayitHitID(hit)
            )
        }
    }

    private func zayitHitID(_ hit: ZayitSearchHit) -> String {
        "zayit:\(OtzariaDataProfileRegistry.activeProfileID):\(hit.id)"
    }

    // MARK: - Reader Parameter Helpers

    var searchModeForReader: SearchMode {
        switch scope {
        case .exact: return .phrase
        case .fuzzy: return .contains
        case .advanced: return .near
        case .zayit: return .near
        }
    }

    var nearDistanceForReader: Int {
        if isSefaria {
            return sefariaWordDistance > 0 ? sefariaWordDistance : 10
        }
        return otzariaDistance > 0 ? otzariaDistance : 10
    }
}

// MARK: - Option Enum Extensions

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

