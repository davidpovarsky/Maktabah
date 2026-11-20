#!/usr/bin/env python3
"""R27 tool probe and integration into the existing native UI execution path."""
import contextlib
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
import re
import signal
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/runtime27"
_SCRIPTS_CI_DIR = str(Path(__file__).resolve().parent)
if _SCRIPTS_CI_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_CI_DIR)

import runtime27_interruption

stop_owned_process_group = runtime27_interruption.stop_owned_process_group


def case_contract_path(requested):
    """Default original scope, or one of two reviewed independent diagnostics."""
    if requested is None:
        return ROOT / "docs/hq-integration/runtime27/R27_CASES.json"
    allowed = {
        "docs/hq-integration/runtime27/keyboard-global-ipad11.json",
        "docs/hq-integration/runtime27/keyboard-global-ipad13.json",
    }
    if requested not in allowed:
        raise ValueError("Unreviewed explicit runtime27 case-manifest path")
    return ROOT / requested


def execution_groups(contract):
    """Exact nonzero affected scope; every group owns a fresh disposable sim."""
    rows = contract["cases"] + contract.get("supplemental_cases", [])
    cases = {row["case_id"]: row for row in rows}
    if len(cases) != len(rows):
        raise ValueError("Duplicated full-phase UI case declaration")
    selected = contract.get("execution_case_ids", list(cases))
    if (not selected or len(selected) != len(set(selected)) or not set(selected) <= cases.keys()
            or any(not re.fullmatch(r"\w+/test\w+", value) for value in selected)):
        raise ValueError("Invalid/empty/duplicated affected UI case selection")
    groups = contract.get("execution_groups")
    if groups is None:
        groups = [{"label": size, "size": size, "case_ids": [value for value in selected if cases[value]["device"] == device]}
                  for size, device in [("11", "ipad11"), ("13", "ipad13"), ("phone", "iphone")]]
        groups = [group for group in groups if group["case_ids"]]
    if not groups or len({group["label"] for group in groups}) != len(groups):
        raise ValueError("Missing/duplicated owned simulator groups")
    flattened = []
    for group in groups:
        size, label, members = group["size"], group["label"], group["case_ids"]
        allowed = {"11": "11", "13": "13", "phone": "phone", "11-reader": "11", "11-window": "11",
                   "11-search": "11", "11-sidebar": "11", "11-index": "11"}
        if allowed.get(label) != size or not members:
            raise ValueError("Invalid owned simulator size/artifact label/scope")
        device = {"11": "ipad11", "13": "ipad13", "phone": "iphone"}[size]
        if any(value not in cases or cases[value]["device"] != device for value in members):
            raise ValueError("A required UI case was assigned to the wrong device")
        flattened.extend(members)
    if len(flattened) != len(selected) or set(flattened) != set(selected):
        raise ValueError("Owned simulator groups do not exactly partition the selected scope")
    return groups


def capture(command, name):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=120)
    (OUT / name).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f"Tool preflight failed: {command}; see {name}")
    return result.stdout


