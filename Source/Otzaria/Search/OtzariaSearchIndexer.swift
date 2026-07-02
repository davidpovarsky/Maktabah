import Foundation
import SQLite3

struct OtzariaSearchIndexProgress: Equatable, Sendable {
    let processedBooks: Int
    let totalBooks: Int
    let processedLines: Int
}

actor OtzariaSearchIndexingService {
    static let shared = OtzariaSearchIndexingService()

    private let indexer = OtzariaSearchIndexer()

    func rebuildIndex(
        databasePath: String,
        progress: @escaping @Sendable (OtzariaSearchIndexProgress) -> Void
    ) async throws -> UInt64 {
        try await indexer.rebuildIndex(databasePath: databasePath, progress: progress)
    }
}

final class OtzariaSearchIndexer: @unchecked Sendable {
    struct BookRow {
        let id: Int
        let title: String
        let categoryId: Int
        let totalLines: Int
        let orderIndex: Int
        let fileType: String
    }

    struct CategoryRow {
        let id: Int
        let parentId: Int?
        let title: String
        let orderIndex: Int
    }

    private let batchSize = 100
    private let commitEveryBooks = 1
    private let consecutiveBookFailureLimit = 10

    func rebuildIndex(
        databasePath: String,
        progress: @escaping @Sendable (OtzariaSearchIndexProgress) -> Void
    ) async throws -> UInt64 {
        let manager = OtzariaSearchIndexManager.shared
        let finalIndexURL = manager.indexURL(for: databasePath)
        let buildingURL = try manager.prepareBuildingIndex(databasePath: databasePath)

        otzariaIndexLog("index start databasePath=\(databasePath) indexURL=\(finalIndexURL.path) tempURL=\(buildingURL.path)")

        do {
            try Task.checkCancellation()

            let db = try SQLiteDatabase(path: databasePath, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            let books = try loadBooks(db: db)
            let categories = try loadCategories(db: db)
            let categoryPaths = buildCategoryPaths(categories)
            otzariaIndexLog("total books=\(books.count)")

            var manifest = manager.storedManifest(indexURL: buildingURL) ?? OtzariaIndexedBooksManifest(
                databasePath: databasePath,
                indexVersion: manager.currentIndexVersion,
                books: []
            )
            if manifest.databasePath != databasePath || manifest.indexVersion != manager.currentIndexVersion {
                manifest = OtzariaIndexedBooksManifest(
                    databasePath: databasePath,
                    indexVersion: manager.currentIndexVersion,
                    books: []
                )
            }
            var indexedBookIds = Set(manifest.books.map(\.bookId))
            var processedBooks = 0
            var processedLines = 0
            var failedBooks = 0
            var consecutiveFailures = 0
            var engine: OtzariaSearchEngineBridge? = try OtzariaSearchEngineBridge(indexURL: buildingURL)

            for (catalogueOrder, book) in books.enumerated() {
                try Task.checkCancellation()

                if indexedBookIds.contains(book.id) {
                    otzariaIndexLog("book skipped bookId=\(book.id) title=\(book.title)")
                    processedBooks += 1
                    progress(OtzariaSearchIndexProgress(processedBooks: processedBooks, totalBooks: books.count, processedLines: processedLines))
                    continue
                }

                otzariaIndexLog("book start bookId=\(book.id) title=\(book.title) totalLines=\(book.totalLines)")

                do {
                    guard let engine else { throw OtzariaSearchError.engineNotAvailable }
                    let facet = categoryPaths[book.categoryId] ?? "/"
                    let lineCount = try indexBook(
                        book,
                        catalogueOrder: catalogueOrder,
                        facet: facet,
                        db: db,
                        engine: engine
                    )

                    try Task.checkCancellation()
                    if (processedBooks + 1) % commitEveryBooks == 0 {
                        otzariaIndexLog("commit start bookId=\(book.id)")
                        try engine.commit()
                        try Task.checkCancellation()
                        otzariaIndexLog("commit done bookId=\(book.id)")
                    }

                    processedLines += lineCount
                    processedBooks += 1
                    consecutiveFailures = 0
                    indexedBookIds.insert(book.id)
                    manifest.books.append(OtzariaIndexedBookRecord(
                        bookId: book.id,
                        title: book.title,
                        totalLines: book.totalLines,
                        indexedLines: lineCount
                    ))
                    try manager.writeManifest(manifest, indexURL: buildingURL)
                    otzariaIndexLog("book done bookId=\(book.id) indexedLines=\(lineCount)")
                    progress(OtzariaSearchIndexProgress(processedBooks: processedBooks, totalBooks: books.count, processedLines: processedLines))
                } catch is CancellationError {
                    throw OtzariaSearchError.indexingCancelled
                } catch {
                    failedBooks += 1
                    consecutiveFailures += 1
                    processedBooks += 1
                    otzariaIndexLog("book failed bookId=\(book.id) title=\(book.title) error=\(error.localizedDescription)")
                    progress(OtzariaSearchIndexProgress(processedBooks: processedBooks, totalBooks: books.count, processedLines: processedLines))

                    if consecutiveFailures >= consecutiveBookFailureLimit {
                        throw OtzariaSearchError.invalidEngineResponse("Too many consecutive Otzaria indexing failures (\(consecutiveFailures)). Last error: \(error.localizedDescription)")
                    }
                }
            }

            try Task.checkCancellation()
            guard let engine else { throw OtzariaSearchError.engineNotAvailable }

            otzariaIndexLog("final commit start")
            try engine.commit()
            try Task.checkCancellation()
            otzariaIndexLog("final commit done")

            let documentCount = try engine.documentCount()
            otzariaIndexLog("document count=\(documentCount) processedLines=\(processedLines) failedBooks=\(failedBooks)")

            if documentCount == 0 && (!books.isEmpty || processedLines > 0) {
                throw OtzariaSearchError.invalidEngineResponse("Otzaria Tantivy index completed with zero documents.")
            }

            let fingerprint = try manager.currentFingerprint(databasePath: databasePath)
            try manager.writeFingerprint(fingerprint, indexURL: buildingURL)
            try manager.writeManifest(manifest, indexURL: buildingURL)

            engine = nil
            try manager.promoteBuildingIndex(databasePath: databasePath)
            OtzariaTantivySearchRepository.shared.invalidate(databasePath: databasePath)
            otzariaIndexLog("index complete documentCount=\(documentCount)")
            return documentCount
        } catch is CancellationError {
            manager.cancelBuildingIndex(databasePath: databasePath)
            otzariaIndexLog("index cancelled")
            throw OtzariaSearchError.indexingCancelled
        } catch OtzariaSearchError.indexingCancelled {
            manager.cancelBuildingIndex(databasePath: databasePath)
            otzariaIndexLog("index cancelled")
            throw OtzariaSearchError.indexingCancelled
        } catch {
            manager.cancelBuildingIndex(databasePath: databasePath)
            otzariaIndexLog("index failed error=\(error.localizedDescription)")
            throw error
        }
    }

    private func loadBooks(db: SQLiteDatabase) throws -> [BookRow] {
        try db.fetch(query: """
            SELECT id, title, COALESCE(categoryId, 0), COALESCE(totalLines, 0), COALESCE(orderIndex, id), COALESCE(fileType, 'txt')
            FROM book
            WHERE COALESCE(fileType, '') NOT IN ('link', 'url')
            ORDER BY COALESCE(categoryId, 0), COALESCE(orderIndex, id), title
        """) { row in
            BookRow(
                id: row.int(at: 0),
                title: row.string(at: 1) ?? "Untitled",
                categoryId: row.int(at: 2),
                totalLines: row.int(at: 3),
                orderIndex: row.int(at: 4),
                fileType: row.string(at: 5) ?? "txt"
            )
        }
    }

    private func loadCategories(db: SQLiteDatabase) throws -> [CategoryRow] {
        try db.fetch(query: """
            SELECT id, parentId, title, COALESCE(orderIndex, id)
            FROM category
            ORDER BY COALESCE(parentId, id), COALESCE(orderIndex, id), title
        """) { row in
            CategoryRow(
                id: row.int(at: 0),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1),
                title: row.string(at: 2) ?? "",
                orderIndex: row.int(at: 3)
            )
        }
    }

