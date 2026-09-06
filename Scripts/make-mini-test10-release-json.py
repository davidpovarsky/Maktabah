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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--official", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    official = json.loads(args.official.read_text())
    payload = {
        "id": official["id"],
        "tag_name": official["tag_name"],
        "assets": [{
            "id": 1,
            "name": "miniTest10-seforim.db.zst",
            "size": args.archive.stat().st_size,
            "digest": f"sha256:{digest(args.archive)}",
            "browser_download_url": (
                "https://github.com/davidpovarsky/Maktabah/releases/download/"
                "otzaria-miniTest10-v2/miniTest10-seforim.db.zst"
            ),
        }],
    }
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
