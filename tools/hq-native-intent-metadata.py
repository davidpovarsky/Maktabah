#!/usr/bin/env python3
"""Original app metadata/DI/query methods + Core/Registry/Host; explicit OS boundaries."""
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
COMPOSITION = "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift"
QUERIES = "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderIntents.swift"
BOUNDARY = "Tests/HQ/navigation/NativeIntentMetadataBoundary.swift"
FIXTURE = "Tests/HQ/navigation/NativeIntentMetadataAcceptance.swift"
PACKAGES = ["Source/Otzaria/Actions", "Source/Otzaria/UIRouting", "Source/ChavrusaText/UIRoutingHost"]
EXPECTED = [kind + "_" + backend for backend in ("otzaria", "sefaria", "sefariaEmbedded")
            for kind in ("background_root", "foreground_root", "root_identity_survives_background_transition", "root_identity_does_not_borrow_busy_ui_admission")] + [
    "backend_change_still_refused", "cancelled_metadata_still_refused", "two_background_windows_keep_exact_selected_identity"]


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
    parser.add_argument("--source-ref")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if args.source_ref and not re.fullmatch(r"[0-9a-f]{40}", args.source_ref):
        raise SystemExit("source-ref must be immutable")
    out = args.artifacts_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit("Use a new evidence directory; preserve every attempt")
    package = out / "package"
    source_dir = package / "Sources/IntentMetadataAcceptance"
    source_dir.mkdir(parents=True)
    inputs = {}

    def source(path):
        data = (subprocess.check_output(["git", "show", args.source_ref + ":" + path], cwd=ROOT)
                if args.source_ref else (ROOT / path).read_bytes())
        inputs[path] = {"sha256": sha(data), "bytes": len(data), "source_ref": args.source_ref or "worktree"}
        return data.decode("utf-8")

    composition = source(COMPOSITION)
    query_type = method(source(QUERIES), "public struct NativeReaderWindowEntityQuery:")
    markers = ["func destinations() async throws", "private func intentEntities() async throws",
               "func setForeground(_ value:", "private func issue(_ context:", "private func finish(_ context:",
               "private func context(sceneID:", "func currentScene(sceneID:", "func assess(_ descriptor:",
               "private func deadline()", "func installIntentDependency()"]
    pieces = {marker: method(composition, marker) for marker in markers}
    registry_start = composition.index("        func id(_ value: String)")
    registry_end = composition.index("        readerSink.deliver =", registry_start)
    registry = composition[registry_start:registry_end]
    mount = method(composition, "try session.mount {")
    query_methods = [method(query_type, marker) for marker in [
        "public func entities(for identifiers:", "public func entities(matching string:", "public func suggestedEntities()"]]
    actual = {"// ACTUAL_COMPOSITION_METHODS": "\n\n".join(pieces.values()),
              "// ACTUAL_REGISTRY_INITIALIZATION": registry,
              "// ACTUAL_COMPOSITION_MOUNT_VALIDATOR": mount,
              "// ACTUAL_READER_WINDOW_QUERY_METHODS": "\n".join(query_methods)}
    boundary = (ROOT / BOUNDARY).read_text(encoding="utf-8")
    for marker, value in actual.items():
        assert boundary.count(marker) == 1
        boundary = boundary.replace(marker, value)
    (source_dir / "NativeIntentMetadataBoundary.swift").write_text(boundary, encoding="utf-8", newline="\n")
    (source_dir / "NativeIntentMetadataAcceptance.swift").write_bytes((ROOT / FIXTURE).read_bytes())
    dependencies = ",\n".join(f".package(path: {json.dumps((ROOT / path).as_posix())})" for path in PACKAGES)
    manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "IntentMetadataAcceptance", dependencies: [
DEPENDENCIES
], targets: [.executableTarget(name: "IntentMetadataAcceptance", dependencies: [
    .product(name: "OtzariaActionCore", package: "Actions"),
    .product(name: "OtzariaUIRouting", package: "UIRouting"),
    .product(name: "ChavrusaUIRoutingHost", package: "UIRoutingHost")
])], swiftLanguageModes: [.v6])
'''.replace("DEPENDENCIES", dependencies)
    (package / "Package.swift").write_text(manifest, encoding="utf-8")
    package_inputs = {}
    for relative in PACKAGES:
        path = ROOT / relative
        for file in [path / "Package.swift", *sorted((path / "Sources").rglob("*"))]:
            if file.is_file(): package_inputs[file.relative_to(ROOT).as_posix()] = sha(file.read_bytes())
    report = {"status": "RUNNING", "source_ref": args.source_ref or "worktree",
        "head_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "observed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "expected": EXPECTED, "expected_count": len(EXPECTED), "native_passes": 0,
        "source_inputs": inputs, "package_inputs_before": package_inputs,
        "actual_method_sha256": {key: sha(value.encode()) for key, value in pieces.items()},
        "actual_generated_block_sha256": {key: sha(value.encode()) for key, value in actual.items()},
        "fixture_sha256": {path: sha((ROOT / path).read_bytes()) for path in (BOUNDARY, FIXTURE)},
        "generated_inputs": {file.relative_to(package).as_posix(): sha(file.read_bytes()) for file in sorted(package.rglob("*.swift"))},
        "boundary": "Complete original Composition metadata/discovery/foreground/authority glue and original Reader-window query method bodies; actual NativeIntentService, Directory, NavigationAuthority, Registry and Core. Explicit native scene observations, backend timing, localization, AppIntents DTO/DI boundaries. No Apple system execution, UIKit visibility, original catalog resolver, app build or native navigation receipt."}
    result_file = out / "RESULT.json"
    result_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    scratch = ROOT / "build/intent-metadata-swift"
    command = [shutil.which("swift"), "build", "--package-path", str(package), "--scratch-path", str(scratch),
               "--product", "IntentMetadataAcceptance", "-j", "1", "-Xswiftc", "-strict-concurrency=complete"]
    report["command"] = command
    started = time.monotonic()
    with (out / "compile.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
        report["compiler_pid"] = process.pid
        try:
            build_exit = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            report["compile_timeout"] = True
            if os.name == "nt": subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
            else: process.kill()
            process.wait()
            build_exit = 124
    report["compile_seconds"] = round(time.monotonic() - started, 3)
    report["compile_exit"] = build_exit
    report["compiler_warning_count"] = (out / "compile.log").read_text(encoding="utf-8").count("warning:")
    passed, failed = [], []
    if build_exit == 0:
        bin_path = subprocess.check_output([command[0], "build", "--package-path", str(package), "--scratch-path", str(scratch), "--show-bin-path"], cwd=ROOT, text=True, encoding="utf-8", timeout=60).strip()
        binary = Path(bin_path) / ("IntentMetadataAcceptance.exe" if os.name == "nt" else "IntentMetadataAcceptance")
        run = subprocess.run([str(binary)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
        log = run.stdout + run.stderr
        (out / "tests.log").write_text(log, encoding="utf-8")
        report["test_exit"] = run.returncode
        passed = re.findall(r"^PASS (\S+)$", log, re.M)
        failed = re.findall(r"^FAIL (\S+) ::", log, re.M)
    after = {path: sha((ROOT / path).read_bytes()) for path in package_inputs}
    executed = passed + failed
    report.update({"passed": passed, "failed": failed, "executed_count": len(executed),
        "package_inputs_after": after, "package_inputs_unchanged": after == package_inputs,
        "missing": sorted(set(EXPECTED) - set(executed)), "unexpected": sorted(set(executed) - set(EXPECTED))})
    complete = len(executed) == len(EXPECTED) and len(set(executed)) == len(executed) and set(executed) == set(EXPECTED)
    success = build_exit == 0 and report.get("test_exit") == 0 and complete and not failed and after == package_inputs
    report["status"] = "PASS_PORTABLE_ONLY" if success else "FAIL"
    result_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ["status", "source_ref", "expected_count", "executed_count", "passed", "failed", "missing", "unexpected", "compile_exit", "compile_seconds", "compiler_warning_count", "package_inputs_unchanged", "native_passes"]}))
    raise SystemExit(0 if success else 1)


if __name__ == "__main__":
    main()
