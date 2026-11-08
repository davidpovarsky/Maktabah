import Foundation

/// Resolves persisted work keys through SQLite facts; never infers identity from a display title.
enum OtzariaCanonicalLineLocatorResolver {
    static func bookID(for workKey: String, database: SQLiteDatabase,
                       capabilities: OtzariaDatabaseCapabilities) throws -> Int {
        let raw = workKey.hasPrefix("book:") ? String(workKey.dropFirst(5)) : workKey
        if let id = Int(raw), id > 0 {
            let found = try database.fetch(query: "SELECT id FROM book WHERE id = ?", parameters: [id]) { $0.int(at: 0) }
            guard found.count == 1 else { throw LibraryBackendError.invalidLocator }
            return id
        }
        guard capabilities.hasColumn("filePath", in: "book") else { throw LibraryBackendError.invalidLocator }
        let ids = try database.fetch(query: "SELECT id FROM book WHERE filePath = ? LIMIT 2", parameters: [workKey]) { $0.int(at: 0) }
        guard ids.count == 1, let id = ids.first else { throw LibraryBackendError.invalidLocator }
        return id
    }

    static func locator(bookID: Int, lineIndex: Int, database: SQLiteDatabase) throws -> TextLocator {
        let matches = try database.fetch(query: "SELECT lineIndex FROM line WHERE bookId = ? AND lineIndex = ? LIMIT 2",
            parameters: [bookID, lineIndex]) { $0.int(at: 0) }
        guard matches.count == 1 else { throw LibraryBackendError.invalidLocator }
        return .init(backend: .otzaria, workKey: "book:\(bookID)", position: .legacyLine(lineIndex))
    }
}
