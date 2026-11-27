#!/usr/bin/env python3
"""Actual Store/Repository/SQLite F07 controls; explicit existing non-UI boundaries."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import platform
import runpy
import shutil
import sqlite3
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = "tools/hq-local-annotation-editor-acceptance.py"
CONTROL = "Tests/HQ/sqlite/F07AnnotationTransactionsAcceptance.swift"
EXPECTED = {
    "thirty_real_store_add_edit_delete_tag_cycles",
    "nested_savepoint_rollback_preserves_outer_commit",
    "outer_rollback_reverts_nested_note_tags_and_pending",
    "mapping_throw_resets_real_cached_statement_before_commit",
    "pending_sync_failure_rolls_back_add",
    "pending_sync_failure_rolls_back_edit",
    "pending_sync_failure_rolls_back_delete",
    "wal_reader_snapshot_survives_original_store_write",
    "annotation_save_completes_during_independent_relationship_cursor",
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args()
    out = args.artifacts_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    report = {"status": "NOT_RUN", "scope": "APPLE_FOUNDATION_F07_ORIGINAL_ANNOTATION_STORE",
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "native_ui_executed": 0, "app_relaunch_executed": 0,
              "full_production_relationship_provider_executed": False,
              "cloudkit_transport_executed": 0, "commands": []}
    def run(command, label, timeout):
        record = {"command": command, "label": label, "timeout_seconds": timeout}
        report["commands"].append(record)
        started = time.monotonic()
        with (out / (label + ".log")).open("wb") as stream:
            p = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        record.update(exit_code=p.returncode, seconds=time.monotonic() - started)
        if p.returncode: raise RuntimeError(label + " failed: " + str(p.returncode))
    try:
        if sys.platform != "darwin": raise RuntimeError("Installed Apple SDK required")
        report["platform"] = platform.platform()
        report["xcode"] = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
        report["swift"] = subprocess.check_output(["xcrun", "swift", "--version"], text=True).strip()
        report["disk_before"] = shutil.disk_usage(ROOT)._asdict()
        if report["disk_before"]["free"] < 2_512_000_000:
            raise RuntimeError("512MB measured phase budget plus2GB OS margin unavailable")
        sources = runpy.run_path(str(ROOT / ORIGINAL))["SOURCES"][:-1] + [CONTROL]
        binding = json.loads((ROOT / "SOURCE_BINDING.json").read_text())
        if binding["compiled_sources"] != sources: raise RuntimeError("Exact original closure membership differs")
        before = {p: digest(ROOT / p) for p in binding["sha256"]}
        if before != binding["sha256"]: raise RuntimeError("Source transfer bytes differ from Oracle receipt")
        report["source_binding"] = binding
        report["source_before"] = before
        target = out / "package/Sources/F07AnnotationTransactionsAcceptance"
        target.mkdir(parents=True)
        if len({Path(p).name for p in sources}) != len(sources): raise RuntimeError("Duplicate source basename")
        for name in sources: shutil.copyfile(ROOT / name, target / Path(name).name)
        manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "F07AnnotationTransactionsAcceptance", platforms: [.macOS(.v15)],
    dependencies: [.package(path: CORE)],
    targets: [.executableTarget(name: "F07AnnotationTransactionsAcceptance",
        dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
        swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
        linkerSettings: [.linkedLibrary("sqlite3")])], swiftLanguageModes: [.v6])
'''.replace("CORE", json.dumps(str(ROOT / "Source/Otzaria/Actions")))
        (out / "package/Package.swift").write_text(manifest)
        command = ["xcrun", "swift", "build", "--package-path", str(out / "package"),
                   "--scratch-path", str(out / "swift-build"), "-j", "2"]
        run(command, "compile", 480)
        binary_dir = Path(subprocess.check_output(command + ["--show-bin-path"], cwd=ROOT, text=True).strip())
        executable = binary_dir / "F07AnnotationTransactionsAcceptance"
        report["executable_sha256"] = digest(executable)
        fixtures = out / "fixtures"
        for mode in ("controls", "cold-write", "cold-reopen"):
            run([str(executable), mode, str(fixtures)], mode, 120)
        rows = json.loads((fixtures / "CASES.json").read_text())
        report["cases"] = rows
        if len(rows) != len(EXPECTED) or {r["name"] for r in rows} != EXPECTED or any(not r["passed"] for r in rows):
            raise RuntimeError("Missing, duplicated or failed controls")
        cold = [json.loads((fixtures / (mode + ".json")).read_text()) for mode in ("cold-write", "cold-reopen")]
        if cold[0]["pid"] == cold[1]["pid"] or cold[1]["prior_pid"] != cold[0]["pid"]:
            raise RuntimeError("Distinct real cold processes were not observed")
        db = fixtures / "cold-profile/Annotations.sqlite"
        conn = sqlite3.connect(db.as_uri() + "?mode=ro", uri=True)
        try:
            if conn.execute("PRAGMA quick_check").fetchall() != [("ok",)]: raise RuntimeError("Actual SQLite integrity failed")
            notes = conn.execute("SELECT contentId,note,ckRecordId,backendLocator FROM annotations ORDER BY contentId").fetchall()
            tags = conn.execute("SELECT COUNT(*) FROM annotation_tags").fetchone()[0]
            pending = conn.execute("SELECT COUNT(*) FROM sync_pending WHERE operation='upload'").fetchone()[0]
            if len(notes) != 30 or tags != 60 or pending != 30: raise RuntimeError("Independent cold SQL count mismatch")
            for (n, note, record_id, locator) in notes:
                if note != "הערה " + str(n) + " — original" or record_id != "f07-owned-" + str(n) + "-original":
                    raise RuntimeError("Independent cold note/record identity changed")
                if json.loads(locator)["backend"] != ("otzaria" if n % 2 == 0 else "sefaria"):
                    raise RuntimeError("Independent cold backend identity changed")
            report["independent_readback"] = {"notes": len(notes), "tag_relations": tags, "pending_uploads": pending,
                "quick_check": "ok", "database_sha256": digest(db)}
        finally: conn.close()
        report["cold_processes"] = cold
        report["compiled_copies_after"] = {p: digest(target / Path(p).name) for p in sources}
        if report["compiled_copies_after"] != {p: before[p] for p in sources}:
            raise RuntimeError("Compiled originals changed")
        after = {p: digest(ROOT / p) for p in before}
        report["source_after"] = after
        if after != before: raise RuntimeError("Source bytes changed during run")
        report["status"] = "PASS_F07_COMPONENT9_30_CYCLES_30_COLD_ROWS"
    except Exception as error:
        report["status"] = "FAILED"
        report["error"] = repr(error)
    finally:
        report["disk_after"] = shutil.disk_usage(ROOT)._asdict()
        report["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        write(out / "RESULT.json", report)
        print(json.dumps({k: report.get(k) for k in ("status", "error", "native_ui_executed")}), flush=True)
    return 0 if report["status"].startswith("PASS_") else 1

if __name__ == "__main__":
    raise SystemExit(main())
