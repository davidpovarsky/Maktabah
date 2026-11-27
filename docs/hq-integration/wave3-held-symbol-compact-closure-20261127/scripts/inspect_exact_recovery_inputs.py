import ctypes
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
SCOPES = [(BASE / 'exact-go-archive-recovery.JvVNJyCs', 63006231),
          (BASE / 'immutable-stage2-artifact-inputs.HZMBWCuD', 58997527)]
SDK = Path('/Users/m1/builds/otzaria-wave1-sdk-20261127/source')
PLAN = Path('/Users/m1/builds/otzaria-wave3-sdk-pasteboard-plan-20261127.mr4u8199')


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
    assert rc == 0, (str(path), ctypes.get_errno())
    assert struct.unpack_from('=I', b.raw, 0)[0] == 44
    assert struct.unpack_from('=IIIII', b.raw, 4) == (0x80000000, 0, 0, 0, 0x1108)
    p, clone, refs = struct.unpack_from('=qQI', b.raw, 24)
    assert p >= 0
    return {'kernel_private_bytes': p, 'clone_id': clone, 'clone_references': refs}


def ident(path):
    s = path.lstat()
    return {'path': str(path), 'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'bytes': s.st_size, 'allocated_bytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def run(argv):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    return {'exit': p.returncode, 'stdout': p.stdout.decode('utf-8', 'replace'), 'stderr': p.stderr.decode('utf-8', 'replace')}


def metadata(path):
    s = path.lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_size > 2 * 1024 * 1024 or path.suffix not in ['.json', '.exit', '.txt', '.log', '.py']:
        return None
    if re.search(r'password|credential|secret|environment', path.name, re.I):
        return None
    raw = path.read_bytes()
    row = {'identity': ident(path), 'sha256': hashlib.sha256(raw).hexdigest()}
    if path.suffix == '.json':
        try:
            d = json.loads(raw)
            if isinstance(d, dict):
                row['keys'] = sorted(d)
                row['safe_scalars'] = {k: v for k, v in d.items()
                    if re.search(r'^(status|source_sha|source_commit|source|archive_sha256|archive_bytes|verified|exit_code|sdk_source_sha|application_source_sha|artifact|sha256|size|bytes)$', k)
                    and (isinstance(v, (bool, int, float)) or isinstance(v, str) and len(v) < 512)}
        except (ValueError, UnicodeError):
            row['not_json'] = True
    elif path.suffix in ['.txt', '.exit']:
        v = raw.decode('utf-8', 'replace').strip()
        if re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}|-?\d{1,3}', v): row['digest_or_exit'] = v
    return row


assert os.getuid() == 501
result = {'schema': 'otzaria.exact-recovery-inputs-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'writes': 0, 'deletions': 0, 'signals': 0, 'builds': 0, 'scope': 'EXACT_TWO_SOURCE_INPUT_ROOTS', 'roots': []}
v = os.statvfs(BASE); result['free_before'] = v.f_bavail * v.f_frsize
for root, expected in SCOPES:
    before = ident(root)
    assert before['inode'] == expected and stat.S_ISDIR(before['mode']) and not root.is_symlink()
    row = {'identity': before, 'entries': [], 'metadata': []}
    for directory, names, files in os.walk(root, followlinks=False):
        names.sort(); files.sort()
        for name in names + files:
            p = Path(directory) / name
            s = p.lstat(); item = ident(p)
            if stat.S_ISREG(s.st_mode): item.update(private(p))
            elif stat.S_ISLNK(s.st_mode): item['symlink_target'] = os.readlink(p)
            row['entries'].append(item)
            if len(p.relative_to(root).parts) <= 2:
                m = metadata(p)
                if m: row['metadata'].append(m)
            assert len(row['entries']) < 30000, 'Bounded exact-root inventory exceeded30000 entries'
    seen = set(); allocated = private_bytes = logical = 0
    for item in row['entries']:
        if stat.S_ISREG(item['mode']):
            logical += item['bytes']
            k = (item['device'], item['inode'])
            if k not in seen:
                seen.add(k); allocated += item['allocated_bytes']
                if item['nlink'] == 1: private_bytes += item['kernel_private_bytes']
    row['totals'] = {'entries': len(row['entries']), 'regular_inodes': len(seen), 'logical_bytes': logical,
                     'allocated_bytes': allocated, 'kernel_private_bytes': private_bytes}
    assert ident(root) == before
    result['roots'].append(row)
result['current_sdk_controller_literal_references'] = run(['/usr/bin/git', '--no-optional-locks', '-C', str(SDK),
    'grep', '-n', '-F', '-e', str(SCOPES[0][0]), '-e', str(SCOPES[1][0]), 'HEAD', '--', 'Tools/OriginalEditor', 'Tools/Hanlin', '.github'])
result['future_launch_metadata'] = []
for name in ['supervisor.py', 'FRESH_RUN_COMMANDS.json', 'LAUNCH_INPUTS.json', 'launch_owned.py', 'completion_watcher.py']:
    p = PLAN / name
    if p.is_file() and not p.is_symlink() and p.stat().st_size < 2 * 1024 * 1024:
        raw = p.read_bytes(); text = raw.decode('utf-8', 'replace')
        result['future_launch_metadata'].append({'path': str(p), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
            'exact_literal_matches': [str(r) for r, _ in SCOPES if str(r) in text], 'encoded_recipe_not_reinterpreted_here': name == 'FRESH_RUN_COMMANDS.json'})
p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=35)
matches = []; pid = command = fd = None
for line in p.stdout.decode('utf-8', 'replace').splitlines():
    if not line: continue
    kind, value = line[0], line[1:]
    if kind == 'p': pid = int(value)
    elif kind == 'c': command = value
    elif kind == 'f': fd = value
    elif kind == 'n' and any(value == str(r) or value.startswith(str(r) + '/') for r, _ in SCOPES):
        matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': value})
result['open_references'] = {'exit': p.returncode, 'matches': matches, 'stderr_bytes': len(p.stderr),
                             'stderr_sha256': hashlib.sha256(p.stderr).hexdigest(), 'unrelated_rows_not_retained': True}
v = os.statvfs(BASE); result['free_after'] = v.f_bavail * v.f_frsize
result['complete_preservation_not_performed'] = True
result['retirement_not_authorized'] = True
print(json.dumps(result, sort_keys=True))
