#!/usr/bin/env python3
"""Additive consent controls against exact original committed SQLite sources.

The baseline compiles the same eight files and SwiftPM manifest as the retained
original driver. It runs only the seven new cases; it does not rerun or report
the separately retained fifteen-case baseline gate.
"""
from pathlib import Path
import datetime
import hashlib
import json
import os
import platform
import runpy
import shutil
import signal
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
ROOT = BASE / "baseline-source"
EVIDENCE = BASE / "baseline-control-attempt-1"
MIN_FREE = 2 * 1024**3 + 256 * 1024**2


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(command, label, timeout=300):
    start = time.monotonic()
    out = EVIDENCE / (label + ".stdout.log")
    err = EVIDENCE / (label + ".stderr.log")
    minimum = shutil.disk_usage(BASE).free
    with out.open("xb") as stdout, err.open("xb") as stderr:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr, start_new_session=True)
        termination = None
        while process.poll() is None:
            free = shutil.disk_usage(BASE).free
            minimum = min(minimum, free)
            if free < MIN_FREE or time.monotonic() - start > timeout:
                termination = "OWNED_CAPACITY_RESERVE" if free < MIN_FREE else "OWNED_TIMEOUT"
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                break
            time.sleep(0.25)
    return {"command": command, "exit": process.returncode, "seconds": time.monotonic() - start,
            "minimum_free_bytes": minimum, "termination": termination,
            "stdout": {"path": str(out), "sha256": sha(out)},
            "stderr": {"path": str(err), "sha256": sha(err)}}


def main():
    EVIDENCE.mkdir(exist_ok=False)
    report = {"schema": "otzaria.wave3.linked-consent-control/1", "phase": "baseline",
              "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "host": platform.platform(), "minimum_free_reserve": MIN_FREE,
              "driver_sha256": sha(__file__), "native_ui": 0, "anytype_runtime": 0,
              "network_transport": 0, "physical_devices": 0,
              "original_15_rerun": False, "status": "FAILED"}
    try:
        assert shutil.disk_usage(BASE).free > MIN_FREE
        original = runpy.run_path(str(ROOT / "tools/hq-annotation-exchange-acceptance.py"))
        sources = original["SOURCES"]
        core = ROOT / "Source/Otzaria/Actions"
        required = sources + ["tools/hq-annotation-exchange-acceptance.py", "tools/exact-source-archive.py",
            "Source/Features/Annotations/Database/AnnotationRepository.swift", "Source/Core/Configuration/ReusableFunc.swift"]
        required += [str(p.relative_to(ROOT)) for p in sorted(core.rglob("*"))
                     if p.is_file() and p.suffix in (".swift", ".json")]
        identity = runpy.run_path(str(ROOT / "tools/exact-source-archive.py"))["source_identity"]
        before = identity(ROOT, required)
        report["source_before"] = before
        report["inputs"] = {p: {"sha256": sha(ROOT / p), "bytes": (ROOT / p).stat().st_size} for p in required}
        package = EVIDENCE / "package"
        target = package / "Sources/ExchangeAcceptance"
        target.mkdir(parents=True)
        for name in sources:
            shutil.copyfile(ROOT / name, target / Path(name).name)
        # Same original package/target, strict concurrency, SQLite and local Core.
        manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AnnotationExchangeAcceptance",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: CORE_PATH)],
    targets: [
        .executableTarget(name: "ExchangeAcceptance",
            dependencies: [.product(name: "OtzariaActionCore", package: "actions")],
            swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])],
            linkerSettings: [.linkedLibrary("sqlite3")])
    ], swiftLanguageModes: [.v6])
'''.replace("CORE_PATH", json.dumps(str(core)))
        (package / "Package.swift").write_text(manifest)
        report["package_sha256"] = sha(package / "Package.swift")
        swift = shutil.which("swift")
        assert swift is not None
        report["swift"] = subprocess.check_output([swift, "--version"], text=True)
        report["sdk"] = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
        command = [swift, "build", "--package-path", str(package), "--scratch-path", str(EVIDENCE / "swift-build"), "-j", "4"]
        report["compile"] = run(command, "compile")
        if report["compile"]["exit"]:
            return 1
        show = subprocess.check_output(command[:2] + ["--show-bin-path"] + command[2:], cwd=ROOT, text=True).strip()
        executable = Path(show) / "ExchangeAcceptance"
        report["executable"] = {"path": str(executable), "sha256": sha(executable), "bytes": executable.stat().st_size}
        fixtures = EVIDENCE / "fixtures"
        report["execute"] = run([str(executable), "linked-consent-only", str(fixtures)], "controls", 60)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        failed = {row["name"] for row in report["cases"] if row["status"] == "FAIL"}
        expected = {"retained_link_cannot_resurrect_after_other_connection_unlinks",
                    "retained_link_cannot_adopt_same_scope_relink_at_same_annotation_revision",
                    "retained_absence_cannot_enable_after_other_connection_link_then_unlink"}
        report["passed"] = sum(row["status"] == "PASS" for row in report["cases"])
        report["failed"] = len(failed)
        report["source_after"] = identity(ROOT, required)
        assert report["source_after"] == before
        assert len(report["cases"]) == 7 and report["passed"] == 4 and failed == expected
        assert report["execute"]["exit"] != 0
        report["status"] = "BASELINE_REPRODUCED_3_STALE_CONSENT_FAILURES"
        return 0
    except Exception as error:
        report["error"] = repr(error)
        return 1
    finally:
        report["free_bytes_after"] = shutil.disk_usage(BASE).free
        report["owned_allocated_bytes"] = sum(p.stat().st_blocks * 512 for p in EVIDENCE.rglob("*") if p.is_file() and not p.is_symlink())
        (EVIDENCE / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({k: report.get(k) for k in ("status", "passed", "failed", "error", "free_bytes_after", "owned_allocated_bytes")}))


if __name__ == "__main__":
    sys.exit(main())
