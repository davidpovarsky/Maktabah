import Foundation

struct OtzariaLineNote: Sendable {
    let lineIndex: Int
    let noteIndex: Int
    let charPosition: Int
    let hasMarker: Bool
    let body: String
}

struct OtzariaDivineNameSpan: Sendable {
    let lineIndex: Int
    let noteIndex: Int?
    let charStart: Int
    let packedSpan: Int
}

struct OtzariaLineDecorations: Sendable {
    let notes: [OtzariaLineNote]
    let divineNames: [OtzariaDivineNameSpan]
    let banner: String?
    let protectionLevel: Int?
}

/// Exposes schema7 source facts; does not guess substitutions or alter user annotations.
struct OtzariaLineDecorationRepository: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    func decorations(for locator: TextLocator) async throws -> OtzariaLineDecorations {
        guard locator.backend == .otzaria, case .legacyLine(let lineIndex) = locator.position else {
            throw LibraryBackendError.invalidLocator
        }
        return try await context.read { database, capabilities in
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: locator.workKey, database: database, capabilities: capabilities)
            _ = try OtzariaCanonicalLineLocatorResolver.locator(bookID: bookID, lineIndex: lineIndex, database: database)
            let decoder = try OtzariaLineContentDecoder(database: database, capabilities: capabilities)
            var notes: [OtzariaLineNote] = []
            if capabilities.hasTable("line_note") {
                notes = try database.fetch(query: """
                    SELECT n.noteIndex, n.charPos, n.hasMarker, n.body FROM line_note n
                    JOIN line l ON l.id = n.lineId WHERE l.bookId = ? AND l.lineIndex = ? ORDER BY n.noteIndex
                    """, parameters: [bookID, lineIndex]) { row in
                    .init(lineIndex: lineIndex, noteIndex: row.int(at: 0), charPosition: row.int(at: 1),
                        hasMarker: row.int(at: 2) != 0, body: try decoder.decode(row: row, at: 3))
                }
            }
            var spans: [OtzariaDivineNameSpan] = []
            for (table, noteColumn) in [("line_divine_name", "NULL"), ("line_note_divine_name", "n.noteIndex")] where capabilities.hasTable(table) {
                spans += try database.fetch(query: """
                    SELECT \(noteColumn), n.charStart, n.span FROM \(table) n
                    JOIN line l ON l.id = n.lineId WHERE l.bookId = ? AND l.lineIndex = ? ORDER BY n.charStart
                    """, parameters: [bookID, lineIndex]) { row in
                    .init(lineIndex: lineIndex, noteIndex: row.isNull(at: 0) ? nil : row.int(at: 0),
                        charStart: row.int(at: 1), packedSpan: row.int(at: 2))
                }
            }
            let protection: Int? = capabilities.hasTable("book_protection")
                ? try database.fetch(query: "SELECT level FROM book_protection WHERE bookId = ?", parameters: [bookID]) { $0.int(at: 0) }.first : nil
            let banner: String? = capabilities.hasTable("book_banner") && capabilities.hasTable("banner")
                ? try database.fetch(query: "SELECT b.text FROM banner b JOIN book_banner bb ON bb.bannerId = b.id WHERE bb.bookId = ?", parameters: [bookID]) { $0.string(at: 0) }.first ?? nil : nil
            return .init(notes: notes, divineNames: spans, banner: banner, protectionLevel: protection)
        }
    }
}
