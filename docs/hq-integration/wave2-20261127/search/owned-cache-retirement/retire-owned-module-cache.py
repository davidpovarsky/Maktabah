#!/usr/bin/env python3
"""One explicitly authorized cache retirement; no wildcard or sibling deletion."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import stat
import subprocess
import sys

EXPECTED = Path('/Users/m1/builds/otzaria-wave2-search-20261127/post-update-ui-typecheck/module-cache')
BASE = EXPECTED.parents[1]
RECEIPTS = BASE / 'cache-retirement-20261127'
original = json.load(sys.stdin)
assert original['path'] == str(EXPECTED)
assert original['fileCount'] == 218 and original['uniqueAllocatedBytes'] == 130023424
assert EXPECTED.resolve(strict=True) == EXPECTED and EXPECTED.is_dir() and not EXPECTED.is_symlink()
assert not RECEIPTS.exists()
RECEIPTS.mkdir(mode=0o700)


def file_record(path):
    s = path.lstat()
    assert stat.S_ISREG(s.st_mode) and s.st_nlink == 1
    return {'relativePath': path.relative_to(EXPECTED).as_posix(), 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'dev': s.st_dev, 'inode': s.st_ino,
            'nlink': s.st_nlink, 'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns}


def inventory():
    files, dirs = [], []
    for root, child_dirs, names in os.walk(EXPECTED, followlinks=False):
        directory = Path(root)
        assert directory.resolve(strict=True) == directory and not directory.is_symlink()
        s = directory.stat()
        dirs.append({'path': str(directory), 'dev': s.st_dev, 'inode': s.st_ino})
        for name in child_dirs:
            child = directory / name
            assert not child.is_symlink() and child.is_dir()
        for name in names:
            files.append(file_record(directory / name))
    return sorted(files, key=lambda r: r['relativePath']), dirs


def sibling_records():
    records = []
    for root, dirs, names in os.walk(BASE, followlinks=False):
        directory = Path(root)
        dirs[:] = [n for n in dirs if directory / n not in (EXPECTED, RECEIPTS)]
        for name in names:
            path = directory / name
            s = path.lstat()
            records.append([path.relative_to(BASE).as_posix(), s.st_dev, s.st_ino, s.st_mode, s.st_nlink,
                            s.st_size, s.st_mtime_ns, s.st_ctime_ns])
    return sorted(records)


def write(name, value):
    raw = json.dumps(value, sort_keys=True, indent=2).encode() + b'\n'
    fd = os.open(RECEIPTS / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(raw); stream.flush(); os.fsync(stream.fileno())
    return {'path': str(RECEIPTS / name), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}

before_files, directories = inventory()
assert before_files == sorted(original['files'], key=lambda r: r['relativePath'])
root_stat = EXPECTED.stat()
assert [root_stat.st_dev, root_stat.st_ino, root_stat.st_mtime_ns, root_stat.st_ctime_ns] == original['directoryAfter']
processes = subprocess.run(['/bin/ps', '-ww', '-axo', 'pid=,ppid=,command='], capture_output=True, text=True, timeout=5)
assert processes.returncode == 0 and not processes.stderr
rows = {}
for line in processes.stdout.splitlines():
    fields = line.strip().split(None, 2)
    if fields:
        assert len(fields) == 3
        rows[int(fields[0])] = {'pid': int(fields[0]), 'parentPID': int(fields[1]), 'command': fields[2]}
owned_ancestry, cursor = set(), os.getpid()
while cursor > 1:
    assert cursor in rows and cursor not in owned_ancestry
    owned_ancestry.add(cursor); cursor = rows[cursor]['parentPID']
references = [row for row in rows.values() if str(EXPECTED) in row['command'] and row['pid'] not in owned_ancestry]
assert references == [], references
opened = subprocess.run(['/usr/bin/sudo', '-n', '/usr/sbin/lsof', '-nP', '+D', str(EXPECTED)], capture_output=True, text=True, timeout=12)
assert opened.returncode == 1 and not opened.stdout and not opened.stderr, (opened.returncode, opened.stdout, opened.stderr)
siblings_before = sibling_records()
# Re-admit membership after the potentially slow process/FD inspection.
assert inventory() == (before_files, directories)
free_before = os.statvfs(BASE).f_bavail * os.statvfs(BASE).f_frsize
start = {'schema': 'otzaria.exact-owned-cache-retirement/1', 'status': 'ADMITTED_BEFORE_UNLINK',
         'observedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'path': str(EXPECTED),
         'rootIdentity': original['directoryAfter'], 'files': before_files, 'directories': directories,
         'sourceInventorySHA256': hashlib.sha256(json.dumps(original, sort_keys=True).encode()).hexdigest(),
         'noOtherAgentPlannedUseConfirmed': True, 'controllerPID': os.getpid(),
         'excludedOnlyCurrentControllerAncestry': sorted(owned_ancestry), 'processReferences': references,
         'openReferenceCheck': {'exitCode': opened.returncode, 'stdout': opened.stdout, 'stderr': opened.stderr},
         'freeBytesBefore': free_before, 'preservedSiblingFileCount': len(siblings_before),
         'preservedSiblingInventorySHA256': hashlib.sha256(json.dumps(siblings_before).encode()).hexdigest()}
start_witness = write('BEFORE.json', start)
removed = []
for expected in before_files:
    path = EXPECTED / expected['relativePath']
    assert path.resolve(strict=True) == path and path.is_relative_to(EXPECTED)
    assert file_record(path) == expected
    path.unlink()
    removed.append(expected['relativePath'])
for record in sorted(directories, key=lambda r: len(Path(r['path']).parts), reverse=True):
    path = Path(record['path'])
    current = path.lstat()
    assert stat.S_ISDIR(current.st_mode) and [current.st_dev, current.st_ino] == [record['dev'], record['inode']]
    path.rmdir()  # Only an empty, freshly matched owned directory can disappear.
assert not EXPECTED.exists()
siblings_after = sibling_records()
assert siblings_after == siblings_before
free_after = os.statvfs(BASE).f_bavail * os.statvfs(BASE).f_frsize
result = {'schema': 'otzaria.exact-owned-cache-retirement/1', 'status': 'ONLY_APPROVED_REPRODUCIBLE_CACHE_RETIRED',
          'completedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'path': str(EXPECTED),
          'beforeReceipt': start_witness, 'removedFileCount': len(removed), 'removedDirectoryCount': len(directories),
          'removedFiles': removed, 'allocatedFileBytesRetired': sum(r['allocatedBytes'] for r in before_files),
          'freeBytesBefore': free_before, 'freeBytesAfter': free_after, 'measuredFreeBytesDelta': free_after - free_before,
          'measurementCaveat': 'Shared volume free-byte delta can include concurrent independent writes; allocated file bytes are separately accounted.',
          'preservedSiblingFileCount': len(siblings_after), 'preservedSiblingInventoryUnchanged': True,
          'preservedSiblingInventorySHA256': hashlib.sha256(json.dumps(siblings_after).encode()).hexdigest(),
          'sourceLogsBinariesSignaturesReceiptsUnchanged': True, 'PFChanges': 0, 'launchdOperations': 0, 'networkDenialWindows': 0}
write('RESULT.json', result)
print(json.dumps(result))
