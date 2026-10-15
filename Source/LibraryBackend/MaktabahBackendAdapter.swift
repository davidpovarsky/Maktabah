import Foundation

@MainActor
enum MaktabahBackendAdapter {
    /// Whether the active backend provides its own catalog/text path instead of
    /// Maktabah's native SQLite data.  Replaces the former ``usesGenericModels``
    /// which hard-coded ``selected == .sefaria``.
    nonisolated static var usesGenericModels: Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                !BackendCoordinator.shared.usesNativeMaktabahDataPath
            }
        } else {
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    !BackendCoordinator.shared.usesNativeMaktabahDataPath
                }
            }
        }
    }

    static func loadLibraryIfNeeded() async throws -> (roots: [CategoryData], books: [Int: BooksData])? {
        guard !BackendCoordinator.shared.usesNativeMaktabahDataPath else { return nil }
        let otzariaBooks: [BooksData]
        if (try? OtzariaMaktabahBridge.shared.restoreDatabaseIfPossible()) == true {
            otzariaBooks = (try? OtzariaMaktabahBridge.shared.fetchAllBooks()) ?? []
        } else {
            otzariaBooks = []
        }
        CrossBackendBookIdentityIndex.shared.prepare(
            otzariaBooks: otzariaBooks.map { (id: $0.id, title: $0.book) }
        )
        let nodes = try await BackendCoordinator.shared.catalog()
        let backendID = BackendCoordinator.shared.activeBackendID
        let catalogWorks = nodes.flatMap(Self.catalogWorks)
        CrossBackendBookIdentityIndex.shared.prepare(catalogWorks: catalogWorks)
        var books: [Int: BooksData] = [:]

        #if DEBUG
        for collision in LibraryCatalogIntegrityAudit.collisions(in: nodes) {
            let paths = collision.paths.map { $0.joined(separator: "/") }.joined(separator: " | ")
            print("Catalog identity collision [\(collision.kind.rawValue)] \(collision.identifier) \(collision.title): \(paths)")
        }
        #endif

        func convert(_ node: LibraryCatalogNode, level: Int, parentID: Int?) -> Any {
            if let work = node.work {
                let title = LibraryPresentationPolicy.workTitle(title: work.title, heTitle: work.heTitle)
                var id = CrossBackendBookIdentityIndex.shared.canonicalID(for: work)
                    ?? LegacyIdentityRegistry.shared.id(for: work.locator, title: title)
                if let existing = books[id], !Self.isSameCanonicalWork(existing, work) {
                    id = LegacyIdentityRegistry.shared.id(for: work.locator, title: title)
                }
                CrossBackendBookIdentityIndex.shared.register(work, canonicalID: id)
                let book = BooksData(id: id, book: title, archive: 0, muallif: 0,
                    bithoqoh: work.description ?? "", info: work.title)
                book.backendLocator = work.locator
                book.backendSearchPath = work.searchPath
                book.catId = parentID
                if books[id] == nil { books[id] = book }
                return book
            }
            let categoryLocator = TextLocator(backend: backendID,
                workKey: "category:\(node.id)", position: .legacyLine(0))
            let id = LegacyIdentityRegistry.shared.id(for: categoryLocator)
            let category = CategoryData(
                id: id,
                name: LibraryPresentationPolicy.categoryTitle(title: node.title, heTitle: node.heTitle),
                level: level,
                order: 0,
                parentId: parentID
            )
            category.children = node.children.map { convert($0, level: level + 1, parentID: id) }
            return category
        }
        let roots = nodes.compactMap { convert($0, level: 1, parentID: nil) as? CategoryData }
        return (roots, books)
    }

    private static func catalogWorks(_ node: LibraryCatalogNode) -> [LibraryWork] {
        (node.work.map { [$0] } ?? []) + node.children.flatMap(catalogWorks)
    }

    private static func isSameCanonicalWork(_ book: BooksData, _ work: LibraryWork) -> Bool {
        guard let locator = book.backendLocator else { return false }
        return locator.backend == work.locator.backend && locator.workKey == work.locator.workKey
    }

    static func renderModel(
        from section: LibraryTextSection,
        preferredMode: LibraryReaderTextMode
    ) -> LibraryReaderRenderModel {
        LibraryReaderRenderModel(section: section, preferredMode: preferredMode)
    }

    static func content(from section: LibraryTextSection, renderModel: LibraryReaderRenderModel) -> BookContent {
        let id = LegacyIdentityRegistry.shared.id(for: section.locator)
        let displayRef = renderModel.mode == .translation
            ? section.displayRef
            : (section.heRef ?? section.displayRef)
        return BookContent(id: id, nash: renderModel.text, page: 1, part: 1,
            heRef: displayRef, backendLocator: section.locator)
    }

    static func searchItem(from hit: LibrarySearchHit) -> SearchResultItem {
        let workPosition: TextPosition = switch hit.locator.position {
        case .canonicalRef: .canonicalRef(hit.locator.workKey)
        case .legacyLine:   .legacyLine(0)
        }
        let workLocator = TextLocator(backend: hit.locator.backend, workKey: hit.locator.workKey,
            position: workPosition)
        let id = CrossBackendBookIdentityIndex.shared.canonicalID(for: workLocator)
            ?? LegacyIdentityRegistry.shared.id(for: workLocator)
        let resultID = LegacyIdentityRegistry.shared.id(for: hit.locator)

        var bookTitle: String
        var locationDisplayText: String? = nil
        var page = 0
        var part = 0

        if hit.locator.backend == .sefaria {
            let engWork = hit.locator.workKey
            let engLocation: String? = if hit.displayRef.hasPrefix(engWork) {
                hit.displayRef.dropFirst(engWork.count).trimmingCharacters(in: .whitespaces)
            } else {
                nil
            }

            if LibraryPresentationPolicy.prefersHebrew(), let heRef = hit.heRef {
                if let registeredTitle = LegacyIdentityRegistry.shared.title(for: workLocator),
                   heRef.hasPrefix(registeredTitle) {
                    bookTitle = registeredTitle
                    let loc = heRef.dropFirst(registeredTitle.count).trimmingCharacters(in: .whitespaces)
                    locationDisplayText = loc.isEmpty ? engLocation : loc
                } else if let colonIndex = heRef.lastIndex(of: ":") {
                    let isTalmud = (engLocation?.contains("a") == true || engLocation?.contains("b") == true)
                    let prefixBeforeColon = heRef[..<colonIndex]
                    if let lastSpace = prefixBeforeColon.lastIndex(of: " ") {
                        let potentialTitleIndex: String.Index
                        if isTalmud {
                            let beforeLast = prefixBeforeColon[..<lastSpace]
                            potentialTitleIndex = beforeLast.lastIndex(of: " ") ?? lastSpace
                        } else {
                            potentialTitleIndex = lastSpace
                        }
                        let titleCandidate = String(heRef[..<potentialTitleIndex]).trimmingCharacters(in: .whitespaces)
                        let locCandidate = String(heRef[potentialTitleIndex...]).trimmingCharacters(in: .whitespaces)
                        if !titleCandidate.isEmpty {
                            bookTitle = titleCandidate
                            locationDisplayText = locCandidate
                        } else {
                            bookTitle = heRef
                            locationDisplayText = engLocation
                        }
                    } else {
                        bookTitle = heRef
                        locationDisplayText = engLocation
                    }
                } else {
                    bookTitle = heRef
                    locationDisplayText = engLocation
                }
            } else {
                bookTitle = engWork
                locationDisplayText = (engLocation?.isEmpty == false) ? engLocation : nil
            }
            page = 0
            part = 0
        } else {
            bookTitle = LibraryPresentationPolicy.prefersHebrew()
                ? (hit.heRef ?? hit.displayRef)
                : hit.displayRef
            page = 1
            part = 1
        }

        let (formattedSnippet, highlightTerms) = MaktabahSearchSnippetFormatter.formatSnippet(hit.snippet)

        return SearchResultItem(
            archive: hit.locator.backend.displayName,
            tableName: "qualified:\(id)",
            bookId: resultID,
            bookTitle: bookTitle,
            page: page,
            part: part,
            attributedText: formattedSnippet,
            backendLocator: hit.locator,
            locationDisplayText: locationDisplayText,
            highlightTerms: highlightTerms.isEmpty ? nil : highlightTerms,
            versionTitle: hit.versionTitle,
            resultLanguage: hit.language
        )
    }

    static func resolveBook(for locator: TextLocator, in manager: LibraryDataManager) -> BooksData? {
        if locator.backend == .otzaria {
            let numericId = locator.workKey.hasPrefix("book:")
                ? Int(locator.workKey.dropFirst("book:".count))
                : Int(locator.workKey)
            if let resolved = try? OtzariaMaktabahBridge.shared.resolveBook(
                stableKey: locator.workKey,
                expectedBookId: numericId ?? 0
            ) {
                let copy = BooksData(
                    id: resolved.id, book: resolved.book, archive: resolved.archive,
                    muallif: resolved.muallif, bithoqoh: resolved.bithoqoh, info: resolved.info,
                    backendLocator: locator, backendSearchPath: resolved.backendSearchPath
                )
                copy.catId = resolved.catId
                copy.pdfCs = resolved.pdfCs
                copy.orderIndex = resolved.orderIndex
                copy.totalLines = resolved.totalLines
                return copy
            }
            if let numericId, let direct = manager.getBook([numericId]).first {
                let copy = BooksData(
                    id: direct.id, book: direct.book, archive: direct.archive,
                    muallif: direct.muallif, bithoqoh: direct.bithoqoh, info: direct.info,
                    backendLocator: locator, backendSearchPath: direct.backendSearchPath
                )
                copy.catId = direct.catId
                copy.pdfCs = direct.pdfCs
                copy.orderIndex = direct.orderIndex
                copy.totalLines = direct.totalLines
                return copy
            }
        }
        let workPosition: TextPosition = switch locator.position {
        case .canonicalRef: .canonicalRef(locator.workKey)
        case .legacyLine:   .legacyLine(0)
        }
        let workLocator = TextLocator(backend: locator.backend, workKey: locator.workKey,
            position: workPosition)
        let id = CrossBackendBookIdentityIndex.shared.canonicalID(for: workLocator)
            ?? LegacyIdentityRegistry.shared.id(for: workLocator)
        if let original = manager.getBook([id]).first {
            let copy = BooksData(id: original.id, book: original.book, archive: original.archive,
                muallif: original.muallif, bithoqoh: original.bithoqoh, info: original.info,
                backendLocator: locator)
            copy.catId = original.catId
            copy.backendSearchPath = original.backendSearchPath
            copy.pdfCs = original.pdfCs
            copy.orderIndex = original.orderIndex
            copy.totalLines = original.totalLines
            return copy
        }
        // Cold catalog miss: Library catalog hasn't been loaded yet (e.g. user
        // went to Search before opening Library tab).  Synthesise a minimal
        // BooksData so the reader can still open the locator.
        let title = LegacyIdentityRegistry.shared.title(for: workLocator) ?? locator.workKey
        let synthetic = BooksData(id: id, book: title, archive: 0, muallif: 0,
            bithoqoh: "", info: locator.workKey, backendLocator: locator)
        return synthetic
    }
}
