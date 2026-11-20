#!/usr/bin/env python3
"""Replay the sealed source/evidence checks. No Swift, network, or CloudKit."""
from pathlib import Path, PurePosixPath
import ast
import hashlib
import json
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def require(value, message):
    if not value:
        raise AssertionError(message)


def main():
    manifest = json.loads((ROOT / "MANIFEST.json").read_bytes())
    for row in manifest["files"]:
        path = PurePosixPath(row["path"])
        require(not path.is_absolute() and ".." not in path.parts, "unsafe seal path")
        data = (ROOT / row["path"]).read_bytes()
        require(len(data) == row["bytes"] and sha(data) == row["sha256"], row["path"])
    raw = {}
    with tarfile.open(ROOT / "raw-evidence.tar.gz", "r:gz") as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            require(member.isfile() and not path.is_absolute() and ".." not in path.parts, "unsafe raw entry")
            require(member.name not in raw, "duplicate raw entry")
            stream = archive.extractfile(member)
            require(stream is not None, "missing raw stream")
            raw[member.name] = stream.read()
    inventory = json.loads((ROOT / "RAW_INVENTORY.json").read_bytes())
    require(set(raw) == {row["path"] for row in inventory["files"]}, "raw inventory coverage")
    for row in inventory["files"]:
        data = raw[row["path"]]
        require(len(data) == row["bytes"] and sha(data) == row["sha256"], row["path"])
    def read(name):
        return json.loads(raw["evidence/" + name])
    source = read("FINAL_SOURCE_GIT_PROOF.json")
    require(source["source"] == manifest["source"] and source["ci"] == manifest["ci"], "source binding")
    require(len(source["files"]) == 96 and source["core_files"] == 53, "source closure counts")
    for row in source["files"]:
        data = raw["candidate/" + row["path"]]
        require(len(data) == row["bytes"] and sha(data) == row["sha256"] and blob(data) == row["git_blob"], row["path"])
    for row in read("PRIOR_CI_GIT_PROOF.json")["files"]:
        data = raw["prior-ci/" + row["path"]]
        require(blob(data) == row["git_blob"] and sha(data) == row["sha256"], "prior CI blob")
    compilation = read("COMPILE_INPUTS.json")
    require(compilation["source_commit"] == manifest["source"] and compilation["not_later_core194"] is True, "compile source scope")
    for key in ("cloud48_whole_files", "local43_whole_files"):
        require(len(compilation[key]) == 23, key)
        for row in compilation[key]:
            data = raw["candidate/" + row["path"]]
            require(len(data) == row["bytes"] and sha(data) == row["sha256"], row["path"])
    prefix = compilation["cloud48_generated_original_fixture_prefix"]
    data = raw["candidate/" + prefix["source"]].split(prefix["end_marker"].encode(), 1)[0]
    require(len(data) == prefix["bytes"] and sha(data) == prefix["sha256"], "original fixture prefix")
    python = read("python-gate-attempt3-final/RESULT.json")
    require(python["status"] == "PASS" and type(python["tests"]) is int and python["tests"] == 43, "actual Python count")
    require(all(python[k] == 0 for k in ("failures", "errors", "skipped", "swift_executed", "apple_executed")), "Python scope")
    require(python["source_before"] == python["source_after"], "Python source drift")
    for path, row in python["source_after"].items():
        require(sha(raw["candidate/" + path]) == row["sha256"], "Python bound source")
    sql = read("sql-premises-attempt3-current.json")
    require(sql["passed"] == 13 and sql["failed"] == 0 and len(sql["cases"]) == 13, "SQLite result count")
    require(len({row["name"] for row in sql["cases"]}) == 13 and all(row["status"] == "PASS" for row in sql["cases"]), "SQLite names")
    require(sql["source_before"] == sql["source_after"], "SQLite source drift")
    for path, digest in sql["source_after"].items():
        require(sha(raw["candidate/" + path]) == digest, "SQLite bound source")
    require(all(sql[k] == 0 for k in ("swift_executed", "cloudkit_executed", "native_ui_executed")), "SQLite scope")
    old_sql = read("sql-premises-attempt1.json")
    require(old_sql["passed"] == 8 and old_sql["failed"] == 1, "retained SQLite failed attempt")
    inverse = read("SOURCE_PRESERVATION.json")
    require(len(inverse["products"]) == 8 and len(inverse["checks"]) == 9 and all(inverse["checks"].values()), "source preservation report")
    require(sha(raw["evidence/CANDIDATE_SOURCE.patch"]) == inverse["whole_product_patch_sha256"], "product patch")
    for path in inverse["original_files_unchanged"]:
        require(raw["base/" + path] == raw["candidate/" + path], "original source changed: " + path)
    with tempfile.TemporaryDirectory(prefix="cloud-owned-seal-inverse-") as temp:
        work = Path(temp)
        for row in inverse["products"]:
            destination = work / row["path"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw["candidate/" + row["path"]])
        patch = work / "reviewed.patch"
        patch.write_bytes(raw["evidence/CANDIDATE_SOURCE.patch"])
        subprocess.run(["git", "apply", "--reverse", "--check", str(patch)], cwd=work, check=True, capture_output=True)
        subprocess.run(["git", "apply", "--reverse", str(patch)], cwd=work, check=True, capture_output=True)
        for row in inverse["products"]:
            destination = work / row["path"]
            if row["base_sha256"] is None:
                require(not destination.exists(), "added file inverse")
            else:
                require(destination.read_bytes() == raw["base/" + row["path"]], "whole product inverse")
    old_gate = raw["prior-ci/Scripts/CI/local-annotation-editor-apple.py"].decode()
    new_gate = raw["candidate/Scripts/CI/local-annotation-cloud-apple.py"].decode()
    start = '    require(exchange.get("status") == "PASS_ACTUAL_SQLITE_COMPONENT"'
    end = '    return {"local_cases": 43'
    require(old_gate[old_gate.index(start):old_gate.index(end)] in new_gate, "original exchange validator")
    def methods(data):
        return {node.name: node for node in ast.walk(ast.parse(data)) if isinstance(node, ast.FunctionDef) and node.name.startswith("test_")}
    old = methods(raw["prior-ci/Scripts/CI/test-local-annotation-editor-apple.py"])
    new = methods(raw["candidate/Scripts/CI/test-local-annotation-cloud-apple.py"])
    require(len(old) == 32 and len(new) == 43 and set(old) <= set(new), "original Python declarations")
    def assertions(node):
        return [ast.dump(x, include_attributes=False) for x in ast.walk(node) if isinstance(x, ast.Call) and isinstance(x.func, ast.Attribute) and x.func.attr.startswith("assert")]
    for name in old:
        require(all(a in assertions(new[name]) for a in assertions(old[name])), "original Python assertion " + name)
    print(json.dumps({"status": "PASS_SEALED_SOURCE_AND_RECORDED_RESULTS", "source": manifest["source"], "ci": manifest["ci"], "sealed_files": len(manifest["files"]), "raw_streams": len(raw), "git_inputs": 96, "whole_files_each_executable": 23, "product_inverse_files": 8, "actual_python_controls": 43, "actual_sqlite_premises": 13, "swift_rerun": 0, "apple_execution_credit": 0, "live_cloudkit_credit": 0}, sort_keys=True))


if __name__ == "__main__":
    main()
