#!/usr/bin/env python3
"""Synthetic ownership evidence-verifier controls; zero Swift/Native credit."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("ownership_driver", ROOT / "tools/hq-cold-search-ownership.py")
driver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(driver)


class OwnershipVerifierTests(unittest.TestCase):
    def result(self, rows):
        return {"scope": "FOUNDATION_OWNERSHIP_WITH_EXPLICIT_NATIVE_CONSTRUCTOR_DOUBLE",
                "actualCOrRustEngineExecuted": 0, "nativeUIExecuted": 0, "checks": rows}

    def baseline(self):
        return self.result([{"id": driver.RED_CASE, "outcome": "failed",
                             "code": "stale_constructor_performed_more_native_work"}])

    def testExactExpectedBaselineFailureQualifies(self):
        self.assertTrue(driver.qualify(self.baseline(), {"returncode": 1, "timed_out": False}, {driver.RED_CASE: "failed"}))

    def testWrongFailureCauseNeverSubstitutesBaseline(self):
        result = self.baseline(); result["checks"][0]["code"] = "missing_fixture_bundle_resource"
        self.assertFalse(driver.qualify(result, {"returncode": 1, "timed_out": False}, {driver.RED_CASE: "failed"}))

    def testCompilationFailureAndEmptyCaseSetNeverQualify(self):
        for result in ({}, self.result([])):
            self.assertFalse(driver.qualify(result, {"returncode": 1, "timed_out": False}, {driver.RED_CASE: "failed"}))

    def testSignalsAndTimeoutAfterReportNeverQualify(self):
        for code in (-9, -15, 2, 137, None):
            self.assertFalse(driver.qualify(self.baseline(), {"returncode": code, "timed_out": False}, {driver.RED_CASE: "failed"}))
        self.assertFalse(driver.qualify(self.baseline(), {"returncode": 1, "timed_out": True}, {driver.RED_CASE: "failed"}))

    def testCandidateNeedsEveryUniqueCaseAndNormalExit(self):
        expected = {"first": "passed", "second": "passed"}
        actual = self.result([{"id": key, "outcome": value} for key, value in expected.items()])
        self.assertTrue(driver.qualify(actual, {"returncode": 0, "timed_out": False}, expected))
        duplicate = copy.deepcopy(actual); duplicate["checks"][1] = duplicate["checks"][0]
        self.assertFalse(driver.qualify(duplicate, {"returncode": 0, "timed_out": False}, expected))
        self.assertFalse(driver.qualify(actual, {"returncode": 1, "timed_out": False}, expected))

    def testConstructorDoubleCannotClaimNativeEngineOrUI(self):
        for key in ("actualCOrRustEngineExecuted", "nativeUIExecuted"):
            actual = self.baseline(); actual[key] = 1
            self.assertFalse(driver.qualify(actual, {"returncode": 1, "timed_out": False}, {driver.RED_CASE: "failed"}))

    def testExtractionKeepsNestedBodiesAndIgnoresStringBrace(self):
        source = 'prefix\nfunc owner() { let text = "}"; if true { work() } }\nsuffix'
        self.assertEqual(driver.extract_block(source, "func owner()"), 'func owner() { let text = "}"; if true { work() } }')

    def testAmbiguousOrUnclosedExtractionRefuses(self):
        for source in ("func owner() {} func owner() {}", "func owner() {"):
            with self.assertRaises(ValueError):
                driver.extract_block(source, "func owner()")


if __name__ == "__main__":
    unittest.main(verbosity=2)
