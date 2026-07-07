import Foundation

extension OtzariaMaktabahBridge {
    func getLinksForLine(_ line: OtzariaLineAnchor) -> [OtzariaLinkedSource] {
        do {
            return try withDatabase { db in
                let categories = try categoryMap(in: db)
                let resolver = OtzariaCategoryPathResolver(categoriesById: categories)

                return try db.fetch(query: """
                    WITH resolved AS (
                        SELECT
                            l.id AS linkId,
                            ct.name AS connectionType,
                            CASE WHEN l.sourceLineId = ? THEN l.targetLineId ELSE l.sourceLineId END AS linkedLineId,
                            CASE WHEN l.sourceLineId = ? THEN l.targetBookId ELSE l.sourceBookId END AS linkedBookId
                        FROM link l
                        JOIN connection_type ct ON ct.id = l.connectionTypeId
                        WHERE l.sourceLineId = ? OR l.targetLineId = ?
                    )
                    SELECT
                        MIN(r.linkId) AS id,
                        r.connectionType,
                        r.linkedLineId,
                        r.linkedBookId,
                        ln.lineIndex,
                        b.title AS bookTitle,
                        b.filePath AS bookPath,
                        b.categoryId AS linkedCategoryId,
                        b.orderIndex AS linkedBookOrderIndex,
                        ln.heRef,
                        ln.content
                    FROM resolved r
                    JOIN line ln ON ln.id = r.linkedLineId
                    JOIN book b ON b.id = r.linkedBookId
                    GROUP BY r.connectionType, r.linkedLineId, r.linkedBookId
                    ORDER BY
                        CASE r.connectionType
                            WHEN 'COMMENTARY' THEN 1
                            WHEN 'TARGUM' THEN 2
                            WHEN 'REFERENCE' THEN 3
                            WHEN 'SOURCE' THEN 4
                            ELSE 5
                        END,
                        b.orderIndex,
                        ln.lineIndex
                    LIMIT 500
                """, parameters: [line.id, line.id, line.id, line.id]) { row in
                    let linkedCategoryId = row.isNull(at: 7) ? nil : row.int(at: 7)

                    return OtzariaLinkedSource(
                        id: row.int(at: 0),
                        connectionType: row.string(at: 1) ?? "OTHER",
                        linkedLineId: row.int(at: 2),
                        linkedBookId: row.int(at: 3),
                        linkedLineIndex: row.int(at: 4),
                        bookTitle: row.string(at: 5) ?? "ללא שם",
                        bookPath: row.string(at: 6),
                        linkedCategoryId: linkedCategoryId,
                        linkedCategoryPath: resolver.path(for: linkedCategoryId),
                        linkedBookOrderIndex: row.isNull(at: 8) ? nil : row.int(at: 8),
                        heRef: row.string(at: 9),
                        content: row.string(at: 10) ?? ""
                    )
                }
            }
        } catch {
            OtzariaFileLogger.shared.log("[OtzariaMaktabahBridge] getLinksForLine error lineId=\(line.id) error=\(error.localizedDescription)")
            return []
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
        for category in categories {
            result[category.id] = category
        }
        return result
    }
}
