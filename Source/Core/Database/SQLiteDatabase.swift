//
//  SQLiteDatabase.swift
//  Maktabah
//

import Foundation
import SQLite3
#if DEBUG
import Dispatch
#if canImport(Darwin)
import Darwin
#endif
#endif

enum SQLiteError: LocalizedError {
    case connectionFailed(String)
    case prepareFailed(String)
    case executionFailed(String)
    case notFound
    case bindFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            "SQLite connection failed: \(message)"
        case .prepareFailed(let message):
            "SQLite statement preparation failed: \(message)"
        case .executionFailed(let message):
            "SQLite statement execution failed: \(message)"
        case .notFound:
            "SQLite record was not found."
        case .bindFailed(let message):
            "SQLite parameter binding failed: \(message)"
        }
    }
}

struct SQLiteRow {
    let stmt: OpaquePointer

    var columnCount: Int32 {
        sqlite3_column_count(stmt)
    }

    func int(at index: Int32) -> Int {
        Int(sqlite3_column_int(stmt, index))
    }

    func int64(at index: Int32) -> Int64 {
        sqlite3_column_int64(stmt, index)
    }

    func string(at index: Int32) -> String? {
        stmt.columnString(index)
    }

    func double(at index: Int32) -> Double {
        sqlite3_column_double(stmt, index)
    }

    func blob(at index: Int32) -> Data? {
        stmt.columnBlob(index)
    }

    func rawBlob(at index: Int32) -> UnsafeRawBufferPointer? {
        stmt.columnRawBlob(index)
    }

    func isNull(at index: Int32) -> Bool {
        sqlite3_column_type(stmt, index) == SQLITE_NULL
    }

    func type(at index: Int32) -> Int32 {
        sqlite3_column_type(stmt, index)
    }
}

class SQLiteDatabase: @unchecked Sendable {
    let dbPointer: OpaquePointer
    private let lock = NSRecursiveLock()
    private var savepointCounter: Int = 0
    private var statementCache: [String: OpaquePointer] = [:]
    private var cacheKeys: [String] = [] // Untuk LRU eviction
    private let maxCacheSize = 100
    #if DEBUG
    private let fetchWaitObservationConnection: SQLiteFetchWaitObservation.Connection?
    #endif

    init(
        path: String,
        flags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        queryOnly: Bool = false
    ) throws {

        if flags & SQLITE_OPEN_READWRITE != 0 {
            let fm = FileManager.default
            let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o644]
            try? fm.setAttributes(attrs, ofItemAtPath: path)
            try? fm.setAttributes(attrs, ofItemAtPath: path + "-wal")
            try? fm.setAttributes(attrs, ofItemAtPath: path + "-shm")
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK {
            dbPointer = db!
            #if DEBUG
            fetchWaitObservationConnection = SQLiteFetchWaitObservation.openedConnection(dbPointer)
            #endif
            if queryOnly {
                try execute(query: "PRAGMA query_only = ON;")
            }
            sqlite3_busy_timeout(dbPointer, 5000)
        } else {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SQLiteError.connectionFailed(errorMsg)
        }
    }

    deinit {
        for stmt in statementCache.values {
            sqlite3_finalize(stmt)
        }
        statementCache.removeAll()
        sqlite3_close(dbPointer)
    }

    private func _resetAllCachedStatements() {
        for stmt in statementCache.values {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }
    }

    /// Executes synchronous work under this connection's existing serialization
    /// lock. The owned annotation completion uses this to retain the same lock
    /// across its lifetime admission and the original transaction's COMMIT.
    /// Never await or invoke a transport; callers must obey their reviewed lock
    /// order. Owned annotation completion never acquires repository state.
    func withSerializedAccess<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func transaction(_ block: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }

        // Cek apakah sudah dalam transaksi aktif untuk mendukung nested transaction.
        // SQLite tidak mendukung nested BEGIN TRANSACTION — gunakan SAVEPOINT sebagai gantinya.
        let isNested = sqlite3_get_autocommit(dbPointer) == 0

