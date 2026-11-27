"""Preserve the already staged SDK observer packet, without launching a build."""
from pathlib import Path, PurePosixPath
import datetime, hashlib, json, os, shutil, stat, subprocess, zipfile

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE = '759da82e7eb443634a4396c4768e44bca53f9001'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
TRANSFER = Path('/home/ubuntu/otzaria-wave3-sdk-bounded-envelope-transfer-20261127')
REL = 'docs/hq-integration/wave3-sdk-bounded-observation-20261127'
OUT = ROOT / REL
ZIP_SHA = 'cf8e030e83c208e10c5f6e0177ef4b631b9dfa9e6cf1eda54a52c2e00776e862'
STAGING_SHA = '2f1ab6468943d4cd5f72c05404bb52bb70630d10f1cd08a420e6bcf19a16cd2d'

def digest(b):
    return hashlib.sha256(b).hexdigest()

def free(p):
    s = os.statvfs(p)
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
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.chown(path, 1001, 1001)

before_free = {'root': free('/'), 'data': free('/mnt/development')}
assert before_free['root'] >= 1342177280, before_free
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == BRANCH
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
original_top = [x for x in git('ls-tree', 'HEAD').decode().splitlines()
                if x.split('\t', 1)[1] != 'docs']
packet = TRANSFER / 'SDK_BOUNDED_ENVELOPE.zip'
raw = packet.read_bytes()
assert len(raw) == 106296 and digest(raw) == ZIP_SHA
assert not OUT.exists()
OUT.mkdir(parents=True)
os.chown(OUT, 1001, 1001)
with zipfile.ZipFile(packet) as z:
    names = z.namelist()
    assert len(names) == 41 and len(set(names)) == 41
    assert digest(z.read('STAGING_INPUTS.json')) == STAGING_SHA
    rows = json.loads(z.read('STAGING_INPUTS.json'))['files']
    assert len(rows) == 40
    assert set(names) == {'STAGING_INPUTS.json'} | {r['path'] for r in rows}
    for row in rows:
        data = z.read(row['path'])
        assert len(data) == row['bytes'] and digest(data) == row['sha256'], row['path']
    for info in z.infolist():
        p = PurePosixPath(info.filename)
        assert not p.is_absolute() and '..' not in p.parts and not info.is_dir()
        assert not stat.S_ISLNK(info.external_attr >> 16)
        write(OUT / 'packet' / str(p), z.read(info.filename))
    launch = json.loads(z.read('LAUNCH_INPUTS.json'))
    assert len(launch['files']) == 13
    for row in launch['files']:
        data = z.read(row['path'])
        assert len(data) == row['bytes'] and digest(data) == row['sha256'], row['path']

