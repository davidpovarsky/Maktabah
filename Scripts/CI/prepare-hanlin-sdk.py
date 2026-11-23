#!/usr/bin/env python3
"""Install/verify one selected canonical Hanlin Gitlink and its original source bytes."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
SUBMODULE = ROOT / "Vendor/HanlinSDK"
URL = "https://github.com/davidpovarsky/hanlin-ai.git"
PACKAGES = ("Packages/HanlinAgentSDK", "Packages/HanlinPlatform", "Packages/HanlinPresentationSDK")
GENERATED = ("Package.swift", "docs/agent-sdk/unified-package-manifest.json")


def command(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
                                   text=True, encoding="utf-8", stderr=subprocess.PIPE, timeout=180).rstrip("\n")


def host_lock(pin):
    if not re.fullmatch(r"[a-f0-9]{40}", pin):
        raise RuntimeError("Expected an immutable Hanlin source SHA")
    lock = json.loads((ROOT / "HanlinSDK.lock.json").read_text())
    if lock.get("revision") != pin or not isinstance(lock.get("products"), list) or not lock["products"]:
        raise RuntimeError("HanlinSDK.lock.json does not match the requested source/products")
    entry = command(["git", "ls-files", "--stage", "--", "Vendor/HanlinSDK"])
    if entry != "160000 " + pin + " 0\tVendor/HanlinSDK":
        raise RuntimeError("The canonical Hanlin Gitlink and host lock must agree")
    return lock


def original_tree(pin):
    rows = subprocess.check_output(["git", "ls-tree", "-r", "-z", pin], cwd=SUBMODULE)
    result = {}
    for entry in rows.split(b"\0"):
        if entry:
            meta, path = entry.split(b"\t", 1)
            mode, kind, blob = meta.split()
            result[path.decode("utf-8")] = (mode, kind, blob.decode("ascii"))
    return result


def verify_original_files(tree, paths):
    paths = sorted(set(paths) - set(GENERATED))
    expected = {}
    for name in paths:
        mode, kind, blob = tree.get(name, (None, None, None))
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise RuntimeError("Unexpected original SDK source entry: " + name)
        if not (SUBMODULE / name).is_file():
            raise RuntimeError("An original selected SDK source is missing: " + name)
        expected[name] = blob
    if not paths:
        raise RuntimeError("The selected canonical SDK source inventory is empty")
    actual = subprocess.check_output(["git", "hash-object", "--no-filters", "--stdin-paths"], cwd=SUBMODULE,
        input=("\n".join(paths) + "\n").encode("utf-8")).decode("ascii").splitlines()
    if len(actual) != len(paths) or any(expected[p] != h for p, h in zip(paths, actual)):
        raise RuntimeError("Actual SDK bytes differ from the original pinned monorepo")
    return expected


def verify(pin):
    lock = host_lock(pin)
    if command(["git", "rev-parse", "HEAD"], SUBMODULE) != pin:
        raise RuntimeError("Hanlin SDK checkout does not match the committed input")
    tree = original_tree(pin)
    materialized = subprocess.check_output(["git", "ls-files", "-t", "-z"], cwd=SUBMODULE).decode("utf-8")
    materialized = [entry[2:] for entry in materialized.split("\0") if entry and not entry.startswith("S ")]
    receipt = json.loads((SUBMODULE / ".hanlin-sdk/installation.json").read_text())
    # Require the complete selected source trees, including files removed by an
    # externally changed sparse pattern. Git status alone cannot prove this.
    source_paths = receipt.get("sourcePaths", [])
    if not source_paths:
        raise RuntimeError("Canonical selected-source installation receipt is missing")
    required = {name for name in tree if any(name == path or name.startswith(path + "/") for path in source_paths)}
    expected = verify_original_files(tree, {*materialized, *required})
    installer_path = SUBMODULE / "Scripts/SDK/install.py"
    if "Scripts/SDK/install.py" not in expected:
        raise RuntimeError("Canonical installer source was not verified")
    spec = importlib.util.spec_from_file_location("canonical_hanlin_installer", installer_path)
    installer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(installer)
    checked = installer.check(ROOT, ROOT / "HanlinSDK.lock.json", "Vendor/HanlinSDK")
    # Derive the generated manifest from the original, byte-verified definitions;
    # a changed receipt hash alone must never admit a modified SDK profile.
    command([sys.executable, "Scripts/SDK/generate_manifest.py", "--check", "--products", *lock["products"]], SUBMODULE)
    description = json.loads(command(["swift", "package", "--package-path", str(SUBMODULE), "dump-package"], SUBMODULE))
    if {item["name"] for item in description["products"]} != set(lock["products"]):
        raise RuntimeError("Installed SDK products differ from the host contract")
    if installer.selected_source_paths(SUBMODULE, description) != source_paths:
        raise RuntimeError("Installed SDK source membership differs from its canonical product closure")
    manifests = {package: hashlib.sha256((SUBMODULE / package / "Package.swift").read_bytes()).hexdigest()
                 for package in PACKAGES}
    manifests["."] = hashlib.sha256((SUBMODULE / "Package.swift").read_bytes()).hexdigest()
    return {"repository": URL, "sha": pin, "layout": ["."],
            "verified_files": len(expected), "git_blobs": expected,
            "manifest_sha256": manifests,
            "source_profile": {"products": lock["products"], "source_paths": source_paths,
                               "generated_sha256": checked["generatedSHA256"],
                               "binary_targets": checked["binaryTargets"]},
            "boundary": "Original selected source identity and derived root profile only; package resolution, Apple build and native acceptance are separate gates."}


def bootstrap_installer(pin, source_cache):
    if source_cache:
        cache = Path(source_cache).resolve(strict=True)
        origin = command(["git", "remote", "get-url", "origin"], cache)
        if origin.rstrip("/").removesuffix(".git") != URL.removesuffix(".git"):
            raise RuntimeError("SDK source cache is not the canonical Hanlin repository")
        return subprocess.check_output(["git", "show", pin + ":Scripts/SDK/install.py"], cwd=cache)
    # The full SHA in this canonical HTTPS URL is immutable. After installation,
    # verify() checks this exact shared script and every selected original blob.
    address = "https://raw.githubusercontent.com/davidpovarsky/hanlin-ai/" + pin + "/Scripts/SDK/install.py"
    with urllib.request.urlopen(address, timeout=60) as response:
        return response.read()


def initialize(pin, source_cache=None):
    host_lock(pin)
    if SUBMODULE.exists() and not (SUBMODULE / ".git").exists():
        if any(SUBMODULE.iterdir()):
            raise RuntimeError("Occupied SDK directory; preserve contents instead of overwriting")
        SUBMODULE.rmdir()  # Git's empty uninitialized gitlink directory only.
    with tempfile.TemporaryDirectory(prefix="hanlin-shared-installer-") as temporary:
        script = Path(temporary) / "install.py"
        script.write_bytes(bootstrap_installer(pin, source_cache))
        arguments = [sys.executable, str(script), "--host-root", str(ROOT)]
        if source_cache:
            arguments.extend(["--source-cache", str(source_cache)])
        command(arguments)
    command(["git", "submodule", "init", "--", "Vendor/HanlinSDK"])
    command(["git", "submodule", "absorbgitdirs", "Vendor/HanlinSDK"])
    return verify(pin)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--source-cache", type=Path, default=os.environ.get("HANLIN_SDK_SOURCE_CACHE"),
                        help="Optional existing canonical Git object cache; no full clone or runtime copy")
    args = parser.parse_args()
    proof = verify(args.sha) if args.verify_only else initialize(args.sha, args.source_cache)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in proof.items() if key != "git_blobs"}))


if __name__ == "__main__":
    main()
