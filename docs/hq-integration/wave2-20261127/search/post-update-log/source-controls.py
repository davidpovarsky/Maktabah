#!/usr/bin/env python3
"""Synthetic parser/lifetime/cleanup controls. No Apple or Simulator execution."""
import copy
import datetime as dt
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import signal
import sys
import tempfile
import types
from unittest import mock

HERE = Path(__file__).resolve().parent
SOURCE = Path(sys.argv[1]).resolve(strict=True) if len(sys.argv) == 2 else HERE / 'study-ui-search-log.py'
spec = importlib.util.spec_from_file_location('r08_log_controls_subject', SOURCE)
subject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)
BASE = 1_795_752_000
UDID = '11111111-1111-4111-8111-111111111111'
NAMESPACE = '22222222-2222-4222-8222-222222222222'
IMAGE = '/synthetic/CoreSimulator/Devices/' + UDID + '/Containers/Bundle/Application/33333333-3333-4333-8333-333333333333/Maktabah.app/Maktabah'
ARGS = [item for pair in {**subject.REQUIRED_PAIRS, '-GlobalSearchNativeTraceNamespace': NAMESPACE}.items() for item in pair]
TRACE = 'a' * 64
results = []


def case(name, action, rejection=False):
    try:
        action()
        if rejection:
            raise AssertionError('Invalid synthetic evidence was admitted')
        results.append({'name': name, 'passed': True})
    except ValueError as error:
        if not rejection:
            raise
        results.append({'name': name, 'passed': True, 'rejection': str(error)})


def fixture():
    attempts = []
    for index, (engine, scope, start, reject, finish) in enumerate((('otzaria', 'exact', 5, 6, 9), ('zayit', 'zayit', 10, 11, 14)), 1):
        attempts.append({'engine': engine, 'querySHA256': subject.digest('בראשית'.encode()),
                         'expectedLogScope': scope, 'expectedSubmissionRevision': index,
                         'startedAtUnix': BASE + start, 'submittedAtUnix': BASE + start + .2,
                         'rejectedAtUnix': BASE + reject, 'finishedAtUnix': BASE + finish,
                         'visibleError': 'synthetic source-mismatch rejection', 'traceOffsetBefore': 1200,
                         'traceOffsetAfter': 1200, 'traceSHA256Before': TRACE, 'traceSHA256After': TRACE})
    boundary = {'schemaVersion': 1, 'simulatorUDID': UDID, 'namespace': NAMESPACE,
                'warmSameProcessUpdateVerified': False, 'hostProcessLogGateRequired': True,
                'sourceProcessID': 400, 'launchArguments': ARGS[:],
                'launchEnvironment': {'OTZARIA_DATA_PROFILE': 'production', 'SIMCTL_CHILD_OTZARIA_DATA_PROFILE': 'production'},
                'launchStartedAtUnix': BASE + 1, 'finishedAtUnix': BASE + 15,
                'traceIdentity': {'bytes': 1200}, 'traceSHA256': TRACE, 'attempts': attempts}
    events = []
    for index, (scope, moment) in enumerate((('exact', 5.1), ('zayit', 10.1)), 1):
        events.append({'eventType': 'logEvent', 'eventMessage': f'[GlobalSearch] submit revision={index} generation={index + 3} backend=otzaria scope={scope}',
                       'processID': 501, 'processImagePath': IMAGE,
                       'timestamp': dt.datetime.fromtimestamp(BASE + moment, dt.timezone.utc).isoformat()})
    row = {'pid': 501, 'parentPID': 200, 'startTimeUTC': 'Fri Nov 27 04:00:01 2026',
           'startTimeUnixFloor': BASE + 1, 'command': IMAGE + ' ' + ' '.join(ARGS),
           'processImagePath': IMAGE, 'arguments': ARGS[:]}
    samples = [{'observedAtUnix': BASE + n, 'captureAlive': True, 'ownedLogAlive': True,
                'resolvedImagePath': IMAGE, 'appProcesses': [copy.deepcopy(row)]} for n in range(1, 17)]
    capture = {'simulatorUDID': UDID, 'namespace': NAMESPACE, 'startedAtUnix': BASE - 1,
               'readyAtUnix': BASE, 'stopRequestedAtUnix': BASE + 16, 'errors': [],
               'unexpectedExit': False, 'rawTruncated': False, 'stderrClean': True, 'cleanupVerified': True}
    return boundary, events, samples, capture


def verify(change=None):
    boundary, events, samples, capture = fixture()
    if change:
        change(boundary, events, samples, capture)
    parsed = subject.parse_ndjson(b''.join(json.dumps(event).encode() + b'\n' for event in events))
    return subject.verify_capture(boundary, parsed, samples, capture)


