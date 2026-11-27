import Foundation
import SQLite3
import CryptoKit

struct ControlFailure: Error, CustomStringConvertible {
    let description: String
}

func requireControl(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw ControlFailure(description: message) }
}

func boundedWait(_ predicate: () -> Bool) -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + 3
    while ProcessInfo.processInfo.systemUptime < deadline {
        if predicate() { return true }
        Thread.sleep(forTimeInterval: 0.005)
    }
    return predicate()
}

func preparedFile(_ folder: URL) throws -> String {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    let file = folder.appendingPathComponent("original-sqlite-control.db").path
    var pointer: OpaquePointer?
    try requireControl(sqlite3_open(file, &pointer) == SQLITE_OK, "Actual system SQLite open")
    guard let pointer else { throw ControlFailure(description: "Actual SQLite pointer") }
    defer { sqlite3_close(pointer) }
    try requireControl(sqlite3_exec(pointer, "CREATE TABLE fixture(value INTEGER);INSERT INTO fixture VALUES(1),(2),(3);", nil, nil, nil) == SQLITE_OK,
                       "Actual small SQLite fixture creation")
    return file
}

#if DEBUG && !ORIGINAL_BASELINE
func snapshot(_ folder: URL, _ label: String) throws -> [String: Any] {
    let request = UUID().uuidString
    guard let value = SQLiteFetchWaitObservation.snapshot(requestID: request) else {
        throw ControlFailure(description: "Explicitly enabled actual snapshot")
    }
    try requireControl(value["requestID"] as? String == request, "Fresh snapshot request identity")
    let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    try data.write(to: folder.appendingPathComponent(label + ".json"))
    return value
}

func records(_ snapshot: [String: Any]) -> [[String: Any]] {
    snapshot["completed"] as? [[String: Any]] ?? []
}
#endif

