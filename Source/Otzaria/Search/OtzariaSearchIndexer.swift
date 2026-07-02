import Foundation
import SQLite3

struct OtzariaSearchIndexProgress: Equatable, Sendable {
    let processedBooks: Int
    let totalBooks: Int
    let processedLines: Int
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

    private let batchSize = 300
    private let commitEveryBooks = 25

    func rebuildIndex(
        databasePath: String,
        progress: @escaping @Sendable (OtzariaSearchIndexProgress) -> Void
    ) async throws -> UInt64 {
        let manager = OtzariaSearchIndexManager.shared
        try manager.clearIndex(databasePath: databasePath)
        let indexURL = manager.indexURL(for: databasePath)
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)

        let engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
        try engine.clear()

        let db = try SQLiteDatabase(path: databasePath, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
        let books = try loadBooks(db: db)
        let categories = try loadCategories(db: db)
        let categoryPaths = buildCategoryPaths(categories)

        var processedBooks = 0
        var processedLines = 0

        for (catalogueOrder, book) in books.enumerated() {
            let facet = categoryPaths[book.categoryId] ?? "/"
            let lineCount = try indexBook(
                book,
                catalogueOrder: catalogueOrder,
                facet: facet,
                db: db,
                engine: engine
            )
            processedBooks += 1
            processedLines += lineCount
            progress(OtzariaSearchIndexProgress(
                processedBooks: processedBooks,
                totalBooks: books.count,
                processedLines: processedLines
            ))

            if processedBooks % commitEveryBooks == 0 {
                try engine.commit()
            }
        }

        try engine.commit()
        try? engine.optimize()
        let fingerprint = try manager.currentFingerprint(databasePath: databasePath)
        try manager.writeFingerprint(fingerprint, indexURL: indexURL)
        return try engine.documentCount()
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
                title: row.string(at: 1) ?? "ללא שם",
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
                    filePath: "otzaria-book:\(book.id)"
                )
            }

            try engine.addDocuments(documents)
            processed += rows.count
            offset = (rows.last?.lineIndex ?? offset) + 1
        }

        // Empty marker, like Otzaria, so processed books can be represented even when no searchable line exists.
        if processed == 0 {
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
        }

        return processed
    }

    private func buildDocumentId(catalogueOrder: Int, ordinal: Int) -> UInt64 {
        let hi = UInt64(max(catalogueOrder, 0) + 1) << 32
        let lo = UInt64(max(ordinal, 0) + 1)
        return hi + lo
    }
}
