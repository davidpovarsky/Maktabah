//
//  LibraryDataManager.swift
//  maktab
//
//  Created by MacBook on 03/12/25.
//

import Foundation

class LibraryDataManager {
    static let shared = LibraryDataManager()
    var db: DatabaseManager = .shared
    
    private(set) var allRootCategories: [CategoryData] = []
    private(set) var categoryMap: [Int: CategoryData] = [:]

    private(set) lazy var booksById: [Int: BooksData] = [:]
    private(set) lazy var archives: [Int: ArchiveInfo] = [:]
    private var archivesBuiltFromFullData: Bool = false

    private(set) var searchIsRunning: Bool = false

    lazy var authorsCache: [Int: Muallif] = [:]

    private(set) var isDataLoaded = false
    private var isAuthorsLoaded = false

    private var loadingTask: Task<Void, Never>?

    private init() {}

    func loadData() async {
        if isDataLoaded { return }

        if let existingTask = loadingTask {
            await existingTask.value
            return
        }

        let newTask = Task {
            do {
                let results = try await Task.detached(priority: .userInitiated)
                { [unowned self] in
                    let allCategories = try db.fetchAllCategories()
                    let (localRootCats, localCategoryMap) =
                        buildCategoryHierarchy(from: allCategories)
                    let localBooksById = try loadBooksAndIndex(
                        for: allCategories
                    )
                    return (localRootCats, localCategoryMap, localBooksById)
                }.value

                allRootCategories = results.0
                categoryMap = results.1
                booksById = results.2
                await applyBundleDownloadMetadataIfNeeded()
                isDataLoaded = true

                // Bangun integration cache di background setelah data siap.
                // buildAllIfNeeded() hanya scan SQLite untuk archive yang belum ada
                // cache-nya — setelah itu filterNotIntegrated/filterIntegrated O(1).
                Task.detached(priority: .background) {
                    IntegrationCache.shared.buildAllIfNeeded()
                }
            } catch {
                #if DEBUG
                    print("Error loading data: \(error)")
                #endif
            }

            // 5. Bersihkan task reference setelah selesai
            loadingTask = nil
        }

        loadingTask = newTask
        await newTask.value
    }

    // MARK: - Helpers for loading data
    private func buildCategoryHierarchy(from allCategories: [CategoryData]) -> (
        rootCats: [CategoryData], categoryMap: [Int: CategoryData]
    ) {
        var localCategoryMap: [Int: CategoryData] = [:]
        var localRootCats: [CategoryData] = []
        var currentRoot: CategoryData?

        // Build hierarki berdasarkan level dan urutan
        for cat in allCategories {
            localCategoryMap[cat.id] = cat

            if cat.level == 0 {
                localRootCats.append(cat)
                currentRoot = cat
            } else if cat.level == 1, let root = currentRoot {
                root.children.append(cat)
            }
        }

        return (localRootCats, localCategoryMap)
    }

    private func loadBooksAndIndex(for allCategories: [CategoryData]) throws
        -> [Int: BooksData]
    {
        var localBooksById: [Int: BooksData] = [:]

        // Fetch all books grouped by category to avoid N+1 query
        let allBooksGrouped = try db.fetchAllBooksGroupedByCategory()

        // Assign buku untuk setiap kategori
        for cat in allCategories {
            let books = allBooksGrouped[cat.id] ?? []
            cat.children.append(contentsOf: books)
            for book in books {
                if localBooksById[book.id] == nil {
                    localBooksById[book.id] = book
                }
            }
        }

        return localBooksById
    }

    private func applyBundleDownloadMetadataIfNeeded() async {
        guard AppConfig.isUsingBundleMode,
              let indexURL = AppConfig.bookIndexURL else { return }

        do {
            let entries = try await BookDownloadIndexCache.shared.entries(
                indexURL: indexURL,
                urlSession: URLSession.shared
            )

            for (bookId, entry) in entries {
                guard let book = booksById[bookId] else { continue }
                book.downloadFilename = entry.filename
                book.compressedDownloadSize = entry.sizeZst
            }
        } catch {
            #if DEBUG
                print("Failed to apply bundle download metadata:", error)
            #endif
        }
    }