@main
struct SQLiteFetchWaitControls {
    static func main() async {
        do {
            let arguments = CommandLine.arguments
            try requireControl(arguments.count == 3, "Case and new fixture directory required")
            let name = arguments[1], folder = URL(fileURLWithPath: arguments[2])
            let path = try preparedFile(folder)
            let db = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, queryOnly: true)
            var checks: [String] = []
            switch name {
            case "basic", "disabled", "release":
                let actualMainThread = Thread.isMainThread
                let values = try db.fetch(query: "SELECT value FROM fixture ORDER BY value") { $0.int(at: 0) }
                try requireControl(values == [1, 2, 3], "Original SELECT values preserved")
                checks.append("original-sqlite-values")
                #if DEBUG && !ORIGINAL_BASELINE
                if name == "disabled" {
                    try requireControl(SQLiteFetchWaitObservation.snapshot(requestID: UUID().uuidString) == nil,
                                       "Default/false opt-in must not record")
                    checks.append("disabled-no-snapshot")
                } else {
                    let observed = try snapshot(folder, "actual-basic-snapshot")
                    let rows = records(observed)
                    try requireControl(rows.count == 1 && observed["completeLifetimeCoverage"] as? Bool == true,
                                       "One actual fetch and complete bounded lifetime")
                    let row = rows[0]
                    try requireControl(row["mainThread"] as? Bool == actualMainThread
                        && (row["nativeThreadID"] as? UInt64 ?? 0) > 0, "Actual native thread/main identity")
                    let begin = row["beginNanoseconds"] as? UInt64 ?? UInt64.max
                    let wait = row["waitStartNanoseconds"] as? UInt64 ?? 0
                    let acquired = row["acquiredNanoseconds"] as? UInt64 ?? 0
                    let terminal = row["terminalNanoseconds"] as? UInt64 ?? 0
                    try requireControl(begin <= wait && wait <= acquired && acquired <= terminal
                        && row["returnedNormally"] as? Bool == true, "Actual monotonic admission/acquire/terminal")
                    let connections = observed["connections"] as? [[String: Any]] ?? []
                    try requireControl(connections.count == 1
                        && connections[0]["identityStatus"] as? String == "VFS_CONFIRMED_OPENED_FILE_IDENTITY_AT_CONNECTION_OPEN",
                        "Actual Apple SQLite VFS confirms the opened file")
                    let file = connections[0]["openedFile"] as? [String: Any] ?? [:]
                    try requireControl(file["path"] as? String == path && (file["inode"] as? UInt64 ?? 0) > 0,
                                       "Original opened file path/inode")
                    checks.append(contentsOf: ["actual-native-thread", "monotonic-lock-wait", "vfs-opened-file-identity"])
                }
                #endif

            case "recursive":
                let values = try db.fetch(query: "SELECT value FROM fixture ORDER BY value") { row in
                    let inner = try db.fetch(query: "SELECT value+10 FROM fixture WHERE value=?", parameters: [row.int(at: 0)]) { $0.int(at: 0) }
                    return inner[0]
                }
                try requireControl(values == [11, 12, 13], "Recursive mapping uses the same actual connection")
                let writable = try SQLiteDatabase(path: path)
                try writable.transaction {
                    try writable.withSerializedAccess {
                        let selected = try writable.fetch(query: "SELECT value FROM fixture WHERE value=2") { $0.int(at: 0) }
                        try requireControl(selected == [2], "Actual outer transaction/serialized fetch")
                        #if DEBUG && !ORIGINAL_BASELINE
                        let value = SQLiteFetchWaitObservation.snapshot(requestID: UUID().uuidString)
                        try requireControl(value != nil, "Snapshot while outer recursive owner remains cannot deadlock")
                        #endif
                    }
                }
                #if DEBUG && !ORIGINAL_BASELINE
                let observed = try snapshot(folder, "actual-recursive-snapshot")
                try requireControl(records(observed).count == 5 && observed["activeCount"] as? Int == 0,
                                   "Inner and outer original fetch records all complete")
                #endif
                checks.append(contentsOf: ["recursive-original-mapping", "outer-original-transaction", "outer-serialization-snapshot-no-deadlock"])

            case "held-wait", "cancel-wait":
                let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
                let holder = Task.detached { () throws -> [Int] in
                    try db.fetch(query: "SELECT value FROM fixture WHERE value=1") { row in
                        entered.signal()
                        guard release.wait(timeout: .now() + 8) == .success else {
                            throw ControlFailure(description: "Holder release deadline")
                        }
                        return row.int(at: 0)
                    }
                }
                try requireControl(entered.wait(timeout: .now() + 3) == .success, "Actual mapper owns original SQLite lock")
                let waiting = DispatchSemaphore(value: 0)
                let waiter = Task.detached { () throws -> [Int] in
                    waiting.signal()
                    return try db.fetch(query: "SELECT value FROM fixture WHERE value=2") { $0.int(at: 0) }
                }
                try requireControl(waiting.wait(timeout: .now() + 3) == .success, "Second original fetch started")
                defer { release.signal() }
                #if DEBUG && !ORIGINAL_BASELINE
                try requireControl(boundedWait {
                    SQLiteFetchWaitObservation.snapshot(requestID: UUID().uuidString)?["activeCount"] as? Int == 2
                }, "Actual holder and waiting fetch remain in flight")
                let active = try snapshot(folder, "actual-active-snapshot")
                try requireControl(active["completeLifetimeCoverage"] as? Bool == false, "In-flight work is incomplete")
                #endif
                if name == "cancel-wait" {
                    waiter.cancel()
                    do { _ = try await waiter.value; throw ControlFailure(description: "Cancelled queued fetch returned") }
                    catch is CancellationError { checks.append("original-cancelled-wait-exits-before-holder-release") }
                    release.signal()
                } else {
                    release.signal()
                    let values = try await waiter.value
                    try requireControl(values == [2], "Waiting query executes after the actual holder releases")
                    checks.append("original-held-lock-wait-completes")
                }
                let held = try await holder.value
                try requireControl(held == [1], "Holder original result preserved")
                #if DEBUG && !ORIGINAL_BASELINE
                let observed = try snapshot(folder, "actual-wait-terminal-snapshot")
                let rows = records(observed)
                try requireControl(rows.count == 2 && observed["activeCount"] as? Int == 0, "Both actual operations terminate")
                if name == "cancel-wait" {
                    try requireControl(rows.contains {
                        $0["returnedNormally"] as? Bool == false && $0["acquiredNanoseconds"] is NSNull
                        && $0["taskCancelledAtTerminal"] as? Bool == true
                        && ($0["unacquiredWaitObservedThroughTerminalSeconds"] as? Double ?? 0) > 0
                    }, "Cancelled waiting time is separate from an acquired lock")
                } else {
                    try requireControl(rows.allSatisfy { $0["returnedNormally"] as? Bool == true }
                        && rows.contains { ($0["lockAcquisitionWaitSeconds"] as? Double ?? 0) > 0 },
                        "Actual acquired wait is measured, not supplied")
                }
                #endif

            case "cancel-before":
                let job = Task.detached { () throws -> [Int] in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try db.fetch(query: "SELECT value FROM fixture") { $0.int(at: 0) }
                }
                do { _ = try await job.value; throw ControlFailure(description: "Already cancelled original fetch returned") }
                catch is CancellationError { checks.append("original-before-acquisition-cancellation") }
                #if DEBUG && !ORIGINAL_BASELINE
                let rows = records(try snapshot(folder, "actual-cancel-before-snapshot"))
                try requireControl(rows.count == 1 && rows[0]["waitStartNanoseconds"] is NSNull
                    && rows[0]["acquiredNanoseconds"] is NSNull && rows[0]["returnedNormally"] as? Bool == false,
                    "No lock acquisition is invented for prior cancellation")
                #endif

            case "errors":
                do {
                    _ = try db.fetch(query: "SELECT PRIVATE_CONTROL_SQL_TOKEN FROM missing_table") { $0.int(at: 0) }
                    throw ControlFailure(description: "Invalid original SQL returned")
                } catch SQLiteError.prepareFailed { checks.append("original-prepare-error-propagates") }
                do {
                    _ = try db.fetch(query: "SELECT value FROM fixture") { _ -> Int in
                        throw ControlFailure(description: "EXPECTED_MAPPING_ERROR")
                    }
                    throw ControlFailure(description: "Mapping throw swallowed")
                } catch let error as ControlFailure where error.description == "EXPECTED_MAPPING_ERROR" {
                    checks.append("original-mapping-error-propagates")
                }
                #if DEBUG && !ORIGINAL_BASELINE
                let observed = try snapshot(folder, "actual-error-snapshot")
                try requireControl(records(observed).count == 2
                    && records(observed).allSatisfy { $0["returnedNormally"] as? Bool == false }, "Actual errors complete their observations")
                let encoded = String(data: try JSONSerialization.data(withJSONObject: observed), encoding: .utf8) ?? ""
                try requireControl(!encoded.contains("PRIVATE_CONTROL_SQL_TOKEN") && !encoded.contains("EXPECTED_MAPPING_ERROR"),
                                   "No SQL or exception text is captured")
                checks.append("no-query-or-error-text")
                #endif

            #if DEBUG && !ORIGINAL_BASELINE
            case "ring-bound":
                for _ in 0..<(SQLiteFetchWaitObservation.completedCapacity + 9) {
                    let rows = try db.fetch(query: "SELECT value FROM fixture WHERE value=1") { $0.int(at: 0) }
                    try requireControl(rows == [1], "Original reads preserved at the recorder bound")
                }
                let observed = try snapshot(folder, "actual-ring-snapshot")
                try requireControl(records(observed).count == SQLiteFetchWaitObservation.completedCapacity
                    && observed["lifetimeOverwritten"] as? UInt64 == 9 && observed["lifetimeDropped"] as? UInt64 == 0
                    && observed["completeLifetimeCoverage"] as? Bool == false, "Overwritten history is distinguished from dropped observations")
                checks.append("bounded-real-fetch-ring-honest-overwrite")

            case "connection-bound":
                for _ in 0...SQLiteFetchWaitObservation.connectionCapacity {
                    let connection = try SQLiteDatabase(path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
                    let rows = try connection.fetch(query: "SELECT value FROM fixture WHERE value=1") { $0.int(at: 0) }
                    try requireControl(rows == [1], "Original SQL preserved despite observation connection cap")
                }
                let observed = try snapshot(folder, "actual-connection-bound-snapshot")
                try requireControl(observed["lifetimeDroppedForConnectionCapacity"] as? UInt64 == 1
                    && observed["lifetimeOverwritten"] as? UInt64 == 0
                    && observed["completeLifetimeCoverage"] as? Bool == false, "Connection loss is explicit")
                checks.append("bounded-real-connections-honest-drop")

            case "active-bound":
                // This one case exercises recorder admission directly. Its
                // synthetic tokens are not actual SQL operations or timings.
                let connection = SQLiteFetchWaitObservation.openedConnection(db.dbPointer)
                let tokens = (0...SQLiteFetchWaitObservation.activeCapacity).map { _ in
                    SQLiteFetchWaitObservation.begin(connection: connection)
                }
                let observed = try snapshot(folder, "synthetic-recorder-active-bound-snapshot")
                try requireControl(tokens.compactMap { $0 }.count == SQLiteFetchWaitObservation.activeCapacity
                    && observed["lifetimeDroppedForActiveCapacity"] as? UInt64 == 1
                    && observed["activeCount"] as? Int == SQLiteFetchWaitObservation.activeCapacity,
                    "Synthetic recorder admission is bounded and loss is explicit")
                for token in tokens {
                    SQLiteFetchWaitObservation.finish(token, waitStart: nil, acquired: nil,
                        returnedNormally: false, taskCancelledAtTerminal: false)
                }
                checks.append("synthetic-recorder-active-admission-bound-only")

            case "non-file-identity":
                let memory = try SQLiteDatabase(path: ":memory:")
                _ = try memory.fetch(query: "SELECT 1") { $0.int(at: 0) }
                let observed = try snapshot(folder, "actual-memory-snapshot")
                let connections = observed["connections"] as? [[String: Any]] ?? []
                try requireControl(connections.count == 1 && connections[0]["openedFile"] == nil
                    && (connections[0]["identityStatus"] as? String ?? "").hasPrefix("UNAVAILABLE"),
                    "A non-file database cannot masquerade as the corpus")
                checks.append("actual-memory-database-identity-unqualified")

            #if canImport(UIKit)
            case "companion-export":
                _ = try db.fetch(query: "SELECT value FROM fixture") { $0.int(at: 0) }
                let prefix = folder.appendingPathComponent("source-request").path
                let request = UUID().uuidString
                let descriptor = ReaderSQLiteFetchWaitSnapshotExport.write(requestID: request, prefix: prefix)
                try requireControl(descriptor["status"] as? String == "AVAILABLE", "Original companion export succeeds")
                let data = try Data(contentsOf: URL(fileURLWithPath: prefix + ".sqlite-fetch-wait.json"))
                let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                try requireControl(data.count <= 1_048_576 && descriptor["bytes"] as? Int == data.count
                    && descriptor["sha256"] as? String == digest && body["requestID"] as? String == request,
                    "Actual bounded companion bytes/hash/fresh request agree")
                let descriptorBytes = try JSONSerialization.data(withJSONObject: descriptor)
                try requireControl(descriptorBytes.count <= 2048, "Viewport descriptor bound")
                let invalid = ReaderSQLiteFetchWaitSnapshotExport.write(requestID: "not-a-request", prefix: prefix)
                try requireControl(invalid["status"] as? String == "UNAVAILABLE", "Invalid request cannot reuse old companion")
                let failed = ReaderSQLiteFetchWaitSnapshotExport.write(requestID: UUID().uuidString,
                    prefix: folder.appendingPathComponent("missing-parent/source-request").path)
                try requireControl(failed["status"] as? String == "UNAVAILABLE", "Write failure is explicit")
                checks.append(contentsOf: ["actual-companion-hash-and-request", "descriptor-and-file-bounds", "invalid-request-and-write-failure"])
            #endif
            #endif

            default: throw ControlFailure(description: "Unknown source-control case")
            }
            let result: [String: Any] = ["status": "COMPONENT_CONTROL_PASS_NOT_APP_PERFORMANCE_ACCEPTANCE", "case": name,
                "checks": checks, "processID": ProcessInfo.processInfo.processIdentifier,
                "scope": "Original Apple SQLite fetch and bounded passive source controls. No full production corpus, Simulator or application UI."]
            let bytes = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            print(String(data: bytes, encoding: .utf8)!)
        } catch {
            FileHandle.standardError.write(Data("SOURCE_CONTROL_FAILED: \(error)\n".utf8))
            exit(1)
        }
    }
}
