#!/usr/bin/env python3
"""Repair metadata-only extracted-layout counts without changing package bytes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_digest(value: dict) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()
    return hashlib.sha256(encoded).hexdigest()


def repaired_manifest(manifest: dict) -> tuple[dict, str]:
    repaired = json.loads(json.dumps(manifest))
    artifact = repaired["lexicalArtifact"]
    parts = artifact["parts"]
    represented_paths = {part["destinationPath"] for part in parts}
    represented_bytes = sum(part["uncompressedBytes"] for part in parts)
    packaged_bytes = sum(part["packagedBytes"] for part in parts)
    if represented_bytes != artifact["extractedBytes"]:
        raise RuntimeError("cannot repair manifest with inconsistent extracted bytes")
    if packaged_bytes != artifact["packagedBytes"]:
        raise RuntimeError("cannot repair manifest with inconsistent packaged bytes")
    if len(represented_paths) >= artifact["fileCount"]:
        raise RuntimeError("manifest does not contain an over-counted extracted layout")

    original_identity = repaired["artifactIdentity"]
    artifact["fileCount"] = len(represented_paths)
    repaired["artifactIdentity"] = ""
    repaired["artifactIdentity"] = canonical_digest(repaired)
    return repaired, original_identity


def write_json(path: Path, value: dict) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--metrics", type=Path)
    args = parser.parse_args()

    repaired, original_identity = repaired_manifest(
        json.loads(args.manifest.read_text(encoding="utf-8"))
    )
    write_json(args.manifest, repaired)
    if args.metrics:
        metrics = json.loads(args.metrics.read_text(encoding="utf-8"))
        metrics["artifactIdentity"] = repaired["artifactIdentity"]
        metrics["fileCount"] = repaired["lexicalArtifact"]["fileCount"]
        metrics["metadataRepair"] = {
            "kind": "excluded-empty-runtime-locks-from-extracted-file-count",
            "originalArtifactIdentity": original_identity,
        }
        write_json(args.metrics, metrics)


if __name__ == "__main__":
    main()
