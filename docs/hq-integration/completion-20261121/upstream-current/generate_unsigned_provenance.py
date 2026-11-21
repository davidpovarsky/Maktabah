#!/usr/bin/env python3
"""Unsigned review evidence only. No signing, policy edits, or gate replay."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import runpy
import subprocess
import zipfile

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser()
    for key in ["repo", "head", "central-base", "policy-base", "upstream", "central-report", "policy-report", "out"]:
        ap.add_argument("--" + key, required=True)
    a = ap.parse_args()
    root, out = Path(a.repo).resolve(), Path(a.out).resolve()
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=root, timeout=90)
    def rev(ref):
        return git("rev-parse", ref).decode().strip()
    def blob(ref, path):
        p = subprocess.run(["git", "rev-parse", "--verify", ref + ":" + path],
                           cwd=root, capture_output=True, timeout=30)
        return p.stdout.decode().strip() if p.returncode == 0 else None
    def content(path):
        return git("show", a.head + ":" + path)
    def write(path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())
    assert rev("HEAD") == a.head and not git("diff", "--name-only", "HEAD").strip()
    assert not out.exists() and out.is_relative_to(root / "docs/hq-integration")
    for ref in [a.head, a.central_base, a.policy_base, a.upstream]:
        assert rev(ref) == ref and re.fullmatch("[a-f0-9]{40}", ref)
    guard_path = "tools/verify_upstream_boundary.py"
    assert (root / guard_path).read_bytes().replace(b"\r\n", b"\n") == content(guard_path).replace(b"\r\n", b"\n")
    guard = runpy.run_path(str(root / guard_path), run_name="unsigned_provenance")
    register_path = "docs/architecture/UPSTREAM_EXCEPTION_REGISTER.json"
    old_manifest_path = "docs/architecture/BUILD_8401_REPRODUCIBLE_PAYLOAD_MANIFEST.json"
    register, old = json.loads(content(register_path)), json.loads(content(old_manifest_path))
    assert register["baseline_commit"] == old["base_commit"] == a.policy_base
    assert register["upstream_pinned_sha"] == old["pinned_upstream_sha"] == a.upstream
    assert old["total_patches"] == len(old["patches"]) == 14
    upstream = set(git("ls-tree", "-r", "--name-only", a.upstream).decode().splitlines())
    reports = {"central": json.loads(Path(a.central_report).read_bytes()),
               "policy-baseline": json.loads(Path(a.policy_report).read_bytes())}
    bases = {"central": a.central_base, "policy-baseline": a.policy_base}
    scopes = {}
    for name, base in bases.items():
        report = reports[name]
        assert report["base_ref"] == base and report["head_ref"] == a.head and report["upstream_ref"] == a.upstream
        assert report["status"] == "FAIL"
        write(out / "guard" / (name + ".json"), report)
        changed = git("diff", "--name-only", "--no-renames", "-z", base, a.head).decode().split("\0")
        protected = sorted(p for p in changed if p and guard["is_protected_path"](p, upstream))
        assert set(protected) == {v["path"] for v in report["violations"]}
        effective = guard["load_exception_register"](base, a.head, None, False, str(root))
        rows = []
        for index, path in enumerate(protected, 1):
            code, text, error = guard["run_cmd"](["git", "diff", base, a.head, "--", path], cwd=str(root))
            assert code == 0, error
            patch = text.replace("\r\n", "\n").encode()
            assert patch
            file = "patches/" + name + "/" + f"{index:02d}-" + re.sub("[^A-Za-z0-9._-]", "_", path) + ".patch"
            (out / file).parent.mkdir(parents=True, exist_ok=True)
            (out / file).write_bytes(patch)
            entry = effective.get(path, {})
            contexts = [e for e in register["exceptions"] if e.get("path") == path or path in e.get("paths", [])]
            rows.append({"path": path, "base_sha": base, "head_sha": a.head,
                         "base_blob_sha": blob(base, path), "head_blob_sha": blob(a.head, path),
                         "upstream_blob_sha": blob(a.upstream, path),
                         "ownership": "PINNED_UPSTREAM_TRACKED" if path in upstream else "PROTECTED_NAMESPACE_OR_SHARED_PROJECT",
                         "patch_file": file, "patch_bytes": len(patch), "canonical_patch_sha256": sha(patch),
                         "guard_types": [v["type"] for v in report["violations"] if v["path"] == path],
                         "effective_record_id": entry.get("patch_id"), "effective_record_status": entry.get("status"),
                         "declared_context_records": [{"patch_id": e.get("patch_id"), "status": e.get("status"),
                            "singular_path_consumed_by_loader": "path" in e,
                            "attestation_present": isinstance(e.get("owner_attestation"), dict)} for e in contexts]})
        scopes[name] = {"base_sha": base, "head_sha": a.head, "protected_path_count": len(rows),
                        "guard_status": report["status"], "guard_counts": dict(Counter(v["type"] for v in report["violations"])),
                        "saved_guard_report": "guard/" + name + ".json", "paths": rows}
    current = {row["path"]: row for row in scopes["policy-baseline"]["paths"]}
    comparisons = []
    for item in old["patches"]:
        row = current[item["path"]]
        raw = content("docs/architecture/build-8401-patches/" + item["patch_file"])
        file = "historical-patches/" + item["patch_file"]
        (out / file).parent.mkdir(parents=True, exist_ok=True)
        (out / file).write_bytes(raw)
        comparisons.append({"patch_id": item["patch_id"], "path": item["path"], "historical_base_sha": old["base_commit"],
                            "historical_head_blob_sha": item["head_blob_sha"], "current_head_blob_sha": row["head_blob_sha"],
                            "head_blob_matches": item["head_blob_sha"] == row["head_blob_sha"],
                            "historical_patch_sha256": item["patch_digest_sha256"],
                            "current_patch_sha256": row["canonical_patch_sha256"],
                            "patch_digest_matches": item["patch_digest_sha256"] == row["canonical_patch_sha256"],
                            "historical_patch_retained": file, "historical_patch_raw_sha256": sha(raw),
                            "historical_payload_integrity_matches": sha(raw.replace(b"\r\n", b"\n")) == item["patch_digest_sha256"],
                            "current_patch_file": row["patch_file"]})
    write(out / "HISTORICAL_8401_COMPARISON.json", comparisons)
    for source in [register_path, old_manifest_path]:
        path = out / "inputs" / Path(source).name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content(source))
    inputs = [guard_path, "Scripts/CI/verify-upstream-boundary.py", register_path, old_manifest_path,
              "docs/architecture/UPSTREAM_INTEGRITY_POLICY.md", "docs/architecture/BATCH_B_TRUSTED_OWNER_APPROVAL_GATE.md"]
    history = {"entries": 14, "current_blob_matches": sum(r["head_blob_matches"] for r in comparisons),
               "current_digest_matches": sum(r["patch_digest_matches"] for r in comparisons),
               "retained_patch_integrity_matches": sum(r["historical_payload_integrity_matches"] for r in comparisons)}
    proof = {"schema": "otzaria-unsigned-upstream-provenance-v1", "status": "UNSIGNED_CURRENT_SOURCE_REVIEW_ONLY",
             "repository": "davidpovarsky/Maktabah", "captured_at_utc": datetime.now(timezone.utc).isoformat(),
             "head_sha": a.head, "head_tree": rev(a.head + "^{tree}"), "pinned_upstream_sha": a.upstream,
             "pin_scope": "Existing verifier pin; no claim of latest upstream.",
             "application_trees": {p: rev(a.head + ":" + p) for p in ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]},
             "canonical_patch_command": ["git", "diff", "<base_sha>", "<head_sha>", "--", "<path>"],
             "canonical_encoding": "Existing guard run_cmd UTF-8 errors=replace/text=True, CRLF normalized to LF, encoded UTF-8",
             "bound_policy_inputs": {p: {"git_blob": blob(a.head, p), "sha256": sha(content(p))} for p in inputs},
             "scopes": scopes, "historical_8401_summary": history,
             "guard_reexecuted_by_generator": False, "acceptance_granted": False,
             "policy_or_register_modified": False, "signing_attempted": False, "keys_created_or_accessed": False,
             "register_records": len(register["exceptions"]),
             "register_records_with_attestation": sum(isinstance(e.get("owner_attestation"), dict) for e in register["exceptions"]),
             "array_only_records_ignored_by_original_loader": [e["patch_id"] for e in register["exceptions"] if "paths" in e and "path" not in e],
             "remaining_trust_material": [
                 "An authentic externally configured owner Ed25519 verifier identity.",
                 "Authentic signatures over the final accepted base/path/head-blob/patch-digest tuples.",
                 "Genuine approval reference and validity period in the unchanged canonical signature payload.",
                 "Current records in the singular-path form admitted by the unchanged loader.",
                 "Required final native/product acceptance, separately from cryptographic verification."]}
    write(out / "UNSIGNED_MANIFEST.json", proof)
    (out / "generate_unsigned_provenance.py").write_bytes(Path(__file__).read_bytes())
    lines = ["# Current unsigned upstream provenance", "", "Captured immutable head: " + a.head + ".",
             "This package grants no cryptographic or product acceptance. Original source, policy, register and historical payloads remain unchanged.",
             "", "## Scope", "", "| Range | Protected paths | Original guard |", "|---|---:|---|"]
    for name, scope in scopes.items():
        lines.append(f"| {scope['base_sha']} to {a.head} ({name}) | {scope['protected_path_count']} | {scope['guard_status']} |")
    lines += ["", "Original saved verifier reports are retained under guard; generation does not rerun the gate.",
              "UNSIGNED_MANIFEST.json contains exact per-path blobs and normalized patch digests for both scopes.",
              "", "## Historical records", "",
              f"Of 14 Build 8401 records, {history['current_blob_matches']} current blobs and {history['current_digest_matches']} current digests match.",
              f"Preserved historical patch integrity matches: {history['retained_patch_integrity_matches']}/14.",
              "See HISTORICAL_8401_COMPARISON.json for the individual comparisons.",
              "", "## Material remaining for trust verification", ""]
    lines.extend("- " + item for item in proof["remaining_trust_material"])
    lines += ["", "## Reproduction", "",
              "Run the included generator with full --head, --central-base, --policy-base, --upstream, --repo, matching saved --central-report and --policy-report, and a fresh --out under docs/hq-integration.",
              "The selected head must be checked out with no tracked edits. Existing snapshots are never overwritten.",
              "Later product changes require fresh source-bound patches and verifier reports. Code-identical CI/docs descendants may retain this receipt with an independently checked source identity mapping.",
              ""]
    (out / "REVIEW.md").write_bytes("\n".join(lines).encode())
    assert rev("HEAD") == a.head and not git("diff", "--name-only", "HEAD").strip()
    hashes = {p.relative_to(out).as_posix(): {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())}
              for p in sorted(out.rglob("*")) if p.is_file()}
    write(out / "FILE_HASHES.json", hashes)
    bundle = out / ("upstream-current-" + a.head[:8] + ".zip")
    with zipfile.ZipFile(bundle, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(out.rglob("*")):
            if path.is_file() and path != bundle:
                archive.write(path, path.relative_to(out).as_posix())
    print(json.dumps({"out": str(out), "head": a.head, "counts": {n: v["protected_path_count"] for n, v in scopes.items()},
                      "historical": history, "manifest_sha256": sha((out / "UNSIGNED_MANIFEST.json").read_bytes()),
                      "bundle_sha256": sha(bundle.read_bytes()), "bundle_bytes": bundle.stat().st_size,
                      "git_status": git("status", "--short").decode()}, indent=2))

if __name__ == "__main__":
    main()
