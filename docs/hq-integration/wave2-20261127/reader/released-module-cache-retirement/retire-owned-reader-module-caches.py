#!/usr/bin/env python3
"""Retire exactly the two released, reproducible Reader compiler caches."""
import hashlib
import json
import os
from pathlib import Path
import pwd
import shutil
import stat
import subprocess
import time

ROOT = Path('/Users/m1/builds/otzaria-wave2-reader-controls-20261127')
OUT = ROOT / 'released-module-cache-retirement-20261127'
TARGETS = [ROOT / 'full-v40-observation-admission/module-cache',
           ROOT / 'r27-phone-restoration-observer/module-cache']

def manifest(directory, *, preserve=False):
    result = []
    for base, dirs, files in os.walk(directory, followlinks=False):
        if preserve:
            dirs[:] = [d for d in dirs if Path(base) / d not in TARGETS and Path(base) / d != OUT]
        for name in sorted(dirs + files):
            path = Path(base) / name
            value = path.lstat()
            assert value.st_uid == pwd.getpwnam('m1').pw_uid, str(path)
            assert not stat.S_ISLNK(value.st_mode), str(path)
            assert stat.S_ISDIR(value.st_mode) or stat.S_ISREG(value.st_mode), str(path)
            row = {'path': str(path.relative_to(directory)), 'device': value.st_dev, 'inode': value.st_ino,
                'mode': value.st_mode, 'uid': value.st_uid, 'gid': value.st_gid,
                'bytes': value.st_size, 'allocatedBytes': value.st_blocks * 512,
                'mtimeNs': value.st_mtime_ns, 'ctimeNs': value.st_ctime_ns, 'links': value.st_nlink}
            if preserve and stat.S_ISREG(value.st_mode):
                assert value.st_size <= 256 * 1024 * 1024
                h = hashlib.sha256()
                with path.open('rb') as stream:
                    while True:
                        block = stream.read(1024 * 1024)
                        if not block: break
                        h.update(block)
                row['sha256'] = h.hexdigest()
            if not preserve or stat.S_ISREG(value.st_mode): result.append(row)
            assert len(result) <= 20000
    return sorted(result, key=lambda x: x['path'])

def command(args):
    started = time.time()
    result = subprocess.run(args, capture_output=True, text=True, timeout=30)
    return {'command': args, 'startedAtUnix': started, 'finishedAtUnix': time.time(),
        'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}

def main():
    assert ROOT.resolve(strict=True) == ROOT and not OUT.exists()
    assert shutil.rmtree.avoids_symlink_attacks
    for path in TARGETS:
        assert path.resolve(strict=True) == path and path.is_dir() and not path.is_symlink()
    before = manifest(ROOT, preserve=True)
    report = {'schema': 1, 'status': 'CHECKING_RELEASED_CACHE_SCOPE', 'startedAtUnix': time.time(),
        'scriptSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'authorization': 'Root authorized ONLY these two released owned module-cache directories; no adjacent files',
        'nonCacheBefore': before, 'caches': [], 'operations': []}
    OUT.mkdir()
    def save():
        (OUT / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        for path in TARGETS:
            root_stat = path.lstat()
            assert root_stat.st_uid == pwd.getpwnam('m1').pw_uid
            members = manifest(path)
            du = command(['/usr/bin/du', '-sk', str(path)])
            assert du['exit'] == 0
            ps = command(['/bin/ps', '-ww', '-axo', 'pid=,command='])
            assert ps['exit'] == 0
            references = [line for line in ps['stdout'].splitlines() if str(path) in line]
            assert not references, references
            fd = command(['/usr/sbin/lsof', '-nP', '+D', str(path)])
            assert fd['exit'] == 1 and not fd['stdout'].strip() and not fd['stderr'].strip(), fd
            assert manifest(path) == members
            now = path.lstat()
            assert (now.st_dev, now.st_ino, now.st_uid) == (root_stat.st_dev, root_stat.st_ino, root_stat.st_uid)
            report['caches'].append({'path': str(path), 'device': root_stat.st_dev, 'inode': root_stat.st_ino,
                'uid': root_stat.st_uid, 'gid': root_stat.st_gid, 'members': members, 'du': du,
                'activeCommandReferences': references, 'fileDescriptorCheck': fd})
        report['freeBytesBefore'] = shutil.disk_usage(ROOT).free
        save()
        for path in TARGETS:
            expected = next(x for x in report['caches'] if x['path'] == str(path))
            value = path.lstat()
            assert (value.st_dev, value.st_ino, value.st_uid) == (expected['device'], expected['inode'], expected['uid'])
            assert manifest(path) == expected['members']
            began = time.time()
            shutil.rmtree(path)
            assert not path.exists()
            report['operations'].append({'operation': 'shutil.rmtree', 'path': str(path),
                'startedAtUnix': began, 'finishedAtUnix': time.time(), 'absentAfter': True})
            save()
        after = manifest(ROOT, preserve=True)
        assert after == before, 'An adjacent retained file changed; inspect original before/after receipts'
        report['nonCacheAfter'] = after
        report['freeBytesAfter'] = shutil.disk_usage(ROOT).free
        report['observedSharedVolumeFreeDeltaBytes'] = report['freeBytesAfter'] - report['freeBytesBefore']
        report['deltaScope'] = 'Observed shared-volume net df delta; concurrent owners may change it. Cache du is separately retained.'
        report['status'] = 'EXACT_TWO_INACTIVE_OWNED_CACHES_RETIRED_ADJACENT_BYTES_UNCHANGED'
    except Exception as error:
        report['status'] = 'STOPPED_NO_UNSCOPED_CLEANUP'
        report['error'] = repr(error)
        raise
    finally:
        report['finishedAtUnix'] = time.time(); save()

if __name__ == '__main__':
    main()
