#!/usr/bin/env python3
"""Preserve one explicitly leased interrupted SDK directory; never qualify it.

Inventory retains every path, regular payload, link, POSIX metadata, Darwin
birth timestamp, flags, ACL and extended attribute. Reused payloads are bound
to a previously fully verified archive. No source is removed by inventory or
stream. Retirement additionally requires a verified off-host differential,
a second complete hash/metadata inventory and no live owner/open-file use.
"""
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

ROOT = Path('/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterCapacity-20261127-Work/producer-derived')
SOURCE = Path('/Users/m1/builds/otzaria-wave1-sdk-20261127/source')
OLD_MANIFEST = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/wave3-interrupted-sdk-work-preservation-20261127.811pvzsd/MEMBER_MANIFEST.json')
OLD_MANIFEST_SHA = '558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94'
OLD_ARCHIVE_SHA = '2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda'
MIN_FREE = 2 * 1024**3 + 256 * 1024**2
READ_CHUNK = 1024 * 1024


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(READ_CHUNK), b''):
            h.update(b)
    return h.hexdigest()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def save(path, value):
    with Path(path).open('xb') as f:
        f.write(canonical(value))


def df():
    return subprocess.check_output(['df', '-k', '/System/Volumes/Data'], text=True)


def guard_capacity():
    free = shutil.disk_usage('/System/Volumes/Data').free
    if free < MIN_FREE:
        raise RuntimeError('Mac capacity reserve: ' + str(free))
    return free


def identity(st):
    # Access time can change because of our own reads; retain it separately.
    return (st.st_dev, st.st_ino, st.st_mode, st.st_uid, st.st_gid,
            st.st_nlink, st.st_size, st.st_mtime_ns, st.st_ctime_ns, st.st_flags)


def exact_root():
    assert str(ROOT.resolve()) == str(ROOT)
    st = ROOT.lstat()
    assert stat.S_ISDIR(st.st_mode) and not ROOT.is_symlink() and st.st_uid == os.getuid()
    assert ROOT.name == 'producer-derived' and ROOT.parent.name == 'SDK-Wave3-1be97035-Debug-FreshAfterCapacity-20261127-Work'
    return st


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


def enumerate_paths():
    root_stat = exact_root()
    result = []
    stack = [ROOT]
    while stack:
        path = stack.pop()
        st = path.lstat()
        if st.st_dev != root_stat.st_dev:
            raise RuntimeError('Mounted/external device inside leased directory: ' + str(path))
        if not (stat.S_ISDIR(st.st_mode) or stat.S_ISREG(st.st_mode) or stat.S_ISLNK(st.st_mode)):
            raise RuntimeError('Unsupported special file; nothing may be retired: ' + str(path))
        result.append((path, st))
        if stat.S_ISDIR(st.st_mode):
            with os.scandir(path) as children:
                stack.extend(sorted((Path(x.path) for x in children), key=os.fsencode, reverse=True))
    return sorted(result, key=lambda x: os.fsencode(str(x[0])))


def entry(item):
    path, before = item
    kind = 'directory' if stat.S_ISDIR(before.st_mode) else 'file' if stat.S_ISREG(before.st_mode) else 'symlink'
    value = {'path': str(path.relative_to(ROOT.parent)), 'type': kind,
             'mode': stat.S_IMODE(before.st_mode), 'uid': before.st_uid, 'gid': before.st_gid,
             'device': before.st_dev, 'inode': before.st_ino, 'nlink': before.st_nlink,
             'bytes': before.st_size, 'allocated_bytes': before.st_blocks * 512,
             'mtime_ns': before.st_mtime_ns, 'atime_ns': before.st_atime_ns,
             'ctime_ns': before.st_ctime_ns, 'flags': before.st_flags, 'rdev': before.st_rdev}
    value.update(metadata(path, before))
    if kind == 'symlink':
        value['target'] = os.readlink(path)
        value['target_bytes_base64'] = base64.b64encode(os.fsencode(value['target'])).decode()
    elif kind == 'file':
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        h = hashlib.sha256()
        with os.fdopen(fd, 'rb') as f:
            assert identity(os.fstat(f.fileno())) == identity(before), str(path)
            for b in iter(lambda: f.read(READ_CHUNK), b''):
                h.update(b)
            assert identity(os.fstat(f.fileno())) == identity(before), str(path)
        value['sha256'] = h.hexdigest()
        if before.st_nlink > 1:
            value['hardlink_group'] = str(before.st_dev) + ':' + str(before.st_ino)
    assert identity(path.lstat()) == identity(before), str(path)
    return value


