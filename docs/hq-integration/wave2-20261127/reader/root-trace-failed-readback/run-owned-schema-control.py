#!/usr/bin/env python3
"""One bounded host-only tool-schema capture; never product/UI acceptance."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import shlex
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
LIMIT = 200 * 1024 * 1024
SUBJECT = '''import json,os,threading,time
print(json.dumps({"event":"started","pid":os.getpid(),"threadID":threading.get_native_id(),"monotonicNs":time.monotonic_ns(),"unixNs":time.time_ns()}),flush=True)
deadline=time.monotonic()+7
iterations=0
while time.monotonic()<deadline:
 end=min(deadline,time.monotonic()+0.12)
 while time.monotonic()<end:
  iterations+=sum(range(500))
 time.sleep(0.04)
print(json.dumps({"event":"finished","pid":os.getpid(),"threadID":threading.get_native_id(),"monotonicNs":time.monotonic_ns(),"unixNs":time.time_ns(),"iterations":iterations}),flush=True)
'''


def require(value, message):
    if not value:
        raise ValueError(message)


def witness(path):
    before = path.stat()
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    after = path.stat()
    require(before == after, 'File changed during final readback')
    return {'path': str(path), 'bytes': before.st_size, 'sha256': h.hexdigest()}


def save(value):
    (OUT / 'RESULT.json').write_text(json.dumps(value, indent=2) + '\n')


def main():
    require(sys.platform == 'darwin' and OUT.resolve() == OUT, 'Actual canonical Mac scope only')
    report = {'schema': 'otzaria.actual-xctrace-schema-control/1',
              'scope': 'Owned host Python workload; tool schema/calibration only; no app, Simulator, corpus, network denial, UI or PERF acceptance',
              'startedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'status': 'STARTED_NOT_ACCEPTED', 'recordingLimitSeconds': 10,
              'traceByteBound': LIMIT, 'runner': witness(Path(__file__).resolve())}
    child = None
    try:
        volume = os.statvfs(OUT)
        report['freeBytesBefore'] = volume.f_bavail * volume.f_frsize
        require(report['freeBytesBefore'] > 4 * 1024**3 + LIMIT, 'No bounded coordinated storage margin')
        ps = subprocess.run(['/bin/ps', '-axo', 'pid=,ppid=,comm='], capture_output=True, text=True, check=True)
        active = [line for line in ps.stdout.splitlines()
                  if Path(line.split(maxsplit=2)[-1]).name in ('xcodebuild', 'swift-frontend', 'swiftc', 'clang', 'xctrace', 'metal')]
        report['activeCompilerOrTraceProcesses'] = active
        require(not active, 'Another compiler or trace is active; do not overlap')
        executable = Path('/opt/homebrew/bin/python3.12').resolve(strict=True)
        require(executable.is_file(), 'Existing host Python target missing')
        report['subjectExecutable'] = witness(executable)
        target = OUT / 'owned-subject.py'
        with target.open('x') as stream:
            stream.write(SUBJECT)
        report['subject'] = witness(target)
        trace = OUT / 'host-schema.trace'
        command = ['xcrun', 'xctrace', 'record', '--template', 'Animation Hitches',
                   '--instrument', 'Swift Tasks', '--instrument', 'Swift Actors',
                   '--instrument', 'Swift Executors', '--output', str(trace),
                   '--time-limit', '10s', '--no-prompt',
                   '--target-stdout', str(OUT / 'subject.stdout.log'),
                   '--launch', '--', str(executable), str(target)]
        report['command'] = command
        report['beforeLaunchMonotonicNs'] = time.monotonic_ns()
        report['beforeLaunchUnixNs'] = time.time_ns()
        with (OUT / 'record.log').open('xb') as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                                     env={**os.environ, 'LC_ALL': 'C', 'TZ': 'UTC'})
            report['ownedRecorderPID'] = child.pid
            stop = time.monotonic() + 65
            while child.poll() is None:
                size = sum(p.stat().st_size for p in trace.rglob('*') if p.is_file() and not p.is_symlink()) if trace.is_dir() else 0
                report['lastObservedTraceBytes'] = size
                require(size <= LIMIT, 'Owned trace allocation bound exceeded')
                require(time.monotonic() < stop, 'Owned trace did not finish within bounded schema-control time')
                time.sleep(0.3)
        report['recordExit'] = child.returncode
        report['afterRecordMonotonicNs'] = time.monotonic_ns()
        report['afterRecordUnixNs'] = time.time_ns()
        require(child.returncode == 0 and trace.is_dir(), 'Actual trace record failed; inspect retained original log')
        toc = OUT / 'host-schema.toc.xml'
        export_command = ['xcrun', 'xctrace', 'export', '--input', str(trace), '--toc', '--output', str(toc)]
        export = subprocess.run(export_command, capture_output=True, timeout=45)
        (OUT / 'export.stdout.log').write_bytes(export.stdout)
        (OUT / 'export.stderr.log').write_bytes(export.stderr)
        report['tocExport'] = {'command': export_command, 'exit': export.returncode}
        require(export.returncode == 0 and toc.is_file(), 'Actual TOC export unavailable')
        report['status'] = 'ACTUAL_HOST_TRACE_SCHEMA_ONLY_NO_PRODUCT_ACCEPTANCE'
    except BaseException as error:
        report.update(status='FAILED_OR_INCOMPLETE_SCHEMA_CONTROL', errorType=type(error).__name__, error=str(error))
    finally:
        if child is not None and child.poll() is None:
            report['stopRequestedAtMonotonicNs'] = time.monotonic_ns()
            os.killpg(child.pid, signal.SIGINT)
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=5)
        report['ownedRecorderExited'] = child is None or child.poll() is not None
        if 'subjectExecutable' in report and 'subject' in report:
            # Read only the exact two-argument target command created above.
            # Never signal Instruments services or another owner's process.
            expected = [report['subjectExecutable']['path'], report['subject']['path']]
            ps = subprocess.run(['/bin/ps', '-ww', '-axo', 'pid=,command='], capture_output=True, text=True, check=True)
            owned = []
            for line in ps.stdout.splitlines():
                parts = line.strip().split(maxsplit=1)
                if len(parts) != 2:
                    continue
                try:
                    same = shlex.split(parts[1]) == expected
                except ValueError:
                    same = False
                if same:
                    owned.append(int(parts[0]))
            report['ownedTargetSurvivorsBeforeCleanup'] = owned
            for pid in owned:
                os.kill(pid, signal.SIGTERM)
            stop = time.monotonic() + 3
            while owned and time.monotonic() < stop:
                remaining = []
                for pid in owned:
                    try:
                        os.kill(pid, 0)
                        remaining.append(pid)
                    except ProcessLookupError:
                        pass
                owned = remaining
                if owned:
                    time.sleep(0.1)
            report['ownedTargetsExited'] = not owned
            if owned:
                report.update(status='FAILED_OR_INCOMPLETE_SCHEMA_CONTROL', error='Exact target remains active after owned cleanup')
        report['completedUTC'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        v = os.statvfs(OUT)
        report['freeBytesAfter'] = v.f_bavail * v.f_frsize
        report['artifacts'] = [witness(p) for p in sorted(OUT.rglob('*'))
                               if p.is_file() and not p.is_symlink() and p.name != 'RESULT.json']
        save(report)
        print(json.dumps({k: v for k, v in report.items() if k != 'artifacts'}))
    if report['status'] != 'ACTUAL_HOST_TRACE_SCHEMA_ONLY_NO_PRODUCT_ACCEPTANCE':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
