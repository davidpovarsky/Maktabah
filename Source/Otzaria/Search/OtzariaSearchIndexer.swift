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
    private var isRunning = false

    func rebuildIndex(
        databasePath: String,
        progress: @escaping @Sendable (OtzariaSearchIndexProgress) -> Void
    ) async throws -> UInt64 {
        guard !isRunning else {
            throw OtzariaSearchError.invalidEngineResponse("An Otzaria index build is already running")
        }
        isRunning = true
        defer { isRunning = false }
        let plan = try indexer.makePlan(databasePath: databasePath)
        let manager = OtzariaSearchIndexManager.shared
        let identity = try manager.makeIdentity(
            databasePath: databasePath,
            catalogueHash: indexer.catalogueHash(plan.books)
        )
        // Release any writer held by the cached final index before a safe
        // snapshot is copied into the replacement build.
        OtzariaTantivySearchRepository.shared.invalidate(databasePath: databasePath)
        let prepared = try manager.prepareOrResumeBuildingIndex(
            databasePath: databasePath,
            identity: identity
        )
        var checkpoint = prepared.checkpoint
        let generationOrder = identity.defaultGenerationOrder

        do {
            while true {
                try Task.checkCancellation()
                let outcome: OtzariaSearchIndexer.BatchOutcome
                do {
                    outcome = try autoreleasepool {
                        try indexer.runOneBatch(
                            databasePath: databasePath,
                            indexURL: prepared.url,
                            plan: plan,
                            identity: identity,
                            checkpoint: checkpoint,
                            generationOrder: generationOrder
                        )
                    }
                } catch let failure as OtzariaRecoverableBookFailure {
                    // The failed writer transaction was rolled back and the
                    // source-bound ledger was durably written. Replaying the
                    // same checkpoint will commit A/B, skip bad C, then index D.
                    OtzariaIndexFileLogger.log(
                        "recoverable book quarantined sourceKey=\(failure.record.sourceKey); replaying batch"
                    )
                    await Task.yield()
                    continue
                }
                checkpoint = outcome.checkpoint
                progress(OtzariaSearchIndexProgress(
                    processedBooks: outcome.checkpoint.committedBooks,
                    totalBooks: plan.books.count,
                    processedLines: outcome.checkpoint.committedDocuments
                ))
                if outcome.isComplete { break }

                // Yield between real invocations. runOneBatch has already
                // committed, checkpointed, closed Rust and closed SQLite.
                await Task.yield()
            }

            try Task.checkCancellation()
            let count = try indexer.finalize(
                databasePath: databasePath,
                buildingURL: prepared.url,
                expectedBooks: plan.books.count,
                identity: identity
            )
            return count
        } catch is CancellationError {
            manager.markPaused(databasePath: databasePath)
            throw OtzariaSearchError.indexingCancelled
        } catch OtzariaSearchError.indexingCancelled {
            manager.markPaused(databasePath: databasePath)
            throw OtzariaSearchError.indexingCancelled
        }
    }
}

final class OtzariaSearchIndexer: @unchecked Sendable {
    struct BatchLimits: Sendable {
        let maxBooks = 16
        let maxDocuments = 20_000
        let maxRawBytes: UInt64 = 16 * 1_024 * 1_024
        let elapsedBudget: TimeInterval = 20
    }

    struct BookRow: Sendable {
        let id: Int
        let title: String
        let categoryId: Int
        let totalLines: Int
        let orderIndex: Int
        let fileType: String
        let isBaseBook: Bool
        let estimatedBytes: UInt64
        let authorNames: [String]
    }

    struct Plan: Sendable {
        let books: [BookRow]
        let categoryPaths: [Int: String]
    }

    struct BatchOutcome: Sendable {
        let checkpoint: OtzariaIndexCheckpoint
        let isComplete: Bool
    }

    private struct CategoryRow {
        let id: Int
        let parentId: Int?
        let title: String
    }

    private struct TextLine {
        let lineIndex: Int
        let content: String
        let reference: String
    }

    private let limits = BatchLimits()

