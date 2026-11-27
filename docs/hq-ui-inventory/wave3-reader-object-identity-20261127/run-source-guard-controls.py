#!/usr/bin/env python3
"""Source-extracted XCTest control for two native test guards; not app/UI acceptance."""
import collections, datetime, hashlib, json, os, pathlib, pwd, re, subprocess, sys
ROOT = "/mnt/development/projects/worktrees/Maktabah-wave3-integration-20261127"
WORKTREE = "/mnt/development/projects/worktrees/Maktabah-wave3-reader-object-identity-20261127"
BASE = "a1e12fd377c0909df535c96d1a61f54bef5001a7"
TEST = "Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift"
DOCS = pathlib.Path(WORKTREE) / "docs/hq-ui-inventory/wave3-reader-object-identity-20261127"
OUT = DOCS / "validation" / "attempt-1"
BUILD = pathlib.Path("/mnt/development/projects/diagnostics/otzaria-wave3-reader-object-identity-20261127")
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*args):
    return subprocess.check_output(["runuser", "-u", "ubuntu", "--", "git", "-C", ROOT, *args])
old = git("show", BASE + ":" + TEST).decode()
new = pathlib.Path(WORKTREE, TEST).read_text()
assert sha(old.encode()) == "aa7077b3ba994c3d35aa25c71e8f9986057b140f748774c866af426074da3bf2"
assert sha(new.encode()) == "74d27daf2acf14b3a8fac14eb80f41bb93833b4beaf17eadad4b0a43da043392"
def block(text, start, stop):
    begin = text.index(start); end = text.index(stop, begin) + len(stop)
    return text[begin:end]
demand = block(old, "    private func demand(", "\n    }")
rejected = re.search(r"private struct Rejected: Error \{[^}]+\}", old).group(0)
blocks = {}
for variant, text in [("baseline", old), ("candidate", new)]:
    start = '        try demand(selection["textViewObject"] as? Int' if variant == "baseline" else '        let selectionObject = try XCTUnwrap'
    first = block(text, start, '"Observe one unchanged original TextKit 2 owner")')
    start = '            try demand(UUID(uuidString: request)' if variant == "baseline" else '            let selectionObject = try XCTUnwrap'
    second = block(text, start, '"Use fresh actual native samples from this original Reader/process during the real held gesture")')
    assert text.count(first) == text.count(second) == 1
    blocks[variant] = (first, second)
swift_prefix = """import Foundation
import XCTest

final class IdentityGuardTests: XCTestCase, @unchecked Sendable {
    """ + rejected + "\n" + demand + """
    private func fixture() throws -> ([String: Any], [String: Any]) {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["READER_IDENTITY_FIXTURE_PATH"])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as? [String: Any])
        return (try XCTUnwrap(object["selection"] as? [String: Any]),
                try XCTUnwrap(object["report"] as? [String: Any]))
    }
    func testOriginalFreshRequestOwner() throws {
        let (selection, report) = try fixture()
"""
swift_between = """
    }
    func testOriginalHeldGestureOwner() throws {
        let (selection, report) = try fixture()
        let request = "276BFED7-ACCF-42E9-A8D0-139FF36B25E2"
        let pid = 271127
        var requests = Set<String>()
"""
swift_suffix = """
    }
}
@main
enum IdentityGuardRunner {
    static func main() {
        XCTMain([testCase([
            ("testOriginalFreshRequestOwner", IdentityGuardTests.testOriginalFreshRequestOwner),
            ("testOriginalHeldGestureOwner", IdentityGuardTests.testOriginalHeldGestureOwner)
        ])])
    }
}
"""
fixtures = [
    ("positive_integer", 73191, 73191, False),
    ("negative_integer", -73191, -73191, False),
    ("zero_integer", 0, 0, False),
    ("both_missing", None, None, True),
    ("both_wrong_string_type", "73191", "73191", True),
    ("selection_missing", None, 73191, True),
    ("viewport_missing", 73191, None, True),
    ("different_integers", 73191, 73192, True),
]
u = pwd.getpwnam("ubuntu")
os.setgid(u.pw_gid); os.setuid(u.pw_uid)
OUT.mkdir(parents=True, exist_ok=False)
BUILD.mkdir(parents=True, exist_ok=False)
(OUT / "fixtures").mkdir()
result = {
    "schema": 1, "scope": "PORTABLE_SOURCE_EXTRACTED_XCTEST_GUARD_CONTROL_NOT_APP_OR_UI",
    "baseCommit": BASE, "sourcePath": TEST, "beforeSHA256": sha(old.encode()),
    "afterSHA256": sha(new.encode()), "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "swiftVersion": subprocess.check_output(["swift", "--version"], text=True).strip(),
    "appSDKCompiled": 0, "nativeUIExecuted": 0, "physicalExecuted": 0,
    "boundary": "Only the verbatim two original owner-identity assertion blocks and original demand/Rejected are compiled. Actual XCTest/Corelibs executes them on Linux. Fixture values supply other unchanged request/process/TextKit flags; no app selection, source observer, simulator or gesture is executed.",
    "cases": [], "compiles": [], "extractions": {}
}
for name, selection_object, report_object, invalid in fixtures:
    selection = {"requestID": "276BFED7-ACCF-42E9-A8D0-139FF36B25E2", "processID": 271127,
                 "usesTextKit2BeforeObservation": True, "usesTextKit2AfterObservation": True}
    report = {"usesTextKit2BeforeObservation": True, "usesTextKit2AfterObservation": True}
    if selection_object is not None: selection["textViewObject"] = selection_object
    if report_object is not None: report["object"] = report_object
    (OUT / "fixtures" / (name + ".json")).write_text(json.dumps({"selection": selection, "report": report}, sort_keys=True) + "\n")