def scan(evidence, label):
    paths = enumerate_paths()
    values = []
    started = time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 1)) as executor:
        for number, value in enumerate(executor.map(entry, paths), 1):
            values.append(value)
            if number % 4096 == 0:
                progress = {'phase': label, 'entries': number, 'total': len(paths),
                            'seconds': time.monotonic() - started, 'free_bytes': guard_capacity()}
                (evidence / 'PROGRESS.json').write_bytes(canonical(progress))
    fresh = enumerate_paths()
    assert [str(p) for p, _ in fresh] == [str(p) for p, _ in paths]
    assert all(identity(a) == identity(b) for (_, a), (_, b) in zip(paths, fresh))
    return values


def no_open_users():
    process = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], capture_output=True, text=True)
    if process.returncode not in (0, 1):
        raise RuntimeError('lsof failed: ' + process.stderr)
    matches, pid, command, fd = [], None, None, None
    for line in process.stdout.splitlines():
        if line.startswith('p'):
            pid = int(line[1:])
        elif line.startswith('c'):
            command = line[1:]
        elif line.startswith('f'):
            fd = line[1:]
        elif line.startswith('n') and (line[1:] == str(ROOT) or line[1:].startswith(str(ROOT) + '/')):
            matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': line[1:]})
    ps = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,comm=,args='], text=True)
    processes = [line for line in ps.splitlines() if str(ROOT.parent) in line
                 and int(line.split(None, 1)[0]) not in (os.getpid(), os.getppid())]
    result = {'utc': utc(), 'lsof_returncode': process.returncode, 'lsof_stderr': process.stderr,
              'open_paths': matches, 'process_references': processes}
    if matches or processes:
        raise RuntimeError('Active use of leased work: ' + json.dumps(result))
    return result


def protected():
    paths = list(SOURCE.iterdir())
    paths = [p for p in paths if p.name != 'build']
    paths += [p for p in (SOURCE / 'build').iterdir() if p != ROOT.parent]
    result = {}
    for p in sorted(paths):
        st = p.lstat()
        result[str(p)] = {'device': st.st_dev, 'inode': st.st_ino, 'mode': st.st_mode,
                          'uid': st.st_uid, 'gid': st.st_gid, 'bytes': st.st_size,
                          'mtime_ns': st.st_mtime_ns, 'ctime_ns': st.st_ctime_ns}
        if stat.S_ISREG(st.st_mode):
            result[str(p)]['sha256'] = digest(p)
        elif stat.S_ISLNK(st.st_mode):
            result[str(p)]['target'] = os.readlink(p)
    return result


def inventory(evidence):
    assert not (evidence / 'MANIFEST.json').exists()
    free_before = guard_capacity()
    old_bytes = OLD_MANIFEST.read_bytes()
    assert hashlib.sha256(old_bytes).hexdigest() == OLD_MANIFEST_SHA
    old = json.loads(old_bytes)
    old_by_path = {x['path']: x for x in old['entries'] if x['type'] == 'file'}
    old_by_content = {}
    for p, x in sorted(old_by_path.items()):
        old_by_content.setdefault((x['sha256'], x['bytes']), p)
    ownership = no_open_users()
    outside = protected()
    source_head = subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip()
    values = scan(evidence, 'inventory')
    payloads, reused_files, reused_bytes = {}, 0, 0
    for x in values:
        if x['type'] != 'file':
            continue
        key = (x['sha256'], x['bytes'])
        previous = old_by_path.get(x['path'])
        old_path = x['path'] if previous and (previous['sha256'], previous['bytes']) == key else old_by_content.get(key)
        if old_path:
            x['payload'] = {'kind': 'base_archive_member', 'member': old_path,
                            'archive_sha256': OLD_ARCHIVE_SHA}
            reused_files += 1
            reused_bytes += x['bytes']
        else:
            member = 'objects/sha256/' + x['sha256']
            x['payload'] = {'kind': 'differential_archive_member', 'member': member}
            payloads.setdefault(member, {'member': member, 'source_path': x['path'],
                                        'sha256': x['sha256'], 'bytes': x['bytes']})
    summary = {'entries': len(values), 'regular_files': sum(x['type'] == 'file' for x in values),
               'directories': sum(x['type'] == 'directory' for x in values),
               'symlinks': sum(x['type'] == 'symlink' for x in values),
               'logical_file_bytes': sum(x['bytes'] for x in values if x['type'] == 'file'),
               'observed_allocated_bytes_including_shared_extents': sum(x['allocated_bytes'] for x in values),
               'base_reused_files': reused_files, 'base_reused_logical_bytes': reused_bytes,
               'new_unique_payloads': len(payloads), 'new_unique_payload_bytes': sum(x['bytes'] for x in payloads.values()),
               'entries_with_xattrs': sum(bool(x['xattrs']) for x in values),
               'entries_with_acl': sum(x['acl'] is not None for x in values),
               'entries_with_flags': sum(x['flags'] != 0 for x in values),
               'hardlinked_names': sum('hardlink_group' in x for x in values)}
    final_ownership = no_open_users()
    assert protected() == outside
    manifest = {'schema': 'otzaria.interrupted-sdk-differential/1', 'created_at': utc(),
                'source_root': str(ROOT), 'source_head': source_head,
                'source_qualification': 'UNQUALIFIED_INTERRUPTED_PRODUCER_DERIVED_NO_BUILD_ACCEPTANCE',
                'base_archive_sha256': OLD_ARCHIVE_SHA, 'base_archive_bytes': 5238640114,
                'base_manifest_sha256': OLD_MANIFEST_SHA,
                'base_full_verification_job': 'job_6f9fcedf19df',
                'metadata_scope': 'Every observed POSIX field, exact Darwin birthtime, flags, full no-follow ACL and all no-follow xattrs including compression; inode/device/ctime are retained historical identity, not a promise that a new filesystem can recreate their numbers.',
                'script_sha256': digest(__file__), 'summary': summary, 'entries': values,
                'new_payloads': sorted(payloads.values(), key=lambda x: x['member']),
                'protected_outside': outside, 'open_users_before': ownership,
                'open_users_after': final_ownership}
    save(evidence / 'MANIFEST.json', manifest)
    result = {'status': 'COMPLETE_HASHED_INVENTORY_NOT_REMOVED', 'utc': utc(),
              'manifest_sha256': digest(evidence / 'MANIFEST.json'),
              'manifest_bytes': (evidence / 'MANIFEST.json').stat().st_size,
              'summary': summary, 'free_before': free_before, 'free_after': guard_capacity(), 'df': df()}
    save(evidence / 'INVENTORY_RESULT.json', result)
    print(json.dumps(result))


