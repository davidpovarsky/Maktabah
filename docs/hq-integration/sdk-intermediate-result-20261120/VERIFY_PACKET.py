#!/usr/bin/env python3
"""Replay the retained SDK packet only; no network, compiler or test execution."""
from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import tempfile


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def main() -> None:
    if not __debug__:
        raise RuntimeError("Run without Python -O: evidence assertions must remain active")
    packet = Path(__file__).resolve().parent
    index = json.loads((packet / "PACKET_INDEX.json").read_bytes())
    assert index["schema"] == "sdk-evidence-packet-v1"
    assert index["run_id"] == 44765034019 and index["native_ui_executed"] == 0
    rows = index["payloads"]
    names = [row["path"] for row in rows]
    assert len(names) == len(set(names))
    actual = {str(path.relative_to(packet)) for path in packet.rglob("*") if path.is_file()}
    assert actual == set(names) | {"PACKET_INDEX.json"}
    for row in rows:
        relative = Path(row["path"])
        assert not relative.is_absolute() and ".." not in relative.parts
        path = packet / relative
        assert not path.is_symlink()
        data = path.read_bytes()
        assert len(data) == row["bytes"] and digest(data) == row["sha256"]
        assert git_blob(data) == row["git_blob"]
        if path.suffix == ".gz":
            original = gzip.decompress(data)
            assert len(original) == row["uncompressed_bytes"]
            assert digest(original) == row["uncompressed_sha256"]
    namespace = {"__name__": "retained_sdk_evidence_verifier"}
    verifier = packet / "VERIFY_SDK_RESULT.py"
    exec(compile(verifier.read_bytes(), str(verifier), "exec"), namespace)
    with tempfile.TemporaryDirectory(prefix="sdk44765034019-evidence-") as scratch:
        base = Path(scratch)
        (base / "artifact-14646210906.zip").write_bytes(
            (packet / "raw/artifact-14646210906.zip").read_bytes())
        for name in ("GITHUB_RECEIPTS.json", "ROOT_GIT_INPUTS.json"):
            (base / name).write_bytes(gzip.decompress((packet / "raw" / (name + ".gz")).read_bytes()))
        observed = namespace["verify"](base)
    assert observed == json.loads((packet / "INDEPENDENT_REVIEW_A.json").read_bytes())
    print(json.dumps({"status": "PACKET_AND_SDK_EVIDENCE_VERIFIED", "payloads": len(rows),
                      "archive_members": 48, "root_git_inputs": 24, "complete_ui_files": 11,
                      "declarations_only": 116, "native_ui_executed": 0,
                      "network_calls": 0, "compiler_or_test_execution": 0}))


if __name__ == "__main__":
    main()
