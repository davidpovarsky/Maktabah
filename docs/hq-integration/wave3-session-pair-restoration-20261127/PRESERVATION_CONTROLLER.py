"""Preserve the actual session-pair restoration pointer before any retirement."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')

from pathlib import Path
import datetime
import hashlib
import json
import os
import stat
import subprocess

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE = '4cc6b3627826d7e30d1c74b9dcbeaebd1641f878'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
ATTEMPT = 'f0d875eb-2b71-49af-a2f9-1f2f7b85c792'
PREP = Path('/home/ubuntu/otzaria-wave3-private-session-pair-publication-20261127') / ('retire-' + ATTEMPT)
STAGED = Path('/home/ubuntu/otzaria-wave3-session-pair-restoration-tools-20261127')
TRANSFER = Path('/home/ubuntu/otzaria-wave3-session-pair-restoration-proof-20261127')
REL = 'docs/hq-integration/wave3-session-pair-restoration-20261127'
OUT = ROOT / REL
PINS = {
    'PREDELETE.json': '93738162a5ffc0f36cffe31eb2638cfa37081140477536ba9355a4f892c043ba',
    'RESTORATION_POINTER.json': '82f75ca26fcd83af71031383168879ad774153d8fad2fddee96be68b908471db',
    'restore_session_pair_differential.py': '0c70a1f0801f777b47b1ffb1589da49172b91273437a4eb367fc15c45dbafa39',
    'retire_session_pair_differential.py': '3118489cb4e9e344e4b5d507f1471cf8bcf23c4ccfd7ee07011729ec5c564eed',
    'VERIFIED_PRIVATE_SESSION_PAIR_TRANSPORT.json': '0c07d1c5b25136331d7790f88436aef3a3d7aef5b82e4cd23ca61ba848ffb05a',
    'PRESERVED_SESSION_PAIR_MANIFEST.json': '47755d066e979027fecb45944a236f5284addc62644a9b44a9487f5e9919c0f7',
    'SESSION_PAIR_TRANSPORT_TERMINAL_JOB.json': 'b9ff599b5da607379f5cd6535c7a04db5e6c5e043d1eb4852e3b2be214e19257',
    'SESSION_PAIR_FINAL_RECEIPT_PUBLISHED.json': '3005be20cf8c2f2ff26f64597f6726709f53df4900a97948326bc93999e6960c',
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def free(path):
    s = os.statvfs(path)
    return s.f_bavail * s.f_frsize


def read(path, maximum=1048576):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        assert stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= maximum
        with os.fdopen(os.dup(fd), 'rb') as f:
            raw = f.read(maximum + 1)
        after = os.fstat(fd)
        assert len(raw) == before.st_size
        assert (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) == (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        return raw
    finally:
        os.close(fd)


def git(*args, timeout=60, input_data=None, allowed=(0,)):
    result = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0',
        '-c', 'maintenance.auto=false', '-C', str(ROOT), *args],
        input=input_data, capture_output=True, timeout=timeout)
    if result.returncode not in allowed:
        raise RuntimeError((args, result.returncode, result.stderr.decode(errors='replace')[:2000]))
    return result.stdout


def write(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as f:
        f.write(raw)
        f.flush()
        os.fsync(f.fileno())
    os.chown(path, 1001, 1001)


assert free('/') >= 1593835520 + 4194304
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
assert git('rev-parse', 'HEAD:Source').decode().strip() == 'c62aa1a24c1a10fb5129c25d6869faa00c9a3dfb'
top = [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs']
payload = {}
for name, expected in PINS.items():
    raw = read(PREP / name)
    assert sha(raw) == expected, name
    payload['prepared/' + name] = raw
pre = json.loads(payload['prepared/PREDELETE.json'])
pointer = json.loads(payload['prepared/RESTORATION_POINTER.json'])
receipt = json.loads(payload['prepared/VERIFIED_PRIVATE_SESSION_PAIR_TRANSPORT.json'])
assert pre['status'] == 'PREPARED_ORIGINAL_RETAINED' and pre['removed'] is False
assert pre['sourceIdentity'] == pointer['originalLeafIdentity'] == receipt['sourceIdentity']
assert len(pre['protectedSiblings']) == pointer['metadataMemberCount'] == 12
assert pre['noUse']['inspectionErrors'] == 0 and pre['noUse']['matches'] == []
assert pre['freshRemoteIdentity']['repositoryID'] == 1474927804
assert pre['freshRemoteIdentity']['private'] is True and pre['freshRemoteIdentity']['draft'] is True
assert pre['freshRemoteIdentity']['releaseID'] == 461122448
assert pointer['leafRestoreMetadata']['xattrs'] == [] and receipt['sourceRestoreMetadata']['xattrs'] == {}
assert str(pointer['leafRestoreMetadata']['atime_ns']) == receipt['sourceRestoreMetadata']['atime_ns'] == '1795770120148876083'
assert pre['transportCompletion'] == pointer['transportCompletion']
assert pointer['unchangedExternalDependencies'] == pre['unchangedExternalDependencies'] == receipt['unchangedExternalDependencies']
assert pre['selfContained'] is False and pointer['fullTreeRestoration'] is False
assert pointer['restorationScriptSHA256'] == PINS['restore_session_pair_differential.py']
source = Path(pre['sourceDirectory']) / pre['leaf']
s = source.lstat()
assert stat.S_ISREG(s.st_mode) and s.st_nlink == 1
assert {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
        'uid': s.st_uid, 'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode), 'nlink': s.st_nlink,
        'mtime_ns': str(s.st_mtime_ns), 'ctime_ns': str(s.st_ctime_ns)} == pre['sourceIdentity']
packet = json.loads(read(TRANSFER / 'LOCAL_PACKET.json'))
assert packet['actualPrepareJob'] == 'job_1d707ab36360'
for row in packet['files']:
    path = Path(row['path'])
    assert not path.is_absolute() and '..' not in path.parts
    raw = read(TRANSFER / 'files' / path)
    assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
    assert str(path) not in payload
    payload[str(path)] = raw
actual = json.loads(payload['transport/ACTUAL_PREPARE_JOB.json'])
assert actual['job']['id'] == 'job_1d707ab36360' and actual['job']['status'] == 'succeeded' and actual['job']['exit_code'] == 0
terminal = json.loads(payload['prepared/SESSION_PAIR_TRANSPORT_TERMINAL_JOB.json'])
assert terminal['job']['id'] == 'job_429fd8747557' and terminal['job']['status'] == 'succeeded' and terminal['job']['exit_code'] == 0
assert sum(map(len, payload.values())) < 2097152
assert not OUT.exists()
for name, raw in payload.items():
    write(OUT / name, raw)
write(OUT / 'PRESERVATION_CONTROLLER.py', read(Path(__file__)))
record = {
    'schema': 'otzaria.pinned-session-pair-restoration-git-preparation.v1',
    'status': 'RESTORATION_POINTER_AND_PREDELETE_PRESERVED_ORIGINAL_DIFFERENTIAL_RETAINED',
    'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'integrationBase': BASE,
    'allNonDocumentationRootEntries': top, 'actualPrepareJob': 'job_1d707ab36360',
    'actualTransportJob': 'job_429fd8747557', 'attempt': ATTEMPT, 'verifiedPins': PINS,
    'protectedMetadataSiblings': 12, 'selfContained': False, 'fullTreeRestoration': False,
    'restorationExecutions': 0, 'localRetirement': False, 'SDKBuilds': 0, 'nativeRuns': 0,
    'files': [{'path': name, 'bytes': len(raw), 'sha256': sha(raw)} for name, raw in sorted(payload.items())],
    'nextGate': 'Root independently reads the committed exact pointer and PREDELETE before any acknowledged single-leaf commit; that commit repeats live private/source/sibling/no-use guards.',
}
write(OUT / 'PRESERVATION.json', (json.dumps(record, indent=2) + '\n').encode())
write(OUT / 'README.md', b'''# Actual differential preservation and exact restoration pointer

The same private draft upload completed in job_429fd8747557 with exit0.
All three assets received full authenticated byte readbacks. The final receipt
and final-publication marker are both bound, and the failed original attempt
remains preserved in the previous integration checkpoint.

Preparation job_1d707ab36360 completed with exit0. It verified the original
archive identity and full hash, twelve exact metadata siblings, current private
asset identities and absence of active file/mapping holders. The original
archive still exists. This checkpoint makes no retirement or build claim.

The differential has four unchanged historical Windows base dependencies.
It is not self-contained. No full tree has been restored. The restoration tool
can recreate only the exact archive leaf, preserving original mode/owner/times
and verifying all three authenticated payloads. Original inode and ctime are
evidence and cannot be recreated. Restoration has not been executed.

The separate retirement command requires this exact committed PREDELETE and
fresh private/source/sibling/no-use checks before its sole named leaf unlink.
The full raw preparation and transport journals and all source reviews are
preserved losslessly as ZIP files. The scripts, pointer and terminal proofs
are also directly reviewable in prepared/. No Apple app is distributed here.
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
paths = sorted(str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file())
ignored = set(git('check-ignore', '-z', '--stdin', input_data=('\0'.join(paths) + '\0').encode(), allowed=(0, 1)).decode().split('\0')) - {''}
ordinary = [p for p in paths if p not in ignored]
if ordinary:
    git('add', '--sparse', '--', *ordinary)
if ignored:
    git('add', '--sparse', '--force', '--', *sorted(ignored))
changed = git('diff', '--cached', '--name-only').decode().splitlines()
assert set(changed) == set(paths) and all(p.startswith(REL + '/') for p in changed)
git('diff', '--cached', '--check')
git('-c', 'user.name=ChatGPT', '-c', 'user.email=chatgpt-agent@users.noreply.github.com',
    'commit', '-m', 'docs: preserve actual session-pair transport and exact restoration pointer')
head = git('rev-parse', 'HEAD').decode().strip()
assert [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs'] == top
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
committed = {}
for name, expected in PINS.items():
    digest = sha(git('show', 'HEAD:' + REL + '/prepared/' + name))
    assert digest == expected
    committed[name] = digest
git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
    'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {
    'status': 'SESSION_PAIR_RESTORATION_PREPARATION_COMMITTED_PUSHED_AND_READ_BACK',
    'head': head, 'changedPaths': len(changed), 'nonDocumentationRootEntriesUnchanged': True,
    'committedPinsReadBack': committed, 'preservationSHA256': sha(read(OUT / 'PRESERVATION.json')),
    'rootFreeAfter': free('/'), 'dataFreeObservedAfter': free('/mnt/development'),
    'localRetirement': False, 'restorationExecutions': 0, 'builds': 0, 'nativeRuns': 0,
}
write(TRANSFER / 'GIT_PRESERVATION_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
