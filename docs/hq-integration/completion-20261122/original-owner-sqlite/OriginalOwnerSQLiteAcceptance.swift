import Foundation
import Dispatch
import SQLite3
#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#endif

// Six new composition controls. Owner/Lifetime/Operation/Binding and the full
// original SQLiteDatabase are compiled unchanged. Only document values, timing
// gates, effect logs and disposable fixture tables are supplied here.
// No native receipt, identity writer, engine, RPC, transport or ACK is modeled.

private struct ControlFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw ControlFailure(description: message) }
}

private final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func append(_ value: String) {
        lock.lock(); values.append(value); lock.unlock()
    }
    func snapshot() -> [String] {
        lock.lock(); defer { lock.unlock() }; return values
    }
}

private final class FixtureDocument: BaseDocumentProtocol, EditorDocumentWriteLifetimeProviding, Sendable {
    let objectId = "fixture-original-owner"
    let spaceId = "fixture-owned-space"
    let mode = DocumentMode.handling
    let isOpened = true
    let isLocked = false
    let editorWriteLifetime = EditorDocumentWriteLifetime()
    let permissions: ObjectPermissions

    init() {
        var value = ObjectPermissions()
        value.canEditBlocks = true
        value.editBlocks = .edit
        value.canEditDetails = true
        value.canEditRelationValues = true
        value.canEditPropertiesList = true
        permissions = value
    }
}

private func rowCount(_ database: SQLiteDatabase, table: String = "fixture_fact") throws -> Int {
    let rows = try database.fetch(query: "SELECT COUNT(*) FROM \(table);") { $0.int(at: 0) }
    try require(rows.count == 1, "COUNT must return exactly one row")
    return rows[0]
}

private func independentRows(_ path: String, table: String = "fixture_fact") throws -> Int {
    let reader = try SQLiteDatabase(
        path: path, flags: SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, queryOnly: true
    )
    try require(sqlite3_get_autocommit(reader.dbPointer) != 0, "fresh reader must not own a transaction")
    return try rowCount(reader, table: table)
}

@MainActor
private final class DrainObservation {
    var count = 0
    var durableRows: Int?
    var observedAutocommit: Int32?
    var error: String?
}

@MainActor
private final class Fixture {
    let path: String
    let database: SQLiteDatabase
    let document: FixtureDocument
    let account = EditorDocumentWriteLifetime()
    let source = EditorDocumentWriteLifetime()
    let owner: EditorDocumentWriteOwner
    let log: EventLog
    let drain: DrainObservation

    init(_ root: URL, _ name: String) throws {
        path = root.appendingPathComponent(name + ".sqlite").path
        try require(!FileManager.default.fileExists(atPath: path), "fixture database must be fresh")
        database = try SQLiteDatabase(path: path)
        database.enableWALMode()
        try database.execute(query: "PRAGMA synchronous = FULL;")
        try database.execute(query: "PRAGMA foreign_keys = ON;")
        try database.execute(query: "CREATE TABLE fixture_fact (id INTEGER PRIMARY KEY, payload TEXT NOT NULL);")
        try database.execute(query: "CREATE TABLE fixture_parent (id TEXT PRIMARY KEY);")
        try database.execute(query: "CREATE TABLE fixture_child (id INTEGER PRIMARY KEY, parent_id TEXT NOT NULL, FOREIGN KEY(parent_id) REFERENCES fixture_parent(id) DEFERRABLE INITIALLY DEFERRED);")
        let journal = try database.fetch(query: "PRAGMA journal_mode;") { $0.string(at: 0) ?? "" }
        let sync = try database.fetch(query: "PRAGMA synchronous;") { $0.int(at: 0) }
        let foreign = try database.fetch(query: "PRAGMA foreign_keys;") { $0.int(at: 0) }
        try require(journal == ["wal"] && sync == [2] && foreign == [1], "real WAL/FULL/deferred-FK fixture prerequisites")
        document = FixtureDocument()
        let log = EventLog()
        self.log = log
        let drain = DrainObservation()
        self.drain = drain
        let path = self.path
        let database = self.database
        let binding = try EditorDocumentWriteSourceBinding(
            lifetime: source, accountLifetime: account, isCurrent: { true }
        )
        owner = try EditorDocumentWriteOwner(
            data: .init(objectId: document.objectId, spaceId: document.spaceId, mode: document.mode),
            lifetimeDocument: document, sourceBinding: binding,
            onDrained: {
                drain.count += 1
                drain.observedAutocommit = sqlite3_get_autocommit(database.dbPointer)
                do { drain.durableRows = try independentRows(path) }
                catch { drain.error = String(describing: error) }
                log.append("owner_onDrained")
            }
        )
    }