        if isNested {
            savepointCounter += 1
            let savepointName = "sp\(savepointCounter)"
            defer { savepointCounter -= 1 }

            try _executeNoLock(query: "SAVEPOINT \(savepointName);")
            do {
                try block()
                _resetAllCachedStatements()
                try _executeNoLock(query: "RELEASE SAVEPOINT \(savepointName);")
            } catch {
                _resetAllCachedStatements()
                try? _executeNoLock(query: "ROLLBACK TO SAVEPOINT \(savepointName);")
                try? _executeNoLock(query: "RELEASE SAVEPOINT \(savepointName);")
                throw error
            }
        } else {
            try _executeNoLock(query: "BEGIN TRANSACTION;")
            do {
                try block()
                _resetAllCachedStatements()
                try _executeNoLock(query: "COMMIT;")
            } catch {
                _resetAllCachedStatements()
                try? _executeNoLock(query: "ROLLBACK;")
                throw error
            }
        }
    }

    func execute(query: String, parameters: [Any] = []) throws {
        lock.lock()
        defer { lock.unlock() }
        try _executeNoLock(query: query, parameters: parameters)
    }

    @discardableResult
    func fetch<T>(query: String, parameters: [Any] = [], mapping: (SQLiteRow) throws -> T) throws -> [T] {
        #if DEBUG
        let observation = SQLiteFetchWaitObservation.begin(connection: fetchWaitObservationConnection)
        var observedWaitStart: UInt64?
        var observedAcquired: UInt64?
        var observedReturnedNormally = false
        // Register before the original unlock defer. This runs after this
        // fetch's unlock, including thrown/cancelled reads. An outer recursive
        // owner can remain; the bounded recorder never calls SQLite or Bridge.
        defer {
            if observation != nil {
                SQLiteFetchWaitObservation.finish(observation, waitStart: observedWaitStart,
                    acquired: observedAcquired, returnedNormally: observedReturnedNormally,
                    taskCancelledAtTerminal: Task.isCancelled)
            }
        }
        #endif
        // Keep statement/decoder serialization, but allow a cancelled read to
        // leave the queue while an unrelated fetch still owns this same lock.
        try Task.checkCancellation()
        #if DEBUG
        if observation != nil { observedWaitStart = DispatchTime.now().uptimeNanoseconds }
        #endif
        while !lock.lock(before: Date(timeIntervalSinceNow: 0.01)) {
            try Task.checkCancellation()
        }
        defer { lock.unlock() }
        #if DEBUG
        if observation != nil { observedAcquired = DispatchTime.now().uptimeNanoseconds }
        #endif
        // Cancellation can win as acquisition succeeds; establish the unlock
        // first and do not prepare or publish a statement in that case.
        try Task.checkCancellation()
        let values = try _fetchNoLock(query: query, parameters: parameters, mapping: mapping)
        #if DEBUG
        observedReturnedNormally = true
        #endif
        return values
    }

    // MARK: - Internal no-lock variants (caller must hold lock)

    private func preparedStatement(for query: String, parameters: [Any]) throws -> OpaquePointer {
        let stmt: OpaquePointer

        if let cachedStmt = statementCache[query] {
            stmt = cachedStmt
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)

            // Perbarui LRU order
            if let idx = cacheKeys.firstIndex(of: query) {
                cacheKeys.remove(at: idx)
                cacheKeys.append(query)
            }
        } else {
            var newStmt: OpaquePointer?
            guard sqlite3_prepare_v2(dbPointer, query, -1, &newStmt, nil) == SQLITE_OK else {
                let error = String(cString: sqlite3_errmsg(dbPointer))
                throw SQLiteError.prepareFailed(error)
            }
            stmt = newStmt!

            if statementCache.count >= maxCacheSize, let oldestKey = cacheKeys.first {
                if let oldStmt = statementCache.removeValue(forKey: oldestKey) {
                    sqlite3_finalize(oldStmt)
                }
                cacheKeys.removeFirst()
            }
            statementCache[query] = stmt
            cacheKeys.append(query)
        }

        try bind(parameters: parameters, to: stmt)
        return stmt
    }

    private func _executeNoLock(query: String, parameters: [Any] = []) throws {
        let stmt = try preparedStatement(for: query, parameters: parameters)
        defer {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }

        if sqlite3_step(stmt) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(dbPointer))
            throw SQLiteError.executionFailed(error)
        }
    }

    @discardableResult
    private func _fetchNoLock<T>(query: String, parameters: [Any] = [], mapping: (SQLiteRow) throws -> T) throws -> [T] {
        let stmt = try preparedStatement(for: query, parameters: parameters)
        defer {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }

        var results: [T] = []
        let row = SQLiteRow(stmt: stmt)

        var status = sqlite3_step(stmt)
        while status == SQLITE_ROW {
            let mapped = try mapping(row)
            results.append(mapped)
            status = sqlite3_step(stmt)
        }
        // Only DONE proves a complete read. BUSY, INTERRUPT and other errors
        // must not publish a partial/empty page or allow a transaction to commit.
        guard status == SQLITE_DONE else {
            throw SQLiteError.executionFailed(String(cString: sqlite3_errmsg(dbPointer)))
        }

        return results
    }

    func lastInsertRowId() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return sqlite3_last_insert_rowid(dbPointer)
    }

    func checkpoint() {
        lock.lock()
        defer { lock.unlock() }
        try? _executeNoLock(query: "PRAGMA wal_checkpoint(TRUNCATE);")
    }

    func enableWALMode() {
        lock.lock()
        defer { lock.unlock() }
        _ = try? _fetchNoLock(query: "PRAGMA journal_mode = WAL;") { row in
            row.string(at: 0) ?? ""
        }
    }

    func tableColumns(tableName: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return (try? _fetchNoLock(query: "PRAGMA table_info('\(tableName)');") { row in
            row.string(at: 1) ?? ""
        }) ?? []
    }

    private func bind(parameters: [Any], to stmt: OpaquePointer?) throws {
        for (index, value) in parameters.enumerated() {
            let bindIndex = Int32(index + 1)
            let status: Int32
            switch value {
            case let intVal as Int:
                status = sqlite3_bind_int64(stmt, bindIndex, Int64(intVal))
            case let int64Val as Int64:
                status = sqlite3_bind_int64(stmt, bindIndex, int64Val)
            case let doubleVal as Double:
                status = sqlite3_bind_double(stmt, bindIndex, doubleVal)
            case let stringVal as String:
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                status = sqlite3_bind_text(stmt, bindIndex, stringVal, -1, SQLITE_TRANSIENT)
            case is NSNull:
                status = sqlite3_bind_null(stmt, bindIndex)
            default:
                throw SQLiteError.bindFailed("Unsupported type for parameter at index \(index)")
            }
            guard status == SQLITE_OK else {
                throw SQLiteError.bindFailed(String(cString: sqlite3_errmsg(dbPointer)))
            }
        }
    }
}

