#!/usr/bin/env python3
"""Independent Windows verification; no Mac mutation or extraction."""
from pathlib import Path, PurePosixPath
import base64
import collections
import datetime
import gzip
import hashlib
import importlib.util
import io
import json
import os
import shutil
import sys
import tarfile
import time

ROOT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-covered-scopes-preservation-20261127')
ARTIFACTS = ROOT.parent
RESERVE = 2415919104
ARCHIVES = {
    'app-generated': ('otzaria-wave3-app-generated-caches-20261127', 'inactive-app-generated-caches.tar.gz',
                      'MEMBER_MANIFEST.json', 'VERIFIED_ARCHIVE.json',
                      '83126774b56474c0406918f423372f75b97ccf55e67b8b3450e73fac62133606'),
    'old-sdk-producer': ('otzaria-wave3-interrupted-sdk-work-20261127', 'interrupted-original-sdk-work.tar.gz',
                         'MEMBER_MANIFEST.json', 'VERIFIED_ARCHIVE.json',
                         '7588011139c99fd2c6bad995fd799a74cafcac1a7e8e5378e0d615cbf7792424'),
    'fresh-sdk-differential': ('otzaria-wave3-fresh-producer-preservation-20261127', 'fresh-producer-differential.tar.gz',
                               'MANIFEST.json', 'VERIFIED_DIFFERENTIAL.json',
                               '485d1842dd531c9f6211a9498bddaa1139089fac92efee2abb436a716fced53f'),
    'qualified-snapshot-differential': ('otzaria-wave3-qualified-snapshot-preservation-20261127', 'qualified-snapshot-differential.tar.gz',
                                        'MANIFEST.json', 'VERIFIED_DIFFERENTIAL.json',
                                        '1be15f9c4f63809eaedbadfbabfad49ea3283673e71c31906c50d524f7be5fd9'),
}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): h.update(b)
    return h.hexdigest()


def identity(path):
    s = path.stat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def save(path, data):
    assert shutil.disk_usage(str(ROOT)).free - len(data) >= RESERVE
    with path.open('xb') as f:
        f.write(data); f.flush(); os.fsync(f.fileno())


