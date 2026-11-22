// Positive-only continuation after the initial fixture path failure.
// The runner adds the exact original helper prefix, observation type and
// unchanged positive assertion method. No passing negative assertion is compiled.

@main
@MainActor
private enum OriginalOwnerExclusiveSQLiteAcceptance {
    static let positiveName = "exclusive_read_allows_explicit_local_read_scope_commit"
    static let negativeName = "exclusive_read_refuses_default_mutation_before_sql"

    static func main() async {
        do {
            try require(CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4,
                        "usage: executable positive|reopen-positive root, or reopen-retained-negative old-root output-root")
            let mode = CommandLine.arguments[1]
            let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
            if mode == "positive" && CommandLine.arguments.count == 3 {
                try await positive(root)
            } else if mode == "reopen-positive" && CommandLine.arguments.count == 3 {
                try reopenPositive(root)
            } else if mode == "reopen-retained-negative" && CommandLine.arguments.count == 4 {
                let output = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
                try reopenRetainedNegative(root, output: output)
            } else { throw ControlFailure(description: "unknown mode or argument count") }
        } catch {
            print("FAIL \(error)")
            #if os(Windows)
            ExitProcess(1)
            #else
            exit(1)
            #endif
        }
    }

    static func positive(_ root: URL) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var fixture: Fixture?
        let row: CaseResult
        do {
            let f = try Fixture(root, positiveName)
            fixture = f
            let (outcome, facts) = try await explicitReadScopeCommit(f)
            let durable = try independentRows(f.path)
            try require(durable == 1, "unchanged positive assertion must leave one committed fact")
            row = .init(name: positiveName, status: "PASS", ownerOutcome: outcome,
                        durableRows: durable, facts: facts, events: f.log.snapshot(), error: nil)
            print("PASS \(positiveName)")
        } catch {
            row = .init(name: positiveName, status: "FAIL", ownerOutcome: "not_verified",
                        durableRows: nil, facts: [:], events: fixture?.log.snapshot() ?? [],
                        error: String(describing: error))
            print("FAIL \(positiveName): \(error)")
        }
        try writeJSON([row], to: root.appendingPathComponent("CASES.json"))
        try writeJSON([
            "pid": String(ProcessInfo.processInfo.processIdentifier),
            "sqlite": String(cString: sqlite3_libversion()), "cases": "1",
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0",
            "scope": "unchanged positive assertion only; passing negative not compiled or executed"
        ], to: root.appendingPathComponent("WRITER.json"))
        try require(row.status == "PASS", "positive-only assertion must pass")
    }

    static func reopenPositive(_ root: URL) throws {
        let writer = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: root.appendingPathComponent("WRITER.json")))
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        try require(writer["pid"] != nil && writer["pid"] != pid && writer["cases"] == "1",
                    "distinct actual process for the positive fixture")
        let path = root.appendingPathComponent(positiveName + ".sqlite").path
        try require(try independentRows(path) == 1, "fresh process preserves the positive committed row")
        try require(try independentRows(path, table: "fixture_child") == 0, "no extra fixture child")
        try writeJSON([
            "status": "PASS", "pid": pid, "writerPID": writer["pid"] ?? "",
            "sqlite": String(cString: sqlite3_libversion()), "durableRows": "1",
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0"
        ], to: root.appendingPathComponent("REOPEN.json"))
        print("PASS distinct_process_reopen_positive_committed_fact")
    }

    static func reopenRetainedNegative(_ root: URL, output: URL) throws {
        let cases = try JSONDecoder().decode([CaseResult].self, from: Data(contentsOf: root.appendingPathComponent("CASES.json")))
        let writer = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: root.appendingPathComponent("WRITER.json")))
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        try require(cases.count == 2 && cases[0].name == positiveName && cases[0].status == "FAIL",
                    "actual retained partial-run evidence must identify the unresolved positive")
        let negative = cases[1]
        try require(negative.name == negativeName && negative.status == "PASS" && negative.durableRows == 0 &&
                    negative.facts["bodyExecutions"] == "0" && negative.facts["SQLTransactionStarted"] == "false" &&
                    negative.ownerOutcome == "rejected_unqualified_dispatch_and_failed_write_latched",
                    "reuse only the exact retained successful negative control")
        try require(writer["pid"] != nil && writer["pid"] != pid && writer["cases"] == "2",
                    "fresh actual process for the original negative database")
        let path = root.appendingPathComponent(negativeName + ".sqlite").path
        try require(try independentRows(path) == 0, "original negative database still contains no local fact")
        try require(try independentRows(path, table: "fixture_child") == 0, "no hidden fixture child")
        try writeJSON([
            "status": "PASS_REOPEN_OF_RETAINED_NEGATIVE", "pid": pid, "writerPID": writer["pid"] ?? "",
            "sqlite": String(cString: sqlite3_libversion()), "durableRows": "0",
            "originalNegativeControlReexecuted": "false", "readOnlyOriginalSQLiteConnection": "true",
            "nativeRPC": "0", "productionIdentityWrites": "0", "nativeReceipts": "0", "ACK": "0"
        ], to: output.appendingPathComponent("RETAINED_NEGATIVE_REOPEN.json"))
        print("PASS distinct_process_readonly_reopen_retained_negative")
    }
}