    private func buildCategoryPaths(_ categories: [CategoryRow]) -> [Int: String] {
        let byId = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var memo: [Int: String] = [:]

        func path(for id: Int, seen: Set<Int> = []) -> String {
            if let cached = memo[id] { return cached }
            guard let category = byId[id], !seen.contains(id) else { return "/" }
            let safeTitle = category.title
                .replacingOccurrences(of: "/", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parentPath: String
            if let parentId = category.parentId {
                parentPath = path(for: parentId, seen: seen.union([id]))
            } else {
                parentPath = ""
            }
            let resolved = (parentPath + "/" + safeTitle).replacingOccurrences(of: #"/+"#, with: "/", options: .regularExpression)
            memo[id] = resolved.isEmpty ? "/" : resolved
            return memo[id]!
        }

        for category in categories {
            _ = path(for: category.id)
        }
        return memo
    }

    private func indexBook(
        _ book: BookRow,
        catalogueOrder: Int,
        facet: String,
        db: SQLiteDatabase,
        engine: OtzariaSearchEngineBridge
    ) throws -> Int {
        var offset = 0
        var processed = 0

        while true {
            try Task.checkCancellation()
            let rows = try db.fetch(query: """
                SELECT id, lineIndex, COALESCE(content, ''), COALESCE(heRef, '')
                FROM line
                WHERE bookId = ? AND lineIndex >= ?
                ORDER BY lineIndex
                LIMIT ?
            """, parameters: [book.id, offset, batchSize]) { row in
                (
                    lineId: row.int(at: 0),
                    lineIndex: row.int(at: 1),
                    content: row.string(at: 2) ?? "",
                    heRef: row.string(at: 3) ?? ""
                )
            }

            if rows.isEmpty { break }
            otzariaIndexLog("batch start bookId=\(book.id) offset=\(offset) rowCount=\(rows.count)")

            let documents = rows.map { row in
                OtzariaSearchDocument(
                    id: buildDocumentId(catalogueOrder: catalogueOrder, ordinal: row.lineIndex),
                    title: book.title,
                    reference: row.heRef,
                    topics: facet.isEmpty ? "/" : facet,
                    text: OtzariaSearchTextNormalizer.normalizeForIndexing(row.content),
                    segment: UInt64(max(row.lineIndex, 0)),
                    isPdf: false,
                    filePath: "otzaria-book:\(book.id)"
                )
            }

            try engine.addDocuments(documents)
            try Task.checkCancellation()
            otzariaIndexLog("batch added bookId=\(book.id) offset=\(offset) rowCount=\(rows.count)")
            processed += rows.count
            offset = (rows.last?.lineIndex ?? offset) + 1
        }

        if processed == 0 {
            try Task.checkCancellation()
            try engine.addDocuments([
                OtzariaSearchDocument(
                    id: buildDocumentId(catalogueOrder: catalogueOrder, ordinal: 0),
                    title: book.title,
                    reference: "",
                    topics: facet.isEmpty ? "/" : facet,
                    text: "",
                    segment: 0,
                    isPdf: false,
                    filePath: "otzaria-book:\(book.id)"
                )
            ])
            try Task.checkCancellation()
            otzariaIndexLog("empty marker added bookId=\(book.id)")
        }

        return processed
    }

    private func buildDocumentId(catalogueOrder: Int, ordinal: Int) -> UInt64 {
        let hi = UInt64(max(catalogueOrder, 0) + 1) << 32
        let lo = UInt64(max(ordinal, 0) + 1)
        return hi + lo
    }
}

private func otzariaIndexLog(_ message: String) {
    NSLog("%@", "[OtzariaIndex] \(message)")
}
