#!/usr/bin/env python3
"""Verify the live integration source is included in the exact signed checkout."""
import argparse
import json
from pathlib import Path
import re
import subprocess


def git(*arguments):
    result = subprocess.run(["git", *arguments], text=True, capture_output=True, timeout=120)
    if result.returncode:
        # A remote failure can contain a credential-bearing URL; never log it.
        raise RuntimeError(f"Git {arguments[0]} verification failed (exit {result.returncode})")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-branch", required=True)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    report = {"status": "FAIL", "expectedReleaseSHA": args.expected_sha}
    try:
        if not re.fullmatch(r"[0-9a-f]{40}", args.expected_sha):
            raise RuntimeError("The expected release SHA must be an exact 40-character commit")
        current = git("rev-parse", "HEAD")
        report["releaseSHA"] = current
        if current != args.expected_sha:
            raise RuntimeError("The signed checkout differs from the expected release SHA")
        ref = args.source_branch
        if not ref.startswith("refs/heads/"):
            ref = "refs/heads/" + ref
        git("check-ref-format", ref)
        report["sourceRef"] = ref
        # Fetch objects/ref metadata only; never merge or update another working tree.
        git("fetch", "--no-tags", "--no-recurse-submodules", "origin", ref)
        source = git("rev-parse", "FETCH_HEAD")
        report["sourceSHA"] = source
        included = subprocess.run(["git", "merge-base", "--is-ancestor", source, current],
                                  text=True, capture_output=True, timeout=30)
        if included.returncode == 1:
            report["status"] = "BLOCKED_SOURCE_ADVANCED"
            raise RuntimeError("The other source has commits outside this build; synchronize and revalidate before uploading")
        if included.returncode:
            raise RuntimeError("Git ancestry could not be verified; no upload is permitted")
        report["status"] = "EXECUTED_PASS"
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    return 0 if report["status"] == "EXECUTED_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
