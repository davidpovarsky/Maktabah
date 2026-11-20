#!/usr/bin/env python3
"""Exact-branch Apple gate: original Repository RED, repaired10, local43/cold2/cloud48."""
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
import subprocess
import tarfile
import unittest

REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
BRANCH = "codex/otzaria-annotation-disconnect-apple-v3-reviewed-20261120"
WORKFLOW = ".github/workflows/otzaria-annotation-disconnect-apple.yml"
SELF = "Scripts/CI/annotation-disconnect-apple.py"
BINDING = "Scripts/CI/annotation-disconnect-apple.inputs.json"
TESTS = "Scripts/CI/test-annotation-disconnect-apple.py"
SELECTOR = "Scripts/CI/select-runtime27-toolchain.py"
DRIVER = "tools/hq-annotation-disconnect-acceptance.py"
CLOUD_DRIVER = "tools/hq-local-annotation-cloud-acceptance.py"
ORIGINAL_DRIVER = "tools/hq-local-annotation-editor-acceptance.py"
FIXTURE = "Tests/HQ/annotation-disconnect/AnnotationRepositoryDisconnectAcceptance.swift"
REPOSITORY_SOURCE = "Source/Features/Annotations/Database/AnnotationRepository.swift"
BASE = "7af3a06d48ccbe77acef180cb99d120971c3804e"
PREVIOUS_SOURCE_M = "939eaf3a5b56fe604354b235579cf7aa4a60e3d4"
SOURCE_M = "1e55f6012a1b8cedd674349106f27b0e0e476a0b"
CORE = "Source/Otzaria/Actions"
CORE_TREE = "5d0ee482c8f10726fe3863792dac94c18e94d792"
OUTPUT = "build/annotation-disconnect-route"
LOCAL_OUTPUT = "build/local-annotation-cloud-acceptance"
EXCHANGE_OUTPUT = "build/local-annotation-cloud-exchange-regression"
ORIGINAL_ROUTE_OUTPUT = "build/local-annotation-cloud-route"
ORIGINAL_VALIDATOR = "Scripts/CI/local-annotation-cloud-apple.py"
ORIGINAL_BINDING = "Scripts/CI/local-annotation-cloud-apple.inputs.json"
ORIGINAL_TESTS = "Scripts/CI/test-local-annotation-cloud-apple.py"
ORIGINAL_WORKFLOW = ".github/workflows/otzaria-local-annotation-cloud-apple.yml"
SQL_CONTROLS = "tools/test-local-cloud-pending-sql.py"
RACE_OUTPUT = "build/annotation-disconnect-acceptance"
DOCS = "docs/hq-integration/annotation-repository-disconnect-20261120/"
NEW_FILES = (WORKFLOW, SELF, BINDING, TESTS)
SOURCE_FILES = (REPOSITORY_SOURCE, DRIVER, FIXTURE)
APPLICATION_ROOTS = ("Maktabah.xcodeproj", "Source", "Tests", "tools")
NO_CLAIMS = {"native_ui_executed": 0, "cloudkit_transport_executed": 0,
             "anytype_runtime_executed": 0, "physical_device_executed": 0,
             "current_core194_executed": False}


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


