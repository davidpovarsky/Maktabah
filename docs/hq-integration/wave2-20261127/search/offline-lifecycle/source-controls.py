#!/usr/bin/env python3
"""Explicit synthetic lifecycle controls; no SSH/Mac/PF/native or real signals."""
import ast
import copy
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import types
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
ORACLE = HERE.parent / 'offline-oracle/study-ui-offline-oracle.py'
EXERCISES = HERE.parent / 'offline-exercises/study-ui-offline-exercises.py'
INTERRUPTION = HERE.parent / 'root-study-offline/input-original/runtime27_interruption.py'
if not ORACLE.exists():
    ORACLE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-oracle.py'
    EXERCISES = HERE.parents[4] / 'Scripts/CI/study-ui-offline-exercises.py'
    INTERRUPTION = HERE.parents[4] / 'Scripts/CI/runtime27_interruption.py'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def baseline(name, filename):
    path = HERE / filename
    expected = json.loads((HERE / 'BASELINE_INPUTS.json').read_text())[filename]
    raw = gzip.decompress(path.read_bytes())
    assert len(raw) == expected['uncompressedBytes']
    assert hashlib.sha256(raw).hexdigest() == expected['uncompressedSHA256']
    result = types.ModuleType(name)
    result.__file__ = str(path)
    exec(compile(raw, str(path) + ':whole-original-source', 'exec'), result.__dict__)
    return result


m, e = load('lifecycle_oracle', ORACLE), load('lifecycle_exercises', EXERCISES)
old_m = baseline('baseline_oracle', 'baseline-oracle-1d5140.py.gz')
old_e = baseline('baseline_exercises', 'baseline-exercises-8dba.py.gz')
original = load('actual_original_interruption', INTERRUPTION)


def identity(pid=200):
    return {'pid': pid, 'parentPID': os.getpid(), 'startUTC': 'Fri Nov 27 09:00:00 2026',
            'command': '/synthetic/ssh fixed'}


def stopped(pid=200):
    return {'process': identity(pid), 'createdChildPID': pid,
        'group': {'owned_pgid': pid, 'group_state': 'GONE_CHECKED'},
        'subprocess': {'pid': pid, 'state': 'EXITED', 'returncode': 0}, 'actualProcessAbsent': True}


def fake_child(operation='collect', pid=200):
    child = Mock(pid=pid, returncode=0)
    child.poll.return_value = 0
    child.communicate.return_value = (m.json_bytes({'schema': 'otzaria.offline-oracle-rpc/1', 'operation': operation}), b'')
    return child


def coordinator(module):
    subject = module.OracleOfflineCoordinator.__new__(module.OracleOfflineCoordinator)
    memory, values = {}, {}
    def write(name, value):
        raw = module.json_bytes(value)
        path = '/synthetic/oracle/output/' + name
        memory[path] = raw
        values[name] = json.loads(raw)
        return {'path': path, 'bytes': len(raw), 'sha256': module.sha(raw)}
    subject.write = write
    subject.window = types.SimpleNamespace(process=Mock(return_value=None), strict_json=module.strict_json,
        read_bytes=lambda path: memory[str(path)])
    subject.exercises = types.SimpleNamespace(new_directory=lambda path: Path(path), stop_owned=Mock(return_value=stopped()))
    subject.interruption = Mock()
    subject.root, subject.output = Path('/synthetic/oracle'), Path('/synthetic/oracle/output')
    subject.spec, subject.sources = {'syntheticOnly': True}, {}
    subject.command = Mock(return_value=['/synthetic/ssh', 'fixed'])
    subject.command_argv, subject.parent_pid = ['/synthetic/ssh', 'fixed'], os.getpid()
    subject.child = subject.identity = subject.owned_stop = subject.final_collection = None
    subject.owned_attempts, subject.owned_handles, subject.cleanup_history = [], {}, []
    subject.remote_interrupt_attempted = False
    subject.remote_interrupt_result = subject.remote_interrupt_error = None
    subject.cleanup_receipt = None
    subject.stdin_thread, subject.stdin_error, subject.stdin_start_attempted = None, None, False
    subject.captures, subject.rpc_records, subject.event_records, subject.errors = [], [], [], []
    subject.relay = subject.relay_result = subject.binding = subject.response_record = subject.mac_relay_rows = None
    subject.source_record, subject.input_record = {}, {}
    subject.source_before, subject.response = {}, None
    subject.state = types.SimpleNamespace(boot=None)
    subject.outer_deadline = time.monotonic() + 120
    subject.join = Mock()
    subject.settings = Mock()
    subject._memory, subject._written = memory, values
    return subject


