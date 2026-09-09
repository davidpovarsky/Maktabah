#!/usr/bin/env python3
"""Package an independently installable, deterministic Zayit Tantivy index."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

CHUNK_BYTES = 512 * 1024 * 1024
MAX_ASSET_BYTES = 1_900 * 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_digest(value: dict) -> str:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def compress_range(source: Path, offset: int, length: int, output: Path) -> None:
    with source.open("rb") as input_handle, output.open("wb") as output_handle:
        input_handle.seek(offset)
        process = subprocess.Popen(
            ["zstd", "-19", "--threads=0", "--no-progress", "-q", "-c"],
            stdin=subprocess.PIPE,
            stdout=output_handle,
        )
        assert process.stdin is not None
        remaining = length
        while remaining:
            chunk = input_handle.read(min(8 * 1024 * 1024, remaining))
            if not chunk:
                process.kill()
                raise RuntimeError(f"unexpected EOF in {source}")
            process.stdin.write(chunk)
            remaining -= len(chunk)
        process.stdin.close()
        if process.wait() != 0:
            raise RuntimeError(f"zstd failed for {source}")


FORBIDDEN_MANAGED_FILENAMES = {".managed.json"}


def packageable_files(index: Path) -> list[Path]:
    all_files = [path for path in index.rglob("*") if path.is_file()]
    for path in all_files:
        if path.name in FORBIDDEN_MANAGED_FILENAMES or path.name.endswith(".managed.json"):
            raise RuntimeError(f"forbidden runtime management file present in index: {path.name}")
    files = sorted(
        path for path in all_files
        if path.stat().st_size > 0 and not path.name.startswith(".")
    )
    if not files or not (index / "meta.json").is_file():
        raise RuntimeError("invalid Tantivy index")
    return files


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--index", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--lexical-version", required=True)
    parser.add_argument("--lexical-sha256", required=True)
    parser.add_argument("--lexical-bytes", required=True, type=int)
    parser.add_argument("--peak-build-bytes", required=True, type=int)
    parser.add_argument("--data-profile", default="production")
    parser.add_argument("--data-profile-version", type=int, default=1)
    args = parser.parse_args()

    metadata = json.loads((args.index / "zayit-index-metadata.json").read_text())
    if metadata["schema_version"] != 2:
        raise RuntimeError("only Zayit index schema 2 can be published")
    files = packageable_files(args.index)

    args.output.mkdir(parents=True, exist_ok=True)
    parts: list[dict] = []
    extracted_bytes = 0
    for source in files:
        relative = source.relative_to(args.index).as_posix()
        size = source.stat().st_size
        extracted_bytes += size
        for offset in range(0, size, CHUNK_BYTES):
            length = min(CHUNK_BYTES, size - offset)
            name = f"zayit-index-{len(parts):04d}.zst"
            destination = args.output / name
            compress_range(source, offset, length, destination)
            packaged = destination.stat().st_size
            if packaged >= MAX_ASSET_BYTES:
                raise RuntimeError(f"asset exceeds 1.9 GiB: {name}")
            parts.append({
                "assetName": name,
                "packagedBytes": packaged,
                "sha256": sha256(destination),
                "destinationPath": relative,
                "destinationOffset": offset,
                "uncompressedBytes": length,
                "compression": "zstd",
            })

    manifest = {
        "manifestSchemaVersion": 1,
        "artifactIdentity": "",
        "component": "zayitIndex",
        "version": metadata["database_release_tag"],
        "requiredDatabase": {
            "releaseTag": metadata["database_release_tag"],
            "compressedAssetSHA256": metadata["database_compressed_asset_sha256"],
            "canonicalSHA256": metadata["database_sha256"],
            "bytes": metadata["source_db_size"],
        },
        "engine": {
            "indexSchemaVersion": metadata["schema_version"],
            "builderVersion": metadata["builder_version"],
            "builderCommit": metadata["builder_commit"],
            "upstreamCommit": metadata["zayit_upstream_commit"],
            "tantivyVersion": metadata["tantivy_version"],
        },
        "counts": {
            "books": metadata["books_indexed"],
            "lines": metadata["lines_indexed"],
            "documents": metadata["index_documents"],
            "splitLines": metadata["oversized_lines_split"],
        },
        "stableBookIdentity": {
            "field": metadata["stable_book_identity"],
            "fallback": metadata["stable_book_identity_fallback"],
        },
        "sharedLexicalDatabase": {
            "version": args.lexical_version,
            "sha256": args.lexical_sha256,
            "bytes": args.lexical_bytes,
        },
        "extractedBytes": extracted_bytes,
        "packagedBytes": sum(part["packagedBytes"] for part in parts),
        "parts": parts,
    }
    if args.data_profile != "production" or args.data_profile_version != 1:
        manifest["profileID"] = args.data_profile
        manifest["profileVersion"] = args.data_profile_version
    manifest["artifactIdentity"] = canonical_digest(manifest)
    (args.output / "zayit-search-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    )
    metrics = {
        "artifactIdentity": manifest["artifactIdentity"],
        "databaseBytes": metadata["source_db_size"],
        "books": metadata["books_indexed"],
        "lines": metadata["lines_indexed"],
        "documents": metadata["index_documents"],
        "splitLines": metadata["oversized_lines_split"],
        "indexBytes": extracted_bytes,
        "compressedBytes": manifest["packagedBytes"],
        "peakBuildWorkspaceBytes": args.peak_build_bytes,
    }
    (args.output / "zayit-search-build-metrics.json").write_text(
        json.dumps(metrics, indent=2, sort_keys=True) + "\n"
    )


if __name__ == "__main__":
    main()