def main(expected_manifest):
    started = time.monotonic()
    manifest_path = ROOT / 'MANIFEST.json'
    assert digest(manifest_path) == expected_manifest
    raw = manifest_path.read_bytes(); manifest = json.loads(raw)
    body = ROOT / 'covered_scopes.py'
    assert digest(body) == manifest['script_sha256']
    spec = importlib.util.spec_from_file_location('exact_scope_inventory_source', body)
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    assert manifest['schema'] == 'otzaria.two-covered-scopes/1'
    assert manifest['roots'] == [str(p).replace('\\', '/') for p in module.ROOTS]
    assert manifest['new_payload_bytes'] == 0 and not manifest['anything_deleted']
    assert manifest['open_use_before']['open_paths'] == manifest['open_use_after']['open_paths'] == []
    assert manifest['open_use_before']['process_references'] == manifest['open_use_after']['process_references'] == []
    required = {}; summaries = []
    for index, scope in enumerate(manifest['scopes']):
        rows = scope['entries']; by_path = {r['path']: r for r in rows}
        assert len(by_path) == len(rows)
        root_name = PurePosixPath(scope['root']).name
        assert root_name in by_path and by_path[root_name]['type'] == 'directory'
        hardlinks = collections.defaultdict(list)
        files = []
        for row in rows:
            path = PurePosixPath(row['path'])
            assert not path.is_absolute() and path.parts[0] == root_name and '..' not in path.parts
            if str(path) != root_name:
                assert by_path[str(path.parent)]['type'] == 'directory'
            assert row['type'] in ('directory', 'file', 'symlink')
            assert row['mode'] >= 0 and row['bytes'] >= 0 and row['nlink'] >= 1
            for key in ('uid', 'gid', 'device', 'inode', 'mtime_ns', 'atime_ns', 'ctime_ns', 'birthtime_ns', 'flags', 'rdev'):
                assert type(row[key]) is int
            names = set()
            for xattr in row['xattrs']:
                name = base64.b64decode(xattr['name_base64'], validate=True)
                data = base64.b64decode(xattr['value_base64'], validate=True)
                assert name and b'\0' not in name and name not in names
                names.add(name)
                assert len(data) == xattr['bytes'] and hashlib.sha256(data).hexdigest() == xattr['sha256']
            if row['acl'] is not None:
                data = base64.b64decode(row['acl']['text_base64'], validate=True)
                assert len(data) == row['acl']['bytes'] and hashlib.sha256(data).hexdigest() == row['acl']['sha256']
            if row['type'] == 'symlink':
                target = base64.b64decode(row['target_bytes_base64'], validate=True)
                assert target == row['target'].encode('utf-8', errors='surrogateescape')
            elif row['type'] == 'file':
                files.append(row)
                payload = row['payload']; aid = payload['archive_id']
                assert aid in ARCHIVES
                archive = next(a for a in manifest['archives'] if a['id'] == aid)
                assert payload['archive_sha256'] == archive['archive_sha256']
                key = (aid, payload['member']); value = (row['sha256'], row['bytes'])
                assert key not in required or required[key] == value
                required[key] = value
                if row['nlink'] > 1: hardlinks[row['hardlink_group']].append(row)
        for group in hardlinks.values():
            assert len(group) == group[0]['nlink']
            assert len({(r['sha256'], r['bytes'], r['device'], r['inode']) for r in group}) == 1
        assert len(files) == module.EXPECTED_FILES[index]
        assert sum(x['bytes'] for x in files) == module.EXPECTED_BYTES[index]
        summaries.append({'label': scope['label'], 'root': scope['root'], 'entries': len(rows), 'files': len(files),
                          'directories': sum(r['type'] == 'directory' for r in rows),
                          'symlinks': sum(r['type'] == 'symlink' for r in rows),
                          'logical_file_bytes': sum(r['bytes'] for r in files),
                          'hardlink_groups': len(hardlinks), 'xattr_entries': sum(bool(r['xattrs']) for r in rows),
                          'acl_entries': sum(r['acl'] is not None for r in rows)})
    bindings = []
    found = set()
    for row in manifest['archives']:
        aid = row['id']; directory, archive_name, manifest_name, receipt_name, receipt_sha = ARCHIVES[aid]
        directory = ARTIFACTS / directory
        previous_manifest = directory / manifest_name
        receipt = directory / receipt_name
        assert digest(receipt) == receipt_sha
        prior = json.loads(receipt.read_bytes())
        assert prior['status'].startswith('COMPLETE_') and 'VERIFIED' in prior['status']
        assert digest(previous_manifest) == row['manifest_sha256']
        counts = {'entries': 0, 'new_payloads': 0}
        physical = 'new_payloads' if 'differential' in aid else 'entries'
        before_manifest = identity(previous_manifest)
        with previous_manifest.open(encoding='utf-8') as f:
            for kind, entry in module.Stream(f).arrays():
                counts[kind] += 1
                if kind != physical or (kind == 'entries' and entry.get('type') != 'file'): continue
                member = entry['path'] if physical == 'entries' else entry['member']
                key = (aid, member)
                if key in required:
                    assert key not in found
                    assert (entry['sha256'], entry['bytes']) == required[key]
                    found.add(key)
        assert counts == row['counts'] and identity(previous_manifest) == before_manifest
        archive = directory / archive_name
        before = identity(archive)
        assert before['bytes'] == row['archive_bytes'] and digest(archive) == row['archive_sha256']
        assert identity(archive) == before
        bindings.append({'id': aid, 'archive': str(archive), 'archive_bytes': row['archive_bytes'],
                         'archive_sha256': row['archive_sha256'], 'archive_identity': before,
                         'manifest': str(previous_manifest), 'manifest_sha256': row['manifest_sha256'],
                         'full_member_verification_receipt': str(receipt), 'full_member_verification_receipt_sha256': receipt_sha,
                         'full_member_verification_status': prior['status']})
    assert found == set(required)
    archive = ROOT / 'covered-scopes-metadata-only.tar.gz'
    assert shutil.disk_usage(str(ROOT)).free - 3 * len(raw) - 1024**2 >= RESERVE
    with archive.open('xb') as output:
        with gzip.GzipFile(fileobj=output, mode='wb', mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode='w|', format=tarfile.PAX_FORMAT) as tar:
                info = tarfile.TarInfo('MANIFEST.json'); info.size = len(raw); info.mode = 0o600
                tar.addfile(info, io.BytesIO(raw))
        output.flush(); os.fsync(output.fileno())
    with gzip.open(archive, 'rb') as zipped:
        with tarfile.open(fileobj=zipped, mode='r|') as tar:
            members = []
            for member in tar:
                members.append(member.name)
                assert member.isfile() and member.name == 'MANIFEST.json' and member.size == len(raw)
                assert tar.extractfile(member).read() == raw
            assert members == ['MANIFEST.json']
        while zipped.read(1024**2): pass
    proof = {'status': 'COMPLETE_TWO_SCOPE_METADATA_AND_EXACT_PRIOR_PAYLOAD_REFERENCES_VERIFIED', 'utc': utc(),
             'roots': manifest['roots'], 'manifest_sha256': expected_manifest, 'manifest_bytes': len(raw),
             'script_sha256': manifest['script_sha256'], 'verifier_sha256': digest(Path(__file__)),
             'all_metadata_preserved': True, 'all_payload_references_verified': True,
             'metadata_archive_verified': True, 'new_payload_bytes': 0, 'scopes': summaries,
             'distinct_exact_archive_member_references': len(required), 'archive_bindings': bindings,
             'metadata_archive': {'path': str(archive), 'bytes': archive.stat().st_size, 'sha256': digest(archive)},
             'free_after': shutil.disk_usage(str(ROOT)).free, 'reserve': RESERVE,
             'full_restored_tree_materialized': False, 'native_acceptance': 0, 'new_sdk_qualification': False,
             'anything_deleted': False, 'seconds': time.monotonic() - started}
    data = (json.dumps(proof, sort_keys=True, separators=(',', ':')) + '\n').encode()
    save(ROOT / 'VERIFIED_PRESERVATION.json', data)
    print(json.dumps({'path': str(ROOT / 'VERIFIED_PRESERVATION.json'), 'bytes': len(data),
                      'sha256': hashlib.sha256(data).hexdigest(), 'proof': proof}))


if __name__ == '__main__':
    main(sys.argv[1])
