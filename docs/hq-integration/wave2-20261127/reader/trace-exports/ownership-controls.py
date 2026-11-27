#!/usr/bin/env python3
"""Synthetic direct-child identity boundaries; never starts or signals a process."""
import argparse
import importlib.util
import json
from pathlib import Path
import signal
import tempfile
import time
import types
from unittest.mock import patch


parser = argparse.ArgumentParser()
parser.add_argument('--helper', type=Path, required=True)
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


candidate = load(args.helper, 'candidate_owned_trace_export')
baseline = load(args.baseline, 'baseline_owned_trace_export')
checks = []


def check(name, action):
    try:
        action()
        checks.append({'name': name, 'passed': True})
    except BaseException as error:
        checks.append({'name': name, 'passed': False, 'errorType': type(error).__name__, 'error': str(error)})


def exercise(module, directory, mode):
    class Child:
        pid = 8765
        returncode = None
        def poll(self):
            return self.returncode
        def wait(self, timeout):
            self.returncode = 0
            return 0

    child = Child()
    command = ['xcrun', 'xctrace', 'export', '--input', 'synthetic-owned-input']
    identity = {'pid': child.pid, 'parentPID': module.os.getpid(),
                'startUTC': 'Fri Nov 27 09:00:00 2026', 'command': 'xcrun xctrace export --input synthetic-owned-input'}
    replacement = {**identity, 'startUTC': 'Fri Nov 27 09:00:01 2026', 'command': '/foreign/process'}
    observed, signals, launches, stops = [], [], [], []
    allocations = 0
    live_cleanup = mode in ('live-child-cap', 'parent-change', 'start-change', 'group-change',
                            'exec-transition', 'replacement-after-first-signal', 'identity-read-fails-once')

    def popen(*values, **kwargs):
        launches.append({'argv': list(values[0]), 'start_new_session': kwargs.get('start_new_session')})
        if mode == 'spawn-interrupted-before-handle':
            raise KeyboardInterrupt('Synthetic Popen interruption; created handle unknown')
        (directory / 'raw.partial').write_bytes(b'preserve these original partial bytes')
        return child

    def kernel(pid):
        assert pid == child.pid
        observed.append(pid)
        if mode == 'identity-read-fails-once' and len(observed) == 1:
            raise OSError('Synthetic initial identity read failure')
        if child.returncode is not None:
            if mode in ('reused-pid-after-reap', 'replacement-after-first-signal'):
                return dict(replacement)
            return None
        value = dict(identity)
        if len(observed) > 1:
            if mode == 'parent-change':
                value['parentPID'] += 1
            elif mode == 'start-change':
                value['startUTC'] = replacement['startUTC']
            elif mode == 'exec-transition':
                value['command'] = '/Applications/Xcode.app/Contents/Developer/usr/bin/xctrace export --input synthetic-owned-input'
        return value

    def group(pid):
        return pid + 1 if mode == 'group-change' and len(observed) > 1 else pid

    def killpg(pid, kind):
        assert pid == child.pid
        signals.append(int(kind))
        if child.returncode is not None:
            if mode in ('reused-pid-after-reap', 'leader-absent-group-present', 'replacement-after-first-signal'):
                return
            raise ProcessLookupError('Synthetic original group is absent')
        if kind:
            child.returncode = -int(kind)

    def original_stop(process, **kwargs):
        assert process is child
        stops.append(process.pid)
        actual_signal = kwargs.get('killpg_fn', killpg)
        try:
            actual_signal(process.pid, signal.SIGINT)
        except ProcessLookupError:
            pass
        gone = False
        try:
            actual_signal(process.pid, 0)
        except ProcessLookupError:
            gone = True
        if not gone:
            actual_signal(process.pid, signal.SIGKILL)
            try:
                actual_signal(process.pid, 0)
            except ProcessLookupError:
                gone = True
        return {'owned_pgid': process.pid, 'group_state': 'GONE_CHECKED' if gone else 'STILL_PRESENT_UNVERIFIED'}

    def allocated(_):
        nonlocal allocations
        allocations += 1
        return 2000 if allocations > 1 and live_cleanup else 0

    error = None
    with patch.object(module.subprocess, 'Popen', side_effect=popen), \
         patch.object(module, 'kernel_process', side_effect=kernel, create=True), \
         patch.object(module.os, 'getpgid', side_effect=group), \
         patch.object(module.os, 'killpg', side_effect=killpg), \
         patch.object(module, 'allocated', side_effect=allocated), \
         patch.object(module.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=10**9)):
        try:
            module.export_child(command, directory=directory, stem='table', timeout=1,
                hard_deadline=time.monotonic() + (-1 if mode == 'expired-before-start' else 10),
                output_budget=1000, free_reserve=100, interruption={'stop_owned_process_group': original_stop})
        except BaseException as failure:
            error = type(failure).__name__
    row = json.loads((directory / 'table.execution.json').read_text())
    if launches and mode != 'spawn-interrupted-before-handle':
        assert (directory / 'raw.partial').read_bytes() == b'preserve these original partial bytes'
    return {'row': row, 'signals': signals, 'launches': launches, 'stops': stops, 'error': error}


