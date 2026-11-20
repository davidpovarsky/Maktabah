import Foundation
import Dispatch
import SQLite3
import Synchronization
import Darwin

// The driver compiles this file with whole, byte-verified production files.
// OriginalLocalFixture.swift is the unchanged original43 fixture prefix only;
// no production method, SQLite connection, state lock or lifetime is doubled.

enum DisconnectControlError: Error { case rollback }

final class DisconnectTrace: Sendable {
    struct Marker: Codable, Sendable {
        let sequence: Int
        let event: String
        let uptimeNanoseconds: UInt64
    }
    let directory: URL
    private let next = Mutex(0)
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    func mark(_ event: String) throws {
        try next.withLock { value in
            value += 1
            let marker = Marker(sequence: value, event: event, uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds)
            let file = directory.appendingPathComponent(String(format: "%03d", value) + "-" + event + ".json")
            guard !FileManager.default.fileExists(atPath: file.path) else { throw LocalCheckFailure("marker exists") }
            try JSONEncoder().encode(marker).write(to: file, options: .atomic)
        }
    }
}

final class DisconnectRaceState: Sendable {
    struct Value: Sendable {
        var transactionEntered = false
        var disconnectStarted = false
        var disconnectReturned = false
        var helperRequested = false
        var helperReturned = false
        var transactionReturned = false
        var probeReturned = false
        var errors: [String] = []
    }
    private let state = Mutex(Value())
    var snapshot: Value { state.withLock { $0 } }
    func update(_ body: (inout Value) -> Void) { state.withLock { value in body(&value) } }
    func fail(_ error: any Error) { state.withLock { $0.errors.append(String(describing: error)) } }
}

struct DisconnectColdExpected: Codable {
    let databaseRelativePath: String
    let annotationID: Int64
    let annotationUUID: String
    let note: String
    let annotations: Int
    let tags: Int
    let pending: Int
    let uncommittedNote: String?
}

@MainActor
final class DisconnectCases {
    let root: URL
    let trace: DisconnectTrace
    init(root: URL) throws {
        self.root = root
        trace = try .init(directory: root.appendingPathComponent("markers", isDirectory: true))
    }

