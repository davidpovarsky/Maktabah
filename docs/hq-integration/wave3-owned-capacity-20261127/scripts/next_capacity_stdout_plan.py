#!/usr/bin/env python3
"""Read-only content coverage and kernel private-allocation plan. No removal."""
from pathlib import Path
import ctypes
import datetime
import hashlib
import heapq
import json
import os
import resource
import shutil
import stat
import struct
import tempfile
import time

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ARCHIVES = [
    ('app-generated', BASE / 'wave3-app-generated-cache-preservation-20261127.6acrz1dj/MEMBER_MANIFEST.json',
     '5e6fd1ffe65b62333b6543d4b8d189109b56ae66f0d12bfda334aa11db424518', 'entries', 47372, 0),
    ('old-sdk-producer', BASE / 'wave3-interrupted-sdk-work-preservation-20261127.811pvzsd/MEMBER_MANIFEST.json',
     '558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94', 'entries', 138339, 0),
    ('fresh-sdk-differential', Path('/Users/m1/builds/otzaria-wave3-fresh-producer-preservation-20261127.hhz749_k/MANIFEST.json'),
     'd47acc0b42ed579d076355901595b66c2b4548a391ae906d27b48a3b210686bb', 'new_payloads', 121147, 22521),
    ('qualified-snapshot-differential', Path('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6/MANIFEST.json'),
     '70a15c1afa2456d9dea9f11191df0561f08d766211360c60a5039feca632d660', 'new_payloads', 65204, 3973),
]
HELD_INODES = {65257836, 60649716, 60745183}
HELD_SIZES = {73643232, 73571512}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''):
            h.update(b)
    return h.hexdigest()


class Stream:
    def __init__(self, f):
        self.f = f
        self.buffer = ''
        self.position = 0
        self.eof = False
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
                # A number at a chunk boundary is not complete without lookahead.
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


class Attr(ctypes.Structure):
    _fields_ = [('count', ctypes.c_uint16), ('reserved', ctypes.c_uint16),
                ('common', ctypes.c_uint32), ('vol', ctypes.c_uint32),
                ('directory', ctypes.c_uint32), ('file', ctypes.c_uint32), ('fork', ctypes.c_uint32)]


LIB = ctypes.CDLL(None, use_errno=True)
LIB.getattrlist.argtypes = [ctypes.c_char_p, ctypes.POINTER(Attr), ctypes.c_void_p,
                            ctypes.c_size_t, ctypes.c_ulong]
LIB.getattrlist.restype = ctypes.c_int


def private_allocation(path):
    a = Attr(5, 0, 0x80000000, 0, 0, 0, 0x1108)
    b = ctypes.create_string_buffer(128)
    ctypes.set_errno(0)
    rc = LIB.getattrlist(os.fsencode(path), ctypes.byref(a), b, len(b), 0x21)
    assert rc == 0, (str(path), ctypes.get_errno())
    length = struct.unpack_from('=I', b.raw, 0)[0]
    returned = struct.unpack_from('=IIIII', b.raw, 4)
    assert length == 44 and returned == (0x80000000, 0, 0, 0, 0x1108)
    private, clone, references = struct.unpack_from('=qQI', b.raw, 24)
    assert private >= 0
    return private, clone, references


def identity(s):
    return (s.st_dev, s.st_ino, s.st_mode, s.st_size, s.st_mtime_ns, s.st_ctime_ns, s.st_nlink)


def group_name(scope, relative):
    parts = relative.parts
    if 'build' in parts:
        i = parts.index('build')
        return scope + '/' + '/'.join(parts[:min(len(parts) - 1, i + 4)])
    return scope + '/' + '/'.join(parts[:min(len(parts) - 1, 2)])


