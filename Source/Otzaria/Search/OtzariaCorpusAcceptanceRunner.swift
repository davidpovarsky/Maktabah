import Foundation
import SQLite3

/// Opt-in DEBUG launch hook used by Scripts/run-otzaria-corpus-acceptance.sh.
/// It is inert in normal app launches and absent from Release behavior.
enum OtzariaCorpusAcceptanceRunner {
    private struct Report: Codable {
        let passed: Bool
        let databasePath: String
        let expectedBooks: Int
        let plannedBooks: Int
        let indexedDocuments: UInt64
        let reopenedDocuments: UInt64
        let indexedSourcePaths: Int
        let baseBooks: Int
        let booksWithAuthors: Int
        let categoryPaths: Int
        let quarantinedBooks: Int
        let searchChecks: Int
        let upstreamCommit: String
        let defaultGenerationOrder: UInt32
        let error: String?
    }

    @MainActor
    static func runIfRequested() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard let databasePath = environment["OTZARIA_CORPUS_ACCEPTANCE_DATABASE"],
              let resultPath = environment["OTZARIA_CORPUS_ACCEPTANCE_RESULT"] else { return }
        let expectedBooks = Int(environment["OTZARIA_CORPUS_ACCEPTANCE_EXPECTED_BOOKS"] ?? "7030") ?? 7030
        let resultURL = URL(fileURLWithPath: resultPath)

        do {
            let indexer = OtzariaSearchIndexer()
            let plan = try indexer.makePlan(databasePath: databasePath)
            guard plan.books.count == expectedBooks else {
                throw OtzariaSearchError.invalidEngineResponse(
                    "Corpus contains \(plan.books.count) indexable books; expected \(expectedBooks)"
                )
            }
            guard plan.books.contains(where: \.isBaseBook),
                  plan.books.contains(where: { !$0.authorNames.isEmpty }),
                  plan.categoryPaths.values.contains(where: { $0 != "/" }) else {
                throw OtzariaSearchError.invalidEngineResponse("Corpus lacks required category/base/author fixtures")
            }

            let count = try await OtzariaSearchIndexingService.shared.rebuildIndex(
                databasePath: databasePath,
                progress: { progress in
                    OtzariaIndexFileLogger.log(
                        "acceptance progress books=\(progress.processedBooks)/\(progress.totalBooks) documents=\(progress.processedLines)"
                    )
                }
            )
            let manager = OtzariaSearchIndexManager.shared
            let engine = try OtzariaSearchEngineBridge(indexURL: manager.indexURL(for: databasePath))
            defer { engine.close() }
            let paths = try engine.indexedFilePaths()
            let reopenedCount = try engine.documentCount()
            let build = try OtzariaSearchEngineBridge.buildInfo()
            let finalCheckpoint = manager.checkpoint(indexURL: manager.indexURL(for: databasePath))
            let quarantined = finalCheckpoint?.quarantinedBooks.count ?? 0
            guard paths.count == Set(paths).count,
                  paths.count == expectedBooks - quarantined,
                  reopenedCount == count,
                  finalCheckpoint?.lastCatalogueOrdinal == expectedBooks - 1,
                  finalCheckpoint?.committedBooks == expectedBooks else {
                throw OtzariaSearchError.invalidEngineResponse(
                    "Final reopen/count/path/checkpoint sanity check failed"
                )
            }
            let quarantinedIDs = Set((finalCheckpoint?.quarantinedBooks ?? []).map(\.bookId))
            let usable = plan.books.filter { !quarantinedIDs.contains($0.id) }
            let base = try requiredBook(usable.first(where: \.isBaseBook), label: "/base")
            let author = try requiredBook(usable.first(where: { !$0.authorNames.isEmpty }), label: "author")
            let category = try requiredBook(
                usable.first(where: { plan.categoryPaths[$0.categoryId] != nil && plan.categoryPaths[$0.categoryId] != "/" }),
                label: "category"
            )
            let checks: [(OtzariaSearchIndexer.BookRow, String)] = [
                (base, "/base"),
                (author, "/author/\(sanitizeFacet(author.authorNames[0]))"),
                (category, plan.categoryPaths[category.categoryId]!)
            ]
            for (book, facet) in checks {
                let query = try sampleQuery(databasePath: databasePath, bookID: book.id)
                let page = try engine.search(OtzariaSearchRequest(
                    query: query,
                    mode: .exact,
                    facets: [facet],
                    limit: 10
                ))
                guard page.totalCount > 0,
                      page.results.contains(where: { $0.filePath == "otzaria-book:\(book.id)" }) else {
                    throw OtzariaSearchError.invalidEngineResponse(
                        "Reopen search failed for facet \(facet), book \(book.id), query \(query)"
                    )
                }
            }
            try write(Report(
                passed: true,
                databasePath: databasePath,
                expectedBooks: expectedBooks,
                plannedBooks: plan.books.count,
                indexedDocuments: count,
                reopenedDocuments: reopenedCount,
                indexedSourcePaths: paths.count,
                baseBooks: plan.books.filter(\.isBaseBook).count,
                booksWithAuthors: plan.books.filter { !$0.authorNames.isEmpty }.count,
                categoryPaths: Set(plan.categoryPaths.values).count,
                quarantinedBooks: quarantined,
                searchChecks: checks.count,
                upstreamCommit: build.upstreamCommit,
                defaultGenerationOrder: build.defaultGenerationOrder,
                error: nil
            ), to: resultURL)
        } catch {
            let build = try? OtzariaSearchEngineBridge.buildInfo()
            try? write(Report(
                passed: false,
                databasePath: databasePath,
                expectedBooks: expectedBooks,
                plannedBooks: 0,
                indexedDocuments: 0,
                reopenedDocuments: 0,
                indexedSourcePaths: 0,
                baseBooks: 0,
                booksWithAuthors: 0,
                categoryPaths: 0,
                quarantinedBooks: 0,
                searchChecks: 0,
                upstreamCommit: build?.upstreamCommit ?? "unavailable",
                defaultGenerationOrder: build?.defaultGenerationOrder ?? 0,
                error: error.localizedDescription
            ), to: resultURL)
        }
        #endif
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func requiredBook(
        _ book: OtzariaSearchIndexer.BookRow?,
        label: String
    ) throws -> OtzariaSearchIndexer.BookRow {
        guard let book else {
            throw OtzariaSearchError.invalidEngineResponse("No non-quarantined \(label) acceptance fixture")
        }
        return book
    }

    private static func sampleQuery(databasePath: String, bookID: Int) throws -> String {
        let db = try SQLiteDatabase(
            path: databasePath,
            flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        )
        let lines = try db.fetch(
            query: "SELECT COALESCE(content, '') FROM line WHERE bookId = ? AND length(content) > 8 ORDER BY lineIndex LIMIT 25",
            parameters: [bookID]
        ) { $0.string(at: 0) ?? "" }
        for line in lines {
            if let word = try OtzariaSearchEngineBridge.splitQueryWords(line)
                .first(where: { $0.count >= 3 }) {
                return word
            }
        }
        throw OtzariaSearchError.invalidEngineResponse("No searchable acceptance token for book \(bookID)")
    }

    private static func sanitizeFacet(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
