#!/usr/bin/env python3
"""Actual whole-Repository RED/10 GREEN controls on the installed Apple SDK.

The original baseline is the exact Git object at SOURCE_BASE. Both executables
use the same complete SQLite/Repository dependencies and unchanged original43
fixture prefix. Only the candidate receives the reviewed Repository repair.
An expected deadlock is recorded as RED, never counted as a passing case.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCE_BASE = "7af3a06d48ccbe77acef180cb99d120971c3804e"
CORE_TREE = "5d0ee482c8f10726fe3863792dac94c18e94d792"
REPOSITORY = "Source/Features/Annotations/Database/AnnotationRepository.swift"
BASELINE_SHA256 = "c3f086003d1667014a50fc996ae3976ebdf3ad82b9b6c9a60484762d6dbc16af"
BASELINE_GIT_BLOB = "86512a8286560aedb248da4abea1a41f5c96ea0e"
CANDIDATE_SHA256 = "634d07799a2e3985ba7a16817856f8d8ccba3045519ad21dab805e3c9b8d1ef8"
SELF = "tools/hq-annotation-disconnect-acceptance.py"
FIXTURE = "Tests/HQ/annotation-disconnect/AnnotationRepositoryDisconnectAcceptance.swift"
CLOUD_DRIVER = "tools/hq-local-annotation-cloud-acceptance.py"
BASELINE_NAME = "baseline-deadlock"
BASELINE_TIMEOUT = 12
CASE_TIMEOUT = 20
CASES = (
    "progress_default", "progress_captured", "stale_capture_queued_during_replacement",
    "stale_database_with_current_lifetime_cannot_detach",
    "current_database_with_stale_lifetime_cannot_detach",
    "matched_capture_detaches_only_original_owner", "nil_default_disconnect_preserves_later_setup",
    "repeated_default_disconnect_is_idempotent",
    "reopen_preserves_rows_queue_and_retires_old_connection",
    "rollback_then_disconnect_preserves_original_note",
)
BASELINE_MARKERS = (
    "fixture_ready", "transaction_acquired_and_uncommitted_write", "disconnect_requested",
    "captured_lifetime_retired_before_transaction_release", "original_repository_exec_requested",
)
PROGRESS_MARKERS = (
    "fixture_ready", "transaction_acquired_and_uncommitted_write", "disconnect_requested",
    "repository_state_read_while_database_held", "original_repository_exec_requested",
    "original_repository_exec_returned", "transaction_returned", "disconnect_returned",
)
ORIGINAL_NOTE = "original plain note"
COMMITTED_NOTE = "committed-original-repository-helper"
UNCOMMITTED_NOTE = "uncommitted-before-disconnect"
NO_CLAIMS = {"native_ui_executed": 0, "cloudkit_transport_executed": 0,
             "anytype_runtime_executed": 0, "physical_device_executed": 0,
             "current_core194_executed": False}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def sha(path):
    return sha_bytes(Path(path).read_bytes())


def write_json(path, value):
    Path(path).write_bytes((json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode())


def read_json(path, maximum=65_536):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "Missing or linked JSON: " + str(path))
    with path.open("rb") as handle:
        data = handle.read(maximum + 1)
    require(len(data) <= maximum, "Oversized JSON: " + str(path))
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Non-finite JSON")))


def load_cloud(root=ROOT):
    spec = importlib.util.spec_from_file_location("unchanged_cloud_driver", Path(root) / CLOUD_DRIVER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(root, *arguments):
    return subprocess.check_output(["git", *arguments], cwd=root, timeout=30)


def baseline_bytes(root):
    data = git(root, "show", SOURCE_BASE + ":" + REPOSITORY)
    require(sha_bytes(data) == BASELINE_SHA256 and git_blob(data) == BASELINE_GIT_BLOB,
            "Actual original Repository Git object differs")
    return data


def declaration_names(text):
    names = re.findall(r'^        case "([a-z0-9_]+)":$', text, re.MULTILINE)
    require(tuple(names) == CASES and len(set(names)) == 10, "Exact10 candidate declarations required")
    return names


def owned_directory(parent, path):
    parent, path = Path(parent).resolve(), Path(path)
    require(path.is_dir() and not path.is_symlink(), "Owned fixture directory required")
    resolved = path.resolve()
    require(resolved != parent and parent in resolved.parents, "Fixture is outside owned evidence")
    current = path
    while current != parent:
        require(not current.is_symlink(), "Linked fixture ancestry")
        current = current.parent
        require(current != current.parent or current == parent, "Invalid owned ancestry")
    return resolved


def markers(root):
    directory = Path(root) / "markers"
    require(directory.is_dir() and not directory.is_symlink(), "Actual numbered markers missing")
    rows = []
    for index, path in enumerate(sorted(directory.iterdir()), 1):
        row = read_json(path, 8192)
        require(set(row) == {"sequence", "event", "uptimeNanoseconds"}, "Unexpected marker schema")
        require(type(row["sequence"]) is int and row["sequence"] == index,
                "Missing, duplicate or reordered marker number")
        event = row["event"]
        require(isinstance(event, str) and re.fullmatch(r"[a-z_]+", event), "Invalid marker event")
        require(path.name == f"{index:03d}-{event}.json", "Marker filename/content mismatch")
        require(type(row["uptimeNanoseconds"]) is int and row["uptimeNanoseconds"] > 0,
                "Actual monotonic marker time required")
        require(not rows or row["uptimeNanoseconds"] >= rows[-1]["uptimeNanoseconds"], "Marker clock regressed")
        rows.append(row)
    return rows


def verify_baseline(root, command):
    require(command.get("timed_out") is True and command.get("timeout_seconds") == BASELINE_TIMEOUT,
            "Original cycle was not observed through its bounded timeout")
    require(type(command.get("pid")) is int and command["pid"] > 0
            and command.get("process_group") == command["pid"], "Owned isolated process identity required")
    require(command.get("terminate_sent") is True and command.get("reaped") is True
            and command.get("process_group_gone") is True
            and command.get("exit_code") in (-signal.SIGTERM, -signal.SIGKILL),
            "Expected deadlock process must be terminated and reaped")
    require(not (Path(root) / "CASE.json").exists(), "Baseline returned an actual result instead of blocking")
    rows = markers(root)
    require(tuple(row["event"] for row in rows) == BASELINE_MARKERS,
            "Timeout alone cannot prove the original state/DB cycle")
    return {"status": "EXPECTED_ORIGINAL_DEADLOCK_REPRODUCED", "counts_as_pass": False,
            "markers": rows, "original_repository_sha256": BASELINE_SHA256}


def verify_candidate(root, name, command):
    require(name in CASES and command.get("timed_out") is False and command.get("exit_code") == 0
            and command.get("reaped") is True and command.get("process_group_gone") is True,
            "Candidate process did not finish normally")
    row = read_json(Path(root) / "CASE.json")
    require(set(row) <= {"name", "status", "error", "sourceKind"}
            and row.get("name") == name and row.get("status") == "PASS"
            and row.get("error") is None and row.get("sourceKind") == "candidate",
            "Candidate case failed or belongs to different source/name")
    observed = markers(root)
    events = [entry["event"] for entry in observed]
    if name in ("progress_default", "progress_captured"):
        require(len(events) == 8 and len(set(events)) == 8 and set(events) == set(PROGRESS_MARKERS),
                "Candidate did not traverse every actual lock/transaction boundary")
        require(events[:6] == list(PROGRESS_MARKERS[:6]), "Candidate transaction/probe ordering changed")
        require(set(events[6:]) == set(PROGRESS_MARKERS[6:]), "Both original operations must return")
    elif name == "stale_capture_queued_during_replacement":
        require(events == ["replacement_published_before_old_database_release"],
                "Replacement was not published while the old DB was held")
    else:
        require(not events, "Unexpected marker set")
    return {"name": name, "status": "PASS", "markers": observed, "result": row}


def cold_read(root, name):
    root = Path(root).resolve()
    expected = read_json(root / "COLD_EXPECTED.json")
    relative = expected.get("databaseRelativePath")
    require(isinstance(relative, str) and re.fullmatch(r"[a-z-]+/Annotations\.sqlite", relative),
            "Only the actual owned fixture path is allowed")
    database = root / relative
    require(database.parent.is_dir() and not database.parent.is_symlink()
            and database.is_file() and not database.is_symlink(), "Owned actual SQLite file required")
    require(root in database.resolve().parents, "Database escaped owned fixture")
    identity = expected.get("annotationUUID")
    require(isinstance(identity, str) and str(uuid.UUID(identity)).upper() == identity,
            "Actual original canonical annotation UUID required")
    require(type(expected.get("annotationID")) is int and expected["annotationID"] > 0,
            "Original row identity required")
    expected_note = COMMITTED_NOTE if name in ("progress_default", "progress_captured") else ORIGINAL_NOTE
    require(expected.get("note") == expected_note
            and all(type(expected.get(key)) is int and expected[key] == value
                    for key, value in (("annotations", 1), ("tags", 2), ("pending", 2))),
            "Cold expectation differs from original fixture/original helper outcome")
    if name == BASELINE_NAME or name in ("progress_default", "progress_captured"):
        require(expected.get("uncommittedNote") == UNCOMMITTED_NOTE, "Original uncommitted write witness missing")
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=2)
    try:
        connection.execute("PRAGMA query_only=ON")
        require(connection.execute("PRAGMA integrity_check").fetchall() == [("ok",)], "Cold database integrity differs")
        rows = connection.execute("SELECT id,ckRecordId,note FROM annotations").fetchall()
        require(rows == [(expected["annotationID"], identity, expected_note)], "Cold original row/UUID/note differs")
        tags = connection.execute("SELECT t.name FROM tags t JOIN annotation_tags a ON a.tagId=t.id WHERE a.annotationId=? ORDER BY t.name", (expected["annotationID"],)).fetchall()
        require(tags == [("second",), ("עיון",)], "Cold original tags differ")
        pending = connection.execute("SELECT ck_record_id,operation FROM sync_pending ORDER BY ck_record_id,operation").fetchall()
        require(sorted(pending) == sorted([(identity, "upload"), ("unrelated-delete", "delete")]),
                "Cold original upload/delete queue differs")
        require(connection.execute("SELECT COUNT(*) FROM annotations WHERE note=?", (UNCOMMITTED_NOTE,)).fetchone() == (0,),
                "Uncommitted baseline write survived")
        return {"status": "PASS_READ_ONLY_SQLITE", "reader": "Python sqlite3 mode=ro after process reap",
                "database": relative, "sqlite_version": sqlite3.sqlite_version,
                "row_id": expected["annotationID"], "annotation_uuid": identity,
                "note": expected_note, "annotation_count": 1, "tag_count": 2, "pending_count": 2,
                "integrity": "ok", "uncommitted_note_absent": True}
    finally:
        connection.close()


def group_exists(group):
    try:
        os.killpg(group, 0)
        return True
    except ProcessLookupError:
        return False


def run_owned(command, cwd, artifacts, label, timeout, report):
    """One exact child/session; bounded owned-group cleanup even on interruption."""
    require(sys.platform in ("darwin", "linux"), "POSIX owned process groups required")
    artifacts = Path(artifacts)
    stdout, stderr = artifacts / (label + ".stdout.log"), artifacts / (label + ".stderr.log")
    require(not stdout.exists() and not stderr.exists(), "Prior command evidence must be retained")
    record = {"label": label, "command": [str(x) for x in command], "timeout_seconds": timeout,
              "started_at": dt.datetime.now(dt.timezone.utc).isoformat(), "timed_out": False,
              "terminate_sent": False, "kill_sent": False, "reaped": False,
              "stdout": stdout.name, "stderr": stderr.name}
    report["commands"].append(record)
    start = time.monotonic()
    process = None
    try:
        with stdout.open("xb") as out, stderr.open("xb") as err:
            process = subprocess.Popen(command, cwd=cwd, stdout=out, stderr=err, start_new_session=True)
            record["pid"] = process.pid
            record["process_group"] = os.getpgid(process.pid)
            require(record["process_group"] == process.pid, "Child did not acquire its owned session")
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                record["timed_out"] = True
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    record["terminate_sent"] = True
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        record["kill_sent"] = True
                        process.wait(timeout=5)
                record["exit_code"] = process.returncode
                record["reaped"] = process.returncode is not None
                # An escaped descendant can never satisfy completion. These
                # processes are children of this newly created group only.
                if group_exists(process.pid):
                    os.killpg(process.pid, signal.SIGKILL)
                    record["descendant_cleanup_sent"] = True
                    limit = time.monotonic() + 2
                    while group_exists(process.pid) and time.monotonic() < limit:
                        time.sleep(0.02)
                record["process_group_gone"] = not group_exists(process.pid)
    finally:
        record["seconds"] = time.monotonic() - start
        record["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        for key, path in (("stdout_sha256", stdout), ("stderr_sha256", stderr)):
            if path.is_file():
                record[key] = sha(path)
        write_json(artifacts / (label + ".command.json"), record)
    return record


def normal_command(*args):
    record = run_owned(*args)
    require(not record["timed_out"] and record.get("exit_code") == 0
            and record.get("reaped") and record.get("process_group_gone"),
            record["label"] + " did not complete normally")
    return record


def prepare_package(root, owned, cloud):
    root, owned = Path(root), Path(owned)
    original = baseline_bytes(root)
    require(sha(root / REPOSITORY) == CANDIDATE_SHA256, "Reviewed Repository candidate differs")
    sources = cloud.SOURCES[:-1] + [FIXTURE]
    require(len(sources) == 23 and len({Path(p).name for p in sources}) == len(sources),
            "Complete unique23-file race closure required")
    prefix = cloud.fixture_prefix(root)
    copied = {}
    targets = []
    for name, candidate in (("DisconnectBaseline", False), ("DisconnectCandidate", True)):
        directory = owned / "package/Sources" / name
        directory.mkdir(parents=True)
        pins = {}
        for relative in sources:
            data = original if relative == REPOSITORY and not candidate else (root / relative).read_bytes()
            (directory / Path(relative).name).write_bytes(data)
            pins[relative] = {"sha256": sha_bytes(data), "git_blob": git_blob(data), "bytes": len(data)}
        (directory / "OriginalLocalFixture.swift").write_bytes(prefix)
        pins["generated:exact_original_fixture_prefix"] = {"sha256": sha_bytes(prefix), "bytes": len(prefix)}
        copied[name] = pins
        define = '.define("REPOSITORY_DISCONNECT_CANDIDATE"), ' if candidate else ""
        targets.append('.executableTarget(name: ' + json.dumps(name) + ', dependencies: [.product(name: "OtzariaActionCore", package: "actions")], swiftSettings: [' + define + '.unsafeFlags(["-strict-concurrency=complete"])], linkerSettings: [.linkedLibrary("sqlite3")])')
    manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AnnotationRepositoryDisconnectAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [TARGETS], swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps((root / "Source/Otzaria/Actions").as_posix())).replace("TARGETS", ",\n        ".join(targets))
    (owned / "package/Package.swift").write_bytes(manifest.encode())
    return copied


def verify_copies(owned, expected):
    output = {}
    for target, pins in expected.items():
        directory = Path(owned) / "package/Sources" / target
        names = {("OriginalLocalFixture.swift" if key.startswith("generated:") else Path(key).name): key for key in pins}
        require({p.name for p in directory.iterdir()} == set(names), "Compiled source membership changed")
        output[target] = {}
        for name, key in names.items():
            path = directory / name
            require(path.is_file() and not path.is_symlink(), "Compiled input is not a regular file")
            data = path.read_bytes()
            row = {"sha256": sha_bytes(data), "bytes": len(data)}
            if "git_blob" in pins[key]:
                row["git_blob"] = git_blob(data)
            require(row == pins[key], "Compiled whole input changed: " + key)
            output[target][key] = row
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    require(not (artifacts / "RESULT.json").exists(), "Preserve previous attempt")
    report = {"schema": "annotation-disconnect-actual-v1", "status": "NOT_RUN",
              "scope": "Whole original Repository/SQLite deterministic lock-order component",
              "started_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "host": platform.platform(), "source_base": SOURCE_BASE, "core_tree": CORE_TREE,
              "baseline": None, "cases": [], "commands": [], **NO_CLAIMS}
    before, paths, owned, copies = None, [], None, None
    try:
        require(sys.platform == "darwin", "Installed Apple SDK required; no fallback or installation")
        swift = shutil.which("swift")
        require(swift is not None, "Installed Swift required")
        sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True, timeout=30).strip()
        require((Path(sdk) / "usr/include/sqlite3.h").is_file(), "Original Apple SQLite3 SDK required")
        require(git(ROOT, "rev-parse", "HEAD:Source/Otzaria/Actions").decode().strip() == CORE_TREE,
                "This gate qualifies original Core5d0, not a different Core tree")
        cloud = load_cloud()
        declaration_names((ROOT / FIXTURE).read_text())
        paths = sorted(set(cloud.source_provenance(ROOT)) | {SELF, FIXTURE})
        before = {p: sha(ROOT / p) for p in paths}
        report.update(source_before=before, source_sha=git(ROOT, "rev-parse", "HEAD").decode().strip(),
                      swift=subprocess.check_output([swift, "--version"], text=True, timeout=30).strip(), sdk=sdk)
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        owned.mkdir()
        report["owned_directory"] = str(owned)
        copies = prepare_package(ROOT, owned, cloud)
        report["compiled_copies_before"] = verify_copies(owned, copies)
        command = [swift, "build", "--package-path", str(owned / "package"), "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        normal_command(command, ROOT, artifacts, "compile", 480, report)
        normal_command(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report)
        binary = Path((artifacts / "binary-path.stdout.log").read_text().strip())
        baseline_exe, candidate_exe = binary / "DisconnectBaseline", binary / "DisconnectCandidate"
        report["executables"] = {str(p): sha(p) for p in (baseline_exe, candidate_exe)}
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        baseline = fixtures / BASELINE_NAME
        baseline.mkdir()
        owned_directory(owned, baseline)
        record = run_owned([str(baseline_exe), BASELINE_NAME, str(baseline)], ROOT, artifacts,
                           BASELINE_NAME, BASELINE_TIMEOUT, report)
        report["baseline"] = verify_baseline(baseline, record)
        report["baseline"]["cold"] = cold_read(baseline, BASELINE_NAME)
        write_json(artifacts / "BASELINE_RED.json", report["baseline"])
        for name in CASES:
            directory = fixtures / name
            directory.mkdir()
            owned_directory(owned, directory)
            record = run_owned([str(candidate_exe), name, str(directory)], ROOT, artifacts, name, CASE_TIMEOUT, report)
            row = verify_candidate(directory, name, record)
            row["cold"] = cold_read(directory, name)
            report["cases"].append(row)
            write_json(artifacts / "CASES.json", report["cases"])
        require([row["name"] for row in report["cases"]] == list(CASES), "All10 ordered cases required")
        report["status"] = "PASS_APPLE_REPOSITORY_RED_AND10_GREEN"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        if "executables" in report:
            try:
                report["executables_after"] = {path: sha(path) for path in report["executables"]}
                if report["executables_after"] != report["executables"]:
                    report["status"] = "FAILED"
            except Exception as error:
                report["executable_after_error"] = repr(error)
                report["status"] = "FAILED"
        if copies is not None:
            try:
                report["compiled_copies_after"] = verify_copies(owned, copies)
            except Exception as error:
                report["compiled_copy_error"] = repr(error)
                report["status"] = "FAILED"
        if before is not None:
            try:
                report["source_after"] = {p: sha(ROOT / p) for p in paths}
                report["source_unchanged"] = report["source_after"] == before
                if not report["source_unchanged"]:
                    report["status"] = "FAILED"
            except Exception as error:
                report["source_after_error"] = repr(error)
                report["status"] = "FAILED"
        report["verified_green_cases"] = len(report["cases"])
        report["expected_original_red"] = report["baseline"] is not None
        report["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({key: report[key] for key in ("status", "verified_green_cases", "expected_original_red")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_REPOSITORY_RED_AND10_GREEN" else 1


if __name__ == "__main__":
    raise SystemExit(main())
