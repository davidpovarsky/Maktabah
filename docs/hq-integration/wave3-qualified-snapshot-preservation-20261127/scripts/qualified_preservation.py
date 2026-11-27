#!/usr/bin/env python3
"""Lossless backup of one fixed snapshot. This script has no deletion action."""
from pathlib import Path, PurePosixPath
import argparse
import base64
import concurrent.futures
import ctypes
import datetime
import errno
import gzip
import hashlib
import io
import json
import os
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import time

ROOT = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt/wave3-qualified-6935f7fd-20261127')
REFERENCE_PLAN = Path('/Users/m1/builds/otzaria-wave3-qualified-capacity-readonly-20261127.4ojqiqdg/REFERENCE_PLAN.json')
REFERENCE_SHA = 'ff591293df6c4c8965f4c085c5f3cd35d5b38751a8dd21a0122ec75cf6644f33'
RESERVE = 2 * 1024**3 + 256 * 1024**2
CHUNK = 1024**2


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def save(path, value):
    with Path(path).open('xb') as f:
        f.write(canonical(value))


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(CHUNK), b''):
            h.update(b)
    return h.hexdigest()


def guard_capacity():
    free = shutil.disk_usage('/System/Volumes/Data').free
    if free < RESERVE:
        raise RuntimeError('Mac live reserve: ' + str(free))
    return free


def identity(s):
    return (s.st_dev, s.st_ino, s.st_mode, s.st_uid, s.st_gid, s.st_nlink,
            s.st_size, s.st_mtime_ns, s.st_ctime_ns, s.st_flags)


class AttrList(ctypes.Structure):
    _fields_ = [('count', ctypes.c_uint16), ('reserved', ctypes.c_uint16),
                ('common', ctypes.c_uint32), ('vol', ctypes.c_uint32),
                ('dir', ctypes.c_uint32), ('file', ctypes.c_uint32), ('fork', ctypes.c_uint32)]


LIB = ctypes.CDLL(None, use_errno=True)
LIB.listxattr.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
LIB.listxattr.restype = ctypes.c_ssize_t
LIB.getxattr.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
LIB.getxattr.restype = ctypes.c_ssize_t
LIB.acl_get_link_np.argtypes = [ctypes.c_char_p, ctypes.c_int]
LIB.acl_get_link_np.restype = ctypes.c_void_p
LIB.acl_to_text.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ssize_t)]
LIB.acl_to_text.restype = ctypes.c_void_p
LIB.acl_free.argtypes = [ctypes.c_void_p]
LIB.acl_free.restype = ctypes.c_int
LIB.getattrlist.argtypes = [ctypes.c_char_p, ctypes.POINTER(AttrList), ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong]
LIB.getattrlist.restype = ctypes.c_int


