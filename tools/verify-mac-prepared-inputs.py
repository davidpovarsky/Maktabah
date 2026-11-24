#!/usr/bin/env python3
"""Control fixtures for prepared-input reuse; never native/build acceptance."""
import copy
import json
from pathlib import Path
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
mod = runpy.run_path(str(ROOT / "Scripts/CI/mac-prepared-inputs.py"))
glob = mod["capture"].__globals__
glob["INPUT_ROOTS"] = ["Pods", "build/SourcePackages/checkouts", "build/jsbundle",
                       "Maktabah.xcodeproj/project.pbxproj", "Podfile.lock"]
original_toolchain, original_images = glob["toolchain"], glob["code_images"]
results = []

def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args],
                                   text=True, stderr=subprocess.PIPE).strip()

def commit(root, text):
    git(root, "add", ".")
    git(root, "-c", "user.name=PreparedInputControl", "-c",
        "user.email=control@example.invalid", "commit", "-m", text)
    return git(root, "rev-parse", "HEAD")

cases = ["unchanged_preparation", "manifest_tamper", "prior_receipt_tamper",
         "dependency_pin_delta", "artifact_pin_delta", "prepared_source_tamper",
         "new_prepared_source", "escaping_symlink", "macro_toolchain_drift",
         "old_binary_replacement", "canonical_project_delta"]
for case in cases:
    with tempfile.TemporaryDirectory(prefix="otzaria-preparation-control-") as temp:
        root = Path(temp) / "source"; root.mkdir()
        git(root, "init")
        for relative, content in {
            "Maktabah.xcodeproj/project.pbxproj": "// Canonical fixture project\n",
            "Vendor/Fixture.swift": "// Dependency fixture\n",
            ".gitignore": "build/\nPods/\nPodfile.lock\n",
        }.items():
            p=root/relative;p.parent.mkdir(parents=True, exist_ok=True);p.write_text(content)
        previous = commit(root, "Control original source")
        for relative, content in {
            "Pods/Original.h": "// Original prepared header\n",
            "build/SourcePackages/checkouts/Fixture/Package.swift": "// Fixture package\n",
            "build/jsbundle/main.jsbundle": "// Fixture bundle\n",
            "Podfile.lock": "fixture\n", "build/control-image": "control image bytes\n",
            "build/hq-stage2/actual-source-inputs.json": "{}\n",
        }.items():
            p=root/relative;p.parent.mkdir(parents=True, exist_ok=True);p.write_text(content)
        artifact = {"name":"control-artifact","id":1,"sha256":"a"*64}
        trees = {p:git(root,"rev-parse","HEAD:"+p) for p in ("Vendor","Maktabah.xcodeproj")}
        receipt = {
            "status":mod["BUILD_STATUS"],"scope":"SIMULATOR_BUILD_FOR_REAL_UI",
            "checkout_sha":previous,"actual_source_inputs_verified":1,
            "actual_package_checkouts":{"fixture":{"status":"CLEAN"}},
            "native_context":{"generated_project_sha256":mod["sha"](root/"Maktabah.xcodeproj/project.pbxproj")},
            "xcode":"control Xcode","sdk_version":"27.0",
            "package_pins":{"fixture":"b"*40},"hanlin_gitlink":"c"*40,"application_trees":trees,
            "resource_inputs":{"json_files":{}},"artifact_inputs":[dict(artifact,verified_sha256=artifact["sha256"])],
        }
        (root/"build/hq-stage2/result.json").write_text(json.dumps(receipt))
        tools = {"tools":{"xcodebuild":{"version":"control Xcode"}},"sdk_version":"27.0","macros":{"sha256":"d"*64}}
        glob["toolchain"] = lambda: copy.deepcopy(tools)
        glob["code_images"] = lambda r: {"control-image": mod["record"](r/"build/control-image")}
        captured = mod["capture"](root, "build/prepared/inputs.json")
        (root/"ci-control.txt").write_text("New CI-only leaf\n")
        current = commit(root, "Control reviewed continuation")
        report = {k:copy.deepcopy(receipt[k]) for k in ("package_pins","hanlin_gitlink","application_trees")}
        report["checkout_sha"] = current
        config = {"resources":{},"artifacts":[copy.deepcopy(artifact)]}
        digest = captured["sha256"]
        if case == "manifest_tamper": (root/"build/prepared/inputs.json").write_text("{}")
        if case == "prior_receipt_tamper":
            p=root/"build/prepared/inputs.prior-build.json";p.write_bytes(p.read_bytes()+b"\n")
        if case == "dependency_pin_delta": report["package_pins"]["fixture"] = "e"*40
        if case == "artifact_pin_delta": config["artifacts"][0]["id"] = 2
        if case == "prepared_source_tamper": (root/"Pods/Original.h").write_text("// Changed header\n")
        if case == "new_prepared_source": (root/"Pods/Injected.swift").write_text("// Added source\n")
        if case == "escaping_symlink":
            outside=Path(temp)/"outside";outside.write_text("outside source root\n")
            (root/"Pods/outside").symlink_to(outside)
        if case == "macro_toolchain_drift": tools["macros"]["sha256"] = "f"*64
        if case == "old_binary_replacement": (root/"build/control-image").write_text("different image\n")
        if case == "canonical_project_delta":
            (root/"Maktabah.xcodeproj/project.pbxproj").write_text("// Changed project\n")
            report["checkout_sha"]=commit(root,"Control project delta")
            report["application_trees"]["Maktabah.xcodeproj"]=git(root,"rev-parse","HEAD:Maktabah.xcodeproj")
        try:
            mod["admit"](root, "build/prepared/inputs.json", digest, config, report)
            assert case == "unchanged_preparation", "Unsafe fixture admitted: "+case
            assert report["prepared_input_reuse"]["native_build_skipped"] is False
            assert report["prepared_input_reuse"]["original_sdk_admission_required"] is True
            assert report["canonical_project_sha256"] == mod["canonical_project"](root)["sha256"]
            results.append({"case":case,"status":"PASS"})
        except RuntimeError as error:
            assert case != "unchanged_preparation", str(error)
            results.append({"case":case,"status":"PASS","expected_rejection":str(error)})

try:
    mod["assert_qualified_receipt"]({"status":"FAILED"})
    raise AssertionError("Failed build receipt admitted")
except RuntimeError as error:
    results.append({"case":"unsuccessful_build_receipt","status":"PASS","expected_rejection":str(error)})

p=subprocess.run([__import__("sys").executable, str(ROOT/"Scripts/CI/hq-stage2-focused-apple.py"),
                  "--build-for-testing","--prepared-inputs-manifest","build/absent.json",
                  "--prepared-inputs-sha256","a"*64],text=True,capture_output=True)
assert p.returncode != 0 and "Prepared inputs may only continue into original SDK admission" in p.stderr
results.append({"case":"resume_cannot_skip_original_sdk_admission","status":"PASS"})
assert len(results)==13
print(json.dumps({"status":"PASS","scope":"Synthetic structure and real-file/Git controls only; no SDK, app build or native tests",
                  "checks":len(results),"results":results},indent=2))
