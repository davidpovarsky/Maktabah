#!/usr/bin/env python3
"""Unlink only the explicitly approved public-reconstructable 144 payload names."""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess

OUT = Path(__file__).resolve().parent
INVENTORY_SHA = '6459030b79350a22a2def6b85d25daed64de03fb4db2d1bdb3d1f578bdd83cd4'
PUBLIC_SHA = 'a4562c412c5fe823a2dcf5becc67d51de2b9652256ad94051d55dddd7afc2efc'
INSPECTOR_SHA = '193f829e88421d089d5751b29adeb811942adfa70a7b197a49d322da9c4ce70e'
BASE = Path('/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source')
CORE = BASE.parents[1]
ROOTS = [BASE / 'full-index-v40', BASE / 'qualified-index-v40']
PATTERN = re.compile(r'[0-9a-f]{32}\.(fast|fieldnorm|idx|pos|store|term)\Z')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def fingerprint(s):
    assert stat.S_ISREG(s.st_mode)
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns}


def save(name, value):
    path = OUT / name
    assert not path.exists(), 'Never overwrite cleanup evidence'
    with path.open('x', encoding='utf-8') as output:
        json.dump(value, output, indent=2)
        output.write('\n')
        output.flush()
        os.fsync(output.fileno())


def free_bytes():
    s = os.statvfs(OUT)
    return s.f_bavail * s.f_frsize


def metadata_witness(rows):
    witnesses = []
    for row in rows:
        path = Path(row['path'])
        assert path.parent in ROOTS and not PATTERN.fullmatch(path.name)
        assert path.resolve(strict=True) == path
        observed = fingerprint(path.lstat())
        assert observed == {key: row[key] for key in observed}
        raw = path.read_bytes()
        assert len(raw) == row['bytes'] and sha(raw) == row['sha256']
        witnesses.append({'path': str(path), **observed, 'sha256': sha(raw)})
    return witnesses


