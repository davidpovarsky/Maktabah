"""Preserve completed closed-control relocation proof without rerunning controls."""
from pathlib import Path
import datetime, hashlib, json, os, stat, subprocess

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE = 'c24eae33049e83a800d80e61948f1d1d800e9bc7'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
CONTROL = Path('/home/ubuntu/otzaria-wave3-closed-controls-relocation-controller-20261127')
EVIDENCE = Path('/home/ubuntu/otzaria-wave3-closed-controls-relocated-20261127')
REL = 'docs/hq-integration/wave3-closed-controls-relocation-20261127'
OUT = ROOT / REL
PINS = {'PLAN.json': '276c2a46ecfd64a1b99faa604bc1e7ee091d5c0bf0fe2c6ebf91eadbd5399c74',
        'PREPARED.json': '3839447e40bbec67c26e0f2d0af10cf2b31aac912fe4b0051b36548a5c38fbf9',
        'CUTOVER_RESULT.json': '45383c2a0fe849e8e62947d5a701e8111882bb602e3cb651e43d98e6a0d8de5b'}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def free(path):
    s = os.statvfs(path)
    return s.f_bavail * s.f_frsize

def git(*args, timeout=60):
    p = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0',
                        '-c', 'maintenance.auto=false', '-C', str(ROOT), *args],
                       capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError((args, p.returncode, p.stderr.decode(errors='replace')[:3000]))
    return p.stdout

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as f:
        f.write(data); f.flush(); os.fsync(f.fileno())
    os.chown(path, 1001, 1001)

assert free('/') >= 1593835520 + 33554432
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
original_top = [x for x in git('ls-tree', 'HEAD').decode().splitlines()
                if x.split('\t', 1)[1] != 'docs']
prepared_raw = (EVIDENCE / 'PREPARED.json').read_bytes()
cutover_raw = (EVIDENCE / 'CUTOVER_RESULT.json').read_bytes()
assert sha(prepared_raw) == PINS['PREPARED.json']
assert sha(cutover_raw) == PINS['CUTOVER_RESULT.json']
prepared, cutover = json.loads(prepared_raw), json.loads(cutover_raw)
assert prepared['status'] == 'FULL_COPY_AND_METADATA_VERIFIED_DATA_ORIGINS_UNCHANGED'
assert cutover['status'] == 'EXACT_CLOSED_CONTROLS_RELOCATED_ALL_ORIGINAL_PATH_ALIASES_VERIFIED'
assert cutover['preparedSHA256'] == PINS['PREPARED.json']
assert len(prepared['scopes']) == len(cutover['scopes']) == 15
assert prepared['allocatedSourceBytes'] == cutover['allocatedBytesRelocated'] == 363614208
assert cutover['uniqueEvidenceDeleted'] == cutover['builds'] == cutover['testRuns'] == 0
entries = 0
alias_records = []
for index, row in enumerate(prepared['scopes']):
    raw = (EVIDENCE / ('MANIFEST-%02d.json' % index)).read_bytes()
    assert sha(raw) == row['manifestSHA256']
    manifest = json.loads(raw)
    assert manifest['source'] == row['source'] and manifest['destination'] == row['destination']
    assert len(manifest['original']) == len(manifest['copied']) == row['entries']
    entries += row['entries']
    origin, destination = Path(row['source']), Path(row['destination'])
    assert origin.is_symlink() and origin.resolve(strict=True) == destination
    assert destination.is_dir() and destination.parent == EVIDENCE
    assert not os.path.lexists(origin.with_name(origin.name + '.verified-relocation-20261127'))
    alias_records.append({'source': str(origin), 'destination': str(destination),
                          'symlinkText': os.readlink(origin), 'aliasVerified': True})
assert entries == 2150
payload = {}
for path in sorted(EVIDENCE.iterdir()):
    if path.is_dir():
        continue
    assert stat.S_ISREG(path.lstat().st_mode) and not path.is_symlink()
    assert path.suffix in ('.json', '.py')
    payload['completed/' + path.name] = path.read_bytes()
for path in sorted(CONTROL.rglob('*')):
    if path.is_dir():
        continue
    assert stat.S_ISREG(path.lstat().st_mode) and not path.is_symlink()
    rel = str(path.relative_to(CONTROL))
    assert not rel.startswith('__pycache__/')
    payload['controller/' + rel] = path.read_bytes()
