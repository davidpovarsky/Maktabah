#!/usr/bin/env python3
"""Release-gate false-green fixtures, not real UI execution."""
import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import runpy
import tempfile
import unittest
import xml.etree.ElementTree as ET

gate = runpy.run_path(str(Path(__file__).with_name("verify-runtime27-release-gate.py")))
collect = runpy.run_path(str(Path(__file__).with_name("runtime27.py")))["collect_cases"]


class ReleaseGateTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.addCleanup(self.folder.cleanup)
        self.sha = "a" * 40
        self.now = datetime(2026, 11, 15, 12, tzinfo=timezone.utc)
        self.run = {"status": "completed", "conclusion": "success", "head_sha": self.sha, "event": "workflow_dispatch",
                    "path": ".github/workflows/sefaria-embedded-validation.yml", "updated_at": "2026-11-15T11:00:00Z"}
        self.required = {"id": "phone", "device_size": "phone", "data_profile": "miniTest10", "required_ui_cases": ["Navigation/testTap"]}
        self.manifest = {"scope": "full-release-ui", "full_release_acceptance_required": True, "max_age_hours": 24,
                         "required_os_major": 27, "configurations": [self.required]}
        self.trees = {"Source": "source", "Vendor": "vendor", "Maktabah.xcodeproj": "project"}
        self.actual = {"id": "phone", "device_size": "phone", "status": "EXECUTED_PASS", "data_profile": "miniTest10",
                       "os_version": "27.0", "os_build": "24A434", "device_udid": "owned", "locale": "he_IL",
                       "orientations": ["portrait", "landscape"], "app_binary_sha256": "app", "test_binary_sha256": "test",
                       "summary_path": "summary.json", "tests_path": "tests.json", "log_path": "test.log", "data_evidence_path": "data.json"}
        self.result = {"status": "EXECUTED_PASS", "checkout_sha": self.sha, "full_release_acceptance": True,
                       "release_manifest_sha256": "manifest", "scope": "full-release-ui", "configurations": [self.actual]}
        self.build = {"status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "checkout_sha": self.sha, "application_trees": self.trees,
                      "actual_source_inputs_verified": 750, "actual_package_checkouts": {str(i): {"head": str(i), "status": "CLEAN"} for i in range(6)},
                      "package_pins": {str(i): str(i) for i in range(6)}}
        self.summary = {"result": "Passed", "totalTestCount": 1, "passedTests": 1, "failedTests": 0, "skippedTests": 0,
                        "expectedFailures": 0, "testFailures": []}
        self.tree = {"devices": [{"deviceId": "owned", "osVersion": "27.0"}], "testNodes": [
            {"nodeType": "UI test bundle", "name": "Maktabah-iOSUITests", "children": [
                {"nodeType": "Test Suite", "name": "Navigation", "children": [
                    {"nodeType": "Test Case", "name": "testTap()", "nodeIdentifier": "Navigation/testTap()", "result": "Passed"}]}]}]}
        self.data = {"passed": True, "profileID": "miniTest10", "shaMatched": True, "expectedSHA256": "compressed",
                     "actualSHA256": "compressed", "quickCheck": "ok", "bookCount": 10}
        self.log = "Test Case '-[Navigation testTap]' passed (1 second)\nExecuted 1 test\n** TEST SUCCEEDED **"

    def check(self):
        for path, value in [("artifacts/runtime27/result.json", self.result), ("hq-stage2/result.json", self.build),
                            ("summary.json", self.summary), ("tests.json", self.tree), ("data.json", self.data)]:
            destination = self.root / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(value))
        (self.root / "test.log").write_text(self.log)
        return gate["verify"](self.run, self.root, self.sha, self.manifest, "manifest", self.trees, self.now)

    def test_complete_positive_fixture(self):
        self.assertEqual(self.check()["required_ui_passed"], 1)

    def test_reject_stale_failed_partial_and_missing_evidence(self):
        variants = [
            ("run", "head_sha", "b" * 40), ("run", "conclusion", "failure"), ("run", "status", "in_progress"),
            ("run", "updated_at", "2026-11-13T11:00:00Z"), ("run", "updated_at", "2026-11-16T11:00:00Z"),
            ("run", "event", "push"), ("run", "path", ".github/workflows/ios-build.yml"),
            ("result", "full_release_acceptance", False), ("result", "scope", "focused-ui"),
            ("result", "release_manifest_sha256", None), ("result", "configurations", []),
            ("actual", "os_version", "26.0"), ("actual", "device_udid", "different"),
            ("actual", "summary_path", "missing.json"), ("actual", "log_path", "../outside"),
            ("actual", "app_binary_sha256", None), ("actual", "locale", None), ("actual", "status", "FAIL"),
            ("build", "actual_package_checkouts", {}), ("build", "application_trees", {}),
            ("summary", "totalTestCount", 0), ("summary", "skippedTests", 1),
            ("data", "passed", False), ("data", "actualSHA256", "different"), ("data", "quickCheck", "corrupt"),
            ("required", "required_ui_cases", ["Navigation/testDifferent"]),
        ]
        for attribute, key, value in variants:
            with self.subTest(attribute=attribute, key=key):
                original = getattr(self, attribute).get(key)
                getattr(self, attribute)[key] = value
                with self.assertRaises((ValueError, KeyError)):
                    self.check()
                getattr(self, attribute)[key] = original

    def test_small_corpus_cannot_satisfy_production(self):
        self.required["data_profile"] = self.actual["data_profile"] = self.data["profileID"] = "production"
        with self.assertRaises(ValueError):
            self.check()

    def test_extra_unit_cases_cannot_replace_required_ui(self):
        self.tree["testNodes"][0]["nodeType"] = "Unit test bundle"
        with self.assertRaises(ValueError):
            self.check()

    def test_documentation_only_reuse_preserves_checked_sha(self):
        self.check()
        candidate = "b" * 40
        proof = {"kind": "DOCUMENTATION_ONLY_DESCENDANT", "tested_sha": self.sha, "candidate_sha": candidate,
                 "changed_paths": ["docs/hq-integration/runtime27/REPORT.md"]}
        accepted = gate["verify"](self.run, self.root, candidate, self.manifest, "manifest", self.trees, self.now, proof)
        self.assertEqual(accepted["tested_checkout_sha"], self.sha)
        self.assertEqual(accepted["checkout_sha"], candidate)
        proof["changed_paths"] = ["Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"]
        with self.assertRaises(ValueError):
            gate["verify"](self.run, self.root, candidate, self.manifest, "manifest", self.trees, self.now, proof)


