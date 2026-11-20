#!/usr/bin/env python3
"""Synthetic orchestration controls; no Apple build, Simulator or Native claim."""
import copy
import ast
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout, redirect_stderr

CI = Path(__file__).resolve().parent
REPO = CI.parents[1]
stages = runpy.run_path(str(CI / "runtime27-release-stages.py"))
release = runpy.run_path(str(CI / "runtime27-release.py"))
helper = runpy.run_path(str(CI / "hq-stage2-focused-apple.py"))


class RestoredInputsTests(unittest.TestCase):
    def setUp(self):
        self.build = {key: {"synthetic_original": key} for key in [
            "checkout_sha", "application_source_sha", "application_trees", "validator_sha256",
            "inputs_sha256", "workflow_sha256", "package_pins", "package_resolved_sha256",
            "hanlin_gitlink", "hanlin_sdk_source", "actual_package_checkouts", "actual_source_inputs_verified",
            "native_context", "resource_inputs"]}
        self.restored = {**copy.deepcopy(self.build), "status": "PREPARED_ORIGINAL_INPUTS_ONLY", "app_build_executed": False}
        self.sources = {"Source/fixture.swift": "a" * 40}

    def check(self, restored_sources=None):
        stages["verify_restored_input_context"](self.build, self.restored, self.sources,
                                                self.sources if restored_sources is None else restored_sources)

    def test_identical_original_inputs_pass_without_debug_rebuild(self):
        self.check()

    def test_each_source_sdk_lock_package_resource_and_context_drift_is_rejected(self):
        for field in self.build:
            original = self.restored[field]
            with self.subTest(field=field):
                self.restored[field] = {"changed": True}
                with self.assertRaisesRegex(ValueError, "input differs"):
                    self.check()
                self.restored[field] = original

    def test_missing_original_input_cannot_silently_match_absence(self):
        self.build.pop("hanlin_sdk_source")
        self.restored.pop("hanlin_sdk_source")
        with self.assertRaisesRegex(ValueError, "input differs"):
            self.check()

    def test_changed_actual_tracked_byte_inventory_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "actual source bytes"):
            self.check({"Source/fixture.swift": "b" * 40})
        self.sources.clear()
        with self.assertRaisesRegex(ValueError, "actual source bytes"):
            self.check()

    def test_a_fresh_debug_build_or_full_acceptance_cannot_replace_input_restoration(self):
        for field, value in [("status", "SIMULATOR_BUILD_FOR_REAL_UI_PASS"), ("status", "EXECUTED_PASS"),
                             ("app_build_executed", True), ("app_build_executed", None)]:
            original = self.restored[field]
            with self.subTest(field=field, value=value):
                self.restored[field] = value
                with self.assertRaisesRegex(ValueError, "Debug rebuild"):
                    self.check()
                self.restored[field] = original


class PreparationControlTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.calls = []
        self.inputs = self.root / "inputs.json"
        self.inputs.write_text("{}")
        self.original_evidence = self.root / "build/hq-stage2/result.json"
        self.original_evidence.parent.mkdir(parents=True)
        self.original_evidence.write_text("retained original Debug proof")
        for path in ["Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
                     "Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved"]:
            lock = self.root / path
            lock.parent.mkdir(parents=True)
            lock.write_text("retained synthetic lock")

    def invoke(self, arguments):
        def record(name):
            def call(*args, **kwargs):
                self.calls.append((name, kwargs))
            return call
        def logged(command, *args, **kwargs):
            self.calls.append(("logged", command))
        globals_ = helper["main"].__globals__
        overrides = {name: record(name) for name in [
            "verify_zayit_test_metadata", "prepare_original_hanlin", "prepare_react_sources", "restore",
            "rebuild_matching_zayit_framework", "prepare_matching_embedded_bundle", "install_real_pods",
            "verify_actual_sources", "verify_selected_zayit_files", "authorize_pinned_equatable_macro"]}
        overrides.update(ROOT=self.root, OUT=self.original_evidence.parent, INPUTS=self.inputs,
                         preflight=lambda _: {"package_pins": {"fixture": "a" * 40}},
                         capture=lambda *args: "synthetic tool response",
                         pins=lambda _: {"fixture": "a" * 40}, logged=logged)
        with patch.dict(globals_, overrides), patch.object(sys, "argv", ["helper", *arguments]), \
             patch.object(sys, "platform", "darwin"), \
             patch.object(subprocess, "run", return_value=SimpleNamespace(stdout="-onlyUsePackageVersionsFromResolvedFile")), \
             redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return helper["main"]()

    def test_input_only_runs_original_preparation_but_never_xcode_debug_build(self):
        self.assertEqual(self.invoke(["--build-for-testing", "--prepare-inputs-only",
                                      "--preparation-evidence-dir", "build/artifacts/restored-inputs"]), 0)
        names = [name for name, _ in self.calls if name != "logged"]
        self.assertEqual(names, ["verify_zayit_test_metadata", "prepare_original_hanlin", "prepare_react_sources",
                                "restore", "rebuild_matching_zayit_framework", "prepare_matching_embedded_bundle",
                                "install_real_pods", "verify_actual_sources", "verify_selected_zayit_files",
                                "authorize_pinned_equatable_macro", "prepare_original_hanlin"])
        commands = [value for name, value in self.calls if name == "logged"]
        self.assertTrue(any("-resolvePackageDependencies" in command for command in commands))
        self.assertFalse(any("build-for-testing" in command or "build" in command for command in commands))
        result = json.loads((self.root / "build/artifacts/restored-inputs/result.json").read_text())
        self.assertEqual(result["status"], "PREPARED_ORIGINAL_INPUTS_ONLY")
        self.assertIs(result["app_build_executed"], False)
        self.assertEqual(self.original_evidence.read_text(), "retained original Debug proof")

    def test_input_only_cannot_overwrite_original_build_evidence(self):
        with self.assertRaisesRegex(RuntimeError, "accepted Debug"):
            self.invoke(["--build-for-testing", "--prepare-inputs-only",
                         "--preparation-evidence-dir", "build/hq-stage2"])
        self.assertFalse(self.calls)

    def test_input_only_requires_original_testing_input_checks(self):
        for arguments in [["--prepare-inputs-only"],
                          ["--prepare-inputs-only", "--preparation-evidence-dir", "build/restored"],
                          ["--build-for-testing", "--preflight-only", "--prepare-inputs-only",
                           "--preparation-evidence-dir", "build/restored"]]:
            with self.subTest(arguments=arguments), self.assertRaises(RuntimeError):
                self.invoke(arguments)
        self.assertFalse(self.calls)

    def test_separate_evidence_argument_cannot_modify_default_mode(self):
        with self.assertRaisesRegex(RuntimeError, "requires input-only"):
            self.invoke(["--preparation-evidence-dir", "build/restored"])
        self.assertFalse(self.calls)


