#!/usr/bin/env python3
"""Compile the entire original SQLiteDatabase.swift against actual installed SQLite.

No production database is modified. Failure/lock/interrupt tests use fresh
owned fixture databases. Optional source-db checks open mode=ro&immutable=1.
The unrelated ZSTD API is a fail-on-call compiler boundary, never exercised.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import platform
import shutil
import sqlite3
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SQL = """SELECT CAST(l.id AS TEXT), CAST(l.bookId AS TEXT), CAST(l.lineIndex AS TEXT), b.title
FROM line l JOIN book b ON b.id = l.bookId WHERE l.bookId = 1 ORDER BY l.lineIndex, l.id LIMIT 5"""

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, default=ROOT / "build/artifacts/sqlite-source")
    parser.add_argument("--source-db", action="append", type=Path, default=[])
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    owned = artifacts / ("owned-fixture-" + str(uuid.uuid4()))
    owned.mkdir()
    sources = [
        ROOT / "Source/Core/Database/SQLiteDatabase.swift",
        ROOT / "Tests/HQ/sqlite/UnusedZstdBoundary.swift",
        ROOT / "Tests/HQ/sqlite/SQLiteDatabaseAcceptance.swift",
    ]
    compiler = shutil.which("swiftc")
    if compiler is None:
        raise RuntimeError("An existing Swift compiler is required; no toolchain installation is performed")
    command = [compiler, "-parse-as-library", "-swift-version", "6",
               "-Xfrontend", "-strict-concurrency=complete"]
    if os.name == "nt":
        sdk_root = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Windows Kits/10"
        sdks = sorted((sdk_root / "Include").glob("*"), key=lambda p: p.name, reverse=True)
        sdk = next((p for p in sdks if (p / "um/winsqlite/winsqlite3.h").is_file()), None)
        if sdk is None:
            raise RuntimeError("Installed Windows SDK winsqlite headers required")
        module = owned / "SQLite3"
        module.mkdir()
        header = (sdk / "um/winsqlite/winsqlite3.h").as_posix()
        (module / "module.modulemap").write_text(
            'module SQLite3 [system] { header "' + header + '" link "winsqlite3" export * }\n',
            encoding="utf-8")
        command += ["-I", str(owned), "-L", str(sdk_root / "Lib" / sdk.name / "um/x64")]
    elif sys.platform == "darwin":
        sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
        command += ["-sdk", sdk]
    else:
        raise RuntimeError("This focused harness currently supports installed Windows or Apple toolchains")
    executable = owned / ("sqlite-acceptance.exe" if os.name == "nt" else "sqlite-acceptance")
    command += [str(p) for p in sources] + ["-o", str(executable)]
    oracles = []
    for index, database in enumerate(args.source_db):
        database = database.resolve(strict=True)
        uri = database.as_uri() + "?mode=ro&immutable=1"
        with sqlite3.connect(uri, uri=True) as connection:
            expected = connection.execute(SOURCE_SQL).fetchall()
        if not expected:
            raise RuntimeError("Actual source book1 is missing; do not substitute synthetic source rows")
        oracles.append({"label": str(index), "uri": uri, "expected": expected})
    oracle_path = owned / "source-oracles.json"
    oracle_path.write_text(json.dumps(oracles, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    compiler_version = subprocess.check_output([compiler, "--version"], text=True, encoding="utf-8")
    build = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=150)
    (artifacts / "compile.log").write_text(build.stdout + build.stderr, encoding="utf-8")
    report = {
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(), "swift": compiler_version.strip(),
        "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_files": {str(p.relative_to(ROOT)).replace("\\", "/"): digest(p) for p in sources},
        "command": command, "compile_exit": build.returncode,
        "owned_fixture": str(owned), "real_source_readonly_count": len(oracles),
        "native_ui_executed": 0, "physical_device_executed": 0,
        "sqlite_is_real": True, "zstd_boundary_is_unexecuted": True,
    }
    result = build.returncode
    if build.returncode == 0:
        run = subprocess.run([str(executable), str(owned), str(oracle_path)], cwd=ROOT,
                             capture_output=True, text=True, encoding="utf-8", timeout=90)
        (artifacts / "tests.log").write_text(run.stdout + run.stderr, encoding="utf-8")
        result = run.returncode
        report["execute_exit"] = run.returncode
        if (owned / "RESULT.json").exists():
            report["actual_sqlite"] = json.loads((owned / "RESULT.json").read_text(encoding="utf-8"))
        print(run.stdout)
        if run.stderr:
            print(run.stderr[-3000:])
    else:
        print(build.stderr[-6000:])
    report["status"] = "EXECUTED_PASS_ACTUAL_SQLITE" if result == 0 else "FAILED"
    (artifacts / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:report[k] for k in ["status", "compile_exit", "owned_fixture", "source_files"]}, ensure_ascii=False))
    return result

if __name__ == "__main__":
    raise SystemExit(main())