class HashingWriter:
    def __init__(self, output):
        self.output, self.hash, self.count = output, hashlib.sha256(), 0
    def write(self, data):
        self.output.write(data)
        self.hash.update(data)
        self.count += len(data)
        return len(data)
    def flush(self):
        self.output.flush()


class HashingReader:
    def __init__(self, f):
        self.file, self.hash, self.count = f, hashlib.sha256(), 0
    def read(self, size=-1):
        data = self.file.read(size)
        self.hash.update(data)
        self.count += len(data)
        return data


def load_manifest(evidence, expected):
    path = evidence / 'MANIFEST.json'
    assert digest(path) == expected
    manifest = json.loads(path.read_bytes())
    assert manifest['source_root'] == str(ROOT) and manifest['base_archive_sha256'] == OLD_ARCHIVE_SHA
    assert manifest['script_sha256'] == digest(__file__)
    return manifest


def stream(evidence, expected):
    manifest = load_manifest(evidence, expected)
    guard_capacity()
    ownership = no_open_users()
    entries = {x['path']: x for x in manifest['entries']}
    writer = HashingWriter(sys.stdout.buffer)
    try:
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
                    path = ROOT.parent / str(rel)
                    before = path.lstat()
                    value = entries[str(rel)]
                    assert stat.S_ISREG(before.st_mode) and before.st_ino == value['inode'] and before.st_dev == value['device']
                    assert before.st_size == value['bytes'] and before.st_mtime_ns == value['mtime_ns'] and before.st_ctime_ns == value['ctime_ns']
                    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
                    with os.fdopen(fd, 'rb') as f:
                        assert identity(os.fstat(f.fileno())) == identity(before)
                        reader = HashingReader(f)
                        member = tarfile.TarInfo(payload['member'])
                        member.size, member.mode, member.mtime = payload['bytes'], 0o600, 0
                        archive.addfile(member, reader)
                        assert reader.count == payload['bytes'] and reader.hash.hexdigest() == payload['sha256']
                        assert identity(os.fstat(f.fileno())) == identity(before)
                    if number % 512 == 0:
                        (evidence / 'PROGRESS.json').write_bytes(canonical({'phase': 'stream', 'payloads': number,
                            'total': len(manifest['new_payloads']), 'archive_bytes_so_far': writer.count}))
        writer.flush()
        result = {'status': 'DIFFERENTIAL_STREAMED_NOT_REMOVED', 'utc': utc(),
                  'manifest_sha256': expected, 'archive_sha256': writer.hash.hexdigest(),
                  'archive_bytes': writer.count, 'payloads': len(manifest['new_payloads']),
                  'source_root': str(ROOT), 'ownership_before': ownership, 'df': df()}
        save(evidence / 'STREAM_RESULT.json', result)
    except Exception as error:
        save(evidence / 'STREAM_ERROR.json', {'status': 'FAILED_NOT_REMOVED', 'utc': utc(), 'error': repr(error),
                                            'partial_bytes': writer.count, 'partial_sha256': writer.hash.hexdigest()})
        raise


