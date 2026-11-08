#!/usr/bin/env python3
"""Stage committed pins and prefetch the unchanged Sparkle binary via GitHub API."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

PIN_FILE = "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SPARKLE_URL = "https://github.com/sparkle-project/Sparkle/releases/download/2.9.1/Sparkle-for-Swift-Package-Manager.zip"
SPARKLE_SHA = "9fec2b888e6e2940b1bfbd5d3d010b9f67076b52170923549095cbb74132403b"


def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            hasher.update(chunk)
    return hasher.hexdigest()


def install_verified_archive(source, cache):
    if digest(source) != SPARKLE_SHA:
        raise RuntimeError("The pinned Sparkle archive checksum does not match its original Package.swift")
    cache.mkdir(parents=True, exist_ok=True)
    # SwiftPM's Workspace+BinaryArtifacts.swift uses the URL's C99 identifier.
    # This exact URL is ASCII; its non-identifier characters become underscores.
    destination = cache / re.sub(r"[^A-Za-z0-9_]", "_", SPARKLE_URL)
    if destination.exists():
        if digest(destination) != SPARKLE_SHA:
            raise RuntimeError("An existing SwiftPM cache file has unexpected bytes; it was left untouched")
        return destination
    descriptor, temporary = tempfile.mkstemp(prefix="codex-sparkle-", dir=cache)
    os.close(descriptor)
    temporary = Path(temporary)
    try:
        shutil.copyfile(source, temporary)
        try:
            # Publish atomically without replacing another process's cache file.
            os.link(temporary, destination)
        except FileExistsError:
            if digest(destination) != SPARKLE_SHA:
                raise RuntimeError("A concurrent SwiftPM cache file differs; it was left untouched")
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def pins(path):
    return {pin["identity"]: pin["state"] for pin in json.loads(path.read_text())["pins"]}


def prepare(root, workspace=None, project=None, verify=False):
    source = root / PIN_FILE
    if workspace:
        target = (root / workspace).resolve() / "xcshareddata/swiftpm/Package.resolved"
    elif project:
        target = (root / project).resolve() / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    else:
        raise RuntimeError("Specify the actual -workspace or -project used by xcodebuild")
    if not target.resolve().is_relative_to(root.resolve()):
        raise RuntimeError("Refusing to stage package pins outside this checkout")
    if verify:
        if pins(source) != pins(target):
            raise RuntimeError("SwiftPM changed the committed package revisions")
        print("Verified all committed package revisions after resolution")
        return
    if source.resolve() != target.resolve():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    sparkle = pins(source)["sparkle"]
    if sparkle != {"revision": "066e75a8b3e99962685d6a90cdd5293ebffd9261", "version": "2.9.1"}:
        raise RuntimeError("Review the original binary checksum before changing the Sparkle pin")
    print("Staged exact committed package pins:", target)


def main():
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("-workspace", type=Path)
    parser.add_argument("-project", type=Path)
    parser.add_argument("--verify", action="store_true")
    args, _ = parser.parse_known_args()
    root = Path(__file__).resolve().parents[2]
    prepare(root, args.workspace, args.project, args.verify)
    if args.verify or sys.platform != "darwin":
        return
    cache = Path.home() / "Library/Caches/org.swift.swiftpm/artifacts"
    destination = cache / re.sub(r"[^A-Za-z0-9_]", "_", SPARKLE_URL)
    if destination.exists() and digest(destination) == SPARKLE_SHA:
        print("Verified cached original Sparkle 2.9.1 archive")
        return
    logs = root / "build/logs"
    logs.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pinned-sparkle-", dir=logs) as temporary:
        archive = Path(temporary) / "Sparkle-for-Swift-Package-Manager.zip"
        for attempt in range(3):
            result = subprocess.run(["gh", "release", "download", "2.9.1", "--repo", "sparkle-project/Sparkle",
                                     "--pattern", archive.name, "--clobber", "--output", str(archive)],
                                    capture_output=True, text=True, timeout=180)
            if result.returncode == 0:
                break
            if attempt == 2 or not re.search(r"429|50[0234]|timed? out|timeout|connection|EOF", result.stderr, re.I):
                raise RuntimeError(f"Pinned Sparkle release download failed (exit {result.returncode})")
            time.sleep(5 * (attempt + 1))
        print("Verified original Sparkle archive in SwiftPM cache:", install_verified_archive(archive, cache))


if __name__ == "__main__":
    main()
