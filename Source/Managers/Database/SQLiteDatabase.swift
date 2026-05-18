//
//  SQLiteDatabase.swift
//  Maktabah
//

import Foundation
import SQLite3

enum SQLiteError: Error {
    case connectionFailed(String)
    case prepareFailed(String)
    case executionFailed(String)
    case notFound
    case bindFailed(String)
}

struct SQLiteRow {
    let stmt: OpaquePointer

    func int(at index: Int32) -> Int {
        return Int(sqlite3_column_int(stmt, index))
    }

    func int64(at index: Int32) -> Int64 {
        return sqlite3_column_int64(stmt, index)
    }

    func string(at index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    func double(at index: Int32) -> Double {
        return sqlite3_column_double(stmt, index)
    }

    func blob(at index: Int32) -> Data? {
        guard let blobPtr = sqlite3_column_blob(stmt, index) else { return nil }
        let blobSize = sqlite3_column_bytes(stmt, index)
        return Data(bytes: blobPtr, count: Int(blobSize))
    }

    func isNull(at index: Int32) -> Bool {
        return sqlite3_column_type(stmt, index) == SQLITE_NULL
    }

    func type(at index: Int32) -> Int32 {
        return sqlite3_column_type(stmt, index)
    }
}

class SQLiteDatabase {
    let dbPointer: OpaquePointer
    private let lock = NSLock()

    init(path: String, flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX) throws {
        var db: OpaquePointer?
        if sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK {
            self.dbPointer = db!
            sqlite3_busy_timeout(dbPointer, 5000)
        } else {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteError.connectionFailed(errorMsg)
        }
    }

    deinit {
        sqlite3_close(dbPointer)
    }

    func execute(query: String, parameters: [Any] = []) throws {
        lock.lock()
        defer { lock.unlock() }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPointer, query, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            throw SQLiteError.prepareFailed(error)
        }
        defer { sqlite3_finalize(stmt) }

        try bind(parameters: parameters, to: stmt)

        if sqlite3_step(stmt) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            throw SQLiteError.executionFailed(error)
        }
    }

    @discardableResult
    func fetch<T>(query: String, parameters: [Any] = [], mapping: (SQLiteRow) throws -> T) throws -> [T] {
        lock.lock()
        defer { lock.unlock() }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(dbPointer, query, -1, &stmt, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            throw SQLiteError.prepareFailed(error)
        }
        defer { sqlite3_finalize(stmt) }

        try bind(parameters: parameters, to: stmt)

        var results: [T] = []
        let row = SQLiteRow(stmt: stmt!)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let mapped = try mapping(row)
            results.append(mapped)
        }

        return results
    }

    func lastInsertRowId() -> Int64 {
        return sqlite3_last_insert_rowid(dbPointer)
    }

    func checkpoint() {
        try? execute(query: "PRAGMA wal_checkpoint(TRUNCATE);")
    }

    private func bind(parameters: [Any], to stmt: OpaquePointer?) throws {
        for (index, value) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)
            switch value {
            case let intVal as Int:
                sqlite3_bind_int(stmt, bindIndex, Int32(intVal))
            case let int64Val as Int64:
                sqlite3_bind_int64(stmt, bindIndex, int64Val)
            case let doubleVal as Double:
                sqlite3_bind_double(stmt, bindIndex, doubleVal)
            case let stringVal as String:
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                sqlite3_bind_text(stmt, bindIndex, stringVal, -1, SQLITE_TRANSIENT)
            case is NSNull:
                sqlite3_bind_null(stmt, bindIndex)
            default:
                throw SQLiteError.bindFailed("Unsupported type for parameter at index \(index)")
            }
        }
    }
}
