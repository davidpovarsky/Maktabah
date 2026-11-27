#!/usr/bin/env python3
"""Bounded immutable-checkout source controls; no SSH/Mac/native execution."""
import ast
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'offline-oracle/study-ui-offline-oracle.py'
if not SOURCE.exists(): SOURCE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-oracle.py'
BASELINE = HERE / 'baseline-4cb7590.py'
FIXTURES = HERE.parent / 'offline-oracle/source-controls.py'
EXPECTED = 'c' * 40


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


m, old, fixtures = load('checkout_candidate', SOURCE), load('checkout_baseline', BASELINE), load('original_43_fixtures', FIXTURES)
# Reuse the explicitly synthetic historical fixture bodies without running
# that historical test suite or changing its retained receipts/source.
fixtures.m = old


def launch(phase='offline-zayit'):
    value = fixtures.launch(phase)
    value['environment']['EXPECTED_CHECKOUT_SHA'] = EXPECTED
    return value


def boot(phase='offline-zayit'):
    value = fixtures.frames(phase)[0]
    value['checkoutSHA'] = EXPECTED
    return value


def remote_functions():
    tree = ast.parse(m.REMOTE_COMMON)
    tree.body = [node for node in tree.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
    values = {}
    exec(compile(tree, '<actual-fixed-remote-functions-no-top-level-runtime>', 'exec'), values)
    values['canonical'] = lambda value, directory=False: Path(value)
    return values


def completed(phase='offline-zayit'):
    collection, arguments = fixtures.complete(phase)
    arguments['state'].launch['environment']['EXPECTED_CHECKOUT_SHA'] = EXPECTED
    arguments['state'].boot['checkoutSHA'] = EXPECTED
    return collection, arguments


def ready_subject(checkout=EXPECTED):
    subject = m.OracleOfflineCoordinator.__new__(m.OracleOfflineCoordinator)
    subject.spec = launch()
    subject.state = m.EventState(subject.spec)
    subject.state.launch_frame(boot())
    subject.sources = fixtures.sources()
    subject.event_records = []
    subject.binding = subject.source_before = None
    subject.options = {'--offline-coordinator-wait-seconds': '300'}
    subject.output = Path('/synthetic/oracle/output')
    source = fixtures.source()
    source['checkout_sha'] = checkout
    ready = fixtures.frames()[1]
    source_record = fixtures.pack(fixtures.OUT + '/source-before.json', source)
    ready['sourceBefore'] = source_record['file']
    subject.rpc = Mock(return_value={'sources': fixtures.mac_sources(), 'readyRecord': fixtures.pack(
        fixtures.OUT + '/offline-control/00-CONTROLLER_READY.private.json', ready),
        'sourceBefore': source_record, 'actualUID': 501,
        'process': {'pid': 200, 'parentPID': 100, 'startUTC': boot()['startUTC'], 'command': 'synthetic original'}})
    subject.write = Mock(side_effect=lambda name, value: fixtures.fw(str(subject.output / name), m.json_bytes(value)))
    return subject, ready


class Controls(unittest.TestCase):
    def test_preserved_baseline_rejects_explicit_required_environment(self):
        self.assertEqual(hashlib.sha256(BASELINE.read_bytes()).hexdigest(),
            '9ea6eeffd4bef89d6f4c8107bf356b9157484552c8a0744b6893423c46594244')
        with self.assertRaises(ValueError): old.validate_launch(launch())

    def test_preserved_baseline_accepts_omission_that_original_core_refuses(self):
        self.assertIsInstance(old.validate_launch(fixtures.launch()), dict)

    def test_candidate_accepts_explicit_checkout_for_both_original_phases(self):
        for phase in m.CASE_IDS:
            with self.subTest(phase=phase): self.assertIsInstance(m.validate_launch(launch(phase)), dict)

    def test_candidate_rejects_missing_or_malformed_checkout(self):
        for value in (None, '', 'UNFINALIZED', 'c' * 39, 'c' * 41, 'C' * 40, 'g' * 40, 123, 'c' * 40 + '\n'):
            with self.subTest(value=value):
                spec = launch()
                if value is None: spec['environment'].pop('EXPECTED_CHECKOUT_SHA')
                else: spec['environment']['EXPECTED_CHECKOUT_SHA'] = value
                with self.assertRaises(ValueError): m.validate_launch(spec)

    def test_original_unmodified_frozen_core_requires_this_exact_environment(self):
        read = json.loads((HERE / 'ORIGINAL_ENVIRONMENT_READ.json').read_text())
        source = read['inputs']['original-source-build']['files']['reader-full-v32-ui-observation.py']['functions']['source_context']
        with tempfile.TemporaryDirectory() as folder:
            inputs = Path(folder) / 'synthetic-inputs.json'
            trees = {name: 'd' * 40 for name in ('Source', 'Vendor', 'Maktabah.xcodeproj', 'Maktabah-iOSUITests')}
            inputs.write_text(json.dumps({'schema': 'synthetic', 'selected_case_ids': [],
                'application_source_sha': EXPECTED, 'application_trees': trees, 'execution_input_paths': []}))
            values = {'json': json, 're': m.re, 'os': os, 'INPUTS': inputs, 'OBSERVATION_SCHEMA': 'synthetic',
                'SELECTED': [], 'require': m.require, 'ROOT': Path(folder), 'digest': lambda p: hashlib.sha256(p.read_bytes()).hexdigest(),
                'git': lambda *args: EXPECTED if args == ('rev-parse', 'HEAD') else 'd' * 40,
                'command': lambda *args, **kwargs: types.SimpleNamespace(returncode=0)}
            exec(compile(source, '<retained-original-source_context>', 'exec'), values)
            for environment in ({}, {'EXPECTED_CHECKOUT_SHA': 'a' * 40}):
                with patch.dict(os.environ, environment, clear=True):
                    with self.assertRaisesRegex(ValueError, 'Wrong immutable checkout'): values['source_context'](True)
            with patch.dict(os.environ, {'EXPECTED_CHECKOUT_SHA': EXPECTED}, clear=True):
                self.assertEqual(values['source_context'](True)['checkout_sha'], EXPECTED)

    def test_actual_fixed_remote_checkout_reads_head_with_bounded_original_git(self):
        values = remote_functions()
        command = Mock(return_value=types.SimpleNamespace(returncode=0, stdout=(EXPECTED + '\n').encode(), stderr=b''))
        values['subprocess'] = types.SimpleNamespace(run=command)
        self.assertEqual(values['checkout']({'launch': launch()}), EXPECTED)
        command.assert_called_once_with(['git', '-C', fixtures.MAC, 'rev-parse', 'HEAD'], capture_output=True, timeout=5)

    def test_remote_checkout_refuses_failed_ambiguous_or_changed_head(self):
        for exit_code, stdout, stderr in ((1, b'', b''), (0, (EXPECTED + '\n').encode(), b'error'),
                (0, ('a' * 40 + '\n').encode(), b''), (0, b'', b'')):
            with self.subTest(exit=exit_code, stdout=stdout, stderr=stderr):
                values = remote_functions()
                values['subprocess'] = types.SimpleNamespace(run=Mock(return_value=types.SimpleNamespace(
                    returncode=exit_code, stdout=stdout, stderr=stderr)))
                with self.assertRaises(ValueError): values['checkout']({'launch': launch()})

    def test_fixed_bootstrap_proves_head_before_any_original_exec(self):
        class ReachedOriginalExec(Exception): pass
        for actual in (EXPECTED, 'a' * 40):
            with self.subTest(actual=actual):
                values = remote_functions()
                spec = launch()
                values['payload'] = {'launch': spec}
                values['sources'] = lambda payload: {'Scripts/CI/production-study-v40-ui.py': spec['controller']}
                values['verified'] = lambda witness: b'synthetic'
                values['subprocess'] = types.SimpleNamespace(run=Mock(return_value=types.SimpleNamespace(
                    returncode=0, stdout=(actual + '\n').encode(), stderr=b'')))
                execve = Mock(side_effect=ReachedOriginalExec)
                values['os'] = types.SimpleNamespace(getpid=lambda: 200, getppid=lambda: 100, geteuid=lambda: 501,
                    chdir=Mock(), execve=execve, environ={'EXPECTED_CHECKOUT_SHA': 'b' * 40})
                values['process'] = lambda pid: {'parentPID': 100, 'startUTC': boot()['startUTC']}
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    with self.assertRaises(ReachedOriginalExec if actual == EXPECTED else ValueError):
                        exec(compile(m.REMOTE_START[len(m.REMOTE_COMMON):], '<actual-fixed-bootstrap-with-stubbed-boundaries>', 'exec'), values)
                if actual == EXPECTED:
                    self.assertEqual(execve.call_args.args[2]['EXPECTED_CHECKOUT_SHA'], EXPECTED)
                    self.assertEqual(json.loads(output.getvalue().removeprefix(m.BOOT_MARKER))['checkoutSHA'], EXPECTED)
                else:
                    execve.assert_not_called()
                    self.assertEqual(output.getvalue(), '')

    def test_launch_frame_binds_observed_head_to_supplied_value(self):
        m.EventState(launch()).launch_frame(boot())
        for value in (None, 'a' * 40):
            changed = boot()
            if value is None: changed.pop('checkoutSHA')
            else: changed['checkoutSHA'] = value
            with self.assertRaises(ValueError): m.EventState(launch()).launch_frame(changed)

    def test_original_ready_is_published_only_after_same_checkout_binding(self):
        subject, event = ready_subject()
        with contextlib.redirect_stdout(io.StringIO()): subject.received(m.EVENT_MARKER + json.dumps(event))
        self.assertEqual(subject.source_before['checkout_sha'], EXPECTED)
        self.assertEqual(sum(call.args[0] == 'READY.private.json' for call in subject.write.call_args_list), 1)
        subject, event = ready_subject('a' * 40)
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, 'immutable checkout'): subject.received(m.EVENT_MARKER + json.dumps(event))
        self.assertEqual(sum(call.args[0] == 'READY.private.json' for call in subject.write.call_args_list), 0)
        self.assertIsNone(subject.binding)

    def test_final_original_join_accepts_both_phases_only_with_same_checkout(self):
        for phase in m.CASE_IDS:
            collection, arguments = completed(phase)
            self.assertIsInstance(m.validate_final(collection, **arguments), dict)
            arguments['state'].launch['environment']['EXPECTED_CHECKOUT_SHA'] = 'a' * 40
            with self.assertRaisesRegex(ValueError, 'immutable checkout'): m.validate_final(collection, **arguments)

    def test_source_and_fixed_remote_programs_parse_without_import_execution(self):
        for source in (SOURCE.read_text(), m.REMOTE_COMMON, m.REMOTE_START, m.REMOTE_RPC): ast.parse(source)
        self.assertEqual([n for n in ast.parse(SOURCE.read_text()).body if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)], [])

    def test_actual_corrected_root_source_closure_covers_every_bridge_input(self):
        retained = json.loads((HERE / 'ROOT_CLOSURE_INPUT.json').read_text())
        self.assertEqual(retained['source']['sha256'], '887196e04b721491e629afba55ed239533d78b1f5e3da7004e9c6cf21a5f3755')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            main = root / 'Scripts/CI/production-study-v40-ui.py'
            values = {'__file__': str(main), 'ROOT': root, 'Path': Path, 're': m.re, 'require': m.require,
                      'PHASES': retained['offlinePhases']}
            exec(compile(retained['filesSource'] + '\n' + retained['sourceContext'], '<actual-root-source-projection>', 'exec'), values)
            declarations = '\n'.join('class ' + klass + ' { func ' + method + '() {} }'
                for phase in retained['offlinePhases'].values() for klass, method in [phase['cases'][0].split('/')])
            for name in ['Scripts/CI/production-study-v40-ui.py', *values['FILES']]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(declarations if name.endswith('.swift') else 'synthetic actual file for closure only\n')
            core = types.SimpleNamespace(source_context=lambda require_frozen: {'checkout_sha': EXPECTED},
                command=lambda args: types.SimpleNamespace(stdout='same-synthetic-git-blob'), git=lambda *args: 'same-synthetic-git-blob',
                witness=lambda path: fixtures.fw(str(path), path.read_bytes()))
            expected = {'Scripts/CI/' + name: core.witness(root / 'Scripts/CI' / name) for name in m.SOURCE_NAMES}
            for phase in m.CASE_IDS:
                context = values['source_context'](core, phase, True)
                m.validate_sources(context['study_ui_execution_sources'], expected, str(root))
                self.assertEqual(context['executed_case_ids'], [m.CASE_IDS[phase]])
                self.assertEqual(retained['offlinePhases'][phase]['allowance'], 1800)
            values['FILES'] = [p for p in values['FILES'] if p != 'Scripts/CI/runtime27_interruption.py']
            omitted = values['source_context'](core, 'offline-zayit', True)
            with self.assertRaisesRegex(ValueError, 'source closure is incomplete'):
                m.validate_sources(omitted['study_ui_execution_sources'], expected, str(root))


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    report = {'scope': 'BOUNDED_SOURCE_ENVIRONMENT_BASELINE_CANDIDATE_AND_STUBBED_LIFECYCLE_CONTROLS_ONLY',
        'baselineSHA256': hashlib.sha256(BASELINE.read_bytes()).hexdigest(),
        'candidateSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'originalEnvironmentReadSHA256': hashlib.sha256((HERE / 'ORIGINAL_ENVIRONMENT_READ.json').read_bytes()).hexdigest(),
        'testsRun': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'actualSSH': 0, 'actualMac': 0, 'actualNetworkDenial': 0, 'actualNativeCases': 0, 'actualSignals': 0}
    (HERE / 'SOURCE_CONTROLS.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
