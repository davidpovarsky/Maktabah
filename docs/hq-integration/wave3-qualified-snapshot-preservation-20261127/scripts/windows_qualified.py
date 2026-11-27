#!/usr/bin/env python3
"""Receive/verify the exact qualified-run snapshot; never delete the source."""
from pathlib import Path, PurePosixPath
import argparse
import base64
import datetime
import gzip
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import time

OUTPUT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-qualified-snapshot-preservation-20261127')
MAC = '/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6'
ROOT = '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt/wave3-qualified-6935f7fd-20261127'
MANIFEST_SHA = '70a15c1afa2456d9dea9f11191df0561f08d766211360c60a5039feca632d660'
MANIFEST_BYTES = 49280191
REFERENCE_SHA = 'ff591293df6c4c8965f4c085c5f3cd35d5b38751a8dd21a0122ec75cf6644f33'
BASE_PROOF_SHA = '5b1f9b85fc969594d6925ffb57e11cfec24da950ffee89c2cd458e83ea5d29cb'
RESERVE = 2 * 1024**3 + 256 * 1024**2
CHUNK = 1024**2
ARCHIVE = OUTPUT / 'qualified-snapshot-differential.tar.gz'
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'scaleway-mac']


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def canonical(v):
    return (json.dumps(v, sort_keys=True, separators=(',', ':')) + '\n').encode()


def save(name, value):
    with (OUTPUT / name).open('xb') as f:
        f.write(canonical(value))


def hash_file(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(CHUNK), b''):
            h.update(b)
    return h.hexdigest()


def guard(extra=0):
    free = shutil.disk_usage(OUTPUT).free
    if free < RESERVE + extra + 65536:
        raise RuntimeError('Windows capacity reserve: ' + str(free))
    return free


def identity(path):
    s = path.stat()
    return {'bytes': s.st_size, 'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns,
            'device': s.st_dev, 'inode': s.st_ino}


def base_proof():
    raw = (OUTPUT / 'BASE_ARCHIVES.json').read_bytes()
    assert hashlib.sha256(raw).hexdigest() == BASE_PROOF_SHA
    proof = json.loads(raw)
    assert proof['status'] == 'THREE_EXACT_PREVIOUSLY_MEMBER_VERIFIED_ARCHIVES_REHASHED'
    expected = {
        'app-generated': ('36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb',1699905882,'5e6fd1ffe65b62333b6543d4b8d189109b56ae66f0d12bfda334aa11db424518'),
        'old-sdk-producer': ('2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda',5238640114,'558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94'),
        'fresh-sdk-differential': ('3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee',944883233,'d47acc0b42ed579d076355901595b66c2b4548a391ae906d27b48a3b210686bb'),
    }
    assert {x['id'] for x in proof['archives']} == set(expected) and len(proof['archives']) == 3
    for item in proof['archives']:
        assert (item['archive_sha256'],item['archive_bytes'],item['manifest_sha256']) == expected[item['id']]
        assert identity(Path(item['archive'])) == item['archive_identity']
        assert hash_file(Path(item['receipt'])) == item['receipt_sha256']
    return proof


def archive_identities(proof):
    return {x['id']:x['archive_identity'] for x in proof['archives']}


