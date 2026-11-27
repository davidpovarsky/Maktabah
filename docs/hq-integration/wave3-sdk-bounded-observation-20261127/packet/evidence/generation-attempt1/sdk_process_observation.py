"""Read-only process admission for the original SDK envelope.

Uses the existing qualified BSD metadata reader for identities and executable
names. The original SDK argument predicate still uses ps, with a finite timeout;
unreadable, malformed or timed-out observations refuse admission.
"""
import datetime
import hashlib
import os
from pathlib import Path
import subprocess

BSD_BRIDGE = Path('/Users/m1/builds/hanlin-testflight-149101-20261125/post149101-20261126/bsd_process_snapshot_exit_retry.py')
BSD_BRIDGE_SHA256 = '24e4bc3832d2e12d66f36c45c749e66687211e514d21362940078801f359229c'
BSD_BINARY_SHA256 = 'b849e2066b9a41f26bdc25816fe53603957ca43d9c099b93c594877244b5a013'
COMPILER_NAMES = {'xcodebuild', 'swiftc', 'swift-frontend', 'clang', 'clang++', 'cc1', 'actool', 'ibtool', 'ld', 'gomobile', 'gobind'}
SDK_ARGUMENT_MARKERS = ['run_framework_acceptance.py', 'prepare_local_execution.py', 'xcodebuild', 'swift-frontend']


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def free_bytes():
    data = os.statvfs('/System/Volumes/Data')
    return data.f_bavail * data.f_frsize


def require_launch_capacity():
    available = free_bytes()
    if available < 15032385536:
        raise RuntimeError('Original fourteen-GiB launch admission unavailable: ' + str(available))
    return available


def bsd_snapshot(pids=None):
    if BSD_BRIDGE.is_symlink():
        raise RuntimeError('Qualified BSD adapter must not be a symlink')
    body = BSD_BRIDGE.read_bytes()
    if hashlib.sha256(body).hexdigest() != BSD_BRIDGE_SHA256:
        raise RuntimeError('Qualified BSD adapter source changed')
    scope = {'__name__': 'otzaria_existing_bsd_reader', '__file__': str(BSD_BRIDGE)}
    exec(compile(body, str(BSD_BRIDGE), 'exec'), scope)
    if scope['BINARY_SHA256'] != BSD_BINARY_SHA256:
        raise RuntimeError('Qualified BSD executable declaration changed')
    return scope['snapshot'](pids=pids, timeout=10, expected_helper_sha256=BSD_BRIDGE_SHA256)


def identity(pid):
    row = bsd_snapshot([pid]).get(pid)
    base = {'pid': pid, 'observed_at': utc(), 'observer': 'existing-qualified-BSD-metadata',
            'adapterSHA256': BSD_BRIDGE_SHA256, 'binarySHA256': BSD_BINARY_SHA256}
    if row is None:
        return {**base, 'available': False}
    if row['pid'] != pid or row['uid'] != os.geteuid():
        raise RuntimeError('Original owned process identity changed')
    return {**base, 'available': True, 'ppid': row['ppid'], 'pgid': row['pgid'],
            'start': row['started'], 'startFormat': 'kernel-seconds.microseconds',
            'executable': row['executable'], 'sid': row['sid'], 'state': row['state']}


def require_compiler_slot():
    rows = bsd_snapshot()
    active = [row for row in rows.values() if Path(row['executable']).name in COMPILER_NAMES]
    if active:
        raise RuntimeError('Exclusive compiler slot occupied; no process stopped: ' +
                           ','.join(str(row['pid']) for row in active))
    return []


def require_original_sdk_slot(root):
    # Preserve the exact original root + argument-marker predicate. Executable
    # metadata alone cannot establish that a queued Python SDK runner is absent.
    command = ['/bin/ps', '-axo', 'pid,ppid,command']
    started = utc()
    result = subprocess.run(command, stdin=subprocess.DEVNULL, capture_output=True,
                            text=True, check=True, timeout=5,
                            env={'LC_ALL': 'C', 'PATH': '/usr/bin:/bin:/usr/sbin:/sbin'})
    lines = result.stdout.splitlines()
    if result.stderr or not lines or lines[0].split() != ['PID', 'PPID', 'COMMAND']:
        raise RuntimeError('Incomplete original SDK process-argument inventory')
    process_count = 0
    for line in lines[1:]:
        fields = line.split(None, 2)
        if len(fields) != 3 or not fields[0].isdigit() or not fields[1].isdigit() or not fields[2]:
            raise RuntimeError('Malformed original SDK process-argument row')
        process_count += 1
    if not process_count:
        raise RuntimeError('Empty original SDK process-argument inventory')
    if any(str(root) in line and any(k in line for k in SDK_ARGUMENT_MARKERS) for line in lines):
        raise RuntimeError('Original SDK slot already active; no process stopped')
    return {'started_at': started, 'observed_at': utc(), 'argv': command,
            'timeoutSeconds': 5, 'processCount': process_count,
            'stdoutSHA256': hashlib.sha256(result.stdout.encode()).hexdigest(),
            'predicate': 'unchanged SDK root plus four original argument markers',
            'scope': 'successful bounded ps argument inventory only; no SDK run or foreign ownership change'}
