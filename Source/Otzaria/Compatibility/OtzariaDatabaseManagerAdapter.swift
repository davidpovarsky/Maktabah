import Foundation

enum OtzariaDatabaseManagerAdapter {
    static var isEnabled: Bool {
        #if os(iOS)
        OtzariaMaktabahBridge.shared.isEnabled
        #else
        false
        #endif
    }

    @discardableResult
    static func setupFoldersIfEnabled() -> Bool {
        guard isEnabled else { return false }

        #if os(iOS)
        do {
            return try OtzariaMaktabahBridge.shared.openIfNeeded()
        } catch {
            print("Otzaria database could not be opened: \(error)")
            return false
        }
        #else
        return false
        #endif
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
        #if os(iOS)
        return try OtzariaMaktabahBridge.shared.fetchCategories()
        #else
        return nil
        #endif
    }

    static func fetchAllBooksGroupedByCategory() throws -> [Int: [BooksData]]? {
        guard isEnabled else { return nil }
        #if os(iOS)
        return try OtzariaMaktabahBridge.shared.fetchBooksGroupedByCategory()
        #else
        return nil
        #endif
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
        #if os(iOS)
        return (try? OtzariaMaktabahBridge.shared.fetchAuthors()) ?? []
        #else
        return nil
        #endif
    }

    static func fetchBook(byId bookId: Int) throws -> BooksData? {
        #if os(iOS)
        try OtzariaMaktabahBridge.shared.fetchBook(byId: bookId)
        #else
        nil
        #endif
    }

    static func resolveBook(stableKey: String, expectedBookId: Int) throws -> BooksData? {
        #if os(iOS)
        try OtzariaMaktabahBridge.shared.resolveBook(
            stableKey: stableKey,
            expectedBookId: expectedBookId
        )
        #else
        nil
        #endif
    }

    static func bookExists(id: Int) -> Bool? {
        guard isEnabled else { return nil }
        #if os(iOS)
        return (try? OtzariaMaktabahBridge.shared.fetchBook(byId: id)) != nil
        #else
        return nil
        #endif
    }

    static func isAuthorUsed(authorId: Int) -> Bool? {
        guard isEnabled else { return nil }
        return false
    }

    @discardableResult
    static func fetchBooksInfo(for bookData: BooksData) -> Bool {
        guard isEnabled else { return false }
        #if os(iOS)
        OtzariaMaktabahBridge.shared.fetchBookInfo(for: bookData)
        return true
        #else
        return false
        #endif
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
