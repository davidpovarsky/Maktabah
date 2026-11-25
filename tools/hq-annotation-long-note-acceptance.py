#!/usr/bin/env python3
"""Actual original SQLite long-note first-conversion gate; never native SDK/UI."""
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
import subprocess
import sys
import time
import traceback
import uuid

ROOT = Path(__file__).resolve().parents[1]
AREA = "Tests/HQ/annotation-long-note"
HARNESS = AREA + "/LongNotePreservationAcceptance.swift"
DRIVER = "tools/hq-annotation-long-note-acceptance.py"
BASELINE = "Tests/HQ/annotation-native-revision/product-inputs.json"
PRODUCT_SHA = "ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f"
CASE_COUNT = 23
PREFIX_MARKER = b"@MainActor\nfinal class LocalCases"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha_bytes(raw):
    return hashlib.sha256(raw).hexdigest()


def sha(path):
    return sha_bytes(path.read_bytes())


def decode64(text):
    return base64.b64decode(text, validate=True)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def verify_cold(fixtures):
    expected = json.loads((fixtures / "long-cold-expected.json").read_text())
    writer = json.loads((fixtures / "cold-write.json").read_text())
    reader = json.loads((fixtures / "cold-reopen.json").read_text())
    pids = [writer["processID"], reader["processID"]]
    require(all(type(p) is int and p > 0 for p in pids) and len(set(pids)) == 2,
            "Cold processes must be distinct actual native executions")
    require(writer["status"] == "PASS_ORIGINAL_LONG_NOTE_COMMITTED" and
            reader["status"] == "PASS_ORIGINAL_LONG_NOTE_COLD_REOPEN" and
            expected["processID"] == pids[0] == reader["writerProcessID"] and
            reader["nativeExecution"] is False, "Cold receipt lineage or scope mismatch")
    database = fixtures / "long-cold-profile/Annotations.sqlite"
    require(database.resolve() == Path(expected["databasePath"]).resolve() and database.is_file(),
            "Evidence must refer to the exact owned original SQLite file")
    note = decode64(expected["noteBase64"])
    preview = decode64(expected["previewBase64"])
    require(len(note) == expected["noteByteCount"] > 8192 and
            sha_bytes(note) == expected["noteSHA256"] and
            len(preview) <= 8192 and note.startswith(preview), "Invalid complete UTF-8 note receipt")
    require("\u05e9".encode() in note and "English".encode() in note and "\U0001f4da".encode() in note,
            "Mixed Hebrew/English/multibyte fixture missing")
    for data_key, sha_key in (("sourceBase64", "sourceSHA256"), ("payloadBase64", "payloadSHA256")):
        require(sha_bytes(decode64(expected[data_key])) == expected[sha_key] == reader[sha_key],
                "Cold immutable byte hash or source witness differs")
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        require(connection.execute("PRAGMA integrity_check").fetchall() == [("ok",)],
                "Independent SQLite integrity failed")
        original = connection.execute("SELECT id,ckRecordId,CAST(note AS BLOB),lastModified FROM annotations").fetchall()
        require(original == [(expected["rowID"], expected["annotationUUID"], note, expected["lastModified"])],
                "Actual original row/CloudKit identity/full text/timestamp differ")
        versions = connection.execute(
            "SELECT mutation_id,annotation_uuid,revision,payload_base64,payload_digest,destinations_json "
            "FROM otzaria_annotation_exchange_versions").fetchall()
        require(versions == [(expected["mutationID"], expected["annotationUUID"], 1,
                              expected["payloadBase64"], expected["payloadSHA256"], "[]")],
                "Cold conversion did not retain exactly one immutable local version")
        payload = json.loads(decode64(expected["payloadBase64"]))
        require(payload["namespace"] == "otzaria.local.annotation" and payload["schemaVersion"] == 1 and
                payload["annotationUUID"] == expected["annotationUUID"] and payload["deletionState"] == "active" and
                payload["textPreview"].encode("utf-8") == preview and
                payload["richBody"]["bytesBase64"] == expected["bodyBase64"] and
                payload["richBody"]["format"] == "org.otzaria.acceptance.two-blocks" and
                payload["richBody"]["formatVersion"] == 1,
                "Actual stored envelope/body differs from the committed original fixture")
        heads = connection.execute("SELECT namespace,annotation_uuid,revision FROM otzaria_annotation_exchange_heads").fetchall()
        require(heads == [("otzaria.local.annotation", expected["annotationUUID"], 1)], "Cold rich head changed")
        tags = [x[0] for x in connection.execute(
            "SELECT t.name FROM tags t INNER JOIN annotation_tags a ON a.tagId=t.id "
            "WHERE a.annotationId=? ORDER BY t.name COLLATE NOCASE ASC", (expected["rowID"],))]
        require(tags == expected["tags"], "Original tags changed on cold reopen")
        require(connection.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] == 0,
                "Local conversion manufactured external delivery or ACK")
        require(connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation='upload'",
                                   (expected["annotationUUID"],)).fetchone()[0] == 1,
                "Original pending upload was lost")
        require(connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id='unrelated-delete' AND operation='delete'").fetchone()[0] == 1,
                "Unrelated original pending deletion changed")
        return {"writer": writer, "reader": reader, "database_path": str(database),
                "integrity_check": "ok", "full_note_bytes": len(note), "full_note_sha256": sha_bytes(note),
                "preview_bytes": len(preview), "versions": 1, "outbox_count": 0,
                "source_sha256": expected["sourceSHA256"], "payload_sha256": expected["payloadSHA256"]}
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    parser.add_argument("--anticipated-concurrent-growth-gib", required=True, type=float)
    parser.add_argument("--os-margin-gib", required=True, type=float)
    args = parser.parse_args()
    require(args.anticipated_concurrent_growth_gib >= 0 and args.os_margin_gib >= 0, "Invalid resource plan")
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    require(not (artifacts / "RESULT.json").exists(), "Preserve previous attempts; choose a fresh directory")
    reserve = int((args.anticipated_concurrent_growth_gib + args.os_margin_gib) * 1024**3)
    report = {"status": "NOT_RUN", "scope": "APPLE_FOUNDATION_ORIGINAL_SQLITE_LONG_NOTE_PRESERVATION",
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "host": platform.platform(),
              "commands": [], "cases": [], "original43_reexecuted": False, "original36_reexecuted": False,
              "native_sdk_executed": 0, "native_ui_executed": 0, "cloudkit_transport_executed": 0,
              "live_exchange_enabled": False, "product_source_sha": PRODUCT_SHA,
              "boundaries": "Whole original Store/Repository/SQLite/ledger/session; original catalog/UI/CloudKit doubles",
              "body_fixture": "Opaque original component body; not an Anytype archive",
              "resource_plan": {"own_initial_peak_bytes": 1024**3, "other_remaining_and_os_bytes": reserve}}
    provenance, before, identity, owned = [], None, None, None

    def admit(phase, remaining):
        free = shutil.disk_usage(artifacts).free
        report.setdefault("phase_admissions", []).append(
            {"phase": phase, "free_bytes": free, "own_remaining_peak_bytes": remaining,
             "other_remaining_and_os_bytes": reserve, "required_free_bytes": remaining + reserve})
        write_json(artifacts / "RESULT.json", report)
        require(free >= remaining + reserve, "Recorded incremental storage admission failed: " + phase)

    def run(label, command, timeout):
        command = list(map(str, command))
        log = artifacts / (label + ".log")
        record = {"label": label, "command": command, "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        report["commands"].append(record)
        start = time.monotonic()
        with log.open("wb") as output:
            process = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            record["processID"] = process.pid
            write_json(artifacts / "RESULT.json", report)
            while True:
                try:
                    result = process.wait(timeout=5)
                    break
                except subprocess.TimeoutExpired:
                    reason = "owned command timeout" if time.monotonic() - start >= timeout else (
                        "actual remaining resource reserve consumed" if shutil.disk_usage(artifacts).free < reserve else None)
                    if reason is None:
                        continue
                    record["owned_process_stopped_reason"] = reason
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    result = 124 if time.monotonic() - start >= timeout else 125
                    break
        record.update(exit_code=result, seconds=round(time.monotonic() - start, 3),
                      log=log.name, log_sha256=sha(log), free_bytes_after=shutil.disk_usage(artifacts).free)
        write_json(artifacts / "RESULT.json", report)
        require(result == 0, label + " failed with exit " + str(result))
        return log.read_text(encoding="utf-8")

    try:
        require(sys.platform == "darwin" and platform.machine() == "arm64", "Existing real Apple arm64 runner required")
        swift = shutil.which("swift")
        require(swift is not None, "Existing Swift required; no compiler download or fallback")
        admit("before_source_preparation", 1024**3)
        original = runpy.run_path(str(ROOT / "tools/hq-local-annotation-editor-acceptance.py"))
        sources = original["SOURCES"]
        require(len(sources) == 25 and sources[-1].endswith("/LocalAnnotationEditorAcceptance.swift"),
                "Original whole-source closure changed; explicit review required")
        baseline = json.loads((ROOT / BASELINE).read_text())
        require(baseline["source_sha"] == PRODUCT_SHA and len(baseline["files"]) == 83, "Unreviewed product baseline")
        provenance = [row["path"] for row in baseline["files"]] + [BASELINE, DRIVER, HARNESS, AREA + "/case-inventory.json", AREA + "/README.md"]
        require(len(provenance) == len(set(provenance)) and set(sources).issubset(provenance),
                "Incomplete or duplicate exact original-source closure")
        before = {p: sha(ROOT / p) for p in provenance}
        for row in baseline["files"]:
            raw = (ROOT / row["path"]).read_bytes()
            require(len(raw) == row["bytes"] and sha_bytes(raw) == row["sha256"] and
                    hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() == row["git_blob"],
                    "Original input changed: " + row["path"])
        identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"]
        report.update(identity(ROOT, provenance))
        report["source_before"] = before
        report["swift"] = run("swift-version", [swift, "--version"], 30).strip()
        sdk = Path(run("sdk-path", ["xcrun", "--sdk", "macosx", "--show-sdk-path"], 30).strip())
        require((sdk / "usr/include/sqlite3.h").is_file(), "Actual Apple SQLite module missing")
        report["sdk"] = str(sdk)
        expected = json.loads((ROOT / AREA / "case-inventory.json").read_text())
        declarations = re.findall(r'await run\("([a-z0-9_]+)"\)', (ROOT / HARNESS).read_text())
        require(isinstance(expected, list) and len(expected) == len(set(expected)) == CASE_COUNT and declarations == expected,
                "Incomplete or changed long-note case inventory")
        raw_fixture = (ROOT / sources[-1]).read_bytes()
        require(raw_fixture.count(PREFIX_MARKER) == 1, "Original fixture boundary is ambiguous")
        prefix = raw_fixture.split(PREFIX_MARKER, 1)[0]
        require(b"@main" not in prefix and b"await run(" not in prefix and len(prefix) > 5000, "Invalid fixture extraction")
        report["verbatim_fixture_prefix"] = {"path": sources[-1], "sha256": sha_bytes(prefix), "bytes": len(prefix)}
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        package = owned / "package"
        target = package / "Sources/LongNotePreservationAcceptance"
        target.mkdir(parents=True)
        fixtures = owned / "fixtures"
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        copied = sources[:-1] + [HARNESS]
        require(len({Path(p).name for p in copied}) == len(copied), "Whole-source basename collision")
        for source in copied:
            shutil.copyfile(ROOT / source, target / Path(source).name)
        (target / "OriginalLocalFixture.swift").write_bytes(prefix)
        core = ROOT / "Source/Otzaria/Actions"
        manifest = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LongNotePreservationAcceptance",
    platforms: [.macOS(.v15)], dependencies: [.package(path: CORE_PATH)],
    targets: [.executableTarget(name: "LongNotePreservationAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])], swiftLanguageModes: [.v6])
""".replace("CORE_PATH", json.dumps(core.as_posix()))
        (package / "Package.swift").write_text(manifest)
        write_json(artifacts / "compiled-original-inputs.json",
                   {"whole_files": [{"path": p, "sha256": before[p]} for p in copied],
                    "original_fixture_prefix": report["verbatim_fixture_prefix"],
                    "whole_actions_package": "Source/Otzaria/Actions", "generated_manifest_sha256": sha(package / "Package.swift")})
        admit("before_original_swift_build", 1024**3)
        command = [swift, "build", "--package-path", package, "--scratch-path", owned / "swift-build", "-j", "1"]
        run("compile", command, 480)
        executable = Path(run("binary-path", command + ["--show-bin-path"], 30).strip()) / "LongNotePreservationAcceptance"
        require(executable.is_file(), "Actual compiled original executable missing")
        report["executable"] = {"path": str(executable), "sha256": sha(executable), "bytes": executable.stat().st_size}
        admit("before_component_and_cold_processes", 128 * 1024**2)
        run("component-cases", [executable, "self-tests", fixtures], 180)
        rows = json.loads((fixtures / "CASES.json").read_text())
        report["cases"] = rows
        require(len(rows) == CASE_COUNT and [row.get("name") for row in rows] == expected and
                all(row.get("status") == "PASS" and row.get("error") is None for row in rows),
                "Long-note gate has a missing or failed actual case")
        for mode in ("cold-write", "cold-reopen"):
            run(mode, [executable, mode, fixtures], 60)
        report["independent_cold_sqlite"] = verify_cold(fixtures)
        report["cold_reopen_gates"] = 1
        require(before == {p: sha(ROOT / p) for p in provenance}, "Source changed during actual execution")
        report["status"] = "PASS_APPLE_FOUNDATION_ORIGINAL_SQLITE_LONG_NOTE"
    except Exception as error:
        report.update(status="FAILED" if report["commands"] else "BLOCKED_BEFORE_EXECUTION", error=repr(error))
        (artifacts / "failure.txt").write_text(traceback.format_exc())
    finally:
        if owned is not None and (owned / "fixtures/CASES.json").is_file():
            try:
                report["cases"] = json.loads((owned / "fixtures/CASES.json").read_text())
            except Exception as error:
                report["cases_read_error"] = repr(error)
        if before is not None:
            try:
                report["source_after"] = {p: sha(ROOT / p) for p in provenance}
                report["source_unchanged"] = report["source_after"] == before
                after = identity(ROOT, provenance)
                require(after["source_sha"] == report["source_sha"] and
                        after["source_archive"] == report["source_archive"] and report["source_unchanged"],
                        "Exact committed source identity changed")
            except Exception as error:
                report.update(status="FAILED", post_source_error=repr(error))
        report["passed_cases"] = sum(row.get("status") == "PASS" for row in report["cases"])
        report["failed_cases"] = sum(row.get("status") != "PASS" for row in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        report["free_bytes_after"] = shutil.disk_usage(artifacts).free
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({k: report[k] for k in ("status", "passed_cases", "failed_cases")}, sort_keys=True))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_ORIGINAL_SQLITE_LONG_NOTE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
