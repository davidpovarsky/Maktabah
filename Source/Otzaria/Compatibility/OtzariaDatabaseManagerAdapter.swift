import Foundation

enum OtzariaDatabaseManagerAdapter {
    static var isEnabled: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    @discardableResult
    static func setupFoldersIfEnabled() -> Bool {
        guard isEnabled else { return false }

        do {
            try OtzariaMaktabahBridge.shared.openIfNeeded()
        } catch {
            print("Otzaria database could not be opened: \(error)")
        }
        return true
    }

    static var shouldSetupTarjamahConnection: Bool {
        !isEnabled
    }

    static var localVersionDisplay: String? {
        guard isEnabled else { return nil }
        return "Otzaria"
    }

    static func fetchAllCategories() throws -> [CategoryData]? {
        guard isEnabled else { return nil }
        return try OtzariaMaktabahBridge.shared.fetchCategories()
    }

    static func fetchAllBooksGroupedByCategory() throws -> [Int: [BooksData]]? {
        guard isEnabled else { return nil }
        return try OtzariaMaktabahBridge.shared.fetchBooksGroupedByCategory()
    }

    static func getMaxBookId() -> Int? {
        guard isEnabled else { return nil }
        return 0
    }

    static func getMaxAuthId() -> Int? {
        guard isEnabled else { return nil }
        return 0
    }

    static func fetchAllAuthors() -> [(id: Int, muallif: Muallif)]? {
        guard isEnabled else { return nil }
        return (try? OtzariaMaktabahBridge.shared.fetchAuthors()) ?? []
    }

    static func fetchBook(byId bookId: Int) throws -> BooksData? {
        try OtzariaMaktabahBridge.shared.fetchBook(byId: bookId)
    }

    static func bookExists(id: Int) -> Bool? {
        guard isEnabled else { return nil }
        return (try? OtzariaMaktabahBridge.shared.fetchBook(byId: id)) != nil
    }

    static func isAuthorUsed(authorId: Int) -> Bool? {
        guard isEnabled else { return nil }
        return false
    }

    @discardableResult
    static func fetchBooksInfo(for bookData: BooksData) -> Bool {
        guard isEnabled else { return false }
        OtzariaMaktabahBridge.shared.fetchBookInfo(for: bookData)
        return true
    }

    static func loadShortsForBook(_ bkid: String) -> ShortsMapping? {
        guard isEnabled else { return nil }
        return ShortsMapping(map: [:], sortedKeys: [])
    }

    static func getAuthor(_ id: Int) -> Muallif? {
        guard isEnabled else { return nil }
        return nil
    }

    static func checkArchiveAvailability(archiveId: Int) -> Bool? {
        guard isEnabled else { return nil }
        return true
    }
}
