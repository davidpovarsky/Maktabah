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
ROOTS = [('session.ntx0UjXO', 59155998), ('session.XsIaHMlh', 60263108), ('session.FK20ACaB', 59894314)]


def identity(path):
    s = path.lstat()
    return {'path': str(path), 'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'uid': s.st_uid, 'gid': s.st_gid, 'bytes': s.st_size, 'allocated_bytes': s.st_blocks * 512,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def children(path):
    result = []
    if path.is_dir() and not path.is_symlink():
        for p in sorted(path.iterdir()):
            # Credential/registration files are outside this read scope.
            if p.name.startswith(('.credentials', '.runner')):
                continue
            s = p.lstat()
            result.append({'name': p.name, 'inode': s.st_ino, 'mode': s.st_mode,
                           'bytes': s.st_size, 'allocated_bytes': s.st_blocks * 512,
                           'symlink': os.readlink(p) if stat.S_ISLNK(s.st_mode) else None})
    return result


def du(path):
    if not path.is_dir() or path.is_symlink():
        return None
    p = subprocess.run(['/usr/bin/du', '-k', '-d', '1', str(path)], stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, timeout=35)
    return {'exit': p.returncode, 'allocated_kib_by_immediate_path': p.stdout.decode().splitlines(),
            'stderr': p.stderr.decode()}


def log_receipt(path):
    if not path.is_file() or path.is_symlink():
        return None
    s = path.stat()
    if s.st_size > 32 * 1024 * 1024:
        return {'identity': identity(path), 'read': 'BOUNDED_READ_DEFERRED_TOO_LARGE'}
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
        f.seek(max(0, s.st_size - 128 * 1024))
        tail = f.read().decode('utf-8', 'replace').splitlines()
    selected = []
    for line in tail:
        if re.search(r'token|password|secret|authorization|credential|bearer|cookie', line, re.I):
            continue
        if re.search(r'completed with result|[Ll]istening for [Jj]obs|[Rr]unning job:|[Ee]xecution ended|[Ee]xit(?:ed)? (?:with )?code|BUILD (?:SUCCEEDED|FAILED)|[Ff]inished with result', line):
            selected.append(line[:250])
    return {'identity': identity(path), 'sha256': h.hexdigest(), 'selected_terminal_or_job_lines': selected[-18:],
            'tail_bytes_max': 131072, 'credential_lines_omitted': True}


assert os.getuid() == 501 and BASE.is_dir() and not BASE.is_symlink()
result = {'schema': 'otzaria.three-runner-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'host': socket.gethostname(), 'scope': 'EXACT_THREE_ROOTS_READ_ONLY_NO_ARCHIVE_OR_RETIREMENT',
          'parent': identity(BASE), 'roots': [], 'writes': 0, 'deletions': 0, 'builds': 0}
v = os.statvfs(BASE)
result['free_before'] = v.f_bavail * v.f_frsize
for name, expected in ROOTS:
    root = BASE / name
    before = identity(root)
    assert before['inode'] == expected and stat.S_ISDIR(before['mode']) and not root.is_symlink()
    work = root / 'runner/_work'
    row = {'identity': before, 'top_children': children(root), 'runner_children': children(root / 'runner'),
           'work_children': children(work), 'work_du': du(work), 'logs': []}
    for p in [root / 'runner.log', root / 'runner.stdout.log', root / 'runner.stderr.log', root / 'runner/runner.log']:
        receipt = log_receipt(p)
        if receipt:
            row['logs'].append(receipt)
    # This is a name/inode inventory, not an archive or a dependency release.
    repositories = []
    if work.is_dir() and not work.is_symlink():
        for first in sorted(work.iterdir()):
            if first.name.startswith('_') or not first.is_dir() or first.is_symlink():
                continue
            for second in sorted(first.iterdir()):
                if second.is_dir() and not second.is_symlink() and len(repositories) < 8:
                    repositories.append({'identity': identity(second), 'children': children(second)})
    row['repository_candidates'] = repositories
    assert identity(root) == before
    result['roots'].append(row)
v = os.statvfs(BASE)
result['free_after'] = v.f_bavail * v.f_frsize
result['closed_or_reclaimable_not_yet_asserted'] = True
print(json.dumps(result, sort_keys=True))
