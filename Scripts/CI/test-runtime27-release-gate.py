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
import hashlib
import subprocess
import io
import os
import sys
import zipfile
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch

gate = runpy.run_path(str(Path(__file__).with_name("verify-runtime27-release-gate.py")))
collect = runpy.run_path(str(Path(__file__).with_name("runtime27.py")))["collect_cases"]
groups = runpy.run_path(str(Path(__file__).with_name("runtime27.py")))["execution_groups"]


def dependency_fixture():
    # Deliberately synthetic evidence for gate mutation tests, never Native PASS.
    return {"package_pins": {"fixture-" + str(i): format(i, "040x") for i in range(9)},
            "package_resolved_sha256": "fixture-lock",
            "hanlin_sdk_source": {"sha": "c" * 40, "verified_files": 1,
                                  "git_blobs": {"fixture-only.swift": "d" * 40},
                                  "manifest_sha256": {"fixture-only-package": "e" * 64}}}


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
        self.required_inputs = dependency_fixture()
        self.sdk_before = copy.deepcopy(self.required_inputs["hanlin_sdk_source"])
        self.sdk_after = copy.deepcopy(self.sdk_before)
        self.build = {"status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS", "checkout_sha": self.sha, "application_trees": self.trees,
                      "actual_source_inputs_verified": 750,
                      "actual_package_checkouts": {name: {"head": revision, "status": "CLEAN"} for name, revision in self.required_inputs["package_pins"].items()},
                      "package_pins": copy.deepcopy(self.required_inputs["package_pins"]),
                      "package_resolved_sha256": self.required_inputs["package_resolved_sha256"],
                      "hanlin_gitlink": self.sdk_before["sha"], "hanlin_sdk_source": copy.deepcopy(self.sdk_before)}
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
                            ("hq-stage2/hanlin-sdk-inputs.json", self.sdk_before), ("hq-stage2/hanlin-sdk-inputs-after.json", self.sdk_after),
                            ("summary.json", self.summary), ("tests.json", self.tree), ("data.json", self.data)]:
            destination = self.root / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(value))
        (self.root / "test.log").write_text(self.log)
        return gate["verify"](self.run, self.root, self.sha, self.manifest, "manifest", self.trees, self.now, required_inputs=self.required_inputs)

    def test_complete_positive_fixture(self):
        self.assertEqual(self.check()["required_ui_passed"], 1)

    def test_same_count_self_consistent_foreign_revision_is_rejected(self):
        self.build["package_pins"]["fixture-0"] = "f" * 40
        self.build["actual_package_checkouts"]["fixture-0"]["head"] = "f" * 40
        with self.assertRaisesRegex(ValueError, "committed lock"):
            self.check()

    def test_legacy_six_pins_cannot_replace_current_nine(self):
        for name in ["fixture-6", "fixture-7", "fixture-8"]:
            self.build["package_pins"].pop(name)
            self.build["actual_package_checkouts"].pop(name)
        with self.assertRaisesRegex(ValueError, "committed lock"):
            self.check()

    def test_extra_checkout_and_missing_checkout_are_rejected(self):
        original = copy.deepcopy(self.build["actual_package_checkouts"])
        self.build["actual_package_checkouts"]["foreign"] = {"head": "f" * 40, "status": "CLEAN"}
        with self.assertRaisesRegex(ValueError, "unexpected actual"):
            self.check()
        self.build["actual_package_checkouts"] = original
        self.build["actual_package_checkouts"].pop("fixture-8")
        with self.assertRaisesRegex(ValueError, "unexpected actual"):
            self.check()

    def test_sdk_revision_source_and_post_build_drift_are_rejected(self):
        for attribute, field, replacement in [
            ("sdk_before", "sha", "f" * 40),
            ("sdk_after", "git_blobs", {}),
            ("sdk_after", "manifest_sha256", {}),
        ]:
            with self.subTest(attribute=attribute, field=field):
                target = getattr(self, attribute)
                previous = target[field]
                target[field] = replacement
                with self.assertRaisesRegex(ValueError, "SDK source proof"):
                    self.check()
                target[field] = previous
        self.build["hanlin_sdk_source"]["sha"] = "f" * 40
        with self.assertRaisesRegex(ValueError, "Hanlin source"):
            self.check()

    def test_unaccepted_lock_bytes_and_sdk_gitlink_are_rejected(self):
        for key, value in [("package_resolved_sha256", "foreign"), ("hanlin_gitlink", "f" * 40)]:
            with self.subTest(key=key):
                previous = self.build[key]
                self.build[key] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.build[key] = previous

    def test_prototype_oracle_never_inflates_native_ui_count(self):
        self.required["required_oracle_cases"] = ["Prototype/testTap"]
        self.summary.update(totalTestCount=2, passedTests=2)
        self.tree["testNodes"][0]["children"].append({"nodeType": "Test Suite", "name": "Prototype", "children": [
            {"nodeType": "Test Case", "name": "testTap()", "nodeIdentifier": "Prototype/testTap()", "result": "Passed"}]})
        self.log = self.log.replace("Executed 1 test", "Executed 2 tests") + "\nTest Case '-[Prototype testTap]' passed (1 second)"
        result = self.check()
        self.assertEqual(result["required_ui_passed"], 1)
        self.assertEqual(result["separate_oracle_executed"], 1)

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
        accepted = gate["verify"](self.run, self.root, candidate, self.manifest, "manifest", self.trees, self.now, proof, required_inputs=self.required_inputs)
        self.assertEqual(accepted["tested_checkout_sha"], self.sha)
        self.assertEqual(accepted["checkout_sha"], candidate)
        proof["changed_paths"] = ["Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"]
        with self.assertRaises(ValueError):
            gate["verify"](self.run, self.root, candidate, self.manifest, "manifest", self.trees, self.now, proof, required_inputs=self.required_inputs)


