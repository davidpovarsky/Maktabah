#!/usr/bin/env python3
"""Restore ONE opaque differential archive; never extract its source payload.

This source is prepared for root review. Running it requires a separately
preserved pointer SHA. No credential is read, printed or changed by this tool.
The actual terminal and publication proofs are pinned with the authenticated
readback receipt and asset IDs. Windows bases remain unchanged
external dependencies; restoring this one file is not restoring either tree.
"""
if not __debug__:
    raise RuntimeError('Optimized Python is forbidden: preservation assertions must execute')

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

CONTROL = Path('/home/ubuntu/otzaria-wave3-private-session-pair-publication-20261127')
SOURCE = Path('/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127')
LEAF = 'session-pair-differential.tar.gz'
REPO = 'davidpovarsky/Maktabah-preserved-evidence'
REPO_ID = 1474927804
RELEASE_ID = 461122448
TAG = 'session-pair-20261127-wave3'
RECEIPT_SHA = '0c07d1c5b25136331d7790f88436aef3a3d7aef5b82e4cd23ca61ba848ffb05a'
RECEIPT_NAME = 'VERIFIED_PRIVATE_SESSION_PAIR_TRANSPORT.json'
RECEIPT_BYTES = 12987
TRANSPORT_COMPLETION = {
    'terminal': {'name': 'SESSION_PAIR_TRANSPORT_TERMINAL_JOB.json', 'bytes': 1861,
        'sha256': 'b9ff599b5da607379f5cd6535c7a04db5e6c5e043d1eb4852e3b2be214e19257'},
    'publication': {'name': 'SESSION_PAIR_FINAL_RECEIPT_PUBLISHED.json', 'bytes': 603,
        'sha256': '3005be20cf8c2f2ff26f64597f6726709f53df4900a97948326bc93999e6960c'},
}
ORIGINAL_VERIFICATION_SHA = '8ec65743855d522d25f7e8b63c71d24c472b7087b3ca3c061d7529faf6e791e3'
COMPLETE_SHA = '313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d'
SOURCE_SHA = '5834032a8d367869ccb57a251ce89c8da1daf3c8a32fae944063621b3263c2ae'
RETIREMENT_SHA = 'd9e57b059eddb12238581f007591f44b8054d594d9ef870f56b665c9dba22701'
INVENTORY_SHA = 'c2805d00315a0cbfa7b83cd444f0d2eb33b63f12b53067d77f88ec4fcb342de2'
PARENT = {'device': 2064, 'inode': 722979, 'uid': 1001, 'gid': 1001, 'mode': 1472}
ROOT_FLOOR = 1593835520
DATA_FLOOR = 2147483648
CONTROL_BUDGET = 48 * 1024 * 1024
METADATA_CAP = 32 * 1024 * 1024
BASES = {
    'app-generated': (1699905882, '36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb', 3),
    'old-sdk-producer': (5238640114, '2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda', 97),
    'fresh-sdk-differential': (944883233, '3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee', 0),
    'qualified-snapshot-differential': (1291853917, 'f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b', 326),
}
ASSETS = {
    LEAF: {'id': 802351073, 'bytes': 1342747334,
           'sha256': 'd0743bef81222350ed4cae139504585c81f1592ec084e31884933e79c22a5e8d'},
    'session-pair-preservation-metadata-20261127.tar.gz': {
        'id': 802350726, 'bytes': 20247355,
        'sha256': '43e303295a389ee1bbe300993070dc1c6f9bd906d408705c68b6ff4aad9366c2'},
    'PRESERVED_SESSION_PAIR_MANIFEST.json': {'id': 802350985, 'bytes': 17372,
        'sha256': '47755d066e979027fecb45944a236f5284addc62644a9b44a9487f5e9919c0f7'},
}
METADATA_NAME = 'session-pair-preservation-metadata-20261127.tar.gz'
MANIFEST_NAME = 'PRESERVED_SESSION_PAIR_MANIFEST.json'
EXPECTED_METADATA = {
    'COMPLETE_PRESERVATION_VERIFIED.json': (7243, COMPLETE_SHA),
    'HEADER.json': (5231, 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'),
    'NEW_ARCHIVE_VERIFIED.json': (1718, ORIGINAL_VERIFICATION_SHA),
    'PRIOR_REFERENCES.json': (107952, '58987ac07e18cf5be1cb88902345e557ca14ee1a6e91a55fb34f1fa2a817fcec'),
    'RECEIVE_RESULT.json': (2359, 'b473e8a3a15af0c74d0d2de6681f25878070ba2f33a25ee65856d5a79337e3c2'),
    'RETIREMENT_PREDELETE.json': (10864, '4990f5818663f85f12e4efc71db26e635f5c2bb93278199a8a1dfb442ce027b0'),
    'RETIREMENT_RESULT.json': (12564, RETIREMENT_SHA),
    'SOURCE_REVERIFIED.json': (6145, SOURCE_SHA),
    'entries.jsonl.gz': (15884473, '84eb7dc3280106120c54fe731a23b196b583bff45d85a8db0d79ab861f298bfe'),
    'new-payloads.jsonl.gz': (4419157, '8c57a12eb797bcb6116e71a417dbe2788f774632fba91d6ef90cd0cdd252136a'),
    'oracle_receiver_verify.py': (14047, '597683bca42bf9b4b82ff173f3a991c15b9cba949a8e749d45301bbad0353710'),
    'session_pair.py': (18331, '5e1f6d9f7f5a56abda50f3cdc76170fa3e4ca78d4d1d7a2ce7db7a5d8f427948'),
}


def require_actual_binding():
    if not isinstance(RECEIPT_SHA, str) or len(RECEIPT_SHA) != 64 or type(RELEASE_ID) is not int:
        raise RuntimeError('UNBOUND DRAFT: actual completed readback receipt and asset IDs required')
    assert RELEASE_ID > 0 and len(bytes.fromhex(RECEIPT_SHA)) == 32
    for row in ASSETS.values():
        assert type(row['id']) is int and row['id'] > 0
        assert type(row['bytes']) is int and row['bytes'] > 0
        assert isinstance(row['sha256'], str) and len(bytes.fromhex(row['sha256'])) == 32
    assert len({x['id'] for x in ASSETS.values()}) == 3
    assert ASSETS[METADATA_NAME]['bytes'] <= METADATA_CAP
    assert ASSETS[MANIFEST_NAME]['bytes'] <= 1024 * 1024


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
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'uid': s.st_uid, 'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode),
            'nlink': s.st_nlink, 'mtime_ns': str(s.st_mtime_ns), 'ctime_ns': str(s.st_ctime_ns)}


