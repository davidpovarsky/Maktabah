#!/usr/bin/env python3
"""Pinned original read-only command/journal guards; no main action."""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before any filesystem action')
from pathlib import Path
import datetime
import hashlib
import json
import os
import selectors
import signal
import stat
import subprocess
import time
CONTROL = None  # Explicitly bound by the reviewed fixed-scope controller.
ROOT_FLOOR = 1593835520
CONTROL_CAP = 48 * 1024**2
OVERALL_SECONDS = 2700
BLOCK = 1024**2

def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def leaf(name):
    assert isinstance(name, str) and name not in ('', '.', '..')
    assert '/' not in name and '\\' not in name and '\x00' not in name
    return name


def directory(path):
    assert path.is_absolute() and path.resolve(strict=True) == path
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def dir_identity(fd):
    s = os.fstat(fd)
    assert stat.S_ISDIR(s.st_mode)
    return {'device': s.st_dev, 'inode': s.st_ino, 'uid': s.st_uid,
            'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode)}


def process_identity(pid):
    raw = Path('/proc/%d/stat' % pid).read_text()
    fields = raw[raw.rfind(')') + 2:].split()
    assert len(fields) >= 20
    return {'pid': pid, 'pgid': int(fields[2]), 'session': int(fields[3]),
            'startTicks': fields[19]}


def stop_owned(process, original):
    # Never poll/reap before a signal decision. An unreaped Popen leader cannot
    # have its PID reused. Every child was started in its own session/group.
    if process.returncode is not None:
        return
    current = process_identity(process.pid)
    assert current['pgid'] == current['session'] == process.pid
    assert original is None or current == original
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        current = process_identity(process.pid)
        assert current['pgid'] == current['session'] == process.pid
        assert original is None or current == original
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=20)


class Runtime:
    def __init__(self):
        self.started = time.monotonic()
        self.deadline = self.started + OVERALL_SECONDS
        self.fd = None
        self.sequence = 0
        self.phase = 'exclusive-rootfs-attempt'
        pfd = directory(CONTROL.parent)
        try:
            assert os.fstat(pfd).st_dev == os.stat('/').st_dev
            self.guard()
            os.mkdir(CONTROL.name, 0o755, dir_fd=pfd)
            os.fsync(pfd)
            self.fd = os.open(CONTROL.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=pfd)
        finally:
            os.close(pfd)
        self.root_before = self.free()

    def free(self):
        s = os.fstatvfs(self.fd) if self.fd is not None else os.statvfs('/')
        return s.f_bavail * s.f_frsize

    def guard(self, addition=0):
        assert time.monotonic() < self.deadline, 'Overall 2700-second deadline'
        assert self.free() - addition >= ROOT_FLOOR, 'Original root reserve unavailable'
        if self.fd is not None:
            used = sum(os.stat(n, dir_fd=self.fd, follow_symlinks=False).st_blocks * 512
                       for n in os.listdir(self.fd))
            assert used + addition <= CONTROL_CAP, 'Bounded rootfs metadata budget'

    def write(self, name, value, terminal=False):
        raw = value if isinstance(value, bytes) else canonical(value)
        assert len(raw) <= BLOCK
        if terminal:
            assert len(raw) <= 16384
        else:
            self.guard(len(raw))
        fd = os.open(leaf(name), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o644, dir_fd=self.fd)
        try:
            with os.fdopen(os.dup(fd), 'wb') as f:
                f.write(raw)
                f.flush()
                os.fsync(f.fileno())
        finally:
            os.close(fd)
        os.fsync(self.fd)
        p = CONTROL / name
        assert p.read_bytes() == raw
        return {'path': str(p), 'bytes': len(raw), 'sha256': digest(raw)}

    def gh(self, args, label, timeout=60, expected=None, allow_error=False):
        self.guard()
        self.sequence += 1
        label = '%02d-%s' % (self.sequence, leaf(label))
        argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', *args]
        limit = expected['bytes'] if expected else BLOCK
        original = None
        selector = None
        out, err = bytearray(), bytearray()
        h, count = hashlib.sha256(), 0
        code = None
        started = time.monotonic()
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        # Immediate cleanup scope: identity, durable ledger, pipe setup and all
        # later operations are inside this try, including their failures.
        try:
            original = process_identity(process.pid)
            assert original['pgid'] == original['session'] == process.pid
            self.write(label + '.PROCESS.json', {'utc': utc(), 'identity': original, 'argv': argv})
            selector = selectors.DefaultSelector()
            for channel, pipe in [('stdout', process.stdout), ('stderr', process.stderr)]:
                os.set_blocking(pipe.fileno(), False)
                selector.register(pipe.fileno(), selectors.EVENT_READ, channel)
            until = min(started + timeout, self.deadline)
            while selector.get_map():
                self.guard()
                assert time.monotonic() < until, 'Owned process/stream deadline'
                for key, _ in selector.select(timeout=0.25):
                    try:
                        b = os.read(key.fd, BLOCK)
                    except BlockingIOError:
                        continue
                    if not b:
                        selector.unregister(key.fd)
                        continue
                    if key.data == 'stderr':
                        assert len(err) + len(b) <= BLOCK, 'Bounded stderr exceeded'
                        err.extend(b)
                    else:
                        count += len(b)
                        assert count <= limit, 'Bounded stdout/payload exceeded'
                        h.update(b)
                        if expected is None:
                            out.extend(b)
            code = process.wait(timeout=max(0.01, min(20, until - time.monotonic())))
            assert allow_error or code == 0, 'Owned gh command failed; no retry'
            if expected:
                assert code == 0 and count == expected['bytes'] and h.hexdigest() == expected['sha256']
            result = {'exit': code, 'bytes': count, 'sha256': h.hexdigest(),
                      'stderrBytes': len(err), 'seconds': time.monotonic() - started}
            self.write(label + '.RESULT.json', result)
            return (code, bytes(out), bytes(err)) if expected is None else result
        finally:
            try:
                stop_owned(process, original)
            finally:
                if selector is not None:
                    selector.close()
                process.stdout.close()
                process.stderr.close()
                # Bounded original logs are retained; streamed archive bytes
                # never become a second local archive or a tool response.
                try:
                    if self.free() - len(out) - len(err) >= ROOT_FLOOR:
                        self.write(label + '.stdout', bytes(out))
                        self.write(label + '.stderr', bytes(err))
                finally:
                    self.write(label + '.TERMINAL.json', {
                        'utc': utc(), 'pid': process.pid, 'startIdentity': original,
                        'returncode': process.returncode, 'stdoutBytes': count,
                        'stdoutSHA256': h.hexdigest(), 'stderrBytes': len(err),
                        'stderrSHA256': digest(err), 'noAutomaticRetry': True,
                    }, terminal=True)

    def api(self, endpoint, label, extra=()):
        code, raw, _ = self.gh(['api', *extra, endpoint], label)
        assert code == 0
        return json.loads(raw)
