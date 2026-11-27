import ctypes
import datetime
import hashlib
import heapq
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import time

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ROOT = BASE / 'compact-reader-preview-worktree.5hRb5SYt'
EXPECTED_INODE = 61610714
SDK = Path('/Users/m1/builds/otzaria-wave1-sdk-20261127/source')
PAIRED = BASE / 'actual-paired-production-release.Hguhbz1S/Maktabah'


class Attr(ctypes.Structure):
    _fields_ = [('count', ctypes.c_uint16), ('reserved', ctypes.c_uint16), ('common', ctypes.c_uint32),
                ('vol', ctypes.c_uint32), ('directory', ctypes.c_uint32), ('file', ctypes.c_uint32), ('fork', ctypes.c_uint32)]


LIB = ctypes.CDLL(None, use_errno=True)
LIB.getattrlist.argtypes = [ctypes.c_char_p, ctypes.POINTER(Attr), ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong]
LIB.getattrlist.restype = ctypes.c_int


def private(path):
    a = Attr(5, 0, 0x80000000, 0, 0, 0, 0x1108)
    b = ctypes.create_string_buffer(128)
    ctypes.set_errno(0)
    rc = LIB.getattrlist(os.fsencode(path), ctypes.byref(a), b, len(b), 0x21)
    if rc:
        return None, ctypes.get_errno()
    length = struct.unpack_from('=I', b.raw, 0)[0]
    attrs = struct.unpack_from('=IIIII', b.raw, 4)
    if length != 44 or attrs != (0x80000000, 0, 0, 0, 0x1108):
        return None, {'length': length, 'attributes': attrs}
    size, clone, refs = struct.unpack_from('=qQI', b.raw, 24)
    assert size >= 0
    return (size, clone, refs), None


def ident(path):
    s = path.lstat()
    return {'path': str(path), 'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'uid': s.st_uid, 'gid': s.st_gid, 'size': s.st_size, 'blocks': s.st_blocks,
            'nlink': s.st_nlink, 'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def run(argv, timeout=35):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    return {'exit': p.returncode, 'stdout': p.stdout.decode('utf-8', 'replace'), 'stderr': p.stderr.decode('utf-8', 'replace')}


def file_pin(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size > 1048576:
        return None
    raw = path.read_bytes()
    return {'identity': ident(path), 'sha256': hashlib.sha256(raw).hexdigest(), 'raw': raw}


def safe_git_metadata(repo):
    row = {'repository': str(repo), 'head': run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'rev-parse', 'HEAD']),
           'git_dir': run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'rev-parse', '--absolute-git-dir']),
           'common_dir': run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'rev-parse', '--git-common-dir']),
           'worktrees': run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'worktree', 'list', '--porcelain'])}
    for label in ['git_dir', 'common_dir']:
        if row[label]['exit'] == 0:
            d = Path(row[label]['stdout'].strip())
            if not d.is_absolute():
                d = repo / d
            a = file_pin(d / 'objects/info/alternates')
            if a:
                raw = a.pop('raw')
                row[label + '_alternates'] = {**a, 'paths': raw.decode().splitlines()}
    return row


assert os.getuid() == 501 and not ROOT.is_symlink()
before = ident(ROOT)
assert before['inode'] == EXPECTED_INODE and stat.S_ISDIR(before['mode'])
start = time.monotonic()
v = os.statvfs(ROOT)
result = {'schema': 'otzaria.compact-root-closure-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'root_before': before, 'free_before': v.f_bavail * v.f_frsize,
          'writes': 0, 'deletions': 0, 'signals': 0, 'builds': 0,
          'inventory_is_metadata_plan_not_preservation': True}
groups = {}
seen = set()
largest = []
links = []
git_markers = []
alternates = []
errors = []
inventory = hashlib.sha256()
entries = 0
for directory, names, files in os.walk(ROOT, followlinks=False):
    names.sort(); files.sort()
    for name in names + files:
        path = Path(directory) / name
        s = path.lstat()
        rel = path.relative_to(ROOT)
        parts = rel.parts
        if parts[0] != 'Maktabah':
            group = parts[0]
        elif len(parts) >= 3 and parts[1] == 'build':
            group = '/'.join(parts[:3])
        else:
            group = '/'.join(parts[:2])
        g = groups.setdefault(group, {'entries': 0, 'files': 0, 'directories': 0, 'symlinks': 0,
                                     'logical_bytes': 0, 'unique_allocated_bytes': 0, 'kernel_private_bytes': 0,
                                     'multiply_linked_files': 0, 'private_errors': 0})
        g['entries'] += 1; entries += 1
        record = [str(rel), s.st_dev, s.st_ino, s.st_mode, s.st_uid, s.st_gid, s.st_size, s.st_blocks, s.st_nlink, s.st_mtime_ns, s.st_ctime_ns]
        if stat.S_ISLNK(s.st_mode):
            target = os.readlink(path)
            g['symlinks'] += 1
            record.append(target)
            # All source/link locators retained, without following them or reading targets.
            links.append({'path': str(path), 'target': target, 'resolved_target': str(path.resolve(strict=False))})
        elif stat.S_ISDIR(s.st_mode):
            g['directories'] += 1
        elif stat.S_ISREG(s.st_mode):
            g['files'] += 1; g['logical_bytes'] += s.st_size
            key = (s.st_dev, s.st_ino)
            if key not in seen:
                seen.add(key)
                g['unique_allocated_bytes'] += s.st_blocks * 512
                p, error = private(path)
                if error is not None:
                    g['private_errors'] += 1
                    if len(errors) < 12:
                        errors.append({'path': str(path), 'error': error})
                elif s.st_nlink == 1:
                    g['kernel_private_bytes'] += p[0]
                else:
                    g['multiply_linked_files'] += 1
            item = (s.st_size, str(path), s.st_ino, s.st_blocks * 512)
            if len(largest) < 40:
                heapq.heappush(largest, item)
            elif item > largest[0]:
                heapq.heapreplace(largest, item)
            if name == 'alternates' and path.parent.name == 'info' and path.parent.parent.name == 'objects':
                a = file_pin(path)
                if a:
                    raw = a.pop('raw')
                    assert len(raw) < 65536
                    alternates.append({**a, 'paths': raw.decode().splitlines()})
            if name == '.git':
                a = file_pin(path)
                if a:
                    raw = a.pop('raw')
                    assert len(raw) < 16384 and raw.startswith(b'gitdir:')
                    git_markers.append({**a, 'gitdir': raw.decode().strip()})
        inventory.update((json.dumps(record, separators=(',', ':')) + '\n').encode())
    assert time.monotonic() - start < 150, 'bounded metadata walk exceeded150 seconds'