def metadata(path, before):
    raw = os.fsencode(path)
    options = 0x0001 | 0x0020  # SDK27 XATTR_NOFOLLOW | XATTR_SHOWCOMPRESSION
    size = LIB.listxattr(raw, None, 0, options)
    if size < 0:
        raise OSError(ctypes.get_errno(), 'listxattr', str(path))
    names = ctypes.create_string_buffer(size)
    if LIB.listxattr(raw, names, size, options) != size:
        raise RuntimeError('Extended attributes changed: ' + str(path))
    xattrs = []
    for name in sorted(x for x in names.raw[:size].split(b'\0') if x):
        n = LIB.getxattr(raw, name, None, 0, 0, options)
        if n < 0:
            raise OSError(ctypes.get_errno(), 'getxattr', str(path))
        value = ctypes.create_string_buffer(n)
        if LIB.getxattr(raw, name, value, n, 0, options) != n:
            raise RuntimeError('Extended attribute changed: ' + str(path))
        b = value.raw[:n]
        xattrs.append({'name_base64': base64.b64encode(name).decode(),
                       'value_base64': base64.b64encode(b).decode(),
                       'bytes': n, 'sha256': hashlib.sha256(b).hexdigest()})
    ctypes.set_errno(0)
    acl = LIB.acl_get_link_np(raw, 0x00000100)  # ACL_TYPE_EXTENDED, no symlink follow
    acl_value = None
    if not acl:
        code = ctypes.get_errno()
        if code != errno.ENOENT or not os.path.lexists(path):
            raise OSError(code, 'acl_get_link_np', str(path))
    else:
        length = ctypes.c_ssize_t()
        text = LIB.acl_to_text(acl, ctypes.byref(length))
        try:
            if not text:
                raise OSError(ctypes.get_errno(), 'acl_to_text', str(path))
            b = ctypes.string_at(text, length.value)
            acl_value = {'text_base64': base64.b64encode(b).decode(),
                         'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()}
        finally:
            if text:
                LIB.acl_free(text)
            LIB.acl_free(acl)
    attrs = AttrList(5, 0, 0x00000200, 0, 0, 0, 0)  # ATTR_CMN_CRTIME
    birth_buffer = ctypes.create_string_buffer(64)
    if LIB.getattrlist(raw, ctypes.byref(attrs), birth_buffer, 64, 1) != 0:
        raise OSError(ctypes.get_errno(), 'getattrlist birthtime', str(path))
    assert struct.unpack_from('=I', birth_buffer.raw)[0] == 20
    birth = struct.unpack_from('=qq', birth_buffer.raw, 4)
    assert 0 <= birth[1] < 10**9 and abs(birth[0] - int(before.st_birthtime)) <= 1
    return {'xattrs': xattrs, 'acl': acl_value, 'birthtime_ns': birth[0] * 10**9 + birth[1]}




def exact_root():
    assert ROOT.resolve() == ROOT and not ROOT.is_symlink()
    s = ROOT.lstat()
    assert stat.S_ISDIR(s.st_mode) and s.st_uid == os.getuid()
    assert ROOT.name == 'wave3-qualified-6935f7fd-20261127'
    assert ROOT.parent.name == 'compact-reader-preview-worktree.5hRb5SYt'
    return s


def enumerate_paths():
    root = exact_root()
    pending, entries = [ROOT], []
    while pending:
        p = pending.pop()
        s = p.lstat()
        assert s.st_dev == root.st_dev
        assert stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode) or stat.S_ISLNK(s.st_mode)
        entries.append((p, s))
        if stat.S_ISDIR(s.st_mode):
            with os.scandir(p) as children:
                pending.extend(Path(x.path) for x in children)
    return sorted(entries, key=lambda x: os.fsencode(str(x[0])))


def entry(item):
    p, before = item
    kind = 'file' if stat.S_ISREG(before.st_mode) else 'directory' if stat.S_ISDIR(before.st_mode) else 'symlink'
    value = {'path': str(p.relative_to(ROOT.parent)), 'type': kind,
             'mode': stat.S_IMODE(before.st_mode), 'uid': before.st_uid, 'gid': before.st_gid,
             'device': before.st_dev, 'inode': before.st_ino, 'nlink': before.st_nlink,
             'bytes': before.st_size, 'allocated_bytes': before.st_blocks * 512,
             'mtime_ns': before.st_mtime_ns, 'atime_ns': before.st_atime_ns,
             'ctime_ns': before.st_ctime_ns, 'flags': before.st_flags, 'rdev': before.st_rdev}
    value.update(metadata(p, before))
    if kind == 'file':
        h = hashlib.sha256()
        fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, 'rb') as f:
            assert identity(os.fstat(f.fileno())) == identity(before)
            for b in iter(lambda: f.read(CHUNK), b''):
                h.update(b)
            assert identity(os.fstat(f.fileno())) == identity(before)
        value['sha256'] = h.hexdigest()
        if before.st_nlink > 1:
            value['hardlink_group'] = str(before.st_dev) + ':' + str(before.st_ino)
    elif kind == 'symlink':
        value['target'] = os.readlink(p)
        value['target_bytes_base64'] = base64.b64encode(os.fsencode(value['target'])).decode()
    assert identity(p.lstat()) == identity(before)
    return value


def scan(evidence, phase):
    paths = enumerate_paths()
    values = []
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 1)) as pool:
        for number, value in enumerate(pool.map(entry, paths), 1):
            values.append(value)
            if number % 4096 == 0:
                (evidence / 'PROGRESS.json').write_bytes(canonical({'phase': phase, 'entries': number,
                    'total': len(paths), 'seconds': time.monotonic() - started, 'free': guard_capacity()}))
    fresh = enumerate_paths()
    assert [str(p) for p, _ in paths] == [str(p) for p, _ in fresh]
    assert all(identity(a) == identity(b) for (_, a), (_, b) in zip(paths, fresh))
    return values


