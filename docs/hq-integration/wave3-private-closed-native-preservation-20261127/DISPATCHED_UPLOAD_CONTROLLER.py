"""Single private archival upload plus authenticated whole-byte readback.

This never removes a local artifact and never distributes an application.
"""
from pathlib import Path
import datetime, hashlib, json, os, selectors, signal, subprocess, tarfile, time

CONTROL = Path('/home/ubuntu/otzaria-wave3-private-evidence-publication-20261127')
SOURCE = Path('/mnt/development/projects/diagnostics/otzaria-wave3-closed-native-preservation-20261127.fcws2jok')
ARCHIVE = SOURCE / 'closed-native-self-contained.tar.gz'
EXPECTED_SIZE = 1463489048
EXPECTED_SHA = '6e5202a79e92edd6d03c0c00af50a94633539817fb34bc3a203c7340239d71e7'
REPO = 'davidpovarsky/Maktabah-preserved-evidence'
REPO_ID = 1474927804
TAG = 'closed-native-20261127-wave3'
FLOOR = 1593835520

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def guard():
    s = os.statvfs('/')
    assert s.f_bavail * s.f_frsize >= FLOOR, 'Reserved root capacity unavailable'

def write(name, value):
    b = (json.dumps(value, indent=2) + '\n').encode()
    path = CONTROL / name
    with path.open('xb') as f:
        f.write(b); f.flush(); os.fsync(f.fileno())
    os.chmod(path, 0o644)
    fd = os.open(CONTROL, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    return path

def gh(args, timeout=60):
    r = subprocess.run(['sudo', '-u', 'ubuntu', '-H', 'gh', *args], capture_output=True, text=True, timeout=timeout)
    assert r.returncode == 0, (args[:3], r.returncode, r.stderr[:2000])
    return r.stdout

def private_repository():
    value = json.loads(gh(['api', 'repos/' + REPO]))
    assert value['id'] == REPO_ID and value['full_name'] == REPO
    assert value['private'] is True and value['owner']['login'] == 'davidpovarsky'
    assert not value['archived']
    return {'id': value['id'], 'full_name': value['full_name'], 'private': value['private']}

def identity(path):
    s = path.lstat()
    assert path.is_file() and not path.is_symlink() and s.st_nlink == 1
    return {'device': s.st_dev, 'inode': s.st_ino, 'size': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}

def stop_owned(process):
    # Each transfer has its own fresh session/group. No foreign process lookup.
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=20)

guard()
repo = private_repository()
assert not (CONTROL / 'ARCHIVE_UPLOAD_STARTED.json').exists()
original = identity(ARCHIVE)
assert original['size'] == EXPECTED_SIZE and sha(ARCHIVE) == EXPECTED_SHA
assert identity(ARCHIVE) == original
verification = SOURCE / 'ARCHIVE_VERIFIED.json'
assert sha(verification) == '50987d6a7daa36458322f755068f6730609ad470309ab2fa6cd4e96fdcf0720e'
v = json.loads(verification.read_bytes())
assert v['archive']['bytes'] == EXPECTED_SIZE and v['archive']['sha256'] == EXPECTED_SHA
assert v['every_source_file_maps_to_verified_member'] is True

members = []
metadata_path = CONTROL / 'closed-native-preservation-metadata-20261127.tar.gz'
assert not metadata_path.exists()
with tarfile.open(metadata_path, 'w:gz') as archive:
    for path in sorted(SOURCE.iterdir()):
        if path == ARCHIVE:
            continue
        st = identity(path)
        digest = sha(path)
        members.append({'path': path.name, 'bytes': st['size'], 'sha256': digest, 'sourceIdentity': st})
        archive.add(path, arcname=path.name, recursive=False)
        assert identity(path) == st and sha(path) == digest
os.chmod(metadata_path, 0o644)
assert metadata_path.stat().st_size < 16 * 1024 * 1024
manifest_path = write('PRESERVED_ARCHIVE_MANIFEST.json', {
    'schema': 'otzaria.private-archive-preservation.v1', 'sourceDirectory': str(SOURCE),
    'originalArchive': {'name': ARCHIVE.name, 'bytes': EXPECTED_SIZE, 'sha256': EXPECTED_SHA, 'identity': original},
    'metadataArchive': {'name': metadata_path.name, 'bytes': metadata_path.stat().st_size, 'sha256': sha(metadata_path)},
    'metadataMembers': members, 'privateRepository': repo,
    'applicationDistribution': False, 'localRetirement': False,
    'limits': 'Original archive/member proof retained; this operation verifies transport only and claims no new SDK/native test success.'
})
request = write('DRAFT_RELEASE_REQUEST.json', {
    'tag_name': TAG, 'target_commitish': 'main', 'name': 'Wave3 closed native evidence — exact preserved archive',
    'body': 'Private archival evidence for Maktabah / Otzaria.\n\nThe original self-contained archive and complete metadata are preserved with SHA256 and authenticated readback. Original failed and successful test evidence remains distinct. This draft is not an application release and establishes no SDK, native, production or TestFlight acceptance.\n\nSource archive SHA256: ' + EXPECTED_SHA,
    'draft': True, 'prerelease': False, 'generate_release_notes': False
})
release = json.loads(gh(['api', '-X', 'POST', 'repos/' + REPO + '/releases', '--input', str(request)]))
assert release['draft'] is True and release['tag_name'] == TAG
release_id = release['id']
write('DRAFT_RELEASE_CREATED.json', {'id': release_id, 'tag_name': TAG, 'draft': True, 'repository': repo,
                                    'html_url': release['html_url'], 'created_at': release['created_at']})
