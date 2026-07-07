import Foundation
import SQLite3

private let otzariaSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class OtzariaSQLiteStatement {
    private let database: OpaquePointer
    private let sql: String
    private let statement: OpaquePointer?

    init(database: OpaquePointer, sql: String) throws {
        self.database = database
        self.sql = sql
        var prepared: OpaquePointer?
        let result = sqlite3_prepare_v2(database, sql, -1, &prepared, nil)
        guard result == SQLITE_OK else {
            throw OtzariaSQLiteError.prepareFailed(message: otzariaSQLiteMessage(database), code: result, sql: sql)
        }
        self.statement = prepared
    }

    deinit {
        sqlite3_finalize(statement)
    }

    func bind(_ value: Int, at index: Int32) throws {
        let result = sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        guard result == SQLITE_OK else {
            throw OtzariaSQLiteError.bindFailed(message: otzariaSQLiteMessage(database), code: result)
        }
    }

    func bind(_ value: String, at index: Int32) throws {
        let result = sqlite3_bind_text(statement, index, value, -1, otzariaSQLiteTransient)
        guard result == SQLITE_OK else {
            throw OtzariaSQLiteError.bindFailed(message: otzariaSQLiteMessage(database), code: result)
        }
    }

    func step() throws -> Bool {
        let result = sqlite3_step(statement)
        switch result {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw OtzariaSQLiteError.stepFailed(message: otzariaSQLiteMessage(database), code: result, sql: sql)
        }
    }

    func columnInt(_ index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    func columnBool(_ index: Int32) -> Bool {
        sqlite3_column_int(statement, index) != 0
    }

    func columnString(_ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self))
    }

    func columnType(_ index: Int32) -> Int32 {
        sqlite3_column_type(statement, index)
    }
}
