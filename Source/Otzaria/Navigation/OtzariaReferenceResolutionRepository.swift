import Foundation

struct OtzariaReferenceResolutionRepository: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    func resolve(workKey: String, reference: String) async throws -> [TextLocator] {
        try await context.read { database, capabilities in
            guard capabilities.hasTable("line_ref") else { throw LibraryBackendError.capabilityUnavailable }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: workKey, database: database, capabilities: capabilities)
            let title = try database.fetch(query: "SELECT title FROM book WHERE id = ?", parameters: [bookID]) { $0.string(at: 0) ?? "" }.first ?? ""
            guard let key = OtzariaReferenceKey.lineKey(reference, aliases: [title]) else { return [] }
            func candidates(_ key: String) throws -> [TextLocator] {
                let hash = Int(truncatingIfNeeded: OtzariaReferenceKey.hash(key))
                let lines = try database.fetch(query: """
                    SELECT DISTINCT l.lineIndex FROM line_ref r JOIN line l ON l.bookId = r.bookId AND l.lineIndex = r.lineIndex
                    WHERE r.bookId = ? AND r.refKeyHash = ? ORDER BY l.lineIndex LIMIT 101
                    """, parameters: [bookID, hash]) { $0.int(at: 0) }
                guard lines.count <= 100 else { throw LibraryBackendError.invalidResponse("Reference is too ambiguous") }
                return lines.map { .init(backend: .otzaria, workKey: workKey, position: .legacyLine($0)) }
            }
            let exact = try candidates(key)
            return exact.isEmpty ? try candidates("~ " + key) : exact
        }
    }

    func diburHamatchil(workKey: String, normalizedPrefix: String, limit: Int = 50) async throws -> [LibraryTOCNode] {
        guard !normalizedPrefix.isEmpty else { return [] }
        return try await context.read { database, capabilities in
            guard capabilities.hasTable("line_dh") else { throw LibraryBackendError.capabilityUnavailable }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: workKey, database: database, capabilities: capabilities)
            return try database.fetch(query: """
                SELECT l.lineIndex, d.dhDisplay FROM line_dh d JOIN line l ON l.bookId = d.bookId AND l.lineIndex = d.lineIndex
                WHERE d.bookId = ? AND d.dhText >= ? AND d.dhText < ? ORDER BY d.dhText, l.lineIndex LIMIT ?
                """, parameters: [bookID, normalizedPrefix, normalizedPrefix + "\u{10FFFF}", min(max(limit, 1), 100)]) { row in
                .init(locator: .init(backend: .otzaria, workKey: workKey, position: .legacyLine(row.int(at: 0))),
                    title: row.string(at: 1) ?? "", children: [])
            }
        }
    }
}
