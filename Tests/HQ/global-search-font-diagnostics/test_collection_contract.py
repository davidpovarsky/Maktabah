#!/usr/bin/env python3
"""Execute the original pure collection selector; no matrix/Swift/UI execution."""
import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "Scripts/CI/run-faithful-ipad-matrix.py"
parsed = ast.parse(SOURCE.read_text())
nodes = [node for node in parsed.body if isinstance(node, ast.FunctionDef)
         and node.name == "requires_native_log_collection"]
if len(nodes) != 1:
    raise RuntimeError("Expected the single original pure collection selector")
namespace = {}
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), namespace)
collect = namespace["requires_native_log_collection"]


class OriginalCollectionSelectorTests(unittest.TestCase):
    def testOriginalRoutingWholeClassStillCollected(self):
        self.assertTrue(collect(["NativeRoutingAcceptanceTests"]))

    def testOriginalPhoneRoutingCaseStillCollected(self):
        self.assertTrue(collect(["NativeRoutingPhoneAcceptanceTests/testReader"]))

    def testOriginalFaithfulWholeClassStillCollected(self):
        self.assertTrue(collect(["FaithfulReaderUIAcceptanceTests"]))

    def testOriginalEscapeCaseStillCollected(self):
        self.assertTrue(collect(["FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal"]))

    def testUnrelatedFaithfulCaseDoesNotExpandCollection(self):
        self.assertFalse(collect(["FaithfulReaderUIAcceptanceTests/testOther"]))

    def testExactGlobalAuditRetainsOriginalPersistentLog(self):
        self.assertTrue(collect(["GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit"]))

    def testWholeGlobalClassIncludesTheAudit(self):
        self.assertTrue(collect(["GlobalSearchNativeAcceptanceTests"]))

    def testUnrelatedGlobalCaseDoesNotExpandCollection(self):
        self.assertFalse(collect(["GlobalSearchNativeAcceptanceTests/testTypingKeepsInlineHistoryAndSingleNativeFieldWithRealClear"]))

    def testSimilarMethodNameDoesNotExpandCollection(self):
        self.assertFalse(collect(["GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAuditOther"]))

    def testSameMethodOnDifferentSuiteDoesNotExpandCollection(self):
        self.assertFalse(collect(["OtherTests/testHeaderAndHistoryNativeAccessibilityAudit"]))

    def testEmptySelectionDoesNotExpandCollection(self):
        self.assertFalse(collect([]))

    def testMixedSelectionContainingActualAuditRetainsLog(self):
        self.assertTrue(collect(["OtherTests/testOther", "GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
