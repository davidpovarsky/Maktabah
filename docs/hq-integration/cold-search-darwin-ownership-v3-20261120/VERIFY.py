#!/usr/bin/env python3
"""Verify retained v2 failure and v3 fixture-only preservation; no Swift run."""
import argparse
import ast
import gzip
import hashlib
import io
import json
import re
import zipfile
from pathlib import Path


def sha(data):
    return hashlib.sha256(data).hexdigest()


def verify(repo, docs):
    raw = docs / "raw"
    receipts = json.loads((raw / "GITHUB_RECEIPTS.json").read_text())
    run, artifact = receipts["run"], receipts["artifacts"]["artifacts"][0]
    assert run["id"] == 44770208643 and run["run_attempt"] == 1
    assert run["head_sha"] == "96f2b8a34259032c9328d972b8eacbdc94121e81"
    assert run["status"] == "completed" and run["conclusion"] == "failure"
    assert run["head_branch"] == "codex/otzaria-cold-search-ownership-v2-20261120"
    assert artifact["id"] == 14645498790 and artifact["workflow_run"]["id"] == run["id"]
    assert artifact["workflow_run"]["head_sha"] == run["head_sha"]
    jobs = receipts["jobs"]["jobs"]
    assert len(jobs) == 1 and jobs[0]["id"] == 136405525120 and jobs[0]["conclusion"] == "failure"
    archive = (raw / "artifact-14645498790.zip").read_bytes()
    assert len(archive) == artifact["size_in_bytes"] == 1221829
    assert "sha256:" + sha(archive) == artifact["digest"]
    assert sha(archive) == "749005417942333ac26205ed58ed7dc7dc943157dd8adfb775dfab664a6a95a6"
    with zipfile.ZipFile(io.BytesIO(archive)) as outer:
        assert outer.testzip() is None and len(outer.namelist()) == 253
        prefix = "cold-search-ownership/"
        result = json.loads(outer.read(prefix + "RESULT.json"))
        assert json.loads(outer.read(prefix + "source-before.json")) == json.loads(outer.read(prefix + "source-after.json"))
        with zipfile.ZipFile(io.BytesIO(outer.read(prefix + "SOURCE_INPUTS.zip"))) as inputs:
            base = {name: inputs.read(name) for name in inputs.namelist()}
        for name in ["candidate32", "pre-guard1"]:
            stage = result["stages"][name]
            assert stage["compile"]["returncode"] == 0 and not stage["compile"]["timed_out"]
            assert stage["runtime"]["returncode"] == 1 and not stage["runtime"]["timed_out"]
            assert stage["checks"] == json.loads(outer.read(prefix + name + ".CHECKS.json"))
            assert outer.read(prefix + name + ".source-before.json") == outer.read(prefix + name + ".source-after.json")
            for suffix, key in [("compile", "compile"), ("run", "runtime")]:
                assert sha(outer.read(prefix + name + "." + suffix + ".log")) == stage[key]["log_sha256"]
    tree = json.loads(gzip.decompress((raw / "ROOT_GIT_TREE.json.gz").read_bytes()))
    assert tree["sha"] == "57f85214a2ec1fc3591eae58c7a750900c680047" and not tree["truncated"]
    canonical = {row["path"]: row for row in tree["tree"]}
    for path, data in base.items():
        blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        assert canonical[path]["sha"] == blob, path
    manifest_path = "Tests/HQ/cold-search-ownership/OWNERSHIP_INPUTS.json"
    old = json.loads(base[manifest_path])
    manifest = json.loads((repo / manifest_path).read_text())
    assert old["cases"] == manifest["cases"] and len(manifest["cases"]) == 32
    expected_case = "missing_index_is_not_created"
    stage = result["stages"]["candidate32"]
    rows = stage["checks"]["checks"]
    assert [row["id"] for row in rows] == old["cases"]
    assert sum(row["outcome"] == "passed" for row in rows) == 31
    assert [row for row in rows if row["outcome"] != "passed"] == [
        {"id": expected_case, "outcome": "failed", "code": "wrong_or_missing_refusal"}]
    assert {"expected": "filesystem_or_boundary_error,unavailable", "observed": "source_changed"} in stage["checks"]["refusalObservations"]
    observed = next(row for row in stage["checks"]["nativeBoundaryObservations"] if row["id"] == expected_case)
    assert all(observed[key] == "0" for key in ["constructors", "dictionaries", "counts", "closes", "compatibilities"])
    assert result["stages"]["pre-guard1"]["qualified"] is True and stage["qualified"] is False
    driver = base["tools/hq-cold-search-ownership.py"].decode()
    parsed = ast.parse(driver)
    nodes = [node for node in parsed.body if isinstance(node, ast.FunctionDef) and node.name == "qualify"]
    assert len(nodes) == 1
    namespace = {"RED_CASE": old["baseline_case"]}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), "original-qualifier", "exec"), namespace)
    assert namespace["qualify"](result["stages"]["pre-guard1"]["checks"], result["stages"]["pre-guard1"]["runtime"], {old["baseline_case"]: "failed"})
    assert not namespace["qualify"](stage["checks"], stage["runtime"], dict.fromkeys(old["cases"], "passed"))

    path = "Tests/HQ/cold-search-ownership/OwnershipCases.swift"
    cases = (repo / path).read_text()
    start = cases.index("            // Capture the actual missing-path URL before this invocation.")
    end = cases.index('            try await refuses(["filesystem_or_boundary_error", "unavailable"])', start)
    inverse = cases[:start] + cases[end:]
    old_call = 'try await refuses(["filesystem_or_boundary_error", "unavailable"]) { try await source.prepare() }'
    new_call = old_call.replace("source.prepare()", "missing.prepare()")
    assert inverse.count(new_call) == 1
    assert inverse.replace(new_call, old_call).encode() == base[path]
    assert re.findall(r'checks.run\("([^"]+)"', cases) == old["cases"]
    for row in manifest["inputs"]:
        data = (repo / row["path"]).read_bytes()
        assert len(data) == row["bytes"] and sha(data) == row["sha256"]
        assert hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest() == row["git_blob"]
        if row["path"] != path:
            assert data == base[row["path"]], row["path"]
    expected_manifest = json.loads(base[manifest_path])
    expected_manifest["fixture_base_commit"] = run["head_sha"]
    expected_manifest["inputs"] = [next(row for row in manifest["inputs"] if row["path"] == old_row["path"])
                                   if old_row["path"] == path else old_row for old_row in expected_manifest["inputs"]]
    assert manifest == expected_manifest
    workflow = (repo / ".github/workflows/otzaria-cold-search-ownership-validation.yml").read_text()
    workflow_inverse = workflow.replace("codex/otzaria-cold-search-ownership-v3-20261120", "codex/otzaria-cold-search-ownership-v2-20261120").replace(
        sha((repo / manifest_path).read_bytes()), sha(base[manifest_path]))
    assert workflow_inverse.encode() == gzip.decompress((raw / "workflow96f.yml.gz").read_bytes())
    return {"status": "PASS_RETAINED_V2_FAILURE_AND_V3_SOURCE_ONLY",
            "v2_actual": {"preguard_qualified": True, "candidate_passed": 31, "candidate_failed": 1,
                          "observed_missing_refusal": "source_changed", "real_engine": 0, "Native_UI": 0},
            "archive_bytes": len(archive), "archive_sha256": sha(archive), "archive_crc_members": 253,
            "git_bound_v2_inputs": len(base), "same_case_ids": len(old["cases"]),
            "all_other_fixture_and_product_inputs_byte_identical": True,
            "original_case_statements_inverse": "BYTE_IDENTICAL", "v3_swift_execution": "NOT_RUN"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--docs", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = json.dumps(verify(args.repo.resolve(), args.docs.resolve()), indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(report)
    print(report, end="")
