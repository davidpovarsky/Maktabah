#!/usr/bin/env python3
"""Observed no-denial watchdog exercises, using only explicitly owned processes.

Importing has no effects. Root supplies real Mac/Oracle coordination callbacks.
No activation, transport probe, Simulator action or approval producer exists here.
The private worker CLI is launched only by NoDenialExercise on the actual Mac.
"""
from __future__ import annotations

import argparse
import base64
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import queue
import re
import select
import shlex
import signal
import subprocess
import sys
import threading
import time
import uuid

SCHEMA = 'otzaria.observed-no-denial-watchdog-exercise/1'
RELAY_SCHEMA = 'otzaria.owned-original-oracle-relay/1'
EXERCISE_PASS = 'ACTUAL_NO_DENIAL_WATCHDOG_RECOVERY_VERIFIED'
REASONS = {'controller-death': 'controller-identity-missing', 'deadline': 'hard-deadline',
           'heartbeat-loss': 'authenticated-oracle-heartbeat-expired'}
SOURCE_NAMES = ('study-ui-offline-exercises.py', 'study-ui-offline-window.py',
                'study-ui-offline-heartbeat.py', 'study-ui-offline-execution.py',
                'study-ui-settings-receipts.py', 'runtime27_interruption.py')
MAX_FRAME = 256 * 1024
MAX_STREAM = 2 * 1024 * 1024
MAX_EXERCISE_SECONDS = 120


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load(path):
    name = 'owned_exercise_' + Path(path).stem.replace('-', '_')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def dependencies(repository):
    root = Path(repository)
    require(root.is_absolute() and root.resolve(strict=True) == root, 'Canonical original checkout required')
    sources = {}
    for name in SOURCE_NAMES:
        path = root / 'Scripts/CI' / name
        require(path.resolve(strict=True) == path and path.is_file(), 'Source file was redirected')
        actual = subprocess.run(['git', '-C', str(root), 'hash-object', str(path)], capture_output=True, timeout=5, check=True)
        committed = subprocess.run(['git', '-C', str(root), 'rev-parse', 'HEAD:Scripts/CI/' + name], capture_output=True, timeout=5, check=True)
        require(not actual.stderr and not committed.stderr and actual.stdout == committed.stdout, 'Exercise source differs from current committed checkout')
        raw = path.read_bytes()
        require(len(raw) <= 1024 * 1024, 'Exercise source exceeded its bound')
        sources[name] = {'path': str(path), 'bytes': len(raw), 'sha256': sha(raw)}
    require(Path(__file__).resolve() == root / 'Scripts/CI/study-ui-offline-exercises.py', 'Execute the actual committed helper')
    window = load(root / 'Scripts/CI/study-ui-offline-window.py')
    join = load(root / 'Scripts/CI/study-ui-offline-execution.py')
    settings = load(root / 'Scripts/CI/study-ui-settings-receipts.py')
    interruption = load(root / 'Scripts/CI/runtime27_interruption.py')
    return root, sources, window, join, settings, interruption


def new_directory(path):
    directory = Path(path)
    require(directory.is_absolute() and not directory.exists() and directory.parent.resolve(strict=True) == directory.parent,
            'Use a new private directory with an existing canonical parent')
    directory.mkdir(mode=0o700)
    require(directory.resolve() == directory and directory.stat().st_uid == os.getuid(), 'Private output owner differs')
    return directory


def frame(nonce, sequence, event, payload):
    return {'schema': SCHEMA, 'nonce': nonce, 'sequence': sequence, 'event': event, 'payload': payload}


def validate_frame(value, nonce, sequence, event):
    require(isinstance(value, dict) and set(value) == {'schema', 'nonce', 'sequence', 'event', 'payload'}
            and value['schema'] == SCHEMA and value['nonce'] == nonce and type(value['sequence']) is int
            and value['sequence'] == sequence and value['event'] == event and isinstance(value['payload'], dict),
            'Foreign, reordered or malformed owned worker frame')
    return value['payload']


def emit(nonce, sequence, event, payload):
    raw = json.dumps(frame(nonce, sequence, event, payload), separators=(',', ':'), allow_nan=False).encode() + b'\n'
    require(len(raw) <= MAX_FRAME, 'Owned worker frame exceeded its limit')
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


def read_input(window, nonce, sequence, event, deadline):
    raw = bytearray()
    while b'\n' not in raw:
        remaining = deadline - time.monotonic()
        require(remaining > 0, 'Coordinator input deadline expired before any new action')
        ready, _, _ = select.select([sys.stdin.buffer], [], [], min(remaining, 1))
        if not ready:
            continue
        block = os.read(sys.stdin.fileno(), min(4096, MAX_FRAME + 1 - len(raw)))
        require(block, 'Coordinator closed its owned worker pipe')
        raw.extend(block)
        require(len(raw) <= MAX_FRAME, 'Coordinator input exceeded its bound')
    require(raw.endswith(b'\n') and raw.count(b'\n') == 1, 'Exactly one owned coordinator frame required')
    return validate_frame(window.strict_json(bytes(raw)), nonce, sequence, event)


def no_denial_state(state, identifier):
    require(isinstance(state, dict) and 'activated' not in state and 'rollback-failure' not in state,
            'No-denial exercise activated or lost verified rollback')
    for key in ('armed', 'status', 'cleanup'):
        if key in state:
            require(state[key].get('windowID') == identifier, 'Another watchdog receipt entered the exercise')
    if 'status' in state:
        require(state['status'].get('active') is False and state['status'].get('counters') == ''
                and state['status'].get('mode') == 'watchdog-exercise-no-denial', 'No-denial status is not empty and inactive')
    if 'cleanup' in state:
        require(state['cleanup'].get('activated') is False and state['cleanup'].get('mode') == 'watchdog-exercise-no-denial',
                'Cleanup belongs to an activated or different mode')
    return state


def admit_exercise(lease, coordination, *, kind, actual_pid, source_sha, window, join, now):
    require(kind in REASONS, 'Unknown no-denial failure trigger')
    admitted = window.admit_lease(lease, source_sha, now=now)
    require(admitted['mode'] == 'watchdog-exercise-no-denial' and admitted.get('exerciseKind') == kind
            and admitted['controllerPID'] == actual_pid, 'Exercise requires its actual worker PID and explicit no-denial lease')
    require(45 < admitted['hardDeadlineUnix'] - now <= MAX_EXERCISE_SECONDS,
            'Use an explicitly coordinated bounded exercise lease; never extend it')
    join.validate_coordination(coordination, admitted, now)
    return admitted


