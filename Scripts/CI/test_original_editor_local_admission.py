"""Synthetic local metadata controls; no SDK, native import or editor execution."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

import original_editor_local_admission as local

API = runpy.run_path(str(Path(__file__).with_name('hq-original-editor-distribution.py')))


class LocalSDKMetadataControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.execution_id = 'local-50b3a82c-87a4-418f-89a2-01d75cd634d8'
        self.config = {
            'schema': 3, 'producer_kind': 'local-mac', 'repository': local.REPOSITORY,
            'source_sha': 'a' * 40, 'run_id': self.execution_id, 'run_attempt': 1,
            'archive_bytes': 1, **{key: 'b' * 64 for key in (
                'archive_sha256', 'distribution_manifest_sha256', 'qualification_sha256',
                'original_source_sha256', 'hanlin_source_sha256')},
        }
        execution = {'schema': 'otzaria.original-editor.local-execution/1',
            'repository': local.REPOSITORY, 'execution_id': self.execution_id,
            'source_sha': self.config['source_sha'], 'source_tree': 'c' * 40,
            'head_branch': 'codex/otzaria-sdk-mac-20261124',
            'host': {'system': 'Darwin', 'architecture': 'arm64', 'hostname': 'SYNTHETIC_NOT_A_RUNNER'},
            'acceptance': 'PROVENANCE_ONLY_NOT_ACCEPTANCE'}
        execution_row = self.write('execution', execution)
        identity = {'producer_kind': 'local-mac', 'source_sha': self.config['source_sha'],
            'run_id': self.execution_id, 'run_attempt': '1', 'local_execution': execution,
            'local_execution_sha256': execution_row['sha256']}
        before = {'head_sha': self.config['source_sha'], 'execution_identity': identity,
                  'status': 'SOURCE_BOUND_FRAMEWORK_RUNTIME_NOT_RUN'}
        abi = {'schema': 'otzaria.original-import-local-sdk-input/1', 'status': 'PASS',
               'producer_kind': 'local-mac', 'sdk_source_sha': self.config['source_sha'],
               'local_execution_sha256': execution_row['sha256'],
               'full_sdk_accepted': False, 'editor_ui_accepted': False,
               'owned_command_groups_drained': True,
               'native_qualification': {'status': 'PASS', 'scope': 'SYNTHETIC_METADATA_ONLY'}}
        abi_row = self.write('abi', abi)
        self.config.update(local_execution_sha256=execution_row['sha256'], local_receipts={
            'execution': execution_row, 'source_before': self.write('source_before', before),
            'source_after': self.write('source_after', before), 'abi': abi_row})
        self.qualification = {'execution_identity': identity, 'status': local.QUALIFIED,
            'phase': 'COMPLETE', 'original_framework_build': 'PASS', 'external_consumer_build': 'PASS',
            'native_editor_ui_tests': 0,
            'heart': {'receipt_sha256': abi_row['sha256'], 'native_qualification': abi['native_qualification']}}

    def write(self, name, value):
        path = self.root / 'build' / (name + '.json')
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(value))
        return {'path': path.relative_to(self.root).as_posix(), 'bytes': path.stat().st_size,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def test_local_metadata_keeps_execution_kind_without_stageb_credit(self):
        proof = local.validate_provenance(self.root, self.config, self.qualification, API)
        self.assertEqual(proof['producer_kind'], 'local-mac')
        self.assertFalse(proof['native_stageb_qualified'])

    def test_borrowed_github_artifact_or_numeric_execution_is_rejected(self):
        config = {**self.config, 'artifact_id': 123}
        with self.assertRaisesRegex(RuntimeError, 'borrow GitHub'):
            local.validate_configuration(config)
        with self.assertRaisesRegex(RuntimeError, 'canonical UUID'):
            local.validate_configuration({**self.config, 'run_id': '123'})

    def test_changed_source_receipt_is_rejected(self):
        (self.root / self.config['local_receipts']['source_after']['path']).write_text('{}')
        with self.assertRaisesRegex(RuntimeError, 'bytes differ'):
            local.validate_provenance(self.root, self.config, self.qualification, API)

    def test_incomplete_framework_or_foreign_abi_is_rejected(self):
        failed = {**self.qualification, 'status': 'FAIL'}
        with self.assertRaisesRegex(RuntimeError, 'unfinished framework'):
            local.validate_provenance(self.root, self.config, failed, API)
        foreign = copy.deepcopy(self.qualification)
        foreign['heart']['receipt_sha256'] = '0' * 64
        with self.assertRaisesRegex(RuntimeError, 'qualified original Import ABI'):
            local.validate_provenance(self.root, self.config, foreign, API)


if __name__ == '__main__':
    unittest.main()
