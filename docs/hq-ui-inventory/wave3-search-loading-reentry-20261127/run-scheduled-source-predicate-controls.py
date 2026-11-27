#!/usr/bin/env python3
"""Second source-bound control: explicit one-shot timer fire dates; attempt1 is preserved."""
import datetime, hashlib, json, os, pathlib, pwd, re, subprocess, sys
TREE = pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave3-search-loading-reentry-20261127")
BASE = "e60a54127f8201e2bd980774b8c73b7345066b9e"
TEST = "Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift"
DOCS = TREE / "docs/hq-ui-inventory/wave3-search-loading-reentry-20261127"
OUT = DOCS / "validation/attempt-2"
BUILD = pathlib.Path("/mnt/development/projects/diagnostics/otzaria-wave3-search-loading-reentry-20261127/attempt-2")
CACHE = pathlib.Path("/mnt/development/projects/diagnostics/otzaria-wave3-reader-object-identity-20261127/module-cache")
def sha(data): return hashlib.sha256(data).hexdigest()
old = subprocess.check_output(["runuser", "-u", "ubuntu", "--", "git", "-C", str(TREE), "show", BASE + ":" + TEST]).decode()
new = (TREE / TEST).read_text()
assert sha(old.encode()) == "fa4cbfc31a73d0265efc572923b756d7e39aa092c70fbdee36e06f0804a66de9"
assert sha(new.encode()) == "2efbdc09aed91c9c2ed2dea67a9ed85f7a4070cb7eb501ee2537375a87680d17"
assert CACHE.is_dir()
def extract(source):
    function = source.index("    private func rejectQuery(engine:")
    start = source.index("        let stale = XCTNSPredicateExpectation", function)
    finish = source.index("        XCTAssertEqual(rows.count, 0)", start) + len("        XCTAssertEqual(rows.count, 0)")
    return source[start:finish]
