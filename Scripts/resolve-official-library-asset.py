#!/usr/bin/env python3
"""Resolve the official SeforimLibrary database asset using Maktabah schema priority policy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SCHEMA_ASSET_PATTERN = re.compile(r"^seforim-schema(\d+)\.db\.zst$")
LEGACY_ASSET_NAME = "seforim.db.zst"


def schema_version(asset_name: str) -> int | None:
    match = SCHEMA_ASSET_PATTERN.match(asset_name)
    if match:
        return int(match.group(1))
    return None


def resolve_asset(release: dict) -> dict:
    assets = release.get("assets", [])
    schema_candidates = []
    legacy_candidate = None

    for asset in assets:
        name = asset.get("name", "")
        ver = schema_version(name)
        if ver is not None:
            schema_candidates.append((ver, asset))
        elif name == LEGACY_ASSET_NAME:
            legacy_candidate = asset

    if schema_candidates:
        # Max schema version, then alphabetical by name
        schema_candidates.sort(key=lambda item: (item[0], item[1].get("name", "")), reverse=True)
        chosen = schema_candidates[0][1]
    elif legacy_candidate is not None:
        chosen = legacy_candidate
    else:
        raise ValueError(f"No valid seforim database asset found in release {release.get('tag_name')}")

    digest = chosen.get("digest", "")
    sha256 = ""
    if digest.lower().startswith("sha256:"):
        sha256 = digest[7:].lower()
    else:
        # Look for build_provenance.json in release assets if available
        prov_asset = next((a for a in assets if a.get("name") == "build_provenance.json"), None)
        if prov_asset:
            # We don't download it here, caller can handle or digest is expected
            pass

    return {
        "release_tag": release.get("tag_name", ""),
        "release_id": release.get("id", 0),
        "asset_id": chosen.get("id", 0),
        "asset_name": chosen.get("name", ""),
        "compressed_bytes": chosen.get("size", 0),
        "compressed_sha256": sha256,
        "browser_download_url": chosen.get("browser_download_url", ""),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve official seforim library database asset.")
    parser.add_argument("--release-json", type=Path, required=True, help="Path to release JSON file")
    parser.add_argument("--field", choices=["release_tag", "release_id", "asset_id", "asset_name", "compressed_bytes", "compressed_sha256", "browser_download_url"], help="Print only this field")
    parser.add_argument("--format", choices=["json", "shell", "value"], default="json", help="Output format")
    args = parser.parse_args()

    raw = args.release_json.read_bytes()
    for enc in ("utf-8", "utf-16", "utf-16-le", "cp1252"):
        try:
            data = json.loads(raw.decode(enc))
            break
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    else:
        raise ValueError(f"Could not decode JSON from {args.release_json}")
    resolved = resolve_asset(data)

    if args.field:
        print(resolved[args.field])
    elif args.format == "shell":
        print(f"RELEASE_TAG='{resolved['release_tag']}'")
        print(f"RELEASE_ID={resolved['release_id']}")
        print(f"DATABASE_ASSET_ID={resolved['asset_id']}")
        print(f"DATABASE_ASSET_NAME='{resolved['asset_name']}'")
        print(f"DATABASE_COMPRESSED_BYTES={resolved['compressed_bytes']}")
        print(f"DATABASE_ASSET_SHA256='{resolved['compressed_sha256']}'")
        print(f"DATABASE_ASSET_URL='{resolved['browser_download_url']}'")
    else:
        print(json.dumps(resolved, indent=2))


if __name__ == "__main__":
    main()