def run_logged(command, name, timeout, interrupt_controller=None):
    if interrupt_controller is not None and interrupt_controller.interrupted:
        raise KeyboardInterrupt(
            f"External signal {interrupt_controller.signal_name or interrupt_controller.signal_number or ''}; skipping {name}".strip()
        )
    with (OUT / name).open("w") as output:
        owned_group = sys.platform == "darwin"
        process = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=owned_group)
        try:
            process.wait(timeout=timeout)
        except BaseException as error:
            # GitHub cancellation previously killed this supervisor while its
            # native child continued through artifact upload. Stop only the
            # process group created here; never another runner's work.
            if isinstance(error, KeyboardInterrupt) and interrupt_controller is not None:
                interrupt_controller.mark_interrupted(error)
            guard = (
                interrupt_controller.cleanup_scope()
                if interrupt_controller is not None
                else contextlib.nullcontext()
            )
            with guard:
                marker = {
                    "status": "INTERRUPTED_CHILD_UNVERIFIED", "exception": type(error).__name__,
                    "owned_process_group": process.pid if owned_group else None,
                    "acceptance_effect": "NONE; interrupted UI results require complete independent validation"}
                marker_path = OUT / (name + ".interrupted.json")
                try:
                    marker_path.write_text(json.dumps(marker, indent=2) + "\n")
                except OSError:
                    pass
                if owned_group:
                    try:
                        marker["cleanup"] = stop_owned_process_group(process)
                    except OSError as cleanup_error:
                        marker["cleanup"] = {"error": type(cleanup_error).__name__, "state": "UNVERIFIED"}
                elif process.poll() is None:
                    marker["cleanup"] = runtime27_interruption.stop_owned_subprocess(
                        process, grace_seconds=5, kill_wait_seconds=2
                    )
                if interrupt_controller is not None:
                    interrupt_controller.apply_metadata(marker)
                try:
                    marker_path.write_text(json.dumps(marker, indent=2) + "\n")
                except OSError:
                    pass
            raise
    if process.returncode:
        print("\n".join((OUT / name).read_text(errors="replace").splitlines()[-60:]), flush=True)
    return process.returncode


