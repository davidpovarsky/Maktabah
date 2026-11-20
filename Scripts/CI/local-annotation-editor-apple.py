#!/usr/bin/env python3
"""Exact Apple Foundation gate for the local annotation body and original ledger.

This wrapper does not replace either acceptance driver or any Swift assertion.
It binds their complete sources and verifies their independent raw results.
It does not mount Anytype, launch the app, or qualify CloudKit transport.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile

REPOSITORY = "davidpovarsky/Maktabah"
REPOSITORY_ID = 1280062128
BRANCH = "codex/otzaria-local-annotation-editor-apple-reviewed-20261120"
WORKFLOW = ".github/workflows/otzaria-local-annotation-editor-apple.yml"
BINDING = "Scripts/CI/local-annotation-editor-apple.inputs.json"
SELF = "Scripts/CI/local-annotation-editor-apple.py"
TESTS = "Scripts/CI/test-local-annotation-editor-apple.py"
SELECTOR = "Scripts/CI/select-runtime27-toolchain.py"
CORE = "Source/Otzaria/Actions"
LOCAL_DRIVER = "tools/hq-local-annotation-editor-acceptance.py"
EXCHANGE_DRIVER = "tools/hq-annotation-exchange-acceptance.py"
LOCAL_OUTPUT = "build/local-annotation-editor-acceptance"
EXCHANGE_OUTPUT = "build/local-annotation-editor-exchange-regression"
ROUTE_OUTPUT = "build/local-annotation-editor-route"
CI_INPUTS = (WORKFLOW, BINDING, SELF, TESTS)
LOCAL_DECLARATIONS = "Tests/HQ/local-annotation-editor/LocalAnnotationEditorAcceptance.swift"
EXCHANGE_DECLARATIONS = "Tests/HQ/annotation-exchange/AnnotationExchangeAcceptance.swift"
NO_CLAIMS = {
    "native_ui_executed": 0, "app_relaunch_executed": 0,
    "anytype_runtime_executed": 0, "cloudkit_transport_executed": 0,
    "physical_device_executed": 0, "live_exchange_enabled": False,
}


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def load_json(path):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    return json.loads(Path(path).read_bytes(), object_pairs_hook=pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Non-finite JSON: " + value)))


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, timeout=60)


def exact_file(root, relative):
    require(isinstance(relative, str) and relative == str(PurePosixPath(relative))
            and not relative.startswith("/") and "\\" not in relative
            and all(part not in ("", ".", "..") for part in relative.split("/")), "Unsafe source path")
    path = Path(root)
    for part in relative.split("/"):
        path /= part
        require(not path.is_symlink(), "Linked source/evidence: " + relative)
    require(path.is_file(), "Missing source/evidence: " + relative)
    return path


def record(root, relative, expected_blob=None):
    data = exact_file(root, relative).read_bytes()
    result = {"bytes": len(data), "sha256": digest(data), "git_blob": git_blob(data)}
    if expected_blob is not None:
        require(result["git_blob"] == expected_blob, "Working bytes differ from Git: " + relative)
    return result


def environment_identity(environment):
    ref = "refs/heads/" + BRANCH
    require(environment.get("GITHUB_EVENT_NAME") == "push", "Only the reviewed push route is admitted")
    require(environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_REPOSITORY_ID") == str(REPOSITORY_ID), "Wrong repository")
    require(environment.get("GITHUB_REF") == ref
            and environment.get("GITHUB_WORKFLOW_REF") == REPOSITORY + "/" + WORKFLOW + "@" + ref,
            "Wrong immutable workflow/ref")
    head = environment.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[a-f0-9]{40}", head)
            and environment.get("EXPECTED_CHECKOUT_SHA") == head
            and environment.get("GITHUB_WORKFLOW_SHA") == head, "Wrong checkout/workflow source")
    run, attempt = environment.get("GITHUB_RUN_ID", ""), environment.get("GITHUB_RUN_ATTEMPT", "")
    require(re.fullmatch(r"[1-9][0-9]*", run) and re.fullmatch(r"[1-9][0-9]*", attempt), "Missing run/attempt")
    return {"repository": REPOSITORY, "repository_id": REPOSITORY_ID, "event": "push",
            "ref": ref, "workflow": WORKFLOW, "head_sha": head,
            "run_id": int(run), "run_attempt": int(attempt)}


def load_module(root, relative, name):
    spec = importlib.util.spec_from_file_location(name, exact_file(root, relative))
    require(spec is not None and spec.loader is not None, "Missing original Python driver")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def declared_cases(root):
    local = re.findall(r'await run\("([a-z0-9_]+)"\)', exact_file(root, LOCAL_DECLARATIONS).read_text(encoding="utf-8"))
    exchange = re.findall(r'^\s*(?:test|await asyncTest)\("([A-Za-z0-9_]+)"\)',
                          exact_file(root, EXCHANGE_DECLARATIONS).read_text(encoding="utf-8"), re.MULTILINE)
    require(len(local) == len(set(local)) == 43 and len(exchange) == len(set(exchange)) == 28,
            "Original 43/28 named declarations changed")
    return {"local": local, "exchange": exchange}


def observe_source(root, environment):
    root = Path(root)
    identity = environment_identity(environment)
    head = identity["head_sha"]
    require(git(root, "rev-parse", "HEAD").decode().strip() == head, "Checkout moved")
    require(not git(root, "status", "--porcelain", "--untracked-files=no"), "Dirty tracked checkout")
    binding = load_json(exact_file(root, BINDING))
    require(binding.get("schema") == "otzaria-local-annotation-apple-v1"
            and binding.get("route") == {"repository": REPOSITORY, "branch": BRANCH, "workflow": WORKFLOW},
            "Wrong reviewed binding")
    require(binding.get("component_count") == 43 and type(binding["component_count"]) is int
            and binding.get("local_cold_gates") == 2 and type(binding["local_cold_gates"]) is int
            and binding.get("exchange_count") == 28 and type(binding["exchange_count"]) is int
            and binding.get("exchange_crash_gates") == 2 and type(binding["exchange_crash_gates"]) is int,
            "Changed complete acceptance selection")
    core_tree = git(root, "rev-parse", head + ":" + CORE).decode().strip()
    require(core_tree == binding.get("core_tree_sha"), "Whole reviewed Core tree differs; explicit repin required")
    raw = git(root, "ls-tree", "-r", "-z", head, "--", CORE)
    core = {}
    for row in raw.split(b"\0"):
        if not row:
            continue
        metadata, name = row.split(b"\t", 1)
        mode, kind, blob = metadata.decode("ascii").split()
        require(kind == "blob" and mode in ("100644", "100755"), "Linked/Core submodule source is not admitted")
        core[name.decode("utf-8")] = blob
    require(CORE + "/Package.swift" in core and core, "Missing whole original Core package")
    for path in (root / CORE).rglob("*"):
        if not path.is_file() or ".build" in path.relative_to(root / CORE).parts:
            continue
        relative = path.relative_to(root).as_posix()
        require(not path.is_symlink(), "Linked Core input")
        if path.suffix in (".swift", ".json", ".resolved"):
            require(relative in core, "Untracked compiled Core input: " + relative)
    pins = binding.get("source_pins")
    require(isinstance(pins, dict) and {LOCAL_DRIVER, EXCHANGE_DRIVER, SELECTOR,
            LOCAL_DECLARATIONS, EXCHANGE_DECLARATIONS} <= set(pins), "Missing original driver/source pins")
    files = {}
    for relative in sorted(set(pins) | set(core) | set(CI_INPUTS)):
        committed = git(root, "rev-parse", head + ":" + relative).decode().strip()
        files[relative] = record(root, relative, committed)
        if relative in pins:
            require(files[relative] == pins[relative], "Reviewed source pin differs: " + relative)
        if relative in core:
            require(committed == core[relative], "Core inventory differs")
    names = declared_cases(root)
    require(names == binding.get("case_names"), "Named acceptance selection differs")
    # Derive driver closure from the unchanged modules, not a subset selected by
    # this wrapper. This includes provenance-only files and every tracked Core input.
    local = load_module(root, LOCAL_DRIVER, "local_body_original_driver")
    exchange = load_module(root, EXCHANGE_DRIVER, "exchange_original_driver")
    required = set(local.SOURCES + exchange.SOURCES) | {
        LOCAL_DRIVER, EXCHANGE_DRIVER, "Maktabah.xcodeproj/project.pbxproj",
        "Source/Core/Database/CloudKitSyncManager.swift",
        "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift",
        "Source/Features/Annotations/Database/AnnotationRepository.swift",
        "Source/Core/Configuration/ReusableFunc.swift", SELECTOR,
    }
    require(required <= set(pins), "Incomplete original driver/source closure")
    return {"identity": identity, "reviewed_source_sha": binding["reviewed_source_sha"],
            "core_tree_sha": core_tree, "case_names": names, "files": files,
            "source_inventory_sha256": digest(json_bytes(files))}


def archive_sources(root, observation, destination):
    require(not destination.exists(), "Preserve existing raw source archive")
    with tarfile.open(destination, "w:gz") as archive:
        for relative, expected in sorted(observation["files"].items()):
            data = exact_file(root, relative).read_bytes()
            require(digest(data) == expected["sha256"], "Source changed during raw capture")
            item = tarfile.TarInfo(relative)
            item.size, item.mode, item.mtime = len(data), 0o644, 0
            archive.addfile(item, io.BytesIO(data))
    return {"file": destination.name, "bytes": destination.stat().st_size,
            "sha256": digest(destination.read_bytes()), "members": len(observation["files"])}


def retain_unverified_after(root, before, output):
    """Retain changed/missing inputs on failure without admitting that source."""
    files, errors = {}, {}
    for relative in before["source"]["files"]:
        try:
            files[relative] = record(root, relative)
        except Exception as error:
            errors[relative] = {"type": type(error).__name__, "message": str(error)}
    result = {"status": "UNVERIFIED_AFTER_FAILURE", "files": files, "missing_or_unsafe": errors}
    result["raw_source_archive"] = archive_sources(root, {"files": files}, output / "source-after-unverified.tar.gz")
    (output / "after-unverified-source.json").write_bytes(json_bytes(result))
    return {"status": result["status"], "captured_files": len(files),
            "missing_or_unsafe_files": len(errors), "raw_source_archive": result["raw_source_archive"]}


def verify_case_rows(rows, names, *, timing_required=False):
    require(isinstance(rows, list) and len(rows) == len(names), "Missing or extra actual cases")
    require(all(isinstance(row, dict) for row in rows), "Malformed actual case")
    actual = [row.get("name") for row in rows]
    require(len(set(actual)) == len(names) and set(actual) == set(names), "Missing/duplicate/renamed actual case")
    for row in rows:
        require(row.get("status") == "PASS" and row.get("error") is None,
                "Failure, skip or unexecuted actual case: " + str(row.get("name")))
        if timing_required:
            duration = row.get("milliseconds")
            require(type(duration) in (int, float) and math.isfinite(duration) and duration >= 0,
                    "Invalid actual case timing")


def verify_source_report(report, before_key, after_key, expected, required):
    before, after = report.get(before_key), report.get(after_key)
    require(isinstance(before, dict) and before == after, "Driver source changed or was not retained")
    require(set(before) == set(required), "Driver reported an incomplete or altered source closure")
    require(before == {key: expected[key]["sha256"] for key in required}, "Driver source differs from reviewed raw input")


def owned_fixtures(root, report, relative):
    base = Path(root) / relative
    owned = Path(report.get("owned_directory", ""))
    require(owned.is_absolute() and owned.parent == base and re.fullmatch(r"owned-[0-9a-f-]{36}", owned.name),
            "Driver fixture is not its fresh owned directory")
    require(owned.is_dir() and not owned.is_symlink() and not (owned / "fixtures").is_symlink(),
            "Missing or linked owned fixture")
    return owned, owned / "fixtures"


def verify_compiled_copy(root, owned, module, target):
    source_root = owned / "package/Sources" / target
    names = {Path(path).name: path for path in module.SOURCES}
    require(len(names) == len(module.SOURCES), "Original whole source name collision")
    actual = {path.name for path in source_root.iterdir()}
    require(actual == set(names), "Copied executable sources changed")
    records = {}
    for name, relative in sorted(names.items()):
        path = source_root / name
        require(path.is_file() and not path.is_symlink()
                and path.read_bytes() == exact_file(root, relative).read_bytes(), "Compiled source differs: " + relative)
        records[relative] = digest(path.read_bytes())
    manifest = owned / "package/Package.swift"
    require(manifest.is_file() and not manifest.is_symlink(), "Missing actual generated Swift package")
    return {"sources": records, "package_sha256": digest(manifest.read_bytes())}


def verify_common_report(report, identity, names, *, timing_required=False):
    require(report.get("source_sha") == identity["head_sha"], "Different executable source checkout")
    verify_case_rows(report.get("cases"), names, timing_required=timing_required)
    require(type(report.get("passed_cases")) is int and report["passed_cases"] == len(names)
            and type(report.get("failed_cases")) is int and report["failed_cases"] == 0,
            "Actual driver count mismatch")


def verify_results(root, observed, outcomes):
    require(outcomes == {"toolchain": "success", "local": "success", "exchange": "success"},
            "Both unchanged drivers and original toolchain must actually succeed")
    root = Path(root)
    toolchain = load_json(exact_file(root, ROUTE_OUTPUT + "/toolchain.json"))
    require(toolchain.get("status") == "MATCHED_MATRIX_PAIR_SELECTED"
            and toolchain.get("toolchains_installed") is False
            and toolchain.get("global_xcode_select_changed") is False, "Original toolchain selection failed")
    require(toolchain.get("selected", {}).get("developer_dir") == os.environ.get("DEVELOPER_DIR"),
            "Executed developer directory differs from original selection")
    local_module = load_module(root, LOCAL_DRIVER, "local_body_verifier")
    exchange_module = load_module(root, EXCHANGE_DRIVER, "exchange_verifier")
    local = load_json(exact_file(root, LOCAL_OUTPUT + "/RESULT.json"))
    exchange = load_json(exact_file(root, EXCHANGE_OUTPUT + "/RESULT.json"))
    files = observed["files"]
    core_files = {path for path in files if path.startswith(CORE + "/")}
    local_provenance = set(local_module.SOURCES) | {LOCAL_DRIVER, "Maktabah.xcodeproj/project.pbxproj",
        "Source/Core/Database/CloudKitSyncManager.swift", "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift"}
    local_provenance |= {path for path in core_files if Path(path).suffix in (".swift", ".json", ".resolved")}
    exchange_provenance = set(exchange_module.SOURCES) | {EXCHANGE_DRIVER,
        "Source/Features/Annotations/Database/AnnotationRepository.swift", "Source/Core/Configuration/ReusableFunc.swift"}
    exchange_provenance |= {path for path in core_files if Path(path).suffix in (".swift", ".json")}
    verify_common_report(local, observed["identity"], observed["case_names"]["local"])
    verify_common_report(exchange, observed["identity"], observed["case_names"]["exchange"], timing_required=True)
    verify_source_report(local, "source_before", "source_after", files, local_provenance)
    verify_source_report(exchange, "source_files_before", "source_files_after", files, exchange_provenance)
    require(local.get("status") == "PASS_APPLE_FOUNDATION_COMPONENT" and local.get("source_unchanged") is True
            and type(local.get("cold_reopen_gates")) is int and local["cold_reopen_gates"] == 2,
            "Local component/cold acceptance incomplete")
    require(all(type(local.get(key)) is int and local[key] == 0 for key in
                ("native_ui_executed", "anytype_executed", "cloudkit_transport_executed", "app_relaunch_executed"))
            and local.get("live_exchange_enabled") is False, "Local component scope was widened")
    commands = local.get("commands", [])
    expected_commands = [("compile", 480), ("binary-path", 30), ("component-cases", 180),
                         ("cold-write", 45), ("cold-reopen", 45), ("cold-reopen-final", 45)]
    require([(row.get("label"), row.get("timeout_seconds")) for row in commands] == expected_commands
            and all(type(row.get("exit_code")) is int and row["exit_code"] == 0
                    and not row.get("timed_out", False) for row in commands), "Missing or failed original local process")
    local_owned, local_fixtures = owned_fixtures(root, local, LOCAL_OUTPUT)
    first = load_json(local_fixtures / "cold-expected-1.json")
    second = load_json(local_fixtures / "cold-expected-2.json")
    local_module.verify_cold(local["cold_processes"], first, second)
    reread = local_module.verify_sqlite(local_fixtures, first, second)
    require(reread == local.get("independent_sqlite_readback"), "Final independent original row/version readback differs")
    require(exchange.get("status") == "PASS_ACTUAL_SQLITE_COMPONENT"
            and exchange.get("source_bytes_unchanged_during_run") is True
            and type(exchange.get("compile_exit")) is int and exchange["compile_exit"] == 0
            and type(exchange.get("execute_exit")) is int and exchange["execute_exit"] == 0,
            "Original exchange acceptance incomplete")
    require(exchange.get("sqlite_module_provider") == "Original Apple SDK SQLite3 module"
            and exchange.get("digest_provider") == "Production CryptoKit SHA256"
            and exchange.get("live_capability_enabled") is False, "Original Apple exchange provider differs")
    gates = exchange.get("process_termination_checks", [])
    require(isinstance(gates, list) and len(gates) == 2 and [row.get("phase") for row in gates] == ["after", "before"],
            "Missing original crash/reopen phase")
    exchange_owned, exchange_fixtures = owned_fixtures(root, exchange, EXCHANGE_OUTPUT)
    for gate in gates:
        phase = gate["phase"]
        require(gate.get("status") == "PASS"
                and type(gate.get("terminated_exit")) is int and gate["terminated_exit"] == 73
                and type(gate.get("expected_terminated_exit")) is int and gate["expected_terminated_exit"] == 73
                and type(gate.get("verify_exit")) is int and gate["verify_exit"] == 0,
                "Actual abrupt exit or separate reopen failed")
        require(re.fullmatch(r"CRASH_JOURNAL_MODE wal; synchronous=[0-9]+", gate.get("actual_journal_observation", "")),
                "Actual original WAL mode was not observed")
        crash_mode = "crash-after-commit" if phase == "after" else "crash-before-outer-commit"
        crash, reopen = gate.get("termination_command", []), gate.get("verify_command", [])
        require(len(crash) == len(reopen) == 3 and crash[0] == reopen[0]
                and crash[1:] == [crash_mode, str(exchange_fixtures)]
                and reopen[1:] == ["verify-crash-" + phase, str(exchange_fixtures)], "Original process sequence differs")
        log = exact_file(root, EXCHANGE_OUTPUT + "/verify-crash-" + phase + ".log").read_text(encoding="utf-8")
        require("PASS actual_process_termination_" + phase + "_commit_reopen" in log, "Missing original reopen assertion output")
    payload = (exchange_fixtures / "rich-payload.json").read_bytes()
    expected_hash = (exchange_fixtures / "rich-payload.sha256").read_text(encoding="utf-8")
    cloud_before = (exchange_fixtures / "cloud-before-ledger.json").read_bytes()
    cloud_after = (exchange_fixtures / "cloud-after-ledger.json").read_bytes()
    require(digest(payload) == expected_hash == exchange.get("independent_python_SHA256"), "Original rich byte hash differs")
    require(cloud_before == cloud_after and exchange.get("cloudkit_queue_bytes_unchanged") is True
            and digest(cloud_before) == exchange.get("cloudkit_queue_rows_SHA256")
            and type(exchange.get("cloudkit_queue_rows_count")) is int
            and len(json.loads(cloud_before)) == exchange["cloudkit_queue_rows_count"], "Original queue row bytes differ")
    return {"local_cases": 43, "local_cold_reopen_gates": 2,
            "local_actual_process_ids": [row["processID"] for row in local["cold_processes"]],
            "exchange_cases": 28, "exchange_abrupt_process_reopen_gates": 2,
            "local_compiled_copy": verify_compiled_copy(root, local_owned, local_module, "LocalAnnotationEditorAcceptance"),
            "exchange_compiled_copy": verify_compiled_copy(root, exchange_owned, exchange_module, "ExchangeAcceptance"),
            "local_independent_sqlite": reread,
            "exchange_raw_payload_sha256": expected_hash,
            "exchange_original_queue_sha256": digest(cloud_before),
            "local_result_sha256": digest((root / LOCAL_OUTPUT / "RESULT.json").read_bytes()),
            "exchange_result_sha256": digest((root / EXCHANGE_OUTPUT / "RESULT.json").read_bytes())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("before", "after"), required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = root / ROUTE_OUTPUT
    output.mkdir(parents=True, exist_ok=True)
    destination = output / (args.phase + ".json")
    require(not destination.exists(), "Preserve prior gate attempt")
    report = {"schema": "otzaria-local-annotation-apple-result-v1", "status": "FAILED",
              "phase": args.phase, "observed_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "scope": "Apple Foundation original Store/Repository/local-body and unchanged exchange components",
              **NO_CLAIMS}
    try:
        require(sys.platform == "darwin", "Real installed Apple environment required")
        observed = observe_source(root, os.environ)
        report["source"] = observed
        report["raw_source_archive"] = archive_sources(root, observed, output / ("source-" + args.phase + ".tar.gz"))
        if args.phase == "before":
            report["status"] = "SOURCE_BOUND_NOT_EXECUTED"
        else:
            before = load_json(output / "before.json")
            require(before.get("status") == "SOURCE_BOUND_NOT_EXECUTED" and before.get("source") == observed,
                    "Missing original before receipt or source drift")
            outcomes = {name: os.environ.get("LOCAL_ANNOTATION_" + name.upper() + "_OUTCOME")
                        for name in ("toolchain", "local", "exchange")}
            report["workflow_step_outcomes"] = outcomes
            report["verified"] = verify_results(root, observed, outcomes)
            report["status"] = "PASS_APPLE_FOUNDATION_LOCAL43_COLD2_EXCHANGE28_CRASH2"
        return 0
    except Exception as error:
        report["error_type"], report["error"] = type(error).__name__, str(error)
        return 1
    finally:
        if args.phase == "after" and report["status"] == "FAILED" and "raw_source_archive" not in report:
            try:
                before = load_json(output / "before.json")
                require(before.get("status") == "SOURCE_BOUND_NOT_EXECUTED", "No qualified initial source inventory")
                report["unverified_failure_capture"] = retain_unverified_after(root, before, output)
            except Exception as error:
                report["failure_capture_error"] = {"type": type(error).__name__, "message": str(error)}
        destination.write_bytes(json_bytes(report))
        print(json.dumps({key: report[key] for key in ("status", "phase", "scope", "native_ui_executed")}, sort_keys=True))


if __name__ == "__main__":
    raise SystemExit(main())
