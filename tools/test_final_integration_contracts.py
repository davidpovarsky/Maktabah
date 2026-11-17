#!/usr/bin/env python3
"""Final integration contract checks for Phase 1 consolidated fixes (F1, F2, F3).

Explicit scope limits (Windows host):
- Validates Stage-2 source-pin alignment (`hq-stage2-focused-apple.inputs.json`),
  fail-closed `--preflight-only` and drift rejections, other-input preservation,
  Swift source contracts for `NativeRoutingAcceptanceTests.swift`, and Swift 6
  frontend syntax parsing (Release and `-D DEBUG`).
- NOT Apple iOS/XCTest SDK compilation, NOT live SpringBoard UI confirmation,
  and NOT R27 runtime acceptance. Native Apple/iOS gates remain NOT_RUN / OPEN.
"""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
from test_o2b_native_ux import swift_env

INPUTS_JSON = ROOT / "Scripts/CI/hq-stage2-focused-apple.inputs.json"
PREFLIGHT_SCRIPT = ROOT / "Scripts/CI/hq-stage2-focused-apple.py"
NATIVE_ROUTING_TESTS = ROOT / "Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift"
BASE_REVIEW_COMMIT = "cc020cc02104324b6fc0f846861f4f653d0639f8"


def _git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, encoding="utf-8").strip()


def _extract_func_block(source: str, signature_prefix: str) -> str:
    idx = source.index(signature_prefix)
    brace_start = source.index("{", idx)
    depth = 0
    for pos in range(brace_start, len(source)):
        ch = source[pos]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[idx : pos + 1]
    raise AssertionError(f"Unbalanced braces in {signature_prefix!r}")


