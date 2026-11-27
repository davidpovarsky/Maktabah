import ctypes
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
EXPECTED = {18664: (1, 'Thu Nov 26 21:12:58 2026'), 18665: (18664, 'Thu Nov 26 21:12:58 2026'),
            35619: (1, 'Thu Nov 26 17:01:38 2026'), 35620: (35619, 'Thu Nov 26 17:01:38 2026'),
            41371: (1, 'Thu Nov 26 17:09:32 2026'), 41372: (41371, 'Thu Nov 26 17:09:32 2026')}
EXPECTED_FDS = {18665: (65257836, 73643232), 35620: (60649716, 73571512), 41372: (60745183, 73571512)}
SDK = Path('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk')


def processes():
    p = subprocess.run(['/bin/ps', '-p', ','.join(map(str, sorted(EXPECTED))), '-o', 'pid=,ppid=,lstart=,comm='], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    rows = []
    for line in p.stdout.decode().splitlines():
        a = line.split(None, 7)
        pid, ppid, start = int(a[0]), int(a[1]), ' '.join(a[2:7])
        assert (ppid, start) == EXPECTED[pid]
        rows.append({'pid': pid, 'ppid': ppid, 'start_local': start, 'command': a[7]})
    assert len(rows) == 6 and p.returncode == 0
    return rows


class VinfoStat(ctypes.Structure):
    _fields_ = [('vst_dev', ctypes.c_uint32), ('vst_mode', ctypes.c_uint16), ('vst_nlink', ctypes.c_uint16),
                ('vst_ino', ctypes.c_uint64), ('vst_uid', ctypes.c_uint32), ('vst_gid', ctypes.c_uint32),
                ('vst_atime', ctypes.c_int64), ('vst_atimensec', ctypes.c_int64),
                ('vst_mtime', ctypes.c_int64), ('vst_mtimensec', ctypes.c_int64),
                ('vst_ctime', ctypes.c_int64), ('vst_ctimensec', ctypes.c_int64),
                ('vst_birthtime', ctypes.c_int64), ('vst_birthtimensec', ctypes.c_int64),
                ('vst_size', ctypes.c_int64), ('vst_blocks', ctypes.c_int64), ('vst_blksize', ctypes.c_int32),
                ('vst_flags', ctypes.c_uint32), ('vst_gen', ctypes.c_uint32), ('vst_rdev', ctypes.c_uint32),
                ('vst_qspare', ctypes.c_int64 * 2)]


class VnodeInfo(ctypes.Structure):
    _fields_ = [('vi_stat', VinfoStat), ('vi_type', ctypes.c_int), ('vi_pad', ctypes.c_int), ('vi_fsid', ctypes.c_int32 * 2)]


class VnodeInfoPath(ctypes.Structure):
    _fields_ = [('vip_vi', VnodeInfo), ('vip_path', ctypes.c_char * 1024)]


class ProcFileInfo(ctypes.Structure):
    _fields_ = [('fi_openflags', ctypes.c_uint32), ('fi_status', ctypes.c_uint32),
                ('fi_offset', ctypes.c_int64), ('fi_type', ctypes.c_int32), ('fi_guardflags', ctypes.c_uint32)]


class VnodeFdInfoWithPath(ctypes.Structure):
    _fields_ = [('pfi', ProcFileInfo), ('pvip', VnodeInfoPath)]


assert os.getuid() == 501
for relative, expected in [('usr/include/sys/proc_info.h', 'e427fa96b348537b21552b9de71e01039410bcad2cedee5584c5e5fddafd70fc'),
                           ('usr/include/libproc.h', '246d87709fc6b9157ce5cf3c475656ac48e0e1ae8bbdc46cf45acd34294448cd')]:
    assert hashlib.sha256((SDK / relative).read_bytes()).hexdigest() == expected
assert ctypes.sizeof(VinfoStat) == 136 and ctypes.sizeof(VnodeFdInfoWithPath) == 1200
result = {'schema': 'otzaria.held-vnode-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'local_timezone': datetime.datetime.now().astimezone().tzname(),
          'local_utc_offset_seconds': int(datetime.datetime.now().astimezone().utcoffset().total_seconds()),
          'processes_before': processes(), 'writes': 0, 'signals': 0, 'payload_bytes_read': 0, 'builds': 0,
          'file_descriptor_metadata': []}
lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
lib.proc_pidfdinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
lib.proc_pidfdinfo.restype = ctypes.c_int
for pid, (expected_inode, expected_size) in EXPECTED_FDS.items():
    info = VnodeFdInfoWithPath()
    ctypes.set_errno(0)
    count = lib.proc_pidfdinfo(pid, 3, 2, ctypes.byref(info), ctypes.sizeof(info))
    row = {'pid': pid, 'fd': 3, 'api': 'proc_pidfdinfo(PROC_PIDFDVNODEPATHINFO)', 'return_bytes': count, 'errno': ctypes.get_errno()}
    if count == ctypes.sizeof(info):
        v = info.pvip.vip_vi.vi_stat
        assert (v.vst_dev, v.vst_ino, v.vst_size, v.vst_nlink) == (16777232, expected_inode, expected_size, 0)
        assert stat.S_ISREG(v.vst_mode) and v.vst_uid == 501
        row.update({'device': v.vst_dev, 'inode': v.vst_ino, 'nlink': v.vst_nlink, 'mode': v.vst_mode,
                    'uid': v.vst_uid, 'gid': v.vst_gid, 'size': v.vst_size, 'blocks': v.vst_blocks,
                    'optimal_io_block_size': v.vst_blksize, 'offset': info.pfi.fi_offset,
                    'openflags': info.pfi.fi_openflags, 'status': info.pfi.fi_status,
                    'mtime_seconds': v.vst_mtime, 'mtime_nsec': v.vst_mtimensec,
                    'ctime_seconds': v.vst_ctime, 'ctime_nsec': v.vst_ctimensec,
                    'birthtime_seconds': v.vst_birthtime, 'birthtime_nsec': v.vst_birthtimensec,
                    'path': bytes(info.pvip.vip_path).decode('utf-8', 'replace')})
    result['file_descriptor_metadata'].append(row)
raw = (SDK / 'usr/include/sys/stat.h').read_bytes()
result['stat_header'] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
                          'block_unit_lines': [line for line in raw.decode().splitlines() if 'st_blocks' in line or '512' in line]}


