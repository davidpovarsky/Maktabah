import Foundation

final class OtzariaReadingUnitService {
    private struct TocEntry {
        let id: Int
        let parentId: Int?
        let text: String
        let level: Int
        let lineIndex: Int?
    }

    private struct SourceLine {
        let id: Int
        let lineIndex: Int
        let html: String
        let heRef: String?
    }

    private struct UnitSummary {
        let key: String
        let bookId: Int
        let tocEntryId: Int?
        let title: String?
        let level: Int?
        let startLineIndex: Int
        let endLineIndex: Int
        let sourceLineIndices: [Int]
    }

    private struct BookIndex {
        let entriesById: [Int: TocEntry]
        let childrenByParentId: [Int: [Int]]
        let leafEntryByLineIndex: [Int: Int]
        let levelTitles: [Int: String]
    }

    private let db: SQLiteDatabase
    private var indexCache: [Int: BookIndex] = [:]
    private var summariesCache: [String: [UnitSummary]] = [:]

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func availableModes(bookId: Int) throws -> [OtzariaUnitLevelOption] {
        let index = try bookIndex(bookId: bookId)
        var options = [
            OtzariaUnitLevelOption(id: OtzariaUnitMode.automatic.storageValue, title: "Automatic", level: nil, mode: .automatic)
        ]

        for level in index.levelTitles.keys.sorted() {
            options.append(
                OtzariaUnitLevelOption(
                    id: OtzariaUnitMode.tocLevel(level).storageValue,
                    title: index.levelTitles[level] ?? "Level \(level)",
                    level: level,
                    mode: .tocLevel(level)
                )
            )
        }

        if !index.entriesById.isEmpty {
            options.append(OtzariaUnitLevelOption(id: OtzariaUnitMode.leaf.storageValue, title: "Leaf / Most specific", level: nil, mode: .leaf))
        }
        options.append(OtzariaUnitLevelOption(id: OtzariaUnitMode.sourceLine.storageValue, title: "Source line", level: nil, mode: .sourceLine))
        return options
    }