def no_open_use():
    result = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], capture_output=True, text=True)
    assert result.returncode in (0, 1)
    matches, pid, command, fd = [], None, None, None
    for line in result.stdout.splitlines():
        if line.startswith('p'): pid = line[1:]
        elif line.startswith('c'): command = line[1:]
        elif line.startswith('f'): fd = line[1:]
        elif line.startswith('n') and (line[1:] == str(ROOT) or line[1:].startswith(str(ROOT) + '/')):
            matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': line[1:]})
    ps = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,comm=,args='], text=True)
    references = [x for x in ps.splitlines() if str(ROOT) in x
                  and int(x.split(None, 1)[0]) not in (os.getpid(), os.getppid())]
    receipt = {'utc': utc(), 'lsof_exit_code': result.returncode, 'lsof_stderr': result.stderr,
               'open_paths': matches, 'process_references': references}
    assert not matches and not references, json.dumps(receipt)
    return receipt


def read_reference():
    data = REFERENCE_PLAN.read_bytes()
    assert hashlib.sha256(data).hexdigest() == REFERENCE_SHA
    value = json.loads(data)
    assert value['root'] == str(ROOT)
    assert value['status'] == 'READ_ONLY_EXACT_CONTENT_COVERAGE_PLAN_NOT_PRESERVATION_OR_DELETION'
    return value


def summary(values, payloads):
    return {'entries': len(values), 'regular_files': sum(x['type'] == 'file' for x in values),
            'directories': sum(x['type'] == 'directory' for x in values),
            'symlinks': sum(x['type'] == 'symlink' for x in values),
            'logical_file_bytes': sum(x['bytes'] for x in values if x['type'] == 'file'),
            'base_reused_files': sum(x.get('payload', {}).get('kind') == 'base_archive_member' for x in values),
            'base_reused_logical_bytes': sum(x['bytes'] for x in values if x.get('payload', {}).get('kind') == 'base_archive_member'),
            'new_unique_payloads': len(payloads), 'new_unique_payload_bytes': sum(x['bytes'] for x in payloads.values()),
            'entries_with_xattrs': sum(bool(x['xattrs']) for x in values),
            'entries_with_acl': sum(x['acl'] is not None for x in values),
            'hardlinked_names': sum('hardlink_group' in x for x in values),
            'observed_allocated_bytes_including_shared_extents': sum(x['allocated_bytes'] for x in values)}