def transferred(settings, envelope, key='record'):
    """Root transfers original Oracle bytes; changed paths do not imply equality."""
    local, original = envelope[key], envelope['original' + key[0].upper() + key[1:]]
    require(set(local) == set(original) == {'path', 'bytes', 'sha256'}
            and local['bytes'] == original['bytes'] and local['sha256'] == original['sha256'],
            'Transferred Oracle receipt differs from its original bytes')
    return settings.verify_witness(local, MAX_STREAM)


def validate_relay_start(value, rendezvous, sources):
    require(value.get('schema') == RELAY_SCHEMA and value.get('status') == 'OWNED_ORIGINAL_RELAY_STARTED'
            and value.get('windowID') == rendezvous['windowID']
            and value.get('oracleEUID') == 1001 and value.get('oracleUser') == 'ubuntu'
            and value.get('existingAlias') == 'scaleway-mac'
            and value.get('helperSourceSHA256') == sources['study-ui-offline-exercises.py']['sha256']
            and value.get('relaySourceSHA256') == sources['study-ui-offline-heartbeat.py']['sha256'],
            'Oracle relay is not the original qualified non-root producer')
    process, command = value.get('process', {}), value.get('command', [])
    require(type(process.get('pid')) is int and process['pid'] > 1 and process.get('parentPID') == value.get('supervisorPID')
            and shlex.split(process.get('command', '')) == command and len(command) == 8
            and command[2:4] == ['--window', rendezvous['windowID']]
            and command[4:6] == ['--deadline-unix', str(rendezvous['hardDeadlineUnix'])]
            and command[6] == '--output' and command[1] == value.get('relaySourcePath'),
            'Original relay PID/start/parent/command is unbound')
    return value


def validate_relay_rows(raw, start, *, required_nonce):
    require(raw and len(raw) <= MAX_STREAM and raw.endswith(b'\n'), 'Original Oracle JSONL is absent, partial or oversized')
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'Repeated original Oracle JSON key')
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('Nonfinite original Oracle JSON')
    rows = [json.loads(line, object_pairs_hook=pairs, parse_constant=invalid) for line in raw.splitlines()]
    require(rows and len(rows) <= 128, 'Original relay exceeded its 900-second bounded row count')
    seen = set()
    previous = None
    for number, row in enumerate(rows):
        require(row.get('windowID') == start['windowID'] and type(row.get('sequence')) is int and row['sequence'] == number
                and row.get('relayProcessID') == start['process']['pid']
                and row.get('relaySourceSHA256') == start['relaySourceSHA256'] and row.get('exit') == 0
                and row.get('stderrSHA256') == sha(b'') and type(row.get('startedUnix')) in (int, float)
                and type(row.get('finishedUnix')) in (int, float) and row['startedUnix'] <= row['finishedUnix']
                and (previous is None or previous <= row['startedUnix']), 'Original relay source/process/sequence/local interval failed')
        previous = row['finishedUnix']
        remote = row.get('remote', {})
        require(remote.get('windowID') == start['windowID'], 'Remote heartbeat belongs to another window')
        if remote.get('status') == 'WINDOW_ALREADY_CLEANED':
            require(number == len(rows) - 1 and re.fullmatch('[a-f0-9]{64}', remote.get('cleanupSHA256', '')),
                    'Early or unbound terminal Oracle response')
        else:
            nonce = remote.get('nonce', '')
            require(re.fullmatch('[a-f0-9]{32}', nonce) and nonce not in seen, 'Repeated or missing actual Oracle nonce')
            seen.add(nonce)
    require(required_nonce in seen, 'Actual Mac heartbeat has no matching original Oracle response')
    return rows


def qualified_stop(value, process):
    require(value.get('process') == process and value.get('group', {}).get('owned_pgid') == process['pid']
            and value['group'].get('group_state') == 'GONE_CHECKED'
            and not value['group'].get('probe_errors') and not value['group'].get('send_errors')
            and value.get('subprocess', {}).get('pid') == process['pid']
            and value['subprocess'].get('state') in ('EXITED', 'TERMINATED', 'KILLED')
            and value.get('actualProcessAbsent') is True, 'Owned process or group cleanup is unverified')
    return value


def created_child_identity(window, child, identity, command, parent_pid):
    """Never adopt a later process merely because its PID matches our Popen."""
    require(isinstance(command, list) and command and type(parent_pid) is int,
            'The original pre-launch argv/parent must be retained')
    def matches(value):
        return value is not None and value.get('pid') == child.pid and value.get('parentPID') == parent_pid \
            and shlex.split(value.get('command', '')) == command
    if identity is not None:
        require(matches(identity), 'The original observed identity was never qualified as this child')
        return identity
    original_status = child.poll()
    current = window.process(child.pid)
    if original_status is not None:
        require(current is None, 'Refuse adopting a live reused PID after the original child was reaped')
        return None
    require(matches(current) and child.poll() is None,
            'Fallback identity requires the same still-live original child and exact launch argv/parent')
    return current


def stop_owned(window, interruption, child, identity):
    current = window.process(child.pid)
    require(current is None or current == identity, 'Refuse signaling a replaced owned process identity')
    require(identity is not None or (current is None and child.poll() is not None),
            'An unobserved live process cannot be signaled by inferred identity')
    result = {'process': identity, 'createdChildPID': child.pid, 'startedUnix': time.time(), 'startedMonotonic': time.monotonic()}
    result['group'] = interruption.stop_owned_process_group(child, grace_seconds=1, kill_wait_seconds=.5)
    result['subprocess'] = interruption.stop_owned_subprocess(child)
    result.update(finishedUnix=time.time(), finishedMonotonic=time.monotonic(), actualProcessAbsent=window.process(child.pid) is None)
    if identity is None:
        # Only a directly created, already reaped child can reach this failure
        # cleanup path. Its original group may still contain owned descendants.
        require(result['group'].get('group_state') == 'GONE_CHECKED'
                and not result['group'].get('probe_errors') and not result['group'].get('send_errors')
                and result['subprocess'].get('state') in ('EXITED', 'TERMINATED', 'KILLED')
                and result['actualProcessAbsent'], 'Created failed-launch group cleanup remains unverified')
        result['sourceIdentityUnavailableNoAcceptance'] = True
        return result
    return qualified_stop(result, identity)


