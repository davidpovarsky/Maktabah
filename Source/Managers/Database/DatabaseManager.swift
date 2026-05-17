//
//  DatabaseManager.swift
//  maktab
//
//  Created by MacBook on 29/11/25.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import SQLite

// DatabaseManager.swift
class DatabaseManager {
    static var shared: DatabaseManager = .init()

    private(set) var db: Connection?
    private(set) var dbSpecial: Connection?

    let booksTable = Table("0bok")
    let categoryTable = Table("0cat")

    // Column definitions untuk 0bok
    let bokId = Expression<Int>("bkid")
    let bokCat = Expression<Int>("cat")
    let bokName = Expression<String>("bk")
    let bokArchive = Expression<Int>("Archive")
    let bokBithoqoh = Expression<String>("betaka")
    let bokMuallif = Expression<Int>("authno")
    let bokInf = Expression<String>("inf")
    let bokPdfCs = Expression<Int?>("PdfCs")
    let tafseerNam = Expression<String?>("TafseerNam")
 
    // Column definitions untuk 0cat
    let catId = Expression<Int>("id")
    let catName = Expression<String>("name")
    let catLevel = Expression<Int>("Lvl")
    let catOrder = Expression<Int>("catord")

    // Column definitions untuk Auth (dari getAuthor)
    let authTable = Table("Auth")
    let authId = Expression<Int>("authid")
    let authName = Expression<String?>("auth")
    let authInf = Expression<String?>("inf")
    let authLng = Expression<String?>("Lng")

    var shortsCache: [String: [String: String]] = [:]

    // MARK: - Archive Availability
    private var archiveAvailabilityCache: [Int: Bool] = [:]

    private init() {
        setupFolders()
    }

    func setupFolders() {
        // Database files path (main.sqlite, special.sqlite)
        guard let mainPath = AppConfig.mainDatabasePath,
              let specialPath = AppConfig.specialDatabasePath
        else {
            print("databaseFilesPath is nil - database will not be initialized")
            return
        }

        do {
            db = try Connection(mainPath, readonly: true)
            dbSpecial = try Connection(specialPath, readonly: true)
        } catch {
            UserDefaults.standard.removeObject(forKey: AppConfig.storageKey)
            ReusableFunc.showAlert(
                title: NSLocalizedString("Folder Not Found", comment: ""),
                message: NSLocalizedString(
                    "Application Will Terminate because Folder Location Not Found on \(AppConfig.databaseFilesPath ?? "N/A")",
                    comment: ""
                )
            )
            #if DEBUG
                print(error.localizedDescription)
            #endif
            #if os(macOS)
            NSApp.terminate(nil)
            #else
            fatalError("Application Terminated: Folder Location Not Found")
            #endif
        }
    }

    func fetchAllCategories() throws -> [CategoryData] {
        guard let db = db else { return [] }

        var categories: [CategoryData] = []

        // Urutkan berdasarkan catord untuk menjaga hierarki yang benar
        for row in try db.prepare(categoryTable.order(catOrder, catId)) {
            let category = CategoryData(
                id: row[catId],
                name: row[catName],
                level: row[catLevel],
                order: row[catOrder]
            )
            categories.append(category)
        }

        return categories
    }

    func fetchAllBooksGroupedByCategory() throws -> [Int: [BooksData]] {
        guard let db = db else { return [:] }

        var groupedBooks: [Int: [BooksData]] = [:]

        for row in try db.prepare(booksTable) {
            let catId = row[bokCat]
            let book = BooksData(
                id: row[bokId],
                book: row[bokName],
                archive: row[bokArchive],
                muallif: row[bokMuallif]
            )
            book.catId = catId
            book.tafseerNam = row[tafseerNam]?.isEmpty == true ? nil : row[tafseerNam]
            book.pdfCs = row[bokPdfCs]
            groupedBooks[catId, default: []].append(book)
        }

        return groupedBooks
    }

