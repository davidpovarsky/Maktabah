#!/usr/bin/env python3
"""Actual Apple Foundation acceptance for explicit local annotation backfill.

Compiles whole original Repository/SQLite/ledger/identity/planner sources.
The existing unrelated UI/catalog/CloudKit doubles are named explicitly.
This does not qualify original Anytype conversion, network synchronization,
UI performance, a simulator relaunch, or Native116/Release114+2.
"""
from pathlib import Path
import argparse
import base64
import datetime
import hashlib
import json
import os
import platform
import runpy
import shutil
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = runpy.run_path(str(ROOT / "tools/hq-local-annotation-editor-acceptance.py"))
SOURCES = ORIGINAL["SOURCES"][:-1] + [
    "Source/ChavrusaText/Annotations/Backfill/AnnotationBackfillPlanner.swift",
    "Tests/HQ/annotation-backfill/AnnotationBackfillAcceptance.swift",
]
EXTRA_PROVENANCE = [
    "tools/hq-local-annotation-editor-acceptance.py",
    "tools/exact-source-archive.py",
    "tools/hq-annotation-backfill-acceptance.py",
    "Maktabah.xcodeproj/project.pbxproj",
    "Source/ChavrusaText/Annotations/Backfill/AnnotationBackfillView.swift",
    "Source/ChavrusaText/Annotations/Backfill/AnnotationBackfill.xcstrings",
    "Source/Features/Setting/SettingsView.swift",
]
EXPECTED_CASES = {
    "inspection_has_no_schema_identity_or_original_writes",
    "legacy_and_uuid_migration_preserve_original_rows_and_cloud_queue",
    "repeated_scan_is_idempotent",
    "plain_A_B_A_edits_keep_three_distinct_plan_versions",
    "rich_saved_body_is_retained_as_opaque_original_version",
    "invalid_legacy_row_rolls_back_whole_batch",
    "retirement_after_actual_SQLite_insert_rolls_back_all_new_state",
    "highlights_and_pending_deletions_do_not_become_notes",
    "profile_switch_retires_old_plan_without_writing",
    "batch_bounds_and_foreign_session_are_rejected",
    "actual_local_preparation_performance_100",
    "actual_local_preparation_performance_1000",
    "actual_local_preparation_performance_5000",
}
sha = ORIGINAL["sha"]
write_json = ORIGINAL["write_json"]
source_identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"]
NAMESPACE = "otzaria.annotation.backfill.v1"
COLUMNS = {
    "annotations": ["id", "bkId", "contentId", "startIndex", "length", "startIndexDiac",
        "lengthDiac", "color", "type", "note", "createdAt", "context", "part", "page",
        "ckRecordId", "lastModified", "backendLocator"],
    "tags": ["id", "name", "normalizedName"],
    "annotation_tags": ["annotationId", "tagId"],
    "sync_pending": ["ck_record_id", "operation", "queued_at"],
}


def provenance_paths():
    core = ROOT / "Source/Otzaria/Actions"
    files = [str(p.relative_to(ROOT)) for p in sorted(core.rglob("*"))
             if p.is_file() and ".build" not in p.parts
             and p.suffix in (".swift", ".json", ".resolved")]
    return sorted(set(SOURCES + EXTRA_PROVENANCE + files))


