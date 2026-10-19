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
        let mode: OtzariaUnitMode
        let tocEntryId: Int?
        let title: String?
        let level: Int?
        let startLineIndex: Int
        let endLineIndex: Int
        let sourceLineIndices: [Int]
        let includeDescendants: Bool

        func toDescriptor(previousStart: Int? = nil, nextStart: Int? = nil) -> OtzariaReadingUnitDescriptor {
            OtzariaReadingUnitDescriptor(
                id: key,
                bookId: bookId,
                mode: mode,
                includeDescendants: includeDescendants,
                tocEntryId: tocEntryId,
                title: title,
                level: level,
                startLineIndex: startLineIndex,
                endLineIndex: endLineIndex,
                sourceLineIndices: sourceLineIndices,
                heRef: nil,
                previousStartLineIndex: previousStart,
                nextStartLineIndex: nextStart
            )
        }
    }

    private struct BookIndex {
        let entriesById: [Int: TocEntry]
        let childrenByParentId: [Int: [Int]]
        let leafEntryByLineIndex: [Int: Int]
    }

    private let db: SQLiteDatabase
    private var indexCache: [Int: BookIndex] = [:]
    private var summariesCache: [String: [UnitSummary]] = [:]
    private var contentCapabilities: OtzariaDatabaseCapabilities?
    private var contentDecoder: OtzariaLineContentDecoder?

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func clearCaches() {
        indexCache.removeAll()
        summariesCache.removeAll()
    }

    func descriptor(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        guard let summary = summaries.first(where: { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex })
                ?? summaries.last(where: { $0.startLineIndex <= lineIndex })
                ?? summaries.first(where: { $0.startLineIndex > lineIndex }) else {
            return nil
        }
        let thresholdStart = summary.startLineIndex
        let thresholdEnd = summary.endLineIndex
        let prev = summaries.last(where: { $0.endLineIndex < thresholdStart })?.startLineIndex
        let next = summaries.first(where: { $0.startLineIndex > thresholdEnd })?.startLineIndex
        return summary.toDescriptor(previousStart: prev, nextStart: next)
    }

    func firstDescriptor(bookId: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        guard let summary = summaries.first ?? (mode == .line ? nil : try unitSummaries(bookId: bookId, mode: .line).first) else {
            return nil
        }
        let next = summaries.first(where: { $0.startLineIndex > summary.endLineIndex })?.startLineIndex
        return summary.toDescriptor(previousStart: nil, nextStart: next)
    }

    func nextDescriptor(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.endLineIndex ?? lineIndex
        guard let next = summaries.first(where: { $0.startLineIndex > threshold }) else {
            if mode != .line {
                let lineSummaries = try unitSummaries(bookId: bookId, mode: .line)
                return lineSummaries.first(where: { $0.startLineIndex > lineIndex })?.toDescriptor()
            }
            return nil
        }
        let prev = summaries.last(where: { $0.endLineIndex < next.startLineIndex })?.startLineIndex
        let nextNext = summaries.first(where: { $0.startLineIndex > next.endLineIndex })?.startLineIndex
        return next.toDescriptor(previousStart: prev, nextStart: nextNext)
    }

    func previousDescriptor(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.first { $0.startLineIndex <= lineIndex && lineIndex <= $0.endLineIndex }
        let threshold = current?.startLineIndex ?? lineIndex
        guard let prev = summaries.last(where: { $0.endLineIndex < threshold }) else {
            if mode != .line {
                let lineSummaries = try unitSummaries(bookId: bookId, mode: .line)
                return lineSummaries.last(where: { $0.endLineIndex < lineIndex })?.toDescriptor()
            }
            return nil
        }
        let prevPrev = summaries.last(where: { $0.endLineIndex < prev.startLineIndex })?.startLineIndex
        let next = summaries.first(where: { $0.startLineIndex > prev.endLineIndex })?.startLineIndex
        return prev.toDescriptor(previousStart: prevPrev, nextStart: next)
    }

    func buildUnit(from descriptor: OtzariaReadingUnitDescriptor) throws -> OtzariaReadingUnit? {
        let summary = UnitSummary(
            key: descriptor.id,
            bookId: descriptor.bookId,
            mode: descriptor.mode,
            tocEntryId: descriptor.tocEntryId,
            title: descriptor.title,
            level: descriptor.level,
            startLineIndex: descriptor.startLineIndex,
            endLineIndex: descriptor.endLineIndex,
            sourceLineIndices: descriptor.sourceLineIndices,
            includeDescendants: descriptor.includeDescendants
        )
        return try buildUnit(from: summary)
    }

    func availableModes(bookId: Int) throws -> [OtzariaUnitLevelOption] {
        [
            OtzariaUnitLevelOption(id: OtzariaUnitMode.line.storageValue, title: "Line", level: nil, mode: .line),
            OtzariaUnitLevelOption(id: OtzariaUnitMode.paragraph.storageValue, title: "Paragraph", level: nil, mode: .paragraph),
            OtzariaUnitLevelOption(id: OtzariaUnitMode.chapter.storageValue, title: "Chapter", level: nil, mode: .chapter)
        ]
    }

    func readingUnit(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let interval = OtzariaPerformanceTelemetry.shared.begin("ReadingUnitService.readingUnit")
        defer { interval.end(extra: "bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue)") }
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

        if summariesCache.count > 50 { summariesCache.removeAll() }
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
                mode: .line,
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
        return try tocSummaries(bookId: bookId, mode: .paragraph, includeDescendants: false, entryIdForLeaf: { leafId in leafId })
    }

    private func chapterSummaries(bookId: Int) throws -> [UnitSummary] {
        let index = try bookIndex(bookId: bookId)
        guard !index.leafEntryByLineIndex.isEmpty else {
            log("chapter fallback no line_toc mappings bookId=\(bookId)")
            return try paragraphSummaries(bookId: bookId)
        }

        let summaries = try tocSummaries(bookId: bookId, mode: .chapter, includeDescendants: true) { leafId in
            chapterEntryId(forLeaf: leafId, index: index)
        }
        guard !summaries.isEmpty else {
            log("chapter fallback empty summaries bookId=\(bookId)")
            return try paragraphSummaries(bookId: bookId)
        }
        return summaries
    }

    private func tocSummaries(
        bookId: Int,
        mode: OtzariaUnitMode,
        includeDescendants: Bool,
        entryIdForLeaf: (Int) -> Int
    ) throws -> [UnitSummary] {
        let interval = OtzariaPerformanceTelemetry.shared.begin("ReadingUnitService.tocSummaries")
        defer { interval.end(extra: "bookId=\(bookId) mode=\(mode.storageValue)") }
        let index = try bookIndex(bookId: bookId)

        // Root entry handling: identify roots with children and direct lines <= 3
        var rootTitleLinesByRootId: [Int: [Int]] = [:]
        for (entryId, entry) in index.entriesById where entry.parentId == nil {
            let children = index.childrenByParentId[entryId] ?? []
            if !children.isEmpty {
                let directLines = index.leafEntryByLineIndex.compactMap { lineIndex, leafId in
                    leafId == entryId ? lineIndex : nil
                }.sorted()
                if !directLines.isEmpty && directLines.count <= 3 {
                    rootTitleLinesByRootId[entryId] = directLines
                }
            }
        }

        var orderedEntryIds: [Int] = []
        var lineIndicesByUnitId: [Int: [Int]] = [:]
        var heldRootLinesByRootId: [Int: [Int]] = [:]

        for (lineIndex, leafId) in index.leafEntryByLineIndex.sorted(by: { $0.key < $1.key }) {
            if rootTitleLinesByRootId[leafId] != nil {
                heldRootLinesByRootId[leafId, default: []].append(lineIndex)
                continue
            }

            let unitId = entryIdForLeaf(leafId)
            let isNewUnit = (lineIndicesByUnitId[unitId] == nil)
            if isNewUnit {
                orderedEntryIds.append(unitId)
                lineIndicesByUnitId[unitId] = []

                // Associate held root title lines only with the first unit descending from that specific root
                let rootOfUnit = rootEntryId(for: unitId, index: index)
                if let held = heldRootLinesByRootId.removeValue(forKey: rootOfUnit) {
                    lineIndicesByUnitId[unitId]?.append(contentsOf: held)
                }
            }
            lineIndicesByUnitId[unitId, default: []].append(lineIndex)
        }

        // If there are still held root lines (e.g. no child units mapped for that root), attach them as standalone units
        if !heldRootLinesByRootId.isEmpty {
            for (rootId, lines) in heldRootLinesByRootId.sorted(by: { $0.key < $1.key }) {
                if lineIndicesByUnitId[rootId] == nil {
                    orderedEntryIds.insert(rootId, at: 0)
                    lineIndicesByUnitId[rootId] = lines
                }
            }
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
                mode: mode,
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

    private func rootEntryId(for entryId: Int, index: BookIndex) -> Int {
        var currentId = entryId
        var visited = Set<Int>()
        while let entry = index.entriesById[currentId] {
            guard visited.insert(currentId).inserted else { return currentId }
            guard let parentId = entry.parentId else { return currentId }
            currentId = parentId
        }
        return currentId
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
        guard let rootEntry = index.entriesById[rootId] else { return [rootId] }
        if rootEntry.parentId == nil && !(index.childrenByParentId[rootId]?.isEmpty ?? true) {
            return [rootId]
        }
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
        let lines = try sourceLines(for: summary)
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
                    range: NSRange(location: currentOffset, length: plain.utf16.count)
                )
            )
            currentOffset += plain.utf16.count + 1
        }

        let plainText = plainSegments.joined(separator: "\n")
        let firstRef = lines.first(where: { ($0.heRef ?? "").isEmpty == false })?.heRef

        return OtzariaReadingUnit(
            id: summary.key,
            bookId: summary.bookId,
            mode: summary.mode,
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
        let access = try lineContentAccess()

        let count = summary.endLineIndex - summary.startLineIndex + 1
        if count == summary.sourceLineIndices.count {
            // Contiguous line range: fast single-index scan on idx_line_book_index
            lines = try db.fetch(query: """
                SELECT l.id, l.lineIndex, \(access.projection.expression), l.heRef
                FROM line l
                \(access.projection.join)
                WHERE l.bookId = ? AND l.lineIndex >= ? AND l.lineIndex <= ?
                ORDER BY l.lineIndex
            """, parameters: [summary.bookId, summary.startLineIndex, summary.endLineIndex]) { row in
                try mapSourceLine(row, decoder: access.decoder)
            }
        } else if !summary.sourceLineIndices.isEmpty {
            // Discontiguous lines: chunked IN query
            var allLines: [SourceLine] = []
            for chunkStart in stride(from: 0, to: summary.sourceLineIndices.count, by: 900) {
                let chunk = Array(summary.sourceLineIndices[chunkStart..<min(chunkStart + 900, summary.sourceLineIndices.count)])
                let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ",")
                var parameters: [Any] = [summary.bookId]
                parameters.append(contentsOf: chunk)
                let chunkLines = try db.fetch(query: """
                    SELECT l.id, l.lineIndex, \(access.projection.expression), l.heRef
                    FROM line l
                    \(access.projection.join)
                    WHERE l.bookId = ? AND l.lineIndex IN (\(placeholders))
                    ORDER BY l.lineIndex
                """, parameters: parameters) { row in
                    try mapSourceLine(row, decoder: access.decoder)
                }
                allLines.append(contentsOf: chunkLines)
            }
            lines = allLines
        } else {
            lines = []
        }

        log("sourceLines bookId=\(summary.bookId) tocEntryId=\(summary.tocEntryId.map(String.init) ?? "nil") start=\(summary.startLineIndex) count=\(lines.count) durationMs=\(elapsedMs(start))")
        return lines
    }

    private func mapSourceLine(_ row: SQLiteRow, decoder: OtzariaLineContentDecoder) throws -> SourceLine {
        SourceLine(
            id: row.int(at: 0),
            lineIndex: row.int(at: 1),
            html: try decoder.decode(row: row, at: 2),
            heRef: row.string(at: 3)
        )
    }

    private func lineContentAccess() throws -> (
        projection: OtzariaLineContentProjection,
        decoder: OtzariaLineContentDecoder
    ) {
        let capabilities: OtzariaDatabaseCapabilities
        if let cached = contentCapabilities {
            capabilities = cached
        } else {
            capabilities = try OtzariaDatabaseCapabilities(database: db)
            contentCapabilities = capabilities
        }
        let decoder: OtzariaLineContentDecoder
        if let cached = contentDecoder {
            decoder = cached
        } else {
            decoder = try OtzariaLineContentDecoder(database: db, capabilities: capabilities)
            contentDecoder = decoder
        }
        return (
            OtzariaLineContentCompatibility.projection(capabilities: capabilities),
            decoder
        )
    }

    private func bookIndex(bookId: Int) throws -> BookIndex {
        if let cached = indexCache[bookId] { return cached }
        let start = Date()
        let schema = try OtzariaTOCSchemaCompatibility.projection(in: db)

        let entries = try db.fetch(query: """
            SELECT te.id, te.parentId, COALESCE(tt.text, ''), COALESCE(te.level, 0)
            FROM tocEntry te
            LEFT JOIN tocText tt ON tt.id = te.textId
            LEFT JOIN line ln ON ln.id = te.lineId
            WHERE te.bookId = ?
            ORDER BY COALESCE(\(schema.resolvedLineIndex), 0), te.id
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
        if indexCache.count > 20 { indexCache.removeAll() }
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