    func getMaxBookId() -> Int {
        guard let db = db else { return 0 }
        let maxId = bokId.max
        return (try? db.scalar(booksTable.select(maxId))) ?? 0
    }

    func getMaxAuthId() -> Int {
        guard let dbSpecial = dbSpecial else { return 0 }
        let maxId = authId.max
        return (try? dbSpecial.scalar(authTable.select(maxId))) ?? 0
    }

    func fetchAllAuthors() -> [(id: Int, muallif: Muallif)] {
        guard let dbSpecial = dbSpecial else { return [] }
        var authors: [(id: Int, muallif: Muallif)] = []
        do {
            for row in try dbSpecial.prepare(authTable) {
                let id = row[authId]
                let auth = row[authName] ?? ""
                let inf = row[authInf] ?? ""
                let lng = row[authLng] ?? ""
                authors.append((id: id, muallif: Muallif(nama: auth, info: inf, namaLengkap: lng)))
            }
        } catch {
            print("Error fetchAllAuthors: \(error)")
        }
        return authors
    }
    
    func fetchBooks(forCategory catId: Int) throws -> [BooksData] {
        try fetchBooks(forCategory: catId, bookIds: nil)
    }

    // Fetch buku spesifik di category (atau semua jika bookIds = nil)
    func fetchBooks(forCategory catId: Int, bookIds: Set<Int>?) throws -> [BooksData] {
        guard let db = db else { return [] }

        var query = booksTable.filter(bokCat == catId)

        // Filter by specific bookIds if provided
        if let bookIds = bookIds, !bookIds.isEmpty {
            query = query.filter(bookIds.contains(bokId))
        }

        var books: [BooksData] = []
        for row in try db.prepare(query) {
            let book = BooksData(
                id: row[bokId],
                book: row[bokName],
                archive: row[bokArchive],
                muallif: row[bokMuallif]
            )
            book.tafseerNam = row[tafseerNam]?.isEmpty == true ? nil : row[tafseerNam]
            book.pdfCs = try? row.get(bokPdfCs)
            books.append(book)
        }

        return books
    }

    // Fetch single book by ID (untuk update individual)
    func fetchBook(byId bookId: Int) throws -> BooksData? {
        guard let db = db else { throw
            NSError(domain: DatabaseError.noConnection.localizedDescription,
                    code: 1)
        }

        let query = booksTable.filter(bokId == bookId).limit(1)

        guard let row = try db.pluck(query) else { throw
            NSError(domain: DatabaseError.bookNotFound(bookId).localizedDescription, code: 1)
        }

        let book = BooksData(
            id: row[bokId],
            book: row[bokName],
            archive: row[bokArchive],
            muallif: row[bokMuallif]
        )
        book.tafseerNam = row[tafseerNam]?.isEmpty == true ? nil : row[tafseerNam]

        return book
    }


    func fetchBooksInfo(for bookData: BooksData) {
        guard let db = DatabaseManager.shared.db else {
            #if DEBUG
                print("Database connection is nil.")
            #endif
            return
        }

        do {
            // 1. Definisikan query: Cari baris di tabel "0bok"
            //    di mana bkid (bokId) sama dengan ID buku yang diberikan.
            let query = booksTable.filter(bokId == bookData.id)

            // 2. Eksekusi query dan ambil baris pertama
            if let row = try db.pluck(query) {

                // 3. Ekstrak data menggunakan Expression objects
                let betaka = try row.get(bokBithoqoh)
                let inf = try row.get(bokInf)

                // 4. Modifikasi objek BooksData yang shared (in-place)
                // didSet pada properti BooksData akan memicu pemrosesan string.
                bookData.bithoqoh = betaka
                bookData.info = inf

                #if DEBUG
                    print("Successfully loaded info for book \(bookData.id).")
                #endif
            }
        } catch {
            #if DEBUG
                print("Error fetching book info using SQLite.swift: \(error)")
            #endif
        }
    }

