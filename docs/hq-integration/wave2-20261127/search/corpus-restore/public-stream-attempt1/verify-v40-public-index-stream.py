#!/usr/bin/env python3
"""Verify published compressed assets against current inodes, with no payload cache."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

OUT = Path(__file__).resolve().parent
BUFFER = 1_048_576
PART_SECONDS = 600
JOB_SECONDS = 3600


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, value):
    data = json.dumps(value, ensure_ascii=False, indent=2).encode() + b'\n'
    path = OUT / name
    temporary = path.with_name(path.name + '.owned-pending')
    temporary.write_bytes(data)
    temporary.replace(path)
    return {'path': str(path), 'bytes': len(data), 'sha256': sha(data)}


def fingerprint(path):
    s = path.lstat()
    assert path.resolve() == path and path.is_file() and not path.is_symlink()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns}


def expected_fingerprint(row):
    return {key: row[key] for key in ['device', 'inode', 'bytes', 'allocatedBytes', 'nlink', 'mtimeNs', 'ctimeNs']}


def verify_part(part, current, ordinal, total, job_started):
    begin = time.monotonic()
    assert begin - job_started < JOB_SECONDS
    paths = [Path(p) for p in current['paths']]
    for path in paths:
        assert fingerprint(path) == expected_fingerprint(current)
    assert part['compression'] == 'zstd' and part['destinationOffset'] == 0
    assert part['uncompressedBytes'] == current['bytes']
    original = part['assetURL']
    parsed = urllib.parse.urlsplit(original)
    assert parsed.scheme == 'https' and parsed.hostname == 'github.com' and not parsed.query and not parsed.fragment
    assert parsed.path.startswith('/davidpovarsky/Maktabah/releases/download/zayit-search-data-v40-20261123094345-17cabb80e86a/')
    assert parsed.path.endswith('/' + part['assetName'])
    request = urllib.request.Request(original, headers={'User-Agent': 'Maktabah-Source-Recovery-Audit',
        'Accept': 'application/octet-stream', 'Accept-Encoding': 'identity'})
    command = ['zstd', '-d', '-q', '-M128', '-c']
    decoder = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    abort = threading.Event()
    transport = {'bytes': 0, 'sha256': None, 'status': None, 'finalHost': None, 'error': None}
    stderr = bytearray()
    stderr_truncated = [False]

    def errors():
        while True:
            block = decoder.stderr.read(4096)
            if not block:
                return
            if len(stderr) + len(block) > 65_536:
                stderr_truncated[0] = True
            stderr.extend(block[:max(0, 65_536 - len(stderr))])

    def feed():
        digest = hashlib.sha256()
        count = 0
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                transport['status'] = response.status
                final = urllib.parse.urlsplit(response.geturl())
                # No redirect query/signature is retained anywhere.
                transport['finalHost'] = final.hostname
                assert final.scheme == 'https' and final.hostname in {
                    'github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com',
                    'github-releases.githubusercontent.com'}, 'Unadmitted download origin'
                assert response.status == 200
                assert response.headers.get('Content-Encoding') in [None, 'identity']
                length = response.headers.get('Content-Length')
                if length is not None:
                    assert int(length) == part['packagedBytes']
                while not abort.is_set():
                    block = response.read(BUFFER)
                    if not block:
                        break
                    count += len(block)
                    assert count <= part['packagedBytes'], 'Compressed stream exceeds exact manifest bound'
                    assert time.monotonic() - begin < PART_SECONDS
                    assert time.monotonic() - job_started < JOB_SECONDS
                    digest.update(block)
                    decoder.stdin.write(block)
                    transport['bytes'] = count
                assert not abort.is_set(), 'Owned stream cancelled'
            assert count == part['packagedBytes'], 'Compressed stream size differs'
            transport['sha256'] = digest.hexdigest()
            assert transport['sha256'] == part['sha256'], 'Compressed stream SHA differs'
        except BaseException as error:
            # HTTPError.__str__/repr can expose a signed redirect URL.
            transport['error'] = {'type': type(error).__name__,
                'httpStatus': getattr(error, 'code', None) if isinstance(error, urllib.error.HTTPError) else None}
            abort.set()
        finally:
            try:
                decoder.stdin.close()
            except (BrokenPipeError, OSError):
                pass

    reader = threading.Thread(target=errors, daemon=True)
    feeder = threading.Thread(target=feed, daemon=True)
    reader.start()
    feeder.start()

    def expire():
        abort.set()
        decoder.kill()

    watchdog = threading.Timer(PART_SECONDS, expire)
    watchdog.daemon = True
    watchdog.start()
    digest = hashlib.sha256()
    decoded = 0
    last_progress = 0.0
    try:
        while True:
            block = decoder.stdout.read(BUFFER)
            if not block:
                break
            decoded += len(block)
            assert decoded <= part['uncompressedBytes'], 'Decoded stream exceeds exact source bound'
            digest.update(block)
            if time.monotonic() - last_progress >= 10:
                save('PUBLIC_STREAM_PROGRESS.json', {'observedAt': now(), 'part': ordinal,
                    'partsTotal': total, 'assetName': part['assetName'], 'compressedReceived': transport['bytes'],
                    'compressedExpected': part['packagedBytes'], 'decodedBytes': decoded,
                    'decodedExpected': part['uncompressedBytes'], 'payloadDiskBytesWritten': 0})
                last_progress = time.monotonic()
        code = decoder.wait(timeout=10)
        feeder.join(timeout=35)
        reader.join(timeout=10)
        assert not feeder.is_alive() and not reader.is_alive(), 'A stream worker did not finish'
        assert not abort.is_set() and transport['error'] is None, 'Public stream failed; see bounded transport fields'
        assert code == 0 and not stderr_truncated[0] and not stderr, 'Original zstd decoder failed'
        assert decoded == part['uncompressedBytes'], 'Decoded size differs'
        assert digest.hexdigest() == current['sha256'], 'Public bytes do not reconstruct the current source inode'
        for path in paths:
            assert fingerprint(path) == expected_fingerprint(current), 'Current source changed during public verification'
        return {'ordinal': ordinal, 'assetID': part['assetID'], 'assetName': part['assetName'],
            'originalURL': original, 'destinationPath': part['destinationPath'], 'destinationOffset': 0,
            'httpStatus': transport['status'], 'redirectHost': transport['finalHost'],
            'compressedBytes': transport['bytes'], 'compressedSHA256': transport['sha256'],
            'decodedBytes': decoded, 'decodedSHA256': digest.hexdigest(),
            'sourcePaths': current['paths'], 'sourceFingerprint': expected_fingerprint(current),
            'decoderCommand': command, 'decoderExit': code, 'seconds': time.monotonic() - begin,
            'payloadDiskBytesWritten': 0, 'matchesCurrentSource': True}
    except BaseException as error:
        save('PUBLIC_STREAM_PART_FAILURE.json', {'observedAt': now(), 'ordinal': ordinal,
            'assetName': part['assetName'], 'compressedExpected': part['packagedBytes'],
            'decodedExpected': part['uncompressedBytes'], 'decodedBytes': decoded,
            'transport': transport, 'errorType': type(error).__name__,
            'decoderError': stderr.decode(errors='replace'), 'payloadDiskBytesWritten': 0})
        raise
    finally:
        watchdog.cancel()
        abort.set()
        if decoder.poll() is None:
            decoder.kill()
        try:
            decoder.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        feeder.join(timeout=35)
        reader.join(timeout=5)


def main():
    started = now()
    job_started = time.monotonic()
    assert not (OUT / 'PUBLIC_STREAM_RESULT.json').exists()
    inventory_bytes = (OUT / 'INVENTORY.json').read_bytes()
    inventory = json.loads(inventory_bytes)
    assert inventory['status'] == 'INVENTORY_ONLY_NO_CLEANUP_NO_CORPUS_DOWNLOAD'
    assert inventory['uniquePayloadInodes'] == 72 and inventory['payloadPathCount'] == 144
    assert not inventory['activity']['references'] and not inventory['activity']['permissionDenied']
    manifest_path = Path(inventory['manifest']['path'])
    manifest_bytes = manifest_path.read_bytes()
    assert sha(manifest_bytes) == inventory['manifest']['sha256']
    manifest = json.loads(manifest_bytes)
    public_bytes = (OUT / 'public-zayit-release.raw.json').read_bytes()
    assert sha(public_bytes) == inventory['publicRelease']['sha256']
    assets = {asset['name']: asset for asset in json.loads(public_bytes)['assets']}
    current = {row['name']: row for row in inventory['files']}
    qualified = Path(inventory['roots'][1])
    for name in ['meta.json', 'zayit-index-metadata.json']:
        path = qualified / name
        record = next(row for row in inventory['preservedMetadata'] if row['path'] == str(path))
        assert sha(path.read_bytes()) == record['sha256']
        current[name] = {**record, 'paths': [str(path)]}
    assert len(current) == 74 and len(manifest['parts']) == 74
    rows = []
    for ordinal, item in enumerate(manifest['parts'], start=1):
        asset = assets[item['assetName']]
        assert asset['digest'] == 'sha256:' + item['sha256'] and asset['size'] == item['packagedBytes']
        part = {**item, 'assetID': asset['id'], 'assetURL': asset['browser_download_url']}
        row = verify_part(part, current[item['destinationPath']], ordinal, len(manifest['parts']), job_started)
        rows.append(row)
        save('PUBLIC_STREAM_VERIFIED_PARTS.json', {'startedAt': started, 'observedAt': now(), 'parts': rows})
        print(json.dumps({'part': ordinal, 'total': 74, 'asset': item['assetName'],
            'compressedBytesVerified': sum(x['compressedBytes'] for x in rows),
            'decodedBytesVerified': sum(x['decodedBytes'] for x in rows)}), flush=True)
    for row in inventory['files']:
        assert all(fingerprint(Path(path)) == expected_fingerprint(row) for path in row['paths'])
    assert sum(row['compressedBytes'] for row in rows) == manifest['packagedBytes']
    assert sum(row['decodedBytes'] for row in rows) == manifest['extractedBytes']
    version = subprocess.check_output(['zstd', '--version'], text=True, timeout=5).strip()
    result = {'schemaVersion': 1, 'status': 'PUBLIC_STREAM_RECONSTRUCTS_CURRENT_SOURCE_NO_CLEANUP',
        'startedAt': started, 'completedAt': now(), 'scriptSHA256': sha(Path(__file__).read_bytes()),
        'inventorySHA256': sha(inventory_bytes), 'manifestSHA256': sha(manifest_bytes),
        'publicReleaseSHA256': sha(public_bytes), 'artifactID': manifest['artifactIdentity'],
        'verifiedParts': len(rows), 'uniquePayloadInodes': 72, 'payloadPathCount': 144,
        'compressedBytesVerified': sum(x['compressedBytes'] for x in rows),
        'decodedBytesVerified': sum(x['decodedBytes'] for x in rows),
        'ioBufferBytes': BUFFER, 'decoderMemoryLimitMiB': 128, 'sequentialOwnedJob': True,
        'payloadDiskBytesWritten': 0, 'cleanupPerformed': False, 'decoderVersion': version, 'parts': rows}
    witness = save('PUBLIC_STREAM_RESULT.json', result)
    print(json.dumps({'result': witness, 'verifiedParts': len(rows), 'cleanupPerformed': False}), flush=True)


if __name__ == '__main__':
    try:
        main()
    except BaseException as error:
        save('PUBLIC_STREAM_FAILURE.json', {'observedAt': now(), 'errorType': type(error).__name__,
            'cleanupPerformed': False, 'payloadDiskBytesWritten': 0})
        raise
