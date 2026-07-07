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
    private let summaryEveryBooks = 25
    private let maxNewBooksPerEngineSession = 200
    private let maxLockBusySessionRetries = 2

    func rebuildIndex(
        databasePath: String,
        progress: @escaping @Sendable (OtzariaSearchIndexProgress) -> Void
    ) async throws -> UInt64 {
        let manager = OtzariaSearchIndexManager.shared
        let repository = OtzariaTantivySearchRepository.shared
        let indexURL = manager.indexURL(for: databasePath)

        otzariaIndexLog("automatic indexing start databasePath=\(databasePath)")
        otzariaIndexLog("final index path=\(indexURL.path)")
        repository.beginExclusiveIndexing(databasePath: databasePath)
        defer { repository.endExclusiveIndexing(databasePath: databasePath) }

        do {
            try Task.checkCancellation()

            let db = try SQLiteDatabase(path: databasePath, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            let books = try loadBooks(db: db)
            let categories = try loadCategories(db: db)
            let categoryPaths = buildCategoryPaths(categories)
            let allBookIds = Set(books.map(\.id))
            otzariaIndexLog("total books=\(books.count)")

            var processedLines = 0
            var skippedBooks = 0
            var indexedBooks = 0
            var failedBooks = 0
            var failedBookIds = Set<Int>()
            var consecutiveFailures = 0
            var totalIndexedThisRun = 0
            var sessionNumber = 0

            while true {
                try Task.checkCancellation()
                sessionNumber += 1
                var sessionRetry = 0

                while true {
                    var engine: OtzariaSearchEngineBridge?

                    do {
                        repository.closeEngine(databasePath: databasePath)
                        repository.invalidate(databasePath: databasePath)
                        otzariaIndexLog("session start sessionNumber=\(sessionNumber) maxNewBooks=\(maxNewBooksPerEngineSession)")
                        engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
                        guard let liveEngine = engine else { throw OtzariaSearchError.engineNotAvailable }

                        let documentCountBefore = try liveEngine.documentCount()
                        let indexedFilePaths = try liveEngine.indexedFilePaths()
                        var indexedBookIds = Set(indexedFilePaths.compactMap(Self.bookId(from:)))
                        var newlyIndexedThisSession = 0

                        otzariaIndexLog("session documentCount before=\(documentCountBefore)")
                        otzariaIndexLog("session indexedFilePaths count=\(indexedFilePaths.count)")
                        otzariaIndexLog("session indexedBookIds count=\(indexedBookIds.count)")
                        progress(OtzariaSearchIndexProgress(
                            processedBooks: min(indexedBookIds.count + failedBookIds.count, books.count),
                            totalBooks: books.count,
                            processedLines: processedLines
                        ))

                        if allBookIds.isSubset(of: indexedBookIds) {
                            otzariaIndexLog("all books already indexed sessionNumber=\(sessionNumber)")
                            let documentCount = try completeIndex(
                                engine: liveEngine,
                                manager: manager,
                                databasePath: databasePath,
                                indexURL: indexURL,
                                processedBooks: indexedBookIds.count,
                                totalBooks: books.count,
                                skippedBooks: skippedBooks,
                                indexedBooks: indexedBooks,
                                failedBooks: failedBooks,
                                processedLines: processedLines
                            )
                            engine?.close()
                            engine = nil
                            repository.invalidate(databasePath: databasePath)
                            return documentCount
                        }

                        for (catalogueOrder, book) in books.enumerated() {
                            try Task.checkCancellation()
                            let indexedFilePath = Self.filePath(forBookId: book.id)
                            otzariaIndexLog("book start sessionNumber=\(sessionNumber) catalogueOrder=\(catalogueOrder) bookId=\(book.id) title=\(book.title) totalLines=\(book.totalLines) categoryId=\(book.categoryId) fileType=\(book.fileType)")

                            if indexedBookIds.contains(book.id) {
                                skippedBooks += 1
                                otzariaIndexLog("book skipped bookId=\(book.id) title=\(book.title) reason=indexedFilePaths indexedFilePath=\(indexedFilePath)")
                                if skippedBooks % summaryEveryBooks == 0 {
                                    otzariaIndexLog("summary processedBooks=\(min(indexedBookIds.count + failedBookIds.count, books.count)) totalBooks=\(books.count) skipped=\(skippedBooks) indexed=\(indexedBooks) failed=\(failedBooks) processedLines=\(processedLines)")
                                }
                                continue
                            }

                            do {
                                let facet = categoryPaths[book.categoryId] ?? "/"
                                let lineCount = try indexBook(
                                    book,
                                    catalogueOrder: catalogueOrder,
                                    facet: facet,
                                    db: db,
                                    engine: liveEngine
                                )

                                try Task.checkCancellation()
                                if newlyIndexedThisSession % commitEveryBooks == 0 {
                                    otzariaIndexLog("commit start bookId=\(book.id)")
                                    try liveEngine.commit()
                                    try Task.checkCancellation()
                                    otzariaIndexLog("commit done bookId=\(book.id)")
                                }

                                processedLines += lineCount
                                indexedBooks += 1
                                totalIndexedThisRun += 1
                                newlyIndexedThisSession += 1
                                consecutiveFailures = 0
                                failedBookIds.remove(book.id)
                                indexedBookIds.insert(book.id)
                                otzariaIndexLog("book indexed and committed bookId=\(book.id) indexedFilePath=\(indexedFilePath) indexedLines=\(lineCount) sessionNewBooks=\(newlyIndexedThisSession) totalIndexedThisRun=\(totalIndexedThisRun)")
                                progress(OtzariaSearchIndexProgress(
                                    processedBooks: min(indexedBookIds.count + failedBookIds.count, books.count),
                                    totalBooks: books.count,
                                    processedLines: processedLines
                                ))

                                if indexedBooks % summaryEveryBooks == 0 {
                                    otzariaIndexLog("summary processedBooks=\(min(indexedBookIds.count + failedBookIds.count, books.count)) totalBooks=\(books.count) skipped=\(skippedBooks) indexed=\(indexedBooks) failed=\(failedBooks) processedLines=\(processedLines)")
                                }

                                if newlyIndexedThisSession >= maxNewBooksPerEngineSession {
                                    otzariaIndexLog("session limit reached sessionNumber=\(sessionNumber) newlyIndexedThisSession=\(newlyIndexedThisSession)")
                                    break
                                }
                            } catch is CancellationError {
                                otzariaIndexLog("book catch cancellation bookId=\(book.id)")
                                throw OtzariaSearchError.indexingCancelled
                            } catch {
                                if isLockBusyError(error) {
                                    throw error
                                }
                                failedBooks += 1
                                consecutiveFailures += 1
                                failedBookIds.insert(book.id)
                                OtzariaIndexFileLogger.logError("book failed bookId=\(book.id) title=\(book.title)", error: error)
                                progress(OtzariaSearchIndexProgress(
                                    processedBooks: min(indexedBookIds.count + failedBookIds.count, books.count),
                                    totalBooks: books.count,
                                    processedLines: processedLines
                                ))

                                if consecutiveFailures >= consecutiveBookFailureLimit {
                                    throw OtzariaSearchError.invalidEngineResponse("Too many consecutive Otzaria indexing failures (\(consecutiveFailures)). Last error: \(error.localizedDescription)")
                                }
                            }
                        }

                        try Task.checkCancellation()
                        otzariaIndexLog("session commit start sessionNumber=\(sessionNumber)")
                        try liveEngine.commit()
                        try Task.checkCancellation()
                        otzariaIndexLog("session commit done sessionNumber=\(sessionNumber)")

                        let documentCount = try liveEngine.documentCount()
                        otzariaIndexLog("session summary sessionNumber=\(sessionNumber) documentCount=\(documentCount) newlyIndexedThisSession=\(newlyIndexedThisSession) totalIndexedThisRun=\(totalIndexedThisRun) skipped=\(skippedBooks) failed=\(failedBooks) processedLines=\(processedLines)")

                        if allBookIds.isSubset(of: indexedBookIds) {
                            let finalCount = try completeIndex(
                                engine: liveEngine,
                                manager: manager,
                                databasePath: databasePath,
                                indexURL: indexURL,
                                processedBooks: indexedBookIds.count,
                                totalBooks: books.count,
                                skippedBooks: skippedBooks,
                                indexedBooks: indexedBooks,
                                failedBooks: failedBooks,
                                processedLines: processedLines
                            )
                            engine?.close()
                            engine = nil
                            repository.invalidate(databasePath: databasePath)
                            return finalCount
                        }

                        if newlyIndexedThisSession == 0 {
                            throw OtzariaSearchError.invalidEngineResponse("Otzaria indexing made no progress in session \(sessionNumber). Existing partial index was not deleted.")
                        }

                        engine?.close()
                        engine = nil
                        repository.invalidate(databasePath: databasePath)
                        otzariaIndexLog("sleep before next session sessionNumber=\(sessionNumber)")
                        try await Task.sleep(nanoseconds: 1_500_000_000)
                        break
                    } catch is CancellationError {
                        engine?.close()
                        engine = nil
                        repository.invalidate(databasePath: databasePath)
                        throw OtzariaSearchError.indexingCancelled
                    } catch {
                        engine?.close()
                        engine = nil
                        repository.invalidate(databasePath: databasePath)
                        if isLockBusyError(error) {
                            if sessionRetry < maxLockBusySessionRetries {
                                sessionRetry += 1
                                OtzariaIndexFileLogger.logError("session retry because LockBusy sessionNumber=\(sessionNumber) retry=\(sessionRetry)", error: error)
                                try await Task.sleep(nanoseconds: 3_000_000_000)
                                continue
                            }
                            throw OtzariaSearchError.invalidEngineResponse("Tantivy index writer lock is busy after retry. Close/reopen the app and resume indexing. Existing partial index was not deleted.")
                        }
                        throw error
                    }
                }
            }
        } catch is CancellationError {
            otzariaIndexLog("index catch cancellationError")
            throw OtzariaSearchError.indexingCancelled
        } catch OtzariaSearchError.indexingCancelled {
            otzariaIndexLog("index catch OtzariaSearchError.indexingCancelled")
            throw OtzariaSearchError.indexingCancelled
        } catch {
            OtzariaIndexFileLogger.logError("index catch failed", error: error)
            throw error
        }
    }

    private func completeIndex(
        engine: OtzariaSearchEngineBridge,
        manager: OtzariaSearchIndexManager,
        databasePath: String,
        indexURL: URL,
        processedBooks: Int,
        totalBooks: Int,
        skippedBooks: Int,
        indexedBooks: Int,
        failedBooks: Int,
        processedLines: Int
    ) throws -> UInt64 {
        otzariaIndexLog("final commit start")
        try engine.commit()
        otzariaIndexLog("final commit done")

        let documentCount = try engine.documentCount()
        otzariaIndexLog("final summary documentCount=\(documentCount) processedBooks=\(processedBooks) totalBooks=\(totalBooks) skipped=\(skippedBooks) indexed=\(indexedBooks) failed=\(failedBooks) processedLines=\(processedLines)")

        if documentCount == 0 && totalBooks > 0 {
            throw OtzariaSearchError.invalidEngineResponse("Otzaria Tantivy index completed with zero documents.")
        }

        let fingerprint = try manager.currentFingerprint(databasePath: databasePath)
        try manager.writeFingerprint(fingerprint, indexURL: indexURL)
        otzariaIndexLog("final complete documentCount=\(documentCount)")
        return documentCount
    }

    private func isLockBusyError(_ error: Error) -> Bool {
        let text = "\(error.localizedDescription) \(String(describing: error))"
        return text.range(of: "LockBusy", options: .caseInsensitive) != nil ||
            text.range(of: "Failed to acquire Lockfile", options: .caseInsensitive) != nil ||
            text.range(of: "already an `IndexWriter` working", options: .caseInsensitive) != nil ||
            text.range(of: "IndexWriter", options: .caseInsensitive) != nil
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
        var batchCount = 0
        otzariaIndexLog("indexBook enter bookId=\(book.id) title=\(book.title) catalogueOrder=\(catalogueOrder) facet=\(facet)")

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

            let documents = rows.map { row in
                OtzariaSearchDocument(
                    id: buildDocumentId(catalogueOrder: catalogueOrder, ordinal: row.lineIndex),
                    title: book.title,
                    reference: row.heRef,
                    topics: facet.isEmpty ? "/" : facet,
                    text: OtzariaSearchTextNormalizer.normalizeForIndexing(row.content),
                    segment: UInt64(max(row.lineIndex, 0)),
                    isPdf: false,
                    filePath: Self.filePath(forBookId: book.id)
                )
            }

            try engine.addDocuments(documents)
            try Task.checkCancellation()
            processed += rows.count
            batchCount += 1
            offset = (rows.last?.lineIndex ?? offset) + 1

            if batchCount % 25 == 0 {
                otzariaIndexLog("indexBook batch summary bookId=\(book.id) batches=\(batchCount) processed=\(processed) nextOffset=\(offset)")
            }
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
                    filePath: Self.filePath(forBookId: book.id)
                )
            ])
            try Task.checkCancellation()
        }

        otzariaIndexLog("indexBook exit bookId=\(book.id) processed=\(processed) batches=\(batchCount)")
        return processed
    }

    private static func filePath(forBookId bookId: Int) -> String {
        "otzaria-book:\(bookId)"
    }

    private static func bookId(from filePath: String) -> Int? {
        guard filePath.hasPrefix("otzaria-book:") else { return nil }
        return Int(filePath.dropFirst("otzaria-book:".count))
    }

    private func buildDocumentId(catalogueOrder: Int, ordinal: Int) -> UInt64 {
        let hi = UInt64(max(catalogueOrder, 0) + 1) << 32
        let lo = UInt64(max(ordinal, 0) + 1)
        return hi + lo
    }
}

private func otzariaIndexLog(_ message: String) {
    OtzariaIndexFileLogger.log(message)
}
