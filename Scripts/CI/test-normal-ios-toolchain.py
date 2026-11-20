#!/usr/bin/env python3
"""Execute the original runtime-selection program against explicit OS/plist doubles.

This is source/contract validation only. It does not compile an app, invoke
Xcode/simctl, install a runtime, or grant Native acceptance.
"""
import argparse
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "2f74d05b1cf75597b3a38fa64d0939b45caa44c2"
SHELL = "Scripts/run-ipad-simulator-acceptance.sh"
WORKFLOW = ".github/workflows/ios-build.yml"
SELECTOR = "Scripts/CI/select-runtime27-toolchain.py"
SCRIPT_TEXT = ""
WORKFLOW_TEXT = ""

def git_text(ref, path):
    return subprocess.check_output(["git", "show", ref + ":" + path],
                                   cwd=ROOT).decode("utf-8")

def device(name, suffix):
    return {"name": name, "identifier": "com.apple.CoreSimulator.SimDeviceType." + suffix}

PAD11 = device("iPad Pro 11-inch (M4)", "iPad-Pro-11-inch-M4")
PAD13 = device("iPad Pro 13-inch (M4)", "iPad-Pro-13-inch-M4")
PHONE = device("iPhone 17", "iPhone-17")
TYPES = [PAD11, PAD13, PHONE]

def runtime(value="27.2", *, available=True, types=None, identifier=None):
    return {"identifier": identifier or "com.apple.CoreSimulator.SimRuntime.iOS-" + value.replace(".", "-"),
            "version": value, "buildversion": "explicit-test-build", "isAvailable": available,
            "supportedDeviceTypes": TYPES if types is None else types}

def selection(*, minimum="27.0", sdk="27.2", runtimes=None, types=None, requested=None):
    rows = [runtime()] if runtimes is None else runtimes
    known_types = TYPES if types is None else types
    output = io.StringIO()
    with tempfile.TemporaryDirectory(prefix="normal-ios-selection-") as temporary:
        folder = Path(temporary)
        app = folder / "Original.app"
        app.mkdir()
        with (app / "Info.plist").open("wb") as stream:
            plistlib.dump({} if minimum is None else {"MinimumOSVersion": minimum}, stream)
        report = folder / "selection.json"
        calls = []
        def command(arguments, **kwargs):
            calls.append(arguments)
            if arguments == ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]:
                return sdk
            if arguments == ["xcrun", "simctl", "list", "runtimes", "available", "-j"]:
                return json.dumps({"runtimes": rows})
            if arguments == ["xcrun", "simctl", "list", "devicetypes", "-j"]:
                return json.dumps({"devicetypes": known_types})
            raise AssertionError("Unexpected process in source fixture: " + repr(arguments))
        environment = dict(os.environ)
        environment.pop("FAITHFUL_RUNTIME27_IDENTIFIER", None)
        if requested is not None:
            environment["FAITHFUL_RUNTIME27_IDENTIFIER"] = requested
        try:
            if "# BEGIN NORMAL_IOS_RUNTIME_SELECTION\n" in SCRIPT_TEXT:
                program = SCRIPT_TEXT.split("# BEGIN NORMAL_IOS_RUNTIME_SELECTION\n", 1)[1].split(
                    "# END NORMAL_IOS_RUNTIME_SELECTION\n", 1)[0]
                with patch.dict(os.environ, environment, clear=True), patch.object(
                        sys, "argv", ["selection", str(app), str(ROOT), str(report)]), patch(
                        "subprocess.check_output", side_effect=command), contextlib.redirect_stdout(output):
                    exec(compile(program, SHELL + ":runtime-selection", "exec"), {"__name__": "selection_fixture"})
                identifier, selected_type = output.getvalue().strip().split("\t")
            else:
                # Execute both original -c programs with their original stdin
                # contract. No alternative selector implements baseline behavior.
                values = {}
                for variable, field, data in [("DEVICE_TYPE", "devicetypes", known_types),
                                               ("RUNTIME", "runtimes", rows)]:
                    line = next(line for line in SCRIPT_TEXT.splitlines() if line.startswith(variable + '="$('))
                    program = line.split("python3 -c '", 1)[1].rsplit("'", 1)[0]
                    stream = io.StringIO()
                    with patch.object(sys, "stdin", io.StringIO(json.dumps({field: data}))), contextlib.redirect_stdout(stream):
                        exec(compile(program, SHELL + ":" + variable, "exec"), {"__name__": "selection_fixture"})
                    values[variable] = stream.getvalue().strip()
                identifier, selected_type = values["RUNTIME"], values["DEVICE_TYPE"]
            return {"admitted": True, "runtime": identifier, "device": selected_type,
                    "report": json.loads(report.read_bytes()) if report.exists() else None,
                    "commands": calls}
        except (SystemExit, Exception) as error:
            return {"admitted": False, "error_type": type(error).__name__, "message": str(error), "commands": calls}