def exact_xattrs(fd):
    return {name: base64.b64encode(os.getxattr(fd, name)).decode('ascii')
            for name in sorted(os.listxattr(fd))}


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
        assert before['bytes'] <= maximum
        raw = os.pread(fd, maximum + 1, 0)
        assert len(raw) == before['bytes'] and identity(os.fstat(fd)) == before
        return raw
    finally:
        os.close(fd)


def verify_receipt(raw):
    require_actual_binding()
    assert len(raw) == RECEIPT_BYTES and digest(raw) == RECEIPT_SHA
    value = json.loads(raw)  # Python retains all historical integers/string nanoseconds exactly.
    assert value['status'] == 'EXACT_PRIVATE_DIFFERENTIAL_AND_12_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINALS_RETAINED'
    assert value['repository'] == {'id': REPO_ID, 'full_name': REPO, 'private': True}
    assert value['releaseID'] == RELEASE_ID and value['tag'] == TAG and value['draft'] is True
    assert value['localRetirement'] is False and value['selfContained'] is False
    assert value['fullTreeRestorationVerified'] is False and value['windowsAccess'] is False
    assert value['newSDKBuilds'] == value['nativeRuns'] == 0
    assert value['sourceDirectory'] == str(SOURCE) and value['sourceParent'] == PARENT
    assert value['currentSourceFullHashesUnchanged'] is True and value['metadataMembersVerified'] == 12
    rows = {r['name']: r for r in value['assets']}
    assert len(value['assets']) == len(rows) == len(ASSETS) and set(rows) == set(ASSETS)
    for name, expected in ASSETS.items():
        row = rows[name]
        assert all(row[k] == expected[k] for k in ('id', 'bytes', 'sha256'))
        assert row['authenticatedFullReadback'] is True and row['exit'] == 0
        assert row['apiURL'] == 'https://api.github.com/repos/%s/releases/assets/%d' % (REPO, expected['id'])
    assert value['sourceIdentity']['bytes'] == ASSETS[LEAF]['bytes']
    verify_dependencies(value['unchangedExternalDependencies'])
    return value