class EvidenceClassificationTests(unittest.TestCase):
    def test_missing_execution_is_not_an_executed_ui_failure(self):
        original = collect.__globals__["OUT"]
        try:
            with tempfile.TemporaryDirectory() as folder:
                collect.__globals__["OUT"] = Path(folder)
                contract = {"cases": [{"device": "ipad11", "case_id": "Native/testTap", "oracle": "actual post-tap state"}]}
                report = {}
                collect(report, contract)
                self.assertEqual(report["executed_ui_pass"], 0)
                self.assertEqual(report["executed_ui_fail"], 0)
                self.assertEqual(report["ui_not_run"], 1)
                junit = ET.parse(Path(folder) / "junit.xml").getroot()
                self.assertEqual(junit.attrib["failures"], "0")
                self.assertEqual(junit.attrib["errors"], "1")
        finally:
            collect.__globals__["OUT"] = original

    def test_only_named_actual_results_count(self):
        original = collect.__globals__["OUT"]
        try:
            with tempfile.TemporaryDirectory() as folder:
                folder = Path(folder)
                collect.__globals__["OUT"] = folder
                (folder / "verified-11.tests.json").write_text(json.dumps({"testNodes": [
                    {"nodeType": "Test Suite", "name": "Native", "children": [
                        {"nodeType": "Test Case", "name": "testTap()", "nodeIdentifier": "Native/testTap()", "result": "Failed"},
                        {"nodeType": "Test Case", "name": "testOther()", "nodeIdentifier": "Native/testOther()", "result": "Passed"}]}]}))
                contract = {"cases": [{"device": "ipad11", "case_id": "Native/testTap", "oracle": "actual post-tap state"},
                                      {"device": "iphone", "case_id": "Phone/testTap", "oracle": "actual phone action"}]}
                report = {}
                collect(report, contract)
                self.assertEqual((report["executed_ui_pass"], report["executed_ui_fail"], report["ui_not_run"]), (0, 1, 1))
        finally:
            collect.__globals__["OUT"] = original


if __name__ == "__main__":
    unittest.main(verbosity=2)
