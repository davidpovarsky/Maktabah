import Foundation

final class OtzariaSQLiteSourceRepository: OtzariaSourceRepository {
    private let database: OtzariaSQLiteConnection

    init(database: OtzariaSQLiteConnection) {
        self.database = database
    }

    func sources(for line: OtzariaBookLine) async throws -> [OtzariaLinkedSource] {
        try await database.read { db in
            let statement = try OtzariaSQLiteStatement(database: db, sql: """
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
            """)

            try statement.bind(line.id, at: 1)
            try statement.bind(line.id, at: 2)
            try statement.bind(line.id, at: 3)
            try statement.bind(line.id, at: 4)

            var sources: [OtzariaLinkedSource] = []
            while try statement.step() {
                sources.append(
                    OtzariaLinkedSource(
                        id: statement.columnInt(0),
                        connectionType: statement.columnString(1) ?? "OTHER",
                        linkedLineId: statement.columnInt(2),
                        linkedBookId: statement.columnInt(3),
                        linkedLineIndex: statement.columnInt(4),
                        bookTitle: statement.columnString(5) ?? "ללא שם",
                        bookPath: statement.columnString(6),
                        heRef: statement.columnString(7),
                        content: statement.columnString(8) ?? ""
                    )
                )
            }
            return sources
        }
    }
}
