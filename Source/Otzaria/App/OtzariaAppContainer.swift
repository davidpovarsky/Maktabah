import Foundation
import SQLite3

@MainActor
final class OtzariaAppContainer: ObservableObject {
    @Published private(set) var repositories: OtzariaAppRepositories?
    @Published private(set) var databaseURL: URL?
    @Published private(set) var databaseToken = UUID()
    @Published var databaseError: String?
    @Published var isOpeningDatabase = false

    private let bookmarkStore = OtzariaSecurityScopedBookmarkStore()
    private var connection: OtzariaSQLiteConnection?
    private var scopedAccess: OtzariaSecurityScopedAccess?

    deinit {
        connection?.close()
        scopedAccess?.stop()
    }

    func restoreDatabaseIfPossible() async {
        guard repositories == nil else { return }
        do {
            guard let restored = try bookmarkStore.restore() else { return }
            await openDatabase(at: restored.url, shouldSaveBookmark: false, scopedAccess: restored.access)
        } catch {
            databaseError = error.localizedDescription
        }
    }

    func openPickedDatabase(at url: URL) async {
        await openDatabase(at: url, shouldSaveBookmark: true, scopedAccess: nil)
    }

    func forgetDatabase() {
        connection?.close()
        connection = nil
        scopedAccess?.stop()
        scopedAccess = nil
        repositories = nil
        databaseURL = nil
        databaseError = nil
        bookmarkStore.forget()
        databaseToken = UUID()
    }

    private func openDatabase(at url: URL, shouldSaveBookmark: Bool, scopedAccess existingAccess: OtzariaSecurityScopedAccess?) async {
        isOpeningDatabase = true
        databaseError = nil
        defer { isOpeningDatabase = false }

        connection?.close()
        connection = nil
        scopedAccess?.stop()
        scopedAccess = nil
        repositories = nil

        do {
            let access = try existingAccess ?? OtzariaSecurityScopedAccess.start(for: url)
            if shouldSaveBookmark {
                try bookmarkStore.save(url: url)
            }

            let newConnection = try OtzariaSQLiteConnection.openReadOnly(url: url)
            try await newConnection.read { db in
                try OtzariaSchemaValidator.validate(db)
            }

            let newRepositories = OtzariaAppRepositories(
                library: OtzariaSQLiteLibraryRepository(database: newConnection),
                bookText: OtzariaSQLiteBookTextRepository(database: newConnection),
                sources: OtzariaSQLiteSourceRepository(database: newConnection)
            )

            scopedAccess = access
            connection = newConnection
            repositories = newRepositories
            databaseURL = url
            databaseToken = UUID()
        } catch {
            databaseError = error.localizedDescription
        }
    }
}

struct OtzariaAppRepositories {
    let library: any OtzariaLibraryRepository
    let bookText: any OtzariaBookTextRepository
    let sources: any OtzariaSourceRepository
}

final class OtzariaMaktabahBridge {
    static let shared = OtzariaMaktabahBridge()

    private let databasePathKey = "otzaria_seforim_database_path"
    private let lock = NSRecursiveLock()
    private var database: SQLiteDatabase?

    private init() {}

    var isEnabled: Bool {
        selectedDatabasePath != nil
    }

    var selectedDatabasePath: String? {
        guard let raw = UserDefaults.standard.string(forKey: databasePathKey), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    func installDatabase(from sourceURL: URL) throws {
        let didStart = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { sourceURL.stopAccessingSecurityScopedResource() }
        }

        guard let appSupport = AppConfig.appSupportDir else {
            throw NSError(domain: "Otzaria", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support folder is not available"])
        }

        let fm = FileManager.default
        let otzariaFolder = appSupport.appendingPathComponent("Otzaria", isDirectory: true)
        if !fm.fileExists(atPath: otzariaFolder.path) {
            try fm.createDirectory(at: otzariaFolder, withIntermediateDirectories: true)
        }

        let destination = otzariaFolder.appendingPathComponent("seforim.db")
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: sourceURL, to: destination)

        UserDefaults.standard.set(destination.path, forKey: databasePathKey)
        resetConnection()
    }

    func forgetDatabase() {
        lock.lock()
        defer { lock.unlock() }
        database = nil
        if let path = selectedDatabasePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        UserDefaults.standard.removeObject(forKey: databasePathKey)
    }

    func resetConnection() {
        lock.lock()
        database = nil
        lock.unlock()
    }

