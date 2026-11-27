#!/usr/bin/env python3
"""Focused original-source Reader-tab ownership controls. No Apple/native claim."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

if not __debug__:
    raise RuntimeError("source controls require ordinary Python; optimization is rejected")
ROOT = Path(__file__).resolve().parents[1]
BASE = "15d283aa0ccbbfe6966f26a2c182810cb39fdafa"
p = argparse.ArgumentParser()
p.add_argument("--output", type=Path, required=True)
p.add_argument("--module-cache", type=Path, required=True)
p.add_argument("--kind", choices=["owner", "service", "syntax"], required=True)
p.add_argument("--variant", choices=["candidate", "original-selection-hooks", "reusable-allowance"], default="candidate")
p.add_argument("--core-products", type=Path)
p.add_argument("--package-inputs", type=Path)
p.add_argument("--service-baseline", type=Path, help="Preserved exact pre-correction service input, SHA-bound below")
args = p.parse_args()
def require(value, message):
    if not value:
        raise RuntimeError(message)
require(not args.output.exists(), "fresh evidence output required")
require(args.module_cache.is_dir(), "only the coordinated existing module cache is permitted")
require(shutil.disk_usage(ROOT).free >= 512 * 1024 * 1024, "source-control reserve unavailable")
require(args.kind == "owner" or args.variant == "candidate", "counterfactual applies only to the owner boundary")
require(args.service_baseline is None or args.kind == "service", "service baseline requires service boundary")
args.output.mkdir(parents=True)
inputs = args.output / "inputs"
inputs.mkdir()
receipt = {
    "schema": "otzaria.native.reader-tab.source-controls.v1",
    "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": "RUNNING", "kind": args.kind, "variant": args.variant,
    "base": BASE, "source_inputs": [], "commands": [], "native": "NOT_RUN",
    "swift_version": subprocess.check_output(["swiftc", "--version"], text=True).strip(),
}
def digest(data): return hashlib.sha256(data).hexdigest()
def read_source(path, ref=None):
    native = ROOT / path
    if ref is None and native.is_file():
        data = native.read_bytes()
        origin = "CURRENT_ISOLATED_WORKTREE"
    else:
        origin = ref or BASE
        data = subprocess.check_output(["git", "-c", "gc.auto=0", "-c", "maintenance.auto=false",
            "show", origin + ":" + path], cwd=ROOT)
    dest = inputs / ("historical/" if ref else "source/") / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    receipt["source_inputs"].append({"path": path, "origin": origin, "bytes": len(data), "sha256": digest(data),
                                     "retained": str(dest.relative_to(args.output))})
    return data.decode("utf-8"), dest
def method(text, marker):
    start = text.index(marker)
    end = text.index("{", start) + 1
    depth = 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]
def save():
    (args.output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
def run(name, command):
    require(shutil.disk_usage(ROOT).free >= 512 * 1024 * 1024, "source-control reserve unavailable before " + name)
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    env_changes = {}
    if name == "controls" and args.kind == "service":
        # Original SwiftPM Debug resource accessor explicitly supports this
        # path. Use the actual retained original bundles, never synthetic data.
        env_changes["PACKAGE_RESOURCE_BUNDLE_PATH"] = str(args.core_products / "Products/Debug-linux-aarch64")
    r = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120,
                       env={**os.environ, **env_changes})
    (args.output / (name + ".stdout")).write_text(r.stdout)
    (args.output / (name + ".stderr")).write_text(r.stderr)
    receipt["commands"].append({"name": name, "argv": command, "started_utc": start,
        "exit": r.returncode, "environment": env_changes, "stdout_sha256": digest(r.stdout.encode()), "stderr_sha256": digest(r.stderr.encode())})
    save()
    print(name + " exit=" + str(r.returncode), flush=True)
    if r.returncode:
        print((r.stdout + r.stderr)[-6500:], flush=True)
    return r
try:
    read_source("tools/test_native_reader_tab_selection.py")
    if args.kind == "owner":
        portable = [
            "Source/LibraryBackend/LibraryBackendModels.swift",
            "Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceModels.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspacePersistence.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceMappingOwnership.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceStore.swift",
        ]
        files = [str(read_source(path)[1]) for path in portable]
        adapter, _ = read_source("Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift")
        policy, policy_file = read_source("Source/ChavrusaText/StudyWorkspace/StudyWorkspaceTabSelectionReservation.swift")
        fixture, _ = read_source("tools/workspace_mapping_native_boundary_fixture.swift")
        original_manager, _ = read_source("Source/UI/iOS/Managers/iOSNavigationManager.swift")
        producer = adapter.split("// MARK: Native mapping producer", 1)[1].split("// MARK: Workspace presentation", 1)[0]
        persist = method(adapter, "private func persistProjection(")
        original_select = method(original_manager, "func selectTab(id:")
        if args.variant == "original-selection-hooks":
            baseline, _ = read_source("Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift", BASE)
            for marker in ["static func nativeMappingSelectionWillChange(", "static func nativeMappingDidChange("]:
                producer = producer.replace(method(producer, marker), method(baseline, marker))
            receipt["counterfactual"] = "Actual pre-existing 15d selection willSet/didSet bodies, new consumer held fixed"
        elif args.variant == "reusable-allowance":
            old = "phase == .applying, changesSelection, !selectionConsumed,\n              !isPublishing, before == original"
            require(policy.count(old) == 1, "one-shot negative control source changed")
            policy = policy.replace(old, "phase == .applying, changesSelection,\n              before == original")
            policy_file = inputs / "MutantReusableAllowance.swift"
            policy_file.write_text(policy)
            receipt["counterfactual"] = "Deliberately remove consumed/pending setter allowance checks; all original assertions retained"
        fixture = fixture.split("@MainActor enum MappingNativeBoundaryChecks", 1)[0]
        fixture = fixture.replace("// ACTUAL_PRODUCER_BLOCK", producer)
        fixture = fixture.replace("// ACTUAL_STARTUP_METHODS", persist + """
    func synchronize(_ manager: iOSNavigationManager) {
        guard let liveGroupID, let liveBackend else { return }
        try? persistProjection(manager.openTabs, activeID: manager.activeTabId, groupID: liveGroupID, backend: liveBackend)
    }