assert sha(payload['controller/PLAN.json']) == PINS['PLAN.json']
assert sha(payload['controller/relocate_closed_controls.py']) == 'fa0ea1728f77e0481c7098629d64c80efd75638b97a948398ef28f1a57f54d57'
assert sha(payload['controller/PEER_SOURCE_REVIEW_FINAL.json']) == '26f04ffee6f7876321db96965149a1f351e2d957743d69464391f7a374c051ad'
assert sum(map(len, payload.values())) <= 16777216
assert not OUT.exists()
for rel, raw in payload.items():
    write(OUT / rel, raw)
write(OUT / 'PRESERVATION_CONTROLLER.py', Path(__file__).read_bytes())
record = {'schema': 'otzaria.closed-controls.relocation-preservation.v1',
          'status': 'COMPLETED_RELOCATION_PROOF_PRESERVED_ORIGINAL_ALIASES_REVERIFIED',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'integrationBase': BASE, 'allNonDocumentationRootEntries': original_top,
          'sourceTree': git('rev-parse', 'HEAD:Source').decode().strip(),
          'actualPrepareJob': 'job_b8edcfda17a1', 'actualCutoverJob': 'job_125eb3c41295',
          'preparedSHA256': PINS['PREPARED.json'], 'cutoverSHA256': PINS['CUTOVER_RESULT.json'],
          'scopes': 15, 'manifestEntries': entries, 'allocatedBytesRelocated': 363614208,
          'aliases': alias_records,
          'files': [{'path': rel, 'bytes': len(raw), 'sha256': sha(raw)} for rel, raw in sorted(payload.items())],
          'uniqueEvidenceDeleted': 0, 'builds': 0, 'testRuns': 0,
          'guardFloorsUnchanged': {'root': 1342177280, 'data': 2147483648},
          'limitations': ['Filesystem capacity readings are concurrent observations.',
                          'The completed cutover still left Data below its unchanged admission floor.',
                          'This documentation checkpoint does not admit a compiler or rerun controls.',
                          'All original preserved payloads remain at exact rootfs destinations behind original-path symlinks.']}
write(OUT / 'PRESERVATION.json', (json.dumps(record, indent=2) + '\n').encode())
write(OUT / 'README.md', b'''# Completed closed-control relocation

Fifteen exact ROOT-owned closed control scopes were copied with full content and
metadata verification. All 2,150 inventory entries, preparation and cutover
journals, original receipt hashes, independent source reviews and controllers
are preserved here. The original paths remain usable through verified symlinks.

The 363,614,208 allocated bytes belong to already completed controls. No active
compiler product, foreign worktree, Git mirror, native source or unique evidence
was deleted. Both original capacity floors remain unchanged. The completed
cutover still left Data below its floor and did not authorize any test or build.

The three concrete source-review concerns and the initial draft remain available
alongside the corrected controller. This checkpoint verifies the completed
receipt chain and current aliases; it does not rerun the original controls.
''')
for parent, dirs, files in os.walk(OUT):
    os.chown(parent, 1001, 1001)
    for name in dirs:
        os.chown(Path(parent) / name, 1001, 1001)
    fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
assert free('/') >= 1593835520
git('add', '--sparse', '--force', '--', REL)
changed = git('diff', '--cached', '--name-only').decode().splitlines()
assert changed and all(x.startswith(REL + '/') for x in changed)
assert set(changed) == {str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file()}
git('diff', '--cached', '--check')
git('-c', 'user.name=ChatGPT', '-c', 'user.email=chatgpt-agent@users.noreply.github.com',
    'commit', '-m', 'docs: preserve verified closed-control relocation and original aliases')
head = git('rev-parse', 'HEAD').decode().strip()
assert [x for x in git('ls-tree', 'HEAD').decode().splitlines()
        if x.split('\t', 1)[1] != 'docs'] == original_top
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
    'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {'status': 'RELOCATION_DOCUMENTATION_COMMITTED_PUSHED', 'head': head,
          'changedPaths': len(changed), 'nonDocumentationRootEntriesUnchanged': True,
          'preservationSHA256': sha((OUT / 'PRESERVATION.json').read_bytes()),
          'rootFreeAfter': free('/'), 'dataFreeObservedAfter': free('/mnt/development'),
          'builds': 0, 'testRuns': 0}
write(CONTROL / 'GIT_PRESERVATION_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
