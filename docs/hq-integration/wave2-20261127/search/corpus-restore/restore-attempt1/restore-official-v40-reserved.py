#!/usr/bin/env python3
"""Restore official pinned v40 into already reserved owned capacity.

Use the unchanged original official resolver. Preserve independent per-part,
concatenated-compressed, decoded and actual on-disk database digests. Never
assemble a second compressed archive or claim an application/UI installation.
"""
import contextlib
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import sqlite3
import stat
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

EVIDENCE = Path(__file__).resolve().parent
WORK = Path('/mnt/development/projects/artifacts/Maktabah-wave2-search-20261127/corpus-v40-recovery-20261127')
RESERVATION_SHA = '8efd950e3b1a792390e754cfdf7f2a7e00ad9c8badfc6b9c1198f3ee8263c48d'
CORE = Path('/mnt/development/projects/worktrees/Maktabah-core-final-20261126')
EXPECTED = {
    'release_id': 455390662, 'release_tag': 'v40-20261123094345', 'asset_id': 782942035,
    'asset_name': 'seforim-schema7.db.zst', 'compressed_bytes': 2_129_902_636,
    'compressed_sha256': '39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587',
    'remote_asset_name': 'seforim-schema7.db.zst.manifest.json', 'remote_asset_bytes': 589,
    'remote_asset_sha256': 'ab51577bad2f457e24ab5f28082ba830597951ab5738a39652dec821e1dff2e3',
}
PARTS = [
    (782942221, 'seforim-schema7.db.zst.part-000', 1_992_294_400, '91a9985084e5217b661664c3b53c357aaf354498752bf9f7c55d93581dcc9c33'),
    (782993890, 'seforim-schema7.db.zst.part-001', 137_608_236, 'a5469c776bae891d49dfcf33986474416b56ee739c4b0fba37ef7eb9ec53af1a'),
]
DATABASE_BYTES = 4_355_063_808
DATABASE_SHA = '8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01'
COUNTS = {'book': 8259, 'line': 7925185, 'link': 7001824}
BUFFER = 1024 * 1024
decoder = None
stage = 'not-started'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def stamp(s):
    assert stat.S_ISREG(s.st_mode)
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns}


def write(name, value, *, progress=False):
    path = EVIDENCE / name
    raw = json.dumps(value, indent=2).encode() + b'\n'
    if progress:
        temporary = path.with_name(path.name + '.owned-pending')
        temporary.write_bytes(raw)
        temporary.replace(path)
    else:
        with path.open('xb') as output:
            output.write(raw)
            output.flush()
            os.fsync(output.fileno())
    return {'path': str(path), 'bytes': len(raw), 'sha256': sha(raw)}


def free():
    s = os.statvfs(WORK)
    return s.f_bavail * s.f_frsize


def official_request(url, *, offset=0):
    headers = {'User-Agent': 'Maktabah-Official-V40-Recovery', 'Accept-Encoding': 'identity'}
    if offset:
        headers['Range'] = 'bytes=' + str(offset) + '-'
    return urllib.request.Request(url, headers=headers)


def small_public(url, destination, maximum):
    with urllib.request.urlopen(official_request(url), timeout=30) as response:
        assert response.status == 200
        raw = response.read(maximum + 1)
        assert len(raw) <= maximum
    with destination.open('xb') as handle:
        handle.write(raw)
    return raw


def verify_reserved(reservation):
    assert WORK.resolve(strict=True) == WORK and reservation['directory'] == str(WORK)
    for row in reservation['files']:
        path = Path(row['path'])
        assert path.parent == WORK and path.resolve(strict=True) == path
        assert stamp(path.lstat()) == {key: row[key] for key in stamp(path.lstat())}
    assert free() >= 1_073_741_824, 'Residual reserve was exhausted before download'


