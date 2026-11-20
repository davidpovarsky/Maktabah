#!/usr/bin/env python3
"""Exact combined Core194, original Annotation/Cloud/Repository and full-app gate.

Foundation component execution and full application compilation are separately
required. This route executes zero Native UI tests and no live CloudKit.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import subprocess
import sys
import tarfile
import unittest
import urllib.request

def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def load_json(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 32 * 1024 * 1024,
            "Missing, linked or oversized JSON")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    return json.loads(path.read_bytes(), object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Non-finite JSON")))


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, timeout=60)


def exact_file(root, relative):
    require(isinstance(relative, str) and relative == str(PurePosixPath(relative))
            and not relative.startswith("/") and "\\" not in relative
            and all(x not in ("", ".", "..") for x in relative.split("/")), "Unsafe source path")
    path = Path(root)
    for part in relative.split("/"):
        path /= part
        require(not path.is_symlink(), "Linked input: " + relative)
    require(path.is_file(), "Missing input: " + relative)
    return path


def record(root, relative):
    data = exact_file(root, relative).read_bytes()
    return {"bytes": len(data), "sha256": digest(data), "git_blob": blob(data)}


def module(root, path, name):
    spec = importlib.util.spec_from_file_location(name, exact_file(root, path))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def archive_sources(root, observed, path):
    require(not path.exists(), "Preserve existing source archive")
    with tarfile.open(path, "w:gz") as archive:
        for relative, expected in sorted(observed["files"].items()):
            data = exact_file(root, relative).read_bytes()
            require(digest(data) == expected["sha256"], "Source changed while archiving")
            entry = tarfile.TarInfo(relative)
            entry.size, entry.mode, entry.mtime = len(data), 0o644, 0
            archive.addfile(entry, io.BytesIO(data))
        baseline = git(root, "show", BASE + ":" + REPOSITORY_SOURCE)
        require(digest(baseline) == observed["original_repository"]["sha256"], "Baseline object changed")
        entry = tarfile.TarInfo("original-baseline/AnnotationRepository.swift")
        entry.size, entry.mode, entry.mtime = len(baseline), 0o644, 0
        archive.addfile(entry, io.BytesIO(baseline))
    return {"file": path.name, "bytes": path.stat().st_size, "sha256": digest(path.read_bytes()),
            "members": len(observed["files"]) + 1}


def source_report(report, observed, required):
    before, after = report.get("source_before"), report.get("source_after")
    require(isinstance(before, dict) and set(before) == set(required) and before == after and report.get("source_unchanged") is True,
            "Component source closure was not retained unchanged")
    require(all(path in observed["files"] and value == observed["files"][path]["sha256"] for path, value in before.items()),
            "Executed source digest differs")
    require(report.get("source_sha") == observed["identity"]["head_sha"], "Executed checkout differs")


def verify_original_gates(root, observed, outcomes):
    # Reuse the complete immutable C gate. Its authority/source-before function
    # is not invoked or overridden: this new route binds the repaired source.
    # All original result validators, output paths, counts and budgets remain.
    original = module(root, ORIGINAL_VALIDATOR, "unchanged_complete_cloud_result_gate")
    require(original.LOCAL_OUTPUT == LOCAL_OUTPUT and original.EXCHANGE_OUTPUT == EXCHANGE_OUTPUT
            and original.ROUTE_OUTPUT == ORIGINAL_ROUTE_OUTPUT, "Original output contract changed")
    original_controls = load_json(Path(root) / ORIGINAL_ROUTE_OUTPUT / "python-controls/RESULT.json")
    control_module = module(root, ORIGINAL_TESTS, "unchanged_original_cloud_controls")
    expected_count = sum(len(unittest.defaultTestLoader.getTestCaseNames(kind))
                         for kind in (control_module.Results, control_module.SourceAndAuthority))
    require(original_controls.get("status") == "PASS"
            and type(original_controls.get("tests")) is int and original_controls["tests"] == expected_count
            and all(type(original_controls.get(key)) is int and original_controls[key] == 0
                    for key in ("failures", "errors", "skipped", "swift_executed", "apple_executed")),
            "All unchanged original C Python controls must actually pass")
    metadata = load_json(Path(root) / ORIGINAL_BINDING)
    required = set(metadata["source_pins"]) | {ORIGINAL_VALIDATOR, ORIGINAL_TESTS, ORIGINAL_BINDING, ORIGINAL_WORKFLOW}
    require(original_controls.get("source_before") == original_controls.get("source_after")
            == {path: observed["files"][path] for path in required},
            "Original C controls source inputs differ")
    return original.verify_results(root, observed, {key: outcomes[key] for key in
                                                  ("toolchain", "controls", "local", "exchange")})


def verify_race(root, observed):
    race = module(root, DRIVER, "actual_disconnect_result_validator")
    output = Path(root) / RACE_OUTPUT
    report = load_json(output / "RESULT.json")
    require(report.get("status") == "PASS_APPLE_REPOSITORY_RED_AND10_GREEN", "Actual Repository RED/GREEN incomplete")
    require(report.get("core_tree") == CORE_TREE and report.get("source_base") == BASE,
            "Wrong actual baseline or Core")
    require(all(report.get(key) == value for key, value in NO_CLAIMS.items()), "Race scope changed")
    owned = race.owned_directory(output, Path(report["owned_directory"]))
    expected = report.get("compiled_copies_before")
    require(isinstance(expected, dict) and set(expected) == {"DisconnectBaseline", "DisconnectCandidate"}, "Whole executables missing")
    require(race.verify_copies(owned, expected) == expected == report.get("compiled_copies_after"), "Compiled race sources changed")
    cloud = race.load_cloud(root)
    source_report(report, observed, set(cloud.source_provenance(root)) | {DRIVER, FIXTURE})
    source_paths = cloud.SOURCES[:-1] + [FIXTURE]
    for target, pins in expected.items():
        require(set(pins) == set(source_paths) | {"generated:exact_original_fixture_prefix"}, "Incomplete compiled closure")
        for path in source_paths:
            expected_pin = observed["original_repository"] if path == REPOSITORY_SOURCE and target == "DisconnectBaseline" else observed["files"][path]
            require(pins[path] == expected_pin, "Wrong baseline/candidate production input")
        prefix = cloud.fixture_prefix(root)
        require(pins["generated:exact_original_fixture_prefix"] == {"sha256": digest(prefix), "bytes": len(prefix)},
                "Original43 fixture prefix changed")
    commands = report.get("commands", [])
    labels = ["compile", "binary-path", race.BASELINE_NAME, *race.CASES]
    require([row.get("label") for row in commands] == labels, "Exact bounded command sequence missing")
    require(all(row.get("exit_code") == 0 and row.get("timed_out") is False
                and row.get("reaped") and row.get("process_group_gone") for row in commands[:2]), "Race compilation incomplete")
    executable_pins = report.get("executables")
    require(isinstance(executable_pins, dict) and len(executable_pins) == 2
            and executable_pins == report.get("executables_after"), "Both compiled executables must remain unchanged")
    executable_paths = {}
    for text, expected_hash in executable_pins.items():
        path = Path(text)
        require(path.name in ("DisconnectBaseline", "DisconnectCandidate") and path.name not in executable_paths
                and path.is_file() and not path.is_symlink() and owned in path.resolve().parents
                and digest(path.read_bytes()) == expected_hash, "Owned actual executable changed")
        executable_paths[path.name] = str(path)
    pids = [row.get("pid") for row in commands[2:]]
    require(all(type(pid) is int and pid > 0 for pid in pids) and len(set(pids)) == 11,
            "All11 isolated actual execution processes are required")
    for index, row in enumerate(commands[2:]):
        executable = "DisconnectBaseline" if index == 0 else "DisconnectCandidate"
        name = race.BASELINE_NAME if index == 0 else race.CASES[index - 1]
        require(row.get("command") == [executable_paths[executable], name, str(owned / "fixtures" / name)]
                and row.get("timeout_seconds") == (race.BASELINE_TIMEOUT if index == 0 else race.CASE_TIMEOUT),
                "Exact bounded original/candidate invocation differs")
    for row in commands:
        raw = load_json(output / (row["label"] + ".command.json"))
        require(raw == row, "Raw process receipt differs")
        for field, key in (("stdout", "stdout_sha256"), ("stderr", "stderr_sha256")):
            require(row.get(field) == row["label"] + "." + field + ".log"
                    and digest(exact_file(output, row[field]).read_bytes()) == row.get(key), "Raw command log differs")
    fixtures = owned / "fixtures"
    baseline = race.verify_baseline(fixtures / race.BASELINE_NAME, commands[2])
    baseline["cold"] = race.cold_read(fixtures / race.BASELINE_NAME, race.BASELINE_NAME)
    require(baseline == report.get("baseline") == load_json(output / "BASELINE_RED.json"), "Original RED proof differs")
    rows = []
    for name, command in zip(race.CASES, commands[3:], strict=True):
        row = race.verify_candidate(fixtures / name, name, command)
        row["cold"] = race.cold_read(fixtures / name, name)
        rows.append(row)
    require(rows == report.get("cases") == load_json(output / "CASES.json")
            and report.get("verified_green_cases") == 10 and report.get("expected_original_red") is True,
            "All10 actual GREEN cases and expected original RED required")
    return {"status": "PASS_ACTUAL_REPOSITORY_RED_AND10_GREEN", "candidate_green": 10,
            "original_red": 1, "original_red_counts_as_pass": False, "cold_reads": 11}


# This authoring file is assembled with the exact original helper/validator
# functions into the single published executable named SELF below.

REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
BRANCH = "codex/otzaria-annotation-core194-combined-apple-v3-20261120"
WORKFLOW = ".github/workflows/otzaria-annotation-core194-combined-apple-v3.yml"
SELF = "Scripts/CI/annotation-combined-core194-apple.py"
BINDING = "Scripts/CI/annotation-combined-core194-apple.inputs.json"
TESTS = "Scripts/CI/test-annotation-combined-core194-apple.py"
SELECTOR = "Scripts/CI/select-runtime27-toolchain.py"
SOURCE_M = "bd855c02fcef94a732f584c5992aeacec6b1b21d"
SOURCE_TREE = "3c08a3de2102dd80df64f79dd56035a689d26edb"
SOURCE_PARENT = "09214fff31c236a23671b7b5ba2eeb0fa25c8be0"
BASE = "7af3a06d48ccbe77acef180cb99d120971c3804e"
CORE = "Source/Otzaria/Actions"
CORE_TREE = "a89104250c1aedf75e6aa95ed3f111a4dc597217"
DRIVER = "tools/hq-annotation-disconnect-acceptance.py"
CLOUD_DRIVER = "tools/hq-local-annotation-cloud-acceptance.py"
FIXTURE = "Tests/HQ/annotation-disconnect/AnnotationRepositoryDisconnectAcceptance.swift"
REPOSITORY_SOURCE = "Source/Features/Annotations/Database/AnnotationRepository.swift"
LOCAL_OUTPUT = "build/local-annotation-cloud-acceptance"
EXCHANGE_OUTPUT = "build/local-annotation-cloud-exchange-regression"
ORIGINAL_ROUTE_OUTPUT = "build/local-annotation-cloud-route"
ORIGINAL_VALIDATOR = "Scripts/CI/local-annotation-cloud-apple.py"
ORIGINAL_BINDING = "Scripts/CI/local-annotation-cloud-apple.inputs.json"
ORIGINAL_TESTS = "Scripts/CI/test-local-annotation-cloud-apple.py"
ORIGINAL_WORKFLOW = ".github/workflows/otzaria-local-annotation-cloud-apple.yml"
RACE_OUTPUT = "build/annotation-disconnect-acceptance"
RACE_CONTROLS = "Scripts/CI/test-annotation-disconnect-apple.py"
RACE_CONTROL_OUTPUT = "build/annotation-disconnect-route/python-controls"
CORE_DRIVER = "tools/hq-cold-search-core-acceptance.py"
CORE_MANIFEST = "Tests/HQ/cold-search/CORE_INPUTS.json"
CORE_OUTPUT = "build/cold-search-core-apple"
HQ_DRIVER = "Scripts/CI/hq-stage2-focused-apple.py"
HQ_INPUTS = "Scripts/CI/hq-stage2-focused-apple.inputs.json"
ADDITIONS = "Scripts/CI/hq-stage2-otzaria-test-additions.json"
RUNTIME = "Scripts/CI/runtime27.py"
PROJECT = "Maktabah.xcodeproj/project.pbxproj"
CORE_MANAGER = "Source/Core/CloudKit/CloudKitCoreManager.swift"
SYNC_MANAGER = "Source/Core/Database/CloudKitSyncManager.swift"
OUTPUT = "build/annotation-combined-core194"
DOCS = "docs/hq-integration/annotation-combined-core194-apple-v3-20261120/"
OLD_CLOUD_BINDING = DOCS + "reference/original-cloud-binding.json"
PROTECTED_TREES = {
    "Source": "efeee8e2366dfa1155f9c029cff1de5c6441f39b",
    "Vendor": "4065c0e62af325e83a65fe0c70270985229807ae",
    "Maktabah.xcodeproj": "d2a88b3624cfab55682ea68e2634f4b6a7d5533f",
    "Maktabah-iOSUITests": "9be9f4c91114f5daffceac8a8ded0e7314f29fb4",
    CORE: CORE_TREE,
}
COUNTS = {"core_baseline": 20, "core_baseline_passed": 11, "core_baseline_failed": 9,
          "core_candidate": 194, "original_local": 43, "cold_reopens": 2, "owned_cloud": 48,
          "original_deadlock_red": 1, "candidate_green": 10, "original_exchange": 28,
          "exchange_crash_reopens": 2, "original_sql_controls": 13}
BUDGETS = {"core_phase_seconds": 1200, "race_compile_seconds": 480,
           "repository_baseline_seconds": 12, "repository_candidate_seconds": 20,
           "original_full_app_seconds": 4200}
# This dictionary belongs to the original Repository component validator.
# Core194 executes separately and is never inferred from the race component.
NO_CLAIMS = {"native_ui_executed": 0, "cloudkit_transport_executed": 0,
             "anytype_runtime_executed": 0, "physical_device_executed": 0,
             "current_core194_executed": False}
JOBS = {"components": "Core194 and original Annotation Cloud Repository",
        "full_app": "Original full app compile including CloudKit callers"}
MODIFIED = {DRIVER, CORE_DRIVER, CORE_MANIFEST, HQ_INPUTS, ADDITIONS}
ADDED_RUNTIME = {SELF, BINDING, TESTS, WORKFLOW, ORIGINAL_VALIDATOR, ORIGINAL_BINDING, ORIGINAL_TESTS,
                 ORIGINAL_WORKFLOW, "Scripts/CI/annotation-disconnect-apple.py",
                 "Scripts/CI/annotation-disconnect-apple.inputs.json", RACE_CONTROLS}
HISTORICAL_DOC = "docs/hq-integration/annotation-repository-disconnect-20261120/compile-types-v3/REPOSITORY_API.json"


def receipt_name(phase):
    require(phase in ("before", "build", "after", "aggregate"), "Unknown receipt phase")
    return "RESULT_" + phase.upper() + ".json"


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as output:
        output.write(json_bytes(value))


def identity(environment, event):
    ref = "refs/heads/" + BRANCH
    require(environment.get("GITHUB_EVENT_NAME") == "push", "Exact push event required")
    require(environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_REPOSITORY_ID") == str(REPOSITORY_ID), "Wrong repository")
    require(environment.get("GITHUB_REF") == ref
            and environment.get("GITHUB_WORKFLOW_REF") == REPOSITORY + "/" + WORKFLOW + "@" + ref,
            "Wrong branch/workflow")
    head = environment.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[0-9a-f]{40}", head) is not None
            and environment.get("EXPECTED_CHECKOUT_SHA") == head
            and environment.get("GITHUB_WORKFLOW_SHA") == head, "Unbound checkout/workflow SHA")
    run, attempt = environment.get("GITHUB_RUN_ID", ""), environment.get("GITHUB_RUN_ATTEMPT", "")
    require(re.fullmatch(r"[1-9][0-9]*", run) is not None
            and re.fullmatch(r"[1-9][0-9]*", attempt) is not None, "Actual run/attempt required")
    require(isinstance(event, dict) and event.get("ref") == ref and event.get("after") == head
            and event.get("deleted") is False, "Push payload differs")
    repository = event.get("repository", {})
    require(type(repository.get("id")) is int and repository["id"] == REPOSITORY_ID
            and repository.get("full_name") == REPOSITORY and repository.get("fork") is True,
            "Push repository differs")
    return {"repository": REPOSITORY, "branch": BRANCH, "workflow": WORKFLOW, "event": "push",
            "head_sha": head, "run_id": int(run), "run_attempt": int(attempt)}


def validate_binding(binding):
    require(binding.get("schema") == "annotation-core194-combined-apple-v1"
            and binding.get("source_sealed") is True, "UNFINALIZED source cannot execute")
    require(binding.get("application_source") == SOURCE_M and binding.get("application_tree") == SOURCE_TREE
            and binding.get("source_parent") == SOURCE_PARENT and binding.get("core_tree") == CORE_TREE,
            "Wrong combined application/Core source")
    require(binding.get("route") == {"repository": REPOSITORY, "branch": BRANCH, "workflow": WORKFLOW}, "Wrong route")
    require(binding.get("application_trees") == PROTECTED_TREES, "Wrong protected product trees")
    require(binding.get("counts") == COUNTS and all(type(v) is int for v in binding["counts"].values()), "Original counts changed")
    require(binding.get("budgets") == BUDGETS and all(type(v) is int for v in binding["budgets"].values()), "Original budgets changed")
    require(binding.get("api_compatibility") == {
        "required_notification_parameter_no_default": True, "explicit_label_syntax_enforced": False,
        "original_unlabeled_result_call_lines": [506, 853], "full_app_compile_required": True},
        "API source/compile scope changed")
    pins = binding.get("source_pins")
    require(isinstance(pins, dict) and {CORE_DRIVER, CORE_MANIFEST, DRIVER, FIXTURE, HQ_DRIVER, HQ_INPUTS,
            ADDITIONS, CORE_MANAGER, SYNC_MANAGER, PROJECT, SELECTOR, ORIGINAL_BINDING,
            ORIGINAL_VALIDATOR, ORIGINAL_TESTS, ORIGINAL_WORKFLOW, RACE_CONTROLS, OLD_CLOUD_BINDING} <= set(pins),
            "Incomplete execution closure")
    require(binding.get("original_repository") == {
        "bytes": 44176, "sha256": "c3f086003d1667014a50fc996ae3976ebdf3ad82b9b6c9a60484762d6dbc16af",
        "git_blob": "86512a8286560aedb248da4abea1a41f5c96ea0e"}, "Original Repository RED changed")


def validate_delta(rows):
    require(len(rows) == len({path for status, path in rows}), "Duplicate source delta")
    modified = {path for status, path in rows if status == "M"}
    added = {path for status, path in rows if status == "A"}
    require(all(status in ("M", "A") for status, _ in rows), "Removed/renamed/unreviewed source")
    require(modified == MODIFIED, "Unexpected modified application/test/helper source")
    require(ADDED_RUNTIME <= added
            and all(path in ADDED_RUNTIME or path == HISTORICAL_DOC or path.startswith(DOCS) for path in added),
            "Unexpected new runtime source")
    return {path: status for status, path in rows}


def metadata_inverse(root, binding):
    def original(path):
        return git(root, "show", SOURCE_M + ":" + path)
    actual = exact_file(root, DRIVER).read_bytes()
    inverse = actual.replace(('CORE_TREE = "' + CORE_TREE + '"').encode(),
                             b'CORE_TREE = "5d0ee482c8f10726fe3863792dac94c18e94d792"', 1)
    inverse = inverse.replace(b'This gate requires the reviewed combined Core tree',
                              b'This gate qualifies original Core5d0, not a different Core tree', 1)
    require(inverse == original(DRIVER), "Original Repository execution bodies changed")
    actual = exact_file(root, CORE_DRIVER).read_bytes()
    inverse = actual.replace(('WORKFLOW = "' + WORKFLOW + '"').encode(),
                              b'WORKFLOW = ".github/workflows/otzaria-cold-search-core-validation.yml"', 1)
    inverse = inverse.replace(('BRANCH = "refs/heads/' + BRANCH + '"').encode(),
                              b'BRANCH = "refs/heads/codex/otzaria-cold-search-core-apple-v2-20261120"', 1)
    require(inverse == original(CORE_DRIVER), "Original Core execution/classifier changed")
    old = json.loads(original(CORE_MANIFEST)); new = load_json(Path(root) / CORE_MANIFEST)
    expected = copy.deepcopy(old)
    matches = [row for row in expected["support_inputs"] if row["path"] == CORE_DRIVER]
    require(len(matches) == 1, "Core driver pin missing")
    matches[0].update(record(root, CORE_DRIVER))
    require(new == expected, "Original174/twenty/baseline/fixtures changed")
    old = json.loads(original(ADDITIONS)); actual = exact_file(root, ADDITIONS).read_bytes()
    prior = old["excluded_build_inputs"][PROJECT]
    current = binding["source_pins"][PROJECT]["git_blob"]
    require(actual == original(ADDITIONS).replace(prior.encode(), current.encode(), 1),
            "Exact78 vendor test additions changed beyond the project proof pin")
    old = json.loads(original(HQ_INPUTS)); new = load_json(Path(root) / HQ_INPUTS)
    expected = copy.deepcopy(old)
    expected["application_source_sha"] = SOURCE_M
    expected["application_trees"] = {path: PROTECTED_TREES[path] for path in ("Source", "Vendor", "Maktabah.xcodeproj")}
    expected["otzaria_test_additions_sha256"] = digest(actual)
    require(new == expected, "Original SDK/framework/resource/macro/lock inputs changed")
    old = load_json(Path(root) / OLD_CLOUD_BINDING); new = load_json(Path(root) / ORIGINAL_BINDING)
    expected = copy.deepcopy(old)
    expected["reviewed_source_sha"] = SOURCE_M
    expected["core_tree_sha"] = CORE_TREE
    expected["application_trees"] = {path: git(root, "rev-parse", SOURCE_M + ":" + path).decode().strip()
                                     for path in old["application_trees"]}
    expected["source_pins"] = {}
    for path in old["source_pins"]:
        data = git(root, "show", "HEAD:" + path)
        expected["source_pins"][path] = {"bytes": len(data), "sha256": digest(data), "git_blob": blob(data)}
    expected["scope"] = binding["original_validator_metadata_scope"]
    require(new == expected, "Original Cloud result binding changed beyond exact source metadata")
    return {"status": "EXACT_ORIGINAL_BODY_AND_METADATA_INVERSES", "production_changes": 0,
            "Swift_test_changes": 0, "Core_original_cases": 174, "Core_added_cases": 20}


def committed_records(root, paths):
    result = {}
    for row in git(root, "ls-tree", "-r", "-z", "HEAD", "--", *paths).split(b"\0"):
        if not row: continue
        metadata, raw = row.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        if kind != "blob": continue
        path = raw.decode()
        require(mode in ("100644", "100755"), "Linked/special execution input")
        actual = record(root, path)
        require(actual["git_blob"] == oid, "Dirty execution input: " + path)
        result[path] = actual
    require(result, "Empty execution closure")
    return result


def require_complete_core_source_inventory(files, committed_core):
    require(committed_core and all(path.startswith(CORE + "/") for path in committed_core),
            "Whole original Core inventory missing")
    require(all(files.get(path) == expected for path, expected in committed_core.items()),
            "Whole original Core input missing or changed")


def observe(root, environment, scope, phase):
    root = Path(root)
    require(scope in JOBS and phase in ("before", "after"), "Unknown observation scope")
    authority = identity(environment, load_json(environment["GITHUB_EVENT_PATH"]))
    head = authority["head_sha"]
    require(git(root, "rev-parse", "HEAD").decode().strip() == head, "Checkout moved")
    require(git(root, "show", "-s", "--format=%P", "HEAD").decode().strip() == SOURCE_M,
            "Combined validation must be one reviewed CI commit on exact M")
    require(git(root, "rev-parse", SOURCE_M + "^{tree}").decode().strip() == SOURCE_TREE
            and git(root, "show", "-s", "--format=%P", SOURCE_M).decode().strip() == SOURCE_PARENT,
            "Combined API source ancestry differs")
    binding = load_json(exact_file(root, BINDING)); validate_binding(binding)
    changes = validate_delta([tuple(line.split("\t")) for line in
                              git(root, "diff", "--name-status", SOURCE_M, "HEAD").decode().splitlines()])
    trees = {path: git(root, "rev-parse", head + ":" + path).decode().strip() for path in PROTECTED_TREES}
    require(trees == PROTECTED_TREES, "Application/test/SDK/Core trees changed after M")
    if scope == "components" or phase == "before":
        require(not git(root, "status", "--porcelain", "--untracked-files=no"), "Dirty tracked checkout")
    inverses = metadata_inverse(root, binding)
    files = {}
    for relative in sorted(set(binding["source_pins"]) | {SELF, BINDING, TESTS, WORKFLOW}):
        if scope == "full_app" and phase == "after" and relative == PROJECT:
            # Original Pod integration legitimately rewrites the project. Its
            # generated bytes are checked below; retain the original Git pin.
            data = git(root, "show", head + ":" + relative)
            actual = {"bytes": len(data), "sha256": digest(data), "git_blob": blob(data)}
        else:
            actual = record(root, relative)
        require(actual["git_blob"] == git(root, "rev-parse", head + ":" + relative).decode().strip(),
                "Executed source differs from committed input: " + relative)
        if relative in binding["source_pins"]:
            require(actual == binding["source_pins"][relative], "Frozen input differs: " + relative)
        files[relative] = actual
    require_complete_core_source_inventory(files, committed_records(root, [CORE]))
    baseline = git(root, "show", BASE + ":" + REPOSITORY_SOURCE)
    require({"bytes": len(baseline), "sha256": digest(baseline), "git_blob": blob(baseline)} == binding["original_repository"],
            "Original Repository baseline object differs")
    core = module(root, CORE_DRIVER, "combined_original_core_driver")
    require(core.verify_inputs(root, load_json(root / CORE_MANIFEST)), "Core whole-source closure missing")
    cloud = module(root, ORIGINAL_VALIDATOR, "combined_original_cloud_gate")
    names = cloud.declared_cases(root)
    race = module(root, DRIVER, "combined_original_repository_driver")
    names["disconnect"] = race.declaration_names(exact_file(root, FIXTURE).read_text())
    require(names == binding["case_names"], "Original component declarations changed")
    execution = committed_records(root, ["Scripts/CI", "tools", ".github/workflows", "Maktabah-iOSUITests",
                                         "Tests/HQ", DOCS, HISTORICAL_DOC])
    product_audit = None
    if scope == "full_app" and phase == "after":
        report = load_json(root / "build/hq-stage2/result.json")
        hq = module(root, HQ_DRIVER, "original_full_app_post_build_validator")
        hq.verify_actual_sources(report)
        native = report.get("native_context", {})
        require(record(root, PROJECT)["sha256"] == native.get("generated_project_sha256"), "Generated Pod project changed")
        require(record(root, "Maktabah.xcworkspace/contents.xcworkspacedata")["sha256"] == native.get("workspace_sha256"),
                "Generated original workspace changed")
        hq.prepare_original_hanlin(load_json(root / HQ_INPUTS), report, verify_only=True)
        product_audit = {"actual_source_inputs_verified": report["actual_source_inputs_verified"],
                         "actual_package_checkouts": report["actual_package_checkouts"],
                         "generated_project_sha256": native["generated_project_sha256"],
                         "workspace_sha256": native["workspace_sha256"],
                         "original_hanlin_after": report["hanlin_sdk_source"],
                         "actual_legacy_callers": {path: record(root, path) for path in (CORE_MANAGER, SYNC_MANAGER)}}
        write_new(root / OUTPUT / scope / "original-post-build-input-audit.json", report)
    return {"identity": authority, "application_source": SOURCE_M, "application_tree": SOURCE_TREE,
            "application_trees": trees, "core_tree": CORE_TREE, "source_base": BASE,
            "source_inventory_sha256": digest(json_bytes(files)), "files": files,
            "case_names": names, "changed_paths": changes, "original_repository": binding["original_repository"],
            "execution_inputs": execution, "metadata_inverses": inverses, "post_build_product_audit": product_audit,
            "checkout_root": str(root.resolve()), "scope": scope, "native_ui_executed": 0}


def comparable_source(observation):
    result = copy.deepcopy(observation)
    result.pop("post_build_product_audit", None)
    return result


def verify_core(root, observed, core_output=None):
    root = Path(root); output = Path(core_output) if core_output else root / CORE_OUTPUT
    core = module(root, CORE_DRIVER, "unchanged_complete_core_result_classifier")
    manifest = load_json(root / CORE_MANIFEST)
    report = load_json(output / "RESULT.json")
    require(report.get("status") == "PASS_APPLE_CORE_194_WITH_BASELINE20_RED"
            and report.get("git_head") == observed["identity"]["head_sha"]
            and report.get("inputs_sha256") == observed["files"][CORE_MANIFEST]["sha256"], "Core actual run/source failed")
    context = observed["identity"]
    expected_github = {"GITHUB_REPOSITORY": REPOSITORY, "GITHUB_REF": "refs/heads/" + BRANCH,
                       "GITHUB_SHA": context["head_sha"], "GITHUB_RUN_ID": str(context["run_id"]),
                       "GITHUB_RUN_ATTEMPT": str(context["run_attempt"]), "GITHUB_JOB": "components"}
    require(report.get("github") == expected_github, "Core report from another job/run/attempt")
    require(report.get("declared_original") == 174 and report.get("declared_added") == 20
            and report.get("actual_xctest_completed") == 214
            and report.get("native_ui_executed") == 0 and report.get("actual_c_engine_executed") == 0,
            "Core count or scope changed")
    before = load_json(output / "source-before.json")
    require(before == load_json(output / "source-after.json") == core.verify_inputs(root, manifest), "Core input source changed")
    require(set(report.get("stages", {})) == {"baseline20", "candidate194"}, "Core phase missing")
    summaries = {}
    for name in ("baseline20", "candidate194"):
        expected = ({case: "passed" for case in manifest["baseline_expected_pass"]} |
                    {case: "failed" for case in manifest["baseline_expected_fail"]}) if name == "baseline20" else {
                        case: "passed" for case in manifest["original_cases"] + manifest["added_cases"]}
        stage = load_json(output / (name + ".result.json")); process = stage.get("process", {})
        raw = exact_file(output, name + ".log").read_bytes()
        require(process.get("log_sha256") == digest(raw), "Core raw log changed")
        qualified = core.classify_run(process, core.parse_xctest(raw.decode("utf-8", errors="replace")), expected)
        require(qualified["qualified"] is True, "Core actual completed leaves failed")
        expected_sources = {row["path"]: row["sha256"] for row in manifest["core_inputs"]}
        if name == "baseline20":
            expected_sources[core.EXECUTOR] = manifest["baseline_executor"]["sha256"]
        require(load_json(output / (name + ".source-before.json")) == expected_sources
                == load_json(output / (name + ".source-after.json")), "Core copied phase sources changed")
        require(stage == {"process": process, **qualified, "source_unchanged": True} == report["stages"][name],
                "Core result differs from actual raw classifier")
        checkout = Path(observed["checkout_root"])
        work = checkout / CORE_OUTPUT / "exact-source-work"
        command = ["xcrun", "swift", "test", "--package-path", str(work / CORE),
                   "--scratch-path", str(checkout / CORE_OUTPUT / "swiftpm-cache"), "--jobs", "1", "--disable-swift-testing"]
        if name == "baseline20": command += ["--filter", "ColdSearchExecutionOfflineTests"]
        require(process.get("command") == command and process.get("cwd") == str(checkout), "Core original invocation changed")
        summaries[name] = {key: qualified[key] for key in ("qualified", "actual_completed", "passed", "failed", "skipped")}
    return {"status": "PASS_ACTUAL_CORE194_AND_EXPECTED_BASELINE20", "stages": summaries,
            "baseline_is_expected_red_not_product_pass": True, "raw_result_sha256": digest((output / "RESULT.json").read_bytes())}


def verify_python_controls(root):
    result = load_json(Path(root) / OUTPUT / "components/python-controls/RESULT.json")
    controls = module(root, TESTS, "combined_actual_control_inventory")
    expected = controls.case_names()
    require(result.get("status") == "PASS_PYTHON_ROUTE_CONTROLS" and result.get("names") == expected
            and [row.get("name") for row in result.get("cases", [])] == expected
            and all(row.get("status") == "PASS" for row in result["cases"])
            and result.get("executed") == len(expected)
            and all(type(result.get(key)) is int and result[key] == 0 for key in ("failures", "errors", "skips", "Swift_executed", "Native_executed")),
            "Combined Python controls incomplete")
    race = load_json(Path(root) / RACE_CONTROL_OUTPUT / "RESULT.json")
    old = module(root, RACE_CONTROLS, "unchanged_repository_control_inventory")
    names = old.case_names()
    require(race.get("status") == "PASS_PYTHON_ADMISSION_COLLECTION_CONTROLS"
            and race.get("expected_names") == names and [row.get("name") for row in race.get("cases", [])] == names
            and all(row.get("status") == "PASS" for row in race["cases"])
            and race.get("executed") == len(names) == 26
            and all(race.get(key) == 0 for key in ("failures", "errors", "skips", "actual_swift_cases", "actual_repository_races", "native_ui_executed")),
            "Unchanged original26 Repository Python controls incomplete")
    return {"combined": len(expected), "original_repository": 26}


def original_build(root, observed):
    require(sys.platform == "darwin", "Full app requires original Apple runner")
    root = Path(root)
    runtime = module(root, RUNTIME, "original_runtime_build_supervisor")
    runtime.OUT.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, HQ_DRIVER, "--build-for-testing", "--derived-data", "build/DerivedData"]
    report = {"status": "FAILED", "identity": observed["identity"], "application_source": SOURCE_M,
              "command": command, "timeout_seconds": 4200, "supervisor": RUNTIME,
              "native_ui_executed": 0, "started_at": dt.datetime.now(dt.timezone.utc).isoformat()}
    try:
        code = runtime.run_logged(command, "build-for-testing-driver.log", 4200)
        report.update(exit_code=code, timed_out=False)
        require(code == 0, "Original full-app build failed")
        report["status"] = "ORIGINAL_BUILD_DRIVER_EXIT_ZERO"
    except BaseException as error:
        report.update(error=type(error).__name__, timed_out=isinstance(error, subprocess.TimeoutExpired))
        raise
    finally:
        report["completed_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        log = root / "build/artifacts/runtime27/build-for-testing-driver.log"
        if log.is_file(): report["log_sha256"] = digest(log.read_bytes())
        write_new(root / OUTPUT / "full_app/BUILD_PROCESS.json", report)


def verify_full_app(root, observed):
    root = Path(root)
    process = load_json(root / OUTPUT / "full_app/BUILD_PROCESS.json")
    require(process.get("status") == "ORIGINAL_BUILD_DRIVER_EXIT_ZERO" and process.get("exit_code") == 0
            and process.get("timed_out") is False and process.get("timeout_seconds") == 4200
            and process.get("identity") == observed["identity"] and process.get("application_source") == SOURCE_M
            and process.get("native_ui_executed") == 0, "Original full-app process did not complete")
    require(process.get("command", [])[1:] == [HQ_DRIVER, "--build-for-testing", "--derived-data", "build/DerivedData"]
            and process.get("supervisor") == RUNTIME, "Original full-app command/supervisor differs")
    log = exact_file(root, "build/artifacts/runtime27/build-for-testing-driver.log").read_bytes()
    require(process.get("log_sha256") == digest(log), "Original build log changed")
    result = load_json(root / "build/hq-stage2/result.json")
    require(result.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and result.get("scope") == "SIMULATOR_BUILD_FOR_REAL_UI"
            and result.get("signing") == "SIMULATOR_AD_HOC_ONLY"
            and result.get("checkout_sha") == observed["identity"]["head_sha"]
            and result.get("application_source_sha") == SOURCE_M
            and result.get("application_trees") == {path: PROTECTED_TREES[path] for path in ("Source", "Vendor", "Maktabah.xcodeproj")},
            "Original full-app build/source gates failed")
    require(result.get("validator_sha256") == observed["files"][HQ_DRIVER]["sha256"]
            and result.get("inputs_sha256") == observed["files"][HQ_INPUTS]["sha256"], "Unbound original app helper")
    actual_paths = {str((root / path).resolve()): path for path in (CORE_MANAGER, SYNC_MANAGER)}
    matched = []
    retained = root / OUTPUT / "full_app/swift-file-lists"
    for path in sorted((root / "build/DerivedData/Build").rglob("*.SwiftFileList")):
        require(not path.is_symlink() and path.stat().st_size <= 16 * 1024 * 1024, "Unsafe Swift file list")
        data = path.read_bytes()
        values = []
        for line in data.decode("utf-8").splitlines():
            if line.strip(): values.extend(shlex.split(line))
        if set(actual_paths) <= set(values):
            relative = path.relative_to(root).as_posix()
            target = retained / (str(len(matched)) + ".SwiftFileList")
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as output: output.write(data)
            matched.append({"actual_path": relative, "retained_path": str(target.relative_to(root)),
                            "bytes": len(data), "sha256": digest(data),
                            "actual_original_sources": {p: observed["files"][p] for p in actual_paths.values()}})
    require(matched, "Original full-app compiler did not list both actual CloudKit source files")
    write_new(root / OUTPUT / "full_app/ACTUAL_CALLER_COMPILE_INPUTS.json", matched)
    return {"status": "PASS_ORIGINAL_FULL_APP_COMPILE", "source": SOURCE_M,
            "original_caller_lines": [506, 853], "actual_file_lists": matched,
            "app_result_sha256": digest((root / "build/hq-stage2/result.json").read_bytes()),
            "native_ui_executed": 0}


def pack_raw(root, scope, output):
    """Retain exact raw evidence, including empty marker dirs and both binaries.

    Compiler caches/dependency artifacts are excluded. Packing never executes a
    binary or changes its bytes and cannot qualify a failed execution.
    """
    root = Path(root); output = Path(output)
    paths = set()
    binary_pins = {}
    def add_tree(relative):
        directory = root / relative
        if directory.exists():
            paths.add(directory)
            paths.update(directory.rglob("*"))
    def add_pattern(relative, pattern):
        directory = root / relative
        if directory.is_dir(): paths.update(directory.glob(pattern))
    for pattern in ("*.json", "*.tar.gz", "*.log"):
        add_pattern(OUTPUT + "/" + scope, pattern)
    if scope == "components":
        add_tree(OUTPUT + "/components/python-controls")
        add_tree("build/annotation-disconnect-route/python-controls")
        add_tree(ORIGINAL_ROUTE_OUTPUT)
        for relative in (LOCAL_OUTPUT, EXCHANGE_OUTPUT, RACE_OUTPUT):
            add_pattern(relative, "*.json"); add_pattern(relative, "*.log")
            for owned in (root / relative).glob("owned-*"):
                if not owned.is_dir(): continue
                for suffix in ("fixtures", "cloud-fixtures", "package/Sources"):
                    add_tree(str((owned / suffix).relative_to(root)))
                if (owned / "package/Package.swift").is_file(): paths.add(owned / "package/Package.swift")
        for pattern in ("*.json", "*.log", "SOURCE_INPUTS.zip"):
            add_pattern(CORE_OUTPUT, pattern)
        race = root / RACE_OUTPUT / "RESULT.json"
        if race.is_file():
            report = load_json(race)
            for text, expected in report.get("executables", {}).items():
                path = Path(text)
                require(path.resolve().is_relative_to((root / RACE_OUTPUT).resolve()), "Unowned binary evidence")
                require(path.is_file() and not path.is_symlink(), "Declared actual executable was not retained")
                paths.add(path); binary_pins[path] = expected
            if report.get("status") == "PASS_APPLE_REPOSITORY_RED_AND10_GREEN":
                owned = Path(report["owned_directory"])
                names = ["baseline-deadlock", *load_json(root / BINDING)["case_names"]["disconnect"]]
                for name in names:
                    marker = owned / "fixtures" / name / "markers"
                    require(marker.is_dir() and not marker.is_symlink() and marker in paths,
                            "Actual empty/nonempty marker directory was not retained")
    else:
        for pattern in ("*.json", "*.log", "*.diff", "*.pbxproj", "*.resolved", "*.lock", "*.swift"):
            add_pattern("build/hq-stage2", pattern)
        add_tree(OUTPUT + "/full_app/swift-file-lists")
        for pattern in ("build-for-testing-driver.log", "build-for-testing-driver.log.interrupted.json"):
            add_pattern("build/artifacts/runtime27", pattern)
    paths.discard(output)
    paths = {p for p in paths if p.name != "RAW_MANIFEST.json" and not p.name.startswith("RESULT_")}
    rows = []
    require(not output.exists(), "Preserve existing raw archive")
    with tarfile.open(output, "w:gz") as archive:
        for path in sorted(paths):
            require(path.resolve().is_relative_to(root.resolve()) and not path.is_symlink(), "Linked/escaped raw evidence")
            relative = path.relative_to(root).as_posix()
            if path.is_dir():
                info = tarfile.TarInfo(relative); info.type = tarfile.DIRTYPE; info.mode = 0o755
                archive.addfile(info); rows.append({"path": relative, "type": "directory"})
            else:
                require(path.is_file(), "Special raw evidence")
                data = path.read_bytes()
                require(len(data) <= 256 * 1024 * 1024, "Unbounded individual raw evidence")
                if path in binary_pins:
                    require(digest(data) == binary_pins[path], "Actual executable changed before evidence retention")
                info = tarfile.TarInfo(relative); info.size = len(data); info.mode = path.stat().st_mode & 0o777
                archive.addfile(info, io.BytesIO(data))
                rows.append({"path": relative, "type": "file", "mode": info.mode,
                             "bytes": len(data), "sha256": digest(data)})
    return {"archive": output.name, "bytes": output.stat().st_size, "sha256": digest(output.read_bytes()),
            "members": rows, "scope": "RAW_ONLY; no result credit from packaging"}


def unpack_raw(artifact, destination):
    artifact, destination = Path(artifact), Path(destination)
    manifest = load_json(artifact / "RAW_MANIFEST.json")
    archive = exact_file(artifact, manifest["archive"])
    require(archive.stat().st_size == manifest["bytes"] and digest(archive.read_bytes()) == manifest["sha256"],
            "Raw artifact archive changed")
    destination.mkdir(parents=True, exist_ok=False)
    expected = manifest["members"]
    require(len(expected) == len({row["path"] for row in expected}), "Duplicate raw path")
    with tarfile.open(archive, "r:gz") as source:
        members = source.getmembers()
        require([item.name for item in members] == [row["path"] for row in expected], "Raw member inventory differs")
        for item, row in zip(members, expected, strict=True):
            name = item.name; pure = PurePosixPath(name)
            require(str(pure) == name and not pure.is_absolute() and ".." not in pure.parts and "\\" not in name,
                    "Unsafe raw archive member")
            target = destination / name
            require(target.resolve().is_relative_to(destination.resolve()), "Raw member escaped")
            if row["type"] == "directory":
                require(item.isdir(), "Raw directory type changed"); target.mkdir(parents=True, exist_ok=True)
            else:
                require(item.isfile() and item.size == row["bytes"] and item.mode == row["mode"] and item.size <= 256 * 1024 * 1024,
                        "Raw file type/size changed")
                data = source.extractfile(item).read()
                require(digest(data) == row["sha256"], "Raw file changed")
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as output: output.write(data)
    return manifest


def verify_retained_repository(raw_root, observed, binding):
    """Inspect retained bytes/directories only; never execute an Apple binary."""
    raw_root = Path(raw_root)
    report = load_json(raw_root / RACE_OUTPUT / "RESULT.json")
    pins = report.get("executables")
    require(report.get("status") == "PASS_APPLE_REPOSITORY_RED_AND10_GREEN"
            and isinstance(pins, dict) and len(pins) == 2 and pins == report.get("executables_after"),
            "Actual producer executable hash gates missing")
    original_root = Path(observed["checkout_root"])
    rows = {}
    for text, expected in pins.items():
        path = Path(text)
        require(path.name in ("DisconnectBaseline", "DisconnectCandidate") and path.name not in rows
                and path.is_relative_to(original_root / RACE_OUTPUT), "Unowned/ambiguous recorded executable path")
        relative = path.relative_to(original_root).as_posix()
        data = exact_file(raw_root, relative).read_bytes()
        require(digest(data) == expected, "Retained actual executable bytes differ")
        rows[path.name] = {"path": relative, "bytes": len(data), "sha256": expected}
    owned = Path(report["owned_directory"])
    require(owned.is_relative_to(original_root / RACE_OUTPUT), "Unowned recorded fixture root")
    relative_owned = owned.relative_to(original_root)
    names = ["baseline-deadlock", *binding["case_names"]["disconnect"]]
    require(len(names) == len(set(names)) == 11, "Original eleven marker directories required")
    for name in names:
        path = raw_root / relative_owned / "fixtures" / name / "markers"
        require(path.is_dir() and not path.is_symlink(), "Original empty/nonempty marker directory missing")
    return {"actual_Apple_binary_bytes": rows, "original_marker_directories": 11,
            "Apple_executables_executed_on_aggregate": 0,
            "scope": "Retention integrity only; full unchanged verify_race ran on the Apple producer"}


def validate_job(job, context, scope):
    require(job.get("name") == JOBS[scope] and type(job.get("id")) is int and job["id"] > 0
            and job.get("run_id") == context["run_id"] and job.get("run_attempt") == context["run_attempt"]
            and job.get("head_sha") == context["head_sha"] and job.get("head_branch") == BRANCH,
            "Wrong actual producer job identity")
    require(job.get("status") == "completed" and job.get("conclusion") == "success"
            and job.get("started_at") and job.get("completed_at"), "Actual required job failed/incomplete")
    required = ("Require complete Core and original component gates", "Retain exact raw component evidence") if scope == "components" else (
        "Require original full app and unchanged source", "Retain actual full app compile evidence")
    for name in required:
        rows = [step for step in job.get("steps", []) if step.get("name") == name]
        require(len(rows) == 1 and rows[0].get("status") == "completed" and rows[0].get("conclusion") == "success",
                "Actual producer gate/upload step did not succeed")
    return {key: job[key] for key in ("id", "name", "run_id", "run_attempt", "head_sha", "started_at", "completed_at", "conclusion")}


def fetch_jobs(context):
    url = f"https://api.github.com/repos/{REPOSITORY}/actions/runs/{context['run_id']}/attempts/{context['run_attempt']}/jobs?per_page=100"
    token = os.environ.get("GH_TOKEN", "")
    require(token, "Read-only GitHub job authority required")
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"})
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            raise ValueError("GitHub metadata redirect refused")
    opener = urllib.request.build_opener(NoRedirect())
    with opener.open(request, timeout=60) as response:
        data = response.read(8 * 1024 * 1024 + 1)
    require(len(data) <= 8 * 1024 * 1024, "Oversized job metadata")
    result = json.loads(data)
    require(result.get("total_count") == len(result.get("jobs", [])) < 100, "Incomplete job metadata page")
    return result


def validate_aggregate(before, after, jobs, context, outcomes):
    require(set(before) == set(after) == set(JOBS), "Both independent required scopes are required")
    require(outcomes == {scope: "success" for scope in JOBS}, "A required job did not succeed")
    shared = None
    qualified = {}
    for scope in JOBS:
        first, last = before[scope], after[scope]
        require(first.get("status") == "SOURCE_BOUND_NOT_EXECUTED"
                and last.get("status") == ("PASS_CORE194_ALL_ORIGINAL_COMPONENTS" if scope == "components" else "PASS_ORIGINAL_FULL_APP_COMPILE"),
                "Missing/partial/unqualified producer receipt")
        source = last.get("source", {})
        require(source.get("identity") == context and source.get("scope") == scope
                and source.get("application_source") == SOURCE_M and source.get("core_tree") == CORE_TREE,
                "Producer receipt from another source/run/scope")
        require(comparable_source(first.get("source", {})) == comparable_source(source), "Source changed during producer execution")
        projection = {key: source.get(key) for key in ("identity", "application_source", "application_tree", "application_trees",
                                                       "core_tree", "files", "execution_inputs", "case_names", "changed_paths")}
        if shared is None: shared = projection
        require(projection == shared, "Two jobs did not execute the exact same frozen inputs")
        matches = [job for job in jobs if job.get("name") == JOBS[scope]]
        require(len(matches) == 1, "Missing/duplicate actual producer job")
        qualified[scope] = validate_job(matches[0], context, scope)
        if scope == "components":
            require(last.get("core", {}).get("status") == "PASS_ACTUAL_CORE194_AND_EXPECTED_BASELINE20"
                    and last.get("original_gates", {}).get("local_cases") == 43
                    and last["original_gates"].get("cloud_cases") == 48
                    and last["original_gates"].get("local_cold_reopen_gates") == 2
                    and last["original_gates"].get("exchange_cases") == 28
                    and last["original_gates"].get("exchange_abrupt_process_reopen_gates") == 2
                    and last.get("race_gates") == {"status": "PASS_ACTUAL_REPOSITORY_RED_AND10_GREEN", "candidate_green": 10,
                        "original_red": 1, "original_red_counts_as_pass": False, "cold_reads": 11},
                    "Incomplete original component/race receipt")
        else:
            require(last.get("app", {}).get("status") == "PASS_ORIGINAL_FULL_APP_COMPILE"
                    and last["app"].get("actual_file_lists") and source.get("post_build_product_audit"),
                    "Full app actual caller/source audit missing")
    require(len({row["id"] for row in qualified.values()}) == 2, "Two distinct producer jobs required")
    return qualified


def read_producer_receipts(artifact_root):
    before, after = {}, {}
    for scope in JOBS:
        directory = Path(artifact_root) / scope
        before[scope] = load_json(directory / receipt_name("before"))
        after[scope] = load_json(directory / receipt_name("after"))
    return before, after


def aggregate(root, artifact_root, output):
    root, artifact_root, output = Path(root), Path(artifact_root), Path(output)
    context = identity(os.environ, load_json(os.environ["GITHUB_EVENT_PATH"]))
    binding = load_json(root / BINDING); validate_binding(binding)
    before, after = read_producer_receipts(artifact_root)
    raw = {}
    for scope in JOBS:
        artifact = artifact_root / scope
        raw[scope] = output / ("raw-" + scope)
        unpack_raw(artifact, raw[scope])
        require(after[scope].get("raw_archive") == load_json(artifact / "RAW_MANIFEST.json"), "Producer/raw manifest differs")
    jobs = fetch_jobs(context)
    write_new(output / "ACTUAL_JOBS.json", jobs)
    outcomes = {scope: os.environ.get("COMBINED_" + scope.upper() + "_JOB_RESULT") for scope in JOBS}
    qualified = validate_aggregate(before, after, jobs["jobs"], context, outcomes)
    # Replay the unchanged original XCTest parser against actual raw leaves.
    core = verify_core(root, after["components"]["source"], raw["components"] / CORE_OUTPUT)
    require(core == after["components"]["core"], "Raw Core evidence disagrees with the complete Apple producer gate")
    retained_race = verify_retained_repository(raw["components"], after["components"]["source"], binding)
    for scope in JOBS:
        source = after[scope]["source"]
        require(source["files"] == {path: record(root, path) for path in source["files"]}, "Artifact source differs from aggregate checkout")
    app_raw = raw["full_app"]
    actual_app = load_json(app_raw / "build/hq-stage2/result.json")
    require(actual_app.get("status") == "SIMULATOR_BUILD_FOR_REAL_UI_PASS"
            and digest((app_raw / "build/hq-stage2/result.json").read_bytes()) == after["full_app"]["app"]["app_result_sha256"],
            "Actual full-app raw result differs")
    for row in after["full_app"]["app"]["actual_file_lists"]:
        data = exact_file(app_raw, row["retained_path"]).read_bytes()
        require(len(data) == row["bytes"] and digest(data) == row["sha256"], "Actual caller compiler list changed")
    return {"status": "PASS_CORE194_ORIGINAL_COMPONENTS_AND_FULL_APP_COMPILE", "identity": context,
            "application_source": SOURCE_M, "core_tree": CORE_TREE, "qualified_jobs": qualified,
            "core": core, "original_components": after["components"]["original_gates"],
            "Repository": after["components"]["race_gates"], "full_app": after["full_app"]["app"],
            "Repository_retention": retained_race,
            "native_ui_executed": 0, "live_cloudkit_executed": 0, "physical_device_executed": 0,
            "offline_component_replay_scope": "Apple complete unchanged validators ran in producer; Linux checks authenticated raw receipts/source, not Apple execution"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("before", "build", "after", "aggregate"), required=True)
    parser.add_argument("--scope", choices=("components", "full_app", "aggregate"), required=True)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--artifacts", type=Path)
    args = parser.parse_args(); root = args.root.resolve()
    require((args.phase == "aggregate") == (args.scope == "aggregate"), "Aggregate phase/scope mismatch")
    require(args.phase != "build" or args.scope == "full_app", "Build phase belongs to full app only")
    output = root / OUTPUT / args.scope; output.mkdir(parents=True, exist_ok=True)
    destination = output / receipt_name(args.phase)
    require(not destination.exists(), "Preserve prior attempt receipt")
    report = {"status": "FAILED", "scope": args.scope, "phase": args.phase,
              "observed_at": dt.datetime.now(dt.timezone.utc).isoformat(), "native_ui_executed": 0}
    try:
        if args.phase == "aggregate":
            require(args.artifacts is not None, "Both downloaded artifacts required")
            report.update(aggregate(root, args.artifacts, output))
        elif args.phase == "build":
            before = load_json(output / receipt_name("before"))
            require(before.get("status") == "SOURCE_BOUND_NOT_EXECUTED", "Source admission missing")
            original_build(root, before["source"])
            report["status"] = "ORIGINAL_BUILD_DRIVER_EXIT_ZERO"
        else:
            observed = observe(root, os.environ, args.scope, args.phase)
            report["source"] = observed
            # The post-build generated project is retained by the original
            # helper; archive the original inputs before, all unchanged inputs
            # after components. Full-app post source is its original audit.
            if args.phase == "before" or args.scope == "components":
                report["source_archive"] = archive_sources(root, observed, output / ("source-" + args.phase + ".tar.gz"))
            if args.phase == "before":
                report["status"] = "SOURCE_BOUND_NOT_EXECUTED"
            else:
                before = load_json(output / receipt_name("before"))
                require(before.get("status") == "SOURCE_BOUND_NOT_EXECUTED"
                        and comparable_source(before.get("source", {})) == comparable_source(observed), "Before/after source changed")
                required = ("toolchain", "controls", "core", "local", "exchange", "race") if args.scope == "components" else (
                    "toolchain", "node", "ruby", "build")
                outcomes = {name: os.environ.get("COMBINED_" + name.upper() + "_OUTCOME") for name in required}
                report["outcomes"] = outcomes
                require(all(value == "success" for value in outcomes.values()), "Missing/failed required execution stage")
                if args.scope == "components":
                    report["python_controls"] = verify_python_controls(root)
                    report["core"] = verify_core(root, observed)
                    report["original_gates"] = verify_original_gates(root, observed, outcomes)
                    report["race_gates"] = verify_race(root, observed)
                    report["status"] = "PASS_CORE194_ALL_ORIGINAL_COMPONENTS"
                else:
                    report["app"] = verify_full_app(root, observed)
                    report["status"] = "PASS_ORIGINAL_FULL_APP_COMPILE"
    except Exception as error:
        report["error"] = repr(error)
        print(repr(error), flush=True)
    finally:
        if args.phase == "after":
            try:
                raw = pack_raw(root, args.scope, output / "RAW_EVIDENCE.tar.gz")
                write_new(output / "RAW_MANIFEST.json", raw)
                report["raw_archive"] = raw
            except Exception as packing_error:
                report["status"] = "FAILED"
                report["raw_retention_error"] = repr(packing_error)
        write_new(destination, report)
        print(json.dumps({"scope": args.scope, "phase": args.phase, "status": report["status"], "native_ui_executed": 0}))
    return 1 if report["status"] == "FAILED" else 0


if __name__ == "__main__":
    raise SystemExit(main())