class FinalPushGateTests(unittest.TestCase):
    """Synthetic false-green mutations of the real push admission contract."""
    def setUp(self):
        ReleaseGateTests.setUp(self)
        self.final_push = gate["verify_final_push_receipts"].__globals__["FINAL_PUSH"]
        self.authority = self.final_push["authority"]("release")
        repository = {"id": 1280062128, "full_name": "davidpovarsky/Maktabah"}
        self.run.update(event="push", path=self.authority["workflow"],
                        head_branch=self.authority["ref"].removeprefix("refs/heads/"),
                        id=42, run_attempt=1, repository=repository, head_repository=copy.deepcopy(repository))
        self.observed = {"application_source_sha": self.sha,
                         "application_trees": {**self.trees, "Maktabah-iOSUITests": "tests"},
                         "source_pins": [{"path": "Scripts/CI/runtime27-release-manifest.json", "sha256": "manifest"}],
                         "binding": {"sha256": "synthetic-finalized-binding"},
                         "inputs": [{"path": "synthetic-original-source", "sha256": "synthetic-bytes"}]}
        source = {**copy.deepcopy(self.observed), "authority": self.authority,
                  "checkout_sha": self.sha, "run_id": 42, "run_attempt": 1}
        self.before = {"status": "FINAL_PUSH_SOURCE_BOUND", "mode": "release", "stage": "production",
                       "phase": "before", "source": source}
        self.after = {**copy.deepcopy(self.before), "status": "FINAL_PUSH_SOURCE_UNCHANGED", "phase": "after"}
        self.candidate_head = self.sha

    def check(self):
        folder = self.root / "artifacts/runtime27"
        folder.mkdir(parents=True, exist_ok=True)
        for phase, receipt in [("before", self.before), ("after", self.after)]:
            (folder / ("final-push-production." + phase + ".json")).write_text(json.dumps(receipt))
        # Only the local source inventory is a fixture. Real authority checks,
        # before/after binding, final gate and every raw UI/data check execute.
        with patch.dict(self.final_push, git=lambda *args: self.candidate_head,
                        reviewed_source=lambda *args: self.observed):
            return ReleaseGateTests.check(self)

    def test_completed_original_push_with_exact_receipts_reaches_full_ui_gate(self):
        self.assertEqual(self.check()["required_ui_passed"], 1)

    def test_foreign_repository_branch_workflow_or_attempt_is_rejected(self):
        for key, replacement in [
            ("repository", {"id": 1, "full_name": "foreign/Maktabah"}),
            ("head_repository", {"id": 1280062128, "full_name": "foreign/Maktabah"}),
            ("head_branch", "codex/otzaria-final-native116-20261120"),
            ("path", ".github/workflows/otzaria-final-native-push.yml"),
            ("id", 43), ("run_attempt", 2),
        ]:
            with self.subTest(key=key):
                original = self.run[key]
                self.run[key] = replacement
                with self.assertRaises(ValueError):
                    self.check()
                self.run[key] = original

    def test_missing_failed_wrong_stage_and_drifted_receipts_are_rejected(self):
        for target, key, replacement in [
            ("before", "status", "FINAL_PUSH_SOURCE_REJECTED"),
            ("after", "status", "FINAL_PUSH_SOURCE_BOUND"),
            ("before", "stage", "native"), ("after", "mode", "ui"),
            ("after", "phase", "before"), ("after", "source", {}),
        ]:
            with self.subTest(target=target, key=key):
                receipt = getattr(self, target)
                original = receipt[key]
                receipt[key] = replacement
                with self.assertRaises(ValueError):
                    self.check()
                receipt[key] = original

    def test_self_consistent_receipts_for_different_candidate_inputs_are_rejected(self):
        self.before["source"]["binding"]["sha256"] = "foreign"
        self.after["source"]["binding"]["sha256"] = "foreign"
        with self.assertRaisesRegex(ValueError, "candidate inputs differ"):
            self.check()

    def test_self_consistent_foreign_authority_and_checkout_are_rejected(self):
        for key, value in [("authority", {}), ("checkout_sha", "b" * 40)]:
            with self.subTest(key=key):
                original = copy.deepcopy(self.before["source"][key])
                self.before["source"][key] = self.after["source"][key] = value
                with self.assertRaisesRegex(ValueError, "authority or checkout"):
                    self.check()
                self.before["source"][key] = self.after["source"][key] = original

    def test_original_full_ui_data_and_age_requirements_still_apply_to_push(self):
        for target, key, replacement in [
            ("result", "full_release_acceptance", False),
            ("summary", "skippedTests", 1), ("data", "actualSHA256", "foreign"),
            ("run", "updated_at", "2026-11-13T11:00:00Z"),
            ("run", "conclusion", "failure"),
        ]:
            with self.subTest(target=target, key=key):
                record = getattr(self, target)
                original = record[key]
                record[key] = replacement
                with self.assertRaises(ValueError):
                    self.check()
                record[key] = original

    def test_source_audit_failure_is_not_caught_as_pass(self):
        self.check()
        with patch.dict(self.final_push, git=lambda *args: self.sha,
                        reviewed_source=lambda *args: (_ for _ in ()).throw(ValueError("dirty input"))):
            with self.assertRaisesRegex(ValueError, "dirty input"):
                gate["verify"](self.run, self.root, self.sha, self.manifest, "manifest", self.trees,
                               self.now, required_inputs=self.required_inputs)

    def test_documentation_descendant_retains_tested_push_sha_only_with_same_inputs(self):
        self.check()
        candidate = "b" * 40
        proof = {"kind": "DOCUMENTATION_ONLY_DESCENDANT", "tested_sha": self.sha,
                 "candidate_sha": candidate, "changed_paths": ["docs/hq-integration/REPORT.md"]}
        with patch.dict(self.final_push, git=lambda *args: candidate,
                        reviewed_source=lambda *args: self.observed):
            result = gate["verify"](self.run, self.root, candidate, self.manifest, "manifest", self.trees,
                                   self.now, proof, required_inputs=self.required_inputs)
        self.assertEqual(result["tested_checkout_sha"], self.sha)
        self.assertEqual(result["checkout_sha"], candidate)


