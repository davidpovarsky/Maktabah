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
    private let unitModeKey = "otzaria_reader_unit_mode"
    private let lock = NSRecursiveLock()
    private var database: SQLiteDatabase?
    private var readingUnitService: OtzariaReadingUnitService?

    private init() {}

    var isEnabled: Bool { selectedDatabasePath != nil }

    var databasePath: String? { selectedDatabasePath }

    var databaseURL: URL? {
        selectedDatabasePath.map { URL(fileURLWithPath: $0) }
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

    func close() {
        resetConnection()
    }

    func resetConnection() {
        lock.lock()
        database = nil
        readingUnitService = nil
        lock.unlock()
    }

    @discardableResult
    func openIfNeeded() throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let path = selectedDatabasePath else { return false }
        if database != nil { return true }
        database = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
        readingUnitService = nil
        return true
    }

    private func requireDatabase() throws -> SQLiteDatabase {
        _ = try openIfNeeded()
        guard let database else {
            throw NSError(domain: "Otzaria", code: 2, userInfo: [NSLocalizedDescriptionKey: "Otzaria database is not selected"])
        }
        return database
    }

    var currentReadingUnitMode: OtzariaUnitMode {
        get {
            OtzariaUnitMode(
                storageValue: UserDefaults.standard.string(forKey: unitModeKey) ?? OtzariaUnitMode.paragraph.storageValue
            )
        }
        set {
            UserDefaults.standard.set(newValue.storageValue, forKey: unitModeKey)
        }
    }

    func withReadingUnitService<T>(_ work: (OtzariaReadingUnitService) -> T) -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard let db = try? requireDatabase() else { return nil }
        if readingUnitService == nil {
            readingUnitService = OtzariaReadingUnitService(database: db)
        }
        guard let readingUnitService else { return nil }
        return work(readingUnitService)
    }

    func withDatabase<T>(_ work: (SQLiteDatabase) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work(requireDatabase())
    }

    func fetchCategories() throws -> [CategoryData] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT id, parentId, title, level, orderIndex
            FROM category
            ORDER BY COALESCE(parentId, id), orderIndex, title
        """) { row in
            CategoryData(
                id: row.int(at: 0),
                name: row.string(at: 2) ?? "Untitled",
                level: row.int(at: 3),
                order: row.int(at: 4),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1)
            )
        }
    }

    func fetchAllBooks() throws -> [BooksData] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT b.id, b.title, b.categoryId, b.orderIndex, b.totalLines, b.heShortDesc, b.filePath, b.fileType,
                   COALESCE((SELECT ba.authorId FROM book_author ba WHERE ba.bookId = b.id ORDER BY ba.authorId LIMIT 1), 0) AS firstAuthorId
            FROM book b
            WHERE COALESCE(b.fileType, '') NOT IN ('link', 'url')
            ORDER BY b.categoryId, b.orderIndex, b.title
        """) { row -> BooksData in
            let shortDescription = row.string(at: 5) ?? ""
            let filePath = row.string(at: 6) ?? ""
            let book = BooksData(
                id: row.int(at: 0),
                book: row.string(at: 1) ?? "Untitled",
                archive: 0,
                muallif: row.int(at: 8),
                bithoqoh: shortDescription,
                info: shortDescription.isEmpty ? filePath : shortDescription
            )
            book.catId = row.int(at: 2)
            book.orderIndex = row.isNull(at: 3) ? nil : row.int(at: 3)
            book.totalLines = row.isNull(at: 4) ? nil : row.int(at: 4)
            book.pdfCs = 4
            return book
        }
    }

    func fetchBooksGroupedByCategory() throws -> [Int: [BooksData]] {
        Dictionary(grouping: try fetchAllBooks()) { $0.catId ?? 0 }
    }

    func fetchAuthors() throws -> [(id: Int, muallif: Muallif)] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT id, name
            FROM author
            ORDER BY name
        """) { row in
            (id: row.int(at: 0), muallif: Muallif(nama: row.string(at: 1) ?? "", info: "", namaLengkap: ""))
        }
    }

    func fetchAuthorMapForBooks() throws -> [Int: [Muallif]] {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        let rows = try db.fetch(query: """
            SELECT ba.bookId, a.name
            FROM book_author ba
            JOIN author a ON a.id = ba.authorId
            ORDER BY ba.bookId, a.name
        """) { row in
            (bookId: row.int(at: 0), author: Muallif(nama: row.string(at: 1) ?? "", info: "", namaLengkap: ""))
        }

        var result: [Int: [Muallif]] = [:]
        for row in rows {
            result[row.bookId, default: []].append(row.author)
        }
        return result
    }

    func fetchBook(byId bookId: Int) throws -> BooksData? {
        lock.lock()
        defer { lock.unlock() }
        let db = try requireDatabase()

        return try db.fetch(query: """
            SELECT b.id, b.title, b.categoryId, b.heShortDesc, b.orderIndex, b.totalLines, b.filePath,
                   COALESCE((SELECT ba.authorId FROM book_author ba WHERE ba.bookId = b.id ORDER BY ba.authorId LIMIT 1), 0) AS firstAuthorId
            FROM book b
            WHERE b.id = ?
            LIMIT 1
        """, parameters: [bookId]) { row -> BooksData in
            let shortDescription = row.string(at: 3) ?? ""
            let filePath = row.string(at: 6) ?? ""
            let book = BooksData(
                id: row.int(at: 0),
                book: row.string(at: 1) ?? "Untitled",
                archive: 0,
                muallif: row.int(at: 7),
                bithoqoh: shortDescription,
                info: shortDescription.isEmpty ? filePath : shortDescription
            )
            book.catId = row.int(at: 2)
            book.orderIndex = row.isNull(at: 4) ? nil : row.int(at: 4)
            book.totalLines = row.isNull(at: 5) ? nil : row.int(at: 5)
            book.pdfCs = 4
            return book
        }.first
    }

    func fetchBookInfo(for book: BooksData) {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return }

        if let info = try? db.fetch(query: """
            SELECT COALESCE(b.heShortDesc, ''), COALESCE(b.filePath, ''), COALESCE(s.name, ''),
                   COALESCE(b.fileType, ''), COALESCE(b.volume, ''), COALESCE(b.pages, ''), COALESCE(b.totalLines, 0),
                   COALESCE((
                       SELECT group_concat(a.name, ', ')
                       FROM book_author ba
                       JOIN author a ON a.id = ba.authorId
                       WHERE ba.bookId = b.id
                   ), '')
            FROM book b
            LEFT JOIN source s ON s.id = b.sourceId
            WHERE b.id = ?
            LIMIT 1
        """, parameters: [book.id], mapping: { row -> (String, String) in
            let shortDescription = row.string(at: 0) ?? ""
            let filePath = row.string(at: 1) ?? ""
            let sourceName = row.string(at: 2) ?? ""
            let fileType = row.string(at: 3) ?? ""
            let volume = row.string(at: 4) ?? ""
            let pages = row.string(at: 5) ?? ""
            let totalLines = row.int(at: 6)
            let authors = row.string(at: 7) ?? ""

            var parts: [String] = []
            if !shortDescription.isEmpty { parts.append(shortDescription) }
            if !authors.isEmpty { parts.append("Authors: \(authors)") }
            if !sourceName.isEmpty { parts.append("Source: \(sourceName)") }
            if !fileType.isEmpty { parts.append("Type: \(fileType)") }
            if !volume.isEmpty { parts.append("Volume: \(volume)") }
            if !pages.isEmpty { parts.append("Pages: \(pages)") }
            if totalLines > 0 { parts.append("Lines: \(totalLines)") }
            if !filePath.isEmpty { parts.append("Path: \(filePath)") }

            return (shortDescription, parts.joined(separator: "\n"))
        }).first {
            book.bithoqoh = info.0
            book.info = info.1
        }
    }

    func getContent(bookId: Int, contentId: Int) -> BookContent? {
        getReadingUnit(
            bookId: bookId,
            containingLineIndex: contentId,
            mode: currentReadingUnitMode
        ).map { makeBookContent(from: $0) }
    }

    func getFirstContent(bookId: Int) -> BookContent? {
        getFirstReadingUnit(bookId: bookId, mode: currentReadingUnitMode).map { makeBookContent(from: $0) }
    }

    func getNextContent(bookId: Int, after contentId: Int) -> BookContent? {
        getNextReadingUnit(bookId: bookId, afterLineIndex: contentId, mode: currentReadingUnitMode).map { makeBookContent(from: $0) }
    }

    func getPreviousContent(bookId: Int, before contentId: Int) -> BookContent? {
        getPreviousReadingUnit(bookId: bookId, beforeLineIndex: contentId, mode: currentReadingUnitMode).map { makeBookContent(from: $0) }
    }

    private func lineContent(bookId: Int, whereClause: String, parameters: [Any], orderClause: String = "") -> BookContent? {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return nil }

        let sql = """
            SELECT id, lineIndex, content, heRef
            FROM line
            WHERE bookId = ? AND \(whereClause)
            \(orderClause)
            LIMIT 1
        """

        var allParameters: [Any] = [bookId]
        allParameters.append(contentsOf: parameters)

        return try? db.fetch(query: sql, parameters: allParameters) { row -> BookContent in
            let lineIndex = row.int(at: 1)
            let content = (row.string(at: 2) ?? "").otsariaPlainText
            let ref = row.string(at: 3) ?? ""
            return BookContent(id: lineIndex, nash: content, page: lineIndex, part: 1, heRef: ref.isEmpty ? nil : ref)
        }.first
    }

    func getTOCEntries(for book: BooksData) -> [TOC] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return [] }

        return (try? db.fetch(query: """
            SELECT te.id, te.parentId, te.level, COALESCE(te.lineIndex, ln.lineIndex, 0) AS resolvedLineIndex, tt.text
            FROM tocEntry te
            JOIN tocText tt ON tt.id = te.textId
            LEFT JOIN line ln ON ln.id = te.lineId
            WHERE te.bookId = ?
            ORDER BY resolvedLineIndex, te.id
        """, parameters: [book.id]) { row -> TOC in
            TOC(
                bab: (row.string(at: 4) ?? "").otsariaPlainText,
                level: max(row.int(at: 2), 1),
                sub: 0,
                id: row.int(at: 3),
                parentId: row.isNull(at: 1) ? nil : row.int(at: 1),
                entryId: row.int(at: 0)
            )
        }) ?? []
    }

    func search(query: String, selectedBookIds: Set<Int>? = nil, limit: Int? = 200, mode: SearchMode = .phrase) -> [SearchResultItem] {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return [] }

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let terms: [String]
        switch mode {
        case .phrase:
            terms = [normalizedQuery]
        case .contains, .or:
            terms = normalizedQuery.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        guard !terms.isEmpty else { return [] }

        let matchQuery = mode == .or ? terms.joined(separator: " OR ") : terms.joined(separator: " ")
        let maxResults = limit ?? 200

        func bookFilterSQL(parameters: inout [Any]) -> String {
            guard let selectedBookIds, !selectedBookIds.isEmpty else { return "" }
            let ids = selectedBookIds.sorted()
            parameters.append(contentsOf: ids)
            return " AND l.bookId IN (" + Array(repeating: "?", count: ids.count).joined(separator: ",") + ")"
        }

        func mapRows(_ rows: [(Int, Int, Int, String, String, String)]) -> [SearchResultItem] {
            rows.map { row in
                let cleaned = row.4.otsariaPlainText
                let snippet = cleaned.snippetAround(keywords: terms, contextLength: 60)
                let highlighted = snippet.highlightedAttributedText(keywords: terms)
                return SearchResultItem(
                    archive: "Otzaria",
                    tableName: "otzaria:\(row.1)",
                    bookId: row.1,
                    bookTitle: row.5,
                    page: row.2,
                    part: 1,
                    attributedText: highlighted
                )
            }
        }

        var ftsParameters: [Any] = [matchQuery]
        let ftsBookFilter = bookFilterSQL(parameters: &ftsParameters)
        ftsParameters.append(maxResults)
        let ftsSQL = """
            SELECT l.id, l.bookId, l.lineIndex, COALESCE(l.heRef, ''), l.content, b.title
            FROM line_fts_with_nikud f
            JOIN line l ON l.id = f.rowid
            JOIN book b ON b.id = l.bookId
            WHERE line_fts_with_nikud MATCH ?\(ftsBookFilter)
            ORDER BY rank
            LIMIT ?
        """

        if let rows = try? db.fetch(query: ftsSQL, parameters: ftsParameters, mapping: { row in
            (row.int(at: 0), row.int(at: 1), row.int(at: 2), row.string(at: 3) ?? "", row.string(at: 4) ?? "", row.string(at: 5) ?? "")
        }), !rows.isEmpty {
            return mapRows(rows)
        }

        var likeParameters: [Any] = []
        let likeClauses = terms.map { term -> String in
            likeParameters.append("%\(term)%")
            return "l.content LIKE ?"
        }
        let joiner = mode == .or ? " OR " : " AND "
        let likeCondition = likeClauses.joined(separator: joiner)
        let likeBookFilter = bookFilterSQL(parameters: &likeParameters)
        likeParameters.append(maxResults)
        let likeSQL = """
            SELECT l.id, l.bookId, l.lineIndex, COALESCE(l.heRef, ''), l.content, b.title
            FROM line l
            JOIN book b ON b.id = l.bookId
            WHERE (\(likeCondition))\(likeBookFilter)
            ORDER BY l.bookId, l.lineIndex
            LIMIT ?
        """

        let rows = (try? db.fetch(query: likeSQL, parameters: likeParameters, mapping: { row in
            (row.int(at: 0), row.int(at: 1), row.int(at: 2), row.string(at: 3) ?? "", row.string(at: 4) ?? "", row.string(at: 5) ?? "")
        })) ?? []
        return mapRows(rows)
    }

    func getTotalParts(bookId: Int) -> Int { 1 }

    func getMinPage(bookId: Int) -> Int { 0 }

    func getMaxPage(bookId: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let db = try? requireDatabase() else { return 0 }
        return (try? db.fetch(query: """
            SELECT COALESCE(
                (SELECT totalLines FROM book WHERE id = ?),
                (SELECT MAX(lineIndex) + 1 FROM line WHERE bookId = ?),
                0
            )
        """, parameters: [bookId, bookId]) { row in
            row.int(at: 0)
        }.first) ?? 0
    }
}
