import Foundation

enum OtzariaSearchResultResolver {
    private static let tablePrefix = "otzaria:"

    static var allowsSearchWithoutSelectedTables: Bool {
        #if os(iOS)
        OtzariaMaktabahBridge.shared.isEnabled
        #else
        false
        #endif
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
