#!/usr/bin/env python3
"""Create deterministic, independently streamable Otzaria Tantivy package parts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

CHUNK_BYTES = 512 * 1024 * 1024
EXCLUDED_PREFIXES = ("otzaria_", ".otzaria_")
RUNTIME_LOCK_FILENAMES = {".tantivy-meta.lock", ".tantivy-writer.lock"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_digest(value: dict) -> str:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def compress_chunk(source: Path, offset: int, length: int, output: Path) -> None:
    command = ["zstd", "-19", "--threads=0", "--no-progress", "-q", "-c"]
    with source.open("rb") as input_handle, output.open("wb") as output_handle:
        input_handle.seek(offset)
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=output_handle)
        assert process.stdin is not None
        remaining = length
        while remaining:
            data = input_handle.read(min(8 * 1024 * 1024, remaining))
            if not data:
                process.kill()
                raise RuntimeError(f"unexpected EOF in {source}")
            process.stdin.write(data)
            remaining -= len(data)
        process.stdin.close()
        if process.wait() != 0:
            raise RuntimeError(f"zstd failed for {source} at offset {offset}")


def selected_asset(release: dict, name: str) -> dict:
    matches = [asset for asset in release["assets"] if asset["name"] == name]
    if len(matches) != 1:
        raise RuntimeError(f"release must contain exactly one {name}")
    return matches[0]


def packageable_files(index: Path) -> tuple[list[Path], list[Path]]:
    candidates = sorted(
        path for path in index.rglob("*")
        if path.is_file() and not path.name.startswith(EXCLUDED_PREFIXES)
    )
    empty_files = [path for path in candidates if path.stat().st_size == 0]
    unexpected_empty_files = [
        path for path in empty_files if path.name not in RUNTIME_LOCK_FILENAMES
    ]
    if unexpected_empty_files:
        names = ", ".join(path.relative_to(index).as_posix() for path in unexpected_empty_files)
        raise RuntimeError(f"index contains unexpected empty package files: {names}")
    files = [path for path in candidates if path.stat().st_size > 0]
    if not files:
        raise RuntimeError("index contains no packageable files")
    return files, empty_files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--release-json", type=Path, required=True)
    parser.add_argument("--acceptance-json", type=Path, required=True)
    parser.add_argument("--magic-release-json", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--peak-build-bytes", type=int, required=True)
    parser.add_argument("--build-duration-seconds", type=float, required=True)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    upstream = json.loads(Path("Vendor/OtzariaSearchEngine/Upstream/UPSTREAM_MANIFEST.json").read_text())
    resources_source = json.loads(Path("Vendor/OtzariaSearchEngine/Upstream/RESOURCE_MANIFEST.json").read_text())
    release = json.loads(args.release_json.read_text())
    acceptance = json.loads(args.acceptance_json.read_text())
    magic_release = json.loads(args.magic_release_json.read_text())
    db_asset = selected_asset(release, "seforim.db.zst")
    magic_asset = selected_asset(magic_release, "lexical.db")
    identity = json.loads((args.index / "otzaria_search_identity.json").read_text())
    optimize_path = args.index / "otzaria_lexical_build_metrics.json"
    optimize = json.loads(optimize_path.read_text()) if optimize_path.exists() else {}

    files, empty_files = packageable_files(args.index)

    parts = []
    part_number = 0
    extracted_bytes = 0
    for source in files:
        relative = source.relative_to(args.index).as_posix()
        file_bytes = source.stat().st_size
        extracted_bytes += file_bytes
        for offset in range(0, file_bytes, CHUNK_BYTES):
            length = min(CHUNK_BYTES, file_bytes - offset)
            asset_name = f"otzaria-lexical-{part_number:04d}.zst"
            output = args.output / asset_name
            compress_chunk(source, offset, length, output)
            packaged = output.stat().st_size
            if packaged >= 2_000_000_000:
                raise RuntimeError(f"release part exceeds GitHub's 2 GB limit: {asset_name}")
            parts.append({
                "assetName": asset_name,
                "packagedBytes": packaged,
                "sha256": sha256(output),
                "destinationPath": relative,
                "destinationOffset": offset,
                "uncompressedBytes": length,
                "compression": "zstd",
            })
            part_number += 1

    resources = {}
    for resource in resources_source["resources"]:
        destination = resource.get("destination")
        digest = resource.get("sha256")
        if destination and digest:
            local = Path(destination)
            resources[destination] = {
                "version": resource.get("source_commit"),
                "bytes": local.stat().st_size,
                "sha256": digest,
            }
    resources["Application Support/Otzaria/lexical.db"] = {
        "version": magic_release["tag_name"],
        "bytes": magic_asset["size"],
        "sha256": (magic_asset.get("digest") or "").removeprefix("sha256:"),
    }

    source = {
        "repository": "Otzaria/SeforimLibrary",
        "releaseTag": release["tag_name"],
        "releaseID": release["id"],
        "assetID": db_asset["id"],
        "assetName": db_asset["name"],
        "sourceAssetDigest": db_asset.get("digest") or "",
        "compressedBytes": db_asset["size"],
        "databaseBytes": args.database.stat().st_size,
        "databaseSHA256": sha256(args.database),
        "bookCount": acceptance["expectedBooks"],
        "documentCount": acceptance["indexedDocuments"],
    }
    manifest = {
        "formatVersion": 1,
        "artifactIdentity": "",
        "sourceDatabase": source,
        "lexicalEngine": {
            "repository": upstream["repository"],
            "commit": upstream["commit"],
            "engineVersion": upstream["engine_package_version"],
            "indexSchemaVersion": upstream["index_schema_version"],
            "defaultGenerationOrder": upstream["default_generation_order"],
            "tantivyVersion": "0.26.1",
            "adapterVersion": "0.1.0",
            "semanticSidecarRevision": upstream["semantic_sidecar_revision"],
        },
        "resources": resources,
        "lexicalArtifact": {
            "documentCount": acceptance["indexedDocuments"],
            "sourceCount": acceptance["indexedSourcePaths"],
            "catalogueHash": identity["catalogueHash"],
            "extractedBytes": extracted_bytes,
            "packagedBytes": sum(part["packagedBytes"] for part in parts),
            "fileCount": len(files),
            "segmentsBeforeOptimize": optimize.get("segmentsBeforeOptimize", 0),
            "segmentsAfterOptimize": optimize.get("segmentsAfterOptimize", 0),
            "parts": parts,
        },
        "semantic": None,
    }
    manifest["artifactIdentity"] = canonical_digest(manifest)
    manifest_path = args.output / "otzaria-search-manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    metrics = {
        "formatVersion": 1,
        "artifactIdentity": manifest["artifactIdentity"],
        "databaseBytes": source["databaseBytes"],
        "freeDiskAtStartBytes": None,
        "peakBuildWorkspaceBytes": args.peak_build_bytes,
        "bytesBeforeOptimize": optimize.get("bytesBeforeOptimize"),
        "finalOptimizedIndexBytes": extracted_bytes,
        "packageBytes": manifest["lexicalArtifact"]["packagedBytes"],
        "installPeakAdditionalBytes": extracted_bytes + manifest["lexicalArtifact"]["packagedBytes"] + 1_073_741_824,
        "fileCount": len(files),
        "omittedRuntimeLockFiles": [
            path.relative_to(args.index).as_posix() for path in empty_files
        ],
        "segmentsBeforeOptimize": manifest["lexicalArtifact"]["segmentsBeforeOptimize"],
        "segmentsAfterOptimize": manifest["lexicalArtifact"]["segmentsAfterOptimize"],
        "documentCount": acceptance["indexedDocuments"],
        "sourceCount": acceptance["indexedSourcePaths"],
        "buildDurationSeconds": args.build_duration_seconds,
        "optimizeDurationSeconds": optimize.get("optimizeDurationSeconds"),
        "generatedAtEpoch": int(time.time()),
    }
    (args.output / "otzaria-search-build-metrics.json").write_text(
        json.dumps(metrics, indent=2, sort_keys=True) + "\n"
    )


if __name__ == "__main__":
    main()
