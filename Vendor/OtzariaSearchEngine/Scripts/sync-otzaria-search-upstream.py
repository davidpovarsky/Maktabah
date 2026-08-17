#!/usr/bin/env python3
"""Pin, materialize and validate the canonical Otzaria search upstream."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tomllib
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "Checkout" / "otzaria_search_engine"
PIN = ROOT / "Upstream" / "UPSTREAM_COMMIT"
MANIFEST = ROOT / "Upstream" / "UPSTREAM_MANIFEST.json"
RESOURCE_MANIFEST = ROOT / "Upstream" / "RESOURCE_MANIFEST.json"
RESOURCES = ROOT / "Resources"
ENGINE_REPOSITORY = "Otzaria/otzaria_search_engine"
ENGINE_URL = f"https://github.com/{ENGINE_REPOSITORY}.git"
ENGINE_BRANCH = "refactor"
APP_REPOSITORY = "Otzaria/otzaria"
APP_BRANCH = "dev"
RESOURCE_PATHS = ("assets/dictionary.json", "assets/Acronyms.json")


def github_request(url: str) -> urllib.request.Request:
    headers = {
        "Accept": "application/vnd.github.raw+json",
        "User-Agent": "Maktabah-Otzaria-Upstream-Sync",
    }
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return urllib.request.Request(url, headers=headers)


def run(*args: str, cwd: pathlib.Path | None = None, capture: bool = True) -> str:
    completed = subprocess.run(
        args,
        cwd=cwd,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
        check=False,
    )
    if completed.returncode:
        raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(args)}\n{completed.stdout or ''}")
    return (completed.stdout or "").strip()


def git(*args: str) -> str:
    return run("git", "-C", str(UPSTREAM), *args)


def ensure_checkout() -> None:
    if not (UPSTREAM / ".git").is_dir():
        UPSTREAM.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--branch", ENGINE_BRANCH, "--single-branch", ENGINE_URL, str(UPSTREAM), capture=False)
    if git("status", "--porcelain"):
        raise RuntimeError(f"upstream checkout is dirty before sync: {UPSTREAM}")
    git("fetch", "--prune", "origin", ENGINE_BRANCH)


def resolve_app_head() -> str:
    output = run("git", "ls-remote", f"https://github.com/{APP_REPOSITORY}.git", f"refs/heads/{APP_BRANCH}")
    return output.split()[0]


def source_metadata(commit: str) -> tuple[str | None, int | None, int | None, str | None]:
    cargo_path = UPSTREAM / "rust" / "Cargo.toml"
    cargo = tomllib.loads(cargo_path.read_text(encoding="utf-8"))
    package_version = cargo.get("package", {}).get("version")
    source = (UPSTREAM / "rust" / "src" / "api" / "search_engine.rs").read_text(encoding="utf-8")
    schema_match = re.search(r"INDEX_SCHEMA_VERSION:\s*u32\s*=\s*(\d+)", source)
    generation_match = re.search(r"DEFAULT_GENERATION_ORDER:\s*u32\s*=\s*(\d+)", source)
    if not generation_match:
        raise RuntimeError("upstream DEFAULT_GENERATION_ORDER was not found; adapter contract must be reviewed")
    semantic = cargo.get("dependencies", {}).get("otzaria-semantic-search", {})
    semantic_revision = semantic.get("rev") if isinstance(semantic, dict) else None
    return (
        package_version,
        int(schema_match.group(1)) if schema_match else None,
        int(generation_match.group(1)),
        semantic_revision,
    )


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sync_resources(app_commit: str, write: bool) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    if write:
        RESOURCES.mkdir(parents=True, exist_ok=True)
    for source_path in RESOURCE_PATHS:
        url = (
            f"https://api.github.com/repos/{APP_REPOSITORY}/contents/"
            f"{source_path}?ref={app_commit}"
        )
        with urllib.request.urlopen(github_request(url), timeout=60) as response:
            data = response.read()
        destination = RESOURCES / pathlib.Path(source_path).name
        if write:
            destination.write_bytes(data)
        records.append(
            {
                "name": "Aramaic translation dictionary" if destination.name == "dictionary.json" else "Acronyms dictionary",
                "source_repository": APP_REPOSITORY,
                "source_commit": app_commit,
                "source_path": source_path,
                "destination": destination.relative_to(ROOT.parent.parent).as_posix(),
                "sha256": sha256(data),
                "purpose": "Aramaic-to-Hebrew expansion for advanced search" if destination.name == "dictionary.json" else "Acronym expansion for advanced search",
                "license_reference": "Otzaria/otzaria repository license",
            }
        )
    records.extend(
        [
            {
                "name": "Morphological lexical database",
                "source_repository": "Otzaria/SeforimMagicIndexer",
                "source_commit": None,
                "source_path": "release asset lexical.db",
                "destination": "Application Support/Otzaria/lexical.db",
                "sha256": None,
                "purpose": "Optional morphology expansion for fuzzy search",
                "license_reference": "Downloaded at runtime using upstream release metadata",
            },
            {
                "name": "Semantic GGUF model",
                "source_repository": "Otzaria/otzaria-semantic-search",
                "source_commit": None,
                "source_path": None,
                "destination": None,
                "sha256": None,
                "purpose": "Optional production semantic embeddings",
                "license_reference": "Not vendored; use the upstream-supported artifact/license flow",
            },
        ]
    )
    return records


def write_json(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate(resource_records: list[dict[str, object]], run_builds: bool) -> list[str]:
    results: list[str] = []
    if git("status", "--porcelain"):
        raise RuntimeError("upstream checkout became dirty")
    for record in resource_records:
        digest = record.get("sha256")
        destination = record.get("destination")
        if not digest or not isinstance(destination, str) or not destination.startswith("Vendor/"):
            continue
        path = ROOT.parent.parent / destination
        if not path.is_file() or sha256(path.read_bytes()) != digest:
            raise RuntimeError(f"resource hash mismatch: {destination}")
    if run_builds:
        bridge = ROOT / "ios_bridge"
        commands = (
            ("cargo", "metadata", "--locked", "--no-default-features", "--format-version", "1"),
            ("cargo", "check", "--locked", "--no-default-features"),
            ("cargo", "test", "--locked", "--no-default-features", "--features", "semantic-mock"),
        )
        for command in commands:
            run(*command, cwd=bridge, capture=False)
            results.append(" ".join(command) + ": passed")
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    target = parser.add_mutually_exclusive_group(required=False)
    target.add_argument("--latest", action="store_true", help="pin origin/refactor HEAD")
    target.add_argument("--commit", help="pin an explicitly reviewed commit")
    parser.add_argument("--check", action="store_true", help="validate without changing tracked state")
    parser.add_argument("--skip-validation", action="store_true", help="skip Cargo builds (hash and cleanliness checks still run)")
    args = parser.parse_args()

    if not args.latest and not args.commit and not args.check:
        parser.error("choose --latest or --commit (plain --check validates the committed pin)")

    ensure_checkout()
    old = PIN.read_text(encoding="utf-8").strip() if PIN.exists() else None
    requested = "origin/refactor" if args.latest else (args.commit or old)
    if not requested:
        raise RuntimeError("no committed upstream pin exists")
    new = git("rev-parse", requested)
    git("merge-base", "--is-ancestor", new, "origin/refactor")
    commit_count = int(git("rev-list", "--count", f"{old}..{new}")) if old else 0
    log = git("log", "--oneline", "--no-decorate", f"{old}..{new}") if old and old != new else ""
    changed = git("diff", "--name-only", old, new) if old and old != new else ""

    git("checkout", "--detach", new)
    if git("status", "--porcelain"):
        raise RuntimeError("upstream checkout is dirty immediately after checkout")
    version, schema, default_generation_order, semantic_revision = source_metadata(new)
    app_commit = resolve_app_head()
    resources = sync_resources(app_commit, write=not args.check)
    for record in resources:
        if record["name"] == "Semantic GGUF model":
            record["source_commit"] = semantic_revision

    if args.check:
        if old != new:
            raise RuntimeError(f"pin drift: committed {old}, requested {new}")
        committed_manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if committed_manifest.get("default_generation_order") != default_generation_order:
            raise RuntimeError(
                "generation default drift: manifest "
                f"{committed_manifest.get('default_generation_order')} != upstream {default_generation_order}"
            )
    else:
        PIN.write_text(new + "\n", encoding="ascii")
        write_json(
            MANIFEST,
            {
                "repository": ENGINE_REPOSITORY,
                "branch": ENGINE_BRANCH,
                "commit": new,
                "synced_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "engine_package_version": version,
                "index_schema_version": schema,
                "default_generation_order": default_generation_order,
                "semantic_sidecar_revision": semantic_revision,
                "resources": {"manifest": "RESOURCE_MANIFEST.json"},
            },
        )
        write_json(
            RESOURCE_MANIFEST,
            {
                "reference_repository": APP_REPOSITORY,
                "reference_branch": APP_BRANCH,
                "reference_commit": app_commit,
                "resources": resources,
            },
        )

    results = validate(resources, run_builds=not args.skip_validation)
    print(f"old commit: {old or '(none)'}")
    print(f"new commit: {new}")
    print(f"commits synced: {commit_count}")
    print(f"reference app: {app_commit}")
    print("changed files/API:\n" + (changed or "(none)"))
    if log:
        print("commit log:\n" + log)
    print("validation:\n" + ("\n".join(results) if results else "clean checkout + resource hashes passed"))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
