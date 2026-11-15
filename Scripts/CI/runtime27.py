#!/usr/bin/env python3
"""R27 tool probe and integration into the existing native UI execution path."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request
import runpy
import plistlib
import html
import xml.etree.ElementTree as ET
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/runtime27"


def capture(command, name):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    (OUT / name).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f"Tool preflight failed: {command}; see {name}")
    return result.stdout


def run_logged(command, name, timeout):
    with (OUT / name).open("w") as output:
        process = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    if process.returncode:
        print("\n".join((OUT / name).read_text(errors="replace").splitlines()[-60:]), flush=True)
    return process.returncode


def collect_cases(report, contract):
    outcomes = []
    for size, device in [("11", "ipad11"), ("phone", "iphone")]:
        summary_path = OUT / f"verified-{size}.summary.json"
        tree_path = OUT / f"verified-{size}.tests.json"
        summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
        report.setdefault("actual_counts_by_device", {})[size] = summary
        found = {}
        def visit(node, suite=None):
            if node.get("nodeType") == "Test Suite":
                suite = node["name"].split(".")[-1]
            if node.get("nodeType") == "Test Case":
                identity = runpy.run_path(str(ROOT / 'tools/verify_xcresult_zero_skips.py'))['case_id'](node.get('nodeIdentifier') or f"{suite}/{node['name']}")
                found[identity] = node.get("result", "unknown")
            for child in node.get("children", []):
                visit(child, suite)
        if tree_path.exists():
            for node in json.loads(tree_path.read_text()).get("testNodes", []):
                visit(node)
        for case in contract["cases"]:
            if case["device"] == device:
                outcomes.append({"case_id": case["case_id"], "device": device, "expected": case["oracle"],
                                 "actual": found.get(case["case_id"], "NOT_RUN")})
    report["case_outcomes"] = outcomes
    for name, status in [("pass", "Passed"), ("fail", "Failed"), ("skip", "Skipped")]:
        report[f"executed_ui_{name}"] = sum(row["actual"] == status for row in outcomes)
    report["executed_ui_fail"] += sum(row["actual"] == "Expected Failure" for row in outcomes)
    # Skipped cases performed no required UI acceptance and remain NOT_RUN in
    # the owner-facing pass/fail/not-run partition. Retain their raw skip count.
    report["ui_not_run"] = sum(row["actual"] not in ["Passed", "Failed", "Expected Failure"] for row in outcomes)
    junit = ET.Element("testsuite", name="R27 real native subset", tests=str(len(outcomes)),
                       failures=str(report["executed_ui_fail"]), skipped=str(report["executed_ui_skip"]),
                       errors=str(sum(row["actual"] not in ["Passed", "Failed", "Expected Failure", "Skipped"] for row in outcomes)))
    for row in outcomes:
        suite, method = row["case_id"].split("/")
        case = ET.SubElement(junit, "testcase", classname=row["device"] + "." + suite, name=method)
        if row["actual"] != "Passed":
            tag = "failure" if row["actual"] in ["Failed", "Expected Failure"] else "skipped" if row["actual"] == "Skipped" else "error"
            ET.SubElement(case, tag, message=row["actual"]).text = row["expected"]
    ET.ElementTree(junit).write(OUT / "junit.xml", encoding="utf-8", xml_declaration=True)
    (OUT / "cases.html").write_text("<!doctype html><meta charset=utf-8><title>Actual R27 UI outcomes</title><table>" +
        "".join("<tr>" + "".join("<td>" + html.escape(row[key]) + "</td>" for key in ["device", "case_id", "actual", "expected"]) + "</tr>" for row in outcomes) + "</table>")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"status": "FAIL", "executed_ui_pass": 0, "executed_ui_fail": 0,
              "mode": os.environ.get("RUNTIME27_MODE"), "idb": "NOT_USED_XCUITEST_DRIVER",
              "maestro": "NOT_USED_NO_SELECTED_FLOW", "distribution": False}
    try:
        if sys.platform != "darwin":
            raise RuntimeError("R27 execution requires real macOS/Xcode")
        report["checkout_sha"] = capture(["git", "rev-parse", "HEAD"], "checkout.txt").strip()
        if report["checkout_sha"] != os.environ.get("EXPECTED_CHECKOUT_SHA"):
            raise RuntimeError("Unexpected checkout")
        report["xcode"] = capture(["xcodebuild", "-version"], "xcode.txt")
        report["swift"] = capture(["xcrun", "swiftc", "--version"], "swift.txt")
        report["python"] = sys.version
        report["sdk"] = capture(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], "sdk.txt").strip()
        if not report["sdk"].startswith("27."):
            raise RuntimeError("Installed simulator SDK is not27.x")
        for kind in ("summary", "tests", "test-details", "activities"):
            capture(["xcrun", "xcresulttool", "get", "test-results", kind, "--help"], f"xcresult-{kind}-help.txt")
            if kind in ("summary", "tests"):
                schema = capture(["xcrun", "xcresulttool", "get", "test-results", kind, "--schema"], f"xcresult-{kind}-schema.json")
                json.loads(schema)
        runtimes = json.loads(capture(["xcrun", "simctl", "list", "runtimes", "-j"], "runtimes.json"))
        capture(["xcrun", "simctl", "list", "devicetypes", "-j"], "device-types.json")
        available = [v for v in runtimes["runtimes"] if v.get("isAvailable") and v.get("version", "").split(".")[0] == "27"]
        if not available:
            raise RuntimeError("No installed available OS27 simulator runtime")
        report["available_runtime27"] = available
        report["reviewed_skills"] = []
        for repository, revision, subpath in [
            ("conorluddy/ios-simulator-skill", "86fb9ba90a438bd2ee7ab640165bd77da396d941", "ios-simulator-skill/skills/ios-simulator-skill"),
            ("foreztgump/maestro-mobile-testing-skill", "d2d9d9387ebba3724d972bee75af15da28622aeb", "skills/maestro-mobile-testing"),
        ]:
            url = f"https://raw.githubusercontent.com/{repository}/{revision}/{subpath}/SKILL.md"
            data = urllib.request.urlopen(url, timeout=60).read()
            name = repository.split("/")[-1] + "-SKILL.md"
            (OUT / name).write_bytes(data)
            report["reviewed_skills"].append({"repository": repository, "revision": revision, "path": subpath,
                                              "sha256": hashlib.sha256(data).hexdigest(), "runtime_tools_installed": []})
        if report["mode"] == "probe":
            report["status"] = "ENVIRONMENT_PROBE_PASS_UI_NOT_RUN"
            return 0
        if report["mode"] != "ui":
            raise RuntimeError("Unknown runtime mode")
        contract_path = ROOT / "docs/hq-integration/runtime27/R27_CASES.json"
        contract = json.loads(contract_path.read_text())
        report["case_manifest_sha256"] = hashlib.sha256(contract_path.read_bytes()).hexdigest()
        report["full_release_acceptance"] = False
        report["scope"] = contract["scope"]
        test_path = ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"
        if hashlib.sha256(test_path.read_bytes()).hexdigest() != "7018060d54afaf60b37a98decba9fcdea6f5fed7434352e83bf76f1cd6a3971d":
            raise RuntimeError("Reviewed test source drift")
        report["test_source_commit"] = contract["source_test_commit"]
        subprocess.run(["git", "merge-base", "--is-ancestor", contract["source_test_commit"], "HEAD"], cwd=ROOT, check=True)
        report["test_tree"] = capture(["git", "rev-parse", "HEAD:Maktabah-iOSUITests"], "test-tree.txt").strip()
        report["test_inputs_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in sorted((ROOT / "Maktabah-iOSUITests").glob("*.swift"))}
        report["helper_inputs_sha256"] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
            "Scripts/CI/hq-stage2-focused-apple.py", "Scripts/CI/hq-stage2-focused-apple.inputs.json", "Scripts/CI/runtime27.py",
            "Scripts/CI/run-faithful-ipad-matrix.py", "Scripts/CI/runtime27-fixture-oracle.py", "tools/verify_xcresult_zero_skips.py"]}
        if run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing", "--derived-data", "build/DerivedData"],
                      "build-for-testing-driver.log", 4200):
            raise RuntimeError("Real app/test build failed; UI cases NOT_RUN")
        products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
        binaries = {}
        for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app"]:
            info = plistlib.loads((bundle / "Info.plist").read_bytes())
            binary = bundle / info["CFBundleExecutable"]
            binaries[str(bundle.relative_to(ROOT))] = hashlib.sha256(binary.read_bytes()).hexdigest()
        test_bundle = products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"
        test_info = plistlib.loads((test_bundle / "Info.plist").read_bytes())
        binaries[str(test_bundle.relative_to(ROOT))] = hashlib.sha256((test_bundle / test_info["CFBundleExecutable"]).read_bytes()).hexdigest()
        for test_run in (ROOT / "build/DerivedData/Build/Products").glob("*.xctestrun"):
            shutil.copyfile(test_run, OUT / test_run.name)
        report["built_binary_sha256"] = binaries
        os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(contract_path)
        os.environ["VALIDATING_BASELINE"] = "false"
        # Native app installer, exact disposable-device lifecycle, existing tests.
        code = run_logged([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"], "native-matrix-driver.log", 5400)
        collect_cases(report, contract)
        if code or report["executed_ui_pass"] != 9 or report["executed_ui_fail"] or report["executed_ui_skip"]:
            raise RuntimeError("Required real UI subset failed, skipped or did not completely execute")
        report["status"] = "EXECUTED_PASS"
        return 0
    except Exception as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        if report["mode"] == "ui" and "case_outcomes" not in report:
            try:
                collect_cases(report, json.loads((ROOT / "docs/hq-integration/runtime27/R27_CASES.json").read_text()))
            except Exception as error:
                report["case_collection_error"] = str(error)
        (OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({key: report.get(key) for key in ("status", "checkout_sha", "sdk", "error")}, indent=2))


if __name__ == "__main__":
    raise SystemExit(main())
