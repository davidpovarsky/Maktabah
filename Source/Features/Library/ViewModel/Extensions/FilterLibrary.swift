//
//  FilterLibrary.swift
//  Maktabah
//

import Foundation

extension LibraryViewModel {
    // MARK: - Filtering

    func applyFilter(_ mode: LibraryFilterMode) {
        filterMode = mode
        var filtered: [CategoryData] = []

        switch mode {
        case .all:
            showOnlyDownloaded = false
            isFlatMode = false
            filtered = dataManager.allRootCategories

        case .downloaded:
            showOnlyDownloaded = true
            isFlatMode = false
            filtered = downloadedCategories(from: dataManager.allRootCategories)

        case .favorites:
            showOnlyDownloaded = false
            isFlatMode = true
            let favBooks = historyManager.favoriteBooks
            let cat = CategoryData(id: -1, name: String(localized: .Library.favorites), level: 1, order: 0)
            cat.children = favBooks
            filtered = favBooks.isEmpty ? [] : [cat]

        case .history:
            showOnlyDownloaded = false
            isFlatMode = true
            let histBooks = historyManager.historyBooks
            let cat = CategoryData(id: -2, name: String(localized: .Library.history), level: 1, order: 0)
            cat.children = histBooks
            filtered = histBooks.isEmpty ? [] : [cat]
        }

        setBaseCategories(filtered, reload: true)
        resetAuthorPagination()
        updateDisplayedCategories()
    }

    func applyDownloadFilter(forSegmentIndex index: Int) {
        guard let mode = LibraryFilterMode(rawValue: index) else { return }
        applyFilter(mode)
    }

    func performSearch(_ query: String) {
        if searchQuery != query {
            searchQuery = query
        }
        resetAuthorPagination()
        updateDisplayedCategories()
    }

    func updateDisplayedCategories() {
        var base = resolveBaseCategories()

        if showOnlyDownloaded, !isFlatMode {
            base = downloadedCategories(from: base)
        }

        applySearchFilter(base: base)
        finalizeDisplayedCategories()

        #if os(iOS)
        updateTrigger += 1
        #else
        updateSubject.send(.reloadData)
        if !searchQuery.isEmpty, !isFlatMode {
            updateSubject.send(.expandItem(nil))
        }
        #endif
    }

    private func resolveBaseCategories() -> [CategoryData] {
        if isFlatMode {
            return baseCategories
        }
        if viewMode == .author {
            if !_hasBuiltAuthorHierarchy {
                _authorHierarchy = dataManager.buildAuthorHierarchy()
                _hasBuiltAuthorHierarchy = true
            }
            return _authorHierarchy
        }
        return baseCategories
    }

    private func applySearchFilter(base: [CategoryData]) {
        if searchQuery.isEmpty {
            _cachedDisplayedCategories = showOnlyDownloaded ? base : (isFlatMode ? baseCategories : base)
        } else {
            if viewMode == .author, !isFlatMode {
                _allFilteredAuthors = dataManager.filterAuthorHierarchy(base, searchText: searchQuery)
                _cachedDisplayedCategories = []
            } else {
                var filtered: [CategoryData] = []
                _ = dataManager.filterContent(
                    with: searchQuery,
                    displayedCategories: &filtered,
                    baseCategories: base
                )
                _cachedDisplayedCategories = filtered
            }
        }
    }

    private func finalizeDisplayedCategories() {
        if viewMode == .author, !isFlatMode {
            if !searchQuery.isEmpty {
                displayedCategories = Array(_allFilteredAuthors.prefix(_displayedFilteredCount))
            } else if showOnlyDownloaded {
                displayedCategories = Array(_cachedDisplayedCategories.prefix(_displayedAuthorCount))
            } else {
                displayedCategories = Array(_authorHierarchy.prefix(_displayedAuthorCount))
            }
        } else {
            displayedCategories = _cachedDisplayedCategories
        }
    }
    private func downloadedCategories(from roots: [CategoryData]) -> [CategoryData] {
        if !LibraryOfflineAvailabilityController.shared.supportsWorkOfflineManagement {
            return dataManager.filterIntegrated(base: roots)
        }
        func prune(_ category: CategoryData) -> CategoryData? {
            let copy = CategoryData(
                id: category.id,
                name: category.name,
                level: category.level,
                order: category.order,
                parentId: category.parentId
            )
            copy.isChecked = category.isChecked
            copy.children = category.children.compactMap { child in
                if let book = child as? BooksData { return isBookDownloaded(book) ? book : nil }
                if let nested = child as? CategoryData { return prune(nested) }
                return nil
            }
            return copy.children.isEmpty ? nil : copy
        }
        return roots.compactMap(prune)
    }
}
