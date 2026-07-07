import Foundation
import SQLite3

enum OtzariaSchema {
    enum Table {
        static let category = "category"
        static let book = "book"
        static let line = "line"
        static let tocEntry = "tocEntry"
        static let tocText = "tocText"
        static let link = "link"
        static let connectionType = "connection_type"
    }

    static let requiredTables: Set<String> = [
        Table.category,
        Table.book,
        Table.line,
        Table.tocEntry,
        Table.tocText,
        Table.link,
        Table.connectionType
    ]
}

struct OtzariaSchemaValidator {
    static func validate(_ db: OpaquePointer) throws {
        let statement = try OtzariaSQLiteStatement(database: db, sql: """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
        """)

        var existing = Set<String>()
        while try statement.step() {
            if let name = statement.columnString(0) {
                existing.insert(name)
            }
        }

        let missing = OtzariaSchema.requiredTables.subtracting(existing).sorted()
        if !missing.isEmpty {
            throw OtzariaSQLiteError.schemaMismatch(missingTables: missing)
        }
    }
}
