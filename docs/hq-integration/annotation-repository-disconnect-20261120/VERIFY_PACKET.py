#!/usr/bin/env python3
"""Verify sealed local source/evidence payloads; no Swift or CI execution."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json

DOCS = "docs/hq-integration/annotation-repository-disconnect-20261120"


def record(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    index = json.loads((root / DOCS / "PACKET_INDEX.json").read_bytes())
    if index["source_M"] != "939eaf3a5b56fe604354b235579cf7aa4a60e3d4":
        raise ValueError("Wrong repaired source")
    for relative, expected in index["files"].items():
        path = root / relative
        if not path.is_file() or path.is_symlink() or root not in path.resolve().parents:
            raise ValueError("Missing or unsafe payload: " + relative)
        data = path.read_bytes()
        if record(data) != {key: expected[key] for key in ("bytes", "sha256", "git_blob")}:
            raise ValueError("Changed payload: " + relative)
        if "uncompressed" in expected and record(gzip.decompress(data)) != expected["uncompressed"]:
            raise ValueError("Changed compressed raw input: " + relative)
    source = index["published_source3"]
    for relative, expected in source.items():
        if record((root / relative).read_bytes()) != expected:
            raise ValueError("Published source M changed: " + relative)
    print(json.dumps({"status": "PASS_PACKET_HASHES_ONLY", "payloads": len(index["files"]),
                      "source_M": index["source_M"], "python_controls": index["executed_local_controls"],
                      "local_whole_git_source_gate": "NOT_RUN", "swift_executed": 0,
                      "native_ui_executed": 0}, sort_keys=True))


if __name__ == "__main__":
    main()