    func makePlan(databasePath: String) throws -> Plan {
        let db = try SQLiteDatabase(path: databasePath, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
        let authors = (try? loadAuthorsByBook(db: db)) ?? [:]
        let schema = try OtzariaBookSchemaCompatibility.projection(in: db)
        let books = try db.fetch(query: """
            SELECT b.id, b.title, COALESCE(b.categoryId, 0),
                   COALESCE((SELECT COUNT(*) FROM line lc WHERE lc.bookId = b.id), COALESCE(b.totalLines, 0)),
                   COALESCE(b.orderIndex, b.id), COALESCE(\(schema.fileType), 'txt'),
                   COALESCE(b.isBaseBook, 0),
                   COALESCE((SELECT SUM(length(CAST(l.content AS BLOB))) FROM line l WHERE l.bookId = b.id), 0)
            FROM book b
            WHERE \(schema.eligiblePredicate)
            ORDER BY COALESCE(b.categoryId, 0), COALESCE(b.orderIndex, b.id), b.title, b.id
        """) { row in
            let id = row.int(at: 0)
            return BookRow(
                id: id,
                title: row.string(at: 1) ?? "Untitled",
                categoryId: row.int(at: 2),
                totalLines: row.int(at: 3),
                orderIndex: row.int(at: 4),
                fileType: row.string(at: 5) ?? "txt",
                isBaseBook: row.int(at: 6) != 0,
                estimatedBytes: UInt64(max(row.int(at: 7), 0)),
                authorNames: authors[id] ?? []
            )
        }
        let categories = try db.fetch(query: "SELECT id, parentId, title FROM category") { row in
            CategoryRow(
                id: row.int(at: 0),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1),
                title: row.string(at: 2) ?? ""
            )
        }
        return Plan(books: books, categoryPaths: buildCategoryPaths(categories))
    }