guard()
private_repository()
inputs = [metadata_path, manifest_path, ARCHIVE]
expected = {p.name: {'bytes': p.stat().st_size, 'sha256': sha(p)} for p in inputs}
write('ARCHIVE_UPLOAD_STARTED.json', {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                                     'releaseID': release_id, 'assets': expected, 'automaticRetries': 0})
with (CONTROL / 'UPLOAD.stdout').open('xb') as out, (CONTROL / 'UPLOAD.stderr').open('xb') as err:
    process = subprocess.Popen(['sudo', '-u', 'ubuntu', '-H', 'gh', 'release', 'upload', TAG, '--repo', REPO,
                                *map(str, inputs)], stdout=out, stderr=err, start_new_session=True)
    write('UPLOAD_PROCESS_STARTED.json', {'pid': process.pid, 'pgid': process.pid,
                                         'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()})
    started = time.monotonic()
    try:
        while process.poll() is None:
            guard()
            if time.monotonic() - started > 1200:
                raise TimeoutError('Private upload deadline')
            time.sleep(0.25)
        upload_exit = process.returncode
    except BaseException:
        stop_owned(process)
        raise
write('UPLOAD_EXIT.json', {'exit': upload_exit, 'releaseID': release_id})
assert upload_exit == 0, 'Upload failed; original artifact retained; no automatic retry or clobber'
assert identity(ARCHIVE) == original
private_repository()
remote = json.loads(gh(['api', f'repos/{REPO}/releases/{release_id}']))
assert remote['draft'] is True and remote['tag_name'] == TAG
assets = remote['assets']
assert {a['name'] for a in assets} == set(expected)
verified = []
for asset in assets:
    guard()
    e = expected[asset['name']]
    assert asset['state'] == 'uploaded' and asset['size'] == e['bytes']
    if asset.get('digest'):
        assert asset['digest'] == 'sha256:' + e['sha256']
    # Read the authenticated remote object completely without a second local
    # archive allocation. The bytes are hashed, never printed into a tool log.
    err_path = CONTROL / ('READBACK-%s.stderr' % asset['id'])
    started = time.monotonic()
    with err_path.open('xb') as err:
        process = subprocess.Popen(['sudo', '-u', 'ubuntu', '-H', 'gh', 'api',
                                    '-H', 'Accept: application/octet-stream',
                                    f'repos/{REPO}/releases/assets/{asset["id"]}'],
                                   stdout=subprocess.PIPE, stderr=err, start_new_session=True)
        write('READBACK-%s-PROCESS_STARTED.json' % asset['id'],
              {'pid': process.pid, 'pgid': process.pid, 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()})
        fd = process.stdout.fileno()
        os.set_blocking(fd, False)
        selector = selectors.DefaultSelector()
        selector.register(fd, selectors.EVENT_READ)
        h, count = hashlib.sha256(), 0
        try:
            while True:
                guard()
                if time.monotonic() - started > 1200:
                    raise TimeoutError('Authenticated readback deadline')
                if not selector.select(timeout=0.5):
                    continue
                try:
                    block = os.read(fd, 1024 * 1024)
                except BlockingIOError:
                    continue
                if not block:
                    break
                count += len(block)
                assert count <= e['bytes'], 'Unexpected remote bytes'
                h.update(block)
            code = process.wait(timeout=20)
        except BaseException:
            stop_owned(process)
            raise
        finally:
            selector.close()
            process.stdout.close()
    assert code == 0 and count == e['bytes'] and h.hexdigest() == e['sha256'], asset['name']
    verified.append({'name': asset['name'], 'id': asset['id'], 'bytes': count, 'sha256': h.hexdigest(),
                     'state': asset['state'], 'authenticatedFullReadback': True,
                     'readbackSeconds': time.monotonic() - started, 'apiURL': asset['url']})
    write('READBACK-%s.json' % asset['id'], verified[-1])
assert identity(ARCHIVE) == original and sha(ARCHIVE) == EXPECTED_SHA
repo = private_repository()
result = {'status': 'PRIVATE_ARCHIVE_AND_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINAL_RETAINED',
          'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'repository': repo, 'releaseID': release_id, 'draft': True, 'tag': TAG,
          'releaseURL': remote['html_url'], 'sourceIdentity': original, 'assets': verified,
          'localRetirement': False, 'applicationDistribution': False,
          'newSDKBuilds': 0, 'nativeRuns': 0}
path = write('VERIFIED_PRIVATE_PRESERVATION.json', result)
print(json.dumps({'status': result['status'], 'releaseID': release_id, 'releaseURL': result['releaseURL'],
                  'receiptSHA256': sha(path), 'assets': verified, 'localRetirement': False}))
