#!/usr/bin/env python3
"""LOCAL SOURCE PROPOSAL. Separate reviewed prepare/publish; no retirement API.

Future invocation requires Python -I, a Root-reviewed SOURCE_SEAL digest and
the exact fixed tools/control locations below. This file has not been run.
"""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before filesystem/network action')

import argparse
import base64
import contextlib
import hashlib
import http.client
import importlib.util
import json
import os
from pathlib import Path
import selectors
import ssl
import stat
import subprocess
import sys
import time
import urllib.parse

TOOLS = Path('/home/ubuntu/otzaria-wave3-native116-stream-tools-20261127')
BASE = Path('/home/ubuntu/otzaria-wave3-native116-stream-preservation-20261127')
REPOSITORY = 'davidpovarsky/Maktabah-preserved-evidence'
REPOSITORY_ID = 1474927804
TAG = 'native116-remaining-stream-20261127-wave3'
RELEASE_NAME = 'Native116 remaining original evidence — verified transport only'
ROOT_FLOOR = 1593835520
CONTROL_CAP = 48 * 1024**2
BLOCK = 1024**2
TAIL = 64 * 1024
PIPE_LIMIT = 64 * 1024
TOOL_NAMES = ('reviewed_runtime.py', 'stream_format.py', 'mac_producer.py', 'oracle_controller.py')
SSH = ['sudo', '-u', 'ubuntu', '-H', 'ssh', '-o', 'BatchMode=yes',
       '-o', 'ConnectTimeout=8', '-o', 'StrictHostKeyChecking=yes',
       '-o', 'IdentitiesOnly=yes', '-o', 'UpdateHostKeys=no',
       '-o', 'ControlMaster=no', '-o', 'ControlPath=none', '-T',
       'scaleway-mac', '/usr/bin/python3', '-I', '-']
R = F = None
SOURCE_BYTES = {}
SEAL = None
SEAL_RAW = None
SEAL_SHA = None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


class UploadHTTPStatusError(RuntimeError):
    def __init__(self, status):
        require(type(status) is int and 100 <= status <= 599, 'Typed HTTP status required')
        self.status = status
        super().__init__('UPLOAD_HTTP_STATUS_REFUSED')


def controlled_failure(error, stage):
    # Neither str(error) nor repr(error) is evaluated. A token can be absent
    # from the caller after getter failure, or an exception can carry a prefix.
    known = {'RuntimeError', 'ValueError', 'TypeError', 'KeyError', 'OSError',
             'TimeoutError', 'BrokenPipeError', 'ConnectionError', 'ConnectionResetError',
             'UnicodeDecodeError', 'JSONDecodeError', 'SSLError', 'SSLCertVerificationError',
             'HTTPException', 'RemoteDisconnected', 'BadStatusLine', 'IncompleteRead',
             'KeyboardInterrupt', 'SystemExit', 'UploadHTTPStatusError'}
    name = type(error).__name__
    stages = {'PREPARE', 'PUBLISH_PREFLIGHT', 'REPOSITORY_READ', 'RELEASE_LIST',
              'DRAFT_CREATE', 'DRAFT_VERIFY', 'TOKEN_GETTER', 'SMALL_ASSET_UPLOAD',
              'ARCHIVE_UPLOAD', 'FULL_READBACK', 'FINAL_SOURCE', 'FINAL_RECEIPT'}
    result = {'code': 'CONTROLLED_STAGE_FAILED',
              'stage': stage if stage in stages else 'UNCLASSIFIED_STAGE',
              'errorType': name if name in known else 'UnexpectedException',
              'exceptionTextRecorded': False}
    if type(error) is UploadHTTPStatusError:
        result.update(code='UPLOAD_HTTP_STATUS_REFUSED', httpStatus=error.status)
    return result


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n').encode('ascii')


def identity(s):
    return {'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'uid': s.st_uid, 'gid': s.st_gid, 'nlink': s.st_nlink, 'bytes': s.st_size,
            'mtimeNS': str(s.st_mtime_ns), 'ctimeNS': str(s.st_ctime_ns)}


def fixed_directory(path):
    require(path.is_absolute() and path.resolve(strict=True) == path, 'Fixed directory traverses a symlink')
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        require(os.fstat(fd).st_dev == os.stat('/').st_dev, 'Oracle controls must remain on root filesystem')
        return fd
    except BaseException:
        os.close(fd); raise


def read_leaf(path, maximum):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= maximum,
                'Fixed input is not a bounded single-link regular file')
        result = bytearray()
        while True:
            block = os.read(fd, min(BLOCK, maximum + 1 - len(result)))
            if not block:
                break
            result.extend(block)
            require(len(result) <= maximum, 'Fixed input grew beyond its bound')
        require(identity(os.fstat(fd)) == identity(before), 'Fixed input changed during read')
        require(identity(os.lstat(path)) == identity(before), 'Fixed input path replaced')
        return bytes(result), identity(before)
    finally:
        os.close(fd)


