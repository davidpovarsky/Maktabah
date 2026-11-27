#!/usr/bin/env python3
"""Read-only payload audit. Writes only this script's small evidence directory."""
import base64
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import urllib.request

BASE = Path('/mnt/development/projects/worktrees/Maktabah-core-final-20261126/build/zayit-v40-source')
CORE = BASE.parents[1]
OUT = Path(__file__).resolve().parent
ROOTS = [BASE / 'full-index-v40', BASE / 'qualified-index-v40']
EXPECTED_MANIFEST_SHA = '577176375f735af240d8a1e84f0a1ad23bf18018ae4c0f716e8acb142d8d8691'
PATTERN = re.compile(r'^[0-9a-f]{32}\.(?:fast|fieldnorm|idx|pos|store|term)$')
SUFFIXES = ['fast', 'fieldnorm', 'idx', 'pos', 'store', 'term']


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def seal(path, limit=1_000_000):
    s = path.lstat()
    assert stat.S_ISREG(s.st_mode) and not path.is_symlink() and s.st_size <= limit
    data = path.read_bytes()
    assert len(data) == s.st_size
    return {'path': str(path), 'bytes': len(data), 'sha256': sha(data)}, data


def fingerprint(s):
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'allocatedBytes': s.st_blocks * 512, 'nlink': s.st_nlink,
            'mtimeNs': s.st_mtime_ns, 'ctimeNs': s.st_ctime_ns}


def save(name, value):
    path = OUT / name
    data = json.dumps(value, ensure_ascii=False, indent=2).encode() + b'\n'
    temporary = path.with_name(path.name + '.owned-pending')
    temporary.write_bytes(data)
    temporary.replace(path)
    return {'path': str(path), 'bytes': len(data), 'sha256': sha(data)}


def activity(inodes):
    references, denied = [], []
    roots = [str(x) for x in ROOTS]
    for process in Path('/proc').iterdir():
        if not process.name.isdigit() or int(process.name) == os.getpid():
            continue
        pid = int(process.name)
        try:
            command = (process / 'cmdline').read_bytes().replace(b'\0', b' ').decode(errors='replace')
            comm = (process / 'comm').read_text().strip()
            cwd = os.readlink(process / 'cwd')
            if str(BASE) in command or any(cwd == r or cwd.startswith(r + '/') for r in roots):
                references.append({'pid': pid, 'kind': 'command-or-cwd', 'comm': comm,
                                   'commandSHA256': sha(command.encode()), 'cwd': cwd})
            for fd in (process / 'fd').iterdir():
                try:
                    s = fd.stat()
                    if (s.st_dev, s.st_ino) in inodes:
                        references.append({'pid': pid, 'kind': 'open-payload-inode',
                                           'fd': fd.name, 'target': os.readlink(fd), 'comm': comm})
                except (FileNotFoundError, ProcessLookupError):
                    pass
            for line in (process / 'maps').read_text().splitlines():
                columns = line.split(maxsplit=5)
                if len(columns) < 5:
                    continue
                major, minor = columns[3].split(':')
                key = (os.makedev(int(major, 16), int(minor, 16)), int(columns[4]))
                if key in inodes:
                    references.append({'pid': pid, 'kind': 'mapped-payload-inode',
                                       'mapping': line, 'comm': comm})
        except (FileNotFoundError, ProcessLookupError):
            pass
        except PermissionError as error:
            denied.append({'pid': pid, 'path': error.filename})
    return {'observedAt': now(), 'inspectorPIDExcluded': os.getpid(),
            'references': references, 'permissionDenied': denied}