def download_part(index, part, reserved):
    global stage
    stage = 'download-part-' + str(index)
    path = Path(reserved['path'])
    assert path.name == part['name'] + '.reserved'
    expected = stamp(path.lstat())
    assert expected == {key: reserved[key] for key in expected}
    received, hasher, requests = 0, hashlib.sha256(), []
    started = now()
    descriptor = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'r+b', buffering=0) as output:
        assert stamp(os.fstat(output.fileno())) == expected
        for attempt in range(1, 4):
            entry = {'attempt': attempt, 'requestedOffset': received, 'startedAt': now()}
            requests.append(entry)
            try:
                with urllib.request.urlopen(official_request(part['browser_download_url'], offset=received), timeout=60) as response:
                    host = urllib.parse.urlsplit(response.url).hostname
                    assert host in ('github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com')
                    assert urllib.parse.urlsplit(response.url).scheme == 'https'
                    assert response.status == (206 if received else 200)
                    if received:
                        assert response.headers.get('Content-Range') == f'bytes {received}-{part["size"] - 1}/{part["size"]}'
                    if response.headers.get('Content-Length') is not None:
                        assert int(response.headers['Content-Length']) == part['size'] - received
                    entry.update(httpStatus=response.status, redirectHost=host)
                    previous_progress = time.monotonic()
                    while True:
                        block = response.read(BUFFER)
                        if not block:
                            break
                        assert received + len(block) <= part['size'], 'Public part exceeded its declared bound'
                        assert output.tell() == received
                        count = output.write(block)
                        assert count == len(block), 'Incomplete reserved-file write'
                        hasher.update(block)
                        received += len(block)
                        if time.monotonic() - previous_progress >= 5:
                            write('RESTORE_PROGRESS.json', {'stage': stage, 'observedAt': now(), 'part': index + 1,
                                  'receivedBytes': received, 'expectedBytes': part['size'], 'attempt': attempt,
                                  'freeBytes': free(), 'assembledCompressedCopyCreated': False}, progress=True)
                            previous_progress = time.monotonic()
                    assert received == part['size'], 'Public response ended before the whole part'
                    assert hasher.hexdigest() == part['digest'][7:]
                    output.flush(); os.fsync(output.fileno())
                    entry.update(completedAt=now(), receivedThrough=received, status='VERIFIED')
                    break
            except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as error:
                entry.update(failedAt=now(), receivedThrough=received, error=type(error).__name__)
                if attempt == 3:
                    raise
                # Only a correctly bound HTTP206 response can continue these
                # actual received bytes. No preallocated length is a resume offset.
        else:
            raise RuntimeError('No verified complete public part')
        assert received == part['size'] and hasher.hexdigest() == part['digest'][7:]
        after = stamp(os.fstat(output.fileno()))
        assert after['device'] == expected['device'] and after['inode'] == expected['inode']
        assert after['bytes'] == expected['bytes'] and after['nlink'] == 1
    verified = path.with_suffix('.verified')
    assert not verified.exists()
    path.rename(verified)
    receipt = {'schemaVersion': 1, 'status': 'PUBLIC_PART_DOWNLOADED_SHA_VERIFIED', 'startedAt': started,
               'completedAt': now(), 'index': index, 'assetID': part['id'], 'assetName': part['name'],
               'originalURL': part['browser_download_url'], 'path': str(verified), 'bytes': received,
               'sha256': hasher.hexdigest(), 'fileIdentity': stamp(verified.lstat()), 'requests': requests}
    write('RESTORE_PART_' + str(index) + '.json', receipt)
    return receipt


