import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location('sheet_gate', ROOT / 'tools/hq-native-study-sheet-lifecycle.py')
gate = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(gate)

class ResultGateTests(unittest.TestCase):
    def setUp(self):
        self.ids = gate.case_ids((ROOT / gate.FIXTURES / 'NativeStudySheetOwnerAcceptance.swift').read_text())
        self.red = [{'id': value, 'passed': value not in gate.EXPECTED_RED} for value in self.ids]
        self.green = [{'id': value, 'passed': True} for value in self.ids]
    def test_exact_declared_red(self):
        self.assertTrue(gate.qualify(self.red, self.ids, {'returncode': 1, 'timeout': False}, gate.EXPECTED_RED))
    def test_exact_declared_green(self):
        self.assertTrue(gate.qualify(self.green, self.ids, {'returncode': 0, 'timeout': False}, set()))
    def test_red_signal_after_all_rows_rejected(self):
        self.assertFalse(gate.qualify(self.red, self.ids, {'returncode': -9, 'timeout': False}, gate.EXPECTED_RED))
    def test_red_other_failure_rejected(self):
        self.red[1]['passed'] = False
        self.assertFalse(gate.qualify(self.red, self.ids, {'returncode': 1, 'timeout': False}, gate.EXPECTED_RED))
    def test_setup_zero_rows_rejected(self):
        self.assertFalse(gate.qualify([], self.ids, {'returncode': 1, 'timeout': False}, gate.EXPECTED_RED))
    def test_timeout_after_complete_rows_rejected(self):
        self.assertFalse(gate.qualify(self.green, self.ids, {'returncode': 0, 'timeout': True}, set()))
    def test_duplicate_substituted_row_rejected(self):
        self.green[1] = self.green[0]
        self.assertFalse(gate.qualify(self.green, self.ids, {'returncode': 0, 'timeout': False}, set()))
    def test_nonboolean_success_rejected(self):
        self.green[0]['passed'] = 1
        self.assertFalse(gate.qualify(self.green, self.ids, {'returncode': 0, 'timeout': False}, set()))
    def test_nonzero_candidate_rejected(self):
        self.assertFalse(gate.qualify(self.green, self.ids, {'returncode': 1, 'timeout': False}, set()))
    def test_reordered_rows_rejected(self):
        self.assertFalse(gate.qualify(self.green[::-1], self.ids, {'returncode': 0, 'timeout': False}, set()))
    def test_declared_lifecycle_twenty_distinct(self):
        ids = gate.case_ids((ROOT / gate.FIXTURES / 'NativeStudySheetLifecycleAcceptance.swift').read_text())
        self.assertEqual(len(ids), 20); self.assertEqual(len(set(ids)), 20)
    def test_complete_balanced_body_preserves_nested_guard(self):
        text = 'prefix\n    func action() { if ready { use() } else { refuse() } }\nother'
        self.assertEqual(gate.method(text, '    func action('), text.split('\n')[1])
    def test_duplicate_source_signature_rejected(self):
        with self.assertRaises(ValueError): gate.method('func a() {}\nfunc a() {}', 'func a(')
    def test_missing_source_signature_rejected(self):
        with self.assertRaises(ValueError): gate.method('func b() {}', 'func a(')
    def test_unterminated_source_rejected(self):
        with self.assertRaises(ValueError): gate.method('func a() { if yes { yes() }', 'func a(')

if __name__ == '__main__': unittest.main(verbosity=2)