def source_seal(expected):
    global SEAL, SEAL_RAW, SEAL_SHA, R, F
    require(sys.flags.isolated == 1, 'Explicit python3 -I is required')
    require('GH_DEBUG' not in os.environ, 'Existing CLI debug environment must be absent; do not expose authenticated headers')
    require(Path(__file__).resolve() == TOOLS / 'oracle_controller.py', 'Exact reviewed tools path required')
    tfd = fixed_directory(TOOLS)
    try:
        require(not os.fstat(tfd).st_mode & 0o022, 'Tools directory may not be group/world writable')
        raw, _ = read_leaf(TOOLS / 'SOURCE_SEAL.json', BLOCK)
        require(sha(raw) == expected, 'Root-reviewed SOURCE_SEAL digest mismatch')
        value = json.loads(raw)
        require(value['schema'] == 'otzaria.native116-stream-source-seal/1', 'Source-seal schema')
        require(set(value['files']) == set(TOOL_NAMES), 'Exact four-file source closure')
        for name in TOOL_NAMES:
            body, metadata = read_leaf(TOOLS / name, BLOCK)
            pin = value['files'][name]
            require(len(body) == pin['bytes'] and sha(body) == pin['sha256'], 'Reviewed tool bytes changed')
            require(not metadata['mode'] & 0o022, 'Tool is group/world writable')
            SOURCE_BYTES[name] = body
        SEAL, SEAL_RAW, SEAL_SHA = value, raw, expected
        for name in ('reviewed_runtime', 'stream_format'):
            spec = importlib.util.spec_from_file_location(name, TOOLS / (name + '.py'))
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            # Execute the bytes actually hashed, not a later path read.
            exec(compile(SOURCE_BYTES[name + '.py'], str(TOOLS / (name + '.py')), 'exec'), module.__dict__)
            if name == 'reviewed_runtime': R = module
            else: F = module
    finally:
        os.close(tfd)


def recheck_sources():
    for name, before in SOURCE_BYTES.items():
        current, _ = read_leaf(TOOLS / name, BLOCK)
        require(current == before, 'Reviewed controller/helper source changed')
    current, _ = read_leaf(TOOLS / 'SOURCE_SEAL.json', BLOCK)
    require(current == SEAL_RAW, 'Source seal changed')


def aggregate_bytes():
    """Only the exclusive fixed two-phase control tree; no other filesystem scan."""
    if not BASE.exists():
        return sum(len(x) for x in SOURCE_BYTES.values()) + len(SEAL_RAW or b'')
    total = sum(len(x) for x in SOURCE_BYTES.values()) + len(SEAL_RAW or b'')
    bfd = fixed_directory(BASE)
    try:
        require(set(os.listdir(bfd)) <= {'prepare', 'publish'}, 'Unknown control child')
        for phase in os.listdir(bfd):
            pfd = os.open(phase, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=bfd)
            try:
                for name in os.listdir(pfd):
                    s = os.stat(name, dir_fd=pfd, follow_symlinks=False)
                    require(stat.S_ISREG(s.st_mode) and s.st_nlink == 1, 'Unexpected control entry type/link')
                    total += s.st_blocks * 512
            finally: os.close(pfd)
    finally: os.close(bfd)
    return total


def make_runtime(phase):
    R.CONTROL = BASE / phase
    class BoundedRuntime(R.Runtime):
        def guard(self, addition=0):
            super().guard(addition)
            require(aggregate_bytes() + addition <= CONTROL_CAP, 'Aggregate 48 MiB source/control cap')
    return BoundedRuntime()


def write_blob(runtime, name, body):
    require(name in (F.SNAPSHOT_NAME,), 'Only the fixed bounded snapshot blob')
    require(len(body) <= F.SNAPSHOT_CAP, 'Snapshot blob bound')
    runtime.guard(len(body) + 4096)
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                 0o644, dir_fd=runtime.fd)
    try:
        position = 0
        while position < len(body):
            part = body[position:position + BLOCK]
            runtime.guard(len(part) + 4096)
            written = os.write(fd, part)
            require(written > 0, 'Short snapshot metadata write')
            position += written
        os.fsync(fd)
    finally: os.close(fd)
    os.fsync(runtime.fd)
    check, metadata = read_leaf(R.CONTROL / name, F.SNAPSHOT_CAP)
    require(check == body, 'Durable snapshot readback mismatch')
    return {'path': str(R.CONTROL / name), 'bytes': len(body), 'sha256': sha(body), 'identity': metadata}


