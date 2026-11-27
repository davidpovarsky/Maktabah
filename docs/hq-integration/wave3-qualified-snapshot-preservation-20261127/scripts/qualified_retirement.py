#!/usr/bin/env python3
"""Retire only the one explicitly authorized, fully preserved root snapshot."""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import time

EVIDENCE = Path('/Users/m1/builds/otzaria-wave3-qualified-snapshot-preservation-20261127.2117vow6')
ROOT = Path('/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/compact-reader-preview-worktree.5hRb5SYt/wave3-qualified-6935f7fd-20261127')
MANIFEST_SHA = '70a15c1afa2456d9dea9f11191df0561f08d766211360c60a5039feca632d660'
HELPER_SHA = 'f07264ccf70a75f9b74566d24f65cfdcd6e832e5f3b09231cb6311afae06749e'
MEMBER_RECEIPT_SHA = '1be15f9c4f63809eaedbadfbabfad49ea3283673e71c31906c50d524f7be5fd9'
EXPECTED_ARCHIVES = {
    'app-generated': ('36b384277403ef416a22150724bd857b65b5d85043c884378630e7f1c6414efb', 1699905882),
    'old-sdk-producer': ('2755568d177d543ac75f45709d0c7aae8dfa7f99b0bfd1131f3295b710db0bda', 5238640114),
    'fresh-sdk-differential': ('3d32de4e4e564f6c606a0daccd9c92582ad1e8e259f7c5cb492ad55622db7fee', 944883233),
    'qualified-snapshot-differential': ('f2dff9300c3b7d429bcaa260fd3f97e1d685c2a1680b0c7dd1e32636b1559e0b', 1291853917),
}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024**2), b''):
            h.update(b)
    return h.hexdigest()


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(path, value):
    with path.open('xb') as f:
        f.write((json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode())


def stat_record(path, hash_file=False):
    s = path.lstat()
    r = {'device': s.st_dev, 'inode': s.st_ino, 'mode': s.st_mode,
         'uid': s.st_uid, 'gid': s.st_gid, 'bytes': s.st_size,
         'mtime_ns': s.st_mtime_ns, 'ctime_ns': s.st_ctime_ns, 'flags': s.st_flags}
    if stat.S_ISLNK(s.st_mode):
        r['target'] = os.readlink(path)
    elif hash_file and stat.S_ISREG(s.st_mode):
        r['sha256'] = digest(path)
    return r


def parent_identity():
    assert ROOT.parent.resolve() == ROOT.parent and not ROOT.parent.is_symlink()
    r = stat_record(ROOT.parent)
    return {k: r[k] for k in ('device', 'inode', 'mode', 'uid', 'gid', 'flags')}


def protected_outside():
    # Sibling roots are never traversed for deletion. Exact top-level metadata,
    # regular-file bytes and the original Maktabah root/source pins are checked.
    original = ROOT.parent / 'Maktabah'
    assert original.is_dir() and original.resolve() == original
    paths = {p for p in ROOT.parent.iterdir() if p != ROOT}
    paths.update(original.iterdir())
    for relative in (
        'Maktabah.xcodeproj/project.pbxproj',
        'Maktabah.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        'Maktabah.xcworkspace/xcshareddata/swiftpm/Package.resolved',
        'Source/Localizable.xcstrings',
    ):
        p = original / relative
        if os.path.lexists(p):
            paths.add(p)
    values = {str(p): stat_record(p, hash_file=True) for p in sorted(paths)}
    git = ['git', '--no-optional-locks', '-C', str(original)]
    return {'paths': values,
            'original_source_head': subprocess.check_output(git + ['rev-parse', 'HEAD'], text=True).strip(),
            'original_tracked_status': subprocess.check_output(git + ['status', '--porcelain=v1', '--untracked-files=no'], text=True)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--execute-exact-authorized-root', action='store_true', required=True)
    parser.add_argument('--final-archive-bindings-sha', required=True)
    args = parser.parse_args()
    assert args.execute_exact_authorized_root
    helper_path = EVIDENCE / 'qualified_preservation.py'
    assert digest(helper_path) == HELPER_SHA
    spec = importlib.util.spec_from_file_location('qualified_preservation_readonly', helper_path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    assert helper.ROOT == ROOT
    manifest = helper.load_manifest(EVIDENCE, MANIFEST_SHA)
    receipt_path = EVIDENCE / 'WINDOWS_VERIFIED_DIFFERENTIAL.json'
    assert digest(receipt_path) == MEMBER_RECEIPT_SHA
    receipt = json.loads(receipt_path.read_bytes())
    assert receipt['status'] == 'COMPLETE_QUALIFIED_SNAPSHOT_DIFFERENTIAL_AND_ALL_REFERENCES_VERIFIED_NOT_RETIRED'
    assert receipt['source_root'] == str(ROOT) and receipt['manifest_sha256'] == MANIFEST_SHA
    assert receipt['entries'] == len(manifest['entries']) == 65204
    assert receipt['archive_sha256'] == EXPECTED_ARCHIVES['qualified-snapshot-differential'][0]
    assert receipt['all_metadata_and_symlink_targets_retained']
    assert receipt['all_original_parent_directory_relationships_verified']
    assert receipt['gzip_crc_and_all_tar_members_verified']
    bindings_path = EVIDENCE / 'FINAL_ARCHIVE_BINDINGS.json'
    assert digest(bindings_path) == args.final_archive_bindings_sha
    bindings = json.loads(bindings_path.read_bytes())
    assert bindings['status'] == 'ALL_FOUR_VERIFIED_ARCHIVES_REHASHED_UNCHANGED_BEFORE_EXACT_RETIREMENT'
    assert bindings['source_root'] == str(ROOT) and bindings['manifest_sha256'] == MANIFEST_SHA
    assert bindings['member_verification_receipt_sha256'] == MEMBER_RECEIPT_SHA
    assert bindings['reference_plan_sha256'] == helper.REFERENCE_SHA
    assert bindings['base_archives_proof_sha256'] == receipt['base_archives_proof_sha256']
    actual = {r['id']: (r['sha256'], r['bytes']) for r in bindings['archives']}
    assert len(bindings['archives']) == 4 and actual == EXPECTED_ARCHIVES
    age = datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(bindings['utc'])
    assert 0 <= age.total_seconds() <= 600, 'archive readback is no longer current'

    free_before = helper.guard_capacity()
    parent_before = parent_identity()
    parent_stat_before = stat_record(ROOT.parent)
    outside_before = protected_outside()
    use_before = helper.no_open_use()
    current = helper.scan(EVIDENCE, 'final-authorized-retirement-full-verification')
    assert [x['path'] for x in current] == [x['path'] for x in manifest['entries']]
    for observed, original in zip(current, manifest['entries']):
        assert {k: v for k, v in observed.items() if k != 'atime_ns'} == {
            k: v for k, v in original.items() if k not in ('atime_ns', 'payload')}, original['path']
    use_after = helper.no_open_use()
    assert protected_outside() == outside_before
    assert parent_identity() == parent_before
    root_stat = helper.exact_root()
    assert root_stat.st_ino == manifest['entries'][0]['inode']
    assert root_stat.st_dev == manifest['entries'][0]['device']
    assert digest(bindings_path) == args.final_archive_bindings_sha
    assert digest(receipt_path) == MEMBER_RECEIPT_SHA
    r = {'status': 'AUTHORIZED_EXACT_SNAPSHOT_FULLY_REVERIFIED_BEFORE_RETIREMENT',
         'utc': utc(), 'source_root': str(ROOT), 'manifest_sha256': MANIFEST_SHA,
         'reference_plan_sha256': helper.REFERENCE_SHA,
         'windows_member_verification_sha256': MEMBER_RECEIPT_SHA,
         'final_archive_bindings_sha256': args.final_archive_bindings_sha,
         'all_four_archives': bindings['archives'], 'entries_rehashed': len(current),
         'parent_before': parent_stat_before, 'protected_before': outside_before,
         'open_use_before': use_before, 'open_use_after': use_after,
         'free_before': free_before, 'script_sha256': digest(__file__),
         'authorization': 'Root explicitly authorized only this exact path after complete preservation.',
         'native_acceptance': 0, 'new_sdk_qualification': False, 'sdk_retry': False}
    save(EVIDENCE / 'RETIREMENT_CURRENT_REVERIFICATION.json', r)
    assert shutil.rmtree.avoids_symlink_attacks
    # This is the sole destructive call. It receives only the fixed ROOT.
    # Python's fd-based rmtree does not traverse replaced symlinks.
    shutil.rmtree(ROOT)
    assert not os.path.lexists(ROOT)
    r['status'] = 'RETIRED_ONLY_FULLY_PRESERVED_QUALIFIED6935_SNAPSHOT'
    r['removed'] = [str(ROOT)]
    r['protected_after'] = protected_outside()
    r['outside_paths_unchanged'] = r['protected_after'] == outside_before
    r['parent_after'] = stat_record(ROOT.parent)
    r['parent_identity_retained'] = parent_identity() == parent_before
    r['original_maktabah_retained'] = (ROOT.parent / 'Maktabah').is_dir()
    r['free_after'] = shutil.disk_usage('/System/Volumes/Data').free
    r['observed_free_delta_bytes'] = r['free_after'] - free_before
    r['delta_caveat'] = 'Concurrent df observation; not exclusive APFS reclaimed allocation.'
    r['df_after'] = subprocess.check_output(['df', '-k', '/System/Volumes/Data'], text=True)
    r['finished_at'] = utc()
    save(EVIDENCE / 'RETIREMENT_RESULT.json', r)
    assert r['outside_paths_unchanged'] and r['parent_identity_retained'] and r['original_maktabah_retained']
    print(json.dumps({k: v for k, v in r.items() if k not in ('protected_before', 'protected_after')}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        save(EVIDENCE / ('RETIREMENT_FAILED_' + str(time.time_ns()) + '.json'),
             {'utc': utc(), 'error': repr(error), 'source_root': str(ROOT),
              'source_still_exists': os.path.lexists(ROOT)})
        raise
