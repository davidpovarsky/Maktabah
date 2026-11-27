//
//  Search+Execution.swift
//  Maktabah
//

import Foundation

extension SearchViewModel {
    func effectiveBackendSearchOptions() -> LibrarySearchOptions {
        var options = backendSearchOptions
        options.searchMode = searchMode.librarySearchMode
        switch searchMode {
        case .phrase:
            options.matchMode = .exact
            options.wordDistance = 0
        case .near:
            options.wordDistance = max(1, nearDistance)
        case .contains, .or:
            options.matchMode = .hebrewLemmatized
        }
        return options
    }

    func loadNextBackendPage() {
        guard !isSearching,
              !isLoadingMoreBackendResults,
              paginationState.hasMore,
              let offset = paginationState.nextOffset else { return }

        isLoadingMoreBackendResults = true
        backendPaginationErrorMessage = nil
        let generation = backendSearchGeneration
        let requestQuery = query
        let selectedBooks = selectedBookIds.compactMap { ldm.booksById[$0] }
        let scopedBooks = selectedBooks.filter { $0.backendLocator != nil }
        let scopeWorkKeys = scopedBooks.compactMap(\.backendLocator?.workKey)
        let candidateFilters = scopedBooks.compactMap(\.backendSearchPath).filter { !$0.isEmpty }
        let backendFilters = candidateFilters.count == scopedBooks.count ? candidateFilters : []
        let options = effectiveBackendSearchOptions()
        let request = LibrarySearchRequest(
            query: requestQuery, offset: offset, limit: backendPageSize,
            filters: backendFilters, scopeWorkKeys: scopeWorkKeys, options: options
        )
        let configuration = LibrarySearchRequest(
            query: requestQuery, offset: 0, limit: backendPageSize,
            filters: backendFilters, scopeWorkKeys: scopeWorkKeys, options: options
        )

        loadMoreBackendWork.withLock {
            $0?.cancel()
            $0 = nil
        }
        let attempt = originalPageLedger.begin(
            generation: generation,
            request: .encode(request, configuration: configuration, offset: request.offset, limit: request.limit),
            replacing: false, consumedBefore: paginationState.loadedCount, cursorBefore: paginationState.nextOffset
        )
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let page = try await BackendCoordinator.shared.search(request)
                try Task.checkCancellation()
                guard self.backendSearchGeneration == generation else { return }

                let newResults = page.hits.map(MaktabahBackendAdapter.searchItem)
                self.results.append(contentsOf: newResults)
                self.paginationState.applyNextPage(requestedOffset: offset, pageTotal: page.total, nextOffset: page.nextOffset, count: newResults.count)
                self.completedTables = self.results.count
                self.recordOriginalBackendPage(page, attempt: attempt, mappedCount: newResults.count)
            } catch is CancellationError {
                self.originalPageLedger.fail(attempt, cancelled: true)
                return
            } catch {
                guard self.backendSearchGeneration == generation else { return }
                self.originalPageLedger.fail(attempt, cancelled: false)
                self.backendPaginationErrorMessage = error.localizedDescription
                #if DEBUG
                print("Error loading next page: \(error)")
                #endif
            }
            self.isLoadingMoreBackendResults = false
        }
        loadMoreBackendWork.withLock { $0 = task }
    }

    /// Observe only the existing committed pagination and original source
    /// evidence. Missing API evidence is not promoted to a completeness claim.
    private func recordOriginalBackendPage(
        _ page: LibrarySearchPage,
        attempt: OriginalSearchPageLedger.Attempt?,
        mappedCount: Int
    ) {
        let sourceEvidence: Data?
        if let evidence = page.sourceEvidence {
            guard let encoded = OriginalSearchPageLedger.encodeEvidence(evidence) else {
                if let attempt, originalPageLedger.snapshot.active == attempt {
                    originalPageLedger.observationFailed(generation: attempt.generation)
                }
                return
            }
            sourceEvidence = encoded
        } else {
            sourceEvidence = nil
        }
        originalPageLedger.accept(
            attempt, rawCount: page.sourceEvidence?.rawHitCount ?? page.hits.count,
            mappedCount: mappedCount, consumedAfter: paginationState.loadedCount,
            cursorAfter: paginationState.nextOffset, hasMore: paginationState.hasMore,
            rawNextOffset: page.nextOffset, sourceEvidence: sourceEvidence
        )
    }

    // MARK: - Search Execution

    func setSelectedBooks(_ bookIds: Set<Int>) {
        selectedBookIds = bookIds
    }

    func startSearch() async {
        if query.isEmpty { return }

        let enginePaused = await searchEngine.currentlyPaused()
        if enginePaused || isPaused {
            await searchEngine.resume()
            isPaused = false
            return
        }

        let engineRunning = await searchEngine.isRunning()
        if engineRunning || isSearching {
            await searchEngine.pause()
            isPaused = true
            return
        }

        isSearching = true
        backendPaginationErrorMessage = nil
        isPaused = false
        cancelCompletionDismiss()

        results = []
        SearchHitResolver.shared.clearCache()
        totalTables = 0
        completedTables = 0
        completedRowsInTable = 0
        totalRowsInTable = 0

        if MaktabahBackendAdapter.usesGenericModels {
            let requestQuery = query
            let selectedBooks = selectedBookIds.compactMap { ldm.booksById[$0] }
            let scopedBooks = selectedBooks.filter { $0.backendLocator != nil }
            let scopeWorkKeys = scopedBooks.compactMap(\.backendLocator?.workKey)
            let candidateFilters = scopedBooks.compactMap(\.backendSearchPath).filter { !$0.isEmpty }
            let backendFilters = candidateFilters.count == scopedBooks.count ? candidateFilters : []
            let options = effectiveBackendSearchOptions()

            backendSearchGeneration &+= 1
            let generation = backendSearchGeneration
            originalPageLedger.invalidate(generation: generation)
            let request = LibrarySearchRequest(
                query: requestQuery, offset: 0, limit: backendPageSize,
                filters: backendFilters, scopeWorkKeys: scopeWorkKeys, options: options
            )
            let attempt = originalPageLedger.begin(
                generation: generation,
                request: .encode(request, configuration: request, offset: request.offset, limit: request.limit),
                replacing: true, consumedBefore: paginationState.loadedCount, cursorBefore: paginationState.nextOffset
            )

            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let page = try await BackendCoordinator.shared.search(request)
                    try Task.checkCancellation()
                    guard self.backendSearchGeneration == generation else { return }

                    results = page.hits.map(MaktabahBackendAdapter.searchItem)
                    paginationState.applyInitialPage(pageTotal: page.total, nextOffset: page.nextOffset, count: results.count)
                    totalTables = max(paginationState.totalResults, 1)
                    completedTables = results.count
                    recordOriginalBackendPage(page, attempt: attempt, mappedCount: results.count)
                    isSearching = false
                    #if os(macOS)
                    searchDidComplete.send()
                    #endif
                } catch is CancellationError {
                    originalPageLedger.fail(attempt, cancelled: true)
                    if self.backendSearchGeneration == generation {
                        isSearching = false
                    }
                } catch LibraryBackendError.staleRequest {
                    originalPageLedger.fail(attempt, cancelled: false)
                    if self.backendSearchGeneration == generation {
                        results = []
                        isSearching = false
                    }
                } catch {
                    originalPageLedger.fail(attempt, cancelled: false)
                    if self.backendSearchGeneration == generation {
                        isSearching = false
                        state = .error(error.localizedDescription)
                    }
                }
                if self.backendSearchGeneration == generation {
                    searchWork.withLock { $0 = nil }
                }
            }
            searchWork.withLock { $0 = task }
            await task.value
            return
        }

        // The legacy table scanner has no generic-backend page commitment.
        originalPageLedger.invalidate(generation: backendSearchGeneration)
        let tablesToScan = resolveTablesToScan()
        if tablesToScan.isEmpty {
            stopSearch(); return
        }

        let task = Task.detached(priority: .userInitiated) { [weak self, tablesToScan] in
            guard let self else { return }

            let searchParams = await LibrarySearchParams(
                tableToScan: tablesToScan,
                searchEngine: searchEngine,
                query: query.replacing("،", with: ","),
                mode: searchMode,
                nearDistance: nearDistance
            )
            let searchCallbacks = await makeLibrarySearchCallbacks()

            await ldm.performSearch(
                params: searchParams,
                callbacks: searchCallbacks
            )
        }

        searchWork.withLock { $0 = task }
    }

    func handleSearchCompletion() {
        emitComplete()
        var delay: Double = 0.5
        #if os(macOS)
        delay = 1
        #endif

        let dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, isSearching else { return }
            stopSearch()
            #if os(macOS)
            searchDidComplete.send()
            #endif
        }
        completionDismissTask.withLock { $0 = dismissTask }
    }

    func stopSearch() {
        cancelCompletionDismiss()
        Task { [searchEngine] in
            await searchEngine.stop()
        }
        clearSearchWork()
        loadMoreBackendWork.withLock {
            $0?.cancel()
            $0 = nil
        }
        backendSearchGeneration &+= 1
        originalPageLedger.invalidate(generation: backendSearchGeneration)
        isSearching = false
        isLoadingMoreBackendResults = false
        isPaused = false
    }

    func clearResults() {
        stopSearch()
        results.removeAll()
        SearchHitResolver.shared.clearCache()
        paginationState.reset()
        #if os(iOS)
        resultKitabFilter = ""
        #endif
    }

    func sortResults(by key: SearchSortKey, ascending: Bool) {
        SearchResultsSorter.sort(&results, by: key, ascending: ascending)
    }

    // MARK: - Helpers

    func resolveTablesToScan() -> Set<String> {
        if !selectedBookIds.isEmpty {
            return Set(selectedBookIds.map { "b\($0)" })
        }
        #if os(iOS)
        return ldm.getCheckedTables(displayedCategories)
        #else
        if !targetBookId.isEmpty {
            return [targetBookId]
        }
        return []
        #endif
    }

    func makeLibrarySearchCallbacks() -> LibrarySearchCallbacks {
        LibrarySearchCallbacks(
            onInitialize: { [weak self] total in self?.emitInitialize(total: total) },
            onTableProgress: { [weak self] completed in self?.emitTableProgress(completed: completed) },
            onRowProgress: { [weak self] _, tableName, current, total in
                self?.emitRowProgress(tableName: tableName, current: current, total: total)
            },
            completion: { [weak self] items in self?.emitResults(items: items) },
            onComplete: { [weak self] in self?.handleSearchCompletion() }
        )
    }

    // MARK: - Emits

    func emitInitialize(total: Int) {
        totalTables = total
        completedTables = 0
        #if os(macOS)
        searchDidInitialize.send(total)
        #endif
    }

    func emitTableProgress(completed: Int) {
        completedTables = completed
        #if os(macOS)
        searchProgressDidUpdate.send((completed: completed, totalTables))
        #endif
    }

    func emitRowProgress(tableName: String, current: Int, total: Int) {
        currentTable = tableName
        completedRowsInTable = current
        totalRowsInTable = total
        #if os(macOS)
        rowProgressDidUpdate.send((completed: current, total: total))
        #endif
    }

    func emitResults(items: [SearchResultItem]) {
        guard isSearching, !items.isEmpty else { return }
        results.append(contentsOf: items)
        #if os(macOS)
        searchDidReceiveResult.send()
        #endif
    }

    func emitComplete() {
        completedTables = totalTables
        if totalRowsInTable > 0 {
            completedRowsInTable = totalRowsInTable
        }
        #if os(macOS)
        searchProgressDidUpdate.send((completed: totalTables, total: totalTables))
        #endif
    }
}
