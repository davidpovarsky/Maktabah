#!/usr/bin/env python3
"""Receive/verify the exact leased Mac SDK preservation stream; never delete it."""
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

OUTPUT = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-fresh-producer-preservation-20261127')
BASE = Path(r'C:\Users\DAVID\.codex\artifacts\otzaria-wave3-interrupted-sdk-work-20261127')
MAC = '/Users/m1/builds/otzaria-wave3-fresh-producer-preservation-20261127.hhz749_k'
ROOT = '/Users/m1/builds/otzaria-wave1-sdk-20261127/source/build/SDK-Wave3-1be97035-Debug-FreshAfterCapacity-20261127-Work/producer-derived'
MANIFEST_SHA = 'd47acc0b42ed579d076355901595b66c2b4548a391ae906d27b48a3b210686bb'
MANIFEST_BYTES = 93784007
BASE_SHA = '2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda'
BASE_MANIFEST_SHA = '558af6b185c0accd75906fbfdba747c8511c1448447819a2bc2a43028d766e94'
BASE_BYTES = 5238640114
RESERVE = 2 * 1024**3 + 256 * 1024**2
CHUNK = 1024**2
ARCHIVE = OUTPUT / 'fresh-producer-differential.tar.gz'
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
    fresh = json.loads((OUTPUT / 'BASE_ARCHIVE_READBACK.json').read_text(encoding='utf-8-sig'))
    old = json.loads((BASE / 'VERIFIED_ARCHIVE.json').read_text(encoding='utf-8-sig'))
    assert fresh['status'] == 'EXACT_PREVIOUSLY_ALL_MEMBER_VERIFIED_ARCHIVE_REHASHED'
    assert fresh['sha256'] == BASE_SHA and fresh['bytes'] == BASE_BYTES
    assert fresh['manifestSHA256'] == BASE_MANIFEST_SHA
    assert old['status'] == 'COMPLETE_ARCHIVE_AND_EVERY_MEMBER_VERIFIED_NOT_REMOVED'
    assert old['archiveSHA256'] == BASE_SHA and old['archiveBytes'] == BASE_BYTES
    assert old['manifestSHA256'] == BASE_MANIFEST_SHA
    assert old['regularFiles'] == 119155 and old['entries'] == 138339
    current = identity(BASE / 'interrupted-original-sdk-work.tar.gz')
    assert current['bytes'] == BASE_BYTES and current['mtime_ns'] // 10**6 == 1795756294281
    return {'fresh_rehash': fresh, 'full_member_verification': old,
            'full_member_job': 'job_6f9fcedf19df', 'fresh_rehash_job': 'job_5a22802cb180',
            'current_archive_identity': current,
            'original_archive_identity_observed_before_fresh_rehash': {'bytes': BASE_BYTES, 'mtime_ms': 1795756294281},
            'fresh_receipt_sha256': hash_file(OUTPUT / 'BASE_ARCHIVE_READBACK.json'),
            'old_receipt_sha256': hash_file(BASE / 'VERIFIED_ARCHIVE.json')}


