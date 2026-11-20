#!/usr/bin/env python3
"""Verify retained bytes and executed portable outcomes; this does not run Swift or Native."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

PREFIX = "docs/hq-integration/semantic-app-intent-20261120"
def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def member(text: str, marker: str) -> str:
    assert text.count(marker) == 1, marker
    start = text.rfind("\n", 0, text.index(marker)) + 1
    index = text.index("{", text.index(marker)); depth = 0; state = "code"; comments = 0
    while index < len(text):
        pair, char = text[index:index + 2], text[index]
        if state == "line":
            if char == "\n": state = "code"
        elif state == "comment":
            if pair == "/*": comments += 1; index += 1
            elif pair == "*/":
                comments -= 1; index += 1
                if comments == 0: state = "code"
        elif state == "string":
            if char == "\\": index += 1
            elif char == '"': state = "code"
        elif pair == "//": state = "line"; index += 1
        elif pair == "/*": state = "comment"; comments = 1; index += 1
        elif char == '"': state = "string"
        elif char == "{": depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0: return text[start:index + 1]
        index += 1
    raise AssertionError(marker)

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-ref", help="read every sealed/repository input from this immutable Git object")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    def read(path: str) -> bytes:
        value = PurePosixPath(path)
        assert not value.is_absolute() and ".." not in value.parts and str(value) == path
        if args.git_ref:
            return subprocess.check_output(["git", "show", args.git_ref + ":" + path], cwd=root)
        return (root / path).read_bytes()
    def doc(name: str) -> bytes: return read(PREFIX + "/" + name)
    def json_doc(name: str): return json.loads(doc(name))
    seal = json_doc("SEAL.json")
    assert len(seal["files"]) == len(set(seal["files"]))
    for name, item in seal["files"].items():
        value = doc(name)
        assert len(value) == item["bytes"] and sha(value) == item["sha256"], name
    manifest = json_doc("RAW_MANIFEST.json")
    assert len(manifest) == len({item["path"] for item in manifest})
    raw = {}
    for item in manifest:
        compressed = doc(item["path"])
        assert sha(compressed) == item["gzipSHA256"]
        value = gzip.decompress(compressed)
        assert sha(value) == item["sha256"] and len(value) == item["bytes"], item["path"]
        raw[item["key"]] = value
    def rj(key): return json.loads(raw[key])
    inputs = json_doc("SOURCE_INPUTS.json")
    for path, item in inputs.items():
        assert sha(raw["source/" + path]) == item["rawSHA256"], path
        assert sha(read(path).replace(b"\r\n", b"\n")) == item["gitLF_SHA256"], path

    inventory = json.loads(read("Tests/HQ/semantic-app-intent/CASES.json"))
    assert len(inventory) == len(set(inventory)) == 35
    for attempt, passed, failed, exit_code in [
        ("host-red-attempt1", 33, 2, 1),
        ("host-green-attempt1", 35, 0, 0),
        ("host-final-attempt2", 35, 0, 0),
    ]:
        result = rj("run/" + attempt + "/RESULT.json")
        captured = rj("run/" + attempt + "/INPUTS.json")
        log = raw["run/" + attempt + "/swift-test.log"]
        assert result["executed"] == 35 and result["passed"] == passed and result["failedCases"] == failed
        assert result["exitCode"] == exit_code and not result["timedOut"]
        assert result["sourceUnchanged"] and result["caseInventoryExact"] and sha(log) == result["logSHA256"]
        assert [item["name"] for item in result["cases"]] == inventory
        assert sum(item["status"] == "passed" for item in result["cases"]) == passed
        assert result["nativeUI"] == result["appleTypecheck"] == result["appIntentsSystemExecution"] == "NOT_RUN"
        assert len(re.findall(rb"^Test Case .* (?:passed|failed) \(", log, re.M)) == 35
        if attempt == "host-final-attempt2":
            for path, expected in captured["sha256"].items():
                assert inputs[path]["rawSHA256"] == expected
    test_path = "Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests/NativeReaderCompoundIntentTests.swift"
    assert len({rj("run/" + attempt + "/INPUTS.json")["sha256"][test_path]
                for attempt in ["host-red-attempt1", "host-green-attempt1", "host-final-attempt2"]}) == 1

    old_host = rj("run/host-factory-baseline/HOST_CASES.json")
    host_cases = json.loads(read("Tests/HQ/semantic-journeys/HOST_CASES.json"))
    assert len(old_host) == 60 and host_cases[:60] == old_host
    assert len(host_cases) == len(set(host_cases)) == 102
    compile_failure = rj("run/host-factory-attempt2/RESULT.json")
    assert compile_failure["executed"] == 0 and compile_failure["compile"]["exitCode"] == 1
    assert b"initializer is inaccessible" in raw["run/host-factory-attempt2/compile.log"]
    for attempt, passed, failed in [("host-factory-attempt3", 101, 1), ("host-factory-attempt4", 102, 0)]:
        result = rj("run/" + attempt + "/RESULT.json")
        assert result["compile"]["exitCode"] == 0 and not result["compile"]["timedOut"]
        assert result["executed"] == 102 and result["passed"] == passed and result["failed"] == failed
        assert result["sourceUnchanged"] and result["caseInventoryExact"]
        assert [item[1] for item in result["cases"]] == host_cases
        assert sha(raw["run/" + attempt + "/compile.log"]) == result["compile"]["logSHA256"]
        assert sha(raw["run/" + attempt + "/runtime.log"]) == result["runtime"]["logSHA256"]
    result = rj("run/host-factory-attempt4/RESULT.json")
    assert result["success"] and result["runtime"]["exitCode"] == 0 and not result["runtime"]["timedOut"]
    host_inputs = rj("run/host-factory-attempt4/INPUTS.json")
    original = raw["source/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"].decode("utf-8-sig")
    generated = raw["run/host-factory-attempt4/NativeJourneyOriginalMembers.swift"].decode()
    markers = {item["marker"] for item in host_inputs["members"]}
    assert {"private func semanticJourneys(manager:", "private func semanticJourneys(owner:",
            "private func validateReaderIntentJourneyOwner("} <= markers
    for item in host_inputs["members"]:
        actual = member(original, item["marker"])
        assert sha(actual.encode()) == item["sha256"] and actual in generated
    for path, expected in host_inputs["sourceSHA256"].items():
        assert inputs[path]["rawSHA256"] == expected
    assert sha(generated.encode()) == host_inputs["generatedSHA256"]

    preservation = json_doc("PRESERVATION.json")
    assert preservation["nativeWholeFileExactInverse"]
    assert preservation["factoryOriginalBodyPreservedExceptPublicFailureContract"]
    assert preservation["original10ServiceTestsByteIdentical"] and preservation["original60HostCaseNamesInSameOrder"]
    assert not preservation["protectedDiff"] and preservation["nativeExecutions"] == 0
    for path, expected in preservation["protectedGitTrees"].items():
        if args.git_ref:
            actual = subprocess.check_output(["git", "ls-tree", args.git_ref, "--", path], cwd=root).decode().strip()
            assert actual == expected, path
    setup = rj("run/NATIVE_COUNT_SETUP_CORRECTION.json")
    assert setup["wholeFileTwoLabelInverse"] and len(setup["checks"]) == 2
    assert all(item["exactInverse"] for item in setup["checks"])
    syntax = rj("run/SYNTAX_ONLY.json") + rj("run/NATIVE_COUNT_SETUP_SYNTAX_ONLY.json")
    assert len(syntax) == 8 and all(item["exitCode"] == 0 for item in syntax)
    summary = json_doc("RESULTS.json")
    assert summary["nativeExecuted"] == 0 and summary["appleTypecheck"] == summary["siriShortcutsSystemUI"] == "NOT_RUN"
    print(json.dumps({"verifiedFiles": len(seal["files"]), "rawEntries": len(manifest), "sourceInputs": len(inputs),
                      "serviceExecuted": 35, "servicePassed": 35, "hostExecuted": 102, "hostPassed": 102,
                      "originalServiceTests": 10, "originalHostControls": 60, "nativeExecuted": 0,
                      "appleTypecheck": "NOT_RUN", "scope": "SEALED_BYTES_AND_PORTABLE_EVIDENCE_ONLY"}, indent=2))

if __name__ == "__main__":
    main()
