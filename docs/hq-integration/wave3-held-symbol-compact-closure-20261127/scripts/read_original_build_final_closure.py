import ast
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat

BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ATTEMPTS = ['actual-app-release-production.l99oRFHb', 'actual-app-release-production-retry.3Ay5HhXW',
            'actual-paired-production-release-expo-root.qliOcHpp', 'owner-verified-current-production-release.0Uv90ibO']
COMPACT = BASE / 'compact-reader-preview-worktree.5hRb5SYt'


def ident(path):
    s = path.lstat()
    return {'path': str(path), 'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
            'bytes': s.st_size, 'allocated_bytes': s.st_blocks * 512,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def children(path):
    if not path.is_dir() or path.is_symlink():
        return None
    return [{'name': p.name, 'identity': ident(p), 'symlink': os.readlink(p) if p.is_symlink() else None}
            for p in sorted(path.iterdir()) if not p.name.startswith(('.credentials', '.runner'))]


def receipt(path):
    s = path.lstat()
    if not stat.S_ISREG(s.st_mode) or s.st_size > 32 * 1024 * 1024:
        return None
    if path.suffix not in ['.exit', '.json', '.log', '.txt', '.py']:
        return None
    if path.name.startswith(('.credentials', '.runner')) or re.search(r'secret|credential|environment', path.name, re.I):
        return None
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    row = {'identity': ident(path), 'sha256': h.hexdigest()}
    if path.suffix == '.exit':
        raw = path.read_text().strip()
        if re.fullmatch(r'-?\d{1,3}', raw):
            row['exit_value'] = int(raw)
    elif path.suffix == '.log':
        with path.open('rb') as f:
            f.seek(max(0, s.st_size - 65536))
            lines = f.read().decode('utf-8', 'replace').splitlines()
        row['terminal_lines'] = [x[:320] for x in lines if re.search(r'^\*\* (BUILD|TEST)|^The following build commands failed:|^Testing (failed|started|cancelled)', x)
                                 and not re.search(r'token|password|secret|authorization|credential|bearer|cookie', x, re.I)][-12:]
    elif path.suffix == '.txt' and s.st_size <= 128:
        raw = path.read_text().strip()
        if re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', raw):
            row['source_digest_value'] = raw
    elif path.suffix == '.py' and s.st_size < 131072:
        # Static original source locators only; no command argv or environment output.
        try:
            tree = ast.parse(path.read_bytes())
            row['static_original_workspace_locators'] = sorted({x.value for x in ast.walk(tree)
                if isinstance(x, ast.Constant) and isinstance(x.value, str) and x.value.startswith(str(BASE))
                and '\n' not in x.value and len(x.value) < 512})
        except SyntaxError:
            row['static_parse'] = 'NOT_PARSED'
    elif path.suffix == '.json' and s.st_size < 1048576:
        try:
            data = json.loads(path.read_bytes())
            if isinstance(data, dict):
                row['top_level_keys'] = sorted(data)
                row['safe_scalar_fields'] = {k: v for k, v in data.items()
                    if re.search(r'^(status|exit_code|returncode|source_sha|source_commit|checkout_sha|created_at|started_at|finished_at|configuration|test_source_commit)$', k)
                    and (v is None or isinstance(v, (int, bool)) or isinstance(v, str) and len(v) < 128)}
        except (ValueError, UnicodeError):
            row['json_parse'] = 'NOT_JSON'
    assert ident(path) == row['identity']
    return row


assert os.getuid() == 501
result = {'schema': 'otzaria.original-build-final-closure-readonly/1', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'writes': 0, 'deletions': 0, 'signals': 0, 'builds': 0, 'attempts': []}
for name in ['actual-app-release-production.l99oRFHb/compile', 'actual-app-release-production-retry.3Ay5HhXW/compile']:
 root = BASE / name
 row = {'path': str(root), 'identity': ident(root), 'children': children(root), 'receipts': []}
 for p in sorted(root.iterdir()):
  if p.is_file() and not p.is_symlink():
   r = receipt(p)
   if r: row['receipts'].append(r)
 result['attempts'].append(row)
result['paired_result_receipts'] = []
for name in ['actual-paired-production-release-expo-root.qliOcHpp', 'owner-verified-current-production-release.0Uv90ibO']:
 p = BASE/name/'RESULT.json'
 raw=p.read_bytes(); data=json.loads(raw)
 assert len(raw)<4096
 result['paired_result_receipts'].append({'path': str(p), 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw), 'safe_fields': {k:v for k,v in data.items() if k in ['status','application_source','exact_build_checkout','executable_sha256','profile','runtime','version','build','original_sdk']}})
print(json.dumps(result,sort_keys=True))
