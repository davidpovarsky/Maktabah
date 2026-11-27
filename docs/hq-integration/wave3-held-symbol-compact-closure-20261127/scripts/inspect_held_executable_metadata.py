import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import stat
import subprocess

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
EXPECTED = {18664: (1, 'Thu Nov 26 21:12:58 2026'), 18665: (18664, 'Thu Nov 26 21:12:58 2026'),
            35619: (1, 'Thu Nov 26 17:01:38 2026'), 35620: (35619, 'Thu Nov 26 17:01:38 2026'),
            41371: (1, 'Thu Nov 26 17:09:32 2026'), 41372: (41371, 'Thu Nov 26 17:09:32 2026')}
REPOS = [BASE / 'actual-paired-production-release.Hguhbz1S/Maktabah',
         BASE / 'session.ntx0UjXO/runner/_work/Maktabah/Maktabah']
APP_REL = 'build/ReleaseDerivedData/Build/Products/Release-iphonesimulator/Maktabah.app/Maktabah'
APP_PATHS = [str(p / APP_REL) for p in REPOS]


def identity(path):
    s = path.lstat()
    return {'path': str(path), 'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'uid': s.st_uid, 'gid': s.st_gid, 'bytes': s.st_size, 'allocated_bytes': s.st_blocks * 512,
            'nlink': s.st_nlink, 'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def run(argv, timeout=25):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    return {'exit': p.returncode, 'stdout': p.stdout.decode('utf-8', 'replace'),
            'stderr': p.stderr.decode('utf-8', 'replace')}


def processes():
    p = run(['/bin/ps', '-p', ','.join(map(str, sorted(EXPECTED))),
             '-o', 'pid=,ppid=,lstart=,etime=,state=,time=,%cpu=,rss=,comm='])
    rows = []
    for line in p['stdout'].splitlines():
        parts = line.split(None, 12)
        assert len(parts) == 13, parts
        pid, ppid = int(parts[0]), int(parts[1])
        start = ' '.join(parts[2:7])
        assert pid in EXPECTED and (ppid, start) == EXPECTED[pid], (pid, ppid, start)
        command = parts[12]
        assert command == '/bin/sh' if pid in [18664, 35619, 41371] else command.endswith('/Pods/FirebaseCrashlytics/upload-symbols')
        rows.append({'pid': pid, 'ppid': ppid, 'start': start, 'elapsed': parts[7],
                     'state': parts[8], 'cpu_time': parts[9], 'percent_cpu': parts[10],
                     'rss_kib': int(parts[11]), 'command': command})
    return {'exit': p['exit'], 'rows': rows, 'missing_pids': sorted(set(EXPECTED) - {r['pid'] for r in rows})}


def children(path):
    if not path.is_dir() or path.is_symlink():
        return None
    rows = []
    for p in sorted(path.iterdir()):
        if p.name.startswith(('.credentials', '.runner')):
            continue
        rows.append({'name': p.name, 'identity': identity(p),
                     'symlink_target': os.readlink(p) if p.is_symlink() else None})
    return rows


assert os.getuid() == 501
result = {'schema': 'otzaria.held-original-app-readonly/1',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'host': socket.gethostname(),
          'writes': 0, 'deletions': 0, 'signals': 0, 'builds': 0, 'process_arguments_read': False,
          'environment_read': False, 'file_payload_read': False}
result['processes_before'] = processes()
assert not result['processes_before']['missing_pids'], 'Known process ended; do not infer PID ownership'
p = run(['/usr/sbin/lsof', '-nP', '-a', '-p', ','.join(map(str, sorted(EXPECTED))), '-FpcfDtiskon'])
records = []
pid = command = None
file = None


def finish():
    if file and file.get('n') in APP_PATHS:
        records.append({'pid': pid, 'command': command, 'fields': dict(file)})


for line in p['stdout'].splitlines():
    if not line:
        continue
    kind, value = line[0], line[1:]
    if kind == 'p':
        finish()
        file = None
        pid = int(value)
    elif kind == 'c':
        command = value
    elif kind == 'f':
        finish()
        file = {'f': value}
    elif file is not None:
        file[kind] = value
finish()
result['held_app_lsof'] = {'exit': p['exit'], 'records': records,
                           'stderr_bytes': len(p['stderr'].encode()),
                           'stderr_sha256': hashlib.sha256(p['stderr'].encode()).hexdigest(),
                           'only_two_original_app_paths_retained': True}
result['current_app_path_state'] = [{'path': path, 'lexists': os.path.lexists(path),
                                     'identity': identity(Path(path)) if os.path.lexists(path) else None}
                                    for path in APP_PATHS]
result['original_owner_metadata'] = []
for repo in REPOS:
    row = {'repository': identity(repo), 'head': run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'rev-parse', 'HEAD']),
           'build_children': children(repo / 'build')}
    if repo == REPOS[0]:
        row['paired_parent_children'] = children(repo.parent)
    row['artifact_children'] = children(repo / 'build/artifacts')
    row['runtime27_artifact_children'] = children(repo / 'build/artifacts/runtime27')
    result['original_owner_metadata'].append(row)

# Read only the installed declarations needed to interpret vnode/fd metadata.
sdk = run(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'])
assert sdk['exit'] == 0
sdk_path = Path(sdk['stdout'].strip())
headers = []
for relative, names in [('usr/include/sys/proc_info.h', ['struct proc_fileinfo', 'struct vinfo_stat', 'struct vnode_info', 'struct vnode_info_path', 'struct vnode_fdinfowithpath', 'PROC_PIDFDVNODEPATHINFO']),
                        ('usr/include/libproc.h', ['proc_pidfdinfo', 'proc_pidinfo'])]:
    path = sdk_path / relative
    raw = path.read_bytes()
    text = raw.decode()
    lines = text.splitlines()
    excerpts = []
    for i, line in enumerate(lines):
        if any(name in line for name in names):
            excerpts.append({'line': i + 1, 'text': '\n'.join(lines[max(0, i - 1):min(len(lines), i + 38)])})
    headers.append({'path': str(path), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
                    'selected_declarations': excerpts})
result['installed_declarations'] = headers
result['processes_after'] = processes()
assert [(x['pid'], x['ppid'], x['start']) for x in result['processes_before']['rows']] == [(x['pid'], x['ppid'], x['start']) for x in result['processes_after']['rows']]
result['historical_build_closure_not_yet_established_for_detached_children'] = True
print(json.dumps(result, sort_keys=True))
