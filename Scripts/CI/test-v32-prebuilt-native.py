#!/usr/bin/env python3
"""Synthetic negative controls for the v32 evidence wrapper; no native pass."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("v32_gate", ROOT / "Scripts/CI/hq-v32-prebuilt-native.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class EvidenceControls(unittest.TestCase):
    def fixture(self):
        common = dict(passed=True, artifactIdentity=gate.IDENTITY, documentCount=7080797,
                      sourceCount=7876, stagingAbsent=True, localIndexingRan=False,
                      productionDiscoveryRan=True, productionValidatorRan=True,
                      selectedReleaseTag=gate.TAG,
                      checks=[dict(mode=mode, query="משה", count=20, firstFilePath="otzaria-book:1")
                              for mode in ["exact", "fuzzy", "advanced"]],
                      golden=dict(query=gate.GOLDEN_QUERY, normalizedQuery="controlled query",
                                  orderedResultIDs=[101, 102], stableSourceIDs=["otzaria-book:1"] * 2,
                                  references=["reference one", "reference two"], highlightedTopResults=2))
        install = copy.deepcopy(common) | dict(phase="install", nativeDownloadRan=True, resumedDownloadBytes=1048576)
        reopen = copy.deepcopy(common) | dict(phase="reopen", nativeDownloadRan=False, resumedDownloadBytes=0)
        log = "Captured prebuilt install PID: 123\nCaptured prebuilt reopen PID: 456\n"
        return install, reopen, log

    def reject(self, change):
        install, reopen, log = self.fixture()
        changed_log = change(install, reopen, log)
        with self.assertRaises(RuntimeError):
            gate.validate_reports(install, reopen, log if changed_log is None else changed_log)

    def test_controlled_complete_report_is_accepted(self):
        self.assertTrue(gate.validate_reports(*self.fixture())["golden_result_identities_equal_after_restart"])

    def test_report_failure_is_not_promoted(self):
        self.reject(lambda a, b, log: b.update(passed=False))

    def test_wrong_artifact_is_rejected(self):
        self.reject(lambda a, b, log: b.update(artifactIdentity="another artifact"))

    def test_partial_corpus_is_rejected(self):
        self.reject(lambda a, b, log: b.update(sourceCount=10))

    def test_missing_native_resume_is_rejected(self):
        self.reject(lambda a, b, log: a.update(nativeDownloadRan=False, resumedDownloadBytes=0))

    def test_reopen_download_is_rejected(self):
        self.reject(lambda a, b, log: b.update(nativeDownloadRan=True))

    def test_reindex_on_reopen_is_rejected(self):
        self.reject(lambda a, b, log: b.update(localIndexingRan=True))

    def test_skipped_original_validator_is_rejected(self):
        self.reject(lambda a, b, log: b.update(productionValidatorRan=False))

    def test_same_process_is_not_a_restart(self):
        self.reject(lambda a, b, log: log.replace("456", "123"))

    def test_changed_order_after_restart_is_rejected(self):
        self.reject(lambda a, b, log: b["golden"].update(orderedResultIDs=[102, 101]))

    def test_missing_query_mode_is_rejected(self):
        self.reject(lambda a, b, log: b["checks"].pop())

    def test_exact_real_manifest_passes_and_modified_bytes_fail(self):
        raw = (ROOT / "docs/hq-integration/full-v32-native-20261119/otzaria-search-manifest.json").read_bytes()
        self.assertEqual(gate.exact_manifest(raw)["artifactIdentity"], gate.IDENTITY)
        with self.assertRaises(RuntimeError):
            gate.exact_manifest(raw + b"\n")

    def selection(self, requested):
        text = (ROOT / "Scripts/run-otzaria-prebuilt-acceptance.sh").read_text()
        source = text.split("python3 <<'PY'\n", 1)[1].split("\nPY\n", 1)[0]
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        responses = [
            json.dumps({"runtimes": [{"identifier": runtime, "version": "27.2", "isAvailable": True}]}),
            json.dumps({"devices": {runtime: [{"name": "owned iPad", "isAvailable": True, "udid": "owned-id"},
                                              {"name": "existing device", "isAvailable": True, "udid": "existing-id"}]}})
        ]
        output = io.StringIO()
        with patch.dict(os.environ, {"OTZARIA_PREBUILT_SIMULATOR_UDID": requested}), \
             patch("subprocess.check_output", side_effect=responses), redirect_stdout(output):
            with self.assertRaises(SystemExit) as stopped:
                exec(compile(source, "<original simulator selector>", "exec"), {})
        return stopped.exception.code, output.getvalue().strip()

    def test_explicit_owned_simulator_is_used(self):
        self.assertEqual(self.selection("owned-id"), (0, "owned-id"))

    def test_unavailable_owned_simulator_cannot_fall_back(self):
        code, output = self.selection("unavailable-id")
        self.assertNotEqual(code, 0)
        self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
