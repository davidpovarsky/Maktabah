#!/usr/bin/env python3
"""Verify sealed bytes, actual XCTest/Host cases, and immutable source binding."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    repo = args.repo or root.parents[2]
    manifest = json.loads((root / "SHA256SUMS.json").read_text(encoding="utf-8"))
    for path, item in manifest.items():
        data = (root / path).read_bytes()
        assert len(data) == item["bytes"] and sha(data) == item["sha256"], path
        if item.get("rawSHA256"):
            assert sha(gzip.decompress(data)) == item["rawSHA256"], path + " uncompressed"
    evidence = json.loads((root / "EVIDENCE.json").read_text(encoding="utf-8"))

    def read(path):
        return gzip.decompress((root / "raw" / (path + ".gz")).read_bytes())

    for attempt in evidence["coreAttempts"]:
        result = json.loads(read(attempt["name"] + "/RESULT.json"))
        text = read(attempt["name"] + "/test.log").decode("utf-8", errors="replace")
        actual = re.findall(r"Test Case '([^']+)' (passed|failed) \(", text)
        assert actual == [tuple(x) for x in result["cases"]], attempt["name"]
        assert len(actual) == attempt["completed"] == result["executed"]
        assert sum(x[1] == "passed" for x in actual) == attempt["passed"] == result["passed"]
        assert sum(x[1] == "failed" for x in actual) == attempt["failedCompleted"] == result["failed"]
        assert result["sourceUnchanged"] and not result["timedOut"]
        assert sha(read(attempt["name"] + "/test.log")) == result["logSHA256"]
    green = json.loads(read("candidate-core-attempt5-green/RESULT.json"))
    assert green["exitCode"] == 0 and green["executed"] == green["passed"] == 174
    assert len({x[0] for x in green["cases"]}) == 174
    preservation = json.loads(read("PRESERVATION.json"))
    assert len(preservation["originalCaseNames"]) == 137
    assert set(preservation["originalCaseNames"]) <= {x[0] for x in green["cases"] if x[1] == "passed"}
    red = json.loads(read("candidate-core-attempt4-lifetime-red/RESULT.json"))
    assert {x[0] for x in red["cases"] if x[1] == "failed"} == set(evidence["lifetimeRedCases"])
    host_results = {}
    for attempt in evidence["hostAttempts"]:
        name = attempt["name"]
        host = json.loads(read(name + "/RESULT.json"))
        # Match the original driver's universal-newline text read, while hashes
        # above still verify every original Windows byte including CRLF.
        host_text = read(name + "/runtime.log").decode("utf-8").replace("\r\n", "\n")
        host_cases = re.findall(r"^(PASS|FAIL) ([A-Za-z0-9_]+)(?: .*)?$", host_text, re.M)
        assert host_cases == [tuple(x) for x in host["cases"]]
        assert host["sourceUnchanged"] and host["caseInventoryExact"]
        assert host["compile"]["exitCode"] == 0 and not host["compile"]["timedOut"]
        assert len(host_cases) == len({x[1] for x in host_cases}) == host["executed"] == attempt["completed"]
        assert sum(x[0] == "PASS" for x in host_cases) == host["passed"] == attempt["passed"]
        assert sum(x[0] == "FAIL" for x in host_cases) == host["failed"] == attempt["failed"]
        assert host["success"] == (attempt["failed"] == 0)
        assert host["runtime"]["exitCode"] == (0 if host["success"] else 1)
        assert not host["runtime"]["timedOut"]
        assert sha(read(name + "/runtime.log")) == host["runtime"]["logSHA256"]
        assert sha(read(name + "/compile.log")) == host["compile"]["logSHA256"]
        host_results[name] = host
    original_host = host_results["host-attempt1"]
    host_red = host_results["host-attempt2-projection-red"]
    host_green = host_results["host-attempt3-projection-green"]
    assert {x[1] for x in host_red["cases"] if x[0] == "FAIL"} == set(evidence["projectionRedCases"])
    assert {x[1] for x in original_host["cases"]} <= {x[1] for x in host_green["cases"] if x[0] == "PASS"}
    assert [x[1] for x in host_red["cases"]] == [x[1] for x in host_green["cases"]]
    assert host_green["executed"] == host_green["passed"] == 60
    source = json.loads(read("SOURCE_BINDING.json"))
    assert source["sourceCommit"] == evidence["sourceCommit"]
    core_inputs = json.loads(read("candidate-core-attempt5-green/INPUTS.json"))["sha256"]
    host_inputs = json.loads(read("host-attempt3-projection-green/INPUTS.json"))["sourceSHA256"]
    for path, expected in {**core_inputs, **host_inputs}.items():
        assert source["inputs"][path]["workingSHA256"] == expected, path
    for path, item in source["inputs"].items():
        blob = subprocess.check_output(["git", "show", evidence["sourceCommit"] + ":" + path], cwd=repo)
        assert sha(blob) == item["gitBlobSHA256"], path
        assert item["normalizedWorkingBytesEqualGitBlob"], path
    red_composition = read("host-attempt2-projection-red/ORIGINAL_COMPOSITION.swift")
    old_blob = subprocess.check_output(["git", "show", evidence["intermediateSourceCommit"] +
        ":Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"], cwd=repo)
    assert red_composition.replace(b"\r\n", b"\n") == old_blob
    assert evidence["nativeCompound"] == evidence["appleTypecheck"] == "NOT_RUN"
    print(json.dumps({"status": "PASS_EVIDENCE_VERIFICATION_ONLY", "sourceCommit": evidence["sourceCommit"],
                      "sealedFiles": len(manifest), "corePassed": 174, "originalCorePreserved": 137,
                      "hostPassed": 60, "originalHostPreserved": 40,
                      "hostProjectionRed": {"passed": 42, "failed": 18},
                      "nativeCompound": "NOT_RUN", "appleTypecheck": "NOT_RUN"}, indent=2))


if __name__ == "__main__":
    main()