ROOT_EXERCISE_READER = r'''
from pathlib import Path
import base64,hashlib,importlib.util,json,os,re,stat,sys
identifier=sys.argv[1];assert re.fullmatch('[a-f0-9]{32}',identifier)
directory=Path('/Library/Application Support/OtzariaOffline')/identifier
code=directory/'watchdog.py'
assert code.resolve(strict=True)==code
for p in [code,*code.parents]:
 s=p.lstat();assert s.st_uid==0 and not s.st_mode&0o022 and not stat.S_ISLNK(s.st_mode)
spec=importlib.util.spec_from_file_location('original_sealed_exercise_reader',code)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
_,sealed=m.load_sealed(identifier);records={}
for name in ['sealed.json','armed.json','status.json','cleanup.json','unloaded.json','heartbeat.json','watchdog.py']:
 path=directory/name
 if not path.exists():continue
 raw=m.read_bytes(m.root_file(path),4*1024*1024);s=path.stat()
 records[name]={'sourcePath':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'rawBase64':base64.b64encode(raw).decode(),'uid':s.st_uid,'mode':stat.S_IMODE(s.st_mode)}
rules=m.pf('-a',m.anchor_name(identifier),'-sr')
rc,stdout,stderr=m.run(['/bin/launchctl','print','system/'+m.label_name(identifier)],allowed=(0,3,113))
absent=rc!=0 and ('Could not find service' in stderr or 'No such process' in stderr)
print(json.dumps({'exports':{identifier:records},'currentBoot':m.boot_identity(),'currentOwnedRulesSHA256':hashlib.sha256(rules.encode()).hexdigest(),'currentDaemonAbsent':absent,'currentPlistAbsent':not (m.DAEMONS/(m.label_name(identifier)+'.plist')).exists(),'observedUnix':m.time.time(),'observedMonotonic':m.time.monotonic()}))
'''


def root_snapshot(window, identifier):
    _, stdout, stderr = window.run(['/usr/bin/sudo', '-n', '/usr/bin/python3', '-I', '-B', '-c', ROOT_EXERCISE_READER, identifier], timeout=20, maximum=MAX_STREAM)
    require(not stderr, 'Original root receipt read was incomplete')
    return window.strict_json(stdout)


def validate_exercise_root(snapshot, *, lease, kind, source_sha, controller, deployment, heartbeat, trigger, join, window):
    identifier = lease['windowID']
    exports = snapshot['exports']
    require(set(exports) == {identifier}, 'Another root window entered this exercise')
    doc = lambda name: join.root_document(exports, identifier, name)
    sealed, armed, cleanup, unloaded = (doc(name) for name in ('sealed.json', 'armed.json', 'cleanup.json', 'unloaded.json'))
    require(sealed.get('lease') == lease and sealed.get('sourceSHA256') == source_sha
            and sha(doc('watchdog.py')) == source_sha and sealed.get('controller') == controller
            and snapshot.get('currentBoot') == sealed.get('bootSession')
            and deployment.get('windowID') == identifier
            and deployment.get('sealedSHA256') == exports[identifier]['sealed.json']['sha256'],
            'Actual sealed source/lease/boot/controller/deployment differs')
    require(type(armed.get('watchdog', {}).get('pid')) is int and armed['watchdog']['pid'] > 1
            and armed.get('windowID') == identifier, 'An actual root-owned watchdog never armed')
    require(cleanup.get('status') == 'OWNED_RULES_EMPTY_ROLLBACK_VERIFIED'
            and cleanup.get('windowID') == identifier and cleanup.get('mode') == 'watchdog-exercise-no-denial'
            and cleanup.get('reason') == REASONS[kind] and cleanup.get('activated') is False
            and cleanup.get('onlyOwnedAnchor') == window.anchor_name(identifier)
            and cleanup.get('attempts') and all(row.get('exit') == 0 and row.get('rulesBeforeSHA256') == sha(b'') for row in cleanup['attempts']),
            'Actual expected no-denial cleanup reason/empty owned rules is missing')
    history = cleanup.get('history')
    require(isinstance(history, list) and history
            and all(row.get('active') is False and row.get('counters') == '' for row in history)
            and heartbeat.get('heartbeatNonce') in {row.get('heartbeatNonce') for row in history},
            'Actual unmodified no-denial history never observed the original Oracle heartbeat')
    require(unloaded.get('status') == 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY'
            and unloaded.get('windowID') == identifier and unloaded.get('originalConfigurationMatches') is True
            and snapshot.get('currentOwnedRulesSHA256') == sha(b'')
            and snapshot.get('currentDaemonAbsent') is True and snapshot.get('currentPlistAbsent') is True,
            'Owned daemon/rules or original host configuration were not restored')
    require(trigger['kind'] == kind and trigger['startedMonotonic'] <= cleanup['cleanupMonotonic'], 'Cleanup preceded its actual failure trigger')
    if kind == 'controller-death':
        qualified_stop(trigger['ownedControllerStop'], controller)
    else:
        require(trigger.get('controllerObservedAfterCleanup') == controller, 'Controller did not remain alive through the observed cleanup')
    if kind == 'deadline':
        require(cleanup['cleanupUnix'] >= lease['hardDeadlineUnix'] or cleanup['cleanupMonotonic'] >= sealed['hardDeadlineMonotonic'],
                'Deadline exercise ended before either sealed clock deadline')
    if kind == 'heartbeat-loss':
        last = doc('heartbeat.json')
        require(cleanup['cleanupMonotonic'] - last['observedMonotonic'] >= window.HEARTBEAT_TIMEOUT,
                'Heartbeat-loss receipt did not observe the original expiration interval')
    return {'cleanup': {'path': str(window.BASE / identifier / 'cleanup.json'),
                        'bytes': exports[identifier]['cleanup.json']['bytes'], 'sha256': exports[identifier]['cleanup.json']['sha256']},
            'bootSession': sealed['bootSession'], 'sourceSHA256': source_sha, 'reason': cleanup['reason'],
            'watchdog': armed['watchdog'], 'originalConfigurationMatches': True, 'activated': False}


