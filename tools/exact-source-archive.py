"""Verify an explicitly transferred exact Git source closure without a fake checkout."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess


def source_identity(root, required_paths):
    root = Path(root).resolve(strict=True)
    manifest_name = os.environ.get("OTZARIA_SOURCE_ARCHIVE_MANIFEST")
    expected = os.environ.get("OTZARIA_SOURCE_ARCHIVE_SHA256")
    expected_source = os.environ.get("OTZARIA_SOURCE_ARCHIVE_COMMIT")
    if not manifest_name and not expected and not expected_source:
        return {
            "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
            "source_status": subprocess.check_output(["git", "status", "--short"], cwd=root, text=True),
            "source_archive": None,
        }
    if not (manifest_name and re.fullmatch(r"[0-9a-f]{64}", expected or "")
            and re.fullmatch(r"[0-9a-f]{40}", expected_source or "")):
        raise RuntimeError("Exact source archive requires manifest, external digest and canonical commit")
    manifest = Path(manifest_name)
    if not manifest.is_file() or manifest.is_symlink() or manifest.stat().st_size > 10_000_000:
        raise RuntimeError("Missing or aliased exact source manifest")
    raw = manifest.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected:
        raise RuntimeError("Source archive manifest differs from its externally pinned digest")
    data = json.loads(raw)
    if (data.get("schema") != "otzaria.exact-source-archive/1"
            or data.get("repository") != "davidpovarsky/Maktabah"
            or data.get("source_sha") != expected_source
            or not isinstance(data.get("files"), dict)
            or not set(required_paths) <= set(data["files"])):
        raise RuntimeError("Source archive identity or required closure differs")
    for name, record in data["files"].items():
        relative = Path(name)
        if (relative.is_absolute() or relative.as_posix() != name or ".." in relative.parts
                or not relative.parts or record.get("mode") not in ("100644", "100755")):
            raise RuntimeError("Invalid source archive path or mode")
        path = root / relative
        if (not path.is_file() or any(parent.is_symlink() for parent in (path, *path.parents)
                                     if parent.is_relative_to(root))
                or not path.resolve().is_relative_to(root)):
            raise RuntimeError("Missing or aliased committed source: " + name)
        metadata = path.stat()
        actual_mode = "100755" if metadata.st_mode & 0o111 else "100644"
        actual = path.read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(actual)).encode() + b"\0" + actual).hexdigest()
        if (not stat.S_ISREG(metadata.st_mode) or actual_mode != record["mode"]
                or len(actual) != record.get("bytes")
                or hashlib.sha256(actual).hexdigest() != record.get("sha256")
                or blob != record.get("git_blob")):
            raise RuntimeError("Transferred source differs from canonical Git bytes: " + name)
    return {
        "source_sha": expected_source,
        "source_status": "EXACT_COMMITTED_SOURCE_ARCHIVE_NOT_GIT_CHECKOUT",
        "source_archive": {"manifest_sha256": expected, "canonical_commit": expected_source,
                           "verified_file_count": len(data["files"]), "git_history_transferred": False},
    }
