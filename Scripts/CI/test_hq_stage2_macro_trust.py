#!/usr/bin/env python3
"""Real filesystem boundaries for the existing package's targeted Xcode trust."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).with_name("hq-stage2-focused-apple.py")
SPEC = importlib.util.spec_from_file_location("focused_apple", SOURCE)
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)
PIN = "597c2bb34af0c51331eb3b5e705f942d8ee20daa"


class PinnedMacroTrustTests(unittest.TestCase):
    def report(self):
        return {"package_pins": {"equatable": PIN},
                "actual_package_checkouts": {"equatable": {"head": PIN, "status": "CLEAN"}}}

    def test_exact_entry_preserves_existing_trust_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "macros.json"
            original = {"fingerprint": "f" * 40, "packageIdentity": "another-package",
                        "targetName": "ExistingMacro", "retainedExtension": "original"}
            path.write_text(json.dumps([original]), encoding="utf-8")
            report = self.report()
            DRIVER.authorize_pinned_equatable_macro(report, security_directory=root)
            entries = json.loads(path.read_text())
            self.assertEqual(entries, [original, {"fingerprint": PIN, "packageIdentity": "equatable",
                                                 "targetName": "EquatableMacros"}])
            self.assertTrue(report["compiler_macro_authorization"]["normal_xcode_fingerprint_validation"])
            self.assertTrue(report["compiler_macro_authorization"]["entry_added"])
            first = path.read_bytes()
            DRIVER.authorize_pinned_equatable_macro(report, security_directory=root)
            self.assertEqual(path.read_bytes(), first)
            self.assertFalse(report["compiler_macro_authorization"]["entry_added"])
            self.assertEqual(list(root.glob(".hanlin-macro-*")), [])

    def test_changed_or_unverified_source_cannot_modify_authorizations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "macros.json"
            original = b'[{"original":"preserve"}]\n'
            path.write_bytes(original)
            for state in ["different-pin", "dirty", "missing"]:
                with self.subTest(state=state):
                    report = self.report()
                    if state == "different-pin":
                        report["package_pins"]["equatable"] = "a" * 40
                    elif state == "dirty":
                        report["actual_package_checkouts"]["equatable"]["status"] = "DIRTY"
                    else:
                        del report["actual_package_checkouts"]["equatable"]
                    with self.assertRaises(RuntimeError):
                        DRIVER.authorize_pinned_equatable_macro(report, security_directory=root)
                    self.assertEqual(path.read_bytes(), original)

    def test_malformed_existing_file_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "macros.json"
            for original in [b'{"incomplete":', b'{"wrong":"shape"}', b'[42]', b'[{}]']:
                with self.subTest(original=original):
                    path.write_bytes(original)
                    with self.assertRaises((RuntimeError, json.JSONDecodeError)):
                        DRIVER.authorize_pinned_equatable_macro(self.report(), security_directory=root)
                    self.assertEqual(path.read_bytes(), original)

    def test_read_failure_is_not_treated_as_missing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "macros.json"
            path.mkdir()
            marker = path / "original"
            marker.write_text("retained", encoding="utf-8")
            with self.assertRaises(OSError):
                DRIVER.authorize_pinned_equatable_macro(self.report(), security_directory=root)
            self.assertEqual(marker.read_text(), "retained")
            self.assertEqual(list(root.glob(".hanlin-macro-*")), [])


if __name__ == "__main__":
    unittest.main()