def inventory(evidence):
    free = guard_capacity()
    reference = read_reference()
    # Verify source records again; the earlier content plan cannot substitute for this full inventory.
    old = {str(Path(ROOT.name) / x['path']): x for x in reference['entries']}
    assert len(old) == len(reference['entries'])
    content = {}
    for archive in reference['archives']:
        data = Path(archive['manifest']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == archive['manifest_sha256']
        source = json.loads(data)
        rows = source['new_payloads'] if archive['id'] == 'fresh-sdk-differential' else [x for x in source['entries'] if x['type'] == 'file']
        for x in rows:
            content.setdefault((x['sha256'], x['bytes']), {'archive_id': archive['id'],
                'archive_sha256': archive['archive_sha256'], 'member': x['member'] if 'member' in x else x['path']})
        del data, source, rows
    before_use = no_open_use()
    values = scan(evidence, 'full-metadata-inventory')
    assert {x['path'] for x in values} == set(old)
    for x in values:
        expected = old[x['path']]
        for key, value in expected.items():
            if key not in ('path', 'existing_payload_reference'):
                assert x[key] == value, (x['path'], key)
    payloads = {}
    for value in values:
        if value['type'] != 'file': continue
        key = (value['sha256'], value['bytes'])
        if key in content:
            value['payload'] = {'kind': 'base_archive_member', **content[key]}
        else:
            member = 'objects/sha256/' + value['sha256']
            value['payload'] = {'kind': 'differential_archive_member', 'member': member}
            payloads.setdefault(member, {'member': member, 'source_path': value['path'],
                                          'sha256': value['sha256'], 'bytes': value['bytes']})
    counts = summary(values, payloads)
    assert counts['entries'] == 65204 and counts['regular_files'] == 52006
    assert counts['new_unique_payloads'] == 3973 and counts['new_unique_payload_bytes'] == 3222367496
    after_use = no_open_use()
    manifest = {'schema': 'otzaria.qualified-snapshot-preservation/1', 'utc': utc(), 'source_root': str(ROOT),
                'reference_plan_sha256': REFERENCE_SHA, 'reference_plan': str(REFERENCE_PLAN),
                'script_sha256': digest(__file__), 'base_archives': reference['archives'],
                'classification': 'PRESERVATION_ONLY_NO_NEW_ACCEPTANCE_OR_CACHE_QUALIFICATION',
                'retirement_authorized': False, 'anything_deleted': False,
                'metadata_scope': 'All observed POSIX fields, exact Darwin birth time, flags, no-follow ACL/xattrs including compression, exact symlink target bytes, and hardlink groups. Historic inode/device/ctime are recorded identities, not promises of restoring those numbers.',
                'summary': counts, 'entries': values,
                'new_payloads': sorted(payloads.values(), key=lambda x: x['member']),
                'open_use_before': before_use, 'open_use_after': after_use}
    save(evidence / 'MANIFEST.json', manifest)
    result = {'status': 'FULL_SNAPSHOT_INVENTORIED_NOT_ARCHIVED_NOT_RETIRED', 'utc': utc(),
              'source_root': str(ROOT), 'reference_plan_sha256': REFERENCE_SHA,
              'manifest_sha256': digest(evidence / 'MANIFEST.json'),
              'manifest_bytes': (evidence / 'MANIFEST.json').stat().st_size,
              'summary': counts, 'free_before': free, 'free_after': guard_capacity(), 'anything_deleted': False}
    save(evidence / 'INVENTORY_RESULT.json', result)
    print(json.dumps(result))


def load_manifest(evidence, expected):
    p = evidence / 'MANIFEST.json'
    assert digest(p) == expected
    value = json.loads(p.read_bytes())
    assert value['source_root'] == str(ROOT) and value['reference_plan_sha256'] == REFERENCE_SHA
    assert value['script_sha256'] == digest(__file__)
    return value


class HashingWriter:
    def __init__(self, output): self.output, self.hash, self.count = output, hashlib.sha256(), 0
    def write(self, data):
        self.output.write(data); self.hash.update(data); self.count += len(data); return len(data)
    def flush(self): self.output.flush()


class HashingReader:
    def __init__(self, source): self.source, self.hash, self.count = source, hashlib.sha256(), 0
    def read(self, size=-1):
        b = self.source.read(size); self.hash.update(b); self.count += len(b); return b


def stream(evidence, expected):
    manifest = load_manifest(evidence, expected)
    guard_capacity()
    use = no_open_use()
    values = {x['path']: x for x in manifest['entries']}
    writer = HashingWriter(sys.stdout.buffer)
    with gzip.GzipFile(fileobj=writer, mode='wb', filename='', mtime=0, compresslevel=6) as gz:
        with tarfile.open(fileobj=gz, mode='w|', format=tarfile.PAX_FORMAT) as archive:
            data = (evidence / 'MANIFEST.json').read_bytes()
            member = tarfile.TarInfo('MANIFEST.json')
            member.size, member.mode, member.mtime = len(data), 0o600, 0
            archive.addfile(member, io.BytesIO(data))
            for number, payload in enumerate(manifest['new_payloads'], 1):
                guard_capacity()
                rel = PurePosixPath(payload['source_path'])
                assert not rel.is_absolute() and '..' not in rel.parts and rel.parts[0] == ROOT.name
                p = ROOT.parent / str(rel)
                s = p.lstat(); value = values[str(rel)]
                assert stat.S_ISREG(s.st_mode) and s.st_ino == value['inode'] and s.st_dev == value['device']
                assert s.st_size == value['bytes'] and s.st_mtime_ns == value['mtime_ns'] and s.st_ctime_ns == value['ctime_ns']
                fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
                with os.fdopen(fd, 'rb') as f:
                    assert identity(os.fstat(f.fileno())) == identity(s)
                    reader = HashingReader(f)
                    member = tarfile.TarInfo(payload['member'])
                    member.size, member.mode, member.mtime = payload['bytes'], 0o600, 0
                    archive.addfile(member, reader)
                    assert reader.count == payload['bytes'] and reader.hash.hexdigest() == payload['sha256']
                    assert identity(os.fstat(f.fileno())) == identity(s)
                if number % 128 == 0:
                    (evidence / 'PROGRESS.json').write_bytes(canonical({'phase': 'stream', 'payloads': number,
                        'total': len(manifest['new_payloads']), 'archive_bytes_so_far': writer.count}))
    writer.flush()
    save(evidence / 'STREAM_RESULT.json', {'status': 'FULL_SNAPSHOT_DIFFERENTIAL_STREAMED_NOT_RETIRED', 'utc': utc(),
         'source_root': str(ROOT), 'manifest_sha256': expected, 'reference_plan_sha256': REFERENCE_SHA,
         'archive_sha256': writer.hash.hexdigest(), 'archive_bytes': writer.count,
         'payloads': len(manifest['new_payloads']), 'ownership_before': use,
         'free_after': guard_capacity(), 'anything_deleted': False})


def verify_current(evidence, expected, receipt_path, receipt_sha):
    manifest = load_manifest(evidence, expected)
    assert digest(receipt_path) == receipt_sha
    receipt = json.loads(Path(receipt_path).read_bytes())
    assert receipt['status'] == 'COMPLETE_QUALIFIED_SNAPSHOT_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_RETIRED'
    assert receipt['manifest_sha256'] == expected and receipt['source_root'] == str(ROOT)
    assert receipt['reference_plan_sha256'] == REFERENCE_SHA and receipt['entries'] == len(manifest['entries'])
    streamed = json.loads((evidence / 'STREAM_RESULT.json').read_bytes())
    assert receipt['archive_sha256'] == streamed['archive_sha256'] and receipt['archive_bytes'] == streamed['archive_bytes']
    assert receipt['verified_payloads'] == len(manifest['new_payloads'])
    guard_capacity(); before_use = no_open_use()
    values = scan(evidence, 'post-archive-current-full-verification')
    assert [x['path'] for x in values] == [x['path'] for x in manifest['entries']]
    for current, original in zip(values, manifest['entries']):
        assert {k:v for k,v in current.items() if k != 'atime_ns'} == {k:v for k,v in original.items() if k not in ('atime_ns','payload')}, original['path']
    after_use = no_open_use()
    result = {'status': 'FULL_CURRENT_SNAPSHOT_PRESERVED_AND_REVERIFIED_NOT_RETIRED', 'utc': utc(),
              'source_root': str(ROOT), 'manifest_sha256': expected, 'reference_plan_sha256': REFERENCE_SHA,
              'windows_receipt_sha256': receipt_sha, 'archive_sha256': receipt['archive_sha256'],
              'archive_bytes': receipt['archive_bytes'], 'entries_reverified': len(values),
              'open_use_before': before_use, 'open_use_after': after_use, 'free_after': guard_capacity(),
              'anything_deleted': False, 'retirement_authorized': False, 'new_sdk_qualification': False}
    save(evidence / 'CURRENT_REVERIFICATION.json', result)
    print(json.dumps(result))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['inventory','stream','verify-current'])
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--manifest-sha')
    parser.add_argument('--windows-receipt', type=Path)
    parser.add_argument('--windows-receipt-sha')
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    assert evidence.is_dir() and str(evidence).startswith('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.')
    try:
        if args.mode == 'inventory': inventory(evidence)
        elif args.mode == 'stream': stream(evidence,args.manifest_sha)
        else: verify_current(evidence,args.manifest_sha,args.windows_receipt,args.windows_receipt_sha)
    except Exception as error:
        save(evidence / (args.mode.upper() + '_FAILED_' + str(time.time_ns()) + '.json'),
             {'utc':utc(),'mode':args.mode,'error':repr(error),'source_root':str(ROOT),
              'source_still_exists':os.path.lexists(ROOT),'anything_deleted':False})
        raise


if __name__ == '__main__': main()