class Pipe:
    """Bounded synchronous pipe reader; stdout never becomes an implicit log."""
    def __init__(self, process, runtime, input_body, limit, timeout):
        self.process, self.runtime = process, runtime
        self.limit, self.until = limit, min(runtime.deadline, time.monotonic() + timeout)
        self.input = memoryview(input_body or b''); self.sent = 0
        self.buffer, self.stderr = bytearray(), bytearray()
        self.count, self.hasher, self.finished = 0, hashlib.sha256(), False
        self.selector = selectors.DefaultSelector()
        self.original = None

    def start(self):
        for name, pipe in (('stdout', self.process.stdout), ('stderr', self.process.stderr)):
            os.set_blocking(pipe.fileno(), False)
            self.selector.register(pipe.fileno(), selectors.EVENT_READ, name)
        if self.process.stdin is not None:
            os.set_blocking(self.process.stdin.fileno(), False)
            if self.input:
                self.selector.register(self.process.stdin.fileno(), selectors.EVENT_WRITE, 'stdin')
            else:
                self.process.stdin.close()

    def pump(self):
        self.runtime.guard()
        require(time.monotonic() < self.until, 'Owned pipe deadline')
        for key, _ in self.selector.select(0.25):
            if key.data == 'stdin':
                try: n = os.write(key.fd, self.input[self.sent:self.sent + PIPE_LIMIT])
                except BlockingIOError: continue
                require(n > 0, 'Owned producer stdin closed')
                self.sent += n
                if self.sent == len(self.input):
                    self.selector.unregister(key.fd)
                    self.process.stdin.close()
                continue
            try: raw = os.read(key.fd, PIPE_LIMIT)
            except BlockingIOError: continue
            if not raw:
                self.selector.unregister(key.fd)
                continue
            if key.data == 'stderr':
                require(len(self.stderr) + len(raw) <= PIPE_LIMIT, 'Owned stderr exceeds 64 KiB')
                self.stderr.extend(raw)
            else:
                self.count += len(raw)
                require(self.count <= self.limit, 'Owned stream exceeds its exact bound')
                self.hasher.update(raw); self.buffer.extend(raw)
                require(len(self.buffer) <= 2 * PIPE_LIMIT, 'Owned pipe buffer bound')

    def read(self, amount=-1):
        require(0 <= amount <= BLOCK, 'Caller must request a bounded stream read')
        if amount == 0:
            return b''
        while not self.buffer and self.selector.get_map():
            self.pump()
        if self.buffer:
            n = min(amount, len(self.buffer)); raw = bytes(self.buffer[:n]); del self.buffer[:n]
            return raw
        self.finish()
        return b''

    def finish(self):
        if self.finished:
            return
        require(not self.buffer, 'Unconsumed stream bytes')
        while self.selector.get_map():
            self.pump()
            require(not self.buffer, 'Unexpected unread stream tail')
        self.runtime.guard()
        require(time.monotonic() < self.until, 'Owned completion deadline')
        code = self.process.wait(timeout=max(0.01, min(20, self.until - time.monotonic())))
        require(code == 0, 'Owned producer/readback failed; no retry')
        require(self.sent == len(self.input), 'Incomplete producer request')
        self.finished = True

    def result(self):
        require(self.finished, 'Owned child must complete before consumption')
        return {'bytes': self.count, 'sha256': self.hasher.hexdigest(), 'exit': self.process.returncode}