    func getAllAuthors() -> [(id: Int, muallif: Muallif)] {
        if isAuthorsLoaded {
            return authorsCache.map { (id: $0.key, muallif: $0.value) }
        }

        let fetched = DatabaseManager.shared.fetchAllAuthors()
        for author in fetched {
            authorsCache[author.id] = author.muallif
        }
        isAuthorsLoaded = true
        return fetched
    }

    func resetState() {
        loadingTask?.cancel()
        loadingTask = nil
        isDataLoaded = false
        isAuthorsLoaded = false
        allRootCategories.removeAll()
        categoryMap.removeAll()
        authorsCache.removeAll()
        booksById.removeAll()
        archives.removeAll()
        archivesBuiltFromFullData = false
    }

    func updateAuthorInCache(id: Int, muallif: Muallif) {
        authorsCache[id] = muallif
    }

    func removeAuthorFromCache(id: Int) {
        authorsCache.removeValue(forKey: id)
    }

    func getBook(_ ids: [Int]) -> [BooksData] {
        var books = [BooksData]()
        for id in ids {
            if let book = booksById[id] {
                books.append(book)
                continue
            }

            do {
                if let book =  try db.fetchBook(byId: id) {
                    booksById[id] = book
                    books.append(book)
                }
            } catch {
                #if DEBUG
                    print(error.localizedDescription)
                #endif
            }
        }

        return books
    }

    func buildArchive() async {
        if archivesBuiltFromFullData { return }
        guard isDataLoaded else { return }
        // gunakan var lokal agar thread-safe selama build
        var archives: [Int: ArchiveInfo] = [:]
        var seenTables = Set<String>() // untuk menghindari duplikat

        // rekursif kumpulkan BooksData dari node (CategoryData atau BooksData)
        func collectBooks(from node: Any) -> [BooksData] {
            var result: [BooksData] = []

            if let book = node as? BooksData {
                result.append(book)
            } else if let cat = node as? CategoryData {
                for child in cat.children {
                    result.append(contentsOf: collectBooks(from: child))
                }
            }
            return result
        }

        // iterasi semua root category dan kumpulkan buku dari seluruh subtree
        for root in allRootCategories {
            let books = collectBooks(from: root)
            for book in books {
                let archiveId = book.archive
                // LEWATI SEMUA ARCHIVE = 0
                if archiveId == 0 {
                    continue
                }
                let tableName = "b\(book.id)"

                // hindari memasukkan tabel yang sama berkali-kali
                if seenTables.contains("\(archiveId)|\(tableName)") {
                    continue
                }
                seenTables.insert("\(archiveId)|\(tableName)")

                if archives[archiveId] == nil {
                    archives[archiveId] = ArchiveInfo(tables: [], books: [])
                }

                archives[archiveId]?.tables.append(tableName)
                archives[archiveId]?.books.append(book)
            }
        }

        // assign ke property jika Anda mau menyimpan hasil build
        self.archives = archives
        archivesBuiltFromFullData = true
    }

    private func createConnections(dbPath: String, count: Int = 4) -> [DBConnectionType] {
        var connections: [DBConnectionType] = []

        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("⚠️ File tidak ditemukan: \(dbPath)")
            return []
        }

        for i in 0..<count {
            do {
                let conn = try SQLiteConnection(dbPath: dbPath)
                connections.append(conn)
            } catch {
                print("⚠️ Connection \(i+1) gagal untuk \(dbPath): \(error)")
            }
        }

