#!/usr/bin/env python3
"""One private opaque-differential upload/readback; never remove local data.

Windows recovery bases are preserved dependencies, not freshly verified here.
The exact source archive is not unpacked, rebased, or called self-contained.
"""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before any filesystem action')

from pathlib import Path
import base64
import datetime
import gzip
import hashlib
import json
import os
import selectors
import signal
import stat
import subprocess
import sys
import tarfile
import time

CONTROL = Path('/home/ubuntu/otzaria-wave3-private-session-pair-publication-20261127')
SOURCE = Path('/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127')
ARCHIVE_NAME = 'session-pair-differential.tar.gz'
ARCHIVE_BYTES = 1342747334
ARCHIVE_SHA = 'd0743bef81222350ed4cae139504585c81f1592ec084e31884933e79c22a5e8d'
INVENTORY_SHA = 'c2805d00315a0cbfa7b83cd444f0d2eb33b63f12b53067d77f88ec4fcb342de2'
REPO = 'davidpovarsky/Maktabah-preserved-evidence'
REPO_ID = 1474927804
TAG = 'session-pair-20261127-wave3'
ROOT_FLOOR = 1593835520
METADATA_CAP = 32 * 1024**2
CONTROL_CAP = 48 * 1024**2
OVERALL_SECONDS = 2700
BLOCK = 1024**2
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
NEW_SHA = '8ec65743855d522d25f7e8b63c71d24c472b7087b3ca3c061d7529faf6e791e3'
COMPLETE_SHA = '313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d'
SOURCE_SHA = '5834032a8d367869ccb57a251ce89c8da1daf3c8a32fae944063621b3263c2ae'
RETIREMENT_SHA = 'd9e57b059eddb12238581f007591f44b8054d594d9ef870f56b665c9dba22701'
BASES = {
    'app-generated': (1699905882, '36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb', 3),
    'old-sdk-producer': (5238640114, '2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda', 97),
    'fresh-sdk-differential': (944883233, '3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee', 0),
    'qualified-snapshot-differential': (1291853917, 'f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b', 326),
}
ORIGINAL_ROOTS = [
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.ftqrs4Ju',
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.e9xp5UCf',
]


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


def file_identity(fd):
    s = os.fstat(fd)
    assert stat.S_ISREG(s.st_mode) and s.st_nlink == 1
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'uid': s.st_uid, 'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode),
            'nlink': s.st_nlink, 'mtime_ns': str(s.st_mtime_ns),
            'ctime_ns': str(s.st_ctime_ns)}


def xattrs(fd):
    return {n: base64.b64encode(os.getxattr(fd, n)).decode('ascii')
            for n in sorted(os.listxattr(fd))}


