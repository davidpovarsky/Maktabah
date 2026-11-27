#!/usr/bin/env python3
"""Synthetic lifecycle/admission controls. No Mac, subprocess, PF or SSH runs."""
import ast
import base64
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import tempfile
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'study-ui-offline-exercises.py'
if not SOURCE.exists(): SOURCE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-exercises.py'
WINDOW = HERE.parent / 'offline-host/study-ui-offline-window.py'
if not WINDOW.exists(): WINDOW = HERE.parents[4] / 'Scripts/CI/study-ui-offline-window.py'
JOIN = HERE.parent / 'offline-execution/study-ui-offline-execution.py'
if not JOIN.exists(): JOIN = HERE.parents[4] / 'Scripts/CI/study-ui-offline-execution.py'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


m, w, j = load('exercise_control_subject', SOURCE), load('exercise_window_subject', WINDOW), load('exercise_join_subject', JOIN)
EPOCH = 1700000000
ID = '0123456789abcdef0123456789abcdef'
NONCE = 'a' * 32
UDID = '11111111-2222-4333-8444-555555555555'
CODE = b'synthetic root source bytes; never executed'
SOURCE_SHA = m.sha(CODE)


def lease(kind='controller-death'):
    value = {'schema': w.VERSION, 'status': 'COORDINATED_EXCLUSIVE_OFFLINE_WINDOW', 'windowID': ID,
        'controllerSourceSHA256': SOURCE_SHA, 'mode': 'watchdog-exercise-no-denial', 'exerciseKind': kind,
        'selectedCaseID': w.CASE_IDS['zayit'], 'coordinatingOwners': ['synthetic-owner-a', 'synthetic-owner-b'],
        'allOtherNetworkAndNativeWorkPaused': True, 'notBeforeUnix': EPOCH - 1, 'hardDeadlineUnix': EPOCH + 90,
        'controls': [{'direction': 'incoming', 'transport': 'ssh-tcp', 'localAddress': '192.0.2.2',
            'localPort': 22, 'peerAddress': '198.51.100.3', 'peerPort': 12345, 'interface': 'en0'}],
        'oracleHeartbeatPeer': '198.51.100.3', 'controllerPID': 200, 'simulatorUDID': UDID,
        'translatedVNC': []}
    coordination = {'schema': 'otzaria.coordinated-mac-network-window/1', 'status': 'ALL_LISTED_OWNERS_PAUSED',
        'windowID': ID, 'hardDeadlineUnix': value['hardDeadlineUnix'], 'selectedCaseID': value['selectedCaseID'],
        'simulatorUDID': UDID, 'observedAtUnix': EPOCH,
        'owners': [{'ownerID': owner, 'paused': True, 'windowID': ID, 'acknowledgedAtUnix': EPOCH,
                    'originalAcknowledgement': {'path': '/synthetic/' + owner, 'bytes': 1, 'sha256': 'b' * 64}}
                   for owner in value['coordinatingOwners']]}
    return value, coordination


def admit(value, coordination, kind='controller-death'):
    return m.admit_exercise(value, coordination, kind=kind, actual_pid=200, source_sha=SOURCE_SHA,
                           window=w, join=j, now=EPOCH)


def root_file(name, value):
    raw = value if type(value) is bytes else json.dumps(value).encode()
    return {'sourcePath': str(w.BASE / ID / name), 'uid': 0, 'mode': 0o400, 'bytes': len(raw),
            'sha256': m.sha(raw), 'rawBase64': base64.b64encode(raw).decode()}


def put(snapshot, name, value):
    snapshot['exports'][ID][name] = root_file(name, value)


def get(snapshot, name):
    return j.root_document(snapshot['exports'], ID, name)


def stop(controller):
    return {'process': controller, 'group': {'owned_pgid': controller['pid'], 'group_state': 'GONE_CHECKED'},
            'subprocess': {'pid': controller['pid'], 'state': 'EXITED'}, 'actualProcessAbsent': True}


