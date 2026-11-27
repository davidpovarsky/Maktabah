#!/usr/bin/env python3
"""Preserve/retire only two explicitly authorized roots; no Mac disk writes.

Inventory and retirement receipts go over SSH stdout. Before deletion, the
Windows receiver must durably store the complete pre-delete record and ACK its
exact SHA. No PID is stopped, and no source/SDK gate is modified.
"""
from pathlib import Path
import base64
import concurrent.futures
import datetime
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import time
import types

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ROOTS = (
    BASE / 'actual-paired-production-release.Hguhbz1S/Maktabah/build/hq-stage2/inputs',
    BASE / 'compact-reader-preview-worktree.5hRb5SYt/Maktabah/build/DerivedData/Build/Products',
)
LABELS = ('paired-release-inputs', 'compact-debug-products')
EXPECTED_FILES = (12, 1864)
EXPECTED_BYTES = (1110270440, 1650035396)
HELPER = Path('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6/qualified_preservation.py')
HELPER_SHA = 'f07264ccf70a75f9b74566d24f65cfdcd6e832e5f3b09231cb6311afae06749e'
PLAN_SHA = '597f831d8cc62764c290f0e55eae50007945d1c2a760cb6c91b147ab7ee79a20'
ARCHIVES = (
    ('app-generated', BASE / 'wave3-app-generated-cache-preservation-20261127.6acrz1dj/MEMBER_MANIFEST.json',
     '5e6fd1ffe65b62333b6543d4b8d189109b56ae66f0d12bfda334aa11db424518', 'entries', 47372, 0,
     '36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb', 1699905882),
    ('old-sdk-producer', BASE / 'wave3-interrupted-sdk-work-preservation-20261127.811pvzsd/MEMBER_MANIFEST.json',
     '558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94', 'entries', 138339, 0,
     '2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda', 5238640114),
    ('fresh-sdk-differential', Path('/Users/m1/builds/otzaria-wave3-fresh-producer-preservation-20261127.hhz749_k/MANIFEST.json'),
     'd47acc0b42ed579d076355901595b66c2b4548a391ae906d27b48a3b210686bb', 'new_payloads', 121147, 22521,
     '3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee', 944883233),
    ('qualified-snapshot-differential', Path('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6/MANIFEST.json'),
     '70a15c1afa2456d9dea9f11191df0561f08d766211360c60a5039feca632d660', 'new_payloads', 65204, 3973,
     'f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b', 1291853917),
)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''):
            h.update(b)
    return h.hexdigest()


def free():
    return shutil.disk_usage('/System/Volumes/Data').free


class Stream:
    """Bounded JSON array reader, also used for the verified prior manifests."""
    def __init__(self, f):
        self.f, self.buffer, self.position, self.eof = f, '', 0, False
        self.decoder = json.JSONDecoder()

    def fill(self):
        self.buffer = self.buffer[self.position:]
        self.position = 0
        chunk = self.f.read(65536)
        self.eof = not chunk
        self.buffer += chunk

    def peek(self):
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace():
                self.position += 1
            if self.position < len(self.buffer):
                return self.buffer[self.position]
            if self.eof:
                return None
            self.fill()

    def take(self, character):
        assert self.peek() == character
        self.position += 1

    def value(self):
        assert self.peek() is not None
        while True:
            try:
                value, end = self.decoder.raw_decode(self.buffer, self.position)
                if end == len(self.buffer) and not self.eof:
                    self.fill()
                    continue
                self.position = end
                return value
            except json.JSONDecodeError:
                if self.eof:
                    raise
                self.fill()

    def arrays(self):
        self.take('{')
        while self.peek() != '}':
            key = self.value()
            self.take(':')
            if key in ('entries', 'new_payloads'):
                self.take('[')
                while self.peek() != ']':
                    yield key, self.value()
                    if self.peek() == ',':
                        self.take(',')
                    else:
                        break
                self.take(']')
            else:
                self.value()
            if self.peek() == ',':
                self.take(',')
            else:
                break
        self.take('}')
        assert self.peek() is None


def helper():
    data = HELPER.read_bytes()
    assert hashlib.sha256(data).hexdigest() == HELPER_SHA
    module = types.ModuleType('pinned_readonly_preservation_helper')
    module.__file__ = str(HELPER)
    exec(compile(data, str(HELPER), 'exec'), module.__dict__)
    return module


