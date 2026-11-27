"""Preserve exact successful private archive readback evidence in product Git."""
from pathlib import Path
import datetime, hashlib, json, os, subprocess, tarfile

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE = '4bfea146611280ca4d2b5c2e4ed4ddd8a7843ce8'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
CONTROL = Path('/home/ubuntu/otzaria-wave3-private-evidence-publication-20261127')
TRANSFER = Path('/home/ubuntu/otzaria-wave3-private-preservation-proof-20261127')
REL = 'docs/hq-integration/wave3-private-closed-native-preservation-20261127'
OUT = ROOT / REL
RECEIPT_SHA = 'c8eb38f53a7b704587523d330c1c1ac63a2dd17cf49900cebb7a9406b545c1ed'
MANIFEST_SHA = 'e8e6210b7fd6e4a808ac851f8e2842df2db8ade6914a667ec6bd648a0adb87c5'

def sha(b):
    return hashlib.sha256(b).hexdigest()

def free(path):
    s = os.statvfs(path)
    return s.f_bavail * s.f_frsize

def git(*args, timeout=60):
    r = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0',
                        '-c', 'maintenance.auto=false', '-C', str(ROOT), *args],
                       capture_output=True, timeout=timeout)
    if r.returncode:
        raise RuntimeError((args, r.returncode, r.stderr.decode(errors='replace')[:3000]))
    return r.stdout

def write(path, b):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as f:
        f.write(b); f.flush(); os.fsync(f.fileno())
    os.chown(path, 1001, 1001)