@contextlib.contextmanager
def owned_pipe(runtime, argv, label, limit, timeout, input_body=None):
    runtime.guard()
    runtime.sequence += 1
    label = '%02d-%s' % (runtime.sequence, R.leaf(label))
    original = None; reader = None
    process = subprocess.Popen(argv, stdin=subprocess.PIPE if input_body is not None else subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    # Everything fallible after Popen is within this immediate cleanup scope.
    try:
        original = R.process_identity(process.pid)
        require(original['pgid'] == original['session'] == process.pid, 'Owned session identity')
        runtime.write(label + '.PROCESS.json', {'utc': R.utc(), 'argv': argv, 'identity': original,
                                               'inputBytes': len(input_body or b''),
                                               'inputSHA256': sha(input_body) if input_body is not None else None})
        reader = Pipe(process, runtime, input_body, limit, timeout); reader.original = original; reader.start()
        yield reader
        reader.finish()
        runtime.write(label + '.RESULT.json', reader.result())
    finally:
        try:
            R.stop_owned(process, original)
        finally:
            if reader is not None: reader.selector.close()
            for pipe in (process.stdin, process.stdout, process.stderr):
                if pipe is not None and not pipe.closed: pipe.close()
            if reader is not None:
                try:
                    runtime.write(label + '.stderr', bytes(reader.stderr))
                finally:
                    runtime.write(label + '.TERMINAL.json', {
                        'utc': R.utc(), 'pid': process.pid, 'startIdentity': original,
                        'exit': process.returncode, 'stdoutBytes': reader.count,
                        'stdoutSHA256': reader.hasher.hexdigest(), 'stderrBytes': len(reader.stderr),
                        'stderrSHA256': sha(reader.stderr), 'noAutomaticRetry': True,
                    }, terminal=True)
            else:
                runtime.write(label + '.TERMINAL.json', {'utc': R.utc(), 'pid': process.pid,
                              'startIdentity': original, 'exit': process.returncode,
                              'setupFailedBeforePipe': True, 'noAutomaticRetry': True}, terminal=True)


def bootstrap(mode, snapshot=None):
    hashes = {n: sha(SOURCE_BYTES[n]) for n in ('stream_format.py', 'mac_producer.py')}
    request = {'mode': mode, 'toolHashes': hashes}
    if snapshot is not None:
        request.update(snapshotBase64=base64.b64encode(snapshot).decode('ascii'), snapshotSHA256=sha(snapshot))
    envelope = {'sources': {n: base64.b64encode(SOURCE_BYTES[n]).decode('ascii') for n in hashes},
                'hashes': hashes, 'request': request}
    encoded = base64.b64encode(canonical(envelope)).decode('ascii')
    # Nonsecret source/snapshot only. No token, environment dump or Mac file write.
    text = """if not __debug__: raise RuntimeError('Optimized producer refused')
import base64, hashlib, json, sys, types
if not sys.flags.isolated: raise RuntimeError('Isolated producer required')
v=json.loads(base64.b64decode(%r, validate=True))
if set(v['sources']) != {'stream_format.py','mac_producer.py'}: raise RuntimeError('Source closure')
for n in ('stream_format.py','mac_producer.py'):
 b=base64.b64decode(v['sources'][n],validate=True)
 if hashlib.sha256(b).hexdigest()!=v['hashes'][n]: raise RuntimeError('Embedded source hash')
 m=types.ModuleType(n[:-3]); m.__file__='<reviewed-'+n+'>'; sys.modules[n[:-3]]=m
 exec(compile(b,m.__file__,'exec'),m.__dict__)
sys.modules['mac_producer'].main(v['request'])
""" % encoded
    body = text.encode('ascii')
    require(len(body) <= 44 * 1024**2, 'Bounded nonsecret bootstrap envelope')
    return body


def source_terminal(pipe, mode, snapshot=None):
    result = pipe.result()
    lines = bytes(pipe.stderr).splitlines()
    require(len(lines) == 1, 'Exactly one original producer terminal JSON required')
    terminal = json.loads(lines[0])
    require(terminal['schema'] == 'otzaria.native116-owned-producer-terminal/1'
            and terminal['mode'] == mode and terminal['status'] == 'SOURCE_VERIFIED_READ_ONLY'
            and terminal['sourceRoot'] == F.SOURCE_ROOT and terminal['sourceModified'] is False,
            'Exact read-only producer completion')
    if snapshot is not None: require(terminal['snapshotSHA256'] == sha(snapshot), 'Producer snapshot mismatch')
    if mode == 'stream':
        require(terminal['archiveBytes'] == result['bytes'] and terminal['archiveSHA256'] == result['sha256']
                and terminal['fullSourceBeforeAndAfter'] is True, 'Complete source/stream join')
    elif mode == 'snapshot':
        require(terminal['snapshotBytes'] == result['bytes'] and terminal['snapshotSHA256'] == result['sha256'],
                'Snapshot transport join')
    else:
        require(result['bytes'] == 0 and terminal['fullCurrentSourceEqual'] is True, 'Fresh source equality required')
    return terminal


def read_all(pipe, limit):
    result = bytearray()
    while True:
        block = pipe.read(BLOCK)
        if not block: break
        require(len(result) + len(block) <= limit, 'Bounded metadata read')
        result.extend(block)
    return bytes(result)


def source_reverify(runtime, snapshot, label):
    with owned_pipe(runtime, SSH, label, 0, 1215, bootstrap('reverify', snapshot)) as pipe:
        require(pipe.read(1) == b'', 'Reverify must emit no source content')
        result = source_terminal(pipe, 'reverify', snapshot)
    runtime.write(label + '.SOURCE_EQUAL.json', result)


def verify_ssh_alias(runtime):
    argv = ['sudo', '-u', 'ubuntu', '-H', 'ssh', '-G', '-o', 'StrictHostKeyChecking=yes',
            '-o', 'IdentitiesOnly=yes', '-o', 'UpdateHostKeys=no',
            '-o', 'ControlMaster=no', '-o', 'ControlPath=none', 'scaleway-mac']
    with owned_pipe(runtime, argv, 'pinned-ssh-config-read', PIPE_LIMIT, 15) as pipe:
        raw = read_all(pipe, PIPE_LIMIT)
    values = {}
    for line in raw.decode('utf-8', 'strict').splitlines():
        k, _, value = line.partition(' ')
        if k in ('hostname', 'user', 'port', 'stricthostkeychecking', 'identitiesonly'):
            require(k not in values, 'Duplicate pinned SSH option'); values[k] = value
    require(values.get('hostname') == '62.210.195.226' and values.get('user') == 'm1'
            and values.get('port') == '22' and values.get('stricthostkeychecking') in ('true', 'yes')
            and values.get('identitiesonly') == 'yes', 'Existing pinned SSH alias mismatch')
    runtime.write('PINNED_SSH_ALIAS.json', values)


def preparation_inventory():
    rows = []
    pfd = fixed_directory(BASE / 'prepare')
    try:
        for name in sorted(os.listdir(pfd)):
            if name == 'PREPARED.json': continue
            raw, metadata = read_leaf(BASE / 'prepare' / name, F.SNAPSHOT_CAP)
            rows.append({'name': name, 'bytes': len(raw), 'sha256': sha(raw), 'identity': metadata})
    finally: os.close(pfd)
    return rows


def prepare():
    parent = fixed_directory(BASE.parent)
    try:
        require(os.fstatvfs(parent).f_bavail * os.fstatvfs(parent).f_frsize >= ROOT_FLOOR + CONTROL_CAP,
                'Admission must reserve the complete bounded metadata allowance')
        os.mkdir(BASE.name, 0o755, dir_fd=parent); os.fsync(parent)
    finally: os.close(parent)
    runtime = make_runtime('prepare')
    try:
        runtime.write('SOURCE_SEAL.json', SEAL_RAW)
        verify_ssh_alias(runtime)
        with owned_pipe(runtime, SSH, 'exact-source-snapshot', F.SNAPSHOT_CAP, 1215, bootstrap('snapshot')) as pipe:
            snapshot = read_all(pipe, F.SNAPSHOT_CAP)
            terminal = source_terminal(pipe, 'snapshot')
        value = F.decode_snapshot(snapshot)
        write_blob(runtime, F.SNAPSHOT_NAME, snapshot)
        runtime.write('SNAPSHOT_COMPLETION.json', terminal)
        with owned_pipe(runtime, SSH, 'first-pass-measure-discard', F.ARCHIVE_CAP, 1215, bootstrap('stream', snapshot)) as pipe:
            while pipe.read(BLOCK): pass
            measure = pipe.result(); source = source_terminal(pipe, 'stream', snapshot)
        require(0 < measure['bytes'] <= F.ARCHIVE_CAP, 'Single GitHub asset conservative cap')
        runtime.write('MEASURED.json', {'stream': measure, 'source': source,
                                      'archiveStoredLocally': False, 'uploaded': False})
        manifest = {'schema': 'otzaria.native116-stream-preservation-manifest/1',
                    'repository': REPOSITORY, 'repositoryID': REPOSITORY_ID, 'draftTag': TAG,
                    'sourceRoot': F.SOURCE_ROOT, 'rootDevice': F.SOURCE_DEVICE, 'rootInode': F.SOURCE_INODE,
                    'sourceSealSHA256': SEAL_SHA,
                    'archive': {'name': F.ARCHIVE_NAME, 'bytes': measure['bytes'], 'sha256': measure['sha256']},
                    'snapshot': {'name': F.SNAPSHOT_NAME, 'bytes': len(snapshot), 'sha256': sha(snapshot)},
                    'toolSources': {n: {'bytes': len(b), 'sha256': sha(b),
                                       'sourceBase64': base64.b64encode(b).decode('ascii')} for n, b in SOURCE_BYTES.items()},
                    'entries': len(value['entries']), 'uniquePayloads': value['uniquePayloads'],
                    'metadataIncludes': ['byte-paths', 'types', 'modes', 'uid', 'gid', 'device', 'inode', 'nlink',
                                         'atime-ns', 'mtime-ns', 'ctime-ns', 'birthtime-ns', 'BSD-flags',
                                         'all-xattr-values', 'ACL-text', 'symlink-target-bytes', 'hardlink-topology'],
                    'snapshotCarriesAllMetadataAndDependencies': True,
                    'dependencyScope': 'Existing external links/Git reference files and historical Windows relocation proofs are captured, never followed or freshly qualified.',
                    'selfContained': False, 'fullTreeRestorePerformed': False, 'windowsDependenciesVerifiedNow': False,
                    'sourceMutationAuthorized': False, 'retirementAuthorized': False}
        body = canonical(manifest); require(len(body) <= BLOCK, 'Manifest bound')
        runtime.write(F.MANIFEST_NAME, body)
        recheck_sources()
        bfd = fixed_directory(BASE)
        try: base_identity = R.dir_identity(bfd)
        finally: os.close(bfd)
        prepared = {'schema': 'otzaria.native116-stream-prepared/1', 'status': 'MEASURED_SOURCE_ONLY_NOT_UPLOADED',
                    'utc': R.utc(), 'sourceSealSHA256': SEAL_SHA, 'baseIdentity': base_identity,
                    'archive': manifest['archive'], 'snapshot': manifest['snapshot'],
                    'manifest': {'name': F.MANIFEST_NAME, 'bytes': len(body), 'sha256': sha(body)},
                    'files': preparation_inventory(), 'aggregateAllocatedBytes': aggregate_bytes(),
                    'sourceRoot': F.SOURCE_ROOT, 'sourceModified': False,
                    'selfContained': False, 'retirementAuthorized': False}
        runtime.write('PREPARED.json', prepared)
        print(json.dumps({'status': prepared['status'], 'preparedPath': str(R.CONTROL / 'PREPARED.json'),
                          'preparedSHA256': sha(R.canonical(prepared)), 'archive': prepared['archive']}))
    except BaseException as error:
        runtime.write('FAILED.json', {'utc': R.utc(), 'status': 'FAILED_NO_UPLOAD_NO_SOURCE_CHANGE',
                      **controlled_failure(error, 'PREPARE')}, terminal=True)
        raise
    finally:
        if runtime.fd is not None: os.close(runtime.fd)


def read_prepared(expected):
    raw, _ = read_leaf(BASE / 'prepare' / 'PREPARED.json', BLOCK)
    require(sha(raw) == expected, 'Reviewed measured-preparation digest mismatch')
    value = json.loads(raw)
    require(value['schema'] == 'otzaria.native116-stream-prepared/1'
            and value['status'] == 'MEASURED_SOURCE_ONLY_NOT_UPLOADED'
            and value['sourceSealSHA256'] == SEAL_SHA, 'Exact preparation/source join')
    bfd = fixed_directory(BASE)
    try: require(R.dir_identity(bfd) == value['baseIdentity'], 'Prepared parent identity changed')
    finally: os.close(bfd)
    require(preparation_inventory() == value['files'], 'Original complete preparation changed')
    snapshot, _ = read_leaf(BASE / 'prepare' / F.SNAPSHOT_NAME, F.SNAPSHOT_CAP)
    manifest, _ = read_leaf(BASE / 'prepare' / F.MANIFEST_NAME, BLOCK)
    require(sha(snapshot) == value['snapshot']['sha256'] and len(snapshot) == value['snapshot']['bytes'], 'Snapshot pin')
    require(sha(manifest) == value['manifest']['sha256'] and len(manifest) == value['manifest']['bytes'], 'Manifest pin')
    F.decode_snapshot(snapshot)
    require(json.loads(manifest)['archive'] == value['archive'], 'Measured archive/manifest join')
    return value, snapshot, manifest


def api(runtime, endpoint, label, extra=()):
    return runtime.api(endpoint, label, extra=('--hostname', 'github.com', *extra))


def repository(runtime, label):
    value = api(runtime, 'repos/' + REPOSITORY, label)
    require(type(value['id']) is int and value['id'] == REPOSITORY_ID and value['private'] is True
            and value['full_name'] == REPOSITORY, 'Exact existing private repository required')
    return {'id': value['id'], 'full_name': value['full_name'], 'private': value['private']}


def release_state(runtime, release_id, expected_assets, label):
    value = api(runtime, 'repos/%s/releases/%d' % (REPOSITORY, release_id), label)
    upload = 'https://uploads.github.com/repos/%s/releases/%d/assets{?name,label}' % (REPOSITORY, release_id)
    require(type(value['id']) is int and value['id'] == release_id and value['draft'] is True
            and value['prerelease'] is False and value['tag_name'] == TAG
            and value['name'] == RELEASE_NAME and value['upload_url'] == upload,
            'Exact private draft/upload endpoint changed')
    assets = value['assets']
    require(len(assets) == len(expected_assets), 'Unexpected existing/partial draft asset; no retry/clobber')
    actual = {x['name']: x for x in assets}
    require(set(actual) == set(expected_assets), 'Draft asset names changed')
    for name, pin in expected_assets.items():
        verify_asset(actual[name], name, pin['bytes'], pin['id'], pin.get('sha256'))
    return {'id': release_id, 'draft': True, 'tag': TAG, 'uploadURL': upload,
            'assets': {k: asset_summary(v) for k, v in actual.items()}}


def asset_summary(asset):
    return {key: asset[key] for key in ('id', 'name', 'size', 'state', 'url', 'content_type')}


def verify_asset(asset, name, size, identifier=None, expected_sha=None):
    require(type(asset['id']) is int and 0 < asset['id'] < 2**63, 'Typed asset ID')
    require(identifier is None or asset['id'] == identifier, 'Exact immutable asset ID')
    require(asset['name'] == name and type(asset['size']) is int and asset['size'] == size
            and asset['state'] == 'uploaded', 'Complete uploaded asset metadata required')
    require(asset['url'] == 'https://api.github.com/repos/%s/releases/assets/%d' % (REPOSITORY, asset['id']),
            'Exact authenticated asset endpoint')
    if asset.get('digest') is not None and expected_sha is not None:
        require(asset['digest'] == 'sha256:' + expected_sha, 'Server-reported asset digest mismatch')


def get_private_token(runtime):
    """Never use Runtime.gh here: it deliberately logs command stdout hashes."""
    runtime.guard(); original = None; selector = None; output = bytearray()
    argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', 'auth', 'token', '--hostname', 'github.com']
    process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        original = R.process_identity(process.pid)
        require(original['pgid'] == original['session'] == process.pid, 'Private getter owned identity')
        runtime.write('PRIVATE_TOKEN_GETTER_PROCESS.json', {'utc': R.utc(), 'identity': original,
                      'purpose': 'Existing Oracle authentication; value/length/digest/output intentionally not recorded'})
        selector = selectors.DefaultSelector(); os.set_blocking(process.stdout.fileno(), False)
        selector.register(process.stdout.fileno(), selectors.EVENT_READ)
        until = min(runtime.deadline, time.monotonic() + 20)
        while selector.get_map():
            runtime.guard(); require(time.monotonic() < until, 'Private getter deadline')
            for key, _ in selector.select(0.25):
                try: raw = os.read(key.fd, 4096)
                except BlockingIOError: continue
                if not raw: selector.unregister(key.fd); continue
                require(len(output) + len(raw) <= 8192, 'Private getter bounded output')
                output.extend(raw)
        require(process.wait(timeout=5) == 0, 'Existing Oracle auth getter failed; no login/retry')
        token = bytes(output).strip().decode('ascii', 'strict')
        require(20 <= len(token) <= 4096 and all(33 <= ord(c) <= 126 for c in token), 'Private header value shape')
        return token
    finally:
        try: R.stop_owned(process, original)
        finally:
            if selector is not None: selector.close()
            process.stdout.close()
            output[:] = b'\0' * len(output)
            runtime.write('PRIVATE_TOKEN_GETTER_TERMINAL.json', {'utc': R.utc(), 'pid': process.pid,
                          'identity': original, 'exit': process.returncode,
                          'stdoutPersisted': False, 'stderrPersisted': False}, terminal=True)


class Upload:
    """One TLS connection, one explicit-length POST, no redirects/retries/proxy."""
    def __init__(self, runtime, token, release_id, pin, content_type):
        self.runtime, self.pin, self.sent = runtime, pin, 0
        runtime.guard()
        require(pin['name'] in (F.ARCHIVE_NAME, F.SNAPSHOT_NAME, F.MANIFEST_NAME), 'Closed upload name')
        path = '/repos/%s/releases/%d/assets?%s' % (REPOSITORY, release_id,
                                                 urllib.parse.urlencode({'name': pin['name']}))
        context = ssl.create_default_context(cafile='/etc/ssl/certs/ca-certificates.crt')
        context.set_alpn_protocols(['http/1.1'])
        self.connection = http.client.HTTPSConnection('uploads.github.com', 443, timeout=20, context=context)
        self.connection.set_debuglevel(0)
        try:
            self.connection.connect()
            require(self.connection.sock is not None, 'Explicit verified TLS connection required')
            self.connection.putrequest('POST', path, skip_accept_encoding=True)
            self.connection.putheader('Authorization', 'Bearer ' + token)
            self.connection.putheader('User-Agent', 'OtzariaNative116Preservation/1')
            self.connection.putheader('Accept', 'application/vnd.github+json')
            self.connection.putheader('Content-Type', content_type)
            self.connection.putheader('Content-Length', str(pin['bytes']))
            self.connection.putheader('Connection', 'close')
            self.connection.endheaders(encode_chunked=False)
        except BaseException:
            self.connection.close(); raise

    def send(self, raw):
        self.runtime.guard()
        require(0 < len(raw) <= BLOCK and self.sent + len(raw) <= self.pin['bytes'], 'Exact HTTP body bound')
        require(self.connection.sock is not None, 'No upload reconnection')
        self.connection.send(raw); self.sent += len(raw)

    def finish(self):
        self.runtime.guard()
        require(self.sent == self.pin['bytes'], 'HTTP body incomplete')
        response = self.connection.getresponse()
        # Never follow Location or persist an arbitrary error/echo response.
        if response.status != 201:
            raise UploadHTTPStatusError(response.status)
        raw = response.read(PIPE_LIMIT + 1)
        require(len(raw) <= PIPE_LIMIT, 'Bounded upload response')
        value = json.loads(raw)
        verify_asset(value, self.pin['name'], self.pin['bytes'], expected_sha=self.pin['sha256'])
        return asset_summary(value)

    def close(self): self.connection.close()


def upload_small(runtime, token, release_id, pin, body, label, content_type):
    require(len(body) == pin['bytes'] and sha(body) == pin['sha256'], 'Immutable small payload')
    runtime.write(label + '.UPLOAD_STARTED.json', {'utc': R.utc(), 'releaseID': release_id,
                  'payload': pin, 'onePOST': True, 'redirects': False, 'retries': 0})
    operation = Upload(runtime, token, release_id, pin, content_type)
    try:
        for position in range(0, len(body), BLOCK): operation.send(body[position:position + BLOCK])
        asset = operation.finish()
    finally: operation.close()
    runtime.write(label + '.UPLOAD_COMPLETED.json', asset)
    return {**asset, 'bytes': pin['bytes'], 'sha256': pin['sha256']}


def upload_archive(runtime, token, release_id, pin, snapshot):
    operation = None; pending = bytearray()
    with owned_pipe(runtime, SSH, 'second-pass-pinned-upload-stream', pin['bytes'], 1215,
                    bootstrap('stream', snapshot)) as pipe:
        try:
            while True:
                raw = pipe.read(BLOCK)
                if not raw: break
                pending.extend(raw)
                if operation is None:
                    runtime.write('ARCHIVE_UPLOAD_STARTED.json', {'utc': R.utc(), 'releaseID': release_id,
                                  'payload': pin, 'onePOST': True, 'redirects': False, 'retries': 0,
                                  'withheldTailBytes': TAIL})
                    operation = Upload(runtime, token, release_id, pin, 'application/gzip')
                if len(pending) > TAIL:
                    sending = len(pending) - TAIL
                    require(sending <= BLOCK, 'Bounded sender chunk')
                    operation.send(bytes(pending[:sending])); del pending[:sending]
            source = source_terminal(pipe, 'stream', snapshot)
            require(pipe.result()['bytes'] == pin['bytes'] and pipe.result()['sha256'] == pin['sha256'],
                    'Second stream must match first measurement byte-for-byte')
            require(operation is not None and 0 < len(pending) <= TAIL, 'Withheld final tail required')
            runtime.write('SECOND_PASS_SOURCE_AND_HASH_ACCEPTED.json', {'utc': R.utc(), 'source': source,
                          'stream': pipe.result(), 'bytesNotYetSent': len(pending)})
            operation.send(bytes(pending)); pending.clear()
            asset = operation.finish()
        finally:
            if operation is not None: operation.close()
    runtime.write('ARCHIVE_UPLOAD_COMPLETED.json', asset)
    return {**asset, 'bytes': pin['bytes'], 'sha256': pin['sha256']}


def full_readback(runtime, asset, snapshot=None, expected_body=None, label='asset'):
    argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', 'api', '--hostname', 'github.com',
            '-H', 'Accept: application/octet-stream',
            'repos/%s/releases/assets/%d' % (REPOSITORY, asset['id'])]
    with owned_pipe(runtime, argv, label + '-authenticated-full-readback', asset['bytes'], 1200) as pipe:
        if snapshot is not None:
            members = F.verify_tar_gzip(pipe, snapshot, runtime.guard)
        else:
            require(expected_body is not None, 'Exact small body required')
            body = read_all(pipe, len(expected_body))
            require(body == expected_body, 'Authenticated small payload differs')
            members = None
        pipe.finish()
        result = pipe.result()
        require(result['bytes'] == asset['bytes'] and result['sha256'] == asset['sha256'], 'Full asset hash/size mismatch')
    proof = {'asset': asset, 'completeAuthenticatedReadback': result, 'memberVerification': members}
    runtime.write(label + '.FULL_READBACK.json', proof)
    return proof