    func wait(_ description: String, state: DisconnectRaceState,
              until predicate: (DisconnectRaceState.Value) -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while true {
            let current = state.snapshot
            try check(current.errors.isEmpty, description + ": " + current.errors.joined(separator: "; "))
            if predicate(current) { return }
            guard ContinuousClock.now < deadline else { throw LocalCheckFailure(description + " timed out") }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    func expected(_ fixture: LocalFixture, note: String, uncommitted: String? = nil) throws {
        let value = DisconnectColdExpected(databaseRelativePath: fixture.url.lastPathComponent + "/Annotations.sqlite",
            annotationID: fixture.annotation.id!, annotationUUID: fixture.annotation.ckRecordId!, note: note,
            annotations: 1, tags: 2, pending: 2, uncommittedNote: uncommitted)
        try JSONEncoder().encode(value).write(to: root.appendingPathComponent("COLD_EXPECTED.json"), options: .atomic)
    }

    func requireDetached(_ repository: AnnotationRepository, _ connection: AnnotationLocalEditorConnection) throws {
        try check(repository.db == nil && repository.syncPendingStore == nil, "original handle/pending store not detached")
        try check(repository.dbURL == connection.databaseURL, "original reconnect URL changed")
        try check(!connection.lifetime.isCurrent, "captured lifetime was not retired")
        try rejects(AnnotationLocalEditorError.noConnection) { _ = try repository.captureLocalEditorConnection() }
    }

    func requireSame(_ repository: AnnotationRepository, _ connection: AnnotationLocalEditorConnection) throws {
        let current = try repository.captureLocalEditorConnection()
        try check(current.database === connection.database && current.lifetime === connection.lifetime,
                  "replacement connection/lifetime was changed")
        // SyncPendingStore is a value containing one private database reference.
        // Compare that actual reference, rather than attempting object identity
        // on the struct or accepting equal rows from a different database.
        func pendingDatabase(_ store: SyncPendingStore) throws -> SQLiteDatabase {
            let reflected = Mirror(reflecting: store)
            guard reflected.displayStyle == .struct, reflected.children.count == 1,
                  let child = reflected.children.first, child.label == "db",
                  let database = child.value as? SQLiteDatabase else {
                throw LocalCheckFailure("original pending store database layout differs")
            }
            return database
        }
        let currentPendingDatabase = try pendingDatabase(current.syncPending)
        let capturedPendingDatabase = try pendingDatabase(connection.syncPending)
        try check(currentPendingDatabase === capturedPendingDatabase
                  && currentPendingDatabase === connection.database && current.lifetime.isCurrent,
                  "replacement pending owner was changed or retired")
    }

    nonisolated static func capturedDisconnect(_ repository: AnnotationRepository,
                                              database: SQLiteDatabase, lifetime: AnnotationLocalEditorLifetime) {
        #if REPOSITORY_DISCONNECT_CANDIDATE
        repository.disconnect(database: database, lifetime: lifetime)
        #else
        fatalError("Captured-generation controls must not execute in the original baseline binary")
        #endif
    }

    func progress(baseline: Bool, useCaptured: Bool = false) async throws {
        let fixture = try LocalFixture(root: root, name: "progress")
        let repository = fixture.repository
        let connection = try repository.captureLocalEditorConnection()
        let id = fixture.annotation.id!
        let uncommitted = "uncommitted-before-disconnect"
        let final = "committed-original-repository-helper"
        try expected(fixture, note: baseline ? fixture.annotation.note! : final, uncommitted: uncommitted)
        let state = DisconnectRaceState(), release = DispatchSemaphore(value: 0)
        let trace = trace
        try trace.mark("fixture_ready")
        DispatchQueue(label: "owned-disconnect-transaction-" + UUID().uuidString).async {
            do {
                try repository.transaction {
                    try repository.exec("UPDATE annotations SET note=? WHERE id=?;", parameters: [uncommitted, id])
                    let observed = try connection.database.fetch(query: "SELECT note FROM annotations WHERE id=?;",
                        parameters: [id]) { $0.string(at: 0) }.first ?? nil
                    try check(observed == uncommitted, "real transaction did not perform its uncommitted write")
                    try trace.mark("transaction_acquired_and_uncommitted_write")
                    state.update { $0.transactionEntered = true }
                    // Synchronous worker only. No blocking wait occurs in an async context.
                    guard release.wait(timeout: .now() + 5) == .success else {
                        throw LocalCheckFailure("transaction release was not received")
                    }
                    try trace.mark("original_repository_exec_requested")
                    state.update { $0.helperRequested = true }
                    try repository.exec("UPDATE annotations SET note=? WHERE id=?;", parameters: [final, id])
                    try trace.mark("original_repository_exec_returned")
                    state.update { $0.helperReturned = true }
                }
                try trace.mark("transaction_returned")
                state.update { $0.transactionReturned = true }
            } catch { state.fail(error) }
        }
        defer { release.signal() }
        try await wait("original transaction entry", state: state) { $0.transactionEntered }
        DispatchQueue(label: "owned-disconnect-teardown-" + UUID().uuidString).async {
            do {
                try trace.mark("disconnect_requested")
                state.update { $0.disconnectStarted = true }
                if useCaptured {
                    Self.capturedDisconnect(repository, database: connection.database, lifetime: connection.lifetime)
                } else {
                    repository.disconnect()
                }
                try trace.mark("disconnect_returned")
                state.update { $0.disconnectReturned = true }
            } catch { state.fail(error) }
        }
        try await wait("disconnect worker entry", state: state) { $0.disconnectStarted }
        if baseline {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while connection.lifetime.isCurrent {
                try check(state.snapshot.errors.isEmpty, "baseline worker failed before original retirement")
                guard ContinuousClock.now < deadline else { throw LocalCheckFailure("original disconnect did not retire captured lifetime") }
                try await Task.sleep(for: .milliseconds(5))
            }
            try trace.mark("captured_lifetime_retired_before_transaction_release")
            release.signal()
            try await wait("original repository helper request", state: state) { $0.helperRequested }
            // A parent-owned bounded process observes this real lock cycle.
            // Continue checking actual progress; merely sleeping can never
            // qualify the baseline if either original operation returns.
            while true {
                let value = state.snapshot
                try check(value.errors.isEmpty && !value.helperReturned && !value.transactionReturned && !value.disconnectReturned,
                          "original blocked cycle unexpectedly progressed or failed")
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        DispatchQueue(label: "owned-disconnect-state-probe-" + UUID().uuidString).async {
            do {
                let observed = try repository.captureLocalEditorConnection()
                try check(observed.database === connection.database && observed.lifetime === connection.lifetime
                          && observed.lifetime.isCurrent, "live original state changed before database release")
                try trace.mark("repository_state_read_while_database_held")
                state.update { $0.probeReturned = true }
            } catch { state.fail(error) }
        }
        try await wait("repository state remains available", state: state) { $0.probeReturned }
        try check(connection.lifetime.isCurrent && !state.snapshot.disconnectReturned,
                  "disconnect retired/detached before the held database completed")
        release.signal()
        try await wait("real helper, transaction and teardown completion", state: state) {
            $0.helperReturned && $0.transactionReturned && $0.disconnectReturned
        }
        try requireDetached(repository, connection)
        let observed = try connection.database.fetch(query: "SELECT note FROM annotations WHERE id=?;", parameters: [id]) {
            $0.string(at: 0)
        }.first ?? nil
        try check(observed == final, "original helper transaction did not commit")
    }

    func queuedStaleCapture() async throws {
        let fixture = try LocalFixture(root: root, name: "stale-wait")
        let repository = fixture.repository, old = try repository.captureLocalEditorConnection()
        try expected(fixture, note: fixture.annotation.note!)
        let state = DisconnectRaceState(), release = DispatchSemaphore(value: 0), trace = trace
        DispatchQueue(label: "owned-stale-database-" + UUID().uuidString).async {
            old.database.withSerializedAccess {
                state.update { $0.transactionEntered = true }
                if release.wait(timeout: .now() + 5) != .success { state.fail(LocalCheckFailure("stale holder release timed out")) }
            }
            state.update { $0.transactionReturned = true }
        }
        defer { release.signal() }
        try await wait("old database held", state: state) { $0.transactionEntered }
        DispatchQueue(label: "owned-stale-teardown-" + UUID().uuidString).async {
            state.update { $0.disconnectStarted = true }
            Self.capturedDisconnect(repository, database: old.database, lifetime: old.lifetime)
            state.update { $0.disconnectReturned = true }
        }
        try await wait("captured teardown worker", state: state) { $0.disconnectStarted }
        repository.connect()
        let replacement = try repository.captureLocalEditorConnection()
        try check(replacement.database !== old.database && replacement.lifetime !== old.lifetime,
                  "original connect did not publish a replacement generation")
        try check(!old.lifetime.isCurrent && replacement.lifetime.isCurrent, "connection replacement lifetime mismatch")
        try trace.mark("replacement_published_before_old_database_release")
        release.signal()
        try await wait("stale captured teardown returned", state: state) { $0.transactionReturned && $0.disconnectReturned }
        try requireSame(repository, replacement)
        try check(try repository.loadAnnotationById(fixture.annotation.id!) == fixture.annotation,
                  "stale teardown changed actual replacement contents")
    }

    func execute(_ name: String) async throws {
        switch name {
        case "progress_default":
            try await progress(baseline: false)
        case "progress_captured":
            try await progress(baseline: false, useCaptured: true)
        case "stale_capture_queued_during_replacement":
            try await queuedStaleCapture()
        case "stale_database_with_current_lifetime_cannot_detach":
            let f = try LocalFixture(root: root, name: "wrong-database"), repository = f.repository
            let old = try repository.captureLocalEditorConnection(); repository.connect()
            let replacement = try repository.captureLocalEditorConnection()
            Self.capturedDisconnect(repository, database: old.database, lifetime: replacement.lifetime)
            try requireSame(repository, replacement); try expected(f, note: f.annotation.note!)
        case "current_database_with_stale_lifetime_cannot_detach":
            let f = try LocalFixture(root: root, name: "wrong-lifetime"), repository = f.repository
            let old = try repository.captureLocalEditorConnection(); repository.connect()
            let replacement = try repository.captureLocalEditorConnection()
            Self.capturedDisconnect(repository, database: replacement.database, lifetime: old.lifetime)
            try requireSame(repository, replacement); try expected(f, note: f.annotation.note!)
        case "matched_capture_detaches_only_original_owner":
            let f = try LocalFixture(root: root, name: "matched"), repository = f.repository
            let old = try repository.captureLocalEditorConnection()
            Self.capturedDisconnect(repository, database: old.database, lifetime: old.lifetime)
            try requireDetached(repository, old); try expected(f, note: f.annotation.note!)
        case "nil_default_disconnect_preserves_later_setup":
            let repository = AnnotationRepository.shared
            try check(repository.db == nil && repository.dbURL == nil && repository.syncPendingStore == nil,
                      "fresh process was not initially disconnected")
            repository.disconnect(); repository.disconnect()
            try rejects(AnnotationLocalEditorError.noConnection) { _ = try repository.captureLocalEditorConnection() }
            let f = try LocalFixture(root: root, name: "after-nil")
            try check(try repository.captureLocalEditorConnection().lifetime.isCurrent, "nil disconnect poisoned later setup")
            try expected(f, note: f.annotation.note!)
        case "repeated_default_disconnect_is_idempotent":
            let f = try LocalFixture(root: root, name: "repeated"), repository = f.repository
            let old = try repository.captureLocalEditorConnection()
            repository.disconnect(); repository.disconnect(); repository.disconnect()
            try requireDetached(repository, old); try expected(f, note: f.annotation.note!)
        case "reopen_preserves_rows_queue_and_retires_old_connection":
            let f = try LocalFixture(root: root, name: "reopen"), repository = f.repository
            let old = try repository.captureLocalEditorConnection()
            repository.disconnect(); try requireDetached(repository, old); repository.connect()
            let replacement = try repository.captureLocalEditorConnection()
            try check(replacement.database !== old.database && replacement.lifetime !== old.lifetime
                      && replacement.lifetime.isCurrent, "reopen reused or retired the wrong generation")
            try check(try repository.loadAnnotationById(f.annotation.id!) == f.annotation, "reopen changed original row/tags")
            try expected(f, note: f.annotation.note!)
        case "rollback_then_disconnect_preserves_original_note":
            let f = try LocalFixture(root: root, name: "rollback"), repository = f.repository
            let old = try repository.captureLocalEditorConnection()
            do {
                try repository.transaction {
                    try repository.exec("UPDATE annotations SET note=? WHERE id=?;", parameters: ["must-roll-back", f.annotation.id!])
                    throw DisconnectControlError.rollback
                }
                throw LocalCheckFailure("original transaction swallowed rollback error")
            } catch DisconnectControlError.rollback {}
            repository.disconnect(); try requireDetached(repository, old); try expected(f, note: f.annotation.note!)
        default:
            throw LocalCheckFailure("unknown disconnect control")
        }
    }
}

@main
struct AnnotationRepositoryDisconnectMain {
    struct Result: Codable { let name: String; let status: String; let error: String?; let sourceKind: String }
    @MainActor
    static func main() async {
        #if REPOSITORY_DISCONNECT_CANDIDATE
        let sourceKind = "candidate"
        #else
        let sourceKind = "original-baseline"
        #endif
        guard CommandLine.arguments.count == 3 else { Darwin.exit(64) }
        let name = CommandLine.arguments[1], root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        do {
            let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let entries = try FileManager.default.contentsOfDirectory(atPath: root.path)
            try check(values.isDirectory == true && values.isSymbolicLink != true
                      && entries.isEmpty,
                      "requires a fresh caller-owned fixture directory")
            let cases = try DisconnectCases(root: root)
            if name == "baseline-deadlock" {
                try check(sourceKind == "original-baseline", "baseline source kind differs")
                try await cases.progress(baseline: true)
                throw LocalCheckFailure("original deadlock reproduction unexpectedly returned")
            }
            try check(sourceKind == "candidate", "candidate source kind differs")
            try await cases.execute(name)
            let result = Result(name: name, status: "PASS", error: nil, sourceKind: sourceKind)
            try JSONEncoder().encode(result).write(to: root.appendingPathComponent("CASE.json"), options: .atomic)
            print("PASS \(name)")
            Darwin.exit(0)
        } catch {
            let result = Result(name: name, status: "FAIL", error: String(describing: error), sourceKind: sourceKind)
            try? JSONEncoder().encode(result).write(to: root.appendingPathComponent("CASE.json"), options: .atomic)
            print("FAIL \(name): \(error)")
            Darwin.exit(1)
        }
    }
}