#if DEBUG
/// Bounded passive measurements of the existing fetch serialization lock.
/// No SQL, parameters, text/results, error strings or callbacks are retained.
/// This recorder's lock never calls a database/bridge. Snapshots release it
/// before constructing dictionaries, encoding JSON or performing any file IO.
enum SQLiteFetchWaitObservation {
    static let enabled = ProcessInfo.processInfo.environment["CHAVRUSA_FULL_V32_SOURCE_OBSERVATION"] == "1"
    static let completedCapacity = 1024
    static let activeCapacity = 64
    static let connectionCapacity = 64
    private static let state = State()

    struct FileIdentity: Sendable, Equatable {
        let path: String
        let device: UInt64
        let inode: UInt64
        let bytes: Int64
        let modifiedNanoseconds: Int64

        var json: [String: Any] {
            ["path": path, "device": device, "inode": inode, "bytes": bytes,
             "modifiedNanoseconds": modifiedNanoseconds]
        }
    }

    struct Connection: Sendable {
        let id: String
        let capturedNanoseconds: UInt64
        let file: FileIdentity?
        let identityStatus: String

        var json: [String: Any] {
            var result: [String: Any] = ["connectionID": id, "capturedNanoseconds": capturedNanoseconds,
                                       "identityStatus": identityStatus]
            if let file { result["openedFile"] = file.json }
            return result
        }
    }

    struct Pending: Sendable {
        let sequence: UInt64
        let operationID: String
        let connectionID: String
        let beginNanoseconds: UInt64
        let threadID: UInt64?
        let mainThread: Bool