case('exact two original-shaped submissions before typeText returns are admitted by the pure gate', verify)
changes = {
    'missing one submit': lambda b, e, s, c: e.pop(),
    'extra submit': lambda b, e, s, c: e.append(copy.deepcopy(e[-1])),
    'same prior v40 PID': lambda b, e, s, c: b.update(sourceProcessID=501),
    'unmatched PID': lambda b, e, s, c: e[1].update(processID=502),
    'unmatched image': lambda b, e, s, c: e[1].update(processImagePath=IMAGE + '-other'),
    'wrong backend': lambda b, e, s, c: e[0].update(eventMessage=e[0]['eventMessage'].replace('backend=otzaria', 'backend=sefaria')),
    'wrong scope': lambda b, e, s, c: e[1].update(eventMessage=e[1]['eventMessage'].replace('scope=zayit', 'scope=exact')),
    'wrong revision': lambda b, e, s, c: e[1].update(eventMessage=e[1]['eventMessage'].replace('revision=2', 'revision=3')),
    'nonadvancing generation': lambda b, e, s, c: e[1].update(eventMessage=e[1]['eventMessage'].replace('generation=5', 'generation=4')),
    'submit before original Return': lambda b, e, s, c: e[0].update(timestamp=dt.datetime.fromtimestamp(BASE + 4.99, dt.timezone.utc).isoformat()),
    'submit after visible rejection': lambda b, e, s, c: e[1].update(timestamp=dt.datetime.fromtimestamp(BASE + 11.01, dt.timezone.utc).isoformat()),
    'page observation write error': lambda b, e, s, c: e[0].update(eventMessage='[GlobalSearchNativeObservation] page observation failed: disk full'),
    'UI observation write error': lambda b, e, s, c: e[1].update(eventMessage='[GlobalSearchNativeObservation] UI observation failed: disk full'),
    'wrong native namespace': lambda b, e, s, c: b.update(namespace=UDID),
    'wrong observed ps namespace': lambda b, e, s, c: s[7]['appProcesses'][0]['arguments'].__setitem__(-1, UDID),
    'wrong ps PID': lambda b, e, s, c: s[7]['appProcesses'][0].update(pid=777),
    'app restart inside query interval': lambda b, e, s, c: s[7]['appProcesses'][0].update(startTimeUTC='Fri Nov 27 04:00:08 2026'),
    'app absent inside query interval': lambda b, e, s, c: s[7].update(appProcesses=[]),
    'ambiguous app ownership': lambda b, e, s, c: s[7]['appProcesses'].append(copy.deepcopy(s[7]['appProcesses'][0])),
    'app predates native cold launch': lambda b, e, s, c: s[7]['appProcesses'][0].update(startTimeUnixFloor=BASE),
    'image resolver moved during submissions': lambda b, e, s, c: s[7].update(resolvedImagePath=IMAGE + '-other'),
    'capture not ready before native launch': lambda b, e, s, c: c.update(readyAtUnix=BASE + 2),
    'capture stops before native final attachment': lambda b, e, s, c: c.update(stopRequestedAtUnix=BASE + 14.9),
    'capture died': lambda b, e, s, c: c.update(unexpectedExit=True),
    'capture sampler saw dead owned process': lambda b, e, s, c: s[7].update(ownedLogAlive=False),
    'capture dropped bytes by configured cap': lambda b, e, s, c: c.update(rawTruncated=True),
    'capture emitted stderr diagnostics': lambda b, e, s, c: c.update(stderrClean=False),
    'unverified owned cleanup': lambda b, e, s, c: c.update(cleanupVerified=False),
    'process observation gap': lambda b, e, s, c: s.__delitem__(slice(5, 10)),
    'missing ending process observation': lambda b, e, s, c: s.__delitem__(slice(12, None)),
    'changed existing prefix offset': lambda b, e, s, c: b['attempts'][1].update(traceOffsetAfter=1201),
    'missing existing prefix': lambda b, e, s, c: b['traceIdentity'].update(bytes=0),
    'production bypass in actual arguments': lambda b, e, s, c: s[7]['appProcesses'][0]['arguments'].append('-smokeBypassBootstrap'),
    'duplicate namespace launch option': lambda b, e, s, c: s[7]['appProcesses'][0]['arguments'].extend(['-GlobalSearchNativeTraceNamespace', NAMESPACE]),
    'wrong actual production profile': lambda b, e, s, c: b['launchEnvironment'].update(OTZARIA_DATA_PROFILE='miniTest10'),
    'fixture data environment': lambda b, e, s, c: b['launchEnvironment'].update(OTZARIA_PRODUCTION_DB_PATH='/synthetic/other.db'),
    'nonfinite native timestamp': lambda b, e, s, c: b['attempts'][0].update(startedAtUnix=float('nan')),
}
for name, change in changes.items():
    case(name, lambda change=change: verify(change), rejection=True)

case('missing log bytes', lambda: subject.parse_ndjson(b''), rejection=True)
case('truncated JSON stream', lambda: subject.parse_ndjson(b'{"eventType":"logEvent"}'), rejection=True)
case('unparseable NDJSON', lambda: subject.parse_ndjson(b'not-json\n'), rejection=True)
case('duplicate JSON keys', lambda: subject.parse_ndjson(b'{"eventType":"logEvent","eventType":"lossEvent"}\n'), rejection=True)
case('actual-shaped loss event fails', lambda: subject.parse_ndjson(b'{"eventType":"lossEvent","eventMessage":"Dropped 12 messages"}\n'), rejection=True)
case('unknown format header is not silently waived', lambda: subject.parse_ndjson(b'Filtering the log data using a predicate\n'), rejection=True)

