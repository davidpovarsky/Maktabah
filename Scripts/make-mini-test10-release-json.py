#!/usr/bin/env python3
"""Create the release-shaped identity consumed by the existing Otzaria packager."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            value.update(chunk)
    return value.hexdigest()


def build_payload(official: dict, profile: dict, archive: Path) -> dict:
    profile_version = profile["profileVersion"]
    if not isinstance(profile_version, int) or profile_version < 1:
        raise ValueError("profileVersion must be a positive integer")
    return {
        "id": official["id"],
        "tag_name": official["tag_name"],
        "assets": [{
            # OtzariaLibraryReleaseClient uses profileVersion as the stable,
            # profile-local asset identity for non-production releases.
            "id": profile_version,
            "name": profile["databaseAssetName"],
            "size": archive.stat().st_size,
            "digest": f"sha256:{digest(archive)}",
            "browser_download_url": (
                f"{profile['releaseBaseURL']}/{profile['databaseAssetName']}"
            ),
        }],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--official", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    official = json.loads(args.official.read_text())
    profile = json.loads(args.profile.read_text())
    payload = build_payload(official, profile, args.archive)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