def verify_transport_completion(proof):
    """Require the completed owned job AND its final publication marker.

    These small exact proofs travel in the restoration pointer. An intermediate
    readback receipt alone cannot satisfy this prerequisite.
    """
    assert isinstance(proof, dict) and set(proof) == set(TRANSPORT_COMPLETION)
    decoded = {}
    for label, pin in TRANSPORT_COMPLETION.items():
        row = proof[label]
        assert set(row) == set(pin) | {'base64'}
        assert all(row[key] == value for key, value in pin.items())
        raw = base64.b64decode(row['base64'], validate=True)
        assert len(raw) == pin['bytes'] and digest(raw) == pin['sha256']
        decoded[label] = json.loads(raw)
    terminal = decoded['terminal']
    assert terminal['ok'] is True
    job = terminal['job']
    assert job['id'] == 'job_429fd8747557' and job['host'] == 'host_299cf75f6b338ecd'
    assert job['tool'] == 'script_run' and job['status'] == 'succeeded'
    assert type(job['exit_code']) is int and job['exit_code'] == 0
    assert job['error'] is None and job['output_truncated'] is False
    original = {'path': str(CONTROL / RECEIPT_NAME), 'bytes': RECEIPT_BYTES, 'sha256': RECEIPT_SHA}
    journal = {'path': str(CONTROL / 'continuation-1' / RECEIPT_NAME),
               'bytes': RECEIPT_BYTES, 'sha256': RECEIPT_SHA}
    marker = decoded['publication']
    assert marker == {'originalReceipt': original, 'journalReceipt': journal,
        'failedOriginalAttemptUnchanged': True, 'localRetirement': False}
    return proof


def read_transport_completion(directory):
    proof = {}
    for label, pin in TRANSPORT_COMPLETION.items():
        raw = read_regular(directory / pin['name'])
        proof[label] = {**pin, 'base64': base64.b64encode(raw).decode('ascii')}
    return verify_transport_completion(proof)


def verify_dependencies(value):
    assert value['selfContained'] is False and value['fullTreeRestorePerformed'] is False
    assert value['baseVerificationPerformedNow'] is False and value['windowsCurrentlyOffline'] is True
    assert value['historicalCompleteReceiptSHA256'] == COMPLETE_SHA
    assert value['priorReferenceLedgerSHA256'] == EXPECTED_METADATA['PRIOR_REFERENCES.json'][1]
    assert value['priorPhysicalMembers'] == 426 and value['priorOriginalFileOccurrences'] == 2802
    declared, bound = value['baseArchives'], value['historicalArchiveBindings']
    assert len(declared) == len(bound) == 4
    assert {r['id'] for r in declared} == {r['id'] for r in bound} == set(BASES)
    for row in bound:
        size, sha, count = BASES[row['id']]
        original = next(r for r in declared if r['id'] == row['id'])
        assert row['archive_bytes'] == original['archive_bytes'] == size
        assert row['archive_sha256'] == original['archive_sha256'] == sha
        assert row['manifest_sha256'] == original['manifest_sha256']
        assert row['referenced_members'] == count
    return value


def verify_manifest(raw, receipt):
    assert len(raw) == ASSETS[MANIFEST_NAME]['bytes'] and digest(raw) == ASSETS[MANIFEST_NAME]['sha256']
    value = json.loads(raw)
    assert value['schema'] == 'otzaria.private-session-pair-differential-transport/1'
    assert value['sourceDirectory'] == str(SOURCE) and value['sourceParent'] == PARENT
    assert value['privateRepository'] == receipt['repository']
    assert value['originalArchive'] == {'name': LEAF, 'bytes': ASSETS[LEAF]['bytes'],
        'sha256': ASSETS[LEAF]['sha256'], 'identity': receipt['sourceIdentity'],
        'restoreMetadata': receipt['sourceRestoreMetadata']}
    bundle = value['metadataArchive']
    assert bundle['name'] == METADATA_NAME and bundle['bytes'] == ASSETS[METADATA_NAME]['bytes']
    assert bundle['sha256'] == ASSETS[METADATA_NAME]['sha256'] and bundle['all12RegularMembersVerified'] is True
    rows = {leaf_name(r['name']): r for r in value['metadataMembers']}
    assert len(value['metadataMembers']) == len(rows) == 12 and set(rows) == set(EXPECTED_METADATA)
    for name, row in rows.items():
        assert (row['bytes'], row['sha256']) == EXPECTED_METADATA[name]
        assert row['identity']['bytes'] == row['bytes'] and row['identity']['nlink'] == 1
        assert row['identity']['device'] == PARENT['device']
        assert isinstance(row['restoreMetadata']['xattrs'], dict)
    assert value['originalInventorySHA256'] == INVENTORY_SHA
    assert value['localRetirement'] is False and value['selfContained'] is False
    assert value['fullTreeRestore'] is False and value['windowsAccess'] is False
    assert verify_dependencies(value['unchangedExternalDependencies']) == receipt['unchangedExternalDependencies']
    return value