def receive():
    assert not ARCHIVE.exists()
    part = Path(str(ARCHIVE) + '.partial')
    assert not part.exists()
    before = guard()
    base = base_proof()
    cmd = SSH + [shlex.join(['/usr/bin/python3', MAC + '/producer_preservation.py', 'stream',
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
                minimum = min(minimum, guard(len(b)))
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
        assert mac['status'] == 'DIFFERENTIAL_STREAMED_NOT_REMOVED'
        assert mac['archive_bytes'] == count and mac['archive_sha256'] == h.hexdigest()
        assert mac['manifest_sha256'] == MANIFEST_SHA and mac['source_root'] == ROOT
        assert mac['payloads'] == 22521
        assert identity(BASE / 'interrupted-original-sdk-work.tar.gz') == base['current_archive_identity']
        with (OUTPUT / 'MAC_STREAM_RESULT.json').open('xb') as f:
            f.write(response.stdout)
        part.rename(ARCHIVE)
        result = {'status': 'EXACT_STREAM_RECEIVED_NOT_YET_MEMBER_VERIFIED_NOT_REMOVED', 'utc': utc(),
                  'archive': str(ARCHIVE), 'archive_sha256': h.hexdigest(), 'archive_bytes': count,
                  'manifest_sha256': MANIFEST_SHA, 'source_root': ROOT, 'mac_evidence': MAC,
                  'free_before': before, 'free_after': guard(), 'minimum_free_before_write': minimum,
                  'reserve': RESERVE, 'seconds': time.monotonic() - started,
                  'archive_identity': identity(ARCHIVE), 'base_archive_identity': base['current_archive_identity'],
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
    assert p.parts and p.parts[0] == 'producer-derived'
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
    assert received['base_archive_identity'] == base['current_archive_identity']
    archive_hash = hash_file(ARCHIVE)
    assert archive_hash == received['archive_sha256']
    old_bytes = (BASE / 'MEMBER_MANIFEST.json').read_bytes()
    assert hashlib.sha256(old_bytes).hexdigest() == BASE_MANIFEST_SHA
    old = json.loads(old_bytes)
    old_entries = {x['path']: x for x in old['entries']}
    assert len(old_entries) == len(old['entries']) == 138339
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
                    assert manifest['source_root'] == ROOT and manifest['base_archive_sha256'] == BASE_SHA
                    assert manifest['base_manifest_sha256'] == BASE_MANIFEST_SHA
                    assert manifest['source_qualification'] == 'UNQUALIFIED_INTERRUPTED_PRODUCER_DERIVED_NO_BUILD_ACCEPTANCE'
                    payloads = {x['member']: x for x in manifest['new_payloads']}
                    assert len(payloads) == len(manifest['new_payloads']) == 22521
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
    assert len(entries) == len(manifest['entries']) == 121147
    counts = {'file': 0, 'directory': 0, 'symlink': 0}
    reused, new_files, logical, xattrs, acls, links, base_members = 0, 0, 0, 0, 0, {}, set()
    for path, value in entries.items():
        relative = safe_relative(path)
        if path != 'producer-derived':
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
                assert reference['archive_sha256'] == BASE_SHA
                original = old_entries[reference['member']]
                assert original['type'] == 'file'
                assert (original['bytes'], original['sha256']) == (value['bytes'], value['sha256'])
                reused += 1
                base_members.add(reference['member'])
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
    assert counts == {'file':102063, 'directory':18845, 'symlink':239}
    assert logical == summary['logical_file_bytes'] == 49890963733
    assert reused == summary['base_reused_files'] == 78509
    assert total == summary['new_unique_payload_bytes'] == 2659619569
    assert xattrs == summary['entries_with_xattrs'] == 88 and acls == summary['entries_with_acl'] == 0
    assert identity(ARCHIVE) == received['archive_identity']
    assert identity(BASE / 'interrupted-original-sdk-work.tar.gz') == base['current_archive_identity']
    result = {'status': 'COMPLETE_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_REMOVED', 'utc': utc(),
              'source_root': ROOT, 'manifest_sha256': MANIFEST_SHA, 'manifest_bytes': MANIFEST_BYTES,
              'archive': str(ARCHIVE), 'archive_sha256': archive_hash, 'archive_bytes': ARCHIVE.stat().st_size,
              'base_archive_sha256': BASE_SHA, 'base_archive': str(BASE / 'interrupted-original-sdk-work.tar.gz'),
              'base_manifest_sha256': BASE_MANIFEST_SHA, 'base_proof': base,
              'entries': len(entries), 'counts': counts, 'logical_file_bytes': logical,
              'verified_payloads': len(payloads), 'verified_payload_bytes': total,
              'base_reused_files': reused, 'base_distinct_members': len(base_members),
              'differential_referenced_files': new_files, 'entries_with_xattrs': xattrs,
              'entries_with_acl': acls, 'hardlink_groups': len(links),
              'all_metadata_and_symlink_targets_retained': True,
              'all_original_parent_directory_relationships_verified': True,
              'gzip_crc_and_all_tar_members_verified': True,
              'full_filesystem_restoration_run': False,
              'restoration_scope': 'Lossless content/metadata manifest and payload references verified; no 49.9GB materialization. Historic inode/device/ctime retained as evidence.',
              'native_acceptance': 0, 'sdk_qualified': False, 'free_after': guard(),
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
