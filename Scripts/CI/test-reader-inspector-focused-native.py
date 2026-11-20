#!/usr/bin/env python3
"""Synthetic refusal/source-preservation controls; zero Native credit."""
import argparse
import copy
import json
from pathlib import Path
import runpy
import subprocess
import unittest

HERE = Path(__file__).resolve().parent
G = runpy.run_path(str(HERE / 'reader-inspector-focused-native.py'))
PARSER = argparse.ArgumentParser()
PARSER.add_argument('--base-dir', type=Path)
ARGS, OTHER = PARSER.parse_known_args()
ROOT = HERE.parents[1]


def original(path):
    if ARGS.base_dir:
        return (ARGS.base_dir / path).read_bytes()
    return subprocess.check_output(['git', 'show', G['BASE'] + ':' + path], cwd=ROOT)


class FocusedBoundary(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / G['MANIFEST']).read_bytes())
        self.old_manifest = json.loads(original(G['MANIFEST']))
        self.pins = [json.loads((ROOT / G['INPUTS']).read_bytes()), json.loads(original(G['INPUTS'])),
                     (ROOT / G['ADDITIONS']).read_bytes(), original(G['ADDITIONS']),
                     (ROOT / G['RUNTIME']).read_bytes(), original(G['RUNTIME'])]
        self.head = 'a' * 40
        self.ui = {'checkout_sha': self.head, 'status': 'SELECTED_UI_EXECUTED_PASS', 'mode': 'ui',
                   'full_release_acceptance': False, 'distribution': False, 'test_source_commit': G['BASE'],
                   'test_tree': G['TREES']['Maktabah-iOSUITests'], 'requested_ui_case_count': 4,
                   'executed_ui_pass': 4, 'executed_ui_fail': 0, 'executed_ui_skip': 0, 'ui_not_run': 0,
                   'case_outcomes': [dict(case_id=c, actual='Passed', device='ipad11', configuration_label='11-reader') for c in G['SELECTED']]}
        self.build = {'checkout_sha': self.head, 'status': 'SIMULATOR_BUILD_FOR_REAL_UI_PASS', 'application_source_sha': G['BASE'],
                      'application_trees': {k: G['TREES'][k] for k in ('Source','Vendor','Maktabah.xcodeproj')}}
        self.summary = {'passedTests': 4, 'failedTests': 0, 'skippedTests': 0, 'expectedFailures': 0}
        self.leaves = [(c, 'Passed') for c in G['SELECTED']]

    def validate(self):
        G['validate_outcomes'](self.ui, self.build, self.summary, self.leaves, self.head)

    def rejected(self):
        with self.assertRaises(ValueError):
            self.validate()

    def test_current_metadata_preserves_original116(self):
        G['validate_manifest'](self.manifest, self.old_manifest)

    def test_current_exact_runtime_and_project_pin_inverses(self):
        G['validate_pins'](*self.pins)

    def test_changed_original_oracle_rejected(self):
        self.manifest['cases'][0]['oracle'] += ' relaxed'
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_missing_original_row_rejected(self):
        self.manifest['supplemental_cases'].pop(0)
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_missing_motion_selection_rejected(self):
        self.manifest['execution_case_ids'].pop()
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_wrong_device_group_rejected(self):
        self.manifest['execution_groups'][0]['size'] = '13'
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_historical_credit_rejected(self):
        self.manifest['native_cases_executed'] = 4
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_full_phase_credit_rejected(self):
        self.manifest['reader_inspector_diagnostic_20261120']['full_native116_acceptance'] = True
        with self.assertRaises(ValueError): G['validate_manifest'](self.manifest, self.old_manifest)

    def test_original_runtime_body_edit_rejected(self):
        self.pins[4] += b'\n# changed original helper\n'
        with self.assertRaises(ValueError): G['validate_pins'](*self.pins)

    def test_source_or_artifact_pin_edit_rejected(self):
        self.pins[0]['engine_producer_sha'] = '0' * 40
        with self.assertRaises(ValueError): G['validate_pins'](*self.pins)

    def test_test_additions_exemption_edit_rejected(self):
        self.pins[2] += b'\n'
        with self.assertRaises(ValueError): G['validate_pins'](*self.pins)

    def test_exact_immutable_child_permitted(self):
        G['validate_identity'](self.head,self.head,G['REF'],[G['BASE']],G['TREES'],G['ALLOWED'])

    def test_wrong_head_ref_or_parent_rejected(self):
        for head,ref,parents in [('b'*40,G['REF'],[G['BASE']]),(self.head,'refs/heads/main',[G['BASE']]),(self.head,G['REF'],[]),(self.head,G['REF'],[G['BASE'],'b'*40])]:
            with self.subTest(head=head,ref=ref,parents=parents),self.assertRaises(ValueError):
                G['validate_identity'](head,self.head,ref,parents,G['TREES'],G['ALLOWED'])

    def test_unreviewed_product_or_test_tree_rejected(self):
        for k in G['TREES']:
            trees=dict(G['TREES']); trees[k]='b'*40
            with self.subTest(tree=k),self.assertRaises(ValueError):
                G['validate_identity'](self.head,self.head,G['REF'],[G['BASE']],trees,G['ALLOWED'])

    def test_changed_unreviewed_path_rejected(self):
        with self.assertRaises(ValueError):
            G['validate_identity'](self.head,self.head,G['REF'],[G['BASE']],G['TREES'],G['ALLOWED']|{'Scripts/CI/run-faithful-ipad-matrix.py'})

    def test_four_matching_synthetic_outcomes_qualify_only_subset(self):
        self.validate()

    def test_build_only_cannot_qualify_native(self):
        self.ui['status']='BUILD_ONLY'
        self.rejected()

    def test_full_phase_status_cannot_qualify_subset(self):
        self.ui['status']='EXECUTED_PASS'
        self.rejected()

    def test_incomplete_or_failed_app_build_rejected(self):
        self.build['status']='FAILED'
        self.rejected()

    def test_wrong_actual_build_head_rejected(self):
        self.build['checkout_sha']='b'*40
        self.rejected()

    def test_wrong_actual_test_tree_rejected(self):
        self.ui['test_tree']='b'*40
        self.rejected()

    def test_one_ui_failure_rejected(self):
        self.ui['executed_ui_pass']=3;self.ui['executed_ui_fail']=1
        self.rejected()

    def test_skip_or_not_run_rejected(self):
        for key in ['executed_ui_skip','ui_not_run']:
            self.ui[key]=1
            with self.subTest(key=key): self.rejected()
            self.ui[key]=0

    def test_raw_xcresult_missing_or_extra_leaf_rejected(self):
        self.leaves.pop();self.rejected()
        self.leaves += [(G['SELECTED'][0],'Passed')]*2;self.rejected()

    def test_raw_expected_failure_is_not_pass(self):
        self.leaves[0]=(self.leaves[0][0],'Expected Failure');self.rejected()

    def test_raw_summary_disagrees_rejected(self):
        self.summary['failedTests']=1;self.rejected()

    def test_wrong_original_case_id_rejected(self):
        self.ui['case_outcomes'][0]['case_id']='AnotherTests/testSynthetic'
        self.rejected()


if __name__ == '__main__':
    unittest.main(argv=[__file__, *OTHER], verbosity=2)