def verify_metadata_tar(path, manifest):
    wanted = {r['name']: r for r in manifest['metadataMembers']}
    seen, count, historical = set(), 0, {}
    with gzip.open(path, 'rb') as gz:
        with tarfile.open(fileobj=gz, mode='r|') as archive:
            for member in archive:
                assert member.isfile() and member.name in wanted and member.name not in seen
                row = wanted[member.name]
                assert member.size == row['bytes']
                assert member.mode == row['identity']['mode']
                assert member.uid == row['identity']['uid'] and member.gid == row['identity']['gid']
                h, size, verification = hashlib.sha256(), 0, bytearray()
                f = archive.extractfile(member)
                for block in iter(lambda: f.read(1024 * 1024), b''):
                    size += len(block); count += len(block)
                    assert size <= row['bytes'] and count <= METADATA_CAP
                    h.update(block)
                    if member.name in ('HEADER.json', 'NEW_ARCHIVE_VERIFIED.json',
                                       'COMPLETE_PRESERVATION_VERIFIED.json', 'SOURCE_REVERIFIED.json',
                                       'RETIREMENT_RESULT.json', 'PRIOR_REFERENCES.json'):
                        assert size <= 1024 * 1024
                        verification.extend(block)
                assert size == row['bytes'] and h.hexdigest() == row['sha256']
                if verification:
                    historical[member.name] = json.loads(verification)
                seen.add(member.name)
        assert not gz.read(1024 * 1024).strip(b'\0') and gz.read(1) == b''
    assert seen == set(wanted)
    new = historical['NEW_ARCHIVE_VERIFIED.json']
    complete = historical['COMPLETE_PRESERVATION_VERIFIED.json']
    header = historical['HEADER.json']
    source = historical['SOURCE_REVERIFIED.json']
    retired = historical['RETIREMENT_RESULT.json']
    prior = historical['PRIOR_REFERENCES.json']
    assert new['archive_bytes'] == complete['new_archive_bytes'] == ASSETS[LEAF]['bytes']
    assert new['archive_sha256'] == complete['new_archive_sha256'] == source['new_archive_sha256'] == ASSETS[LEAF]['sha256']
    assert new['members_verified'] == 58125 and new['new_payloads_verified'] == 58121
    assert complete['new_archive_verification_sha256'] == ORIGINAL_VERIFICATION_SHA
    assert source['complete_preservation_receipt_sha256'] == retired['complete_preservation_sha256'] == COMPLETE_SHA
    assert retired['source_reverified_sha256'] == SOURCE_SHA and retired['full_absence_verified'] is True
    assert len(prior['references']) == complete['prior_members_verified'] == 426
    deps = manifest['unchangedExternalDependencies']
    assert header['base_archives'] == prior['base_archives'] == deps['baseArchives']
    assert complete['archive_bindings'] == retired['current_archive_bindings']['archive_bindings'] == deps['historicalArchiveBindings']
    return {'regularMembers': len(seen), 'payloadBytes': count, 'allMemberBytesVerified': True,
            'extractedFiles': 0, 'selfContained': False, 'windowsAccess': False,
            'historicalBaseBindingsPreserved': 4, 'newBaseVerification': False}


