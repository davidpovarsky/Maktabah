#!/usr/bin/env python3
"""Verify the exact disjoint History/groups source integration; runs no Swift or Native."""
from pathlib import Path
import gzip
import hashlib
import json
import subprocess
import sys
import tempfile

PACKET = Path(__file__).resolve().parent
REPO = PACKET.parents[2]
GROUPS = PACKET.parent / "native98-groups-snapshot-20261120"
def unpack(root, name):
    return gzip.decompress((root / "raw" / name).read_bytes())
def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

receipt = json.loads((PACKET / "ROOT_INTEGRATION_REVIEW.json").read_text())
baseline = unpack(PACKET, "Faithful.baseline.swift.gz")
assert baseline == unpack(GROUPS, "Faithful.baseline.swift.gz")
history = unpack(PACKET, "Faithful.candidate.swift.gz")
groups = unpack(GROUPS, "Faithful.candidate.swift.gz")
combined_path = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift"
combined = combined_path.read_bytes()
assert len(combined) == receipt["combined"]["bytes"]
assert hashlib.sha256(combined).hexdigest() == receipt["combined"]["sha256"]
assert blob(combined) == receipt["combined"]["git_blob"]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for name, data in [("baseline", baseline), ("history", history), ("groups", groups), ("combined", combined)]:
        (root / name).write_bytes(data)
    def merge(left, base, right):
        process = subprocess.run(["git", "merge-file", "-p", str(root / left), str(root / base), str(root / right)], capture_output=True, timeout=30)
        assert process.returncode == 0, process.stderr.decode(errors="replace")
        return process.stdout
    assert merge("groups", "baseline", "history") == combined
    assert merge("history", "baseline", "groups") == combined
    assert merge("combined", "history", "baseline") == groups
    assert merge("combined", "groups", "baseline") == history
inverse = combined.decode()
for change in reversed(json.loads((PACKET / "CHANGE_MAP.json").read_text())):
    assert inverse.count(change["new"]) == 1
    inverse = inverse.replace(change["new"], change["old"])
assert inverse.encode() == groups
print(json.dumps({"status": "EXACT_SOURCE_INTEGRATION_VERIFIED", "commutative": True, "both_inverses_exact": True, "Swift_executed": 0, "Native_executed": 0}))