def verify_and_retire(evidence, expected, receipt_path, receipt_sha, remove):
    manifest = load_manifest(evidence, expected)
    assert digest(receipt_path) == receipt_sha
    receipt = json.loads(Path(receipt_path).read_bytes())
    assert receipt['status'] == 'COMPLETE_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_REMOVED'
    assert receipt['manifest_sha256'] == expected and receipt['base_archive_sha256'] == OLD_ARCHIVE_SHA
    assert receipt['entries'] == len(manifest['entries']) and receipt['source_root'] == str(ROOT)
    streamed = json.loads((evidence / 'STREAM_RESULT.json').read_bytes())
    assert receipt['archive_sha256'] == streamed['archive_sha256'] and receipt['archive_bytes'] == streamed['archive_bytes']
    assert receipt['verified_payloads'] == len(manifest['new_payloads'])
    free_before = guard_capacity()
    ownership_before = no_open_users()
    outside = protected()
    assert outside == manifest['protected_outside']
    source_head = subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip()
    assert source_head == manifest['source_head']
    fresh = scan(evidence, 'full-rehash-before-retirement')
    before = manifest['entries']
    assert [x['path'] for x in fresh] == [x['path'] for x in before]
    for actual, original in zip(fresh, before):
        comparable = {k: v for k, v in original.items() if k not in ('atime_ns', 'payload')}
        current = {k: v for k, v in actual.items() if k != 'atime_ns'}
        assert comparable == current, original['path']
    ownership_after = no_open_users()
    assert protected() == outside
    root_stat = exact_root()
    assert root_stat.st_ino == before[0]['inode'] and root_stat.st_dev == before[0]['device']
    result = {'status': 'FULL_CURRENT_CONTENT_AND_METADATA_REVERIFIED_NOT_REMOVED', 'utc': utc(),
              'source_root': str(ROOT), 'source_head': source_head, 'manifest_sha256': expected,
              'windows_receipt_sha256': receipt_sha, 'archive_sha256': receipt['archive_sha256'],
              'base_archive_sha256': OLD_ARCHIVE_SHA, 'entries_rehashed': len(fresh),
              'ownership_before': ownership_before, 'ownership_after': ownership_after,
              'free_before': free_before, 'protected_before': outside, 'source_qualified': False}
    save(evidence / 'CURRENT_REVERIFICATION.json', result)
    if remove:
        assert shutil.rmtree.avoids_symlink_attacks
        # The exact fixed root has just been rehashed, stat-checked and found
        # unused; Python's fd-based rmtree does not follow replaced symlinks.
        shutil.rmtree(ROOT)
        assert not os.path.lexists(ROOT)
        result['status'] = 'RETIRED_ONLY_FULLY_PRESERVED_FRESH_PRODUCER_DERIVED'
        result['removed'] = [str(ROOT)]
        result['outside_paths_unchanged'] = protected() == outside
        result['work_parent_retained'] = ROOT.parent.is_dir()
        result['free_after'] = shutil.disk_usage('/System/Volumes/Data').free
        result['observed_free_delta_bytes'] = result['free_after'] - free_before
        result['delta_caveat'] = 'Concurrent df observation, not exclusive APFS reclaimed allocation.'
        result['df_after'] = df()
        result['finished_at'] = utc()
        save(evidence / 'RETIREMENT_RESULT.json', result)
        assert result['outside_paths_unchanged']
    print(json.dumps({k: v for k, v in result.items() if k not in ('protected_before', 'ownership_before', 'ownership_after')}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['inventory', 'stream', 'verify-current', 'retire'])
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--manifest-sha')
    parser.add_argument('--windows-receipt', type=Path)
    parser.add_argument('--windows-receipt-sha')
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    assert evidence.is_dir() and str(evidence).startswith('/Users/m1/builds/otzaria-wave3-fresh-producer-preservation-20261127.')
    try:
        if args.mode == 'inventory':
            inventory(evidence)
        elif args.mode == 'stream':
            stream(evidence, args.manifest_sha)
        else:
            verify_and_retire(evidence, args.manifest_sha, args.windows_receipt,
                              args.windows_receipt_sha, args.mode == 'retire')
    except Exception as error:
        path = evidence / (args.mode.upper() + '_FAILED_' + str(time.time_ns()) + '.json')
        save(path, {'status': 'FAILED', 'utc': utc(), 'mode': args.mode, 'error': repr(error),
                    'source_root': str(ROOT), 'source_root_still_exists': os.path.lexists(ROOT), 'native_acceptance': 0})
        raise


if __name__ == '__main__':
    main()
