#!/usr/bin/env python3
"""Actual Inspector app adapter/session projection + Core/Registry; UIKit boundary doubles."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativePublicBindingAdapter.swift"
SESSION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift"
BINDINGS = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
BOUNDARY = "Tests/HQ/navigation/NativeInspectorBindingBoundary.swift"
FIXTURE = "Tests/HQ/navigation/NativeInspectorBindingAcceptance.swift"
COPIED = [ADAPTER,
    "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceOwner.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift",
    "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift",
    "Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift",
    "Source/LibraryBackend/LibraryBackendModels.swift",
    "Source/Otzaria/Actions/Integration/ActionAppIdentityBridge.swift",
    "Source/Otzaria/Reading/OtzariaLineAnchor.swift"]
PACKAGES = ["Source/Otzaria/Actions", "Source/Otzaria/UIRouting", "Source/ChavrusaText/UIRoutingHost"]
EXPECTED = [f"exact_{backend}_{layout}_completion" for backend in ("otzaria", "sefaria", "sefariaEmbedded")
            for layout in ("inline", "modal")] + [
    "closed_reader_projects_observed_false", "already_visible_original_inspector_completes",
    "missing_both_native_witnesses_fails_before_effect", "presentation_blocker_fails_before_effect",
    "missing_navigation_scope_cannot_bind", "model_visibility_without_inspector_witness_cannot_ack",
    "foreign_scene_inspector_witness_cannot_ack", "old_request_inspector_witness_cannot_ack",
    "private_selection_change_after_effect_stays_stale", "reader_replacement_after_effect_stays_stale",
    "backend_generation_change_after_effect_cannot_ack", "mapping_epoch_aba_revokes_original_admission",
    "workspace_owner_replacement_cannot_borrow_old_grant", "foreground_revocation_after_effect_cannot_ack",
    "expired_original_deadline_cannot_ack", "cancelled_original_task_cannot_ack",
    "one_use_core_authorization_stays_one_use", "history_binding_keeps_absent_inspector_and_private_tab"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def method(source, marker):
    assert source.count(marker) == 1, marker
    start = source.index(marker)
    end = source.index("{", start) + 1
    depth = 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    parser.add_argument("--source-ref", help="Exact immutable original source for a discriminating RED run")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if args.source_ref and not re.fullmatch(r"[0-9a-f]{40}", args.source_ref):
        raise SystemExit("source-ref must be an immutable Git SHA")
    out = args.artifacts_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit("Preserve earlier attempts; use a new artifacts directory")
    package = out / "package"
    source_dir = package / "Sources/InspectorBindingAcceptance"
    source_dir.mkdir(parents=True)
    inputs = {}

    def source(path):
        data = (subprocess.check_output(["git", "show", args.source_ref + ":" + path], cwd=ROOT)
                if args.source_ref else (ROOT / path).read_bytes())
        inputs[path] = {"sha256": sha(data), "bytes": len(data), "source_ref": args.source_ref or "worktree"}
        return data

    for path in COPIED:
        (source_dir / Path(path).name).write_bytes(source(path))
    session = source(SESSION).decode("utf-8")
    binding_source = source(BINDINGS).decode("utf-8")
    start, end = "// BEGIN NATIVE INSPECTOR OWNER BINDING", "// END NATIVE INSPECTOR OWNER BINDING"
    assert binding_source.count(start) == binding_source.count(end) == 1
    owner = binding_source[binding_source.index(start):binding_source.index(end) + len(end)]
    actual_methods = {
        "// ACTUAL_SESSION_MOUNT": method(session, "func mount(validateLifetime:"),
        "// ACTUAL_SESSION_PUBLIC_PRESENTATION": method(session, "func publicBindingPresentation()"),
        "// ACTUAL_INSPECTOR_OWNER": owner,
    }
    boundary = (ROOT / BOUNDARY).read_text(encoding="utf-8")
    for marker, value in actual_methods.items():
        assert boundary.count(marker) == 1
        boundary = boundary.replace(marker, value)
    (source_dir / "NativeInspectorBindingBoundary.swift").write_bytes(boundary.encode("utf-8"))
    (source_dir / "NativeInspectorBindingAcceptance.swift").write_bytes((ROOT / FIXTURE).read_bytes())
    dependencies = ",\n".join(f"        .package(path: {json.dumps((ROOT / p).as_posix())})" for p in PACKAGES)
    manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "InspectorBindingAcceptance", dependencies: [
DEPENDENCIES
], targets: [.executableTarget(name: "InspectorBindingAcceptance", dependencies: [
    .product(name: "OtzariaActionCore", package: "Actions"),
    .product(name: "OtzariaUIRouting", package: "UIRouting"),
    .product(name: "ChavrusaUIRoutingHost", package: "UIRoutingHost")
])], swiftLanguageModes: [.v6])
'''.replace("DEPENDENCIES", dependencies)
    (package / "Package.swift").write_text(manifest, encoding="utf-8")
    package_inputs = {}
    for relative in PACKAGES:
        p = ROOT / relative
        for f in [p / "Package.swift", *sorted((p / "Sources").rglob("*"))]:
            if f.is_file(): package_inputs[f.relative_to(ROOT).as_posix()] = sha(f.read_bytes())
    report = {"status": "RUNNING", "source_ref": args.source_ref or "worktree",
        "head_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "expected": EXPECTED, "expected_count": len(EXPECTED), "native_passes": 0,
        "source_inputs": inputs, "package_inputs_before": package_inputs,
        "actual_method_sha256": {k: sha(v.encode("utf-8")) for k, v in actual_methods.items()},
        "fixture_sha256": {p: sha((ROOT / p).read_bytes()) for p in (BOUNDARY, FIXTURE)},
        "generated_inputs": {f.relative_to(package).as_posix(): sha(f.read_bytes()) for f in sorted(package.rglob("*.swift"))},
        "boundary": "Actual complete app binding adapter, original Inspector owner, original session public-presentation/mount methods, original workspace ownership source and Core/Registry/Host modules. Explicit Reader/UIKit/manager/workspace-projection doubles; no native UI, real rendering, app build, external provider or data acceptance."}
    (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    scratch = ROOT / "build/inspector-binding-swift"
    command = [shutil.which("swift"), "build", "--package-path", str(package), "--scratch-path", str(scratch),
               "--product", "InspectorBindingAcceptance", "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
    report["command"] = command
    started = time.monotonic()
    with (out / "compile.log").open("w", encoding="utf-8") as log:
        proc = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
        report["compiler_pid"] = proc.pid
        try:
            build_exit = proc.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            report["compile_timeout"] = True
            if os.name == "nt": subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
            else: proc.kill()
            proc.wait()
            build_exit = 124
    report["compile_seconds"] = round(time.monotonic() - started, 3)
    report["compile_exit"] = build_exit
    report["compiler_warning_count"] = (out / "compile.log").read_text(encoding="utf-8").count("warning:")
    executed, passed, failed = [], [], []
    if build_exit == 0:
        query = [command[0], "build", "--package-path", str(package), "--scratch-path", str(scratch), "--show-bin-path"]
        bin_path = subprocess.check_output(query, cwd=ROOT, text=True, encoding="utf-8", timeout=60).strip()
        executable = Path(bin_path) / ("InspectorBindingAcceptance.exe" if os.name == "nt" else "InspectorBindingAcceptance")
        run = subprocess.run([str(executable)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
        log = run.stdout + run.stderr
        (out / "tests.log").write_text(log, encoding="utf-8")
        report["test_exit"] = run.returncode
        passed = re.findall(r"^PASS (\S+)$", log, re.M)
        failed = re.findall(r"^FAIL (\S+) ::", log, re.M)
        executed = passed + failed
    after = {p: sha((ROOT / p).read_bytes()) for p in package_inputs}
    report["package_inputs_after"] = after
    report["package_inputs_unchanged"] = after == package_inputs
    report.update({"passed": passed, "failed": failed, "executed_count": len(executed),
        "missing": sorted(set(EXPECTED) - set(executed)), "unexpected": sorted(set(executed) - set(EXPECTED))})
    complete = len(executed) == len(EXPECTED) and len(set(executed)) == len(executed) and set(executed) == set(EXPECTED)
    success = build_exit == 0 and report.get("test_exit") == 0 and complete and not failed and after == package_inputs
    report["status"] = "PASS_PORTABLE_ONLY" if success else "FAIL"
    (out / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ["status", "source_ref", "expected_count", "executed_count", "passed", "failed", "missing", "unexpected", "compile_exit", "compile_seconds", "compiler_warning_count", "package_inputs_unchanged", "native_passes"]}))
    raise SystemExit(0 if success else 1)


if __name__ == "__main__":
    main()
