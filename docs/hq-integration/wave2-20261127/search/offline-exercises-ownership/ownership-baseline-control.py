#!/usr/bin/env python3
"""Original-source baseline and candidate, with no actual process/signals."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
def load(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module

def observe(path):
    m = load(path); results = {}
    command = ['/synthetic/original-python', 'owned']
    foreign = {'pid': 200, 'parentPID': 1, 'startUTC': 'later reused PID', 'command': '/synthetic/foreign'}
    for kind in ('relay', 'worker'):
        subject = object.__new__(m.OwnedOracleRelay if kind == 'relay' else m.NoDenialExercise)
        subject.identity = None; subject.child = Mock(pid=200); subject.child.poll.return_value = 0
        subject.command = command; subject.parent_pid = os.getpid()
        subject.window = Mock(); subject.window.process.return_value = foreign; subject.interruption = Mock()
        if kind == 'relay': subject.finished = None; subject.logs = []
        else:
            subject.possible_deployment = subject.relay_possible = False
            subject._close_owned_streams = Mock()
        failure = None
        with patch.object(m, 'stop_owned', return_value={'syntheticNoSignal': True}) as stopper:
            try: subject.abort()
            except ValueError as error: failure = str(error)
            results[kind] = {'stoppedNewlyAdoptedForeignIdentity': stopper.called and stopper.call_args.args[3] == foreign,
                             'refused': failure is not None, 'failure': failure}
    subject = object.__new__(m.NoDenialExercise); subject.child = Mock(); subject.child.poll.return_value = 0
    live = Mock(); live.is_alive.return_value = True; subject.threads = [live]
    failure = None
    try: subject._close_owned_streams()
    except ValueError as error: failure = str(error)
    results['streams'] = {'calledBufferedCloseWithLiveReader': any(p.close.called for p in (subject.child.stdin, subject.child.stdout, subject.child.stderr)),
                          'refused': failure is not None}
    return {'sourceSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'observations': results}

baseline = observe(HERE / 'baseline-b303.py')
candidate_path = HERE / 'study-ui-offline-exercises.py'
if not candidate_path.exists(): candidate_path = HERE.parents[4] / 'Scripts/CI/study-ui-offline-exercises.py'
candidate = observe(candidate_path)
assert baseline['sourceSHA256'] == 'bcb5d64c75ae5da597b0343ef96b911c4a3d7658da62c8bed3265216102fe48f'
assert all(baseline['observations'][kind]['stoppedNewlyAdoptedForeignIdentity'] for kind in ('relay', 'worker'))
assert baseline['observations']['streams']['calledBufferedCloseWithLiveReader']
assert all(candidate['observations'][kind]['refused'] and not candidate['observations'][kind]['stoppedNewlyAdoptedForeignIdentity'] for kind in ('relay', 'worker'))
assert candidate['observations']['streams']['refused'] and not candidate['observations']['streams']['calledBufferedCloseWithLiveReader']
report = {'scope': 'WHOLE_ORIGINAL_SOURCE_WITH_SYNTHETIC_REAPED_PID_AND_READER_CONTROLS_ONLY',
          'actualProcesses': 0, 'actualSignals': 0, 'actualMacOrNetworkActions': 0,
          'baseline': baseline, 'candidate': candidate, 'status': 'THREE_SOURCE_BASELINE_DEFECTS_REPRODUCED_AND_REJECTED_BY_CANDIDATE'}
(HERE / 'BASELINE_CANDIDATE.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
