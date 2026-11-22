#!/usr/bin/env python3
"""One fresh-read no-key native diagnostic; no Send or full-phase acceptance."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import runpy
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "7eb9d2a5c8ac7ccb184e3cc50fb36b6272475ff1"
OUT = ROOT / "build/artifacts/continuation-focused"
MANIFEST = OUT / "selection.json"
FULL = ROOT / "docs/hq-integration/runtime27/R27_CASES.json"
RELEASE = ROOT / "Scripts/CI/runtime27-release-manifest.json"
GROUPS = [
    {"label": "11-reader", "size": "11", "hid_comparison": False, "case_ids": [
        "HanlinReaderConsumerAcceptanceTests/testOriginalIPadFreshCurrentWorkReadConnectionWithoutSending",
    ]},
]
SELECTED = [case for group in GROUPS for case in group["case_ids"]]

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, timeout=90).decode().strip()

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

def exact_working_inputs(paths):
    # Same actual-byte/source audit used by reader-inspector-focused-native.py.
    records = {}
    entries = subprocess.check_output(["git", "ls-tree", "-r", "-z", "HEAD", "--", *paths], cwd=ROOT, timeout=90)
    for row in entries.split(b"\0"):
        if not row:
            continue
        meta, name = row.split(b"\t", 1)
        mode, kind, object_id = meta.decode().split()
        if kind != "blob":
            continue
        path = name.decode()
        p = ROOT / path
        actual = os.readlink(p).encode() if mode == "120000" and p.is_symlink() else p.read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(actual)).encode() + b"\0" + actual).hexdigest()
        if blob != object_id:
            raise ValueError("Dirty tracked execution input: " + path)
        records[path] = {"blob": object_id, "bytes": len(actual), "sha256": hashlib.sha256(actual).hexdigest()}
    if not records:
        raise ValueError("Empty execution source closure")
    return records

def source_context():
    if len(SOURCE) != 40 or any(c not in "0123456789abcdef" for c in SOURCE):
        raise ValueError("Final integrated application source is not frozen")
    head = git("rev-parse", "HEAD")
    if head != os.environ["EXPECTED_CHECKOUT_SHA"]:
        raise ValueError("Wrong immutable checkout")
    subprocess.run(["git", "merge-base", "--is-ancestor", SOURCE, head], cwd=ROOT, check=True, timeout=90)
    trees = {path: git("rev-parse", "HEAD:" + path) for path in
             ["Source", "Vendor", "Maktabah.xcodeproj", "Maktabah-iOSUITests"]}
    if any(tree != git("rev-parse", SOURCE + ":" + path) for path, tree in trees.items()):
        raise ValueError("Integrated application or original test tree changed")
    inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
    if inputs["application_source_sha"] != SOURCE or any(inputs["application_trees"][p] != trees[p]
                                                        for p in ["Source", "Vendor", "Maktabah.xcodeproj"]):
        raise ValueError("Build pins do not bind the integrated source")
    return {"checkout_sha": head, "application_source_sha": SOURCE, "application_trees": trees,
            "native116_catalog_sha256": hashlib.sha256(FULL.read_bytes()).hexdigest(),
            "release114_manifest_sha256": hashlib.sha256(RELEASE.read_bytes()).hexdigest(),
            "execution_inputs": exact_working_inputs(["Scripts/CI", ".github/workflows", "Maktabah-iOSUITests", "tools"])}

def prepare():
    context = source_context()
    contract = json.loads(FULL.read_text())
    rows = contract["cases"] + contract.get("supplemental_cases", [])
    existing = {row["case_id"] for row in rows}
    for identity in SELECTED:
        if identity not in existing:
            contract.setdefault("supplemental_cases", []).append({
                "case_id": identity, "device": "ipad11", "status": "NOT_RUN",
                "oracle": "Original XCTest assertions retained in " + identity,
            })
    contract.update(source_test_commit=SOURCE, app_source=SOURCE, application_source_sha=SOURCE,
                    execution_case_ids=SELECTED, execution_groups=GROUPS,
                    required_nonzero_cases=len(SELECTED), native_cases_executed=0,
                    expected_per_device={"ipad11": len(SELECTED), "ipad13": 0, "iphone": 0},
                    diagnostic_only=True, hid_comparison=False,
                    scope="One original fresh empty-conversation read diagnostic with explicit unused form values and no Send; prior Native PASS cases remain separate immutable evidence and are not replayed; full Native116/Release114 remain unaccepted")
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    driver["execution_groups"](contract)
    declaration = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
        SELECTED, ROOT / "Maktabah-iOSUITests")
    write(OUT / "declarations.json", declaration)
    if declaration["status"] != "DECLARATIONS_MATCH":
        raise ValueError("Selected original XCTest declaration missing")
    write(MANIFEST, contract)
    write(OUT / "source-before.json", context)

def execute():
    if source_context() != json.loads((OUT / "source-before.json").read_text()):
        raise ValueError("Source changed after preparation")
    os.environ["VALIDATING_BASELINE"] = "false"
    os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(MANIFEST)
    driver = runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))
    products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
    binaries = {}
    for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app",
                   products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        binaries[str(bundle.relative_to(ROOT))] = hashlib.sha256((bundle / info["CFBundleExecutable"]).read_bytes()).hexdigest()
        if bundle.name == "Maktabah.app":
            driver["capture_palette_code_images"](bundle, info["CFBundleExecutable"])
    for test_run in products.parent.glob("*.xctestrun"):
        shutil.copyfile(test_run, OUT / test_run.name)
    write(OUT / "built-binaries.json", binaries)
    controller = driver["runtime27_interruption"].InterruptController().install()
    try:
        return driver["run_logged"]([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"],
                                    "continuation-focused-matrix.log", 9000,
                                    interrupt_controller=controller)
    finally:
        controller.restore()

def collect():
    report = {"status": "FAILED", "scope": "FOCUSED_FRESH_READ_NO_SEND_ONLY", "full_native116_acceptance": False,
              "full_release114_acceptance": False, "required_case_ids": SELECTED}
    try:
        context = source_context()
        report.update(context)
        if context != json.loads((OUT / "source-before.json").read_text()):
            raise ValueError("Source or complete catalog changed during execution")
        build = json.loads((ROOT / "build/hq-stage2/result.json").read_text())
        if build.get("status") != "SIMULATOR_BUILD_FOR_REAL_UI_PASS" or build.get("checkout_sha") != context["checkout_sha"]:
            raise ValueError("No matching real app and UI runner build")
        binaries = json.loads((OUT / "built-binaries.json").read_text())
        for bundle_path, expected_digest in binaries.items():
            bundle = ROOT / bundle_path
            info = plistlib.loads((bundle / "Info.plist").read_bytes())
            if hashlib.sha256((bundle / info["CFBundleExecutable"]).read_bytes()).hexdigest() != expected_digest:
                raise ValueError("Built native binary changed during execution: " + bundle_path)
        images = json.loads((ROOT / "build/artifacts/runtime27/palette-compiled-images.json").read_text())["images"]
        for image in images:
            if hashlib.sha256((ROOT / image["path"]).read_bytes()).hexdigest() != image["sha256"]:
                raise ValueError("Built app code image changed during execution: " + image["path"])
        report.update(built_binary_sha256=binaries, compiled_image_bytes_unchanged=True)
        # Reuse the original package/pristine/privacy audit after actual UI.
        # Reviewed CocoaPods project/privacy generation remains auditable.
        hq = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
        hq["verify_actual_sources"](build)
        native = build.get("native_context", {})
        if hashlib.sha256((ROOT / "Maktabah.xcodeproj/project.pbxproj").read_bytes()).hexdigest() != native.get("generated_project_sha256"):
            raise ValueError("Generated original Pod integration project changed")
        if hashlib.sha256((ROOT / "Maktabah.xcworkspace/contents.xcworkspacedata").read_bytes()).hexdigest() != native.get("workspace_sha256"):
            raise ValueError("Original workspace changed")
        inputs = json.loads((ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json").read_text())
        hq["prepare_original_hanlin"](inputs, build, verify_only=True)
        write(OUT / "original-post-ui-input-audit.json", build)
        contract = json.loads(MANIFEST.read_text())
        runpy.run_path(str(ROOT / "Scripts/CI/runtime27.py"))["collect_cases"](report, contract)
        matrix = json.loads((ROOT / "build/artifacts/faithful-ipad-matrix.json").read_text())
        devices = matrix.get("devices", [])
        if ({d["label"] for d in devices} != {g["label"] for g in GROUPS}
                or any(d.get("status") != "EXECUTED_PASS" or d.get("ownedSimulatorCleanup") != "PASS" for d in devices)
                or report.get("executed_ui_pass") != len(SELECTED)
                or any(report.get(key, 0) for key in ["executed_ui_fail", "executed_ui_skip", "ui_not_run"])):
            raise ValueError("The single original fresh-read diagnostic must execute and pass")
        report["status"] = "SELECTED_UI_EXECUTED_PASS"
        return 0
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
        return 1
    finally:
        write(OUT / "result.json", report)

if __name__ == "__main__":
    os.chdir(ROOT)
    OUT.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/artifacts/runtime27").mkdir(parents=True, exist_ok=True)
    if sys.argv[1] == "prepare":
        prepare()
    elif sys.argv[1] == "run":
        raise SystemExit(execute())
    elif sys.argv[1] == "collect":
        raise SystemExit(collect())
    else:
        raise SystemExit("Expected prepare, run, or collect")
