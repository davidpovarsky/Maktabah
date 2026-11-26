"""Synthetic donor transport integrity controls; no SDK/native/editor execution."""
import copy
import json
from pathlib import Path
import unittest

import original_editor_local_admission as local
import test_original_editor_local_admission as fixture

API = fixture.API


class DonorSDKMetadataControls(unittest.TestCase):
    write = fixture.LocalSDKMetadataControls.write

    def setUp(self):
        fixture.LocalSDKMetadataControls.setUp(self)
        self.config['public_host_contract_sha256'] = local.MINIAPPS_CONTRACT
        self.config['abi_provenance'] = local.DONOR_SCHEMA
        current_identity = copy.deepcopy(self.qualification['execution_identity'])
        current_execution = current_identity['local_execution']
        current_execution['head_branch'] = 'codex/anytype-original-miniapps-facade-20261125'
        current_row = self.write('execution', current_execution)
        current_identity['local_execution_sha256'] = current_row['sha256']
        self.config['local_execution_sha256'] = current_row['sha256']
        self.qualification['execution_identity'] = current_identity

        donor_root = '/SYNTHETIC_NOT_A_PRODUCER/retained-donor'
        donor_execution = {**copy.deepcopy(current_execution),
            'source_sha': local.DONOR_SOURCE, 'root': donor_root,
            'head_branch': 'codex/otzaria-local-annotation-sdk-20261124',
            'execution_id': 'local-af236fb7-d3fb-466d-a068-c7acb8c1dca9'}
        donor_execution_row = self.write('abi_donor_execution', donor_execution)
        donor_identity = {**copy.deepcopy(current_identity), 'source_sha': local.DONOR_SOURCE,
            'run_id': donor_execution['execution_id'], 'local_execution': donor_execution,
            'local_execution_sha256': donor_execution_row['sha256']}
        native = {'status': 'PASS', 'scope': 'SYNTHETIC_METADATA_ONLY_NOT_EXECUTION'}
        wrapper = {'schema': 'otzaria.gomobile-pinned-wrapper-observation/1',
            'status': 'THREE_ACTUAL_PINNED_WRAPPERS_PASS', 'control_sha': local.DONOR_SOURCE,
            'original_go_sum_preserved': True, 'all_targets_admitted_before_compile': True,
            'original_gomobile_modified': False, 'rejected_archives_reused': False,
            'targets': [{'target': name} for name in
                        ('ios-arm64', 'iossimulator-arm64', 'iossimulator-amd64')]}
        wrapper_row = self.write('abi_donor_pinned_wrapper', wrapper)
        wrapper_proof = {**copy.deepcopy(wrapper), 'receipt_sha256': wrapper_row['sha256'],
                         'targets': [row['target'] for row in wrapper['targets']]}
        abi = {'schema': 'otzaria.original-import-local-sdk-input/2', 'status': 'PASS',
            'producer_kind': 'local-mac', 'sdk_source_sha': local.DONOR_SOURCE,
            'local_execution_sha256': donor_execution_row['sha256'],
            'full_sdk_accepted': False, 'editor_ui_accepted': False,
            'owned_command_groups_drained': True, 'native_qualification': native,
            'pinned_wrapper': {**wrapper_row, 'path': 'pinned-wrapper/RESULT.json'}}
        abi_row = self.write('abi_donor_abi', abi)
        lib = [{'path': 'Dependencies/Middleware/Lib.xcframework/SYNTHETIC-' + str(i),
                'bytes': 1, 'sha256': 'f' * 64} for i in range(17)]
        installation = {'schema': abi['schema'], 'status': 'PASS',
            'app_source_sha': local.DONOR_SOURCE, 'producer_kind': 'local-mac',
            'receipt_sha256': abi_row['sha256'], 'native_qualification': native,
            'pinned_wrapper': wrapper_proof, 'lib_files': lib,
            'generated_files_verified': 733, 'generated_files_written': 0,
            'full_sdk_accepted': False, 'editor_ui_accepted': False}
        generated = {'generated_index_sha256': '1' * 64, 'source_adoption_sha256': '2' * 64,
            'working_generated_files': 733, 'committed_generated_blobs': 733,
            'postimage_source': '3' * 40, 'preimage_source': '4' * 40}
        trees = {path: '5' * 40 for path in local.DONOR_INPUTS}
        donor_before = {'head_sha': local.DONOR_SOURCE, 'execution_identity': donor_identity,
            'status': 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'generated_import_source': copy.deepcopy(generated)}
        donor_before_row = self.write('abi_donor_source_before', donor_before)
        donor_qualification = {'source_sha': local.DONOR_SOURCE, 'execution_identity': donor_identity,
            'status': local.QUALIFIED, 'phase': 'COMPLETE', 'original_framework_build': 'PASS',
            'external_consumer_build': 'PASS', 'native_editor_ui_tests': 0, 'heart': installation}
        donor_qualification_row = self.write('abi_donor_debug_qualification', donor_qualification)
        donor_rows = {'execution': donor_execution_row, 'source_before': donor_before_row,
                      'abi': abi_row, 'debug_qualification': donor_qualification_row}
        policy = {'schema': 'otzaria.native-abi-donor-policy/1', 'source_sha': local.DONOR_SOURCE,
            'native_tests_rerun': False, 'new_sdk_acceptance_granted': False,
            'unchanged_git_inputs': trees,
            'receipts': {key: {'path': row['path'], 'sha256': row['sha256']}
                         for key, row in donor_rows.items()}}
        policy_row = self.write('abi_donor_policy', policy)
        current_trees = {key: value for key, value in trees.items()
                         if key in ('Anytype/Sources', 'Anytype/Resources', 'Modules')}
        current_trees['Anytype/Sources'] = '6' * 40
        generated['annotation_exchange'] = {'base_source': local.DONOR_SOURCE,
            'native_acceptance_reused_by_this_document': False,
            'sdk_compiler_and_runtime_acceptance': 'NOT_GRANTED_BY_SOURCE_OBSERVATION',
            'reviewed_product_trees': current_trees}
        before = {'head_sha': self.config['source_sha'], 'execution_identity': current_identity,
            'status': 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN',
            'public_host_contract_sha256': local.MINIAPPS_CONTRACT,
            'generated_import_source': generated, 'original_trees': current_trees,
            'source_inputs': {local.DONOR_POLICY: {'sha256': policy_row['sha256']}}}
        reference = {'schema': local.DONOR_SCHEMA,
            'status': 'EVIDENCE_REFERENCE_ONLY_REQUIRES_VERIFICATION',
            'consumer_source_sha': self.config['source_sha'],
            'consumer_local_execution_sha256': current_row['sha256'],
            'policy_sha256': policy_row['sha256'], 'donor_root': donor_root,
            'new_sdk_acceptance_granted': False}
        reference_row = self.write('abi', reference)
        self.config['local_receipts'] = {
            'execution': current_row, 'source_before': self.write('source_before', before),
            'source_after': self.write('source_after', before), 'abi': reference_row,
            **{'abi_donor_' + key: row for key, row in donor_rows.items()},
            'abi_donor_policy': policy_row, 'abi_donor_pinned_wrapper': wrapper_row}
        self.qualification['heart'] = {**copy.deepcopy(installation),
            'schema': local.DONOR_SCHEMA, 'receipt_sha256': reference_row['sha256'],
            'app_source_sha': self.config['source_sha'],
            'original_abi_producer_identity': donor_identity,
            'abi_reuse': {'status': 'EXACT_NATIVE_INPUT_AND_ARTIFACT_EQUIVALENCE',
                'donor_source_sha': local.DONOR_SOURCE, 'donor_root': donor_root,
                'donor_receipts': policy['receipts'], 'unchanged_git_inputs': trees,
                'original_abi_installation': installation, 'native_tests_rerun': False,
                'new_sdk_acceptance_granted': False}}

    def validate(self):
        return local.validate_provenance(self.root, self.config, self.qualification, API)

    def mutate_receipt(self, role, update):
        value = json.loads((self.root / self.config['local_receipts'][role]['path']).read_text())
        update(value)
        self.config['local_receipts'][role] = self.write(role, value)
        return value

    def test_reference_retains_original_identity_and_no_new_native_credit(self):
        proof = self.validate()
        self.assertFalse(proof['native_stageb_qualified'])
        self.assertEqual(proof['abi_reuse']['donor_source_sha'], local.DONOR_SOURCE)
        self.assertNotEqual(proof['abi_reuse']['original_abi_producer_identity']['run_id'],
                            self.config['run_id'])
        self.assertFalse(proof['abi_reuse']['native_tests_rerun'])
        self.assertFalse(proof['abi_reuse']['new_sdk_acceptance_granted'])

    def test_exact_closed_receipt_set_is_required(self):
        for role in sorted(local.DONOR_ROLES):
            with self.subTest(role=role):
                row = self.config['local_receipts'].pop(role)
                with self.assertRaisesRegex(RuntimeError, 'evidence closure'):
                    self.validate()
                self.config['local_receipts'][role] = row
        self.config['local_receipts']['invented'] = self.config['local_receipts']['abi']
        with self.assertRaisesRegex(RuntimeError, 'evidence closure'):
            self.validate()

    def test_donor_reference_cannot_use_fresh_abi_route(self):
        del self.config['abi_provenance']
        with self.assertRaisesRegex(RuntimeError, 'evidence closure'):
            self.validate()

    def test_reference_cannot_be_relabelled_as_fresh_pass(self):
        self.mutate_receipt('abi', lambda value: value.update(status='PASS'))
        with self.assertRaisesRegex(RuntimeError, 'relabelled'):
            self.validate()

    def test_reference_cannot_borrow_another_current_execution(self):
        self.mutate_receipt('abi', lambda value: value.update(consumer_local_execution_sha256='0' * 64))
        with self.assertRaisesRegex(RuntimeError, 'another SDK execution'):
            self.validate()

    def test_original_raw_receipt_tampering_is_detected(self):
        row = self.config['local_receipts']['abi_donor_pinned_wrapper']
        (self.root / row['path']).write_text('{}')
        with self.assertRaisesRegex(RuntimeError, 'receipt bytes differ'):
            self.validate()

    def test_rehashed_donor_receipt_still_must_match_original_policy(self):
        self.mutate_receipt('abi_donor_abi', lambda value: value.update(sdk_source_sha=self.config['source_sha']))
        with self.assertRaisesRegex(RuntimeError, 'committed policy'):
            self.validate()

    def test_current_heart_cannot_replace_original_donor_identity(self):
        self.qualification['heart']['original_abi_producer_identity'] = self.qualification['execution_identity']
        with self.assertRaisesRegex(RuntimeError, 'original donor installation'):
            self.validate()

    def test_reuse_cannot_award_new_native_or_sdk_acceptance(self):
        for field in ('native_tests_rerun', 'new_sdk_acceptance_granted'):
            with self.subTest(field=field):
                self.qualification['heart']['abi_reuse'][field] = True
                with self.assertRaisesRegex(RuntimeError, 'reuse scope'):
                    self.validate()
                self.qualification['heart']['abi_reuse'][field] = False

    def test_installed_native_member_cannot_be_substituted(self):
        self.qualification['heart']['lib_files'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(RuntimeError, 'original donor installation'):
            self.validate()

    def test_generated_source_changes_are_not_admitted_by_original_abi(self):
        value = self.mutate_receipt('source_before', lambda value:
                                   value['generated_import_source'].update(generated_index_sha256='0' * 64))
        self.config['local_receipts']['source_after'] = self.write('source_after', value)
        with self.assertRaisesRegex(RuntimeError, '733 generated'):
            self.validate()

    def test_unreviewed_swift_tree_cannot_reuse_native_abi(self):
        value = self.mutate_receipt('source_before', lambda value:
                                   value['original_trees'].update({'Anytype/Sources': '0' * 40}))
        self.config['local_receipts']['source_after'] = self.write('source_after', value)
        with self.assertRaisesRegex(RuntimeError, 'reviewed source scope'):
            self.validate()

    def test_new_editor_credit_is_never_granted(self):
        self.qualification['native_editor_ui_tests'] = 1
        with self.assertRaisesRegex(RuntimeError, 'editor UI credit'):
            self.validate()


if __name__ == '__main__':
    unittest.main()