""")
        fixture = fixture.replace("    var renderRevision = 0", """    var saveCalls = 0
    var closeCalls = 0
    var annotationEvent: Int?
    var searchEvent: Int?
    var currentContentId: Int?
    var beforeSave: (() -> Void)?
    init(book: MappingFixtureBook? = nil) {}
    func saveCurrentState() { saveCalls += 1; let callback = beforeSave; beforeSave = nil; callback?() }
    func closeReaderInspector() { closeCalls += 1 }
    var renderRevision = 0""")
        fixture = fixture.replace("    var persistCalls = 0", """    var selectedBook: MappingFixtureBook?
    var selectedContentId: Int?
    @ObservationIgnored var beforeSelectionPublication: (() -> Void)?
    var persistCalls = 0""")
        fixture = fixture.replace(
            "willSet { if installed { StudyWorkspaceNavigationAdapter.nativeMappingSelectionWillChange(self, to: newValue) } }",
            """willSet {
            if installed { StudyWorkspaceNavigationAdapter.nativeMappingSelectionWillChange(self, to: newValue) }
            let callback = beforeSelectionPublication; beforeSelectionPublication = nil; callback?()
        }""")
        fixture = fixture.replace("func selectTab(id: UUID) { activeTabId = id }", original_select)
        fixture += """
