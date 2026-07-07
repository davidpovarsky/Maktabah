import Foundation

final class OtzariaReadingUnitService {
    private struct TocEntry {
        let id: Int
        let parentId: Int?
        let text: String
        let level: Int
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
        let includeDescendants: Bool
    }

    private struct BookIndex {
        let entriesById: [Int: TocEntry]
        let childrenByParentId: [Int: [Int]]
        let leafEntryByLineIndex: [Int: Int]
    }

    private let db: SQLiteDatabase
    private var indexCache: [Int: BookIndex] = [:]
    private var summariesCache: [String: [UnitSummary]] = [:]
    private static let maxSourceLineCount = 120
    private static let maxHTMLCharacterCount = 25_000

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func availableModes(bookId: Int) throws -> [OtzariaUnitLevelOption] {
        [
            OtzariaUnitLevelOption(id: OtzariaUnitMode.line.storageValue, title: "Line", level: nil, mode: .line),
            OtzariaUnitLevelOption(id: OtzariaUnitMode.paragraph.storageValue, title: "Paragraph", level: nil, mode: .paragraph),
            OtzariaUnitLevelOption(id: OtzariaUnitMode.chapter.storageValue, title: "Chapter", level: nil, mode: .chapter)
        ]
    }

    func readingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let unit = try readingUnitWithoutFallback(bookId: bookId, containingLineIndex: lineIndex, mode: mode)
            ?? fallbackUnit(bookId: bookId, lineIndex: lineIndex, failedMode: mode)
        log("readingUnit bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    func firstReadingUnit(bookId: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let summary = try unitSummaries(bookId: bookId, mode: mode).first
            ?? (mode == .line ? nil : try unitSummaries(bookId: bookId, mode: .line).first)
        var unit = try summary.flatMap(buildUnit(from:))
        if unit == nil, mode != .line {
            log("fallback \(mode.storageValue)->line firstReadingUnit bookId=\(bookId)")
            unit = try unitSummaries(bookId: bookId, mode: .line).first.flatMap(buildUnit(from:))
        }
        log("firstReadingUnit bookId=\(bookId) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    func nextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.endLineIndex ?? lineIndex
        var unit = try summaries.first(where: { $0.startLineIndex > threshold }).flatMap(buildUnit(from:))
        if unit == nil, mode != .line {
            log("fallback \(mode.storageValue)->line nextReadingUnit bookId=\(bookId) lineIndex=\(lineIndex)")
            let lineSummaries = try unitSummaries(bookId: bookId, mode: .line)
            unit = try lineSummaries.first(where: { $0.startLineIndex > lineIndex }).flatMap(buildUnit(from:))
        }
        log("nextReadingUnit bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    func previousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.startLineIndex ?? lineIndex
        var unit = try summaries.last(where: { $0.endLineIndex < threshold }).flatMap(buildUnit(from:))
        if unit == nil, mode != .line {
            log("fallback \(mode.storageValue)->line previousReadingUnit bookId=\(bookId) lineIndex=\(lineIndex)")
            let lineSummaries = try unitSummaries(bookId: bookId, mode: .line)
            unit = try lineSummaries.last(where: { $0.endLineIndex < lineIndex }).flatMap(buildUnit(from:))
        }
        log("previousReadingUnit bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    private func readingUnitWithoutFallback(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        guard let summary = summaries.first(where: { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex })
                ?? summaries.last(where: { $0.startLineIndex <= lineIndex })
                ?? summaries.first(where: { $0.startLineIndex > lineIndex }) else {
            return nil
        }
        return try buildUnit(from: summary)
    }

    private func fallbackUnit(bookId: Int, lineIndex: Int, failedMode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        switch failedMode {
        case .line:
            return nil
        case .paragraph:
            log("fallback paragraph->line bookId=\(bookId) lineIndex=\(lineIndex)")
            return try readingUnitWithoutFallback(bookId: bookId, containingLineIndex: lineIndex, mode: .line)
        case .chapter:
            log("fallback chapter->paragraph bookId=\(bookId) lineIndex=\(lineIndex)")
            return try readingUnitWithoutFallback(bookId: bookId, containingLineIndex: lineIndex, mode: .paragraph)
                ?? fallbackUnit(bookId: bookId, lineIndex: lineIndex, failedMode: .paragraph)
        }
    }

    private func unitSummaries(bookId: Int, mode: OtzariaUnitMode) throws -> [UnitSummary] {
        let start = Date()
        let cacheKey = "\(bookId):\(mode.storageValue)"
        if let cached = summariesCache[cacheKey] { return cached }

        let summaries: [UnitSummary]
        switch mode {
        case .line:
            summaries = try lineSummaries(bookId: bookId)
        case .paragraph:
            summaries = try paragraphSummaries(bookId: bookId)
        case .chapter:
            summaries = try chapterSummaries(bookId: bookId)
        }

        summariesCache[cacheKey] = summaries
        log("unitSummaries bookId=\(bookId) mode=\(mode.storageValue) count=\(summaries.count) durationMs=\(elapsedMs(start))")
        return summaries
    }

    private func lineSummaries(bookId: Int) throws -> [UnitSummary] {
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
                sourceLineIndices: [lineIndex],
                includeDescendants: false
            )
        }
    }

    private func paragraphSummaries(bookId: Int) throws -> [UnitSummary] {
        let index = try bookIndex(bookId: bookId)
        guard !index.leafEntryByLineIndex.isEmpty else {
            log("paragraph fallback no line_toc mappings bookId=\(bookId)")
            return try lineSummaries(bookId: bookId)
        }
        return try tocSummaries(bookId: bookId, includeDescendants: false, entryIdForLeaf: { leafId in leafId })
    }

    private func chapterSummaries(bookId: Int) throws -> [UnitSummary] {
        let index = try bookIndex(bookId: bookId)
        guard !index.leafEntryByLineIndex.isEmpty else {
            log("chapter fallback no line_toc mappings bookId=\(bookId)")
            return try paragraphSummaries(bookId: bookId)
        }

        let summaries = try tocSummaries(bookId: bookId, includeDescendants: true) { leafId in
            chapterEntryId(forLeaf: leafId, index: index)
        }
        guard !summaries.isEmpty else {
            log("chapter fallback empty summaries bookId=\(bookId)")
            return try paragraphSummaries(bookId: bookId)
        }
        return summaries
    }

    private func tocSummaries(bookId: Int, includeDescendants: Bool, entryIdForLeaf: (Int) -> Int) throws -> [UnitSummary] {
        let index = try bookIndex(bookId: bookId)
        var orderedEntryIds: [Int] = []
        var lineIndicesByUnitId: [Int: [Int]] = [:]

        for (lineIndex, leafId) in index.leafEntryByLineIndex.sorted(by: { $0.key < $1.key }) {
            let unitId = entryIdForLeaf(leafId)
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
                sourceLineIndices: sourceLineIndices.sorted(),
                includeDescendants: includeDescendants
            )
        }.sorted { $0.startLineIndex < $1.startLineIndex }
    }

