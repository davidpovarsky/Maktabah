"""New downstream flag/plan boundaries; no old suite, Ruby, or Apple execution."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

BASE = Path(__file__).resolve().parents[1]
CI = BASE / 'candidate/Scripts/CI'
CLANG = runpy.run_path(str(CI / 'original_editor_clang_imports.py'))
HQ = runpy.run_path(str(CI / 'hq-original-editor-distribution.py'))

def raw_json(value): return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()

class ConsumerContext(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='otzaria consumer context ')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.distribution = self.root / 'build/original-sdk'
        self.distribution.mkdir(parents=True)
        self.identity = {'source_sha': 'a' * 40, 'run_id': '1', 'run_attempt': '1', 'original_package_lock_sha256': 'b' * 64}
        maps, headers, files, provenance = [], [], {}, []
        for number in range(19):
            root = 'Clang/Packages/package' + str(number) + '/include'
            module = root + '/module.modulemap'
            headers.append(root)
            maps.append(module)
            for relative, raw in [(module, ('module Fixture' + str(number) + ' { header "header.h" export * }\n').encode()),
                                  (root + '/header.h', b'#pragma once\n')]:
                path = self.distribution / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
                files[relative] = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
            provenance.append({'path': module, 'exported_sha256': files[module]['sha256'],
                               'transformation': 'EXACT_ORIGINAL_TRACKED_BYTES'})
        value = {'schema': 1, 'status': 'ORIGINAL_CLANG_DECLARATIONS_EXPORTED_NOT_QUALIFIED', **self.identity,
                 'implementation_translation_units_exported_or_added': False, 'consumer_or_native_qualification': False,
                 'module_maps': maps, 'header_search_paths': headers, 'module_map_provenance': provenance, 'files': files}
        path = self.distribution / CLANG['MANIFEST']
        path.parent.mkdir(parents=True)
        path.write_bytes(raw_json(value))
        self.identity['manifest_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.context = CLANG['admitted_context'](self.distribution, self.identity)

    def test_nineteen_maps_and_headers_keep_all_compiler_argument_pairs(self):
        actual = CLANG['swift_import_arguments'](self.distribution, self.context)
        self.assertEqual(len(actual), 76)
        self.assertEqual(actual[::2], ['-Xcc'] * 38)
        self.assertEqual(actual[1:38:2], ['-I' + str(self.distribution / p) for p in self.context['header_search_paths']])
        self.assertEqual(actual[39::2], ['-fmodule-map-file=' + str(self.distribution / p) for p in self.context['module_maps']])
        self.assertFalse((self.distribution / 'Include').exists())

    def test_changed_admitted_map_order_cannot_reach_compiler(self):
        changed = copy.deepcopy(self.context)
        changed['module_maps'].reverse()
        with self.assertRaisesRegex(RuntimeError, 'context changed'):
            CLANG['swift_import_arguments'](self.distribution, changed)

    def test_changed_header_bytes_cannot_reach_compiler(self):
        (self.distribution / self.context['header_search_paths'][0] / 'header.h').write_bytes(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'declaration differs'):
            CLANG['swift_import_arguments'](self.distribution, self.context)

    def test_missing_context_has_no_conventional_include_fallback(self):
        with self.assertRaises(KeyError):
            CLANG['swift_import_arguments'](self.distribution, {})

    def prepare(self, schema):
        project = self.root / 'Maktabah.xcodeproj/project.pbxproj'
        project.parent.mkdir(parents=True)
        project.write_bytes(b'owned fixture project\n')
        probe = self.root / 'Scripts/CI/OriginalEditorDistributionAPICheck.swift'
        probe.parent.mkdir(parents=True)
        probe.write_bytes(b'// isolated probe-command fixture\n')
        # The new copied reader is an actual module in the temporary checkout.
        (probe.parent / 'original_editor_clang_imports.py').write_bytes((CI / 'original_editor_clang_imports.py').read_bytes())
        producer = {'toolchain': {'xcode': 'Xcode fixture'}}
        admitted = {'source_sha': self.identity['source_sha'], 'distribution_root': 'build/original-sdk',
                    'shared_package_revisions': {}, 'hanlin_source': {'files': {}, 'revision': 'fixture'},
                    'dynamic_frameworks': ['AnytypeOriginalEditor.framework']}
        if schema == 2:
            admitted.update(schema=2, framework_producer=producer, clang_import_context=self.context)
        report = {'swift': 'fixture swift', 'sdk_version': '27.0', 'sdk_path': '/fixture simulator SDK',
                  'xcode': 'Xcode fixture', 'package_pins': [], 'hanlin_sdk_source': {'git_blobs': [], 'sha': 'fixture'},
                  'native_context': {}}
        observed = {}
        def command(argv, **kwargs): observed['command'] = argv
        def logged(argv, label, report):
            plan = json.loads(Path(argv[3]).read_bytes())
            observed['plan'] = plan
            Path(argv[4]).write_bytes(raw_json({'before_project_sha256': plan['before_project_sha256'],
                'after_project_sha256': plan['before_project_sha256'], 'all_other_objects_unchanged': True}))
        globals_ = HQ['prepare'].__globals__
        with patch.dict(globals_, {'admit': lambda *a, **k: admitted,
                                  'shared_package_policy': lambda *a: {'swift_syntax_requires_actual_runtime_absence': False},
                                  'command': command}):
            HQ['prepare'](self.root, self.root / 'Scripts/CI/admission.json', report, self.root / 'build/output', logged)
        return observed

    def test_actual_prepare_wires_schema2_maps_into_probe_and_target_plan(self):
        observed = self.prepare(2)
        arguments = observed['command']
        self.assertEqual(arguments.count('-Xcc'), 38)
        self.assertTrue(all('-fmodule-map-file=' + str(self.distribution / p) in arguments for p in self.context['module_maps']))
        self.assertNotIn(str(self.distribution / 'Include'), arguments)
        self.assertEqual(observed['plan']['admission_schema'], 2)
        self.assertEqual(observed['plan']['clang_import_context'], self.context)

    def test_actual_prepare_retains_the_original_schema1_probe_and_plan(self):
        observed = self.prepare(1)
        expected = ['xcrun', 'swiftc', '-typecheck', '-parse-as-library', '-swift-version', '6', '-D', 'DEBUG',
                    '-sdk', '/fixture simulator SDK', '-target', 'arm64-apple-ios27.0-simulator',
                    '-F', str(self.distribution / 'Frameworks'), '-I', str(self.distribution / 'Modules'),
                    '-I', str(self.distribution / 'Include'), str(self.root / 'Scripts/CI/OriginalEditorDistributionAPICheck.swift')]
        self.assertEqual(observed['command'], expected)
        self.assertNotIn('admission_schema', observed['plan'])
        self.assertNotIn('clang_import_context', observed['plan'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--result', required=True, type=Path)
    arguments = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ConsumerContext)
    expected = [t.id().split('.')[-1] for t in suite]
    passed = []
    class Results(unittest.TextTestResult):
        def addSuccess(self, test):
            passed.append(test.id().split('.')[-1])
            super().addSuccess(test)
    outcome = unittest.TextTestRunner(verbosity=2, resultclass=Results).run(suite)
    result = {'status': 'PASS_NEW_CONSUMER_CLANG_BOUNDARIES' if outcome.wasSuccessful() else 'FAIL',
        'tests_run': outcome.testsRun, 'expected_ids': expected, 'passed_ids': passed,
        'failures': [str(t) for t,_ in outcome.failures], 'errors': [str(t) for t,_ in outcome.errors],
        'skipped': [str(t) for t,_ in outcome.skipped],
        'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(CI.iterdir()) if p.is_file()},
        'fixture_scope': 'Synthetic19-map headers plus actual prepare function; existing native admission/package gates and Ruby invocation are explicit doubles.',
        'prior_test_bodies_replayed': 0, 'ruby_or_apple_execution': False}
    arguments.result.parent.mkdir(parents=True, exist_ok=True)
    arguments.result.write_bytes(raw_json(result))
    raise SystemExit(0 if outcome.wasSuccessful() else 1)
