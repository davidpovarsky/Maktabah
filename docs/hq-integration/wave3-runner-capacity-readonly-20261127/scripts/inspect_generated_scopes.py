import datetime
import hashlib
import json
import os
from pathlib import Path
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


def run(argv, timeout=40):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    return {'argv': argv, 'exit': p.returncode, 'stdout': p.stdout.decode('utf-8', 'replace'),
            'stderr': p.stderr.decode('utf-8', 'replace')}


def directory(path):
    if not path.is_dir() or path.is_symlink():
        return None
    result = []
    for p in sorted(path.iterdir()):
        if p.name.startswith(('.credentials', '.runner')):
            continue
        s = p.lstat()
        result.append({'name': p.name, 'identity': identity(p),
                       'symlink_target': os.readlink(p) if stat.S_ISLNK(s.st_mode) else None})
    return result


assert os.getuid() == 501 and BASE.is_dir() and not BASE.is_symlink()
roots = [BASE / n for n, _ in ROOTS]
result = {'schema': 'otzaria.three-runner-generated-scope-readonly/1',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'host': socket.gethostname(),
          'writes': 0, 'builds': 0, 'deletions': 0, 'roots': [], 'credential_contents_read': False}
v = os.statvfs(BASE)
result['free_before'] = v.f_bavail * v.f_frsize
for name, expected in ROOTS:
    root = BASE / name
    before = identity(root)
    assert before['inode'] == expected and stat.S_ISDIR(before['mode']) and not root.is_symlink()
    repo = root / 'runner/_work/Maktabah/Maktabah'
    assert repo.is_dir() and not repo.is_symlink()
    row = {'identity': before, 'repository': identity(repo),
           'repository_du_one_level': run(['/usr/bin/du', '-k', '-d', '1', str(repo)]),
           'build_children': directory(repo / 'build')}
    if (repo / 'build').is_dir() and not (repo / 'build').is_symlink():
        row['build_du_two_levels'] = run(['/usr/bin/du', '-k', '-d', '2', str(repo / 'build')])
    row['immutable_head'] = run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), 'rev-parse', 'HEAD'])
    alt = repo / '.git/objects/info/alternates'
    row['own_git_alternates'] = None
    if alt.is_file() and not alt.is_symlink():
        assert alt.stat().st_size < 16384
        raw = alt.read_bytes()
        row['own_git_alternates'] = {'identity': identity(alt), 'sha256': hashlib.sha256(raw).hexdigest(),
                                     'paths': raw.decode().splitlines()}
    assert identity(root) == before
    result['roots'].append(row)

# One bounded open-file query; only exact scoped paths are retained or printed.
# No process argv, environment, runner credential/registration contents, or foreign files are returned.
p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], stdout=subprocess.PIPE,
                   stderr=subprocess.PIPE, timeout=45)
matches = []
pid = command = fd = None
for line in p.stdout.decode('utf-8', 'replace').splitlines():
    if not line:
        continue
    kind, value = line[0], line[1:]
    if kind == 'p':
        pid, command, fd = value, None, None
    elif kind == 'c':
        command = value
    elif kind == 'f':
        fd = value
    elif kind == 'n' and any(value == str(root) or value.startswith(str(root) + '/') for root in roots):
        if any(part.startswith(('.credentials', '.runner')) for part in Path(value).parts):
            value = '[SCOPED_CREDENTIAL_PATH_OMITTED]'
        matches.append({'pid': int(pid), 'command': command, 'fd': fd, 'path': value})
result['open_file_query'] = {'exit': p.returncode, 'matching_open_paths': matches,
                            'stderr_bytes': len(p.stderr), 'stderr_sha256': hashlib.sha256(p.stderr).hexdigest(),
                            'unrelated_open_paths_not_retained': True}
matching_pids = sorted({m['pid'] for m in matches})
result['matching_process_identities'] = run(['/bin/ps', '-p', ','.join(map(str, matching_pids)),
                                           '-o', 'pid=,ppid=,lstart=,comm=']) if matching_pids else None
v = os.statvfs(BASE)
result['free_after'] = v.f_bavail * v.f_frsize
result['preservation_or_retirement_not_authorized'] = True
print(json.dumps(result, sort_keys=True))