class EvidenceClassificationTests(unittest.TestCase):
    def test_skipped_and_expected_failure_never_become_ui_passes(self):
        original = collect.__globals__["OUT"]
        try:
            with tempfile.TemporaryDirectory() as folder:
                folder = Path(folder)
                collect.__globals__["OUT"] = folder
                contract = {"cases": [{"device": "ipad11", "case_id": "Native/testTap", "oracle": "real required action"}]}
                for status, expected in [("Skipped", (0, 0, 1)), ("Expected Failure", (0, 1, 0))]:
                    (folder / "verified-11.tests.json").write_text(json.dumps({"testNodes": [
                        {"nodeType": "Test Suite", "name": "Native", "children": [
                            {"nodeType": "Test Case", "name": "testTap()", "nodeIdentifier": "Native/testTap()", "result": status}]}]}))
                    report = {}
                    collect(report, contract)
                    self.assertEqual((report["executed_ui_pass"], report["executed_ui_fail"], report["ui_not_run"]), expected)
        finally:
            collect.__globals__["OUT"] = original


class AffectedExecutionTests(unittest.TestCase):
    def setUp(self):
        self.contract = {"cases": [
            {"case_id": "Pad/testReader", "device": "ipad11", "oracle": "actual reader state"},
            {"case_id": "Pad/testWindow", "device": "ipad11", "oracle": "actual window restore"},
            {"case_id": "Phone/testRestore", "device": "iphone", "oracle": "actual persisted state"}],
            "execution_case_ids": ["Pad/testReader", "Pad/testWindow"],
            "execution_groups": [{"label": "11-reader", "size": "11", "case_ids": ["Pad/testReader"]},
                                 {"label": "11-window", "size": "11", "case_ids": ["Pad/testWindow"]}]}

    def test_fresh_isolation_exactly_partitions_affected_cases(self):
        self.assertEqual([row["label"] for row in groups(self.contract)], ["11-reader", "11-window"])

    def test_empty_duplicate_unknown_wrong_device_scopes_rejected(self):
        for selected in [[], ["Pad/testReader"] * 2, ["Pad/testAbsent"]]:
            with self.subTest(selected=selected), self.assertRaises(ValueError):
                groups({**self.contract, "execution_case_ids": selected})
        bad = copy.deepcopy(self.contract)
        bad["execution_groups"][1]["label"] = "11-reader"
        with self.assertRaises(ValueError):
            groups(bad)
        bad = copy.deepcopy(self.contract)
        bad["execution_groups"][1]["size"] = "phone"
        bad["execution_groups"][1]["label"] = "phone"
        with self.assertRaises(ValueError):
            groups(bad)

    def test_nonrequested_prior_pass_is_not_reported_as_new_or_not_run(self):
        original = collect.__globals__["OUT"]
        try:
            with tempfile.TemporaryDirectory() as folder:
                collect.__globals__["OUT"] = Path(folder)
                report = {}
                collect(report, self.contract)
                self.assertEqual(report["ui_not_run"], 2)
                self.assertEqual(len(report["case_outcomes"]), 2)
                self.assertNotIn("Phone/testRestore", [row["case_id"] for row in report["case_outcomes"]])
        finally:
            collect.__globals__["OUT"] = original

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

    def test_supplemental_navigation_cases_preserve_original_phase_and_not_run(self):
        contract = copy.deepcopy(self.contract)
        original_cases = copy.deepcopy(contract['cases'])
        extra = {'case_id':'NativeRoutingAcceptanceTests/testActualHistoryURL', 'device':'ipad11', 'oracle':'visible History plus exact actual canonical receipt'}
        contract['supplemental_cases'] = [extra]
        contract['execution_case_ids'].append(extra['case_id'])
        contract['execution_groups'][0]['case_ids'].append(extra['case_id'])
        self.assertEqual(len(groups(contract)[0]['case_ids']), 2)
        original = collect.__globals__['OUT']
        try:
            with tempfile.TemporaryDirectory() as folder:
                collect.__globals__['OUT'] = Path(folder)
                report = {}
                collect(report, contract)
                self.assertEqual(report['ui_not_run'], 3)
                self.assertEqual(report['executed_ui_pass'], 0)
                self.assertIn(extra['case_id'], [row['case_id'] for row in report['case_outcomes']])
                self.assertEqual(contract['cases'], original_cases)
        finally:
            collect.__globals__['OUT'] = original
        contract['supplemental_cases'].append(copy.deepcopy(contract['cases'][0]))
        with self.assertRaises(ValueError):
            groups(contract)


