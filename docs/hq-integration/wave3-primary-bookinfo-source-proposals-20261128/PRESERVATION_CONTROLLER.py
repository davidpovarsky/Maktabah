"""Persist reviewed source proposals as documentation, never product source."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')
from pathlib import Path, PurePosixPath
import base64
import datetime
import hashlib
import json
import os
import stat
import subprocess
import zipfile

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
TRANSFER = Path('/home/ubuntu/otzaria-wave3-primary-bookinfo-proposal-proof-20261128')
ARCHIVE = Path('/var/lib/sentinelx/uploads/otzaria-wave3-primary-bookinfo-proposals-20261128.zip')
BASE = '40b558c03f26d4f4919f2de2d1c7b27e856fcdbf'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
REL = 'docs/hq-integration/wave3-primary-bookinfo-source-proposals-20261128'
OUT = ROOT / REL
ARCHIVE_SHA = 'df641fafd9b470eaa22307025fff8599f6c60cc18196c6aed1d900adb43c94eb'
MANIFEST_SHA = '2f99156e4a3c4bd969342c2e30e42c529ed2c53b00794435ee69af1ca0eed737'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def free(path):
    info = os.statvfs(path)
    return info.f_bavail * info.f_frsize


def git(*args, timeout=60):
    result = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0',
                             '-c', 'maintenance.auto=false', '-C', str(ROOT), *args],
                            capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError((args, result.returncode, result.stdout.decode(errors='replace')[:2500],
                            result.stderr.decode(errors='replace')[:2500]))
    return result.stdout


def write(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    os.chown(path, 1001, 1001)


assert free('/') >= 1593835520 + 48 * 1024 * 1024
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
assert git('rev-parse', 'HEAD:Source').decode().strip() == 'c62aa1a24c1a10fb5129c25d6869faa00c9a3dfb'
non_docs = [row for row in git('ls-tree', 'HEAD').decode().splitlines() if row.split('\t', 1)[1] != 'docs']
assert not os.path.lexists(OUT)
info = ARCHIVE.lstat()
assert stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and info.st_size == 5683581
archive_raw = ARCHIVE.read_bytes()
assert sha(archive_raw) == ARCHIVE_SHA
with zipfile.ZipFile(ARCHIVE) as archive:
    manifest_raw = archive.read('MANIFEST.json')
    assert len(manifest_raw) == 199173 and sha(manifest_raw) == MANIFEST_SHA
    manifest = json.loads(manifest_raw)
    assert manifest['status'] == 'SOURCE_PREPARATION_AND_EXISTING_EVIDENCE_ONLY_NOT_PRODUCT_INTAKE'
    assert manifest['integration_base'] == BASE
    assert len(manifest['files']) == manifest['file_count'] == 779
    assert manifest['unique_blobs'] == 546 and manifest['logical_bytes'] == 29120030
    assert len(set(row['path'] for row in manifest['files'])) == 779
    blobs = {row['sha256'] for row in manifest['files']}
    assert set(archive.namelist()) == {'MANIFEST.json'} | {'blobs/' + key for key in blobs}
    assert len(archive.namelist()) == 547
    for row in manifest['files']:
        path = PurePosixPath(row['path'])
        assert not path.is_absolute() and '..' not in path.parts and path.parts[0] in manifest['scopes']
        assert row['bytes'] <= 8 * 1024 * 1024
        raw = archive.read('blobs/' + row['sha256'])
        assert (len(raw), sha(raw)) == (row['bytes'], row['sha256'])

raw_files = (TRANSFER / 'FILES.json').read_bytes()
assert len(raw_files) < 180000
files = json.loads(raw_files)
assert set(files) == {
    'README.md', 'LOCAL_PREPARATION.json', 'LOCAL_TRANSPORT_PREPARATION_FAILURE.json',
    'PREPARE_CHECKPOINT.py', 'ROOT_SOURCE_REVIEW.json', 'METADATA_EDITS.json',
    'PREPARE_BOOKINFO_PROPOSAL.py', 'TRANSPORT_RECEIPT.json',
}
payload = {'PROPOSALS.zip': archive_raw, 'MANIFEST.json': manifest_raw}
for name, row in files.items():
    raw = base64.b64decode(row['base64'], validate=True)
    assert (len(raw), sha(raw)) == (row['bytes'], row['sha256'])
    payload[name] = raw
local = json.loads(payload['LOCAL_PREPARATION.json'])
assert local['archive_sha256'] == ARCHIVE_SHA and local['manifest_sha256'] == MANIFEST_SHA
review = json.loads(payload['ROOT_SOURCE_REVIEW.json'])
assert review['shared_ledger_sha256'] == 'b533af94fec04ebe2ffb42789fdd4a86d122e08829c8abe38ca94478b5f3dcfc'
assert review['compiler_invocations'] == review['native_runs'] == review['remote_source_mutations'] == 0
transport = json.loads(payload['TRANSPORT_RECEIPT.json'])
assert transport['completion']['target_path'] == str(ARCHIVE)
assert transport['completion']['sha256'] == ARCHIVE_SHA and transport['completion']['size'] == info.st_size
assert len(transport['chunks']) == 22 and all(row['ok'] is True for row in transport['chunks'])
assert sum(row['chunk_size'] for row in transport['chunks']) == info.st_size
assert {row['index'] for row in transport['chunks']} == set(range(22))
assert sha(ARCHIVE.read_bytes()) == ARCHIVE_SHA
after = ARCHIVE.lstat()
assert (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns) == (
    after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
payload['PRESERVATION_CONTROLLER.py'] = Path(__file__).read_bytes()
for name, raw in payload.items():
    write(OUT / name, raw)
proof = {
    'schema': 'otzaria.reviewed-source-proposal-checkpoint-preservation/1',
    'status': 'UNQUALIFIED_SOURCE_PROPOSALS_AND_PRIOR_EVIDENCE_PRESERVED',
    'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'integration_base': BASE, 'all_non_documentation_root_entries': non_docs,
    'archive_sha256': ARCHIVE_SHA, 'manifest_sha256': MANIFEST_SHA,
    'mapped_source_files': 779, 'unique_blobs': 546,
    'all_archive_members_and_source_mappings_verified': True,
    'product_intake': False, 'compiler_invocations': 0, 'SDK_builds': 0, 'native_runs': 0,
    'gates': manifest['current_gates'],
    'files': [{'path': name, 'bytes': len(raw), 'sha256': sha(raw)} for name, raw in sorted(payload.items())],
}
proof_raw = (json.dumps(proof, ensure_ascii=False, indent=2) + '\n').encode()
write(OUT / 'PRESERVATION.json', proof_raw)
for parent, directories, _ in os.walk(OUT):
    os.chown(parent, 1001, 1001)
    for name in directories:
        os.chown(Path(parent) / name, 1001, 1001)
    descriptor = os.open(parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
assert free('/') >= 1593835520
paths = sorted(str(path.relative_to(ROOT)) for path in OUT.rglob('*') if path.is_file())
check = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'git', '-c', 'gc.auto=0', '-c',
                        'maintenance.auto=false', '-C', str(ROOT), 'check-ignore', '-z', '--stdin'],
                       input=('\0'.join(paths) + '\0').encode(), capture_output=True, timeout=15)
assert check.returncode in (0, 1)
ignored = set(check.stdout.decode().split('\0')) - {''}
ordinary = [path for path in paths if path not in ignored]
if ordinary:
    git('add', '--sparse', '--', *ordinary)
if ignored:
    git('add', '--sparse', '--force', '--', *sorted(ignored))
changed = git('diff', '--cached', '--name-only').decode().splitlines()
assert set(changed) == set(paths) and all(path.startswith(REL + '/') for path in changed)
git('diff', '--cached', '--check')
git('-c', 'user.name=ChatGPT', '-c', 'user.email=chatgpt-agent@users.noreply.github.com',
    'commit', '-m', 'docs: preserve reviewed primary UI and BookInfo source proposals')
head = git('rev-parse', 'HEAD').decode().strip()
assert [row for row in git('ls-tree', 'HEAD').decode().splitlines() if row.split('\t', 1)[1] != 'docs'] == non_docs
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
    'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {
    'status': 'SOURCE_PROPOSAL_DOCUMENTATION_COMMITTED_PUSHED', 'head': head,
    'changed_paths': len(changed), 'source_and_all_non_doc_trees_unchanged': True,
    'preservation_sha256': sha(proof_raw), 'archive_sha256': ARCHIVE_SHA,
    'root_free_after': free('/'), 'data_free_observed_after': free('/mnt/development'),
    'product_intake': False, 'compiler_invocations': 0, 'native_runs': 0,
}
write(TRANSFER / 'GIT_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