class OwnedOracleRelay:
    """Explicit Oracle callback implementation; it never grants Mac permission."""
    def __init__(self, *, repository, output_directory, rendezvous):
        import pwd
        require(sys.platform == 'linux' and os.geteuid() == 1001 and pwd.getpwuid(os.geteuid()).pw_name == 'ubuntu',
                'Use the existing verified ubuntu SSH owner')
        self.root, self.sources, self.window, self.join, self.settings, self.interruption = dependencies(repository)
        self.output = new_directory(output_directory)
        self.ready = dict(rendezvous)
        require(self.ready['oracleRelaySource']['sha256'] == self.sources['study-ui-offline-heartbeat.py']['sha256'], 'Oracle/Mac relay source differs')
        self.child = self.identity = self.start_value = self.finished = self.finished_stop = None
        self.command, self.parent_pid = None, os.getpid()
        self.logs = []

    def start(self):
        require(self.child is None, 'Start this actual owned relay only once')
        path = self.output / 'heartbeat.jsonl'
        command = [sys.executable, self.sources['study-ui-offline-heartbeat.py']['path'], '--window', self.ready['windowID'],
                   '--deadline-unix', str(self.ready['hardDeadlineUnix']), '--output', str(path)]
        self.command = command
        try:
            stdout = (self.output / 'relay.stdout.log').open('xb'); self.logs.append(stdout)
            stderr = (self.output / 'relay.stderr.log').open('xb'); self.logs.append(stderr)
            self.child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr, start_new_session=True)
            self.identity = created_child_identity(self.window, self.child, None, self.command, self.parent_pid)
            require(self.identity is not None, 'The relay ended before its original identity was observed')
            self.start_value = {'schema': RELAY_SCHEMA, 'status': 'OWNED_ORIGINAL_RELAY_STARTED', 'windowID': self.ready['windowID'],
                'oracleEUID': os.geteuid(), 'oracleUser': 'ubuntu', 'existingAlias': 'scaleway-mac', 'supervisorPID': os.getpid(),
                'process': self.identity, 'command': command, 'startedOracleUnix': time.time(),
                'helperSourceSHA256': self.sources['study-ui-offline-exercises.py']['sha256'],
                'relaySourceSHA256': self.sources['study-ui-offline-heartbeat.py']['sha256'],
                'relaySourcePath': self.sources['study-ui-offline-heartbeat.py']['path']}
            validate_relay_start(self.start_value, self.ready, self.sources)
            return self.window.private_write(self.output / 'START.json', self.start_value)
        except BaseException:
            self.abort()
            raise

    def stop_for_heartbeat_loss(self, heartbeat):
        try:
            return self._stop_for_heartbeat_loss(heartbeat)
        except BaseException:
            self.abort()
            raise

    def _stop_for_heartbeat_loss(self, heartbeat):
        require(self.finished is None and self.start_value is not None and self.child.poll() is None
                and self.window.process(self.child.pid) == self.identity, 'Only the currently running exact owned relay may be stopped')
        raw = self.window.read_bytes(self.output / 'heartbeat.jsonl', MAX_STREAM)
        rows = validate_relay_rows(raw, self.start_value, required_nonce=heartbeat['heartbeatNonce'])
        require(rows[-1].get('remote', {}).get('nonce') == heartbeat['heartbeatNonce'],
                'Stop only at the matched completed heartbeat, not an unqualified in-flight state')
        stopped = stop_owned(self.window, self.interruption, self.child, self.identity)
        return self._seal('INTENTIONALLY_STOPPED_FOR_HEARTBEAT_LOSS', stopped, heartbeat['heartbeatNonce'])

    def finish(self, *, required_nonce, kind):
        try:
            return self._finish(required_nonce=required_nonce, kind=kind)
        except BaseException:
            self.abort()
            raise

    def _finish(self, *, required_nonce, kind):
        if self.finished is not None:
            require(kind == 'heartbeat-loss', 'A stopped relay cannot qualify another exercise')
            return self.finished
        require(kind in REASONS and self.start_value is not None, 'Unknown original relay finish')
        self.child.wait(timeout=12)
        require(self.child.returncode == 0, 'Original relay failed before expected cleanup/deadline')
        stopped = stop_owned(self.window, self.interruption, self.child, self.identity)
        return self._seal('ORIGINAL_RELAY_ENDED_AFTER_OBSERVATION', stopped, required_nonce)

    def finish_after_restoration(self, *, window_id, cleanup_sha256):
        try:
            return self._finish_after_restoration(window_id=window_id, cleanup_sha256=cleanup_sha256)
        except BaseException:
            self.abort()
            raise

    def _finish_after_restoration(self, *, window_id, cleanup_sha256):
        """Root's original UI phase: require the genuine terminal remote reply.

        The root then transfers only the unchanged rows to OfflineStudyCase;
        that independent collector joins every nonce to its actual root history.
        This wrapper neither activates a window nor accepts native UI results.
        """
        require(self.finished is None and self.start_value is not None
                and window_id == self.ready['windowID']
                and re.fullmatch('[a-f0-9]{64}', cleanup_sha256), 'Actual restored-window identity is required')
        self.child.wait(timeout=12)
        require(self.child.returncode == 0, 'Original relay did not end after restoration')
        raw = self.window.read_bytes(self.output / 'heartbeat.jsonl', MAX_STREAM)
        parsed = [self.window.strict_json(line) for line in raw.splitlines()]
        heartbeat_rows = [row for row in parsed if row.get('remote', {}).get('nonce')]
        require(heartbeat_rows and parsed[-1].get('remote', {}).get('status') == 'WINDOW_ALREADY_CLEANED'
                and parsed[-1]['remote'].get('cleanupSHA256') == cleanup_sha256,
                'Actual terminal Oracle reply does not bind the restored root receipt')
        nonce = heartbeat_rows[-1]['remote']['nonce']
        validate_relay_rows(raw, self.start_value, required_nonce=nonce)
        stopped = stop_owned(self.window, self.interruption, self.child, self.identity)
        return self._seal('ORIGINAL_RELAY_ENDED_AFTER_VERIFIED_RESTORATION', stopped, nonce)

    def _seal(self, status, stopped, nonce):
        raw = self.window.read_bytes(self.output / 'heartbeat.jsonl', MAX_STREAM)
        validate_relay_rows(raw, self.start_value, required_nonce=nonce)
        for handle in self.logs:
            handle.flush(); os.fsync(handle.fileno()); handle.close()
        self.logs.clear()
        value = {'schema': RELAY_SCHEMA, 'status': status, 'start': self.start_value, 'ownedStop': stopped,
                 'requiredMacNonce': nonce, 'rawRows': self.window.witness(self.output / 'heartbeat.jsonl'),
                 'stdout': self.window.witness(self.output / 'relay.stdout.log'),
                 'stderr': self.window.witness(self.output / 'relay.stderr.log'), 'clockDomain': 'Oracle-local intervals; Mac nonce observations retain their own clocks'}
        record = self.window.private_write(self.output / 'RESULT.json', value)
        self.finished = {'record': record, 'rows': value['rawRows']}
        self.finished_stop = stopped
        return self.finished

    def abort(self):
        if self.finished is not None:
            # The original group was already checked gone. Never signal a PID
            # that may later have been reused after successful completion.
            return self.finished_stop
        result = None
        try:
            if self.child is not None:
                identity = created_child_identity(self.window, self.child, self.identity, self.command, self.parent_pid)
                result = stop_owned(self.window, self.interruption, self.child, identity)
        finally:
            for handle in self.logs:
                handle.close()
            self.logs.clear()
        return result


