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
import re
import signal
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/artifacts/runtime27"


def execution_groups(contract):
    """Exact nonzero affected scope; every group owns a fresh disposable sim."""
    cases = {row["case_id"]: row for row in contract["cases"]}
    if len(cases) != len(contract["cases"]):
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
        allowed = {"11": "11", "13": "13", "phone": "phone", "11-reader": "11", "11-window": "11"}
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


def stop_owned_process_group(process, grace_seconds=5, kill_wait_seconds=2):
    """Observe the created group independently of its Python leader's exit."""
    pgid = process.pid

    def alive():
        process.poll()  # Reap the leader if it exited; children may still exist.
        try:
            os.killpg(pgid, 0)
            return True
        except ProcessLookupError:
            return False

    def send(kind):
        try:
            os.killpg(pgid, kind)
        except ProcessLookupError:
            pass

    def wait_gone(seconds):
        end = time.monotonic() + seconds
        while alive():
            if time.monotonic() >= end:
                return False
            time.sleep(0.05)
        return True

    send(signal.SIGINT)
    gone = wait_gone(grace_seconds)
    if not gone:
        send(getattr(signal, "SIGKILL", signal.SIGTERM))
        gone = wait_gone(kill_wait_seconds)
    return {"owned_pgid": pgid, "group_state": "GONE_CHECKED" if gone else "STILL_PRESENT_UNVERIFIED",
            "off_group_simulator_agents": "NOT_INDEPENDENTLY_VERIFIED"}


def run_logged(command, name, timeout):
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
            marker = {
                "status": "INTERRUPTED_CHILD_UNVERIFIED", "exception": type(error).__name__,
                "owned_process_group": process.pid if owned_group else None,
                "acceptance_effect": "NONE; interrupted UI results require complete independent validation"}
            marker_path = OUT / (name + ".interrupted.json")
            marker_path.write_text(json.dumps(marker, indent=2) + "\n")
            if owned_group:
                try:
                    marker["cleanup"] = stop_owned_process_group(process)
                except OSError as cleanup_error:
                    marker["cleanup"] = {"error": type(cleanup_error).__name__, "state": "UNVERIFIED"}
                marker_path.write_text(json.dumps(marker, indent=2) + "\n")
            elif process.poll() is None:
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        pass  # Keep the original interruption, never claim cleanup completed.
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
                identity = runpy.run_path(str(ROOT / 'tools/verify_xcresult_zero_skips.py'))['case_id'](node.get('nodeIdentifier') or f"{suite}/{node['name']}")
                found[identity] = node.get("result", "unknown")
            for child in node.get("children", []):
                visit(child, suite)
        if tree_path.exists():
            for node in json.loads(tree_path.read_text()).get("testNodes", []):
                visit(node)
        for case in contract["cases"]:
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
    try:
        if sys.platform != "darwin":
            raise RuntimeError("R27 execution requires real macOS/Xcode")
        interrupt_received = False
        def interrupted(signum, frame):
            nonlocal interrupt_received
            if interrupt_received:
                return  # Already stopping owned work within the bounded grace.
            interrupt_received = True
            raise KeyboardInterrupt(f"External signal {signum}; UI acceptance remains unverified")
        signal.signal(signal.SIGINT, interrupted)
        signal.signal(signal.SIGTERM, interrupted)
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
        groups = execution_groups(contract)
        expected_count = sum(len(group["case_ids"]) for group in groups)
        report["execution_groups"] = groups
        report["full_phase_case_ids"] = [case["case_id"] for case in contract["cases"]]
        report["requested_ui_case_count"] = expected_count
        report["prior_pass_reuse"] = "Separate independent Q proof required; not counted as new execution"
        report["case_manifest_sha256"] = hashlib.sha256(contract_path.read_bytes()).hexdigest()
        report["full_release_acceptance"] = False
        report["scope"] = contract["scope"]
        test_path = ROOT / "Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"
        if hashlib.sha256(test_path.read_bytes()).hexdigest() != "a49f211277aa9f91aab8c254b9ac54ec6bac9ea5b6159884c626b44e2ae1458b":
            raise RuntimeError("Reviewed test source drift")
        report["test_source_commit"] = contract["source_test_commit"]
        subprocess.run(["git", "merge-base", "--is-ancestor", contract["source_test_commit"], "HEAD"], cwd=ROOT, check=True)
        report["test_tree"] = capture(["git", "rev-parse", "HEAD:Maktabah-iOSUITests"], "test-tree.txt").strip()
        report["test_inputs_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in sorted((ROOT / "Maktabah-iOSUITests").glob("*.swift"))}
        report["helper_inputs_sha256"] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [
            "Scripts/CI/hq-stage2-focused-apple.py", "Scripts/CI/hq-stage2-focused-apple.inputs.json", "Scripts/CI/runtime27.py",
            "Scripts/CI/run-faithful-ipad-matrix.py", "Scripts/CI/runtime27-fixture-oracle.py", "tools/verify_xcresult_zero_skips.py",
            "Scripts/CI/collect-runtime27-palette-log.py"]}
        if run_logged([sys.executable, "Scripts/CI/hq-stage2-focused-apple.py", "--build-for-testing", "--derived-data", "build/DerivedData"],
                      "build-for-testing-driver.log", 4200):
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
        os.environ["FAITHFUL_RUNTIME27_MANIFEST"] = str(contract_path)
        os.environ["VALIDATING_BASELINE"] = "false"
        # Native app installer, exact disposable-device lifecycle, existing tests.
        code = run_logged([sys.executable, "Scripts/CI/run-faithful-ipad-matrix.py"], "native-matrix-driver.log", 5400)
        collect_cases(report, contract)
        if code or report["executed_ui_pass"] != expected_count or report["executed_ui_fail"] or report["executed_ui_skip"]:
            raise RuntimeError("Required real UI subset failed, skipped or did not completely execute")
        report["status"] = "EXECUTED_PASS" if expected_count == len(contract["cases"]) else "SELECTED_UI_EXECUTED_PASS"
        return 0
    except KeyboardInterrupt as error:
        report.update(status="INTERRUPTED_UI_UNVERIFIED", error=str(error) or "External interruption")
        return 130
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
