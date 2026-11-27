#!/usr/bin/env python3
"""Focused source controls for the new phase/owned cleanup; no Apple execution.

All devices, processes, kernel identities and signals below are explicit
synthetic doubles. Real local temporary files exercise receipt sealing only.
The original controller controls are imported unchanged, not replaced by these.
"""
import argparse
import ast
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('--candidate', type=Path, default=HERE / 'production-study-v40-ui.py')
parser.add_argument('--owner', type=Path, default=HERE / 'study-ui-pending-execution.py')
parser.add_argument('--original-controls', type=Path, default=HERE.parent / 'study-ui-driver-draft/test_study_ui_driver.py')
parser.add_argument('--interruption', type=Path, default=HERE / 'input-original/runtime27_interruption.py')
parser.add_argument('--coordinator', type=Path, default=HERE.parent / 'offline-oracle/study-ui-offline-oracle.py')
parser.add_argument('--v40-inputs', type=Path, default=HERE / 'reader-full-v40-ui-observation.inputs.json')
ARGS, REST = parser.parse_known_args()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


with patch.object(sys, 'argv', [str(ARGS.original_controls), '--candidate', str(ARGS.candidate)]):
    BASE = module('pending_original_controller_controls', ARGS.original_controls)
D = BASE.DRIVER
M = module('pending_owned_execution_controls', ARGS.owner)
ORIGINAL_INTERRUPTION = runpy.run_path(str(ARGS.interruption))


class PendingScenario(BASE.Scenario):
    def __init__(self, root):
        super().__init__(root, 'reader-pending-sql')
        self.core.source_context = lambda require_frozen: self.source
        self.fail_start = self.fail_stop = self.fail_admission = False
        self.bound_calls = 0
        scenario = self
        class Host:
            def __init__(self, **kwargs):
                self.runner = NS(original=scenario.core)
                self.cleanup_verified = False
                self.token = 'synthetic-token'
                scenario.events.append('pending-constructed')
            def start(self):
                scenario.events.append('pending-start')
                if scenario.fail_start: raise ValueError('synthetic start interrupted')
                return {'TEST_RUNNER_SYNTHETIC_PENDING_CONTROL': '1'}
            def private_tokens(self): return (self.token,)
            def stop(self):
                scenario.events.append('pending-stop')
                self.cleanup_verified = not scenario.cleanup_failure
                if scenario.fail_stop or scenario.cleanup_failure: raise ValueError('synthetic host incomplete')
                return {'scope': 'synthetic pending proof only'}
            def abort(self):
                scenario.events.append('pending-abort')
                self.cleanup_verified = not scenario.cleanup_failure
                return {'verified': self.cleanup_verified}
        def bind(core, owner, original, config, udid, build):
            self.bound_calls += 1
            self.events.append('passive-admission')
            assert core.source_context(require_frozen=True) == json.loads((core.OUT / 'source-before.json').read_text())
            if self.fail_admission: raise ValueError('synthetic admission rejected')
            return original(config, udid, build)
        self.modules.update({
            'study-ui-pending-sql.py': NS(load_wait=lambda root: NS(bind_admission=bind)),
            'study-ui-pending-execution.py': NS(PendingStudyCase=Host),
        })

    def run_case(self, core, *args, **kwargs):
        assert core.original is self.core
        self.events.append('owned-native-runner')
        return super().run_case(core, *args, **kwargs)