def root_case(kind='controller-death'):
    value, _ = lease(kind)
    controller = {'pid': 200, 'parentPID': 100, 'startUTC': 'Tue Nov 14 22:13:20 2023', 'command': '/synthetic/python worker'}
    sealed = {'lease': value, 'sourceSHA256': SOURCE_SHA, 'controller': controller, 'bootSession': UDID,
              'preparedUnix': EPOCH, 'hardDeadlineMonotonic': 190}
    cleanup = {'status': 'OWNED_RULES_EMPTY_ROLLBACK_VERIFIED', 'windowID': ID,
        'mode': 'watchdog-exercise-no-denial', 'reason': m.REASONS[kind], 'activated': False,
        'onlyOwnedAnchor': w.anchor_name(ID), 'attempts': [{'exit': 0, 'rulesBeforeSHA256': m.sha(b'')}],
        'cleanupUnix': EPOCH + (90 if kind == 'deadline' else 45),
        'cleanupMonotonic': 190 if kind == 'deadline' else 145,
        'history': [{'active': False, 'counters': '', 'heartbeatNonce': NONCE}]}
    snapshot = {'exports': {ID: {}}, 'currentBoot': UDID, 'currentOwnedRulesSHA256': m.sha(b''),
                'currentDaemonAbsent': True, 'currentPlistAbsent': True}
    for name, record in {
        'sealed.json': sealed, 'armed.json': {'windowID': ID, 'watchdog': {'pid': 300}},
        'cleanup.json': cleanup, 'unloaded.json': {'windowID': ID,
            'status': 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY', 'originalConfigurationMatches': True},
        'heartbeat.json': {'observedMonotonic': 100, 'nonce': NONCE}, 'watchdog.py': CODE,
    }.items(): put(snapshot, name, record)
    trigger = {'kind': kind, 'startedUnix': EPOCH + 10, 'startedMonotonic': 110}
    if kind == 'controller-death': trigger['ownedControllerStop'] = stop(controller)
    else: trigger['controllerObservedAfterCleanup'] = controller
    kwargs = {'lease': value, 'kind': kind, 'source_sha': SOURCE_SHA, 'controller': controller,
              'deployment': {'windowID': ID, 'sealedSHA256': snapshot['exports'][ID]['sealed.json']['sha256']},
              'heartbeat': {'heartbeatNonce': NONCE}, 'trigger': trigger, 'join': j, 'window': w}
    return snapshot, kwargs


def relay():
    command = ['/synthetic/python3', '/synthetic/relay.py', '--window', ID, '--deadline-unix', str(EPOCH + 90), '--output', '/synthetic/rows.jsonl']
    start = {'schema': m.RELAY_SCHEMA, 'status': 'OWNED_ORIGINAL_RELAY_STARTED', 'windowID': ID,
        'oracleEUID': 1001, 'oracleUser': 'ubuntu', 'existingAlias': 'scaleway-mac', 'supervisorPID': 100,
        'process': {'pid': 200, 'parentPID': 100, 'startUTC': 'Tue Nov 14 22:13:20 2023', 'command': shlex.join(command)},
        'command': command, 'helperSourceSHA256': 'a' * 64, 'relaySourceSHA256': 'b' * 64, 'relaySourcePath': command[1]}
    rows = [{'windowID': ID, 'sequence': 0, 'relayProcessID': 200, 'relaySourceSHA256': 'b' * 64,
        'exit': 0, 'stderrSHA256': m.sha(b''), 'startedUnix': EPOCH + 100000, 'finishedUnix': EPOCH + 100001,
        'remote': {'windowID': ID, 'nonce': NONCE, 'observedUnix': EPOCH}}]
    return start, rows


class Controls(unittest.TestCase):
    def bad_root(self, change, kind='controller-death'):
        snapshot, arguments = root_case(kind); change(snapshot, arguments)
        with self.assertRaises((ValueError, KeyError)): m.validate_exercise_root(snapshot, **arguments)

    def test_each_actual_root_shape_requires_its_exact_distinct_reason(self):
        for kind in m.REASONS:
            snapshot, arguments = root_case(kind)
            self.assertEqual(m.validate_exercise_root(snapshot, **arguments)['reason'], m.REASONS[kind])

    def test_exact_owned_worker_frame(self):
        self.assertEqual(m.validate_frame(m.frame(NONCE, 2, 'READY', {'pid': 200}), NONCE, 2, 'READY'), {'pid': 200})

    def test_foreign_or_reordered_worker_frame_rejected(self):
        for key, value in [('nonce', 'c' * 32), ('sequence', 3), ('event', 'OTHER'), ('schema', 'other')]:
            row = m.frame(NONCE, 2, 'READY', {}); row[key] = value
            with self.assertRaises(ValueError): m.validate_frame(row, NONCE, 2, 'READY')

    def test_all_three_explicit_no_denial_admissions(self):
        for kind in m.REASONS:
            value, coordination = lease(kind); self.assertEqual(admit(value, coordination, kind)['mode'], 'watchdog-exercise-no-denial')

    def test_real_denial_mode_is_never_accepted(self):
        value, coordination = lease(); value['mode'] = 'network-denial'
        with self.assertRaises(ValueError): admit(value, coordination)

    def test_other_actual_pid_or_trigger_is_never_accepted(self):
        for key, item in [('controllerPID', 999), ('exerciseKind', 'deadline')]:
            value, coordination = lease(); value[key] = item
            with self.assertRaises(ValueError): admit(value, coordination)

    def test_owner_pause_is_not_synthesized(self):
        value, coordination = lease(); coordination['owners'][0]['paused'] = False
        with self.assertRaises(ValueError): admit(value, coordination)

    def test_stale_owner_coordination_rejected(self):
        value, coordination = lease(); coordination['observedAtUnix'] -= 121
        with self.assertRaises(ValueError): admit(value, coordination)

    def test_resource_window_cannot_be_silently_extended(self):
        value, coordination = lease(); value['hardDeadlineUnix'] = coordination['hardDeadlineUnix'] = EPOCH + 121
        with self.assertRaises(ValueError): admit(value, coordination)

    def test_actual_activation_marker_blocks_no_denial(self):
        with self.assertRaises(ValueError): m.no_denial_state({'activated': {'windowID': ID}}, ID)

    def test_wrong_cleanup_reason_rejected(self):
        def change(s, a):
            done = get(s, 'cleanup.json'); done['reason'] = 'normal-finish-requested'; put(s, 'cleanup.json', done)
        self.bad_root(change)

    def test_actual_rule_load_cannot_be_relabelled_no_denial(self):
        def change(s, a):
            done = get(s, 'cleanup.json'); done['activated'] = True; put(s, 'cleanup.json', done)
        self.bad_root(change)

    def test_original_source_or_boot_change_rejected(self):
        self.bad_root(lambda s, a: s.update(currentBoot='different-boot'))
        self.bad_root(lambda s, a: put(s, 'watchdog.py', b'different source'))

    def test_empty_history_does_not_prove_actual_lifecycle(self):
        def change(s, a):
            done = get(s, 'cleanup.json'); done['history'] = []; put(s, 'cleanup.json', done)
        self.bad_root(change)

    def test_history_must_observe_the_actual_oracle_nonce(self):
        self.bad_root(lambda s, a: a['heartbeat'].update(heartbeatNonce='c' * 32))

    def test_nonempty_rules_cannot_pass_empty_rollback(self):
        def change(s, a):
            done = get(s, 'cleanup.json'); done['attempts'][0]['rulesBeforeSHA256'] = 'c' * 64; put(s, 'cleanup.json', done)
        self.bad_root(change)

    def test_daemon_or_plist_still_present_rejected(self):
        for key in ('currentDaemonAbsent', 'currentPlistAbsent'):
            self.bad_root(lambda s, a: s.update({key: False}))

    def test_changed_original_host_configuration_rejected(self):
        def change(s, a):
            done = get(s, 'unloaded.json'); done['originalConfigurationMatches'] = False; put(s, 'unloaded.json', done)
        self.bad_root(change)

    def test_deadline_cannot_pass_before_both_sealed_clocks(self):
        def change(s, a):
            done = get(s, 'cleanup.json'); done.update(cleanupUnix=EPOCH + 89, cleanupMonotonic=189); put(s, 'cleanup.json', done)
        self.bad_root(change, 'deadline')

    def test_heartbeat_loss_needs_actual_expiration(self):
        self.bad_root(lambda s, a: put(s, 'heartbeat.json', {'observedMonotonic': 140, 'nonce': NONCE}), 'heartbeat-loss')

    def test_deadline_and_heartbeat_loss_keep_controller_alive(self):
        for kind in ('deadline', 'heartbeat-loss'):
            self.bad_root(lambda s, a: a['trigger'].update(controllerObservedAfterCleanup=None), kind)

    def test_replaced_process_is_not_signaled(self):
        window, helper, child = Mock(), Mock(), Mock(pid=200)
        window.process.return_value = {'pid': 200, 'startUTC': 'different'}
        with self.assertRaises(ValueError): m.stop_owned(window, helper, child, {'pid': 200, 'startUTC': 'original'})
        helper.stop_owned_process_group.assert_not_called(); helper.stop_owned_subprocess.assert_not_called()

    def test_failed_launch_still_cleans_its_created_group(self):
        window, helper, child = Mock(), Mock(), Mock(pid=200)
        window.process.return_value = None; child.poll.return_value = 1
        helper.stop_owned_process_group.return_value = {'group_state': 'GONE_CHECKED', 'owned_pgid': 200}
        helper.stop_owned_subprocess.return_value = {'pid': 200, 'state': 'EXITED'}
        value = m.stop_owned(window, helper, child, None)
        self.assertTrue(value['sourceIdentityUnavailableNoAcceptance'])
        helper.stop_owned_process_group.assert_called_once(); helper.stop_owned_subprocess.assert_called_once()

    def test_original_nonroot_relay_identity(self):
        value, _ = relay()
        sources = {'study-ui-offline-exercises.py': {'sha256': 'a' * 64}, 'study-ui-offline-heartbeat.py': {'sha256': 'b' * 64}}
        m.validate_relay_start(value, {'windowID': ID, 'hardDeadlineUnix': EPOCH + 90}, sources)
        value['oracleEUID'] = 0
        with self.assertRaises(ValueError): m.validate_relay_start(value, {'windowID': ID, 'hardDeadlineUnix': EPOCH + 90}, sources)

    def test_cross_host_clock_skew_does_not_invent_order(self):
        start, rows = relay(); m.validate_relay_rows(('\n'.join(json.dumps(r) for r in rows) + '\n').encode(), start, required_nonce=NONCE)

    def test_partial_relay_jsonl_and_foreign_nonce_rejected(self):
        start, rows = relay(); raw = ('\n'.join(json.dumps(r) for r in rows) + '\n').encode()
        with self.assertRaises(ValueError): m.validate_relay_rows(raw[:-1], start, required_nonce=NONCE)
        with self.assertRaises(ValueError): m.validate_relay_rows(raw, start, required_nonce='b' * 32)

    def test_duplicate_relay_keys_are_not_silently_accepted(self):
        start, _ = relay()
        with self.assertRaises(ValueError): m.validate_relay_rows(b'{"windowID":"a","windowID":"b"}\n', start, required_nonce=NONCE)

    def test_changed_transfer_cannot_claim_original_rows(self):
        settings = Mock()
        envelope = {'record': {'path': '/copy', 'bytes': 10, 'sha256': 'a' * 64},
                    'originalRecord': {'path': '/original', 'bytes': 10, 'sha256': 'b' * 64}}
        with self.assertRaises(ValueError): m.transferred(settings, envelope)
        settings.verify_witness.assert_not_called()

    def test_launch_receipt_enospc_cannot_skip_owned_abort(self):
        subject = object.__new__(m.NoDenialExercise)
        subject.output, subject.kind, subject.nonce, subject.sources = Path('/synthetic/output'), 'deadline', NONCE, {}
        subject.window = Mock(); subject.window.private_write.side_effect = OSError('synthetic ENOSPC')
        subject.abort = Mock(return_value={'verified': True})
        child = Mock(pid=200)
        def launch(command, **kwargs):
            subject.window.process.return_value = {'pid': 200, 'parentPID': os.getpid(), 'startUTC': 'synthetic', 'command': shlex.join(command)}
            return child
        with patch.object(m.subprocess, 'Popen', side_effect=launch):
            with self.assertRaises(OSError): subject.run()
        subject.abort.assert_called_once()

    def test_already_finished_relay_never_signals_reused_pid(self):
        relay_instance = object.__new__(m.OwnedOracleRelay)
        relay_instance.finished = {'record': {}}; relay_instance.finished_stop = {'actualOriginalGroupGone': True}
        relay_instance.window = Mock()
        self.assertEqual(relay_instance.abort(), relay_instance.finished_stop)
        relay_instance.window.process.assert_not_called()

    def test_exercise_source_has_no_activation_or_native_calls(self):
        tree = ast.parse(SOURCE.read_text())
        forbidden = {'activate', 'probe_round', 'observe_native_case', 'run_native_actions'}
        self.assertFalse([node for node in ast.walk(tree) if isinstance(node, ast.Call)
                          and isinstance(node.func, ast.Attribute) and node.func.attr in forbidden])


    def restored_relay(self, *, terminal=True):
        start, rows = relay()
        if terminal:
            rows.append({**rows[0], 'sequence': 1, 'startedUnix': EPOCH + 100002, 'finishedUnix': EPOCH + 100003,
                         'remote': {'windowID': ID, 'status': 'WINDOW_ALREADY_CLEANED', 'cleanupSHA256': 'c' * 64}})
        subject = object.__new__(m.OwnedOracleRelay)
        subject.finished = None; subject.start_value = start; subject.identity = start['process']
        subject.ready = {'windowID': ID}; subject.output = Path('/synthetic')
        subject.child = Mock(); subject.child.returncode = 0; subject.interruption = Mock()
        subject.window = Mock(); subject.window.read_bytes.return_value = ('\n'.join(json.dumps(r) for r in rows) + '\n').encode()
        subject.window.strict_json.side_effect = json.loads
        subject._seal = Mock(return_value={'record': {}, 'rows': {}}); subject.abort = Mock()
        return subject

    def test_main_phase_requires_real_terminal_cleanup_binding(self):
        subject = self.restored_relay()
        with patch.object(m, 'stop_owned', return_value={'synthetic': True}):
            subject.finish_after_restoration(window_id=ID, cleanup_sha256='c' * 64)
        self.assertEqual(subject._seal.call_args.args[0], 'ORIGINAL_RELAY_ENDED_AFTER_VERIFIED_RESTORATION')
        subject.abort.assert_not_called()

    def test_wrong_main_cleanup_sha_cleans_owned_relay_and_fails(self):
        subject = self.restored_relay()
        with self.assertRaises(ValueError): subject.finish_after_restoration(window_id=ID, cleanup_sha256='d' * 64)
        subject.abort.assert_called_once(); subject._seal.assert_not_called()

    def test_missing_main_terminal_reply_is_not_passed(self):
        subject = self.restored_relay(terminal=False)
        with self.assertRaises(ValueError): subject.finish_after_restoration(window_id=ID, cleanup_sha256='c' * 64)
        subject.abort.assert_called_once(); subject._seal.assert_not_called()

    def test_relay_accepts_bounded_900s_rows_without_weakening_identity(self):
        start, prototype = relay(); rows = []
        for number in range(100):
            row = copy.deepcopy(prototype[0]); row.update(sequence=number, startedUnix=EPOCH + 100000 + number * 8,
                                                        finishedUnix=EPOCH + 100001 + number * 8)
            row['remote']['nonce'] = format(number + 1, '032x'); rows.append(row)
        m.validate_relay_rows(('\n'.join(json.dumps(r) for r in rows) + '\n').encode(), start, required_nonce=rows[0]['remote']['nonce'])


    def test_concurrent_owned_unload_requires_actual_root_and_kernel_proof(self):
        subject = object.__new__(m.NoDenialExercise)
        subject.window, subject.join, subject.lease, subject.unloaded = w, j, {'windowID': ID}, False
        before, _ = root_case(); after = copy.deepcopy(before); del before['exports'][ID]['unloaded.json']
        subject._private = Mock(side_effect=FileNotFoundError('same owned plist already removed'))
        with patch.object(m, 'root_snapshot', side_effect=[before, after]):
            result = subject._unload()
        self.assertTrue(subject.unloaded); self.assertIn('concurrentOwnedUnloadDiagnostic', result)
        after['currentDaemonAbsent'] = False; subject.unloaded = False
        with patch.object(m, 'root_snapshot', side_effect=[before, after]):
            with self.assertRaises(ValueError): subject._unload()
        self.assertFalse(subject.unloaded)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    report = {'scope': 'SYNTHETIC_SOURCE_CONTROLS_ONLY_NO_MAC_SUBPROCESS_PF_SSH_OR_NATIVE_EXECUTION',
              'testsRun': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
              'sourceSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'actualWatchdogExercises': 0,
              'networkDenialWindows': 0, 'nativeCases': 0}
    (HERE / 'SOURCE_CONTROLS.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
