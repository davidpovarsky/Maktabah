#!/usr/bin/env python3
"""Exercise inert exchange code with unchanged original SQLite/queue/Core sources.

All writable DBs are owned test fixtures. No user DB, Anytype app, transport,
signing, CloudKit runtime or Native UI is opened. Abrupt process termination is
deliberate; only the separate reopen verifier can pass its durability gate.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "Source/Core/Database/SQLiteDatabase.swift",
    "Source/Core/CloudKit/SyncPendingStore.swift",
    "Source/ChavrusaText/Annotations/Exchange/TorahAnnotationEnvelope.swift",
    "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift",
    "Tests/HQ/sqlite/UnusedZstdBoundary.swift",
    "Tests/HQ/annotation-exchange/AnnotationExchangeTestSupport.swift",
    "Tests/HQ/annotation-exchange/AnnotationExchangeAcceptance.swift",
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    args = parser.parse_args()
    artifacts = args.artifacts_dir.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    if (artifacts / "RESULT.json").exists():
        raise RuntimeError("Use a fresh evidence directory; prior results are preserved")
    owned = artifacts / ("owned-" + str(uuid.uuid4()))
    package = owned / "package"
    target = package / "Sources/ExchangeAcceptance"
    target.mkdir(parents=True)
    fixtures = owned / "fixtures"
    fixtures.mkdir()
    swift = shutil.which("swift")
    if swift is None:
        raise RuntimeError("Existing Swift compiler required; no installation/download")
    core = ROOT / "Source/Otzaria/Actions"
    provenance = SOURCES + ["tools/hq-annotation-exchange-acceptance.py",
        "Source/Features/Annotations/Database/AnnotationRepository.swift",
        "Source/Core/Configuration/ReusableFunc.swift"]
    provenance += [str(p.relative_to(ROOT)).replace("\\", "/") for p in sorted(core.rglob("*"))
                   if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json")]
    before = {p: sha(ROOT / p) for p in provenance}
    for source in SOURCES:
        shutil.copyfile(ROOT / source, target / Path(source).name)
    linker = []
    sqlite_target = ""
    sqlite_dependency = ""
    if os.name == "nt":
        sdk_root = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Windows Kits/10"
        sdk = next((p for p in sorted((sdk_root / "Include").glob("*"), reverse=True)
                    if (p / "um/winsqlite/winsqlite3.h").is_file()), None)
        if sdk is None:
            raise RuntimeError("Existing Windows SDK winsqlite headers required")
        header = (sdk / "um/winsqlite/winsqlite3.h").as_posix()
        module = package / "Sources/SQLite3"
        module.mkdir()
        (module / "module.modulemap").write_text(
            'module SQLite3 [system] { header ' + json.dumps(header) + ' link "winsqlite3" export * }\n',
            encoding="utf-8")
        sqlite_target = '.systemLibrary(name: "SQLite3"),'
        sqlite_dependency = '"SQLite3", '
        sqlite_module_provider = "Generated Windows winsqlite3 system target"
        linker = ['.unsafeFlags(["-L", ' + json.dumps((sdk_root / "Lib" / sdk.name / "um/x64").as_posix()) + '])', '.linkedLibrary("bcrypt")']
    elif sys.platform == "darwin":
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
        if not (sdk / "usr/include/sqlite3.h").is_file():
            raise RuntimeError("Installed Apple SDK SQLite headers required")
        # The Apple SDK already supplies SQLite3. A second SPM system module
        # with the same name breaks Swift/Clang dependency scanning before tests.
        # Use the same SDK-owned module as the original SQLite acceptance driver.
        sqlite_module_provider = "Original Apple SDK SQLite3 module"
        linker = ['.linkedLibrary("sqlite3")']
    else:
        raise RuntimeError("Runner supports installed Windows and Apple toolchains")
    manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AnnotationExchangeAcceptance",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [
        SQLITE_TARGET
        .executableTarget(name: "ExchangeAcceptance",
            dependencies: [SQLITE_DEPENDENCY.product(name: "OtzariaActionCore", package: "actions")],
            swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
            linkerSettings: [LINKER_SETTINGS])
    ], swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps(core.as_posix())).replace("LINKER_SETTINGS", ", ".join(linker))
    manifest = manifest.replace("SQLITE_TARGET", sqlite_target).replace("SQLITE_DEPENDENCY", sqlite_dependency)
    (package / "Package.swift").write_text(manifest, encoding="utf-8")
    command = [swift, "build", "--package-path", str(package), "--scratch-path", str(owned / "swift-build"), "-j", "4"]
    report = {
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(),
        "swift": subprocess.check_output([swift, "--version"], text=True, encoding="utf-8").strip(),
        "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_files_before": before,
        "source_status_before": subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True, encoding="utf-8"),
        "build_command": command,
        "owned_directory": str(owned),
        "actual_sqlite": True,
        "sqlite_module_provider": sqlite_module_provider,
        "actual_original_sync_pending_store": True,
        "original_annotation_repository_runtime_executed": False,
        "digest_provider": "Windows CNG BCrypt SHA256" if os.name == "nt" else "Production CryptoKit SHA256",
        "native_ui_executed": 0,
        "cloudkit_runtime_executed": 0,
        "anytype_runtime_executed": 0,
        "transport_executed": 0,
        "physical_device_executed": 0,
        "live_capability_enabled": False,
        "cases": [], "process_termination_checks": [],
    }
    exit_code = 1
    try:
        start = time.monotonic()
        build = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=300)
        report["build_seconds"] = time.monotonic() - start
        report["compile_exit"] = build.returncode
        (artifacts / "compile.log").write_text(build.stdout + build.stderr, encoding="utf-8")
        if build.returncode != 0:
            print(build.stderr[-8000:] or build.stdout[-8000:])
            return build.returncode
        show = subprocess.check_output(command[:2] + ["--show-bin-path"] + command[2:], cwd=ROOT, text=True, encoding="utf-8").strip()
        executable = Path(show) / ("ExchangeAcceptance.exe" if os.name == "nt" else "ExchangeAcceptance")
        test_command = [str(executable), "self-tests", str(fixtures)]
        report["test_command"] = test_command
        run = subprocess.run(test_command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=150)
        report["execute_exit"] = run.returncode
        report["sqlite_version"] = next((line.removeprefix("ACTUAL_SQLITE ") for line in run.stdout.splitlines()
                                         if line.startswith("ACTUAL_SQLITE ")), None)
        (artifacts / "tests.log").write_text(run.stdout + run.stderr, encoding="utf-8")
        print(run.stdout)
        if run.stderr:
            print(run.stderr[-3000:])
        cases = fixtures / "CASES.json"
        if cases.exists():
            report["cases"] = json.loads(cases.read_text(encoding="utf-8"))
        if run.returncode != 0:
            return run.returncode
        for phase, crash_mode in (("after", "crash-after-commit"), ("before", "crash-before-outer-commit")):
            child_command = [str(executable), crash_mode, str(fixtures)]
            child = subprocess.run(child_command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=40)
            (artifacts / ("crash-" + phase + ".log")).write_text(child.stdout + child.stderr, encoding="utf-8")
            gate = {"phase": phase, "termination_command": child_command, "terminated_exit": child.returncode,
                    "expected_terminated_exit": 73, "status": "FAIL",
                    "actual_journal_observation": next((line for line in child.stdout.splitlines()
                                                       if line.startswith("CRASH_JOURNAL_MODE ")), None)}
            report["process_termination_checks"].append(gate)
            if child.returncode != 73:
                raise RuntimeError("Expected actual abrupt process exit 73: " + repr(gate))
            verify_command = [str(executable), "verify-crash-" + phase, str(fixtures)]
            verify = subprocess.run(verify_command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=40)
            gate.update({"verify_command": verify_command, "verify_exit": verify.returncode})
            (artifacts / ("verify-crash-" + phase + ".log")).write_text(verify.stdout + verify.stderr, encoding="utf-8")
            print(verify.stdout)
            if verify.returncode != 0:
                raise RuntimeError("Separate reopen verification failed: " + verify.stderr[-1500:])
            gate["status"] = "PASS"
        # Independent Python hashlib/byte comparisons do not reuse Swift codec.
        payload = fixtures / "rich-payload.json"
        expected = (fixtures / "rich-payload.sha256").read_text(encoding="utf-8")
        if sha(payload) != expected:
            raise RuntimeError("Independent Python SHA256 differs")
        before_cloud = (fixtures / "cloud-before-ledger.json").read_bytes()
        after_cloud = (fixtures / "cloud-after-ledger.json").read_bytes()
        if before_cloud != after_cloud:
            raise RuntimeError("Original CloudKit queue row bytes differ")
        report["independent_python_SHA256"] = expected
        report["cloudkit_queue_bytes_unchanged"] = True
        report["cloudkit_queue_rows_SHA256"] = hashlib.sha256(before_cloud).hexdigest()
        report["cloudkit_queue_rows_count"] = len(json.loads(before_cloud))
        if before != {p: sha(ROOT / p) for p in provenance}:
            raise RuntimeError("Source bytes changed while execution was in progress")
        exit_code = 0
        return 0
    except Exception as error:
        report["runner_error"] = repr(error)
        print(repr(error))
        return 1
    finally:
        report["source_files_after"] = {p: sha(ROOT / p) for p in provenance}
        report["source_bytes_unchanged_during_run"] = before == report["source_files_after"]
        report["status"] = "PASS_ACTUAL_SQLITE_COMPONENT" if exit_code == 0 and report["source_bytes_unchanged_during_run"] else "FAILED"
        report["passed_cases"] = sum(x["status"] == "PASS" for x in report["cases"])
        report["failed_cases"] = sum(x["status"] == "FAIL" for x in report["cases"])
        (artifacts / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: report[k] for k in ("status", "source_sha", "passed_cases", "failed_cases", "owned_directory")}, ensure_ascii=False))


if __name__ == "__main__":
    raise SystemExit(main())