class Stage2SourcePinContractsTests(unittest.TestCase):
    def test_inputs_json_pins_actual_source_commit_and_preserves_other_inputs(self) -> None:
        config = json.loads(INPUTS_JSON.read_text(encoding="utf-8"))
        head_source_tree = _git("rev-parse", "HEAD:Source")
        pin_commit = config["application_source_sha"]
        self.assertRegex(pin_commit, r"^[0-9a-f]{40}$")

        # Must point to an actual ancestor commit whose Source tree matches HEAD:Source.
        anc = subprocess.run(
            ["git", "merge-base", "--is-ancestor", pin_commit, "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(anc.returncode, 0, f"application_source_sha {pin_commit} must be an ancestor of HEAD")
        self.assertEqual(_git("rev-parse", f"{pin_commit}:Source"), head_source_tree)
        self.assertEqual(config["application_trees"]["Source"], head_source_tree)

        # Preserve all non-Source fields byte-for-value relative to the pre-wave base commit.
        base_config = json.loads(_git("show", f"{BASE_REVIEW_COMMIT}:Scripts/CI/hq-stage2-focused-apple.inputs.json"))
        for key in (
            "engine_producer_sha",
            "engine_trees",
            "sefaria_gitlink",
            "resource_producer_sha",
            "resource_bundle_sha256",
            "resources",
            "artifacts",
            "embedded_js_overlay_paths",
            "rebuild_zayit_framework",
        ):
            self.assertEqual(config[key], base_config[key], f"Non-Source input field changed: {key}")
        for tree_key in ("Vendor", "Maktabah.xcodeproj"):
            self.assertEqual(
                config["application_trees"][tree_key],
                base_config["application_trees"][tree_key],
                f"Non-Source application_trees field changed: {tree_key}",
            )

    def test_real_preflight_only_passes(self) -> None:
        res = subprocess.run(
            [sys.executable, str(PREFLIGHT_SCRIPT), "--preflight-only"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(res.returncode, 0, f"preflight failed:\nSTDOUT:\n{res.stdout}\nSTDERR:\n{res.stderr}")
        payload = json.loads(res.stdout)
        self.assertEqual(payload["checkout_sha"], _git("rev-parse", "HEAD"))
        self.assertEqual(payload["application_trees"]["Source"], _git("rev-parse", "HEAD:Source"))

    def test_negative_drift_and_checkout_checks_fail_closed(self) -> None:
        env = os.environ.copy()
        env["EXPECTED_CHECKOUT_SHA"] = "0" * 40
        res = subprocess.run(
            [sys.executable, str(PREFLIGHT_SCRIPT), "--preflight-only"],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertNotEqual(res.returncode, 0, "Wrong EXPECTED_CHECKOUT_SHA must fail closed")
        self.assertIn("Wrong immutable checkout", res.stderr)

        preflight = runpy.run_path(str(PREFLIGHT_SCRIPT))["preflight"]
        valid = json.loads(INPUTS_JSON.read_text(encoding="utf-8"))

        bad_source = copy.deepcopy(valid)
        bad_source["application_trees"]["Source"] = "431748950e3285e600aa9d98d0c252856b429262"
        with self.assertRaisesRegex(RuntimeError, r"Application tree drift: Source"):
            preflight(bad_source)

        bad_vendor = copy.deepcopy(valid)
        bad_vendor["application_trees"]["Vendor"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, r"Application tree drift: Vendor"):
            preflight(bad_vendor)

        bad_sefaria = copy.deepcopy(valid)
        bad_sefaria["sefaria_gitlink"] = "0" * 40
        with self.assertRaisesRegex(RuntimeError, r"Sefaria pin drift"):
            preflight(bad_sefaria)


class NativeRoutingSourceContractTests(unittest.TestCase):
    def test_confirm_dialog_waits_bounded_2s_and_revalidates_before_tap(self) -> None:
        src = NATIVE_ROUTING_TESTS.read_text(encoding="utf-8")
        confirm_fn = _extract_func_block(src, "@MainActor private func confirmSpringBoardOpenDialog(")

        # Must wait up to 2s using actor-safe MainActor.assumeIsolated query before checking/tapping.
        self.assertIn("XCTNSPredicateExpectation", confirm_fn)
        self.assertIn("MainActor.assumeIsolated", confirm_fn)
        self.assertRegex(confirm_fn, r"XCTWaiter\.wait\(for:\s*\[[^\]]+\],\s*timeout:\s*2(?:\.0)?\)")
        self.assertIn('XCUIApplication(bundleIdentifier: "com.apple.springboard")', confirm_fn)

        # Revalidation and fail-closed guards must still occur AFTER the settling wait and BEFORE openButton.tap().
        wait_pos = confirm_fn.index("timeout: 2")
        tap_pos = confirm_fn.index("openButton.tap()")
        post_wait_pre_tap = confirm_fn[wait_pos:tap_pos]
        self.assertIn("alerts.count == 1", post_wait_pre_tap)
        self.assertIn("matchesExpectedSpringBoardOpenTitle", post_wait_pre_tap)
        self.assertIn("openMatches.count == 1", post_wait_pre_tap)
        self.assertIn("openButton.exists", post_wait_pre_tap)
        self.assertIn("openButton.isHittable", post_wait_pre_tap)
        self.assertIn("ambiguous-springboard-alerts", post_wait_pre_tap)
        self.assertIn("unexpected-springboard-alert", post_wait_pre_tap)
        self.assertIn("missing-springboard-open-button", post_wait_pre_tap)
        self.assertNotIn('"Cancel"', confirm_fn)

        # Preserve transport, PID, refusal, replay, and receipt assertions in the file.
        for invariant in (
            'Set(response.keys) == ["udid", "transport", "delivered", "nonce", "time"]',
            "XCTAssertEqual(actualPID, originalPID",
            "[NativeNavigationReceipt]",
            'app.alerts["Unable to open link"]',
            "func testReplayCannotIssueSecondNativeReceipt()",
        ):
            self.assertIn(invariant, src)

    def test_teardown_cancellation_checks_wait_completion_and_fails_unconditionally(self) -> None:
        src = NATIVE_ROUTING_TESTS.read_text(encoding="utf-8")
        teardown_fn = _extract_func_block(src, "private func cleanupLeftoverSpringBoardOpenAlertsInTeardown()")

        self.assertNotIn("_ = XCTWaiter.wait(for: [reduced]", teardown_fn)
        self.assertRegex(
            teardown_fn,
            r"XCTWaiter\.wait\(for:\s*\[reduced\],\s*timeout:\s*5(?:\.0)?\)\s*==\s*\.completed",
        )
        # Must break when reduction does not complete, before incrementing cancelledCount.
        cancel_inc_pos = teardown_fn.index("cancelledCount += 1")
        reduced_check_pos = teardown_fn.index("reduced")
        self.assertLess(reduced_check_pos, cancel_inc_pos)
        self.assertIn("break", teardown_fn[reduced_check_pos:cancel_inc_pos])
        self.assertIn("XCTFail(", teardown_fn)

    def test_native_routing_swift6_frontend_syntax_parse_release_and_debug(self) -> None:
        env = swift_env()
        targets = [
            ROOT / "Maktabah-iOSUITests/MaktabahUITestBase.swift",
            ROOT / "Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift",
            NATIVE_ROUTING_TESTS,
        ]
        for extra in ([], ["-D", "DEBUG"]):
            cmd = ["swiftc", "-frontend", "-parse", "-swift-version", "6", *extra, *map(str, targets)]
            res = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=45)
            self.assertEqual(
                res.returncode,
                0,
                f"swiftc -frontend -parse {' '.join(extra)} failed:\n{res.stdout}\n{res.stderr}",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