def decode_parts(parts, reserved):
    global decoder, stage
    stage = 'verify-compressed-and-decode-directly-into-reserved-database'
    target = Path(reserved['path'])
    assert target.name == 'seforim.db.restoring' and target.resolve(strict=True) == target
    before = stamp(target.lstat())
    assert before == {key: reserved[key] for key in before}
    errors, compressed_parts, stderr = [], [], bytearray()
    total_hash, total_bytes = hashlib.sha256(), 0
    decoder = subprocess.Popen(['zstd', '-d', '-q', '-M128MB', '-c'], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)

    def feed():
        nonlocal total_bytes
        try:
            for part in parts:
                path = Path(part['path'])
                start = stamp(path.lstat())
                assert start == part['fileIdentity']
                hasher, count = hashlib.sha256(), 0
                with path.open('rb') as source:
                    assert stamp(os.fstat(source.fileno())) == start
                    while block := source.read(BUFFER):
                        hasher.update(block); total_hash.update(block)
                        count += len(block); total_bytes += len(block)
                        decoder.stdin.write(block)
                    assert stamp(os.fstat(source.fileno())) == start
                assert stamp(path.lstat()) == start
                assert count == part['bytes'] and hasher.hexdigest() == part['sha256']
                compressed_parts.append({'path': str(path), 'bytes': count, 'sha256': hasher.hexdigest(), 'identityUnchanged': True})
            assert total_bytes == EXPECTED['compressed_bytes'] and total_hash.hexdigest() == EXPECTED['compressed_sha256']
        except Exception as error:
            errors.append(type(error).__name__ + ': ' + str(error))
        finally:
            decoder.stdin.close()

    def drain_stderr():
        try:
            while block := decoder.stderr.read(4096):
                assert len(stderr) + len(block) <= 65536, 'Decoder stderr exceeded bound'
                stderr.extend(block)
        except Exception as error:
            errors.append(type(error).__name__ + ': ' + str(error))

    feeder = threading.Thread(target=feed, daemon=True)
    diagnostic = threading.Thread(target=drain_stderr, daemon=True)
    feeder.start(); diagnostic.start()
    decoded_hash, decoded_bytes = hashlib.sha256(), 0
    last_progress = time.monotonic()
    descriptor = os.open(target, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'r+b', buffering=0) as output:
        assert stamp(os.fstat(output.fileno())) == before
        while block := decoder.stdout.read(BUFFER):
            assert decoded_bytes + len(block) <= DATABASE_BYTES, 'Decoded database exceeded reserved bound'
            assert output.write(block) == len(block)
            decoded_hash.update(block); decoded_bytes += len(block)
            if time.monotonic() - last_progress >= 5:
                write('RESTORE_PROGRESS.json', {'stage': stage, 'observedAt': now(), 'decodedBytes': decoded_bytes,
                      'expectedBytes': DATABASE_BYTES, 'freeBytes': free(), 'assembledCompressedCopyCreated': False}, progress=True)
                last_progress = time.monotonic()
        output.flush(); os.fsync(output.fileno())
        assert stamp(os.fstat(output.fileno()))['bytes'] == DATABASE_BYTES
    feeder.join(timeout=10); diagnostic.join(timeout=10)
    assert not feeder.is_alive() and not diagnostic.is_alive()
    exit_code = decoder.wait(timeout=10)
    assert exit_code == 0 and not errors and not stderr
    assert decoded_bytes == DATABASE_BYTES and decoded_hash.hexdigest() == DATABASE_SHA
    receipt = {'schemaVersion': 1, 'status': 'ORDERED_PUBLIC_PARTS_AND_DECODED_DATABASE_SHA_VERIFIED',
               'completedAt': now(), 'partsReadFromDisk': compressed_parts,
               'compressedBytes': total_bytes, 'compressedSHA256': total_hash.hexdigest(),
               'decodedBytes': decoded_bytes, 'decodedSHA256': decoded_hash.hexdigest(),
               'decoderCommand': decoder.args, 'decoderExit': exit_code, 'decoderMemoryLimitMiB': 128,
               'ioBufferBytes': BUFFER, 'assembledCompressedCopyCreated': False,
               'targetIdentity': stamp(target.lstat())}
    write('RESTORE_DECOMPRESSION.json', receipt)
    decoder = None
    return target, receipt