        return connections
    }

    func getDatabasePath(forArchive archiveId: Int) -> String? {
        AppConfig.archiveDatabasePath(archiveId: archiveId)
    }

    func getCheckedTables(_ items: [Any]) -> Set<String> {
        var checkedTables = Set<String>()

        func traverse(_ items: [Any]) {
            for item in items {
                if let category = item as? CategoryData {
                    // Jika kategori dicentang, kita tetap harus cek anaknya
                    // (siapa tahu ada user uncheck sebagian anak)
                    traverse(category.children)
                } else if let book = item as? BooksData {
                    if book.isChecked {
                        // Format nama tabel: "b" + id
                        checkedTables.insert("b\(book.id)")
                    }
                }
            }
        }

        traverse(items)
        return checkedTables
    }

    func performSearch(
        tableToScan: Set<String> = [],
        searchEngine: SearchEngine,
        query: String,
        mode: SearchMode,
        onInitialize: @escaping (Int) -> Void,  // totalTables
        onTableProgress: @escaping (Int) -> Void,  // completedTables
        onRowProgress: @escaping (String, String, Int, Int) -> Void,  // ✅ BARU
        completion: @escaping (SearchResultItem) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        searchIsRunning = true
        let allowed = tableToScan

        let searchKeywords: [String]
        switch mode {
        case .phrase:
            if query.trimmingCharacters(in: .whitespaces).isEmpty { return }
            searchKeywords = [query.normalizeArabic()]
        case .contains, .or:
            searchKeywords = query.normalizeArabic().components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        if searchKeywords.isEmpty { return }

        var allowedByArchive: [Int: Set<String>] = [:]
        for tableName in allowed {
            let bookId = Int(tableName.dropFirst()) ?? 0
            if let book = booksById[bookId] {
                allowedByArchive[book.archive, default: []].insert(tableName)
            }
        }

        #if DEBUG
            print(
                "Filter: Dari \(archives.count) archive → \(allowedByArchive.keys.count) relevan")
        #endif

        var totalTables = 0

        for archiveId in allowedByArchive.keys.sorted() {
            guard let archiveInfo = archives[archiveId] else { continue }
            guard let dbPath = getDatabasePath(forArchive: archiveId) else { return }
            let connections = createConnections(dbPath: dbPath, count: 4)

            if connections.isEmpty {
                print("⚠️ Skip archive \(archiveId): Tidak ada koneksi")
                continue
            }

            // Validasi: pastikan table ada di archive dan diizinkan (O(1) lookup per item)
            let allowedForThisArchive = allowedByArchive[archiveId] ?? []
            let relevantTablesForArchive = archiveInfo.tables.filter {
                allowedForThisArchive.contains($0)
            }
            guard !relevantTablesForArchive.isEmpty else { continue }

            totalTables += relevantTablesForArchive.count

            searchEngine.registerDB(
                archiveId: String(archiveId),
                tables: archiveInfo.tables,  // Masih kirim semua tables, filtering di worker
                connections: connections,
                batchSize: 200
            )
            #if DEBUG
                print("Worker archive \(archiveId): \(relevantTablesForArchive.count) tables")
            #endif
        }

        if totalTables == 0 { return }

        searchEngine.checkAndResumeIfNeeded { [weak self] resumed in
            guard let self, !resumed else { return }

            var completedTablesGlobal = 0

            searchEngine.startSearch(
                keywords: searchKeywords,
                allowedTables: allowed.isEmpty ? nil : allowed,
                mode: mode,
                onInitialize: { totalWorkers in
                    Task { @MainActor [totalTables] in
                        // Kirim hanya total tables
                        onInitialize(totalTables)
                    }
                },
                onTableComplete: { archiveId, completedTablesInWorker in
                    completedTablesGlobal += 1
                    Task { @MainActor [completedTablesGlobal] in
                        onTableProgress(completedTablesGlobal)
                    }
                }, 
                onRowProgress: { archiveId, tableName, current, total in
                    // ✅ Forward ke UI
                    Task { @MainActor in
                        onRowProgress(archiveId, tableName, current, total)
                    }
                },
                onResult: { tableName, archive, content in
                    Task { @MainActor in
                        let bookId = Int(tableName.dropFirst()) ?? 0
                        let bookTitle = self.booksById[bookId]?.book ?? ""
                        let snippet = content.nash
                            .normalizeArabic()
                            .snippetAround(keywords: searchKeywords, contextLength: 60)
                        let highlightedSnippet = snippet.highlightedAttributedText(
                            keywords: searchKeywords)
                        completion(
                            SearchResultItem(
                                archive: archive,
                                tableName: tableName,
                                bookId: content.id,
                                bookTitle: bookTitle,
                                page: content.page,
                                part: content.part,
                                attributedText: highlightedSnippet
                            ))
                    }
                },
                onComplete: { [weak self] in
                    onComplete()
                    self?.stopSearch()
                }
            )
        }
    }

    func stopSearch() {
        searchIsRunning = false
    }

    // MARK: - Generic Hierarchy Filtering logic

    func filterContent(
        with searchText: String,
        displayedCategories: inout [CategoryData],
        baseCategories: [CategoryData]? = nil
    ) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let base = baseCategories ?? allRootCategories

        if trimmed.isEmpty {
            // Tampilkan semua (sesuai base)
            displayedCategories = base
        } else {
            // Filter dari base
            displayedCategories = base.compactMap { rootCategory in
                filterCategory(rootCategory, searchText: trimmed.lowercased())
            }
        }

        return !trimmed.isEmpty
    }

    func filterCategory(_ category: CategoryData, searchText: String) -> CategoryData? {
        let categoryMatches = category.name.localizedStandardContains(searchText)

        // Filter children (bisa kategori atau buku)
        let filteredChildren = category.children.compactMap { child -> Any? in
            if let childCategory = child as? CategoryData {
                return filterCategory(childCategory, searchText: searchText)
            } else if let book = child as? BooksData {
                if book.book.localizedStandardContains(searchText) {
                    return book
                }
            }
            return nil
        }

        // Jika kategori match atau ada children yang match, return kategori
        if categoryMatches || !filteredChildren.isEmpty {
            let cloned = category.copy() as! CategoryData
            cloned.children = filteredChildren
            return cloned
        }

        return nil
    }

    /// Fungsi helper utama untuk memfilter hierarchy berdasarkan kondisi buku dan kategori.
    private func applyHierarchyFilter(
        to category: CategoryData,
        bookCondition: (BooksData) -> Bool,
        includeCategoryIfEmpty: (CategoryData) -> Bool = { _ in false }
    ) -> CategoryData? {
        let filteredChildren: [Any] = category.children.compactMap { child in
            if let book = child as? BooksData {
                return bookCondition(book) ? book : nil
            } else if let subCategory = child as? CategoryData {
                return applyHierarchyFilter(
                    to: subCategory,
                    bookCondition: bookCondition,
                    includeCategoryIfEmpty: includeCategoryIfEmpty
                )
            }
            return nil
        }

        // Tentukan apakah kategori ini harus disertakan
        let shouldInclude =
        !filteredChildren.isEmpty || includeCategoryIfEmpty(category)

        if shouldInclude {
            let cloned = category.copy() as! CategoryData
            cloned.children = filteredChildren
            return cloned
        }

        return nil
    }

    /// Kembalikan salinan hierarchy yang hanya berisi kitab yang belum terintegrasi.
    func filterNotIntegrated() -> [CategoryData] {
        return allRootCategories.compactMap { root in
            applyHierarchyFilter(to: root) {
                !BookArchiveIntegrator.shared.isBookIntegrated($0)
            }
        }
    }

    func filterIntegrated() -> [CategoryData] {
        return allRootCategories.compactMap { root in
            applyHierarchyFilter(to: root) {
                BookArchiveIntegrator.shared.isBookIntegrated($0)
            }
        }
    }

    func loadBookInfo(_ id: Int, completion: @escaping () -> Void?) {
        defer { completion() }
        guard let book = booksById[id],
              book.info.isEmpty, book.bithoqoh.isEmpty
        else { return }
        db.fetchBooksInfo(for: book)
    }

    func removeBookFromMemory(id: Int, muallifId: Int) {
        if id > 32792 {
            booksById.removeValue(forKey: id)
            for root in allRootCategories {
                removeBookFromHierarchy(root, bookId: id)
            }
        }

        if id > 2515 {
            removeAuthorFromCache(id: muallifId)
        }
    }

    private func removeBookFromHierarchy(_ category: CategoryData, bookId: Int) {
        category.children.removeAll { ($0 as? BooksData)?.id == bookId }
        for child in category.children {
            if let sub = child as? CategoryData {
                removeBookFromHierarchy(sub, bookId: bookId)
            }
        }
    }
}