class NativeStageFixture(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.out = self.root / "build/artifacts/runtime27"
        self.out.mkdir(parents=True)
        self.manifest = json.loads((CI / "runtime27-release-manifest.json").read_text())
        manifest_path = self.root / "Scripts/CI/runtime27-release-manifest.json"
        manifest_path.parent.mkdir(parents=True)
        manifest_path.write_text(json.dumps(self.manifest))
        guard = self.root / "tools/verify_xcresult_zero_skips.py"
        guard.parent.mkdir()
        shutil.copyfile(REPO / "tools/verify_xcresult_zero_skips.py", guard)
        self.report = {"checkout_sha": "a" * 40, "status": "RELEASE_BUILD_ONLY_PASS",
                       "scope": "full-release-ui", "release_stage": "build", "full_release_acceptance": False,
                       "built_binary_sha256": {
                           "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah.app": "b" * 64,
                           "build/DerivedData/Build/Products/Debug-iphonesimulator/Maktabah-iOSUITests-Runner.app/PlugIns/Maktabah-iOSUITests.xctest": "c" * 64}}
        matrix = {"appSHA": self.report["checkout_sha"], "baseline": False, "fullMatrixAcceptance": True,
                  "diagnosticCases": [], "releaseManifestSHA256": stages["transfer"].digest(manifest_path), "devices": []}
        for size in ["11", "13", "phone"]:
            matrix["devices"].append({"size": size, "status": "EXECUTED_PASS", "ownedSimulatorCleanup": "PASS",
                "udid": "synthetic-owned-" + size, "runtime": {"version": "27.2", "buildversion": "synthetic"},
                "largeText": {"status": "EXECUTED_PASS", "actual": "accessibility-extra-extra-extra-large"}})
        self.write("build/artifacts/faithful-ipad-matrix.json", matrix)
        for row in self.manifest["configurations"]:
            if row["data_profile"] == "production":
                continue
            size = row["device_size"]
            label = "13-large-text" if "content_size" in row else size
            cases = row["required_ui_cases"] + row.get("required_oracle_cases", [])
            suites = {}
            for case in cases:
                suite, method = case.split("/")
                suites.setdefault(suite, []).append({"nodeType": "Test Case", "name": method + "()",
                    "nodeIdentifier": case + "()", "result": "Passed"})
            tree = {"devices": [{"deviceId": "synthetic-owned-" + size, "osVersion": "27.2"}],
                    "testNodes": [{"nodeType": "UI test bundle", "name": "Maktabah-iOSUITests", "children": [
                        {"nodeType": "Test Suite", "name": suite, "children": values} for suite, values in suites.items()]}]}
            summary = {"result": "Passed", "totalTestCount": len(cases), "passedTests": len(cases),
                       "failedTests": 0, "skippedTests": 0, "expectedFailures": 0, "testFailures": []}
            self.write(f"build/artifacts/runtime27/verified-{label}.summary.json", summary)
            self.write(f"build/artifacts/runtime27/verified-{label}.tests.json", tree)
            log = ["R27_RUNTIME_CONFIGURATION " + json.dumps({"bundle_id": "com.davidpovarsky.chavrusatext",
                "locale_source": "XCUIApplication.launchArguments/-AppleLocale", "orientation_source": "XCUIDevice.shared.orientation",
                "test": cases[0], "foreground": True, "locale": "he_IL", "orientation": 1})]
            log.extend("Test Case '-[" + case.replace("/", " ") + "]' passed (1 second)" for case in cases)
            log.append(f"Executed {len(cases)} tests")
            log.append("** TEST SUCCEEDED **")
            self.write(f"build/artifacts/test-simulator-{label}.log", "\n".join(log))
        self.write("build/runtime27-handoff/imported-build.json", {"synthetic_fixture": True})
        self.globals = stages["strict_native_configurations"].__globals__
        self.release_module = {**release, "load_manifest": lambda root: self.manifest}
        self.addCleanup(patch.stopall)
        patch.dict(self.globals, ROOT=self.root, OUT=self.out,
                   module=lambda _: self.release_module).start()

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value if isinstance(value, str) else json.dumps(value))