def root_stat(root):
    assert root in ROOTS and root.resolve() == root and not root.is_symlink()
    s = root.lstat()
    assert stat.S_ISDIR(s.st_mode) and s.st_uid == os.getuid()
    return s


def paths(root):
    initial = root_stat(root)
    pending, result = [root], []
    while pending:
        p = pending.pop()
        s = p.lstat()
        assert s.st_dev == initial.st_dev
        assert stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode) or stat.S_ISLNK(s.st_mode)
        result.append((p, s))
        if stat.S_ISDIR(s.st_mode):
            with os.scandir(p) as children:
                pending.extend(Path(x.path) for x in children)
    return sorted(result, key=lambda x: os.fsencode(str(x[0])))


def scan(h, root):
    h.ROOT = root
    before = paths(root)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        entries = list(pool.map(h.entry, before))
    after = paths(root)
    assert [str(p) for p, _ in before] == [str(p) for p, _ in after]
    assert all(h.identity(a) == h.identity(b) for (_, a), (_, b) in zip(before, after))
    return entries


def no_use():
    p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], capture_output=True, text=True)
    assert p.returncode in (0, 1)
    matches, pid, command, fd = [], None, None, None
    for line in p.stdout.splitlines():
        if line.startswith('p'): pid = line[1:]
        elif line.startswith('c'): command = line[1:]
        elif line.startswith('f'): fd = line[1:]
        elif line.startswith('n') and any(line[1:] == str(root) or line[1:].startswith(str(root) + '/') for root in ROOTS):
            matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': line[1:]})
    ps = subprocess.check_output(['/bin/ps', '-axo', 'pid=,ppid=,comm=,args='], text=True)
    # Only exact target references are retained. This process/SSH transport may
    # include the literal program; neither is an external owner of target data.
    refs = [line for line in ps.splitlines() if any(str(root) in line for root in ROOTS)
            and int(line.split(None, 1)[0]) not in (os.getpid(), os.getppid())]
    result = {'utc': utc(), 'lsof_exit': p.returncode, 'lsof_stderr': p.stderr,
              'open_paths': matches, 'process_references': refs}
    assert not matches and not refs, json.dumps(result)
    return result