    func readingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let summaries = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode))
        guard let summary = summaries.first(where: { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex })
                ?? summaries.last(where: { $0.startLineIndex <= lineIndex })
                ?? summaries.first(where: { $0.startLineIndex > lineIndex }) else {
            return nil
        }
        return try buildUnit(from: summary)
    }

    func firstReadingUnit(bookId: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        guard let first = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode)).first else { return nil }
        return try buildUnit(from: first)
    }

    func nextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let summaries = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode))
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.endLineIndex ?? lineIndex
        guard let next = summaries.first(where: { $0.startLineIndex > threshold }) else { return nil }
        return try buildUnit(from: next)
    }

    func previousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let summaries = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode))
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.startLineIndex ?? lineIndex
        guard let previous = summaries.last(where: { $0.endLineIndex < threshold }) else { return nil }
        return try buildUnit(from: previous)
    }

    func readingUnitsWindow(bookId: Int, aroundLineIndex lineIndex: Int, mode: OtzariaUnitMode, before: Int, after: Int) throws -> [OtzariaReadingUnit] {
        let summaries = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode))
        guard !summaries.isEmpty else { return [] }
        let center = summaries.firstIndex { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
            ?? summaries.lastIndex(where: { $0.startLineIndex <= lineIndex })
            ?? 0
        let lower = max(0, center - before)
        let upper = min(summaries.count - 1, center + after)
        return try summaries[lower...upper].compactMap { try buildUnit(from: $0) }
    }

    private func resolvedMode(bookId: Int, mode: OtzariaUnitMode) throws -> OtzariaUnitMode {
        guard mode == .automatic else { return mode }
        let levels = try bookIndex(bookId: bookId).levelTitles.keys.sorted()
        guard !levels.isEmpty else { return .sourceLine }
        guard levels.count > 1 else { return .tocLevel(levels[0]) }
        if let first = levels.first, let last = levels.last, last - first <= 1 {
            return .tocLevel(last)
        }
        return .leaf
    }

    private func unitSummaries(bookId: Int, mode: OtzariaUnitMode) throws -> [UnitSummary] {
        let cacheKey = "\(bookId):\(mode.storageValue)"
        if let cached = summariesCache[cacheKey] { return cached }

        let summaries: [UnitSummary]
        switch mode {
        case .automatic:
            summaries = try unitSummaries(bookId: bookId, mode: resolvedMode(bookId: bookId, mode: mode))
        case .sourceLine:
            summaries = try sourceLineSummaries(bookId: bookId)
        case .leaf:
            summaries = try tocSummaries(bookId: bookId, level: nil)
        case .tocLevel(let level):
            summaries = try tocSummaries(bookId: bookId, level: level)
        }

        summariesCache[cacheKey] = summaries
        return summaries
    }

    private func sourceLineSummaries(bookId: Int) throws -> [UnitSummary] {
        try db.fetch(query: """
            SELECT lineIndex
            FROM line
            WHERE bookId = ?
            ORDER BY lineIndex
        """, parameters: [bookId]) { row in
            let lineIndex = row.int(at: 0)
            return UnitSummary(
                key: "line:\(lineIndex)",
                bookId: bookId,
                tocEntryId: nil,
                title: nil,
                level: nil,
                startLineIndex: lineIndex,
                endLineIndex: lineIndex,
                sourceLineIndices: [lineIndex]
            )
        }
    }

    private func tocSummaries(bookId: Int, level: Int?) throws -> [UnitSummary] {
        let index = try bookIndex(bookId: bookId)
        guard !index.leafEntryByLineIndex.isEmpty else {
            return try sourceLineSummaries(bookId: bookId)
        }

        var orderedEntryIds: [Int] = []
        var lineIndicesByUnitId: [Int: [Int]] = [:]

        for (lineIndex, leafId) in index.leafEntryByLineIndex.sorted(by: { $0.key < $1.key }) {
            let unitId = unitEntryId(forLeaf: leafId, requestedLevel: level, index: index)
            if lineIndicesByUnitId[unitId] == nil {
                orderedEntryIds.append(unitId)
            }
            lineIndicesByUnitId[unitId, default: []].append(lineIndex)
        }

        return orderedEntryIds.compactMap { entryId in
            guard let entry = index.entriesById[entryId],
                  let sourceLineIndices = lineIndicesByUnitId[entryId],
                  let start = sourceLineIndices.min(),
                  let end = sourceLineIndices.max() else {
                return nil
            }

            return UnitSummary(
                key: "toc:\(entryId)",
                bookId: bookId,
                tocEntryId: entryId,
                title: entry.text.otsariaPlainText,
                level: entry.level,
                startLineIndex: start,
                endLineIndex: end,
                sourceLineIndices: sourceLineIndices.sorted()
            )
        }.sorted { $0.startLineIndex < $1.startLineIndex }
    }

    private func unitEntryId(forLeaf leafId: Int, requestedLevel: Int?, index: BookIndex) -> Int {
        guard let requestedLevel else { return leafId }
        var currentId = leafId
        var bestId = leafId
        while let entry = index.entriesById[currentId] {
            if entry.level <= requestedLevel {
                bestId = currentId
                break
            }
            guard let parentId = entry.parentId else { break }
            bestId = parentId
            currentId = parentId
        }
        return bestId
    }

    private func descendantEntryIds(including rootId: Int, index: BookIndex) -> [Int] {
        var result: [Int] = []
        var stack = [rootId]
        while let current = stack.popLast() {
            result.append(current)
            stack.append(contentsOf: index.childrenByParentId[current] ?? [])
        }
        return result
    }

    private func buildUnit(from summary: UnitSummary) throws -> OtzariaReadingUnit? {
        let lines = try sourceLines(for: summary)
        guard !lines.isEmpty else { return nil }
        let html = lines.map(\.html).joined(separator: "\n")
        let firstRef = lines.first(where: { ($0.heRef ?? "").isEmpty == false })?.heRef

        return OtzariaReadingUnit(
            id: summary.key,
            bookId: summary.bookId,
            tocEntryId: summary.tocEntryId,
            title: summary.title,
            level: summary.level,
            startLineIndex: lines.first?.lineIndex ?? summary.startLineIndex,
            endLineIndex: lines.last?.lineIndex ?? summary.endLineIndex,
            sourceLineIndices: lines.map(\.lineIndex),
            html: html,
            plainText: html.otsariaPlainText,
            heRef: firstRef
        )
    }

    private func sourceLines(for summary: UnitSummary) throws -> [SourceLine] {
        if let tocEntryId = summary.tocEntryId {
            let index = try bookIndex(bookId: summary.bookId)
            let entryIds = descendantEntryIds(including: tocEntryId, index: index)
            let placeholders = Array(repeating: "?", count: entryIds.count).joined(separator: ",")
            var parameters: [Any] = [summary.bookId]
            parameters.append(contentsOf: entryIds)

            return try db.fetch(query: """
                SELECT DISTINCT l.id, l.lineIndex, l.content, l.heRef
                FROM line_toc lt
                JOIN line l ON l.id = lt.lineId
                WHERE l.bookId = ?
                AND lt.tocEntryId IN (\(placeholders))
                ORDER BY l.lineIndex
            """, parameters: parameters, mapping: mapSourceLine)
        }

        return try db.fetch(query: """
            SELECT id, lineIndex, content, heRef
            FROM line
            WHERE bookId = ? AND lineIndex = ?
            ORDER BY lineIndex
        """, parameters: [summary.bookId, summary.startLineIndex], mapping: mapSourceLine)
    }

    private func mapSourceLine(_ row: SQLiteRow) -> SourceLine {
        SourceLine(id: row.int(at: 0), lineIndex: row.int(at: 1), html: row.string(at: 2) ?? "", heRef: row.string(at: 3))
    }

    private func bookIndex(bookId: Int) throws -> BookIndex {
        if let cached = indexCache[bookId] { return cached }

        let entries = try db.fetch(query: """
            SELECT te.id, te.parentId, COALESCE(tt.text, ''), COALESCE(te.level, 0)
            FROM tocEntry te
            LEFT JOIN tocText tt ON tt.id = te.textId
            WHERE te.bookId = ?
            ORDER BY COALESCE(te.lineIndex, 0), te.id
        """, parameters: [bookId]) { row in
            TocEntry(
                id: row.int(at: 0),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1),
                text: row.string(at: 2) ?? "",
                level: row.int(at: 3),
                lineIndex: nil
            )
        }

        var entriesById: [Int: TocEntry] = [:]
        var childrenByParentId: [Int: [Int]] = [:]
        var levelTitles: [Int: String] = [:]

        for entry in entries {
            entriesById[entry.id] = entry
            if let parentId = entry.parentId {
                childrenByParentId[parentId, default: []].append(entry.id)
            }
            if entry.level > 0, levelTitles[entry.level] == nil {
                let title = entry.text.otsariaPlainText
                levelTitles[entry.level] = title.isEmpty ? "Level \(entry.level)" : title
            }
        }

        let mappings = try db.fetch(query: """
            SELECT l.lineIndex, lt.tocEntryId
            FROM line_toc lt
            JOIN line l ON l.id = lt.lineId
            WHERE l.bookId = ?
            ORDER BY l.lineIndex
        """, parameters: [bookId]) { row in
            (lineIndex: row.int(at: 0), tocEntryId: row.int(at: 1))
        }

        var leafEntryByLineIndex: [Int: Int] = [:]
        for mapping in mappings {
            leafEntryByLineIndex[mapping.lineIndex] = mapping.tocEntryId
        }

        let index = BookIndex(
            entriesById: entriesById,
            childrenByParentId: childrenByParentId,
            leafEntryByLineIndex: leafEntryByLineIndex,
            levelTitles: levelTitles
        )
        indexCache[bookId] = index
        return index
    }
}