    @discardableResult
    func openIfNeeded() throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let path = selectedDatabasePath else { return false }
        if database != nil { return true }
        database = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
        return true
    }

    private func requireDatabase() throws -> SQLiteDatabase {
        _ = try openIfNeeded()
        guard let database else {
            throw NSError(domain: "Otzaria", code: 2, userInfo: [NSLocalizedDescriptionKey: "Otzaria database is not selected"])
        }
        return database
    }

    func fetchCategories() throws -> [CategoryData] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT id, parentId, title, level, orderIndex
            FROM category
            ORDER BY level, orderIndex, title
        """) { row in
            let parentId = row.isNull(at: 1) ? nil : row.int(at: 1)
            return CategoryData(
                id: row.int(at: 0),
                name: row.string(at: 2) ?? "ללא שם",
                level: row.int(at: 3),
                order: row.int(at: 4),
                parentId: parentId
            )
        }
    }

    func fetchBooksGroupedByCategory() throws -> [Int: [BooksData]] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        let books = try db.fetch(query: """
            SELECT id, title, categoryId, orderIndex, totalLines, heShortDesc, fileType
            FROM book
            WHERE COALESCE(fileType, '') NOT IN ('link', 'url')
            ORDER BY orderIndex, title
        """) { row -> BooksData in
            let book = BooksData(
                id: row.int(at: 0),
                book: row.string(at: 1) ?? "ללא שם",
                archive: 0,
                muallif: 0,
                bithoqoh: row.string(at: 5) ?? "",
                info: row.string(at: 5) ?? ""
            )
            book.catId = row.int(at: 2)
            book.pdfCs = 4
            return book
        }

        var grouped: [Int: [BooksData]] = [:]
        for book in books {
            if let catId = book.catId {
                grouped[catId, default: []].append(book)
            }
        }
        return grouped
    }

    func fetchBook(byId bookId: Int) throws -> BooksData? {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT id, title, categoryId, heShortDesc
            FROM book
            WHERE id = ?
            LIMIT 1
        """, parameters: [bookId]) { row -> BooksData in
            let book = BooksData(
                id: row.int(at: 0),
                book: row.string(at: 1) ?? "ללא שם",
                archive: 0,
                muallif: 0,
                bithoqoh: row.string(at: 3) ?? "",
                info: row.string(at: 3) ?? ""
            )
            book.catId = row.int(at: 2)
            book.pdfCs = 4
            return book
        }.first
    }

    func fetchBookInfo(for book: BooksData) {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return }

        if let info = try? db.fetch(query: """
            SELECT COALESCE(heShortDesc, ''), COALESCE(filePath, '')
            FROM book
            WHERE id = ?
            LIMIT 1
        """, parameters: [book.id], mapping: { row -> (String, String) in
            (row.string(at: 0) ?? "", row.string(at: 1) ?? "")
        }).first {
            book.bithoqoh = info.0
            book.info = info.0.isEmpty ? info.1 : info.0
        }
    }

    func getContent(bookId: Int, contentId: Int) -> BookContent? {
        lineContent(bookId: bookId, whereClause: "lineIndex = ?", parameters: [contentId])
    }

    func getFirstContent(bookId: Int) -> BookContent? {
        lineContent(bookId: bookId, whereClause: "1 = 1", parameters: [], orderClause: "ORDER BY lineIndex ASC")
    }

    func getNextContent(bookId: Int, after contentId: Int) -> BookContent? {
        lineContent(bookId: bookId, whereClause: "lineIndex > ?", parameters: [contentId], orderClause: "ORDER BY lineIndex ASC")
    }

    func getPreviousContent(bookId: Int, before contentId: Int) -> BookContent? {
        lineContent(bookId: bookId, whereClause: "lineIndex < ?", parameters: [contentId], orderClause: "ORDER BY lineIndex DESC")
    }

    private func lineContent(bookId: Int, whereClause: String, parameters: [Any], orderClause: String = "") -> BookContent? {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return nil }

        let sql = """
            SELECT lineIndex, content, heRef
            FROM line
            WHERE bookId = ? AND \(whereClause)
            \(orderClause)
            LIMIT 1
        """

        var allParameters: [Any] = [bookId]
        allParameters.append(contentsOf: parameters)

        return try? db.fetch(query: sql, parameters: allParameters) { row -> BookContent in
            let lineIndex = row.int(at: 0)
            let content = (row.string(at: 1) ?? "").otsariaPlainText
            let ref = row.string(at: 2) ?? ""
            let text = ref.isEmpty ? content : "\(ref)\n\n\(content)"
            return BookContent(id: lineIndex, nash: text, page: lineIndex + 1, part: 1)
        }.first
    }

    func getTOCEntries(for book: BooksData) -> [TOC] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return [] }

        return (try? db.fetch(query: """
            SELECT tt.text, te.level, COALESCE(te.lineIndex, ln.lineIndex) AS resolvedLineIndex
            FROM tocEntry te
            JOIN tocText tt ON tt.id = te.textId
            LEFT JOIN line ln ON ln.id = te.lineId
            WHERE te.bookId = ?
              AND resolvedLineIndex IS NOT NULL
            ORDER BY resolvedLineIndex, te.level, te.id
        """, parameters: [book.id]) { row -> TOC in
            TOC(
                bab: (row.string(at: 0) ?? "").otsariaPlainText,
                level: max(row.int(at: 1), 1),
                sub: 0,
                id: row.int(at: 2)
            )
        }) ?? []
    }

    func getTotalParts(bookId: Int) -> Int { 1 }

    func getMinPage(bookId: Int) -> Int { 1 }

    func getMaxPage(bookId: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return 0 }
        return (try? db.fetch(query: "SELECT COALESCE(MAX(lineIndex), 0) + 1 FROM line WHERE bookId = ?", parameters: [bookId]) { row in
            row.int(at: 0)
        }.first) ?? 0
    }
}
