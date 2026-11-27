#!/usr/bin/env python3
"""Run the original linked15 gate once, then seven additive consent controls.

The unchanged original driver builds its actual ledger/SQLite/queue/Core inputs.
Its resulting executable is reused for the new mode. The three app-layer Swift
files receive only iOS27 parsing here; no native/SDK integration is inferred.
"""
from pathlib import Path
import argparse
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

MIN_FREE = 2 * 1024**3 + 256 * 1024**2
PRODUCT = [
    "Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorSession.swift",
    "Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorReceive.swift",
]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(command, label, root, evidence, timeout=400):
    start = time.monotonic()
    out = evidence / (label + ".stdout.log")
    err = evidence / (label + ".stderr.log")
    minimum = shutil.disk_usage(evidence).free
    if minimum < MIN_FREE:
        raise RuntimeError("Owned capacity reserve before " + label)
    with out.open("xb") as stdout, err.open("xb") as stderr:
        process = subprocess.Popen(command, cwd=root, stdout=stdout, stderr=stderr,
                                   start_new_session=True)
        termination = None
        while process.poll() is None:
            free = shutil.disk_usage(evidence).free
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
    return {"command": command, "exit": process.returncode,
            "seconds": time.monotonic() - start, "minimum_free_bytes": minimum,
            "termination": termination,
            "stdout": {"path": str(out), "sha256": sha(out)},
            "stderr": {"path": str(err), "sha256": sha(err)}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--artifacts-dir", required=True, type=Path)
    args = parser.parse_args()
    root, evidence = args.source_root.resolve(), args.artifacts_dir.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    report = {"schema": "otzaria.wave3.linked-consent-control/1", "phase": "candidate",
              "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "host": platform.platform(), "minimum_free_reserve": MIN_FREE,
              "driver_sha256": sha(__file__), "native_ui": 0, "anytype_runtime": 0,
              "network_transport": 0, "physical_devices": 0,
              "full_app_sdk_compile": 0, "status": "FAILED"}
    try:
        original_driver = root / "tools/hq-annotation-exchange-acceptance.py"
        original = runpy.run_path(str(original_driver))
        required = list(original["SOURCES"]) + [
            "tools/hq-annotation-exchange-acceptance.py", "tools/exact-source-archive.py",
            "Source/Features/Annotations/Database/AnnotationRepository.swift",
            "Source/Core/Configuration/ReusableFunc.swift",
            "Tests/HQ/annotation-exchange/run-linked-consent-controls.py",
        ] + PRODUCT
        required += [str(p.relative_to(root))
                     for p in sorted((root / "Source/Otzaria/Actions").rglob("*"))
                     if p.is_file() and ".build" not in p.parts and p.suffix in (".swift", ".json")]
        required = sorted(set(required))
        identity = runpy.run_path(str(root / "tools/exact-source-archive.py"))["source_identity"]
        before = identity(root, required)
        report["source_before"] = before
        report["inputs"] = {p: {"sha256": sha(root / p), "bytes": (root / p).stat().st_size}
                            for p in required}
        report["original_driver_sha256"] = sha(original_driver)
        original_evidence = evidence / "original-linked15"
        report["original_driver"] = run([
            sys.executable, str(original_driver), "--artifacts-dir", str(original_evidence),
            "--linked-sync-only"], "original-driver", root, evidence)
        original_result = original_evidence / "RESULT.json"
        if original_result.is_file():
            report["original_result"] = {"path": str(original_result), "sha256": sha(original_result)}
            result = json.loads(original_result.read_text())
            report["original15"] = {k: result.get(k) for k in
                                    ("status", "compile_exit", "execute_exit", "passed_cases", "failed_cases")}
        else:
            result = {}
        if report["original_driver"]["exit"] != 0:
            raise RuntimeError("Original linked15 driver failed; see immutable logs")
        assert result.get("status") == "PASS_LINKED_SQLITE_COMPONENT"
        assert result.get("passed_cases") == 15 and result.get("failed_cases") == 0
        assert result.get("compile_exit") == 0 and result.get("execute_exit") == 0
        executable = Path(result["test_command"][0])
        report["executable"] = {"path": str(executable), "sha256": sha(executable),
                                "bytes": executable.stat().st_size}
        fixtures = evidence / "consent-fixtures"
        report["consent_execute"] = run([str(executable), "linked-consent-only", str(fixtures)],
                                         "consent-controls", root, evidence, 60)
        report["cases"] = json.loads((fixtures / "CASES.json").read_text())
        report["passed"] = sum(row["status"] == "PASS" for row in report["cases"])
        report["failed"] = sum(row["status"] == "FAIL" for row in report["cases"])
        assert report["consent_execute"]["exit"] == 0
        assert len(report["cases"]) == 7 and report["passed"] == 7 and report["failed"] == 0
        assert sha(executable) == report["executable"]["sha256"]
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
        swiftc = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--find", "swiftc"], text=True).strip()
        report["syntax_sdk"] = sdk
        report["syntax_target"] = "arm64-apple-ios27.0-simulator"
        report["syntax_scope"] = "parse-only; imports/types/SDK integration not checked"
        report["syntax"] = []
        for index, path in enumerate(PRODUCT):
            check = run([swiftc, "-frontend", "-parse", "-target", report["syntax_target"],
                         "-sdk", sdk, str(root / path)], "syntax-" + str(index + 1), root, evidence, 30)
            check["path"] = path
            report["syntax"].append(check)
            assert check["exit"] == 0
        report["source_after"] = identity(root, required)
        assert report["source_after"] == before
        assert report["inputs"] == {p: {"sha256": sha(root / p), "bytes": (root / p).stat().st_size}
                                    for p in required}
        report["status"] = "PASS_ORIGINAL15_AND_ADDITIVE7_SQLITE_COMPONENT"
        return 0
    except Exception as error:
        report["error"] = repr(error)
        return 1
    finally:
        report["free_bytes_after"] = shutil.disk_usage(evidence).free
        report["owned_allocated_bytes"] = sum(p.stat().st_blocks * 512 for p in evidence.rglob("*")
                                              if p.is_file() and not p.is_symlink())
        (evidence / "RESULT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({k: report.get(k) for k in
                          ("status", "original15", "passed", "failed", "error",
                           "free_bytes_after", "owned_allocated_bytes")}))


if __name__ == "__main__":
    sys.exit(main())