def main():
    started = time.monotonic()
    evidence = None
    free_before = shutil.disk_usage('/System/Volumes/Data').free
    content = {}
    pins = []
    inode_hits = []
    size_hits = []
    for archive_id, path, expected, physical_array, expected_entries, expected_new in ARCHIVES:
        before = path.stat()
        assert digest(path) == expected
        counts = {'entries': 0, 'new_payloads': 0}
        with path.open(encoding='utf-8') as f:
            for key, row in Stream(f).arrays():
                counts[key] += 1
                if key == 'entries' and row.get('inode') in HELD_INODES:
                    inode_hits.append({'archive_id': archive_id, **{k: row.get(k) for k in (
                        'path', 'type', 'bytes', 'sha256', 'inode', 'device', 'mtime_ns', 'ctime_ns', 'payload')}})
                if key == 'entries' and row.get('bytes') in HELD_SIZES and row.get('type') == 'file':
                    size_hits.append({'archive_id': archive_id, **{k: row.get(k) for k in (
                        'path', 'bytes', 'sha256', 'inode', 'device', 'mtime_ns', 'ctime_ns', 'payload')}})
                if key != physical_array or (key == 'entries' and row.get('type') != 'file'):
                    continue
                sha = row['sha256']
                assert len(sha) == 64
                member = row['path'] if key == 'entries' else row['member']
                content.setdefault((bytes.fromhex(sha), row['bytes']), (archive_id, member))
        assert counts == {'entries': expected_entries, 'new_payloads': expected_new}, (archive_id, counts)
        assert identity(before) == identity(path.stat())
        pins.append({'id': archive_id, 'manifest': str(path), 'sha256': expected, 'counts': counts})

    scopes = [('compact-Maktabah', BASE / 'compact-reader-preview-worktree.5hRb5SYt/Maktabah'),
              ('paired-release', BASE / 'actual-paired-production-release.Hguhbz1S')]
    scopes += [(p.name, p) for p in sorted(BASE.glob('session.*')) if p.is_dir()]
    groups = {}
    seen = set()
    uncovered = {}
    largest = []
    inventory = hashlib.sha256()
    source_changes = []
    scan_errors = []
    for scope, root in scopes:
        assert root.resolve() == root and not root.is_symlink()
        for directory, directories, files in os.walk(root, followlinks=False,
                onerror=lambda error: scan_errors.append(str(error))):
            directories.sort()
            for name in sorted(files):
                p = Path(directory) / name
                before = p.lstat()
                if not stat.S_ISREG(before.st_mode):
                    continue
                group = group_name(scope, p.relative_to(root))
                g = groups.setdefault(group, dict(files=0, logical_bytes=0, allocated_bytes_including_clones=0,
                    distinct_inode_files=0, kernel_private_bytes=0, shared_clone_files=0, hardlinked_files=0, covered_files=0,
                    covered_logical_bytes=0, uncovered_files=0, uncovered_logical_bytes=0, covered_private_bytes=0,
                    uncovered_private_bytes=0))
                private, clone, refs = private_allocation(p)
                sha = digest(p)
                after = p.lstat()
                if identity(before) != identity(after):
                    source_changes.append(str(p))
                key = (bytes.fromhex(sha), before.st_size)
                covered = content.get(key)
                inode = (before.st_dev, before.st_ino)
                distinct = inode not in seen
                seen.add(inode)
                g['files'] += 1
                g['logical_bytes'] += before.st_size
                g['allocated_bytes_including_clones'] += before.st_blocks * 512
                g['distinct_inode_files'] += int(distinct)
                eligible_private = private if distinct and before.st_nlink == 1 else 0
                g['kernel_private_bytes'] += eligible_private
                g['shared_clone_files'] += int(refs > 1)
                g['hardlinked_files'] += int(before.st_nlink > 1)
                g['covered_files' if covered else 'uncovered_files'] += 1
                g['covered_logical_bytes' if covered else 'uncovered_logical_bytes'] += before.st_size
                g['covered_private_bytes' if covered else 'uncovered_private_bytes'] += eligible_private
                if not covered:
                    uncovered.setdefault(key, str(p))
                row = {'path': str(p), 'bytes': before.st_size, 'allocated_bytes': before.st_blocks * 512,
                       'private_bytes': private, 'clone_id': clone, 'clone_refcount': refs,
                       'inode': before.st_ino, 'device': before.st_dev, 'nlink': before.st_nlink, 'mtime_ns': before.st_mtime_ns,
                       'ctime_ns': before.st_ctime_ns, 'sha256': sha,
                       'existing_reference': {'archive_id': covered[0], 'member': covered[1]} if covered else None}
                inventory.update((json.dumps(row, sort_keys=True, separators=(',', ':')) + '\n').encode())
                item = (private, str(p), row)
                if len(largest) < 80:
                    heapq.heappush(largest, item)
                elif item[:2] > largest[0][:2]:
                    heapq.heapreplace(largest, item)
    totals = {k: sum(g[k] for g in groups.values()) for k in next(iter(groups.values()))}
    result = {'status': 'READ_ONLY_CONTENT_COVERAGE_AND_KERNEL_PRIVATE_ALLOCATION_NOT_PRESERVATION',
              'utc': utc(), 'evidence': None, 'output_mode': 'SSH_STDOUT_TO_WINDOWS_NO_MAC_WRITE', 'free_before': free_before,
              'source_scopes': [{'label': label, 'root': str(root)} for label, root in scopes],
              'verified_manifest_pins': pins, 'existing_distinct_payloads': len(content),
              'inventory_stream_sha256': inventory.hexdigest(), 'totals': totals,
              'new_unique_payloads': len(uncovered), 'new_unique_raw_bytes': sum(k[1] for k in uncovered),
              'groups': groups, 'largest_kernel_private_files': [x[2] for x in sorted(largest, reverse=True)],
              'held_deleted_inode_matches': inode_hits, 'held_deleted_size_only_matches_not_identity_proof': size_hits,
              'source_changed_during_hash': source_changes,
              'scan_errors': scan_errors,
              'free_after': shutil.disk_usage('/System/Volumes/Data').free,
              'peak_rss_bytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
              'seconds': time.monotonic() - started, 'anything_deleted': False,
              'limits': ['Content coverage only; full metadata preservation is still required before any future retirement.',
                         'Private bytes are per-file kernel observations, not a promise of concurrent whole-tree df reclaim.',
                         'Private-byte totals conservatively exclude all multiply-linked files.',
                         'Already shared clone blocks can become private later; whole-tree deletion may release more.',
                         'No SDK cache qualification, active-work release, or new deletion permission follows from this plan.']}
    print(json.dumps(result, sort_keys=True, separators=(',', ':')))


if __name__ == '__main__':
    main()