blocks = {"baseline": extract(old), "candidate": extract(new)}
prefix = """import Foundation
import XCTest

// Explicit UI-state doubles only. Every access below occurs on the XCTest
// main run loop; they do not represent an application or a native element.
final class ElementBoundary: @unchecked Sendable {
    var exists: Bool
    var isHittable = true
    var value: Any? = "בראשית"
    init(exists: Bool = true) { self.exists = exists }
}
final class RowsBoundary: @unchecked Sendable {
    var storedCount = 0
    var reads = 0
    var count: Int { reads += 1; return storedCount }
}
final class UIBoundary: @unchecked Sendable {
    let elements = [
        "global-search-count": ElementBoundary(exists: false),
        "global-search-page-error": ElementBoundary(exists: false),
        "global-search-loading": ElementBoundary(exists: false),
        "global-search-dirty": ElementBoundary(exists: false),
        "global-search-retry": ElementBoundary()
    ]
    func control(_ id: String) -> ElementBoundary { elements[id]! }
}
final class TimelineBoundary: @unchecked Sendable {
    var events: [[String: Any]] = []
}
final class RejectionStabilityTests: XCTestCase, @unchecked Sendable {
    private let ui = UIBoundary()
    func testVerbatimOriginalRejectionStability() throws {
        precondition(Thread.isMainThread)
        let fixture = try XCTUnwrap(ProcessInfo.processInfo.environment["SEARCH_LOADING_FIXTURE"])
        let output = try XCTUnwrap(ProcessInfo.processInfo.environment["SEARCH_LOADING_RECORD"])
        let rows = RowsBoundary(), text = ElementBoundary(), field = ElementBoundary()
        let query = "בראשית"
        let timeline = TimelineBoundary()
        let started = Date().timeIntervalSince1970
        XCTAssertFalse(ui.control("global-search-loading").exists)
        timeline.events.append(["event": "initial_settled_rejection", "loading": false, "at": started])
        let mutation = Timer(timeInterval: 0.08, repeats: false) { [self] _ in
            MainActor.assumeIsolated {
                precondition(Thread.isMainThread)
                if fixture == "loading_reentry_persistent" || fixture == "loading_reentry_then_recovers" {
                    self.ui.control("global-search-loading").exists = true
                    timeline.events.append(["event": "loading_reentered", "rowsEvaluatedBefore": rows.reads,
                                            "at": Date().timeIntervalSince1970])
                } else if fixture == "original_result_rows_reenter" {
                    rows.storedCount = 1
                    timeline.events.append(["event": "result_rows_reentered", "rowsEvaluatedBefore": rows.reads,
                                            "at": Date().timeIntervalSince1970])
                }
            }
        }
        let recovery = Timer(timeInterval: 0.30, repeats: false) { [self] _ in
            MainActor.assumeIsolated {
                precondition(Thread.isMainThread)
                if fixture == "loading_reentry_then_recovers" {
                    self.ui.control("global-search-loading").exists = false
                    timeline.events.append(["event": "loading_recovered", "at": Date().timeIntervalSince1970])
                }
            }
        }
        mutation.fireDate = Date(timeIntervalSinceNow: 0.08)
        recovery.fireDate = Date(timeIntervalSinceNow: 0.30)
        RunLoop.main.add(mutation, forMode: .default)
        RunLoop.main.add(recovery, forMode: .default)
        defer { mutation.invalidate(); recovery.invalidate() }
"""
suffix = """
        XCTAssertGreaterThan(rows.reads, 0, "The actual XCTest predicate must evaluate the initial source state")
        if fixture != "stable_rejection" {
            let transition = try XCTUnwrap(timeline.events.first { $0["rowsEvaluatedBefore"] != nil })
            XCTAssertGreaterThan(try XCTUnwrap(transition["at"] as? Double) - started, 0.05,
                                 "The explicit original-state transition must occur after its scheduled delay")
            XCTAssertGreaterThan(try XCTUnwrap(transition["rowsEvaluatedBefore"] as? Int), 0,
                                 "The bad state must reenter after at least one actual predicate evaluation")
        }
        let record: [String: Any] = [
            "schema": 1, "fixture": fixture, "events": timeline.events, "rowsReads": rows.reads,
            "loadingAtEnd": ui.control("global-search-loading").exists,
            "finishedAt": Date().timeIntervalSince1970,
            "scope": "Synthetic UI-state boundary with real XCTest predicate/waiter on Linux; no app/UI"
        ]
        XCTAssertFalse(FileManager.default.fileExists(atPath: output))
        try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            .write(to: URL(fileURLWithPath: output), options: .withoutOverwriting)
    }
}
@main
enum RejectionStabilityRunner {
    static func main() {
        XCTMain([testCase([
            ("testVerbatimOriginalRejectionStability", RejectionStabilityTests.testVerbatimOriginalRejectionStability)
        ])])
    }
}
"""
fixtures = ["stable_rejection", "loading_reentry_persistent", "loading_reentry_then_recovers", "original_result_rows_reenter"]
u = pwd.getpwnam("ubuntu")
os.setgid(u.pw_gid); os.setuid(u.pw_uid)
OUT.mkdir(parents=True, exist_ok=False); BUILD.mkdir(parents=True, exist_ok=False)
result = {
    "schema": 1, "scope": "SOURCE_EXTRACTED_XCTEST_PREDICATE_BOUNDARY_NOT_NATIVE_UI",
    "baseCommit": BASE, "sourcePath": TEST, "beforeSHA256": sha(old.encode()), "afterSHA256": sha(new.encode()),
    "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "swiftVersion": subprocess.check_output(["swift", "--version"], text=True).strip(),
    "moduleCache": str(CACHE), "moduleCacheExisted": True,
    "priorAttempt": "validation/attempt-1/RESULT.json; intentionally preserved unexpected immediate-timer fixture",
    "timerCorrection": "Set explicit absolute fireDate for each one-shot control Timer; original test source and 3-second waiter remain unchanged",
    "boundary": "Verbatim original inverted predicate, original 3-second XCTest wait and final assertion block. Explicit mutable UI-state doubles change only loading or retained original result rows after the first real predicate evaluation. Foundation Timer and actual XCTest/Corelibs execute on the main run loop. No application, simulator, native UI, provider, index, corpus, SDK build or UI result is substituted.",
    "appSDKCompiled": 0, "nativeUIExecuted": 0, "physicalExecuted": 0,
    "compiles": [], "extractions": {}, "cases": []
}
for variant, block in blocks.items():
    source = OUT / (variant + ".swift"); source.write_text(prefix + block + suffix)
    assert block in source.read_text()
    result["extractions"][variant] = {"verbatim": True, "blockSHA256": sha(block.encode()), "harnessSHA256": sha(source.read_bytes())}
    executable = BUILD / variant
    command = ["swiftc", "-swift-version", "6", "-parse-as-library", "-module-cache-path", str(CACHE), str(source), "-o", str(executable)]
    compiled = subprocess.run(command, capture_output=True, timeout=45)
    (OUT / (variant + "-compile.stdout")).write_bytes(compiled.stdout)
    (OUT / (variant + "-compile.stderr")).write_bytes(compiled.stderr)
    result["compiles"].append({"variant": variant, "command": command, "exit": compiled.returncode,
                              "stdoutSHA256": sha(compiled.stdout), "stderrSHA256": sha(compiled.stderr)})
    if compiled.returncode:
        result["status"] = "BOUNDARY_HARNESS_COMPILATION_FAILED"
        (OUT / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({"status": result["status"], "result": str(OUT / "RESULT.json"), "stderr": compiled.stderr.decode()}))
        sys.exit(1)
    for fixture in fixtures:
        record = OUT / (variant + "-" + fixture + ".json")
        env = os.environ.copy(); env.update(SEARCH_LOADING_FIXTURE=fixture, SEARCH_LOADING_RECORD=str(record))
        completed = subprocess.run([str(executable)], env=env, capture_output=True, timeout=10)
        (OUT / (variant + "-" + fixture + ".stdout")).write_bytes(completed.stdout)
        (OUT / (variant + "-" + fixture + ".stderr")).write_bytes(completed.stderr)
        cases = re.findall(r"Test Case '([^']+)' (passed|failed)", completed.stdout.decode())
        observations = json.loads(record.read_text()) if record.exists() else None
        accepted = completed.returncode == 0 and len(cases) == 1 and cases[0][1] == "passed"
        rejected = completed.returncode != 0 and len(cases) == 1 and cases[0][1] == "failed"
        expected_accept = fixture == "stable_rejection" or (variant == "baseline" and fixture.startswith("loading_reentry"))
        matched = accepted if expected_accept else rejected
        result["cases"].append({"variant": variant, "fixture": fixture, "exit": completed.returncode,
            "xctestCases": cases, "accepted": accepted, "rejected": rejected, "matchesExpectedOutcome": matched,
            "observation": observations, "stdoutSHA256": sha(completed.stdout), "stderrSHA256": sha(completed.stderr)})
