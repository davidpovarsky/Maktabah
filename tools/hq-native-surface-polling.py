#!/usr/bin/env python3
"""Original scene wait/observe + native geometry predicate; explicit UIKit doubles."""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SESSION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift"
WITNESS = "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSurfaceWitness.swift"
BOUNDARY = "Tests/HQ/navigation/NativeSurfacePollingBoundary.swift"
FIXTURE = "Tests/HQ/navigation/NativeSurfacePollingAcceptance.swift"
CASES = "Tests/HQ/navigation/NativeSurfacePollingCases.json"
PACKAGES = ["Source/Otzaria/Actions", "Source/Otzaria/UIRouting", "Source/ChavrusaText/UIRoutingHost"]
spec = importlib.util.spec_from_file_location("original_inspector_fixture_driver", ROOT / "tools/hq-native-inspector-binding.py")
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
sha, method = original.sha, original.method


def package_inputs():
    result = {}
    for relative in PACKAGES:
        package = ROOT / relative
        for path in [package / "Package.swift", *sorted((package / "Sources").rglob("*"))]:
            if path.is_file():
                result[path.relative_to(ROOT).as_posix()] = sha(path.read_bytes())
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    parser.add_argument("--source-ref", help="Exact immutable source for a discriminating RED run")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if args.source_ref and not re.fullmatch(r"[0-9a-f]{40}", args.source_ref):
        raise SystemExit("source-ref must be a full immutable Git SHA")
    out = args.artifacts_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit("Use a new attempt directory; earlier outcomes must be retained")
    available = shutil.disk_usage(ROOT).free
    if available < 1_073_741_824:
        raise SystemExit("Less than1GiB free; preserve inputs and wait for owned-space recovery")
    package = out / "package"
    sources = package / "Sources/NativeSurfacePollingAcceptance"
    sources.mkdir(parents=True)
    inputs = {}

    def source(path):
        data = (subprocess.check_output(["git", "show", args.source_ref + ":" + path], cwd=ROOT)
                if args.source_ref else (ROOT / path).read_bytes())
        inputs[path] = {"sha256": sha(data), "bytes": len(data), "source_ref": args.source_ref or "worktree"}
        saved = out / "source-before" / path
        saved.parent.mkdir(parents=True, exist_ok=True)
        saved.write_bytes(data)
        return data.decode("utf-8")

    session, witness = source(SESSION), source(WITNESS)
    actual = {
        "// ACTUAL_WITNESS_EVIDENCE": method(witness, "public struct Evidence:"),
        "// ACTUAL_WITNESS_CURRENT_EVIDENCE": method(witness, "fileprivate func currentEvidence()"),
        "// ACTUAL_WITNESS_DIAGNOSTIC": method(witness, "private func diagnostic("),
        "// ACTUAL_SESSION_OBSERVE_VISIBILITY": method(session, "func observeVisibility(for"),
        "// ACTUAL_SESSION_OBSERVE": method(session, "func observe(_ evidence:"),
        "// ACTUAL_SESSION_WAIT": method(session, "func waitUntilVisible("),
        "// ACTUAL_SESSION_END": method(session, "func endObservation(requestID:"),
    }
    boundary = (ROOT / BOUNDARY).read_text(encoding="utf-8")
    for marker, value in actual.items():
        assert boundary.count(marker) == 1, marker
        boundary = boundary.replace(marker, value)
    (sources / Path(BOUNDARY).name).write_text(boundary, encoding="utf-8", newline="\n")
    (sources / Path(FIXTURE).name).write_bytes((ROOT / FIXTURE).read_bytes())
    dependencies = ",\n".join(f"    .package(path: {json.dumps((ROOT / p).as_posix())})" for p in PACKAGES)
    manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "NativeSurfacePollingAcceptance", dependencies: [
DEPENDENCIES
], targets: [.executableTarget(name: "NativeSurfacePollingAcceptance", dependencies: [
    .product(name: "OtzariaActionCore", package: "Actions"),
    .product(name: "OtzariaUIRouting", package: "UIRouting"),
    .product(name: "ChavrusaUIRoutingHost", package: "UIRoutingHost")
])], swiftLanguageModes: [.v6])
'''.replace("DEPENDENCIES", dependencies)
    (package / "Package.swift").write_text(manifest, encoding="utf-8")
    before = package_inputs()
    expected = json.loads((ROOT / CASES).read_text(encoding="utf-8"))
    assert len(expected) == len(set(expected)) and expected
    report = {
        "status": "RUNNING", "source_ref": args.source_ref or "worktree",
        "head_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "expected": expected, "expected_count": len(expected), "native_passes": 0,
        "disk_free_before": available, "source_inputs": inputs,
        "actual_method_sha256": {k: sha(v.encode("utf-8")) for k, v in actual.items()},
        "fixture_sha256": {p: sha((ROOT / p).read_bytes()) for p in [BOUNDARY, FIXTURE, CASES, "tools/hq-native-surface-polling.py"]},
        "generated_inputs": {p.relative_to(package).as_posix(): sha(p.read_bytes()) for p in sorted(package.rglob("*.swift"))},
        "package_inputs_before": before,
        "boundary": "Whole original scene waitUntilVisible/observe/observeVisibility/endObservation; whole original NativeSurfaceWitness Evidence/currentEvidence/diagnostic; complete unchanged Core/UIRouting/Host packages including real NativePresentationObserver and deadline. Explicit UIKit geometry/lifecycle and Reader/note projection boundary doubles. No real native rendering, app launch, Core admission, final Directory/orchestrator receipt, physical-device or performance proof.",
    }
    record = out / "RESULT.json"
    record.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    scratch = ROOT / "build/native-surface-polling-swift"
    command = [shutil.which("swift"), "build", "--package-path", str(package), "--scratch-path", str(scratch),
               "--product", "NativeSurfacePollingAcceptance", "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
    report["command"] = command
    started = time.monotonic()
    with (out / "compile.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
        report["compiler_pid"] = process.pid
        try:
            code = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            report["compile_timeout"] = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
            else:
                process.kill()
            process.wait()
            code = 124
    report["compile_exit"] = code
    report["compile_seconds"] = round(time.monotonic() - started, 3)
    report["compiler_warning_count"] = (out / "compile.log").read_text(encoding="utf-8").count("warning:")
    passed, failed, executed = [], [], []
    if code == 0:
        query = [command[0], "build", "--package-path", str(package), "--scratch-path", str(scratch), "--show-bin-path"]
        binary_directory = Path(subprocess.check_output(query, cwd=ROOT, text=True, timeout=60).strip())
        executable = binary_directory / ("NativeSurfacePollingAcceptance.exe" if os.name == "nt" else "NativeSurfacePollingAcceptance")
        report["executable_sha256"] = sha(executable.read_bytes())
        report["test_command"] = [str(executable)]
        ran = subprocess.run([str(executable)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
        output = ran.stdout + ran.stderr
        (out / "tests.log").write_text(output, encoding="utf-8")
        report["test_exit"] = ran.returncode
        passed = re.findall(r"^PASS (\S+)$", output, re.M)
        failed = re.findall(r"^FAIL (\S+) ::", output, re.M)
        executed = re.findall(r"^(?:PASS|FAIL) (\S+)(?: ::.*)?$", output, re.M)
    after = package_inputs()
    report.update({
        "package_inputs_after": after, "package_inputs_unchanged": before == after,
        "passed": passed, "failed": failed, "executed_count": len(executed), "executed": executed,
        "missing": sorted(set(expected) - set(executed)), "unexpected": sorted(set(executed) - set(expected)),
        "disk_free_after": shutil.disk_usage(ROOT).free,
        "finishedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    })
    complete = executed == expected and len(set(executed)) == len(executed)
    report["exact_case_inventory"] = complete
    success = code == 0 and report.get("test_exit") == 0 and complete and not failed and before == after
    report["status"] = "PASS_PORTABLE_ONLY" if success else "FAIL"
    record.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ["status", "source_ref", "expected_count", "executed_count", "passed", "failed",
        "compile_exit", "compile_seconds", "compiler_warning_count", "exact_case_inventory", "package_inputs_unchanged",
        "disk_free_before", "disk_free_after", "native_passes"]}))
    raise SystemExit(0 if success else 1)


if __name__ == "__main__":
    main()