        var json: [String: Any] {
            ["sequence": sequence, "operationID": operationID, "connectionID": connectionID,
             "beginNanoseconds": beginNanoseconds, "nativeThreadID": threadID as Any? ?? NSNull(),
             "mainThread": mainThread]
        }
    }

    private struct Completed: Sendable {
        let pending: Pending
        let waitStart: UInt64?
        let acquired: UInt64?
        let terminal: UInt64
        let returnedNormally: Bool
        let taskCancelledAtTerminal: Bool

        var json: [String: Any] {
            var result = pending.json
            result["waitStartNanoseconds"] = waitStart as Any? ?? NSNull()
            result["acquiredNanoseconds"] = acquired as Any? ?? NSNull()
            result["terminalNanoseconds"] = terminal
            result["returnedNormally"] = returnedNormally
            // A cancellation flag is not an error classification. SQL/mapping
            // errors can race cancellation; no exception text is recorded.
            result["taskCancelledAtTerminal"] = taskCancelledAtTerminal
            if let waitStart, let acquired, acquired >= waitStart {
                result["lockAcquisitionWaitSeconds"] = Double(acquired - waitStart) / 1_000_000_000
            } else if let waitStart, terminal >= waitStart {
                result["unacquiredWaitObservedThroughTerminalSeconds"] = Double(terminal - waitStart) / 1_000_000_000
            }
            return result
        }
    }

    private struct Copy: Sendable {
        let connections: [String: Connection]
        let active: [UInt64: Pending]
        let completed: [Completed]
        let started: UInt64
        let finished: UInt64
        let dropped: UInt64
        let droppedActive: UInt64
        let droppedConnections: UInt64
        let unmatchedCompletions: UInt64
        let overwritten: UInt64
        let counterOverflowed: Bool
        let copiedNanoseconds: UInt64
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var connections: [String: Connection] = [:]
        private var active: [UInt64: Pending] = [:]
        private var completed: [Completed] = []
        private var nextReplacement = 0
        private var started: UInt64 = 0
        private var finished: UInt64 = 0
        private var dropped: UInt64 = 0
        private var droppedActive: UInt64 = 0
        private var droppedConnections: UInt64 = 0
        private var unmatchedCompletions: UInt64 = 0
        private var overwritten: UInt64 = 0
        private var counterOverflowed = false

        private func increment(_ value: inout UInt64) {
            if value == UInt64.max { counterOverflowed = true }
            else { value += 1 }
        }

        func begin(connection: Connection, timestamp: UInt64, threadID: UInt64?, main: Bool) -> Pending? {
            lock.lock()
            defer { lock.unlock() }
            increment(&started)
            guard !counterOverflowed else {
                increment(&dropped)
                return nil
            }
            guard active.count < activeCapacity else {
                increment(&dropped); increment(&droppedActive)
                return nil
            }
            guard connections[connection.id] != nil || connections.count < connectionCapacity else {
                increment(&dropped); increment(&droppedConnections)
                return nil
            }
            connections[connection.id] = connection
            let pending = Pending(sequence: started, operationID: UUID().uuidString,
                connectionID: connection.id, beginNanoseconds: timestamp, threadID: threadID, mainThread: main)
            active[pending.sequence] = pending
            return pending
        }

        func finish(_ value: Completed) {
            lock.lock()
            defer { lock.unlock() }
            guard active.removeValue(forKey: value.pending.sequence) != nil else {
                increment(&dropped); increment(&unmatchedCompletions)
                return
            }
            increment(&finished)
            if completed.count < completedCapacity { completed.append(value) }
            else {
                completed[nextReplacement] = value
                nextReplacement = (nextReplacement + 1) % completedCapacity
                increment(&overwritten)
            }
        }

        func copy() -> Copy {
            lock.lock()
            defer { lock.unlock() }
            return Copy(connections: connections, active: active, completed: completed,
                started: started, finished: finished, dropped: dropped,
                droppedActive: droppedActive, droppedConnections: droppedConnections,
                unmatchedCompletions: unmatchedCompletions, overwritten: overwritten,
                counterOverflowed: counterOverflowed, copiedNanoseconds: DispatchTime.now().uptimeNanoseconds)
        }
    }

