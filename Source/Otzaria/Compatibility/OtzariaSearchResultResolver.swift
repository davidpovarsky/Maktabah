import Foundation

enum OtzariaSearchResultResolver {
    private static let tablePrefix = "otzaria:"

    static var allowsSearchWithoutSelectedTables: Bool {
        OtzariaMaktabahBridge.shared.isEnabled
    }

    static func bookId(from tableName: String) -> Int? {
        if tableName.hasPrefix(tablePrefix) {
            return Int(tableName.dropFirst(tablePrefix.count))
        }
        if tableName.hasPrefix("b") {
            return Int(tableName.dropFirst())
        }
        return Int(tableName)
    }

    static func resolveBook(
        from result: SearchResultItem,
        libraryDataManager: LibraryDataManager
    ) -> BooksData? {
        guard let bookId = bookId(from: result.tableName) else { return nil }
        return libraryDataManager.getBook([bookId]).first
    }
}
