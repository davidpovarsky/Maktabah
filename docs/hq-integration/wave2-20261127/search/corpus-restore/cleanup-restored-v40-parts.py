#!/usr/bin/env python3
"""Remove only the two published, verified compressed parts approved by root."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127')
ARTIFACT = Path('/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127')
DATABASE = ARTIFACT / 'seforim.db'
NAMES = ['seforim-schema7.db.zst.part-000.verified', 'seforim-schema7.db.zst.part-001.verified']


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def identity(path):
    value = path.lstat()
    assert stat.S_ISREG(value.st_mode) and not path.is_symlink()
    return {'device': value.st_dev, 'inode': value.st_ino, 'bytes': value.st_size,
            'allocatedBytes': value.st_blocks * 512, 'nlink': value.st_nlink,
            'mtimeNs': value.st_mtime_ns, 'ctimeNs': value.st_ctime_ns}


def save(name, value):
    with (OUT / name).open('x') as handle:
        json.dump(value, handle, indent=2)
        handle.write('\n'); handle.flush(); os.fsync(handle.fileno())


def free_bytes():
    s = os.statvfs(ARTIFACT)
    return s.f_bavail * s.f_frsize


def activity(inodes):
    paths = {str(ARTIFACT / name) for name in NAMES}
    references, permissions, exited = [], [], 0
    checked = 0
    for process in Path('/proc').iterdir():
        if not process.name.isdigit():
            continue
        checked += 1
        try:
            try:
                cwd = os.readlink(process / 'cwd')
                if cwd == str(ARTIFACT):
                    references.append({'pid': int(process.name), 'kind': 'artifact-cwd', 'path': cwd})
            except FileNotFoundError:
                pass
            command = (process / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
            if any(path in command or name in command for path, name in zip(sorted(paths), NAMES)):
                references.append({'pid': int(process.name), 'kind': 'exact-part-command'})
            for descriptor in (process / 'fd').iterdir():
                try:
                    s = descriptor.stat()
                    target = os.readlink(descriptor)
                    if (s.st_dev, s.st_ino) in inodes or target in paths:
                        references.append({'pid': int(process.name), 'kind': 'fd', 'descriptor': descriptor.name})
                except FileNotFoundError:
                    pass
            for line in (process / 'maps').read_text().splitlines():
                fields = line.split(None, 5)
                if len(fields) < 5:
                    continue
                major, minor = fields[3].split(':')
                observed = (os.makedev(int(major, 16), int(minor, 16)), int(fields[4]))
                if observed in inodes or (len(fields) == 6 and fields[5] in paths):
                    references.append({'pid': int(process.name), 'kind': 'map'})
        except FileNotFoundError:
            exited += 1
        except PermissionError as error:
            permissions.append({'pid': int(process.name), 'kind': type(error).__name__})
    return {'observedAt': now(), 'processesInspected': checked, 'processesExitedDuringRead': exited,
            'references': references, 'permissionDenied': permissions}


def main():
    assert OUT == ROOT / 'docs/hq-integration/wave2-20261127/search/corpus-restore'
    assert ARTIFACT.resolve(strict=True) == ARTIFACT
    assert not (OUT / 'PARTS_CLEANUP_ADMISSION.json').exists()
    assert not (OUT / 'PARTS_CLEANUP_RESULT.json').exists()
    receipts = []
    parts = []
    expected_shas = ['91a9985084e5217b661664c3b53c357aaf354498752bf9f7c55d93581dcc9c33',
                     'a5469c776bae891d49dfcf33986474416b56ee739c4b0fba37ef7eb9ec53af1a']
    for index, name in enumerate(NAMES):
        raw = (OUT / ('RESTORE_PART_' + str(index) + '.json')).read_bytes()
        record = json.loads(raw)
        assert record['status'] == 'PUBLIC_PART_DOWNLOADED_SHA_VERIFIED'
        assert record['path'] == str(ARTIFACT / name) and record['sha256'] == expected_shas[index]
        assert record['assetID'] == [782942221, 782993890][index]
        assert record['originalURL'] == 'https://github.com/Otzaria/SeforimLibrary/releases/download/v40-20261123094345/' + name.removesuffix('.verified')
        assert identity(ARTIFACT / name) == record['fileIdentity'] and record['fileIdentity']['nlink'] == 1
        parts.append(record)
        receipts.append({'name': 'RESTORE_PART_' + str(index) + '.json', 'bytes': len(raw), 'sha256': sha(raw)})
    restore_raw = (OUT / 'RESTORE_RESULT.json').read_bytes()
    assert sha(restore_raw) == '768d333cceb7e9d5e05bcb299f1ee579c8acd5174c5aec54c3afe76e0c074afb'
    db_before = identity(DATABASE)
    assert db_before == {'device': 2064, 'inode': 5946339, 'bytes': 4355063808,
                         'allocatedBytes': 4355162112, 'nlink': 1,
                         'mtimeNs': 1795753058125287433, 'ctimeNs': 1795753435326503158}
    assert stat.S_IMODE(DATABASE.lstat().st_mode) == 0o444
    activity_before = activity({(r['fileIdentity']['device'], r['fileIdentity']['inode']) for r in parts})
    assert not activity_before['references'] and not activity_before['permissionDenied'], activity_before
    dependencies = []
    worktrees = subprocess.check_output(['sudo', '-u', 'ubuntu', 'git', '--git-dir=/mnt/development/projects/git-mirrors/Maktabah.git', 'worktree', 'list', '--porcelain'], text=True)
    for line in worktrees.splitlines():
        if not line.startswith('worktree '):
            continue
        worktree = Path(line.removeprefix('worktree '))
        if not (worktree / '.git').is_file():
            continue
        command = ['sudo', '-u', 'ubuntu', 'git', '-C', str(worktree), 'grep', '-n', '-I']
        for name in NAMES:
            command += ['-F', '-e', str(ARTIFACT / name)]
        command += ['--', 'Source', 'Scripts', 'tools', 'Maktabah-iOSUITests']
        r = subprocess.run(command, capture_output=True, text=True, timeout=25)
        assert r.returncode == 1 and not r.stdout and not r.stderr, (str(worktree), r.returncode, r.stdout, r.stderr)
        dependencies.append({'worktree': str(worktree), 'exit': r.returncode, 'exactRuntimePathMatches': 0})
    admission = {'schemaVersion': 1, 'startedAt': now(), 'scope': 'Explicit root approval of only the two original public verified compressed parts after published restore receipts',
                 'sourceSHA256': sha(Path(__file__).read_bytes()), 'parts': parts, 'originalReceipts': receipts,
                 'restoreReceiptSHA256': sha(restore_raw), 'databaseBefore': db_before,
                 'activity': activity_before, 'runtimeDependencies': dependencies,
                 'noPlannedUseConfirmedBy': ['root', 'root/reader_perf', 'root/library_v40'],
                 'freeBytesBefore': free_bytes(), 'newPartOrDatabaseHashScans': 0, 'publicDownloads': 0}
    save('PARTS_CLEANUP_ADMISSION.json', admission)
    directory = os.open(ARTIFACT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    removed = []
    try:
        with (OUT / 'PARTS_CLEANUP_JOURNAL.jsonl').open('x') as journal:
            for name, record in zip(NAMES, parts):
                before = identity(ARTIFACT / name)
                assert before == record['fileIdentity']
                journal.write(json.dumps({'stage': 'before-unlink', 'name': name, 'identity': before, 'observedAt': now()}) + '\n')
                journal.flush(); os.fsync(journal.fileno())
                os.unlink(name, dir_fd=directory)
                assert not os.path.lexists(ARTIFACT / name)
                removed.append({'path': str(ARTIFACT / name), 'before': before, 'removedAt': now()})
                journal.write(json.dumps({'stage': 'removed', **removed[-1]}) + '\n')
                journal.flush(); os.fsync(journal.fileno())
        os.fsync(directory)
    finally:
        os.close(directory)
    assert identity(DATABASE) == db_before and stat.S_IMODE(DATABASE.lstat().st_mode) == 0o444
    for r in receipts:
        assert sha((OUT / r['name']).read_bytes()) == r['sha256']
    assert sha((OUT / 'RESTORE_RESULT.json').read_bytes()) == admission['restoreReceiptSHA256']
    free_after = free_bytes()
    result = {'schemaVersion': 1, 'status': 'ONLY_TWO_APPROVED_PUBLIC_COMPRESSED_PARTS_REMOVED_VERIFIED_DATABASE_RETAINED',
              'completedAt': now(), 'sourceSHA256': admission['sourceSHA256'], 'removed': removed,
              'logicalBytesRemoved': sum(r['before']['bytes'] for r in removed),
              'allocatedBytesRemoved': sum(r['before']['allocatedBytes'] for r in removed),
              'freeBytesBefore': admission['freeBytesBefore'], 'freeBytesAfter': free_after,
              'observedFreeBytesDelta': free_after - admission['freeBytesBefore'],
              'databaseAfter': identity(DATABASE), 'databaseMode': '0444',
              'originalReceiptsUnchanged': True, 'allOtherFilesUntouchedByThisScript': True,
              'newPartOrDatabaseHashScans': 0, 'publicDownloads': 0, 'nativeExecutions': 0}
    save('PARTS_CLEANUP_RESULT.json', result)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
