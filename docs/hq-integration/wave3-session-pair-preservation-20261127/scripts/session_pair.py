#!/usr/bin/env python3
"""Lossless preservation of two fixed inactive sessions. No deletion action.

Large metadata is streamed as gzip JSON Lines; payload bytes are streamed to
the already-authorized Oracle receiver. The Mac never stages a large tar.
"""
from pathlib import Path
import base64
import ctypes
import datetime
import gzip
import hashlib
import io
import json
import os
import resource
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
import types

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ROOTS = (BASE / 'session.ftqrs4Ju', BASE / 'session.e9xp5UCf')
EXPECTED_FILES = (79860, 79860)
EXPECTED_BYTES = (1917676802, 1917040783)
HELPER = Path('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6/qualified_preservation.py')
HELPER_SHA = 'f07264ccf70a75f9b74566d24f65cfdcd6e832e5f3b09231cb6311afae06749e'
PLAN_SHA = '597f831d8cc62764c290f0e55eae50007945d1c2a760cb6c91b147ab7ee79a20'
MAC_RESERVE = 2415919104
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


def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def canonical(value): return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): h.update(b)
    return h.hexdigest()


def capacity():
    free = shutil.disk_usage('/System/Volumes/Data').free
    assert free >= MAC_RESERVE, ('Mac live reserve', free)
    return free


def save(path, value):
    data = canonical(value)
    assert capacity() - len(data) >= MAC_RESERVE
    with path.open('xb') as f: f.write(data)


class Stream:
    def __init__(self, f):
        self.f, self.buffer, self.position, self.eof = f, '', 0, False
        self.decoder = json.JSONDecoder()
    def fill(self):
        self.buffer = self.buffer[self.position:]; self.position = 0
        chunk = self.f.read(65536); self.eof = not chunk; self.buffer += chunk
    def peek(self):
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace(): self.position += 1
            if self.position < len(self.buffer): return self.buffer[self.position]
            if self.eof: return None
            self.fill()
    def take(self, value):
        assert self.peek() == value; self.position += 1
    def value(self):
        assert self.peek() is not None
        while True:
            try:
                value, end = self.decoder.raw_decode(self.buffer, self.position)
                if end == len(self.buffer) and not self.eof: self.fill(); continue
                self.position = end; return value
            except json.JSONDecodeError:
                if self.eof: raise
                self.fill()
    def arrays(self):
        self.take('{')
        while self.peek() != '}':
            key = self.value(); self.take(':')
            if key in ('entries', 'new_payloads'):
                self.take('[')
                while self.peek() != ']':
                    yield key, self.value()
                    if self.peek() == ',': self.take(',')
                    else: break
                self.take(']')
            else: self.value()
            if self.peek() == ',': self.take(',')
            else: break
        self.take('}'); assert self.peek() is None


def helper():
    data = HELPER.read_bytes(); assert hashlib.sha256(data).hexdigest() == HELPER_SHA
    module = types.ModuleType('pinned_preservation_only_helper'); module.__file__ = str(HELPER)
    exec(compile(data, str(HELPER), 'exec'), module.__dict__)
    return module


def root_identity(root):
    assert root in ROOTS and root.resolve() == root and not root.is_symlink()
    s = root.lstat(); assert stat.S_ISDIR(s.st_mode) and s.st_uid == os.getuid()
    return {'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode, 'uid': s.st_uid, 'gid': s.st_gid}


def walk(root):
    device = root_identity(root)['device']
    pending = [root]
    while pending:
        p = pending.pop(); s = p.lstat()
        assert s.st_dev == device and (stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode) or stat.S_ISLNK(s.st_mode))
        yield p, s
        if stat.S_ISDIR(s.st_mode):
            with os.scandir(p) as it: children = sorted((Path(x.path) for x in it), key=os.fsencode, reverse=True)
            pending.extend(children)


