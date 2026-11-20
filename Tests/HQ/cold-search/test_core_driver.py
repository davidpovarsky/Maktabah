#!/usr/bin/env python3
"""Synthetic verifier controls only; never XCTest/app/engine execution."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location("cold_driver", ROOT / "tools/hq-cold-search-core-acceptance.py")
driver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(driver)


class ExactLeafEvidenceTests(unittest.TestCase):
    expected = {"ColdTests/testReady": "passed", "ColdTests/testCold": "failed"}

    def evidence(self):
        text = "\n".join([
            "Test Case '-[OtzariaActionCoreTests.ColdTests testReady]' started.",
            "Test Case '-[OtzariaActionCoreTests.ColdTests testReady]' passed (0.001 seconds).",
            "Test Case '-[OtzariaActionCoreTests.ColdTests testCold]' started.",
            "Test Case '-[OtzariaActionCoreTests.ColdTests testCold]' failed (0.002 seconds).",
            "Executed 2 tests, with 3 failures (0 unexpected) in 0.003 (0.004) seconds",
        ])
        return driver.parse_xctest(text)

    def qualifies(self, parsed=None, code=1, timeout=False):
        return driver.classify_run({"returncode": code, "timed_out": timeout},
                                   parsed or self.evidence(), self.expected)["qualified"]

    def testMacLeafRenderingAndExactOutcomes(self):
        self.assertTrue(self.qualifies())
        self.assertEqual(self.evidence()["leaves"][1],
                         {"id": "ColdTests/testCold", "outcome": "failed", "seconds": 0.002})

    def testPortableXCTestRendering(self):
        result = driver.parse_xctest("Test Case 'ColdTests.testCold' started.\n"
                                    "Test Case 'ColdTests.testCold' failed (0.013 seconds).")
        self.assertEqual(result["starts"], ["ColdTests/testCold"])
        self.assertEqual(result["leaves"][0]["id"], "ColdTests/testCold")

    def testCompilerFailureAndZeroLeavesAreNeverRed(self):
        self.assertFalse(self.qualifies(driver.parse_xctest("error: no such module\n")))

    def testSummaryWithoutLeavesCannotPass(self):
        self.assertFalse(self.qualifies(driver.parse_xctest("Executed 2 tests, with 3 failures (0 unexpected)")))

    def testDifferentFailingCaseCannotSubstituteExpectedRed(self):
        parsed = self.evidence()
        parsed["leaves"][0]["outcome"], parsed["leaves"][1]["outcome"] = "failed", "passed"
        self.assertFalse(self.qualifies(parsed))

    def testExtraOrDuplicateCaseIsRejected(self):
        for duplicate in (True, False):
            parsed = self.evidence()
            row = copy.deepcopy(parsed["leaves"][0])
            if not duplicate:
                row["id"] = "UnrelatedTests/testOther"
            parsed["leaves"].append(row)
            self.assertFalse(self.qualifies(parsed))

    def testMissingStartOrCompletionIsRejected(self):
        for key in ("starts", "leaves"):
            parsed = self.evidence(); parsed[key].pop()
            self.assertFalse(self.qualifies(parsed))

    def testSkippedAndUnexpectedFailureAreRejected(self):
        parsed = self.evidence(); parsed["leaves"][1]["outcome"] = "skipped"
        self.assertFalse(self.qualifies(parsed))
        parsed = self.evidence(); parsed["final_summary"][2] = 1
        self.assertFalse(self.qualifies(parsed))

    def testTimeoutAndMissingExitAreNeverExpectedRed(self):
        self.assertFalse(self.qualifies(timeout=True))
        self.assertFalse(self.qualifies(code=None))

    def testNonzeroExitDoesNotProveCandidateGreen(self):
        parsed = self.evidence()
        for row in parsed["leaves"]:
            row["outcome"] = "passed"
        parsed["final_summary"] = [2, 0, 0]
        expected = {name: "passed" for name in self.expected}
        self.assertFalse(driver.classify_run({"returncode": 1, "timed_out": False}, parsed, expected)["qualified"])
        self.assertTrue(driver.classify_run({"returncode": 0, "timed_out": False}, parsed, expected)["qualified"])

    def testWrongSummaryOrExitClassCannotBeRed(self):
        self.assertFalse(self.qualifies(code=0))
        parsed = self.evidence(); parsed["final_summary"] = [1, 3, 0]
        self.assertFalse(self.qualifies(parsed))

    def testSignalOrNonstandardExitAfterCompleteLeavesCannotBeRed(self):
        for code in (-9, -15, -6, 2, 70, 137):
            with self.subTest(code=code):
                self.assertFalse(self.qualifies(code=code))

    def testSourcePathCannotEscapeOrUseSymlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / "source").write_text("original", encoding="utf-8")
            self.assertEqual(driver.safe_file(root, "source").read_text(), "original")
            for relative in ("../source", "/source", "x/../source", "x//source", "x\\source", "./source"):
                with self.subTest(relative=relative), self.assertRaises(ValueError):
                    driver.safe_file(root, relative)
            (root / "alias").symlink_to(root / "source")
            with self.assertRaises(ValueError):
                driver.safe_file(root, "alias")


if __name__ == "__main__":
    unittest.main(verbosity=2)