def verify_database(target):
    global stage
    stage = 'full-on-disk-database-sha-and-readonly-sql'
    before = stamp(target.lstat())
    write('RESTORE_PROGRESS.json', {'stage': stage, 'observedAt': now(), 'databaseBytes': before['bytes']}, progress=True)
    with target.open('rb') as source:
        actual_sha = hashlib.file_digest(source, 'sha256').hexdigest()
        assert stamp(os.fstat(source.fileno())) == before
    assert actual_sha == DATABASE_SHA and stamp(target.lstat()) == before
    uri = target.as_uri() + '?mode=ro&immutable=1'
    with contextlib.closing(sqlite3.connect(uri, uri=True)) as connection:
        connection.execute('PRAGMA query_only=ON')
        counts = {table: connection.execute('SELECT COUNT(*) FROM ' + table).fetchone()[0] for table in COUNTS}
        quick_check = [row[0] for row in connection.execute('PRAGMA quick_check')]
        user_version = connection.execute('PRAGMA user_version').fetchone()[0]
        page_size = connection.execute('PRAGMA page_size').fetchone()[0]
        journal_mode = connection.execute('PRAGMA journal_mode').fetchone()[0]
    assert counts == COUNTS and quick_check == ['ok'] and stamp(target.lstat()) == before
    assert not any(Path(str(target) + suffix).exists() for suffix in ('-wal', '-shm', '-journal'))
    return {'schemaVersion': 1, 'completedAt': now(), 'sourceDatabaseURI': uri,
            'bytes': before['bytes'], 'sha256': actual_sha, 'identityBefore': before,
            'identityAfter': stamp(target.lstat()), 'counts': counts, 'quickCheck': quick_check,
            'pragmaUserVersion': user_version, 'pageSize': page_size, 'journalMode': journal_mode,
            'immutableReadOnly': True, 'sidecarsCreated': False}