write(OUT / 'SDK_BOUNDED_ENVELOPE_20261127.zip', raw)
transport = (TRANSFER / 'MAC_STAGING_TRANSPORT.json').read_bytes()
json.loads(transport)
write(OUT / 'MAC_STAGING_TRANSPORT.json', transport)
write(OUT / 'PRESERVATION_CONTROLLER.py', Path(__file__).read_bytes())
record = {
    'schema': 'otzaria.sdk.bounded-observation-preservation.v1',
    'status': 'SOURCE_PACKET_VERIFIED_AND_STAGED_NOT_LAUNCHED',
    'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'integrationBase': BASE,
    'sourceTree': git('rev-parse', 'HEAD:Source').decode().strip(),
    'vendorTree': git('rev-parse', 'HEAD:Vendor').decode().strip(),
    'allNonDocumentationRootEntries': original_top,
    'packetSHA256': ZIP_SHA, 'packetBytes': len(raw), 'packetMembers': 41,
    'transportManifestSHA256': STAGING_SHA, 'transportRowsVerified': 40,
    'launchManifestSHA256': digest((OUT / 'packet/LAUNCH_INPUTS.json').read_bytes()),
    'launchRowsVerified': 13, 'exactControllerHunks': 22,
    'portableObserverMethods': 14, 'portableObserverFailures': 0,
    'actualMacStagingJob': 'job_8ec89d476889',
    'actualMacStagingReceiptSHA256': '5c66896ea3fb5b98e6eb7060308d025863bcb080f5c295306a4c548eca40ffc3',
    'actualMacControl': '/Users/m1/builds/otzaria-wave3-sdk-bounded-launch-20261127.t2mfqqkj',
    'preservationFreeBefore': before_free,
    'minimumSDKAdmissionBytes': 15032385536, 'SDKLiveStopBytes': 2415919104,
    'SDKBuilds': 0, 'nativeRuns': 0, 'compilerSlotClaimed': False,
    'scope': 'Rootfs-only preservation of completed source preparation and staging. No build or control admission exception; no Data writes; no actual Mac process observation by this controller.',
    'limitations': ['Portable observer controls use explicit OS boundaries.',
                    'The unsuccessful first local envelope preparation is retained in packet/evidence/generation-attempt1.',
                    'Original source, SDK recipe, 17 guards, deadlines, and live reserve are unchanged.',
                    'Historical PROPOSAL/COMPLETE_PLAN are identified by the current addendum.',
                    'Fresh capacity and exclusive ownership admission remain mandatory before any launch.']
}
write(OUT / 'PRESERVATION.json', (json.dumps(record, indent=2) + '\n').encode())
write(OUT / 'README.md', ('''# Bounded SDK process observation — preserved staging evidence

The SDK source at d6090c03b9ac4e5760941e34f4c04478db4ae59f remains unbuilt.
The source packet was copied and hash-verified on the Mac by job_8ec89d476889.
This checkpoint changes documentation only and claims no SDK or native acceptance.

The current observation envelope retains the original queued-SDK predicate,
recipe, seventeen source guards, 14 GiB admission requirement, 2 GiB + 256 MiB
live stop reserve, deadlines and original source restoration. It bounds process
reads, reuses the already qualified BSD metadata reader, and records spawned
process identities before fallible observation. Twenty-two exact edits are
preserved with their original controllers and an independent source review.

Fourteen focused portable observer methods passed. Their OS responses are
explicit test boundaries; they are not real Mac observations. The unsuccessful
first local preparation is retained in full. The current addendum distinguishes
the historical proposal and plan from the new envelope.

The ZIP and every expanded member are retained, along with the original Mac
transport receipt. PRESERVATION.json records verification and unchanged product
trees. Fresh admission and exclusive ownership checks are still required before
the single SDK launch. No launcher, compiler or TestFlight action ran here.
''').encode())
for parent, dirs, files in os.walk(OUT):
    os.chown(parent, 1001, 1001)
    for name in dirs:
        os.chown(Path(parent) / name, 1001, 1001)
assert free('/') >= 1342177280
git('add', '--sparse', '--force', '--', REL)
changed = git('diff', '--cached', '--name-only').decode().splitlines()
assert changed and all(x.startswith(REL + '/') for x in changed)
assert set(changed) == {str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file()}
git('diff', '--cached', '--check')
commit = git('-c', 'user.name=ChatGPT', '-c', 'user.email=chatgpt-agent@users.noreply.github.com',
             'commit', '-m', 'docs: preserve bounded SDK observer and verified Mac staging')
head = git('rev-parse', 'HEAD').decode().strip()
assert [x for x in git('ls-tree', 'HEAD').decode().splitlines()
        if x.split('\t', 1)[1] != 'docs'] == original_top
assert git('status', '--porcelain=v1', '--untracked-files=all') == b''
push = git('-c', 'remote.origin.mirror=false', '-c', 'credential.helper=!gh auth git-credential',
           'push', 'origin', 'HEAD:refs/heads/' + BRANCH, timeout=120)
result = {'status': 'DOCUMENTATION_COMMITTED_PUSHED', 'head': head,
          'changedPaths': len(changed), 'nonDocumentationRootEntriesUnchanged': True,
          'preservationSHA256': digest((OUT / 'PRESERVATION.json').read_bytes()),
          'rootFreeAfter': free('/'), 'dataFreeObservedAfter': free('/mnt/development'),
          'SDKBuilds': 0, 'nativeRuns': 0}
write(TRANSFER / 'GIT_PRESERVATION_RESULT.json', (json.dumps(result, indent=2) + '\n').encode())
print(json.dumps(result))
