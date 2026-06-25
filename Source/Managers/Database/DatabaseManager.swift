#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite3

struct ShortsMapping {
    let map: [String: String]
    let sortedKeys: [String]
    var isEmpty: Bool { map.isEmpty }
}

class DatabaseManager {
    static var shared: DatabaseManager = .init()

    private(set) var db: SQLiteDatabase?
    private(set) var dbSpecial: SQLiteDatabase?
    private let lock = NSLock()

    private let booksTableName = "\"0bok\""
    private let categoryTableName = "\"0cat\""
    private let authTableName = "Auth"

    private let colBokId = "bkid"
    private let colBokCat = "cat"
    private let colBokName = "bk"
    private let colBokArchive = "Archive"
    private let colBokBithoqoh = "betaka"
    private let colBokMuallif = "authno"
    private let colBokInf = "inf"
    private let colBokPdfCs = "PdfCs"
    private let colTafseerNam = "TafseerNam"

    private let colCatId = "id"
    private let colCatName = "name"
    private let colCatLevel = "Lvl"
    private let colCatOrder = "catord"

    private let colAuthId = "authid"
    private let colAuthName = "auth"
    private let colAuthInf = "inf"
    private let colAuthLng = "Lng"

    var shortsCache: [String: ShortsMapping] = [:]
    private var archiveAvailabilityCache: [Int: Bool] = [:]

    private init() {
        setupFolders()
    }

    func setupFolders() {
        lock.lock()
        defer { lock.unlock() }

        db = nil
        dbSpecial = nil
        shortsCache.removeAll()
        archiveAvailabilityCache.removeAll()

        if OtzariaMaktabahBridge.shared.isEnabled {
            do {
                try OtzariaMaktabahBridge.shared.openIfNeeded()
            } catch {
                print("Otzaria database could not be opened: \(error)")
            }
            return
        }

        guard let mainPath = AppConfig.mainDatabasePath,
              let specialPath = AppConfig.specialDatabasePath
        else {
            print("databaseFilesPath is nil - database will not be initialized")
            return
        }

        do {
            let tempWriteDb = try SQLiteDatabase(path: specialPath)
            try tempWriteDb.execute(query: """
                CREATE INDEX IF NOT EXISTS idx_auth_covering
                ON "Auth" ("auth" ASC, "authid", "inf", "Lng");
                """)
        } catch {
            print("\(error). Continue to ReadOnly Mode...")
        }

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        do {
            db = try SQLiteDatabase(path: mainPath, flags: flags)
            dbSpecial = try SQLiteDatabase(path: specialPath, flags: flags)
        } catch {
            print("Database setup error: \(error)")
        }
    }

    func reloadConnectionAndLibrary() {
        LibraryDataManager.shared.resetState()
        setupFolders()
        if !OtzariaMaktabahBridge.shared.isEnabled {
            TarjamahGlobalManager.shared.setupConnection()
        }
        BookPageCache.shared.removeAll()
        NotificationCenter.default.post(name: .libraryFolderChanged, object: nil)
    }

    func getLocalVersionDisplay() -> String? {
        if OtzariaMaktabahBridge.shared.isEnabled { return "Otzaria" }
        let checkQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='v'"
        var tableExists = false
        do { try db?.fetch(query: checkQuery) { _ in tableExists = true } } catch { return nil }
        guard tableExists else { return nil }
        return try? db?.fetch(query: "SELECT version FROM v LIMIT 1") { row in row.string(at: 0) }.first ?? nil
    }

