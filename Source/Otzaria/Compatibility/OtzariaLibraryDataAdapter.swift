import Foundation

enum OtzariaLibraryDataAdapter {
    static var isEnabled: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    static func buildCategoryHierarchy(from allCategories: [CategoryData]) -> (
        rootCats: [CategoryData], categoryMap: [Int: CategoryData]
    ) {
        var localCategoryMap: [Int: CategoryData] = [:]
        var localRootCats: [CategoryData] = []
        let sortedCategories = allCategories.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        for category in sortedCategories {
            category.children.removeAll()
            localCategoryMap[category.id] = category
        }

        for category in sortedCategories {
            if let parentId = category.parentId,
               let parent = localCategoryMap[parentId],
               parent.id != category.id {
                parent.children.append(category)
            } else {
                localRootCats.append(category)
            }
        }

        return (localRootCats, localCategoryMap)
    }

    static func sortedBooksForCategory(_ books: [BooksData]) -> [BooksData] {
        books.sorted {
            switch ($0.orderIndex, $1.orderIndex) {
            case let (lhs?, rhs?) where lhs != rhs:
                return lhs < rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return $0.book.localizedStandardCompare($1.book) == .orderedAscending
            }
        }
    }

    static func emptyArchiveStateIfEnabled() -> (archives: [Int: ArchiveInfo], builtFromFullData: Bool)? {
        guard isEnabled else { return nil }
        return ([:], true)
    }

    static func performSearchIfEnabled(
        tableToScan: Set<String>,
        query: String,
        mode: SearchMode,
        onInitialize: @escaping @MainActor (Int) -> Void,
        onTableProgress: @escaping @MainActor (Int) -> Void,
        onRowProgress: @escaping @MainActor (String, String, Int, Int) -> Void,
        completion: @escaping @MainActor (SearchResultItem) -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) async -> Bool {
        guard isEnabled else { return false }

        let selectedIds: Set<Int>? = tableToScan.isEmpty
            ? nil
            : Set(tableToScan.compactMap { tableName in
                if tableName.hasPrefix("otzaria:") {
                    return Int(tableName.dropFirst("otzaria:".count))
                }
                if tableName.hasPrefix("b") {
                    return Int(tableName.dropFirst())
                }
                return Int(tableName)
            })

        let results = OtzariaMaktabahBridge.shared.search(
            query: query,
            selectedBookIds: selectedIds,
            limit: nil,
            mode: mode
        )

        await MainActor.run {
            onInitialize(max(results.count, 1))
            for (index, item) in results.enumerated() {
                onTableProgress(index + 1)
                onRowProgress("Otzaria", item.tableName, index + 1, results.count)
                completion(item)
            }
            onComplete()
        }
        return true
    }

    static func buildAuthorHierarchyIfEnabled(
        authors: [(id: Int, muallif: Muallif)],
        allBooks: [BooksData]
    ) -> [CategoryData]? {
        guard isEnabled else { return nil }

        var booksByAuthor: [Int: [BooksData]] = [:]
        var booksWithNoAuthor: [BooksData] = []

        for book in allBooks {
            if book.muallif == 0 {
                booksWithNoAuthor.append(book)
            } else {
                booksByAuthor[book.muallif, default: []].append(book)
            }
        }

        var authorCategories: [CategoryData] = authors.compactMap { author in
            guard let books = booksByAuthor[author.id], !books.isEmpty else { return nil }
            let category = CategoryData(id: author.id, name: author.muallif.nama, level: 0, order: author.id)
            category.children = books.sorted { $0.book.localizedStandardCompare($1.book) == .orderedAscending }
            return category
        }

        if !booksWithNoAuthor.isEmpty {
            let noAuthorCategory = CategoryData(id: 0, name: "---", level: 0, order: Int.max)
            noAuthorCategory.children = booksWithNoAuthor.sorted { $0.book.localizedStandardCompare($1.book) == .orderedAscending }
            authorCategories.append(noAuthorCategory)
        }

        return authorCategories.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func filterNotIntegratedIfEnabled() -> [CategoryData]? {
        guard isEnabled else { return nil }
        return []
    }

    static func filterIntegratedIfEnabled(base rootCats: [CategoryData]) -> [CategoryData]? {
        guard isEnabled else { return nil }
        return rootCats
    }
}
