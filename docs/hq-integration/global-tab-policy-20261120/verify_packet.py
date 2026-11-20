#!/usr/bin/env python3
"""Read-only source/selection integrity checks; does not compile or run Swift."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    docs = root / "docs/hq-integration/global-tab-policy-20261120"
    manifest = json.loads((docs / "ARTIFACTS.json").read_text())
    for item in manifest["files"]:
        data = (root / item["path"]).read_bytes()
        assert len(data) == item["bytes"], item["path"]
        assert digest(data) == item["sha256"], item["path"]
        assert blob(data) == item["git_blob"], item["path"]
    proof = json.loads((docs / "INVERSE_PROOF.json").read_text())
    old = gzip.decompress((docs / "raw/iPadLayout.swift.gz").read_bytes())
    new = (root / proof["path"]).read_bytes()
    assert blob(old) == proof["base_blob"]
    assert blob(new) == proof["candidate_blob"]
    change = json.loads((docs / "EXACT_EDIT.json").read_text())
    inverse = new.decode()
    for item in reversed(change["replacements"]):
        assert inverse.count(item["after"]) == 1
        inverse = inverse.replace(item["after"], item["before"], 1)
    assert inverse.encode() == old
    native = json.loads(gzip.decompress((docs / "raw/R27_CASES.json.gz").read_bytes()))
    release = json.loads(gzip.decompress((docs / "raw/runtime27-release-manifest.json.gz").read_bytes()))
    crosswalk = json.loads((docs / "SELECTION_CROSSWALK.json").read_text())
    assert len(native["execution_case_ids"]) == 116
    assert sum(len(c["required_ui_cases"]) for c in release["configurations"]) == 114
    assert sum(len(c.get("required_oracle_cases", [])) for c in release["configurations"]) == 2
    for row in crosswalk["cases"]:
        case_id = row["case_id"]
        assert case_id not in native["execution_case_ids"]
        configs = [{"configuration": c["id"], "device_size": c["device_size"],
                    "array_index": c["required_ui_cases"].index(case_id)}
                   for c in release["configurations"] if case_id in c["required_ui_cases"]]
        assert configs == row["release114_selections"]
        assert len(configs) == 2
    print(json.dumps({"status": "PASS_SOURCE_INVERSE_AND_SELECTION_INTEGRITY_ONLY",
                      "manifested_files": len(manifest["files"]),
                      "whole_file_inverse_exact": True, "native116_case_count": 116,
                      "release114_ui_executions": 114, "release_oracle_executions": 2,
                      "global_navigation_native116_selections": 0,
                      "global_navigation_release114_executions": 4,
                      "swift_parse": "NOT_RUN", "apple_typecheck": "NOT_RUN",
                      "native_executions": 0}, indent=2))


if __name__ == "__main__":
    main()