def verify_siblings(parent_fd, manifest, *, archive_present, extra=()):
    rows = {r['name']: r for r in manifest['metadataMembers']}
    expected = set(rows) | ({LEAF} if archive_present else set()) | set(extra)
    assert set(os.listdir(parent_fd)) == expected, 'Exact protected sibling path set changed'
    result = []
    for name in sorted(rows):
        fd = open_leaf(parent_fd, name)
        try:
            before = identity(os.fstat(fd))
            assert before == rows[name]['identity'], name
            assert exact_xattrs(fd) == rows[name]['restoreMetadata']['xattrs'], name
            assert hash_fd(fd, rows[name]['bytes']) == rows[name]['sha256'], name
            assert identity(os.fstat(fd)) == before
            assert exact_xattrs(fd) == rows[name]['restoreMetadata']['xattrs'], name
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


def owned_process_identity(pid):
    raw = Path('/proc/%d/stat' % pid).read_text()
    fields = raw[raw.rfind(')') + 2:].split()
    return {'pid': pid, 'pgid': int(fields[2]), 'session': int(fields[3]), 'startTicks': fields[19]}


def stop_owned(process, original):
    # A Popen leader which has not been reaped cannot have its PID reused.
    # Never signal a group after wait() has set returncode.
    if process.returncode is not None:
        return
    current = owned_process_identity(process.pid)
    assert current['pgid'] == current['session'] == process.pid
    assert original is None or current == original
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        current = owned_process_identity(process.pid)
        assert current['pgid'] == current['session'] == process.pid
        assert original is None or current == original
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=20)