class NativeAcceptanceBoundaryTests(NativeStageFixture):
    def test_original_four_config_gates_count_95_ui_and_two_separate_oracles(self):
        checked = stages["strict_native_configurations"](self.report, self.manifest)
        self.assertEqual(checked["required_ui_passed"], 95)
        self.assertEqual(checked["separate_oracle_executed"], 2)
        self.assertIs(checked["full_release_acceptance"], False)
        self.assertEqual(len(checked["configurations"]), 4)

    def test_partial_device_matrix_cannot_reach_production(self):
        path = self.root / "build/artifacts/faithful-ipad-matrix.json"
        matrix = json.loads(path.read_text())
        matrix["devices"].pop()
        path.write_text(json.dumps(matrix))
        with self.assertRaisesRegex(ValueError, "Missing or duplicate"):
            stages["strict_native_configurations"](self.report, self.manifest)

    def test_a_skipped_leaf_is_not_success_even_with_passing_matrix_report(self):
        path = self.out / "verified-phone.tests.json"
        tree = json.loads(path.read_text())
        tree["testNodes"][0]["children"][0]["children"][0]["result"] = "Skipped"
        path.write_text(json.dumps(tree))
        with self.assertRaises(ValueError):
            stages["strict_native_configurations"](self.report, self.manifest)

    def test_failed_largest_text_does_not_satisfy_native_predecessor(self):
        path = self.root / "build/artifacts/faithful-ipad-matrix.json"
        matrix = json.loads(path.read_text())
        matrix["devices"][1]["largeText"]["status"] = "FAIL"
        path.write_text(json.dumps(matrix))
        with self.assertRaisesRegex(ValueError, "did not pass"):
            stages["strict_native_configurations"](self.report, self.manifest)

    def invoke_native(self, exit_code, hid_exit_code=0):
        controller = SimpleNamespace(apply_metadata=lambda report: None)
        args = SimpleNamespace(build_artifact=301, build_archive_sha="6" * 64)
        self.commands = []
        def logged(command, *args, **kwargs):
            self.commands.append(command)
            return hid_exit_code if "Scripts/CI/runtime27-hid.py" in command else exit_code
        with patch.dict(self.globals, import_handoff=lambda *a: None,
                        expected_build_report=lambda: (copy.deepcopy(self.report), {})), \
             patch.object(stages["transfer"], "verify_products", return_value={"synthetic": True}), \
             patch.object(stages["transfer"], "original_xctestrun", return_value=self.root / "original.xctestrun"), \
             patch.dict(os.environ, {}, clear=True):
            return stages["native_stage"](args, logged, controller)

    def test_successful_native_stage_remains_partial_with_original_counts(self):
        self.assertEqual(self.invoke_native(0), 0)
        report = json.loads((self.out / "result.json").read_text())
        self.assertEqual(report["status"], "RELEASE_NATIVE_MATRIX_ONLY_PASS")
        self.assertIs(report["full_release_acceptance"], False)
        self.assertEqual((report["executed_ui_pass"], report["ui_not_run"]), (95, 1))

    def test_failed_child_never_inherits_build_success_or_invents_counts(self):
        with self.assertRaisesRegex(ValueError, "matrix failed"):
            self.invoke_native(65)
        report = json.loads((self.out / "result.json").read_text())
        self.assertEqual(report["status"], "FAIL")
        self.assertIs(report["full_release_acceptance"], False)
        self.assertIsNone(report["executed_ui_pass"])
        self.assertIn("matrix failed", report["error"]["message"])

    def test_required_hid_tools_are_prepared_on_actual_native_host_before_matrix(self):
        self.assertEqual(self.invoke_native(0), 0)
        self.assertEqual([command[1] for command in self.commands],
                         ["Scripts/CI/runtime27-hid.py", "Scripts/CI/run-faithful-ipad-matrix.py"])
        self.assertIn(str(self.out / "hid-tools.json"), self.commands[0])

    def test_hid_preparation_failure_keeps_the_matrix_unexecuted(self):
        with self.assertRaisesRegex(ValueError, "HID preflight failed"):
            self.invoke_native(0, hid_exit_code=1)
        self.assertEqual(len(self.commands), 1)
        report = json.loads((self.out / "result.json").read_text())
        self.assertEqual(report["status"], "FAIL")
        self.assertIs(report["full_release_acceptance"], False)


