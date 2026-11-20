#!/usr/bin/env python3
"""Verify sealed local evidence and new processor inputs; does not run/download CI."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("--root", type=Path, required=True)
args = p.parse_args()
root = args.root.resolve()
doc = Path(__file__).resolve().parent
manifest = json.loads((doc / "ARTIFACTS.json").read_bytes())
for entry in manifest["files"]:
    path = root / entry["path"]
    assert path.is_file() and not path.is_symlink(), entry["path"]
    data = path.read_bytes()
    assert len(data) == entry["bytes"] and hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"]
    if "uncompressedSha256" in entry:
        raw = gzip.decompress(data)
        assert len(raw) == entry["uncompressedBytes"] and hashlib.sha256(raw).hexdigest() == entry["uncompressedSha256"], entry["path"]
controls = (doc / "python-controls-final.log").read_text()
assert "Ran 40 tests" in controls and controls.rstrip().endswith("OK")
actual = json.loads((doc / "ACTUAL_METADATA_CONTROL.json").read_bytes())
assert actual["passed"] and actual["actualArchiveHashVerified"] is False
assert actual["sourceRunConclusion"] == actual["sourceJobConclusion"] == "cancelled"
contract = json.loads((root / "Scripts/CI/native98-commentary-evidence.json").read_bytes())
assert contract["sourceArtifact"]["id"] == 14632274701
assert len(contract["selectedMembers"]) == 3
print(json.dumps({"sealedFilesVerified": len(manifest["files"]), "pythonControls": "40 PASS, synthetic only",
                  "authenticMetadataChecked": True, "largeArchiveVerified": False,
                  "nativeExecutions": 0, "activationPerformed": False}, sort_keys=True))