def no_use():
    p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], capture_output=True, text=True)
    assert p.returncode in (0, 1)
    matches, pid, command, fd = [], None, None, None
    for line in p.stdout.splitlines():
        if line.startswith('p'): pid = line[1:]
        elif line.startswith('c'): command = line[1:]
        elif line.startswith('f'): fd = line[1:]
        elif line.startswith('n') and any(line[1:] == str(r) or line[1:].startswith(str(r) + '/') for r in ROOTS):
            matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': line[1:]})
    ps = subprocess.check_output(['/bin/ps', '-axo', 'pid=,ppid=,comm=,args='], text=True)
    references = [s for s in ps.splitlines() if any(str(r) in s for r in ROOTS)
                  and int(s.split(None, 1)[0]) not in (os.getpid(), os.getppid())]
    result = {'utc': utc(), 'lsof_exit': p.returncode, 'lsof_stderr': p.stderr,
              'open_paths': matches, 'process_references': references}
    assert not matches and not references, json.dumps(result)
    return result


def private_size(h, path):
    attrs = h.AttrList(5, 0, 0x80000000, 0, 0, 0, 0x1108)
    buffer = ctypes.create_string_buffer(128)
    assert h.LIB.getattrlist(os.fsencode(path), ctypes.byref(attrs), buffer, len(buffer), 0x21) == 0
    assert struct.unpack_from('=I', buffer.raw)[0] == 44
    assert struct.unpack_from('=IIIII', buffer.raw, 4) == (0x80000000, 0, 0, 0, 0x1108)
    value, clone, refs = struct.unpack_from('=qQI', buffer.raw, 24)
    assert value >= 0
    return {'private_bytes': value, 'clone_id': clone, 'clone_references': refs}


def source_heads():
    result = []
    for root in ROOTS:
        repo = root / 'runner/_work/Maktabah/Maktabah'
        git = ['git', '--no-optional-locks', '-C', str(repo)]
        result.append({'root': str(root), 'repository': str(repo),
                       'head': subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip(),
                       'tracked_status': subprocess.check_output(git + ['status', '--porcelain=v1', '--untracked-files=no'], text=True)})
    return result


def payload_index(h):
    index, pins = {}, []
    for aid, path, expected, physical, count, new_count, archive_sha, archive_bytes in ARCHIVES:
        before = path.stat(); assert digest(path) == expected
        counts = {'entries': 0, 'new_payloads': 0}
        with path.open(encoding='utf-8') as f:
            for kind, row in Stream(f).arrays():
                counts[kind] += 1
                if kind != physical or (kind == 'entries' and row.get('type') != 'file'): continue
                index.setdefault((bytes.fromhex(row['sha256']), row['bytes']),
                    (aid, row['path'] if kind == 'entries' else row['member'], archive_sha))
        assert counts == {'entries': count, 'new_payloads': new_count}
        assert h.identity(before) == h.identity(path.stat())
        pins.append({'id': aid, 'manifest': str(path), 'manifest_sha256': expected,
                     'archive_sha256': archive_sha, 'archive_bytes': archive_bytes, 'counts': counts})
    return index, pins


def stat_line(h, root, path, s):
    return canonical({'path': str(path.relative_to(root.parent)), 'identity': h.identity(s)})