result['metadata_inventory'] = {'entries': entries, 'unique_regular_inodes': len(seen),
                                'stat_stream_sha256': inventory.hexdigest(), 'groups': groups,
                                'largest40_files': [{'bytes': x[0], 'path': x[1], 'inode': x[2], 'allocated_bytes': x[3]} for x in sorted(largest, reverse=True)],
                                'symlinks': links, 'git_marker_files': git_markers, 'object_alternates': alternates,
                                'private_errors': errors, 'elapsed_seconds': time.monotonic() - start}
repo = ROOT / 'Maktabah'
result['primary_git_metadata'] = safe_git_metadata(repo)
result['primary_tracked_worktree_delta'] = run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'status', '--porcelain=v1', '--untracked-files=no', '--ignore-submodules=all'])
result['explicit_consumer_metadata'] = []
for consumer in [repo, PAIRED, SDK]:
    row = {'repository': str(consumer)}
    for name in ['Maktabah.xcodeproj/project.pbxproj', 'Maktabah.xcworkspace/contents.xcworkspacedata',
                 'Scripts/CI/hq-stage2-focused-apple.inputs.json', '.git/objects/info/alternates',
                 'build/DerivedData/info.plist', 'build/ReleaseDerivedData/info.plist']:
        p = consumer / name
        pin = file_pin(p)
        if pin:
            raw = pin.pop('raw')
            text = raw.decode('utf-8', 'replace')
            needles = [str(ROOT), 'SourcePackages', 'wave3-native-0db0ab78-sdk2']
            matches = [line[:1000] for line in text.splitlines() if any(x in line for x in needles)
                       and not any(x in line.lower() for x in ['password', 'credential', 'bearer', 'authorization'])]
            row.setdefault('files', []).append({**pin, 'matching_source_locator_lines': matches[:50]})
    for name in ['Pods', 'node_modules']:
        p = consumer / name
        if p.is_symlink():
            row.setdefault('symlinks', []).append({'path': str(p), 'target': os.readlink(p), 'resolved': str(p.resolve(strict=False))})
    if consumer == SDK:
        row['source'] = safe_git_metadata(consumer)
        row['literal_controller_references'] = run(['/usr/bin/git', '--no-optional-locks', '-C', str(consumer), 'grep', '-n', '-F', str(ROOT), 'HEAD', '--', 'Tools/OriginalEditor', 'Tools/Hanlin', '.github'])
    result['explicit_consumer_metadata'].append(row)

p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=45)
matches = []; pid = command = fd = None
for line in p.stdout.decode('utf-8', 'replace').splitlines():
    if not line:
        continue
    kind, value = line[0], line[1:]
    if kind == 'p': pid = int(value)
    elif kind == 'c': command = value
    elif kind == 'f': fd = value
    elif kind == 'n' and (value == str(ROOT) or value.startswith(str(ROOT) + '/')):
        if any(part.startswith(('.credentials', '.runner')) for part in Path(value).parts):
            value = '[SCOPED_CREDENTIAL_PATH_OMITTED]'
        matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': value})
result['open_references'] = {'exit': p.returncode, 'matches': matches,
                             'stderr_bytes': len(p.stderr), 'stderr_sha256': hashlib.sha256(p.stderr).hexdigest(),
                             'foreign_rows_not_retained': True}
v = os.statvfs(ROOT)
result['free_after'] = v.f_bavail * v.f_frsize
result['root_after'] = ident(ROOT)
assert result['root_before'] == result['root_after']
result['full_content_preservation_not_performed'] = True
result['incoming_consumers_not_exhaustively_proven_absent'] = True
print(json.dumps(result, sort_keys=True))