def run_logged(command, cwd, artifacts, label, timeout, report, expected_exit=0):
    record = {"label": label, "command": command, "timeout_seconds": timeout,
        "expected_exit_code": expected_exit,
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    report["commands"].append(record)
    began = time.monotonic()
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True,
                                text=True, encoding="utf-8", timeout=timeout)
        record["exit_code"] = result.returncode
        output = result.stdout + result.stderr
        (artifacts / (label + ".log")).write_text(output, encoding="utf-8")
        record["log_sha256"] = sha(artifacts / (label + ".log"))
        if result.returncode != expected_exit:
            raise RuntimeError(label + " exited " + str(result.returncode))
        return result.stdout
    except subprocess.TimeoutExpired as error:
        record["timed_out"] = True
        def text(value):
            return value.decode("utf-8", "replace") if isinstance(value, bytes) else value or ""
        (artifacts / (label + ".log")).write_text(text(error.stdout) + text(error.stderr), encoding="utf-8")
        raise
    finally:
        record["seconds"] = time.monotonic() - began
        record["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()


def original_digest(connection):
    rows = {}
    for table, names in COLUMNS.items():
        projection = ",".join(value for name in names
                              for value in ("typeof(" + name + ")", "hex(CAST(" + name + " AS BLOB))"))
        rows[table] = connection.execute(
            "SELECT " + projection + " FROM " + table + " ORDER BY " + ",".join(names)
        ).fetchall()
    data = json.dumps(rows, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()
    return hashlib.sha256(data).hexdigest()


def readback(path, count, expected_digest):
    connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
    try:
        if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Independent SQLite integrity failure")
        observed = original_digest(connection)
        if observed != expected_digest:
            raise ValueError("Independent original rows/tags/CloudKit queue digest differs")
        if connection.execute("SELECT COUNT(*) FROM annotations").fetchone() != (count,):
            raise ValueError("Independent source row count differs")
        if connection.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone() != (0,):
            raise ValueError("Local preparation generated external deliveries")
        rows = connection.execute("""SELECT namespace, annotation_uuid, revision,
                payload_base64, payload_digest, destinations_json
            FROM otzaria_annotation_exchange_versions""").fetchall()
        if len(rows) != count or len({row[1] for row in rows}) != count:
            raise ValueError("Missing or duplicate immutable plans")
        for namespace, note_uuid, revision, encoded, digest, destinations in rows:
            payload = base64.b64decode(encoded, validate=True)
            decoded = json.loads(payload)
            if (namespace != NAMESPACE or revision != 1 or destinations != "[]"
                    or str(uuid.UUID(note_uuid)).upper() != note_uuid
                    or hashlib.sha256(payload).hexdigest() != digest
                    or decoded.get("namespace") != NAMESPACE
                    or decoded.get("richBody") is not None
                    or decoded.get("otzariaBackfill", {}).get("classification") != "annotation"):
                raise ValueError("Local plan bytes, scope or version differs")
        aliases = connection.execute("""SELECT original_record_id, annotation_uuid, mapping_version
            FROM otzaria_annotation_exchange_legacy_identities""").fetchall()
        if len(aliases) != count or {row[1] for row in aliases} != {row[1] for row in rows}:
            raise ValueError("Independent legacy mapping census differs")
        for record, note_uuid, version in aliases:
            raw = bytearray(hashlib.sha256((NAMESPACE + "\0cloudkit-record-id\0" + record).encode()).digest()[:16])
            raw[6] = (raw[6] & 15) | 128
            raw[8] = (raw[8] & 63) | 128
            if version != 1 or str(uuid.UUID(bytes=bytes(raw))).upper() != note_uuid:
                raise ValueError("Independent deterministic legacy UUID differs")
        heads = connection.execute("SELECT namespace, annotation_uuid, revision FROM otzaria_annotation_exchange_heads").fetchall()
        if set(heads) != {(NAMESPACE, row[1], 1) for row in rows}:
            raise ValueError("Independent local plan heads differ")
        return {"database": str(path), "integrity": "ok", "original_digest": observed,
                "original_row_count": count, "immutable_plan_count": count,
                "legacy_alias_count": len(aliases), "external_deliveries": 0}
    finally:
        connection.close()


def verify_measurements(benchmarks):
    if [row.get("count") for row in benchmarks] != [100, 1000, 5000]:
        raise ValueError("All original performance sizes required")
    for row in benchmarks:
        count = row["count"]
        if (row.get("prepared") != count or row.get("reused") != 0
                or row.get("originalDigestBefore") != row.get("originalDigestAfter")
                or not isinstance(row.get("processID"), int) or row["processID"] <= 0
                or not isinstance(row.get("elapsedSeconds"), (int, float)) or row["elapsedSeconds"] <= 0
                or len(row.get("batchMilliseconds", [])) != count // 50
                or len(row.get("lookupMilliseconds", [])) != 100
                or len(row.get("footprintBoundaryBytes", [])) != count // 50 + 1
                or any(not isinstance(x, int) or x <= 0 for x in row["footprintBoundaryBytes"])
                or any(not isinstance(x, (int, float)) or x < 0 for key in
                       ("batchMilliseconds", "lookupMilliseconds") for x in row[key])):
            raise ValueError("Incomplete actual performance observations")
    if len({row["processID"] for row in benchmarks}) != 1:
        raise ValueError("Initial performance process lineage differs")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    parser.add_argument("--reserved-other-bytes", default=0, type=int)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise RuntimeError("Choose a fresh evidence directory; preserve the prior attempt")
    report = {
        "status": "NOT_RUN", "scope": "APPLE_FOUNDATION_EXPLICIT_LOCAL_BACKFILL",
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(), "commands": [], "cases": [],
        "native_ui_executed": 0, "anytype_executed": 0, "network_sync_executed": 0,
        "app_relaunch_executed": 0,
        "boundaries": "Whole original Repository/SQLite/ledger/identity/planner; explicit unrelated catalog/UI/CloudKit doubles",
        "measurement_scope": "Local preparation and indexed identity reads with actual task_vm_info boundary samples; no UI/Anytype latency or peak-RSS claim",
    }
    before = None
    paths = []
    fixtures = None
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Installed Apple SDK required")
        swift = shutil.which("swift")
        if not swift:
            raise RuntimeError("Existing Swift toolchain required")
        free = shutil.disk_usage(artifacts).free
        incremental = 1_000_000_000
        margin = 2_000_000_000
        report["storage_admission"] = {
            "policy": "mac-storage-lifecycle-v2",
            "free_bytes": free, "estimated_incremental_bytes": incremental,
            "reserved_other_bytes": args.reserved_other_bytes, "os_margin_bytes": margin,
        }
        if args.reserved_other_bytes < 0 or free < incremental + margin + args.reserved_other_bytes:
            raise RuntimeError("Insufficient actual incremental disk budget")
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Actual Apple SQLite SDK required")
        report["sdk"] = str(sdk)
        report["swift"] = subprocess.check_output([swift, "--version"], text=True).strip()
        paths = provenance_paths()
        report.update(source_identity(ROOT, paths))
        before = {path: sha(ROOT / path) for path in paths}
        report["source_before"] = before
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        target = package / "Sources/AnnotationBackfillAcceptance"
        target.mkdir(parents=True)
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        if len({Path(path).name for path in SOURCES}) != len(SOURCES):
            raise ValueError("Whole-source filename collision")
        for path in SOURCES:
            shutil.copyfile(ROOT / path, target / Path(path).name)
        manifest = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AnnotationBackfillAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [.executableTarget(name: "AnnotationBackfillAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])],
    swiftLanguageModes: [.v6])
""".replace("CORE_PATH", json.dumps(str(ROOT / "Source/Otzaria/Actions")))
        (package / "Package.swift").write_text(manifest, encoding="utf-8")
        command = [swift, "build", "--package-path", str(package), "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        run_logged(command, ROOT, artifacts, "compile", 480, report)
        binary_dir = run_logged(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report).strip()
        binary = Path(binary_dir) / "AnnotationBackfillAcceptance"
        report["executable_sha256"] = sha(binary)
        run_logged([str(binary), "checks", str(fixtures)], ROOT, artifacts, "component-cases", 600, report)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        if (len(report["cases"]) != len(EXPECTED_CASES)
                or {row.get("name") for row in report["cases"]} != EXPECTED_CASES
                or any(row.get("status") != "PASS" or row.get("error") is not None for row in report["cases"])):
            raise ValueError("All 13 exact actual-source cases must pass")
        benchmarks = json.loads((fixtures / "BENCHMARKS.json").read_text())
        verify_measurements(benchmarks)
        report["measurements"] = benchmarks
        report["independent_readback"] = [
            readback(fixtures / ("performance-" + str(row["count"])) / "Annotations.sqlite",
                     row["count"], row["originalDigestBefore"])
            for row in benchmarks
        ]
        run_logged([str(binary), "reopen-5000", str(fixtures)], ROOT, artifacts, "reopen-5000", 300, report)
        cold = json.loads((fixtures / "reopen-5000.json").read_text())
        if (cold.get("reused") != "5000" or cold.get("originalDigest") != benchmarks[-1]["originalDigestBefore"]
                or int(cold.get("processID", "0")) <= 0 or int(cold["processID"]) == benchmarks[-1]["processID"]):
            raise ValueError("Independent 5000-note cold process did not preserve plans")
        report["cold_5000"] = cold
        run_logged([str(binary), "crash-write", str(fixtures)], ROOT, artifacts, "crash-write", 90, report, expected_exit=73)
        writer = json.loads((fixtures / "crash-writer.json").read_text())
        run_logged([str(binary), "crash-reopen", str(fixtures)], ROOT, artifacts, "crash-reopen", 90, report)
        reopen = json.loads((fixtures / "crash-reopen.json").read_text())
        pids = [benchmarks[-1]["processID"], int(cold["processID"]), int(writer.get("processID", "0")), int(reopen.get("processID", "0"))]
        if (len(set(pids)) != 4 or min(pids) <= 0
                or writer.get("originalDigest") != reopen.get("originalDigest")
                or reopen.get("prepared") != "50" or reopen.get("reused") != "50"):
            raise ValueError("Actual committed-batch crash/reopen lineage differs")
        report["crash_processes"] = [writer, reopen]
        report["independent_readback"].append(
            readback(fixtures / "crash/Annotations.sqlite", 100, writer["originalDigest"]))
        report["source_after_identity"] = source_identity(ROOT, paths)
        if report["source_after_identity"]["source_sha"] != report["source_sha"]:
            raise RuntimeError("Canonical source changed during execution")
        report["status"] = "PASS_APPLE_FOUNDATION_LOCAL_BACKFILL"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        if fixtures is not None and (fixtures / "CASES.json").is_file():
            report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        if before is not None:
            report["source_after"] = {path: sha(ROOT / path) for path in paths}
            report["source_unchanged"] = before == report["source_after"]
            if not report["source_unchanged"]:
                report["status"] = "FAILED"
        report["passed_cases"] = sum(row.get("status") == "PASS" for row in report["cases"])
        report["failed_cases"] = sum(row.get("status") != "PASS" for row in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({key: report[key] for key in ("status", "passed_cases", "failed_cases")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_LOCAL_BACKFILL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
