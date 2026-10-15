import Foundation

extension OtzariaMaktabahBridge {
    func getLinksForLine(_ line: OtzariaLineAnchor) -> [OtzariaLinkedSource] {
        (try? getLinks(
            bookID: line.bookId,
            sourceLineIndices: [line.lineIndex]
        )) ?? []
    }

    func getLinksForReadingUnit(_ unit: OtzariaReadingUnit) throws -> [OtzariaLinkedSource] {
        try getLinks(
            bookID: unit.bookId,
            sourceLineIndices: unit.sourceLineIndices
        )
    }

    /// Otzaria parity path for a displayed unit. The query is bounded by the
    /// unit's exact line indexes (not MIN...MAX), includes forward and inverse
    /// relationships, range coverage, and per-side suppression, and never opens
    /// one SQLite connection per line.
    private func getLinks(bookID: Int, sourceLineIndices: [Int]) throws -> [OtzariaLinkedSource] {
        let uniqueIndexes = Array(Set(sourceLineIndices)).sorted()
        guard !uniqueIndexes.isEmpty else { return [] }

        do {
            return try withDatabase { db in
                let categories = try categoryMap(in: db)
                let resolver = OtzariaCategoryPathResolver(categoriesById: categories)
                let schema = try OtzariaBookSchemaCompatibility.projection(in: db)
                let capabilities = try OtzariaDatabaseCapabilities(database: db)
                let content = OtzariaLineContentCompatibility.projection(
                    capabilities: capabilities,
                    lineAlias: "linked_line",
                    contentAlias: "linked_content"
                )
                let decoder = try OtzariaLineContentDecoder(database: db, capabilities: capabilities)
                var byIdentity: [String: OtzariaLinkedSource] = [:]

                // Each index appears in the forward and inverse arms. 400 keeps
                // the statement below SQLite's common 999-variable limit.
                for start in stride(from: 0, to: uniqueIndexes.count, by: 400) {
                    let indexes = Array(uniqueIndexes[start..<min(start + 400, uniqueIndexes.count)])
                    let placeholders = Array(repeating: "?", count: indexes.count).joined(separator: ",")
                    let forwardCoverage = capabilities.hasLinkRanges
                        ? "UNION SELECT link.id, 0, coverage.lineId FROM link_coverage coverage JOIN link ON link.id = coverage.linkId WHERE coverage.side = 0 AND link.sourceBookId = \(bookID) AND coverage.lineId IN (SELECT id FROM win)"
                        : ""
                    let inverseCoverage = capabilities.hasLinkRanges
                        ? "UNION SELECT link.id, 1, coverage.lineId FROM link_coverage coverage JOIN link ON link.id = coverage.linkId WHERE coverage.side = 1 AND link.targetBookId = \(bookID) AND coverage.lineId IN (SELECT id FROM win)"
                        : ""
                    let forwardSuppression = capabilities.hasSuppressedLinkSides
                        ? "AND NOT EXISTS (SELECT 1 FROM link_suppressed_side hidden WHERE hidden.linkId = link.id AND hidden.side = 0)"
                        : ""
                    let inverseSuppression = capabilities.hasSuppressedLinkSides
                        ? "AND NOT EXISTS (SELECT 1 FROM link_suppressed_side hidden WHERE hidden.linkId = link.id AND hidden.side = 1)"
                        : ""

                    let dependentTypes = Self.sqlList([
                        "COMMENTARY", "SUPER_COMMENTARY", "TARGUM", "MIDRASH",
                        "PARSHANUT", "DIBUR_HAMATCHIL", "ELUCIDATION",
                        "EXPLICATION", "FOOTNOTES",
                    ])
                    let referenceTypes = Self.sqlList([
                        "REFERENCE", "QUOTATION", "MESORAT_HASHAS", "EIN_MISHPAT",
                        "MISHNAH_IN_TALMUD", "RELATED", "OTHER", "SIFREI_MITZVOT",
                        "ESSAY", "ALLUSION", "LITURGY", "LAW", "SUMMARY",
                    ])
                    let inverseTypes = capabilities.hasSuppressedLinkSides
                        ? "\(dependentTypes), \(referenceTypes)"
                        : dependentTypes
                    let inverseSameBook = capabilities.hasSuppressedLinkSides
                        ? """
                          AND (link.sourceBookId != link.targetBookId OR (
                            connection_type.name IN (\(referenceTypes))
                            AND (
                              EXISTS (
                                SELECT 1 FROM link_suppressed_side source_hidden
                                WHERE source_hidden.linkId = link.id AND source_hidden.side = 0
                              )
                              OR (
                                matched.anchorLineId != link.sourceLineId
                                \(capabilities.hasLinkRanges ? "AND NOT EXISTS (SELECT 1 FROM link_coverage source_coverage WHERE source_coverage.linkId = link.id AND source_coverage.side = 0 AND source_coverage.lineId = matched.anchorLineId)" : "")
                              )
                            )
                          ))
                          """
                        : "AND link.sourceBookId != link.targetBookId"

                    var parameters: [Any] = [bookID]
                    parameters.append(contentsOf: indexes)

                    let values = try db.fetch(query: """
                        WITH win(id) AS (
                            SELECT id FROM line
                            WHERE bookId = ? AND lineIndex IN (\(placeholders))
                        ), matched(linkId, matchedSide, anchorLineId) AS (
                            SELECT link.id, 0, link.sourceLineId
                            FROM link
                            WHERE link.sourceBookId = \(bookID)
                              AND link.sourceLineId IN (SELECT id FROM win)
                            \(forwardCoverage)
                            UNION
                            SELECT link.id, 1, link.targetLineId
                            FROM link
                            WHERE link.targetBookId = \(bookID)
                              AND link.targetLineId IN (SELECT id FROM win)
                            \(inverseCoverage)
                        ), resolved AS (
                            SELECT DISTINCT
                                link.id AS linkId,
                                CASE
                                    WHEN matched.matchedSide = 1
                                     AND connection_type.name IN (\(dependentTypes))
                                    THEN 'SOURCE'
                                    ELSE COALESCE(connection_type.name, 'OTHER')
                                END AS connectionType,
                                CASE matched.matchedSide
                                    WHEN 0 THEN link.targetLineId ELSE link.sourceLineId
                                END AS linkedLineId,
                                CASE matched.matchedSide
                                    WHEN 0 THEN link.targetBookId ELSE link.sourceBookId
                                END AS linkedBookId
                            FROM matched
                            JOIN link ON link.id = matched.linkId
                            LEFT JOIN connection_type ON connection_type.id = link.connectionTypeId
                            WHERE (
                                matched.matchedSide = 0
                                \(forwardSuppression)
                            ) OR (
                                matched.matchedSide = 1
                                AND connection_type.name IN (\(inverseTypes))
                                \(inverseSuppression)
                                \(inverseSameBook)
                            )
                        )
                        SELECT resolved.linkId,
                               resolved.connectionType,
                               resolved.linkedLineId,
                               resolved.linkedBookId,
                               linked_line.lineIndex,
                               linked_book.title,
                               \(schema.filePath),
                               linked_book.categoryId,
                               linked_book.orderIndex,
                               linked_line.heRef,
                               \(content.expression)
                        FROM resolved
                        JOIN line linked_line ON linked_line.id = resolved.linkedLineId
                        \(content.join)
                        JOIN book linked_book ON linked_book.id = resolved.linkedBookId
                        ORDER BY linked_book.orderIndex, linked_line.lineIndex, resolved.linkId
                    """, parameters: parameters) { row in
                        let linkedCategoryID = row.isNull(at: 7) ? nil : row.int(at: 7)
                        return OtzariaLinkedSource(
                            id: row.int(at: 0),
                            connectionType: row.string(at: 1) ?? "OTHER",
                            linkedLineId: row.int(at: 2),
                            linkedBookId: row.int(at: 3),
                            linkedLineIndex: row.int(at: 4),
                            bookTitle: row.string(at: 5) ?? "ללא שם",
                            bookPath: row.string(at: 6),
                            linkedCategoryId: linkedCategoryID,
                            linkedCategoryPath: resolver.path(for: linkedCategoryID),
                            linkedBookOrderIndex: row.isNull(at: 8) ? nil : row.int(at: 8),
                            heRef: row.string(at: 9),
                            content: try decoder.decode(row: row, at: 10)
                        )
                    }

                    for value in values {
                        let key = "\(value.id):\(value.linkedBookId):\(value.linkedLineId)"
                        byIdentity[key] = value
                    }
                }

                return byIdentity.values.sorted {
                    let left = ($0.linkedBookOrderIndex ?? Int.max, $0.linkedLineIndex, $0.id)
                    let right = ($1.linkedBookOrderIndex ?? Int.max, $1.linkedLineIndex, $1.id)
                    return left < right
                }
            }
        } catch {
            OtzariaFileLogger.shared.log(
                "[OtzariaMaktabahBridge] getLinks error bookId=\(bookID) "
                    + "lineCount=\(uniqueIndexes.count) error=\(error.localizedDescription)"
            )
            throw error
        }
    }

    private func categoryMap(in db: SQLiteDatabase) throws -> [Int: CategoryData] {
        let categories = try db.fetch(query: """
            SELECT id, parentId, title, level, orderIndex
            FROM category
        """) { row in
            CategoryData(
                id: row.int(at: 0),
                name: row.string(at: 2) ?? "Untitled",
                level: row.int(at: 3),
                order: row.int(at: 4),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1)
            )
        }

        var result: [Int: CategoryData] = [:]
        for category in categories { result[category.id] = category }
        return result
    }

    private static func sqlList(_ values: [String]) -> String {
        values.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }
            .joined(separator: ", ")
    }
}
