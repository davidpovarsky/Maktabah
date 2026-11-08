import Foundation

struct OtzariaLinkAnchor: Hashable, Sendable {
    let side: Int
    let lineIndex: Int
    let charStart: Int
    let charEnd: Int?
    let label: String?
}

struct OtzariaLinkAnchorRepository {
    static func anchors(linkIDs: [Int], bookID: Int, lines: Set<Int>, database: SQLiteDatabase,
                        capabilities: OtzariaDatabaseCapabilities) throws -> [Int: [OtzariaLinkAnchor]] {
        guard capabilities.hasTable("link_anchor") else { return [:] }
        var result: [Int: [OtzariaLinkAnchor]] = [:]
        let ids = Array(Set(linkIDs)).sorted()
        for offset in stride(from: 0, to: ids.count, by: 400) {
            try Task.checkCancellation()
            let chunk = Array(ids[offset..<min(offset + 400, ids.count)])
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            let rows = try database.fetch(query: """
                SELECT a.linkId, a.side, anchored.lineIndex, a.charStart, a.charEnd, a.label
                FROM link_anchor a JOIN link l ON l.id = a.linkId
                JOIN line anchored ON anchored.id = CASE a.side WHEN 0 THEN l.sourceLineId ELSE l.targetLineId END
                WHERE anchored.bookId = ? AND a.linkId IN (\(placeholders))
                ORDER BY a.linkId, a.side, a.charStart
                """, parameters: [bookID] + chunk.map { $0 as Any }) { row in
                (row.int(at: 0), OtzariaLinkAnchor(side: row.int(at: 1), lineIndex: row.int(at: 2),
                    charStart: row.int(at: 3), charEnd: row.isNull(at: 4) ? nil : row.int(at: 4), label: row.string(at: 5)))
            }
            for (linkID, anchor) in rows where lines.contains(anchor.lineIndex) && (0...1).contains(anchor.side)
                && anchor.charStart >= 0 && (anchor.charEnd == nil || anchor.charEnd! >= anchor.charStart) {
                result[linkID, default: []].append(anchor)
            }
        }
        return result
    }
}
