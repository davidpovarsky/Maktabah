import Foundation

enum OtzariaReadingUnitError: Error {
    case inconsistentSourceLines
}

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
        let lineIndices: [Int]
    }

    private let db: SQLiteDatabase
    private let cacheLock = NSLock()
    private var indexCache: [Int: BookIndex] = [:]
    private var summariesCache: [String: [UnitSummary]] = [:]
    private var contentCapabilities: OtzariaDatabaseCapabilities?
    private var contentDecoder: OtzariaLineContentDecoder?
    private var cacheGeneration: UInt64 = 0
    private var indexCacheCost = 0
    private var summariesCacheCost = 0
    private let maxIndexCacheCost = 100_000
    private let maxSummariesCacheCost = 200_000

    init(database: SQLiteDatabase) {
        self.db = database
    }

    func clearCaches() {
        cacheLock.withLock {
            indexCache.removeAll()
            summariesCache.removeAll()
            contentCapabilities = nil
            contentDecoder = nil
            indexCacheCost = 0
            summariesCacheCost = 0
            cacheGeneration &+= 1
        }
    }

    func descriptor(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        guard let index = summaries.firstIndex(where: { $0.sourceLineIndices.contains(lineIndex) }) else { return nil }
        return descriptor(at: index, in: summaries)
    }

    func firstDescriptor(bookId: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        var summaries = try unitSummaries(bookId: bookId, mode: mode)
        if summaries.isEmpty && mode != .line {
            summaries = try unitSummaries(bookId: bookId, mode: .line)
        }
        return summaries.isEmpty ? nil : descriptor(at: 0, in: summaries)
    }

    func nextDescriptor(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.firstIndex { $0.sourceLineIndices.contains(lineIndex) }
        guard let next = current.map({ $0 + 1 }) ?? summaries.firstIndex(where: { $0.startLineIndex > lineIndex }),
              summaries.indices.contains(next) else { return nil }
        return descriptor(at: next, in: summaries)
    }

    func previousDescriptor(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnitDescriptor? {
        let summaries = try unitSummaries(bookId: bookId, mode: mode)
        let current = summaries.firstIndex { $0.sourceLineIndices.contains(lineIndex) }
        guard let previous = current.map({ $0 - 1 }) ?? summaries.lastIndex(where: { $0.endLineIndex < lineIndex }),
              summaries.indices.contains(previous) else { return nil }
        return descriptor(at: previous, in: summaries)
    }

    private func descriptor(at index: Int, in summaries: [UnitSummary]) -> OtzariaReadingUnitDescriptor {
        summaries[index].toDescriptor(
            previousStart: index > 0 ? summaries[index - 1].startLineIndex : nil,
            nextStart: index + 1 < summaries.count ? summaries[index + 1].startLineIndex : nil
        )
    }

    func buildUnit(from descriptor: OtzariaReadingUnitDescriptor) throws -> OtzariaReadingUnit? {
        let indices = Array(Set(descriptor.sourceLineIndices)).sorted()
        guard let start = indices.first, let end = indices.last else { return nil }
        let summary = UnitSummary(
            key: descriptor.id,
            bookId: descriptor.bookId,
            mode: descriptor.mode,
            tocEntryId: descriptor.tocEntryId,
            title: descriptor.title,
            level: descriptor.level,
            startLineIndex: start,
            endLineIndex: end,
            sourceLineIndices: indices,
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
        let unit = try firstDescriptor(bookId: bookId, mode: mode).flatMap(buildUnit(from:))
        log("firstReadingUnit bookId=\(bookId) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    func nextReadingUnit(bookId: Int, afterLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let unit = try nextDescriptor(bookId: bookId, afterLineIndex: lineIndex, mode: mode).flatMap(buildUnit(from:))
        log("nextReadingUnit bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    func previousReadingUnit(bookId: Int, beforeLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        let start = Date()
        let unit = try previousDescriptor(bookId: bookId, beforeLineIndex: lineIndex, mode: mode).flatMap(buildUnit(from:))
        log("previousReadingUnit bookId=\(bookId) lineIndex=\(lineIndex) mode=\(mode.storageValue) result=\(unit == nil ? "nil" : "ok") \(unitSummary(unit)) durationMs=\(elapsedMs(start))")
        return unit
    }

    private func readingUnitWithoutFallback(bookId: Int, containingLineIndex lineIndex: Int, mode: OtzariaUnitMode) throws -> OtzariaReadingUnit? {
        try descriptor(bookId: bookId, containingLineIndex: lineIndex, mode: mode).flatMap(buildUnit(from:))
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
        try Task.checkCancellation()
        let start = Date()
        let cacheKey = "\(bookId):\(mode.storageValue)"
        let (cached, generation) = cacheLock.withLock { (summariesCache[cacheKey], cacheGeneration) }
        if let cached { return cached }

        let summaries: [UnitSummary]
        switch mode {
        case .line:
            summaries = try lineSummaries(bookId: bookId)
        case .paragraph:
            summaries = try paragraphSummaries(bookId: bookId)
        case .chapter:
            summaries = try chapterSummaries(bookId: bookId)
        }

        try Task.checkCancellation()
        let cost = summaries.count + summaries.reduce(0) { $0 + $1.sourceLineIndices.count + ($1.title?.utf16.count ?? 0) }
        cacheLock.withLock {
            guard generation == cacheGeneration, cost <= maxSummariesCacheCost else { return }
            if summariesCache[cacheKey] != nil { return }
            if summariesCache.count >= 50 || summariesCacheCost + cost > maxSummariesCacheCost {
                summariesCache.removeAll()
                summariesCacheCost = 0
            }
            summariesCache[cacheKey] = summaries
            summariesCacheCost += cost
        }
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
            try Task.checkCancellation()
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
            try Task.checkCancellation()
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
            try Task.checkCancellation()
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

        var summaries = orderedEntryIds.compactMap { entryId -> UnitSummary? in
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
        }
        // Partial or dangling TOC mappings must never hide real source lines.
        let mappedLines = Set(summaries.flatMap(\.sourceLineIndices))
        for lineIndex in index.lineIndices where !mappedLines.contains(lineIndex) {
            try Task.checkCancellation()
            summaries.append(UnitSummary(key: "line:\(lineIndex)", bookId: bookId, mode: mode,
                tocEntryId: nil, title: nil, level: nil, startLineIndex: lineIndex,
                endLineIndex: lineIndex, sourceLineIndices: [lineIndex], includeDescendants: false))
        }
        return summaries.sorted { $0.startLineIndex < $1.startLineIndex }
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
        try Task.checkCancellation()
        let lines = try sourceLines(for: summary)
        guard !lines.isEmpty else { return nil }
        guard lines.map(\.lineIndex) == summary.sourceLineIndices else {
            throw OtzariaReadingUnitError.inconsistentSourceLines
        }
        let html = lines.map(\.html).joined(separator: "\n")
        var plainSegments: [String] = []
        var lineAnchors: [OtzariaLineAnchor] = []
        var currentOffset = 0

        for line in lines {
            try Task.checkCancellation()
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

    private func isContiguousRange(start: Int, end: Int, indices: [Int]) -> Bool {
        guard start <= end, indices.count == (end - start + 1) else { return false }
        guard let first = indices.first, first == start else { return false }
        guard let last = indices.last, last == end else { return false }
        for (i, val) in indices.enumerated() {
            if val != start + i { return false }
        }
        return true
    }

    private func sourceLines(for summary: UnitSummary) throws -> [SourceLine] {
        try Task.checkCancellation()
        let start = Date()
        let lines: [SourceLine]
        let access = try lineContentAccess()

        if isContiguousRange(start: summary.startLineIndex, end: summary.endLineIndex, indices: summary.sourceLineIndices) {
            // Strictly contiguous line range: fast single-index scan on idx_line_book_index
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
                try Task.checkCancellation()
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
        try Task.checkCancellation()
        return SourceLine(
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
        try Task.checkCancellation()
        let (cachedCaps, cachedDec, generation) = cacheLock.withLock {
            (contentCapabilities, contentDecoder, cacheGeneration)
        }
        let capabilities: OtzariaDatabaseCapabilities
        if let cachedCaps {
            capabilities = cachedCaps
        } else {
            capabilities = try OtzariaDatabaseCapabilities(database: db)
            cacheLock.withLock { if generation == cacheGeneration { contentCapabilities = capabilities } }
        }
        let decoder: OtzariaLineContentDecoder
        if let cachedDec {
            decoder = cachedDec
        } else {
            decoder = try OtzariaLineContentDecoder(database: db, capabilities: capabilities)
            cacheLock.withLock { if generation == cacheGeneration { contentDecoder = decoder } }
        }
        return (
            OtzariaLineContentCompatibility.projection(capabilities: capabilities),
            decoder
        )
    }

    private func bookIndex(bookId: Int) throws -> BookIndex {
        try Task.checkCancellation()
        let (cached, generation) = cacheLock.withLock { (indexCache[bookId], cacheGeneration) }
        if let cached { return cached }
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
            try Task.checkCancellation()
            return TocEntry(
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
            FROM line l
            LEFT JOIN line_toc lt ON lt.lineId = l.id
            WHERE l.bookId = ?
            ORDER BY l.lineIndex, lt.tocEntryId
        """, parameters: [bookId]) { row in
            try Task.checkCancellation()
            return (lineIndex: row.int(at: 0), tocEntryId: row.isNull(at: 1) ? nil : row.int(at: 1))
        }

        var leafEntryByLineIndex: [Int: Int] = [:]
        for mapping in mappings {
            try Task.checkCancellation()
            guard let entryId = mapping.tocEntryId, let entry = entriesById[entryId] else { continue }
            if let existingId = leafEntryByLineIndex[mapping.lineIndex],
               let existing = entriesById[existingId], existing.level >= entry.level { continue }
            leafEntryByLineIndex[mapping.lineIndex] = entryId
        }

        let index = BookIndex(
            entriesById: entriesById,
            childrenByParentId: childrenByParentId,
            leafEntryByLineIndex: leafEntryByLineIndex,
            lineIndices: Array(Set(mappings.map(\.lineIndex))).sorted()
        )
        let cost = entries.reduce(0) { $0 + 4 + $1.text.utf16.count } + index.lineIndices.count * 3
        cacheLock.withLock {
            guard generation == cacheGeneration, cost <= maxIndexCacheCost else { return }
            if indexCache[bookId] != nil { return }
            if indexCache.count >= 20 || indexCacheCost + cost > maxIndexCacheCost {
                indexCache.removeAll()
                indexCacheCost = 0
            }
            indexCache[bookId] = index
            indexCacheCost += cost
        }
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