extension LibraryDataManager {

    /// Update atau insert books berdasarkan BookUpdateResult
    /// - Parameter updateResults: Results dari book update process
    func processBookUpdates(_ updateResults: [BookUpdateResult]) async throws {
        guard !updateResults.isEmpty else { return }

        var insertedBooks: [(categoryId: Int, book: BooksData)] = []
        var updatedBookIds: Set<Int> = []

        for result in updateResults {
            let bookId = result.bookId

            switch result.action {
            case .inserted:
                // Fetch buku baru dari database
                if let book = try db.fetchBook(byId: bookId) {
                    // Tambahkan ke data structures
                    booksById[bookId] = book

                    // Dapatkan category ID
                    let categoryId = result.catId

                    // Tambahkan ke category hierarchy
                    if let category = categoryMap[categoryId] {
                        category.children.append(book)
                        insertedBooks.append((categoryId, book))
                    }

                    // Update archive
                    await updateArchiveForBooks([book])
                }

            case .updated:
                // Fetch buku yang diupdate dari database
                if let book = try db.fetchBook(byId: bookId) {
                    // Update booksById cache
                    booksById[bookId] = book

                    // Update di hierarchy tree
                    updateBookInHierarchy(book)

                    // Clear cache
                    BookPageCache.shared.remove(bookId: bookId)

                    // Update archive
                    await updateArchiveForBooks([book])

                    updatedBookIds.insert(bookId)
                }

            case .skipped:
                // Do nothing
                break
            }
        }

        // Kirim combined notification
        if !insertedBooks.isEmpty || !updatedBookIds.isEmpty {
            NotificationCenter.default.postBooksChanged(
                insertedBooks: insertedBooks,
                updatedBookIds: updatedBookIds
            )
        }
    }

