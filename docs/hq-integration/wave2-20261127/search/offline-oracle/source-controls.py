#!/usr/bin/env python3
"""Synthetic source/lifecycle controls; no SSH, PF, Mac or native subprocess."""
import ast
import base64
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import queue
import shlex
import stat
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'study-ui-offline-oracle.py'
if not SOURCE.exists(): SOURCE = HERE.parents[4] / 'Scripts/CI/study-ui-offline-oracle.py'
FIXTURES = HERE.parent / 'offline-execution/source-controls.py'
if not FIXTURES.exists(): FIXTURES = HERE.parents[4] / 'docs/hq-integration/wave2-20261127/search/offline-execution/source-controls.py'
WINDOW = HERE.parent / 'offline-host/study-ui-offline-window.py'
if not WINDOW.exists(): WINDOW = HERE.parents[4] / 'Scripts/CI/study-ui-offline-window.py'

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path); module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module); return module

m, f, w = load('oracle_subject', SOURCE), load('oracle_page_fixture', FIXTURES), load('oracle_private_read', WINDOW)
j = f.m
UDID = '11111111-2222-4333-8444-555555555555'
RID, WID = 'a' * 32, 'b' * 32
MAC = '/synthetic/mac/current'
OUT = MAC + '/build/artifacts/one-offline-phase'

def fw(path, raw=b'original synthetic bytes'):
    return {'path': path, 'bytes': len(raw), 'sha256': m.sha(raw)}

def pack(path, value):
    raw = value if type(value) is bytes else m.json_bytes(value)
    return {'file': fw(path, raw), 'rawBase64': base64.b64encode(raw).decode()}