class NoDenialExercise:
    """One real exercise; callbacks bridge to the existing Oracle coordinator.

    request_coordination(actual_ready) -> {lease:FileWitness, coordination:FileWitness}
    start_oracle(actual_rendezvous) -> transferred START record envelope
    control_oracle(action,payload) -> transferred RESULT + rows envelope
    The integration owner supplies actual approvals and byte-preserving transfer.
    """
    def __init__(self, *, repository, output_directory, kind, selected_case_id, simulator_udid,
                 request_coordination, start_oracle, control_oracle):
        require(sys.platform == 'darwin' and os.geteuid() != 0 and kind in REASONS, 'Original non-root Mac supervisor required')
        self.root, self.sources, self.window, self.join, self.settings, self.interruption = dependencies(repository)
        require(selected_case_id in self.window.CASE_IDS.values()
                and str(uuid.UUID(simulator_udid)).upper() == simulator_udid, 'Use the explicitly coordinated original case/device identity')
        require(all(callable(f) for f in (request_coordination, start_oracle, control_oracle)), 'Actual Mac/Oracle callbacks are required')
        self.output = new_directory(output_directory)
        self.kind, self.case_id, self.udid = kind, selected_case_id, simulator_udid
        self.request_coordination, self.start_oracle, self.control_oracle = request_coordination, start_oracle, control_oracle
        self.nonce = uuid.uuid4().hex
        self.child = self.identity = self.lease = self.ready = self.heartbeat = self.relay_start = None
        self.command, self.parent_pid = None, os.getpid()
        self.possible_deployment = self.relay_possible = self.unloaded = False
        self.events, self.errors, self.threads = queue.Queue(maxsize=16), [], []
        self.stderr = bytearray()

    def _read_stdout(self):
        try:
            total = 0
            while True:
                raw = self.child.stdout.readline(MAX_FRAME + 1)
                if not raw:
                    return
                total += len(raw)
                require(raw.endswith(b'\n') and len(raw) <= MAX_FRAME and total <= MAX_STREAM, 'Owned worker output was truncated or oversized')
                self.events.put(self.window.strict_json(raw), timeout=.5)
        except BaseException as error:
            self.errors.append(type(error).__name__ + ': ' + str(error))

    def _read_stderr(self):
        try:
            while True:
                raw = self.child.stderr.read(4096)
                if not raw:
                    return
                self.stderr.extend(raw)
                require(len(self.stderr) <= MAX_FRAME, 'Owned worker diagnostics exceeded their bound')
        except BaseException as error:
            self.errors.append(type(error).__name__ + ': ' + str(error))

    def _event(self, sequence, event, timeout):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            require(not self.errors, 'Owned worker stream failed: ' + repr(self.errors))
            try:
                value = self.events.get(timeout=min(.2, max(.001, end - time.monotonic())))
                result = validate_frame(value, self.nonce, sequence, event)
                self.window.private_write(self.output / ('WORKER-' + str(sequence) + '-' + event + '.json'), value)
                return result
            except queue.Empty:
                require(self.child.poll() is None, 'Owned worker exited before its exact expected event')
        raise TimeoutError('Owned worker event did not arrive within its bounded interval: ' + event)

    def _send(self, sequence, event, payload):
        raw = json.dumps(frame(self.nonce, sequence, event, payload), allow_nan=False).encode() + b'\n'
        require(len(raw) <= MAX_FRAME, 'Owned worker input exceeds its bound')
        self.child.stdin.write(raw); self.child.stdin.flush()

    def _private(self, action):
        require(action in ('status', 'finish', 'unload'), 'Exercise supervisor has no activation operation')
        path = self.window.BASE / self.lease['windowID'] / 'watchdog.py'
        _, out, error = self.window.run(['/usr/bin/sudo', '-n', '/usr/bin/python3', '-I', '-B', str(path), action, self.lease['windowID']], timeout=12)
        require(not error, 'Original owned watchdog diagnostic')
        return self.window.strict_json(out)

    def _wait_cleanup(self, maximum):
        end = time.monotonic() + maximum
        while time.monotonic() < end:
            state = no_denial_state(self._private('status'), self.lease['windowID'])
            if 'cleanup' in state:
                return state['cleanup']
            time.sleep(.25)
        raise TimeoutError('Original owned watchdog cleanup remains unverified')

    def _unload(self):
        before = root_snapshot(self.window, self.lease['windowID'])
        unload_error = None
        if 'unloaded.json' not in before['exports'][self.lease['windowID']]:
            try:
                self._private('unload')
            except BaseException as error:
                # The worker's own error-finally may concurrently finish this
                # same UUID. Re-read actual root receipts/kernel state; never
                # infer successful cleanup from a missing plist alone.
                unload_error = type(error).__name__ + ': ' + str(error)
        after = root_snapshot(self.window, self.lease['windowID'])
        completed = self.join.root_document(after['exports'], self.lease['windowID'], 'unloaded.json')
        require(completed.get('windowID') == self.lease['windowID']
                and completed.get('status') == 'OWNED_DAEMON_UNLOADED_PLIST_REMOVED_RULES_EMPTY'
                and after['currentDaemonAbsent'] is True and after['currentPlistAbsent'] is True
                and after['currentOwnedRulesSHA256'] == sha(b''), 'Owned exercise daemon/rules still present')
        if unload_error is not None:
            after['concurrentOwnedUnloadDiagnostic'] = unload_error
        self.unloaded = True
        return after

    def run(self):
        result = None
        try:
            command = [sys.executable, str(Path(__file__).resolve()), '--worker', self.kind,
                       '--nonce', self.nonce, '--output', str(self.output / 'worker')]
            self.command = command
            self.child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
            # This try already owns the process: an ENOSPC receipt cannot escape cleanup.
            self.identity = created_child_identity(self.window, self.child, None, self.command, self.parent_pid)
            require(self.identity is not None, 'Owned worker ended before its original identity was observed')
            self.window.private_write(self.output / 'LAUNCH.json', {'command': command, 'process': self.identity, 'sources': self.sources})
            for callback in (self._read_stdout, self._read_stderr):
                thread = threading.Thread(target=callback, daemon=True); self.threads.append(thread); thread.start()
            actual = self._event(0, 'CONTROLLER_READY', 15)
            require(actual['process'] == self.identity and actual['sources'] == self.sources, 'Ready record is not the actual source-qualified child')
            actual.update(exerciseKind=self.kind, selectedCaseID=self.case_id, simulatorUDID=self.udid)
            admission = self.request_coordination(actual)
            lease = self.settings.decode_json(self.settings.verify_witness(admission['lease']))
            coordination = self.settings.decode_json(self.settings.verify_witness(admission['coordination']))
            self.lease = admit_exercise(lease, coordination, kind=self.kind, actual_pid=self.child.pid,
                source_sha=self.sources['study-ui-offline-window.py']['sha256'], window=self.window, join=self.join, now=time.time())
            require(self.lease['selectedCaseID'] == self.case_id and self.lease['simulatorUDID'] == self.udid, 'Actual coordination changed the original case/device')
            for owner in coordination['owners']:
                self.settings.verify_witness(owner['originalAcknowledgement'])
            self.possible_deployment = True
            self._send(0, 'ADMIT', admission)
            self.ready = self._event(1, 'PREPARED', 40)
            require(self.ready['windowID'] == self.lease['windowID'] and self.ready['actualControllerPID'] == self.child.pid
                    and self.ready['hardDeadlineUnix'] == self.lease['hardDeadlineUnix'], 'Actual prepared window differs')
            self.relay_possible = True
            transferred_start = self.start_oracle(self.ready)
            self.relay_start = validate_relay_start(self.settings.decode_json(transferred(self.settings, transferred_start)), self.ready, self.sources)
            self.heartbeat = self._event(2, 'HEARTBEAT_PROVEN', 15)
            state = no_denial_state(self.heartbeat['state'], self.lease['windowID'])
            heartbeat = state['status']
            require(re.fullmatch('[a-f0-9]{32}', heartbeat.get('heartbeatNonce', ''))
                    and 0 <= time.monotonic() - heartbeat['heartbeatMonotonic'] <= 10, 'Fresh actual root heartbeat is missing at the trigger boundary')
            trigger = {'kind': self.kind, 'startedUnix': time.time(), 'startedMonotonic': time.monotonic()}
            if self.kind != 'deadline':
                require(self.lease['hardDeadlineUnix'] - time.time() > self.window.HEARTBEAT_TIMEOUT + self.window.MAX_WATCHDOG_GAP + 10,
                        'The sealed deadline cannot substitute for the requested failure trigger')
            if self.kind == 'controller-death':
                require(self.heartbeat.get('awaitingOnlyOwnedTermination') is True, 'Worker has not entered its explicit abrupt-death boundary')
                require(self.child.poll() is None and self.window.process(self.child.pid) == self.identity,
                        'Controller-death trigger requires the still-running exact owned child')
                trigger['ownedControllerStop'] = stop_owned(self.window, self.interruption, self.child, self.identity)
                self._wait_cleanup(20)
            else:
                if self.kind == 'heartbeat-loss':
                    trigger['relayStop'] = self.control_oracle('heartbeat-loss', {'windowID': self.lease['windowID'], 'heartbeat': heartbeat})
                self._send(1, 'OBSERVE_CLEANUP', {'kind': self.kind})
                observed = self._event(3, 'CLEANUP_OBSERVED', min(MAX_EXERCISE_SECONDS + 20, max(1, self.lease['hardDeadlineUnix'] - time.time() + 20)))
                no_denial_state(observed['state'], self.lease['windowID'])
                trigger['controllerObservedAfterCleanup'] = self.window.process(self.child.pid)
                require(trigger['controllerObservedAfterCleanup'] == self.identity, 'Original child died before cleanup observation')
            snapshot = self._unload()
            deployment = self.settings.read_json(self.output / 'worker/transport/DEPLOYMENT.json')
            root_join = validate_exercise_root(snapshot, lease=self.lease, kind=self.kind,
                source_sha=self.sources['study-ui-offline-window.py']['sha256'], controller=self.identity,
                deployment=deployment, heartbeat=heartbeat, trigger=trigger, join=self.join, window=self.window)
            root_record = self.window.private_write(self.output / 'ROOT_RECEIPTS.private.json', snapshot)
            if self.kind != 'controller-death':
                self._send(2, 'GUARDIAN_UNLOADED', {'rootReceipt': root_record})
                self.child.wait(timeout=10)
                require(self.child.returncode == 0, 'Owned child failed after verified unload')
            worker_stop = stop_owned(self.window, self.interruption, self.child, self.identity)
            relay_envelope = self.control_oracle('finish', {'kind': self.kind, 'windowID': self.lease['windowID'], 'requiredNonce': heartbeat['heartbeatNonce']})
            relay = self.settings.decode_json(transferred(self.settings, relay_envelope))
            relay_rows = transferred(self.settings, relay_envelope, 'rows')
            require(relay.get('schema') == RELAY_SCHEMA and relay.get('start') == self.relay_start
                    and relay.get('status') == ('INTENTIONALLY_STOPPED_FOR_HEARTBEAT_LOSS' if self.kind == 'heartbeat-loss' else 'ORIGINAL_RELAY_ENDED_AFTER_OBSERVATION')
                    and relay.get('requiredMacNonce') == heartbeat['heartbeatNonce'], 'Actual relay finish differs from the requested exercise')
            qualified_stop(relay['ownedStop'], self.relay_start['process'])
            rows = validate_relay_rows(relay_rows, self.relay_start, required_nonce=heartbeat['heartbeatNonce'])
            if rows[-1]['remote'].get('status') == 'WINDOW_ALREADY_CLEANED':
                require(rows[-1]['remote']['cleanupSHA256'] == root_join['cleanup']['sha256'],
                        'Terminal Oracle reply differs from the actual root cleanup receipt')
            require(relay['rawRows']['bytes'] == len(relay_rows) and relay['rawRows']['sha256'] == sha(relay_rows), 'Original relay rows changed during transfer')
            require(dependencies(self.root)[1] == self.sources, 'Current exercise source changed during observation')
            result = {'schema': SCHEMA, 'status': EXERCISE_PASS, 'kind': self.kind, 'lease': admission['lease'],
                'coordination': admission['coordination'], 'sources': self.sources, 'controller': self.identity,
                'trigger': trigger, 'rootReceipts': root_record, 'rootJoin': root_join,
                'oracleStart': transferred_start, 'oracleResult': relay_envelope, 'workerStop': worker_stop,
                'networkDenialWindows': 0, 'nativeExecutions': 0, 'transportProbes': 0}
        except BaseException as error:
            try:
                self.window.private_write(self.output / 'FAILURE.private.json', {'schema': SCHEMA, 'status': 'FAILED_OR_INCOMPLETE',
                    'kind': self.kind, 'errorType': type(error).__name__, 'error': str(error), 'noAcceptance': True})
            finally:
                self.abort()
            raise
        try:
            self._close_owned_streams()
            require(result is not None and not self.errors and not self.stderr, 'Owned worker ended with unqualified output')
            return self.window.private_write(self.output / 'RESULT.private.json', result)
        except BaseException as error:
            try:
                self.window.private_write(self.output / 'POSTCHECK_FAILURE.private.json', {'schema': SCHEMA,
                    'status': 'FAILED_OR_INCOMPLETE', 'kind': self.kind, 'errorType': type(error).__name__,
                    'error': str(error), 'noAcceptance': True})
            finally:
                self.abort()
            raise

    def _close_owned_streams(self):
        for thread in self.threads:
            thread.join(2)
        require(not any(thread.is_alive() for thread in self.threads),
                'Owned worker reader remains active; defer buffered pipe close')
        if self.child is not None:
            require(self.child.poll() is not None, 'Owned worker remains live; defer buffered pipe close')
            for pipe in (self.child.stdin, self.child.stdout, self.child.stderr):
                with contextlib.suppress(OSError):
                    pipe.close()

    def abort(self):
        errors = {}
        if self.possible_deployment and not self.unloaded and self.lease is not None:
            try:
                self._private('finish'); self._wait_cleanup(20); self._unload()
            except BaseException as error:
                errors['watchdog'] = type(error).__name__ + ': ' + str(error)
        if self.child is not None:
            try:
                identity = created_child_identity(self.window, self.child, self.identity, self.command, self.parent_pid)
                stop_owned(self.window, self.interruption, self.child, identity)
            except BaseException as error:
                errors['worker'] = type(error).__name__ + ': ' + str(error)
        if self.relay_possible:
            try:
                self.control_oracle('abort', {'windowID': self.lease['windowID']})
            except BaseException as error:
                errors['oracleRelay'] = type(error).__name__ + ': ' + str(error)
        try:
            self._close_owned_streams()
        except BaseException as error:
            errors['streams'] = type(error).__name__ + ': ' + str(error)
        require(not errors, 'Owned exercise cleanup remains unverified: ' + repr(errors))
        return {'verified': True, 'offlineAcceptance': False}


