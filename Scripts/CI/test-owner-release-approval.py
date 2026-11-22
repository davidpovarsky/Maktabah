#!/usr/bin/env python3
"""Controls for release wiring and authenticated-verifier result consumption.

Synthetic PASS reports exercise the wrapper contract only; they are not owner
signatures. Real Ed25519 verification remains in the unchanged pinned verifier.
"""
import base64
import copy
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import types
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location("owner_release_gate", HERE / "verify-owner-release-approval.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
CANDIDATE = "1" * 40
SCOPE = ["Source/Features/Reader/First.swift", "Source/UI/Second.swift"]
NOW = datetime(2026, 11, 22, tzinfo=timezone.utc)


def fixture_report():
    return {
        "status": "PASS", "base_ref": gate.BASELINE, "head_ref": CANDIDATE,
        "upstream_ref": gate.UPSTREAM, "total_violations": 0, "violations": [],
        "total_warnings": 2,
        "warnings": [
            {"type": "APPROVED_UPSTREAM_EXCEPTION", "path": path,
             "attestation": {"repo": gate.REPOSITORY, "expires_at": "2099-01-01T00:00:00Z"}}
            for path in SCOPE
        ],
    }


def job(text, name):
    match = re.search(r"(?ms)^  " + re.escape(name) + r":\n(.*?)(?=^  [a-zA-Z0-9_-]+:|\Z)", text)
    if not match:
        raise AssertionError("Missing workflow job " + name)
    return match.group(1)


def require_release_wiring(text):
    build = job(text, "build-sign-and-upload")
    header = build.split("    steps:", 1)[0]
    if not re.search(r"^    needs: \[verify-owner-approval\]$", header, re.M):
        raise AssertionError("Signing job must depend on owner approval")
    if re.search(r"^    (?:if|continue-on-error):", header, re.M):
        raise AssertionError("Signing job cannot override failed dependency status")
    owner = job(text, "verify-owner-approval")
    for required in [
        "ref: ${{ github.sha }}", "fetch-depth: 0", "python-version: '3.11'",
        "cryptography==43.0.3", "python3 -I Scripts/CI/verify-owner-release-approval.py",
        '--expected-sha "$EXPECTED_SHA"', '--repository "$GITHUB_REPOSITORY"',
        "MAKTABAH_OWNER_VERIFICATION_KEY:", "secrets.MAKTABAH_OWNER_VERIFICATION_KEY",
        "vars.MAKTABAH_OWNER_VERIFICATION_KEY", "if: always()",
        "uses: actions/upload-artifact@v4", "build/owner-approval/", "if-no-files-found: error",
    ]:
        if required not in owner:
            raise AssertionError("Missing mandatory approval wiring: " + required)
    if "continue-on-error:" in owner or "|| true" in owner:
        raise AssertionError("Owner gate must not ignore failure")


class OwnerReleaseControls(unittest.TestCase):
    def accept(self, report=None, code=0, scope=SCOPE):
        return gate.validate_report(code, report or fixture_report(), CANDIDATE, scope, NOW)

    def test_complete_authenticated_report_contract(self):
        self.assertEqual(self.accept(), 2)

    def test_exit_failure_cannot_be_relabelled_by_pass_json(self):
        with self.assertRaises(gate.ApprovalError):
            self.accept(code=1)

    def test_failed_json_cannot_be_relabelled_by_exit_zero(self):
        report = fixture_report(); report["status"] = "FAIL"
        with self.assertRaises(gate.ApprovalError):
            self.accept(report)

    def test_foreign_source_bindings_are_rejected(self):
        for field in ("base_ref", "head_ref", "upstream_ref"):
            with self.subTest(field=field):
                report = fixture_report(); report[field] = "2" * 40
                with self.assertRaises(gate.ApprovalError):
                    self.accept(report)

    def test_unapproved_missing_extra_and_duplicate_paths_are_rejected(self):
        for paths in (SCOPE[:1], SCOPE + ["Source/UI/Unrelated.swift"], [SCOPE[0], SCOPE[0]]):
            with self.subTest(paths=paths):
                report = fixture_report()
                row = report["warnings"][0]
                report["warnings"] = [dict(copy.deepcopy(row), path=p) for p in paths]
                report["total_warnings"] = len(paths)
                with self.assertRaises(gate.ApprovalError):
                    self.accept(report)

    def test_violations_cannot_hide_under_pass_status(self):
        report = fixture_report(); report["violations"] = [{"type": "MISSING_OWNER_SIGNATURE"}]
        with self.assertRaises(gate.ApprovalError):
            self.accept(report)

    def test_warning_count_and_kind_must_be_consistent(self):
        for field, value in (("total_warnings", 0), ("total_violations", 1)):
            report = fixture_report(); report[field] = value
            with self.assertRaises(gate.ApprovalError):
                self.accept(report)
        report = fixture_report(); report["warnings"][0]["type"] = "DIAGNOSTIC_ONLY"
        with self.assertRaises(gate.ApprovalError):
            self.accept(report)

    def test_release_approval_repository_must_match(self):
        report = fixture_report(); report["warnings"][0]["attestation"]["repo"] = "other/repository"
        with self.assertRaises(gate.ApprovalError):
            self.accept(report)

    def test_missing_expired_and_naive_expiration_are_rejected(self):
        for expiry in (None, "NEVER", "2026-11-22T00:00:00Z", "2099-01-01T00:00:00"):
            report = fixture_report(); attestation = report["warnings"][0]["attestation"]
            if expiry is None: del attestation["expires_at"]
            else: attestation["expires_at"] = expiry
            with self.assertRaises(gate.ApprovalError):
                self.accept(report)

    def test_absent_or_invalid_public_key_is_rejected(self):
        for key in ("", "not a key", "ff" * 31):
            with self.assertRaises(gate.ApprovalError):
                gate.public_key_fingerprint(key)
        raw = bytes(range(32))  # Public parsing fixture; no private key or signer is created.
        self.assertEqual(gate.public_key_fingerprint(raw.hex()),
                         gate.public_key_fingerprint(base64.b64encode(raw).decode()))

    def test_verifier_hash_is_checked_before_loading(self):
        with mock.patch.object(gate, "git", return_value=b"untrusted verifier") as read:
            with self.assertRaisesRegex(gate.ApprovalError, "SHA-256 mismatch"):
                gate.trusted_verifier_bytes(ROOT)
        read.assert_called_once_with(ROOT, "show", gate.VERIFIER_COMMIT + ":" + gate.VERIFIER_PATH)

    def test_pinned_immutable_verifier_matches_reviewed_bytes(self):
        self.assertTrue(gate.trusted_verifier_bytes(ROOT).startswith(b"#!/usr/bin/env python3"))

    def test_candidate_and_event_mismatch_stop_before_guard(self):
        with mock.patch.object(gate, "git", return_value=(CANDIDATE + "\n").encode()):
            with self.assertRaises(gate.ApprovalError):
                gate.checkout_identity(ROOT, "2" * 40, gate.REPOSITORY)
            with self.assertRaises(gate.ApprovalError):
                gate.checkout_identity(ROOT, CANDIDATE, gate.REPOSITORY, "2" * 40)

    def test_wrong_repository_or_mutable_candidate_is_rejected(self):
        for candidate, repository in (("HEAD", gate.REPOSITORY), (CANDIDATE, "other/repo")):
            with self.assertRaises(gate.ApprovalError):
                gate.checkout_identity(ROOT, candidate, repository)

    def test_missing_key_retains_report_and_cannot_accept_even_a_pass_fixture(self):
        report = fixture_report()
        fake = types.SimpleNamespace(
            get_tree_files=lambda *args: set(SCOPE),
            parse_raw_diff=lambda *args: [{"path": p} for p in SCOPE],
            is_protected_path=lambda *args: True,
            verify_boundaries=mock.Mock(return_value=(0, report)),
        )
        loader = types.SimpleNamespace(loader=types.SimpleNamespace(exec_module=lambda module: None))
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            with mock.patch.object(gate, "checkout_identity", return_value={"Source": "fixture"}), \
                 mock.patch.object(gate, "trusted_verifier_bytes", return_value=b"# fixture, never executed"), \
                 mock.patch.object(gate.importlib.util, "spec_from_file_location", return_value=loader), \
                 mock.patch.object(gate.importlib.util, "module_from_spec", return_value=fake), \
                 mock.patch("builtins.print"):
                self.assertEqual(gate.audit(ROOT, CANDIDATE, gate.REPOSITORY, out, key=""), 1)
            receipt = json.loads((out / "owner-approval-gate.json").read_text())
            self.assertEqual(receipt["status"], "FAILED")
            self.assertIn("not configured", receipt["error"])
            self.assertEqual(json.loads((out / "boundary-guard-report.json").read_text()), report)
            fake.verify_boundaries.assert_called_once_with(
                base_ref=gate.BASELINE, head_ref=CANDIDATE, upstream_ref=gate.UPSTREAM,
                cwd=str(ROOT), owner_public_key="")

    def test_testflight_requires_gate_before_signing(self):
        require_release_wiring((ROOT / ".github/workflows/ios-testflight.yml").read_text(encoding="utf-8"))

    def test_success_fixture_requires_source_stability_and_retains_receipts(self):
        for stable in (True, False):
            with self.subTest(stable=stable), tempfile.TemporaryDirectory() as folder:
                report = fixture_report()
                fake = types.SimpleNamespace(
                    get_tree_files=lambda *args: set(SCOPE),
                    parse_raw_diff=lambda *args: [{"path": p} for p in SCOPE],
                    is_protected_path=lambda *args: True,
                    verify_boundaries=mock.Mock(return_value=(0, report)),
                )
                loader = types.SimpleNamespace(loader=types.SimpleNamespace(exec_module=lambda module: None))
                before = {"Source": "fixture-before"}
                after = before if stable else {"Source": "fixture-after"}
                out = Path(folder)
                with mock.patch.object(gate, "checkout_identity", side_effect=[before, after]), \
                     mock.patch.object(gate, "trusted_verifier_bytes", return_value=b"# fixture, never executed"), \
                     mock.patch.object(gate.importlib.util, "spec_from_file_location", return_value=loader), \
                     mock.patch.object(gate.importlib.util, "module_from_spec", return_value=fake), \
                     mock.patch("builtins.print"):
                    self.assertEqual(gate.audit(ROOT, CANDIDATE, gate.REPOSITORY, out, key="ab" * 32), 0 if stable else 1)
                receipt = json.loads((out / "owner-approval-gate.json").read_text())
                self.assertEqual(receipt["status"], "OWNER_APPROVAL_VERIFIED" if stable else "FAILED")
                if stable:
                    self.assertEqual(receipt["verified_protected_paths"], 2)
                else:
                    self.assertIn("changed during", receipt["error"])
                self.assertEqual(json.loads((out / "boundary-guard-report.json").read_text()), report)

    def test_wiring_control_rejects_detached_or_failure_ignoring_signing_job(self):
        text = (ROOT / ".github/workflows/ios-testflight.yml").read_text(encoding="utf-8")
        for mutated in (text.replace("needs: [verify-owner-approval]", "needs: [unrelated]"),
                        text.replace("  build-sign-and-upload:\n", "  build-sign-and-upload:\n    if: always()\n")):
            with self.assertRaises(AssertionError):
                require_release_wiring(mutated)

    def test_default_branch_and_trusted_base_failure_paths(self):
        text = (ROOT / ".github/workflows/upstream-boundary-guard.yml").read_text(encoding="utf-8")
        self.assertEqual(text.count('branches: [ "main", "dev", "sync/**" ]'), 2)
        self.assertIn("set -euo pipefail", text)
        self.assertNotIn("|| true", text)
        self.assertNotIn('|| echo "$PR_BASE_SHA"', text)
        self.assertIn('git checkout "origin/$GITHUB_BASE_REF" -- Scripts/CI/verify-upstream-boundary.py', text)
        self.assertNotIn("--allow-unsafe-register", text)
        self.assertNotIn("--exception-register", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