    private func chapterEntryId(forLeaf leafId: Int, index: BookIndex) -> Int {
        var currentId = leafId
        var bestId = leafId
        var visited = Set<Int>()

        while let entry = index.entriesById[currentId] {
            guard visited.insert(currentId).inserted else {
                log("cycle detected ascending tocEntryId=\(currentId)")
                return bestId
            }
            guard let parentId = entry.parentId, let parent = index.entriesById[parentId] else {
                return bestId
            }
            if parent.parentId != nil {
                bestId = parent.id
            }
            currentId = parent.id
        }

        return bestId
    }

    private func descendantEntryIds(including rootId: Int, index: BookIndex) -> [Int] {
        var result: [Int] = []
        var stack = [rootId]
        var visited = Set<Int>()

        while let current = stack.popLast() {
            guard visited.insert(current).inserted else {
                log("cycle detected descending tocEntryId=\(current)")
                continue
            }
            result.append(current)
            stack.append(contentsOf: index.childrenByParentId[current] ?? [])
        }

        return result
    }

    private func buildUnit(from summary: UnitSummary) throws -> OtzariaReadingUnit? {
        let lines = limitedLines(try sourceLines(for: summary))
        guard !lines.isEmpty else { return nil }
        let html = lines.map(\.html).joined(separator: "\n")
        var plainSegments: [String] = []
        var lineAnchors: [OtzariaLineAnchor] = []
        var currentOffset = 0

        for line in lines {
            let plain = line.html.otsariaPlainText
            plainSegments.append(plain)
            lineAnchors.append(
                OtzariaLineAnchor(
                    id: line.id,
                    bookId: summary.bookId,
                    lineIndex: line.lineIndex,
                    heRef: line.heRef,
                    text: plain,
                    range: NSRange(location: currentOffset, length: (plain as NSString).length)
                )
            )
            currentOffset += (plain as NSString).length + 1
        }

        let plainText = plainSegments.joined(separator: "\n")
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
            lineAnchors: lineAnchors,
            html: html,
            plainText: plainText,
            heRef: firstRef
        )
    }

    private func sourceLines(for summary: UnitSummary) throws -> [SourceLine] {
        let start = Date()
        let lines: [SourceLine]

        if let tocEntryId = summary.tocEntryId {
            let entryIds: [Int]
            if summary.includeDescendants {
                let index = try bookIndex(bookId: summary.bookId)
                entryIds = descendantEntryIds(including: tocEntryId, index: index)
            } else {
                entryIds = [tocEntryId]
            }
            lines = try sourceLines(bookId: summary.bookId, tocEntryIds: entryIds)
        } else {
            lines = try db.fetch(query: """
                SELECT id, lineIndex, content, heRef
                FROM line
                WHERE bookId = ? AND lineIndex = ?
                LIMIT 1
            """, parameters: [summary.bookId, summary.startLineIndex], mapping: mapSourceLine)
        }

        log("sourceLines bookId=\(summary.bookId) tocEntryId=\(summary.tocEntryId.map(String.init) ?? "nil") start=\(summary.startLineIndex) count=\(lines.count) durationMs=\(elapsedMs(start))")
        return lines
    }

    private func sourceLines(bookId: Int, tocEntryIds: [Int]) throws -> [SourceLine] {
        guard !tocEntryIds.isEmpty else { return [] }
        var allLines: [SourceLine] = []

        for chunkStart in stride(from: 0, to: tocEntryIds.count, by: 900) {
            let chunk = Array(tocEntryIds[chunkStart..<min(chunkStart + 900, tocEntryIds.count)])
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            var parameters: [Any] = [bookId]
            parameters.append(contentsOf: chunk)

            let lines = try db.fetch(query: """
                SELECT DISTINCT l.id, l.lineIndex, l.content, l.heRef
                FROM line_toc lt
                JOIN line l ON l.id = lt.lineId
                WHERE l.bookId = ?
                AND lt.tocEntryId IN (\(placeholders))
                ORDER BY l.lineIndex
                LIMIT \(Self.maxSourceLineCount)
            """, parameters: parameters, mapping: mapSourceLine)
            allLines.append(contentsOf: lines)
            if allLines.count >= Self.maxSourceLineCount {
                break
            }
        }

        return Dictionary(grouping: allLines, by: \.id)
            .compactMap { $0.value.first }
            .sorted { $0.lineIndex < $1.lineIndex }
            .prefix(Self.maxSourceLineCount)
            .map { $0 }
    }

    private func limitedLines(_ lines: [SourceLine]) -> [SourceLine] {
        var limited: [SourceLine] = []
        var htmlCount = 0

        for line in lines.prefix(Self.maxSourceLineCount) {
            let nextCount = htmlCount + line.html.count
            if !limited.isEmpty && nextCount > Self.maxHTMLCharacterCount {
                break
            }
            limited.append(line)
            htmlCount = nextCount
        }

        if limited.count < lines.count {
            log("limited unit sourceLines=\(lines.count)->\(limited.count) htmlCount=\(htmlCount)")
        }

        return limited
    }

    private func mapSourceLine(_ row: SQLiteRow) -> SourceLine {
        SourceLine(id: row.int(at: 0), lineIndex: row.int(at: 1), html: row.string(at: 2) ?? "", heRef: row.string(at: 3))
    }

    private func bookIndex(bookId: Int) throws -> BookIndex {
        if let cached = indexCache[bookId] { return cached }
        let start = Date()

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
                level: row.int(at: 3)
            )
        }

        var entriesById: [Int: TocEntry] = [:]
        var childrenByParentId: [Int: [Int]] = [:]

        for entry in entries {
            entriesById[entry.id] = entry
            if let parentId = entry.parentId {
                childrenByParentId[parentId, default: []].append(entry.id)
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
            leafEntryByLineIndex: leafEntryByLineIndex
        )
        indexCache[bookId] = index
        log("bookIndex bookId=\(bookId) tocEntries=\(entries.count) lineTocMappings=\(mappings.count) durationMs=\(elapsedMs(start))")
        return index
    }

    private func unitSummary(_ unit: OtzariaReadingUnit?) -> String {
        guard let unit else { return "unit=nil" }
        return "modeUnitId=\(unit.id) tocEntryId=\(unit.tocEntryId.map(String.init) ?? "nil") startLineIndex=\(unit.startLineIndex) endLineIndex=\(unit.endLineIndex) sourceLineCount=\(unit.sourceLineIndices.count) plainTextCount=\(unit.plainText.count) htmlCount=\(unit.html.count) heRef=\(unit.heRef ?? "")"
    }

    private func log(_ message: String) {
        OtzariaFileLogger.shared.log("[OtzariaReadingUnitService] \(message)")
    }

    private func elapsedMs(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}