class PendingPhaseControls(unittest.TestCase):
    def scenario(self):
        temp = tempfile.TemporaryDirectory(prefix='pending-phase-source-control-')
        self.addCleanup(temp.cleanup)
        return PendingScenario(Path(temp.name))

    def test_phase_is_one_separate_required_preupdate_case(self):
        value = D.PHASES['reader-pending-sql']
        self.assertEqual(len(value['cases']), 1)
        self.assertEqual(value['allowance'], 1800)
        self.assertEqual(value['payload_peak'], 768 * 1024 * 1024)
        self.assertEqual(D.PRE_UPDATE_PHASES['reader-pending-sql'], value['cases'])

    def test_complete_coordinator_and_pending_source_closures_are_registered(self):
        tree = ast.parse(ARGS.coordinator.read_text())
        declaration = next(node for node in tree.body if isinstance(node, ast.Assign)
                           and any(isinstance(target, ast.Name) and target.id == 'SOURCE_NAMES' for target in node.targets))
        names = {'Scripts/CI/' + name for name in ast.literal_eval(declaration.value)}
        self.assertLessEqual(names, set(D.FILES) | {'Scripts/CI/production-study-v40-ui.py'})
        config = json.loads(ARGS.v40_inputs.read_text())
        required = {'Scripts/CI/study-ui-pending-sql.py', 'Scripts/CI/study-ui-pending-execution.py',
                    'Scripts/CI/reader-v40-perbook-mode-performance.py',
                    'Maktabah-iOSUITests/Build8401SevenDefectsAcceptanceTests.swift',
                    'docs/hq-integration/wave2-20261127/reader/FullV40ObservationCatalog.swift'}
        self.assertLessEqual(required, set(config['execution_input_paths']))

    def test_success_uses_one_actual_admission_and_owner_before_retention(self):
        s = self.scenario(); error, result = s.run()
        self.assertIsNone(error)
        self.assertEqual(s.bound_calls, 1)
        self.assertEqual(s.native_calls, 1)
        self.assertEqual(result['status'], D.STUDY_PASS)
        ordered = ['passive-admission', 'pending-constructed', 'pending-start', 'owned-native-runner',
                   'synthetic-ui-result', 'pending-stop', 'images-verified', 'simulator-retained']
        self.assertEqual([v for v in s.events if v in ordered], ordered)

    def test_failed_native_is_not_accepted_and_host_stops_first(self):
        s = self.scenario(); s.native_failure = True
        error, result = s.run()
        self.assertIsNotNone(error)
        self.assertNotIn('pending-stop', s.events)
        self.assertLess(s.events.index('pending-abort'), s.events.index('simulator-retained'))
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_start_failure_keeps_owned_host_for_cleanup(self):
        s = self.scenario(); s.fail_start = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.native_calls, 0)
        self.assertIn('pending-abort', s.events)
        self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_unverified_cleanup_never_retains_simulator(self):
        s = self.scenario(); s.cleanup_failure = True
        error, result = s.run()
        self.assertIsNotNone(error)
        self.assertNotIn('simulator-retained', s.events)
        self.assertEqual(result['owned_cleanup']['status'], 'NOT_SHUT_DOWN_HOST_CLEANUP_UNVERIFIED')

    def test_host_incomplete_cannot_pass_after_native_success(self):
        s = self.scenario(); s.fail_stop = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')

    def test_original_admission_rejection_never_launches_pending_case(self):
        s = self.scenario(); s.fail_admission = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(s.native_calls, 0)
        self.assertNotIn('pending-constructed', s.events)

    def test_post_source_failure_cannot_promote_completed_host(self):
        s = self.scenario(); s.source_changed = True
        error, result = s.run()
        self.assertIsNotNone(error); self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')
        self.assertTrue(any(value.startswith('source_build:') for value in result['post_verification_failures']))


class Child:
    pid = 424242
    def __init__(self):
        self.returncode = None
        self.stdout, self.stderr = io.StringIO(), io.StringIO()
        self.group_alive = True
        self.fail_wait = False
    def poll(self): return self.returncode
    def wait(self, timeout):
        if self.fail_wait: raise subprocess.TimeoutExpired(['synthetic'], timeout)
        self.returncode = 0; self.group_alive = False; return 0
    def communicate(self, timeout): self.wait(timeout); return 'original synthetic stdout', ''


class OwnedLifetimeControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pending-owner-source-control-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.child, self.signals, self.foreign = Child(), [], None
        self.core = NS(ROOT=self.root, write=BASE.write, witness=BASE.witness)
        self.stack = contextlib.ExitStack(); self.addCleanup(self.stack.close)
        def read_process(pid):
            if self.foreign is not None: return self.foreign
            if self.child.returncode is not None: return None
            return {'pid': pid, 'parentPID': os.getpid(), 'startUTC': 'synthetic-original-start',
                    'command': 'synthetic-original-command'}
        def signal_group(pgid, kind):
            self.signals.append((pgid, kind))
            if not self.child.group_alive: raise ProcessLookupError()
            if kind:
                self.child.group_alive = False; self.child.returncode = -int(kind)
        self.stack.enter_context(patch.object(M.runpy, 'run_path', side_effect=lambda p:
            {'process': read_process} if p.endswith('study-ui-offline-window.py') else ORIGINAL_INTERRUPTION))
        self.stack.enter_context(patch.object(M.subprocess, 'Popen', return_value=self.child))
        self.stack.enter_context(patch.object(M.os, 'getpgid', return_value=self.child.pid))
        self.stack.enter_context(patch.object(M.os, 'killpg', side_effect=signal_group))
        self.runner = M.OwnedOriginalRunner(self.core, self.root / 'processes')

    def test_command_keeps_original_output_and_seals_actual_exit(self):
        value = self.runner.command(['synthetic-native-command'])
        self.assertEqual(value.stdout, 'original synthetic stdout')
        self.assertTrue(self.runner.verify_exits())
        self.assertTrue(all(kind == 0 for _, kind in self.signals))

    def test_bounded_timeout_stops_only_verified_live_original_group(self):
        self.child.fail_wait = True
        with self.assertRaises(subprocess.TimeoutExpired):
            self.runner.bounded(['synthetic-native-command'], self.root / 'native.log', 1)
        self.assertTrue(self.runner.verify_exits())
        self.assertIn((self.child.pid, signal.SIGINT), self.signals)

    def test_known_handle_assignment_gap_is_swept(self):
        self.runner.spawn(['synthetic-native-command'], phase='synthetic-assignment-gap')
        self.assertEqual(self.runner.finish_unfinished_handles(), [])
        self.assertTrue(self.runner.verify_exits())
        self.assertIsNotNone(self.child.returncode)

    def test_unknown_interrupted_spawn_does_not_infer_exit(self):
        with patch.object(M.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic start gap')):
            with self.assertRaises(KeyboardInterrupt):
                self.runner.spawn(['synthetic-native-command'], phase='synthetic-unknown-spawn')
        self.assertEqual(self.runner.finish_unfinished_handles(), [])
        self.assertFalse(self.runner.verify_exits()); self.assertEqual(self.signals, [])

    def test_live_reused_pid_is_never_signaled_after_original_exit(self):
        child = self.runner.spawn(['synthetic-native-command'], phase='synthetic-reused-pid')
        self.child.returncode = 0
        self.foreign = {'pid': child.pid, 'parentPID': os.getpid(), 'startUTC': 'synthetic-foreign-start',
                        'command': 'foreign command'}
        with self.assertRaisesRegex(ValueError, 'reused PID'):
            self.runner.finish(child)
        self.assertEqual(self.signals, []); self.assertFalse(self.runner.verify_exits())

    def test_absent_leader_with_remaining_group_is_not_adopted(self):
        child = self.runner.spawn(['synthetic-native-command'], phase='synthetic-remaining-group')
        self.child.returncode = 0; self.child.group_alive = True
        with self.assertRaisesRegex(ValueError, 'no verifiable original live leader'):
            self.runner.finish(child)
        self.assertTrue(all(kind == 0 for _, kind in self.signals))
        self.assertFalse(self.runner.verify_exits())

    def test_failed_cleanup_is_not_repeated_by_outer_sweep(self):
        child = self.runner.spawn(['synthetic-native-command'], phase='synthetic-once-only')
        self.child.returncode = 0; self.child.group_alive = True
        with self.assertRaises(ValueError): self.runner.finish(child)
        prior = list(self.signals)
        self.assertEqual(self.runner.finish_unfinished_handles(), [])
        self.assertEqual(self.signals, prior); self.assertFalse(self.runner.verify_exits())

    def test_receipt_enospc_cannot_authorize_handoff(self):
        child = self.runner.spawn(['synthetic-native-command'], phase='synthetic-enospc')
        self.child.returncode = 0; self.child.group_alive = False
        with patch.object(self.core, 'write', side_effect=OSError(28, 'synthetic ENOSPC')):
            with self.assertRaises(OSError): self.runner.finish(child)
        self.assertTrue(self.runner.rows[0]['verified'])
        self.assertIsNone(self.runner.rows[0]['receipt'])
        self.assertFalse(self.runner.verify_exits())

    def test_phase_seal_enospc_preserves_memory_but_not_cleanup_permission(self):
        wait = NS(seal=lambda *args: (_ for _ in ()).throw(OSError(28, 'synthetic phase seal ENOSPC')))
        pending = NS(load_wait=lambda root: wait)
        case = M.PendingStudyCase(core=self.core, settings=None, pending=pending, config={},
            udid=BASE.UDID, container=self.root, installation={}, output=self.root, reserved_other_bytes=0)
        with self.assertRaises(OSError): case.close()
        self.assertIsNotNone(case.cleanup_state)
        self.assertIsNone(case.cleanup_receipt); self.assertFalse(case.cleanup_verified)
        self.assertFalse(case.abort()['verified'])

    def test_passive_observer_receives_original_core_not_command_inventory(self):
        observed = {}
        def observer(core, *args):
            observed['observerCore'] = core
            return NS(host=NS(token='synthetic-observer'), start=lambda: {'synthetic-observer': '1'})
        def compile_catalog(core, *args, **kwargs):
            observed['compilerCore'] = core
            return {'scope': 'synthetic catalog only'}
        pending = NS(load_wait=lambda root: NS(), prepare_catalog=compile_catalog, PendingSQLHost=observer)
        case = M.PendingStudyCase(core=self.core, settings=None, pending=pending, config={},
            udid=BASE.UDID, container=self.root, installation={}, output=self.root, reserved_other_bytes=0)
        delivery = lambda *args: NS(start=lambda: {'synthetic-url': '1'}, token='synthetic-url')
        with patch.object(case.runner, 'original_url_class', return_value=delivery):
            case.start()
        self.assertIs(observed['observerCore'], self.core)
        self.assertIs(observed['compilerCore'], case.runner)


class RetainedCleanupControls(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pending-retained-cleanup-control-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        def read(reference):
            if BASE.witness(reference['path']) != reference:
                raise ValueError('Synthetic immutable receipt changed')
            return json.loads(Path(reference['path']).read_text())
        self.evidence = NS(read_witness=read)
        command = ['xcodebuild', 'test-without-building', '-resultBundlePath', str(self.root / 'case/original.xcresult')]
        self.report = {'case_results': [{'passed': True, 'command': command, 'xcodebuild_exit': 0,
                                        'case_directory': str(self.root / 'case')}]}
        observer = {'ownedActivityExited': True, 'originalObserverThreadExited': True,
                    'passiveProbeWriterExited': True, 'stopError': None}
        BASE.write(self.root / 'pending-fetch-cleanup.json', observer)
        rows = []
        for number, (phase, args, code) in enumerate([
                ('bounded-original-command', command, 0),
                ('original-url-transport', ['synthetic-original-url'], -15)], 1):
            row = {'phase': phase, 'command': args, 'ownedPID': number + 1000,
                   'cleanupAttempted': True, 'verified': True, 'leaderExit': code,
                   'originalCleanup': {'group_state': 'GONE_CHECKED', 'owned_pgid': number + 1000}}
            path = self.root / 'pending-owned-processes' / (str(number) + '-cleanup.json')
            BASE.write(path, row); row['receipt'] = BASE.witness(path); rows.append(row)
        self.state = {'schema': 'otzaria.original-pending-phase-cleanup/1', 'verified': True,
            'observerConstructed': True, 'observerAcceptanceError': None, 'urlError': None,
            'unfinishedHandleCleanupErrors': [], 'urlStartAttempted': True, 'urlStopAttempted': True,
            'urlPID': 1002, 'urlExit': -15, 'observerCleanup': BASE.witness(self.root / 'pending-fetch-cleanup.json'),
            'observerState': observer, 'ownedProcesses': rows}
        self.seal()

    def seal(self):
        BASE.write(self.root / 'pending-phase-cleanup.json', self.state)
        self.value = {'fullPerformanceAcceptance': False,
                      'cleanup': BASE.witness(self.root / 'pending-phase-cleanup.json')}

    def test_revalidates_exact_native_and_owned_exit_receipts(self):
        result = M.validate_cleanup(self.value, self.evidence, self.report)
        self.assertEqual(len(result['ownedProcessReceipts']), 2)

    def test_another_native_command_cannot_supply_the_exit_proof(self):
        self.report['case_results'][0]['command'] = ['xcodebuild', 'another-original-case']
        with self.assertRaisesRegex(ValueError, 'real URL transport and native test'):
            M.validate_cleanup(self.value, self.evidence, self.report)

    def test_another_phase_cannot_supply_an_identical_cleanup_file(self):
        other = self.root / 'other/pending-phase-cleanup.json'; BASE.write(other, self.state)
        self.value['cleanup'] = BASE.witness(other)
        with self.assertRaisesRegex(ValueError, 'another phase directory'):
            M.validate_cleanup(self.value, self.evidence, self.report)

    def test_changed_original_cleanup_bytes_are_rejected(self):
        path = Path(self.state['ownedProcesses'][0]['receipt']['path'])
        BASE.write(path, {'scope': 'changed synthetic source receipt'})
        with self.assertRaisesRegex(ValueError, 'receipt changed'):
            M.validate_cleanup(self.value, self.evidence, self.report)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0], *REST], verbosity=2)
