#!/usr/bin/env python3
"""Run original compound-owner guards with explicit portable scene boundaries.

Reuse one already verified Core XCTest build; do not create another package or
module cache. This is not an Apple typecheck, UIKit run, or Native UI receipt.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


COMPOSITION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
BOUNDARY = "Tests/HQ/semantic-journeys/NativeJourneyBoundary.swift"
MARKERS = (
    "fileprivate struct HanlinSourceObservation:",
    "private final class SemanticJourneyOwner {",
    "private struct SemanticJourneyInvocation {",
    "private func validateSemanticJourney(",
    "private func semanticJourneyInvocation(",
    "private func advanceSemanticJourney(",
    "private func advanceSemanticSearchJourney(",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def member(text: str, marker: str) -> str:
    """Extract a whole Swift member; braces inside strings/comments are inert."""
    if text.count(marker) != 1:
        raise ValueError(f"expected exactly one original member: {marker}")
    start = text.index(marker)
    start = text.rfind("\n", 0, start) + 1
    i = text.index("{", text.index(marker))
    depth = 0
    state = "code"
    comment_depth = 0
    while i < len(text):
        pair = text[i:i + 2]
        char = text[i]
        if state == "line":
            if char == "\n":
                state = "code"
        elif state == "comment":
            if pair == "/*":
                comment_depth += 1; i += 1
            elif pair == "*/":
                comment_depth -= 1; i += 1
                if comment_depth == 0:
                    state = "code"
        elif state == "string":
            if char == "\\":
                i += 1
            elif char == '"':
                state = "code"
        elif pair == "//":
            state = "line"; i += 1
        elif pair == "/*":
            state = "comment"; comment_depth = 1; i += 1
        elif char == '"':
            state = "string"
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    raise ValueError(f"unclosed original member: {marker}")


def execute(command: list[str], *, cwd: Path, log: Path, env: dict[str, str], timeout: int) -> dict:
    started = time.monotonic()
    with log.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            else:
                process.kill()
            code = process.wait(timeout=20)
    return {"command": command, "pid": process.pid, "exitCode": code, "timedOut": timed_out,
            "durationSeconds": time.monotonic() - started, "completedAt": now(), "logSHA256": digest(log.read_bytes())}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--core-cache", required=True, type=Path)
    parser.add_argument("--core-evidence", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--swiftc", required=True, type=Path)
    args = parser.parse_args()
    root, output = args.repo.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    original = root / COMPOSITION
    boundary = root / BOUNDARY
    before = {COMPOSITION: digest(original.read_bytes()), BOUNDARY: digest(boundary.read_bytes())}
    core_input = json.loads((args.core_evidence / "INPUTS.json").read_text(encoding="utf-8"))
    core_result = json.loads((args.core_evidence / "RESULT.json").read_text(encoding="utf-8"))
    if not (core_result["exitCode"] == 0 and not core_result["timedOut"] and core_result["sourceUnchanged"]
            and core_result["executed"] > 0 and core_result["failed"] == 0
            and core_result["passed"] == core_result["executed"]):
        raise ValueError("original Core build has no completed passing execution proof")
    for path, expected in core_input["sha256"].items():
        if digest((root / path).read_bytes()) != expected:
            raise ValueError(f"Core input changed since verified build: {path}")
    source = original.read_text(encoding="utf-8-sig")
    members = [member(source, marker) for marker in MARKERS]
    template = boundary.read_text(encoding="utf-8-sig")
    token = "    /* ORIGINAL_COMPOSITION_MEMBERS */"
    if template.count(token) != 1:
        raise ValueError("boundary insertion marker is not unique")
    generated = output / "NativeJourneyOriginalMembers.swift"
    generated.write_text(template.replace(token, "\n\n".join(members)), encoding="utf-8", newline="\n")
    debug = args.core_cache.resolve() / "x86_64-unknown-windows-msvc" / "debug"
    objects = sorted((debug / "OtzariaActionCore.build").glob("*.o"))
    if not objects or not (debug / "Modules" / "OtzariaActionCore.swiftmodule").is_file():
        raise ValueError("verified Core module/objects missing")
    executable = output / "native-journey-host.exe"
    command = [str(args.swiftc), "-swift-version", "6", "-parse-as-library", "-j", "1",
               "-module-cache-path", str(debug / "ModuleCache"), "-I", str(debug / "Modules"),
               str(generated), *map(str, objects), "-o", str(executable)]
    inputs = {"startedAt": now(), "scope": "original composition guard source + actual Core contracts; explicit portable UI boundaries",
              "native": "NOT_RUN", "appleTypecheck": "NOT_RUN", "sourceSHA256": before,
              "coreEvidence": str(args.core_evidence), "coreInputSHA256": digest((args.core_evidence / "INPUTS.json").read_bytes()),
              "coreResultSHA256": digest((args.core_evidence / "RESULT.json").read_bytes()),
              "coreModuleSHA256": digest((debug / "Modules" / "OtzariaActionCore.swiftmodule").read_bytes()),
              "members": [{"marker": marker, "sha256": digest(value.encode("utf-8"))} for marker, value in zip(MARKERS, members)],
              "objects": {str(p): digest(p.read_bytes()) for p in objects}, "generatedSHA256": digest(generated.read_bytes())}
    (output / "INPUTS.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    env = os.environ.copy()
    env["PATH"] = str(args.swiftc.parent) + os.pathsep + env.get("PATH", "")
    compile_result = execute(command, cwd=root, log=output / "compile.log", env=env, timeout=240)
    result = {"compile": compile_result, "executed": 0, "passed": 0, "failed": 0,
              "sourceUnchanged": all(digest((root / p).read_bytes()) == h for p, h in before.items()),
              "scope": "PASS_PORTABLE_ONLY"}
    if compile_result["exitCode"] == 0 and not compile_result["timedOut"]:
        result["runtime"] = execute([str(executable)], cwd=root, log=output / "runtime.log", env=env, timeout=30)
        text = (output / "runtime.log").read_text(encoding="utf-8", errors="replace")
        cases = re.findall(r"^(PASS|FAIL) ([A-Za-z0-9_]+)(?: .*)?$", text, re.M)
        result.update(executed=len(cases), passed=sum(x[0] == "PASS" for x in cases),
                      failed=sum(x[0] == "FAIL" for x in cases), cases=cases,
                      executableSHA256=digest(executable.read_bytes()))
    expected_cases = json.loads((root / "Tests/HQ/semantic-journeys/HOST_CASES.json").read_text(encoding="utf-8"))
    if len(expected_cases) != 40 or len(set(expected_cases)) != 40:
        raise ValueError("host case inventory must contain exactly40 unique names")
    result["caseInventoryExact"] = [x[1] for x in result.get("cases", [])] == expected_cases
    result["success"] = (result["sourceUnchanged"] and result["caseInventoryExact"] and result["executed"] == 40 and result["passed"] == 40
                         and result["failed"] == 0 and result.get("runtime", {}).get("exitCode") == 0
                         and not result.get("runtime", {}).get("timedOut", True))
    if not result["success"]:
        result["scope"] = "FAILED_PORTABLE_FIXTURE"
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
