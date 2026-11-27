#!/usr/bin/env python3
"""Retire ONLY the separately authorized fixed pair after durable off-host ACK."""
from pathlib import Path
import base64
import datetime
import gzip
import hashlib
import inspect
import json
import os
import shutil
import stat
import sys
import types

EVIDENCE = Path('/Users/m1/builds/otzaria-wave3-session-pair-preservation-20261127.dnwtgpgc')
BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
ROOTS = (BASE / 'session.ftqrs4Ju', BASE / 'session.e9xp5UCf')
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
PROOF_SHA = '313e1e60aa516ae218bf709e8d106e7c5b8c64b8a72a61136a78394913e5909d'
SOURCE_SHA = '5834032a8d367869ccb57a251ce89c8da1daf3c8a32fae944063621b3263c2ae'


def canonical(value): return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()


def load_module(name, filename, expected):
    p = EVIDENCE / filename; body = p.read_bytes()
    assert hashlib.sha256(body).hexdigest() == expected
    module = types.ModuleType(name); module.__file__ = str(p)
    exec(compile(body, str(p), 'exec'), module.__dict__)
    return module


def main():
    envelope_raw = sys.stdin.buffer.readline(256 * 1024); envelope = json.loads(envelope_raw)
    proof_raw = base64.b64decode(envelope['proof_base64'], validate=True)
    source_raw = base64.b64decode(envelope['source_base64'], validate=True)
    current_raw = base64.b64decode(envelope['current_base64'], validate=True)
    assert hashlib.sha256(proof_raw).hexdigest() == PROOF_SHA
    assert hashlib.sha256(source_raw).hexdigest() == SOURCE_SHA
    assert hashlib.sha256(current_raw).hexdigest() == envelope['current_sha256']
    assert (EVIDENCE / 'COMPLETE_PRESERVATION_VERIFIED.json').read_bytes() == proof_raw
    assert (EVIDENCE / 'SOURCE_REVERIFIED.json').read_bytes() == source_raw
    proof, source, current = json.loads(proof_raw), json.loads(source_raw), json.loads(current_raw)
    assert proof['status'] == 'COMPLETE_PAIR_DIFFERENTIAL_AND_PRIOR_MEMBER_BINDINGS_VERIFIED_NOT_RETIRED'
    assert source['status'] == 'COMPLETE_PAIR_SOURCE_CONTENT_METADATA_REVERIFIED_PRESERVED_NOT_RETIRED'
    assert current['status'] == 'ALL_CURRENT_ARCHIVE_AND_RECEIPT_IDENTITIES_MATCH'
    assert source['roots'] == current['roots'] == [str(p) for p in ROOTS]
    assert source['complete_preservation_receipt_sha256'] == PROOF_SHA
    assert source['header_sha256'] == proof['header_sha256'] == HEADER_SHA
    assert not source['anything_deleted'] and not proof['anything_deleted']
    assert current['complete_preservation_sha256'] == PROOF_SHA and current['source_reverified_sha256'] == SOURCE_SHA
    assert current['new_archive']['archive_sha256'] == proof['new_archive_sha256']
    assert current['new_archive']['archive_bytes'] == proof['new_archive_bytes']
    assert current['archive_bindings'] == proof['archive_bindings']
    age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(current['utc'])).total_seconds()
    assert 0 <= age <= 180
    inventory = load_module('fixed_pair_inventory', 'session_pair.py',
        '5e1f6d9f7f5a56abda50f3cdc76170fa3e4ca78d4d1d7a2ce7db7a5d8f427948')
    reverify = load_module('fixed_pair_source_verification', 'reverify_pair.py',
        '04eca70a3ba4239dca4c6fb056c4fe053934d772e472c4ba64a244f192e7b157')
    assert inventory.ROOTS == ROOTS
    header = inventory.load_header(EVIDENCE, HEADER_SHA); helper = inventory.helper()
    before_use = inventory.no_use(); outside = reverify.preserved_outside()
    assert outside == source['protected_outside_after']
    heads = inventory.source_heads(); assert heads == header['source_heads'] == source['source_heads_after']
    expected_selected = {}
    for root in ROOTS:
        for relative in ('Maktabah.xcodeproj/project.pbxproj', 'Source/PrivacyInfo.xcprivacy'):
            path = root / 'runner/_work/Maktabah/Maktabah' / relative
            expected_selected[str(path.relative_to(BASE))] = None
    with gzip.open(EVIDENCE / 'entries.jsonl.gz', 'rb') as f:
        for line in f:
            row = json.loads(line)
            if row['path'] in expected_selected:
                assert row['type'] == 'file'
                expected_selected[row['path']] = row['sha256']
    assert all(expected_selected.values())
    selected = {}
    for relative, expected in expected_selected.items():
        path = BASE / relative; before = path.lstat()
        assert stat.S_ISREG(before.st_mode) and not path.is_symlink()
        selected[relative] = inventory.digest(path)
        assert selected[relative] == expected and helper.identity(before) == helper.identity(path.lstat())
    fresh_hashes = []; counts = []
    for root, scope in zip(ROOTS, header['scopes']):
        assert inventory.root_identity(root) == scope['root_identity']
        sha = hashlib.sha256(); count = 0
        for path, info in inventory.walk(root):
            sha.update(inventory.stat_line(helper, root, path, info)); count += 1
        fresh_hashes.append(sha.hexdigest()); counts.append(count)
    assert fresh_hashes == header['stat_inventory_sha256'] == source['stat_inventory_sha256']
    assert counts == [s['entries'] for s in header['scopes']]
    assert heads == inventory.source_heads() and reverify.preserved_outside() == outside
    after_use = inventory.no_use()
    before = {'status': 'EXACT_PAIR_CURRENT_STATE_VERIFIED_AWAITING_DURABLE_OFFHOST_ACK', 'utc': utc(),
              'roots': [str(p) for p in ROOTS], 'header_sha256': HEADER_SHA,
              'complete_preservation_sha256': PROOF_SHA, 'source_reverified_sha256': SOURCE_SHA,
              'current_archive_bindings_sha256': envelope['current_sha256'],
              'current_archive_bindings': current, 'source_heads': heads,
              'preserved_pbx_privacy_sha256': selected, 'entries_rechecked': counts,
              'stat_inventory_sha256': fresh_hashes, 'protected_outside_before': outside,
              'open_use_before': before_use, 'open_use_after': after_use,
              'free_before': inventory.capacity(), 'script_sha256': inventory.digest(Path(__file__)),
              'authorization': 'Root explicitly authorized only the two absolute paths after independent review of proof313e1e60 and source5834032a; no archive, other scope, held executable, foreign work, or SDK source is authorized.',
              'anything_deleted': False, 'native_acceptance': 0, 'sdk_retry': False}
    raw = canonical(before); sys.stdout.buffer.write(raw); sys.stdout.buffer.flush()
    acknowledgement = json.loads(sys.stdin.buffer.readline(4096))
    expected_ack = {'ack': 'DURABLE_OFFHOST_EXACT_PAIR_PREDELETE', 'sha256': hashlib.sha256(raw).hexdigest(),
                    'complete_preservation_sha256': PROOF_SHA, 'source_reverified_sha256': SOURCE_SHA,
                    'current_archive_bindings_sha256': envelope['current_sha256']}
    assert acknowledgement == expected_ack
    assert inventory.no_use()['open_paths'] == []
    assert reverify.preserved_outside() == outside and inventory.source_heads() == heads
    for root, scope in zip(ROOTS, header['scopes']): assert inventory.root_identity(root) == scope['root_identity']
    assert shutil.rmtree.avoids_symlink_attacks
    parent_fd = os.open(BASE, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    cwd_fd = os.open('.', os.O_RDONLY | os.O_DIRECTORY)
    removed = []; started = []
    try:
        parent = os.fstat(parent_fd)
        assert (parent.st_dev, parent.st_ino, parent.st_mode, parent.st_uid, parent.st_gid) == (
            outside[0]['device'], outside[0]['inode'], outside[0]['mode'], outside[0]['uid'], outside[0]['gid'])
        # Pin the parent descriptor as well as relying on Python's fd-based,
        # symlink-attack-resistant implementation for every descendant.
        has_dir_fd = 'dir_fd' in inspect.signature(shutil.rmtree).parameters
        if not has_dir_fd: os.fchdir(parent_fd)
        for root, scope in zip(ROOTS, header['scopes']):
            current_root = os.stat(root.name, dir_fd=parent_fd, follow_symlinks=False)
            original = scope['root_identity']
            assert (current_root.st_dev, current_root.st_ino, current_root.st_mode,
                    current_root.st_uid, current_root.st_gid) == (
                        original['device'], original['inode'], original['mode'], original['uid'], original['gid'])
            started.append(str(root))
            if has_dir_fd: shutil.rmtree(root.name, dir_fd=parent_fd)
            else: shutil.rmtree(root.name)
            try: os.stat(root.name, dir_fd=parent_fd, follow_symlinks=False)
            except FileNotFoundError: pass
            else: raise AssertionError('Authorized root still exists')
            removed.append(str(root))
        os.fchdir(cwd_fd)
        assert all(not os.path.lexists(root) for root in ROOTS)
        after = reverify.preserved_outside(); assert after == outside
        result = {**before, 'status': 'RETIRED_ONLY_EXACT_FULLY_PRESERVED_SESSION_PAIR', 'finished_at': utc(),
                  'anything_deleted': True, 'removed': removed, 'full_absence_verified': True,
                  'protected_outside_after': after, 'protected_identities_unchanged': True,
                  'parent_fd_pinned': True, 'fd_based_rmtree': True,
                  'predelete_receipt_sha256': hashlib.sha256(raw).hexdigest(),
                  'free_after': inventory.capacity()}
        result['concurrent_free_delta_bytes'] = result['free_after'] - result['free_before']
        result['free_delta_scope'] = 'Concurrent filesystem observation; not exclusive attribution.'
    except BaseException as error:
        result = {**before, 'status': 'EXACT_PAIR_RETIREMENT_ERROR', 'finished_at': utc(),
                  'anything_deleted': bool(started), 'removal_started': started, 'removed': removed,
                  'error': repr(error), 'roots_still_exist': [os.path.lexists(p) for p in ROOTS],
                  'predelete_receipt_sha256': hashlib.sha256(raw).hexdigest()}
        sys.stdout.buffer.write(canonical(result)); sys.stdout.buffer.flush()
        raise
    finally:
        os.fchdir(cwd_fd); os.close(cwd_fd); os.close(parent_fd)
    sys.stdout.buffer.write(canonical(result)); sys.stdout.buffer.flush()


if __name__ == '__main__': main()
