// New entrypoint for the two newly required held-read combinations.
// The runner prepends the exact shared fixture-helper prefix from the frozen
// f922db58 six-case source. None of the six prior assertions is included.

@main
@MainActor
private enum OriginalOwnerExclusiveSQLiteAcceptance {
    static func main() async {
        do {
            try require(CommandLine.arguments.count == 3, "usage: executable controls|reopen fixture-directory")
            let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            if CommandLine.arguments[1] == "controls" {
                try await exclusiveControls(root)
            } else if CommandLine.arguments[1] == "reopen" {
                try exclusiveReopen(root)
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
}


// Additional focused combination: preserve the original exclusive native read
// lineage while committing only fixture-local SQLite state. The original six
// assertion bodies are excluded; only their unchanged shared helper prefix is reused.
@MainActor
private final class ExclusiveReadObservation {
    var bodyExecutions = 0
    var innerRejected = false
    var publishedCurrentSuccess = false
}

@MainActor
private extension OriginalOwnerExclusiveSQLiteAcceptance {
    static var exclusiveNames: [String] {
        [
            "exclusive_read_allows_explicit_local_read_scope_commit",
            "exclusive_read_refuses_default_mutation_before_sql"
        ]
    }

    static func exclusiveControls(_ root: URL) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var rows: [CaseResult] = []
        let bodies: [@MainActor (Fixture) async throws -> (String, [String: String])] = [
            explicitReadScopeCommit, defaultMutationIsRefused
        ]
        for (index, name) in exclusiveNames.enumerated() {
            var fixture: Fixture?
            do {
                let f = try Fixture(root, name)
                fixture = f
                let (outcome, facts) = try await bodies[index](f)
                let durable = try independentRows(f.path)
                try require(durable == (index == 0 ? 1 : 0), "exclusive-read durable row count")
                rows.append(.init(name: name, status: "PASS", ownerOutcome: outcome,
                                  durableRows: durable, facts: facts, events: f.log.snapshot(), error: nil))
                print("PASS \(name)")
            } catch {
                rows.append(.init(name: name, status: "FAIL", ownerOutcome: "not_verified",
                                  durableRows: nil, facts: [:], events: fixture?.log.snapshot() ?? [],
                                  error: String(describing: error)))
                print("FAIL \(name): \(error)")
            }
            try writeJSON(rows, to: root.appendingPathComponent("CASES.json"))
        }
        try writeJSON([
            "pid": String(ProcessInfo.processInfo.processIdentifier),
            "sqlite": String(cString: sqlite3_libversion()), "cases": String(rows.count),
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0",
            "fixtureOnlyTables": "true", "sourceOwner": "553d4ae90eb8fb0ec21b5ecc319b43db40d2dba2",
            "scope": "two new exclusive-read combinations; six original controls not executed"
        ], to: root.appendingPathComponent("WRITER.json"))
        try require(rows.count == 2 && rows.allSatisfy { $0.status == "PASS" }, "both new exclusive-read controls must pass")
    }

    static func explicitReadScopeCommit(_ f: Fixture) async throws -> (String, [String: String]) {
        let observation = ExclusiveReadObservation()
        let value: String = try await f.owner.withExclusiveRead(
            contextId: f.document.objectId, spaceId: f.document.spaceId,
            rpcNames: ["ObjectShow"]
        ) {
            try await MainActor.run {
                try require(f.owner.isCapturing && f.owner.pendingOperationCount == 1, "actual exclusive-read parent holds capture")
                f.log.append("original_exclusive_read_entered")
                let committed: String = try f.owner.performSynchronousOperation(
                    contextId: f.document.objectId, spaceId: f.document.spaceId,
                    requiresEditing: false
                ) {
                    observation.bodyExecutions += 1
                    try require(f.owner.isCapturing && f.owner.pendingOperationCount == 2, "actual child read inherits held parent scope")
                    f.log.append("explicit_read_scope_local_body_admitted")
                    return try f.database.withSerializedAccess {
                        try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "real outer transaction required")
                        try f.database.transaction {
                            try f.insertFact()
                            try require(f.owner.isCapturing, "read barrier held through SQL body")
                            try require(sqlite3_get_autocommit(f.database.dbPointer) == 0, "actual transaction active")
                            try require(try independentRows(f.path) == 0, "uncommitted local row stays invisible")
                        }
                        try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "actual outer COMMIT completed")
                        try require(f.owner.isCapturing && f.owner.pendingOperationCount == 2, "read barrier still held at COMMIT boundary")
                        try require(try independentRows(f.path) == 1, "real committed local row visible")
                        f.log.append("local_outer_commit_inside_exclusive_read")
                        return "fixture_local_fact_committed"
                    }
                }
                try require(f.owner.isCapturing && f.owner.pendingOperationCount == 1, "child read drains while original barrier remains held")
                f.log.append("explicit_child_read_returned_before_capture_release")
                return committed
            }
        }
        observation.publishedCurrentSuccess = true
        f.log.append("original_exclusive_read_returned")
        try require(value == "fixture_local_fact_committed" && observation.bodyExecutions == 1, "one actual read-scoped local commit")
        try require(!f.owner.isCapturing && f.owner.isDrained && !f.owner.isRetired, "original exclusive read released only after completion")
        try require(try independentRows(f.path) == 1, "read-scoped local fact persists")
        f.owner.retire()
        try require(f.drain.count == 1 && f.drain.durableRows == 1 && f.drain.error == nil, "normal teardown sees committed local fact")
        return ("current_owner_explicit_read_scope_success", [
            "bodyExecutions": "1", "requiresEditing": "false", "outerCommit": "true",
            "originalReadBarrierHeldAtCommit": "true", "publishedCurrentSuccess": "true",
            "nativeRPCDispatched": "0", "nativeMutationAuthorityUpgrade": "false"
        ])
    }