    // Fixture composition seam only. The actual owner admission surrounds the
    // existing serialized DB access and real outer COMMIT; no production writer
    // or proof is invented. Nested transaction execution is refused explicitly.
    func admittedCommit(_ body: () throws -> Void) throws {
        try owner.performSynchronousOperation(
            contextId: document.objectId, spaceId: document.spaceId
        ) {
            log.append("owner_body_admitted")
            try database.withSerializedAccess {
                try require(sqlite3_get_autocommit(database.dbPointer) != 0, "requires actual outermost transaction")
                try database.transaction {
                    try require(sqlite3_get_autocommit(database.dbPointer) == 0, "original transaction really began")
                    try body()
                }
                try require(sqlite3_get_autocommit(database.dbPointer) != 0, "original outer COMMIT completed")
                log.append("outer_commit_returned")
            }
        }
    }

    func insertFact() throws {
        try database.execute(query: "INSERT INTO fixture_fact(id, payload) VALUES (1, ?);",
                             parameters: ["fixture-only-durable-fact"])
    }
}

private struct CaseResult: Codable {
    let name: String
    let status: String
    let ownerOutcome: String
    let durableRows: Int?
    let facts: [String: String]
    let events: [String]
    let error: String?
}

private func writeJSON<T: Encodable>(_ value: T, to path: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(value).write(to: path, options: .atomic)
}

@main
@MainActor
private enum OriginalOwnerSQLiteAcceptance {
    static let expected = [
        "current_owner_outer_commit_succeeds",
        "retirement_before_admission_denies_body",
        "account_retirement_after_admission_commits_without_publication",
        "retirement_after_commit_preserves_durable_fact",
        "deferred_fk_commit_failure_rolls_back",
        "owner_and_account_teardown_wait_for_actual_drain"
    ]
    static let expectedRows = [1, 0, 1, 1, 0, 1]

    static func main() async {
        do {
            try require(CommandLine.arguments.count == 3, "usage: executable controls|reopen fixture-directory")
            let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            if CommandLine.arguments[1] == "controls" {
                try await controls(root)
            } else if CommandLine.arguments[1] == "reopen" {
                try reopen(root)
            } else { throw ControlFailure(description: "unknown mode") }
        } catch {
            print("FAIL \(error)")
            #if os(Windows)
            ExitProcess(1)
            #else
            exit(1)
            #endif
        }
    }