def admit(mode, result):
    row = result['row']
    if mode == 'spawn-interrupted-before-handle':
        assert result['error'] == 'KeyboardInterrupt' and len(result['launches']) == 1
        assert row['owned_cleanup_verified'] is False and row['child_scope'] == 'SPAWN_ATTEMPT_WITHOUT_HANDLE_UNVERIFIED'
        assert not result['signals'] and not result['stops']
    elif mode in ('reused-pid-after-reap', 'parent-change', 'start-change', 'group-change'):
        assert result['error'] is not None and row['owned_cleanup_verified'] is False
        assert not result['signals']
    elif mode == 'leader-absent-group-present':
        assert result['error'] is not None and row['owned_cleanup_verified'] is False
        assert result['signals'] == [0]
    elif mode == 'replacement-after-first-signal':
        assert result['error'] is not None and row['owned_cleanup_verified'] is False
        assert result['signals'] == [signal.SIGINT]
    elif mode == 'expired-before-start':
        assert result['error'] is not None and row['spawn_attempted'] is False
        assert row['owned_cleanup_verified'] is True and row['child_scope'] == 'SPAWN_NOT_ATTEMPTED'
        assert not result['launches'] and not result['signals']
    elif mode == 'completed-group-absent':
        assert result['error'] is None and row['owned_cleanup_verified'] is True and row['exit'] == 0
        assert result['signals'] and all(value == 0 for value in result['signals'])
        assert row['original_kernel_identity']['parentPID'] == row['parent_pid']
    else:
        assert result['error'] is not None and row['owned_cleanup_verified'] is True
        assert result['signals'] == [signal.SIGINT, 0]
        assert row['actual_exit_observed_after_cleanup'] == -signal.SIGINT
        if mode == 'exec-transition':
            assert row['original_kernel_identity']['command'] != row['last_verified_kernel_identity']['command']


with tempfile.TemporaryDirectory(prefix='synthetic-trace-child-ownership-') as temporary:
    root = Path(temporary)
    for mode in ('completed-group-absent', 'live-child-cap', 'spawn-interrupted-before-handle',
                 'reused-pid-after-reap', 'leader-absent-group-present', 'replacement-after-first-signal',
                 'parent-change', 'start-change', 'group-change', 'exec-transition',
                 'expired-before-start', 'identity-read-fails-once'):
        def action(mode=mode):
            folder = root / ('candidate-' + mode)
            folder.mkdir()
            admit(mode, exercise(candidate, folder, mode))
        check('candidate-synthetic-' + mode, action)

    baseline_rows = []
    for mode in ('spawn-interrupted-before-handle', 'reused-pid-after-reap'):
        folder = root / ('baseline-' + mode)
        folder.mkdir()
        observed = exercise(baseline, folder, mode)
        rejected = False
        try:
            admit(mode, observed)
        except (AssertionError, KeyError):
            rejected = True
        baseline_rows.append({'boundary': mode, 'fixed_contract_rejected_baseline': rejected,
                              'actual_mocked_result': observed})
        check('same-boundary-reproduces-baseline-defect-' + mode, lambda rejected=rejected: candidate.require(rejected, 'Baseline defect was not reproduced'))

    ps = ' 8765 42 Fri Nov 27 09:00:00 2026 /actual/xctrace export --input /original.trace\n'
    def ps_control(stdout=ps, stderr='', exit=0, reject=False):
        with patch.object(candidate.subprocess, 'run', return_value=types.SimpleNamespace(stdout=stdout, stderr=stderr, returncode=exit)) as run:
            try:
                value = candidate.kernel_process(8765)
            except ValueError:
                assert reject
            else:
                assert not reject
                if stdout.strip():
                    assert value['pid'] == 8765 and value['parentPID'] == 42 and value['startUTC'] == 'Fri Nov 27 09:00:00 2026'
                else:
                    assert value is None
            assert run.call_args.kwargs['timeout'] == 2 and run.call_args.kwargs['env']['LC_ALL'] == 'C'
    check('synthetic-bounded-actual-ps-shape-parser', ps_control)
    check('synthetic-explicit-empty-ps-means-no-current-PID', lambda: ps_control(stdout='', exit=1))
    check('synthetic-ps-duplicate-PID-rejected', lambda: ps_control(stdout=ps + ps, reject=True))
    check('synthetic-ps-wrong-PID-rejected', lambda: ps_control(stdout=ps.replace('8765', '8766'), reject=True))
    check('synthetic-ps-diagnostic-rejected', lambda: ps_control(stderr='unavailable', reject=True))
    check('synthetic-ps-oversized-command-rejected', lambda: ps_control(stdout=ps + 'x' * 32768, reject=True))

report = {'schema': 'otzaria.trace-export-owned-child-source-controls/1',
          'status': 'SOURCE_CONTROLS_PASSED_NOT_PERF_ACCEPTANCE' if all(row['passed'] for row in checks) else 'SOURCE_CONTROLS_FAILED',
          'candidate': candidate.file_record(args.helper.resolve())[0],
          'baseline': candidate.file_record(args.baseline.resolve())[0],
          'baselineCommit': '4f3b3e21305cb7bab1e629378dd720c143c28c22',
          'controls': checks, 'baselineComparisons': baseline_rows,
          'passed': sum(row['passed'] for row in checks), 'total': len(checks),
          'actualChildProcessesStarted': 0, 'actualSignalsSent': 0, 'appleToolsExecuted': 0,
          'nativeExecutions': 0, 'corpusQueries': 0, 'performanceAcceptance': False}
candidate.write_new(args.output.resolve(), report)
print(json.dumps({key: value for key, value in report.items() if key not in ('controls', 'baselineComparisons')}))
if not all(row['passed'] for row in checks):
    print(json.dumps([row for row in checks if not row['passed']], indent=2))
    raise SystemExit(1)
