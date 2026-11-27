#!/usr/bin/env python3
"""Parent-authorized one-file retirement, conditional on fresh complete proof."""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import time
import urllib.request
from urllib.parse import urlsplit

ROOT = Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127')
BASE = Path('/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127')
DB = BASE / 'corpus-v40-recovery-20261127/seforim.db'
OUT = BASE / 'corpus-db-retirement-20261127'
EXPECTED = '8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01'


def require(value, message):
    if not value:
        raise ValueError(message)


def identity(path):
    s = path.lstat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns,
            'uid': s.st_uid, 'gid': s.st_gid, 'mode': stat.S_IMODE(s.st_mode)}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def write(name, value):
    p = OUT / name
    raw = json.dumps(value, indent=2, sort_keys=True).encode() + b'\n'
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())
    return {'path': str(p), 'bytes': len(raw), 'sha256': digest(raw)}


def tracked(name):
    raw = subprocess.check_output(['sudo', '-u', 'ubuntu', 'git', '-C', str(ROOT), 'show', 'HEAD:' + name], timeout=10)
    return json.loads(raw), {'path': name, 'bytes': len(raw), 'sha256': digest(raw)}


def no_references():
    hits, gaps, vanished = [], [], 0
    pids = sorted(p for p in Path('/proc').iterdir() if p.name.isdecimal())
    for proc in pids:
        pid = int(proc.name)
        try:
            command = (proc / 'cmdline').read_bytes()
            if str(DB).encode() in command or str(DB.parent).encode() in command:
                hits.append({'pid': pid, 'kind': 'command', 'commandSHA256': digest(command)})
        except (FileNotFoundError, ProcessLookupError):
            vanished += 1; continue
        except PermissionError:
            gaps.append({'pid': pid, 'kind': 'command'}); continue
        try:
            current = os.readlink(proc / 'cwd')
            if current == str(DB.parent) or current.startswith(str(DB.parent) + '/'):
                hits.append({'pid': pid, 'kind': 'cwd'})
        except (FileNotFoundError, ProcessLookupError):
            pass
        except PermissionError:
            gaps.append({'pid': pid, 'kind': 'cwd'})
        try:
            maps = (proc / 'maps').read_bytes()
            for line in maps.splitlines():
                columns = line.split(None, 5)
                if len(columns) >= 5 and columns[4] == b'5946339':
                    dev = columns[3].decode().split(':')
                    if len(dev) == 2 and os.makedev(int(dev[0], 16), int(dev[1], 16)) == 2064:
                        hits.append({'pid': pid, 'kind': 'mapped-inode'})
                if str(DB).encode() in line:
                    hits.append({'pid': pid, 'kind': 'mapped-path'})
        except (FileNotFoundError, ProcessLookupError):
            pass
        except PermissionError:
            gaps.append({'pid': pid, 'kind': 'maps'})
        try:
            descriptors = list((proc / 'fd').iterdir())
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            gaps.append({'pid': pid, 'kind': 'fd-directory'}); continue
        for descriptor in descriptors:
            try:
                s = descriptor.stat()
                if s.st_dev == 2064 and s.st_ino == 5946339:
                    hits.append({'pid': pid, 'kind': 'open-inode', 'fd': descriptor.name})
            except (FileNotFoundError, ProcessLookupError):
                pass
            except PermissionError:
                gaps.append({'pid': pid, 'kind': 'fd', 'fd': descriptor.name})
    result = {'observedUnix': time.time(), 'processesEnumerated': len(pids), 'vanishedProcesses': vanished,
              'matchingReferences': hits, 'permissionGaps': gaps}
    require(not hits and not gaps, 'An active reference or incomplete process visibility blocks retirement')
    return result


def siblings():
    result = []
    for path in sorted(DB.parent.iterdir()):
        if path == DB:
            continue
        s = path.lstat()
        require(stat.S_ISREG(s.st_mode) and not path.is_symlink() and s.st_size <= 8 * 1024 * 1024,
                'An unexpected sibling requires independent preservation review')
        result.append({'name': path.name, 'identity': identity(path), 'sha256': digest(path.read_bytes())})
    return result