ps_fixture = '501 200 Fri Nov 27 04:00:01 2026 ' + IMAGE + ' ' + ' '.join(ARGS) + '\n'
case('exact retained ps argument extraction', lambda: subject.launch_scope(subject.app_rows(subject.parse_ps(ps_fixture), IMAGE)[0]['arguments'], NAMESPACE))
case('truncated ps row fails', lambda: subject.parse_ps('501 200 Fri Nov'), rejection=True)


def cleanup_scope(changed_identity=False, unrelated=False):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        capture = subject.SearchLogCapture(udid=UDID, output_dir=root / 'build/artifacts/capture', namespace=NAMESPACE,
                                           image_path_resolver=lambda: IMAGE, repository_root=root)
        owned = {'pid': 881, 'parentPID': 770, 'startTimeUTC': 'Fri Nov 27 04:00:01 2026',
                 'command': '/synthetic/runtime/usr/bin/log stream --style ndjson --level debug --predicate ' + capture.predicate}
        process = types.SimpleNamespace(pid=880, poll=lambda: 0)
        capture.process, capture.owned_log = process, owned
        capture.interruption = types.SimpleNamespace(
            stop_owned_process_group=lambda p, **kw: {'group_state': 'GONE_CHECKED', 'owned_pgid': p.pid},
            stop_owned_subprocess=lambda p: {'state': 'EXITED', 'pid': p.pid})
        changed = {**owned, 'parentPID': 999} if changed_identity else owned
        other = {**owned, 'pid': 999, 'command': '/synthetic/runtime/usr/bin/log stream --style ndjson --level debug --predicate eventMessage == "another-owner"'}
        rows = [[changed, other], [other], [other]]
        capture._ps = lambda: rows.pop(0) if rows else [other]
        with mock.patch.object(subject.os, 'kill') as killed:
            result = capture._cleanup()
        if changed_identity:
            assert not result['verified'] and killed.call_count == 0
        else:
            assert result['verified'] and killed.call_args_list == [mock.call(881, signal.SIGINT)]
            assert all(call.args[0] != 999 for call in killed.call_args_list)


case('owned runtime process alone is signalled and unrelated capture preserved', cleanup_scope)
case('changed owned runtime parent prevents a targeted signal', lambda: cleanup_scope(changed_identity=True))


def launch_write_failure_cleanup():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / 'build/artifacts').mkdir(parents=True)
        (root / 'Scripts/CI').mkdir(parents=True)
        (root / 'Scripts/CI/runtime27_interruption.py').write_text('# Explicit synthetic import fixture. No runtime calls.\n')
        capture = subject.SearchLogCapture(udid=UDID, output_dir=root / 'build/artifacts/capture', namespace=NAMESPACE,
                                           image_path_resolver=lambda: IMAGE, repository_root=root)
        capture._write = mock.Mock(side_effect=OSError('synthetic ENOSPC at LAUNCH evidence'))
        capture._cleanup = mock.Mock(return_value={'verified': True})
        fake = types.SimpleNamespace(pid=880, stdout=io.BytesIO(), stderr=io.BytesIO())
        with mock.patch.object(subject.sys, 'platform', 'darwin'), \
             mock.patch.object(subject, 'regular_bytes', return_value=(b'synthetic', {})), \
             mock.patch.object(subject.subprocess, 'run', return_value=types.SimpleNamespace(stdout=b'synthetic')), \
             mock.patch.object(subject.subprocess, 'Popen', return_value=fake) as popen:
            try:
                capture.start()
            except OSError:
                pass
            else:
                raise AssertionError('Expected explicit source-control write failure')
        assert popen.call_count == 1 and capture._cleanup.call_count == 1
        assert capture.stop_event.is_set()


case('post-Popen LAUNCH write failure immediately invokes owned cleanup', launch_write_failure_cleanup)


def early_stdout_eof():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        output = root / 'capture'
        output.mkdir()
        capture = subject.SearchLogCapture(udid=UDID, output_dir=output, namespace=NAMESPACE,
                                           image_path_resolver=lambda: IMAGE, repository_root=root)
        capture._drain(io.BytesIO(b'complete synthetic line\n'), 'original-log.ndjson', 1000)
        assert capture.errors == ['Original log stdout reached EOF before the requested capture stop']


case('stdout EOF before planned stop is a capture failure even with a live process', early_stdout_eof)
report = {'schemaVersion': 1, 'status': 'SYNTHETIC_SOURCE_CONTROLS_ONLY',
          'subjectSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          'controlSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'passed': len(results), 'failed': 0, 'cases': results,
          'nativeExecutions': 0, 'simulatorExecutions': 0, 'realLogCaptures': 0,
          'realProcessSignals': 0, 'positiveProductionReceipts': 0}
(HERE / 'SOURCE_CONTROL_RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({key: value for key, value in report.items() if key != 'cases'}))
