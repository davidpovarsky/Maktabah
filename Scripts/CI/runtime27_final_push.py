#!/usr/bin/env python3
"""Exact final push admission and source receipts; never an acceptance oracle."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
ORIGINAL_WORKFLOW = ".github/workflows/sefaria-embedded-validation.yml"
BINDING = "Scripts/CI/runtime27-final-push.inputs.json"
ORIGINAL_RUNTIME_BLOB = "41268a7e701d9962c6e4ea3cf54764bb9213c3f4"
ORIGINAL_R27_SHA256 = "53f9db5b97784b9003eacf1bafc69e51bb64dd0580e426f0d8a17d32f4d9de9b"
R27_SOURCE = "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"
ROUTES = {
    "ui": {"ref": "refs/heads/codex/otzaria-final-native116-20261120",
           "workflow": ".github/workflows/otzaria-final-native-push.yml"},
    "release": {"ref": "refs/heads/codex/otzaria-final-release114-20261120",
                "workflow": ".github/workflows/otzaria-final-release-push.yml"},
}
TREE_PATHS = ("Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests")
PIN_PATHS = (
    "Scripts/CI/hq-stage2-focused-apple.inputs.json",
    "docs/hq-integration/runtime27/R27_CASES.json",
    "Scripts/CI/runtime27-release-manifest.json",
    "Scripts/CI/hq-v32-prebuilt-native.py",
)
SELECTION = {"native_cases": 116, "release_ui_cases": 114, "release_oracle_cases": 2,
             "per_test_timeout_seconds": 600}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(root, *args, binary=False):
    value = subprocess.check_output(["git", *args], cwd=root, timeout=120)
    return value if binary else value.decode("utf-8").strip()


def source_record(root, relative, head):
    path = Path(root)
    for part in Path(relative).parts:
        path /= part
        require(not path.is_symlink(), "Linked reviewed source: " + relative)
    require(path.is_file(), "Missing complete reviewed source: " + relative)
    data = path.read_bytes()
    actual_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    require(actual_blob == git(root, "rev-parse", head + ":" + relative),
            "Reviewed source bytes changed: " + relative)
    return {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "git_blob": actual_blob}


def authority(mode):
    require(mode in ROUTES, "Unknown final push mode")
    return {"event": "push", "repository": REPOSITORY, "repository_id": REPOSITORY_ID,
            **ROUTES[mode],
            "workflow_ref": REPOSITORY + "/" + ROUTES[mode]["workflow"] + "@" + ROUTES[mode]["ref"]}


def environment_identity(mode):
    expected = authority(mode)
    require(os.environ.get("GITHUB_EVENT_NAME") == expected["event"], "Final route requires push")
    require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY
            and os.environ.get("GITHUB_REPOSITORY_ID") == str(REPOSITORY_ID), "Wrong push repository")
    require(os.environ.get("GITHUB_REF") == expected["ref"]
            and os.environ.get("GITHUB_WORKFLOW_REF") == expected["workflow_ref"], "Wrong push workflow/ref")
    head = os.environ.get("GITHUB_SHA", "")
    require(re.fullmatch("[a-f0-9]{40}", head)
            and os.environ.get("EXPECTED_CHECKOUT_SHA") == head, "Missing exact push checkout")
    run_id, attempt = os.environ.get("GITHUB_RUN_ID", ""), os.environ.get("GITHUB_RUN_ATTEMPT", "")
    require(re.fullmatch("[1-9][0-9]*", run_id) and re.fullmatch("[1-9][0-9]*", attempt),
            "Missing actual push run/attempt")
    return {"authority": expected, "checkout_sha": head, "run_id": int(run_id), "run_attempt": int(attempt)}


def reviewed_source(root, head):
    """Inspect the same committed bytes for producer and later release consumer."""
    root = Path(root)
    require(git(root, "rev-parse", "HEAD") == head, "Push checkout moved")
    binding_record = source_record(root, BINDING, head)
    binding = json.loads((root / BINDING).read_bytes())
    require(binding.get("schema") == "otzaria-final-runtime-push-v1"
            and binding.get("state") == "FINALIZED", "Final application/four-pin review is not finalized")
    require(binding.get("routes") == ROUTES and binding.get("selection") == SELECTION,
            "Final route or complete selection contract changed")
    application = binding.get("application_source_sha")
    require(isinstance(application, str) and re.fullmatch("[a-f0-9]{40}", application),
            "Missing final application source")
    trees = binding.get("application_trees")
    require(isinstance(trees, dict) and set(trees) == set(TREE_PATHS)
            and all(isinstance(v, str) and re.fullmatch("[a-f0-9]{40}", v) for v in trees.values()),
            "Missing final four application trees")
    subprocess.run(["git", "merge-base", "--is-ancestor", application, head], cwd=root,
                   check=True, timeout=120)
    require({path: git(root, "rev-parse", application + ":" + path) for path in TREE_PATHS} == trees
            and {path: git(root, "rev-parse", head + ":" + path) for path in TREE_PATHS} == trees,
            "Final application/test/vendor/project tree differs")
    pin_hashes = binding.get("source_pin_sha256")
    require(isinstance(pin_hashes, dict) and set(pin_hashes) == set(PIN_PATHS)
            and all(isinstance(v, str) and re.fullmatch("[a-f0-9]{64}", v) for v in pin_hashes.values()),
            "Missing four reviewed original source pins")
    pins = [source_record(root, path, head) for path in PIN_PATHS]
    require({row["path"]: row["sha256"] for row in pins} == pin_hashes, "Final original source pin differs")
    inputs = json.loads((root / PIN_PATHS[0]).read_bytes())
    require(inputs.get("application_source_sha") == application
            and inputs.get("application_trees") == {path: trees[path] for path in ("Source", "Vendor", "Maktabah.xcodeproj")},
            "Original focused driver has a different application binding")
    r27_sha = binding.get("reviewed_r27_sha256")
    require(isinstance(r27_sha, str) and re.fullmatch("[a-f0-9]{64}", r27_sha), "Missing reviewed R27 source digest")
    r27_record = source_record(root, R27_SOURCE, head)
    require(r27_record["sha256"] == r27_sha, "Reviewed R27 source digest differs")
    runtime_record = source_record(root, "Scripts/CI/runtime27.py", head)
    runtime_bytes = (root / "Scripts/CI/runtime27.py").read_bytes()
    literal = ('"' + r27_sha + '"').encode()
    require(runtime_bytes.count(literal) == 1, "Runtime R27 digest must be one exact literal")
    inverse = runtime_bytes.replace(literal, ('"' + ORIGINAL_R27_SHA256 + '"').encode(), 1)
    inverse_blob = hashlib.sha1(b"blob " + str(len(inverse)).encode() + b"\0" + inverse).hexdigest()
    require(inverse_blob == ORIGINAL_RUNTIME_BLOB, "Runtime driver changed beyond the reviewed single R27 digest")
    paths = [ORIGINAL_WORKFLOW, *(route["workflow"] for route in ROUTES.values()),
             "Scripts/CI", "Maktabah-iOSUITests", "docs/hq-integration/runtime27",
             "tools/verify_xcresult_zero_skips.py"]
    raw = git(root, "ls-tree", "-r", "-z", head, "--", *paths, binary=True)
    expected = {}
    for entry in raw.split(b"\0"):
        if entry:
            meta, name = entry.split(b"\t", 1)
            require(meta.split()[1] == b"blob", "Unexpected final runtime gitlink")
            expected[name.decode("utf-8")] = meta.split()[2].decode("ascii")
    required = {ORIGINAL_WORKFLOW, BINDING, "Scripts/CI/runtime27_final_push.py",
                "Scripts/CI/runtime27.py", "Scripts/CI/verify-faithful-xctest.py",
                "Scripts/CI/runtime27-release-stages.py", "Scripts/CI/runtime27_release_handoff.py",
                *(route["workflow"] for route in ROUTES.values()), *PIN_PATHS}
    require(required <= set(expected), "Missing original runtime/declaration/authority source closure")
    records = [source_record(root, path, head) for path in sorted(expected)]
    require(all(record["git_blob"] == expected[record["path"]] for record in records), "Runtime closure changed")
    return {"application_source_sha": application, "application_trees": trees,
            "runtime27_digest_binding": {"r27_source": r27_record, "old_digest": ORIGINAL_R27_SHA256,
                "new_digest": r27_sha, "runtime_source": runtime_record, "whole_driver_inverse_git_blob": inverse_blob},
            "binding": binding_record, "source_pins": pins, "inputs": records,
            "source_inventory_sha256": hashlib.sha256(json.dumps(records, sort_keys=True,
                 separators=(",", ":")).encode()).hexdigest()}


def observe_source(root, mode):
    identity = environment_identity(mode)
    return {**identity, **reviewed_source(root, identity["checkout_sha"])}


def release_context(root, original_context):
    """Additional exact push case. The original manual context is unchanged."""
    observed = observe_source(root, "release")
    require(original_context["checkout_sha"] == observed["checkout_sha"]
            and original_context["run_id"] == observed["run_id"]
            and original_context["run_attempt"] == observed["run_attempt"], "Mixed push context")
    record = next(row for row in observed["inputs"] if row["path"] == ROUTES["release"]["workflow"])
    return {**original_context, "workflow": record["path"], "workflow_sha256": record["sha256"],
            "original_workflow_sha256": original_context["workflow_sha256"],
            "push_authority": observed["authority"], "push_source_binding": observed}


def validate_release_run(run, expected_context):
    """The caller supplies the real GitHub GET response, never local claims."""
    expected = authority("release")
    require(expected_context.get("workflow") == expected["workflow"]
            and expected_context.get("push_authority") == expected,
            "Handoff push authority mismatch")
    require(type(run.get("id")) is int and run["id"] > 0
            and type(run.get("run_attempt")) is int and run["run_attempt"] > 0
            and run["id"] == expected_context["run_id"]
            and run["run_attempt"] == expected_context["run_attempt"]
            and run.get("head_sha") == expected_context["checkout_sha"],
            "Handoff push source/attempt mismatch")
    require(run.get("event") == expected["event"]
            and run.get("path") in (expected["workflow"], expected["workflow"] + "@" + expected["ref"])
            and run.get("head_branch") == expected["ref"].removeprefix("refs/heads/"),
            "Handoff push event/path/ref mismatch")
    for name in ("repository", "head_repository"):
        repository = run.get(name, {})
        require(type(repository.get("id")) is int and repository["id"] == REPOSITORY_ID
                and repository.get("full_name") == REPOSITORY, "Handoff push repository mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=ROUTES, required=True)
    parser.add_argument("--stage", choices=["build", "native", "production"], required=True)
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    prefix = root / ("build/artifacts/runtime27/final-push-" + args.stage)
    output = prefix.with_name(prefix.name + "." + args.phase + ".json")
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {"status": "FINAL_PUSH_SOURCE_REJECTED", "mode": args.mode, "stage": args.stage,
              "phase": args.phase, "observed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "scope": "Source/route admission only; original Swift declaration, build, UI, HID and Release gates remain required",
              "native_execution_claimed": False}
    try:
        require(args.mode == "release" or args.stage == "native", "UI has only the original native job")
        observed = observe_source(root, args.mode)
        report["source"] = observed
        if args.phase == "after":
            before = json.loads(prefix.with_name(prefix.name + ".before.json").read_bytes())
            require(before.get("status") == "FINAL_PUSH_SOURCE_BOUND" and before.get("mode") == args.mode
                    and before.get("stage") == args.stage and before.get("source") == observed,
                    "Missing matching before source receipt or source drift")
        report["status"] = "FINAL_PUSH_SOURCE_BOUND" if args.phase == "before" else "FINAL_PUSH_SOURCE_UNCHANGED"
        return 0
    except Exception as error:
        report["error_type"], report["error"] = type(error).__name__, str(error)
        return 1
    finally:
        output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(json.dumps({key: report[key] for key in ("status", "mode", "stage", "phase", "native_execution_claimed")}))


if __name__ == "__main__":
    raise SystemExit(main())
