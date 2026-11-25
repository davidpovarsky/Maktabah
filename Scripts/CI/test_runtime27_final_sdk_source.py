#!/usr/bin/env python3
"""Source-binding controls; no GitHub, native, or runtime acceptance is claimed."""
import hashlib
import subprocess
from pathlib import Path
import runpy
import unittest

ROOT = Path(__file__).resolve().parents[2]
M = runpy.run_path(str(ROOT / "Scripts/CI/runtime27_final_push.py"))
R27 = hashlib.sha256(subprocess.check_output(["git", "show", "HEAD:Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift"], cwd=ROOT)).hexdigest()
CURRENT = (ROOT / "Scripts/CI/runtime27.py").read_bytes()
ORIGINAL = M["ORIGINAL_HQ_BUILD_CALL"]
SDK = M["SDK_HQ_BUILD_CALL"]
# A memory-only fixture of the single reviewed SDK argument permits this control
# branch to be reviewed independently before merging the producer's runtime leaf.
REVIEWED = CURRENT if SDK in CURRENT else CURRENT.replace(ORIGINAL, SDK, 1)


class FinalSDKSourceControls(unittest.TestCase):
    def test_exact_sdk_argument_preserves_complete_original_driver(self):
        self.assertEqual(M["reviewed_runtime_inverse"](REVIEWED, R27), M["ORIGINAL_RUNTIME_BLOB"])

    def test_old_driver_cannot_silently_omit_original_sdk(self):
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](REVIEWED.replace(SDK, ORIGINAL, 1), R27)

    def test_another_build_target_is_not_the_reviewed_route(self):
        changed = REVIEWED.replace(SDK, SDK.replace(b"build/DerivedData", b"build/Other"), 1)
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](changed, R27)

    def test_duplicate_sdk_build_call_is_rejected(self):
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](REVIEWED + SDK, R27)

    def test_existing_timeout_cannot_change(self):
        before = b'"build-for-testing-driver.log", 4200'
        self.assertEqual(REVIEWED.count(before), 1)
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](REVIEWED.replace(before, b'"build-for-testing-driver.log", 4201', 1), R27)

    def test_source_digest_cannot_be_substituted(self):
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](REVIEWED, "0" * 64)

    def test_unreviewed_source_bytes_are_rejected(self):
        with self.assertRaises(ValueError):
            M["reviewed_runtime_inverse"](REVIEWED + b"# Unreviewed change\\n", R27)


if __name__ == "__main__":
    unittest.main(verbosity=2)