    /// Update single book di hierarchy tree
    private func updateBookInHierarchy(_ updatedBook: BooksData) {
        // Cari book di tree dan replace
        for category in allRootCategories {
            if replaceBookInCategory(category, with: updatedBook) {
                break
            }
        }
    }

    private func replaceBookInCategory(_ category: CategoryData, with book: BooksData) -> Bool {
        // Cek children langsung
        for (index, child) in category.children.enumerated() {
            if let existingBook = child as? BooksData, existingBook.id == book.id {
                category.children[index] = book
                return true
            } else if let subCategory = child as? CategoryData {
                if replaceBookInCategory(subCategory, with: book) {
                    return true
                }
            }
        }
        return false
    }

    /// Update archive untuk beberapa buku
    private func updateArchiveForBooks(_ books: [BooksData]) async {
        for book in books {
            let archiveId = book.archive
            guard archiveId != 0 else { continue }

            let tableName = "b\(book.id)"

            if archives[archiveId] == nil {
                archives[archiveId] = ArchiveInfo(tables: [], books: [])
            }

            // Remove old entry if exists
            if let index = archives[archiveId]?.tables.firstIndex(of: tableName) {
                archives[archiveId]?.tables.remove(at: index)
                archives[archiveId]?.books.remove(at: index)
            }

            // Add new entry
            archives[archiveId]?.tables.append(tableName)
            archives[archiveId]?.books.append(book)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let booksChanged = Notification.Name("booksChanged")
    static let bookIntegrated = Notification.Name("bookIntegrated")
}

// MARK: - Type-safe Posting Helper

extension NotificationCenter {
    func postBooksChanged(
        insertedBooks: [(categoryId: Int, book: BooksData)],
        updatedBookIds: Set<Int>
    ) {
        let payload = BooksChangedNotification(
            insertedBooks: insertedBooks,
            updatedBookIds: updatedBookIds
        )
        post(name: .booksChanged, object: payload)
    }
}
