import Foundation

/// Generic facade over the existing, lock-protected Otzaria bridge. It intentionally
/// leaves Maktabah's established Otzaria presentation path in place.
struct OtzariaGenericBackendAdapter: LibraryCatalogProviding, LibraryTextProviding,
    LibrarySearchProviding, LibraryNavigationProviding, LibraryAuthorsProviding, @unchecked Sendable {

    func authors() async throws -> [LibraryAuthor] {
        #if os(iOS)
        return try OtzariaMaktabahBridge.shared.fetchAuthors().map {
            .init(id: "otzaria-author:\($0.id)", name: $0.muallif.nama,
                biography: $0.muallif.info.isEmpty ? nil : $0.muallif.info)
        }
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func catalog(forceRefresh: Bool) async throws -> [LibraryCatalogNode] {
        #if os(iOS)
        let categories = try OtzariaMaktabahBridge.shared.fetchCategories()
        let books = try OtzariaMaktabahBridge.shared.fetchAllBooks()
        var children: [Int?: [CategoryData]] = [:]
        categories.forEach { children[$0.parentId, default: []].append($0) }
        let groupedBooks = Dictionary(grouping: books, by: \BooksData.catId)

        func node(_ category: CategoryData) -> LibraryCatalogNode {
            let categoryChildren = (children[category.id] ?? []).map(node)
            let bookChildren = (groupedBooks[category.id] ?? []).map { book -> LibraryCatalogNode in
                let locator = TextLocator(backend: .otzaria, workKey: "book:\(book.id)", position: .legacyLine(0))
                let work = LibraryWork(locator: locator, title: book.book, heTitle: nil,
                    categories: [category.name], description: book.bithoqoh)
                return .init(id: locator.persistenceKey, kind: .work, title: book.book,
                    heTitle: nil, work: work, children: [])
            }
            return .init(id: "otzaria-category|\(category.id)", kind: .category,
                title: category.name, heTitle: nil, work: nil, children: categoryChildren + bookChildren)
        }
        return (children[nil] ?? []).map(node)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func section(at locator: TextLocator) async throws -> LibraryTextSection {
        #if os(iOS)
        guard locator.backend == .otzaria,
              let bookID = Int(locator.workKey.replacingOccurrences(of: "book:", with: "")),
              case .legacyLine(let line) = locator.position else { throw LibraryBackendError.invalidLocator }
        let content = line == 0
            ? OtzariaMaktabahBridge.shared.getFirstContent(bookId: bookID)
            : OtzariaMaktabahBridge.shared.getContent(bookId: bookID, contentId: line)
        guard let content else { throw LibraryBackendError.invalidLocator }
        let current = TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine(content.id))
        let previous = OtzariaMaktabahBridge.shared.getPreviousContent(bookId: bookID, before: content.id)
        let next = OtzariaMaktabahBridge.shared.getNextContent(bookId: bookID, after: content.id)
        return LibraryTextSection(locator: current, displayRef: content.heRef ?? "\(content.id)",
            heRef: content.heRef,
            segments: [.init(locator: current, heRef: content.heRef, primaryText: content.nash, translation: nil)],
            previous: previous.map { TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine($0.id)) },
            next: next.map { TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine($0.id)) },
            versions: [], links: [], origin: .offline)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let pieces = input.split(separator: "|", maxSplits: 1).map(String.init)
        guard let bookID = Int(pieces[0]) else { throw LibraryBackendError.invalidLocator }
        let line = pieces.count == 2 ? Int(pieces[1]) ?? 0 : 0
        return TextLocator(backend: .otzaria, workKey: "book:\(bookID)", position: .legacyLine(line))
    }

    func tableOfContents(for work: LibraryWork) async throws -> [LibraryTOCNode] {
        #if os(iOS)
        guard let id = Int(work.locator.workKey.replacingOccurrences(of: "book:", with: "")),
              let book = try OtzariaMaktabahBridge.shared.fetchBook(byId: id) else { return [] }
        return OtzariaMaktabahBridge.shared.getTOCEntries(for: book).map { entry in
            let locator = TextLocator(backend: .otzaria, workKey: work.locator.workKey,
                position: .legacyLine(entry.id))
            return LibraryTOCNode(locator: locator, title: entry.bab, children: [])
        }
        #else
        return []
        #endif
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        #if os(iOS)
        let results = OtzariaMaktabahBridge.shared.search(query: request.query, limit: request.offset + request.limit)
        let slice = results.dropFirst(min(request.offset, results.count)).prefix(request.limit)
        let hits = slice.map { item -> LibrarySearchHit in
            let locator = TextLocator(backend: .otzaria, workKey: "book:\(item.bookId)", position: .legacyLine(item.page))
            return .init(locator: locator, displayRef: item.bookTitle, heRef: nil,
                snippet: item.attributedText.string, score: nil)
        }
        return .init(hits: hits, total: results.count,
            nextOffset: request.offset + hits.count < results.count ? request.offset + hits.count : nil)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }
}
