
//
//  BookConnection.swift
//  maktab
//
//  Created by MacBook on 02/12/25.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

class BookConnection {
    private(set) var db: SQLiteDatabase?
    static let tocTreeCache = NSCache<NSNumber, NSArray>()
    private let totalPartsCache = NSCache<NSString, NSNumber>()

    init() {
        totalPartsCache.countLimit = 100
        totalPartsCache.name = "BookTotalPartsCache"
    }

    deinit {
        db = nil
    }

    func connect(archive: Int) throws {
        let start = Date()
        otzariaConnectionLog("connect start enabled=\(OtzariaMaktabahBridge.shared.isEnabled) archive=\(archive)")
        if OtzariaMaktabahBridge.shared.isEnabled {
            try OtzariaMaktabahBridge.shared.openIfNeeded()
            db = nil
            otzariaConnectionLog("connect done enabled=true archive=\(archive) durationMs=\(otzariaConnectionElapsedMs(start))")
            return
        }

        guard let archivePath = AppConfig.archiveDatabasePath(archiveId: archive) else {
            throw ArchiveError.databasePathNotAvailable
        }

        guard DatabaseManager.shared.checkArchiveAvailability(archiveId: archive) else {
            throw ArchiveError.archiveNotAvailable(archiveId: archive)
        }

        db = nil

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        do {
            db = try SQLiteDatabase(path: archivePath, flags: flags)
            otzariaConnectionLog("connect done enabled=false archive=\(archive) durationMs=\(otzariaConnectionElapsedMs(start))")
        } catch let SQLiteError.connectionFailed(msg) {
            otzariaConnectionLog("connect error enabled=false archive=\(archive) error=\(msg) durationMs=\(otzariaConnectionElapsedMs(start))")
            throw NSError(
                domain: "BookConnection",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        } catch {
            otzariaConnectionLog("connect error enabled=false archive=\(archive) error=\(error.localizedDescription) durationMs=\(otzariaConnectionElapsedMs(start))")
            throw NSError(
                domain: "BookConnection",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }

    func fetchTafseer(
        archive: Int,
        bkId: Int,
        for aya: Int,
        in surah: Int
    ) -> BookContent? {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return nil
        }

        if db == nil {
            try? connect(archive: archive)
        }

        guard let db else { return nil }

        let tableName = "b\(bkId)"

        let sql = """
        SELECT id, nass, page, part, sora, aya
        FROM \(tableName)
        WHERE sora = ? AND aya = ?
        LIMIT 1
        """

        do {
            return try db.fetch(query: sql, parameters: [surah, aya]) { row -> BookContent? in
                let id = row.int64(at: 0)
                let page = row.int64(at: 2)
                let part = row.int64(at: 3)

                if let nassBlob = row.blob(at: 1) {
                    let nass = ReusableFunc.decompressData(nassBlob)

                    return BookContent(
                        id: Int(id),
                        nash: nass,
                        page: Int(page),
                        part: Int(part)
                    )
                }

                return nil
            }.compactMap { $0 }.first
        } catch {
            #if DEBUG
            print("fetchTafseer error:", error)
            #endif
            return nil
        }
    }

    func applyShortsMapping(
        to text: String,
        with mapping: ShortsMapping
    ) -> String {
        guard !mapping.isEmpty else { return text }

        var output = text

        for key in mapping.sortedKeys {
            if let replacement = mapping.map[key] {
                output = output.replacingOccurrences(
                    of: key,
                    with: "\(replacement)\n"
                )
            }
        }

        return output
    }

    func getCached(bkId: String, idContent: Int) -> BookContent? {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return nil
        }

        if let bkIdInt = Int(bkId),
           let cached = BookPageCache.shared.get(
               bookId: bkIdInt,
               contentId: idContent
           )
        {
            return cached
        }

        return nil
    }

    private func setCache(bkId: String, content: BookContent) {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return
        }

        if let bookId = Int(bkId) {
            BookPageCache.shared.set(bookId: bookId, content: content)
        }
    }
}

extension BookConnection {
    fileprivate func otzariaConnectionLog(_ message: String) {
        OtzariaFileLogger.shared.log("[BookConnection] \(message)")
    }

