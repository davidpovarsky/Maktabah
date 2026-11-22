"""Only new selector-to-schema-2 boundaries; no Apple or native execution."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
SELECTOR = runpy.run_path(str(ROOT / 'candidate/Scripts/CI/select-runtime27-toolchain.py'))
ORIGINAL = runpy.run_path(str(ROOT / 'original/select-runtime27-toolchain.py'))
HELPER = runpy.run_path(str(ROOT / 'candidate/Scripts/CI/original_editor_continuation_admission.py'))
FRAMEWORK = json.loads((ROOT.parent / 'FRAMEWORK_PRODUCER.json').read_bytes())

def fixture():
    # Exact original framework contract, explicitly synthetic later runtime IDs.
    p = copy.deepcopy(FRAMEWORK)
    runtime = dict(repository=p['repository'], repository_id=p['repository_id'], control_sha='a' * 40,
        run_id=999001, run_attempt=1, workflow_path=HELPER['WORKFLOW'], head_branch=HELPER['BRANCH'],
        job_name=HELPER['JOB_NAME'], job_id=999002, required_steps=copy.deepcopy(HELPER['RUNTIME_REQUIRED_STEPS']),
        evidence_artifact=dict(id=999003, name='Otzaria-Original-Editor-Runtime-Continuation-' + ('a' * 40) + '-999001-1',
            size_in_bytes=50, sha256='b' * 64, path='build/sdk/runtime.zip', upload_step=HELPER['RUNTIME_UPLOAD_STEP']))
    c = {key: copy.deepcopy(p[key]) for key in ['repository', 'repository_id', 'source_sha', 'run_id',
        'run_attempt', 'job_id', 'job_name', 'workflow_path', 'required_steps']}
    c.update(schema=2, framework_producer=p, runtime_qualification_producer=runtime,
        framework_artifact={**p['framework_artifact'], 'path': 'build/sdk/framework.zip'},
        evidence_artifact={**p['evidence_artifact'], 'path': 'build/sdk/original-evidence.zip'},
        artifact_id=p['framework_artifact']['id'], archive_path='build/sdk/framework.zip',
        archive_bytes=p['framework_artifact']['size_in_bytes'], archive_sha256=p['framework_artifact']['sha256'],
        distribution_manifest_sha256=p['retained_input_sha256']['framework-distribution.json'],
        hanlin_source_sha256=p['retained_input_sha256']['original-hanlin-snapshot.json'],
        original_source_sha256=p['original_source_sha256'], qualification_sha256='c' * 64,
        qualification_member='runtime-qualification.json', qualification_wrapper=HELPER['RUNTIME_WRAPPER'],
        toolchain=copy.deepcopy(p['toolchain']))
    return c

class SelectorSchema2Boundaries(unittest.TestCase):
    def committed(self, config):
        directory = tempfile.TemporaryDirectory(prefix='otzaria-schema2-selector-')
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        path = root / 'Scripts/CI/input.json'
        path.parent.mkdir(parents=True)
        path.write_bytes(json.dumps(config, sort_keys=True).encode())
        for args in [('init', '--quiet'), ('add', 'Scripts/CI/input.json'),
                     ('commit', '--quiet', '-m', 'Synthetic isolated selector boundary')]:
            subprocess.run(['git', '-c', 'user.name=Otzaria isolated control',
                '-c', 'user.email=isolated-control@example.invalid', *args], cwd=root,
                check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
        return root, path

    def test_finalized_schema2_selects_original_framework_tuple_and_keeps_roles(self):
        config = fixture()
        root, path = self.committed(config)
        with self.assertRaisesRegex(RuntimeError, 'not finalized'):
            ORIGINAL['original_editor_toolchain']('Scripts/CI/input.json', root)
        result = SELECTOR['original_editor_toolchain']('Scripts/CI/input.json', root)
        self.assertEqual(result['toolchain'], FRAMEWORK['toolchain'])
        self.assertEqual(result['source_sha'], FRAMEWORK['source_sha'])
        self.assertEqual(result['run_id'], FRAMEWORK['run_id'])
        self.assertNotEqual(result['run_id'], config['runtime_qualification_producer']['run_id'])
        self.assertEqual(result['qualification_sha256'], config['qualification_sha256'])
        self.assertEqual(result['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())

    def test_missing_or_changed_top_level_tuple_cannot_override_retained_framework(self):
        changes = [None, *[{**FRAMEWORK['toolchain'], key: value + '-changed'}
                          for key, value in FRAMEWORK['toolchain'].items()]]
        for changed in changes:
            with self.subTest(tuple=changed):
                config = fixture()
                if changed is None:
                    del config['toolchain']
                else:
                    config['toolchain'] = changed
                root, _ = self.committed(config)
                with self.assertRaisesRegex(RuntimeError, 'exact retained framework producer'):
                    SELECTOR['original_editor_toolchain']('Scripts/CI/input.json', root)

    def test_exact_toolchain_cannot_bypass_distinct_finalized_runtime_validation(self):
        config = fixture()
        config['runtime_qualification_producer']['run_id'] = config['run_id']
        root, _ = self.committed(config)
        with self.assertRaisesRegex(RuntimeError, 'Unfinalized distinct continuation identity'):
            SELECTOR['original_editor_toolchain']('Scripts/CI/input.json', root)

if __name__ == '__main__':
    unittest.main(verbosity=2)
