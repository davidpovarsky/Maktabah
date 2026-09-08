import Foundation

@MainActor
enum MaktabahBackendAdapter {
    nonisolated static var usesGenericModels: Bool {
        let selected = UserDefaults.standard.string(forKey: BackendCoordinator.selectionDefaultsKey)
            .flatMap(BackendID.init(rawValue:)) ?? .otzaria
        return selected == .sefaria
    }

    static func loadLibraryIfNeeded() async throws -> (roots: [CategoryData], books: [Int: BooksData])? {
        guard usesGenericModels else { return nil }
        let nodes = try await BackendCoordinator.shared.catalog()
        var books: [Int: BooksData] = [:]

        func convert(_ node: LibraryCatalogNode, level: Int, parentID: Int?) -> Any {
            if let work = node.work {
                let id = LegacyIdentityRegistry.shared.id(for: work.locator)
                let book = BooksData(id: id, book: work.heTitle ?? work.title, archive: 0, muallif: 0,
                    bithoqoh: work.description ?? "", info: work.title)
                book.backendLocator = work.locator
                book.catId = parentID
                book.pdfCs = 4
                books[id] = book
                return book
            }
            let categoryLocator = TextLocator(backend: BackendCoordinator.shared.activeBackendID,
                workKey: "category:\(node.id)", position: .legacyLine(0))
            let id = LegacyIdentityRegistry.shared.id(for: categoryLocator)
            let category = CategoryData(id: id, name: node.heTitle ?? node.title, level: level, order: 0, parentId: parentID)
            category.children = node.children.map { convert($0, level: level + 1, parentID: id) }
            return category
        }
        let roots = nodes.compactMap { convert($0, level: 1, parentID: nil) as? CategoryData }
        return (roots, books)
    }

    static func content(from section: LibraryTextSection) -> BookContent {
        let text = section.segments.map { segment in
            if let translation = segment.translation, !translation.isEmpty {
                return segment.primaryText + "\n" + translation
            }
            return segment.primaryText
        }.joined(separator: "\n\n")
        let id = LegacyIdentityRegistry.shared.id(for: section.locator)
        return BookContent(id: id, nash: text, page: 1, part: 1,
            heRef: section.heRef ?? section.displayRef, backendLocator: section.locator)
    }

    static func searchItem(from hit: LibrarySearchHit) -> SearchResultItem {
        let workLocator = TextLocator(backend: hit.locator.backend, workKey: hit.locator.workKey,
            position: hit.locator.backend == .sefaria ? .canonicalRef(hit.locator.workKey) : .legacyLine(0))
        let id = LegacyIdentityRegistry.shared.id(for: workLocator)
        let resultID = LegacyIdentityRegistry.shared.id(for: hit.locator)
        return SearchResultItem(archive: hit.locator.backend.displayName,
            tableName: "qualified:\(id)", bookId: resultID, bookTitle: hit.heRef ?? hit.displayRef,
            page: 1, part: 1, attributedText: NSAttributedString(string: hit.snippet),
            backendLocator: hit.locator)
    }

    static func resolveBook(for locator: TextLocator, in manager: LibraryDataManager) -> BooksData? {
        let workLocator = TextLocator(backend: locator.backend, workKey: locator.workKey,
            position: locator.backend == .sefaria ? .canonicalRef(locator.workKey) : .legacyLine(0))
        guard let original = manager.getBook([LegacyIdentityRegistry.shared.id(for: workLocator)]).first else { return nil }
        let copy = BooksData(id: original.id, book: original.book, archive: original.archive,
            muallif: original.muallif, bithoqoh: original.bithoqoh, info: original.info,
            backendLocator: locator)
        copy.catId = original.catId
        copy.pdfCs = original.pdfCs
        copy.orderIndex = original.orderIndex
        copy.totalLines = original.totalLines
        return copy
    }
}