def receive():
    assert not ARCHIVE.exists()
    part = Path(str(ARCHIVE) + '.partial')
    assert not part.exists()
    before = guard()
    base = base_proof()
    cmd = SSH + [shlex.join(['/usr/bin/python3', MAC + '/qualified_preservation.py', 'stream',
                             '--evidence', MAC, '--manifest-sha', MANIFEST_SHA])]
    save('RECEIVE_PREFLIGHT.json', {'utc': utc(), 'windows_free': before, 'reserve': RESERVE,
         'command': cmd, 'base_proof': base, 'receiver_sha256': hash_file(Path(__file__)),
         'native_acceptance': 0})
    h, count, minimum = hashlib.sha256(), 0, before
    process = None
    started = time.monotonic()
    try:
        with (OUTPUT / 'MAC_STREAM.stderr.log').open('xb') as err, part.open('xb') as target:
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=err, stdin=subprocess.DEVNULL)
            while True:
                b = process.stdout.read(CHUNK)
                if not b:
                    break
                minimum = min(minimum, guard(len(b) + MANIFEST_BYTES))
                target.write(b)
                h.update(b)
                count += len(b)
                if count % (64 * CHUNK) == 0:
                    (OUTPUT / 'RECEIVE_PROGRESS.json').write_bytes(canonical({'utc': utc(), 'bytes': count,
                        'free': shutil.disk_usage(OUTPUT).free, 'seconds': time.monotonic() - started}))
            target.flush()
            os.fsync(target.fileno())
            code = process.wait(timeout=30)
            assert code == 0, 'Mac stream exit ' + str(code)
        response = subprocess.run(SSH + [shlex.join(['cat', MAC + '/STREAM_RESULT.json'])],
                                  check=True, capture_output=True, timeout=30)
        mac = json.loads(response.stdout)
        assert mac['status'] == 'FULL_SNAPSHOT_DIFFERENTIAL_STREAMED_NOT_RETIRED'
        assert mac['archive_bytes'] == count and mac['archive_sha256'] == h.hexdigest()
        assert mac['manifest_sha256'] == MANIFEST_SHA and mac['source_root'] == ROOT
        assert mac['payloads'] == 3973 and mac['reference_plan_sha256'] == REFERENCE_SHA
        assert base_proof() == base
        with (OUTPUT / 'MAC_STREAM_RESULT.json').open('xb') as f:
            f.write(response.stdout)
        part.rename(ARCHIVE)
        result = {'status': 'EXACT_STREAM_RECEIVED_NOT_YET_MEMBER_VERIFIED_NOT_REMOVED', 'utc': utc(),
                  'archive': str(ARCHIVE), 'archive_sha256': h.hexdigest(), 'archive_bytes': count,
                  'manifest_sha256': MANIFEST_SHA, 'source_root': ROOT, 'mac_evidence': MAC,
                  'free_before': before, 'free_after': guard(), 'minimum_free_before_write': minimum,
                  'reserve': RESERVE, 'seconds': time.monotonic() - started,
                  'archive_identity': identity(ARCHIVE), 'base_archive_identities': archive_identities(base),
                  'mac_stream_result_sha256': hashlib.sha256(response.stdout).hexdigest(), 'native_acceptance': 0}
        save('RECEIVE_RESULT.json', result)
        print(json.dumps(result), flush=True)
    except Exception as error:
        if process is not None and process.poll() is None:
            process.terminate()  # Only the receiver's own SSH child; no foreign PID.
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
        save('RECEIVE_FAILED_' + str(time.time_ns()) + '.json', {'utc': utc(), 'error': repr(error),
             'status': 'FAILED_NOT_REMOVED', 'partial_bytes': count, 'partial_sha256': h.hexdigest(),
             'source_root': ROOT, 'minimum_free_before_write': minimum, 'native_acceptance': 0})
        raise


def safe_relative(value):
    p = PurePosixPath(value)
    assert str(p) == value and not p.is_absolute() and '..' not in p.parts
    assert p.parts and p.parts[0] == ROOT.rsplit('/',1)[-1]
    return p


def blob(v, key):
    b = base64.b64decode(v[key], validate=True)
    assert len(b) == v['bytes'] and hashlib.sha256(b).hexdigest() == v['sha256']
    return b