def main():
    global stage
    assert EVIDENCE == Path('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127/docs/hq-integration/wave2-20261127/search/corpus-restore')
    assert not (EVIDENCE / 'RESTORE_RESULT.json').exists() and not (EVIDENCE / 'RESTORE_ADMISSION.json').exists()
    reservation_raw = (EVIDENCE / 'RESERVATION_RESULT.json').read_bytes()
    assert sha(reservation_raw) == RESERVATION_SHA and (WORK / 'RESERVATION.json').read_bytes() == reservation_raw
    reservation = json.loads(reservation_raw)
    verify_reserved(reservation)
    inventory = json.loads((EVIDENCE / 'INVENTORY.json').read_bytes())
    resolver_path = CORE / 'Scripts/resolve-official-library-asset.py'
    source_receipt = next(row for row in inventory['sourceReceipts'] if row['path'] == str(resolver_path))
    assert sha(resolver_path.read_bytes()) == source_receipt['sha256']
    spec = importlib.util.spec_from_file_location('unchanged_original_official_resolver', resolver_path)
    original = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(original)
    stage = 'official-pinned-release-and-original-resolver'
    raw = small_public('https://api.github.com/repos/Otzaria/SeforimLibrary/releases/455390662',
                       EVIDENCE / 'official-v40-release.raw.json', 1_000_000)
    release = json.loads(raw)
    assert release['id'] == 455390662 and not release['draft'] and not release['prerelease']
    resolved = original.resolve_asset(release)
    assert all(resolved[key] == value for key, value in EXPECTED.items())
    assert len(resolved['parts']) == 2
    for part, expected in zip(resolved['parts'], PARTS):
        assert (part['id'], part['name'], part['size'], original.digest(part)) == expected
        assert part['state'] == 'uploaded'
    manifest_raw = small_public(resolved['browser_download_url'], EVIDENCE / 'official-v40-manifest.raw.json', 589)
    assert len(manifest_raw) == 589 and sha(manifest_raw) == EXPECTED['remote_asset_sha256']
    manifest = json.loads(manifest_raw)
    assert manifest['size'] == EXPECTED['compressed_bytes'] and manifest['sha256'] == EXPECTED['compressed_sha256']
    write('RESTORE_ORIGINAL_RESOLVER.json', resolved)
    admission = {'schemaVersion': 1, 'startedAt': now(), 'scriptSHA256': sha(Path(__file__).read_bytes()),
                 'reservationSHA256': RESERVATION_SHA, 'originalResolver': source_receipt,
                 'publicReleaseSHA256': sha(raw), 'publicManifestSHA256': sha(manifest_raw),
                 'releaseID': 455390662, 'releaseTag': resolved['release_tag'], 'freeBytes': free(),
                 'scope': 'Official source corpus reconstruction only; not in-app/UI installation acceptance',
                 'compressedPlusDatabaseAllocationAlreadyReserved': True,
                 'assembledCompressedCopyCreated': False, 'noDuplicateCorpusJob': True}
    assert free() >= 1_073_741_824
    write('RESTORE_ADMISSION.json', admission)
    parts = [download_part(index, part, reservation['files'][index]) for index, part in enumerate(resolved['parts'])]
    target, decompression = decode_parts(parts, reservation['files'][2])
    sql = verify_database(target)
    sql_witness = write('RESTORE_DATABASE_SQL.json', sql)
    final = WORK / 'seforim.db'
    assert not final.exists() and not final.is_symlink()
    os.chmod(target, 0o444)
    target.rename(final)
    after = stamp(final.lstat())
    result = {'schemaVersion': 1, 'status': 'OFFICIAL_V40_CORPUS_RECONSTRUCTED_FULL_SHA_AND_READONLY_COUNTS_VERIFIED',
              'completedAt': now(), 'sourceDatabase': {'path': str(final), 'uri': final.as_uri() + '?mode=ro&immutable=1',
              'bytes': DATABASE_BYTES, 'sha256': DATABASE_SHA, 'identity': after},
              'releaseID': 455390662, 'releaseTag': resolved['release_tag'], 'manifestAssetID': 782942035,
              'manifestSHA256': EXPECTED['remote_asset_sha256'], 'counts': sql['counts'], 'quickCheck': sql['quickCheck'],
              'compressedBytes': decompression['compressedBytes'], 'compressedSHA256': decompression['compressedSHA256'],
              'sqlReceipt': sql_witness, 'originalResolver': source_receipt,
              'scriptSHA256': sha(Path(__file__).read_bytes()), 'reservationSHA256': RESERVATION_SHA,
              'freeBytesAfter': free(), 'retainedVerifiedCompressedParts': [part['path'] for part in parts],
              'assembledCompressedCopyCreated': False, 'inAppInstallationClaimed': False,
              'nativeUIClaimed': False, 'priorDeletedCorpusInodeContinuityClaimed': False}
    write('RESTORE_RESULT.json', result)
    print(json.dumps(result))


if __name__ == '__main__':
    def expired(_signal, _frame):
        raise TimeoutError('Owned restore exceeded3600seconds')
    signal.signal(signal.SIGALRM, expired)
    signal.alarm(3600)
    try:
        main()
    except BaseException as error:
        if decoder is not None and decoder.poll() is None:
            decoder.terminate()
            try:
                decoder.wait(timeout=2)
            except subprocess.TimeoutExpired:
                decoder.kill(); decoder.wait(timeout=2)
        if not (EVIDENCE / 'RESTORE_FAILURE.json').exists():
            write('RESTORE_FAILURE.json', {'observedAt': now(), 'stage': stage,
                  'error': type(error).__name__ + ': ' + str(error), 'retainedOwnedStaging': True,
                  'inAppInstallationClaimed': False, 'nativeUIClaimed': False})
        raise
    finally:
        signal.alarm(0)