def capture_palette_code_images(bundle, executable):
    """Retain actual compiled-image provenance, including Xcode's debug dylib."""
    evidence = {"acceptance_effect": "NONE; symbols do not establish UI behavior", "images": []}
    for path in [bundle / executable, *sorted(bundle.glob("*.dylib"))]:
        row = {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size}
        with path.open("rb") as stream:
            row["sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        try:
            result = subprocess.run(["xcrun", "nm", "-a", str(path)], capture_output=True, timeout=45)
            matches = [line for line in result.stdout.decode("utf-8", errors="replace").splitlines()
                       if "PaletteTextField" in line or "PaletteSearchTextField" in line]
            row.update(nm_exit_code=result.returncode, matched_symbol_count=len(matches),
                       bounded_matched_symbols=matches[:200], nm_stdout_sha256=hashlib.sha256(result.stdout).hexdigest())
        except (OSError, subprocess.TimeoutExpired) as error:
            row["symbol_capture_error"] = type(error).__name__
        evidence["images"].append(row)
    (OUT / "palette-compiled-images.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return evidence


def collect_cases(report, contract):
    outcomes = []
    case_id_fn = runpy.run_path(str(ROOT / 'tools/verify_xcresult_zero_skips.py'))['case_id']
    for group in execution_groups(contract):
        label = group["label"]
        device = {"11": "ipad11", "13": "ipad13", "phone": "iphone"}[group["size"]]
        summary_path = OUT / f"verified-{label}.summary.json"
        tree_path = OUT / f"verified-{label}.tests.json"
        summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
        report.setdefault("actual_counts_by_device", {})[label] = summary
        found = {}
        def visit(node, suite=None):
            if node.get("nodeType") == "Test Suite":
                suite = node["name"].split(".")[-1]
            if node.get("nodeType") == "Test Case":
                identity = case_id_fn(node.get('nodeIdentifier') or f"{suite}/{node['name']}")
                found[identity] = node.get("result", "unknown")
            for child in node.get("children", []):
                visit(child, suite)
        if tree_path.exists():
            for node in json.loads(tree_path.read_text()).get("testNodes", []):
                visit(node)
        for case in contract["cases"] + contract.get("supplemental_cases", []):
            if case["case_id"] in group["case_ids"]:
                outcomes.append({"case_id": case["case_id"], "device": device, "expected": case["oracle"],
                                 "configuration_label": label,
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
    controller = runtime27_interruption.InterruptController()
    contract_path = case_contract_path(None)
    try:
        contract_path = case_contract_path(os.environ.get("RUNTIME27_CASE_MANIFEST"))
        if sys.platform != "darwin":
            raise RuntimeError("R27 execution requires real macOS/Xcode")
        controller.install()
        report["checkout_sha"] = capture(["git", "rev-parse", "HEAD"], "checkout.txt").strip()
        if report["checkout_sha"] != os.environ.get("EXPECTED_CHECKOUT_SHA"):
            raise RuntimeError("Unexpected checkout")
        report["xcode"] = capture(["xcodebuild", "-version"], "xcode.txt")
        report["swift"] = capture(["xcrun", "swiftc", "--version"], "swift.txt")
        report["python"] = sys.version
        # Inspect the real execution Mac, independently of installed Windows skills.
        # These CLIs are optional because XCUITest is this case's native driver.
        report["optional_native_clis"] = {}
        for name in ("idb", "idb_companion", "maestro"):
            path = shutil.which(name)
            tool = {"path": path, "status": "NOT_INSTALLED" if not path else "PRESENT"}
            if path:
                try:
                    version = subprocess.run([path, "--version"], text=True, capture_output=True, timeout=15)
                    tool.update(version_exit_code=version.returncode,
                                version_output=(version.stdout + version.stderr)[:2000])
                except (OSError, subprocess.TimeoutExpired) as error:
                    tool.update(version_error=type(error).__name__)
            report["optional_native_clis"][name] = tool
        report["sdk"] = capture(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], "sdk.txt").strip()
        if not report["sdk"].startswith("27."):
            raise RuntimeError("Installed simulator SDK is not27.x")
        capture(["xcrun", "simctl", "help", "io"], "simctl-io-help.txt")
        capture(["xcrun", "simctl", "help", "ui"], "simctl-ui-help.txt")
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
        if report["mode"] not in {"ui", "release"}:
            raise RuntimeError("Unknown runtime mode")
        if report["mode"] == "release":
            # Validate the full unchanged release contract before the expensive
            # app build. The producer validates it again against final inputs.
            release_manifest = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-release.py"))["load_manifest"](ROOT)
            report["release_manifest_preflight"] = {
                "status": "DECLARATIONS_AND_PREPARED_SOURCE_MATCH",
                "manifest_sha256": hashlib.sha256((ROOT / "Scripts/CI/runtime27-release-manifest.json").read_bytes()).hexdigest(),
                "required_ui_executions": sum(len(row["required_ui_cases"]) for row in release_manifest["configurations"]),
                "required_oracle_executions": sum(len(row.get("required_oracle_cases", [])) for row in release_manifest["configurations"]),
                "native_executed": 0,
            }
        # Fail cheap on the exact owned native component before restoring/building
        # the full app. This is real SDK module compilation, never runtime acceptance.
        sdk_path = capture(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], "sdk-path.txt").strip()
        palette_sources = sorted((ROOT / "Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette").rglob("*.swift"))
        palette_command = ["xcrun", "swiftc", "-emit-module", "-parse-as-library", "-swift-version", "6", "-module-name", "CommandPalette",
                           "-sdk", sdk_path, "-target", "arm64-apple-ios27.0-simulator",
                           "-emit-module-path", str(OUT / "CommandPalette.swiftmodule"), *map(str, palette_sources)]
        report["palette_sdk_compile"] = {"command": palette_command, "native_ui_passes": 0}
        palette_code = run_logged(palette_command, "palette-sdk-compile.log", 180, interrupt_controller=controller)
        report["palette_sdk_compile"]["exit_code"] = palette_code
        if palette_code:
            raise RuntimeError("Owned palette component did not compile with actual Apple SDK")
        # Compile the exact downstream UIKit adapter early, without app mocks
        # or a second UI harness. Full real app/test compilation still follows.
        sidebar_path = ROOT / "Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift"
        sidebar = sidebar_path.read_text()
        policy = sidebar.split("#if canImport(SwiftUI)", 1)[0]
        adapter = sidebar[sidebar.index("private struct ReaderSidebarSplitConfiguration:"):sidebar.rindex("#endif")]
        sidebar_sdk_source = OUT / "ReaderSidebarSplit.swift"
        sidebar_sdk_source.write_text(policy + "\nimport SwiftUI\nimport UIKit\n" + adapter)
        sidebar_command = ["xcrun", "swiftc", "-emit-module", "-parse-as-library", "-swift-version", "6",
                           "-module-name", "ReaderSidebarSplit", "-sdk", sdk_path,
                           "-target", "arm64-apple-ios27.0-simulator",
                           "-emit-module-path", str(OUT / "ReaderSidebarSplit.swiftmodule"), str(sidebar_sdk_source)]
        report["sidebar_sdk_compile"] = dict(command=sidebar_command, native_ui_passes=0,
            original_source_sha256=hashlib.sha256(sidebar_path.read_bytes()).hexdigest())
        sidebar_code = run_logged(sidebar_command, "sidebar-sdk-compile.log", 180, interrupt_controller=controller)
        report["sidebar_sdk_compile"]["exit_code"] = sidebar_code
        if sidebar_code:
            raise RuntimeError("Owned sidebar adapter did not compile with actual Apple SDK")
        contract = json.loads(contract_path.read_text())
        groups = execution_groups(contract)
        expected_count = sum(len(group["case_ids"]) for group in groups)
        report["execution_groups"] = groups
        report["full_phase_case_ids"] = [case["case_id"] for case in contract["cases"]]
        report["supplemental_case_ids"] = [case["case_id"] for case in contract.get("supplemental_cases", [])]
        report["requested_ui_case_count"] = expected_count
        selected_cases = [case for group in groups for case in group["case_ids"]]
        declaration_report = runpy.run_path(str(ROOT / "Scripts/CI/verify-faithful-xctest.py"))["validate_selections"](
            selected_cases, ROOT / "Maktabah-iOSUITests")
        (OUT / "selected-test-declarations.json").write_text(json.dumps(declaration_report, indent=2))
        report["declaration_preflight"] = {"status": declaration_report["status"], "runtime_passes": 0}
        if declaration_report["status"] != "DECLARATIONS_MATCH":
            raise RuntimeError("Required Swift XCTest declarations do not match; see selected-test-declarations.json")
        report["prior_pass_reuse"] = "Historical eight cases require exact compatibility proof; never counted as new execution"
        report["case_manifest_sha256"] = hashlib.sha256(contract_path.read_bytes()).hexdigest()
        report["full_release_acceptance"] = False
        report["scope"] = contract["scope"]
        test_path = ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"
        if hashlib.sha256(test_path.read_bytes()).hexdigest() != "b81034f6e6f83089c9a2cf6294468abfde382af156879f8a7161599539bb87ed":
            raise RuntimeError("Reviewed test source drift")
        report["test_source_commit"] = contract["source_test_commit"]
        subprocess.run(["git", "merge-base", "--is-ancestor", contract["source_test_commit"], "HEAD"], cwd=ROOT, check=True)
        report["test_tree"] = capture(["git", "rev-parse", "HEAD:Maktabah-iOSUITests"], "test-tree.txt").strip()
        report["test_inputs_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in sorted((ROOT / "Maktabah-iOSUITests").glob("*.swift"))}
        report["helper_inputs_sha256"] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
            "Scripts/CI/hq-stage2-focused-apple.py", "Scripts/CI/hq-stage2-focused-apple.inputs.json", "Scripts/CI/runtime27.py",
            "Scripts/CI/run-faithful-ipad-matrix.py", "Scripts/CI/select-runtime27-toolchain.py", "Scripts/CI/runtime27_interruption.py", "Scripts/CI/runtime27-fixture-oracle.py",
            "tools/verify_xcresult_zero_skips.py", "Scripts/CI/collect-runtime27-palette-log.py", "Scripts/CI/runtime27-hid.py",
            "Scripts/CI/runtime27-fixture-recovery.py", "Scripts/CI/runtime27-url-delivery.py", "Scripts/CI/shutdown-faithful-simulator.py",
            "Scripts/CI/verify-faithful-xctest.py"]}
        if contract.get("hid_comparison"):
            if run_logged([sys.executable, "Scripts/CI/runtime27-hid.py", "prepare", "--out", str(OUT / "hid-tools.json")],
                          "hid-prepare.log", 360, interrupt_controller=controller):
                raise RuntimeError("Isolated native HID tool preflight failed; comparison UI NOT_RUN")
            report["idb"] = "PINNED_JOB_LOCAL_HID_COMPARISON_ORIGINAL_XCTEST_CASE_RETAINED"
        if run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing", "--derived-data", "build/DerivedData"],
                      "build-for-testing-driver.log", 4200, interrupt_controller=controller):
            raise RuntimeError("Real app/test build failed; UI cases NOT_RUN")
        products = ROOT / "build/DerivedData/Build/Products/Debug-iphonesimulator"
        binaries = {}
        for bundle in [products / "Maktabah.app", products / "Maktabah-iOSUITests-Runner.app"]:
            info = plistlib.loads((bundle / "Info.plist").read_bytes())
            binary = bundle / info["CFBundleExecutable"]
            binaries[str(bundle.relative_to(ROOT))] = hashlib.sha256(binary.read_bytes()).hexdigest()
            if bundle.name == "Maktabah.app":
                report["palette_compiled_code_images"] = capture_palette_code_images(bundle, info["CFBundleExecutable"])
        test_bundle = products / "Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest"
        test_info = plistlib.loads((test_bundle / "Info.plist").read_bytes())
        binaries[str(test_bundle.relative_to(ROOT))] = hashlib.sha256((test_bundle / test_info["CFBundleExecutable"]).read_bytes()).hexdigest()
        for test_run in (ROOT / "build/DerivedData/Build/Products").glob("*.xctestrun"):
            shutil.copyfile(test_run, OUT / test_run.name)
        report["built_binary_sha256"] = binaries
        if report["mode"] == "release":
            return runpy.run_path(str(ROOT / "Scripts/CI/runtime27-release.py"))["run"](
                report, run_logged, controller)
        os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(contract_path)
        os.environ["VALIDATING_BASELINE"] = "false"
        # The expanded matrix includes long bidirectional sidebar transition loops.
        # Increase only the whole-matrix budget; per-case assertions/timeouts stay intact.
        # Native app installer, exact disposable-device lifecycle, existing tests.
        code = run_logged([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"], "native-matrix-driver.log", 16200, interrupt_controller=controller)
        collect_cases(report, contract)
        matrix_path = ROOT / "build/artifacts/faithful-ipad-matrix.json"
        if code and matrix_path.is_file():
            try:
                matrix_report = json.loads(matrix_path.read_text())
                if matrix_report.get("status") == "INTERRUPTED_UI_UNVERIFIED":
                    report.update(status="INTERRUPTED_UI_UNVERIFIED", error="Matrix execution interrupted")
                    return 130
            except (OSError, ValueError):
                pass
        if code or report["executed_ui_pass"] != expected_count or report["executed_ui_fail"] or report["executed_ui_skip"]:
            raise RuntimeError("Required real UI subset failed, skipped or did not completely execute")
        selected = {identity for group in groups for identity in group["case_ids"]}
        full_phase = {case["case_id"] for case in contract["cases"] + contract.get("supplemental_cases", [])}
        report["status"] = "EXECUTED_PASS" if selected == full_phase and not contract.get("diagnostic_only", False) else "SELECTED_UI_EXECUTED_PASS"
        return 0
    except KeyboardInterrupt as error:
        controller.mark_interrupted(error)
        report.update(status="INTERRUPTED_UI_UNVERIFIED", error=str(error) or "External interruption")
        return 130
    except Exception as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        with controller.cleanup_scope():
            try:
                if report["mode"] == "ui" and "case_outcomes" not in report:
                    try:
                        collect_cases(report, json.loads(contract_path.read_text()))
                    except BaseException as error:
                        if isinstance(error, KeyboardInterrupt):
                            controller.mark_interrupted(error)
                            report["status"] = "INTERRUPTED_UI_UNVERIFIED"
                        report["case_collection_error"] = f"{type(error).__name__}: {error}"
            finally:
                try:
                    controller.apply_metadata(report)
                    (OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
                    print(json.dumps({key: report.get(key) for key in ("status", "checkout_sha", "sdk", "error")}, indent=2))
                finally:
                    controller.restore()


if __name__ == "__main__":
    raise SystemExit(main())