def stat_record(path, hash_file=False):
    s = path.lstat()
    result = {'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
              'uid': s.st_uid, 'gid': s.st_gid, 'bytes': s.st_size,
              'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns, 'flags': s.st_flags}
    if stat.S_ISLNK(s.st_mode): result['target'] = os.readlink(path)
    elif hash_file and stat.S_ISREG(s.st_mode): result['sha256'] = digest(path)
    return result


def parent_identity(root):
    assert root.parent.resolve() == root.parent and not root.parent.is_symlink()
    value = stat_record(root.parent)
    return {k: value[k] for k in ('device', 'inode', 'mode', 'uid', 'gid', 'flags')}


def protected():
    selected = set()
    workspaces = (BASE / 'actual-paired-production-release.Hguhbz1S/Maktabah',
                  BASE / 'compact-reader-preview-worktree.5hRb5SYt/Maktabah')
    for root in ROOTS:
        selected.update(p for p in root.parent.iterdir() if p != root)
    heads = {}
    for workspace in workspaces:
        assert workspace.resolve() == workspace and workspace.is_dir()
        selected.update(workspace.iterdir())
        for relative in ('Maktabah.xcodeproj/project.pbxproj',
                         'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
                         'Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved', 'Source/Localizable.xcstrings'):
            p = workspace / relative
            if os.path.lexists(p): selected.add(p)
        git = ['git', '--no-optional-locks', '-C', str(workspace)]
        heads[str(workspace)] = {
            'head': subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip(),
            'tracked_status': subprocess.check_output(git + ['status', '--porcelain=v1', '--untracked-files=no'], text=True)}
    assert not any(p == root or root in p.parents for root in ROOTS for p in selected)
    return {'paths': {str(p): stat_record(p, True) for p in sorted(selected)}, 'workspaces': heads}


def inventory():
    start = time.monotonic()
    h = helper()
    result = {'schema': 'otzaria.two-covered-scopes/1', 'utc': utc(),
              'classification': 'PRESERVATION_ONLY_NOT_ACCEPTANCE_OR_SDK_QUALIFICATION',
              'roots': [str(p) for p in ROOTS], 'script_sha256': EXECUTED_SCRIPT_SHA256,
              'helper_sha256': HELPER_SHA, 'read_only_plan_sha256': PLAN_SHA,
              'free_before': free(), 'open_use_before': no_use(),
              'parent_identities': [parent_identity(root) for root in ROOTS],
              'protected_outside': protected(), 'scopes': [], 'archives': [], 'anything_deleted': False,
              'metadata_scope': 'Full POSIX identity/permissions/timestamps, exact Darwin birthtime/flags, no-follow ACL/xattrs including compression, symlink target bytes and hardlink groups. Historical inode/device/ctime are evidence, not restorable numeric guarantees.'}
    wanted = set()
    for index, root in enumerate(ROOTS):
        entries = scan(h, root)
        files = [x for x in entries if x['type'] == 'file']
        assert len(files) == EXPECTED_FILES[index]
        assert sum(x['bytes'] for x in files) == EXPECTED_BYTES[index]
        wanted.update((x['sha256'], x['bytes']) for x in files)
        result['scopes'].append({'label': LABELS[index], 'root': str(root), 'entries': entries})
    covered = {}
    for aid, path, expected, physical, count, new_count, archive_sha, archive_bytes in ARCHIVES:
        before = path.stat()
        assert digest(path) == expected
        counts = {'entries': 0, 'new_payloads': 0}
        with path.open(encoding='utf-8') as f:
            for key, row in Stream(f).arrays():
                counts[key] += 1
                if key != physical or (key == 'entries' and row.get('type') != 'file'): continue
                identity = (row['sha256'], row['bytes'])
                if identity in wanted:
                    covered.setdefault(identity, {'archive_id': aid, 'archive_sha256': archive_sha,
                                                   'member': row['path'] if physical == 'entries' else row['member']})
        assert counts == {'entries': count, 'new_payloads': new_count}
        assert h.identity(before) == h.identity(path.stat())
        result['archives'].append({'id': aid, 'manifest': str(path), 'manifest_sha256': expected,
                                   'archive_sha256': archive_sha, 'archive_bytes': archive_bytes, 'counts': counts})
    assert set(covered) == wanted, 'A current file lacks exact preserved payload coverage'
    for scope in result['scopes']:
        for row in scope['entries']:
            if row['type'] == 'file': row['payload'] = covered[(row['sha256'], row['bytes'])]
    result['open_use_after'] = no_use()
    assert protected() == result['protected_outside']
    assert [parent_identity(root) for root in ROOTS] == result['parent_identities']
    result['free_after'] = free()
    result['new_payload_bytes'] = 0
    result['seconds'] = time.monotonic() - start
    sys.stdout.buffer.write(canonical(result)); sys.stdout.buffer.flush()


def retire():
    envelope = json.loads(sys.stdin.buffer.readline(16 * 1024**2))
    manifest_bytes = base64.b64decode(envelope['manifest_base64'], validate=True)
    proof_bytes = base64.b64decode(envelope['proof_base64'], validate=True)
    assert hashlib.sha256(manifest_bytes).hexdigest() == envelope['manifest_sha256']
    assert hashlib.sha256(proof_bytes).hexdigest() == envelope['proof_sha256']
    manifest, proof = json.loads(manifest_bytes), json.loads(proof_bytes)
    assert manifest['roots'] == proof['roots'] == [str(p) for p in ROOTS]
    assert manifest['schema'] == 'otzaria.two-covered-scopes/1'
    assert manifest['helper_sha256'] == HELPER_SHA and manifest['script_sha256'] == EXECUTED_SCRIPT_SHA256
    assert manifest['read_only_plan_sha256'] == PLAN_SHA and manifest['new_payload_bytes'] == 0
    assert proof['status'] == 'COMPLETE_TWO_SCOPE_METADATA_AND_EXACT_PRIOR_PAYLOAD_REFERENCES_VERIFIED'
    assert proof['manifest_sha256'] == envelope['manifest_sha256']
    assert proof['all_metadata_preserved'] and proof['all_payload_references_verified']
    assert proof['new_payload_bytes'] == 0 and proof['metadata_archive_verified']
    expected_archives = {a[0]: (a[6], a[7], a[2]) for a in ARCHIVES}
    assert {a['id']: (a['archive_sha256'], a['archive_bytes'], a['manifest_sha256'])
            for a in proof['archive_bindings']} == expected_archives
    age = datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(proof['utc'])
    assert 0 <= age.total_seconds() <= 600, 'Off-host verification is no longer current'
    h = helper()
    outside = protected()
    assert outside == manifest['protected_outside']
    parents = [parent_identity(root) for root in ROOTS]
    assert parents == manifest['parent_identities']
    before_use = no_use()
    counts = []
    for root, scope in zip(ROOTS, manifest['scopes']):
        assert scope['root'] == str(root)
        entries = scan(h, root)
        assert [r['path'] for r in entries] == [r['path'] for r in scope['entries']]
        for actual, initial in zip(entries, scope['entries']):
            assert {k: v for k, v in actual.items() if k != 'atime_ns'} == {
                k: v for k, v in initial.items() if k not in ('atime_ns', 'payload')}, initial['path']
        counts.append(len(entries))
    after_use = no_use()
    assert protected() == outside and [parent_identity(root) for root in ROOTS] == parents
    receipt = {'status': 'TWO_EXACT_SCOPES_FULLY_REVERIFIED_AWAITING_DURABLE_ACK', 'utc': utc(),
               'roots': [str(p) for p in ROOTS], 'manifest_sha256': envelope['manifest_sha256'],
               'windows_proof_sha256': envelope['proof_sha256'], 'script_sha256': EXECUTED_SCRIPT_SHA256,
               'helper_sha256': HELPER_SHA, 'entries_reverified': counts,
               'archive_bindings': proof['archive_bindings'], 'metadata_archive': proof['metadata_archive'],
               'open_use_before': before_use, 'open_use_after': after_use,
               'protected_before': outside, 'parents_before': parents, 'free_before': free(),
               'authorization': 'Root authorized only the two fixed fully-covered scopes after complete preservation and fresh no-use verification.',
               'anything_deleted': False, 'native_acceptance': 0, 'sdk_retry': False}
    raw = canonical(receipt)
    sys.stdout.buffer.write(raw); sys.stdout.buffer.flush()
    ack = json.loads(sys.stdin.buffer.readline(4096))
    assert ack == {'ack': 'DURABLE_PREDELETE_RECORD', 'sha256': hashlib.sha256(raw).hexdigest(),
                   'manifest_sha256': envelope['manifest_sha256'], 'proof_sha256': envelope['proof_sha256']}
    assert no_use()['open_paths'] == []
    assert protected() == outside and [parent_identity(root) for root in ROOTS] == parents
    for root, scope in zip(ROOTS, manifest['scopes']):
        s = root_stat(root)
        assert s.st_ino == scope['entries'][0]['inode'] and s.st_dev == scope['entries'][0]['device']
    removed = []
    assert shutil.rmtree.avoids_symlink_attacks
    try:
        # The only destructive operations receive these two fixed constants.
        for root in ROOTS:
            shutil.rmtree(root)
            assert not os.path.lexists(root)
            removed.append(str(root))
        after = protected()
        receipt.update(status='RETIRED_ONLY_TWO_EXACT_FULLY_PRESERVED_SCOPES', finished_at=utc(),
                       removed=removed, anything_deleted=True, protected_after=after,
                       outside_paths_unchanged=(after == outside),
                       parent_identities_retained=([parent_identity(root) for root in ROOTS] == parents),
                       free_after=free(), predelete_receipt_sha256=hashlib.sha256(raw).hexdigest())
        receipt['observed_free_delta_bytes'] = receipt['free_after'] - receipt['free_before']
        receipt['delta_caveat'] = 'Concurrent df observation, not exclusive reclaimed allocation.'
        assert receipt['outside_paths_unchanged'] and receipt['parent_identities_retained']
    except Exception as error:
        receipt.update(status='EXACT_SCOPE_RETIREMENT_ERROR', finished_at=utc(), removed=removed,
                       anything_deleted=bool(removed), error=repr(error),
                       roots_still_exist=[os.path.lexists(p) for p in ROOTS], free_after=free())
        sys.stdout.buffer.write(canonical(receipt)); sys.stdout.buffer.flush()
        raise
    sys.stdout.buffer.write(canonical(receipt)); sys.stdout.buffer.flush()


if __name__ == '__main__':
    assert sys.argv[1:] in (['inventory'], ['retire'])
    if sys.argv[1] == 'inventory': inventory()
    else: retire()