    /// Called once after the original successful open, only with the explicit
    /// DEBUG opt-in. A VFS that cannot verify opened-file identity is honestly
    /// unqualified; a pathname alone must not identify a replaced open handle.
    static func openedConnection(_ database: OpaquePointer) -> Connection? {
        guard enabled else { return nil }
        let id = UUID().uuidString
        let timestamp = DispatchTime.now().uptimeNanoseconds
        var observed: FileIdentity?
        var status = "UNAVAILABLE_OPENED_FILE_IDENTITY"
        #if canImport(Darwin)
        if let raw = sqlite3_db_filename(database, "main") {
            let path = String(cString: raw)
            if !path.isEmpty, path.utf8.count <= 4096, path.hasPrefix("/") {
                func identity() -> FileIdentity? {
                    var value = stat()
                    guard lstat(path, &value) == 0, (value.st_mode & S_IFMT) == S_IFREG,
                          value.st_size >= 0 else { return nil }
                    return FileIdentity(path: path, device: UInt64(UInt32(bitPattern: value.st_dev)),
                        inode: UInt64(value.st_ino), bytes: Int64(value.st_size),
                        modifiedNanoseconds: Int64(value.st_mtimespec.tv_sec) * 1_000_000_000 + Int64(value.st_mtimespec.tv_nsec))
                }
                let before = identity()
                var moved: Int32 = -1
                let code = sqlite3_file_control(database, "main", SQLITE_FCNTL_HAS_MOVED, &moved)
                let after = identity()
                if let before, before == after, code == SQLITE_OK, moved == 0 {
                    observed = before
                    status = "VFS_CONFIRMED_OPENED_FILE_IDENTITY_AT_CONNECTION_OPEN"
                }
            } else { status = "UNAVAILABLE_NON_FILE_OR_UNBOUNDED_FILENAME" }
        }
        #endif
        return Connection(id: id, capturedNanoseconds: timestamp, file: observed, identityStatus: status)
    }

    static func begin(connection: Connection?) -> Pending? {
        guard enabled, let connection else { return nil }
        var thread: UInt64 = 0
        var validThread = false
        #if canImport(Darwin)
        validThread = pthread_threadid_np(nil, &thread) == 0 && thread > 0
        #endif
        return state.begin(connection: connection, timestamp: DispatchTime.now().uptimeNanoseconds,
            threadID: validThread ? thread : nil, main: Thread.isMainThread)
    }

    static func finish(_ pending: Pending?, waitStart: UInt64?, acquired: UInt64?,
                       returnedNormally: Bool, taskCancelledAtTerminal: Bool) {
        guard let pending else { return }
        let terminal = DispatchTime.now().uptimeNanoseconds
        state.finish(Completed(pending: pending, waitStart: waitStart, acquired: acquired, terminal: terminal,
            returnedNormally: returnedNormally, taskCancelledAtTerminal: taskCancelledAtTerminal))
    }

    static func snapshot(requestID: String) -> [String: Any]? {
        guard enabled, UUID(uuidString: requestID) != nil else { return nil }
        let captured = state.copy()
        // The recorder lock has been released. No database, bridge, logger or
        // file is consulted while this immutable bounded copy is serialized.
        return ["schema": 1, "status": "PASSIVE_FETCH_LOCK_OBSERVATION_NOT_PERFORMANCE_ACCEPTANCE",
                "requestID": requestID, "processID": ProcessInfo.processInfo.processIdentifier,
                "snapshotNanoseconds": captured.copiedNanoseconds,
                "clock": "DispatchTime.uptimeNanoseconds", "observedUptime": ProcessInfo.processInfo.systemUptime,
                "scope": "Existing fetch lock admission; terminal sampled after this fetch unlock, an outer recursive owner may remain. Not SQLite engine busy wait, query duration or UI responsiveness.",
                "completedCapacity": completedCapacity, "activeCapacity": activeCapacity, "connectionCapacity": connectionCapacity,
                "lifetimeStarted": captured.started, "lifetimeFinished": captured.finished,
                "lifetimeDropped": captured.dropped, "lifetimeOverwritten": captured.overwritten,
                "lifetimeDroppedForActiveCapacity": captured.droppedActive,
                "lifetimeDroppedForConnectionCapacity": captured.droppedConnections,
                "lifetimeUnmatchedCompletions": captured.unmatchedCompletions,
                "counterOverflowed": captured.counterOverflowed,
                "completeLifetimeCoverage": captured.dropped == 0 && captured.overwritten == 0 && captured.active.isEmpty && !captured.counterOverflowed,
                "activeCount": captured.active.count, "completedRetainedCount": captured.completed.count,
                "connections": captured.connections.values.sorted { $0.id < $1.id }.map(\.json),
                "active": captured.active.values.sorted { $0.sequence < $1.sequence }.map(\.json),
                "completed": captured.completed.sorted { $0.pending.sequence < $1.pending.sequence }.map(\.json)]
    }
}
#endif