def worker(kind, nonce, output):
    require(sys.platform == 'darwin' and os.geteuid() != 0 and kind in REASONS
            and re.fullmatch('[a-f0-9]{32}', nonce), 'Actual original Mac worker required')
    root, sources, window_module, join, settings, _ = dependencies(Path(__file__).resolve().parents[2])
    directory = new_directory(output)
    window = None
    try:
        actual = window_module.process(os.getpid())
        emit(nonce, 0, 'CONTROLLER_READY', {'process': actual, 'sources': sources, 'bootSession': window_module.boot_identity()})
        admission = read_input(window_module, nonce, 0, 'ADMIT', time.monotonic() + 300)
        lease = settings.decode_json(settings.verify_witness(admission['lease']))
        coordination = settings.decode_json(settings.verify_witness(admission['coordination']))
        lease = admit_exercise(lease, coordination, kind=kind, actual_pid=os.getpid(),
            source_sha=sources['study-ui-offline-window.py']['sha256'], window=window_module, join=join, now=time.time())
        for owner in coordination['owners']:
            settings.verify_witness(owner['originalAcknowledgement'])
        window = window_module.OfflineWindow(private_lease=admission['lease']['path'], output_dir=directory / 'transport',
            simulator_probe=None, host_probe=None, image_path_resolver=None)
        ready = window.prepare()
        ready.update(actualControllerPID=os.getpid(), oracleRelaySource=sources['study-ui-offline-heartbeat.py'])
        emit(nonce, 1, 'PREPARED', ready)
        deadline = min(time.monotonic() + 15, time.monotonic() + lease['hardDeadlineUnix'] - time.time())
        while True:
            require(time.monotonic() < deadline, 'Actual independent Oracle heartbeat did not arrive')
            state = no_denial_state(window._private('status'), lease['windowID'])
            require('cleanup' not in state, 'Watchdog ended before the actual trigger')
            status = state.get('status', {})
            if re.fullmatch('[a-f0-9]{32}', status.get('heartbeatNonce') or '') \
                    and window_module.finite(status.get('heartbeatMonotonic')) \
                    and 0 <= time.monotonic() - status['heartbeatMonotonic'] <= 10:
                break
            time.sleep(.2)
        if kind == 'controller-death':
            # The test trigger is actual abrupt death. Original group cleanup
            # uses SIGINT; Python's default KeyboardInterrupt would run finally
            # and request normal-finish instead of exercising watchdog recovery.
            signal.signal(signal.SIGINT, signal.SIG_DFL)
            signal.signal(signal.SIGTERM, signal.SIG_DFL)
        emit(nonce, 2, 'HEARTBEAT_PROVEN', {'state': state, 'awaitingOnlyOwnedTermination': kind == 'controller-death'})
        remaining = max(1, lease['hardDeadlineUnix'] - time.time() + 20)
        request = read_input(window_module, nonce, 1, 'OBSERVE_CLEANUP', time.monotonic() + remaining)
        require(kind != 'controller-death' and request == {'kind': kind}, 'Abrupt-death worker cannot continue through a graceful command')
        until = time.monotonic() + max(1, lease['hardDeadlineUnix'] - time.time() + 20)
        while time.monotonic() < until:
            state = no_denial_state(window._private('status'), lease['windowID'])
            if 'cleanup' in state:
                break
            time.sleep(.4)
        else:
            raise TimeoutError('Actual expected watchdog cleanup never arrived')
        emit(nonce, 3, 'CLEANUP_OBSERVED', {'state': state, 'controller': window_module.process(os.getpid())})
        read_input(window_module, nonce, 2, 'GUARDIAN_UNLOADED', time.monotonic() + 90)
        final = root_snapshot(window_module, lease['windowID'])
        require(final['currentDaemonAbsent'] is True and final['currentPlistAbsent'] is True
                and final['currentOwnedRulesSHA256'] == sha(b'') and 'unloaded.json' in final['exports'][lease['windowID']],
                'Guardian has not actually removed the owned watchdog')
        window.deployed = False
    finally:
        if window is not None and window.deployed:
            window.abort()