    static func defaultMutationIsRefused(_ f: Fixture) async throws -> (String, [String: String]) {
        let observation = ExclusiveReadObservation()
        do {
            let _: String = try await f.owner.withExclusiveRead(
                contextId: f.document.objectId, spaceId: f.document.spaceId,
                rpcNames: ["ObjectShow"]
            ) {
                try await MainActor.run {
                    try require(f.owner.isCapturing && f.owner.pendingOperationCount == 1, "actual exclusive read holds parent")
                    f.log.append("original_exclusive_read_entered")
                    do {
                        // Deliberately use the original default mutation scope.
                        // It must be refused before this explicit fixture SQL body.
                        try f.owner.performSynchronousOperation(
                            contextId: f.document.objectId, spaceId: f.document.spaceId
                        ) {
                            observation.bodyExecutions += 1
                            try f.database.withSerializedAccess {
                                try f.database.transaction { try f.insertFact() }
                            }
                        }
                        throw ControlFailure(description: "native read lineage incorrectly upgraded to mutation")
                    } catch let error as EditorDocumentWriteError {
                        try require(error == .rejected(.unqualifiedDispatch), "exact default nested-mutation rejection")
                        observation.innerRejected = true
                        f.log.append("default_mutation_rejected_before_fixture_sql")
                    }
                    try require(observation.bodyExecutions == 0, "rejected nested body must never begin")
                    try require(sqlite3_get_autocommit(f.database.dbPointer) != 0, "rejected mutation started no SQL transaction")
                    try require(try independentRows(f.path) == 0, "rejected mutation wrote no local fact")
                    try require(f.owner.isCapturing && f.owner.pendingOperationCount == 1, "rejected child created no pending lease")
                    return "inner_rejection_observed"
                }
            }
            observation.publishedCurrentSuccess = true
            throw ControlFailure(description: "exclusive read ignored the original failed-write latch")
        } catch let error as EditorDocumentWriteError {
            try require(error == .rejected(.failedWrite), "original parent fails closed after swallowed authority-upgrade attempt")
            f.log.append("original_exclusive_read_failed_write_latched")
        }
        try require(observation.innerRejected && !observation.publishedCurrentSuccess && observation.bodyExecutions == 0, "separate inner rejection and outer no-publication outcomes")
        try require(f.owner.isDrained && !f.owner.isCapturing, "original failed read still releases the actual barrier")
        try require(try independentRows(f.path) == 0, "no fixture row after rejected native mutation upgrade")
        f.owner.retire()
        try require(f.drain.count == 1 && f.drain.durableRows == 0 && f.drain.error == nil, "teardown sees untouched local table")
        return ("rejected_unqualified_dispatch_and_failed_write_latched", [
            "bodyExecutions": "0", "requiresEditing": "true_default", "outerCommit": "false",
            "innerRejection": "unqualifiedDispatch", "outerRejection": "failedWrite",
            "publishedCurrentSuccess": "false", "nativeRPCDispatched": "0"
        ])
    }

    static func exclusiveReopen(_ root: URL) throws {
        let writer = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: root.appendingPathComponent("WRITER.json")))
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        try require(writer["pid"] != pid && writer["cases"] == "2", "separate actual process for only the two new controls")
        var facts: [String: String] = [
            "status": "PASS", "pid": pid, "writerPID": writer["pid"] ?? "",
            "sqlite": String(cString: sqlite3_libversion()), "nativeRPC": "0",
            "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0"
        ]
        for (index, name) in exclusiveNames.enumerated() {
            let path = root.appendingPathComponent(name + ".sqlite").path
            let count = try independentRows(path)
            try require(count == (index == 0 ? 1 : 0), "fresh process preserves read-scope outcome: \(name)")
            try require(try independentRows(path, table: "fixture_child") == 0, "no extra fixture child")
            facts[name] = String(count)
        }
        try writeJSON(facts, to: root.appendingPathComponent("REOPEN.json"))
        print("PASS distinct_process_reopen_both_exclusive_read_facts")
    }
}
