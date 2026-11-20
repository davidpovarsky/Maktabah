#!/usr/bin/env python3
"""Verify the bounded current-source ledger without modifying historical evidence."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def sha(value):
    return hashlib.sha256(value).hexdigest()

def main():
    ledger = json.loads((HERE / "source-provenance-reconciliation.json").read_text(encoding="utf-8"))
    original = ROOT / ledger["historical_manifest_path"]
    assert sha(original.read_bytes().replace(b"\r\n", b"\n")) == ledger["historical_manifest_lf_sha256"], "Historical manifest changed"
    failures = []
    for row in ledger["rows"]:
        path = ROOT / row["destination"]
        if sha(path.read_bytes().replace(b"\r\n", b"\n")) != row["current_lf_sha256"]:
            failures.append(row["destination"])
        if row.get("subsequent_diff"):
            assert sha(gzip.decompress((HERE / row["subsequent_diff"]).read_bytes())) == row["subsequent_diff_uncompressed_sha256"], "Recorded diff changed"
    assert not failures, "Current source diverged from audited Git objects: " + ", ".join(failures)
    print(json.dumps({
        "result": "PASS", "current_rows": len(ledger["rows"]),
        "historical_rows_still_matching": ledger["matching_rows"],
        "historical_drift_rows_preserved": ledger["drift_rows"],
        "scope": "Exact current source/diff/manifest bytes only; historical gaps, Native and license approvals remain explicit."
    }))

if __name__ == "__main__":
    main()
