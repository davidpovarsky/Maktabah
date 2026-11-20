#!/usr/bin/env python3
"""Verify sealed local-body sources and retained SQL/Python evidence only."""
import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import tempfile


def digest(value): return hashlib.sha256(value).hexdigest()
def blob(value): return hashlib.sha1(b"blob " + str(len(value)).encode() + b"\0" + value).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--replay-inverse", action="store_true")
    args = parser.parse_args()
    folder = Path(__file__).resolve().parent
    manifest = json.loads((folder / "MANIFEST.json").read_bytes())
    for row in manifest["files"]:
        value = (folder / row["path"]).read_bytes()
        assert len(value) == row["bytes"] and digest(value) == row["sha256"], row["path"]
    inventory = json.loads((folder / "RAW_INVENTORY.json").read_bytes())
    archive = (folder / "raw-evidence.tar.gz").read_bytes()
    assert len(archive) == inventory["archive_bytes"] and digest(archive) == inventory["archive_sha256"]
    raw = gzip.decompress(archive)
    assert len(raw) == inventory["tar_bytes"] and digest(raw) == inventory["tar_sha256"]
    expected = {row["path"]: row for row in inventory["files"]}
    assert len(expected) == len(inventory["files"])
    contents = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tar:
        for member in tar:
            name = PurePosixPath(member.name)
            assert member.isfile() and not name.is_absolute() and ".." not in name.parts
            assert member.name in expected and member.name not in contents
            value = tar.extractfile(member).read()
            row = expected[member.name]
            assert len(value) == row["bytes"] and digest(value) == row["sha256"], member.name
            contents[member.name] = value
    assert set(contents) == set(expected)
    base = json.loads(contents["BASE_INPUTS.json"])
    proof = json.loads(contents["evidence/SOURCE_PROOF.json"])
    assert proof == json.loads((folder / "SOURCE_PROOF.json").read_bytes())
    for row in base["files"]:
        value = contents["base/" + row["path"]]
        assert len(value) == row["bytes"] and digest(value) == row["sha256"] and blob(value) == row["blob"]
    for row in proof["candidate_files"]:
        value = contents["candidate/" + row["path"]]
        assert len(value) == row["bytes"] and digest(value) == row["sha256"] and blob(value) == row["blob"]
        if args.repo:
            # Git blobs are canonical LF; a working checkout may be CRLF.
            actual = subprocess.check_output(["git", "show", "HEAD:" + row["path"]], cwd=args.repo)
            assert actual == value, row["path"]
    publication = json.loads(contents["evidence/SOURCE_PUBLICATION.json"])
    assert publication["sourceCommit"] == manifest["source_commit"] == "4be6c9b27fa6c882275cddf209f5959cb9b9690b"
    assert publication["refReadback"]["object"]["sha"] == manifest["source_commit"]
    assert publication["compare"]["total_commits"] == 1 and len(publication["compare"]["files"]) == 11
    sql = json.loads(contents["evidence/sql-attempt2/RESULT.json"])
    assert sql["status"] == "PASS_SQL_STATEMENTS_ONLY" and sql["swift_executed"] == 0
    assert len(sql["checks"]) == 18 and len({x["id"] for x in sql["checks"]}) == 18
    assert all(x["status"] == "PASS" for x in sql["checks"])
    assert sql["source_before"] == sql["source_after"]
    for path, value in sql["source_before"].items(): assert digest(contents["candidate/" + path]) == value
    gate = json.loads(contents["evidence/gate-attempt1/RESULT.json"])
    assert gate["status"] == "PASS" and gate["tests"] == 15
    assert gate["errors"] == gate["failures"] == gate["skipped"] == gate["swift_executed"] == 0
    assert gate["source_before"] == gate["source_after"]
    for path, value in gate["source_before"].items(): assert digest(contents["candidate/" + path]) == value
    assert proof["apple_component_count"] == len(set(proof["apple_component_declarations"])) == 43
    assert proof["apple_cold_reopen_gates"] == 2 and proof["apple_execution"] == "NOT_RUN"
    assert len(proof["originals"]) == 18 and sum(x["unchanged"] for x in proof["originals"]) == 15
    assert len(proof["target_registration"]) == 9 and proof["live_exchange_enabled"] is False
    if args.replay_inverse:
        with tempfile.TemporaryDirectory(prefix="local-annotation-source-inverse-") as temporary:
            root = Path(temporary)
            for name, value in contents.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(value)
            subprocess.run([sys.executable, "evidence/source-proof.py"], cwd=root, check=True, timeout=30)
            replay = json.loads((root / "evidence/SOURCE_PROOF.json").read_bytes())
            assert {k:v for k,v in replay.items() if k != "observed_at"} == {k:v for k,v in proof.items() if k != "observed_at"}
    print(json.dumps({"status": "PASS_SEALED_SOURCE_SQL_PYTHON_ONLY", "raw_members": len(contents),
        "canonical_original_inputs": 18, "candidate_files": 11, "sql_checks": 18,
        "python_gate_controls": 15, "swift_executed": 0, "apple_component_cases_not_run": 43,
        "cold_reopen_gates_not_run": 2, "inverse_replayed": args.replay_inverse}, sort_keys=True))


if __name__ == "__main__":
    main()