def main():
    require(os.geteuid() == 0 and not OUT.exists(), 'Root complete process visibility and fresh receipt directory are required')
    require(DB.resolve(strict=True) == DB and stat.S_ISREG(DB.lstat().st_mode), 'Exact canonical regular recovered DB required')
    ancestors = []
    for p in [DB.parent, *DB.parent.parents]:
        s = p.lstat()
        require(stat.S_ISDIR(s.st_mode) and not stat.S_ISLNK(s.st_mode) and s.st_uid in (0, 1001)
                and not stat.S_IMODE(s.st_mode) & 0o002, 'Parent identity/permission is not qualified')
        ancestors.append({'path': str(p), 'device': s.st_dev, 'inode': s.st_ino, 'uid': s.st_uid, 'mode': stat.S_IMODE(s.st_mode)})
    golden, golden_witness = tracked('docs/hq-integration/wave2-20261127/search/corpus-restore/RESTORE_RESULT.json')
    before = identity(DB)
    require(all(before[key] == value for key, value in golden['sourceDatabase']['identity'].items())
            and before['device'] == 2064 and before['inode'] == 5946339 and before['bytes'] == 4355063808
            and before['allocatedBytes'] == 4355162112 and before['nlink'] == 1
            and before['uid'] == before['gid'] == 1001 and before['mode'] == 0o444
            and golden['sourceDatabase']['path'] == str(DB) and golden['sourceDatabase']['sha256'] == EXPECTED,
            'Fresh file identity differs from the independently retained reconstruction')
    OUT.mkdir(mode=0o700)
    proof = {'schema': 'otzaria.exact-recovered-corpus-retirement/1', 'status': 'ADMISSION_RUNNING_NO_DELETION_YET',
             'startedUnix': time.time(), 'target': str(DB), 'before': before, 'parents': ancestors,
             'goldenRestoration': golden_witness, 'scriptSHA256': digest(Path(__file__).read_bytes()),
             'authorization': 'Root explicitly authorized conditional retirement of this one file after all three lane owners released it; no other file deletion.',
             'releasedOwners': ['search_native', 'library_v40', 'reader_perf'],
             'inAppInstallationClaimed': False, 'nativeUIClaimed': False, 'otherPathsAuthorizedForDeletion': []}
    write('INTENT.json', proof)
    proof['referencesBefore'] = no_references()
    proof['siblingsBefore'] = siblings()
    release_url = 'https://api.github.com/repos/Otzaria/SeforimLibrary/releases/455390662'
    request = urllib.request.Request(release_url, headers={'User-Agent': 'Maktabah-owned-retirement-readonly', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=15) as response:
        raw = response.read(1024 * 1024 + 1)
        require(response.status == 200 and len(raw) <= 1024 * 1024, 'Bounded unauthenticated public release metadata failed')
    release = json.loads(raw)
    require(release['id'] == 455390662 and release['tag_name'] == golden['releaseTag']
            and release['draft'] is False and release['published_at'], 'Official pinned public v40 release differs')
    part_records = [tracked('docs/hq-integration/wave2-20261127/search/corpus-restore/RESTORE_PART_' + str(index) + '.json') for index in (0, 1)]
    expected_assets = [{'id': row[0]['assetID'], 'name': row[0]['assetName'], 'size': row[0]['bytes'], 'sha256': row[0]['sha256']} for row in part_records]
    manifest = [a for a in release['assets'] if a['id'] == golden['manifestAssetID']]
    require(len(manifest) == 1, 'Original official manifest asset is not public')
    expected_assets.append({'id': golden['manifestAssetID'], 'name': manifest[0]['name'], 'size': manifest[0]['size'], 'sha256': golden['manifestSHA256']})
    assets = []
    for expected in expected_assets:
        matches = [a for a in release['assets'] if a['id'] == expected['id']]
        require(len(matches) == 1, 'Original public asset ID was replaced')
        asset = matches[0]
        require(asset['name'] == expected['name'] and asset['size'] == expected['size'] and asset['state'] == 'uploaded'
                and asset.get('digest') == 'sha256:' + expected['sha256'], 'Current public asset size/name/digest differs')
        direct = 'https://github.com/Otzaria/SeforimLibrary/releases/download/' + golden['releaseTag'] + '/' + expected['name']
        require(asset['browser_download_url'] == direct, 'Official public download route differs')
        head = urllib.request.Request(direct, method='HEAD', headers={'User-Agent': 'Maktabah-owned-retirement-readonly'})
        with urllib.request.urlopen(head, timeout=15) as response:
            require(response.status == 200 and int(response.headers['Content-Length']) == expected['size']
                    and urlsplit(response.geturl()).hostname in ('release-assets.githubusercontent.com', 'objects.githubusercontent.com', 'github.com'),
                    'Public HEAD availability/length is unqualified')
            availability = {'HTTPStatus': response.status, 'bytes': int(response.headers['Content-Length']),
                            'finalHost': urlsplit(response.geturl()).hostname, 'payloadBytesRead': 0}
        assets.append({**expected, 'currentDigest': asset['digest'], 'availability': availability})
    proof['publicRecovery'] = {'releaseID': release['id'], 'releaseTag': release['tag_name'], 'metadataSHA256': digest(raw),
                               'metadataBytes': len(raw), 'unauthenticatedPublicHTTP': True, 'assets': assets,
                               'originalPartProofs': [row[1] for row in part_records], 'payloadRedownloaded': False}
    started = time.monotonic(); hashed = hashlib.sha256(); total = 0
    descriptor = os.open(DB, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb') as handle:
        s = os.fstat(handle.fileno())
        require(s.st_dev == before['device'] and s.st_ino == before['inode'], 'Hash opened another inode')
        while True:
            block = handle.read(4 * 1024 * 1024)
            if not block:
                break
            hashed.update(block); total += len(block)
            require(time.monotonic() - started <= 180, 'Single complete hash exceeded its bounded read interval')
    require(total == before['bytes'] and hashed.hexdigest() == EXPECTED and identity(DB) == before,
            'Fresh full corpus bytes or file identity changed')
    proof['freshFullHash'] = {'bytes': total, 'sha256': hashed.hexdigest(), 'seconds': time.monotonic() - started,
                              'bufferBytes': 4 * 1024 * 1024, 'databaseQueries': 0}
    proof['referencesBeforeUnlink'] = no_references()
    require(siblings() == proof['siblingsBefore'] and identity(DB) == before and DB.parent.resolve() == DB.parent,
            'Target/sibling identity changed immediately before unlink')
    proof['freeBytesBefore'] = os.statvfs(DB.parent).f_bavail * os.statvfs(DB.parent).f_frsize
    proof['status'] = 'ALL_CONDITIONAL_ONE_FILE_RETIREMENT_GATES_PASSED'
    admission = write('ADMISSION.json', proof)
    # This is the only deletion in this script. The exact original inode was
    # hashed and rechecked; all siblings and all source/receipt paths are kept.
    require(identity(DB) == before, 'Last target identity changed')
    DB.unlink()
    parent_fd = os.open(DB.parent, os.O_RDONLY)
    try:
        os.fsync(parent_fd)
    finally:
        os.close(parent_fd)
    require(not DB.exists() and siblings() == proof['siblingsBefore'], 'Target removal/sibling preservation is unverified')
    free = os.statvfs(DB.parent).f_bavail * os.statvfs(DB.parent).f_frsize
    final = {'schema': proof['schema'], 'status': 'EXACT_RELEASED_REPRODUCIBLE_CORPUS_COPY_RETIRED', 'target': str(DB),
             'admission': admission, 'before': before, 'afterExists': False, 'freeBytesBefore': proof['freeBytesBefore'],
             'freeBytesAfter': free, 'sharedFreeSpaceDeltaBytes': free - proof['freeBytesBefore'],
             'uniqueAllocatedBytesRetired': before['allocatedBytes'], 'siblingsAfter': siblings(),
             'originalSourceAndReceiptsPreserved': True, 'inAppInstallationClaimed': False, 'nativeUIClaimed': False,
             'completedUnix': time.time()}
    record = write('RESULT.json', final)
    print(json.dumps({'receipt': record, 'result': final}, indent=2))


if __name__ == '__main__':
    main()
