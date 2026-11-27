#!/usr/bin/env python3
"""Fresh complete source equality after preservation. No retirement capability."""
from pathlib import Path
import datetime
import gzip
import hashlib
import json
import os
import resource
import stat
import sys
import time
import types

EVIDENCE = Path('/Users/m1/builds/otzaria-wave3-session-pair-preservation-20261127.dnwtgpgc')
HEADER_SHA = 'ce9ebccb6c36704448b659ee5354c44391e514a78f4df08073326eff18e6cf3b'
INVENTORY_SCRIPT_SHA = '5e1f6d9f7f5a56abda50f3cdc76170fa3e4ca78d4d1d7a2ce7db7a5d8f427948'
BASE = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl')
PROTECTED = (
    BASE,
    BASE / 'compact-reader-preview-worktree.5hRb5SYt',
    BASE / 'compact-reader-preview-worktree.5hRb5SYt/Maktabah',
    BASE / 'actual-paired-production-release.Hguhbz1S',
    BASE / 'actual-paired-production-release.Hguhbz1S/Maktabah',
    Path('/Users/m1/builds/otzaria-wave1-sdk-20261127/source'),
)


def digest(p):
    sha = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''): sha.update(b)
    return sha.hexdigest()


def preserved_outside():
    values = []
    for p in PROTECTED:
        assert p.resolve() == p and not p.is_symlink()
        s = p.lstat(); assert stat.S_ISDIR(s.st_mode)
        values.append({'path': str(p), 'device': s.st_dev, 'inode': s.st_ino,
                       'mode': s.st_mode, 'uid': s.st_uid, 'gid': s.st_gid, 'flags': s.st_flags})
    return values


def main(expected_proof):
    started = time.monotonic(); body = (EVIDENCE / 'session_pair.py').read_bytes()
    assert hashlib.sha256(body).hexdigest() == INVENTORY_SCRIPT_SHA
    module = types.ModuleType('exact_inventory_source'); module.__file__ = str(EVIDENCE / 'session_pair.py')
    exec(compile(body, module.__file__, 'exec'), module.__dict__)
    header = module.load_header(EVIDENCE, HEADER_SHA)
    proof_path = EVIDENCE / 'COMPLETE_PRESERVATION_VERIFIED.json'
    assert digest(proof_path) == expected_proof
    proof = json.loads(proof_path.read_bytes())
    assert proof['status'] == 'COMPLETE_PAIR_DIFFERENTIAL_AND_PRIOR_MEMBER_BINDINGS_VERIFIED_NOT_RETIRED'
    assert proof['header_sha256'] == HEADER_SHA and not proof['anything_deleted']
    streamed = json.loads((EVIDENCE / 'STREAM_RESULT.json').read_bytes())
    assert streamed['header_sha256'] == HEADER_SHA
    assert streamed['archive_sha256'] == proof['new_archive_sha256'] and streamed['archive_bytes'] == proof['new_archive_bytes']
    free_before = module.capacity(); before_use = module.no_use(); outside = preserved_outside()
    heads_before = module.source_heads(); assert heads_before == header['source_heads']
    h = module.helper(); counts = []; hashes = []; current_private = []; total_logical = 0
    with gzip.open(EVIDENCE / 'entries.jsonl.gz', 'rb') as entries:
        for scope, root in enumerate(module.ROOTS):
            assert module.root_identity(root) == header['scopes'][scope]['root_identity']
            h.ROOT = root; count = 0; files = 0; logical = 0; private = 0; stat_sha = hashlib.sha256()
            for p, s in module.walk(root):
                raw = entries.readline(); assert raw, 'Current source has extra paths'
                initial = json.loads(raw); assert initial['scope'] == scope
                actual = h.entry((p, s))
                assert {k: v for k, v in actual.items() if k != 'atime_ns'} == {
                    k: v for k, v in initial.items() if k not in ('atime_ns', 'scope', 'payload', 'allocation_observation')
                }, str(p)
                stat_sha.update(module.stat_line(h, root, p, s)); count += 1
                if actual['type'] == 'file':
                    files += 1; logical += actual['bytes']
                    allocation = module.private_size(h, p)
                    if actual['nlink'] == 1: private += allocation['private_bytes']
                if count % 1024 == 0: module.capacity()
            assert count == header['scopes'][scope]['entries']
            assert files == header['scopes'][scope]['files'] and logical == header['scopes'][scope]['logical_bytes']
            counts.append({'root': str(root), 'entries': count, 'files': files, 'logical_bytes': logical})
            hashes.append(stat_sha.hexdigest()); current_private.append(private); total_logical += logical
        assert entries.read(1) == b'', 'Current source lost paths'
    assert hashes == header['stat_inventory_sha256']
    after_hashes = []
    for root in module.ROOTS:
        sha = hashlib.sha256()
        for p, s in module.walk(root): sha.update(module.stat_line(h, root, p, s))
        after_hashes.append(sha.hexdigest())
    assert after_hashes == hashes
    heads_after = module.source_heads(); assert heads_after == heads_before
    assert preserved_outside() == outside
    after_use = module.no_use()
    result = {'status': 'COMPLETE_PAIR_SOURCE_CONTENT_METADATA_REVERIFIED_PRESERVED_NOT_RETIRED',
              'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'roots': [str(x) for x in module.ROOTS], 'header_sha256': HEADER_SHA,
              'complete_preservation_receipt_sha256': expected_proof,
              'new_archive': proof['new_archive'], 'new_archive_sha256': proof['new_archive_sha256'],
              'new_archive_bytes': proof['new_archive_bytes'],
              'source_heads_before': heads_before, 'source_heads_after': heads_after,
              'scopes': counts, 'fresh_kernel_private_bytes_by_scope': current_private,
              'fresh_kernel_private_bytes_total': sum(current_private),
              'stat_inventory_sha256': hashes, 'open_use_before': before_use, 'open_use_after': after_use,
              'protected_outside_before': outside, 'protected_outside_after': preserved_outside(),
              'free_before': free_before, 'free_after': module.capacity(),
              'full_restored_tree_materialized': False,
              'preservation_proof': 'Every current path/metadata/content equals the complete inventory; each file resolves to a newly byte-verified member or an exact physically preserved prior member with current archive hash and full-member receipt.',
              'metadata_note': 'Original atime bytes remain preserved; validation omits read-induced current atime. Historical inode/device/ctime are retained evidence, not numeric guarantees after restoration.',
              'anything_deleted': False, 'retirement_authorized': False, 'native_acceptance': 0,
              'new_sdk_qualification': False, 'reverification_script_sha256': digest(Path(__file__)),
              'seconds': time.monotonic() - started, 'peak_rss_bytes': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}
    module.save(EVIDENCE / 'SOURCE_REVERIFIED.json', result)
    print(json.dumps({'status': result['status'], 'receipt': str(EVIDENCE / 'SOURCE_REVERIFIED.json'),
                      'receipt_sha256': digest(EVIDENCE / 'SOURCE_REVERIFIED.json'), 'summary': result}))


if __name__ == '__main__':
    assert len(sys.argv) == 2
    main(sys.argv[1])
