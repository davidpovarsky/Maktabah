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
                let locator = book.backendLocator ?? TextLocator(backend: .otzaria, workKey: "book:\(book.id)", position: .legacyLine(0))
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
              case .legacyLine(let line) = locator.position else { throw LibraryBackendError.invalidLocator }
        let bookID: Int?
        if locator.workKey.hasPrefix("book:"),
           let parsed = Int(locator.workKey.dropFirst("book:".count)) {
            bookID = parsed
        } else if let parsed = Int(locator.workKey) {
            bookID = parsed
        } else if let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: locator.workKey, expectedBookId: 0) {
            bookID = resolved.id
        } else {
            bookID = nil
        }
        guard let bookID else { throw LibraryBackendError.invalidLocator }
        
        let mode = OtzariaMaktabahBridge.shared.currentReadingUnitMode
        if let unit = line == 0
            ? OtzariaMaktabahBridge.shared.getFirstReadingUnit(bookId: bookID, mode: mode)
            : OtzariaMaktabahBridge.shared.getReadingUnit(bookId: bookID, containingLineIndex: line, mode: mode) {
            let previous = OtzariaMaktabahBridge.shared.getPreviousReadingUnit(bookId: bookID, beforeLineIndex: unit.startLineIndex, mode: mode)
            let next = OtzariaMaktabahBridge.shared.getNextReadingUnit(bookId: bookID, afterLineIndex: unit.startLineIndex, mode: mode)
            return OtzariaInspectorDocumentMapper.section(from: unit, previous: previous, next: next)
        }
        
        let content = line == 0
            ? OtzariaMaktabahBridge.shared.getFirstContent(bookId: bookID)
            : OtzariaMaktabahBridge.shared.getContent(bookId: bookID, contentId: line)
        guard let content else { throw LibraryBackendError.invalidLocator }
        let current = TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine(content.id))
        let previous = OtzariaMaktabahBridge.shared.getPreviousContent(bookId: bookID, before: content.id)
        let next = OtzariaMaktabahBridge.shared.getNextContent(bookId: bookID, after: content.id)
        // Split into per-paragraph segments for granular selection when reading units are unavailable.
        let paragraphs = content.nash.components(separatedBy: "\n").enumerated().compactMap { offset, text -> LibraryTextSegment? in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let segLocator = TextLocator(backend: .otzaria, workKey: locator.workKey,
                position: .legacyLine(content.id + offset))
            return .init(locator: segLocator, heRef: content.heRef, primaryText: trimmed, translation: nil)
        }
        let segments = paragraphs.isEmpty
            ? [LibraryTextSegment(locator: current, heRef: content.heRef, primaryText: content.nash, translation: nil)]
            : paragraphs
        return LibraryTextSection(locator: current, displayRef: content.heRef ?? "\(content.id)",
            heRef: content.heRef,
            segments: segments,
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
        let bookID: Int?
        if work.locator.workKey.hasPrefix("book:"),
           let parsed = Int(work.locator.workKey.dropFirst("book:".count)) {
            bookID = parsed
        } else if let parsed = Int(work.locator.workKey) {
            bookID = parsed
        } else if let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: work.locator.workKey, expectedBookId: 0) {
            bookID = resolved.id
        } else {
            bookID = nil
        }
        guard let bookID,
              let book = try OtzariaMaktabahBridge.shared.fetchBook(byId: bookID) else { return [] }
        let entries = OtzariaMaktabahBridge.shared.getTOCEntries(for: book)
        let entryIds = Set(entries.map { $0.entryId })
        
        var childrenByParentId: [Int: [TOC]] = [:]
        var rootEntries: [TOC] = []
        
        for entry in entries {
            if let parentId = entry.parentId, entryIds.contains(parentId) {
                childrenByParentId[parentId, default: []].append(entry)
            } else {
                rootEntries.append(entry)
            }
        }
        
        func buildNode(for entry: TOC) -> LibraryTOCNode {
            let childEntries = childrenByParentId[entry.entryId] ?? []
            let children = childEntries.map { buildNode(for: $0) }
            let locator = TextLocator(backend: .otzaria, workKey: work.locator.workKey,
                position: .legacyLine(entry.id))
            return LibraryTOCNode(locator: locator, title: entry.bab, children: children)
        }
        
        return rootEntries.map { buildNode(for: $0) }
        #else
        return []
        #endif
    }

    func navigationItems(for work: LibraryWork) async throws -> [LibraryNavigationItem] {
        let toc = try await tableOfContents(for: work)
        var items: [LibraryNavigationItem] = []
        func collectLeaves(_ nodes: [LibraryTOCNode]) {
            for node in nodes {
                if node.children.isEmpty {
                    items.append(LibraryNavigationItem(
                        locator: node.locator,
                        title: node.title,
                        index: items.count
                    ))
                } else {
                    collectLeaves(node.children)
                }
            }
        }
        collectLeaves(toc)
        return items
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        #if os(iOS)
        let mode: SearchMode = switch request.options.searchMode {
        case .phrase: .phrase
        case .contains: .contains
        case .or: .or
        case .near: .near
        }
        let results = OtzariaMaktabahBridge.shared.search(
            query: request.query,
            limit: request.offset + request.limit,
            mode: mode,
            nearDistance: max(1, request.options.wordDistance)
        )
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
