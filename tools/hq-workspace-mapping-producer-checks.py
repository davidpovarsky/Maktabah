"""Focused actual Store/Observation/persistence tests, never live user data."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile
import sys
import argparse

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--startup-ref", help="Immutable alternate startup method source for discriminating regression checks only")
parser.add_argument("--artifacts-dir", type=Path)
args = parser.parse_args()
OUT = args.artifacts_dir or ROOT / "docs/hq-native-mapping-reconciliation/results"
OUT.mkdir(parents=True, exist_ok=True)
SOURCES = [
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift",
    "tools/test_workspace_mapping_producer.swift",
    "tools/test_workspace_mapping_startup_reconciliation.swift",
]
with tempfile.TemporaryDirectory(prefix="workspace-producer-compile-") as temp:
    observer = Path(temp) / "NativeBindingSourceObservation.swift"
    # A canonical test snapshot makes the source/test patch runnable on base043
    # without requiring a second branch/package or an unreferenced Git object.
    observer_snapshot = "Tests/HQ/workspace-producer/NativeBindingSourceObservation_bdd1169a.swift"
    observer_bytes = (ROOT / observer_snapshot).read_bytes().replace(b"\r\n", b"\n")
    assert hashlib.sha256(observer_bytes).hexdigest() == "fe9cc784e80a1bf39e570855245aafb13511d77de7399465c776f8b6f2442d55"
    observer.write_bytes(observer_bytes)
    adapter_source = (ROOT / "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift").read_text(encoding="utf-8")
    producer_block = adapter_source.split("// MARK: Native mapping producer", 1)[1].split("// MARK: Workspace presentation", 1)[0]
    startup_source = (subprocess.check_output(["git", "show", args.startup_ref + ":Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift"], cwd=ROOT).decode("utf-8")
                      if args.startup_ref else adapter_source)
    def method(marker):
        start = startup_source.index(marker)
        end = startup_source.index("{", start) + 1
        depth = 1
        while depth:
            depth += (startup_source[end] == "{") - (startup_source[end] == "}")
            end += 1
        return startup_source[start:end]
    startup_methods = "\n".join(method(m) for m in ["func attach(_ manager:", "func switchGroup(to id:"])
    boundary = Path(temp) / "NativeProducerBoundary.swift"
    boundary.write_text((ROOT / "tools/workspace_mapping_native_boundary_fixture.swift").read_text(encoding="utf-8")
                        .replace("// ACTUAL_PRODUCER_BLOCK", producer_block)
                        .replace("// ACTUAL_STARTUP_METHODS", startup_methods), encoding="utf-8")
    exe = Path(temp) / ("producer-tests.exe" if os.name == "nt" else "producer-tests")
    summary = {"scope": "Actual Store, real Observation, real isolated persistence; canonical N observer at bdd1169a; no native setter coverage inferred",
               "status": "RUNNING",
               "swift_version": subprocess.check_output(["swiftc", "--version"], text=True).strip(),
               "observer_sha256": hashlib.sha256(observer_bytes).hexdigest(),
               "canonical_observer_snapshot": observer_snapshot,
               "actual_adapter_block_sha256": hashlib.sha256(producer_block.encode()).hexdigest(), "source_sha256": {
                   path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCES}}
    summary["actual_startup_methods_sha256"] = hashlib.sha256(startup_methods.encode()).hexdigest()
    summary["startup_methods_ref"] = args.startup_ref or "CURRENT_RECONCILED_WORKTREE"
    summary["extra_source_sha256"] = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in [
        "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift",
        "tools/workspace_mapping_native_boundary_fixture.swift", "tools/hq-workspace-mapping-producer-checks.py"]}
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    for name, command in [
        ("compile", ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
                     *[str(ROOT / path) for path in SOURCES], str(observer), str(boundary), "-o", str(exe)]),
        ("tests", [str(exe)]),
    ]:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=180)
        (OUT / f"{name}.log").write_text((result.stdout + result.stderr).rstrip() + "\n", encoding="utf-8")
        summary[f"{name}_exit"] = result.returncode
        if name == "compile": summary["compiler_warning_count"] = (result.stdout + result.stderr).count("warning:")
        print(f"{name}: exit={result.returncode}", flush=True)
        if result.returncode:
            print(result.stdout + result.stderr, flush=True)
            break
        if name == "tests":
            print(result.stdout, flush=True)
    summary["status"] = "PASS_PORTABLE_ONLY" if summary.get("tests_exit", 1) == 0 else "FAILED"
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    raise SystemExit(summary.get("tests_exit", 1))