result["summary"] = {
    "baselineLoadingReentriesIncorrectlyAccepted": sum(x["variant"] == "baseline" and x["fixture"].startswith("loading_reentry") and x["accepted"] for x in result["cases"]),
    "candidateLoadingReentriesRejected": sum(x["variant"] == "candidate" and x["fixture"].startswith("loading_reentry") and x["rejected"] for x in result["cases"]),
    "stableRejectionAcceptedBoth": all(x["accepted"] for x in result["cases"] if x["fixture"] == "stable_rejection"),
    "originalResultRowReentryRejectedBoth": all(x["rejected"] for x in result["cases"] if x["fixture"] == "original_result_rows_reenter"),
    "allExpectedOutcomesObserved": all(x["matchesExpectedOutcome"] and x["observation"] is not None for x in result["cases"])
}
assert (TREE / TEST).read_text() == new
result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
result["status"] = "EXPECTED_BASELINE_LOADING_FALSE_ACCEPTANCE_REPRODUCED_CANDIDATE_REJECTS" if result["summary"]["allExpectedOutcomesObserved"] else "UNEXPECTED_BOUNDARY_CONTROL_OUTCOME"
(OUT / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"status": result["status"], "summary": result["summary"], "result": str(OUT / "RESULT.json"), "sha256": sha((OUT / "RESULT.json").read_bytes())}))
sys.exit(0 if result["summary"]["allExpectedOutcomesObserved"] else 1)
