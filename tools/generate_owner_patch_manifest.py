#!/usr/bin/env python3
"""Generate unsigned, deterministic patch artifacts for explicit owner review.

This writes only a new output directory. It never signs, edits a register,
changes an approval status, or configures an owner verification key.
"""
import argparse
import hashlib
import json
from pathlib import Path

import verify_upstream_boundary as guard


def generate_manifest(repo, base_ref, head_ref, upstream_ref, paths=None):
    repo = str(Path(repo).resolve())
    refs = []
    for ref in (base_ref, head_ref, upstream_ref):
        code, value, _ = guard.run_cmd(["git", "rev-parse", "--verify", ref + "^{commit}"], cwd=repo)
        if code:
            raise ValueError("Every input must resolve to an existing immutable commit")
        refs.append(value.strip())
    base, head, upstream = refs
    if base == head:
        raise ValueError("Base and head cannot be the same commit")
    upstream_files = guard.get_tree_files(upstream, repo)
    changes = guard.parse_raw_diff(["git", "diff", "--raw", "--no-renames", "-z", base, head], repo)
    protected = {change["path"]: change for change in changes
                 if guard.is_protected_path(change["path"], upstream_files)}
    selected = sorted(protected if paths is None else set(paths))
    if not selected or any(path not in protected for path in selected):
        raise ValueError("Every selected path must be a changed protected file")
    patches = []
    contents = {}
    for index, path in enumerate(selected, 1):
        if protected[path]["status"] not in ("M", "T"):
            raise ValueError("This approval generator does not authorize protected additions/deletions: " + path)
        patch = guard.canonical_patch_bytes(base, head, path, repo)
        if not patch:
            raise ValueError("Changed protected file has an empty patch: " + path)
        blobs = []
        for commit in (base, head):
            code, blob, _ = guard.run_cmd(["git", "rev-parse", commit + ":" + path], cwd=repo)
            if code:
                raise ValueError("Could not resolve the exact protected blob: " + path)
            blobs.append(blob.strip())
        filename = f"{index:03d}-protected.patch"
        patches.append({"patch_id": f"OWNER_PATCH_{index:03d}", "path": path,
                        "patch_file": filename, "base_blob_sha": blobs[0],
                        "head_blob_sha": blobs[1], "patch_digest_sha256": hashlib.sha256(patch).hexdigest(),
                        "diff_bytes": len(patch)})
        contents[filename] = patch
    return {"schema_version": "1.3.0", "patch_format": "git-full-index-v1",
            "base_commit": base, "head_commit": head, "pinned_upstream_sha": upstream,
            "total_patches": len(patches), "patches": patches}, contents


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--upstream-ref", default=guard.DEFAULT_PINNED_UPSTREAM_SHA)
    parser.add_argument("--path", action="append", dest="paths", help="Optional explicit subset of changed protected files")
    parser.add_argument("--out-dir", required=True, help="New directory; existing paths are never overwritten")
    args = parser.parse_args()
    manifest, patches = generate_manifest(args.repo, args.base, args.head, args.upstream_ref, args.paths)
    output = Path(args.out_dir).resolve()
    output.mkdir(parents=True, exist_ok=False)
    for filename, content in patches.items():
        with (output / filename).open("xb") as file:
            file.write(content)
    with (output / "manifest.json").open("x", encoding="utf-8", newline="\n") as file:
        json.dump(manifest, file, indent=2, ensure_ascii=False)
        file.write("\n")
    print(f"Generated {len(patches)} unsigned full-index patches for review: {output}")


if __name__ == "__main__":
    main()