for variant, (first, second) in blocks.items():
    source = OUT / (variant + ".swift")
    source.write_text(swift_prefix + first + swift_between + second + swift_suffix)
    assert first in source.read_text() and second in source.read_text()
    result["extractions"][variant] = {"firstBlockSHA256": sha(first.encode()), "secondBlockSHA256": sha(second.encode()), "compiledHarnessSHA256": sha(source.read_bytes()), "verbatimBlocks": True}
    executable = BUILD / variant
    command = ["swiftc", "-swift-version", "6", "-parse-as-library", "-module-cache-path", str(BUILD / "module-cache"), str(source), "-o", str(executable)]
    compiled = subprocess.run(command, capture_output=True)
    (OUT / (variant + "-compile.stdout")).write_bytes(compiled.stdout)
    (OUT / (variant + "-compile.stderr")).write_bytes(compiled.stderr)
    result["compiles"].append({"variant": variant, "command": command, "exit": compiled.returncode,
                              "stdoutSHA256": sha(compiled.stdout), "stderrSHA256": sha(compiled.stderr)})
    if compiled.returncode:
        result["status"] = "COMPILATION_FAILED"
        (OUT / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result)); sys.exit(1)
    for name, _, _, invalid in fixtures:
        env = os.environ.copy(); env["READER_IDENTITY_FIXTURE_PATH"] = str(OUT / "fixtures" / (name + ".json"))
        completed = subprocess.run([str(executable)], env=env, capture_output=True)
        (OUT / (variant + "-" + name + ".stdout")).write_bytes(completed.stdout)
        (OUT / (variant + "-" + name + ".stderr")).write_bytes(completed.stderr)
        outcomes = re.findall(r"Test Case '([^']+)' (passed|failed)", completed.stdout.decode())
        assert len(outcomes) == 2, (variant, name, completed.stdout, completed.stderr)
        accepted = completed.returncode == 0 and all(x[1] == "passed" for x in outcomes)
        rejected_case = completed.returncode != 0 and all(x[1] == "failed" for x in outcomes)
        expected_accept = not invalid or (variant == "baseline" and name in ["both_missing", "both_wrong_string_type"])
        assert (accepted if expected_accept else rejected_case), (variant, name, completed.returncode, outcomes)
        result["cases"].append({"variant": variant, "fixture": name, "invalid": invalid, "exit": completed.returncode,
                                "cases": [{"name": n, "outcome": v} for n, v in outcomes], "accepted": accepted,
                                "rejected": rejected_case, "guardCorrect": accepted != invalid,
                                "stdoutSHA256": sha(completed.stdout), "stderrSHA256": sha(completed.stderr)})
result["summary"] = {
    "candidateValidPayloadsAccepted": sum(r["accepted"] and not r["invalid"] for r in result["cases"] if r["variant"] == "candidate"),
    "candidateInvalidPayloadsRejected": sum(r["rejected"] and r["invalid"] for r in result["cases"] if r["variant"] == "candidate"),
    "baselineInvalidPayloadsIncorrectlyAccepted": sum(r["accepted"] and r["invalid"] for r in result["cases"] if r["variant"] == "baseline"),
    "xctestCasesPerPayload": 2,
    "candidateGuardContractPasses": all(r["guardCorrect"] for r in result["cases"] if r["variant"] == "candidate"),
    "baselineGuardContractFails": any(not r["guardCorrect"] for r in result["cases"] if r["variant"] == "baseline")
}
assert pathlib.Path(WORKTREE, TEST).read_text() == new
result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
result["status"] = "EXPECTED_BASELINE_FALSE_ACCEPTANCE_REPRODUCED_CANDIDATE_REJECTS"
(OUT / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"status": result["status"], "summary": result["summary"], "result": str(OUT / "RESULT.json"), "sha256": sha((OUT / "RESULT.json").read_bytes())}))