def inventory():
    started = time.monotonic(); free_before = capacity()
    evidence = Path(tempfile.mkdtemp(prefix='otzaria-wave3-session-pair-preservation-20261127.', dir='/Users/m1/builds'))
    shutil.copyfile(__file__, evidence / 'session_pair.py')
    h = helper(); old, pins = payload_index(h)
    before_use = no_use(); heads = source_heads()
    entries_path = evidence / 'entries.jsonl.gz'; payload_path = evidence / 'new-payloads.jsonl.gz'
    unique = set(); new_raw = 0; entry_hash = hashlib.sha256(); payload_hash = hashlib.sha256()
    summaries = []; stat_hashes = []; entry_bytes = 0; payload_bytes = 0
    with entries_path.open('xb') as eraw, payload_path.open('xb') as praw:
        with gzip.GzipFile(fileobj=eraw, mode='wb', mtime=0) as entries, gzip.GzipFile(fileobj=praw, mode='wb', mtime=0) as payloads:
            for number, root in enumerate(ROOTS):
                h.ROOT = root; stat_hash = hashlib.sha256()
                summary = {'root': str(root), 'root_identity': root_identity(root), 'entries': 0,
                           'files': 0, 'directories': 0, 'symlinks': 0, 'logical_bytes': 0,
                           'kernel_private_bytes': 0, 'covered_files': 0, 'covered_bytes': 0,
                           'xattr_entries': 0, 'acl_entries': 0, 'hardlinked_files': 0}
                for p, s in walk(root):
                    stat_hash.update(stat_line(h, root, p, s)); row = h.entry((p, s)); row['scope'] = number
                    summary['entries'] += 1; summary['xattr_entries'] += bool(row['xattrs']); summary['acl_entries'] += row['acl'] is not None
                    if row['type'] == 'file':
                        summary['files'] += 1; summary['logical_bytes'] += row['bytes']
                        allocation = private_size(h, p); row['allocation_observation'] = allocation
                        if row['nlink'] == 1: summary['kernel_private_bytes'] += allocation['private_bytes']
                        else: summary['hardlinked_files'] += 1
                        key = (bytes.fromhex(row['sha256']), row['bytes'])
                        if key in old:
                            aid, member, archive_sha = old[key]
                            row['payload'] = {'kind': 'prior_member', 'archive_id': aid, 'archive_sha256': archive_sha, 'member': member}
                            summary['covered_files'] += 1; summary['covered_bytes'] += row['bytes']
                        else:
                            member = 'objects/sha256/' + row['sha256']
                            row['payload'] = {'kind': 'new_member', 'member': member}
                            if key not in unique:
                                unique.add(key); new_raw += row['bytes']
                                payload = {'member': member, 'scope': number, 'source_path': row['path'],
                                           'bytes': row['bytes'], 'sha256': row['sha256'], 'stat_identity': h.identity(s)}
                                b = canonical(payload); payloads.write(b); payload_hash.update(b); payload_bytes += len(b)
                    elif row['type'] == 'directory': summary['directories'] += 1
                    else: summary['symlinks'] += 1
                    b = canonical(row); entries.write(b); entry_hash.update(b); entry_bytes += len(b)
                    if summary['entries'] % 1024 == 0: capacity()
                assert summary['files'] == EXPECTED_FILES[number] and summary['logical_bytes'] == EXPECTED_BYTES[number]
                summaries.append(summary); stat_hashes.append(stat_hash.hexdigest())
    fresh_hashes = []
    for root in ROOTS:
        sha = hashlib.sha256()
        for p, s in walk(root): sha.update(stat_line(h, root, p, s))
        fresh_hashes.append(sha.hexdigest())
    assert fresh_hashes == stat_hashes
    assert heads == source_heads()
    after_use = no_use()
    metadata = []
    for path, raw_sha, raw_bytes in ((entries_path, entry_hash.hexdigest(), entry_bytes), (payload_path, payload_hash.hexdigest(), payload_bytes)):
        metadata.append({'name': path.name, 'bytes': path.stat().st_size, 'sha256': digest(path),
                         'uncompressed_bytes': raw_bytes, 'uncompressed_sha256': raw_sha})
    header = {'schema': 'otzaria.session-pair-preservation/1', 'utc': utc(), 'evidence': str(evidence),
              'source_roots': [str(p) for p in ROOTS], 'script_sha256': digest(__file__), 'helper_sha256': HELPER_SHA,
              'read_only_plan_sha256': PLAN_SHA, 'base_archives': pins, 'scopes': summaries,
              'metadata': metadata, 'stat_inventory_sha256': stat_hashes, 'source_heads': heads,
              'new_unique_payloads': len(unique), 'new_unique_raw_bytes': new_raw,
              'open_use_before': before_use, 'open_use_after': after_use, 'free_before': free_before,
              'free_after': capacity(), 'peak_rss_bytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              'seconds': time.monotonic() - started, 'anything_deleted': False,
              'retirement_authorized': False, 'native_acceptance': 0, 'new_sdk_qualification': False,
              'metadata_scope': 'Complete original per-entry POSIX/Darwin/no-follow ACL/xattr/symlink/hardlink metadata from the pinned helper, gzip JSON Lines. Historic inode/device/ctime are retained evidence.'}
    save(evidence / 'HEADER.json', header)
    print(json.dumps({'status': 'FULL_PAIR_INVENTORIED_NOT_ARCHIVED_NOT_RETIRED', 'evidence': str(evidence),
                      'header_sha256': digest(evidence / 'HEADER.json'), 'header_bytes': (evidence / 'HEADER.json').stat().st_size,
                      'summary': header}))