typealias BooksData = MappingFixtureBook
typealias ReaderViewModel = MappingFixtureReader
@MainActor final class LegacyIdentityRegistry {
    static let shared = LegacyIdentityRegistry()
    func id(for locator: TextLocator) -> Int { 0 }
}
"""
        fixture += adapter[adapter.index("@MainActor final class StudyWorkspaceNativeReaderReservation"):]
        boundary = inputs / "ActualOwnerBoundary.swift"
        boundary.write_text(fixture)
        receipt["actual_original_select_body_sha256"] = digest(original_select.encode())
        receipt["actual_producer_body_sha256"] = digest(producer.encode())
        receipt["actual_checkpoint_body_sha256"] = digest(persist.encode())
        receipt["assembled_boundary_sha256"] = digest(boundary.read_bytes())
        _, controls = read_source("tools/test_native_reader_tab_selection.swift")
        exe = args.output / "owner-controls"
        command = ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
            "-module-cache-path", str(args.module_cache), *files, str(policy_file), str(boundary), str(controls), "-o", str(exe)]
    elif args.kind == "service":
        require(args.core_products and args.package_inputs, "exact original Core products and source closure required")
        require(args.package_inputs.is_file(), "original source closure receipt missing")
        closure_bytes = args.package_inputs.read_bytes()
        closure = json.loads(closure_bytes)
        admitted = []
        for row in closure["files"]:
            path = row["path"]
            if not path.startswith(("Source/Otzaria/Actions/", "Source/Otzaria/UIRouting/")):
                continue
            data = subprocess.check_output(["git", "show", BASE + ":" + path], cwd=ROOT)
            require(len(data) == row["bytes"] and digest(data) == row["sha256"], "original module source mismatch: " + path)
            admitted.append(row)
        require(admitted, "empty original module source closure")
        (args.output / "ORIGINAL_PACKAGE_INPUTS.json").write_bytes(closure_bytes)
        receipt["original_module_sources"] = admitted
        receipt["original_package_inputs_sha256"] = digest(closure_bytes)
        for name in ["OtzariaActionCore", "OtzariaUIRouting"]:
            bundle = args.core_products / ("Products/Debug-linux-aarch64/" + name + "_" + name + ".bundle")
            require(bundle.is_dir(), "original resource bundle missing")
            for resource in sorted(bundle.rglob("*")):
                require(not resource.is_symlink(), "unexpected original resource symlink")
                if resource.is_file():
                    data = resource.read_bytes()
                    if resource.name != "Info.plist":
                        require(any(Path(x["path"]).name == resource.name and x["sha256"] == digest(data)
                                    for x in admitted), "original resource/source mismatch: " + resource.name)
                    receipt.setdefault("original_binary_inputs", []).append({
                        "path": str(resource), "bytes": len(data), "sha256": digest(data)})
        modules = []
        objects = []
        for name, sha in [
            ("OtzariaActionCore", "717d7eb259c903199d8b71197ac636bf5f29a41f2fa4a51f2db12eb3ddc4c78e"),
            ("OtzariaUIRouting", "b888a2d4dc6bd8cb5ac393df875e4c4a7e4e96a7e78660bb8fc631fe96904d15"),
        ]:
            module = args.core_products / ("Intermediates.noindex/" + name + ".build/Debug-linux-aarch64/"
                + name + "-t.build/Objects-normal/aarch64/Modules/" + name + ".swiftmodule")
            obj = args.core_products / ("Products/Debug-linux-aarch64/" + name + ".o")
            require(module.is_file() and digest(module.read_bytes()) == sha and obj.is_file(), "original module not verified: " + name)
            expected_object = {"OtzariaActionCore": "79b905e6ae9a727f7dcd922e5b41f5c51dbafa24ec1fbf8b1ec3bb4f5fa9cd00",
                               "OtzariaUIRouting": "3d75564ec045662e66c819f642aeaa299da1b4f9065b04b72836197d3d622682"}[name]
            require(digest(obj.read_bytes()) == expected_object, "original linked object changed: " + name)
            modules += ["-I", str(module.parent)]
            objects.append(str(obj))
            receipt.setdefault("original_binary_inputs", []).extend([
                {"path": str(x), "bytes": x.stat().st_size, "sha256": digest(x.read_bytes())} for x in [module, obj]])
        _, service = read_source("Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderTabIntentService.swift")
        if args.service_baseline:
            historical = args.service_baseline.read_bytes()
            require(digest(historical) == "bbd3c831f642ef916f88988b2b429ce10fe9e7a79a48f83b6c762d52e2fa80ca",
                    "exact preserved service boundary required")
            service = inputs / "OriginalServiceBeforeAckCancellation.swift"
            service.write_bytes(historical)
            receipt["counterfactual"] = "Exact preserved service-attempt-2 before receipt-retaining cancellation guard"
            receipt["service_baseline"] = {"path": str(args.service_baseline), "bytes": len(historical),
                                           "sha256": digest(historical), "retained": str(service.relative_to(args.output))}
        _, controls = read_source("tools/test_native_reader_tab_intent_service.swift")
        exe = args.output / "service-controls"
        command = ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-parse-as-library",
            "-module-cache-path", str(args.module_cache), *modules, str(service), str(controls), *objects, "-o", str(exe)]
    else:
        paths = [
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceTabSelectionReservation.swift",
            "Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift",
            "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeReaderTabBinding.swift",
            "Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift",
            "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderTabIntentService.swift",
            "Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeReaderTabIntents.swift",
        ]
        files = [str(read_source(x)[1]) for x in paths]
        exe = None
        command = ["swiftc", "-frontend", "-parse", "-target", "arm64-apple-ios27.0", *files]
    result = run("compile", command)
    if result.returncode:
        receipt["status"] = "COMPILE_FAILED"
    elif exe:
        receipt["executable"] = {"bytes": exe.stat().st_size, "sha256": digest(exe.read_bytes())}
        result = run("controls", (["stdbuf", "-oL"] if shutil.which("stdbuf") else []) + [str(exe)])
        rows = [line for line in result.stdout.splitlines() if line.startswith("{")]
        if rows:
            receipt["controls"] = json.loads(rows[-1])
        receipt["status"] = "PASS_SOURCE_ONLY" if result.returncode == 0 else "CONTROLS_FAILED"
        for row in receipt.get("original_binary_inputs", []):
            require(digest(Path(row["path"]).read_bytes()) == row["sha256"], "read-only original binary changed during controls")
    else:
        receipt["status"] = "PASS_SYNTAX_ONLY"
    receipt["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    receipt["free_bytes_after"] = shutil.disk_usage(ROOT).free
    save()
    print(json.dumps({"status": receipt["status"], "controls": receipt.get("controls"), "result": str(args.output / "RESULT.json"),
                      "sha256": digest((args.output / "RESULT.json").read_bytes())}), flush=True)
    raise SystemExit(result.returncode)
except BaseException as error:
    if not isinstance(error, SystemExit):
        receipt["status"] = "DRIVER_FAILED"
        receipt["error_type"] = type(error).__name__
        receipt["error"] = str(error)
        save()
    raise
