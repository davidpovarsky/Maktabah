import Foundation
import SQLite3

struct OtzariaBookSchemaProjection: Equatable {
    let filePath: String
    let fileType: String
    let volume: String
    let pages: String
    let eligiblePredicate: String
}

struct OtzariaTOCSchemaProjection: Equatable {
    let resolvedLineIndex: String
}

enum OtzariaBookSchemaCompatibility {
    static func projection(columns: Set<String>, alias: String = "b") -> OtzariaBookSchemaProjection {
        func expression(_ column: String, fallback: String) -> String {
            columns.contains(column) ? "\(alias).\(column)" : fallback
        }

        let hasFileType = columns.contains("fileType")
        return OtzariaBookSchemaProjection(
            filePath: expression("filePath", fallback: "NULL"),
            fileType: expression("fileType", fallback: "'txt'"),
            volume: expression("volume", fallback: "NULL"),
            pages: expression("pages", fallback: "NULL"),
            eligiblePredicate: hasFileType
                ? "COALESCE(\(alias).fileType, '') NOT IN ('link', 'url')"
                : "1 = 1"
        )
    }

    static func projection(in database: SQLiteDatabase, alias: String = "b") throws
        -> OtzariaBookSchemaProjection {
        let columns = Set(try database.fetch(query: "PRAGMA table_info(book)") { row in
            row.string(at: 1) ?? ""
        })
        return projection(columns: columns, alias: alias)
    }

    static func projection(in database: OpaquePointer, alias: String = "b") throws
        -> OtzariaBookSchemaProjection {
        projection(columns: try sqliteColumns(in: database, table: "book"), alias: alias)
    }
}

enum OtzariaTOCSchemaCompatibility {
    static func projection(
        columns: Set<String>,
        tocAlias: String = "te",
        lineAlias: String = "ln"
    ) -> OtzariaTOCSchemaProjection {
        OtzariaTOCSchemaProjection(
            resolvedLineIndex: columns.contains("lineIndex")
                ? "COALESCE(\(tocAlias).lineIndex, \(lineAlias).lineIndex)"
                : "\(lineAlias).lineIndex"
        )
    }

    static func projection(
        in database: SQLiteDatabase,
        tocAlias: String = "te",
        lineAlias: String = "ln"
    ) throws -> OtzariaTOCSchemaProjection {
        let columns = Set(try database.fetch(query: "PRAGMA table_info(tocEntry)") { row in
            row.string(at: 1) ?? ""
        })
        return projection(columns: columns, tocAlias: tocAlias, lineAlias: lineAlias)
    }

    static func projection(
        in database: OpaquePointer,
        tocAlias: String = "te",
        lineAlias: String = "ln"
    ) throws -> OtzariaTOCSchemaProjection {
        projection(
            columns: try sqliteColumns(in: database, table: "tocEntry"),
            tocAlias: tocAlias,
            lineAlias: lineAlias
        )
    }
}

private func sqliteColumns(in database: OpaquePointer, table: String) throws -> Set<String> {
    var statement: OpaquePointer?
    let sql = "PRAGMA table_info(\(table))"
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw NSError(
            domain: "OtzariaBookSchemaCompatibility",
            code: Int(sqlite3_errcode(database)),
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
        )
    }
    defer { sqlite3_finalize(statement) }

    var columns = Set<String>()
    var status = sqlite3_step(statement)
    while status == SQLITE_ROW {
        if let name = sqlite3_column_text(statement, 1) {
            columns.insert(String(cString: name))
        }
        status = sqlite3_step(statement)
    }
    guard status == SQLITE_DONE else {
        throw NSError(
            domain: "OtzariaBookSchemaCompatibility",
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
        )
    }
    return columns
}