    static func controls(_ root: URL) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var results: [CaseResult] = []
        let bodies: [@MainActor (Fixture) async throws -> (String, [String: String])] = [
            currentOwner, retiredBeforeAdmission, accountRetiredAfterAdmission,
            retiredAfterCommit, deferredCommitFailure, teardownDrain
        ]
        for (index, name) in expected.enumerated() {
            var fixture: Fixture?
            do {
                let f = try Fixture(root, name)
                fixture = f
                let (outcome, facts) = try await bodies[index](f)
                let rows = try independentRows(f.path)
                try require(rows == expectedRows[index], "final independent-connection row count")
                results.append(.init(name: name, status: "PASS", ownerOutcome: outcome,
                                     durableRows: rows, facts: facts, events: f.log.snapshot(), error: nil))
                print("PASS \(name)")
            } catch {
                results.append(.init(name: name, status: "FAIL", ownerOutcome: "not_verified",
                                     durableRows: nil, facts: [:], events: fixture?.log.snapshot() ?? [],
                                     error: String(describing: error)))
                print("FAIL \(name): \(error)")
            }
            try writeJSON(results, to: root.appendingPathComponent("CASES.json"))
        }
        try writeJSON([
            "pid": String(ProcessInfo.processInfo.processIdentifier),
            "sqlite": String(cString: sqlite3_libversion()),
            "cases": String(results.count),
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0",
            "fixtureOnlyTables": "true", "sourceOwner": "553d4ae90eb8fb0ec21b5ecc319b43db40d2dba2"
        ], to: root.appendingPathComponent("WRITER.json"))
        try require(results.count == 6 && results.allSatisfy { $0.status == "PASS" }, "all six new composition controls must pass")
    }

    static func currentOwner(_ f: Fixture) async throws -> (String, [String: String]) {
        var published = false
        try f.admittedCommit {
            try f.insertFact()
            try require(try independentRows(f.path) == 0, "uncommitted fact must not leak to reader")
        }
        published = true
        f.log.append("owner_returned_current_success")
        try require(published && !f.owner.isRetired && f.owner.isDrained, "current owner succeeded and operation drained")
        try require(try independentRows(f.path) == 1, "real COMMIT visible through distinct connection")
        try require(f.drain.count == 0, "onDrained teardown waits for retirement")
        f.owner.retire()
        try require(f.drain.count == 1 && f.drain.durableRows == 1 && f.drain.error == nil, "retired current owner drains exactly once")
        return ("current_owner_success", ["publishedCurrentSuccess": "true", "outerCommit": "true", "onDrained": "1"])
    }

    static func retiredBeforeAdmission(_ f: Fixture) async throws -> (String, [String: String]) {
        let closing = f.account.beginClosing()
        defer { closing.cancel() }
        f.log.append("account_retired_before_admission")
        var bodyCount = 0
        do {
            try f.admittedCommit { bodyCount += 1; try f.insertFact() }
            throw ControlFailure(description: "retired owner unexpectedly succeeded")
        } catch let error as EditorDocumentWriteError {
            try require(error == .rejected(.retired), "exact pre-admission rejected(retired)")
            f.log.append("owner_rejected_retired")
        }
        try require(bodyCount == 0 && f.owner.isDrained, "no admitted body or leaked operation")
        try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "no SQL transaction started")
        try require(try independentRows(f.path) == 0, "retired source wrote no durable fact")
        return ("rejected_retired", ["bodyExecutions": "0", "outerCommit": "false", "publishedCurrentSuccess": "false"])
    }

    static func accountRetiredAfterAdmission(_ f: Fixture) async throws -> (String, [String: String]) {
        let entered = DispatchSemaphore(value: 0)
        let retired = DispatchSemaphore(value: 0)
        let releaseWorker = DispatchSemaphore(value: 0)
        let workerDone = DispatchSemaphore(value: 0)
        let account = f.account, log = f.log
        DispatchQueue.global().async {
            defer { workerDone.signal() }
            guard entered.wait(timeout: .now() + 10) == .success else {
                log.append("worker_admission_timeout"); retired.signal(); return
            }
            let closing = account.beginClosing()
            log.append("account_beginClosing_returned_on_other_thread")
            retired.signal()
            if releaseWorker.wait(timeout: .now() + 10) != .success { log.append("worker_release_timeout") }
            closing.cancel()
        }
        var published = false
        defer { releaseWorker.signal() }
        do {
            try f.admittedCommit {
                entered.signal()
                try require(retired.wait(timeout: .now() + 10) == .success, "actual other-thread retirement returned")
                try require(account.token() == nil, "account is unavailable before SQL commit")
                try f.insertFact()
                f.log.append("insert_after_account_retirement")
                try require(try independentRows(f.path) == 0, "still uncommitted after retirement")
            }
            published = true
            throw ControlFailure(description: "post-COMMIT retirement published current success")
        } catch let error as EditorDocumentWriteError {
            try require(error == .completedWithoutOwnership(.retired), "exact committed-without-owner outcome")
            f.log.append("owner_completed_without_ownership")
        }
        releaseWorker.signal()
        try require(workerDone.wait(timeout: .now() + 10) == .success, "retirement worker completed")
        try require(!published && f.owner.isRetired && f.owner.isDrained, "no current success; original owner drained")
        try require(try independentRows(f.path) == 1, "admitted transaction remains committed despite Owner error")
        let events = f.log.snapshot()
        try require(!events.contains(where: { $0.contains("timeout") }), "no worker timeout")
        try require(events.firstIndex(of: "account_beginClosing_returned_on_other_thread")! < events.firstIndex(of: "outer_commit_returned")!, "retirement really preceded COMMIT return")
        return ("completed_without_ownership_retired", ["outerCommit": "true", "publishedCurrentSuccess": "false", "retirementThread": "separate", "durableFactDisposition": "retained_pending_recovery"])
    }

    static func retiredAfterCommit(_ f: Fixture) async throws -> (String, [String: String]) {
        var committed = false, published = false
        do {
            try f.owner.performSynchronousOperation(contextId: f.document.objectId, spaceId: f.document.spaceId) {
                f.log.append("owner_body_admitted")
                try f.database.withSerializedAccess {
                    try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "outermost before commit")
                    try f.database.transaction { try f.insertFact() }
                    try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "actual outer COMMIT returned")
                    committed = true
                    f.log.append("outer_commit_returned")
                    try require(try independentRows(f.path) == 1, "durable fact before retirement")
                    f.owner.retire()
                    f.log.append("owner_retired_after_commit")
                    try require(f.owner.pendingOperationCount == 1 && f.drain.count == 0, "teardown cannot run inside admitted body")
                }
            }
            published = true
            throw ControlFailure(description: "retired owner published current success")
        } catch let error as EditorDocumentWriteError {
            try require(error == .completedWithoutOwnership(.retired), "post-COMMIT error is not rollback")
            f.log.append("owner_completed_without_ownership")
        }
        try require(committed && !published, "durable outcome and publication outcome are independent")
        try require(try independentRows(f.path) == 1, "Owner catch must not erase committed fact")
        try require(f.drain.count == 1 && f.drain.durableRows == 1 && f.drain.error == nil, "real teardown observes durable fact once")
        return ("completed_without_ownership_retired", ["outerCommit": "true", "publishedCurrentSuccess": "false", "resetOrRecreate": "false", "durableFactDisposition": "retained_pending_recovery"])
    }

    static func deferredCommitFailure(_ f: Fixture) async throws -> (String, [String: String]) {
        var bodyReturned = false, published = false
        var sqliteMessage = ""
        do {
            try f.admittedCommit {
                try f.insertFact()
                try f.database.execute(query: "INSERT INTO fixture_child(id, parent_id) VALUES (1, 'absent-parent');")
                try require(try rowCount(f.database) == 1, "insert succeeded before deferred COMMIT check")
                try require(try rowCount(f.database, table: "fixture_child") == 1, "deferred invalid FK insert itself succeeded")
                try require(try independentRows(f.path) == 0, "uncommitted fact remains invisible")
                bodyReturned = true
                f.log.append("transaction_body_returned_before_deferred_check")
            }
            published = true
            throw ControlFailure(description: "deferred invalid FK unexpectedly committed")
        } catch let error as SQLiteError {
            guard case .executionFailed(let message) = error else { throw error }
            sqliteMessage = message
            try require(message.lowercased().contains("foreign key"), "actual SQLite COMMIT FK failure")
            f.log.append("sqlite_commit_failed_and_original_transaction_rolled_back")
        }
        try require(bodyReturned && !published, "failure happened after original transaction body")
        try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "original transaction restored autocommit after rollback")
        try require(try independentRows(f.path) == 0, "failed COMMIT fact absent through new connection")
        try require(try independentRows(f.path, table: "fixture_child") == 0, "deferred invalid child rolled back")
        try require(!f.log.snapshot().contains("outer_commit_returned"), "failed COMMIT was never recorded as success")
        try require(f.owner.isDrained, "failed original owner operation drained")
        f.owner.retire()
        try require(f.drain.count == 1 && f.drain.durableRows == 0 && f.drain.error == nil, "teardown sees rolled back state")
        return ("sqlite_commit_failed", ["bodyReturned": "true", "outerCommit": "false", "publishedCurrentSuccess": "false", "autocommitRestored": "true", "sqliteError": sqliteMessage])
    }

    static func teardownDrain(_ f: Fixture) async throws -> (String, [String: String]) {
        let startWait = DispatchSemaphore(value: 0)
        let waiterStarted = DispatchSemaphore(value: 0)
        let accountDrained = DispatchSemaphore(value: 0)
        let account = f.account, log = f.log
        let waiter = Task.detached {
            try require(startWait.wait(timeout: .now() + 10) == .success, "account drain task start gate")
            log.append("account_waitForOperationsToDrain_entering")
            waiterStarted.signal()
            await account.waitForOperationsToDrain()
            log.append("account_waitForOperationsToDrain_returned")
            accountDrained.signal()
        }
        var closing: EditorDocumentWriteLifetime.Observation?
        defer { startWait.signal(); closing?.cancel() }
        var published = false
        do {
            try f.owner.performSynchronousOperation(contextId: f.document.objectId, spaceId: f.document.spaceId) {
                f.log.append("owner_body_admitted")
                try f.database.withSerializedAccess {
                    try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "outermost drain fixture")
                    try f.database.transaction {
                        try f.insertFact()
                        f.owner.retire()
                        closing = account.beginClosing()
                        f.log.append("owner_and_account_retired_inside_transaction")
                        try require(f.owner.pendingOperationCount == 1 && !f.owner.isDrained, "real pending registry retains admitted operation")
                        startWait.signal()
                        try require(waiterStarted.wait(timeout: .now() + 10) == .success, "actual original lifetime drain waiter entered")
                        try require(accountDrained.wait(timeout: .now() + .milliseconds(250)) == .timedOut, "account drain must remain blocked while original admission is held")
                        try require(f.drain.count == 0, "original Owner.onDrained cannot precede COMMIT")
                        try require(try independentRows(f.path) == 0, "teardown hold observes uncommitted state")
                    }
                    f.log.append("outer_commit_returned")
                    try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "real COMMIT restored autocommit")
                    try require(try independentRows(f.path) == 1, "committed row exists before admitted body returns")
                    try require(f.drain.count == 0 && f.owner.pendingOperationCount == 1, "even committed body still holds actual owner drain")
                    try require(accountDrained.wait(timeout: .now()) == .timedOut, "account admission held until synchronous closure returns")
                }
            }
            published = true
            throw ControlFailure(description: "retired drain fixture published success")
        } catch let error as EditorDocumentWriteError {
            try require(error == .completedWithoutOwnership(.retired), "drained operation reports committed-without-ownership")
            f.log.append("owner_completed_without_ownership")
        }
        try await waiter.value
        try require(!published && f.owner.isDrained && f.owner.pendingOperationCount == 0, "real pending registry drained")
        try require(f.drain.count == 1 && f.drain.durableRows == 1 && f.drain.observedAutocommit == 1 && f.drain.error == nil, "original onDrained runs once after actual outer COMMIT")
        let events = f.log.snapshot()
        guard let commit = events.firstIndex(of: "outer_commit_returned"),
              let ownerDrain = events.firstIndex(of: "owner_onDrained"),
              let accountDrain = events.firstIndex(of: "account_waitForOperationsToDrain_returned") else {
            throw ControlFailure(description: "missing actual teardown events")
        }
        try require(commit < ownerDrain && commit < accountDrain, "both original drains follow actual COMMIT")
        return ("completed_without_ownership_retired", ["outerCommit": "true", "publishedCurrentSuccess": "false", "ownerOnDrained": "1", "accountDrainReturned": "true", "negativeHoldMilliseconds": "250"])
    }

    static func reopen(_ root: URL) throws {
        let writer = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: root.appendingPathComponent("WRITER.json")))
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        try require(writer["pid"] != pid, "reopen must be a distinct actual process")
        var facts: [String: String] = [
            "status": "PASS", "pid": pid, "writerPID": writer["pid"] ?? "",
            "sqlite": String(cString: sqlite3_libversion()),
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0"
        ]
        for (index, name) in expected.enumerated() {
            let path = root.appendingPathComponent(name + ".sqlite").path
            let rows = try independentRows(path)
            try require(rows == expectedRows[index], "distinct-process durable rows: \(name)")
            try require(try independentRows(path, table: "fixture_child") == 0, "no deferred child survived: \(name)")
            facts[name] = String(rows)
        }
        try writeJSON(facts, to: root.appendingPathComponent("REOPEN.json"))
        print("PASS distinct_process_reopen_all_six_fixture_facts")
    }
}
