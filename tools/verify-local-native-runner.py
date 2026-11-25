#!/usr/bin/env python3
"""Portable checks for local-run ownership and transferred artifact integrity."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LIVE = runpy.run_path(str(ROOT / "Scripts/CI/runtime27-hanlin-live.py"))
BUILD = runpy.run_path(str(ROOT / "Scripts/CI/hq-stage2-focused-apple.py"))
RUN = "c7e05dea-3663-4426-a176-385d601ff867"


class LocalNativeRunnerControls(unittest.TestCase):
    def test_real_github_identity_is_preserved(self):
        with patch.dict(os.environ, {"GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "2"}, clear=True):
            self.assertEqual(LIVE["execution_identity"](), {
                "run_id": "123", "run_attempt": "2", "execution_environment": "github-actions"})

    def test_local_identity_is_never_a_github_run(self):
        with patch.dict(os.environ, {"OTZARIA_LOCAL_RUN_ID": RUN}, clear=True), \
                patch("platform.system", return_value="Darwin"), patch("platform.node", return_value="owned-mac"):
            identity = LIVE["execution_identity"]()
            self.assertEqual(identity["run_id"], "local-" + RUN)
            self.assertEqual(identity["execution_environment"], "dedicated-mac")
            self.assertEqual(identity["host"], "owned-mac")
            LIVE["verify_execution_owner"](identity)

    def test_ambiguous_identity_is_rejected(self):
        with patch.dict(os.environ, {"OTZARIA_LOCAL_RUN_ID": RUN, "GITHUB_RUN_ID": "123"}, clear=True):
            with self.assertRaises(ValueError):
                LIVE["execution_identity"]()

    def test_missing_and_invalid_identity_are_rejected(self):
        for value in (None, "123", "not-a-run"):
            environment = {} if value is None else {"OTZARIA_LOCAL_RUN_ID": value}
            with self.subTest(value=value), patch.dict(os.environ, environment, clear=True), \
                    patch("platform.system", return_value="Darwin"):
                with self.assertRaises(ValueError):
                    LIVE["execution_identity"]()

    def test_non_apple_local_execution_is_rejected(self):
        with patch.dict(os.environ, {"OTZARIA_LOCAL_RUN_ID": RUN}, clear=True), \
                patch("platform.system", return_value="Linux"):
            with self.assertRaises(ValueError):
                LIVE["execution_identity"]()

    def test_other_run_host_and_attempt_cannot_clean_up(self):
        with patch.dict(os.environ, {"OTZARIA_LOCAL_RUN_ID": RUN}, clear=True), \
                patch("platform.system", return_value="Darwin"), patch("platform.node", return_value="owned-mac"):
            identity = LIVE["execution_identity"]()
            for key, value in [("run_id", "local-00000000-0000-0000-0000-000000000000"),
                               ("host", "other-mac"), ("run_attempt", "2"),
                               ("execution_environment", "github-actions")]:
                with self.subTest(field=key), self.assertRaises(ValueError):
                    LIVE["verify_execution_owner"]({**identity, key: value})

    def test_original_direct_download_route_remains_default(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertIsNone(BUILD["staged_input"]("artifact.zip"))

    def test_staged_bytes_and_manifest_are_both_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = root / "artifact.zip"
            payload.write_bytes(b"original immutable artifact")
            manifest = {"schema_version": 1, "repository": "davidpovarsky/Maktabah", "files": {
                payload.name: {"bytes": payload.stat().st_size,
                               "sha256": hashlib.sha256(payload.read_bytes()).hexdigest()}}}
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            with patch.dict(os.environ, {"OTZARIA_STAGED_INPUTS": directory}, clear=True):
                self.assertEqual(BUILD["staged_input"](payload.name), payload)
                original = payload.read_bytes()
                payload.write_bytes(b"changed immutable artifact!")
                with self.assertRaises(RuntimeError):
                    BUILD["staged_input"](payload.name)
                payload.write_bytes(original)
                manifest["repository"] = "different/repository"
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(RuntimeError):
                    BUILD["staged_input"](payload.name)

    def test_unlisted_and_redirected_inputs_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "manifest.json").write_text(json.dumps({"schema_version": 1,
                "repository": "davidpovarsky/Maktabah", "files": {}}))
            (root / "unlisted.zip").write_bytes(b"unlisted")
            (root / "redirect.zip").symlink_to(root / "unlisted.zip")
            with patch.dict(os.environ, {"OTZARIA_STAGED_INPUTS": directory}, clear=True):
                for name in ["unlisted.zip", "redirect.zip", "../outside.zip"]:
                    with self.subTest(name=name), self.assertRaises(RuntimeError):
                        BUILD["staged_input"](name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
