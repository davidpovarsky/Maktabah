#!/usr/bin/env python3
"""Bind the existing SDK-only job to one immutable push source; no compile claim."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BRANCH = "refs/heads/codex/otzaria-ui-sdk-intermediate-20261120"
WORKFLOW = ".github/workflows/otzaria-ui-sdk-intermediate.yml"
SELF = "Scripts/CI/verify-ui-sdk-intermediate-source.py"
PREFIX = "build/artifacts/ui-acceptance-typecheck.intermediate-source"
REVIEWED_SOURCE_COMMIT = "e603d8182a1c10c4b37b14c92b5f0bc3829edea8"
SOURCE_TREES = {
    "Source": "2c44edd5258cb0ea121472d76c4aef23ccbefc4d",
    "Vendor": "4065c0e62af325e83a65fe0c70270985229807ae",
    "Maktabah.xcodeproj": "f80e996fa5144a7be76a7ccad8c2939e1d03d9b5",
    "Maktabah-iOSUITests": "4ca3b75613f63f104db613a05518516b304f0ead",
}
ORIGINAL_INPUTS = {
    ".github/workflows/sefaria-embedded-validation.yml": "ac42069b4dbbe57898c45e280513412c8df41ee7",
    "Scripts/CI/select-runtime27-toolchain.py": "2a2202b8b9efb56aa0c39f7bd1ddea8aa1cf4f05",
    "Scripts/CI/typecheck-faithful-ui-tests.py": "0102957b43d9e4a71cd122046418dd33b55b8210",
    "Scripts/CI/test-faithful-workspace.py": "777da2ddd5f941a2ebe1b884fe75367534e4862b",
}
UI_FILES = [
    "MaktabahUITestBase.swift", "FaithfulReaderUIAcceptanceTests.swift",
    "Build8401SevenDefectsAcceptanceTests.swift", "PullNavigationAcceptanceTests.swift",
    "SefariaEmbeddedAcceptanceTests.swift", "NativeRoutingAcceptanceTests.swift",
    "GlobalSearchNativeAcceptanceTests.swift", "R27NativeInteractionAcceptanceTests.swift",
    "Sidebar11201AcceptanceTests.swift", "HanlinConsumerAcceptanceTests.swift",
    "BookHistoryScopeAcceptanceTests.swift",
]
SUPPORT = [
    SELF, WORKFLOW, "Scripts/CI/verify-otzaria-xcode-project.py", "Scripts/CI/runtime27.py",
    "Scripts/CI/verify-faithful-xctest.py", "Scripts/CI/test-verify-faithful-xctest.py",
    "Scripts/CI/hq-stage2-focused-apple.inputs.json", "Scripts/CI/prepare-hanlin-sdk.py",
    "docs/hq-integration/runtime27/R27_CASES.json",
]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=30).strip()


def source_record(relative: str, head: str) -> dict:
    path = ROOT
    for part in Path(relative).parts:
        path /= part
        if path.is_symlink():
            raise ValueError("Source symlink: " + relative)
    if not path.is_file():
        raise ValueError("Required complete source missing: " + relative)
    data = path.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()
    committed = git("rev-parse", head + ":" + relative)
    if blob != committed or (relative in ORIGINAL_INPUTS and blob != ORIGINAL_INPUTS[relative]):
        raise ValueError("Original or committed source differs: " + relative)
    return {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "git_blob": blob}


def observe_source() -> dict:
    if os.environ.get("GITHUB_EVENT_NAME") != "push":
        raise ValueError("Only the exact-branch push route is authorized")
    if os.environ.get("GITHUB_REPOSITORY") != "davidpovarsky/Maktabah" or os.environ.get("GITHUB_REF") != BRANCH:
        raise ValueError("Wrong repository or ref")
    expected = os.environ.get("GITHUB_SHA", "")
    head = git("rev-parse", "HEAD")
    if not re.fullmatch(r"[0-9a-f]{40}", expected) or head != expected:
        raise ValueError("Checkout is not the actual immutable workflow SHA")
    if git("status", "--porcelain", "--untracked-files=no"):
        raise ValueError("Tracked checkout changed")
    trees = {name: git("rev-parse", head + ":" + name) for name in SOURCE_TREES}
    if trees != SOURCE_TREES:
        raise ValueError("Reviewed application/test/vendor/project source changed")
    paths = sorted(set(ORIGINAL_INPUTS) | set(SUPPORT) | {"Maktabah-iOSUITests/" + name for name in UI_FILES})
    return {
        "head": head,
        "repository": os.environ["GITHUB_REPOSITORY"], "ref": os.environ["GITHUB_REF"],
        "reviewed_application_test_source": REVIEWED_SOURCE_COMMIT,
        "source_trees": trees,
        "inputs": [source_record(path, head) for path in paths],
        "complete_sdk_test_sources": ["Maktabah-iOSUITests/" + name for name in UI_FILES],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    args = parser.parse_args()
    output = ROOT / (PREFIX + "." + args.phase + ".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {"phase": args.phase, "observed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "status": "SOURCE_BINDING_FAILED", "native_ui_executed": 0,
              "scope": "Existing SDK-only job; this helper verifies sources, not compilation",
              "github_run_id": os.environ.get("GITHUB_RUN_ID"),
              "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")}
    try:
        observation = observe_source()
        report["observation"] = observation
        if args.phase == "after":
            before = json.loads((ROOT / (PREFIX + ".before.json")).read_text())
            if before.get("status") != "SOURCE_BOUND" or before.get("observation") != observation:
                raise ValueError("Source changed, or a completed original before-snapshot is missing")
        report["status"] = "SOURCE_BOUND" if args.phase == "before" else "SOURCE_UNCHANGED"
        return 0
    except Exception as error:
        report["error_type"] = type(error).__name__
        report["error"] = str(error)
        return 1
    finally:
        output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report[key] for key in ("phase", "status", "native_ui_executed")}))


if __name__ == "__main__":
    raise SystemExit(main())