def identity(environment, event):
    ref = "refs/heads/" + BRANCH
    require(environment.get("GITHUB_EVENT_NAME") == "push", "Only the reviewed push event is admitted")
    require(environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_REPOSITORY_ID") == str(REPOSITORY_ID), "Wrong repository")
    require(environment.get("GITHUB_REF") == ref
            and environment.get("GITHUB_WORKFLOW_REF") == REPOSITORY + "/" + WORKFLOW + "@" + ref,
            "Wrong branch or workflow")
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
    return {"repository": REPOSITORY, "branch": BRANCH, "workflow": WORKFLOW,
            "event": "push", "head_sha": head, "run_id": int(run), "run_attempt": int(attempt)}


def validate_binding(binding):
    require(binding.get("schema") == "annotation-disconnect-apple-v1"
            and binding.get("route") == {"repository": REPOSITORY, "branch": BRANCH, "workflow": WORKFLOW},
            "Wrong source binding")
    require(binding.get("source_base") == BASE and binding.get("core_tree") == CORE_TREE,
            "Wrong original source/Core; this is not Core194")
    require(re.fullmatch(r"[0-9a-f]{40}", SOURCE_M) is not None and SOURCE_M != "0" * 40
            and binding.get("application_source") == SOURCE_M,
            "Final repaired source commit must precede the CI binding")
    require(binding.get("source_sealed") is True, "Draft source cannot execute")
    require(binding.get("counts") == {"original_local": 43, "cold_reopens": 2, "owned_cloud": 48,
                                      "original_deadlock_red": 1, "candidate_green": 10, "original_exchange": 28,
                                      "exchange_crash_reopens": 2, "original_sql_controls": 13},
            "Complete original/new gates are required")
    require(all(type(value) is int for value in binding["counts"].values()), "Counts must be exact integers")
    require(isinstance(binding.get("source_pins"), dict)
            and {SELECTOR, DRIVER, FIXTURE, CLOUD_DRIVER, ORIGINAL_DRIVER, ORIGINAL_VALIDATOR, ORIGINAL_BINDING,
                 ORIGINAL_TESTS, ORIGINAL_WORKFLOW, SQL_CONTROLS, REPOSITORY_SOURCE} <= set(binding["source_pins"]),
            "Missing whole-source inputs")
    require(binding.get("original_repository") == {
        "bytes": 44176, "sha256": "c3f086003d1667014a50fc996ae3976ebdf3ad82b9b6c9a60484762d6dbc16af",
        "git_blob": "86512a8286560aedb248da4abea1a41f5c96ea0e"}, "Original RED source changed")


def observe(root, environment):
    root = Path(root)
    event = load_json(environment["GITHUB_EVENT_PATH"])
    authority = identity(environment, event)
    head = authority["head_sha"]
    require(git(root, "rev-parse", "HEAD").decode().strip() == head, "Checkout moved")
    require(not git(root, "status", "--porcelain", "--untracked-files=no"), "Dirty tracked checkout")
    require(git(root, "show", "-s", "--format=%P", "HEAD").decode().strip() == SOURCE_M,
            "This reviewed route must be a single additive CI commit on repaired M")
    require(git(root, "show", "-s", "--format=%P", SOURCE_M).decode().strip() == PREVIOUS_SOURCE_M
            and git(root, "show", "-s", "--format=%P", PREVIOUS_SOURCE_M).decode().strip() == BASE,
            "Compiler repair must be the exact child of the reviewed Repository source and Cloud base")
    repair_delta = git(root, "diff", "--name-status", PREVIOUS_SOURCE_M, SOURCE_M).decode().splitlines()
    require(set(repair_delta) == {"M\tSource/Core/CloudKit/CloudKitCoreManager.swift", "M\t" + FIXTURE}
            and len(repair_delta) == 2, "Compiler repair changed unreviewed source")
    binding = load_json(exact_file(root, BINDING))
    validate_binding(binding)
    source_delta = {}
    for line in git(root, "diff", "--name-status", BASE, SOURCE_M).decode().splitlines():
        status, relative = line.split("\t")
        require(relative not in source_delta, "Duplicate source change")
        source_delta[relative] = status
    require(source_delta == {REPOSITORY_SOURCE: "M", DRIVER: "A", FIXTURE: "A",
                             "Source/Core/CloudKit/CloudKitCoreManager.swift": "M"},
            "Repaired M contains an unreviewed production/source change")
    changes = git(root, "diff", "--name-status", SOURCE_M, head).decode().splitlines()
    observed_changes = {}
    for line in changes:
        status, path = line.split("\t")
        require(path not in observed_changes and status in ("A", "M"), "Unreviewed rename/delete/type change")
        observed_changes[path] = status
        require(path in NEW_FILES or path == ORIGINAL_BINDING or (status == "A" and path.startswith(DOCS)),
                "Change outside reviewed Repository/route/docs scope: " + path)
    require(all(observed_changes.get(p) == "A" for p in NEW_FILES)
            and observed_changes.get(ORIGINAL_BINDING) == "M", "Required additive CI and metadata delta missing")
    trees = binding.get("application_trees")
    require(isinstance(trees, dict) and set(trees) == set(APPLICATION_ROOTS), "Complete repaired source trees required")
    for relative, expected in trees.items():
        require(git(root, "rev-parse", head + ":" + relative).decode().strip()
                == git(root, "rev-parse", SOURCE_M + ":" + relative).decode().strip() == expected,
                "Application/tests/tools tree changed after repaired M")
    require(git(root, "rev-parse", head + ":" + CORE).decode().strip() == CORE_TREE,
            "Whole original Core5d0 differs")
    core = {}
    for row in git(root, "ls-tree", "-r", "-z", head, "--", CORE).split(b"\0"):
        if not row:
            continue
        metadata, path = row.split(b"\t", 1)
        mode, kind, oid = metadata.decode().split()
        require(mode in ("100644", "100755") and kind == "blob", "Unexpected Core link/submodule")
        core[path.decode()] = oid
    require(CORE + "/Package.swift" in core, "Complete original Core package missing")
    for path in (root / CORE).rglob("*"):
        if path.is_file() and ".build" not in path.parts and path.suffix in (".swift", ".json", ".resolved"):
            require(path.relative_to(root).as_posix() in core and not path.is_symlink(), "Untracked/linked Core input")
    pins = binding["source_pins"]
    files = {}
    for relative in sorted(set(pins) | set(core) | set(NEW_FILES)):
        actual = record(root, relative)
        require(actual["git_blob"] == git(root, "rev-parse", head + ":" + relative).decode().strip(),
                "Checkout input differs from immutable Git: " + relative)
        if relative in pins:
            require(actual == pins[relative], "Reviewed input differs: " + relative)
        if relative in core:
            require(actual["git_blob"] == core[relative], "Whole Core membership differs")
        if relative in pins and relative != ORIGINAL_BINDING:
            require(actual["git_blob"] == git(root, "rev-parse", SOURCE_M + ":" + relative).decode().strip(),
                    "A source dependency changed after repaired M: " + relative)
        files[relative] = actual
    original = git(root, "show", BASE + ":" + REPOSITORY_SOURCE)
    require({"bytes": len(original), "sha256": digest(original), "git_blob": blob(original)} == binding["original_repository"],
            "Original baseline Git object changed")
    old_metadata_bytes = git(root, "show", SOURCE_M + ":" + ORIGINAL_BINDING)
    old_metadata = json.loads(old_metadata_bytes)
    corrected_metadata = copy.deepcopy(old_metadata)
    corrected_metadata["reviewed_source_sha"] = SOURCE_M
    corrected_metadata["application_trees"] = trees
    for relative in (REPOSITORY_SOURCE, "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudOwnership.swift",
                     "Source/Core/CloudKit/CloudKitCoreManager.swift"):
        corrected_metadata["source_pins"][relative] = files[relative]
    require(load_json(root / ORIGINAL_BINDING) == corrected_metadata,
            "Original C binding changed beyond exact source M/trees/three input pins")
    cloud = module(root, CLOUD_DRIVER, "unchanged_annotation_cloud_driver")
    race = module(root, DRIVER, "whole_repository_disconnect_driver")
    required = set(cloud.source_provenance(root)) | set(cloud.SOURCES + cloud.CLOUD_SOURCES) | {DRIVER, FIXTURE}
    require(required <= set(files), "Incomplete executable source closure")
    original_validator = module(root, ORIGINAL_VALIDATOR, "unchanged_full_cloud_gate")
    names = original_validator.declared_cases(root)
    names["disconnect"] = race.declaration_names((root / FIXTURE).read_text())
    require(names == binding.get("case_names"), "Exact declarations changed")
    return {"identity": authority, "source_base": BASE, "application_source": SOURCE_M,
            "application_trees": trees, "source_delta": source_delta, "core_tree": CORE_TREE,
            "source_inventory_sha256": digest(json_bytes(files)), "files": files,
            "case_names": names, "changed_paths": observed_changes,
            "original_repository": binding["original_repository"], **NO_CLAIMS}


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=("before", "after"), required=True)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    output = root / OUTPUT
    output.mkdir(parents=True, exist_ok=True)
    destination = output / (args.phase + ".json")
    require(not destination.exists(), "Preserve prior route receipt")
    report = {"status": "FAILED", "phase": args.phase, "at": dt.datetime.now(dt.timezone.utc).isoformat(), **NO_CLAIMS}
    try:
        observed = observe(root, os.environ)
        report["source"] = observed
        report["source_archive"] = archive_sources(root, observed, output / ("source-" + args.phase + ".tar.gz"))
        if args.phase == "before":
            report["status"] = "SOURCE_BOUND_NOT_EXECUTED"
        else:
            before = load_json(output / "before.json")
            require(before.get("status") == "SOURCE_BOUND_NOT_EXECUTED" and before.get("source") == observed,
                    "Before/after immutable source/run differs")
            outcomes = {name: os.environ.get("DISCONNECT_" + name.upper() + "_OUTCOME")
                        for name in ("toolchain", "controls", "local", "exchange", "race")}
            report["outcomes"] = outcomes
            require(all(value == "success" for value in outcomes.values()), "Missing or failed original execution step")
            controls = load_json(output / "python-controls/RESULT.json")
            control_module = module(root, TESTS, "disconnect_actual_control_inventory")
            expected_controls = control_module.case_names()
            require(controls.get("status") == "PASS_PYTHON_ADMISSION_COLLECTION_CONTROLS"
                    and controls.get("expected_names") == expected_controls
                    and [row.get("name") for row in controls.get("cases", [])] == expected_controls
                    and all(row.get("status") == "PASS" for row in controls["cases"])
                    and controls.get("executed") == len(expected_controls)
                    and all(controls.get(key) == 0 for key in ("failures", "errors", "skips", "actual_swift_cases", "actual_repository_races", "native_ui_executed")),
                    "Complete Python admission/collector controls required")
            report["python_controls"] = len(expected_controls)
            report["original_gates"] = verify_original_gates(root, observed, outcomes)
            report["race_gates"] = verify_race(root, observed)
            report["status"] = "PASS_APPLE_REPOSITORY_RED10_LOCAL43_COLD2_CLOUD48_EXCHANGE28_CRASH2"
    except Exception as error:
        report["error"] = repr(error)
        # Keep partial reports verbatim as unverified evidence. They are never
        # a substitute for the complete source/result validators above.
        report["unverified_partial_results"] = {}
        for label, path in (("local", root / LOCAL_OUTPUT / "RESULT.json"), ("exchange", root / EXCHANGE_OUTPUT / "RESULT.json"), ("race", root / RACE_OUTPUT / "RESULT.json")):
            if path.is_file():
                try:
                    report["unverified_partial_results"][label] = load_json(path)
                except Exception as read_error:
                    report["unverified_partial_results"][label] = {"read_error": repr(read_error)}
        print(repr(error))
    finally:
        destination.write_bytes(json_bytes(report))
        print(json.dumps({"phase": args.phase, "status": report["status"]}))
    return 0 if report["status"] != "FAILED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
