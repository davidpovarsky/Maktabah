#!/usr/bin/env python3
"""Resolve the official SeforimLibrary database asset using Maktabah schema priority policy."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shlex
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import quote


SCHEMA_ASSET_PATTERN = re.compile(r"^seforim-schema(\d+)\.db\.zst$")
LEGACY_ASSET_NAME = "seforim.db.zst"


def schema_version(asset_name: str) -> int | None:
    match = SCHEMA_ASSET_PATTERN.match(asset_name)
    if match:
        return int(match.group(1))
    return None


MANIFEST_SUFFIX = ".manifest.json"
MAX_MANIFEST_BYTES = 1_048_576


def digest(asset: dict) -> str:
    value = asset.get("digest")
    if isinstance(value, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", value, re.IGNORECASE):
        return value[7:].lower()
    return ""


def official_url(tag: str, asset: dict) -> str:
    name = asset["name"]
    expected = "https://github.com/Otzaria/SeforimLibrary/releases/download/" + quote(tag, safe="") + "/" + name
    if asset.get("browser_download_url") != expected:
        raise ValueError(f"Unexpected official asset URL for {name}")
    return expected


def download(url: str, output: Path, maximum_bytes: int) -> None:
    subprocess.run([
        "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "5",
        "--proto", "=https", "--proto-redir", "=https", "--max-filesize", str(maximum_bytes),
        "--output", str(output), url,
    ], check=True)


def resolve_asset(release: dict) -> dict:
    tag = release.get("tag_name")
    if not isinstance(tag, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", tag):
        raise ValueError("Invalid official library release tag")
    assets = release.get("assets", [])
    candidates = []
    for asset in assets:
        name = asset.get("name", "")
        multipart = name.endswith(MANIFEST_SUFFIX)
        candidate = name.removesuffix(MANIFEST_SUFFIX)
        version = schema_version(candidate)
        if candidate == LEGACY_ASSET_NAME or version is not None:
            candidates.append((version or 0, not multipart, candidate, asset))
    if not candidates:
        raise ValueError(f"No valid seforim database asset found in release {tag}")
    _, monolithic, archive, selected = max(candidates, key=lambda candidate: candidate[:3])
    if sum(a.get("name") == selected["name"] for a in assets) != 1:
        raise ValueError("Ambiguous official database asset")
    remote_url = official_url(tag, selected)
    pieces = [selected]
    compressed_bytes = selected["size"]
    compressed_sha256 = digest(selected)
    if not monolithic:
        if not compressed_sha256 or not 0 < compressed_bytes <= MAX_MANIFEST_BYTES:
            raise ValueError("Invalid official multipart manifest identity")
        with tempfile.TemporaryDirectory(prefix="seforim-release-manifest-") as work:
            payload = Path(work) / "manifest.json"
            download(remote_url, payload, compressed_bytes)
            raw = payload.read_bytes()
        if len(raw) != compressed_bytes or hashlib.sha256(raw).hexdigest() != compressed_sha256:
            raise ValueError("Official multipart manifest integrity check failed")
        plan = json.loads(raw)
        parts = plan.get("parts", [])
        if plan.get("schemaVersion") != 1 or plan.get("archive") != archive or not 1 <= len(parts) <= 1_000:
            raise ValueError("Invalid official multipart archive description")
        compressed_bytes = plan["size"]
        compressed_sha256 = plan["sha256"]
        if not re.fullmatch(r"[0-9a-f]{64}", compressed_sha256):
            raise ValueError("Invalid assembled archive digest")
        pieces = []
        for index, part in enumerate(parts):
            name = f"{archive}.part-{index:03d}"
            matches = [a for a in assets if a.get("name") == name]
            if (part.get("name") != name or len(matches) != 1
                    or matches[0]["size"] != part.get("size") or matches[0]["size"] < 1
                    or not digest(matches[0]) or digest(matches[0]) != part.get("sha256")):
                raise ValueError(f"Multipart part differs from the official release: {name}")
            official_url(tag, matches[0])
            pieces.append(matches[0])
        if compressed_bytes != sum(piece["size"] for piece in pieces):
            raise ValueError("Assembled archive size differs from the sum of its parts")

    return {
        "release_tag": tag,
        "release_id": int(release["id"]),
        "asset_id": int(selected["id"]),
        "asset_name": archive,
        "compressed_bytes": int(compressed_bytes),
        "compressed_sha256": compressed_sha256,
        "browser_download_url": remote_url,
        "remote_asset_name": selected["name"],
        "remote_asset_bytes": int(selected["size"]),
        "remote_asset_sha256": digest(selected),
        "parts": pieces if not monolithic else [],
    }


def materialize(resolved: dict, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / resolved["asset_name"]
    if destination.exists() or destination.is_symlink():
        raise FileExistsError(destination)
    with tempfile.TemporaryDirectory(prefix=".seforim-", dir=directory) as work:
        temporary = Path(work)
        staging = temporary / "archive.zst"
        archive_hash = hashlib.sha256()
        pieces = resolved["parts"] or [{
            "browser_download_url": resolved["browser_download_url"],
            "size": resolved["compressed_bytes"],
            "digest": "sha256:" + resolved["compressed_sha256"],
        }]
        with staging.open("xb") as output:
            for index, part in enumerate(pieces):
                local = temporary / f"part-{index}"
                download(part["browser_download_url"], local, part["size"])
                part_hash = hashlib.sha256()
                with local.open("rb") as handle:
                    while block := handle.read(4 * 1024 * 1024):
                        part_hash.update(block)
                        archive_hash.update(block)
                        output.write(block)
                if local.stat().st_size != part["size"] or (digest(part) and part_hash.hexdigest() != digest(part)):
                    raise ValueError(f"Official archive part integrity check failed at index {index}")
                local.unlink()
        expected = resolved["compressed_sha256"]
        if staging.stat().st_size != resolved["compressed_bytes"] or (expected and archive_hash.hexdigest() != expected):
            raise ValueError("Assembled official archive integrity check failed")
        destination.hardlink_to(staging)


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve official seforim library database asset.")
    parser.add_argument("--release-json", type=Path, required=True, help="Path to release JSON file")
    parser.add_argument("--field", choices=["release_tag", "release_id", "asset_id", "asset_name", "compressed_bytes", "compressed_sha256", "browser_download_url"], help="Print only this field")
    parser.add_argument("--download-dir", type=Path, help="Assemble and verify the archive in this directory")
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

    if args.download_dir is not None:
        materialize(resolved, args.download_dir)
    if args.field:
        print(resolved[args.field])
    elif args.format == "shell":
        mappings = {
            "RELEASE_TAG": "release_tag", "RELEASE_ID": "release_id",
            "ASSET_ID": "asset_id", "ASSET_NAME": "asset_name",
            "ASSET_COMPRESSED_BYTES": "compressed_bytes", "ASSET_COMPRESSED_SHA256": "compressed_sha256",
            "ASSET_BROWSER_DOWNLOAD_URL": "browser_download_url", "DATABASE_ASSET_ID": "asset_id",
            # The app installation manifest stores the remote asset identity.
            # For multipart releases that is the manifest, not its assembled archive.
            "DATABASE_ASSET_NAME": "remote_asset_name", "DATABASE_COMPRESSED_BYTES": "remote_asset_bytes",
            "DATABASE_ASSET_SHA256": "remote_asset_sha256", "DATABASE_ASSET_URL": "browser_download_url",
        }
        for name, key in mappings.items():
            print(f"{name}={shlex.quote(str(resolved[key]))}")
    else:
        print(json.dumps(resolved, indent=2))


if __name__ == "__main__":
    main()