class HashingWriter:
    def __init__(self, output): self.output, self.sha, self.count = output, hashlib.sha256(), 0
    def write(self, data): self.output.write(data); self.sha.update(data); self.count += len(data); return len(data)
    def flush(self): self.output.flush()


class HashingReader:
    def __init__(self, source): self.source, self.sha, self.count = source, hashlib.sha256(), 0
    def read(self, size=-1):
        b = self.source.read(size); self.sha.update(b); self.count += len(b); return b


def load_header(evidence, expected):
    assert evidence.parent == Path('/Users/m1/builds') and evidence.name.startswith('otzaria-wave3-session-pair-preservation-20261127.')
    assert digest(evidence / 'HEADER.json') == expected
    header = json.loads((evidence / 'HEADER.json').read_bytes())
    assert header['source_roots'] == [str(p) for p in ROOTS]
    assert header['script_sha256'] == digest(__file__) and header['helper_sha256'] == HELPER_SHA
    for m in header['metadata']:
        p = evidence / m['name']; assert p.stat().st_size == m['bytes'] and digest(p) == m['sha256']
    return header


def stream(evidence, expected):
    header = load_header(evidence, expected); h = helper(); before_use = no_use(); capacity()
    writer = HashingWriter(sys.stdout.buffer); count = 0; total = 0
    with gzip.GzipFile(fileobj=writer, mode='wb', mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode='w|', format=tarfile.PAX_FORMAT) as tar:
            for name in ('HEADER.json', 'entries.jsonl.gz', 'new-payloads.jsonl.gz', 'session_pair.py'):
                p = evidence / name; data = p.read_bytes()
                info = tarfile.TarInfo(name); info.size = len(data); info.mode = 0o600
                tar.addfile(info, io.BytesIO(data))
            with gzip.open(evidence / 'new-payloads.jsonl.gz', 'rb') as payloads:
                for line in payloads:
                    row = json.loads(line); root = ROOTS[row['scope']]
                    p = root.parent / row['source_path']; assert root in p.parents and not p.is_symlink()
                    s = p.lstat(); assert list(h.identity(s)) == row['stat_identity']
                    fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
                    with os.fdopen(fd, 'rb') as f:
                        assert h.identity(os.fstat(f.fileno())) == h.identity(s)
                        reader = HashingReader(f); info = tarfile.TarInfo(row['member']); info.size = row['bytes']; info.mode = 0o600
                        tar.addfile(info, reader)
                        assert reader.count == row['bytes'] and reader.sha.hexdigest() == row['sha256']
                        assert h.identity(os.fstat(f.fileno())) == h.identity(s)
                    assert h.identity(p.lstat()) == h.identity(s)
                    count += 1; total += row['bytes']; capacity()
    writer.flush()
    assert count == header['new_unique_payloads'] and total == header['new_unique_raw_bytes']
    result = {'status': 'PAIR_DIFFERENTIAL_STREAMED_NOT_RETIRED', 'utc': utc(), 'evidence': str(evidence),
              'header_sha256': expected, 'archive_bytes': writer.count, 'archive_sha256': writer.sha.hexdigest(),
              'new_payloads': count, 'new_payload_bytes': total, 'open_use_before': before_use,
              'free_after': capacity(), 'anything_deleted': False}
    save(evidence / 'STREAM_RESULT.json', result)


if __name__ == '__main__':
    if len(sys.argv) == 1 or sys.argv[1:] == ['inventory']: inventory()
    elif len(sys.argv) == 4 and sys.argv[1] == 'stream': stream(Path(sys.argv[2]), sys.argv[3])
    else: raise SystemExit('Only inventory or stream of the two fixed roots is supported; no deletion action exists.')