class Journal:
    """One exclusive bounded rootfs attempt; no DATA archive staging here."""
    def __init__(self, operation, attempt, existing=False):
        require_actual_binding()
        assert operation in ('restore', 'retire') and str(uuid.UUID(attempt)) == attempt
        parent = open_directory(CONTROL)
        self.name = operation + '-' + attempt
        self.path = CONTROL / self.name
        self.sequence = 0
        self.deadline = time.monotonic() + 2700
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
        assert time.monotonic() < self.deadline, 'Overall bounded preservation deadline'
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
        selector = None
        started = time.monotonic()
        start_identity = None
        captured, errors = bytearray(), bytearray()
        h, count = hashlib.sha256(), 0
        argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', *args]
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        try:
            start_identity = owned_process_identity(process.pid)
            assert start_identity['pgid'] == start_identity['session'] == process.pid
            self.write(label + '.PROCESS.json', {'identity': start_identity, 'argv': argv, 'utc': utc()})
            selector = selectors.DefaultSelector()
            for channel, pipe in [('stdout', process.stdout), ('stderr', process.stderr)]:
                os.set_blocking(pipe.fileno(), False)
                selector.register(pipe.fileno(), selectors.EVENT_READ, channel)
            until = min(started + timeout, self.deadline)
            while selector.get_map():
                self.guard()
                assert time.monotonic() < until, 'Owned authenticated transfer deadline'
                for key, _ in selector.select(timeout=0.25):
                    try:
                        block = os.read(key.fd, 1024 * 1024)
                    except BlockingIOError:
                        continue
                    if not block:
                        selector.unregister(key.fd)
                        continue
                    if key.data == 'stderr':
                        assert len(errors) + len(block) <= 1024 * 1024, 'Bounded stderr exceeded'
                        errors.extend(block)
                        continue
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
                        assert len(captured) + len(block) <= 1024 * 1024
                        captured.extend(block)
            code = process.wait(timeout=max(0.01, min(20, until - time.monotonic())))
            assert code == 0, 'Authenticated transfer failed; no automatic retry'
            if expected:
                assert count == expected['bytes'] and h.hexdigest() == expected['sha256']
            if output_fd is not None:
                os.fsync(output_fd)
            result = {'bytes': count, 'sha256': h.hexdigest(), 'exit': code, 'seconds': time.monotonic() - started}
            self.write(label + '.RESULT.json', result)
            return bytes(captured) if expected is None else result
        finally:
            try:
                stop_owned(process, start_identity)
            finally:
                if selector is not None:
                    selector.close()
                process.stdout.close()
                process.stderr.close()
                try:
                    v = os.fstatvfs(self.fd)
                    if v.f_bavail * v.f_frsize - len(captured) - len(errors) >= ROOT_FLOOR:
                        self.write(label + '.stdout', bytes(captured))
                        self.write(label + '.stderr', bytes(errors))
                finally:
                    self.write(label + '.TERMINAL.json', {'utc': utc(), 'identity': start_identity,
                        'pid': process.pid, 'returncode': process.returncode,
                        'stdoutBytes': count, 'stdoutSHA256': h.hexdigest(),
                        'stderrBytes': len(errors), 'stderrSHA256': digest(errors),
                        'noAutomaticRetry': True}, terminal=True)


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
    require_actual_binding()  # Ordinary unbound-draft refusal before any file read.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', action='store_true', required=True)
    parser.add_argument('--pointer', type=Path, required=True)
    parser.add_argument('--pointer-sha256', required=True)
    parser.add_argument('--attempt', required=True, help='Fresh canonical UUID, not an existing attempt')
    args = parser.parse_args()
    raw = read_regular(args.pointer)
    assert digest(raw) == args.pointer_sha256 and len(args.pointer_sha256) == 64
    pointer = json.loads(raw)
    assert pointer['schema'] == 'otzaria.one-session-pair-differential-restoration-pointer.v1'
    assert pointer['sourceDirectory'] == str(SOURCE) and pointer['leaf'] == LEAF and pointer['parent'] == PARENT
    assert pointer['assets'] == ASSETS and pointer['receiptSHA256'] == RECEIPT_SHA
    assert pointer['restorationScriptSHA256'] == digest(read_regular(Path(__file__)))
    receipt = verify_receipt(base64.b64decode(pointer['receiptBase64'], validate=True))
    verify_transport_completion(pointer['transportCompletion'])
    assert pointer['unchangedExternalDependencies'] == receipt['unchangedExternalDependencies']
    assert pointer['selfContained'] is False and pointer['fullTreeRestoration'] is False
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
        temporary = '.session-pair-differential-restore-' + args.attempt + '.partial'
        output_fd = os.open(temporary, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent_fd)
        os.fsync(parent_fd)
        def data_guard(amount):
            s = os.fstatvfs(parent_fd)
            assert s.f_bavail * s.f_frsize - amount >= DATA_FLOOR, 'Restoration Data floor'
        result = download(journal, LEAF, output_fd, data_guard)
        before = identity(os.fstat(output_fd))
        assert before['bytes'] == ASSETS[LEAF]['bytes'] and hash_fd(output_fd, before['bytes']) == ASSETS[LEAF]['sha256']
        assert identity(os.fstat(output_fd)) == before
        assert verify_siblings(parent_fd, manifest, archive_present=False, extra=(temporary,)) == protected
        assert parent_identity(parent_fd) == PARENT
        restore_metadata(output_fd, pointer['leafRestoreMetadata'])
        ready = identity(os.fstat(output_fd))
        assert identity(os.stat(temporary, dir_fd=parent_fd, follow_symlinks=False)) == ready
        assert ready['bytes'] == ASSETS[LEAF]['bytes']
        # Exclusive hard-link publication cannot replace an existing leaf.
        # Fsync the final directory entry before removing only our partial alias.
        os.link(temporary, LEAF, src_dir_fd=parent_fd, dst_dir_fd=parent_fd, follow_symlinks=False)
        linked = True; os.fsync(parent_fd)
        os.unlink(temporary, dir_fd=parent_fd); os.fsync(parent_fd)
        final = identity(os.fstat(output_fd))
        assert identity(os.stat(LEAF, dir_fd=parent_fd, follow_symlinks=False)) == final
        assert final['bytes'] == ASSETS[LEAF]['bytes']
        assert verify_siblings(parent_fd, manifest, archive_present=True) == protected
        journal.write('RESTORED.json', {'status': 'EXACT_OPAQUE_DIFFERENTIAL_RESTORED_NO_TREE_EXTRACTION', 'utc': utc(),
            'archive': str(SOURCE / LEAF), 'payload': result, 'identity': final,
            'metadataRestored': pointer['leafRestoreMetadata'], 'originalCtimeAndInodeNotRestorable': True,
            'protectedSiblings': len(protected), 'newSDKBuilds': 0, 'nativeRuns': 0,
            'selfContained': False, 'fullTreeRestoration': False, 'windowsAccess': False,
            'unchangedExternalDependencies': receipt['unchangedExternalDependencies']}, terminal=True)
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
