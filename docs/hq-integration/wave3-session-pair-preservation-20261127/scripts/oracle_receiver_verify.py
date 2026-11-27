#!/usr/bin/env python3
"""Receive and independently verify one fixed differential; never retire data."""
from pathlib import Path, PurePosixPath
import base64
import collections
import datetime
import gzip
import hashlib
import json
import os
import resource
import shutil
import sys
import tarfile
import time

ROOT = Path('/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127')
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
ORACLE_RESERVE = (256 + 300 + 100) * 1024**2
METADATA_RESERVE = 32 * 1024**2
MAX_ARCHIVE_BYTES = 2150000000
ARCHIVE = ROOT / 'session-pair-differential.tar.gz'
SOURCE_ROOTS = (
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.ftqrs4Ju',
    '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/session.e9xp5UCf',
)


def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def canonical(x): return (json.dumps(x, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): h.update(b)
    return h.hexdigest()


def identity(p):
    s = Path(p).stat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'bytes': s.st_size,
            'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns}


def free(): return shutil.disk_usage(ROOT).free


def save(name, value):
    raw = canonical(value)
    assert free() - len(raw) >= ORACLE_RESERVE
    with (ROOT / name).open('xb') as f:
        f.write(raw); f.flush(); os.fsync(f.fileno())
    return {'path': str(ROOT / name), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def receive():
    assert ROOT.is_dir() and ROOT.resolve() == ROOT and not ROOT.is_symlink()
    assert free() >= ORACLE_RESERVE + METADATA_RESERVE + MAX_ARCHIVE_BYTES
    assert not ARCHIVE.exists()
    before = free(); started = time.monotonic(); sha = hashlib.sha256(); count = 0
    partial = ROOT / 'session-pair-differential.tar.gz.partial'
    samples = [{'bytes': 0, 'free': before, 'utc': utc()}]
    last_sample = 0
    try:
        with partial.open('xb') as output:
            while True:
                block = sys.stdin.buffer.read(1024**2)
                if not block: break
                available = free()
                assert available - len(block) >= ORACLE_RESERVE + METADATA_RESERVE, ('Oracle reserve', available, count)
                assert count + len(block) <= MAX_ARCHIVE_BYTES, 'Unexpected archive size'
                output.write(block); sha.update(block); count += len(block)
                if count - last_sample >= 64 * 1024**2:
                    output.flush(); os.fsync(output.fileno())
                    samples.append({'bytes': count, 'free': free(), 'utc': utc()}); last_sample = count
            output.flush(); os.fsync(output.fileno())
        assert count > 0
        partial.rename(ARCHIVE)
        result = {'status': 'RECEIVED_BYTES_NOT_YET_MEMBER_VERIFIED', 'utc': utc(),
                  'archive': str(ARCHIVE), 'archive_bytes': count, 'archive_sha256': sha.hexdigest(),
                  'header_sha256': HEADER_SHA, 'receiver_sha256': digest(__file__),
                  'free_before': before, 'free_after': free(), 'protected_reserve_bytes': ORACLE_RESERVE,
                  'metadata_write_reserve_bytes': METADATA_RESERVE, 'capacity_samples': samples,
                  'seconds': time.monotonic() - started, 'anything_deleted': False}
        result['receipt'] = save('RECEIVE_RESULT.json', result)
        print(json.dumps(result))
    except BaseException as error:
        result = {'status': 'RECEIVE_FAILED_SOURCE_NOT_RETIRED', 'utc': utc(), 'error': repr(error),
                  'partial': str(partial), 'bytes_received': count, 'free_before': before,
                  'free_after': free(), 'capacity_samples': samples, 'anything_deleted': False}
        if free() > ORACLE_RESERVE + 65536: save('RECEIVE_FAILURE.json', result)
        print(json.dumps(result), file=sys.stderr)
        raise


def rows(name, header):
    expected = next(x for x in header['metadata'] if x['name'] == name)
    p = ROOT / name
    assert p.stat().st_size == expected['bytes'] and digest(p) == expected['sha256']
    sha = hashlib.sha256(); size = 0
    with gzip.open(p, 'rb') as f:
        for line in f:
            sha.update(line); size += len(line)
            yield json.loads(line)
    assert size == expected['uncompressed_bytes'] and sha.hexdigest() == expected['uncompressed_sha256']


def validate_metadata(header):
    new = {}; new_bytes = 0
    for row in rows('new-payloads.jsonl.gz', header):
        member = row['member']; sha = row['sha256']; size = row['bytes']
        assert len(sha) == 64 and bytes.fromhex(sha) and member == 'objects/sha256/' + sha
        assert member not in new and type(size) is int and size >= 0
        path = PurePosixPath(row['source_path'])
        assert row['scope'] in (0, 1) and not path.is_absolute() and '..' not in path.parts
        assert path.parts[0] == PurePosixPath(SOURCE_ROOTS[row['scope']]).name
        assert len(row['stat_identity']) >= 6
        new[member] = (sha, size); new_bytes += size
    assert len(new) == header['new_unique_payloads'] and new_bytes == header['new_unique_raw_bytes']
    paths = set(); directories = set(); used_new = set(); required = {}; hardlinks = collections.defaultdict(list)
    summaries = [dict(entries=0, files=0, directories=0, symlinks=0, logical_bytes=0,
                      covered_files=0, covered_bytes=0, xattr_entries=0, acl_entries=0,
                      hardlinked_files=0, kernel_private_bytes=0) for _ in SOURCE_ROOTS]
    pins = {r['id']: r for r in header['base_archives']}
    for row in rows('entries.jsonl.gz', header):
        scope = row['scope']; assert scope in (0, 1)
        s = summaries[scope]; s['entries'] += 1
        path = PurePosixPath(row['path']); key = (scope, str(path))
        assert not path.is_absolute() and '..' not in path.parts and key not in paths
        assert path.parts[0] == PurePosixPath(SOURCE_ROOTS[scope]).name
        if len(path.parts) > 1: assert (scope, str(path.parent)) in directories
        paths.add(key)
        assert row['type'] in ('file', 'directory', 'symlink')
        assert row['mode'] >= 0 and row['bytes'] >= 0 and row['nlink'] >= 1
        for field in ('uid', 'gid', 'device', 'inode', 'mtime_ns', 'atime_ns', 'ctime_ns', 'birthtime_ns', 'flags', 'rdev'):
            assert type(row[field]) is int
        names = set()
        for x in row['xattrs']:
            name = base64.b64decode(x['name_base64'], validate=True)
            value = base64.b64decode(x['value_base64'], validate=True)
            assert name and b'\0' not in name and name not in names; names.add(name)
            assert len(value) == x['bytes'] and hashlib.sha256(value).hexdigest() == x['sha256']
        s['xattr_entries'] += bool(row['xattrs']); s['acl_entries'] += row['acl'] is not None
        if row['acl'] is not None:
            value = base64.b64decode(row['acl']['text_base64'], validate=True)
            assert len(value) == row['acl']['bytes'] and hashlib.sha256(value).hexdigest() == row['acl']['sha256']
        if row['type'] == 'directory':
            s['directories'] += 1; directories.add(key)
        elif row['type'] == 'symlink':
            s['symlinks'] += 1
            target = base64.b64decode(row['target_bytes_base64'], validate=True)
            assert target == row['target'].encode('utf-8', errors='surrogateescape') and b'\0' not in target
        else:
            s['files'] += 1; s['logical_bytes'] += row['bytes']
            assert len(row['sha256']) == 64 and bytes.fromhex(row['sha256'])
            if row['nlink'] > 1:
                s['hardlinked_files'] += 1
                hardlinks[row['hardlink_group']].append((row['nlink'], row['sha256'], row['bytes'], row['device'], row['inode']))
            else: s['kernel_private_bytes'] += row['allocation_observation']['private_bytes']
            payload = row['payload']; value = (row['sha256'], row['bytes'])
            if payload['kind'] == 'new_member':
                assert new.get(payload['member']) == value; used_new.add(payload['member'])
            else:
                assert payload['kind'] == 'prior_member'
                aid = payload['archive_id']; assert aid in pins
                assert payload['archive_sha256'] == pins[aid]['archive_sha256']
                key = (aid, payload['member'])
                assert key not in required or required[key][:2] == value
                previous_count = required.get(key, (None, None, 0))[2]
                required[key] = (*value, previous_count + 1)
                s['covered_files'] += 1; s['covered_bytes'] += row['bytes']
    assert used_new == set(new)
    for group in hardlinks.values():
        assert len(group) == group[0][0] and len(set(group)) == 1
    for actual, expected in zip(summaries, header['scopes']):
        assert all(actual[k] == expected[k] for k in actual), (actual, expected)
    references = {'schema': 'otzaria.session-pair-prior-member-references/1', 'header_sha256': HEADER_SHA,
                  'base_archives': header['base_archives'], 'source_entries_sha256': header['metadata'][0]['sha256'],
                  'references': [{'archive_id': key[0], 'member': key[1], 'sha256': value[0],
                                  'bytes': value[1], 'source_files': value[2]}
                                 for key, value in sorted(required.items())]}
    return new, summaries, references


def verify(expected_archive_sha):
    started = time.monotonic(); before_free = free(); initial = identity(ARCHIVE)
    assert digest(ARCHIVE) == expected_archive_sha
    receipt = json.loads((ROOT / 'RECEIVE_RESULT.json').read_bytes())
    assert receipt['archive_sha256'] == expected_archive_sha and receipt['archive_bytes'] == initial['bytes']
    expected_first = ('HEADER.json', 'entries.jsonl.gz', 'new-payloads.jsonl.gz', 'session_pair.py')
    header = None; expected_new = None; seen = set(); members = 0; payload_bytes = 0; summaries = None; refs = None
    with gzip.open(ARCHIVE, 'rb') as zipped:
        with tarfile.open(fileobj=zipped, mode='r|') as archive:
            for member in archive:
                assert member.isfile() and member.name not in seen
                seen.add(member.name); members += 1
                f = archive.extractfile(member); sha = hashlib.sha256(); count = 0
                if members <= 4:
                    assert member.name == expected_first[members - 1] and member.size < 20 * 1024**2
                    assert free() - member.size >= ORACLE_RESERVE
                    with (ROOT / member.name).open('xb') as output:
                        for block in iter(lambda: f.read(1024**2), b''):
                            output.write(block); sha.update(block); count += len(block)
                        output.flush(); os.fsync(output.fileno())
                    assert count == member.size
                    if member.name == 'HEADER.json':
                        assert sha.hexdigest() == HEADER_SHA
                        header = json.loads((ROOT / member.name).read_bytes())
                        assert header['schema'] == 'otzaria.session-pair-preservation/1'
                        assert header['source_roots'] == list(SOURCE_ROOTS)
                        assert not header['anything_deleted'] and not header['retirement_authorized']
                    elif member.name == 'session_pair.py':
                        assert sha.hexdigest() == header['script_sha256']
                        expected_new, summaries, refs = validate_metadata(header)
                    else:
                        expected = next(x for x in header['metadata'] if x['name'] == member.name)
                        assert count == expected['bytes'] and sha.hexdigest() == expected['sha256']
                else:
                    assert member.name in expected_new
                    expected_sha, expected_size = expected_new[member.name]
                    assert member.size == expected_size
                    for block in iter(lambda: f.read(1024**2), b''): sha.update(block); count += len(block)
                    assert count == expected_size and sha.hexdigest() == expected_sha
                    payload_bytes += count
        # Force gzip trailer/integrity checks even after tar's end markers.
        assert not zipped.read().strip(b'\0')
    assert seen == set(expected_first) | set(expected_new)
    assert payload_bytes == header['new_unique_raw_bytes'] and identity(ARCHIVE) == initial
    reference_pin = save('PRIOR_REFERENCES.json', refs)
    result = {'status': 'COMPLETE_NEW_DIFFERENTIAL_MEMBERS_VERIFIED_PRIOR_REFERENCES_AWAIT_WINDOWS',
              'utc': utc(), 'archive': str(ARCHIVE), 'archive_sha256': expected_archive_sha,
              'archive_bytes': initial['bytes'], 'archive_identity': initial, 'header_sha256': HEADER_SHA,
              'verifier_sha256': digest(__file__), 'members_verified': members,
              'new_payloads_verified': len(expected_new), 'new_payload_bytes_verified': payload_bytes,
              'scopes': summaries, 'prior_reference_ledger': reference_pin,
              'prior_distinct_members': len(refs['references']), 'free_before': before_free, 'free_after': free(),
              'protected_reserve_bytes': ORACLE_RESERVE, 'seconds': time.monotonic() - started,
              'peak_rss_bytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024,
              'anything_deleted': False, 'native_acceptance': 0, 'new_sdk_qualification': False}
    result['receipt'] = save('NEW_ARCHIVE_VERIFIED.json', result)
    print(json.dumps(result))


if __name__ == '__main__':
    if sys.argv[1:] == ['receive']: receive()
    elif len(sys.argv) == 3 and sys.argv[1] == 'verify': verify(sys.argv[2])
    else: raise SystemExit('Only receive or verify; no deletion action exists.')
