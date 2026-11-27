import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
COMMON = BASE / 'compact-reader-preview-worktree.5hRb5SYt/Maktabah/.git'
WORKTREES = [BASE / 'exact-three-sdk-transport-verification.5DfXvIjL/Host',
             BASE / 'reviewed-new-original-simulator-sdk-host-admission.nw59FCm9/Maktabah']


def ident(path):
    s = path.lstat()
    return {'path': str(path), 'inode': s.st_ino, 'device': s.st_dev, 'mode': s.st_mode,
            'bytes': s.st_size, 'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def run(argv):
    p = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=25)
    return {'exit': p.returncode, 'stdout': p.stdout.decode('utf-8', 'replace'), 'stderr': p.stderr.decode('utf-8', 'replace')}


def small_metadata(path):
    s = path.lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_size > 1048576 or path.suffix not in ['.json', '.exit', '.txt', '.log']:
        return None
    if re.search(r'credential|secret|environment', path.name, re.I):
        return None
    raw = path.read_bytes()
    row = {'identity': ident(path), 'sha256': hashlib.sha256(raw).hexdigest()}
    if path.suffix == '.json':
        try:
            data = json.loads(raw)
            if isinstance(data, dict):
                row['top_keys'] = sorted(data)
                row['safe_scalar_fields'] = {k: v for k, v in data.items()
                    if re.search(r'^(status|exit_code|returncode|source_sha|source_commit|checkout_sha|created_at|started_at|finished_at|configuration|test_source_commit|application_source|exact_build_checkout)$', k)
                    and (v is None or isinstance(v, (int, bool)) or isinstance(v, str) and len(v) < 128)}
        except ValueError:
            row['not_json'] = True
    elif path.suffix in ['.txt', '.exit']:
        text = raw.decode().strip()
        if re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}|-?\d{1,3}', text):
            row['source_or_exit_value'] = text
    else:
        lines = raw.decode('utf-8', 'replace').splitlines()
        row['terminal_lines'] = [x[:300] for x in lines if re.search(r'^\*\* (BUILD|TEST)|^The following build commands failed:', x)
                                 and not re.search(r'token|password|secret|authorization|credential|bearer|cookie', x, re.I)][-8:]
    return row


assert os.getuid() == 501
result = {'schema': 'otzaria.compact-external-worktree-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'writes': 0, 'signals': 0, 'deletions': 0, 'builds': 0, 'common_git_identity': ident(COMMON), 'worktrees': []}
for repo in WORKTREES:
    row = {'path': str(repo), 'lexists': os.path.lexists(repo)}
    if repo.is_dir() and not repo.is_symlink():
        row['identity'] = ident(repo)
        p = repo / '.git'
        assert p.is_file() and not p.is_symlink() and p.stat().st_size < 16384
        raw = p.read_bytes()
        assert raw.startswith(b'gitdir: ')
        row['git_pointer'] = {'identity': ident(p), 'sha256': hashlib.sha256(raw).hexdigest(), 'value': raw.decode().strip()}
        for key, args in [('head', ['rev-parse', 'HEAD']), ('common_dir', ['rev-parse', '--git-common-dir']),
                          ('tracked_delta', ['status', '--porcelain=v1', '--untracked-files=no', '--ignore-submodules=all'])]:
            row[key] = run(['/usr/bin/git', '--no-optional-locks', '-C', str(repo), *args])
        parent = repo.parent
        row['parent'] = ident(parent)
        row['parent_children'] = [{'name': x.name, 'identity': ident(x)} for x in sorted(parent.iterdir())
                                   if not x.name.startswith(('.credentials', '.runner'))]
        row['original_receipts'] = []
        for p in sorted(parent.iterdir()):
            if p.is_file() and not p.is_symlink():
                item = small_metadata(p)
                if item:
                    row['original_receipts'].append(item)
    result['worktrees'].append(row)
p = subprocess.run(['/usr/sbin/lsof', '-nP', '-Fpcfn'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=35)
matches = []; pid = command = fd = None
for line in p.stdout.decode('utf-8', 'replace').splitlines():
    if not line: continue
    kind, value = line[0], line[1:]
    if kind == 'p': pid = int(value)
    elif kind == 'c': command = value
    elif kind == 'f': fd = value
    elif kind == 'n' and any(value == str(root) or value.startswith(str(root) + '/') for root in WORKTREES):
        matches.append({'pid': pid, 'command': command, 'fd': fd, 'path': value})
result['open_references'] = {'exit': p.returncode, 'matching_paths': matches, 'stderr_bytes': len(p.stderr),
                             'stderr_sha256': hashlib.sha256(p.stderr).hexdigest(), 'unrelated_paths_not_retained': True}
result['no_retirement_authorized'] = True
print(json.dumps(result, sort_keys=True))