def main():
    assert OUT == Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127/docs/hq-integration/wave2-20261127/search/corpus-restore')
    assert not (OUT / 'CLEANUP_JOURNAL.jsonl').exists() and not (OUT / 'CLEANUP_RESULT.json').exists()
    inventory_raw = (OUT / 'INVENTORY.json').read_bytes()
    public_raw = (OUT / 'PUBLIC_STREAM_RESULT.json').read_bytes()
    assert sha(inventory_raw) == INVENTORY_SHA and sha(public_raw) == PUBLIC_SHA
    inventory, public = json.loads(inventory_raw), json.loads(public_raw)
    assert public['status'] == 'PUBLIC_STREAM_RECONSTRUCTS_CURRENT_SOURCE_NO_CLEANUP'
    assert public['inventorySHA256'] == INVENTORY_SHA and public['verifiedParts'] == 74
    assert public['payloadDiskBytesWritten'] == 0 and not public['cleanupPerformed']
    rows = inventory['files']
    assert len(rows) == 72 and inventory['payloadPathCount'] == 144
    assert sum(row['allocatedBytes'] for row in rows) == 4_109_066_240
    public_files = {part['destinationPath']: part for part in public['parts']}
    inodes = set()
    for root in ROOTS:
        assert root.resolve(strict=True) == root and root.is_dir()
    for row in rows:
        assert PATTERN.fullmatch(row['name']) and row['nlink'] == 2
        assert row['paths'] == [str(root / row['name']) for root in ROOTS]
        assert (row['device'], row['inode']) not in inodes
        inodes.add((row['device'], row['inode']))
        part = public_files[row['name']]
        assert part['decodedSHA256'] == row['sha256'] and part['decodedBytes'] == row['bytes']
        assert part['matchesCurrentSource'] and part['decoderExit'] == 0
        for path in row['paths']:
            value = fingerprint(Path(path).lstat())
            assert value == {key: row[key] for key in value}
    before_metadata = metadata_witness(inventory['preservedMetadata'])
    commands = [
        ['sudo', '-u', 'ubuntu', 'git', '-C', str(CORE), 'ls-files', '-z', '--',
         'build/zayit-v40-source/full-index-v40', 'build/zayit-v40-source/qualified-index-v40'],
        ['sudo', '-u', 'ubuntu', 'git', '-C', str(CORE), 'grep', '-n', '-I', '-e',
         'full-index-v40', '-e', 'qualified-index-v40', '--', 'Source', 'Scripts', 'tools'],
    ]
    dependencies = []
    for index, command in enumerate(commands):
        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
        assert result.returncode == (0 if index == 0 else 1) and not result.stdout and not result.stderr
        dependencies.append({'command': command, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
    inspector_path = OUT / 'inspect-v40-index-hardlinks.py'
    assert sha(inspector_path.read_bytes()) == INSPECTOR_SHA
    spec = importlib.util.spec_from_file_location('original_payload_inventory', inspector_path)
    inspector = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inspector)
    activity = inspector.activity(inodes)
    assert not activity['references'] and not activity['permissionDenied'], 'Active references or permission gaps block cleanup'
    admission = {'schemaVersion': 1, 'startedAt': now(), 'scope': 'Root approved only exact144 payload paths in inventory6459030b; all nonpayload files remain',
                 'inventorySHA256': INVENTORY_SHA, 'publicStreamSHA256': PUBLIC_SHA,
                 'cleanupSourceSHA256': sha(Path(__file__).read_bytes()), 'payloadPaths': [p for row in rows for p in row['paths']],
                 'activity': activity, 'gitAndRuntimeSourceDependencies': dependencies,
                 'preservedMetadataBefore': before_metadata, 'freeBytesBefore': free_bytes(),
                 'expectedReclaimableAllocatedBytes': 4_109_066_240,
                 'plannedUseConfirmedAbsent': ['root/reader_perf', 'root/library_v40'],
                 'corpusDownloadStarted': False}
    save('CLEANUP_ADMISSION.json', admission)
    roots = [os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW) for root in ROOTS]
    removed = []
    try:
        with (OUT / 'CLEANUP_JOURNAL.jsonl').open('x', encoding='utf-8') as journal:
            for row in rows:
                expected = {key: row[key] for key in fingerprint(os.stat(row['name'], dir_fd=roots[0], follow_symlinks=False))}
                first = fingerprint(os.stat(row['name'], dir_fd=roots[0], follow_symlinks=False))
                second = fingerprint(os.stat(row['name'], dir_fd=roots[1], follow_symlinks=False))
                assert first == second == expected and first['nlink'] == 2
                record = {'name': row['name'], 'firstPath': row['paths'][0], 'secondPath': row['paths'][1], 'before': first, 'startedAt': now()}
                journal.write(json.dumps({'stage': 'before-owned-pair', **record}) + '\n')
                journal.flush(); os.fsync(journal.fileno())
                os.unlink(row['name'], dir_fd=roots[0])
                remaining = fingerprint(os.stat(row['name'], dir_fd=roots[1], follow_symlinks=False))
                assert remaining['nlink'] == 1 and remaining['ctimeNs'] >= first['ctimeNs']
                assert {key: value for key, value in remaining.items() if key not in ('nlink', 'ctimeNs')} == {key: value for key, value in first.items() if key not in ('nlink', 'ctimeNs')}
                assert not os.path.lexists(row['paths'][0])
                record['afterFirstOwnedUnlink'] = remaining
                os.unlink(row['name'], dir_fd=roots[1])
                assert not any(os.path.lexists(path) for path in row['paths'])
                record['completedAt'] = now()
                removed.append(record)
                journal.write(json.dumps({'stage': 'pair-removed', **record}) + '\n')
                journal.flush(); os.fsync(journal.fileno())
    finally:
        for descriptor in roots:
            os.close(descriptor)
    after_metadata = metadata_witness(inventory['preservedMetadata'])
    assert before_metadata == after_metadata and len(removed) == 72
    for root in ROOTS:
        assert not any(PATTERN.fullmatch(path.name) for path in root.iterdir())
    free_after = free_bytes()
    result = {'schemaVersion': 1, 'status': 'APPROVED_PUBLIC_DUPLICATE_PAYLOADS_REMOVED_METADATA_PRESERVED',
              'completedAt': now(), 'inventorySHA256': INVENTORY_SHA, 'publicStreamSHA256': PUBLIC_SHA,
              'cleanupSourceSHA256': sha(Path(__file__).read_bytes()), 'removedPaths': 144, 'removedUniqueInodes': 72,
              'uniquePayloadLogicalBytes': 4_108_851_123, 'expectedReclaimableAllocatedBytes': 4_109_066_240,
              'freeBytesBefore': admission['freeBytesBefore'], 'freeBytesAfter': free_after,
              'observedFreeBytesDelta': free_after - admission['freeBytesBefore'],
              'preservedMetadata': after_metadata, 'allOtherPathsUntouchedByThisScript': True,
              'corpusDownloadStarted': False, 'corpusReservationStarted': False,
              'requiredRestoreCompressedPlusDatabaseBytes': 6_484_966_444, 'requiredResidualReserveBytes': 1_073_741_824,
              'restoreBudgetAdmittedAtObservation': free_after >= 7_558_708_268}
    save('CLEANUP_RESULT.json', result)
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        if not (OUT / 'CLEANUP_FAILURE.json').exists():
            save('CLEANUP_FAILURE.json', {'observedAt': now(), 'error': type(error).__name__ + ': ' + str(error),
                                         'journalPath': str(OUT / 'CLEANUP_JOURNAL.jsonl'), 'corpusDownloadStarted': False})
        raise
