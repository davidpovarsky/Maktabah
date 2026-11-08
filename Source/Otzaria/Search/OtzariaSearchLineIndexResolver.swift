import Foundation

/// v7 segment addresses count raw text lines, including embedded newlines and restored note bodies.
/// Resolve those ordinals through real SQLite rows; never equate them with a primary key or lineIndex.
enum OtzariaSearchLineIndexResolver {
    static func resolve(ordinals: Set<UInt64>, bookID: Int, database: SQLiteDatabase,
                        capabilities: OtzariaDatabaseCapabilities) throws -> [UInt64: Int] {
        guard !ordinals.isEmpty else { return [:] }
        let decoder = try OtzariaLineContentDecoder(database: database, capabilities: capabilities)
        let projection = OtzariaLineContentCompatibility.projection(capabilities: capabilities)
        var resolved: [UInt64: Int] = [:]
        var textOrdinal: UInt64 = 0
        var lastLine = Int.min
        var rawOrdinal: UInt64 = 0
        while resolved.count < ordinals.count {
            try Task.checkCancellation()
            let rows = try database.fetch(query: """
                SELECT l.id, l.lineIndex, \(projection.expression) FROM line l \(projection.join)
                WHERE l.bookId = ? AND l.lineIndex > ? ORDER BY l.lineIndex LIMIT 400
                """, parameters: [bookID, lastLine]) { row in
                (id: row.int(at: 0), line: row.int(at: 1), text: try decoder.decode(row: row, at: 2))
            }
            guard !rows.isEmpty else { throw LibraryBackendError.invalidResponse("Search source ordinal is outside the canonical book") }
            let rawEnd = rows.reduce(rawOrdinal) { $0 + UInt64($1.text.utf8.filter { $0 == 10 }.count) + 1 }
            var noteBreaks: [UInt64: UInt64] = [:]
            if capabilities.hasTable("line_note") {
                // The original engine assigns notes by raw joined-text ordinal (before
                // restored note newlines), not by the row's primary key or its position.
                let notes = try database.fetch(query: """
                    SELECT l.lineIndex, n.body FROM line_note n JOIN line l ON l.id = n.lineId
                    WHERE l.bookId = ? AND l.lineIndex >= ? AND l.lineIndex < ?
                    ORDER BY l.lineIndex, n.noteIndex LIMIT 10001
                    """, parameters: [bookID, Int(rawOrdinal), Int(rawEnd)]) { row in
                    (row.int(at: 0), try decoder.decode(row: row, at: 1))
                }
                guard notes.count <= 10000 else { throw LibraryBackendError.invalidResponse("Search note batch exceeds supported bounds") }
                for (line, body) in notes {
                    guard !(body.contains("data:") && body.contains("\n")) else {
                        throw LibraryBackendError.invalidResponse("Search source has an unsupported multiline data URI")
                    }
                    noteBreaks[UInt64(line), default: 0] += UInt64(body.utf8.filter { $0 == 10 }.count)
                }
            }
            for row in rows {
                guard row.line > lastLine else { throw LibraryBackendError.invalidLocator }
                guard !(row.text.contains("data:") && row.text.contains("\n")) else {
                    throw LibraryBackendError.invalidResponse("Search source has an unsupported multiline data URI")
                }
                let rawCount = UInt64(row.text.utf8.filter { $0 == 10 }.count) + 1
                let noteCount = noteBreaks.filter { $0.key >= rawOrdinal && $0.key < rawOrdinal + rawCount }.values.reduce(0, +)
                guard noteCount == 0 || !row.text.lowercased().contains("footnote") else {
                    // Already restored body HTML suppresses upstream note insertion.
                    // Its exact HTML grammar must be resolved by Rust, never guessed here.
                    throw LibraryBackendError.invalidResponse("Search source note HTML needs an exact ordinal map")
                }
                let count = rawCount + noteCount
                rawOrdinal += rawCount
                let (end, overflow) = textOrdinal.addingReportingOverflow(count)
                guard !overflow else { throw LibraryBackendError.invalidLocator }
                for ordinal in ordinals where ordinal >= textOrdinal && ordinal < end { resolved[ordinal] = row.line }
                textOrdinal = end
                lastLine = row.line
                if resolved.count == ordinals.count { break }
            }
        }
        for line in Set(resolved.values) {
            _ = try OtzariaCanonicalLineLocatorResolver.locator(bookID: bookID, lineIndex: line, database: database)
        }
        return resolved
    }
}
