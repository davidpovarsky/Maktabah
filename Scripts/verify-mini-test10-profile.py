#!/usr/bin/env python3
"""Verify miniTest10 database, profile, and both engine manifests as one identity."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3


EXPECTED_BOOKS = [1, 28, 40, 103, 382, 3152, 3163, 3276, 3764, 3891]


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(8 * 1024 * 1024):
            value.update(chunk)
    return value.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--otzaria-manifest", type=Path)
    parser.add_argument("--zayit-manifest", type=Path)
    args = parser.parse_args()
    profile = json.loads(args.profile.read_text(encoding="utf-8"))
    db_hash = sha256(args.database)
    archive_hash = sha256(args.archive)
    assert profile["profileID"] == "miniTest10" and profile["profileVersion"] == 3
    assert profile["sharedLexicalDatabase"] == {
        "bytes": 57122816,
        "releaseTag": "v0.3.0",
        "sha256": "b42e36626802629fed178068e8cf11f0f034d6f24ae3b72ac9999b9311bf299f",
    }
    assert profile["bookIDs"] == EXPECTED_BOOKS
    assert profile["sourceDatabase"]["databaseBytes"] == args.database.stat().st_size
    assert profile["sourceDatabase"]["databaseSHA256"] == db_hash
    assert profile["databaseCompressedBytes"] == args.archive.stat().st_size
    assert profile["databaseCompressedSHA256"] == archive_hash

    with sqlite3.connect(args.database) as database:
        books = [row[0] for row in database.execute("SELECT id FROM book ORDER BY id")]
        lines = database.execute("SELECT COUNT(*) FROM line").fetchone()[0]
        links = database.execute("SELECT COUNT(*) FROM link").fetchone()[0]
        foreign_keys = database.execute("PRAGMA foreign_key_check").fetchall()
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
    assert books == EXPECTED_BOOKS
    assert lines == 18195 and links == 4834
    assert not foreign_keys and integrity == "ok"

    if args.otzaria_manifest:
        manifest = json.loads(args.otzaria_manifest.read_text())
        assert manifest["profileID"] == "miniTest10" and manifest["profileVersion"] == 3
        assert manifest["sourceDatabase"]["databaseSHA256"] == db_hash
        assert manifest["sourceDatabase"]["databaseBytes"] == args.database.stat().st_size
        assert manifest["sourceDatabase"]["bookCount"] == 10
        assert manifest["sourceDatabase"]["repository"] == profile["sourceDatabase"]["repository"]
        assert manifest["sourceDatabase"]["releaseID"] == profile["sourceDatabase"]["releaseID"]
        assert manifest["sourceDatabase"]["releaseTag"] == profile["sourceDatabase"]["releaseTag"]
        assert manifest["sourceDatabase"]["assetID"] == profile["profileVersion"]
        assert manifest["sourceDatabase"]["assetName"] == "miniTest10-seforim.db.zst"
        assert manifest["sourceDatabase"]["sourceAssetDigest"] == f"sha256:{archive_hash}"
        lexical = manifest["resources"]["Application Support/Otzaria/lexical.db"]
        assert lexical["version"] == profile["sharedLexicalDatabase"]["releaseTag"]
        assert lexical["bytes"] == profile["sharedLexicalDatabase"]["bytes"]
        assert lexical["sha256"] == profile["sharedLexicalDatabase"]["sha256"]
    if args.zayit_manifest:
        manifest = json.loads(args.zayit_manifest.read_text())
        assert manifest["profileID"] == "miniTest10" and manifest["profileVersion"] == 3
        assert manifest["requiredDatabase"]["canonicalSHA256"] == db_hash
        assert manifest["requiredDatabase"]["compressedAssetSHA256"] == archive_hash
        assert manifest["requiredDatabase"]["bytes"] == args.database.stat().st_size
        assert manifest["requiredDatabase"]["releaseTag"] == profile["sourceDatabase"]["releaseTag"]
        assert manifest["counts"]["books"] == 10
        lexical = manifest["sharedLexicalDatabase"]
        assert lexical["version"] == profile["sharedLexicalDatabase"]["releaseTag"]
        assert lexical["bytes"] == profile["sharedLexicalDatabase"]["bytes"]
        assert lexical["sha256"] == profile["sharedLexicalDatabase"]["sha256"]

    print(json.dumps({
        "databaseBytes": args.database.stat().st_size,
        "databaseSHA256": db_hash,
        "compressedBytes": args.archive.stat().st_size,
        "compressedSHA256": archive_hash,
        "bookIDs": EXPECTED_BOOKS,
        "lines": lines,
        "links": links,
        "integrity": integrity,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