assert free('/') >= 1593835520 + 4194304
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
original_top = [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs']
raw = (CONTROL / 'VERIFIED_PRIVATE_PRESERVATION.json').read_bytes()
assert sha(raw) == RECEIPT_SHA
receipt = json.loads(raw)
assert receipt['status'] == 'PRIVATE_ARCHIVE_AND_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINAL_RETAINED'
assert receipt['repository'] == {'id': 1474927804, 'full_name': 'davidpovarsky/Maktabah-preserved-evidence', 'private': True}
assert receipt['releaseID'] == 461088091 and receipt['draft'] is True
assert receipt['tag'] == 'closed-native-20261127-wave3'
assert receipt['localRetirement'] is False and receipt['applicationDistribution'] is False
assert receipt['newSDKBuilds'] == receipt['nativeRuns'] == 0
assets = {r['name']: r for r in receipt['assets']}
assert len(assets) == len(receipt['assets']) == 3
expected = {
    'closed-native-self-contained.tar.gz': (802156560, 1463489048, '6e5202a79e92edd6d03c0c00af50a94633539817fb34bc3a203c7340239d71e7'),
    'closed-native-preservation-metadata-20261127.tar.gz': (802156561, 5201005, 'e4d4d954bee4797c3b4fc9e8abf415937f47214aefdfd5cde55aa6b9eb77187a'),
    'PRESERVED_ARCHIVE_MANIFEST.json': (802156548, 8651, MANIFEST_SHA)}
assert set(assets) == set(expected)
for name, (asset_id, size, digest) in expected.items():
    row = assets[name]
    assert (row['id'], row['bytes'], row['sha256']) == (asset_id, size, digest)
    assert row['state'] == 'uploaded' and row['authenticatedFullReadback'] is True
manifest_raw = (CONTROL / 'PRESERVED_ARCHIVE_MANIFEST.json').read_bytes()
assert len(manifest_raw) == 8651 and sha(manifest_raw) == MANIFEST_SHA
manifest = json.loads(manifest_raw)
assert manifest['originalArchive']['identity'] == receipt['sourceIdentity']
assert manifest['originalArchive']['sha256'] == expected['closed-native-self-contained.tar.gz'][2]
assert manifest['metadataArchive']['sha256'] == expected['closed-native-preservation-metadata-20261127.tar.gz'][2]
assert len(manifest['metadataMembers']) == 22
metadata = CONTROL / manifest['metadataArchive']['name']
assert metadata.stat().st_size == 5201005 and sha(metadata.read_bytes()) == expected[metadata.name][2]
members = {r['path']: r for r in manifest['metadataMembers']}
assert len(members) == 22
with tarfile.open(metadata, 'r:gz') as archive:
    entries = archive.getmembers()
    assert len(entries) == len(members) and {r.name for r in entries} == set(members)
    for entry in entries:
        assert entry.isfile() and '/' not in entry.name and entry.name not in ('.', '..')
        data = archive.extractfile(entry).read()
        row = members[entry.name]
        assert len(data) == row['bytes'] and sha(data) == row['sha256']
    assert members['ARCHIVE_VERIFIED.json']['sha256'] == '50987d6a7daa36458322f755068f6730609ad470309ab2fa6cd4e96fdcf0720e'
    assert members['COMPLETE_PRESERVATION_VERIFIED.json']['sha256'] == 'fc6acb50b51ece3133921d746cbdb06fc8869e0c541f057e4a1240ffe835f6a7'

payload = {}
names = ['CREATE_VERIFIED.json', 'DRAFT_RELEASE_REQUEST.json', 'DRAFT_RELEASE_CREATED.json',
         'ARCHIVE_UPLOAD_STARTED.json', 'UPLOAD_PROCESS_STARTED.json', 'UPLOAD_EXIT.json',
         'UPLOAD.stdout', 'UPLOAD.stderr', 'VERIFIED_PRIVATE_PRESERVATION.json',
         'PRESERVED_ARCHIVE_MANIFEST.json']
for row in receipt['assets']:
    prefix = 'READBACK-' + str(row['id'])
    names.extend([prefix + '.json', prefix + '-PROCESS_STARTED.json', prefix + '.stderr'])
for name in names:
    p = CONTROL / name
    assert not p.is_symlink() and p.is_file() and p.stat().st_size <= 32768
    payload['actual/' + name] = p.read_bytes()
for name in ['DISPATCHED_UPLOAD_CONTROLLER.py', 'PEER_SOURCE_AND_RETIREMENT_REVIEW.json',
             'ACTUAL_SENTINEL_UPLOAD_RESULT.json']:
    payload[name] = (TRANSFER / name).read_bytes()
assert sha(payload['DISPATCHED_UPLOAD_CONTROLLER.py']) == 'f366f7e4a96b26d1177bbd0dce2fc03f841663f203cdf67e8a5f55dcdb1c70d5'
assert sha(payload['PEER_SOURCE_AND_RETIREMENT_REVIEW.json']) == '07a930cf0e73c8b8744b1e1f5ba8f2059008c6526696a8deee753b483b1f3e25'
job = json.loads(payload['ACTUAL_SENTINEL_UPLOAD_RESULT.json'])['job']
assert job['id'] == 'job_3ba9d20db5c2' and job['status'] == 'succeeded' and job['exit_code'] == 0
assert json.loads(job['output'])['receiptSHA256'] == RECEIPT_SHA
assert sum(map(len, payload.values())) < 1048576
assert not OUT.exists()
for name, data in payload.items():
    write(OUT / name, data)
write(OUT / 'PRESERVATION_CONTROLLER.py', Path(__file__).read_bytes())
record = {'schema': 'otzaria.private-archive-readback-git-preservation.v1',
          'status': 'ACTUAL_PRIVATE_FULL_READBACK_PRESERVED_ORIGINAL_LOCAL_ARCHIVE_RETAINED',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'integrationBase': BASE, 'allNonDocumentationRootEntries': original_top,
          'repository': receipt['repository'], 'releaseID': receipt['releaseID'],
          'receiptSHA256': RECEIPT_SHA, 'manifestSHA256': MANIFEST_SHA,
          'metadataMembersVerified': 22, 'assets': receipt['assets'],
          'files': [{'path': p, 'bytes': len(b), 'sha256': sha(b)} for p, b in sorted(payload.items())],
          'localRetirement': False, 'newSDKBuilds': 0, 'nativeRuns': 0,
          'limitations': ['The private archive and metadata tar are not copied into this public source repository.',
                         'The observed upload/readback succeeded; the initial controller cleanup-entry defect is retained for review.',
                         'Separate restoration, source/no-use and exact one-leaf retirement checks remain required.',
                         'This is evidence preservation, not SDK/native/production/TestFlight acceptance.']}
write(OUT / 'PRESERVATION.json', (json.dumps(record, indent=2) + '\n').encode())
write(OUT / 'README.md', b'''# Verified private preservation of closed native evidence

Actual job_3ba9d20db5c2 completed at 2026-11-27 21:49:26 UTC with exit 0.
The exact 1,463,489,048-byte self-contained archive, its complete 22-file metadata
archive, and the manifest were uploaded to a private draft evidence release.
Every asset was then read completely through authenticated access and matched
by byte count and SHA256. This checkpoint preserves the actual receipts, exact
dispatched controller, manifest, and independent source/retirement review.

The private archive and raw metadata tar remain private. No application was
published by this operation. The local original remains intact; a separate
durable restoration pointer, full source fence, no-use check and exact one-leaf
retirement operation are required before its capacity can be reclaimed.

The initial controller has a documented cleanup-entry defect if a process-ledger
write or selector setup throws after Popen. This actual successful run reached
all terminal full-byte receipts. The defect is preserved, not represented as
fixed or reused for subsequent execution. No SDK, native or TestFlight pass is
claimed by archive preservation.
''')
for parent, dirs, files in os.walk(OUT):
    os.chown(parent, 1001, 1001)
    for name in dirs:
        os.chown(Path(parent) / name, 1001, 1001)
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
    'commit', '-m', 'docs: preserve authenticated private native archive readback')
head = git('rev-parse', 'HEAD').decode().strip()
assert [r for r in git('ls-tree', 'HEAD').decode().splitlines() if r.split('\t', 1)[1] != 'docs'] == original_top
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
    'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {'status': 'PRIVATE_PRESERVATION_DOCUMENTATION_COMMITTED_PUSHED', 'head': head,
          'changedPaths': len(changed), 'nonDocumentationRootEntriesUnchanged': True,
          'preservationSHA256': sha((OUT / 'PRESERVATION.json').read_bytes()),
          'rootFreeAfter': free('/'), 'dataFreeObservedAfter': free('/mnt/development'),
          'localRetirement': False, 'builds': 0, 'nativeRuns': 0}
write(TRANSFER / 'GIT_PRESERVATION_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