    func catalogueHash(_ books: [BookRow]) -> String {
        var hash: UInt64 = 1469598103934665603
        for (ordinal, book) in books.enumerated() {
            let record = [
                String(ordinal), String(book.id), book.title,
                String(book.categoryId), String(book.orderIndex), String(book.totalLines),
                String(book.estimatedBytes), book.fileType, String(book.isBaseBook),
                book.authorNames.joined(separator: "\u{1d}")
            ].joined(separator: "\u{1f}") + "\u{1e}"
            for byte in record.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1099511628211
            }
        }
        return String(hash, radix: 16)
    }

    /// One bounded native-engine lifetime. A successful return always means
    /// the engine was committed, the checkpoint was atomically written, and
    /// both native/SQLite handles were released.
    func runOneBatch(
        databasePath: String,
        indexURL: URL,
        plan: Plan,
        identity: OtzariaIndexBuildIdentity,
        checkpoint: OtzariaIndexCheckpoint?,
        generationOrder: UInt32
    ) throws -> BatchOutcome {
        let startOrdinal = (checkpoint?.lastCatalogueOrdinal ?? -1) + 1
        guard startOrdinal < plan.books.count else {
            return BatchOutcome(checkpoint: checkpoint ?? emptyCheckpoint(identity: identity), isComplete: true)
        }

        let started = Date()
        let sequence = (checkpoint?.batchSequence ?? 0) + 1
        OtzariaIndexFileLogger.log(
            "batch start sequence=\(sequence) startOrdinal=\(startOrdinal) upstream=\(identity.upstreamCommit) " +
            "engine=\(identity.engineVersion) schema=\(identity.indexSchemaVersion) " +
            "limits.books=\(limits.maxBooks) limits.documents=\(limits.maxDocuments) limits.bytes=\(limits.maxRawBytes) " +
            "memoryBytes=\(OtzariaIndexFileLogger.memoryFootprint)"
        )

        var lastOrdinal = startOrdinal - 1
        var booksWritten = 0
        var documentsWritten = 0
        var bytesWritten: UInt64 = 0
        var lastSourceKey = checkpoint?.lastSourceKey ?? ""
        var activeBook: BookRow?
        var activeOrdinal: Int?
        var activeSourceIdentity: String?

        var liveEngine: OtzariaSearchEngineBridge?
        do {
            let db = try SQLiteDatabase(path: databasePath, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            let engine = try OtzariaSearchEngineBridge(indexURL: indexURL)
            liveEngine = engine
            try engine.setBulkIndexing(true)
            let existingFingerprints = try engine.bookFingerprints()
            var unchangedBooks = 0
            var quarantinedBooks = 0
            var quarantinedRecords = checkpoint?.quarantinedBooks ?? []
            let manager = OtzariaSearchIndexManager.shared
            let failureLedger = manager.failureLedger(indexURL: indexURL)
            var pdfFreshness = manager.pdfFreshness(indexURL: indexURL)
            var pdfFreshnessChanged = false

            for ordinal in startOrdinal..<plan.books.count {
                try Task.checkCancellation()
                let book = plan.books[ordinal]
                let canInclude = OtzariaSearchIndexingPolicy.canIncludeNextBook(
                    booksWritten: booksWritten,
                    documentsWritten: documentsWritten,
                    bytesWritten: bytesWritten,
                    nextDocuments: book.totalLines,
                    nextBytes: book.estimatedBytes,
                    elapsed: Date().timeIntervalSince(started),
                    maxBooks: limits.maxBooks,
                    maxDocuments: limits.maxDocuments,
                    maxBytes: limits.maxRawBytes,
                    elapsedBudget: limits.elapsedBudget
                )
                if !canInclude { break }
                activeBook = book
                activeOrdinal = ordinal

                let sourceKey = Self.filePath(forBookId: book.id)
                let topics = plan.categoryPaths[book.categoryId] ?? "/"
                var extraFacets = book.authorNames.map { "/author/\(sanitizeFacet($0))" }
                // `/base` is emitted only from the explicit, persisted
                // `book.isBaseBook` SQLite column; no title/category heuristic
                // is used. Authors come only from book_author -> author.
                if book.isBaseBook { extraFacets.append("/base") }
                let sourceIdentity = self.sourceIdentity(
                    book: book,
                    ordinal: ordinal,
                    identity: identity,
                    topics: topics,
                    extraFacets: extraFacets,
                    generationOrder: generationOrder
                )
                activeSourceIdentity = sourceIdentity
                if let quarantined = failureLedger.records.first(where: {
                    OtzariaSearchIndexingPolicy.quarantineMatches(
                        recordSourceKey: $0.sourceKey,
                        recordSourceIdentity: $0.sourceIdentity,
                        sourceKey: sourceKey,
                        sourceIdentity: sourceIdentity
                    )
                }) {
                    quarantinedBooks += 1
                    booksWritten += 1
                    lastOrdinal = ordinal
                    lastSourceKey = sourceKey
                    if !quarantinedRecords.contains(quarantined) { quarantinedRecords.append(quarantined) }
                    OtzariaIndexFileLogger.log(
                        "book skipped from quarantine id=\(book.id) ordinal=\(ordinal) classification=\(quarantined.classification.rawValue)"
                    )
                    activeBook = nil
                    activeOrdinal = nil
                    activeSourceIdentity = nil
                    continue
                }
                let lines = try loadLines(bookId: book.id, db: db)
                let measuredBytes = UInt64(lines.reduce(0) { $0 + $1.content.utf8.count })
                let oversized = OtzariaSearchIndexingPolicy.isOversized(
                    documents: book.totalLines,
                    bytes: measuredBytes,
                    maxDocuments: limits.maxDocuments,
                    maxBytes: limits.maxRawBytes
                )
                if oversized {
                    OtzariaIndexFileLogger.log(
                        "oversized book isolated id=\(book.id) ordinal=\(ordinal) documents=\(lines.count) bytes=\(measuredBytes) " +
                        "memoryBefore=\(OtzariaIndexFileLogger.memoryFootprint)"
                    )
                }
                let added: UInt32
                if book.fileType.lowercased().contains("pdf") {
                    // Upstream deliberately stores PDF fingerprint 0. Zero is
                    // never accepted as evidence of freshness: this local
                    // identity covers the DB-backed pages and index metadata.
                    let pdfIdentity = pdfSourceIdentity(
                        sourceIdentity: sourceIdentity,
                        lines: lines
                    )
                    if OtzariaSearchIndexingPolicy.pdfIsFresh(
                        storedLocalIdentity: pdfFreshness.sourceIdentities[sourceKey],
                        currentLocalIdentity: pdfIdentity,
                        indexedPathExists: existingFingerprints[sourceKey] != nil
                    ) {
                        unchangedBooks += 1
                        added = 0
                    } else {
                        try engine.deleteFilePaths([sourceKey])
                        let pages = lines.map {
                            OtzariaPDFPageInput(
                                reference: $0.reference,
                                text: $0.content,
                                pageIndex: UInt32(clamping: max($0.lineIndex, 0))
                            )
                        }
                        added = try engine.addPDFBook(OtzariaPDFBookIndexInput(
                            title: book.title,
                            topics: topics,
                            filePath: sourceKey,
                            catalogueOrder: UInt32(clamping: ordinal),
                            generationOrder: generationOrder,
                            pages: pages,
                            extraFacets: extraFacets.isEmpty ? nil : extraFacets
                        ))
                        pdfFreshness.sourceIdentities[sourceKey] = pdfIdentity
                        pdfFreshnessChanged = true
                    }
                } else {
                    // Preserve the raw stored book markup and let upstream do
                    // heading tracking, normalization and fingerprinting.
                    let text = lines.map(\.content).joined(separator: "\n")
                    let fingerprint = try OtzariaSearchEngineBridge.computeBookFingerprint(
                        text: text,
                        title: book.title,
                        topics: topics,
                        catalogueOrder: UInt32(clamping: ordinal),
                        generationOrder: generationOrder,
                        extraFacets: extraFacets
                    )
                    if existingFingerprints[sourceKey] == fingerprint {
                        unchangedBooks += 1
                        added = 0
                    } else {
                        // Delete + add share the same writer transaction. This
                        // also makes replay after commit-before-checkpoint safe.
                        try engine.deleteFilePaths([sourceKey])
                        added = try engine.addTextBook(
                            title: book.title,
                            topics: topics,
                            filePath: sourceKey,
                            catalogueOrder: UInt32(clamping: ordinal),
                            generationOrder: generationOrder,
                            text: text,
                            extraFacets: extraFacets
                        )
                    }
                }

                booksWritten += 1
                documentsWritten += Int(added)
                bytesWritten += max(book.estimatedBytes, measuredBytes)
                lastOrdinal = ordinal
                lastSourceKey = sourceKey
                activeBook = nil
                activeOrdinal = nil
                activeSourceIdentity = nil
                if oversized { break }
            }

            guard booksWritten > 0 else {
                throw OtzariaSearchError.invalidEngineResponse("Batch made no progress at catalogue ordinal \(startOrdinal)")
            }

            OtzariaIndexFileLogger.log(
                "batch pre-commit sequence=\(sequence) books=\(booksWritten) unchanged=\(unchangedBooks) quarantined=\(quarantinedBooks) documents=\(documentsWritten) " +
                "bytes=\(bytesWritten) elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000)) " +
                "memoryBytes=\(OtzariaIndexFileLogger.memoryFootprint)"
            )
            let commitStarted = Date()
            try engine.commit()
            OtzariaIndexFileLogger.log(
                "batch native-commit sequence=\(sequence) elapsedMs=\(Int(Date().timeIntervalSince(commitStarted) * 1000)) " +
                "memoryBytes=\(OtzariaIndexFileLogger.memoryFootprint)"
            )

            // There is deliberately no cancellation point between commit and
            // these atomic orchestration writes. If the process dies here,
            // delete+add replay is idempotent and converges on the same state.
            if pdfFreshnessChanged {
                try manager.writePDFFreshness(pdfFreshness, indexURL: indexURL)
            }
            let candidate = OtzariaIndexCheckpoint(
                identity: identity,
                lastCatalogueOrdinal: lastOrdinal,
                lastSourceKey: lastSourceKey,
                committedBooks: (checkpoint?.committedBooks ?? 0) + booksWritten,
                totalBooks: plan.books.count,
                committedDocuments: (checkpoint?.committedDocuments ?? 0) + documentsWritten,
                committedBytes: (checkpoint?.committedBytes ?? 0) + bytesWritten,
                timestamp: Date(),
                upstreamCommit: identity.upstreamCommit,
                batchSequence: sequence,
                quarantinedBooks: quarantinedRecords.sorted { $0.catalogueOrdinal < $1.catalogueOrdinal }
            )
            try OtzariaSearchIndexManager.shared.writeCheckpoint(candidate, indexURL: indexURL)
            OtzariaIndexFileLogger.log(
                "batch committed sequence=\(sequence) checkpointOrdinal=\(lastOrdinal) elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000))"
            )
            engine.close()
            liveEngine = nil
            OtzariaIndexFileLogger.log(
                "batch closed sequence=\(sequence) memoryBytes=\(OtzariaIndexFileLogger.memoryFootprint)"
            )
            return BatchOutcome(checkpoint: candidate, isComplete: lastOrdinal + 1 >= plan.books.count)
        } catch {
            try? liveEngine?.rollback()
            liveEngine?.close()
            if let book = activeBook {
                let classification = classifyFailure(error, fileType: book.fileType)
                OtzariaIndexFileLogger.logError(
                    "book failed id=\(book.id) title=\(book.title) classification=\(classification?.rawValue ?? "fatal") batch rolled back",
                    error: error
                )
                if let classification, let ordinal = activeOrdinal, let sourceIdentity = activeSourceIdentity {
                    let record = OtzariaBookFailureRecord(
                        sourceKey: Self.filePath(forBookId: book.id),
                        sourceIdentity: sourceIdentity,
                        bookId: book.id,
                        title: book.title,
                        catalogueOrdinal: ordinal,
                        classification: classification,
                        message: String(describing: error),
                        failedAt: Date()
                    )
                    try OtzariaSearchIndexManager.shared.recordFailure(record, indexURL: indexURL)
                    throw OtzariaRecoverableBookFailure(record: record)
                }
            }
            OtzariaIndexFileLogger.logError("batch failed sequence=\(sequence); checkpoint not advanced", error: error)
            throw error
        }
    }

    func finalize(
        databasePath: String,
        buildingURL: URL,
        expectedBooks: Int,
        identity: OtzariaIndexBuildIdentity
    ) throws -> UInt64 {
        OtzariaIndexFileLogger.log("index finalizing expectedBooks=\(expectedBooks)")
        let finalPlan = try makePlan(databasePath: databasePath)
        guard try OtzariaSearchIndexManager.shared.currentFingerprint(databasePath: databasePath) == identity.database,
              catalogueHash(finalPlan.books) == identity.catalogueHash else {
            throw OtzariaSearchError.invalidEngineResponse(
                "The source database changed during indexing; the committed partial build was retained for reconciliation."
            )
        }
        let engine = try OtzariaSearchEngineBridge(indexURL: buildingURL)
        defer { engine.close() }
        try engine.setBulkIndexing(false)
        let quarantinedPaths = Set(
            (OtzariaSearchIndexManager.shared.checkpoint(indexURL: buildingURL)?.quarantinedBooks ?? [])
                .map(\.sourceKey)
        )
        let currentPaths = Set(finalPlan.books.map { Self.filePath(forBookId: $0.id) })
            .subtracting(quarantinedPaths)
        let stalePaths = try engine.indexedFilePaths().filter { !currentPaths.contains($0) }
        if !stalePaths.isEmpty {
            try engine.deleteFilePaths(stalePaths)
            OtzariaIndexFileLogger.log("index finalizing removedStaleBooks=\(stalePaths.count)")
        }
        try engine.commit()
        let bytesBeforeOptimize = directorySize(buildingURL)
        let segmentsBeforeOptimize = segmentCount(buildingURL)
        let optimizeStarted = Date()
        try engine.optimize()
        let optimizeDuration = Date().timeIntervalSince(optimizeStarted)
        let segmentsAfterOptimize = segmentCount(buildingURL)
        let bytesAfterOptimize = directorySize(buildingURL)
        try writeOptimizeMetrics(
            at: buildingURL,
            segmentsBefore: segmentsBeforeOptimize,
            segmentsAfter: segmentsAfterOptimize,
            bytesBefore: bytesBeforeOptimize,
            bytesAfter: bytesAfterOptimize,
            duration: optimizeDuration
        )

        let compatibility = try OtzariaSearchEngineBridge.checkCompatibility(indexURL: buildingURL)
        guard compatibility.compatible else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Built index failed upstream compatibility: \(compatibility.status) \(compatibility.reason ?? "")"
            )
        }
        let documentCount = try engine.documentCount()
        guard documentCount > 0 || expectedBooks == 0 else {
            throw OtzariaSearchError.invalidEngineResponse("Completed index contains zero documents")
        }
        let unexpectedPaths = Set(try engine.indexedFilePaths()).subtracting(currentPaths)
        guard unexpectedPaths.isEmpty else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Completed index still contains \(unexpectedPaths.count) stale source paths"
            )
        }
        let fingerprints = try engine.bookFingerprints()
        let textPaths = Set(finalPlan.books.lazy
            .filter { !$0.fileType.lowercased().contains("pdf") }
            .map { Self.filePath(forBookId: $0.id) })
            .subtracting(quarantinedPaths)
        let conflictingTextFingerprints = fingerprints.filter { textPaths.contains($0.key) && $0.value == 0 }
        guard conflictingTextFingerprints.isEmpty else {
            throw OtzariaSearchError.invalidEngineResponse(
                "Completed index contains \(conflictingTextFingerprints.count) conflicting text-book fingerprints"
            )
        }
        OtzariaIndexFileLogger.log(
            "index validated documents=\(documentCount) fingerprints=\(fingerprints.count) schema=\(compatibility.requiredSchemaVersion)"
        )
        engine.close()

        let repository = OtzariaTantivySearchRepository.shared
        repository.invalidate(databasePath: databasePath)
        try OtzariaSearchIndexManager.shared.promoteBuildingIndex(databasePath: databasePath)
        repository.invalidate(databasePath: databasePath)
        return documentCount
    }

    private func segmentCount(_ indexURL: URL) -> Int {
        let metaURL = indexURL.appendingPathComponent("meta.json")
        guard let data = try? Data(contentsOf: metaURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let segments = object["segments"] as? [Any] else { return 0 }
        return segments.count
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
        ) else { return 0 }
        var total: UInt64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { continue }
            total += UInt64(values.fileSize ?? 0)
        }
        return total
    }

    private func writeOptimizeMetrics(
        at indexURL: URL,
        segmentsBefore: Int,
        segmentsAfter: Int,
        bytesBefore: UInt64,
        bytesAfter: UInt64,
        duration: TimeInterval
    ) throws {
        let payload: [String: Any] = [
            "segmentsBeforeOptimize": segmentsBefore,
            "segmentsAfterOptimize": segmentsAfter,
            "bytesBeforeOptimize": bytesBefore,
            "bytesAfterOptimize": bytesAfter,
            "optimizeDurationSeconds": duration,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(
            to: indexURL.appendingPathComponent("otzaria_lexical_build_metrics.json"),
            options: .atomic
        )
    }

    private func emptyCheckpoint(identity: OtzariaIndexBuildIdentity) -> OtzariaIndexCheckpoint {
        OtzariaIndexCheckpoint(
            identity: identity,
            lastCatalogueOrdinal: -1,
            lastSourceKey: "",
            committedBooks: 0,
            totalBooks: 0,
            committedDocuments: 0,
            committedBytes: 0,
            timestamp: Date(),
            upstreamCommit: identity.upstreamCommit,
            batchSequence: 0,
            quarantinedBooks: []
        )
    }

    private func loadLines(bookId: Int, db: SQLiteDatabase) throws -> [TextLine] {
        try db.fetch(query: """
            SELECT lineIndex, COALESCE(content, ''), COALESCE(heRef, '')
            FROM line WHERE bookId = ? ORDER BY lineIndex
        """, parameters: [bookId]) { row in
            TextLine(
                lineIndex: row.int(at: 0),
                content: row.string(at: 1) ?? "",
                reference: row.string(at: 2) ?? ""
            )
        }
    }

    private func loadAuthorsByBook(db: SQLiteDatabase) throws -> [Int: [String]] {
        let rows = try db.fetch(query: """
            SELECT ba.bookId, a.name
            FROM book_author ba JOIN author a ON a.id = ba.authorId
            ORDER BY ba.bookId, a.name
        """) { row in (row.int(at: 0), row.string(at: 1) ?? "") }
        return Dictionary(grouping: rows, by: { $0.0 }).mapValues { $0.map(\.1).filter { !$0.isEmpty } }
    }

    private func buildCategoryPaths(_ categories: [CategoryRow]) -> [Int: String] {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var memo: [Int: String] = [:]
        func resolve(_ id: Int, seen: Set<Int> = []) -> String {
            if let cached = memo[id] { return cached }
            guard let category = byID[id], !seen.contains(id) else { return "/" }
            let title = sanitizeFacet(category.title)
            let parent = category.parentId.map { resolve($0, seen: seen.union([id])) } ?? ""
            let path = (parent + "/" + title).replacingOccurrences(of: #"/+"#, with: "/", options: .regularExpression)
            memo[id] = path.isEmpty ? "/" : path
            return memo[id]!
        }
        for category in categories { _ = resolve(category.id) }
        return memo
    }

    private func sanitizeFacet(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceIdentity(
        book: BookRow,
        ordinal: Int,
        identity: OtzariaIndexBuildIdentity,
        topics: String,
        extraFacets: [String],
        generationOrder: UInt32
    ) -> String {
        stableHash([
            identity.database.databasePath,
            String(identity.database.fileSize),
            String(identity.database.modificationTime.bitPattern),
            String(book.id), String(ordinal), book.title, topics,
            String(book.totalLines), String(book.estimatedBytes), book.fileType,
            String(book.isBaseBook), String(generationOrder),
            extraFacets.joined(separator: "\u{1d}")
        ])
    }

    private func pdfSourceIdentity(sourceIdentity: String, lines: [TextLine]) -> String {
        var hash: UInt64 = 1469598103934665603
        feed(sourceIdentity, into: &hash)
        for line in lines {
            feed(String(line.lineIndex), into: &hash)
            feed(line.reference, into: &hash)
            feed(line.content, into: &hash)
        }
        return String(hash, radix: 16)
    }

    private func stableHash(_ fields: [String]) -> String {
        var hash: UInt64 = 1469598103934665603
        for field in fields { feed(field, into: &hash) }
        return String(hash, radix: 16)
    }

    private func feed(_ value: String, into hash: inout UInt64) {
        for byte in value.utf8 { hash ^= UInt64(byte); hash &*= 1099511628211 }
        hash ^= 0xff
        hash &*= 1099511628211
    }

    private func classifyFailure(
        _ error: Error,
        fileType: String
    ) -> OtzariaBookFailureClassification? {
        let message = String(describing: error).lowercased()
        if fileType.lowercased().contains("pdf") {
            if message.contains("password") || message.contains("encrypted") { return .pdfPasswordProtected }
            if message.contains("permission") || message.contains("access denied") { return .pdfPermission }
            if message.contains("timeout") || message.contains("timed out") { return .pdfTimeout }
            if message.contains("unsupported") { return .pdfUnsupported }
            if message.contains("corrupt") || message.contains("partial") || message.contains("truncated") {
                return .pdfCorrupt
            }
        }
        if message.contains("invalid utf") || message.contains("invalid book") || message.contains("malformed input") {
            return .invalidBookInput
        }
        // Unknown engine, writer, SQLite and commit failures are fatal. They
        // must never be hidden by the per-book quarantine.
        return nil
    }

    private static func filePath(forBookId id: Int) -> String { "otzaria-book:\(id)" }
}
