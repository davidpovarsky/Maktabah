#!/usr/bin/env python3
"""Bind every prior reference to current immutable archives and full receipts."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
import types

ROOT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-session-pair-preservation-20261127')
ORACLE = '/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127'
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
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


def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): h.update(b)
    return h.hexdigest()


def identity(p):
    s = p.stat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def save(name, raw):
    if not isinstance(raw, bytes): raw = (json.dumps(raw, sort_keys=True) + '\n').encode()
    assert shutil.disk_usage(ROOT).free - len(raw) >= RESERVE
    with (ROOT / name).open('xb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())
    return {'path': str(ROOT / name), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def remote(name, expected):
    assert '/' not in name and '\\' not in name
    result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'torah-social',
                             '/bin/cat ' + shlex.quote(ORACLE + '/' + name)], capture_output=True, timeout=30)
    assert result.returncode == 0 and len(result.stdout) < 4 * 1024**2, result.stderr.decode(errors='replace')
    assert hashlib.sha256(result.stdout).hexdigest() == expected
    save(name, result.stdout)
    return result.stdout


def main(expected_ledger, expected_new_receipt):
    started = time.monotonic(); before = shutil.disk_usage(ROOT).free
    header = json.loads(remote('HEADER.json', HEADER_SHA))
    assert header['schema'] == 'otzaria.session-pair-preservation/1'
    ledger = json.loads(remote('PRIOR_REFERENCES.json', expected_ledger))
    new_receipt = json.loads(remote('NEW_ARCHIVE_VERIFIED.json', expected_new_receipt))
    assert ledger['header_sha256'] == new_receipt['header_sha256'] == HEADER_SHA
    assert ledger['base_archives'] == header['base_archives']
    assert ledger['source_entries_sha256'] == header['metadata'][0]['sha256']
    assert new_receipt['prior_reference_ledger']['sha256'] == expected_ledger
    assert new_receipt['status'] == 'COMPLETE_NEW_DIFFERENTIAL_MEMBERS_VERIFIED_PRIOR_REFERENCES_AWAIT_WINDOWS'
    body = remote('session_pair.py', header['script_sha256'])
    module = types.ModuleType('pinned_stream_parser'); module.__file__ = str(ROOT / 'session_pair.py')
    exec(compile(body, module.__file__, 'exec'), module.__dict__)
    required = {}
    for row in ledger['references']:
        key = (row['archive_id'], row['member'])
        assert key not in required and row['archive_id'] in ARCHIVES and row['source_files'] > 0
        required[key] = (row['sha256'], row['bytes'])
    assert len(required) == new_receipt['prior_distinct_members']
    found = set(); bindings = []
    for pin in header['base_archives']:
        aid = pin['id']; dirname, archive_name, manifest_name, receipt_name, receipt_sha = ARCHIVES[aid]
        directory = ROOT.parent / dirname
        previous_manifest = directory / manifest_name; receipt = directory / receipt_name
        before_manifest = identity(previous_manifest); before_receipt = identity(receipt)
        assert digest(receipt) == receipt_sha and digest(previous_manifest) == pin['manifest_sha256']
        prior = json.loads(receipt.read_bytes())
        assert prior['status'].startswith('COMPLETE_') and 'VERIFIED' in prior['status']
        counts = {'entries': 0, 'new_payloads': 0}
        physical = 'new_payloads' if 'differential' in aid else 'entries'
        with previous_manifest.open(encoding='utf-8') as f:
            for kind, row in module.Stream(f).arrays():
                counts[kind] += 1
                if kind != physical or (kind == 'entries' and row.get('type') != 'file'): continue
                member = row['member'] if physical == 'new_payloads' else row['path']
                key = (aid, member)
                if key in required:
                    assert key not in found and (row['sha256'], row['bytes']) == required[key]
                    found.add(key)
        assert counts == pin['counts']
        assert identity(previous_manifest) == before_manifest and identity(receipt) == before_receipt
        archive = directory / archive_name; before_archive = identity(archive)
        assert before_archive['bytes'] == pin['archive_bytes'] and digest(archive) == pin['archive_sha256']
        assert identity(archive) == before_archive
        bindings.append({'id': aid, 'archive': str(archive), 'archive_sha256': pin['archive_sha256'],
                         'archive_bytes': pin['archive_bytes'], 'archive_identity': before_archive,
                         'manifest': str(previous_manifest), 'manifest_sha256': pin['manifest_sha256'],
                         'manifest_identity': before_manifest,
                         'full_member_receipt': str(receipt), 'full_member_receipt_sha256': receipt_sha,
                         'full_member_receipt_identity': before_receipt, 'full_member_status': prior['status'],
                         'referenced_members': sum(k[0] == aid for k in required)})
    assert found == set(required)
    result = {'status': 'COMPLETE_PAIR_DIFFERENTIAL_AND_PRIOR_MEMBER_BINDINGS_VERIFIED_NOT_RETIRED',
              'utc': utc(), 'header_sha256': HEADER_SHA, 'prior_reference_ledger_sha256': expected_ledger,
              'new_archive_verification_sha256': expected_new_receipt,
              'new_archive': new_receipt['archive'], 'new_archive_sha256': new_receipt['archive_sha256'],
              'new_archive_bytes': new_receipt['archive_bytes'], 'archive_bindings': bindings,
              'prior_members_verified': len(found),
              'covered_source_files': sum(r['source_files'] for r in ledger['references']),
              'new_payloads_verified': new_receipt['new_payloads_verified'],
              'source_entries': sum(s['entries'] for s in header['scopes']),
              'source_files': sum(s['files'] for s in header['scopes']),
              'source_logical_bytes': sum(s['logical_bytes'] for s in header['scopes']),
              'new_archive_validation_scope': 'Every new member byte plus full metadata/pathset validation on Oracle; actual receipt pinned.',
              'prior_validation_scope': 'Current full archive hashes plus exact physical-member manifest hashes and immutable prior full-member verification receipts.',
              'full_restored_tree_materialized': False, 'source_retirement_authorized': False,
              'anything_deleted': False, 'native_acceptance': 0, 'new_sdk_qualification': False,
              'verifier_sha256': digest(Path(__file__)), 'windows_free_before': before,
              'windows_free_after': shutil.disk_usage(ROOT).free, 'seconds': time.monotonic() - started}
    result['receipt'] = save('COMPLETE_PRESERVATION_VERIFIED.json', result)
    print(json.dumps(result))


if __name__ == '__main__':
    assert len(sys.argv) == 3
    main(sys.argv[1], sys.argv[2])