class RuntimeSelectionContract(unittest.TestCase):
    def reject(self, **kwargs):
        result = selection(**kwargs)
        self.assertFalse(result["admitted"], result)

    def test_original_27_app_sdk_runtime_pair_is_admitted(self):
        result = selection()
        self.assertTrue(result["admitted"], result)
        self.assertEqual(result["runtime"], runtime()["identifier"])
        self.assertEqual(result["device"], PAD13["identifier"])

    def test_explicit_selected_runtime_is_preserved(self):
        selected = runtime("27.2.1")
        result = selection(runtimes=[selected, runtime("27.2.2")], requested=selected["identifier"])
        self.assertTrue(result["admitted"], result)
        self.assertEqual(result["runtime"], selected["identifier"])

    def test_inventory_order_cannot_select_old_runtime(self):
        result = selection(runtimes=[runtime(), runtime("26.5")])
        self.assertTrue(result["admitted"], result)
        self.assertEqual(result["runtime"], runtime()["identifier"])

    def test_selected_type_must_belong_to_selected_runtime(self):
        newer = device("iPad Pro 13-inch (M5)", "iPad-Pro-13-inch-M5")
        result = selection(runtimes=[runtime(types=[PAD11, newer, PHONE])], types=TYPES + [newer])
        self.assertTrue(result["admitted"], result)
        self.assertEqual(result["device"], newer["identifier"])

    def test_sdk26_is_denied(self):
        self.reject(sdk="26.5", runtimes=[runtime("26.5")])

    def test_unreviewed_sdk28_is_denied(self):
        self.reject(sdk="28.0", runtimes=[runtime("28.0")])

    def test_older_runtime_minor_is_denied(self):
        self.reject(runtimes=[runtime("27.1")])

    def test_newer_runtime_minor_does_not_replace_sdk_pair(self):
        self.reject(runtimes=[runtime("27.3")])

    def test_app_minimum_above_runtime_is_denied(self):
        self.reject(minimum="27.3")

    def test_app_minimum_patch_is_checked(self):
        self.reject(minimum="27.2.2", runtimes=[runtime("27.2.1")])

    def test_matching_patch_runtime_can_run_app(self):
        result = selection(minimum="27.2.1", runtimes=[runtime("27.2.2")])
        self.assertTrue(result["admitted"], result)

    def test_missing_app_minimum_is_denied(self):
        self.reject(minimum=None)

    def test_malformed_app_minimum_is_denied(self):
        self.reject(minimum="27.beta")

    def test_requested_missing_runtime_is_denied(self):
        self.reject(requested=runtime("27.1")["identifier"])

    def test_requested_unavailable_runtime_is_denied(self):
        row = runtime(available=False)
        self.reject(runtimes=[row, runtime("27.2.1")], requested=row["identifier"])

    def test_duplicate_requested_runtime_is_denied(self):
        self.reject(runtimes=[runtime(), runtime()], requested=runtime()["identifier"])

    def test_no_available_runtime_is_denied(self):
        self.reject(runtimes=[])

    def test_no_supported_13_inch_type_is_denied(self):
        self.reject(runtimes=[runtime(types=[PAD11, PHONE])])

    def test_no_supported_phone_is_denied_by_original_selector(self):
        self.reject(runtimes=[runtime(types=[PAD11, PAD13])])

    def test_no_supported_11_inch_type_is_denied_by_original_selector(self):
        self.reject(runtimes=[runtime(types=[PAD13, PHONE])])

    def test_supported_type_absent_from_installed_inventory_is_denied(self):
        self.reject(types=[PAD11, PHONE])

    def test_runtime_identifier_cannot_break_shell_output(self):
        bad = runtime(identifier=runtime()["identifier"] + "\nextra")
        self.reject(runtimes=[bad])

    def test_device_identifier_cannot_break_shell_output(self):
        bad = device("iPad Pro 13-inch (M4)", "iPad-Pro-13-inch-M4\textra")
        self.reject(runtimes=[runtime(types=[PAD11, bad, PHONE])], types=[PAD11, bad, PHONE])

    def test_receipt_reports_only_observed_selection_without_native_pass(self):
        result = selection()
        self.assertTrue(result["admitted"], result)
        self.assertEqual(result["report"]["app_minimum_os"], "27.0")
        self.assertEqual(result["report"]["sdk_version"], "27.2")
        self.assertEqual(result["report"]["runtime"]["identifier"], result["runtime"])
        self.assertEqual(result["report"]["native_ui_executed"], 0)
        self.assertEqual(len(result["commands"]), 3)