def small_receipt(path, kind):
    assert path.is_file() and not path.is_symlink() and path.stat().st_size < 16384
    raw = path.read_bytes()
    value = raw.decode().strip()
    if kind == 'exit':
        assert re.fullmatch(r'-?\d{1,3}', value)
    elif kind == 'sha':
        assert re.fullmatch(r'[0-9a-f]{40}', value)
    else:
        raise AssertionError(kind)
    return {'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'value': value,
            'mtime_ns': path.stat().st_mtime_ns}


def bounded_log(path):
    assert path.is_file() and not path.is_symlink() and path.stat().st_size < 32 * 1024 * 1024
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
        f.seek(max(0, path.stat().st_size - 65536))
        tail = f.read().decode('utf-8', 'replace').splitlines()
    selected = [x[:300] for x in tail if re.search(r'^\*\* (BUILD|TEST)|^[0-9]+ (error|warning)s? generated|^The following build commands failed:|^Testing (failed|started|cancelled)', x)
                and not re.search(r'token|password|secret|authorization|credential|bearer|cookie', x, re.I)]
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': h.hexdigest(),
            'selected_terminal_lines': selected[-20:], 'mtime_ns': path.stat().st_mtime_ns}


paired = BASE / 'actual-paired-production-release.Hguhbz1S'
ntx = BASE / 'session.ntx0UjXO/runner/_work/Maktabah/Maktabah/build/artifacts/runtime27'
result['historical_file_receipts'] = [small_receipt(paired / 'compile.exit', 'exit'),
                                     small_receipt(paired / 'source.txt', 'sha'),
                                     small_receipt(paired / 'preparation-checkout.txt', 'sha'),
                                     small_receipt(ntx / 'checkout.txt', 'sha')]
result['historical_log_receipts'] = [bounded_log(paired / 'apple-release-build.log'),
                                    bounded_log(ntx / 'build-for-testing-driver.log'),
                                    bounded_log(ntx / 'release-prototype-build.log')]
result['historical_result_metadata'] = []
for path in [ntx / 'release-build-result.json', ntx / 'release-manifest.json']:
    raw = path.read_bytes()
    assert len(raw) < 256 * 1024
    data = json.loads(raw)
    fields = {}
    for key, value in data.items():
        if re.search(r'(status|exit|source|commit|sha|created|started|finished|configuration|result)', key, re.I) and not re.search(r'(secret|token|credential)', key, re.I):
            if value is None or isinstance(value, (bool, int, float)) or (isinstance(value, str) and len(value) < 512):
                fields[key] = value
    result['historical_result_metadata'].append({'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
                                                 'top_level_keys': sorted(data), 'safe_scalar_fields': fields})
result['processes_after'] = processes()
assert result['processes_before'] == result['processes_after']
result['retirement_not_authorized'] = True
result['apfs_exclusive_private_bytes_not_available_from_this_metadata_api'] = True
print(json.dumps(result, sort_keys=True))