def main():
    started = now()
    assert OUT != BASE and str(OUT).startswith('/mnt/development/projects/worktrees/Maktabah-wave2-search-20261127/docs/')
    for root in ROOTS:
        assert root.is_dir() and root.resolve() == root
    manifest_receipt, manifest_bytes = seal(BASE / 'artifact-v40/zayit-search-manifest.json')
    assert manifest_receipt['sha256'] == EXPECTED_MANIFEST_SHA
    manifest = json.loads(manifest_bytes)
    assert manifest['artifactIdentity'] == '17cabb80e86ac8c2d1a3ce16a4e1457d4351709798f2b91a84120d4dd0c6c480'
    assert len(manifest['parts']) == 74
    meta_receipt, meta_bytes = seal(ROOTS[0] / 'meta.json')
    meta = json.loads(meta_bytes)
    segments = [row['segment_id'].replace('-', '') for row in meta['segments']]
    expected = sorted(segment + '.' + extension for segment in segments for extension in SUFFIXES)
    assert len(segments) == 12 and len(set(expected)) == 72
    assert sum(row['max_doc'] for row in meta['segments']) == manifest['counts']['documents'] == 7_930_286
    assert all(row['deletes'] is None for row in meta['segments'])
    for root in ROOTS:
        assert sorted(x.name for x in root.iterdir() if PATTERN.fullmatch(x.name)) == expected
    managed_receipt, managed_bytes = seal(ROOTS[0] / '.managed.json')
    assert set(json.loads(managed_bytes)) == set(expected) | {'meta.json'}

    request_url = 'https://api.github.com/repos/davidpovarsky/Maktabah/releases/458964380'
    request = urllib.request.Request(request_url, headers={
        'User-Agent': 'Maktabah-Source-Recovery-Audit', 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=20) as response:
        public_bytes = response.read(1_000_001)
        assert len(public_bytes) <= 1_000_000
        public_headers = {'etag': response.headers.get('ETag'), 'lastModified': response.headers.get('Last-Modified')}
    release = json.loads(public_bytes)
    assert release['id'] == 458964380 and not release['draft']
    assert release['tag_name'] == 'zayit-search-data-v40-20261123094345-17cabb80e86a'
    assets = {a['name']: a for a in release['assets']}
    assert len(assets) == 76
    public_manifest = assets['zayit-search-manifest.json']
    assert public_manifest['digest'] == 'sha256:' + EXPECTED_MANIFEST_SHA
    assert public_manifest['size'] == len(manifest_bytes)
    bindings = {}
    for part in manifest['parts']:
        asset = assets[part['assetName']]
        assert asset['state'] == 'uploaded' and asset['size'] == part['packagedBytes']
        assert asset['digest'] == 'sha256:' + part['sha256']
        assert part['compression'] == 'zstd' and part['destinationOffset'] == 0
        assert part['destinationPath'] not in bindings
        bindings[part['destinationPath']] = {'assetID': asset['id'], 'assetURL': asset['browser_download_url'],
            **part}
    assert set(bindings) == set(expected) | {'meta.json', 'zayit-index-metadata.json'}
    (OUT / 'public-zayit-release.raw.json').write_bytes(public_bytes)

    rows = []
    unique = set()
    for index, name in enumerate(expected):
        paths = [root / name for root in ROOTS]
        a, b = [p.lstat() for p in paths]
        assert all(stat.S_ISREG(s.st_mode) and s.st_nlink == 2 for s in [a, b])
        assert fingerprint(a) == fingerprint(b)
        assert a.st_size == bindings[name]['uncompressedBytes']
        assert (a.st_dev, a.st_ino) not in unique
        unique.add((a.st_dev, a.st_ino))
        descriptor = os.open(paths[0], os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(descriptor, 'rb') as file:
            assert fingerprint(os.fstat(file.fileno())) == fingerprint(a)
            digest = hashlib.file_digest(file, 'sha256').hexdigest()
            assert fingerprint(os.fstat(file.fileno())) == fingerprint(a)
        assert all(fingerprint(p.lstat()) == fingerprint(a) for p in paths)
        rows.append({'name': name, 'paths': list(map(str, paths)), **fingerprint(a),
                     'sha256': digest, 'publicPart': bindings[name]})
        save('PROGRESS.json', {'startedAt': started, 'observedAt': now(), 'filesHashed': index + 1,
            'totalFiles': len(expected), 'uniqueBytesHashed': sum(r['bytes'] for r in rows)})

    preserved = []
    for root in ROOTS:
        for path in sorted(root.iterdir()):
            if path.name in expected:
                continue
            witness, _ = seal(path)
            preserved.append({**witness, **fingerprint(path.lstat())})
    small_sources = [BASE / 'ZAYIT_V40_PACKAGE_RECEIPT.json', BASE / 'qualified-release.json',
        BASE / 'artifact-v40/zayit-search-manifest.json', BASE / 'artifact-v40/zayit-search-build-metrics.json',
        BASE / 'package-qualified-v40.sh', BASE / 'resume-package-v40.sh', BASE / 'run-full-v40.sh',
        BASE / 'full-index.exit', BASE / 'package-index.exit', BASE / 'package-index.log',
        CORE / 'Scripts/package-zayit-search-artifact.py', CORE / 'Scripts/resolve-official-library-asset.py']
    source_receipts = [seal(path)[0] for path in small_sources]
    old_proof = json.loads((BASE / 'ZAYIT_V40_PACKAGE_RECEIPT.json').read_bytes())
    assert old_proof['verified_parts'] == old_proof['verified_reconstituted_files'] == 74
    assert old_proof['artifact_identity'] == manifest['artifactIdentity']
    assert (BASE / 'full-index.exit').read_text().strip() == '0'
    assert (BASE / 'package-index.exit').read_text().strip() == '0'
    current_activity = activity(unique)
    # Archive only bounded original metadata/source; never a segment payload.
    archive = OUT / 'retained-recovery-metadata.tar.gz'
    with tarfile.open(archive, 'w:gz') as tar:
        for p in small_sources:
            tar.add(p, arcname='original/' + str(p.relative_to(CORE)), recursive=False)
        for root in ROOTS:
            for p in root.iterdir():
                if p.name not in expected:
                    tar.add(p, arcname='original/' + str(p.relative_to(CORE)), recursive=False)
        tar.add(OUT / 'public-zayit-release.raw.json', arcname='public-zayit-release.raw.json', recursive=False)
    fs = subprocess.run(['findmnt', '-T', str(BASE), '-n', '-o', 'TARGET,FSTYPE,SOURCE'],
                        capture_output=True, text=True, timeout=10)
    assert fs.returncode == 0
    result = {'schemaVersion': 1, 'status': 'INVENTORY_ONLY_NO_CLEANUP_NO_CORPUS_DOWNLOAD',
        'startedAt': started, 'completedAt': now(), 'inspectorSHA256': sha(Path(__file__).read_bytes()),
        'cleanupPerformed': False, 'payloadDownloads': 0, 'roots': list(map(str, ROOTS)),
        'files': rows, 'payloadPathCount': len(rows) * 2, 'uniquePayloadInodes': len(unique),
        'uniquePayloadBytes': sum(r['bytes'] for r in rows),
        'uniqueAllocatedPayloadBytes': sum(r['allocatedBytes'] for r in rows),
        'qualifiedOnlyPayloadBytesReclaimable': 0, 'preservedMetadata': preserved,
        'manifest': manifest_receipt, 'meta': meta_receipt, 'managedList': managed_receipt,
        'metaDocumentCount': sum(r['max_doc'] for r in meta['segments']),
        'publicRelease': {'url': request_url, 'sha256': sha(public_bytes), 'bytes': len(public_bytes),
            'releaseID': release['id'], 'tag': release['tag_name'], 'publishedAt': release['published_at'],
            'assetCount': len(assets), 'validatedPartMetadataCount': len(bindings), 'headers': public_headers},
        'historicalRecompositionEvidence': old_proof, 'sourceReceipts': source_receipts,
        'freshPublicPayloadDecodePerformed': False, 'freshRecompressionPerformed': False,
        'activity': current_activity, 'filesystem': fs.stdout.strip(),
        'freeBytes': shutil.disk_usage(BASE).free,
        'metadataArchive': {'path': str(archive), 'bytes': archive.stat().st_size, 'sha256': sha(archive.read_bytes())},
        'plannedUseConfirmations': {'reader_perf': 'no current or planned use of either root; 2026-11-27',
                                    'library_v40': 'no current or planned use of either root; 2026-11-27'},
        'admissionLimit': 'Current local SHA is recorded once per inode. Public metadata matches the original compressed manifest; full compressed-to-uncompressed comparison reuses the retained original 74/74 recomposition evidence, not a fresh payload decode.'}
    assert all(fingerprint(Path(row['paths'][0]).lstat()) == {k: row[k] for k in fingerprint(Path(row['paths'][0]).lstat())}
               and fingerprint(Path(row['paths'][1]).lstat()) == {k: row[k] for k in fingerprint(Path(row['paths'][1]).lstat())}
               for row in rows)
    witness = save('INVENTORY.json', result)
    print(json.dumps({'receipt': witness, 'uniquePayloadBytes': result['uniquePayloadBytes'],
        'uniqueAllocatedPayloadBytes': result['uniqueAllocatedPayloadBytes'],
        'activity': current_activity, 'filesystem': result['filesystem'], 'freeBytes': result['freeBytes']}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        save('FAILURE.json', {'observedAt': now(), 'error': repr(error), 'cleanupPerformed': False})
        raise
