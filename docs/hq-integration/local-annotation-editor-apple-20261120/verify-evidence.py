#!/usr/bin/env python3
"""Verify this sealed preparation packet; optional replay is Python only."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check_record(data, expected, label):
    require(len(data) == expected["bytes"] and sha(data) == expected["sha256"], "Digest/length mismatch: " + label)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--replay-controls", action="store_true")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "MANIFEST.json").read_bytes())
    for name, expected in manifest["files"].items():
        require(Path(name).name == name, "Unsafe sealed file")
        check_record((ROOT / name).read_bytes(), expected, name)
    inventory = json.loads((ROOT / "RAW_INVENTORY.json").read_bytes())
    check_record((ROOT / inventory["archive"]["name"]).read_bytes(), inventory["archive"], "raw archive")
    raw = {}
    with tarfile.open(ROOT / inventory["archive"]["name"], "r:gz") as archive:
        for item in archive.getmembers():
            name = item.name
            require(item.isfile() and name not in raw and not name.startswith("/")
                    and name == str(PurePosixPath(name)) and ".." not in PurePosixPath(name).parts,
                    "Unsafe/duplicate raw member")
            require(name in inventory["files"] and item.size <= 2_000_000, "Unexpected raw member/size")
            data = archive.extractfile(item).read()
            check_record(data, inventory["files"][name], name)
            raw[name] = data
    require(set(raw) == set(inventory["files"]), "Missing raw member")
    proof = json.loads((ROOT / "SOURCE_PROOF.json").read_bytes())
    require(proof["ci_source_commit"] == "6cd53aae3dbf6b443ab74ad6eff926e8ea529338"
            and proof["apple_swift_executed"] == 0 and proof["activation_or_dispatch"] is False,
            "Wrong preparation scope")
    for row in proof["ci_added_files"]:
        check_record(raw["sources/" + row["path"]], row, row["path"])
    for name, expected in proof["original_pinned_inputs"].items():
        check_record(raw["sources/" + name], expected, name)
    result = json.loads(raw["evidence/python-attempt2/RESULT.json"])
    require(result["status"] == "PASS" and result["tests"] == 28
            and result["failures"] == result["errors"] == result["skipped"] == 0
            and result["swift_executed"] == result["apple_executed"] == 0
            and result["source_before"] == result["source_after"], "Actual Python control result mismatch")
    for name, expected in result["source_before"].items():
        check_record(raw["sources/" + name], expected, name)
    first = json.loads(raw["evidence/python-attempt1/RESULT.json"])
    require(first["status"] == "PASS" and first["tests"] == 27
            and first["source_before"] == first["source_after"], "Original first attempt differs")
    for name, expected in first["source_before"].items():
        retained = "evidence/python-attempt1/source/" + name
        check_record(raw[retained if retained in raw else "sources/" + name], expected, "first attempt " + name)
    log = raw["evidence/python-attempt2.log"].decode("utf-8")
    names = re.findall(r"^(test_[^\n]+) \.\.\. ok$", log, re.MULTILINE)
    require(len(names) == len(set(names)) == 28 and "\nOK\n" in log, "Actual named control log mismatch")
    tree = json.loads(raw["provenance/CORE_TREE.json"])
    require(tree["sha"] == "5d0ee482c8f10726fe3863792dac94c18e94d792"
            and tree["truncated"] is False and sum(row["type"] == "blob" for row in tree["tree"]) == 53,
            "Original Core Git inventory mismatch")
    replay = "NOT_RUN"
    if args.replay_controls:
        with tempfile.TemporaryDirectory(prefix="local-annotation-apple-proof-owned-") as directory:
            root = Path(directory)
            for name, data in raw.items():
                if name.startswith("sources/"):
                    path = root / name.removeprefix("sources/")
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(data)
            execution = subprocess.run([sys.executable, str(root / "Scripts/CI/test-local-annotation-editor-apple.py"),
                "--artifacts-dir", str(root / "replay")], cwd=root, capture_output=True, text=True, timeout=90)
            require(execution.returncode == 0, "Python-only replay failed: " + execution.stdout + execution.stderr)
            replay_result = json.loads((root / "replay/RESULT.json").read_bytes())
            require(replay_result["status"] == "PASS" and replay_result["tests"] == 28
                    and replay_result["source_before"] == result["source_before"]
                    and replay_result["source_after"] == result["source_after"], "Replay source/result differs")
            replay = "PASS_PYTHON_28"
    print(json.dumps({"status": "VERIFIED_PREPARATION_ONLY", "sealed_files": len(manifest["files"]),
                      "raw_files": len(raw), "actual_python": 28, "replay": replay,
                      "swift_executed": 0, "apple_executed": 0, "activation_or_dispatch": False}, sort_keys=True))


if __name__ == "__main__":
    main()
