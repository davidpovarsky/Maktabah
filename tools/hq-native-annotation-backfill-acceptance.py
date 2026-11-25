#!/usr/bin/env python3
"""Actual Apple Foundation controls for native Backfill candidate selection.

Whole original Store/Repository/SQLite/local-save files plus the unchanged
Backfill planner and the new read-only catalog are compiled. Explicit existing
catalog/UI/CloudKit doubles and a test.opaque body isolate this component gate.
No Anytype engine, editor UI, network delivery or 5,000-native-note claim is made.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import platform
import re
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
    "Source/ChavrusaText/Annotations/Backfill/AnnotationNativeBackfillCatalog.swift",
    "Tests/HQ/native-annotation-backfill/AnnotationNativeBackfillAcceptance.swift",
]
PRODUCT_CONTEXT = [
    "Source/ChavrusaText/Annotations/Backfill/AnnotationNativeBackfillModel.swift",
    "Source/ChavrusaText/Annotations/Backfill/AnnotationNativeBackfillSection.swift",
    "Source/ChavrusaText/Annotations/Backfill/AnnotationBackfillView.swift",
    "Source/ChavrusaText/Annotations/Backfill/AnnotationBackfill.xcstrings",
]
EXPECTED_CASES = [
    "unprepared_discovery_does_not_install_schema_or_register_identity",
    "current_plan_preserves_legacy_and_uuid_original_identity",
    "utf8_8192_boundary_preserves_multibyte_and_long_note_bytes",
    "capture_text_comparison_rejects_normalization_nul_and_truncation",
    "native_seed_1mib_boundary_retains_oversize_bytes",
    "same_preview_different_full_text_is_refused",
    "long_preview_requires_exact_scalar_boundary",
    "saved_text_changed_after_plan_requires_new_explicit_preparation",
    "candidate_rechecks_original_metadata_and_revision_before_native_work",
    "existing_opaque_rich_body_is_preserved_without_native_decode",
    "future_envelope_is_retained_without_downgrade",
    "highlights_and_pending_deletions_are_not_converted",
    "retired_run_cannot_read_or_recover_current_authority",
    "original_profile_switch_retires_captured_scan",
    "bounded_scan_rejects_foreign_session_and_invalid_cursor",
    "resume_uses_real_canonical_saved_version_without_duplicate_conversion",
    "sqlite_nul_text_is_refused_without_truncated_selection",
]
sha = ORIGINAL["sha"]
write_json = ORIGINAL["write_json"]
run_logged = ORIGINAL["run_logged"]


def verify_cases(rows):
    if (not isinstance(rows, list) or len(rows) != len(EXPECTED_CASES)
            or [x.get("name") for x in rows] != EXPECTED_CASES
            or any(x.get("status") != "PASS" or x.get("error") is not None for x in rows)):
        raise ValueError("All 17 exact new selection and full-text boundary cases must execute and pass")


def readonly(database):
    return sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)


def verify_sqlite(fixtures):
    observation = {}
    with readonly(fixtures / "boundaries/Annotations.sqlite") as db:
        rows = db.execute("SELECT id,CAST(note AS BLOB) FROM annotations ORDER BY id").fetchall()
        expected = [(1, ("א" * 4096).encode()), (2, ("א" * 4096 + "x").encode()),
                    (3, ("📖" * 2048).encode())]
        if rows != expected:
            raise ValueError("Original UTF-8 boundary/long-note bytes differ")
        if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Boundary fixture SQLite integrity failure")
        observation["unchanged_note_bytes"] = [len(x[1]) for x in rows]
        observation["unchanged_note_sha256"] = [hashlib.sha256(x[1]).hexdigest() for x in rows]
        if db.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] != 0:
            raise ValueError("Selection generated an Anytype destination")
    with readonly(fixtures / "seed-limit/Annotations.sqlite") as db:
        rows = db.execute("SELECT id,CAST(note AS BLOB) FROM annotations ORDER BY id").fetchall()
        expected = [(1, ("א" * 524288).encode()), (2, ("א" * 524288 + "x").encode())]
        if rows != expected or db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Original 1 MiB/oversize UTF8 bytes or SQLite integrity differ")
        if db.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] != 0:
            raise ValueError("Native-size selection generated an Anytype destination")
        if db.execute("SELECT COUNT(*) FROM sync_pending").fetchone()[0] != 2:
            raise ValueError("Native-size selection changed original pending rows")
        observation["original_seed_size_note_bytes"] = [len(x[1]) for x in rows]
        observation["original_seed_size_note_sha256"] = [hashlib.sha256(x[1]).hexdigest() for x in rows]
    with readonly(fixtures / "same-preview/Annotations.sqlite") as db:
        text = ("a" * 8192 + " complete original סוף").encode()
        if db.execute("SELECT CAST(note AS BLOB) FROM annotations").fetchone()[0] != text:
            raise ValueError("A matching preview hid a changed complete saved note")
        if db.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_versions WHERE namespace='otzaria.local.annotation'").fetchone()[0] != 0:
            raise ValueError("Rejected full-text mismatch created a rich saved revision")
        observation["full_text_mismatch_preserved_original"] = True
    with readonly(fixtures / "canonical-resume/Annotations.sqlite") as db:
        rows = db.execute("SELECT ckRecordId,note FROM annotations").fetchall()
        if rows != [("00000000-0000-4000-8000-000000000001", "saved byte-exact")]:
            raise ValueError("Resume original record/text mismatch")
        versions = db.execute("""
            SELECT annotation_uuid,revision,payload_base64,payload_digest,destinations_json
            FROM otzaria_annotation_exchange_versions
            WHERE namespace='otzaria.local.annotation'
        """).fetchall()
        if len(versions) != 1 or versions[0][0] != rows[0][0] or versions[0][1] != 1 or versions[0][4] != "[]":
            raise ValueError("Canonical saved revision missing or duplicated")
        import base64
        payload = base64.b64decode(versions[0][2], validate=True)
        if hashlib.sha256(payload).hexdigest() != versions[0][3]:
            raise ValueError("Canonical opaque component bytes changed")
        observation["component_body_sha256"] = versions[0][3]
        if db.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] != 0:
            raise ValueError("Resume generated a transport entry")
        if db.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload'", (rows[0][0],)).fetchone()[0] != 1:
            raise ValueError("Original durable upload queue missing")
        if db.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id IN ('other-upload','other-delete')").fetchone()[0] != 2:
            raise ValueError("Unrelated original pending entries changed")
        if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Resume fixture SQLite integrity failure")
        observation["canonical_local_versions"] = 1
        observation["original_upload_pending"] = True
        observation["anytype_outbox_count"] = 0
    with readonly(fixtures / "legacy/Annotations.sqlite") as db:
        original = db.execute("SELECT ckRecordId FROM annotations").fetchone()[0]
        if original != "legacy_2_1_0_1700000000":
            raise ValueError("Legacy CloudKit identity rewritten")
        observation["original_legacy_cloudkit_identity_preserved"] = True
    return observation


def tree_bytes(root):
    return sum(p.stat().st_size for p in root.rglob("*") if p.is_file() and not p.is_symlink())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    parser.add_argument("--expected-growth-bytes", type=int, default=1024 * 1024 * 1024)
    parser.add_argument("--concurrent-growth-bytes", type=int, required=True)
    parser.add_argument("--os-margin-bytes", type=int, default=5 * 1024 * 1024 * 1024)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise RuntimeError("Preserve the prior attempt; choose a fresh evidence directory")
    report = {"status": "NOT_RUN", "scope": "APPLE_FOUNDATION_NATIVE_BACKFILL_SELECTION",
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "host": platform.platform(), "commands": [], "cases": [],
              "anytype_executed": 0, "native_ui_executed": 0, "native_5000_executed": 0,
              "cloudkit_transport_executed": 0, "app_relaunch_executed": 0,
              "boundaries": "Whole original SQLite/save/identity + unchanged planner; explicit catalog/UI/CloudKit doubles; test.opaque fixture body. Native worker/UI are source provenance only."}
    before = None
    provenance = []
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Installed Apple SDK required; no fallback or compiler installation")
        if any(x < 0 for x in (args.expected_growth_bytes, args.concurrent_growth_bytes, args.os_margin_bytes)):
            raise ValueError("Storage budgets must be nonnegative")
        free = shutil.disk_usage(artifacts).free
        required = args.expected_growth_bytes + args.concurrent_growth_bytes + args.os_margin_bytes
        report["storage_admission"] = {"free_bytes": free, "estimated_new_bytes": args.expected_growth_bytes,
            "reserved_concurrent_growth_bytes": args.concurrent_growth_bytes,
            "os_margin_bytes": args.os_margin_bytes, "required_bytes": required}
        if free < required:
            raise RuntimeError("The current incremental and concurrent storage budget does not fit")
        swift = shutil.which("swift")
        if not swift:
            raise RuntimeError("Existing Swift compiler required")
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Original Apple SDK SQLite3 module required")
        core = ROOT / "Source/Otzaria/Actions"
        if not (core / "Package.swift").is_file():
            raise RuntimeError("Whole original local Core package required")
        provenance = SOURCES + PRODUCT_CONTEXT + [
            "tools/hq-local-annotation-editor-acceptance.py",
            "tools/hq-native-annotation-backfill-acceptance.py", "tools/exact-source-archive.py"]
        provenance += [str(p.relative_to(ROOT)) for p in sorted(core.rglob("*"))
                       if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json", ".resolved")]
        if len(set(provenance)) != len(provenance):
            raise ValueError("Duplicate provenance input")
        before = {p: sha(ROOT / p) for p in provenance}
        report["source_before"] = before
        report.update(runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"](ROOT, provenance))
        report["swift"] = subprocess.check_output([swift, "--version"], text=True).strip()
        report["sdk"] = str(sdk)
        declarations = re.findall(r'        run\("([a-z0-9_]+)"\)', (ROOT / SOURCES[-1]).read_text())
        if declarations != EXPECTED_CASES:
            raise ValueError("Swift declarations do not match the fixed 17-case gate")
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        target = package / "Sources/NativeAnnotationBackfillAcceptance"
        target.mkdir(parents=True)
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        if len({Path(p).name for p in SOURCES}) != len(SOURCES):
            raise ValueError("Whole-source filename collision")
        for source in SOURCES:
            shutil.copyfile(ROOT / source, target / Path(source).name)
        manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NativeAnnotationBackfillAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [.executableTarget(name: "NativeAnnotationBackfillAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])],
    swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps(core.as_posix()))
        (package / "Package.swift").write_text(manifest)
        command = [swift, "build", "--package-path", str(package), "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        run_logged(["/usr/bin/time", "-l"] + command, ROOT, artifacts, "compile", 480, report)
        binary_path = run_logged(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report).strip()
        executable = Path(binary_path) / "NativeAnnotationBackfillAcceptance"
        report["executable_sha256"] = sha(executable)
        run_logged([str(executable), "checks", str(fixtures)], ROOT, artifacts, "selection-cases", 180, report)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        verify_cases(report["cases"])
        run_logged([str(executable), "cold-rescan", str(fixtures)], ROOT, artifacts, "cold-rescan", 45, report)
        first = json.loads((fixtures / "RESUME.json").read_text())
        cold = json.loads((fixtures / "COLD.json").read_text())
        first_pid, cold_pid = int(first["processID"]), int(cold["processID"])
        if (first_pid <= 0 or cold_pid <= 0 or first_pid == cold_pid
                or first["localBodyVersions"] != "1" or cold["retainedRich"] != "1"
                or cold["newNativeOperations"] != "0"):
            raise ValueError("Distinct cold process and canonical skip evidence required")
        report["cold_rescan"] = {"first_process_id": first_pid, "cold_process_id": cold_pid,
            "canonical_rich_retained": True, "new_native_operations": 0,
            "scope": "Actual separate Foundation executable process, not the iOS app"}
        report["independent_sqlite_readback"] = verify_sqlite(fixtures)
        report["actual_owned_bytes"] = tree_bytes(owned)
        if before != {p: sha(ROOT / p) for p in provenance}:
            raise RuntimeError("Source changed during actual execution")
        report["status"] = "PASS_APPLE_FOUNDATION_NATIVE_BACKFILL_SELECTION"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        if "owned_directory" in report:
            case_file = Path(report["owned_directory"]) / "fixtures/CASES.json"
            if case_file.is_file():
                try:
                    report["cases"] = json.loads(case_file.read_text())
                except Exception as error:
                    report["cases_read_error"] = repr(error)
            report["actual_owned_bytes"] = tree_bytes(Path(report["owned_directory"]))
        if before is not None:
            report["source_after"] = {p: sha(ROOT / p) for p in provenance}
            report["source_unchanged"] = before == report["source_after"]
            if not report["source_unchanged"]:
                report["status"] = "FAILED"
            final_identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"](ROOT, provenance)
            if final_identity["source_sha"] != report["source_sha"] or final_identity["source_archive"] != report["source_archive"]:
                report["status"] = "FAILED"
        report["passed_cases"] = sum(x.get("status") == "PASS" for x in report["cases"])
        report["failed_cases"] = sum(x.get("status") != "PASS" for x in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        report["free_bytes_after"] = shutil.disk_usage(artifacts).free
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({k: report[k] for k in ("status", "passed_cases", "failed_cases")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_NATIVE_BACKFILL_SELECTION" else 1


if __name__ == "__main__":
    raise SystemExit(main())
