import Foundation
import SQLite3

enum OtzariaLineContentError: LocalizedError, Equatable {
    case unsupportedSQLiteType(Int32)
    case compressedRowWithoutDictionaries
    case invalidFrameSize(UInt64)
    case unknownDictionary(UInt32)
    case decompressionFailed(String)
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .unsupportedSQLiteType(let type): "Unsupported Otzaria line-content SQLite type \(type)."
        case .compressedRowWithoutDictionaries: "Compressed Otzaria content has no zstd dictionary table."
        case .invalidFrameSize(let size): "Invalid Otzaria zstd frame size \(size)."
        case .unknownDictionary(let id): "Otzaria zstd dictionary \(id) is missing."
        case .decompressionFailed(let message): "Could not decode Otzaria content: \(message)"
        case .invalidUTF8: "Decoded Otzaria content is not valid UTF-8."
        }
    }
}

struct OtzariaLineContentProjection: Equatable {
    let join: String
    let expression: String
}

enum OtzariaLineContentCompatibility {
    static func projection(
        capabilities: OtzariaDatabaseCapabilities,
        lineAlias: String = "l",
        contentAlias: String = "lc"
    ) -> OtzariaLineContentProjection {
        if capabilities.hasSplitLineContent {
            return OtzariaLineContentProjection(
                join: "LEFT JOIN line_content \(contentAlias) ON \(contentAlias).id = \(lineAlias).id",
                expression: "\(contentAlias).content"
            )
        }
        return OtzariaLineContentProjection(join: "", expression: "\(lineAlias).content")
    }
}

final class OtzariaLineContentDecoder {
    static let maximumLineBytes = 16 * 1024 * 1024

    private let context: OpaquePointer?
    private var dictionaries: [UInt32: OpaquePointer] = [:]

    init(database: OpaquePointer, capabilities: OtzariaDatabaseCapabilities) throws {
        guard capabilities.hasZstdDictionaries else {
            context = nil
            return
        }
        guard let context = ZSTD_createDCtx() else {
            throw OtzariaLineContentError.decompressionFailed("ZSTD_createDCtx failed")
        }
        self.context = context
        let statement = try OtzariaSQLiteStatement(database: database, sql: "SELECT dict FROM zstd_dict")
        do {
            while try statement.step() {
                guard let data = statement.columnData(0) else { continue }
                let dictionary = data.withUnsafeBytes { bytes in
                    ZSTD_createDDict(bytes.baseAddress, bytes.count)
                }
                guard let dictionary else {
                    throw OtzariaLineContentError.decompressionFailed("ZSTD_createDDict failed")
                }
                let id = ZSTD_getDictID_fromDDict(dictionary)
                if let previous = dictionaries.updateValue(dictionary, forKey: id) {
                    ZSTD_freeDDict(previous)
                }
            }
        } catch {
            ZSTD_freeDCtx(context)
            for dictionary in dictionaries.values { ZSTD_freeDDict(dictionary) }
            dictionaries.removeAll()
            throw error
        }
    }

    convenience init(database: SQLiteDatabase, capabilities: OtzariaDatabaseCapabilities) throws {
        try self.init(database: database.dbPointer, capabilities: capabilities)
    }

    deinit {
        ZSTD_freeDCtx(context)
        for dictionary in dictionaries.values { ZSTD_freeDDict(dictionary) }
    }

    func decode(row: SQLiteRow, at index: Int32) throws -> String {
        try decode(type: row.type(at: index), text: row.string(at: index), data: row.blob(at: index))
    }

    func decode(statement: OtzariaSQLiteStatement, at index: Int32) throws -> String {
        try decode(
            type: statement.columnType(index),
            text: statement.columnString(index),
            data: statement.columnData(index)
        )
    }

    func decode(type: Int32, text: String?, data: Data?) throws -> String {
        switch type {
        case SQLITE_NULL:
            return ""
        case SQLITE_TEXT:
            return text ?? ""
        case SQLITE_BLOB:
            guard let data else { return "" }
            return try decode(frame: data)
        default:
            throw OtzariaLineContentError.unsupportedSQLiteType(type)
        }
    }

    func decode(frame: Data) throws -> String {
        guard context != nil else {
            throw OtzariaLineContentError.compressedRowWithoutDictionaries
        }
        let size = frame.withUnsafeBytes { bytes in
            ZSTD_getFrameContentSize(bytes.baseAddress, bytes.count)
        }
        guard size != ZSTD_CONTENTSIZE_UNKNOWN,
              size != ZSTD_CONTENTSIZE_ERROR,
              size <= UInt64(Self.maximumLineBytes) else {
            throw OtzariaLineContentError.invalidFrameSize(size)
        }
        let dictionaryID = frame.withUnsafeBytes { bytes in
            ZSTD_getDictID_fromFrame(bytes.baseAddress, bytes.count)
        }
        guard let dictionary = dictionaries[dictionaryID] else {
            throw OtzariaLineContentError.unknownDictionary(dictionaryID)
        }
        var output = Data(count: Int(size))
        let written = output.withUnsafeMutableBytes { destination in
            frame.withUnsafeBytes { source in
                ZSTD_decompress_usingDDict(
                    context,
                    destination.baseAddress,
                    destination.count,
                    source.baseAddress,
                    source.count,
                    dictionary
                )
            }
        }
        guard ZSTD_isError(written) == 0, written == Int(size) else {
            throw OtzariaLineContentError.decompressionFailed(String(cString: ZSTD_getErrorName(written)))
        }
        guard let value = String(data: output, encoding: .utf8) else {
            throw OtzariaLineContentError.invalidUTF8
        }
        return value
    }
}

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