class PreparedInputTests(unittest.TestCase):
    """Dependency drift must block before signing; tool responses are fixtures."""
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.function = gate["verify_prepared_inputs"]
        self.old_root = self.function.__globals__["ROOT"]
        self.function.__globals__["ROOT"] = self.root
        self.addCleanup(lambda: self.function.__globals__.update(ROOT=self.old_root))
        files = {"Podfile": b"pod source", "Podfile.lock": b"approved resolved pods", "Vendor/SefariaMobile/Upstream/package-lock.json": b"pinned npm",
                 "Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved": b"pinned swift",
                 "Source/PrivacyInfo.xcprivacy": b"approved generated privacy", "Pods/ExpoModulesProvider.swift": b"approved generated expo"}
        self.hashes = {}
        for name, value in files.items():
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(value)
            self.hashes[name] = hashlib.sha256(value).hexdigest()
        self.sha = "a" * 40
        native = {"podfile_sha256": self.hashes["Podfile"], "pod_lock_sha256": self.hashes["Podfile.lock"],
                  "npm_lock_sha256": self.hashes["Vendor/SefariaMobile/Upstream/package-lock.json"],
                  "gitlink": "pinned-gitlink", "node": "v22.23.4", "cocoapods": "1.17.0",
                  "generated_expo_providers": [{"path": "Pods/ExpoModulesProvider.swift", "sha256": self.hashes["Pods/ExpoModulesProvider.swift"]}]}
        self.dependencies = dependency_fixture()
        self.actual_dependencies = copy.deepcopy(self.dependencies)
        self.approval = self.root / "approval.json"
        self.approval.write_text(json.dumps({"candidate_sha": self.sha, "tested_sha": self.sha, "tested_build_report": {
            "native_context": native, "package_resolved_sha256": self.hashes["Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"],
            "package_pins": self.dependencies["package_pins"], "hanlin_sdk_source": self.dependencies["hanlin_sdk_source"],
            "xcode": "Xcode 27.1", "generated_configuration": [{"path": "Source/PrivacyInfo.xcprivacy", "compiled_sha256": self.hashes["Source/PrivacyInfo.xcprivacy"]}]}}))
        self.pod_version = "1.17.0"

    def check(self):
        def command(args, **kwargs):
            if args == ["git", "rev-parse", "HEAD"]:
                return self.sha
            if args[0] == "git":
                return "pinned-gitlink"
            return {"xcodebuild": "Xcode 27.1", "node": "v22.23.4", "pod": self.pod_version}[args[0]]
        def audit(report):
            report.update(actual_source_inputs_verified=750, actual_package_checkouts={})
        with patch.object(subprocess, "check_output", side_effect=command), patch.object(runpy, "run_path", return_value={"verify_actual_sources": audit}), \
             patch.dict(self.function.__globals__, candidate_dependency_requirements=lambda: self.actual_dependencies):
            return self.function(self.approval)

    def test_matching_prepared_context_reaches_existing_source_auditor(self):
        self.assertEqual(self.check()["status"], "RELEASE_UI_INPUTS_PASS")

    def test_changed_native_lock_and_provider_are_rejected(self):
        for name in ["Podfile.lock", "Pods/ExpoModulesProvider.swift", "Source/PrivacyInfo.xcprivacy"]:
            with self.subTest(name=name):
                path = self.root / name
                before = path.read_bytes()
                path.write_bytes(b"unaccepted drift")
                with self.assertRaises(ValueError):
                    self.check()
                path.write_bytes(before)

    def test_original_sdk_or_pinned_package_drift_before_signing_is_rejected(self):
        for key in ["package_pins", "hanlin_sdk_source"]:
            with self.subTest(key=key):
                before = self.actual_dependencies[key]
                self.actual_dependencies[key] = {}
                with self.assertRaisesRegex(ValueError, "original package sources"):
                    self.check()
                self.actual_dependencies[key] = before

    def test_changed_native_toolchain_rejected(self):
        self.pod_version = "1.18.0"
        with self.assertRaises(ValueError):
            self.check()

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