    func loadShortsForBook(_ bkid: String) -> [String: String] {
        // cek cache dulu
        if let cached = DatabaseManager.shared.shortsCache[bkid] {
            return cached
        }

        guard let dbSpecial = DatabaseManager.shared.dbSpecial else {
            return [:]
        }

        var dict: [String: String] = [:]

        do {
            let sql = "SELECT Ramz, Nass FROM shorts WHERE Bk = ?"
            let stmt = try dbSpecial.prepare(sql, bkid)

            for row in stmt {
                if let code = row[0] as? String,
                    let text = row[1] as? String
                {
                    dict[code] = text
                }
            }

            // simpan ke cache untuk pemakaian berikutnya
            DatabaseManager.shared.shortsCache[bkid] = dict

        } catch {
            #if DEBUG
                print("Error loading shorts mapping for book \(bkid): \(error)")
            #endif
        }

        return dict
    }

    func getAuthor(_ id: Int) -> Muallif? {
        if let cached = LibraryDataManager.shared.authorsCache[id] {
            return cached
        }

        guard let dbSpecial = DatabaseManager.shared.dbSpecial else {
            return nil
        }
        var resultAuthor: Muallif? = nil

        do {
            // Menggunakan Expression dan Table untuk kueri
            let query = authTable.filter(authId == id)

            if let row = try dbSpecial.pluck(query) {
                let auth = try row.get(authName) ?? ""
                let inf = try row.get(authInf) ?? ""
                let lng = try row.get(authLng) ?? ""

                let author = Muallif(
                    nama: auth,
                    info: inf,
                    namaLengkap: lng
                )

                resultAuthor = author
                LibraryDataManager.shared.authorsCache[id] = author
            }
        } catch {
            #if DEBUG
                print(
                    "Error fetching author \(id): \(error.localizedDescription)"
                )
            #endif
        }

        return resultAuthor
    }

    // MARK: - Archive File Management

    /// Check apakah archive file tersedia untuk buku tertentu
    /// - Parameter archiveId: Nomor archive (1-20, sesuai kolom Archive di tabel 0bok)
    /// - Returns: True jika baik {archiveId}.sqlite dan {archiveId}_fts.sqlite tersedia
    func checkArchiveAvailability(archiveId: Int) -> Bool {
        // Check cache dulu
        if let cached = archiveAvailabilityCache[archiveId] {
            return cached
        }

        let fm = FileManager.default
        guard let archiveFile = AppConfig.archiveDatabasePath(archiveId: archiveId),
              let ftsFtsFile = AppConfig.archiveFtsDatabasePath(archiveId: archiveId)
        else {
            return false
        }

        let archiveExists = fm.fileExists(atPath: archiveFile)
        let ftsExists = fm.fileExists(atPath: ftsFtsFile)
        let isAvailable: Bool

        // Kedua file harus ada dan bukan file kosong.
        if archiveExists && ftsExists {
            let archiveSize =
            (try? fm.attributesOfItem(atPath: archiveFile)[.size] as? NSNumber)?
                .int64Value ?? 0
            let ftsSize =
            (try? fm.attributesOfItem(atPath: ftsFtsFile)[.size] as? NSNumber)?
                .int64Value ?? 0
            isAvailable = archiveSize > 0 && ftsSize > 0
        } else {
            isAvailable = false
        }

        // Cache result
        archiveAvailabilityCache[archiveId] = isAvailable

        #if DEBUG
            if isAvailable {
                print("Archive \(archiveId) is available at: \(archiveFile)")
            } else {
                print("Archive \(archiveId) is NOT available")
                print("Looking in: \(AppConfig.archiveFilesPath ?? "N/A")")
            }
        #endif

        return isAvailable
    }

    /// Invalidate cache untuk archive specific (call setelah download single archive)
    func invalidateArchiveCache(archiveId: Int) {
        archiveAvailabilityCache.removeValue(forKey: archiveId)
        IntegrationCache.shared.invalidate(archiveId: archiveId)
        #if DEBUG
            print("Cache invalidated for archive \(archiveId)")
        #endif
    }
}
