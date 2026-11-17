import Foundation

/// Generic facade over the existing, lock-protected Otzaria bridge. It intentionally
/// leaves Maktabah's established Otzaria presentation path in place.
struct OtzariaGenericBackendAdapter: LibraryCatalogProviding, LibraryTextProviding,
    LibrarySearchProviding, LibraryNavigationProviding, LibraryAuthorsProviding,
    LibraryWorkMetadataProviding, @unchecked Sendable {

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
        #if DEBUG
        let debugPositionKind: String
        switch locator.position {
        case .legacyLine: debugPositionKind = "legacyLine"
        case .canonicalRef: debugPositionKind = "canonicalRef"
        }
        let debugWorkKeyKind: String = locator.workKey.hasPrefix("book:")
            ? "bookPrefix"
            : (Int(locator.workKey) != nil ? "numeric" : "stableKey")
        Self.debugLog("stage=enter backend=\(locator.backend.rawValue) positionKind=\(debugPositionKind) workKeyKind=\(debugWorkKeyKind)")
        #endif
        let backgroundTask = Task.detached(priority: .userInitiated) { () -> (section: LibraryTextSection, generation: UInt64, mode: OtzariaUnitMode) in
            do {
                try Task.checkCancellation()
                guard locator.backend == .otzaria,
                      case .legacyLine(let line) = locator.position, line >= 0 else {
                    #if DEBUG
                    Self.debugLog("stage=reject_locator errorCategory=invalidLocator backend=\(locator.backend.rawValue) positionKind=\(debugPositionKind)")
                    #endif
                    throw LibraryBackendError.invalidLocator
                }
                let bridge = OtzariaMaktabahBridge.shared
                let generation = try bridge.withDatabase { _ in bridge.generationSnapshot() }
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
                guard let bookID, bookID > 0 else {
                    #if DEBUG
                    Self.debugLog("stage=reject_book_id errorCategory=invalidLocator workKeyKind=\(debugWorkKeyKind) lineIndex=\(line)")
                    #endif
                    throw LibraryBackendError.invalidLocator
                }

                let mode = OtzariaMaktabahBridge.shared.currentReadingUnitMode
                // The legacy optional bridge methods log and erase SQL/decode errors.
                // Preserve those errors here so a failed chapter cannot appear as a
                // successful single-row fallback or as the last navigation unit.
                let loaded = try bridge.withCachedReadingUnit { service in
                    try line == 0
                        ? service.firstReadingUnit(bookId: bookID, mode: mode)
                        : service.readingUnit(bookId: bookID, containingLineIndex: line, mode: mode)
                }
                if let unit = loaded {
                    let adjacent = bridge.withReadingUnitService { service in
                        Result {
                            (try service.previousDescriptor(bookId: bookID, beforeLineIndex: unit.startLineIndex, mode: mode),
                             try service.nextDescriptor(bookId: bookID, afterLineIndex: unit.endLineIndex, mode: mode))
                        }
                    }
                    guard let adjacent else {
                        #if DEBUG
                        Self.debugLog("stage=adjacent_stale errorCategory=cancellation bookId=\(bookID) lineIndex=\(line)")
                        #endif
                        throw CancellationError()
                    }
                    let (previous, next) = try adjacent.get()
                    try Task.checkCancellation()
                    guard generation == bridge.generationSnapshot(), mode == bridge.currentReadingUnitMode else {
                        #if DEBUG
                        Self.debugLog("stage=unit_fence_stale errorCategory=cancellation bookId=\(bookID) lineIndex=\(line)")
                        #endif
                        throw CancellationError()
                    }
                    #if DEBUG
                    Self.debugLog("stage=unit_hit bookId=\(bookID) lineIndex=\(line) mode=\(mode.storageValue)")
                    #endif
                    return (OtzariaInspectorDocumentMapper.section(from: unit, previous: previous, next: next), generation, mode)
                }

                #if DEBUG
                Self.debugLog("stage=unit_nil bookId=\(bookID) lineIndex=\(line) mode=\(mode.storageValue) cancelled=\(Task.isCancelled) genMatch=\(generation == bridge.generationSnapshot())")
                #endif
                try Task.checkCancellation()
                guard generation == bridge.generationSnapshot() else { throw CancellationError() }
                let content = line == 0
                    ? OtzariaMaktabahBridge.shared.getFirstContent(bookId: bookID)
                    : OtzariaMaktabahBridge.shared.getContent(bookId: bookID, contentId: line)
                guard let content else {
                    #if DEBUG
                    Self.debugLog("stage=fallback_nil errorCategory=invalidLocator bookId=\(bookID) lineIndex=\(line) mode=\(mode.storageValue)")
                    #endif
                    throw LibraryBackendError.invalidLocator
                }
                let current = TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine(content.id))
                let previous = OtzariaMaktabahBridge.shared.getPreviousContent(bookId: bookID, before: content.id)
                let next = OtzariaMaktabahBridge.shared.getNextContent(bookId: bookID, after: content.id)
                // Newlines inside a SQLite row are not additional SQLite line IDs.
                let segments = [LibraryTextSegment(locator: current, heRef: content.heRef, primaryText: content.nash, translation: nil)]
                try Task.checkCancellation()
                guard generation == bridge.generationSnapshot(), mode == bridge.currentReadingUnitMode else {
                    #if DEBUG
                    Self.debugLog("stage=fallback_fence_stale errorCategory=cancellation bookId=\(bookID) lineIndex=\(line)")
                    #endif
                    throw CancellationError()
                }
                #if DEBUG
                Self.debugLog("stage=fallback_hit bookId=\(bookID) lineIndex=\(line)")
                #endif
                return (LibraryTextSection(locator: current, displayRef: content.heRef ?? "\(content.id)",
                    heRef: content.heRef,
                    segments: segments,
                    previous: previous.map { TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine($0.id)) },
                    next: next.map { TextLocator(backend: .otzaria, workKey: locator.workKey, position: .legacyLine($0.id)) },
                    versions: [], links: [], origin: .offline), generation, mode)
            } catch {
                #if DEBUG
                Self.debugLog("stage=background_error errorCategory=\(Self.debugErrorCategory(error))")
                #endif
                throw error
            }
        }

        let result = try await withTaskCancellationHandler(
            operation: { try await backgroundTask.value },
            onCancel: { backgroundTask.cancel() }
        )
        try Task.checkCancellation()
        let bridge = OtzariaMaktabahBridge.shared
        guard result.generation == bridge.generationSnapshot(), result.mode == bridge.currentReadingUnitMode else {
            #if DEBUG
            Self.debugLog("stage=outer_fence_stale errorCategory=cancellation")
            #endif
            throw CancellationError()
        }
        return result.section
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    #if os(iOS) && DEBUG
    private static func debugLog(_ message: String) {
        OtzariaFileLogger.shared.log("[OtzariaGenericBackendAdapter] \(message)")
    }

    private static func debugErrorCategory(_ error: Error) -> String {
        if error is CancellationError { return "cancellation" }
        if let backendError = error as? LibraryBackendError {
            switch backendError {
            case .invalidLocator: return "invalidLocator"
            case .staleRequest: return "staleRequest"
            case .capabilityUnavailable: return "capabilityUnavailable"
            case .unavailableOffline: return "unavailableOffline"
            case .unsupportedSchema: return "unsupportedSchema"
            case .invalidResponse: return "invalidResponse"
            case .httpStatus: return "httpStatus"
            case .corruptData: return "corruptData"
            case .insufficientDiskSpace: return "insufficientDiskSpace"
            }
        }
        if let readingUnitError = error as? OtzariaReadingUnitError {
            switch readingUnitError {
            case .inconsistentSourceLines: return "inconsistentSourceLines"
            }
        }
        let nsError = error as NSError
        return "nsError:\(nsError.domain):\(nsError.code)"
    }
    #endif

    func normalizedLocator(for input: String) async throws -> TextLocator {
        let pieces = input.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let first = pieces.first, let bookID = Int(first), bookID > 0 else { throw LibraryBackendError.invalidLocator }
        let line: Int
        if pieces.count == 2 {
            guard let parsed = Int(pieces[1]), parsed >= 0 else { throw LibraryBackendError.invalidLocator }
            line = parsed
        } else {
            line = 0
        }
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

    static func resolveBookIds(from filters: [String]) -> Set<Int> {
        var ids = Set<Int>()
        for filter in filters {
            let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("book:"), let id = Int(trimmed.dropFirst("book:".count)), id > 0 {
                ids.insert(id)
            } else if trimmed.hasPrefix("otzaria:"), let id = Int(trimmed.dropFirst("otzaria:".count)), id > 0 {
                ids.insert(id)
            } else if trimmed.hasPrefix("b"), let id = Int(trimmed.dropFirst(1)), id > 0 {
                ids.insert(id)
            } else if let id = Int(trimmed), id > 0 {
                ids.insert(id)
            } else {
                #if os(iOS)
                if let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: trimmed, expectedBookId: 0) {
                    ids.insert(resolved.id)
                }
                #endif
            }
        }
        return ids
    }

    func search(_ request: LibrarySearchRequest) async throws -> LibrarySearchPage {
        #if os(iOS)
        let selectedBookIds: Set<Int>?
        if request.filters.isEmpty {
            selectedBookIds = nil
        } else {
            let resolved = Self.resolveBookIds(from: request.filters)
            if resolved.isEmpty {
                return .init(hits: [], total: 0, nextOffset: nil)
            }
            selectedBookIds = resolved
        }

        if let databasePath = OtzariaMaktabahBridge.shared.databasePath {
            let indexURL = OtzariaSearchIndexManager.shared.indexURL(for: databasePath)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                let sortedBookIDs = selectedBookIds?.sorted()
                let facets = sortedBookIDs?.map { "/book/\($0)" } ?? ["/"]
                let mode: OtzariaSearchMode = request.options.matchMode == .exact
                    ? .exact
                    : .advanced
                let order: OtzariaSearchOrder = request.options.sortOrder == .canonical
                    ? .catalogue
                    : .relevance
                let page = try OtzariaTantivySearchRepository.shared.search(
                    databasePath: databasePath,
                    request: OtzariaSearchRequest(
                        query: request.query,
                        mode: mode,
                        facets: facets,
                        limit: request.limit,
                        offset: request.offset,
                        order: order,
                        distance: request.options.searchMode == .near
                            ? max(1, request.options.wordDistance)
                            : 0,
                        wordMatchMode: request.options.searchMode == .or ? .anyWord : .all,
                        bookIds: sortedBookIDs
                    )
                )
                let items = OtzariaTantivySearchRepository.shared.navigationItems(from: page)
                let hits = items.map { item in
                    LibrarySearchHit(
                        locator: TextLocator(
                            backend: .otzaria,
                            workKey: "book:\(item.bookId)",
                            position: .legacyLine(item.page)
                        ),
                        displayRef: item.locationDisplayText ?? item.bookTitle,
                        heRef: item.locationDisplayText,
                        snippet: item.attributedText.string,
                        score: nil
                    )
                }
                let consumed = request.offset + hits.count
                let total = Int(page.totalCount)
                return .init(
                    hits: hits,
                    total: total,
                    nextOffset: page.truncated || consumed < total ? consumed : nil
                )
            }
        }

        let mode: SearchMode = switch request.options.searchMode {
        case .phrase: .phrase
        case .contains: .contains
        case .or: .or
        case .near: .near
        }

        let fetchLimit = request.limit + 1
        let results = OtzariaMaktabahBridge.shared.search(
            query: request.query,
            selectedBookIds: selectedBookIds,
            offset: request.offset,
            limit: fetchLimit,
            mode: mode,
            nearDistance: max(1, request.options.wordDistance)
        )
        let hasMore = results.count > request.limit
        let hitsSlice = hasMore ? Array(results.prefix(request.limit)) : results
        let hits = hitsSlice.map { item -> LibrarySearchHit in
            let locator = TextLocator(backend: .otzaria, workKey: "book:\(item.bookId)", position: .legacyLine(item.page))
            return .init(locator: locator, displayRef: item.bookTitle, heRef: nil,
                snippet: item.attributedText.string, score: nil)
        }
        let nextOffset = hasMore ? request.offset + hits.count : nil
        let total = hasMore
            ? max(request.offset + results.count + 1, request.offset + hits.count + 1)
            : request.offset + results.count
        return .init(hits: hits, total: total, nextOffset: nextOffset)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }

    func workMetadata(for workKey: String) async throws -> LibraryWorkMetadata? {
        #if os(iOS)
        let bookID: Int?
        if workKey.hasPrefix("book:"),
           let parsed = Int(workKey.dropFirst("book:".count)) {
            bookID = parsed
        } else if let parsed = Int(workKey) {
            bookID = parsed
        } else if let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(stableKey: workKey, expectedBookId: 0) {
            bookID = resolved.id
        } else {
            bookID = nil
        }
        guard let bookID else { return nil }
        return OtzariaMaktabahBridge.shared.workMetadata(for: bookID)
        #else
        throw LibraryBackendError.capabilityUnavailable
        #endif
    }
}
