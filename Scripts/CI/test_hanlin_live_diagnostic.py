"""Strict admission and actual Git continuation controls; not native acceptance."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
MODULE = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-hanlin-live.py"))
VALIDATE = MODULE["validate_connection_diagnostic"]
BIND = MODULE["bind_original_build"]
RUNNER = "Scripts/CI/runtime27-hanlin-live.py"
TEST = "Scripts/CI/test_hanlin_live_diagnostic.py"


def packet(events):
    return json.dumps({"schemaVersion": 1, "overflow": False,
                       "events": [{"sequence": 1, "stage": "inputConsumed",
                                   "reason": "none", "flags": {}}, *events]}).encode()


class DiagnosticAdmission(unittest.TestCase):
    def test_exact_original_swift_enum_coverage(self):
        source = (ROOT / "Source/ChavrusaText/HanlinHostAdapter/OtzariaHanlinChatSession.swift").read_text()
        for enum, field in [("Stage", "STAGES"), ("Reason", "REASONS"), ("Flag", "FLAGS")]:
            body = re.search(r"    enum " + enum + r": String \{(.*?)\n    \}", source, re.S).group(1)
            values = {item.strip() for line in body.splitlines()
                      if line.strip().startswith("case ")
                      for item in line.strip()[5:].split(",")}
            self.assertEqual(MODULE["CONNECTION_DIAGNOSTIC_" + field], values)

    def test_actual_stream_and_failure_observations_are_admitted(self):
        data = packet([
            {"sequence": 2, "stage": "streamStepStarted", "reason": "none",
             "flags": {"hasActiveTools": True, "searchAdvertised": True,
                       "referenceAdvertised": True, "hasVisibleSchemas": True}},
            {"sequence": 3, "stage": "runCompletionObserved", "reason": "emptyProviderResponse",
             "flags": {"matchingSession": True, "completionSucceeded": False,
                       "completionCancelled": False, "completionFailed": True}},
            {"sequence": 4, "stage": "sendSettled", "reason": "none",
             "flags": {"hasSources": False, "hasActivities": False,
                       "hasAssistantText": False, "hasReasoning": False}},
        ])
        self.assertEqual(len(VALIDATE(data)["events"]), 4)

    def test_free_text_and_nonboolean_payloads_still_refused(self):
        original = {"sequence": 2, "stage": "streamFailed",
                    "reason": "otherError", "flags": {"hasSources": False}}
        for change in [
            {"stage": "provider raw response"}, {"reason": "credential=value"},
            {"flags": {"hasSources": "false"}}, {"flags": {"rawPayload": True}},
        ]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                VALIDATE(packet([{**original, **change}]))

    def test_duplicate_keys_bounds_and_input_reuse_still_refused(self):
        malformed = [
            b'{"schemaVersion":1,"schemaVersion":1,"overflow":false,"events":[]}',
            packet([{"sequence": 2, "stage": "inputConsumed", "reason": "none", "flags": {}}]),
            packet([{"sequence": 3, "stage": "streamOpened", "reason": "none", "flags": {}}]),
            b" " * 65537,
        ]
        for raw in malformed:
            with self.subTest(size=len(raw)), self.assertRaises(ValueError):
                VALIDATE(raw)


class RetainedBuildAdmission(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.environment = {"GIT_AUTHOR_NAME": "Admission control",
                            "GIT_AUTHOR_EMAIL": "control@example.invalid",
                            "GIT_COMMITTER_NAME": "Admission control",
                            "GIT_COMMITTER_EMAIL": "control@example.invalid"}
        self.git("init", "-q")
        for name, value in [(RUNNER, "original runner"), ("Source/app.swift", "original app")]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(value)
        self.git("add", ".")
        self.git("commit", "-qm", "original native source")
        self.base = self.git("rev-parse", "HEAD")
        self.prior = {"checkout_sha": self.base, "reviewed_source_sha": "original",
                      "application_source_sha": "original", "application_trees": {"Source": "tree"},
                      "original_build_status": "SIMULATOR_BUILD_FOR_REAL_UI_PASS",
                      "original_build_receipt_sha256": "unchanged original build receipt",
                      "qualified_sdk_route": {"sdk_source_sha": "qualified SDK", "admission_sha256": "admitted distribution"},
                      "generated_project_sha256": "project", "workspace_sha256": "workspace",
                      "execution_inputs": {RUNNER: {"sha256": "prior"}, "tools/guard.py": {"sha256": "retained"}},
                      "binaries": {"Maktabah.app/Maktabah.debug.dylib": "unchanged image"}}
        (self.root / RUNNER).write_text("reviewed collector")
        self.git("add", ".")
        self.git("commit", "-qm", "bounded collector correction")
        self.head = self.git("rev-parse", "HEAD")
        self.current = copy.deepcopy(self.prior)
        self.current["checkout_sha"] = self.head
        self.current["execution_inputs"][RUNNER] = {"sha256": "current"}
        self.proof = self.root / "build/prior-source.json"
        self.proof.parent.mkdir()
        self.proof.write_text(json.dumps(self.prior))
        self.env = {"OTZARIA_HANLIN_RETAINED_SOURCE": "build/prior-source.json",
                    "OTZARIA_HANLIN_RETAINED_SOURCE_SHA256": hashlib.sha256(self.proof.read_bytes()).hexdigest()}
        self.previous_root = BIND.__globals__["ROOT"]
        BIND.__globals__["ROOT"] = self.root

    def tearDown(self):
        BIND.__globals__["ROOT"] = self.previous_root
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, env={**os.environ, **self.environment},
                                       stderr=subprocess.PIPE, text=True).strip()

    def call(self, context=None):
        with patch.dict(os.environ, self.env):
            return BIND(context or self.current, {"checkout_sha": self.base})

    def test_real_git_ci_only_delta_preserves_original_build_identity(self):
        result = self.call()
        self.assertEqual(result["original_build_checkout_sha"], self.base)
        self.assertEqual(result["harness_only_delta"], [RUNNER])
        self.assertTrue(result["native_build_reused"])
        self.assertNotEqual(self.current["checkout_sha"], result["original_build_checkout_sha"])

    def test_real_git_product_delta_refused(self):
        (self.root / "Source/app.swift").write_text("changed app")
        self.git("add", ".")
        self.git("commit", "-qm", "unqualified app delta")
        self.current["checkout_sha"] = self.git("rev-parse", "HEAD")
        with self.assertRaisesRegex(ValueError, "non-harness"):
            self.call()

    def test_changed_debug_image_or_unrelated_execution_input_refused(self):
        for field in ["binaries", "execution_inputs"]:
            current = copy.deepcopy(self.current)
            name = "Maktabah.app/Maktabah.debug.dylib" if field == "binaries" else "tools/guard.py"
            current[field][name] = "tampered"
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.call(current)

    def test_retained_sdk_admission_and_build_receipt_must_be_identical(self):
        for field in ["qualified_sdk_route", "original_build_receipt_sha256"]:
            current = copy.deepcopy(self.current)
            current[field] = "another SDK admission or build receipt"
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "Retained native source or image differs"):
                self.call(current)

    def test_changed_proof_or_missing_explicit_binding_refused(self):
        self.proof.write_text(self.proof.read_text() + " ")
        with self.assertRaisesRegex(ValueError, "proof changed"):
            self.call()
        with patch.dict(os.environ, {"OTZARIA_HANLIN_RETAINED_SOURCE": "",
                                     "OTZARIA_HANLIN_RETAINED_SOURCE_SHA256": ""}):
            with self.assertRaisesRegex(ValueError, "explicit immutable"):
                BIND(self.current, {"checkout_sha": self.base})


if __name__ == "__main__":
    unittest.main()
