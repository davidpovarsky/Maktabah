#!/usr/bin/env python3
"""Prepare/verify the original pinned Hanlin monorepo, never copied SDK modules."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SUBMODULE = ROOT / "Vendor/HanlinSDK"
URL = "https://github.com/davidpovarsky/hanlin-ai.git"
PACKAGES = ("Packages/HanlinAgentSDK", "Packages/HanlinPlatform", "Packages/HanlinPresentationSDK")


def command(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
                                   text=True, encoding="utf-8", stderr=subprocess.PIPE, timeout=180).strip()


def verify(pin):
    if not re.fullmatch(r"[a-f0-9]{40}", pin):
        raise RuntimeError("Expected an immutable Hanlin source SHA")
    if command(["git", "rev-parse", "HEAD"], SUBMODULE) != pin:
        raise RuntimeError("Hanlin SDK checkout does not match the committed input")
    if command(["git", "status", "--porcelain", "--untracked-files=all"], SUBMODULE):
        raise RuntimeError("Preserve and inspect changed SDK files; never reset a dirty SDK checkout")
    rows = subprocess.check_output(["git", "ls-tree", "-r", "-z", pin, "--", *PACKAGES], cwd=SUBMODULE)
    expected = {}
    for entry in rows.split(b"\0"):
        if not entry:
            continue
        meta, path = entry.split(b"\t", 1)
        mode, kind, blob = meta.split()
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise RuntimeError("Unexpected SDK package entry")
        expected[path.decode("utf-8")] = blob.decode("ascii")
    paths = sorted(expected)
    if not paths or any(not (SUBMODULE / name).is_file() for name in paths):
        raise RuntimeError("An original SDK package is incomplete")
    actual = subprocess.check_output(["git", "hash-object", "--no-filters", "--stdin-paths"], cwd=SUBMODULE,
        input=("\n".join(paths) + "\n").encode("utf-8")).decode("ascii").splitlines()
    if len(actual) != len(paths) or any(expected[p] != h for p, h in zip(paths, actual)):
        raise RuntimeError("Actual SDK bytes differ from the original pinned monorepo")
    manifests = {}
    for package in PACKAGES:
        path = SUBMODULE / package / "Package.swift"
        manifests[package] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {"repository": URL, "sha": pin, "layout": list(PACKAGES),
            "verified_files": len(paths), "git_blobs": expected,
            "manifest_sha256": manifests,
            "boundary": "Original source identity/layout only; package resolution, Apple build and native acceptance are separate gates."}


def initialize(pin):
    if not (SUBMODULE / ".git").exists():
        if SUBMODULE.exists() and any(SUBMODULE.iterdir()):
            raise RuntimeError("Occupied SDK directory; preserve contents instead of overwriting")
        command(["git", "clone", "--filter=blob:none", "--no-checkout", "--depth=1", URL, str(SUBMODULE)])
        command(["git", "sparse-checkout", "init", "--cone"], SUBMODULE)
        command(["git", "sparse-checkout", "set", *PACKAGES], SUBMODULE)
        command(["git", "fetch", "--filter=blob:none", "--depth=1", "origin", pin], SUBMODULE)
        command(["git", "checkout", "--detach", pin], SUBMODULE)
        command(["git", "submodule", "init", "--", "Vendor/HanlinSDK"])
        command(["git", "submodule", "absorbgitdirs", "Vendor/HanlinSDK"])
    return verify(pin)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    proof = verify(args.sha) if args.verify_only else initialize(args.sha)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in proof.items() if key != "git_blobs"}))


if __name__ == "__main__":
    main()