class GateMainFailureTests(unittest.TestCase):
    def test_post_verification_staging_error_cannot_leave_success_status(self):
        # Valid ZIP/digest and nominal core PASS, then corrupt native lock:
        # acceptance must still return nonzero and persist FAIL, never late-green.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = root / "Scripts/CI/runtime27-release-manifest.json"
            manifest.parent.mkdir(parents=True)
            manifest.write_text("{}")
            payload = io.BytesIO()
            with zipfile.ZipFile(payload, "w") as archive:
                archive.writestr("hq-stage2/result.json", json.dumps({"native_context": {"pod_lock_sha256": "wrong"}}))
                archive.writestr("hq-stage2/resolved-Podfile.lock", "actual resolved lock")
            data = payload.getvalue()
            digest = hashlib.sha256(data).hexdigest()
            sha = "a" * 40
            run = {"head_sha": sha, "conclusion": "success"}
            def api(path):
                return {"artifacts": [{"id": 1, "name": "runtime27-evidence", "expired": False,
                                       "digest": "sha256:" + digest}]} if "artifacts?" in path else run
            def download(args, **kwargs):
                kwargs["stdout"].write(data)
                return subprocess.CompletedProcess(args, 0)
            out = root / "gate.json"
            globals_ = gate["main"].__globals__
            with patch.dict(globals_, ROOT=root, api=api, candidate_dependency_requirements=lambda: {}, verify=lambda *args, **kwargs: {"status": "RELEASE_UI_GATE_PASS"}), \
                 patch.object(subprocess, "check_output", return_value=sha), patch.object(subprocess, "run", side_effect=download), \
                 patch.dict(os.environ, GITHUB_REPOSITORY="davidpovarsky/Maktabah"), \
                 patch.object(sys, "argv", ["gate", "--run", "123", "--expected-sha", sha, "--out", str(out)]), \
                 redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(gate["main"](), 1)
            self.assertEqual(json.loads(out.read_text())["status"], "FAIL")


if __name__ == "__main__":
    unittest.main(verbosity=2)