def private_stub(path, raw):
    return {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def cleanup_value(subject):
    return json.loads(subject._memory[subject.cleanup_receipt['path']])


class KernelModel:
    """No OS actions: explicit Popen/process/group observations for one child."""
    def __init__(self, *, alive=True, survivor=False, group_alive=True, reused=False):
        self.child = types.SimpleNamespace(pid=200, returncode=None if alive else 0)
        self.child.poll = lambda: self.child.returncode
        self.current = identity() if alive else (dict(identity(), startUTC='different-process') if reused else None)
        self.group_alive, self.survivor = group_alive, survivor
        self.calls, self.clock = [], 0.0
        self.window = types.SimpleNamespace(process=lambda pid: copy.deepcopy(self.current))
        self.helper = types.SimpleNamespace(stop_owned_process_group=self.group,
            stop_owned_subprocess=Mock(side_effect=lambda child: {'pid': child.pid, 'state': 'EXITED', 'returncode': child.poll()}))

    def killpg(self, pid, kind):
        assert pid == 200
        self.calls.append(int(kind))
        if not self.group_alive: raise ProcessLookupError()
        if kind:
            self.child.returncode, self.current = 0, None
            if not self.survivor or kind == signal.SIGKILL: self.group_alive = False

    def monotonic(self):
        self.clock += .4
        return self.clock

    def group(self, child, **kwargs):
        kwargs.setdefault('killpg_fn', self.killpg)
        kwargs.update(sleep_fn=lambda seconds: None, monotonic_fn=self.monotonic)
        return original.stop_owned_process_group(child, **kwargs)

    def run(self, module, expected=None):
        if expected is None: expected = identity()
        with patch.object(module.os, 'killpg', side_effect=self.killpg), patch.object(module.os, 'getpgid', return_value=200):
            return module.stop_owned(self.window, self.helper, self.child, expected)


class Controls(unittest.TestCase):
    def test_whole_preserved_baseline_unknown_controller_spawn_falsely_reports_stopped(self):
        subject = coordinator(old_m)
        with patch.object(old_m.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic interrupted spawn')):
            with self.assertRaises(KeyboardInterrupt): subject.start()
        subject.cleanup(False)
        self.assertTrue(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])

    def test_candidate_unknown_controller_spawn_stays_unverified(self):
        subject = coordinator(m)
        with patch.object(m.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic interrupted spawn')):
            with self.assertRaises(KeyboardInterrupt): subject.start()
        subject.cleanup(False)
        value = cleanup_value(subject)
        self.assertFalse(value['ownedLocalProcessesAndStreamsStopped'])
        self.assertEqual(value['ownedChildren'][0]['errorType'], 'SpawnAttemptWithoutReturnedHandle')
        subject.exercises.stop_owned.assert_not_called()

    def test_whole_preserved_baseline_unknown_rpc_spawn_falsely_reports_stopped(self):
        subject = coordinator(old_m)
        with (patch.object(old_m.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic RPC spawn')),
                patch.object(old_m, 'private_raw', side_effect=private_stub)):
            with self.assertRaises(KeyboardInterrupt): subject.rpc('collect')
        subject.cleanup(False)
        self.assertTrue(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])

    def test_candidate_unknown_rpc_spawn_is_in_final_cleanup(self):
        subject = coordinator(m)
        with (patch.object(m.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic RPC spawn')),
                patch.object(m, 'private_raw', side_effect=private_stub)):
            with self.assertRaises(KeyboardInterrupt): subject.rpc('collect')
        subject.cleanup(False)
        self.assertFalse(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])
        self.assertEqual(cleanup_value(subject)['ownedChildren'][0]['kind'], 'rpc:collect')

    def test_whole_preserved_baseline_failed_known_rpc_stop_is_omitted_from_cleanup(self):
        subject, child = coordinator(old_m), fake_child()
        subject.exercises.stop_owned.side_effect = ValueError('synthetic uncertain stop')
        with (patch.object(old_m.subprocess, 'Popen', return_value=child), patch.object(old_m, 'qualified_ssh_identity', return_value=identity()),
                patch.object(old_m, 'private_raw', side_effect=private_stub)):
            with self.assertRaises(ValueError): subject.rpc('collect')
        subject.cleanup(False)
        self.assertTrue(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])

    def test_candidate_failed_known_rpc_stop_blocks_cleanup_without_repeated_stop(self):
        subject, child = coordinator(m), fake_child()
        subject.exercises.stop_owned.side_effect = ValueError('synthetic uncertain stop')
        with (patch.object(m.subprocess, 'Popen', return_value=child), patch.object(m, 'qualified_ssh_identity', return_value=identity()),
                patch.object(m, 'private_raw', side_effect=private_stub)):
            with self.assertRaises(ValueError): subject.rpc('collect')
            subject.cleanup(False)
            subject.cleanup(True)
        value = cleanup_value(subject)
        self.assertFalse(value['ownedLocalProcessesAndStreamsStopped'])
        self.assertTrue(value['ownedChildren'][0]['cleanupAttempted'])
        self.assertFalse(value['ownedChildren'][0]['verified'])
        subject.exercises.stop_owned.assert_called_once()

    def test_known_handle_survives_interruption_before_controller_assignment(self):
        subject, child = coordinator(m), fake_child()
        actual_spawn = subject.spawn_child
        def interrupted_return(*args, **kwargs):
            actual_spawn(*args, **kwargs)
            raise KeyboardInterrupt('synthetic gap before caller assignment')
        subject.spawn_child = interrupted_return
        with patch.object(m.subprocess, 'Popen', return_value=child), patch.object(m, 'qualified_ssh_identity', return_value=identity()):
            with self.assertRaises(KeyboardInterrupt): subject.start()
            self.assertIsNone(subject.child)
            subject.cleanup(False)
        self.assertTrue(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])
        self.assertTrue(cleanup_value(subject)['ownedChildren'][0]['verified'])
        subject.exercises.stop_owned.assert_called_once()

    def test_sweep_continues_after_one_known_handle_stop_fails(self):
        subject, a, b = coordinator(m), fake_child(pid=200), fake_child(pid=201)
        with patch.object(m.subprocess, 'Popen', side_effect=[a, b]):
            subject.spawn_child(['/synthetic/ssh', 'fixed'], kind='rpc:first')
            subject.spawn_child(['/synthetic/ssh', 'fixed'], kind='rpc:second')
        def stop(window, interruption, child, actual):
            if child.pid == 200: raise ValueError('synthetic first stop failed')
            return stopped(201)
        subject.exercises.stop_owned.side_effect = stop
        with patch.object(m, 'qualified_ssh_identity', side_effect=lambda window, child, *rest: identity(child.pid)):
            subject.cleanup(False)
        rows = cleanup_value(subject)['ownedChildren']
        self.assertFalse(rows[0]['verified'])
        self.assertTrue(rows[1]['verified'])
        self.assertEqual(subject.exercises.stop_owned.call_count, 2)

    def test_repeated_successful_stop_returns_retained_proof_without_signal(self):
        subject, child = coordinator(m), fake_child()
        with patch.object(m.subprocess, 'Popen', return_value=child): subject.spawn_child(subject.command_argv, kind='controller')
        with patch.object(m, 'qualified_ssh_identity', return_value=identity()):
            first = subject.stop_child(child, identity(), subject.command_argv)
            second = subject.stop_child(child, identity(), subject.command_argv)
        self.assertEqual(first, second)
        subject.exercises.stop_owned.assert_called_once()

    def test_readback_rpc_invalidates_earlier_cleanup_and_final_receipt_includes_it(self):
        subject, child = coordinator(m), fake_child()
        first = subject.cleanup(False)
        with (patch.object(m.subprocess, 'Popen', return_value=child), patch.object(m, 'qualified_ssh_identity', return_value=identity()),
                patch.object(m, 'private_raw', side_effect=private_stub)):
            subject.rpc('collect')
        self.assertIsNone(subject.cleanup_receipt)
        last = subject.cleanup(False)
        self.assertNotEqual(first['path'], last['path'])
        self.assertEqual(subject.cleanup_history, [first, last])
        self.assertEqual(len(cleanup_value(subject)['ownedChildren']), 1)
        self.assertTrue(cleanup_value(subject)['ownedChildren'][0]['verified'])

    def test_final_evidence_readback_unknown_spawn_cannot_reuse_prior_clean_receipt(self):
        subject, child = coordinator(m), fake_child()
        with patch.object(m.subprocess, 'Popen', return_value=child): subject.child = subject.spawn_child(subject.command_argv, kind='controller')
        subject.start = subject.loop = Mock()
        with (patch.object(m, 'qualified_ssh_identity', return_value=identity()),
                patch.object(m.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic final readback spawn')),
                patch.object(m, 'private_raw', side_effect=private_stub)):
            with self.assertRaises(KeyboardInterrupt): subject.run()
        final = subject._written['RESULT.private.json']
        self.assertEqual(final['status'], 'FAILED_OR_INCOMPLETE')
        self.assertFalse(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])
        self.assertEqual(final['ownedCleanup'], subject.cleanup_receipt)
        self.assertEqual([r['kind'] for r in cleanup_value(subject)['ownedChildren']], ['controller', 'rpc:collect', 'rpc:collect'])

    def test_baseline_skips_remote_interrupt_after_original_ssh_disconnect(self):
        subject = coordinator(old_m)
        subject.child = fake_child()
        subject.state.boot = {'actualControllerPID': 300}
        subject.rpc = Mock()
        subject.stop_child = Mock(return_value=stopped())
        subject.cleanup(True)
        subject.rpc.assert_not_called()

    def test_candidate_interrupts_bound_remote_after_old_ssh_disconnect_once(self):
        subject, child = coordinator(m), fake_child()
        with patch.object(m.subprocess, 'Popen', return_value=child): subject.child = subject.spawn_child(subject.command_argv, kind='controller')
        subject.state.boot = {'actualControllerPID': 300}
        subject.rpc = Mock(return_value={'status': 'ORIGINAL_CONTROLLER_ALREADY_ABSENT'})
        with patch.object(m, 'qualified_ssh_identity', return_value=identity()):
            subject.cleanup(True)
            subject.cleanup(True)
        subject.rpc.assert_called_once_with('interrupt-controller', cleanup=True, binding=None, boot=subject.state.boot)
        child.wait.assert_not_called()

    def test_unreachable_remote_remains_explicit_cleanup_failure(self):
        subject = coordinator(m)
        subject.state.boot = {'actualControllerPID': 300}
        subject.rpc = Mock(side_effect=OSError('synthetic disconnected route'))
        subject.cleanup(True)
        self.assertFalse(cleanup_value(subject)['ownedLocalProcessesAndStreamsStopped'])
        self.assertTrue(any('remote controller' in row for row in cleanup_value(subject)['errors']))

    def test_baseline_signals_surviving_group_after_original_leader_reaped(self):
        model = KernelModel(alive=False, group_alive=True)
        self.assertTrue(model.run(old_e)['actualProcessAbsent'])
        self.assertIn(int(signal.SIGINT), model.calls)

    def test_candidate_only_probes_surviving_group_after_original_leader_reaped(self):
        for expected in (identity(), None):
            model = KernelModel(alive=False, group_alive=True)
            with patch.object(e.os, 'killpg', side_effect=model.killpg), patch.object(e.os, 'getpgid', return_value=200):
                with self.assertRaisesRegex(ValueError, 'no verifiable original live leader'):
                    e.stop_owned(model.window, model.helper, model.child, expected)
            self.assertEqual(model.calls, [0])
            model.helper.stop_owned_subprocess.assert_not_called()

    def test_absent_leader_and_gone_group_can_be_observed_without_signal(self):
        model = KernelModel(alive=False, group_alive=False)
        value = model.run(e)
        self.assertTrue(value['actualProcessAbsent'])
        self.assertTrue(model.calls and all(kind == 0 for kind in model.calls))

    def test_normal_original_live_child_stop_retains_original_helper_behavior(self):
        model = KernelModel()
        value = model.run(e)
        self.assertEqual(value['group']['group_state'], 'GONE_CHECKED')
        self.assertEqual([kind for kind in model.calls if kind], [int(signal.SIGINT)])
        model.helper.stop_owned_subprocess.assert_called_once()

    def test_identity_is_rechecked_before_later_sigkill_after_leader_exit(self):
        old_model, new_model = KernelModel(survivor=True), KernelModel(survivor=True)
        old_model.run(old_e)
        self.assertIn(int(signal.SIGKILL), old_model.calls)
        with self.assertRaisesRegex(ValueError, 'no verifiable original live leader'): new_model.run(e)
        self.assertEqual([kind for kind in new_model.calls if kind], [int(signal.SIGINT)])

    def test_reaped_reused_pid_or_changed_pgid_never_receives_signal(self):
        reused = KernelModel(alive=False, reused=True)
        with self.assertRaisesRegex(ValueError, 'reused PID'): reused.run(e)
        self.assertEqual(reused.calls, [])
        model = KernelModel()
        with patch.object(e.os, 'killpg', side_effect=model.killpg), patch.object(e.os, 'getpgid', return_value=201):
            with self.assertRaisesRegex(ValueError, 'created process group'): e.stop_owned(model.window, model.helper, model.child, identity())
        self.assertEqual(model.calls, [])

    def test_unverified_group_never_enters_original_unguarded_subprocess_stop(self):
        model = KernelModel()
        model.helper.stop_owned_process_group = Mock(return_value={'owned_pgid': 200, 'group_state': 'STILL_PRESENT_UNVERIFIED'})
        with patch.object(e.os, 'getpgid', return_value=200):
            with self.assertRaisesRegex(ValueError, 'no unguarded subprocess signal'):
                e.stop_owned(model.window, model.helper, model.child, identity())
        model.helper.stop_owned_subprocess.assert_not_called()

    def test_relay_unknown_spawn_cannot_return_successful_abort(self):
        for module, rejects in ((old_e, False), (e, True)):
            subject = module.OwnedOracleRelay.__new__(module.OwnedOracleRelay)
            subject.finished, subject.child, subject.logs, subject.start_attempted = None, None, [], True
            if rejects:
                with self.assertRaisesRegex(ValueError, 'without a returned handle'): subject.abort()
            else: self.assertIsNone(subject.abort())

    def test_exercise_unknown_worker_spawn_cannot_return_successful_abort(self):
        for module, rejects in ((old_e, False), (e, True)):
            subject = module.NoDenialExercise.__new__(module.NoDenialExercise)
            subject.child, subject.start_attempted = None, True
            subject.possible_deployment = subject.relay_possible = False
            subject._close_owned_streams = Mock()
            if rejects:
                with self.assertRaisesRegex(ValueError, 'without a returned handle'): subject.abort()
            else: self.assertEqual(subject.abort(), {'verified': True, 'offlineAcceptance': False})

    def test_actual_relay_start_records_attempt_before_interrupted_popen(self):
        for module, records_attempt in ((old_e, False), (e, True)):
            with tempfile.TemporaryDirectory() as folder:
                subject = module.OwnedOracleRelay.__new__(module.OwnedOracleRelay)
                subject.output = Path(folder)
                subject.child = subject.finished = None
                subject.logs, subject.start_attempted = [], False
                subject.ready = {'windowID': 'a' * 32, 'hardDeadlineUnix': time.time() + 60}
                subject.sources = {'study-ui-offline-heartbeat.py': {'path': '/synthetic/original-heartbeat.py'}}
                with patch.object(module.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic relay spawn')):
                    with self.assertRaises(ValueError if records_attempt else KeyboardInterrupt): subject.start()
                self.assertEqual(subject.start_attempted, records_attempt)
                self.assertEqual(subject.logs, [])

    def test_actual_exercise_run_records_attempt_before_interrupted_popen(self):
        for module, records_attempt in ((old_e, False), (e, True)):
            subject = module.NoDenialExercise.__new__(module.NoDenialExercise)
            subject.output = Path('/synthetic/exercise')
            subject.kind, subject.nonce, subject.child = 'deadline', 'a' * 32, None
            subject.start_attempted = subject.possible_deployment = subject.relay_possible = False
            subject.window = types.SimpleNamespace(private_write=Mock())
            subject._close_owned_streams = Mock()
            with patch.object(module.subprocess, 'Popen', side_effect=KeyboardInterrupt('synthetic worker spawn')):
                with self.assertRaises(ValueError if records_attempt else KeyboardInterrupt): subject.run()
            self.assertEqual(subject.start_attempted, records_attempt)

    def test_all_candidate_and_fixed_remote_sources_parse_without_runtime(self):
        for source in (ORACLE.read_text(), EXERCISES.read_text(), m.REMOTE_COMMON, m.REMOTE_START, m.REMOTE_RPC): ast.parse(source)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    report = {'scope': 'SYNTHETIC_WHOLE_BASELINE_CANDIDATE_OWNERSHIP_LIFECYCLE_CONTROLS_ONLY',
        'sources': {str(path.name): {'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                    for path in (ORACLE, EXERCISES, INTERRUPTION)},
        'baselineInputs': json.loads((HERE / 'BASELINE_INPUTS.json').read_text()),
        'testsRun': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'actualSSH': 0, 'actualMac': 0, 'actualNetworkDenial': 0, 'actualNativeCases': 0, 'actualSignals': 0}
    (HERE / 'SOURCE_CONTROLS.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
