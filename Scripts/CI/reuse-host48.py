#!/usr/bin/env python3
"""Reuse the real 48-test component result only for identical component inputs.

This verifies prior evidence and source identity; it never executes or credits
new native tests. The original full app build audits the checked-out SDK too.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SDK = "e00498e33f106cc43be0476ffa2e09329c8ca300"
PRIOR = "3b475a8f8fd88ddfd12d0e6c891979e965cf9ce2"
BUILDER = "tools/hq-hanlin-host-contracts.py"
BUILDER_SHA = "07b30678c06aff58b1e351a12c3a3a74056cea9322891f2253f77e37057f4626"
EVIDENCE = "docs/hq-integration/completion-20261121/host48-reuse-44940208007/original-host48-evidence.zip"
ARCHIVE_SHA = "331c19caf9887172412103b65f404a74ea8e27ed469e11c065516451186c4bf2"
CORE = "Source/Otzaria/Actions/Sources/OtzariaActionCore"
ADAPTER = "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinHostAdapter.swift"
TEST = "Tests/HQ/hanlin-host/OtzariaHanlinHostAdapterTests.swift"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, timeout=60).decode().strip()


def read_prior(path):
    require(digest(path.read_bytes()) == ARCHIVE_SHA, "Prior evidence archive changed")
    with zipfile.ZipFile(path) as archive:
        require(sorted(archive.namelist()) == sorted([
            "result.json", "inputs.json", "swift-test.log", "package/Package.swift"]),
            "Prior evidence member set changed")
        require(archive.testzip() is None, "Prior evidence CRC failed")
        result = json.loads(archive.read("result.json"))
        inputs = json.loads(archive.read("inputs.json"))
        log = archive.read("swift-test.log").decode()
    expected = result["expected_tests"]
    passed = sorted(set(re.findall(
        r"Test Case '.*OtzariaHanlinHostAdapterTests[ .](test[A-Za-z0-9_]+)[\]'].*passed", log)))
    require(result["status"] == "PASS" and result["exit_code"] == 0
            and result["warnings"] == 0 and "warning:" not in log,
            "Prior component execution did not pass cleanly")
    require(len(expected) == 48 and len(set(expected)) == 48
            and expected == result["passed_tests"] == passed,
            "Prior log does not prove all 48 original tests")
    require(result["hanlin_sha"] == SDK and result["inputs"] == len(inputs) == 64,
            "Prior source closure changed")
    return result, inputs


def actual_bytes(path, expected_sha, expected_size=None):
    require(path.is_file() and not path.is_symlink(), "Missing or symbolic input: " + str(path))
    raw = path.read_bytes()
    # Windows checkout CRLF conversion changes no Swift/JSON source content.
    # On Apple CI actual bytes must equal the original executed bytes exactly.
    normalized = False
    if digest(raw) != expected_sha and os.name == "nt":
        converted = raw.replace(b"\r\n", b"\n")
        if converted.replace(b"\n", b"\r\n") == raw:
            raw = converted
            normalized = True
    require(digest(raw) == expected_sha
            and (expected_size is None or len(raw) == expected_size),
            "Changed component input: " + str(path))
    return normalized


def verify_local_inputs(root, inputs):
    local = {v["source"]: v for v in inputs.values() if not v["source"].startswith(SDK + ":")}
    sdk = {k: v for k, v in inputs.items() if v["source"].startswith(SDK + ":")}
    require(len(local) == 35 and len(sdk) == 29, "Unexpected local/SDK input closure")
    observed = {p.relative_to(root).as_posix() for p in (root / CORE).rglob("*")
                if p.is_file() and p.suffix in (".swift", ".json")}
    observed.update(p.relative_to(root).as_posix()
                    for p in (root / Path(ADAPTER).parent).rglob("*")
                    if p.is_file() and p.name == "OtzariaHanlinHostAdapter.swift")
    observed.add(TEST)
    require(observed == set(local), "Added or removed component input")
    normalized = []
    for name, row in local.items():
        path = root / name
        require(path.resolve().is_relative_to(root.resolve()), "Input escaped source root")
        if actual_bytes(path, row["sha256"], row["bytes"]):
            normalized.append(name)
    return normalized


def verify_committed_inputs(root, head, inputs):
    local = {v["source"]: v for v in inputs.values() if not v["source"].startswith(SDK + ":")}
    tracked = git(root, "ls-tree", "-r", "--name-only", head, "--",
                  CORE, str(Path(ADAPTER).parent).replace("\\", "/"), TEST).splitlines()
    selected = {name for name in tracked
                if (name.startswith(CORE + "/") and Path(name).suffix in (".swift", ".json"))
                or (name.startswith(str(Path(ADAPTER).parent).replace("\\", "/") + "/")
                    and Path(name).name == "OtzariaHanlinHostAdapter.swift")
                or name == TEST}
    require(selected == set(local), "Committed component input closure changed")
    for name, row in {**local, BUILDER: {"sha256": BUILDER_SHA}}.items():
        raw = subprocess.check_output(["git", "show", head + ":" + name], cwd=root, timeout=60)
        require(digest(raw) == row["sha256"]
                and ("bytes" not in row or len(raw) == row["bytes"]),
                "Committed component input changed: " + name)


def verify(root):
    prior, inputs = read_prior(root / EVIDENCE)
    head = git(root, "rev-parse", "HEAD")
    expected = os.environ.get("EXPECTED_CHECKOUT_SHA")
    require(not expected or head == expected, "Wrong immutable checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", PRIOR, head],
                   cwd=root, check=True, timeout=60)
    require(git(root, "ls-tree", head, "Vendor/HanlinSDK")
            == "160000 commit " + SDK + "\tVendor/HanlinSDK",
            "Original SDK gitlink changed")
    builder_normalized = actual_bytes(root / BUILDER, BUILDER_SHA)
    verify_committed_inputs(root, head, inputs)
    normalized = verify_local_inputs(root, inputs)
    require(git(root, "rev-parse", "HEAD") == head, "Checkout changed during verification")
    return {
        "status": "VERIFIED_REUSE_OF_PRIOR_HOST48_PASS",
        "checkout_sha": head,
        "prior_run_url": "https://github.com/davidpovarsky/Maktabah/actions/runs/44940208007",
        "prior_checkout_sha": PRIOR,
        "prior_artifact_id": 14724450161,
        "prior_artifact_sha256": "0484d4115576cd30b6ea35ad8a32aded9bca10d12d0fcf25dd10e883702dd8de",
        "subset_archive_sha256": ARCHIVE_SHA,
        "original_tests_executed": 48,
        "original_tests_passed": 48,
        "new_tests_executed": 0,
        "local_source_inputs_verified": 35,
        "sdk_source_inputs_bound_to_unchanged_gitlink": 29,
        "hanlin_sha": SDK,
        "builder_sha256": BUILDER_SHA,
        "windows_checkout_line_endings_normalized": normalized,
        "builder_windows_line_endings_normalized": builder_normalized,
        "boundary": prior["boundary"],
        "native_ui_acceptance": False,
        "live_provider_acceptance": False,
    }


def main():
    out = ROOT / "build/artifacts/continuation-host48-reuse/result.json"
    try:
        report = verify(ROOT)
        code = 0
    except Exception as error:
        report = {"status": "REUSE_REJECTED", "new_tests_executed": 0,
                  "error": type(error).__name__ + ": " + str(error)}
        code = 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return code


if __name__ == "__main__":
    sys.exit(main())
