#!/usr/bin/env python3
"""Compiler/source-selection and log-gate regression checks; never Native UI."""
from pathlib import Path
import runpy
import tempfile
import unittest

api = runpy.run_path(str(Path(__file__).with_name("verify-faithful-xctest.py")))


class XCTestDeclarationRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def source(self, name, value):
        (self.root / name).write_text(value, encoding="utf-8")

    def selection(self, *values):
        return api["validate_selections"](list(values), self.root)

    def verify(self, log, *values):
        return api["verify"](log, list(values), self.root)

    def test_extensions_after_another_class_keep_actual_owner_and_inline_attributes(self):
        self.source("A.swift", """
class Parent: XCTestCase { func testParent() {} }
final class Child: Parent { func testPhone() {} }
extension Parent { @MainActor func testExtension() async throws {} }
extension Child { @MainActor func testChildExtension() {} }
""")
        result = self.selection("Parent/testExtension", "Child/testChildExtension", "Parent/testParent")
        self.assertEqual(result["status"], "DECLARATIONS_MATCH")
        self.assertEqual(self.selection("Child/testExtension")["status"], "FAIL")
        self.assertEqual(self.selection("Parent/testPhone")["status"], "FAIL")

    def test_every_file_is_parsed_not_only_swift_primary_source(self):
        self.source("A.swift", "class First: XCTestCase { func testFirst() {} }\n")
        self.source("Z.swift", "class Last: XCTestCase { @MainActor func testLast() {} }\n")
        self.assertEqual(self.selection("First/testFirst", "Last/testLast")["status"], "DECLARATIONS_MATCH")

    def test_comments_literals_nested_functions_and_parameterized_helpers_are_not_cases(self):
        self.source("A.swift", """
class Original: XCTestCase {
    // func testComment() {}
    /* extension Original { func testBlockComment() {} } */
    let text = #"class Invented: XCTestCase { func testLiteral() {} }"#
    func helper() { func testNested() {} }
    func testParameterized(_ argument: Int) {}
    func testReal() {}
}
""")
        self.assertEqual(self.selection("Original/testReal")["status"], "DECLARATIONS_MATCH")
        for item in ["Original/testComment", "Original/testBlockComment", "Original/testNested",
                     "Original/testParameterized", "Invented/testLiteral"]:
            self.assertEqual(self.selection(item)["status"], "FAIL", item)

    def test_ambiguous_duplicate_methods_fail_even_with_a_passing_log(self):
        self.source("A.swift", """
class Original: XCTestCase { func testDuplicate() {} }
extension Original { func testDuplicate() {} }
""")
        self.assertEqual(self.selection("Original/testDuplicate")["status"], "FAIL")
        self.assertEqual(self.verify("Test Case '-[Fixture.Original testDuplicate]' passed",
                                     "Original/testDuplicate")["status"], "FAIL")

    def test_unknown_class_extension_cannot_create_a_test_suite(self):
        self.source("A.swift", """
class Original: XCTestCase { func testReal() {} }
extension Unknown { func testInvented() {} }
""")
        self.assertEqual(self.selection("Unknown/testInvented")["status"], "FAIL")

    def test_swift_syntax_failure_fails_closed(self):
        self.source("A.swift", "class Original: XCTestCase { func testBroken( {")
        report = self.selection("Original/testBroken")
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("Swift frontend", report["source_error"])

    def test_no_log_missing_failure_or_other_suite_cannot_claim_pass(self):
        self.source("A.swift", "class Original: XCTestCase { func testReal() {} }\n")
        passed = "Test Case '-[Fixture.Original testReal]' passed (0.001 seconds)."
        failed = "Test Case '-[Fixture.Original testReal]' failed (0.001 seconds)."
        self.assertEqual(self.verify(passed, "Original/testReal")["status"], "EXECUTED_PASS")
        for log in ["", failed, failed + "\n" + passed, passed.replace("Original", "Another")]:
            self.assertEqual(self.verify(log, "Original/testReal")["status"], "FAIL")

    def test_empty_source_and_unknown_method_fail_closed(self):
        self.assertEqual(self.selection("Original/testReal")["status"], "FAIL")
        self.source("A.swift", "class Original: XCTestCase { func testReal() {} }\n")
        self.assertEqual(self.selection("Original/testMissing")["status"], "FAIL")
        self.assertEqual(self.selection()["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
