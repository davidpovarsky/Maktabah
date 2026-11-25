#!/usr/bin/env python3
"""Original SQLite conditional-revision gate on the owner's real Apple runner.

Reuses the committed original local-editor source list and its verbatim fixture
prefix. No product implementation is replaced, extracted, or copied into a
shared library. The existing unrelated CloudKit/UI boundary doubles remain
explicit. These are Foundation component proofs, never native SDK/UI acceptance.
"""
from pathlib import Path
import argparse
import base64
import datetime
import hashlib
import json
import os
import platform
import re
import runpy
import shutil
import signal
import sqlite3
import struct
import subprocess
import sys
import time
import traceback
import uuid

ROOT = Path(__file__).resolve().parents[1]
AREA = "Tests/HQ/annotation-native-revision"
HARNESS = AREA + "/NativeRevisionAcceptance.swift"
ORIGINAL_DRIVER = "tools/hq-local-annotation-editor-acceptance.py"
DRIVER = "tools/hq-annotation-native-revision-acceptance.py"
CASE_COUNT = 36
MODES = (
    ("cold-write", 0), ("cold-reopen", 0),
    ("crash-before", 73), ("crash-before-reopen", 0),
    ("crash-after", 73), ("crash-after-reopen", 0),
)
NEW_TABLES = (
    "otzaria_local_editor_native_revision_schema",
    "otzaria_local_editor_native_revision_attempts",
)
PREFIX_MARKER = b"@MainActor\nfinal class LocalCases"
PACKAGE = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AnnotationNativeRevisionAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [.executableTarget(name: "AnnotationNativeRevisionAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])],
    swiftLanguageModes: [.v6])
"""


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha_bytes(raw):
    return hashlib.sha256(raw).hexdigest()


def sha(path):
    return sha_bytes(path.read_bytes())


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def decode64(text):
    return base64.b64decode(text, validate=True)


def quote_identifier(value):
    return '"' + value.replace('"', '""') + '"'


def protected_database(connection):
    """Independent Python readback of all original typed cells and schema."""
    schema = connection.execute(
        "SELECT type,name,tbl_name,coalesce(sql,'') FROM main.sqlite_master "
        "WHERE tbl_name NOT IN (?,?) ORDER BY type COLLATE BINARY,name COLLATE BINARY",
        NEW_TABLES).fetchall()
    contents = {}
    for kind, name, table, statement in schema:
        if kind != "table":
            continue
        projection = "*" if "WITHOUT ROWID" in statement.upper() else "rowid,*"
        rows = []
        for values in connection.execute("SELECT " + projection + " FROM main." + quote_identifier(name)):
            cells = []
            for value in values:
                if value is None:
                    cell = "null"
                elif type(value) is int:
                    cell = "i:" + str(value)
                elif type(value) is float:
                    bits = struct.unpack(">Q", struct.pack(">d", value))[0]
                    cell = "f:" + format(bits, "x")
                elif type(value) is str:
                    cell = "t:" + base64.b64encode(value.encode("utf-8")).decode()
                elif type(value) is bytes:
                    cell = "b:" + base64.b64encode(value).decode()
                else:
                    raise RuntimeError("Unexpected original SQLite cell type")
                cells.append(cell)
            raw = json.dumps(cells, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            rows.append(base64.b64encode(raw).decode())
        contents[name] = sorted(rows)
    return {"schema": [list(row) for row in schema], "rows": contents}


def verify_sqlite(fixtures, writer, expected, reopened):
    database = fixtures / ("cold-profile" if writer == "cold-write" else writer + "-profile") / "Annotations.sqlite"
    require(database.resolve() == Path(expected["databasePath"]).resolve() ==
            Path(reopened["databasePath"]).resolve(), "Cold evidence refers outside the exact owned database")
    require(database.is_file(), "Original fixture database missing")
    expected_original = decode64(expected["protectedBase64"])
    require(sha_bytes(expected_original) == expected["protectedSHA256"], "Protected-state receipt hash mismatch")
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        require(connection.execute("PRAGMA integrity_check").fetchall() == [("ok",)],
                "Independent SQLite integrity check failed")
        require(protected_database(connection) == json.loads(expected_original),
                "Independent readback found changed original rows, tags, history, queue, ACK or schema")
        columns = ("attempt_uuid", "operation", "image_base64", "image_sha256",
                   "target_base64", "target_sha256", "request_base64", "request_sha256", "dispatch_state")
        rows = connection.execute("SELECT " + ",".join(columns) + " FROM " + NEW_TABLES[1]).fetchall()
        require(len(rows) == 1, "Independent revision count differs")
        actual = dict(zip(columns, rows[0]))
        old = expected["preparedRecord"]
        pairs = (
            ("attempt_uuid", "attempt"), ("operation", "operation"),
            ("image_base64", "imageBase64"), ("image_sha256", "imageSHA256"),
            ("target_base64", "targetBase64"), ("target_sha256", "targetSHA256"),
        )
        require(all(actual[a] == old[b] for a, b in pairs), "Independent immutable revision image changed")
        require(actual["operation"] == "revision", "Unexpected operation")
        for body, digest in (("image_base64", "image_sha256"), ("target_base64", "target_sha256")):
            require(sha_bytes(decode64(actual[body])) == actual[digest], "Independent revision byte digest mismatch")
        image = json.loads(decode64(actual["image_base64"]))
        require(image.get("schema") == "otzaria.original.annotation.revision-source.v1" and
                len(image["columns"]) == len(image["values"]) == len(set(image["columns"])) == 19,
                "Frozen original saved image is incomplete")
        fields = dict(zip(image["columns"], image["values"]))
        require(fields["annotation_uuid"] == expected["annotationUUID"] and
                fields["annotation_id"] == expected["rowID"] and
                fields["source_digest"] == expected["sourceSHA256"] and
                fields["payload_digest"] == expected["payloadSHA256"],
                "Frozen original image identity or exact bytes differ")
        for body, digest in (("source_canonical_base64", "source_digest"), ("payload_base64", "payload_digest")):
            require(sha_bytes(decode64(fields[body])) == fields[digest], "Frozen original byte digest mismatch")
        require(fields["namespace"] == "otzaria.local.annotation" and fields["destinations_json"] == "[]",
                "Component unexpectedly admitted external destinations")
        should_dispatch = writer == "crash-after"
        state = "dispatch_may_have_occurred" if should_dispatch else "prepared"
        require(actual["dispatch_state"] == state == reopened["revisionState"], "Actual crash transition differs")
        if should_dispatch:
            require(actual["request_base64"] == expected["requestBase64"] and
                    actual["request_sha256"] == expected["requestSHA256"] and
                    sha_bytes(decode64(actual["request_base64"])) == actual["request_sha256"],
                    "Committed exact SDK request fixture was lost or changed")
        else:
            require(actual["request_base64"] is None and actual["request_sha256"] is None,
                    "Uncommitted request survived or prepared history changed")
        original = connection.execute("SELECT id,ckRecordId FROM annotations").fetchall()
        require(original == [(expected["rowID"], expected["annotationUUID"])], "Original annotation/CloudKit identity changed")
        versions = connection.execute("SELECT annotation_uuid,revision,payload_digest,destinations_json "
                                      "FROM otzaria_annotation_exchange_versions").fetchall()
        require(versions == [(expected["annotationUUID"], 1, expected["payloadSHA256"], "[]")],
                "Revision bookkeeping changed original saved version")
        fresh = connection.execute("SELECT attempt_uuid,annotation_uuid,dispatch_state "
                                   "FROM otzaria_local_editor_native_attempts").fetchall()
        require(fresh == [(expected["freshAttemptUUID"], expected["annotationUUID"], "dispatch_may_have_occurred")],
                "Permanent fresh-import dispatch fence was altered")
        outbox = connection.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0]
        require(outbox == 0, "Revision bookkeeping created a remote outbox delivery")
        require(connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload'",
                                   (expected["annotationUUID"],)).fetchone()[0] == 1,
                "Original durable upload queue changed")
        require(connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' "
                                   "AND operation='delete'").fetchone()[0] == 1, "Unrelated deletion queue changed")
        require(connection.execute("PRAGMA journal_mode").fetchone() == ("wal",), "Crash fixture was not a real WAL database")
        return {
            "database_path": str(database), "integrity_check": "ok",
            "all_original_schema_and_typed_cells_equal": True,
            "protected_original_sha256": expected["protectedSHA256"], "state": state,
            "image_sha256": actual["image_sha256"], "target_sha256": actual["target_sha256"],
            "request_sha256": actual["request_sha256"], "outbox_count": outbox,
            "permanent_fresh_import_fence_preserved": True,
        }
    finally:
        connection.close()


def verify_cold(fixtures):
    receipts = []
    readbacks = []
    all_pids = []
    for writer, reader in (("cold-write", "cold-reopen"), ("crash-before", "crash-before-reopen"),
                           ("crash-after", "crash-after-reopen")):
        expected = json.loads((fixtures / (writer + "-expected.json")).read_text())
        observed = json.loads((fixtures / (reader + ".json")).read_text())
        require(expected["mode"] == writer and expected["journalMode"] == "wal" and expected["synchronous"] == 2,
                "Writer durability receipt mismatch")
        require(observed["mode"] == reader and observed["status"] == "PASS_ORIGINAL_SQLITE_COLD_REOPEN" and
                observed["originalStateUnchanged"] is True and observed["freshImportFencePreserved"] is True and
                observed["nativeExecution"] is False, "Actual cold process receipt mismatch")
        require(observed["writerProcessID"] == expected["processID"] and
                observed["processID"] != expected["processID"], "Cold process lineage mismatch")
        all_pids += [expected["processID"], observed["processID"]]
        require(str(uuid.UUID(expected["annotationUUID"])).upper() == expected["annotationUUID"],
                "Cold annotation UUID is not original canonical identity")
        require(type(expected["rowID"]) is int and expected["rowID"] > 0, "Invalid original SQLite row ID")
        if writer == "cold-write":
            completed = json.loads((fixtures / (writer + ".json")).read_text())
            require(completed["status"] == "PASS_PREPARED_COMMITTED" and
                    completed["processID"] == expected["processID"], "Prepared transaction did not finish")
            marker = completed
        else:
            marker = json.loads((fixtures / (writer + "-marker.json")).read_text())
            require(marker["processID"] == expected["processID"], "Crash marker belongs to another process")
            if writer == "crash-before":
                require(marker["phase"] == "inside_actual_sqlite_commit_hook" and marker["updates"] == 1 and
                        marker["inserts"] == 0 and marker["commitCalls"] == 1,
                        "Before-COMMIT crash did not reach the actual original UPDATE/commit hook")
            else:
                require(marker["phase"] == "after_actual_sqlite_commit_return" and
                        marker["state"] == "dispatch_may_have_occurred",
                        "After-COMMIT crash preceded the real committed transition")
        readbacks.append(verify_sqlite(fixtures, writer, expected, observed))
        receipts.append({"writer": expected, "marker": marker, "reopen": observed})
    require(len(all_pids) == len(set(all_pids)) == 6 and
            all(type(pid) is int and pid > 0 for pid in all_pids), "Six distinct actual cold/crash processes are required")
    return receipts, readbacks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    parser.add_argument("--anticipated-concurrent-growth-gib", required=True, type=float)
    parser.add_argument("--os-margin-gib", required=True, type=float)
    args = parser.parse_args()
    require(args.anticipated_concurrent_growth_gib >= 0 and args.os_margin_gib >= 0, "Invalid phase resource plan")
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    require(not (artifacts / "RESULT.json").exists(), "Preserve every attempt; use a fresh evidence directory")
    report = {
        "status": "NOT_RUN", "scope": "APPLE_FOUNDATION_ORIGINAL_SQLITE_CONDITIONAL_REVISION",
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(), "commands": [], "cases": [], "cold_processes": [],
        "original43_reexecuted": False, "original28_reexecuted": False,
        "native_sdk_executed": 0, "native_ui_executed": 0, "app_relaunch_executed": 0,
        "cloudkit_transport_executed": 0, "live_exchange_enabled": False,
        "boundaries": "Original Store/Repository/SQLite/ledger/local editor; existing catalog/UI/CloudKit doubles",
        "opaque_fixtures": "Original two-block body and bounded request bytes; not native SDK serialization",
        "resource_plan": {"own_incremental_bytes": 1024**3,
                          "anticipated_concurrent_growth_gib": args.anticipated_concurrent_growth_gib,
                          "os_margin_gib": args.os_margin_gib},
    }
    write_json(artifacts / "RESULT.json", report)
    before = None
    identity = None
    owned = None
    provenance = []
    reserve = int((args.anticipated_concurrent_growth_gib + args.os_margin_gib) * 1024**3)

    def admit(phase, remaining):
        free = shutil.disk_usage(artifacts).free
        row = {"phase": phase, "free_bytes": free, "own_remaining_peak_bytes": remaining,
               "other_remaining_and_os_bytes": reserve, "required_free_bytes": remaining + reserve}
        report.setdefault("phase_admissions", []).append(row)
        write_json(artifacts / "RESULT.json", report)
        require(free >= remaining + reserve, "Recorded incremental storage admission failed at " + phase)

    def run(label, command, timeout, expected=0):
        record = {"label": label, "command": list(map(str, command)), "expected_exit": expected,
                  "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        report["commands"].append(record)
        log = artifacts / (label + ".log")
        start = time.monotonic()
        with log.open("wb") as output:
            process = subprocess.Popen(record["command"], cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            record["processID"] = process.pid
            write_json(artifacts / "RESULT.json", report)
            deadline = start + timeout
            while True:
                try:
                    result = process.wait(timeout=min(5, max(0.1, deadline - time.monotonic())))
                    break
                except subprocess.TimeoutExpired:
                    reason = None
                    if time.monotonic() >= deadline:
                        reason = "owned command timed out"
                    elif shutil.disk_usage(artifacts).free < reserve:
                        reason = "other concurrent growth consumed the recorded remaining disk reserve"
                    if reason is None:
                        continue
                    record["owned_process_stopped_reason"] = reason
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    result = 124 if time.monotonic() >= deadline else 125
                    break
        record.update(exit_code=result, seconds=round(time.monotonic() - start, 3),
                      finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      log=log.name, log_sha256=sha(log), free_bytes_after=shutil.disk_usage(artifacts).free)
        write_json(artifacts / "RESULT.json", report)
        require(result == expected, label + " exited " + str(result) + ", expected " + str(expected))
        return log.read_text(encoding="utf-8")

    try:
        require(sys.platform == "darwin" and platform.machine() == "arm64", "Real Apple arm64 runner required")
        swift = shutil.which("swift")
        require(swift is not None, "Installed Swift compiler required; never install a fallback")
        admit("before_source_preparation", 1024**3)
        original = runpy.run_path(str(ROOT / ORIGINAL_DRIVER))
        sources = original["SOURCES"]
        require(sources[-1] == "Tests/HQ/local-annotation-editor/LocalAnnotationEditorAcceptance.swift" and
                len(sources) == 25, "Original whole-source component closure changed; review explicitly")
        core = ROOT / "Source/Otzaria/Actions"
        baseline = json.loads((ROOT / AREA / "product-inputs.json").read_text())
        require(baseline["source_sha"] == "ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f",
                "This checkpoint has not reviewed the changed product baseline")
        provenance = [x["path"] for x in baseline["files"]] + [
            DRIVER, HARNESS, AREA + "/case-inventory.json", AREA + "/product-inputs.json", AREA + "/README.md"]
        require(len(provenance) == len(set(provenance)) and set(sources).issubset(set(provenance)),
                "Incomplete or duplicate original-source proof closure")
        before = {p: sha(ROOT / p) for p in provenance}
        for row in baseline["files"]:
            raw = (ROOT / row["path"]).read_bytes()
            require(len(raw) == row["bytes"] and sha_bytes(raw) == row["sha256"] and
                    hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() == row["git_blob"],
                    "Original source differs from reviewed root checkpoint: " + row["path"])
        identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"]
        report.update(identity(ROOT, provenance))
        report["product_source_sha"] = baseline["source_sha"]
        report["source_before"] = before
        report["swift"] = run("swift-version", [swift, "--version"], 30).strip()
        sdk = Path(run("sdk-path", ["xcrun", "--sdk", "macosx", "--show-sdk-path"], 30).strip())
        require((sdk / "usr/include/sqlite3.h").is_file(), "Original Apple SDK SQLite3 module missing")
        report["sdk"] = str(sdk)
        expected = json.loads((ROOT / AREA / "case-inventory.json").read_text())
        declarations = re.findall(r'await run\("([a-z0-9_]+)"\)', (ROOT / HARNESS).read_text())
        require(isinstance(expected, list) and len(expected) == len(set(expected)) == CASE_COUNT and
                declarations == expected, "The complete reviewed 36-case declaration inventory is required")
        fixture = (ROOT / sources[-1]).read_bytes()
        require(fixture.count(PREFIX_MARKER) == 1, "Original reusable fixture prefix is ambiguous")
        prefix = fixture.split(PREFIX_MARKER, 1)[0]
        require(b"@main" not in prefix and b"await run(" not in prefix and len(prefix) > 5000,
                "Fixture extraction unexpectedly includes an old executable or test case")
        report["verbatim_fixture_prefix"] = {"path": sources[-1], "sha256": sha_bytes(prefix),
                                            "bytes": len(prefix), "marker": PREFIX_MARKER.decode()}
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        target = package / "Sources/AnnotationNativeRevisionAcceptance"
        target.mkdir(parents=True)
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        copied = sources[:-1] + [HARNESS]
        require(len({Path(p).name for p in copied}) == len(copied), "Whole-source filename collision")
        for source in copied:
            shutil.copyfile(ROOT / source, target / Path(source).name)
        (target / "OriginalLocalFixture.swift").write_bytes(prefix)
        (package / "Package.swift").write_text(PACKAGE.replace("CORE_PATH", json.dumps(core.as_posix())))
        write_json(artifacts / "compiled-original-inputs.json", {
            "whole_files": [{"path": p, "sha256": before[p]} for p in copied],
            "original_fixture_prefix": report["verbatim_fixture_prefix"],
            "whole_actions_package": "Source/Otzaria/Actions",
            "generated_manifest_sha256": sha(package / "Package.swift"),
        })
        admit("before_original_swift_build", 1024**3)
        command = [swift, "build", "--package-path", package, "--scratch-path", owned / "swift-build", "-j", "1"]
        run("compile", command, 480)
        binary_directory = Path(run("binary-path", command + ["--show-bin-path"], 30).strip())
        executable = binary_directory / "AnnotationNativeRevisionAcceptance"
        require(executable.is_file(), "Original compiled executable missing")
        report["executable"] = {"path": str(executable), "bytes": executable.stat().st_size,
                                "sha256": sha(executable)}
        admit("before_component_and_crash_processes", 128 * 1024**2)
        run("component-cases", [executable, "self-tests", fixtures], 240)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        rows = report["cases"]
        require(len(rows) == CASE_COUNT and [x.get("name") for x in rows] == expected and
                all(x.get("status") == "PASS" and x.get("error") is None for x in rows),
                "Original SQLite revision gate has an incomplete or failed case")
        for mode, code in MODES:
            run(mode, [executable, mode, fixtures], 60, expected=code)
        report["cold_processes"], report["independent_sqlite_readbacks"] = verify_cold(fixtures)
        report["crash_exit_code"] = 73
        report["cold_reopen_gates"] = 3
        require(before == {p: sha(ROOT / p) for p in provenance}, "Source changed during execution")
        report["status"] = "PASS_APPLE_FOUNDATION_ORIGINAL_SQLITE_REVISION"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "BLOCKED_BEFORE_EXECUTION"
        (artifacts / "failure.txt").write_text(traceback.format_exc())
    finally:
        if owned is not None:
            case_file = owned / "fixtures/CASES.json"
            if case_file.is_file():
                try:
                    report["cases"] = json.loads(case_file.read_text())
                except Exception as error:
                    report["cases_read_error"] = repr(error)
        if before is not None:
            try:
                report["source_after"] = {p: sha(ROOT / p) for p in provenance}
                report["source_unchanged"] = before == report["source_after"]
                after = identity(ROOT, provenance)
                require(after["source_sha"] == report["source_sha"] and
                        after["source_archive"] == report["source_archive"] and report["source_unchanged"],
                        "Exact committed source identity changed")
            except Exception as error:
                report.update(status="FAILED", post_source_error=repr(error))
        report["passed_cases"] = sum(x.get("status") == "PASS" for x in report["cases"])
        report["failed_cases"] = sum(x.get("status") != "PASS" for x in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        report["free_bytes_after"] = shutil.disk_usage(artifacts).free
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({k: report[k] for k in ("status", "passed_cases", "failed_cases")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_ORIGINAL_SQLITE_REVISION" else 1


if __name__ == "__main__":
    raise SystemExit(main())