def validate_exercise_result(record, *, repository):
    """Actual Mac readback; no deployment, signals, activation or owner renewal."""
    require(sys.platform == 'darwin' and os.geteuid() != 0, 'Original Mac readback required')
    root, sources, window, join, settings, _ = dependencies(repository)
    value = settings.decode_json(settings.verify_witness(record, MAX_STREAM))
    require(value.get('schema') == SCHEMA and value.get('status') == EXERCISE_PASS
            and value.get('kind') in REASONS and value.get('sources') == sources
            and all(type(value.get(key)) is int and value[key] == 0
                    for key in ('networkDenialWindows', 'nativeExecutions', 'transportProbes')),
            'Not the current actual no-denial-only exercise producer')
    kind = value['kind']
    lease = settings.decode_json(settings.verify_witness(value['lease']))
    coordination = settings.decode_json(settings.verify_witness(value['coordination']))
    original = settings.decode_json(settings.verify_witness(value['rootReceipts'], MAX_STREAM))
    snapshot = root_snapshot(window, lease['windowID'])
    require(snapshot['exports'] == original['exports'], 'Actual root-owned exercise receipts changed')
    sealed = join.root_document(snapshot['exports'], lease['windowID'], 'sealed.json')
    # Check the original admission time; later inspection never renews approval.
    window.admit_lease(lease, sources['study-ui-offline-window.py']['sha256'], now=sealed['preparedUnix'])
    require(lease.get('exerciseKind') == kind and lease['mode'] == 'watchdog-exercise-no-denial'
            and lease['controllerPID'] == value['controller']['pid'], 'Root exercise scope differs')
    join.validate_coordination(coordination, lease, sealed['preparedUnix'])
    for owner in coordination['owners']:
        settings.verify_witness(owner['originalAcknowledgement'])
    directory = Path(record['path']).parent
    heartbeat_record = settings.read_json(directory / 'WORKER-2-HEARTBEAT_PROVEN.json')
    heartbeat = heartbeat_record['payload']['state']['status']
    deployment = settings.read_json(directory / 'worker/transport/DEPLOYMENT.json')
    qualified = validate_exercise_root(snapshot, lease=lease, kind=kind,
        source_sha=sources['study-ui-offline-window.py']['sha256'], controller=value['controller'],
        deployment=deployment, heartbeat=heartbeat, trigger=value['trigger'], join=join, window=window)
    require(qualified == value['rootJoin'], 'Actual root lifecycle join differs from its retained summary')
    ready = {'windowID': lease['windowID'], 'hardDeadlineUnix': lease['hardDeadlineUnix']}
    start = validate_relay_start(settings.decode_json(transferred(settings, value['oracleStart'])), ready, sources)
    relay = settings.decode_json(transferred(settings, value['oracleResult']))
    rows_raw = transferred(settings, value['oracleResult'], 'rows')
    require(relay.get('schema') == RELAY_SCHEMA and relay.get('start') == start
            and relay.get('status') == ('INTENTIONALLY_STOPPED_FOR_HEARTBEAT_LOSS' if kind == 'heartbeat-loss' else 'ORIGINAL_RELAY_ENDED_AFTER_OBSERVATION')
            and relay.get('requiredMacNonce') == heartbeat['heartbeatNonce']
            and relay.get('rawRows', {}).get('bytes') == len(rows_raw)
            and relay['rawRows'].get('sha256') == sha(rows_raw), 'Original relay producer/bytes changed')
    qualified_stop(relay['ownedStop'], start['process'])
    qualified_stop(value['workerStop'], value['controller'])
    rows = validate_relay_rows(rows_raw, start, required_nonce=heartbeat['heartbeatNonce'])
    if rows[-1]['remote'].get('status') == 'WINDOW_ALREADY_CLEANED':
        require(rows[-1]['remote']['cleanupSHA256'] == qualified['cleanup']['sha256'], 'Terminal Oracle cleanup binding changed')
    return qualified


def exercise_receipts(records, *, repository):
    """Return only real root cleanup witnesses accepted by the original deployer."""
    require(set(records) == set(REASONS), 'All three actual distinct exercises are required')
    results = {kind: validate_exercise_result(record, repository=repository) for kind, record in records.items()}
    require(all(results[kind]['reason'] == REASONS[kind] for kind in REASONS)
            and len({row['cleanup']['path'] for row in results.values()}) == 3
            and len({row['bootSession'] for row in results.values()}) == 1
            and len({row['sourceSHA256'] for row in results.values()}) == 1,
            'Three distinct same-source/same-boot actual recoveries are required')
    return {kind: results[kind]['cleanup'] for kind in REASONS}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--worker', choices=tuple(REASONS), required=True)
    parser.add_argument('--nonce', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    worker(args.worker, args.nonce, args.output)


if __name__ == '__main__':
    main()
