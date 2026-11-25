#!/usr/bin/env python3
"""Real Apple Foundation/SQLite legacy identity controls; no native/UI/cloud claim.

The original complete local43 source closure and original Actions package are
compiled. The new standalone @main replaces only the original test entrypoint.
No application source, SQLite implementation, assertions or SDK are generated.
"""
from pathlib import Path
import argparse
import base64
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
import uuid

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = "tools/hq-local-annotation-editor-acceptance.py"
SELF = "tools/hq-legacy-annotation-identity-acceptance.py"
DECLARATIONS = "Tests/HQ/local-annotation-editor/LegacyAnnotationIdentityAcceptance.swift"
original = runpy.run_path(str(ROOT / ORIGINAL))
SOURCES = original["SOURCES"][:-1] + [DECLARATIONS]
CASE_COUNT = 24
COLD_MODES = ("legacy-write", "legacy-reopen")
sha = original["sha"]
write_json = original["write_json"]
run_logged = original["run_logged"]
source_identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"]


def provenance(root):
    paths = set(SOURCES) | {ORIGINAL, SELF, "tools/exact-source-archive.py",
        "Maktabah.xcodeproj/project.pbxproj", "Source/Core/Database/CloudKitSyncManager.swift",
        "Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift"}
    paths.update(p.relative_to(root).as_posix() for p in (root / "Source/Otzaria/Actions").rglob("*")
                 if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json", ".resolved"))
    return sorted(paths)


def declarations(text):
    names = re.findall(r'await run\("([a-z0-9_]+)"\)', text)
    if len(names) != CASE_COUNT or len(set(names)) != CASE_COUNT:
        raise ValueError("All 24 unique legacy identity controls required")
    return names


def verify_cases(rows, expected):
    if (not isinstance(rows, list) or len(rows) != CASE_COUNT
            or any(not isinstance(row, dict) for row in rows)
            or set(row.get("name") for row in rows) != set(expected)
            or any(row.get("status") != "PASS" or row.get("error") is not None for row in rows)):
        raise ValueError("Failed, skipped, duplicated or missing legacy identity controls")


def verify_cold(rows, fixtures):
    if len(rows) != 2 or [row.get("mode") for row in rows] != list(COLD_MODES):
        raise ValueError("Two actual cold processes required")
    first, second = rows
    pids = [row.get("processID") for row in rows]
    if any(type(pid) is not int or pid <= 0 for pid in pids) or len(set(pids)) != 2:
        raise ValueError("Actual process IDs must be distinct")
    if first.get("priorProcessID") is not None or second.get("priorProcessID") != pids[0]:
        raise ValueError("Cold process lineage differs")
    record = first.get("originalRecordID")
    if not isinstance(record, str) or not re.fullmatch(r"legacy_-?[0-9]+_-?[0-9]+_-?[0-9]+_-?[0-9]+", record):
        raise ValueError("Original CloudKit record was replaced")
    stable = uuid.UUID(first["annotationUUID"])
    if stable.version != 8 or str(stable).upper() != first["annotationUUID"]:
        raise ValueError("Stable alias format differs")
    db = fixtures / "legacy-cold-profile/Annotations.sqlite"
    for index, row in enumerate(rows):
        if (row.get("annotationUUID") != first["annotationUUID"] or row.get("originalRecordID") != record
                or type(row.get("annotationID")) is not int or row["annotationID"] <= 0
                or row["annotationID"] != first["annotationID"] or row.get("revision") != index + 1
                or Path(row["databasePath"]).resolve() != db.resolve()
                or any(not re.fullmatch(r"[0-9a-f]{64}", row.get(key, "")) for key in ("payloadSHA256", "sourceSHA256"))):
            raise ValueError("Cold source identity/revision/digest mismatch")
    connection = sqlite3.connect(db.as_uri() + "?mode=ro", uri=True)
    try:
        if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
            raise ValueError("Actual SQLite integrity failed")
        if connection.execute("SELECT id,ckRecordId,note FROM annotations").fetchall() != [
                (first["annotationID"], record, "legacy preview reopen")]:
            raise ValueError("Original row or CloudKit identity changed")
        if connection.execute("SELECT original_record_id,annotation_uuid,mapping_version FROM otzaria_annotation_exchange_legacy_identities").fetchall() != [
                (record, first["annotationUUID"], 1)]:
            raise ValueError("Durable alias differs")
        versions = connection.execute(
            "SELECT annotation_uuid,revision,payload_base64,payload_digest,destinations_json "
            "FROM otzaria_annotation_exchange_versions ORDER BY revision").fetchall()
        if len(versions) != 2:
            raise ValueError("Expected both immutable rich versions")
        body_hashes = []
        for version, receipt, suffix in zip(versions, rows, ("one", "reopen")):
            raw = base64.b64decode(version[2], validate=True)
            if (version[:2] != (first["annotationUUID"], receipt["revision"])
                    or version[3] != receipt["payloadSHA256"] or hashlib.sha256(raw).hexdigest() != version[3]
                    or version[4] != "[]"):
                raise ValueError("Rich bytes/digest/destination changed")
            envelope = json.loads(raw)
            body = envelope["richBody"]
            expected_body = ("opaque owned legacy body \u05e9\u05dc\u05d5\u05dd " + suffix).encode("utf-8")
            decoded_body = base64.b64decode(body["bytesBase64"], validate=True)
            if (envelope["namespace"] != "otzaria.local.annotation"
                    or envelope["annotationUUID"] != first["annotationUUID"]
                    or body["format"] != "org.otzaria.acceptance.legacy-identity"
                    or body["formatVersion"] != 1 or decoded_body != expected_body):
                raise ValueError("Actual saved opaque component bytes differ")
            body_hashes.append(hashlib.sha256(decoded_body).hexdigest())
        if connection.execute("SELECT namespace,annotation_uuid,revision FROM otzaria_annotation_exchange_heads").fetchall() != [
                ("otzaria.local.annotation", first["annotationUUID"], 2)]:
            raise ValueError("Current rich head differs")
        if connection.execute("SELECT COUNT(*) FROM otzaria_annotation_exchange_outbox").fetchone()[0] != 0:
            raise ValueError("Local identity test generated a delivery")
        for key, operation, expected in [(record, "upload", 1), (first["annotationUUID"], "upload", 0),
                                          ("unrelated-delete", "delete", 1)]:
            if connection.execute("SELECT COUNT(*) FROM sync_pending WHERE ck_record_id=? AND operation=?",
                                  (key, operation)).fetchone()[0] != expected:
                raise ValueError("Original CloudKit queue identity changed")
        if connection.execute("SELECT COUNT(*) FROM annotation_tags WHERE annotationId=?", (first["annotationID"],)).fetchone()[0] != 2:
            raise ValueError("Original tag links changed")
        return {"database_path": str(db), "sqlite_version": sqlite3.sqlite_version, "quick_check": "ok",
                "same_original_record_id": True, "same_original_row": True, "versions": 2,
                "rich_body_sha256": body_hashes, "zero_external_destinations": True}
    finally:
        connection.close()


def copies(root, target):
    names = {Path(name).name: name for name in SOURCES}
    if len(names) != len(SOURCES) or set(p.name for p in target.iterdir()) != set(names):
        raise ValueError("Compiled membership differs")
    values = {}
    for basename, name in names.items():
        file = target / basename
        if file.is_symlink() or file.read_bytes() != (root / name).read_bytes():
            raise ValueError("Compiled source differs: " + name)
        values[name] = sha(file)
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise ValueError("Preserve prior attempt")
    report = {"status": "NOT_RUN", "scope": "APPLE_FOUNDATION_LEGACY_IDENTITY_COMPONENT",
        "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(), "commands": [], "cases": [], "cold_processes": [],
        "native_ui_executed": 0, "anytype_executed": 0, "cloudkit_transport_executed": 0,
        "app_relaunch_executed": 0, "live_exchange_enabled": False,
        "boundaries": "Original Store/Repository/SQLite/ledger/local/cloud ownership sources; explicit existing UI/catalog/localization/configuration boundaries"}
    paths = []
    before = None
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Real installed Apple SDK required")
        paths = provenance(ROOT)
        identity = source_identity(ROOT, paths)
        report.update(identity)
        before = {name: sha(ROOT / name) for name in paths}
        report["source_before"] = before
        swift = shutil.which("swift")
        if not swift:
            raise RuntimeError("Existing Apple Swift required")
        report["swift"] = subprocess.check_output([swift, "--version"], text=True, timeout=30).strip()
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True, timeout=30).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Actual Apple SQLite module required")
        report["sdk"] = str(sdk)
        expected = declarations((ROOT / DECLARATIONS).read_text())
        owned = artifacts / ("owned-" + str(uuid.uuid4()))
        target = owned / "package/Sources/LegacyAnnotationIdentityAcceptance"
        fixtures = owned / "fixtures"
        target.mkdir(parents=True)
        fixtures.mkdir()
        report["owned_directory"] = str(owned)
        for name in SOURCES:
            shutil.copyfile(ROOT / name, target / Path(name).name)
        report["compiled_before"] = copies(ROOT, target)
        manifest = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LegacyAnnotationIdentityAcceptance",
    platforms: [.macOS(.v15)], dependencies: [.package(path: CORE)],
    targets: [.executableTarget(name: "LegacyAnnotationIdentityAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])], swiftLanguageModes: [.v6])
""".replace("CORE", json.dumps(str(ROOT / "Source/Otzaria/Actions")))
        (owned / "package/Package.swift").write_text(manifest)
        command = [swift, "build", "--package-path", str(owned / "package"),
                   "--scratch-path", str(owned / "swift-build"), "-j", "1"]
        run_logged(command, ROOT, artifacts, "compile", 480, report)
        binary_dir = Path(run_logged(command + ["--show-bin-path"], ROOT, artifacts, "binary-path", 30, report).strip())
        executable = binary_dir / "LegacyAnnotationIdentityAcceptance"
        report["executable_sha256"] = sha(executable)
        run_logged([str(executable), "self-tests", str(fixtures)], ROOT, artifacts, "component-cases", 180, report)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        verify_cases(report["cases"], expected)
        for mode in COLD_MODES:
            run_logged([str(executable), mode, str(fixtures)], ROOT, artifacts, mode, 45, report)
            report["cold_processes"].append(json.loads((fixtures / (mode + ".json")).read_text()))
        report["independent_sqlite_readback"] = verify_cold(report["cold_processes"], fixtures)
        report["compiled_after"] = copies(ROOT, target)
        if report["compiled_before"] != report["compiled_after"]:
            raise ValueError("Compiled inputs changed")
        report["status"] = "PASS_APPLE_FOUNDATION_LEGACY_IDENTITY24_COLD"
    except Exception as error:
        report["error"] = repr(error)
        report["status"] = "FAILED" if report["commands"] else "NOT_RUN"
        print(repr(error))
    finally:
        if "owned_directory" in report:
            case_path = Path(report["owned_directory"]) / "fixtures/CASES.json"
            if case_path.is_file():
                report["cases"] = json.loads(case_path.read_text())
        if before is not None:
            report["source_after"] = {name: sha(ROOT / name) for name in paths}
            report["source_unchanged"] = before == report["source_after"]
            try:
                observed = source_identity(ROOT, paths)
                report["source_identity_after"] = observed
                if observed != identity or not report["source_unchanged"]:
                    raise ValueError("Source identity changed during execution")
            except Exception as error:
                report["status"] = "FAILED"
                report["source_identity_error"] = repr(error)
        report["passed_cases"] = sum(row.get("status") == "PASS" for row in report["cases"])
        report["failed_cases"] = sum(row.get("status") != "PASS" for row in report["cases"])
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write_json(artifacts / "RESULT.json", report)
        print(json.dumps({key: report[key] for key in ("status", "passed_cases", "failed_cases")}))
    return 0 if report["status"] == "PASS_APPLE_FOUNDATION_LEGACY_IDENTITY24_COLD" else 1


if __name__ == "__main__":
    raise SystemExit(main())