def publish(prepared_sha):
    prepared, snapshot, manifest = read_prepared(prepared_sha)
    runtime = make_runtime('publish'); token = None; stage = 'PUBLISH_PREFLIGHT'
    try:
        runtime.write('SOURCE_SEAL.json', SEAL_RAW)
        runtime.write('REVIEWED_PREPARATION.json', {'sha256': prepared_sha,
                      'path': str(BASE / 'prepare' / 'PREPARED.json')})
        verify_ssh_alias(runtime)
        source_reverify(runtime, snapshot, 'pre-publication-full-source')
        stage = 'REPOSITORY_READ'; repo = repository(runtime, 'exact-private-repository')
        # The by-tag endpoint is for published releases. Discover absence by the
        # authenticated complete bounded listing, then use only immutable ID.
        stage = 'RELEASE_LIST'; ended = False
        for page in range(1, 11):
            releases = api(runtime, 'repos/%s/releases?per_page=100&page=%d' % (REPOSITORY, page),
                           'release-list-%d' % page)
            require(isinstance(releases, list) and len(releases) <= 100, 'Release-list response')
            require(all(x['tag_name'] != TAG for x in releases), 'Draft/tag already exists; no reuse/retry')
            if len(releases) < 100: ended = True; break
        require(ended, 'Release list exceeds bounded complete-absence check')
        request = canonical({'tag_name': TAG, 'name': RELEASE_NAME, 'draft': True, 'prerelease': False,
                             'body': 'Private preservation of the exact remaining Native116 source scope. External references remain unresolved. No acceptance or retirement claim.'})
        runtime.write('CREATE_DRAFT_REQUEST.json', request)
        runtime.write('CREATE_DRAFT_STARTED.json', {'utc': R.utc(), 'repositoryID': REPOSITORY_ID, 'tag': TAG})
        stage = 'DRAFT_CREATE'
        created = api(runtime, 'repos/' + REPOSITORY + '/releases', 'create-one-private-draft',
                      extra=('--method', 'POST', '--input', str(R.CONTROL / 'CREATE_DRAFT_REQUEST.json')))
        require(type(created['id']) is int and 0 < created['id'] < 2**63, 'Exact new release ID')
        release_id = created['id']; assets = {}
        stage = 'DRAFT_VERIFY'; release_state(runtime, release_id, assets, 'new-draft-empty-before-first-post')
        stage = 'TOKEN_GETTER'; token = get_private_token(runtime)
        values = json.loads(manifest)
        stage = 'SMALL_ASSET_UPLOAD'
        for label, pin, body, kind in (
            ('snapshot', prepared['snapshot'], snapshot, 'application/gzip'),
            ('manifest', prepared['manifest'], manifest, 'application/json'),
        ):
            release_state(runtime, release_id, assets, label + '-pre-post-state')
            assets[pin['name']] = upload_small(runtime, token, release_id, pin, body, label, kind)
        release_state(runtime, release_id, assets, 'archive-pre-post-state')
        stage = 'ARCHIVE_UPLOAD'
        assets[F.ARCHIVE_NAME] = upload_archive(runtime, token, release_id, values['archive'], snapshot)
        token = None
        release_state(runtime, release_id, assets, 'three-exact-assets-after-upload')
        stage = 'FULL_READBACK'
        readbacks = [full_readback(runtime, assets[F.SNAPSHOT_NAME], expected_body=snapshot, label='snapshot'),
                     full_readback(runtime, assets[F.MANIFEST_NAME], expected_body=manifest, label='manifest'),
                     full_readback(runtime, assets[F.ARCHIVE_NAME], snapshot=snapshot, label='archive')]
        stage = 'FINAL_SOURCE'; source_reverify(runtime, snapshot, 'post-readback-full-source')
        repository(runtime, 'final-exact-private-repository')
        final_release = release_state(runtime, release_id, assets, 'final-exact-private-draft')
        read_prepared(prepared_sha); recheck_sources(); runtime.guard()
        stage = 'FINAL_RECEIPT'
        result = {'schema': 'otzaria.native116-stream-private-preservation/1',
                  'status': 'ALL_THREE_AUTHENTICATED_PAYLOADS_AND_EVERY_ARCHIVE_MEMBER_VERIFIED',
                  'utc': R.utc(), 'repository': repo, 'release': final_release,
                  'preparedSHA256': prepared_sha, 'sourceSealSHA256': SEAL_SHA,
                  'sourceRoot': F.SOURCE_ROOT, 'sourceIdentity': {'device': F.SOURCE_DEVICE, 'inode': F.SOURCE_INODE},
                  'snapshotSHA256': sha(snapshot), 'manifestSHA256': sha(manifest),
                  'assets': assets, 'fullReadbacks': readbacks,
                  'everyCurrentSourceEntryMetadataAndRegularPayloadVerified': True,
                  'originalSourceRetained': True, 'sourceModified': False,
                  'largeLocalArchiveCreated': False, 'selfContained': False,
                  'externalReferencesVerifiedNow': False, 'windowsDependenciesVerifiedNow': False,
                  'fullTreeRestorePerformed': False, 'freshNoUseClosurePerformed': False,
                  'retirementAuthorized': False, 'separateFreshClosureAndRootReviewRequired': True,
                  'aggregateAllocatedBytes': aggregate_bytes(), 'rootFreeBytes': runtime.free()}
        proof = runtime.write('VERIFIED_PRIVATE_NATIVE116_STREAM_PRESERVATION.json', result)
        marker = runtime.write('FINAL_RECEIPT_PUBLISHED.json', {'utc': R.utc(), 'receipt': proof,
                               'allOwnedChildrenReaped': True, 'controllerMustExitZero': True,
                               'retirementAuthorized': False})
        print(json.dumps({'status': result['status'], 'receipt': proof, 'publication': marker}))
    except BaseException as error:
        runtime.write('FAILED.json', {'utc': R.utc(), 'status': 'FAILED_NO_LOCAL_RETIREMENT',
                      **controlled_failure(error, stage),
                      'partialRemoteAssetsMustBePreserved': True, 'automaticRetry': False}, terminal=True)
        raise RuntimeError('Native116 publication failed; see bounded nonsecret FAILED.json') from None
    finally:
        token = None
        if runtime.fd is not None: os.close(runtime.fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-seal-sha256', required=True)
    sub = parser.add_subparsers(dest='phase', required=True)
    sub.add_parser('prepare')
    publication = sub.add_parser('publish')
    publication.add_argument('--reviewed-prepared-sha256', required=True)
    args = parser.parse_args()
    source_seal(args.source_seal_sha256)
    if args.phase == 'prepare': prepare()
    else: publish(args.reviewed_prepared_sha256)


if __name__ == '__main__':
    main()