    fileprivate func otzariaConnectionElapsedMs(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func parsePartValue(row: SQLiteRow, column: Int32) -> Int {
        let type = row.type(at: column)

        if type == SQLITE_INTEGER {
            return Int(row.int64(at: column))
        } else if type == SQLITE_TEXT {
            if let strValue = row.string(at: column) {
                if let dashIndex = strValue.firstIndex(of: "-") {
                    return Int(strValue[..<dashIndex]) ?? 1
                }

                return Int(strValue) ?? 1
            }
        }

        return 1
    }

    func getContent(
        bkid: String,
        contentId: Int,
        quran: Bool = false
    ) -> BookContent? {
        let start = Date()
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            let content = OtzariaMaktabahBridge.shared.getContent(
                bookId: bookId,
                contentId: contentId
            )
            otzariaConnectionLog("getContent enabled=true bookId=\(bookId) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(otzariaConnectionElapsedMs(start))")
            return content
        }

        guard let db else { return nil }

        if let cached = getCached(bkId: bkid, idContent: contentId) {
            return cached
        }

        let querySQL = quran ? quranContentQuery(forBook: bkid) : contentQuery(forBook: bkid)

        do {
            let contents = try db.fetch(
                query: querySQL,
                parameters: [String(contentId)]
            ) { row -> BookContent? in
                if let nassBlob = row.blob(at: 0) {
                    let decompressedNass = ReusableFunc.decompressData(nassBlob)

                    let page = row.int64(at: 1)
                    let id = row.int64(at: 2)
                    let part = self.parsePartValue(row: row, column: 3)

                    let shortsMap = DatabaseManager.shared.loadShortsForBook(bkid)
                    let finalNass = shortsMap.isEmpty
                        ? decompressedNass
                        : self.applyShortsMapping(to: decompressedNass, with: shortsMap)

                    let newContent = BookContent(
                        id: Int(id),
                        nash: finalNass,
                        page: Int(page),
                        part: part
                    )

                    if quran {
                        newContent.surah = Int(row.int64(at: 4))
                        newContent.aya = Int(row.int64(at: 5))
                    }

                    return newContent
                }

                return nil
            }.compactMap { $0 }

            if let content = contents.first {
                setCache(bkId: bkid, content: content)
                otzariaConnectionLog("getContent enabled=false bookId=\(bkid) contentId=\(contentId) result=ok durationMs=\(otzariaConnectionElapsedMs(start))")
                return content
            }
        } catch {
            print("getContent error:", error)
            otzariaConnectionLog("getContent enabled=false bookId=\(bkid) contentId=\(contentId) result=error error=\(error.localizedDescription) durationMs=\(otzariaConnectionElapsedMs(start))")
        }

        otzariaConnectionLog("getContent enabled=false bookId=\(bkid) contentId=\(contentId) result=nil durationMs=\(otzariaConnectionElapsedMs(start))")
        return nil
    }

    func getFirstContent(bkid: String) -> BookContent? {
        let start = Date()
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            let content = OtzariaMaktabahBridge.shared.getFirstContent(bookId: bookId)
            otzariaConnectionLog("getFirstContent enabled=true bookId=\(bookId) result=\(content == nil ? "nil" : "ok") durationMs=\(otzariaConnectionElapsedMs(start))")
            return content
        }

        guard let db else { return nil }

        let querySQL = """
        SELECT nass, page, id, part
        FROM b\(bkid)
        ORDER BY id ASC
        LIMIT 1
        """

        do {
            let contents = try db.fetch(query: querySQL) { row -> BookContent? in
                if let nassBlob = row.blob(at: 0) {
                    let decompressedNass = ReusableFunc.decompressData(nassBlob)

                    let page = row.int64(at: 1)
                    let id = row.int64(at: 2)
                    let part = self.parsePartValue(row: row, column: 3)

                    let shortsMap = DatabaseManager.shared.loadShortsForBook(bkid)
                    let finalNass = shortsMap.isEmpty
                        ? decompressedNass
                        : self.applyShortsMapping(to: decompressedNass, with: shortsMap)

                    return BookContent(
                        id: Int(id),
                        nash: finalNass,
                        page: Int(page),
                        part: part
                    )
                }

                return nil
            }.compactMap { $0 }

            if let content = contents.first {
                setCache(bkId: bkid, content: content)
                otzariaConnectionLog("getFirstContent enabled=false bookId=\(bkid) result=ok durationMs=\(otzariaConnectionElapsedMs(start))")
                return content
            }
        } catch {
            print("getFirstContent error:", error)
            otzariaConnectionLog("getFirstContent enabled=false bookId=\(bkid) result=error error=\(error.localizedDescription) durationMs=\(otzariaConnectionElapsedMs(start))")
        }

