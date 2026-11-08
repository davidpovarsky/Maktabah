import Foundation

struct OtzariaAlternativeTOCRepository: Sendable {
    var context: OtzariaSchemaAwareReadContext = .shared
    private struct Entry {
        let id: Int
        let parentID: Int?
        let title: String
        let lineIndex: Int?
        let invalidAnchor: Bool
    }

    func structures(for workKey: String, hebrew: Bool) async throws -> [LibraryNavigationStructure] {
        try await context.read { database, capabilities in
            guard capabilities.hasAlternateTOC, capabilities.hasTable("tocText") else { return [] }
            let bookID = try OtzariaCanonicalLineLocatorResolver.bookID(for: workKey, database: database, capabilities: capabilities)
            let structures = try database.fetch(query: "SELECT id, key, title, heTitle FROM alt_toc_structure WHERE bookId = ? ORDER BY key, id",
                parameters: [bookID]) { ($0.int(at: 0), $0.string(at: 1) ?? "", $0.string(at: 2), $0.string(at: 3)) }
            return try structures.map { structure in
                let rows = try database.fetch(query: """
                    SELECT e.id, e.parentId, tt.text, l.lineIndex, e.lineId
                    FROM alt_toc_entry e JOIN tocText tt ON tt.id = e.textId
                    LEFT JOIN line l ON l.id = e.lineId AND l.bookId = ?
                    WHERE e.structureId = ? ORDER BY COALESCE(l.lineIndex, 0), e.level, e.id
                    """, parameters: [bookID, structure.0]) { row in
                    Entry(id: row.int(at: 0), parentID: row.isNull(at: 1) ? nil : row.int(at: 1),
                          title: row.string(at: 2) ?? "", lineIndex: row.isNull(at: 3) ? nil : row.int(at: 3),
                          invalidAnchor: !row.isNull(at: 4) && row.isNull(at: 3))
                }
                let children = Dictionary(grouping: rows.filter { $0.parentID != nil }, by: { $0.parentID! })
                var visited = Set<Int>()
                var entryAnchors: [Int: Int] = [:]
                func node(_ entry: Entry, depth: Int) throws -> LibraryTOCNode? {
                    try Task.checkCancellation()
                    guard !entry.invalidAnchor, depth < 256, visited.insert(entry.id).inserted else { return nil }
                    let descendants = try (children[entry.id] ?? []).compactMap { try node($0, depth: depth + 1) }
                    let line = entry.lineIndex ?? descendants.first.flatMap {
                        if case .legacyLine(let index) = $0.locator.position { return index }
                        return nil
                    }
                    guard let line else { return nil }
                    entryAnchors[entry.id] = line
                    return .init(locator: .init(backend: .otzaria, workKey: workKey, position: .legacyLine(line)),
                        title: entry.title, children: descendants)
                }
                // Orphans and cycles are not invented roots; a missing target is not a valid location.
                let roots = rows.filter { $0.parentID == nil }
                let nodes = try roots.compactMap { try node($0, depth: 0) }
                let title = hebrew ? (structure.3 ?? structure.2 ?? structure.1) : (structure.2 ?? structure.3 ?? structure.1)
                var result = LibraryNavigationStructure(id: "otzaria-alt:\(structure.0):\(structure.1)", title: title, nodes: nodes)
                result.lineCoverage = [:]
                if ["lineId", "structureId", "altTocEntryId"].allSatisfy({ capabilities.hasColumn($0, in: "line_alt_toc") }) {
                    var coverage: [Int: Int] = [:]
                    var ambiguous = Set<Int>()
                    var afterID = Int.min
                    while true {
                        try Task.checkCancellation()
                        let page = try database.fetch(query: """
                            SELECT l.id, l.lineIndex, a.altTocEntryId FROM line_alt_toc a
                            JOIN line l ON l.id = a.lineId
                            WHERE a.structureId = ? AND l.bookId = ? AND l.id > ?
                            ORDER BY l.id LIMIT 400
                            """, parameters: [structure.0, bookID, afterID]) { ($0.int(at: 0), $0.int(at: 1), $0.int(at: 2)) }
                        guard let last = page.last else { break }
                        for row in page {
                            guard let anchor = entryAnchors[row.2] else { continue }
                            if coverage[row.1] != nil { ambiguous.insert(row.1) }
                            coverage[row.1] = anchor
                        }
                        afterID = last.0
                    }
                    for line in ambiguous { coverage.removeValue(forKey: line) }
                    result.lineCoverage = coverage
                }
                return result
            }.filter { !$0.nodes.isEmpty }
        }
    }
}