def open_regular(parent, name):
    fd = os.open(leaf(name), os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
    try:
        file_identity(fd)
        return fd
    except BaseException:
        os.close(fd)
        raise


def hash_fd(fd, runtime, maximum, capture=False):
    os.lseek(fd, 0, os.SEEK_SET)
    h, count, raw = hashlib.sha256(), 0, bytearray()
    while True:
        runtime.guard()
        b = os.read(fd, BLOCK)
        if not b:
            break
        count += len(b)
        assert count <= maximum
        h.update(b)
        if capture:
            raw.extend(b)
    return count, h.hexdigest(), bytes(raw)


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


def source_inventory(runtime, source_fd, expected, saved=None, full=True):
    assert dir_identity(source_fd) == expected['parent']
    assert SOURCE.resolve(strict=True) == SOURCE
    fresh_parent = directory(SOURCE)
    try:
        assert dir_identity(fresh_parent) == expected['parent']
    finally:
        os.close(fresh_parent)
    names = {x['name'] for x in expected['entries']}
    assert len(names) == 13 and set(os.listdir(source_fd)) == names
    result, small = {}, {}
    for row in expected['entries']:
        name = leaf(row['name'])
        fd = open_regular(source_fd, name)
        try:
            before = file_identity(fd)
            assert all(before[k] == row[k] for k in before if k != 'nlink')
            metadata = {'atime_ns': str(os.fstat(fd).st_atime_ns), 'xattrs': xattrs(fd)}
            wanted = ARCHIVE_SHA if name == ARCHIVE_NAME else row['sha256']
            if full:
                size, sha, raw = hash_fd(fd, runtime, row['bytes'], capture=row['bytes'] <= BLOCK)
                assert size == row['bytes'] and sha == wanted
                if raw:
                    small[name] = raw
            else:
                sha = wanted
            assert file_identity(fd) == before and xattrs(fd) == metadata['xattrs']
            if saved is not None:
                assert before == saved[name]['identity'] and metadata['xattrs'] == saved[name]['restoreMetadata']['xattrs']
            result[name] = {'name': name, 'bytes': row['bytes'], 'sha256': sha,
                            'identity': before, 'restoreMetadata': metadata if saved is None else saved[name]['restoreMetadata']}
        finally:
            os.close(fd)
    assert set(os.listdir(source_fd)) == names and dir_identity(source_fd) == expected['parent']
    return result, small


def historical_join(inventory, raw):
    header = json.loads(raw['HEADER.json'])
    new = json.loads(raw['NEW_ARCHIVE_VERIFIED.json'])
    complete = json.loads(raw['COMPLETE_PRESERVATION_VERIFIED.json'])
    source = json.loads(raw['SOURCE_REVERIFIED.json'])
    retired = json.loads(raw['RETIREMENT_RESULT.json'])
    prior = json.loads(raw['PRIOR_REFERENCES.json'])
    for name, pin in [('HEADER.json', HEADER_SHA), ('NEW_ARCHIVE_VERIFIED.json', NEW_SHA),
                      ('COMPLETE_PRESERVATION_VERIFIED.json', COMPLETE_SHA),
                      ('SOURCE_REVERIFIED.json', SOURCE_SHA), ('RETIREMENT_RESULT.json', RETIREMENT_SHA)]:
        assert digest(raw[name]) == pin == inventory[name]['sha256']
    assert header['schema'] == 'otzaria.session-pair-preservation/1'
    assert header['source_roots'] == ORIGINAL_ROOTS
    assert new['archive'] == complete['new_archive'] == source['new_archive'] == str(SOURCE / ARCHIVE_NAME)
    assert new['archive_bytes'] == complete['new_archive_bytes'] == ARCHIVE_BYTES
    assert new['archive_sha256'] == complete['new_archive_sha256'] == source['new_archive_sha256'] == ARCHIVE_SHA
    for key in ('device', 'inode', 'bytes', 'mtime_ns', 'ctime_ns'):
        assert str(new['archive_identity'][key]) == str(inventory[ARCHIVE_NAME]['identity'][key])
    assert new['header_sha256'] == complete['header_sha256'] == source['header_sha256'] == retired['header_sha256'] == HEADER_SHA
    assert new['members_verified'] == 58125 and new['new_payloads_verified'] == complete['new_payloads_verified'] == 58121
    assert new['prior_distinct_members'] == complete['prior_members_verified'] == 426
    assert complete['covered_source_files'] == 2802 and complete['full_restored_tree_materialized'] is False
    assert complete['new_archive_verification_sha256'] == NEW_SHA
    assert source['complete_preservation_receipt_sha256'] == retired['complete_preservation_sha256'] == COMPLETE_SHA
    assert retired['source_reverified_sha256'] == SOURCE_SHA
    assert retired['status'] == 'RETIRED_ONLY_EXACT_FULLY_PRESERVED_SESSION_PAIR'
    assert retired['full_absence_verified'] is True and retired['protected_identities_unchanged'] is True
    assert retired['roots'] == retired['removed'] == ORIGINAL_ROOTS
    assert retired['current_archive_bindings']['archive_bindings'] == complete['archive_bindings']
    assert digest(raw['RETIREMENT_PREDELETE.json']) == retired['predelete_receipt_sha256']
    assert prior['header_sha256'] == HEADER_SHA and prior['base_archives'] == header['base_archives']
    assert digest(raw['PRIOR_REFERENCES.json']) == complete['prior_reference_ledger_sha256'] == new['prior_reference_ledger']['sha256']
    assert prior['source_entries_sha256'] == header['metadata'][0]['sha256']
    assert len(prior['references']) == 426 and sum(x['source_files'] for x in prior['references']) == 2802
    assert len(header['base_archives']) == len(complete['archive_bindings']) == 4
    assert {x['id'] for x in complete['archive_bindings']} == set(BASES)
    assert {x['id'] for x in header['base_archives']} == set(BASES)
    for binding in complete['archive_bindings']:
        aid = binding['id']
        size, sha, count = BASES[aid]
        original = next(x for x in header['base_archives'] if x['id'] == aid)
        assert binding['archive_bytes'] == original['archive_bytes'] == size
        assert binding['archive_sha256'] == original['archive_sha256'] == sha
        assert binding['manifest_sha256'] == original['manifest_sha256']
        assert binding['referenced_members'] == count == sum(x['archive_id'] == aid for x in prior['references'])
    # Keep exact original dictionaries, including all four physical archive,
    # manifest, full-member receipt identities and the declared zero-use base.
    return {'baseArchives': header['base_archives'], 'historicalArchiveBindings': complete['archive_bindings'],
            'priorReferenceLedgerSHA256': inventory['PRIOR_REFERENCES.json']['sha256'],
            'historicalCompleteReceiptSHA256': COMPLETE_SHA, 'priorPhysicalMembers': 426,
            'priorOriginalFileOccurrences': 2802, 'baseVerificationPerformedNow': False,
            'windowsCurrentlyOffline': True, 'selfContained': False, 'fullTreeRestorePerformed': False}


class BoundedWriter:
    def __init__(self, runtime, fd):
        self.runtime, self.fd, self.count = runtime, fd, 0

    def write(self, b):
        assert self.count + len(b) <= METADATA_CAP, 'Metadata archive 32 MiB cap'
        self.runtime.guard(len(b))
        view = memoryview(b)
        while view:
            n = os.write(self.fd, view)
            assert n > 0
            self.count += n
            view = view[n:]
        return len(b)

    def flush(self):
        os.fsync(self.fd)


def metadata_bundle(runtime, source_fd, inventory):
    name = 'session-pair-preservation-metadata-20261127.tar.gz'
    runtime.guard(METADATA_CAP)
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644, dir_fd=runtime.fd)
    try:
        bounded = BoundedWriter(runtime, fd)
        with gzip.GzipFile(filename='', fileobj=bounded, mode='wb', mtime=0) as z:
            with tarfile.open(fileobj=z, mode='w|', format=tarfile.PAX_FORMAT) as tar:
                for n in sorted(set(inventory) - {ARCHIVE_NAME}):
                    expected = inventory[n]
                    source = open_regular(source_fd, n)
                    try:
                        assert file_identity(source) == expected['identity']
                        info = tarfile.TarInfo(n)
                        info.size = expected['bytes']
                        info.mode = expected['identity']['mode']
                        info.uid = expected['identity']['uid']
                        info.gid = expected['identity']['gid']
                        ns = int(expected['identity']['mtime_ns'])
                        info.mtime = ns // 1000000000
                        info.pax_headers = {'mtime': '%d.%09d' % divmod(ns, 1000000000)}
                        with os.fdopen(os.dup(source), 'rb') as body:
                            tar.addfile(info, body)
                        assert file_identity(source) == expected['identity']
                    finally:
                        os.close(source)
        os.fsync(fd)
    finally:
        os.close(fd)
    os.fsync(runtime.fd)
    # Independent bounded member read; no extraction and no original writes.
    path = CONTROL / name
    seen = set()
    with gzip.open(path, 'rb') as z:
        with tarfile.open(fileobj=z, mode='r|') as tar:
            for m in tar:
                runtime.guard()
                assert m.isfile() and m.name in inventory and m.name != ARCHIVE_NAME and m.name not in seen
                seen.add(m.name)
                expected = inventory[m.name]
                assert m.size == expected['bytes'] and m.mode == expected['identity']['mode']
                assert m.uid == expected['identity']['uid'] and m.gid == expected['identity']['gid']
                body = tar.extractfile(m)
                h, size = hashlib.sha256(), 0
                for b in iter(lambda: body.read(BLOCK), b''):
                    runtime.guard()
                    size += len(b)
                    assert size <= m.size
                    h.update(b)
                assert size == expected['bytes'] and h.hexdigest() == expected['sha256']
        assert not z.read(BLOCK).strip(b'\0') and z.read(1) == b''
    assert seen == set(inventory) - {ARCHIVE_NAME} and len(seen) == 12
    input_fd = open_regular(runtime.fd, name)
    try:
        before = file_identity(input_fd)
        size, sha, _ = hash_fd(input_fd, runtime, METADATA_CAP)
        assert file_identity(input_fd) == before
    finally:
        os.close(input_fd)
    return {'name': name, 'bytes': size, 'sha256': sha, 'identity': before,
            'all12RegularMembersVerified': True}


