#!/usr/bin/env python3
"""Actual original Store/Repository/local-body gate on an installed Apple SDK.

Compiles whole original sources; only unrelated catalog/UI/CloudKit boundaries
are explicit doubles. This is a Foundation component gate, not an Anytype editor
mount, CloudKit transport, app relaunch, or XCTest UI acceptance. No compiler or
SDK is installed/downloaded. Every writable database is an owned fixture.
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
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "Source/Features/Annotations/Models/Annotation.swift",
    "Source/Features/Annotations/Models/AnnotationNode.swift",
    "Source/Features/Annotations/Models/AnnotationChangeTypes.swift",
    "Source/Features/Annotations/Models/AnnotationEvent.swift",
    "Source/Features/Annotations/Database/AnnotationRepository.swift",
    "Source/ChavrusaText/Annotations/AnnotationCloudImportIdentity.swift",
    "Source/Features/Annotations/Database/AnnotationStore.swift",
    "Source/Core/Database/SQLiteDatabase.swift",
    "Source/Core/CloudKit/SyncPendingStore.swift",
    "Source/ChavrusaText/Annotations/Exchange/TorahAnnotationEnvelope.swift",
    "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift",
    "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeIdentity.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorModels.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorSession.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudOwnership.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudKit.swift",
    "Source/Core/CloudKit/CloudKitCoreManager.swift",
    "Source/Core/CloudKit/CloudKitUploadDebouncer.swift",
    "Source/Core/CloudKit/CloudKitSyncable.swift",
    "Source/Core/CloudKit/AnnotationSyncHandler.swift",
    "Tests/HQ/local-annotation-cloud/LocalAnnotationCloudBoundary.swift",
    "Tests/HQ/sqlite/UnusedZstdBoundary.swift",
    "Tests/HQ/local-annotation-editor/LocalAnnotationEditorBoundary.swift",
    "Tests/HQ/local-annotation-editor/LocalAnnotationEditorAcceptance.swift",
]
CASE_COUNT = 43
COLD_MODES = ("cold-write", "cold-reopen", "cold-reopen-final")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def declaration_names(text):
    names = re.findall(r'await run\("([a-z0-9_]+)"\)', text)
    if len(names) != CASE_COUNT or len(set(names)) != CASE_COUNT:
        raise ValueError("Expected all 43 unique actual-source component declarations")
    return names


def verify_cases(rows, expected):
    if not isinstance(rows, list) or len(rows) != CASE_COUNT:
        raise ValueError("Missing component results")
    names = [row.get("name") for row in rows]
    if len(set(names)) != CASE_COUNT or set(names) != set(expected):
        raise ValueError("Component results do not match all exact declarations")
    if any(row.get("status") != "PASS" or row.get("error") is not None for row in rows):
        raise ValueError("Component failure or unexecuted case")


def verify_cold(observations, first, second):
    if len(observations) != 3 or [x.get("mode") for x in observations] != list(COLD_MODES):
        raise ValueError("All three original executable processes are required")
    pids = [x.get("processID") for x in observations]
    if any(type(pid) is not int or pid <= 0 for pid in pids) or len(set(pids)) != 3:
        raise ValueError("Three distinct actual process IDs required")
    for index, row in enumerate(observations):
        expected = first if index == 0 else second
        if (row.get("status") != "PASS_COMPONENT_COLD_PROCESS"
                or row.get("originalPendingUpload") is not True
                or type(row.get("exchangeDestinations")) is not int or row["exchangeDestinations"] != 0
                or type(row.get("revision")) is not int or row["revision"] != (1 if index == 0 else 2)
                or row.get("annotationUUID") != first["annotationUUID"]
                or row.get("payloadSHA256") != expected["payloadSHA256"]
                or row.get("sourceSHA256") != expected["sourceSHA256"]
                or not isinstance(row.get("sqliteVersion"), str) or not row["sqliteVersion"]):
            raise ValueError("Cold component receipt mismatch")
    if observations[0].get("priorProcessID") is not None:
        raise ValueError("Initial writer unexpectedly reused a prior process")
    if observations[1].get("priorProcessID") != pids[0] or observations[2].get("priorProcessID") != pids[1]:
        raise ValueError("Cold process lineage mismatch")
    if first.get("processID") != pids[0] or second.get("processID") != pids[1]:
        raise ValueError("Expected records are not bound to actual writer processes")
    if (first.get("annotationUUID") != second.get("annotationUUID")
            or type(first.get("rowID")) is not int or first["rowID"] <= 0
            or type(second.get("rowID")) is not int or first["rowID"] != second.get("rowID")
            or first.get("revision") != 1 or second.get("revision") != 2
            or first.get("mutationID") == second.get("mutationID")):
        raise ValueError("Cold original row/UUID or new immutable revision mismatch")
    for record in (first, second):
        if type(record.get("processID")) is not int or type(record.get("revision")) is not int:
            raise ValueError("Cold record identity/revision type mismatch")
        if any(str(uuid.UUID(record[key])).upper() != record[key] for key in ("annotationUUID", "mutationID")):
            raise ValueError("Cold record UUID is not the original canonical identity")
        for content, digest in (("payload", "payloadSHA256"), ("source", "sourceSHA256")):
            raw = base64.b64decode(record[content], validate=True)
            if hashlib.sha256(raw).hexdigest() != record[digest]:
                raise ValueError("Independent Python cold byte/digest mismatch")


def verify_sqlite(fixtures, first, second):
    database = fixtures / "cold-profile/Annotations.sqlite"
    if any(Path(x["databasePath"]).resolve() != database.resolve() for x in (first, second)):
        raise ValueError("Only the actual owned fixture DB is allowed")
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        row = connection.execute("SELECT id, ckRecordId, note FROM annotations").fetchall()
        if row != [(second["rowID"], second["annotationUUID"], second["note"])]:
            raise ValueError("Independent original row/UUID/preview differs")
        versions = connection.execute("SELECT mutation_id, annotation_uuid, revision, payload_base64, payload_digest, destinations_json FROM otzaria_annotation_exchange_versions ORDER BY revision").fetchall()
        expected = [(x["mutationID"], x["annotationUUID"], x["revision"], x["payload"], x["payloadSHA256"], "[]") for x in (first, second)]
        if versions != expected:
            raise ValueError("Independent immutable rich version bytes differ")
        heads = connection.execute("SELECT namespace, annotation_uuid, revision FROM otzaria_annotation_exchange_heads").fetchall()
        if heads != [("otzaria.local.annotation", second["annotationUUID"], 2)]:
            raise ValueError("Independent current rich head differs")
        tags = [x[0] for x in connection.execute("SELECT t.name FROM tags t INNER JOIN annotation_tags a ON a.tagId=t.id WHERE a.annotationId=? ORDER BY t.name COLLATE NOCASE ASC", (second["rowID"],))]
        if tags != first["tags"] or tags != second["tags"]:
            raise ValueError("Independent original tags changed")
        if connection.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] != 0:
            raise ValueError("Offline editor generated an external delivery")
        if connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload'", (second["annotationUUID"],)).fetchone()[0] != 1:
            raise ValueError("Original durable upload queue missing")
        if connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete'").fetchone()[0] != 1:
            raise ValueError("Unrelated original CloudKit delete changed")
        return {"database_path": str(database), "versions": len(versions), "tags": len(tags),
                "same_annotation_uuid": True, "same_original_row": True,
                "zero_external_destinations": True, "payload_hashes": [x["payloadSHA256"] for x in (first, second)]}
    finally:
        connection.close()


def run_logged(command, cwd, artifacts, label, timeout, report):
    record = {"label": label, "command": command, "timeout_seconds": timeout,
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    report["commands"].append(record)
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, encoding="utf-8", timeout=timeout)
        record["exit_code"] = result.returncode
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        record["timed_out"] = True
        def text(value):
            return value.decode("utf-8", "replace") if isinstance(value, bytes) else value or ""
        output = text(error.stdout) + text(error.stderr)
        (artifacts / (label + ".log")).write_bytes(output.encode("utf-8"))
        raise
    finally:
        record["seconds"] = time.monotonic() - started
        record["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (artifacts / (label + ".log")).write_bytes(output.encode("utf-8"))
    if result.returncode:
        raise RuntimeError(label + " failed with exit " + str(result.returncode))
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise RuntimeError("Preserve prior attempt: choose a fresh evidence directory")
    report = {"status": "NOT_RUN", "scope": "APPLE_FOUNDATION_ORIGINAL_STORE_COMPONENT",
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "host": platform.platform(), "commands": [], "cases": [], "cold_processes": [],
              "native_ui_executed": 0, "anytype_executed": 0, "cloudkit_transport_executed": 0,
              "app_relaunch_executed": 0, "live_exchange_enabled": False,
              "boundaries": "Whole Store/Repository/SQLite/ledger/session; explicit catalog/UI/CloudKit doubles"}
    before = None
    provenance = []
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Installed Apple SDK required; no fallback or compiler installation")
        swift = shutil.which("swift")
        if not swift:
            raise RuntimeError("Existing Swift compiler required")
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Original Apple SDK SQLite3 module required")
        core = ROOT / "Source/Otzaria/Actions"
        provenance = SOURCES + ["tools/hq-local-annotation-editor-acceptance.py", "tools/exact-source-archive.py", "Maktabah.xcodeproj/project.pbxproj",
            "Source/Core/Database/CloudKitSyncManager.swift", "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift"]
        provenance += [str(p.relative_to(ROOT)).replace("\\", "/") for p in sorted(core.rglob("*"))
                       if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json", ".resolved")]
        if not (core / "Package.swift").is_file():
            raise RuntimeError("Whole original local Core package required")
        before = {p: sha(ROOT / p) for p in provenance}
        report["source_before"] = before
        report.update(runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"](ROOT, provenance))
        report["swift"] = subprocess.check_output([swift, "--version"], text=True).strip()
        report["sdk"] = str(sdk)
        expected = declaration_names((ROOT / SOURCES[-1]).read_text(encoding="utf-8"))
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        target = package / "Sources/LocalAnnotationEditorAcceptance"
        target.mkdir(parents=True)
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        for source in SOURCES:
            shutil.copyfile(ROOT / source, target / Path(source).name)
        if len({Path(p).name for p in SOURCES}) != len(SOURCES):
            raise ValueError("Whole-source filename collision")
        manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LocalAnnotationEditorAcceptance",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [.executableTarget(name: "LocalAnnotationEditorAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])],
    swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps(core.as_posix()))
        (package / "Package.swift").write_bytes(manifest.encode("utf-8"))
        command = [swift, "build", "--package-path", str(package), "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        run_logged(command, ROOT, artifacts, "compile", 480, report)
        binary_path = run_logged(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report).strip()
        executable = Path(binary_path) / "LocalAnnotationEditorAcceptance"
        report["executable_sha256"] = sha(executable)
        run_logged([str(executable), "self-tests", str(fixtures)], ROOT, artifacts, "component-cases", 180, report)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text(encoding="utf-8"))
        verify_cases(report["cases"], expected)
        for mode in COLD_MODES:
            run_logged([str(executable), mode, str(fixtures)], ROOT, artifacts, mode, 45, report)
            report["cold_processes"].append(json.loads((fixtures / (mode + ".json")).read_text(encoding="utf-8")))
        first = json.loads((fixtures / "cold-expected-1.json").read_text(encoding="utf-8"))
        second = json.loads((fixtures / "cold-expected-2.json").read_text(encoding="utf-8"))
        verify_cold(report["cold_processes"], first, second)
        report["independent_sqlite_readback"] = verify_sqlite(fixtures, first, second)
        report["independent_bytes"] = {"first_payload": first["payloadSHA256"], "second_payload": second["payloadSHA256"]}
        report["cold_reopen_gates"] = 2
        if before != {p: sha(ROOT / p) for p in provenance}:
            raise RuntimeError("Source changed during actual execution")
        report["status"] = "PASS_APPLE_FOUNDATION_COMPONENT"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        if before is not None:
            final_identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"](ROOT, provenance)
            if final_identity["source_sha"] != report["source_sha"] or final_identity["source_archive"] != report["source_archive"]:
                report["status"] = "FAILED"
            report["source_after"] = {p: sha(ROOT / p) for p in provenance}
            report["source_unchanged"] = before == report["source_after"]
            if not report["source_unchanged"]:
                report["status"] = "FAILED"
        report["passed_cases"] = sum(x.get("status") == "PASS" for x in report["cases"])
        report["failed_cases"] = sum(x.get("status") != "PASS" for x in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({k: report[k] for k in ("status", "passed_cases", "failed_cases")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_COMPONENT" else 1


if __name__ == "__main__":
    raise SystemExit(main())
