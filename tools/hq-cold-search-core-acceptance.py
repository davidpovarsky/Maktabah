#!/usr/bin/env python3
"""Exact original Core XCTest acceptance; no app, C engine or Native claim.

Runs the independently materialized twenty controls against the original 19b
Executor first, then all 174 original + twenty new tests against the candidate.
Every expected XCTest leaf must actually finish. A compiler failure or timeout
is a setup/execution failure, never the expected baseline RED.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import time
import zipfile

PACKAGE = "Source/Otzaria/Actions"
EXECUTOR = PACKAGE + "/Sources/OtzariaActionCore/Engine/ActionExecutor.swift"
NEW_TEST = PACKAGE + "/Tests/OtzariaActionCoreTests/Engine/ColdSearchExecutionOfflineTests.swift"
FIXTURE = "docs/hq-actions-bridge/embedded-handler-fixtures.json"
INPUTS = "Tests/HQ/cold-search/CORE_INPUTS.json"
WORKFLOW = ".github/workflows/otzaria-annotation-core194-combined-apple-v3.yml"
BRANCH = "refs/heads/codex/otzaria-annotation-core194-combined-apple-v3-20261120"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def save(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def utc() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def safe_file(root: Path, relative: str) -> Path:
    parts = PurePosixPath(relative)
    if (not relative or parts.is_absolute() or ".." in parts.parts or "\\" in relative
            or str(parts) != relative):
        raise ValueError("Noncanonical source path")
    path = root
    for part in parts.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError("Source symlink refused: " + relative)
    if not path.is_file():
        raise ValueError("Source file missing: " + relative)
    return path


def declared_cases(root: Path) -> list[str]:
    result = []
    tests = root / PACKAGE / "Tests/OtzariaActionCoreTests"
    for path in sorted(tests.rglob("*.swift")):
        source = path.read_text(encoding="utf-8")
        methods = re.findall(r"\bfunc\s+(test[A-Za-z0-9_]+)\s*\(", source)
        if not methods:
            continue
        classes = re.findall(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b", source)
        if len(classes) != 1:
            raise ValueError("Ambiguous XCTest declaration owner: " + str(path))
        result.extend(classes[0] + "/" + name for name in methods)
    if len(result) != len(set(result)):
        raise ValueError("Duplicate XCTest declaration")
    return sorted(result)


def verify_inputs(root: Path, manifest: dict) -> list[dict]:
    if manifest.get("schema_version") != 1 or manifest.get("baseline_commit") != "19b68b8b0085a3e44e519835194398486273aaa4":
        raise ValueError("Unexpected source contract")
    originals, added = manifest["original_cases"], manifest["added_cases"]
    if len(originals) != 174 or len(added) != 20 or len(set(originals + added)) != 194:
        raise ValueError("Original/additive declaration contract changed")
    if declared_cases(root) != sorted(originals + added):
        raise ValueError("Actual XCTest declaration inventory differs")
    pass_ids = manifest["baseline_expected_pass"]
    fail_ids = manifest["baseline_expected_fail"]
    if (len(pass_ids) != 11 or len(fail_ids) != 9 or set(pass_ids) & set(fail_ids)
            or sorted(pass_ids + fail_ids) != sorted(added)):
        raise ValueError("Baseline leaf outcomes do not partition the twenty controls")
    core_paths = {row["path"] for row in manifest["core_inputs"]}
    actual = {PACKAGE + "/Package.swift", FIXTURE}
    for directory in ("Sources", "Tests"):
        actual.update(str(path.relative_to(root)).replace(os.sep, "/")
                      for path in (root / PACKAGE / directory).rglob("*") if path.is_file())
    if actual != core_paths:
        raise ValueError("SwiftPM source/resource inventory differs")
    rows = manifest["core_inputs"] + manifest["review_inputs"] + manifest["support_inputs"]
    witnessed = {}
    for row in rows:
        data = safe_file(root, row["path"]).read_bytes()
        actual_row = {"path": row["path"], "bytes": len(data), "sha256": digest(data), "git_blob": blob(data)}
        if any(actual_row[key] != row[key] for key in ("bytes", "sha256", "git_blob")):
            raise ValueError("Source hash changed: " + row["path"])
        if row["path"] in witnessed and witnessed[row["path"]] != actual_row:
            raise ValueError("Conflicting input row")
        witnessed[row["path"]] = actual_row
    old_tests = manifest["original_test_inputs"]
    if len(old_tests) != 12 or {r["path"] for r in old_tests} != {
            p for p in core_paths if "/Tests/" in p and p.endswith(".swift") and p != NEW_TEST}:
        raise ValueError("Original test file inventory changed")
    for row in old_tests:
        if witnessed[row["path"]] != row:
            raise ValueError("An original XCTest source was changed")
    baseline = manifest["baseline_executor"]
    packed = safe_file(root, baseline["gzip_path"]).read_bytes()
    if digest(packed) != baseline["gzip_sha256"]:
        raise ValueError("Baseline executor archive changed")
    raw = gzip.decompress(packed)
    if (len(raw) != baseline["bytes"] or digest(raw) != baseline["sha256"]
            or blob(raw) != baseline["git_blob"]):
        raise ValueError("Original Executor19b bytes changed")
    return sorted(witnessed.values(), key=lambda row: row["path"])


def parse_xctest(text: str) -> dict:
    # Both authentic XCTest renderings are retained; no declaration implies a
    # completed case. Summary lines alone also cannot fabricate a leaf.
    patterns = [
        re.compile(r"^Test Case '-\[(?:\w+\.)?(\w+) (test\w+)\]' (started|passed|failed|skipped)(?: \(([0-9.]+) seconds\))?\.$"),
        re.compile(r"^Test Case '(?:\w+\.)?(\w+)\.(test\w+)' (started|passed|failed|skipped)(?: \(([0-9.]+) seconds\))?\.$"),
    ]
    starts, leaves = [], []
    for line in text.splitlines():
        match = next((match for pattern in patterns if (match := pattern.fullmatch(line.strip()))), None)
        if match:
            case_id = match[1] + "/" + match[2]
            if match[3] == "started":
                starts.append(case_id)
            else:
                leaves.append({"id": case_id, "outcome": match[3], "seconds": float(match[4]) if match[4] else None})
    summaries = re.findall(r"Executed (\d+) tests?, with (\d+) failures? \((\d+) unexpected\)", text)
    return {"starts": starts, "leaves": leaves,
            "final_summary": list(map(int, summaries[-1])) if summaries else None}


def classify_run(process: dict, parsed: dict, expected: dict[str, str]) -> dict:
    leaves = parsed["leaves"]
    ids = [row["id"] for row in leaves]
    outcomes = {row["id"]: row["outcome"] for row in leaves}
    expected_failures = sum(value == "failed" for value in expected.values())
    checks = {
        "process_completed": not process["timed_out"] and process["returncode"] is not None,
        "expected_exit_class": process["returncode"] == (1 if expected_failures else 0),
        "exact_started_once": collections.Counter(parsed["starts"]) == collections.Counter(expected.keys()),
        "exact_completed_once": collections.Counter(ids) == collections.Counter(expected.keys()),
        "exact_leaf_outcomes": outcomes == expected,
        # XCTest failures count assertions, not failed test cases. Require all
        # actual cases and a compatible failure class, without guessing how many
        # assertions the original failing path executes on this toolchain.
        "authentic_summary": bool(parsed["final_summary"] and parsed["final_summary"][0] == len(expected)
                                  and ((parsed["final_summary"][1] > 0 and parsed["final_summary"][2] == 0)
                                       if expected_failures else (parsed["final_summary"][1:] == [0, 0]))),
    }
    return {"checks": checks, "qualified": all(checks.values()), "actual_completed": len(leaves),
            "passed": sum(x["outcome"] == "passed" for x in leaves),
            "failed": sum(x["outcome"] == "failed" for x in leaves),
            "skipped": sum(x["outcome"] == "skipped" for x in leaves), **parsed}


def run_process(command: list[str], cwd: Path, log: Path, timeout: int) -> dict:
    started = utc(); clock = time.monotonic()
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                code = process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                code = process.wait(timeout=10)
    return {"command": command, "cwd": str(cwd), "pid": process.pid, "started_at": started,
            "completed_at": utc(), "elapsed_seconds": time.monotonic() - clock,
            "returncode": code, "timed_out": timed_out, "log_sha256": digest(log.read_bytes())}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=Path("build/cold-search-core-apple"))
    parser.add_argument("--expected-inputs-sha256", required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    root = args.repo.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = {"scope": "ORIGINAL_CORE_XCTEST_WITH_EXPLICIT_PROVIDER_UI_DOUBLES", "started_at": utc(),
              "status": "SETUP_NOT_COMPLETED", "native_ui_executed": 0, "actual_c_engine_executed": 0,
              "windows_orphaned_job": "job_ed394b183ed4", "windows_job_outcome": "UNKNOWN",
              "windows_twenty_source_equivalence": "NOT_VERIFIED", "stages": {}}
    try:
        manifest_data = safe_file(root, INPUTS).read_bytes()
        if digest(manifest_data) != args.expected_inputs_sha256:
            raise ValueError("Pinned input manifest changed")
        manifest = json.loads(manifest_data)
        before = verify_inputs(root, manifest)
        save(output / "source-before.json", before)
        result["inputs_sha256"] = digest(manifest_data)
        result["declared_original"] = 174; result["declared_added"] = 20
        if args.verify_only:
            result["status"] = "PASS_SOURCE_CONTRACT_ONLY"
            result["actual_xctest_completed"] = 0
            return 0
        if sys.platform != "darwin":
            raise ValueError("Actual Apple Foundation/XCTest requires macOS")
        expected_head = os.environ.get("GITHUB_SHA", "")
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True, timeout=20).strip()
        if not re.fullmatch(r"[0-9a-f]{40}", expected_head) or head != expected_head or os.environ.get("GITHUB_REF") != BRANCH:
            raise ValueError("Not the exact authorized validation ref/head")
        result["git_head"] = head
        result["github"] = {key: os.environ.get(key) for key in
                            ("GITHUB_REPOSITORY", "GITHUB_REF", "GITHUB_SHA", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_JOB")}
        if result["github"]["GITHUB_REPOSITORY"] != "davidpovarsky/Maktabah":
            raise ValueError("Unexpected repository")
        for row in before:
            actual_blob = subprocess.check_output(["git", "rev-parse", head + ":" + row["path"]], cwd=root, text=True, timeout=20).strip()
            if actual_blob != row["git_blob"]:
                raise ValueError("Checkout differs from committed source: " + row["path"])
        for relative in (INPUTS, WORKFLOW):
            data = safe_file(root, relative).read_bytes()
            committed = subprocess.check_output(["git", "rev-parse", head + ":" + relative], cwd=root, text=True, timeout=20).strip()
            if committed != blob(data):
                raise ValueError("Validation definition differs from the committed source")
            result[relative] = {"sha256": digest(data), "git_blob": committed}
        for name, command in (("swift", ["xcrun", "swift", "--version"]), ("xcode", ["xcodebuild", "-version"])):
            observed = run_process(command, root, output / (name + "-version.log"), 30)
            result[name + "_identity"] = observed
            if observed["returncode"] != 0 or observed["timed_out"]:
                raise ValueError("Toolchain identity failed")
        with zipfile.ZipFile(output / "SOURCE_INPUTS.zip", "x", compression=zipfile.ZIP_DEFLATED) as archive:
            for relative in sorted({row["path"] for row in before} | {INPUTS, WORKFLOW}):
                archive.write(safe_file(root, relative), relative)
        work = output / "exact-source-work"
        work.mkdir(exist_ok=False)
        for row in manifest["core_inputs"]:
            destination = work / row["path"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / row["path"], destination)
        candidate_executor = (work / EXECUTOR).read_bytes()
        baseline = gzip.decompress((root / manifest["baseline_executor"]["gzip_path"]).read_bytes())
        common = ["xcrun", "swift", "test", "--package-path", str(work / PACKAGE),
                  "--scratch-path", str(output / "swiftpm-cache"), "--jobs", "1", "--disable-swift-testing"]
        expected_red = {case: "passed" for case in manifest["baseline_expected_pass"]}
        expected_red.update({case: "failed" for case in manifest["baseline_expected_fail"]})
        stages = [("baseline20", baseline, common + ["--filter", "ColdSearchExecutionOfflineTests"], expected_red),
                  ("candidate194", candidate_executor, common, {case: "passed" for case in manifest["original_cases"] + manifest["added_cases"]})]
        for name, executor_data, command, expected in stages:
            (work / EXECUTOR).write_bytes(executor_data)
            expected_sources = {row["path"]: row["sha256"] for row in manifest["core_inputs"]}
            expected_sources[EXECUTOR] = digest(executor_data)
            actual_before = {path: digest((work / path).read_bytes()) for path in expected_sources}
            if actual_before != expected_sources:
                raise ValueError("Generated whole-source input differs before " + name)
            save(output / (name + ".source-before.json"), actual_before)
            log = output / (name + ".log")
            process = run_process(command, root, log, 1200)
            parsed = parse_xctest(log.read_text(encoding="utf-8", errors="replace"))
            stage = {"process": process, **classify_run(process, parsed, expected)}
            actual_after = {path: digest((work / path).read_bytes()) for path in expected_sources}
            save(output / (name + ".source-after.json"), actual_after)
            stage["source_unchanged"] = actual_after == actual_before
            stage["qualified"] &= stage["source_unchanged"]
            result["stages"][name] = stage
            save(output / (name + ".result.json"), stage)
            save(output / "RESULT.json", result)
        after = verify_inputs(root, manifest)
        save(output / "source-after.json", after)
        if before != after:
            raise ValueError("Original checkout inputs changed during validation")
        qualified = all(stage["qualified"] for stage in result["stages"].values())
        result["status"] = "PASS_APPLE_CORE_194_WITH_BASELINE20_RED" if qualified else "FAIL_ACTUAL_CORE_ACCEPTANCE"
        result["actual_xctest_completed"] = sum(stage["actual_completed"] for stage in result["stages"].values())
        return 0 if qualified else 1
    except Exception as error:
        result["status"] = "FAIL_SETUP_OR_EXECUTION"
        result["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        result["completed_at"] = utc()
        save(output / "RESULT.json", result)
        print(json.dumps({"status": result["status"], "stages": {name: {key: stage[key] for key in
            ("qualified", "actual_completed", "passed", "failed", "skipped")} for name, stage in result["stages"].items()},
            "native_ui_executed": 0, "actual_c_engine_executed": 0}, sort_keys=True))


if __name__ == "__main__":
    raise SystemExit(main())
