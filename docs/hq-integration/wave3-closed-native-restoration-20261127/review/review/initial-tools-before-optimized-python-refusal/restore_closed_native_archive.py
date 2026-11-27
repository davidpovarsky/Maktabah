#!/usr/bin/env python3
"""Restore ONE preserved archive; never extract its Mac/source payload.

This source is prepared for root review. Running it requires a separately
preserved pointer SHA. No credential is read, printed or changed by this tool.
The private asset IDs and every payload hash below are from the actual complete
authenticated readback, not an upload-state or provider-digest assumption.
"""
from pathlib import Path
import argparse
import base64
import datetime
import gzip
import hashlib
import io
import json
import os
import selectors
import signal
import stat
import subprocess
import tarfile
import time
import uuid

CONTROL = Path('/home/ubuntu/otzaria-wave3-private-evidence-publication-20261127')
SOURCE = Path('/mnt/development/projects/diagnostics/otzaria-wave3-closed-native-preservation-20261127.fcws2jok')
LEAF = 'closed-native-self-contained.tar.gz'
REPO = 'davidpovarsky/Maktabah-preserved-evidence'
REPO_ID = 1474927804
RELEASE_ID = 461088091
TAG = 'closed-native-20261127-wave3'
RECEIPT_SHA = 'c8eb38f53a7b704587523d330c1c1ac63a2dd17cf49900cebb7a9406b545c1ed'
ORIGINAL_VERIFICATION_SHA = '50987d6a7daa36458322f755068f6730609ad470309ab2fa6cd4e96fdcf0720e'
PARENT = {'device': 2064, 'inode': 397500, 'uid': 1001, 'gid': 1001, 'mode': 1472}
ROOT_FLOOR = 1593835520
DATA_FLOOR = 2147483648
CONTROL_BUDGET = 32 * 1024 * 1024
ASSETS = {
    LEAF: {'id': 802156560, 'bytes': 1463489048,
           'sha256': '6e5202a79e92edd6d03c0c00af50a94633539817fb34bc3a203c7340239d71e7'},
    'closed-native-preservation-metadata-20261127.tar.gz': {
        'id': 802156561, 'bytes': 5201005,
        'sha256': 'e4d4d954bee4797c3b4fc9e8abf415937f47214aefdfd5cde55aa6b9eb77187a'},
    'PRESERVED_ARCHIVE_MANIFEST.json': {'id': 802156548, 'bytes': 8651,
        'sha256': 'e8e6210b7fd6e4a808ac851f8e2842df2db8ade6914a667ec6bd648a0adb87c5'},
}
METADATA_NAME = 'closed-native-preservation-metadata-20261127.tar.gz'
MANIFEST_NAME = 'PRESERVED_ARCHIVE_MANIFEST.json'


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def leaf_name(value):
    assert isinstance(value, str) and value not in ('', '.', '..')
    assert '/' not in value and '\\' not in value and '\x00' not in value
    return value


def open_directory(path):
    """No component of the fixed absolute path may be a symlink."""
    path = Path(path)
    assert path.is_absolute() and '..' not in path.parts
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise


def parent_identity(fd):
    s = os.fstat(fd)
    assert stat.S_ISDIR(s.st_mode)
    return {'device': s.st_dev, 'inode': s.st_ino, 'uid': s.st_uid,
            'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode)}


def open_source():
    fd = open_directory(SOURCE)
    try:
        assert parent_identity(fd) == PARENT, 'Exact preserved parent identity changed'
        return fd
    except BaseException:
        os.close(fd)
        raise


def identity(s):
    assert stat.S_ISREG(s.st_mode) and s.st_nlink == 1, 'Expected single-link regular leaf'
    return {'device': s.st_dev, 'inode': s.st_ino, 'size': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def open_leaf(parent_fd, name):
    fd = os.open(leaf_name(name), os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_fd)
    try:
        identity(os.fstat(fd))
        return fd
    except BaseException:
        os.close(fd)
        raise


def hash_fd(fd, expected_bytes):
    h, count = hashlib.sha256(), 0
    while True:
        block = os.pread(fd, 1024 * 1024, count)
        if not block:
            break
        count += len(block)
        assert count <= expected_bytes, 'Unexpected additional source bytes'
        h.update(block)
    assert count == expected_bytes, 'Incomplete source bytes'
    return h.hexdigest()


def read_regular(path, maximum=1024 * 1024):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = identity(os.fstat(fd))
        assert before['size'] <= maximum
        raw = os.pread(fd, maximum + 1, 0)
        assert len(raw) == before['size'] and identity(os.fstat(fd)) == before
        return raw
    finally:
        os.close(fd)


def verify_receipt(raw):
    assert digest(raw) == RECEIPT_SHA
    value = json.loads(raw)  # Python preserves the actual nanosecond integers.
    assert value['status'] == 'PRIVATE_ARCHIVE_AND_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINAL_RETAINED'
    assert value['repository'] == {'id': REPO_ID, 'full_name': REPO, 'private': True}
    assert value['releaseID'] == RELEASE_ID and value['tag'] == TAG and value['draft'] is True
    assert value['localRetirement'] is False and value['applicationDistribution'] is False
    rows = {r['name']: r for r in value['assets']}
    assert len(value['assets']) == len(rows) == len(ASSETS) and set(rows) == set(ASSETS)
    for name, expected in ASSETS.items():
        row = rows[name]
        assert all(row[k] == expected[k] for k in ('id', 'bytes', 'sha256'))
        assert row['authenticatedFullReadback'] is True and row['state'] == 'uploaded'
    assert value['sourceIdentity']['size'] == ASSETS[LEAF]['bytes']
    return value


def verify_manifest(raw, receipt):
    assert len(raw) == ASSETS[MANIFEST_NAME]['bytes'] and digest(raw) == ASSETS[MANIFEST_NAME]['sha256']
    value = json.loads(raw)
    assert value['schema'] == 'otzaria.private-archive-preservation.v1'
    assert value['sourceDirectory'] == str(SOURCE)
    assert value['privateRepository'] == receipt['repository']
    assert value['originalArchive'] == {'name': LEAF, 'bytes': ASSETS[LEAF]['bytes'],
        'sha256': ASSETS[LEAF]['sha256'], 'identity': receipt['sourceIdentity']}
    assert value['metadataArchive'] == {'name': METADATA_NAME, 'bytes': ASSETS[METADATA_NAME]['bytes'],
                                       'sha256': ASSETS[METADATA_NAME]['sha256']}
    rows = {leaf_name(r['path']): r for r in value['metadataMembers']}
    assert len(value['metadataMembers']) == len(rows) == 22 and LEAF not in rows
    for row in rows.values():
        assert type(row['bytes']) is int and 0 <= row['bytes'] <= 64 * 1024 * 1024
        assert len(row['sha256']) == 64 and row['sourceIdentity']['size'] == row['bytes']
    assert rows['ARCHIVE_VERIFIED.json']['sha256'] == ORIGINAL_VERIFICATION_SHA
    return value


def verify_metadata_tar(path, manifest):
    wanted = {r['path']: r for r in manifest['metadataMembers']}
    seen, count = set(), 0
    with gzip.open(path, 'rb') as gz:
        with tarfile.open(fileobj=gz, mode='r|') as archive:
            for member in archive:
                assert member.isfile() and member.name in wanted and member.name not in seen
                row = wanted[member.name]
                assert member.size == row['bytes']
                h, size, verification = hashlib.sha256(), 0, bytearray()
                f = archive.extractfile(member)
                for block in iter(lambda: f.read(1024 * 1024), b''):
                    size += len(block); count += len(block)
                    assert size <= row['bytes'] and count <= 128 * 1024 * 1024
                    h.update(block)
                    if member.name == 'ARCHIVE_VERIFIED.json':
                        assert size <= 1024 * 1024
                        verification.extend(block)
                assert size == row['bytes'] and h.hexdigest() == row['sha256']
                if verification:
                    proof = json.loads(verification)
                    assert proof['every_source_file_maps_to_verified_member'] is True
                    assert proof['archive']['bytes'] == ASSETS[LEAF]['bytes']
                    assert proof['archive']['sha256'] == ASSETS[LEAF]['sha256']
                seen.add(member.name)
        for block in iter(lambda: gz.read(1024 * 1024), b''):
            assert not any(block), 'Nonzero trailing metadata tar data'
    assert seen == set(wanted)
    return {'regularMembers': len(seen), 'payloadBytes': count, 'allMemberBytesVerified': True,
            'extractedFiles': 0}


def verify_siblings(parent_fd, manifest, *, archive_present, extra=()):
    rows = {r['path']: r for r in manifest['metadataMembers']}
    expected = set(rows) | ({LEAF} if archive_present else set()) | set(extra)
    assert set(os.listdir(parent_fd)) == expected, 'Exact protected sibling path set changed'
    result = []
    for name in sorted(rows):
        fd = open_leaf(parent_fd, name)
        try:
            before = identity(os.fstat(fd))
            assert before == rows[name]['sourceIdentity'], name
            assert hash_fd(fd, rows[name]['bytes']) == rows[name]['sha256'], name
            assert identity(os.fstat(fd)) == before
            assert identity(os.stat(name, dir_fd=parent_fd, follow_symlinks=False)) == before
            result.append({'name': name, 'identity': before, 'sha256': rows[name]['sha256']})
        finally:
            os.close(fd)
    return result


def restore_metadata(fd, saved):
    os.fchown(fd, saved['uid'], saved['gid'])
    os.fchmod(fd, saved['mode'])
    assert not os.listxattr(fd), 'Unexpected attributes on exclusive restoration file'
    for row in saved['xattrs']:
        name = base64.b64decode(row['name_base64'], validate=True)
        raw = base64.b64decode(row['value_base64'], validate=True)
        assert len(raw) == row['bytes'] and digest(raw) == row['sha256']
        os.setxattr(fd, name, raw)
    os.utime(fd, ns=(saved['atime_ns'], saved['mtime_ns']))
    os.fsync(fd)
    s = os.fstat(fd)
    assert stat.S_IMODE(s.st_mode) == saved['mode'] and (s.st_uid, s.st_gid) == (saved['uid'], saved['gid'])
    assert (s.st_atime_ns, s.st_mtime_ns) == (saved['atime_ns'], saved['mtime_ns'])
    actual = {os.fsencode(k): os.getxattr(fd, k) for k in os.listxattr(fd)}
    assert actual == {base64.b64decode(r['name_base64']): base64.b64decode(r['value_base64']) for r in saved['xattrs']}


class Journal:
    """One exclusive bounded rootfs attempt; no DATA archive staging here."""
    def __init__(self, operation, attempt, existing=False):
        assert operation in ('restore', 'retire') and str(uuid.UUID(attempt)) == attempt
        parent = open_directory(CONTROL)
        self.name = operation + '-' + attempt
        self.path = CONTROL / self.name
        self.sequence = 0
        self.root_before = os.statvfs(CONTROL).f_bavail * os.statvfs(CONTROL).f_frsize
        assert self.root_before >= ROOT_FLOOR
        try:
            if not existing:
                os.mkdir(self.name, 0o700, dir_fd=parent)
                os.fsync(parent)
            self.fd = os.open(self.name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
        finally:
            os.close(parent)
        assert parent_identity(self.fd)['device'] == os.stat(CONTROL).st_dev

    def guard(self, addition=0):
        s = os.fstatvfs(self.fd)
        assert s.f_bavail * s.f_frsize - addition >= ROOT_FLOOR, 'Rootfs preservation floor'
        used = sum(os.stat(n, dir_fd=self.fd, follow_symlinks=False).st_blocks * 512 for n in os.listdir(self.fd))
        assert used + addition <= CONTROL_BUDGET, 'Bounded preservation metadata budget'

    def write(self, name, value, terminal=False):
        raw = value if isinstance(value, bytes) else canonical(value)
        assert len(raw) <= 1024 * 1024
        if not terminal:
            self.guard(len(raw))
        fd = os.open(leaf_name(name), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=self.fd)
        try:
            with os.fdopen(os.dup(fd), 'wb') as f:
                f.write(raw); f.flush(); os.fsync(f.fileno())
        finally:
            os.close(fd)
        os.fsync(self.fd)
        check = read_regular(self.path / name)
        assert check == raw
        return {'path': str(self.path / name), 'bytes': len(raw), 'sha256': digest(raw)}

    def close(self):
        os.close(self.fd)

    def transfer(self, args, label, maximum, expected=None, output_fd=None, data_guard=None, timeout=1200):
        self.guard()
        self.sequence += 1
        label = str(self.sequence).zfill(2) + '-' + leaf_name(label)
        error_fd = os.open(label + '.stderr', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=self.fd)
        process = None
        selector = None
        started = time.monotonic()
        result = None
        start_identity = None
        try:
            process = subprocess.Popen(['sudo', '-u', 'ubuntu', '-H', 'gh', *args],
                stdout=subprocess.PIPE, stderr=error_fd, start_new_session=True)
            # Entered cleanup scope before any ledger/selector/identity call.
            try:
                proc = Path('/proc/%d/stat' % process.pid).read_text()
                start_identity = proc[proc.rfind(')') + 2:].split()[19]
                assert os.getpgid(process.pid) == process.pid
            except (FileNotFoundError, ProcessLookupError):
                if process.poll() is None:
                    raise
            self.write(label + '.PROCESS.json', {'pid': process.pid, 'pgid': process.pid,
                'procStart': start_identity, 'argv': ['sudo', '-u', 'ubuntu', '-H', 'gh', *args], 'utc': utc()}, terminal=True)
            fd = process.stdout.fileno(); os.set_blocking(fd, False)
            selector = selectors.DefaultSelector(); selector.register(fd, selectors.EVENT_READ)
            h, count, captured = hashlib.sha256(), 0, bytearray()
            while True:
                self.guard()
                assert time.monotonic() - started <= timeout, 'Owned authenticated transfer deadline'
                if not selector.select(0.5):
                    continue
                try:
                    block = os.read(fd, 1024 * 1024)
                except BlockingIOError:
                    continue
                if not block:
                    break
                count += len(block)
                assert count <= maximum, 'Unexpected authenticated payload length'
                h.update(block)
                if output_fd is not None:
                    if data_guard:
                        data_guard(len(block))
                    else:
                        self.guard(len(block))
                    view = memoryview(block)
                    while view:
                        n = os.write(output_fd, view)
                        assert n > 0
                        view = view[n:]
                elif expected is None:
                    captured.extend(block)
            code = process.wait(timeout=20)
            assert code == 0, 'Authenticated transfer failed; raw error retained privately'
            if expected:
                assert count == expected['bytes'] and h.hexdigest() == expected['sha256']
            if output_fd is not None:
                os.fsync(output_fd)
            result = {'bytes': count, 'sha256': h.hexdigest(), 'exit': code, 'seconds': time.monotonic() - started}
            self.write(label + '.RESULT.json', result)
            return bytes(captured) if expected is None else result
        finally:
            try:
                if process is not None and process.poll() is None:
                    # The leader is our unreaped Popen child, in its own
                    # session. Never signal a reaped/different PID or group.
                    proc = Path('/proc/%d/stat' % process.pid).read_text()
                    current = proc[proc.rfind(')') + 2:].split()[19]
                    assert os.getpgid(process.pid) == process.pid
                    assert start_identity is None or current == start_identity
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        if process.poll() is None:
                            proc = Path('/proc/%d/stat' % process.pid).read_text()
                            assert os.getpgid(process.pid) == process.pid
                            assert start_identity is None or proc[proc.rfind(')') + 2:].split()[19] == start_identity
                            os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=20)
            finally:
                if process is not None and process.stdout:
                    process.stdout.close()
                if selector:
                    selector.close()
                try:
                    os.fsync(error_fd)
                finally:
                    os.close(error_fd)


def remote_state(journal):
    repo = json.loads(journal.transfer(['api', 'repos/' + REPO], 'repository', 1024 * 1024, timeout=60))
    assert repo['id'] == REPO_ID and repo['full_name'] == REPO and repo['private'] is True
    assert repo['owner']['login'] == 'davidpovarsky' and repo['archived'] is False
    release = json.loads(journal.transfer(['api', 'repos/' + REPO + '/releases/' + str(RELEASE_ID)], 'release', 1024 * 1024, timeout=60))
    assert release['id'] == RELEASE_ID and release['tag_name'] == TAG and release['draft'] is True
    rows = {r['name']: r for r in release['assets']}
    assert len(release['assets']) == len(rows) == len(ASSETS) and set(rows) == set(ASSETS)
    for name, expected in ASSETS.items():
        row = rows[name]
        assert row['id'] == expected['id'] and row['size'] == expected['bytes'] and row['state'] == 'uploaded'
        if row.get('digest'):
            assert row['digest'] == 'sha256:' + expected['sha256']
    return {'repositoryID': REPO_ID, 'private': True, 'releaseID': RELEASE_ID, 'draft': True,
            'assetIDs': {n: r['id'] for n, r in rows.items()}, 'observedUTC': utc()}


def download(journal, name, output_fd, data_guard=None):
    row = ASSETS[name]
    return journal.transfer(['api', '-H', 'Accept: application/octet-stream',
        'repos/' + REPO + '/releases/assets/' + str(row['id'])], 'asset-' + str(row['id']),
        row['bytes'], expected=row, output_fd=output_fd, data_guard=data_guard)


def download_metadata(journal, receipt):
    for name in (MANIFEST_NAME, METADATA_NAME):
        journal.guard(ASSETS[name]['bytes'])
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=journal.fd)
        try:
            download(journal, name, fd)
        finally:
            os.close(fd)
        os.fsync(journal.fd)
    manifest = verify_manifest(read_regular(journal.path / MANIFEST_NAME), receipt)
    proof = verify_metadata_tar(journal.path / METADATA_NAME, manifest)
    journal.write('METADATA_MEMBERS_VERIFIED.json', proof)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', action='store_true', required=True)
    parser.add_argument('--pointer', type=Path, required=True)
    parser.add_argument('--pointer-sha256', required=True)
    parser.add_argument('--attempt', required=True, help='Fresh canonical UUID, not an existing attempt')
    args = parser.parse_args()
    raw = read_regular(args.pointer)
    assert digest(raw) == args.pointer_sha256 and len(args.pointer_sha256) == 64
    pointer = json.loads(raw)
    assert pointer['schema'] == 'otzaria.one-archive-restoration-pointer.v1'
    assert pointer['sourceDirectory'] == str(SOURCE) and pointer['leaf'] == LEAF and pointer['parent'] == PARENT
    assert pointer['assets'] == ASSETS and pointer['receiptSHA256'] == RECEIPT_SHA
    assert pointer['restorationScriptSHA256'] == digest(read_regular(Path(__file__)))
    receipt = verify_receipt(base64.b64decode(pointer['receiptBase64'], validate=True))
    journal = Journal('restore', args.attempt)
    parent_fd = None; output_fd = None; linked = False; temporary = None
    try:
        journal.write('POINTER.json', raw)
        remote_state(journal)
        manifest = download_metadata(journal, receipt)
        parent_fd = open_source()
        protected = verify_siblings(parent_fd, manifest, archive_present=False)
        available = os.fstatvfs(parent_fd)
        assert available.f_bavail * available.f_frsize >= DATA_FLOOR + ASSETS[LEAF]['bytes'] + 1024 * 1024
        temporary = '.closed-native-restore-' + args.attempt + '.partial'
        output_fd = os.open(temporary, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        os.fsync(parent_fd)
        def data_guard(amount):
            s = os.fstatvfs(parent_fd)
            assert s.f_bavail * s.f_frsize - amount >= DATA_FLOOR, 'Restoration Data floor'
        result = download(journal, LEAF, output_fd, data_guard)
        before = identity(os.fstat(output_fd))
        assert before['size'] == ASSETS[LEAF]['bytes'] and hash_fd(output_fd, before['size']) == ASSETS[LEAF]['sha256']
        assert identity(os.fstat(output_fd)) == before
        assert verify_siblings(parent_fd, manifest, archive_present=False, extra=(temporary,)) == protected
        assert parent_identity(parent_fd) == PARENT
        restore_metadata(output_fd, pointer['leafRestoreMetadata'])
        ready = identity(os.fstat(output_fd))
        assert identity(os.stat(temporary, dir_fd=parent_fd, follow_symlinks=False)) == ready
        assert ready['size'] == ASSETS[LEAF]['bytes']
        # Exclusive hard-link publication cannot replace an existing leaf.
        # Fsync the final directory entry before removing only our partial alias.
        os.link(temporary, LEAF, src_dir_fd=parent_fd, dst_dir_fd=parent_fd, follow_symlinks=False)
        linked = True; os.fsync(parent_fd)
        os.unlink(temporary, dir_fd=parent_fd); os.fsync(parent_fd)
        final = identity(os.fstat(output_fd))
        assert identity(os.stat(LEAF, dir_fd=parent_fd, follow_symlinks=False)) == final
        assert final['size'] == ASSETS[LEAF]['bytes']
        assert verify_siblings(parent_fd, manifest, archive_present=True) == protected
        journal.write('RESTORED.json', {'status': 'EXACT_ARCHIVE_RESTORED_NO_PAYLOAD_EXTRACTION', 'utc': utc(),
            'archive': str(SOURCE / LEAF), 'payload': result, 'identity': final,
            'metadataRestored': pointer['leafRestoreMetadata'], 'originalCtimeAndInodeNotRestorable': True,
            'protectedSiblings': len(protected), 'newSDKBuilds': 0, 'nativeRuns': 0}, terminal=True)
    except BaseException as error:
        journal.write('RESTORE_FAILED.json', {'status': 'FAILED_PRESERVED_PARTIAL_OR_RESULT', 'utc': utc(),
            'errorType': type(error).__name__, 'message': str(error), 'finalLinkPublished': linked,
            'partialName': temporary, 'noOtherSourceMutation': True}, terminal=True)
        raise
    finally:
        if output_fd is not None:
            os.close(output_fd)
        if parent_fd is not None:
            os.close(parent_fd)
        journal.close()


if __name__ == '__main__':
    main()
