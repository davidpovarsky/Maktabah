#!/usr/bin/env python3
"""Observe one managed-v40 Simulator app; write context for the Settings UI gate.

This changes only the requested evidence files. It never copies a database,
creates user-data rows, launches the app or replaces an official release response.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request
import uuid

BUNDLE = "com.davidpovarsky.chavrusatext"
TAG = "v40-20261123094345"
SHA = "8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01"
LATEST = "https://api.github.com/repos/Otzaria/SeforimLibrary/releases/latest"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--database", type=Path, required=True, help="Observed native managed v40 seforim.db path")
    parser.add_argument("--annotations-path", type=Path, help="Observed original store if unique discovery is unavailable")
    parser.add_argument("--expected-target-id", type=int, default=459809828)
    parser.add_argument("--expected-target-tag", default="v41-20261126162443")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(str(uuid.UUID(args.udid)).upper() == args.udid, "Use the canonical owned Simulator UDID")
    owned = (Path.home() / "Library/Developer/CoreSimulator/Devices" / args.udid / "data").resolve(strict=True)

    def observed(path, exists=True):
        require(path.is_absolute(), "Observed paths must be absolute")
        resolved = path.resolve(strict=exists)
        require(resolved == path and resolved.is_relative_to(owned), "Path is redirected or outside the owned Simulator")
        return resolved

    raw = subprocess.check_output(["xcrun", "simctl", "get_app_container", args.udid, BUNDLE, "data"],
                                  text=True, timeout=45)
    data = observed(Path(raw.strip()))
    database = observed(args.database)
    require(database.name == "seforim.db" and database.parent.name == "Otzaria"
            and database.is_file() and database.stat().st_size == 4_355_063_808,
            "Expected the managed production v40 database")
    manifest_bytes = (database.parent / "seforim-installation.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    require(manifest.get("releaseID") == 455390662 and manifest.get("releaseTag") == TAG
            and manifest.get("profileID") == "production", "Managed manifest is not the accepted full-v40 source")
    candidates = [args.annotations_path] if args.annotations_path else sorted({
        candidate.resolve(strict=True) for candidate in data.rglob("Annotations.sqlite")
        if candidate.is_file() and not candidate.is_symlink()})
    require(len(candidates) == 1,
            "Open original Reader/Notes to initialize its repository, or pass its observed --annotations-path")
    annotations = observed(candidates[0])
    require(annotations.name == "Annotations.sqlite" and annotations.is_file(), "Expected the actual annotation repository")
    support = data / "Library/Application Support"
    workspace = observed(support / "ChavrusaText/StudyWorkspace/workspace-v1.json", False)
    qualified = observed(support / "Maktabah/qualified-locators-v1.json", False)
    # ITorahSharedContainer.downloadsRootURL, then the production database profile.
    downloads = observed(database.parent / "Downloads/Maktabah/Otzaria/Downloads", False)
    request = urllib.request.Request(LATEST, headers={"User-Agent": "Maktabah-Settings-UI-Acceptance"})
    with urllib.request.urlopen(request, timeout=45) as response:
        require(response.status == 200, "Official latest lookup failed")
        release_bytes = response.read(2_000_001)
    require(len(release_bytes) <= 2_000_000, "Official release metadata exceeds its bound")
    release = json.loads(release_bytes)
    require(release.get("id") == args.expected_target_id and release.get("tag_name") == args.expected_target_tag
            and release.get("draft") is False and release.get("prerelease") is False,
            "Official latest changed; rebind the expected target from observed public metadata")
    assets = [a for a in release.get("assets", []) if a.get("name") == "seforim-schema7.db.zst.manifest.json"]
    require(len(assets) == 1, "Expected one official full-library multipart manifest")
    context = {
        "simulatorUDID": args.udid, "databasePath": str(database), "downloadsPath": str(downloads),
        "annotationsPath": str(annotations), "qualifiedLocatorsPath": str(qualified), "workspacePath": str(workspace),
        "expectedCurrentTag": TAG, "expectedCurrentSHA256": SHA,
        "expectedTargetID": args.expected_target_id, "expectedTargetTag": args.expected_target_tag,
    }
    proof = {
        "status": "CONTEXT_PREPARED_UI_NOT_RUN", "observed_at": datetime.now(timezone.utc).isoformat(),
        "app_bundle": BUNDLE, "app_data_container": str(data),
        "installed_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "latest_api": LATEST, "latest_response_sha256": hashlib.sha256(release_bytes).hexdigest(),
        "latest_release_id": release["id"], "latest_tag": release["tag_name"],
        "full_asset": {key: assets[0].get(key) for key in ("id", "name", "size", "digest", "browser_download_url")},
        "database_hash_check": "Mandatory XCTest check before mutation; not claimed by this metadata helper",
        "state_setup": "Original UI note/tag, history row star and current-tabs group copy",
        "ordinary_reader_precondition": "Leave a genuine book open in the ordinary production Library tab",
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    proof_path = output.with_name(output.stem + ".proof.json")
    require(not output.exists() and not proof_path.exists(), "Existing receipts are preserved; choose new filenames")
    for path, value in [(output, context), (proof_path, proof)]:
        with path.open("x") as stream:
            json.dump(value, stream, indent=2); stream.write("\n")
    print(json.dumps({"status": proof["status"], "context": str(output), "proof": str(proof_path)}, indent=2))


if __name__ == "__main__":
    main()
