"""Commit the reviewed restoration pointer before any exact archive retirement."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')
from pathlib import Path
import base64, datetime, hashlib, json, os, stat, subprocess

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE = '3a665ae5d4a6ff0db78b356a5362d93e0f0fe408'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
ATTEMPT = '4e93087e-2565-441f-a6cb-9d33296cc916'
PREP = Path('/home/ubuntu/otzaria-wave3-private-evidence-publication-20261127') / ('retire-' + ATTEMPT)
STAGED = Path('/home/ubuntu/otzaria-wave3-private-archive-tools-20261127')
TRANSFER = Path('/home/ubuntu/otzaria-wave3-restoration-proof-20261127')
REL = 'docs/hq-integration/wave3-closed-native-restoration-20261127'
OUT = ROOT / REL
PINS = {'PREDELETE.json': '31be7ad1aeb4f672059edac8b57c04429da38f495eef0fb7aacc0401ff1486f5',
        'RESTORATION_POINTER.json': 'e89db2f5ee59d9dbc466eeffbc43beb64f145aa823a3071aa08d48424b3dbabc',
        'restore_closed_native_archive.py': '0338bf97de4ae6c88b53b5692b0a92320ba75159b6ef88cb94b5bc77bdf050b4',
        'retire_closed_native_archive.py': '5ad5afd70009fbe12c7779a8ecb5c42518a30b58c181d4f786a75734e02f5784',
        'VERIFIED_PRIVATE_PRESERVATION.json': 'c8eb38f53a7b704587523d330c1c1ac63a2dd17cf49900cebb7a9406b545c1ed',
        'PRESERVED_ARCHIVE_MANIFEST.json': 'e8e6210b7fd6e4a808ac851f8e2842df2db8ade6914a667ec6bd648a0adb87c5'}

def sha(b): return hashlib.sha256(b).hexdigest()
def free(path):
    s = os.statvfs(path)
    return s.f_bavail * s.f_frsize
def git(*args, timeout=60):
    r = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0', '-c', 'maintenance.auto=false',
                        '-C', str(ROOT), *args], capture_output=True, timeout=timeout)
    if r.returncode: raise RuntimeError((args, r.returncode, r.stderr.decode(errors='replace')[:3000]))
    return r.stdout
def write(path, b):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as f: f.write(b); f.flush(); os.fsync(f.fileno())
    os.chown(path, 1001, 1001)

assert free('/') >= 1593835520 + 4194304
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
original_top = [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs']
for name, expected in PINS.items(): assert sha((PREP / name).read_bytes()) == expected, name
pre = json.loads((PREP / 'PREDELETE.json').read_bytes())
pointer = json.loads((PREP / 'RESTORATION_POINTER.json').read_bytes())
assert pre['status'] == 'PREPARED_ORIGINAL_RETAINED' and pre['removed'] is False
assert pre['sourceIdentity'] == pointer['originalLeafIdentity']
assert pre['noUse']['inspectionErrors'] == 0 and pre['noUse']['matches'] == []
assert pre['freshRemoteIdentity']['repositoryID'] == 1474927804 and pre['freshRemoteIdentity']['private'] is True
assert pre['freshRemoteIdentity']['releaseID'] == 461088091 and pre['freshRemoteIdentity']['draft'] is True
assert len(pre['protectedSiblings']) == pointer['metadataMemberCount'] == 22
assert pointer['leafRestoreMetadata']['xattrs'] == [], 'Review any nonempty private xattrs before public proof'
assert pointer['restorationScriptSHA256'] == PINS['restore_closed_native_archive.py']
source = Path(pre['sourceDirectory']) / pre['leaf']
st = source.lstat()
assert stat.S_ISREG(st.st_mode) and st.st_nlink == 1
assert {'device': st.st_dev, 'inode': st.st_ino, 'size': st.st_size,
        'mtime_ns': st.st_mtime_ns, 'ctime_ns': st.st_ctime_ns} == pre['sourceIdentity']
payload = {}
for path in sorted(PREP.iterdir()):
    assert stat.S_ISREG(path.lstat().st_mode) and not path.is_symlink() and path.stat().st_size < 1048576
    assert not path.name.startswith('COMMIT') and not path.name.startswith('RETIREMENT')
    payload['prepared/' + path.name] = path.read_bytes()
for name in ('STAGING.json', 'PREPARE.stdout', 'PREPARE.stderr'):
    payload['transport/' + name] = (STAGED / name).read_bytes()
packet = json.loads((TRANSFER / 'LOCAL_PACKET.json').read_bytes())
for row in packet['files']:
    p = Path(row['path'])
    assert not p.is_absolute() and '..' not in p.parts
    b = base64.b64decode(row['base64'], validate=True)
    assert len(b) == row['bytes'] and sha(b) == row['sha256']
    payload['review/' + str(p)] = b
actual = packet['actualPrepareResult']
assert actual['job']['id'] == 'job_630724af9922' and actual['job']['status'] == 'succeeded' and actual['job']['exit_code'] == 0
payload['transport/ACTUAL_SENTINEL_PREPARE_RESULT.json'] = (json.dumps(actual, indent=2) + '\n').encode()
assert sum(map(len, payload.values())) < 2097152
assert not OUT.exists()
for name, b in payload.items(): write(OUT / name, b)
write(OUT / 'PRESERVATION_CONTROLLER.py', Path(__file__).read_bytes())
record = {'schema': 'otzaria.pinned-restoration-git-preparation.v1',
          'status': 'RESTORATION_POINTER_AND_PREDELETE_PRESERVED_ORIGINAL_ARCHIVE_RETAINED',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'integrationBase': BASE,
          'allNonDocumentationRootEntries': original_top, 'actualPrepareJob': 'job_630724af9922',
          'attempt': ATTEMPT, 'verifiedPins': PINS, 'protectedOriginalMetadataSiblings': 22,
          'optimizedPythonExpectedRefusals': 2, 'restorationExecutions': 0, 'localRetirement': False,
          'SDKBuilds': 0, 'nativeRuns': 0,
          'files': [{'path': p, 'bytes': len(b), 'sha256': sha(b)} for p, b in sorted(payload.items())],
          'nextGate': 'ROOT must independently read the committed pointer/PREDELETE hashes, then exact commit reruns all current source/no-use/private-asset guards before the sole leaf unlink.'}
write(OUT / 'PRESERVATION.json', (json.dumps(record, indent=2) + '\n').encode())
write(OUT / 'README.md', b'''# Pinned restoration before exact archive retirement

Actual preparation job_630724af9922 completed with exit0. The original archive
is still present. The exact private release and all three asset identities,
source inode/ctime/full hash, all22 metadata siblings, and absence of current
archive holders were verified. The pointer and scripts were fsynced and read
back before PREDELETE was written. Their exact hashes are preserved here.

The restoration script recreates only the original archive leaf, verifies all
three full authenticated payloads and metadata members, and never extracts the
Mac/source payload. Its actual restoration has not been run. It requires the
original2GiB Data reserve plus space for the archive. Original mode/owner/times
are preserved; original inode and ctime are evidence and cannot be recreated.

Both tools refuse optimized Python before imports or actions. The initial
source drafts and review finding are retained, together with two actual local
expected-refusal checks. Those checks are not remote or native executions.

The separate commit phase still requires this exact PREDELETE acknowledgement,
fresh private/source/sibling/no-use checks and the pinned parent directory.
It may unlink only the named archive leaf. This Git checkpoint performs no
retirement, test, SDK build, native run or application distribution.
''')
for parent, dirs, files in os.walk(OUT):
    os.chown(parent, 1001, 1001)
    for name in dirs: os.chown(Path(parent) / name, 1001, 1001)
    fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try: os.fsync(fd)
    finally: os.close(fd)
assert free('/') >= 1593835520
git('add', '--sparse', '--force', '--', REL)
changed = git('diff', '--cached', '--name-only').decode().splitlines()
assert changed and all(p.startswith(REL + '/') for p in changed)
assert set(changed) == {str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file()}
git('diff', '--cached', '--check')
git('-c', 'user.name=ChatGPT', '-c', 'user.email=chatgpt-agent@users.noreply.github.com',
    'commit', '-m', 'docs: preserve pinned restoration and reviewed exact archive retirement')
head = git('rev-parse', 'HEAD').decode().strip()
assert [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs'] == original_top
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
committed = {}
for name, expected in PINS.items():
    digest = sha(git('show', 'HEAD:' + REL + '/prepared/' + name))
    assert digest == expected
    committed[name] = digest
git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
    'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {'status': 'RESTORATION_PREPARATION_COMMITTED_PUSHED_AND_READ_BACK', 'head': head,
          'changedPaths': len(changed), 'nonDocumentationRootEntriesUnchanged': True,
          'committedPinsReadBack': committed,
          'preservationSHA256': sha((OUT / 'PRESERVATION.json').read_bytes()),
          'rootFreeAfter': free('/'), 'dataFreeObservedAfter': free('/mnt/development'),
          'localRetirement': False, 'builds': 0, 'nativeRuns': 0}
write(TRANSFER / 'GIT_PRESERVATION_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