        otzariaConnectionLog("getFirstContent enabled=false bookId=\(bkid) result=nil durationMs=\(otzariaConnectionElapsedMs(start))")
        return nil
    }

    func getContent(
        bkid: String,
        part: Int,
        page: Int
    ) -> BookContent? {
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            return OtzariaMaktabahBridge.shared.getContent(
                bookId: bookId,
                contentId: page
            )
        }

        guard let db else { return nil }

        let querySQL = """
        SELECT nass, page, id, part
        FROM b\(bkid)
        WHERE part = ? AND page = ?
        LIMIT 1
        """

        do {
            let contents = try db.fetch(
                query: querySQL,
                parameters: [String(part), String(page)]
            ) { row -> BookContent? in
                if let nassBlob = row.blob(at: 0) {
                    let decompressedNass = ReusableFunc.decompressData(nassBlob)

                    let id = row.int64(at: 2)
                    let partValue = self.parsePartValue(row: row, column: 3)

                    let shortsMap = DatabaseManager.shared.loadShortsForBook(bkid)
                    let finalNass = self.applyShortsMapping(to: decompressedNass, with: shortsMap)

                    return BookContent(
                        id: Int(id),
                        nash: finalNass,
                        page: page,
                        part: partValue
                    )
                }

                return nil
            }.compactMap { $0 }

            if let content = contents.first {
                setCache(bkId: bkid, content: content)
                return content
            }
        } catch {
            print("getContent part page error:", error)
        }

        return nil
    }

    func getNextPage(
        from currentBook: BooksData,
        contentId: Int,
        quran: Bool = false
    ) -> BookContent? {
        let start = Date()
        if OtzariaMaktabahBridge.shared.isEnabled {
            let content = OtzariaMaktabahBridge.shared.getNextContent(
                bookId: currentBook.id,
                after: contentId
            )
            otzariaConnectionLog("getNextPage enabled=true bookId=\(currentBook.id) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(otzariaConnectionElapsedMs(start))")
            return content
        }

        guard
            let content = getContent(
                bkid: "\(currentBook.id)",
                contentId: contentId + 1,
                quran: quran
            )
        else {
            guard
                let content = getContent(
                    bkid: "\(currentBook.id)",
                    contentId: contentId + 2,
                    quran: quran
                )
            else { return nil }

            return content
        }

        return content
    }

    func getPrevPage(
        from currentBook: BooksData,
        contentId: Int,
        quran: Bool = false
    ) -> BookContent? {
        let start = Date()
        if OtzariaMaktabahBridge.shared.isEnabled {
            let content = OtzariaMaktabahBridge.shared.getPreviousContent(
                bookId: currentBook.id,
                before: contentId
            )
            otzariaConnectionLog("getPrevPage enabled=true bookId=\(currentBook.id) contentId=\(contentId) result=\(content == nil ? "nil" : "ok") durationMs=\(otzariaConnectionElapsedMs(start))")
            return content
        }

        guard
            let content = getContent(
                bkid: "\(currentBook.id)",
                contentId: contentId - 1,
                quran: quran
            )
        else {
            guard
                let content = getContent(
                    bkid: "\(currentBook.id)",
                    contentId: contentId - 2,
                    quran: quran
                )
            else { return nil }

            return content
        }

        return content
    }

    func contentQuery(forBook bkid: String) -> String {
        """
        SELECT nass, page, id, part
        FROM b\(bkid)
        WHERE id = ?
        """
    }

    func quranContentQuery(forBook bkid: String) -> String {
        """
        SELECT nass, page, id, part, sora, aya
        FROM b\(bkid)
        WHERE id = ?
        """
    }

    func getTotalParts(bkid: String) -> Int {
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            return OtzariaMaktabahBridge.shared.getTotalParts(bookId: bookId)
        }

        let key = bkid as NSString

        if let cached = totalPartsCache.object(forKey: key) {
            return cached.intValue
        }

        let total = calculateTotalParts(bkid: bkid)
        totalPartsCache.setObject(NSNumber(value: total), forKey: key)

        return total
    }

    private func calculateTotalParts(bkid: String) -> Int {
        guard let db else { return 0 }

        let querySQL = """
        SELECT MAX(
            CAST(
                CASE
                    WHEN instr(part, '-') > 0
                    THEN substr(part, 1, instr(part, '-') - 1)
                    ELSE part
                END AS INTEGER
            )
        )
        FROM b\(bkid)
        """

        return (try? db.fetch(query: querySQL) { row in
            Int(row.int64(at: 0))
        }.first) ?? 0
    }

    func getPagesInPart(bkid: String, part: Int) -> Int {
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            return OtzariaMaktabahBridge.shared.getMaxPage(bookId: bookId)
        }

        guard let db else { return 0 }

        let querySQL = """
        SELECT MAX(page)
        FROM b\(bkid)
        WHERE part = ?
        """

        return (try? db.fetch(query: querySQL, parameters: [String(part)]) { row in
            Int(row.int64(at: 0))
        }.first) ?? 0
    }

    func getMinPagesInPart(bkid: String, part: Int) -> Int {
        if OtzariaMaktabahBridge.shared.isEnabled, let bookId = Int(bkid) {
            return OtzariaMaktabahBridge.shared.getMinPage(bookId: bookId)
        }

        guard let db else { return 0 }

        let querySQL = """
        SELECT MIN(page)
        FROM b\(bkid)
        WHERE part = ?
        """

        return (try? db.fetch(query: querySQL, parameters: [String(part)]) { row in
            Int(row.int64(at: 0))
        }.first) ?? 0
    }

    func getTOCEntries(_ book: BooksData) async -> [TOC] {
        let start = Date()
        if OtzariaMaktabahBridge.shared.isEnabled {
            let entries = OtzariaMaktabahBridge.shared.getTOCEntries(for: book)
            otzariaConnectionLog("getTOCEntries enabled=true bookId=\(book.id) count=\(entries.count) durationMs=\(otzariaConnectionElapsedMs(start))")
            return entries
        }

        try? connect(archive: book.archive)

        guard let db else { return [] }

        let query = """
        SELECT id, tit, COALESCE(lvl, 0) as lvl, COALESCE(sub, 0) as sub
        FROM t\(book.id)
        ORDER BY id
        """

        do {
            return try db.fetch(query: query) { row -> TOC? in
                if Task.isCancelled { return nil }

                let id = row.int64(at: 0)
                let tit = row.string(at: 1) ?? ""
                let lvl = row.int64(at: 2)
                let sub = row.int64(at: 3)

                return TOC(
                    bab: tit,
                    level: Int(lvl),
                    sub: Int(sub),
                    id: Int(id)
                )
            }.compactMap { $0 }
        } catch {
            print("getTOCEntries error:", error)
            return []
        }
    }

    func buildTOCTree(from flatTOCs: [TOC], bookId: Int) async -> [TOCNode] {
        guard !flatTOCs.isEmpty else { return [] }

        let key = NSNumber(value: bookId)

        if let cached = Self.tocTreeCache.object(forKey: key) as? [TOCNode] {
            return cached
        }

        var allNodes: [TOCNode] = []
        var levelStacks: [Int: [TOCNode]] = [:]
        var nodesByEntryId: [Int: TOCNode] = [:]
        var hasParentLinks = false

        for toc in flatTOCs {
            if Task.isCancelled { return [] }

            let node = TOCNode(from: toc)
            allNodes.append(node)
            nodesByEntryId[toc.entryId] = node
            if toc.parentId != nil { hasParentLinks = true }

            if levelStacks[node.level] == nil {
                levelStacks[node.level] = []
            }

            levelStacks[node.level]?.append(node)
        }

        var rootNodes: [TOCNode] = []

        if hasParentLinks {
            for toc in flatTOCs {
                if Task.isCancelled { return [] }
                let node = nodesByEntryId[toc.entryId]
                guard let node else { continue }
                if let parentId = toc.parentId, let parent = nodesByEntryId[parentId] {
                    parent.children.append(node)
                } else {
                    rootNodes.append(node)
                }
            }
        } else {
            if let level1Nodes = levelStacks[1] {
                rootNodes = level1Nodes.filter { $0.sub == 0 }
            }

            if rootNodes.isEmpty {
                rootNodes = allNodes.filter { $0.level <= 1 }
            }

            let sortedLevels = levelStacks.keys.sorted()

            for currentLevel in sortedLevels where currentLevel > 1 {
                if Task.isCancelled { return [] }

                guard let nodesAtCurrentLevel = levelStacks[currentLevel] else { continue }

                for node in nodesAtCurrentLevel {
                    if Task.isCancelled { return [] }

                    var foundParent = false

                    for parentLevel in stride(from: currentLevel - 1, through: 1, by: -1) {
                        if Task.isCancelled { return [] }

                        guard let candidateParents = levelStacks[parentLevel] else { continue }

                        if let parent = candidateParents.last(where: { $0.id <= node.id }) {
                            parent.children.append(node)
                            foundParent = true
                            break
                        }
                    }

                    if !foundParent {
                        rootNodes.append(node)
                    }
                }
            }
        }

        #if os(iOS)
        for (i, node) in allNodes.enumerated() {
            if i < allNodes.count - 1 {
                node.endID = allNodes[i + 1].id - 1
            } else {
                node.endID = Int.max
            }
        }
        #endif

        Self.tocTreeCache.setObject(rootNodes as NSArray, forKey: key)
        return rootNodes
    }
}

