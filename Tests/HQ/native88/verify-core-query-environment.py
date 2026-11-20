#!/usr/bin/env python3
"""Exercise the actual matrix environment statement against an authentic mini DB.

The simulator-shaped directory and installation receipt are controlled fixtures.
This is a Windows/native-input integration check, never a Native installation,
engine result, XCTest UI pass or Core permission result.
"""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile

EXPECTED_DB = "d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef"
CANDIDATES = "Tests/HQ/search/canonical-miniTest10-query-candidates.json"
ORACLE = "Scripts/CI/runtime27-fixture-oracle.py"
MATRIX = "Scripts/CI/run-faithful-ipad-matrix.py"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root, database, out = args.root.resolve(), args.database.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    before = digest(database)
    if before != EXPECTED_DB:
        raise ValueError("Requires the original authenticated miniTest10 database")
    source = (root / MATRIX).read_text(encoding="utf-8")
    tree = ast.parse(source)
    statements = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Attribute) and node.value.func.attr == "update"
        and any(isinstance(child, ast.Constant) and child.value == ORACLE
                for child in ast.walk(node))
    ]
    if len(statements) != 1:
        raise ValueError("Expected exactly one actual native fixture environment statement")
    executable = compile(ast.fix_missing_locations(ast.Module(body=statements, type_ignores=[])),
                         str(root / MATRIX), "exec")
    contract = json.loads(subprocess.check_output(
        ["git", "show", "HEAD:docs/hq-integration/runtime27/R27_CASES.json"], cwd=root))
    groups = {value["label"]: value["case_ids"] for value in contract["execution_groups"]}
    candidate_bytes = subprocess.check_output(["git", "show", "HEAD:" + CANDIDATES], cwd=root)
    candidates = json.loads(candidate_bytes)
    if candidates["databaseSHA256"] != before:
        raise ValueError("Candidate evidence does not belong to this database")
    report = {
        "matrix_source_sha256_raw": digest(root / MATRIX),
        "oracle_source_sha256_raw": digest(root / ORACLE),
        "candidate_git_lf_sha256": hashlib.sha256(candidate_bytes).hexdigest(),
        "database_sha256_before": before,
        "native_executed": 0, "apple_typecheck": False, "engine_opened": False,
        "controlled_boundary": "Synthetic installation receipt and owned simulator-shaped temporary directory; no actual simulator claim",
        "actual_code": "Unmodified AST statement from the real matrix runner calling the unmodified original oracle",
        "cases": []
    }
    previous = Path.cwd()
    with tempfile.TemporaryDirectory(prefix="native-query-environment-", dir=out) as folder:
        try:
            temp = Path(folder)
            udid = "00000000-0000-0000-0000-000000000088"
            copied = temp / "Devices" / udid / "data/Containers/owned/seforim.db"
            copied.parent.mkdir(parents=True)
            shutil.copyfile(database, copied)
            for relative, data in [
                (ORACLE, (root / ORACLE).read_bytes()),
                (CANDIDATES, candidate_bytes)
            ]:
                path = temp / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            (temp / "build/artifacts/runtime27").mkdir(parents=True)
            os.chdir(temp)
            for label, needs_query in [("11", True), ("phone", True),
                                       ("11-search", True), ("11-reader", False)]:
                receipt = {
                    "passed": True, "profileID": "miniTest10", "profileVersion": 6,
                    "expectedSHA256": "CONTROLLED_RECEIPT_NOT_NATIVE_INSTALLATION",
                    "actualSHA256": "CONTROLLED_RECEIPT_NOT_NATIVE_INSTALLATION",
                    "shaMatched": True, "quickCheck": "ok", "finalPath": str(copied),
                    "test_boundary": "Synthetic receipt; original authentic DB bytes"
                }
                Path(f"build/artifacts/miniTest10-native-fixture-install-{label}.json").write_text(
                    json.dumps(receipt), encoding="utf-8")
                environment = {}
                scope = {"runpy": runpy, "environment": environment, "selection": groups[label],
                         "udid": udid, "label": label}
                case = {"label": label, "selected_cases": len(groups[label]),
                        "requires_actual_source_query": needs_query}
                try:
                    exec(executable, scope)
                    oracle = json.loads(Path(
                        f"build/artifacts/runtime27/fixture-oracle-{label}.json").read_text())
                    if oracle["database_sha256"] != EXPECTED_DB or oracle["ui_observation_used"] is not False:
                        raise AssertionError("Original independent source evidence was not retained")
                    for key in ("GLOBAL_SEARCH_TEST_QUERY", "GLOBAL_SEARCH_PAGING_QUERY"):
                        if needs_query:
                            if environment.get("TEST_RUNNER_" + key) != candidates["queries"][key]["query"]:
                                raise AssertionError("Missing authenticated environment value: " + key)
                        elif "TEST_RUNNER_" + key in environment:
                            raise AssertionError("Unrelated group unexpectedly changed its oracle scope")
                    if bool(oracle["search_query_source_evidence"]) != needs_query:
                        raise AssertionError("Source query evidence was not propagated with environment")
                    case.update(passed=True, environment_keys=sorted(environment),
                                database_sha256=oracle["database_sha256"],
                                selected_source_identity=oracle["selected"])
                except Exception as error:
                    case.update(passed=False, error=type(error).__name__ + ": " + str(error))
                report["cases"].append(case)
            report["temporary_database_sha256_after"] = digest(copied)
        finally:
            os.chdir(previous)
    report["database_sha256_after"] = digest(database)
    report["original_database_unchanged"] = report["database_sha256_after"] == before
    report["temporary_database_unchanged"] = report.get("temporary_database_sha256_after") == before
    report["passed"] = sum(case["passed"] for case in report["cases"])
    report["failed"] = len(report["cases"]) - report["passed"]
    report["status"] = "PASS" if report["failed"] == 0 and report["original_database_unchanged"] and report["temporary_database_unchanged"] else "FAIL"
    (out / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                     encoding="utf-8", newline="\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "PASS" else 1

if __name__ == "__main__":
    raise SystemExit(main())
