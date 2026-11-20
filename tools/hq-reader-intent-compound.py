#!/usr/bin/env python3
"""Compile/run original Reader Intent Service/Core XCTest controls on one existing cache.

The Apple-only AppIntent/Composition and native UI have separate gates. Native
ports in the tests are explicit doubles; no synthetic receipt is app evidence.
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

TESTS = {
    "NativeReaderIntentServiceTests": "Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests/NativeReaderIntentServiceTests.swift",
    "NativeReaderCompoundIntentTests": "Source/ChavrusaText/UIRoutingHost/Tests/ChavrusaUIRoutingHostTests/NativeReaderCompoundIntentTests.swift",
}
COMPOSITION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
INVENTORY = "Tests/HQ/semantic-app-intent/CASES.json"

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()

def source_inputs(root: Path) -> dict[str, str]:
    files = {root / COMPOSITION, root / INVENTORY, root / "tools/hq-reader-intent-compound.py"}
    for name in ("Source/Otzaria/Actions", "Source/Otzaria/UIRouting", "Source/ChavrusaText/UIRoutingHost"):
        for path in (root / name).rglob("*"):
            if path.is_file() and not any(p in {".build", "build", ".swiftpm"} for p in path.relative_to(root).parts):
                if path.suffix in {".swift", ".json"}:
                    files.add(path)
    return {path.relative_to(root).as_posix(): sha(path.read_bytes()) for path in sorted(files)}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--swift", type=Path, required=True)
    args = parser.parse_args()
    root, cache, output = args.repo.resolve(), args.cache.resolve(), args.output.resolve()
    if not (cache / "x86_64-unknown-windows-msvc/debug/Modules/OtzariaActionCore.swiftmodule").is_file():
        raise ValueError("reuse the existing original Core cache; no new scratch cache")
    output.mkdir(parents=True, exist_ok=False)
    before = source_inputs(root)
    expected = json.loads((root / INVENTORY).read_text(encoding="utf-8"))
    declared = sorted(f"{name}.{method}" for name, path in TESTS.items()
        for method in re.findall(r"\bfunc (test[A-Za-z0-9_]+)\s*\(", (root / path).read_text(encoding="utf-8")))
    if sorted(expected) != declared or len(set(expected)) != len(expected) or len(expected) != 35:
        raise ValueError("exact original 10 plus new 25 XCTest inventory required")
    command = [str(args.swift), "test", "--package-path", str(root / "Source/ChavrusaText/UIRoutingHost"),
        "--scratch-path", str(cache), "--jobs", "1", "--disable-swift-testing",
        "--filter", "NativeReader(CompoundIntent|IntentService)Tests"]
    inputs = {"startedAt": now(), "command": command, "cwd": str(root), "sha256": before,
        "declaredCases": declared, "scope": "complete original portable Host/Core/Resolver/Policy; explicit native UI doubles",
        "appleTypecheck": "NOT_RUN", "nativeUI": "NOT_RUN", "appIntentsSystemExecution": "NOT_RUN"}
    (output / "INPUTS.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    env = os.environ.copy()
    env["PATH"] = str(args.swift.parent) + os.pathsep + env.get("PATH", "")
    start = time.monotonic()
    with (output / "swift-test.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
        timed_out = False
        try:
            code = process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            timed_out = True
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False)
            code = process.wait(timeout=20)
    raw = (output / "swift-test.log").read_bytes()
    text = raw.decode("utf-8", errors="replace")
    outcomes = re.findall(r"Test Case '([^']+)' (passed|failed)\s*\(", text)
    cases = [{"name": ".".join(name.split(".")[-2:]), "status": status} for name, status in outcomes]
    actual = [case["name"] for case in cases]
    summaries = re.findall(r"Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\)", text)
    result = {"exitCode": code, "timedOut": timed_out, "pid": process.pid,
        "completedAt": now(), "durationSeconds": time.monotonic() - start,
        "executed": len(cases), "passed": sum(c["status"] == "passed" for c in cases),
        "failedCases": sum(c["status"] == "failed" for c in cases), "cases": cases,
        "xctestSummaries": summaries, "logSHA256": sha(raw),
        "sourceUnchanged": source_inputs(root) == before,
        "caseInventoryExact": sorted(actual) == sorted(expected) and len(set(actual)) == len(actual),
        "appleTypecheck": "NOT_RUN", "nativeUI": "NOT_RUN", "appIntentsSystemExecution": "NOT_RUN"}
    executable = cache / "x86_64-unknown-windows-msvc/debug/ChavrusaUIRoutingHostPackageTests.xctest.exe"
    if executable.is_file():
        result["executable"] = {"path": str(executable), "sha256": sha(executable.read_bytes())}
    result["success"] = code == 0 and not timed_out and result["sourceUnchanged"] and result["caseInventoryExact"] and result["passed"] == 35
    result["scope"] = "PASS_PORTABLE_ONLY" if result["success"] else "FAILED_PORTABLE_ATTEMPT"
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result["success"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