def verify():
    started = time.monotonic()
    guard()
    base = base_proof()
    received = json.loads((OUTPUT / 'RECEIVE_RESULT.json').read_bytes())
    assert received['archive_identity'] == identity(ARCHIVE)
    assert received['base_archive_identities'] == archive_identities(base)
    archive_hash = hash_file(ARCHIVE)
    assert archive_hash == received['archive_sha256']
    old_entries, base_hashes = {}, {}
    for item in base['archives']:
        data = Path(item['manifest']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == item['manifest_sha256']
        existing = json.loads(data)
        records = existing['new_payloads'] if item['id'] == 'fresh-sdk-differential' else [x for x in existing['entries'] if x['type'] == 'file']
        for value in records:
            member = value['member'] if 'member' in value else value['path']
            key = (item['id'],member)
            assert key not in old_entries
            old_entries[key] = {'type':'file','bytes':value['bytes'],'sha256':value['sha256']}
        base_hashes[item['id']] = item['archive_sha256']
        del data, existing, records
    seen, payloads, manifest = set(), {}, None
    total = 0
    with ARCHIVE.open('rb') as raw, gzip.GzipFile(fileobj=raw, mode='rb') as gz:
        with tarfile.open(fileobj=gz, mode='r|') as archive:
            for number, member in enumerate(archive):
                assert member.isfile() and member.name not in seen and not member.pax_headers
                assert member.mode == 0o600 and member.uid == 0 and member.gid == 0 and member.mtime == 0
                seen.add(member.name)
                stream = archive.extractfile(member)
                if number == 0:
                    assert member.name == 'MANIFEST.json' and member.size == MANIFEST_BYTES
                    data = stream.read()
                    assert len(data) == MANIFEST_BYTES and hashlib.sha256(data).hexdigest() == MANIFEST_SHA
                    manifest = json.loads(data)
                    assert manifest['source_root'] == ROOT and manifest['reference_plan_sha256'] == REFERENCE_SHA
                    assert {x['id']:x['manifest_sha256'] for x in manifest['base_archives']} == {x['id']:x['manifest_sha256'] for x in base['archives']}
                    assert manifest['classification'] == 'PRESERVATION_ONLY_NO_NEW_ACCEPTANCE_OR_CACHE_QUALIFICATION'
                    payloads = {x['member']: x for x in manifest['new_payloads']}
                    assert len(payloads) == len(manifest['new_payloads']) == 3973
                    guard(len(data))
                    with (OUTPUT / 'MANIFEST.json').open('xb') as f:
                        f.write(data)
                else:
                    assert member.name in payloads
                    expected = payloads[member.name]
                    assert member.name == 'objects/sha256/' + expected['sha256'] and member.size == expected['bytes']
                    h, size = hashlib.sha256(), 0
                    for b in iter(lambda: stream.read(CHUNK), b''):
                        h.update(b)
                        size += len(b)
                    assert size == expected['bytes'] and h.hexdigest() == expected['sha256']
                    total += size
                if number % 512 == 0:
                    (OUTPUT / 'VERIFY_PROGRESS.json').write_bytes(canonical({'utc': utc(), 'members': number + 1,
                        'payload_bytes': total, 'seconds': time.monotonic() - started}))
                    guard()
        # Consume the gzip trailer/CRC as well as all tar members. Only tar padding may remain.
        for tail in iter(lambda: gz.read(CHUNK), b''):
            assert not tail.strip(b'\0')
    assert seen == {'MANIFEST.json'} | set(payloads)
    assert manifest is not None
    entries = {x['path']: x for x in manifest['entries']}
    assert len(entries) == len(manifest['entries']) == 65204
    counts = {'file': 0, 'directory': 0, 'symlink': 0}
    reused, new_files, logical, xattrs, acls, links, base_members = 0, 0, 0, 0, 0, {}, set()
    for path, value in entries.items():
        relative = safe_relative(path)
        if path != ROOT.rsplit('/',1)[-1]:
            assert entries[str(relative.parent)]['type'] == 'directory'
        kind = value['type']
        counts[kind] += 1
        for name in ('mode','uid','gid','device','inode','nlink','bytes','allocated_bytes','mtime_ns','atime_ns','ctime_ns','birthtime_ns','flags','rdev'):
            assert isinstance(value[name], int)
        assert 0 <= value['mode'] <= 0o7777 and value['nlink'] >= 1
        attr_names = set()
        for attr in value['xattrs']:
            name = base64.b64decode(attr['name_base64'], validate=True)
            assert name and b'\0' not in name and name not in attr_names
            attr_names.add(name)
            blob(attr, 'value_base64')
        xattrs += bool(value['xattrs'])
        if value['acl'] is not None:
            blob(value['acl'], 'text_base64')
            acls += 1
        if kind == 'symlink':
            assert base64.b64decode(value['target_bytes_base64'], validate=True) == value['target'].encode('utf-8', 'surrogateescape')
        elif kind == 'file':
            logical += value['bytes']
            assert re.fullmatch('[a-f0-9]{64}', value['sha256'])
            reference = value['payload']
            if reference['kind'] == 'base_archive_member':
                assert reference['archive_sha256'] == base_hashes[reference['archive_id']]
                original = old_entries[(reference['archive_id'],reference['member'])]
                assert original['type'] == 'file'
                assert (original['bytes'], original['sha256']) == (value['bytes'], value['sha256'])
                reused += 1
                base_members.add((reference['archive_id'],reference['member']))
            else:
                assert reference['kind'] == 'differential_archive_member'
                original = payloads[reference['member']]
                assert (original['bytes'], original['sha256']) == (value['bytes'], value['sha256'])
                new_files += 1
            if value['nlink'] > 1:
                assert value['hardlink_group'] == str(value['device']) + ':' + str(value['inode'])
                links.setdefault(value['hardlink_group'], []).append(value)
    for group in links.values():
        assert len({(x['bytes'], x['sha256'], x['nlink']) for x in group}) == 1
    for payload in payloads.values():
        source = entries[payload['source_path']]
        assert source['type'] == 'file' and source['payload']['member'] == payload['member']
    summary = manifest['summary']
    assert counts == {'file':52006, 'directory':13120, 'symlink':78}
    assert logical == summary['logical_file_bytes'] == 12813835966
    assert reused == summary['base_reused_files'] == 40984
    assert total == summary['new_unique_payload_bytes'] == 3222367496
    assert xattrs == summary['entries_with_xattrs'] == 390 and acls == summary['entries_with_acl'] == 0
    assert identity(ARCHIVE) == received['archive_identity']
    assert base_proof() == base
    result = {'status': 'COMPLETE_QUALIFIED_SNAPSHOT_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_RETIRED', 'utc': utc(),
              'source_root': ROOT, 'manifest_sha256': MANIFEST_SHA, 'manifest_bytes': MANIFEST_BYTES,
              'archive': str(ARCHIVE), 'archive_sha256': archive_hash, 'archive_bytes': ARCHIVE.stat().st_size,
              'base_archives': base['archives'], 'base_archives_proof_sha256': BASE_PROOF_SHA,
              'reference_plan_sha256': REFERENCE_SHA, 'base_proof': base,
              'entries': len(entries), 'counts': counts, 'logical_file_bytes': logical,
              'verified_payloads': len(payloads), 'verified_payload_bytes': total,
              'base_reused_files': reused, 'base_distinct_members': len(base_members),
              'differential_referenced_files': new_files, 'entries_with_xattrs': xattrs,
              'entries_with_acl': acls, 'hardlink_groups': len(links),
              'all_metadata_and_symlink_targets_retained': True,
              'all_original_parent_directory_relationships_verified': True,
              'gzip_crc_and_all_tar_members_verified': True,
              'full_filesystem_restoration_run': False,
              'restoration_scope': 'Lossless content/metadata manifest and payload references verified; no 12.8GB materialization. Historic inode/device/ctime retained as evidence.',
              'native_acceptance': 0, 'new_sdk_qualification': False, 'retirement_authorized': False, 'anything_deleted': False, 'free_after': guard(),
              'seconds': time.monotonic() - started, 'verifier_sha256': hash_file(Path(__file__))}
    save('VERIFIED_DIFFERENTIAL.json', result)
    print(json.dumps({k:v for k,v in result.items() if k != 'base_proof'}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['receive', 'verify'])
    args = parser.parse_args()
    try:
        receive() if args.mode == 'receive' else verify()
    except Exception as error:
        save(args.mode.upper() + '_ERROR_' + str(time.time_ns()) + '.json',
             {'utc': utc(), 'error': repr(error), 'status': 'FAILED_NOT_REMOVED', 'source_root': ROOT})
        raise