def private_repository(runtime):
    value = runtime.api('repos/' + REPO, 'repository')
    assert type(value['id']) is int and value['id'] == REPO_ID
    assert value['full_name'] == REPO and value['owner']['login'] == 'davidpovarsky'
    assert value['private'] is True and value['archived'] is False and value['default_branch'] == 'main'
    return {'id': value['id'], 'full_name': value['full_name'], 'private': True}


def validate_release(value, release_id=None):
    assert type(value['id']) is int and value['id'] > 0
    assert release_id is None or value['id'] == release_id
    assert value['draft'] is True and value['tag_name'] == TAG
    assert value['url'] == 'https://api.github.com/repos/%s/releases/%d' % (REPO, value['id'])
    assert value['html_url'].startswith('https://github.com/' + REPO + '/releases/')
    return value['id']


def main():
    assert sys.argv[1:] == ['--execute-reviewed-upload'], 'Explicit reviewed-upload invocation required'
    inventory_path = Path(__file__).resolve().parent / 'FRESH_13_LEAF_INVENTORY.json'
    assert not inventory_path.is_symlink()
    raw = inventory_path.read_bytes()
    assert len(raw) == 4180 and digest(raw) == INVENTORY_SHA
    expected = json.loads(raw)
    assert expected['directory'] == str(SOURCE)
    assert expected['parent'] == {'device': 2064, 'inode': 722979, 'uid': 1001, 'gid': 1001, 'mode': 1472}
    runtime = Runtime()
    source_fd = None
    try:
        runtime.write('ATTEMPT.json', {'utc': utc(), 'controllerSHA256': digest(Path(__file__).read_bytes()),
            'sourceInventorySHA256': INVENTORY_SHA, 'rootFreeBefore': runtime.root_before,
            'rootReserveBytes': ROOT_FLOOR, 'metadataCapBytes': METADATA_CAP,
            'overallSeconds': OVERALL_SECONDS, 'controllerAutomaticRetries': 0,
            'localRetirement': False, 'selfContained': False, 'windowsAccess': False})
        runtime.phase = 'full-current-source-hash-and-historical-join'
        source_fd = directory(SOURCE)
        source, small = source_inventory(runtime, source_fd, expected)
        assert source[ARCHIVE_NAME]['bytes'] == ARCHIVE_BYTES
        dependencies = historical_join(source, small)
        runtime.write('SOURCE_PREFLIGHT.json', {'utc': utc(), 'parent': expected['parent'],
            'entries': source, 'all13LeavesFullyHashed': True, 'dependencies': dependencies})
        runtime.phase = 'bounded-metadata-bundle'
        bundle = metadata_bundle(runtime, source_fd, source)
        source_inventory(runtime, source_fd, expected, source, full=False)
        repo = private_repository(runtime)
        manifest = {'schema': 'otzaria.private-session-pair-differential-transport/1',
            'sourceDirectory': str(SOURCE), 'sourceParent': expected['parent'],
            'originalArchive': source[ARCHIVE_NAME], 'metadataArchive': bundle,
            'metadataMembers': [source[n] for n in sorted(source) if n != ARCHIVE_NAME],
            'unchangedExternalDependencies': dependencies, 'privateRepository': repo,
            'originalInventorySHA256': INVENTORY_SHA, 'localRetirement': False,
            'selfContained': False, 'fullTreeRestore': False, 'windowsAccess': False,
            'qualification': 'Exact opaque differential and metadata transport only; historical Windows verification is retained unchanged, not refreshed. No SDK, app, native or physical acceptance.'}
        manifest_pin = runtime.write('PRESERVED_SESSION_PAIR_MANIFEST.json', manifest)
        runtime.phase = 'new-draft-release-once'
        # Require actual authenticated 404; any ambiguity/existing release fails.
        code, response, _ = runtime.gh(['api', '--include', 'repos/' + REPO + '/releases/tags/' + TAG],
                                        'absence-of-new-draft-tag', allow_error=True)
        normalized = response.replace(b'\r\n', b'\n')
        headers, body = normalized.split(b'\n\n', 1)
        assert code != 0 and headers.splitlines()[0].split()[1] == b'404'
        assert json.loads(body)['message'] == 'Not Found'
        request_pin = runtime.write('DRAFT_RELEASE_REQUEST.json', {
            'tag_name': TAG, 'target_commitish': 'main', 'name': 'Wave3 exact session-pair differential evidence',
            'body': 'Private archival transport only. The session-pair differential is NOT self-contained. All four original Windows archive/manifest/full-member-receipt dependencies remain unchanged; Windows is currently offline and no fresh full-tree restoration is claimed. Original evidence and all twelve metadata siblings are retained with full authenticated byte readback. No application release, SDK qualification or native acceptance. Archive SHA256: ' + ARCHIVE_SHA,
            'draft': True, 'prerelease': False, 'generate_release_notes': False})
        release = runtime.api('repos/' + REPO + '/releases', 'create-new-private-draft',
                              ['-X', 'POST', '--input', request_pin['path']])
        release_id = validate_release(release)
        assert release['assets'] == []
        runtime.write('DRAFT_RELEASE_CREATED.json', {'id': release_id, 'tag': TAG, 'draft': True,
            'repository': repo, 'url': release['url'], 'html_url': release['html_url']})
        assets_expected = {
            ARCHIVE_NAME: {'bytes': ARCHIVE_BYTES, 'sha256': ARCHIVE_SHA},
            bundle['name']: {'bytes': bundle['bytes'], 'sha256': bundle['sha256']},
            'PRESERVED_SESSION_PAIR_MANIFEST.json': {'bytes': manifest_pin['bytes'], 'sha256': manifest_pin['sha256']},
        }
        runtime.phase = 'single-upload-no-clobber'
        private_repository(runtime)
        validate_release(runtime.api('repos/' + REPO + '/releases/tags/' + TAG, 'tag-before-upload'), release_id)
        source_inventory(runtime, source_fd, expected, source, full=False)
        runtime.write('ARCHIVE_UPLOAD_STARTED.json', {'utc': utc(), 'releaseID': release_id,
            'assets': assets_expected, 'controllerAutomaticRetries': 0, 'clobber': False})
        runtime.gh(['release', 'upload', TAG, '--repo', REPO,
                    str(CONTROL / bundle['name']), manifest_pin['path'], str(SOURCE / ARCHIVE_NAME)],
                   'single-upload', timeout=1200)
        source_inventory(runtime, source_fd, expected, source, full=False)
        private_repository(runtime)
        remote = runtime.api('repos/%s/releases/%d' % (REPO, release_id), 'release-after-upload')
        validate_release(remote, release_id)
        assert len(remote['assets']) == 3 and {a['name'] for a in remote['assets']} == set(assets_expected)
        assert len({a['id'] for a in remote['assets']}) == 3
        verified = []
        runtime.phase = 'three-full-authenticated-streaming-readbacks'
        for asset in remote['assets']:
            wanted = assets_expected[asset['name']]
            assert type(asset['id']) is int and asset['id'] > 0
            assert asset['url'] == 'https://api.github.com/repos/%s/releases/assets/%d' % (REPO, asset['id'])
            assert asset['state'] == 'uploaded' and asset['size'] == wanted['bytes']
            assert not asset.get('digest') or asset['digest'] == 'sha256:' + wanted['sha256']
            result = runtime.gh(['api', '-H', 'Accept: application/octet-stream',
                'repos/%s/releases/assets/%d' % (REPO, asset['id'])], 'readback-%d' % asset['id'],
                timeout=1200, expected=wanted)
            verified.append({'name': asset['name'], 'id': asset['id'], 'apiURL': asset['url'],
                **result, 'authenticatedFullReadback': True})
            runtime.write('READBACK-%d.json' % asset['id'], verified[-1])
        runtime.phase = 'full-source-and-remote-final-fences'
        source_inventory(runtime, source_fd, expected, source, full=True)
        private_repository(runtime)
        final = runtime.api('repos/%s/releases/%d' % (REPO, release_id), 'release-final')
        validate_release(final, release_id)
        assert {(a['id'], a['name'], a['size'], a['state']) for a in final['assets']} == {
            (a['id'], a['name'], a['size'], a['state']) for a in remote['assets']}
        validate_release(runtime.api('repos/' + REPO + '/releases/tags/' + TAG, 'tag-final'), release_id)
        result = {'status': 'EXACT_PRIVATE_DIFFERENTIAL_AND_12_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINALS_RETAINED',
            'utc': utc(), 'repository': repo, 'releaseID': release_id, 'tag': TAG, 'draft': True,
            'releaseURL': final['html_url'], 'sourceDirectory': str(SOURCE), 'sourceParent': expected['parent'],
            'sourceIdentity': source[ARCHIVE_NAME]['identity'], 'sourceRestoreMetadata': source[ARCHIVE_NAME]['restoreMetadata'],
            'manifest': manifest_pin, 'assets': verified, 'metadataMembersVerified': 12,
            'currentSourceFullHashesUnchanged': True, 'unchangedExternalDependencies': dependencies,
            'selfContained': False, 'fullTreeRestorationVerified': False, 'windowsAccess': False,
            'localRetirement': False, 'newSDKBuilds': 0, 'nativeRuns': 0,
            'rootFreeBefore': runtime.root_before, 'rootFreeAfter': runtime.free(),
            'seconds': time.monotonic() - runtime.started}
        pin = runtime.write('VERIFIED_PRIVATE_SESSION_PAIR_TRANSPORT.json', result)
        print(json.dumps({'status': result['status'], 'receipt': pin, 'releaseID': release_id,
                          'localRetirement': False, 'selfContained': False, 'windowsAccess': False}))
    except BaseException as exc:
        runtime.write('FAILED.json', {'status': 'FAILED_OR_INCOMPLETE_ORIGINALS_NOT_REMOVED', 'utc': utc(),
            'phase': runtime.phase, 'errorType': type(exc).__name__, 'error': str(exc)[:2000],
            'seconds': time.monotonic() - runtime.started, 'localRetirement': False,
            'automaticRetry': False, 'selfContained': False}, terminal=True)
        raise
    finally:
        if source_fd is not None:
            os.close(source_fd)
        os.close(runtime.fd)


if __name__ == '__main__':
    main()
