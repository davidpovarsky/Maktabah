#!/usr/bin/env python3
"""Small real-source Swift controls. Never claims UIKit/Apple/native acceptance."""
import argparse
import datetime
import hashlib
import json
import pathlib
import shutil
import subprocess


def digest(path):
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    quoted = False
    escaped = False
    for index in range(opening, len(source)):
        char = source[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    raise RuntimeError("Unbalanced production method: " + signature)


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise RuntimeError("Counterfactual source guard mismatch")
    return text.replace(before, after)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--module-cache", type=pathlib.Path, required=True)
    parser.add_argument("--baseline-binding", type=pathlib.Path, required=True)
    parser.add_argument("--baseline-bridge", type=pathlib.Path, required=True)
    parser.add_argument("--baseline-source", default="68b191f56c4fc1644d0b2a3478f05e9935770d20",
                        help="Exact pre-feature Git source; never use a moving HEAD as the negative baseline")
    args = parser.parse_args()
    root, output = args.source_root.resolve(), args.output.resolve()
    if output.exists():
        raise RuntimeError("Fresh output required; preserve prior evidence")
    if shutil.disk_usage(root).free < 250_000_000:
        raise RuntimeError("Insufficient room for bounded source controls")
    output.mkdir(parents=True)
    source = root / "Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift"
    binding = root / "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfaceBinding.swift"
    contract = root / "Source/SefariaEmbedded/UI/SefariaEmbeddedSurfaceContract.swift"
    runtime_harness = root / "tools/test_sefaria_visible_surface_runtime.swift"
    membership_harness = root / "tools/test_sefaria_visible_surface_membership.swift"
    native_harness = root / "tools/test_sefaria_visible_surface_native_lifecycle.swift"
    workspace_harness = root / "tools/test_sefaria_visible_surface_workspace_revision.swift"
    native_module = root / "Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift"
    runtime_manager = root / "Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift"
    workspace_binding = root / "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspacePresentationBinding.swift"
    bridge_text = source.read_text()
    binding_text = binding.read_text()
    baseline_bridge = args.baseline_bridge.read_text()
    baseline_binding = args.baseline_binding.read_text()
    git = ["git", "-c", "gc.auto=0", "-c", "maintenance.auto=false", "-C", str(root)]
    models = output / "SefariaRPCModels.swift"
    models.write_bytes(subprocess.check_output(git + ["show", "HEAD:Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift"]))
    backend_source = subprocess.check_output(git + ["show", "HEAD:Source/LibraryBackend/LibraryBackendModels.swift"]).decode()
    backend = output / "BackendID.swift"
    enum_text = method(backend_source, "enum BackendID")
    backend.write_text("import Foundation\n" + enum_text + "\n")
    compiler = shutil.which("swiftc")
    if compiler is None:
        raise RuntimeError("Original installed Swift compiler unavailable")
    report = {
        "scope": "real bridge and verbatim retained-source boundary controls; Apple/native NOT_RUN",
        "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "compiler": subprocess.check_output([compiler, "--version"], text=True).strip(),
        "base": subprocess.check_output(git + ["rev-parse", "HEAD"], text=True).strip(),
        "baselineSource": args.baseline_source,
        "freeBefore": shutil.disk_usage(root).free,
        "inputs": [digest(p) for p in [source, binding, contract, models, backend, runtime_harness,
                                      membership_harness, native_harness, workspace_harness, native_module,
                                      runtime_manager, workspace_binding, args.baseline_bridge, args.baseline_binding]],
        "runs": [],
    }
    (output / "INPUTS.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    def run(name, swift_text, expected_success, extra=()):
        if shutil.disk_usage(root).free < 220_000_000:
            raise RuntimeError("Capacity reserve reached; partial evidence retained")
        directory = output / name
        directory.mkdir()
        staged = directory / "ActualSourceWithControls.swift"
        staged.write_text(swift_text)
        binary = directory / "controls"
        argv = [compiler, "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
                "-module-cache-path", str(args.module_cache), str(staged), str(models), str(backend),
                *map(str, extra), "-o", str(binary)]
        result = {"name": name, "expectedSuccess": expected_success, "compileArgv": argv,
                  "source": digest(staged), "startedAt": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        with (directory / "compile.stdout.log").open("wb") as out, (directory / "compile.stderr.log").open("wb") as err:
            completed = subprocess.run(argv, stdout=out, stderr=err, timeout=60)
        result["compileExit"] = completed.returncode
        if completed.returncode == 0:
            execution = [str(binary), hashlib.sha256(source.read_bytes()).hexdigest()]
            result["runArgv"] = execution
            with (directory / "run.stdout.json").open("wb") as out, (directory / "run.stderr.log").open("wb") as err:
                completed = subprocess.run(execution, stdout=out, stderr=err, timeout=30)
            result["runExit"] = completed.returncode
            actual = json.loads((directory / "run.stdout.json").read_text())
            result["passed"], result["failed"] = actual["passed"], actual["failed"]
            result["expectedOutcomeObserved"] = (completed.returncode == 0 and actual["failed"] == 0) if expected_success \
                else (completed.returncode != 0 and actual["failed"] > 0)
        else:
            result["expectedOutcomeObserved"] = False
        result["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result["logs"] = [digest(p) for p in sorted(directory.glob("*.log")) + sorted(directory.glob("*.json"))]
        (directory / "RESULT.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        report["runs"].append(result)
        print(json.dumps({k: result.get(k) for k in ["name", "compileExit", "runExit", "passed", "failed", "expectedOutcomeObserved"]}), flush=True)
        (output / "PARTIAL.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")

    runtime = runtime_harness.read_text()
    run("runtime-corrected", bridge_text + "\n" + runtime, True, [contract])
    old_bump = method(baseline_bridge, "    func bumpSessionEpoch()")
    current_bump = method(bridge_text, "    func bumpSessionEpoch()")
    run("runtime-original-bump-boundary", replace_once(bridge_text, current_bump, old_bump) + "\n" + runtime, False, [contract])
    no_revision = replace_once(bridge_text,
        "if state.revision == .max { state.exhausted = true } else { state.revision += 1 }",
        "if state.revision == .max { state.exhausted = true }")
    run("runtime-weakened-revision", no_revision + "\n" + runtime, False, [contract])
    no_nesting = replace_once(bridge_text, "update { $0.transitioning = transitionDepth > 0 }", "update { $0.transitioning = false }")
    run("runtime-weakened-nesting", no_nesting + "\n" + runtime, False, [contract])
    sync_scope = method(bridge_text, "    @MainActor func withSurface<T>")
    no_lock_scope = replace_once(sync_scope, "        lock.lock(); defer { lock.unlock() }\n", "")
    run("runtime-weakened-synchronous-lock", replace_once(bridge_text, sync_scope, no_lock_scope) + "\n" + runtime, False, [contract])

    common_signatures = ["    func releaseSource(requestID:", "    func begin(requestID:",
                         "    private func withSource<T>(requestID:"]
    corrected_signatures = common_signatures + ["    private func retainedRequest(", "    private func validateMembership(",
                                               "    private func withSource<T>(request:"]
    template = membership_harness.read_text()
    for name, text, signatures, expected in [
        ("membership-original-peer-draft", baseline_binding, common_signatures, False),
        ("membership-corrected", binding_text, corrected_signatures, True),
    ]:
        chunks = [method(text, signature) for signature in signatures]
        combined = replace_once(template, "__SOURCE_METHODS__", "\n".join(chunks))
        run(name, bridge_text + "\n" + combined, expected)
        (output / name / "EXTRACTED_METHODS.json").write_text(json.dumps(
            [{"signature": signature, "sha256": hashlib.sha256(chunk.encode()).hexdigest(), "text": chunk}
             for signature, chunk in zip(signatures, chunks)], indent=2, sort_keys=True) + "\n")

    native_before = subprocess.check_output(git + ["show", args.baseline_source + ":Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift"]).decode()
    reset_before = subprocess.check_output(git + ["show", args.baseline_source + ":Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift"]).decode()
    native_signatures = ["    override func startObserving()", "    override func stopObserving()",
                         "    override func invalidate()", "    func setJSExecutor(", "    @objc func deliverEvent("]
    for name, module_text, reset_text, expected in [
        ("native-queued-original", native_before, reset_before, False),
        ("native-queued-corrected", native_module.read_text(), runtime_manager.read_text(), True),
    ]:
        original_chunks = [method(module_text, signature) for signature in native_signatures]
        # Linux has no Objective-C runtime; remove only this export attribute.
        # Method bodies remain exact. Real React/ObjC validation is still pending.
        chunks = [chunk.replace("@objc func deliverEvent", "func deliverEvent", 1) for chunk in original_chunks]
        reset = method(reset_text, "    func reset()")
        combined = replace_once(native_harness.read_text(), "__NATIVE_METHODS__", "\n".join(chunks))
        combined = replace_once(combined, "__RESET_METHOD__", reset)
        run(name, bridge_text + "\n" + combined, expected)
        (output / name / "EXTRACTED_METHODS.json").write_text(json.dumps({
            "objcAttributeRemovedForLinuxOnly": True,
            "nativeMethods": original_chunks, "originalReset": reset,
            "moduleSourceSHA256": hashlib.sha256(module_text.encode()).hexdigest(),
            "resetSourceSHA256": hashlib.sha256(reset_text.encode()).hexdigest(),
        }, indent=2, sort_keys=True) + "\n")

    workspace_before = subprocess.check_output(git + ["show", args.baseline_source + ":Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspacePresentationBinding.swift"]).decode()
    for name, text, expected in [
        ("workspace-revision-original", workspace_before, False),
        ("workspace-revision-corrected", workspace_binding.read_text(), True),
    ]:
        chunks = [method(text, "    func originalStateWillChange(")]
        if "    private func advanceOriginalStateRevision()" in text:
            chunks.append(method(text, "    private func advanceOriginalStateRevision()"))
        callback = method(text, "        sidebarObservation = sidebar?.observeOverviewRequestChanges")
        body = callback.split("{ [weak self] in\n", 1)[1].rsplit("}", 1)[0]
        combined = replace_once(workspace_harness.read_text(), "__WORKSPACE_METHODS__", "\n".join(chunks))
        combined = replace_once(combined, "__SIDEBAR_BODY__", body)
        run(name, bridge_text + "\n" + combined, expected)
        (output / name / "EXTRACTED_METHODS.json").write_text(json.dumps({
            "sourceSHA256": hashlib.sha256(text.encode()).hexdigest(), "methods": chunks,
            "originalSidebarCallback": callback,
        }, indent=2, sort_keys=True) + "\n")

    report["finishedAt"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    report["freeAfter"] = shutil.disk_usage(root).free
    report["allExpectedOutcomesObserved"] = all(run["expectedOutcomeObserved"] for run in report["runs"])
    (output / "RESULT.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if not report["allExpectedOutcomesObserved"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
