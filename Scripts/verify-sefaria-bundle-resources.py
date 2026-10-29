#!/usr/bin/env python3
"""
verify-sefaria-bundle-resources.py
Validates that Sefaria upstream JSON files and main.jsbundle are present, valid JSON, non-empty,
and generates a JSON manifest with SHA256 checksums.
"""

import sys
import os
import json
import hashlib
from datetime import datetime, timezone

REQUIRED_JSON_FILES = [
    "calendar.json",
    "hebrew_categories.json",
    "packages.json",
    "people.json",
    "search_toc.json",
    "toc.json",
    "topic_toc.json"
]

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def main():
    if len(sys.argv) < 2:
        print("Usage: verify-sefaria-bundle-resources.py <app-bundle-or-sources-dir> [--require-bundle] [--manifest-out <path>]")
        sys.exit(1)

    target_dir = sys.argv[1]
    require_bundle = "--require-bundle" in sys.argv
    manifest_out = None
    if "--manifest-out" in sys.argv:
        idx = sys.argv.index("--manifest-out")
        if idx + 1 < len(sys.argv):
            manifest_out = sys.argv[idx + 1]

    # Check if target is directly the sources dir or app bundle
    if os.path.basename(target_dir) == "sources":
        sources_dir = target_dir
        app_dir = os.path.dirname(target_dir)
    else:
        app_dir = target_dir
        sources_dir = os.path.join(target_dir, "sources")

    print("============================================================")
    print(f"Verifying Sefaria Resources in: {sources_dir}")
    print("============================================================")

    if not os.path.isdir(sources_dir):
        print(f"FAIL: Sources directory not found: {sources_dir}")
        sys.exit(1)

    manifest = {
        "verifiedAt": datetime.now(timezone.utc).isoformat(),
        "targetDir": target_dir,
        "resources": {},
        "failures": []
    }

    failed = 0
    for fname in REQUIRED_JSON_FILES:
        fpath = os.path.join(sources_dir, fname)
        if not os.path.isfile(fpath):
            print(f"FAIL: Missing required file: {fname}")
            manifest["failures"].append({"file": fname, "reason": "missing"})
            failed += 1
            continue

        size = os.path.getsize(fpath)
        if size < 10:
            print(f"FAIL: File is empty/too small ({size} bytes): {fname}")
            manifest["failures"].append({"file": fname, "reason": "empty"})
            failed += 1
            continue

        try:
            with open(fpath, "r", encoding="utf-8") as fp:
                json.load(fp)
        except Exception as e:
            print(f"FAIL: Invalid JSON in {fname}: {e}")
            manifest["failures"].append({"file": fname, "reason": f"invalid_json: {e}"})
            failed += 1
            continue

        digest = sha256_file(fpath)
        print(f"OK: {fname} ({size:,} bytes, sha256: {digest[:16]}...)")
        manifest["resources"][f"sources/{fname}"] = {
            "size": size,
            "sha256": digest
        }

    jsbundle_path = os.path.join(app_dir, "main.jsbundle")
    if os.path.isfile(jsbundle_path):
        size = os.path.getsize(jsbundle_path)
        digest = sha256_file(jsbundle_path)
        print(f"OK: main.jsbundle ({size:,} bytes, sha256: {digest[:16]}...)")
        manifest["resources"]["main.jsbundle"] = {
            "size": size,
            "sha256": digest
        }
    else:
        if require_bundle:
            print(f"FAIL: main.jsbundle is required but missing at: {jsbundle_path}")
            manifest["failures"].append({"file": "main.jsbundle", "reason": "missing_required_bundle"})
            failed += 1
        else:
            print(f"WARN: main.jsbundle not found in {app_dir} (permitted in debug/simulator mode)")

    if manifest_out:
        os.makedirs(os.path.dirname(os.path.abspath(manifest_out)), exist_ok=True)
        with open(manifest_out, "w", encoding="utf-8") as fp:
            json.dump(manifest, fp, indent=2)
        print(f"Manifest written to: {manifest_out}")

    if failed > 0:
        print(f"FAILED: {failed} checks failed.")
        sys.exit(1)

    print("SUCCESS: All Sefaria resources verified.")
    sys.exit(0)

if __name__ == "__main__":
    main()