// MARK: - Safe Database Attach

extension OpaquePointer {
    func safeAttachDatabase(path: String, schema: String) throws {
        let sql = "ATTACH DATABASE ? AS \(schema)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(self, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorString = String(cString: sqlite3_errmsg(self))
            throw NSError(domain: "SQLite", code: Int(sqlite3_errcode(self)), userInfo: [NSLocalizedDescriptionKey: "Prepare failed: \(errorString)"])
        }
        defer { sqlite3_finalize(stmt) }

        path.withCString { ptr in
            let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, ptr, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            let errorString = String(cString: sqlite3_errmsg(self))
            throw NSError(domain: "SQLite", code: Int(sqlite3_errcode(self)), userInfo: [NSLocalizedDescriptionKey: "Step failed: \(errorString)"])
        }
    }

    // MARK: - Statement Column Readers

    /// Reads UTF-8 string from a SQLite statement column at index.
    func columnString(_ index: Int32) -> String? {
        guard let textPtr = sqlite3_column_text(self, index) else { return nil }
        let bytes = sqlite3_column_bytes(self, index)
        let buffer = UnsafeBufferPointer(start: textPtr, count: Int(bytes))
        return String(bytes: buffer, encoding: .utf8)
    }

    /// Reads column name from a SQLite statement at index.
    func columnName(_ index: Int32) -> String {
        guard let namePtr = sqlite3_column_name(self, index) else { return "" }
        let nameLen = strlen(namePtr)
        let buffer = UnsafeRawBufferPointer(start: UnsafeRawPointer(namePtr), count: Int(nameLen))
        return String(bytes: buffer, encoding: .utf8) ?? ""
    }

    /// Reads blob Data from a SQLite statement column at index.
    func columnBlob(_ index: Int32) -> Data? {
        guard let blobPtr = sqlite3_column_blob(self, index) else { return nil }
        let blobSize = sqlite3_column_bytes(self, index)
        return Data(bytes: blobPtr, count: Int(blobSize))
    }

    /// Reads raw blob buffer from a SQLite statement column at index.
    func columnRawBlob(_ index: Int32) -> UnsafeRawBufferPointer? {
        guard let blobPtr = sqlite3_column_blob(self, index) else { return nil }
        let blobSize = sqlite3_column_bytes(self, index)
        return UnsafeRawBufferPointer(start: blobPtr, count: Int(blobSize))
    }

    /// Reads text or decompressed LZString blob from a SQLite statement column at index.
    func columnTextOrDecompressedBlob(_ index: Int32) -> String {
        let type = sqlite3_column_type(self, index)
        if type == SQLITE_TEXT {
            return columnString(index) ?? ""
        } else if type == SQLITE_BLOB, let raw = columnRawBlob(index) {
            return ZstdDecompressor.decompressData(from: raw)
        }
        return ""
    }

    // MARK: - Database Table Queries

    /// Lists table/view names from a SQLite database connection.
    func listTableNames(schemaName: String = "main", whereCondition: String = "type='table'") -> [String] {
        let sql = "SELECT name FROM \(schemaName).sqlite_master WHERE \(whereCondition) ORDER BY name;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(self, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var tables: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = stmt.columnString(0) {
                tables.append(name)
            }
        }
        return tables
    }

    // MARK: - Database Close

    /// Truncate wal_checkpoint and close_v2.
    func truncateAndClose() {
        _ = sqlite3_exec(self, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
        sqlite3_close_v2(self)
    }
}