class ExistingHIDRequirementTests(unittest.TestCase):
    CASE = "R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector"

    def condition(self):
        source = ast.parse((CI / "run-faithful-ipad-matrix.py").read_text())
        candidates = []
        for node in ast.walk(source):
            if isinstance(node, ast.If) and any(
                isinstance(item, ast.Assign) and isinstance(item.value, ast.Call)
                and isinstance(item.value.func, ast.Subscript)
                and isinstance(item.value.func.slice, ast.Constant) and item.value.func.slice.value == "HIDComparison"
                for item in node.body):
                candidates.append(node.test)
        self.assertEqual(len(candidates), 1)
        return candidates[0]

    def evaluate(self, condition, contract=None, scenario=None, release_manifest=None, selection=None):
        return bool(eval(compile(ast.Expression(condition), "actual-matrix-hid-condition", "eval"),
                         {"runtime27_contract": contract, "scenario": scenario or {}, "runpy": runpy,
                          "release_manifest": release_manifest, "selection": selection or []}))

    def test_original_release_window_requirement_was_not_reached_by_old_group_only_condition(self):
        actual = self.condition()
        self.assertIsInstance(actual.op, ast.Or)
        kwargs = {"release_manifest": {"synthetic": True}, "selection": [self.CASE]}
        self.assertFalse(self.evaluate(actual.values[0], **kwargs))
        self.assertTrue(self.evaluate(actual, **kwargs))

    def test_existing_native_phase_hid_selection_and_group_opt_out_are_preserved(self):
        actual = self.condition()
        self.assertTrue(self.evaluate(actual, contract={"hid_comparison": True}, scenario={"hid_comparison": True}))
        self.assertFalse(self.evaluate(actual, contract={"hid_comparison": True}, scenario={"hid_comparison": False}))
        self.assertFalse(self.evaluate(actual, contract={"hid_comparison": False}))

    def test_unrelated_release_case_does_not_start_hid_transport(self):
        self.assertFalse(self.evaluate(self.condition(), release_manifest={"synthetic": True},
                                       selection=["R27NativePadTests/testNormalBootstrapLegacyGenesisAndRotation"]))
        self.assertFalse(release["requires_native_hid"]([self.CASE + "Extra"]))


class OutcomePublicationTests(unittest.TestCase):
    def test_original_final_gate_failure_cannot_publish_release_success(self):
        report = {"status": "FAIL", "full_release_acceptance": False, "checkout_sha": "a" * 40}
        def reject(*args, **kwargs):
            raise ValueError("synthetic final gate rejection")
        globals_ = release["complete_release"].__globals__
        with patch.dict(globals_, collect_configurations=lambda *a: []), \
             patch.object(runpy, "run_path", return_value={"verify_artifact_evidence": reject,
                                                          "candidate_dependency_requirements": lambda: {}}):
            with self.assertRaisesRegex(ValueError, "final gate rejection"):
                release["complete_release"](Path("synthetic-root"), report, {}, "b" * 64, {"application_trees": {}})
        self.assertEqual(report["status"], "FAIL")
        self.assertIs(report["full_release_acceptance"], False)

    def test_failed_import_has_durable_failure_before_a_stage_report_exists(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "runtime27"
            class Controller:
                def install(self): return self
                def restore(self): pass
                def apply_metadata(self, report): pass
            def fail(*args):
                raise ValueError("synthetic source-mismatched import")
            globals_ = stages["main"].__globals__
            with patch.dict(globals_, OUT=out, module=lambda _: {"run_logged": lambda *a: None}, native_stage=fail), \
                 patch.object(stages["runtime27_interruption"], "InterruptController", Controller), \
                 patch.object(sys, "argv", ["stage", "native"]):
                with self.assertRaisesRegex(ValueError, "source-mismatched"):
                    stages["main"]()
            report = json.loads((out / "result.json").read_text())
            self.assertEqual(report["status"], "FAIL")
            self.assertIs(report["full_release_acceptance"], False)
            self.assertTrue((out / "release-native-failure.json").is_file())

    def test_diagnostic_or_baseline_scope_is_rejected(self):
        for environment in [{"FAITHFUL_RUNTIME27_MANIFEST": "subset"}, {"FAITHFUL_DIAGNOSTIC_CASES": "Suite/testOne"},
                            {"VALIDATING_BASELINE": "true"}]:
            with self.subTest(environment=environment), patch.dict(os.environ, environment, clear=True):
                with self.assertRaisesRegex(ValueError, "scoped diagnostics"):
                    stages["set_release_environment"]()

    def test_complete_manifest_remains_five_configurations_96_ui_and_two_oracles(self):
        manifest = json.loads((CI / "runtime27-release-manifest.json").read_text())
        self.assertEqual(len(manifest["configurations"]), 5)
        self.assertEqual(sum(len(row["required_ui_cases"]) for row in manifest["configurations"]), 96)
        self.assertEqual(sum(len(row.get("required_oracle_cases", [])) for row in manifest["configurations"]), 2)
        self.assertTrue(manifest["full_release_acceptance_required"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
