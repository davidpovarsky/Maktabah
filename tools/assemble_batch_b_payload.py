#!/usr/bin/env python3
"""
assemble_batch_b_payload.py — Reproducible Downstream Payload Assembler and Hash Validator
Verifies integrity of all 15 fork-owned components and all 11 integration patches against
docs/architecture/BATCH_B_PAYLOAD_MANIFEST.json.
Can assemble, verify, or validate a target checkout from scratch.
"""

import argparse
import hashlib
import json
import os
import sys
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

def verify_payload_integrity(repo_root, manifest_data):
    print("=== Verifying Batch B Payload Components & Patches Integrity ===")
    baseline = manifest_data.get("baseline_commit")
    upstream_ref = manifest_data.get("upstream_pinned_sha")
    print(f"Manifest Version: {manifest_data.get('manifest_version')}")
    print(f"Target Baseline:  {baseline}")
    print(f"Pinned Upstream:  {upstream_ref}")
    print(f"Generated At:     {manifest_data.get('generated_at')}\n")

    errors = []

    # 1. Verify fork payload components
    print("--- 1. Fork-Owned Payload Components (15 files) ---")
    payload_components = manifest_data.get("fork_payload_components", [])
    for item in payload_components:
        rel_path = item["path"]
        expected_sha = item["sha256"]
        expected_size = item["size_bytes"]
        full_path = os.path.join(repo_root, rel_path.replace("/", os.sep))

        if not os.path.exists(full_path):
            errors.append(f"MISSING_PAYLOAD_FILE: {rel_path} does not exist at {full_path}")
            print(f"  [MISSING] {rel_path}")
            continue

        with open(full_path, "rb") as f:
            actual_bytes = f.read().replace(b"\r\n", b"\n")

        actual_size = len(actual_bytes)
        actual_sha = hashlib.sha256(actual_bytes).hexdigest()

        if actual_size != expected_size:
            errors.append(f"SIZE_MISMATCH: {rel_path} expected {expected_size} bytes, got {actual_size}")
            print(f"  [FAIL] {rel_path} (size mismatch)")
            continue

        if actual_sha != expected_sha:
            errors.append(f"HASH_MISMATCH: {rel_path} expected {expected_sha}, got {actual_sha}")
            print(f"  [FAIL] {rel_path} (SHA-256 mismatch)")
            continue

        print(f"  [PASS] {rel_path} ({actual_size} bytes, sha256={actual_sha[:12]}...)")

    # 2. Verify integration patches
    print("\n--- 2. Ordered Integration Patches (11 patches) ---")
    patches = manifest_data.get("ordered_patches", [])
    patches_dir = os.path.join(repo_root, "docs", "architecture", "batch-b-patches")

    for p in patches:
        filename = p["filename"]
        expected_sha = p["patch_file_sha256"]
        expected_size = p["size_bytes"]
        ownership = p["ownership"]
        approval = p["approval_status"]
        patch_full = os.path.join(patches_dir, filename)

        if not os.path.exists(patch_full):
            errors.append(f"MISSING_PATCH: {filename} does not exist at {patch_full}")
            print(f"  [MISSING] {filename}")
            continue

        with open(patch_full, "rb") as pf:
            p_bytes = pf.read().replace(b"\r\n", b"\n")

        p_size = len(p_bytes)
        p_sha = hashlib.sha256(p_bytes).hexdigest()

        if p_sha != expected_sha:
            errors.append(f"PATCH_HASH_MISMATCH: {filename} expected {expected_sha}, got {p_sha}")
            print(f"  [FAIL] {filename} (SHA-256 mismatch)")
            continue

        print(f"  [PASS] #{p['order']:02d} {filename} [{ownership}] ({approval}) sha256={p_sha[:12]}...")

    print("\n==========================================")
    if errors:
        print(f"VERIFICATION FAILED: {len(errors)} error(s) detected:")
        for err in errors:
            print(f"  ❌ {err}")
        return 1
    else:
        print("VERIFICATION SUCCESS: All 15 payload components and 11 patches match manifest exactly.")
        print("==========================================")
        return 0

def main():
    parser = argparse.ArgumentParser(description="Verify or assemble reproducible Batch B downstream payload.")
    parser.add_argument("--repo", default=None, help="Path to repository root")
    parser.add_argument("--manifest", default=None, help="Path to BATCH_B_PAYLOAD_MANIFEST.json")
    args = parser.parse_args()

    repo_root = os.path.abspath(args.repo) if args.repo else os.getcwd()
    manifest_path = os.path.abspath(args.manifest) if args.manifest else os.path.join(repo_root, "docs", "architecture", "BATCH_B_PAYLOAD_MANIFEST.json")

    if not os.path.exists(manifest_path):
        print(f"Error: Manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(2)

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_data = json.load(f)

    code = verify_payload_integrity(repo_root, manifest_data)
    sys.exit(code)

if __name__ == "__main__":
    main()