def launch(phase='offline-zayit'):
    python, main = fw('/synthetic/mac/python3'), fw(MAC + '/Scripts/CI/production-study-v40-ui.py')
    original = fw('/synthetic/mac/installed/RESULT.json')
    return {'schema': m.LAUNCH_SCHEMA, 'phase': phase, 'simulatorUDID': UDID, 'macRepository': MAC,
        'python': python, 'controller': main, 'inputs': {'installationResult': original}, 'outputDirectory': OUT,
        'argv': [python['path'], '-I', '-B', '-u', main['path'], 'execute', phase,
                 '--owned-simulator', UDID, '--installation-result', original['path'], '--output', OUT,
                 '--reserved-other-bytes', '0', '--offline-coordinator-wait-seconds', '300'],
        'environment': {'FAITHFUL_RUNTIME27_IDENTIFIER': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1', 'LC_ALL': 'C', 'TZ': 'UTC'},
        'timeouts': {'preReadySeconds': 1200, 'postRestorationSeconds': 600}}

def sources():
    return {'Scripts/CI/' + name: fw('/synthetic/oracle/current/Scripts/CI/' + name) for name in m.SOURCE_NAMES}

def mac_sources():
    return {name: {**row, 'path': MAC + '/' + name} for name, row in sources().items()}

def source(phase='offline-zayit'):
    return {'study_ui_execution_sources': mac_sources(), 'study_ui_phase': phase,
            'executed_case_ids': [m.CASE_IDS[phase]], 'checkout_sha': 'c' * 40}

def response():
    probe = {key: fw('/synthetic/mac/probe/' + key) for key in ('binary', 'source', 'compileReceipt')}
    return {'schema': m.INPUT_SCHEMA, 'requestID': RID, 'lease': fw('/synthetic/mac/lease.json'),
            'coordination': fw('/synthetic/mac/coordination.json'), 'hostProbe': probe, 'simulatorProbe': copy.deepcopy(probe)}

def frames(phase='offline-zayit'):
    spec = launch(phase)
    boot = {'schema': m.SCHEMA, 'event': 'ORIGINAL_CONTROLLER_EXEC_READY', 'actualControllerPID': 200,
        'actualUID': 501, 'parentPID': 100, 'startUTC': 'Fri Nov 27 08:00:00 2026', 'argv': spec['argv'],
        'macRepository': MAC, 'sources': mac_sources(), 'python': spec['python']}
    common = {'schema': m.EVENT_SCHEMA, 'requestID': RID, 'actualControllerPID': 200,
              'observedAtUnix': 1_700_000_000, 'controlDirectory': OUT + '/offline-control'}
    ready = {**common, 'event': 'CONTROLLER_READY', 'sequence': 0, 'studyPhase': phase, 'simulatorUDID': UDID,
        'selectedCaseID': 'Maktabah-iOSUITests/' + m.CASE_IDS[phase], 'sourceBefore': pack(OUT + '/source-before.json', source(phase))['file'],
        'windowSource': mac_sources()['Scripts/CI/study-ui-offline-window.py']}
    r = response()
    prepared = {**common, 'event': 'WINDOW_PREPARED', 'sequence': 1,
        'rendezvous': {'schema': 'otzaria.offline-oracle-rendezvous/1', 'actualControllerPID': 200,
            'selectedCaseID': ready['selectedCaseID'], 'simulatorUDID': UDID, 'windowID': WID,
            'hardDeadlineUnix': 1_700_000_900, 'oracleRelaySource': mac_sources()['Scripts/CI/study-ui-offline-heartbeat.py'],
            'coordinationReceipt': r['coordination'], 'lease': r['lease']}}
    restored = {**common, 'event': 'TRANSPORT_RESTORED', 'sequence': 2, 'windowID': WID, 'cleanupSHA256': 'd' * 64}
    pending = {**common, 'event': 'CONTROLLER_POSTCHECKS_PENDING', 'sequence': 3,
               'cleanupVerified': True, 'nativeCaseCompleted': True, 'rootFinalResultPending': True}
    return boot, ready, prepared, restored, pending

def state(phase='offline-zayit'):
    values = frames(phase); result = m.EventState(launch(phase)); result.launch_frame(values[0])
    for value in values[1:]: result.accept(value)
    return result

def complete(phase='offline-zayit'):
    s = state(phase); src = source(phase); response_value = response()
    process = {'pid': 200, 'parentPID': 100, 'startUTC': s.boot['startUTC'], 'command': shlex.join(s.launch['argv'])}
    binding = {'actualUID': 501, 'process': process, 'ready': s.ready, 'controlDirectory': s.ready['controlDirectory']}
    engine = phase.removeprefix('offline-')
    pages = f.pages(engine)
    original_lease = {'windowID': WID, 'controllerPID': 200, 'selectedCaseID': s.ready['selectedCaseID'], 'simulatorUDID': UDID}
    lease = pack('/synthetic/mac/lease.json', original_lease); response_value['lease'] = lease['file']
    cleanup_raw = m.json_bytes({'windowID': WID, 'syntheticObservedCleanup': True})
    cleanup = {'bytes': len(cleanup_raw), 'sha256': m.sha(cleanup_raw), 'rawBase64': base64.b64encode(cleanup_raw).decode()}
    s.restored['cleanupSHA256'] = cleanup['sha256']
    root_receipts = pack(OUT + '/offline-host/ROOT_WATCHDOG_RECEIPTS.private.json', {WID: {'cleanup.json': cleanup}})
    rows = pack(OUT + '/offline-control/oracle-relay-' + RID + '.jsonl', b'{"syntheticOnly":true}\n')
    native = {'case': m.CASE_IDS[phase], 'case_directory': OUT + '/01-' + m.CASE_IDS[phase].split('/')[1], 'passed': True}
    native_result = pack(native['case_directory'] + '/RESULT.json', native)
    build = {'complete_native_images': {'synthetic': 'retained'}, 'sdk': '27.1'}
    runtime = {'identifier': s.launch['environment']['FAITHFUL_RUNTIME27_IDENTIFIER']}
    proof = {'schema': j.SCHEMA, 'status': j.CASE_PASS, 'engine': engine, 'caseID': s.ready['selectedCaseID'],
        'simulatorUDID': UDID, 'source': src, 'build': build, 'runtime': runtime, 'sourceBeforeEqualsAfter': True,
        'lease': lease['file'], 'coordination': response_value['coordination'], 'oracleRelay': rows['file'],
        'originalPages': {'contents': pages}, 'pageIdentity': j.validate_pages(pages, engine)}
    case = pack(OUT + '/offline-host/CASE_RESULT.private.json', proof)
    db = fw('/synthetic/mac/container/seforim.db'); db['bytes'] = 4_355_063_808
    report = {'status': j.OFFLINE_PHASE_PASS, 'network_scope': j.OFFLINE_NETWORK_SCOPE, 'study_phase': phase,
        'selected_case_ids': [m.CASE_IDS[phase]], 'native_cases_completed': True, 'post_verification_failures': [],
        'source_before': src, 'source_after': copy.deepcopy(src), 'build_before': build, 'build_after': copy.deepcopy(build),
        'configuration': 'Debug', 'runtime': runtime, 'reused_external_owned_simulator': UDID,
        'original_installation': {'result': s.launch['inputs']['installationResult']},
        'owned_cleanup': {'status': 'SHUTDOWN_RETAINED_FOR_INTEGRATION_OWNER', 'udid': UDID,
                          'actual_device': {'udid': UDID, 'state': 'Shutdown'}},
        'offline_host_cleanup': {'verified': True}, 'database_after': db, 'installation_before': {'database': db},
        'installed_images_after': {'synthetic': 'present'}, 'original_installation_receipts_after': {'synthetic': 'present'},
        'offline_case': case['file'], 'case_results': [{**native, 'case_result': native_result['file']}]}
    collection = {'operation': 'collect', 'actualUID': 501, 'currentControllerProcess': None, 'sources': mac_sources(),
        'records': {'RESULT.json': pack(OUT + '/RESULT.json', report), 'offline_case': case, 'lease': lease,
                    'rootReceipts': root_receipts, 'oracleRelay': rows},
        'nativeRetained': {'RESULT.json': native_result, 'RUN_ATTEMPT.json': pack(native['case_directory'] + '/RUN_ATTEMPT.json', {'synthetic': True}),
                          'xcresult': {'path': native['case_directory'] + '/original.xcresult', 'observedPresent': True}}}
    arguments = {'state': s, 'binding': binding, 'source_before': src, 'expected_sources': sources(),
                 'response': response_value, 'relay_rows': rows['file'], 'ssh_exit': 0, 'join': j}
    return collection, arguments

def edit_record(collection, key, callback):
    row = collection['records'][key]; value = m.strict_json(m.unpack(row)); callback(value)
    collection['records'][key] = pack(row['file']['path'], value)
    if key == 'offline_case': edit_record(collection, 'RESULT.json', lambda report: report.update(offline_case=collection['records'][key]['file']))

def remote_functions():
    tree = ast.parse(m.REMOTE_COMMON)
    tree.body = [node for node in tree.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
    values = {}; exec(compile(tree, '<actual-fixed-remote-functions>', 'exec'), values); return values


class Controls(unittest.TestCase):
    def test_source_and_both_fixed_remote_programs_parse(self):
        for text in (SOURCE.read_text(), m.REMOTE_START, m.REMOTE_RPC): ast.parse(text)

    def test_each_exact_original_launch_contract(self):
        for phase in m.CASE_IDS: m.validate_launch(launch(phase))

    def test_extra_case_or_shell_operation_rejected(self):
        for change in (lambda v: v['argv'].append('-only-testing:other'), lambda v: v['argv'].__setitem__(5, 'source-check'),
                       lambda v: v['argv'].__setitem__(0, '/other/python'), lambda v: v['argv'].__setitem__(6, 'pages')):
            value = launch(); change(value)
            with self.assertRaises(ValueError): m.validate_launch(value)

    def test_wrong_udid_or_input_path_or_output_rejected(self):
        for position, replacement in ((8, 'other-udid'), (10, '/other/RESULT.json'), (12, '/other/output')):
            value = launch(); value['argv'][position] = replacement
            with self.assertRaises(ValueError): m.validate_launch(value)

    def test_runner_provider_proxy_and_unknown_environment_rejected(self):
        for key in ('TEST_RUNNER_Backend', 'HTTP_PROXY', 'PYTHONPATH', 'SIMCTL_CHILD_Fixture'):
            value = launch(); value['environment'][key] = 'synthetic'
            with self.assertRaises(ValueError): m.validate_launch(value)

    def test_other_runtime_and_unbounded_resource_wait_rejected(self):
        for change in (lambda v: v['environment'].update(FAITHFUL_RUNTIME27_IDENTIFIER='other-runtime'),
                       lambda v: v['timeouts'].update(preReadySeconds=1801), lambda v: v['timeouts'].update(postRestorationSeconds=901),
                       lambda v: v['argv'].__setitem__(-1, '601')):
            value = launch(); change(value)
            with self.assertRaises(ValueError): m.validate_launch(value)

    def test_only_original_mac_file_witnesses_in_owner_response(self):
        m.validate_response(response(), RID)
        for change in (lambda v: v.update(pausedOwners=True), lambda v: v.update(requestID='c' * 32),
                       lambda v: v['hostProbe'].update(fakeProvider='yes'), lambda v: v['lease'].update(bytes=True)):
            value = response(); change(value)
            with self.assertRaises(ValueError): m.validate_response(value, RID)

    def test_both_original_four_event_sequences(self):
        for phase in m.CASE_IDS:
            value = state(phase); self.assertIsNotNone(value.pending); self.assertEqual(value.sequence, 4)

    def test_event_requires_actual_boot_identity(self):
        value = m.EventState(launch())
        with self.assertRaises(ValueError): value.accept(frames()[1])

    def test_foreign_request_pid_directory_and_sequence_rejected(self):
        for key, item in [('requestID', 'd' * 32), ('actualControllerPID', 201), ('controlDirectory', '/other'), ('sequence', 2)]:
            boot, ready, prepared, _, _ = frames(); value = m.EventState(launch()); value.launch_frame(boot); value.accept(ready)
            prepared[key] = item
            with self.assertRaises(ValueError): value.accept(prepared)

    def test_prepared_without_ready_and_duplicate_boot_rejected(self):
        value = m.EventState(launch()); boot, ready, prepared, _, _ = frames(); value.launch_frame(boot)
        with self.assertRaises(ValueError): value.accept(prepared)
        with self.assertRaises(ValueError): value.launch_frame(boot)

    def test_foreign_window_or_case_in_prepared_rejected(self):
        for key, item in [('selectedCaseID', 'other'), ('simulatorUDID', 'other'), ('actualControllerPID', 999), ('hardDeadlineUnix', True)]:
            boot, ready, prepared, _, _ = frames(); value = m.EventState(launch()); value.launch_frame(boot); value.accept(ready)
            prepared['rendezvous'][key] = item
            with self.assertRaises(ValueError): value.accept(prepared)

    def test_restored_requires_exact_window_and_cleanup_digest(self):
        for key, item in [('windowID', 'd' * 32), ('cleanupSHA256', 'unknown')]:
            boot, ready, prepared, restored, _ = frames(); value = m.EventState(launch()); value.launch_frame(boot)
            value.accept(ready); value.accept(prepared); restored[key] = item
            with self.assertRaises(ValueError): value.accept(restored)

    def test_pending_before_restoration_or_unverified_cleanup_rejected(self):
        boot, ready, prepared, restored, pending = frames(); value = m.EventState(launch()); value.launch_frame(boot); value.accept(ready)
        with self.assertRaises(ValueError): value.accept(pending)
        value.accept(prepared); value.accept(restored); pending['cleanupVerified'] = False
        with self.assertRaises(ValueError): value.accept(pending)

    def test_aborted_at_each_active_stage_never_becomes_pending(self):
        for prefix in range(1, 4):
            values = frames(); value = m.EventState(launch()); value.launch_frame(values[0])
            for item in values[1:prefix + 1]: value.accept(item)
            aborted = {**values[1], 'sequence': prefix, 'event': 'WINDOW_ABORTED', 'cleanupVerified': True,
                       'nativeCaseCompleted': False, 'rootFinalResultPending': True}
            value.accept(aborted)
            with self.assertRaises(ValueError): value.accept(values[-1])

    def test_original_mac_source_closure_must_match_current_oracle(self):
        m.validate_sources(mac_sources(), sources(), MAC)
        for change in (lambda v: v.pop(next(iter(v))), lambda v: next(iter(v.values())).update(sha256='e' * 64),
                       lambda v: next(iter(v.values())).update(path='/other/source')):
            value = mac_sources(); change(value)
            with self.assertRaises(ValueError): m.validate_sources(value, sources(), MAC)

    def test_both_original_final_phase_shapes_and_pages(self):
        for phase in m.CASE_IDS:
            collection, arguments = complete(phase)
            self.assertEqual(m.validate_final(collection, **arguments)['pageIdentity']['resultCount'], 150 if phase == 'offline-zayit' else 200)

    def test_pending_or_nonzero_ssh_exit_never_qualifies_final(self):
        for modification in ('pending', 'exit'):
            collection, arguments = complete()
            if modification == 'pending': arguments['state'].pending = None
            else: arguments['ssh_exit'] = 1
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_late_original_postcheck_failure_is_not_pass(self):
        for change in (lambda v: v.update(status='FAILED_OR_INCOMPLETE'), lambda v: v.update(post_verification_failures=['late source change']),
                       lambda v: v.update(native_cases_completed=False)):
            collection, arguments = complete(); edit_record(collection, 'RESULT.json', change)
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_changed_source_build_or_runtime_rejected_after_pending(self):
        for change in (lambda v: v['source_after'].update(checkout_sha='e' * 40), lambda v: v['build_after'].update(sdk='other'),
                       lambda v: v['runtime'].update(identifier='other')):
            collection, arguments = complete(); edit_record(collection, 'RESULT.json', change)
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_foreign_installation_or_failed_cleanup_rejected(self):
        for change in (lambda v: v['original_installation']['result'].update(sha256='e' * 64),
                       lambda v: v['owned_cleanup']['actual_device'].update(state='Booted'),
                       lambda v: v['offline_host_cleanup'].update(verified=False)):
            collection, arguments = complete(); edit_record(collection, 'RESULT.json', change)
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_absent_or_changed_corpus_cannot_match_null_to_null(self):
        for change in (lambda v: v.update(database_after={}, installation_before={}),
                       lambda v: v['database_after'].update(sha256='e' * 64)):
            collection, arguments = complete(); edit_record(collection, 'RESULT.json', change)
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_missing_native_file_or_current_controller_alive_fails(self):
        for change in (lambda c, a: c['nativeRetained']['xcresult'].update(observedPresent=False),
                       lambda c, a: c['nativeRetained'].pop('RUN_ATTEMPT.json'),
                       lambda c, a: c.update(currentControllerProcess=a['binding']['process'])):
            collection, arguments = complete(); change(collection, arguments)
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_original_pages_must_include_all_intermediate_sql_identities(self):
        for phase in m.CASE_IDS:
            collection, arguments = complete(phase)
            edit_record(collection, 'offline_case', lambda p: p['originalPages']['contents']['events'].pop(1))
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_original_lease_or_relay_copy_cannot_be_substituted(self):
        for key in ('lease', 'oracleRelay'):
            collection, arguments = complete(); edit_record(collection, 'offline_case', lambda p: p[key].update(sha256='e' * 64))
            with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_actual_root_cleanup_digest_must_match_live_restoration(self):
        collection, arguments = complete(); arguments['state'].restored['cleanupSHA256'] = 'e' * 64
        with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_original_native_result_bytes_must_match_final_row(self):
        collection, arguments = complete(); edit_record(collection, 'RESULT.json', lambda v: v['case_results'][0].update(passed=False))
        with self.assertRaises(ValueError): m.validate_final(collection, **arguments)

    def test_modified_transfer_or_duplicate_json_rejected(self):
        value = pack('/synthetic/file', b'original'); value['rawBase64'] = base64.b64encode(b'changed').decode()
        with self.assertRaises(ValueError): m.unpack(value)
        with self.assertRaises(ValueError): m.strict_json(b'{"requestID":"a","requestID":"b"}')

    def test_private_response_modes_links_and_symlink_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); path = root / 'response'; path.write_bytes(b'original'); path.chmod(0o600)
            self.assertEqual(m.local_private_bytes(w, path), b'original')
            path.chmod(0o644)
            with self.assertRaises(ValueError): m.local_private_bytes(w, path)
            path.chmod(0o600); os.link(path, root / 'linked')
            with self.assertRaises(ValueError): m.local_private_bytes(w, path)
            (root / 'linked').unlink(); (root / 'symlink').symlink_to(path)
            with self.assertRaises(ValueError): m.local_private_bytes(w, root / 'symlink')

    def test_private_owner_change_during_read_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'response'; path.write_bytes(b'original'); path.chmod(0o600)
            def read(*args): path.chmod(0o644); return b'original'
            fake = Mock(); fake.read_bytes.side_effect = read
            with self.assertRaises(ValueError): m.local_private_bytes(fake, path)

    def test_remote_writer_stages_complete_private_bytes_before_atomic_publish(self):
        remote = remote_functions()
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory); parent.chmod(0o700); raw = b'complete-original-bytes'
            real_rename = os.rename
            def observed(before, after):
                self.assertFalse(Path(after).exists()); self.assertEqual(Path(before).read_bytes(), raw)
                self.assertEqual(stat.S_IMODE(Path(before).stat().st_mode), 0o600); self.assertEqual(Path(before).stat().st_nlink, 1)
                return real_rename(before, after)
            with patch.object(os, 'rename', side_effect=observed):
                value = remote['publish'](parent, 'COORDINATION_INPUT.private.json', raw)
            self.assertEqual(value, fw(str(parent / 'COORDINATION_INPUT.private.json'), raw))

    def test_remote_writer_preserves_existing_foreign_final(self):
        remote = remote_functions()
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory); target = parent / 'COORDINATION_INPUT.private.json'; target.write_bytes(b'foreign')
            before = target.stat().st_ino
            with self.assertRaises(ValueError): remote['publish'](parent, target.name, b'new')
            self.assertEqual(target.read_bytes(), b'foreign'); self.assertEqual(target.stat().st_ino, before)

    def test_remote_write_failure_removes_only_its_unpublished_stage(self):
        remote = remote_functions()
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory); foreign = parent / 'foreign'; foreign.write_bytes(b'keep')
            with patch.object(os, 'fsync', side_effect=OSError('synthetic ENOSPC')):
                with self.assertRaises(OSError): remote['publish'](parent, 'COORDINATION_INPUT.private.json', b'original')
            self.assertEqual(list(parent.iterdir()), [foreign]); self.assertEqual(foreign.read_bytes(), b'keep')

    def test_remote_private_directory_mode_change_blocks_publication(self):
        remote = remote_functions()
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory); parent.chmod(0o700); original = os.fsync
            def changed(fd): original(fd); parent.chmod(0o755)
            with patch.object(os, 'fsync', side_effect=changed):
                with self.assertRaises(ValueError): remote['publish'](parent, 'COORDINATION_INPUT.private.json', b'original')
            self.assertFalse((parent / 'COORDINATION_INPUT.private.json').exists())

    def test_linux_ssh_identity_preserves_multiword_remote_argv(self):
        command = ['/usr/bin/ssh', 'scaleway-mac', 'python -c "print(1)"']; child = Mock(pid=200); child.poll.return_value = None
        identity = {'pid': 200, 'parentPID': os.getpid(), 'startUTC': 'original', 'command': ' '.join(command)}
        window = Mock(); window.process.return_value = identity
        with patch.object(Path, 'open', return_value=io.BytesIO(b'\0'.join(v.encode() for v in command) + b'\0')):
            self.assertEqual(m.qualified_ssh_identity(window, child, None, command, os.getpid()), identity)

    def test_reaped_ssh_never_adopts_reused_pid_or_signals_it(self):
        child = Mock(pid=200); child.poll.return_value = 0; window = Mock()
        window.process.return_value = {'pid': 200, 'parentPID': os.getpid(), 'command': 'foreign'}
        with patch.object(Path, 'open') as reader:
            with self.assertRaises(ValueError): m.qualified_ssh_identity(window, child, None, ['/synthetic/ssh'], os.getpid())
            reader.assert_not_called()

    def test_ssh_fallback_requires_original_popen_still_live_after_observation(self):
        command = ['/synthetic/ssh']; child = Mock(pid=200); child.poll.side_effect = [None, 0]
        window = Mock(); window.process.return_value = {'pid': 200, 'parentPID': os.getpid(), 'command': command[0]}
        with patch.object(Path, 'open', return_value=io.BytesIO(command[0].encode() + b'\0')):
            with self.assertRaises(ValueError): m.qualified_ssh_identity(window, child, None, command, os.getpid())

    def test_stream_partial_event_and_size_failure_never_mark_complete_success(self):
        for chunks in ([b'partial', b''], [b'a' * 20, b'']):
            with tempfile.TemporaryDirectory() as directory:
                subject = m.StreamCapture(Mock(), Path(directory) / 'stdout', queue.Queue(), 'stdout', maximum=10)
                with patch.object(os, 'read', side_effect=chunks): subject.read()
                self.assertIsNotNone(subject.error); self.assertTrue(subject.finished); self.assertIsNone(subject.record)

    def test_stream_real_marker_is_queued_without_waiting_for_ssh_exit(self):
        line = m.EVENT_MARKER + '{"synthetic":"actual-pipe-shape"}'
        with tempfile.TemporaryDirectory() as directory:
            events = queue.Queue(); subject = m.StreamCapture(Mock(), Path(directory) / 'stdout', events, 'stdout')
            with patch.object(os, 'read', side_effect=[(line + '\n').encode(), b'']): subject.read()
            self.assertEqual(events.get_nowait(), line); self.assertIsNone(subject.error)

    def test_interrupted_start_is_unverified_even_if_thread_appears_dead(self):
        for role in ('stdout', 'stdin'):
            subject = object.__new__(m.OracleOfflineCoordinator)
            subject.cleanup_receipt = None; subject.relay = subject.child = None; subject.captures = []
            subject.stdin_thread = None; subject.stdin_start_attempted = False
            thread = Mock(); thread.ident = None; thread.is_alive.return_value = False
            if role == 'stdout':
                capture = Mock(); capture.channel = role; capture.thread = thread; capture.start_attempted = True
                subject.captures = [capture]
            else: subject.stdin_thread = thread; subject.stdin_start_attempted = True
            subject.write = Mock(return_value={'path': '/synthetic/cleanup'})
            subject.cleanup(True)
            value = subject.write.call_args.args[1]
            self.assertFalse(value['ownedLocalProcessesAndStreamsStopped']); self.assertTrue(value['errors'])
            thread.join.assert_not_called()

    def test_one_reader_cleanup_failure_does_not_skip_other_owned_join(self):
        subject = object.__new__(m.OracleOfflineCoordinator)
        subject.cleanup_receipt = None; subject.relay = subject.child = None
        first, second = Mock(), Mock()
        for row in (first, second): row.start_attempted = True; row.channel = 'synthetic'; row.thread.is_alive.return_value = False
        first.thread.ident = None; second.thread.ident = 123
        subject.captures = [first, second]; subject.stdin_thread = None; subject.stdin_start_attempted = False
        subject.write = Mock(return_value={'path': '/synthetic/cleanup'})
        subject.cleanup(True); second.thread.join.assert_called_once_with(timeout=2)
        self.assertFalse(subject.write.call_args.args[1]['ownedLocalProcessesAndStreamsStopped'])

    def test_all_owned_lifecycle_failures_cleanup_and_retain_partial_evidence(self):
        for stage in ('start', 'loop', 'collect', 'validate'):
            subject = object.__new__(m.OracleOfflineCoordinator)
            subject.child = Mock(returncode=0); subject.start = Mock(); subject.loop = Mock(); subject.cleanup = Mock()
            subject.cleanup_receipt = {'path': '/synthetic/cleanup'}; subject.window = Mock()
            subject.window.strict_json.return_value = {'ownedLocalProcessesAndStreamsStopped': True}
            subject.rpc = Mock(return_value={'actualPartialEvidence': True}); subject.final_collection = None
            subject.root = Path('/synthetic'); subject.sources = {}; subject.state = Mock(); subject.binding = {}; subject.source_before = {}
            subject.response = {}; subject.mac_relay_rows = {}; subject.join = j; subject.errors = []
            subject.input_record = subject.source_record = {}; subject.event_records = []; subject.response_record = None
            subject.relay_result = None; subject.rpc_records = []; subject.captures = []; subject.write = Mock(side_effect=lambda name, value: {'path': name})
            if stage in ('start', 'loop'): getattr(subject, stage).side_effect = OSError('synthetic stage failure')
            if stage == 'collect': subject.rpc.side_effect = OSError('synthetic final read failure')
            with patch.object(m, 'current_sources', return_value={}), patch.object(m, 'validate_final', side_effect=ValueError('synthetic final validation')):
                with self.assertRaises((OSError, ValueError)): subject.run()
            self.assertTrue(subject.cleanup.called)
            result = next(call.args[1] for call in subject.write.call_args_list if call.args[0] == 'RESULT.private.json')
            self.assertEqual(result['status'], 'FAILED_OR_INCOMPLETE')
            if stage != 'collect': self.assertIsNotNone(result['originalMacEvidence'])

    def test_no_runtime_functions_invoked_by_source_import(self):
        top = ast.parse(SOURCE.read_text()).body
        calls = [n for n in top if isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)]
        self.assertEqual(calls, [])


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Controls))
    report = {'scope': 'SYNTHETIC_SOURCE_ADMISSION_LIFECYCLE_AND_LOCAL_TEMPFILE_CONTROLS_ONLY',
              'sourceSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'testsRun': result.testsRun,
              'failures': len(result.failures), 'errors': len(result.errors), 'actualSSH': 0, 'actualMac': 0,
              'actualNetworkDenial': 0, 'actualNativeCases': 0, 'actualSignals': 0}
    (HERE / 'SOURCE_CONTROLS.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() else 1)