class WorkflowContract(unittest.TestCase):
    def setUp(self):
        self.before = yaml.load(git_text(BASELINE, WORKFLOW), Loader=yaml.BaseLoader)
        self.current = yaml.load(WORKFLOW_TEXT, Loader=yaml.BaseLoader)
        self.apple = ["otzaria-framework", "zayit-framework", "swiftpm",
                      "simulator-build", "device-build", "native-bootstrap-heavy"]

    def test_all_original_apple_jobs_use_reviewed_runner(self):
        for name in self.apple:
            with self.subTest(job=name):
                self.assertEqual(self.current["jobs"][name]["runs-on"], "xcode-27")

    def test_each_job_selects_actual_installed_pair(self):
        for name in self.apple:
            with self.subTest(job=name):
                steps = self.current["jobs"][name]["steps"]
                matches = [step for step in steps if "select-runtime27-toolchain.py" in step.get("run", "")]
                self.assertEqual(len(matches), 1)
                self.assertIn("--github-env", matches[0]["run"])
                self.assertNotIn("select-xcode-26.sh", "\n".join(step.get("run", "") for step in steps))

    def test_cache_identity_reads_next_step_published_environment(self):
        for name, identity in [("otzaria-framework", "xcode"), ("zayit-framework", "xcode"),
                               ("swiftpm", "cache-inputs")]:
            with self.subTest(job=name):
                steps = self.current["jobs"][name]["steps"]
                selectors = [i for i, row in enumerate(steps) if "select-runtime27-toolchain.py" in row.get("run", "")]
                identities = [i for i, row in enumerate(steps) if row.get("id") == identity]
                self.assertEqual(len(selectors), 1)
                self.assertEqual(len(identities), 1)
                self.assertLess(selectors[0], identities[0])
                code = steps[identities[0]]["run"]
                for actual in ["xcodebuild -version", "xcrun swiftc --version",
                               "xcrun --sdk iphoneos --show-sdk-version",
                               "xcrun --sdk iphonesimulator --show-sdk-version"]:
                    self.assertIn(actual, code)

    def test_original_workflow_inputs_permissions_and_sdk_are_unchanged(self):
        self.assertEqual({k: v for k, v in self.current.items() if k != "jobs"},
                         {k: v for k, v in self.before.items() if k != "jobs"})
        self.assertEqual(self.current["env"]["HANLIN_SDK_SHA"], "e00498e33f106cc43be0476ffa2e09329c8ca300")

    def test_all_other_original_steps_conditions_and_timeouts_are_exact(self):
        self.assertEqual(set(self.current["jobs"]), set(self.before["jobs"]))
        def without_selection(steps):
            return [row for row in steps if row.get("id") not in {"xcode", "cache-inputs"}
                    and "select-xcode-26.sh" not in row.get("run", "")
                    and "select-runtime27-toolchain.py" not in row.get("run", "")]
        for name, original in self.before["jobs"].items():
            with self.subTest(job=name):
                current = self.current["jobs"][name]
                self.assertEqual({k: v for k, v in current.items() if k not in {"steps", "runs-on"}},
                                 {k: v for k, v in original.items() if k not in {"steps", "runs-on"}})
                if name not in self.apple:
                    self.assertEqual(current["runs-on"], original["runs-on"])
                self.assertEqual(without_selection(current["steps"]), without_selection(original["steps"]))

class Result(unittest.TextTestResult):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.passed = []
    def addSuccess(self, test):
        super().addSuccess(test)
        self.passed.append(test.id())

def main():
    global SCRIPT_TEXT, WORKFLOW_TEXT
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-ref", help="Execute source from this immutable baseline; default exact working candidate")
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    SCRIPT_TEXT = git_text(args.source_ref, SHELL) if args.source_ref else (ROOT / SHELL).read_text(encoding="utf-8")
    WORKFLOW_TEXT = git_text(args.source_ref, WORKFLOW) if args.source_ref else (ROOT / WORKFLOW).read_text(encoding="utf-8")
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite)
    report = {"status": "PASS_SOURCE_CONTRACT_ONLY" if result.wasSuccessful() else "FAIL_SOURCE_CONTRACT",
              "source_ref": args.source_ref, "git_head": subprocess.check_output(
                  ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "inputs_sha256_lf": {SHELL: hashlib.sha256(SCRIPT_TEXT.encode()).hexdigest(),
                                  WORKFLOW: hashlib.sha256(WORKFLOW_TEXT.encode()).hexdigest(),
                                  SELECTOR: hashlib.sha256((ROOT / SELECTOR).read_bytes().replace(b"\r\n", b"\n")).hexdigest()},
              "test_methods_run": result.testsRun, "passed_methods": result.passed,
              "failures": [(test.id(), detail) for test, detail in result.failures],
              "errors": [(test.id(), detail) for test, detail in result.errors],
              "skipped": result.skipped, "native_executed": 0, "apple_compiles": 0,
              "boundaries": "Original shell-embedded selection and original common selector, actual temporary plist I/O; explicit OS/SDK inventory and subprocess doubles. Original workflow parsed structurally. No Xcode/simctl executed."}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if result.wasSuccessful() else 1

if __name__ == "__main__":
    raise SystemExit(main())