    func fetchAllCategories() throws -> [CategoryData] {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return try OtzariaMaktabahBridge.shared.fetchCategories()
        }
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [] }
        let sql = "SELECT \(colCatId), \(colCatName), \(colCatLevel), \(colCatOrder) FROM \(categoryTableName) ORDER BY \(colCatOrder), \(colCatId)"
        return try db.fetch(query: sql) { row in
            CategoryData(id: row.int(at: 0), name: row.string(at: 1) ?? "", level: row.int(at: 2), order: row.int(at: 3))
        }
    }

    func fetchAllBooksGroupedByCategory() throws -> [Int: [BooksData]] {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return try OtzariaMaktabahBridge.shared.fetchBooksGroupedByCategory()
        }
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [:] }
        var groupedBooks: [Int: [BooksData]] = [:]
        let sql = "SELECT \(colBokId), \(colBokName), \(colBokArchive), \(colBokMuallif), \(colBokCat), \(colTafseerNam), \(colBokPdfCs) FROM \(booksTableName) ORDER BY \(colBokName) ASC"
        let books = try db.fetch(query: sql) { row -> BooksData in
            let book = BooksData(id: row.int(at: 0), book: row.string(at: 1) ?? "", archive: row.int(at: 2), muallif: row.int(at: 3))
            book.catId = row.int(at: 4)
            let tafseer = row.string(at: 5)
            book.tafseerNam = (tafseer?.isEmpty == true) ? nil : tafseer
            book.pdfCs = !row.isNull(at: 6) ? row.int(at: 6) : nil
            return book
        }
        for book in books {
            if let catId = book.catId { groupedBooks[catId, default: []].append(book) }
        }
        return groupedBooks
    }

    func getMaxBookId() -> Int {
        if OtzariaMaktabahBridge.shared.isEnabled { return 0 }
        lock.lock(); defer { lock.unlock() }
        guard let db else { return 0 }
        return (try? db.fetch(query: "SELECT MAX(\(colBokId)) FROM \(booksTableName)") { row in row.int(at: 0) }.first) ?? 0
    }

    func getMaxAuthId() -> Int {
        if OtzariaMaktabahBridge.shared.isEnabled { return 0 }
        lock.lock(); defer { lock.unlock() }
        guard let dbSpecial else { return 0 }
        return (try? dbSpecial.fetch(query: "SELECT MAX(\(colAuthId)) FROM \(authTableName)") { row in row.int(at: 0) }.first) ?? 0
    }

    func fetchAllAuthors() -> [(id: Int, muallif: Muallif)] {
        if OtzariaMaktabahBridge.shared.isEnabled { return [] }
        lock.lock(); defer { lock.unlock() }
        guard let dbSpecial else { return [] }
        let sql = "SELECT \(colAuthId), \(colAuthName), \(colAuthInf), \(colAuthLng) FROM \(authTableName) ORDER BY \(colAuthName)"
        return (try? dbSpecial.fetch(query: sql) { row in
            (id: row.int(at: 0), muallif: Muallif(nama: row.string(at: 1) ?? "", info: row.string(at: 2) ?? "", namaLengkap: row.string(at: 3) ?? ""))
        }) ?? []
    }

    func fetchBook(byId bookId: Int) throws -> BooksData? {
        if OtzariaMaktabahBridge.shared.isEnabled {
            return try OtzariaMaktabahBridge.shared.fetchBook(byId: bookId)
        }
        lock.lock(); defer { lock.unlock() }
        guard let db else { throw NSError(domain: "No database connection", code: 1) }
        let sql = "SELECT \(colBokId), \(colBokName), \(colBokArchive), \(colBokMuallif), \(colTafseerNam), \(colBokPdfCs) FROM \(booksTableName) WHERE \(colBokId) = ? LIMIT 1"
        let books = try db.fetch(query: sql, parameters: [bookId]) { row -> BooksData in
            let book = BooksData(id: row.int(at: 0), book: row.string(at: 1) ?? "", archive: row.int(at: 2), muallif: row.int(at: 3))
            let tafseer = row.string(at: 4)
            book.tafseerNam = (tafseer?.isEmpty == true) ? nil : tafseer
            book.pdfCs = !row.isNull(at: 5) ? row.int(at: 5) : nil
            return book
        }
        return books.first
    }

    func bookExists(id: Int) -> Bool {
        if OtzariaMaktabahBridge.shared.isEnabled { return (try? OtzariaMaktabahBridge.shared.fetchBook(byId: id)) != nil }
        lock.lock(); defer { lock.unlock() }
        guard let db else { return false }
        return (try? db.fetch(query: "SELECT 1 FROM `0bok` WHERE `bkid` = ? LIMIT 1;", parameters: [id]) { _ in true }.first) ?? false
    }

    func isAuthorUsed(authorId: Int) -> Bool {
        if OtzariaMaktabahBridge.shared.isEnabled { return false }
        lock.lock(); defer { lock.unlock() }
        guard let db else { return false }
        return (try? db.fetch(query: "SELECT 1 FROM \(booksTableName) WHERE \(colBokMuallif) = ? LIMIT 1;", parameters: [authorId]) { _ in true }.first) ?? false
    }

    func fetchBooksInfo(for bookData: BooksData) {
        if OtzariaMaktabahBridge.shared.isEnabled {
            OtzariaMaktabahBridge.shared.fetchBookInfo(for: bookData)
            return
        }
        lock.lock(); defer { lock.unlock() }
        guard let db else { return }
        let sql = "SELECT \(colBokBithoqoh), \(colBokInf) FROM \(booksTableName) WHERE \(colBokId) = ?"
        if let info = try? db.fetch(query: sql, parameters: [bookData.id], mapping: { row -> (String, String) in
            (row.string(at: 0) ?? "", row.string(at: 1) ?? "")
        }).first {
            bookData.bithoqoh = info.0
            bookData.info = info.1
        }
    }

    func loadShortsForBook(_ bkid: String) -> ShortsMapping {
        if OtzariaMaktabahBridge.shared.isEnabled { return ShortsMapping(map: [:], sortedKeys: []) }
        lock.lock(); defer { lock.unlock() }
        if let cached = shortsCache[bkid] { return cached }
        guard let dbSpecial else { return ShortsMapping(map: [:], sortedKeys: []) }
        var dict: [String: String] = [:]
        if let results = try? dbSpecial.fetch(query: "SELECT Ramz, Nass FROM shorts WHERE Bk = ?", parameters: [bkid], mapping: { row -> (String, String) in
            (row.string(at: 0) ?? "", row.string(at: 1) ?? "")
        }) {
            for item in results { dict[item.0] = item.1 }
        }
        let mapping = ShortsMapping(map: dict, sortedKeys: dict.keys.sorted { $0.count > $1.count })
        shortsCache[bkid] = mapping
        return mapping
    }

    func getAuthor(_ id: Int) -> Muallif? {
        if OtzariaMaktabahBridge.shared.isEnabled { return nil }
        if let cached = LibraryDataManager.shared.getAuthorFromCache(id: id) { return cached }
        lock.lock(); defer { lock.unlock() }
        guard let dbSpecial else { return nil }
        let sql = "SELECT \(colAuthName), \(colAuthInf), \(colAuthLng) FROM \(authTableName) WHERE \(colAuthId) = ? LIMIT 1"
        if let author = try? dbSpecial.fetch(query: sql, parameters: [id], mapping: { row -> Muallif in
            Muallif(nama: row.string(at: 0) ?? "", info: row.string(at: 1) ?? "", namaLengkap: row.string(at: 2) ?? "")
        }).first {
            LibraryDataManager.shared.updateAuthorInCache(id: id, muallif: author)
            return author
        }
        return nil
    }

    func checkArchiveAvailability(archiveId: Int) -> Bool {
        if OtzariaMaktabahBridge.shared.isEnabled { return true }
        lock.lock()
        if let cached = archiveAvailabilityCache[archiveId] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let fm = FileManager.default
        guard let archiveFile = AppConfig.archiveDatabasePath(archiveId: archiveId), let ftsFile = AppConfig.archiveFtsDatabasePath(archiveId: archiveId) else { return false }
        let archiveSize = (try? fm.attributesOfItem(atPath: archiveFile)[.size] as? NSNumber)?.int64Value ?? 0
        let ftsSize = (try? fm.attributesOfItem(atPath: ftsFile)[.size] as? NSNumber)?.int64Value ?? 0
        let isAvailable = fm.fileExists(atPath: archiveFile) && fm.fileExists(atPath: ftsFile) && archiveSize > 0 && ftsSize > 0
        lock.lock(); archiveAvailabilityCache[archiveId] = isAvailable; lock.unlock()
        return isAvailable
    }

    func invalidateArchiveCache(archiveId: Int) {
        lock.lock()
        archiveAvailabilityCache.removeValue(forKey: archiveId)
        lock.unlock()
        IntegrationCache.shared.invalidate(archiveId: archiveId)
    }
}
