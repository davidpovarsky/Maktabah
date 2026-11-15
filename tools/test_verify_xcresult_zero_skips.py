#!/usr/bin/env python3
"""Adversarial verifier fixtures; these are NOT simulator/UI acceptance."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("guard", Path(__file__).with_name("verify_xcresult_zero_skips.py"))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class ResultGuardTests(unittest.TestCase):
    def setUp(self):
        self.summary = {"result": "Passed", "totalTestCount": 1, "passedTests": 1, "failedTests": 0, "skippedTests": 0}
        self.case = {"name": "testTap()", "nodeType": "Test Case", "result": "Passed", "nodeIdentifier": "Navigation/testTap()"}
        self.suite = {"name": "Navigation", "nodeType": "Test Suite", "children": [self.case]}
        self.bundle = {"name": "Maktabah-iOSUITests", "nodeType": "Test Bundle", "children": [self.suite]}
        self.tree = {"testNodes": [self.bundle]}
        self.log = "Test Case '-[Maktabah_iOSUITests.Navigation testTap]' passed (1.0 seconds).\nExecuted 1 test, with 0 failures\n** TEST SUCCEEDED **\n"

    def verify(self, **kwargs):
        return guard.verify(kwargs.get("summary", self.summary), kwargs.get("tree", self.tree), kwargs.get("log", self.log),
                            kwargs.get("required", ["Navigation/testTap"]), kwargs.get("minimum", 1))

    def test_named_real_result_and_log_pass(self):
        result = self.verify()
        self.assertEqual(result["required_ui_passed"], 1)
        self.assertEqual(result["database_open"], "NOT_VERIFIED_BY_TEST_COUNTS")

    def test_reject_false_green_variants(self):
        variants = []
        for field, value in [("result", "Failed"), ("passedTests", 0), ("failedTests", 1), ("skippedTests", 1),
                             ("totalTestCount", 0), ("totalTestCount", 2), ("expectedFailures", 1), ("testFailures", [{}]),
                             ("passedTests", True), ("passedTests", "1")]:
            summary = {**self.summary, field: value}
            variants.append((field + str(value), {"summary": summary}))
        summary = copy.deepcopy(self.summary)
        del summary["skippedTests"]
        variants.extend([("missingCount", {"summary": summary}), ("missingSummary", {"summary": None}),
                         ("emptyScope", {"required": []}), ("duplicateScope", {"required": ["Navigation/testTap"] * 2}),
                         ("wrongCase", {"required": ["Navigation/testOther"]}), ("zeroMinimum", {"minimum": 0}),
                         ("negativeMinimum", {"minimum": -1}), ("partialScope", {"minimum": 2}),
                         ("missingTree", {"tree": {}}), ("emptyTree", {"tree": {"testNodes": []}}),
                         ("emptyLog", {"log": ""}), ("logOnlyGreen", {"log": "** TEST SUCCEEDED **"}),
                         ("missingFinal", {"log": self.log.replace("** TEST SUCCEEDED **", "")}),
                         ("failedFinal", {"log": self.log + "** TEST FAILED **"}),
                         ("wrongLogID", {"log": self.log.replace("testTap", "testOther")}),
                         ("wrongLogCount", {"log": self.log.replace("Executed 1 test", "Executed 2 tests")}),
                         ("failedThenPassed", {"log": self.log + "Test Case '-[Navigation testTap]' failed"}),
                         ("skippedThenPassed", {"log": self.log + "Test Case '-[Navigation testTap]' skipped"})])
        for name, kwargs in variants:
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(**kwargs)

    def test_reject_tree_failures_and_non_ui_bundle(self):
        for result in ["Failed", "Skipped", "Expected Failure", "Not Run", None]:
            with self.subTest(result=result), self.assertRaises(ValueError):
                self.case["result"] = result
                self.verify()
        self.case["result"] = "Passed"
        self.bundle["name"] = "PortableUnitTests"
        with self.assertRaises(ValueError):
            self.verify()

    def test_reject_failed_retry_hidden_by_parent(self):
        self.case["children"] = [{"nodeType": "Test Case Run", "name": "attempt1", "result": "Failed"}]
        with self.assertRaises(ValueError):
            self.verify()

    def test_reject_duplicate_case(self):
        self.suite["children"].append(copy.deepcopy(self.case))
        with self.assertRaises(ValueError):
            self.verify()

    def test_metadata_probe_does_not_satisfy_required_ui_case(self):
        self.case.update(name="testMetadata()", nodeIdentifier="Probe/testMetadata()")
        self.suite["name"] = "Probe"
        with self.assertRaises(ValueError):
            self.verify()


if __name__ == "__main__":
    unittest.main(verbosity=2)
