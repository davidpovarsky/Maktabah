#!/usr/bin/env python3
"""Exact original driver/helper methods with synthetic process/kernel boundaries.

No child is started; no real signal, ps, waitpid, Apple tool or simulator runs.
The helper's actual stop algorithm and defaults remain in use, with a model
clock and kernel calls. Assertions test ownership and retention, not UI/PERF.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import sys
from types import SimpleNamespace
from unittest.mock import patch

sys.dont_write_bytecode = True
parser = argparse.ArgumentParser()
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
parser.add_argument('--interruption', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.output = args.output.resolve()
assert not args.output.exists()
args.output.mkdir()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def witness(path):
    path = Path(path).resolve(strict=True)
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


baseline = load(args.baseline, 'original_perf_72db')
candidate = load(args.candidate, 'candidate_perf_lifecycle')
original = {}
exec(compile(args.interruption.read_bytes(), str(args.interruption), 'exec'), original)
checks, observations = [], []


def check(name, action):
    try:
        detail = action()
        checks.append({'name': name, 'passed': True, 'detail': detail})
    except BaseException as error:
        checks.append({'name': name, 'passed': False, 'errorType': type(error).__name__, 'error': str(error)})


class Model:
    def __init__(self, mode):
        self.mode, self.child, self.seconds = mode, None, 100.0
        self.calls, self.signals, self.kernel_reads, self.original_stops = [], [], [], []
        self.group_alive, self.changed, self.replacement = False, False, False
        self.probe_error_sent = False

    def now(self):
        return self.seconds

    def sleep(self, value):
        self.seconds += value

    def kernel(self, pid):
        assert pid == 8765
        self.kernel_reads.append(pid)
        if self.replacement:
            return {'pid': pid, 'parentPID': os.getpid(), 'startUTC': 'Fri Nov 27 10:00:01 2026', 'command': '/foreign/command'}
        if self.child.returncode is not None:
            return None
        value = {'pid': pid, 'parentPID': os.getpid(), 'startUTC': 'Fri Nov 27 10:00:00 2026', 'command': 'xcrun actual-tool'}
        if self.changed:
            if self.mode == 'parent-changed':
                value['parentPID'] += 1
            if self.mode == 'start-changed':
                value['startUTC'] = 'Fri Nov 27 10:00:01 2026'
            if self.mode == 'exec-transition':
                value['command'] = '/Applications/Xcode.app/Contents/Developer/usr/bin/actual-tool'
        return value

    def getpgid(self, pid):
        assert pid == 8765
        return pid + 1 if self.changed and self.mode == 'group-changed' else pid

    def killpg(self, pid, kind):
        assert pid == 8765
        self.signals.append({'signal': int(kind), 'replacement': self.replacement,
            'leaderExit': self.child.returncode, 'groupAlive': self.group_alive})
        if not self.group_alive:
            raise ProcessLookupError('Model group absent')
        if self.mode == 'send-permission-error' and kind == signal.SIGINT:
            raise PermissionError('Model signal refusal')
        if self.mode == 'probe-permission-error' and kind == 0 and not self.probe_error_sent:
            self.probe_error_sent = True
            raise PermissionError('Model probe refusal')
        if kind:
            if self.mode in ('send-permission-error', 'probe-permission-error') and kind == signal.SIGINT:
                return
            self.child.returncode = -int(kind)
            if self.mode == 'replacement-after-signal' and kind == signal.SIGINT:
                self.replacement = True
            elif self.mode == 'survivor-after-signal' and kind == signal.SIGINT:
                pass
            else:
                self.group_alive = False

    def original_stop(self, child, **kwargs):
        assert child is self.child
        self.original_stops.append(child.pid)
        return original['stop_owned_process_group'](child, sleep_fn=self.sleep, monotonic_fn=self.now, **kwargs)


def exercise(module, name, mode, wrapper='command', mutate=None):
    folder = args.output / name
    folder.mkdir()
    model = Model(mode)
    write_failed = False

    def write(path, value):
        nonlocal write_failed
        if mode == 'receipt-enospc':
            write_failed = True
            raise OSError(28, 'Synthetic receipt ENOSPC')
        Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

    core = SimpleNamespace(OUT=folder, write=write, witness=witness,
        bounded_read=lambda p, n: Path(p).read_bytes() if Path(p).stat().st_size <= n else (_ for _ in ()).throw(ValueError('bound')))
    guard = SimpleNamespace(failure=None)

    def guard_check():
        if model.child is not None and mode in ('live-failure', 'parent-changed', 'start-changed', 'group-changed',
                'exec-transition', 'replacement-after-signal', 'survivor-after-signal', 'send-permission-error', 'probe-permission-error'):
            model.changed = True
            raise ValueError('Synthetic owned byte guard failure')

    guard.check = guard_check
    runner = module.BudgetedOriginalRunner(core, guard, SimpleNamespace(require_running=lambda: None))

    class Child:
        def __new__(cls, *values, **kwargs):
            if mode == 'allocation-interrupted':
                raise KeyboardInterrupt('Synthetic interruption before constructor')
            return object.__new__(cls)

        def __init__(self, command, **kwargs):
            model.child = self
            self.returncode, self._child_created = None, False
            self.stdout = self.stderr = None
            model.calls.append({'command': list(command), 'kwargs': {key: (str(value) if key in ('cwd', 'stdout') else value)
                for key, value in kwargs.items()}})
            if mode == 'constructor-before-pid':
                raise KeyboardInterrupt('Synthetic unobservable spawn interruption')
            self.pid = 8765
            model.group_alive = True
            if mode == 'constructor-before-child-flag':
                raise KeyboardInterrupt('Synthetic PID without original child-created proof')
            self._child_created = True
            if mode == 'constructor-after-child':
                raise KeyboardInterrupt('Synthetic constructor interruption after actual child creation')

        def poll(self):
            assert self._child_created is True, 'Never poll an incomplete unknown handle'
            return self.returncode

        def complete(self):
            self.returncode = 0
            model.group_alive = mode in ('reaped-reused-pid', 'reaped-surviving-group')
            model.replacement = mode == 'reaped-reused-pid'

        def communicate(self, timeout):
            self.complete()
            return 'synthetic stdout', 'synthetic stderr'

        def wait(self, timeout):
            self.complete()
            return self.returncode

    if mode == 'caller-assignment-interrupted':
        spawn = runner.spawn
        def interrupted_return(*values, **kwargs):
            spawn(*values, **kwargs)
            raise KeyboardInterrupt('Synthetic caller assignment gap after original spawn')
        runner.spawn = interrupted_return

    error, outcome = None, None
    environment = {'EXACT_ORIGINAL_ENV': 'retained'}
    def load_cleanup(_):
        if mode == 'cleanup-import-failed':
            raise ImportError('Synthetic original cleanup dependency import failure')
        return {'stop_owned_process_group': model.original_stop}
    with patch.object(module.subprocess, 'Popen', Child), \
            patch.object(module.os, 'getpgid', side_effect=model.getpgid), \
            patch.object(module.os, 'killpg', side_effect=model.killpg), \
            patch.object(module.runpy, 'run_path', side_effect=load_cleanup), \
            patch.object(module.time, 'monotonic', side_effect=model.now), \
            patch.object(runner, 'kernel_process', side_effect=model.kernel, create=True):
        try:
            if wrapper == 'command':
                outcome = runner.command(['xcrun', 'original-export', '--exact'], timeout=90)
            else:
                outcome = runner.bounded(['xcodebuild', 'test-without-building', '--exact'], folder / 'actual.log', 600, environment)
        except BaseException as failure:
            error = type(failure).__name__
        if mutate is not None:
            mutate(runner)
        before_stop_calls = len(model.original_stops)
        state = {}
        module.stop_owned_runtime(state, host=None, trace=None, delivery=None, proxy=runner,
            start_attempts={'observer': False, 'trace': False, 'url_delivery': False})
        retain_calls = []
        owner = SimpleNamespace(retain_simulator=lambda udid: retain_calls.append(udid) or {'status': 'MODEL_RETAINED'})
        retained, allowed = module.retain_only_after_runtime_cleanup(owner, 'MODEL-OWNED-UDID', [state])
        stop_calls_after = len(model.original_stops)
        if hasattr(runner, 'finish_unfinished_handles'):
            runner.finish_unfinished_handles()
            assert len(model.original_stops) == stop_calls_after, 'Uncertain cleanup was repeated'
    if model.calls:
        actual = model.calls[0]
        assert actual['kwargs']['start_new_session'] is True and actual['kwargs']['cwd'] == str(module.ROOT)
        if wrapper == 'command':
            assert actual['kwargs']['text'] is True and actual['kwargs']['stderr'] == module.subprocess.PIPE
            assert 'env' not in actual['kwargs']
        else:
            assert actual['kwargs']['env'] == environment and actual['kwargs']['stderr'] == module.subprocess.STDOUT
    result = {'name': name, 'mode': mode, 'wrapper': wrapper, 'error': error,
        'returncode': None if outcome is None else (outcome.returncode if hasattr(outcome, 'returncode') else outcome),
        'signals': model.signals, 'kernelReadCount': len(model.kernel_reads), 'originalStopCalls': model.original_stops,
        'stopsBeforeFinalSweep': before_stop_calls, 'state': copy.deepcopy(state), 'retentionAllowed': allowed,
        'retentionCalled': bool(retain_calls), 'receiptWriteFailureInjected': write_failed,
        'createdHandleRetained': bool(getattr(runner, 'owned_handles', {})), 'originalCalls': model.calls}
    observations.append(result)
    return result


def expect(result, *, allowed, signals=None):
    assert result['retentionAllowed'] is allowed and result['retentionCalled'] is allowed, result['state']
    if signals is not None:
        assert [row['signal'] for row in result['signals']] == signals, result['signals']
    assert not any(row['signal'] and row['replacement'] for row in result['signals']), 'A reused PID/group was signaled'
    return {'observed': result['name'], 'retentionAllowed': allowed}


for wrapper in ('command', 'bounded'):
    for mode, allowed, signals in (
            ('completed', True, [0, 0]),
            ('live-failure', True, [signal.SIGINT, 0]),
            ('constructor-after-child', True, [signal.SIGINT, 0]),
            ('constructor-before-pid', False, []),
            ('constructor-before-child-flag', False, []),
            ('reaped-reused-pid', False, []),
            ('reaped-surviving-group', False, [0]),
            ('replacement-after-signal', False, [signal.SIGINT]),
            ('survivor-after-signal', False, [signal.SIGINT, 0])):
        check('candidate-' + wrapper + '-' + mode,
            lambda w=wrapper, m=mode, a=allowed, s=signals: expect(exercise(candidate, 'candidate-' + w + '-' + m, m, w), allowed=a, signals=s))

for mode, allowed, signals in (
        ('allocation-interrupted', True, []), ('caller-assignment-interrupted', True, [signal.SIGINT, 0]),
        ('parent-changed', False, []), ('start-changed', False, []), ('group-changed', False, []),
        ('exec-transition', True, [signal.SIGINT, 0]), ('receipt-enospc', False, [0, 0]),
        ('send-permission-error', False, None), ('probe-permission-error', False, None)):
    check('candidate-' + mode, lambda m=mode, a=allowed, s=signals:
        expect(exercise(candidate, 'candidate-' + m, m), allowed=a, signals=s))


def changed_receipt(runner):
    row = runner.owned_process_groups[0]
    path = Path(row['cleanup_path'])
    value = json.loads(path.read_text()); value['original_cleanup']['owned_pgid'] += 1
    path.write_text(json.dumps(value))


for name, mutate in (
        ('counter-with-missing-row', lambda r: setattr(r, 'owned_process_groups', [])),
        ('wrong-original-pgid', lambda r: r.owned_process_groups[0]['original_cleanup'].update(owned_pgid=8766)),
        ('receipt-byte-change', changed_receipt),
        ('unqualified-receipt', lambda r: r.owned_process_groups[0].update(receipt=None))):
    check('candidate-' + name, lambda n=name, m=mutate:
        expect(exercise(candidate, 'candidate-' + n, 'completed', mutate=m), allowed=False, signals=[0, 0]))


def baseline_counterexample(mode, wrapper, contract):
    value = exercise(baseline, 'baseline-' + wrapper + '-' + mode, mode, wrapper)
    failed = False
    try:
        contract(value)
    except AssertionError:
        failed = True
    assert failed, 'The exact original driver did not reproduce the stated defect'
    return {'observed': value['name'], 'sameContractRejectedBaseline': True}


for wrapper in ('command', 'bounded'):
    check('baseline-' + wrapper + '-unknown-spawn-falsely-retains', lambda w=wrapper:
        baseline_counterexample('constructor-before-pid', w, lambda r: expect(r, allowed=False, signals=[])))
    check('baseline-' + wrapper + '-created-child-is-unregistered', lambda w=wrapper:
        baseline_counterexample('constructor-after-child', w, lambda r: expect(r, allowed=True, signals=[signal.SIGINT, 0])))
    check('baseline-' + wrapper + '-reused-group-is-signaled', lambda w=wrapper:
        baseline_counterexample('reaped-reused-pid', w, lambda r: expect(r, allowed=False, signals=[])))


def ps_contract():
    core = SimpleNamespace()
    runner = candidate.BudgetedOriginalRunner(core, None, None)
    line = ' 8765 42 Fri Nov 27 10:00:00 2026 /actual/tool argument\n'
    with patch.object(candidate.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout=line, stderr='')) as run:
        value = runner.kernel_process(8765)
        assert value == {'pid': 8765, 'parentPID': 42, 'startUTC': 'Fri Nov 27 10:00:00 2026', 'command': '/actual/tool argument'}
        assert run.call_args.kwargs['timeout'] == 2
        assert run.call_args.kwargs['env']['TZ'] == 'UTC' and run.call_args.kwargs['env']['LC_ALL'] == 'C'
    return {'scope': 'Actual parser and identity-only environment; ps boundary is synthetic'}


check('identity-only-ps-parser-and-UTC-environment', ps_contract)


def import_precedes_spawn(wrapper):
    value = exercise(candidate, 'candidate-' + wrapper + '-missing-cleanup-import', 'cleanup-import-failed', wrapper)
    assert value['error'] == 'ImportError' and not value['originalCalls'] and not value['signals']
    assert not value['createdHandleRetained'] and value['state']['owned_process_attempt_inventory']['attempt_count'] == 0
    return expect(value, allowed=True, signals=[])


check('original-cleanup-import-still-precedes-both-spawn-paths',
    lambda: [import_precedes_spawn(wrapper) for wrapper in ('command', 'bounded')])
result = {'schema': 'otzaria.perf01-owned-process-lifecycle-controls/1',
    'status': 'SOURCE_CONTROLS_PASS_NOT_NATIVE_OR_PERFORMANCE' if all(v['passed'] for v in checks) else 'SOURCE_CONTROLS_FAIL',
    'baseline': witness(args.baseline), 'candidate': witness(args.candidate), 'control': witness(__file__),
    'originalInterruptionHelper': witness(args.interruption), 'checks': checks, 'observations': observations,
    'passed': sum(v['passed'] for v in checks), 'total': len(checks),
    'actualChildrenStartedByModel': 0, 'actualSignalsSent': 0, 'appleToolsExecuted': 0,
    'nativeExecutions': 0, 'corpusQueries': 0, 'performanceAcceptance': False}
(args.output / 'RESULT.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in ('observations', 'checks')}))
if result['passed'] != result['total']:
    print(json.dumps([v for v in checks if not v['passed']], indent=2))
    raise SystemExit(1)
