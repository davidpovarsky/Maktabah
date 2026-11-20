#!/usr/bin/env python3
"""Read-only, offline verification of this exact source-provenance reconciliation."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess

TARGET = "0f5111e8f8e379e17da558ddbe2aab5214ac0315"
UPSTREAM = "d46af139b3a265399c16d87f5923acd8e3444024"
BASE = "a0ed0df908a6cb38bc459d4baaeb400f447b2fc4"
HISTORICAL = "dd7b1eb5119544ed28c12d1ea4a3653dddce9842"
ADAPTER = "Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift"
EXPECTED_OLD = "d4f5c45680c8cf72001a0a0d83b5e62a97368dbc68b6ea229985028cf86ae66a"


def digest(value):
    return hashlib.sha256(value).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    evidence = Path(__file__).resolve().parent
    checks = []

    def require(name, condition):
        if not condition:
            raise AssertionError(name)
        checks.append(name)

    def git(*parts):
        return subprocess.run(["git", "-C", str(args.repo), *parts], capture_output=True, check=False)

    def value(*parts):
        p = git(*parts)
        if p.returncode:
            raise RuntimeError(p.stderr.decode("utf-8", errors="replace"))
        return p.stdout

    def blob(revision, path):
        return value("show", revision + ":" + path)

    inventory = json.loads((evidence / "CURRENT_32_ROW_RECONCILIATION.json").read_text(encoding="utf-8"))
    require("exact_target", inventory["target_source"] == TARGET)
    rows = inventory["rows"]
    require("exact_unique_32_origin_records", len(rows) == len({(r["repository_declared"], r["original_declared"], r["destination"]) for r in rows}) == 32)
    require("exact_28_destination_paths", len({r["destination"] for r in rows}) == 28)
    require("historical_manifest_unchanged", digest(blob(TARGET, inventory["manifest_path"])) == inventory["manifest_git_sha256"])
    require("historical_audit_unchanged", digest(blob(TARGET, inventory["prior_audit_path"])) == inventory["prior_audit_git_sha256"])
    original_manifest_bytes = blob(TARGET, inventory["manifest_path"])
    original_manifest_rows = {(r["repo"], r["original"], r["destination"]): r for r in json.loads(original_manifest_bytes)}
    require("retained_manifest_copy_exact", gzip.decompress((evidence / "HISTORICAL_PORT_LEDGER.git-lf.json.gz").read_bytes()) == original_manifest_bytes)
    require("retained_prior_audit_copy_exact", gzip.decompress((evidence / "PRIOR_RECONCILIATION.git-lf.json.gz").read_bytes()) == blob(TARGET, inventory["prior_audit_path"]))
    for row in rows:
        path = row["destination"]
        identity = (row["repository_declared"], row["original_declared"], path)
        label = " | ".join(identity)
        data = blob(TARGET, path)
        require("historical_row_bound:" + label, row["historical_destination_sha256"] == original_manifest_rows[identity]["destinationSHA256"])
        require("prior_origin_bound:" + label, (row["prior_audit"]["repository"], row["prior_audit"]["original"], row["prior_audit"]["destination"]) == identity)
        require("match_status_recomputed:" + label, row["current_matches_historical_git_bytes"] == (digest(data) == row["historical_destination_sha256"]))
        require("current_hash:" + label, digest(data) == row["current_git_lf_sha256"])
        require("current_blob:" + label, value("rev-parse", TARGET + ":" + path).decode().strip() == row["current_git_blob"])
        require("current_size:" + label, len(data) == row["current_git_bytes"])
    require("26_exact_historical_matches", sum(r["current_matches_historical_git_bytes"] for r in rows) == 26)
    drift = {r["destination"] for r in rows if not r["current_matches_historical_git_bytes"]}
    evolutions = json.loads((evidence / "SIX_SOURCE_EVOLUTIONS.json").read_text(encoding="utf-8"))
    require("exact_six_evolutions", len(evolutions) == 6 and {r["destination"] for r in evolutions} == drift)
    for row in evolutions:
        path = row["destination"]
        old = blob(row["historical_revision"], path)
        require("historical_git_hash:" + path, digest(old) == row["historical_git_sha256"])
        represented = old if row["historical_representation"] == "git_bytes" else old.replace(b"\n", b"\r\n")
        require("historical_record_match:" + path, digest(represented) == row["expected_historical_sha256"])
        require("historical_ancestor:" + path, git("merge-base", "--is-ancestor", row["historical_revision"], TARGET).returncode == 0)
        patch = value("diff", "--no-ext-diff", row["historical_revision"], TARGET, "--", path)
        require("exact_evolution_patch:" + path, patch == gzip.decompress((evidence / row["evolution_patch"]).read_bytes()) and digest(patch) == row["evolution_patch_sha256"])
    old = blob(HISTORICAL, ADAPTER)
    crlf = old.replace(b"\n", b"\r\n")
    require("historical_git_lf_only", old.count(b"\r\n") == 0 and old.count(b"\n") == 165)
    require("historical_canonical_bytes", old == gzip.decompress((evidence / "LIBRARY_HISTORICAL.git-lf.swift.txt.gz").read_bytes()))
    require("historical_reconstructed_crlf_bytes", crlf == gzip.decompress((evidence / "LIBRARY_HISTORICAL.reconstructed-crlf.swift.txt.gz").read_bytes()))
    require("line_endings_only_round_trip", crlf.replace(b"\r\n", b"\n") == old)
    require("historical_record_digest", digest(crlf) == EXPECTED_OLD)
    manifest = json.loads(blob(HISTORICAL, inventory["manifest_path"]))
    row = next(r for r in manifest if r["destination"] == ADAPTER)
    require("digest_present_at_same_historical_commit", row["destinationSHA256"] == EXPECTED_OLD)
    require("local_single_merge_base", value("merge-base", "--all", TARGET, UPSTREAM).decode().splitlines() == [BASE])
    require("base_ancestor_of_target", git("merge-base", "--is-ancestor", BASE, TARGET).returncode == 0)
    require("base_ancestor_of_upstream", git("merge-base", "--is-ancestor", BASE, UPSTREAM).returncode == 0)
    require("upstream_not_integrated", git("merge-base", "--is-ancestor", UPSTREAM, TARGET).returncode == 1)
    require("no_replace_refs", value("replace", "-l") == b"")
    remote_raw = gzip.decompress((evidence / "GITHUB_COMPARE.raw.json.gz").read_bytes())
    remote_receipt = json.loads((evidence / "GITHUB_COMPARE.json").read_text(encoding="utf-8"))
    require("remote_response_sealed", digest(remote_raw) == remote_receipt["raw_sha256"] and len(remote_raw) == remote_receipt["raw_bytes"])
    remote = json.loads(remote_raw)
    require("remote_exact_target_url", remote["html_url"] == "https://github.com/davidpovarsky/Maktabah/compare/" + UPSTREAM + "..." + TARGET)
    require("remote_pinned_base", remote["base_commit"]["sha"] == UPSTREAM)
    require("independent_remote_merge_base_agrees", remote["merge_base_commit"]["sha"] == BASE)
    require("remote_divergence_preserved", remote["status"] == "diverged" and remote["behind_by"] == 22 and remote["ahead_by"] == 1387)
    print(json.dumps({"status": "PASS", "scope": "Read-only exact-source provenance verification; no compiler, Native, runtime, license approval or full-history certification", "target": TARGET, "checks": len(checks), "unique_checks": len(set(checks)), "check_names": checks, "native_tests_executed": 0, "source_files_modified": 0}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
