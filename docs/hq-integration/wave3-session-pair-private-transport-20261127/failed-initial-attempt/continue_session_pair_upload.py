#!/usr/bin/env python3
"""Continue the SAME empty private draft after the exact pre-upload 404.

No new release, publication, clobber, automatic upload retry, local retirement,
Windows access, archive extraction or source rebasing. All failed-attempt files
remain unchanged. Only exact asset-creation POSTs to release 461122448 are used.
"""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before any filesystem action')

from pathlib import Path
import hashlib
import json
import os
import stat
import sys
import time
import types
import urllib.parse

HERE = Path(__file__).resolve().parent
HELPER = HERE / 'upload_session_pair.py'
HELPER_SHA = '96d094820d108e098823fba8a9346dec821b00a880088e8f4f9f92f8a45cf61d'
ORIGINAL = Path('/home/ubuntu/otzaria-wave3-private-session-pair-publication-20261127')
JOURNAL = ORIGINAL / 'continuation-1'
FAILURE_SNAPSHOT_SHA = 'a2711edae5a4e17135d999089def7303ae637a0f4c26af5a8a371f6c16010f76'
RELEASE_ID = 461122448
UPLOAD_URL = 'https://uploads.github.com/repos/davidpovarsky/Maktabah-preserved-evidence/releases/461122448/assets{?name,label}'
MANIFEST_NAME = 'PRESERVED_SESSION_PAIR_MANIFEST.json'
METADATA_NAME = 'session-pair-preservation-metadata-20261127.tar.gz'
FINAL_NAME = 'VERIFIED_PRIVATE_SESSION_PAIR_TRANSPORT.json'
MANIFEST_PIN = {'bytes': 17372, 'sha256': '47755d066e979027fecb45944a236f5284addc62644a9b44a9487f5e9919c0f7'}
METADATA_PIN = {'bytes': 20247355, 'sha256': '43e303295a389ee1bbe300993070dc1c6f9bd906d408705c68b6ff4aad9366c2'}


def pinned_read(path, sha, maximum):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        assert stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= maximum
        raw = os.pread(fd, maximum + 1, 0)
        assert len(raw) == before.st_size and hashlib.sha256(raw).hexdigest() == sha
        after = os.fstat(fd)
        assert (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) == (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
        return raw
    finally:
        os.close(fd)


def load_original():
    raw = pinned_read(HELPER, HELPER_SHA, 65536)
    assert len(raw) == 31089
    module = types.ModuleType('reviewed_session_pair_upload_96d09482')
    module.__file__ = str(HELPER)
    # Execute only the exact reviewed definitions, never their original main.
    exec(compile(raw, str(HELPER), 'exec'), module.__dict__)
    assert module.CONTROL == ORIGINAL and module.REPO_ID == 1474927804
    assert module.SOURCE == Path('/mnt/development/projects/diagnostics/otzaria-wave3-session-pair-preservation-20261127')
    assert module.ROOT_FLOOR == 1593835520 and module.METADATA_CAP == 33554432
    assert module.CONTROL_CAP == 50331648 and module.OVERALL_SECONDS == 2700
    # Sole explicit reuse adaptation: the unchanged Runtime's exclusive journal
    # is this fixed child. SOURCE, repository, archive pins, process/lifetime,
    # capacity and timeout code are unchanged. No existing attempt is reopened.
    module.CONTROL = JOURNAL
    return module


def original_attempt(c, runtime, parent_fd, snapshot, saved=None, final=False):
    rows = {c.leaf(r['name']): r for r in snapshot['rows']}
    assert len(rows) == 31 and METADATA_NAME in rows
    rows[METADATA_NAME] = {'name': METADATA_NAME, **METADATA_PIN}
    expected_names = set(rows) | {JOURNAL.name} | ({FINAL_NAME} if final else set())
    assert set(os.listdir(parent_fd)) == expected_names
    assert 'ARCHIVE_UPLOAD_STARTED.json' not in rows and snapshot['uploadStartedMarkerExists'] is False
    current, captured = {}, {}
    for name, row in rows.items():
        fd = c.open_regular(parent_fd, name)
        try:
            before = c.file_identity(fd)
            attrs = c.xattrs(fd)
            count, sha, body = c.hash_fd(fd, runtime, row['bytes'], capture=row['bytes'] <= c.BLOCK)
            assert count == row['bytes'] and sha == row['sha256']
            assert c.file_identity(fd) == before and c.xattrs(fd) == attrs
            current[name] = {'identity': before, 'xattrs': attrs, 'bytes': count, 'sha256': sha}
            if saved is not None:
                assert current[name] == saved[name]
            if body:
                captured[name] = body
        finally:
            os.close(fd)
    assert set(os.listdir(parent_fd)) == expected_names
    initial = json.loads(captured['ATTEMPT.json'])
    failed = json.loads(captured['FAILED.json'])
    created = json.loads(captured['DRAFT_RELEASE_CREATED.json'])
    request = json.loads(captured['05-tag-before-upload.PROCESS.json'])
    terminal = json.loads(captured['05-tag-before-upload.TERMINAL.json'])
    assert initial['controllerSHA256'] == HELPER_SHA
    assert initial['controllerAutomaticRetries'] == 0 and initial['localRetirement'] is False
    assert failed['phase'] == 'single-upload-no-clobber' and failed['automaticRetry'] is False
    assert failed['errorType'] == 'AssertionError' and failed['error'] == 'Owned gh command failed; no retry'
    assert created['id'] == RELEASE_ID and created['tag'] == c.TAG and created['draft'] is True
    assert created['repository'] == {'id': c.REPO_ID, 'full_name': c.REPO, 'private': True}
    assert request['argv'] == ['sudo', '-u', 'ubuntu', '-H', 'gh', 'api',
                              'repos/' + c.REPO + '/releases/tags/' + c.TAG]
    assert terminal['returncode'] == 1
    assert captured['05-tag-before-upload.stderr'] == b'gh: Not Found (HTTP 404)\n'
    assert json.loads(captured['05-tag-before-upload.stdout'])['status'] == '404'
    assert hashlib.sha256(captured[MANIFEST_NAME]).hexdigest() == MANIFEST_PIN['sha256']
    return current, captured


def same_release(c, runtime, known):
    c.private_repository(runtime)
    release = runtime.api('repos/%s/releases/%d' % (c.REPO, RELEASE_ID), 'same-private-draft')
    c.validate_release(release, RELEASE_ID)
    assert release['upload_url'] == UPLOAD_URL
    assert release['prerelease'] is False and release['published_at'] is None
    assert len(release['assets']) == len(known)
    rows = {a['name']: a for a in release['assets']}
    assert len(rows) == len(known) and set(rows) == set(known)
    for name, previous in known.items():
        row = rows[name]
        assert row['id'] == previous['id'] and row['size'] == previous['bytes']
        assert row['state'] == 'uploaded'
        assert row['url'] == previous['apiURL']
        assert not row.get('digest') or row['digest'] == 'sha256:' + previous['sha256']
    return release


def main():
    assert sys.argv[1:] == ['--continue-reviewed-empty-draft'], 'Explicit same-draft continuation invocation required'
    c = load_original()
    raw_inventory = pinned_read(HERE / 'FRESH_13_LEAF_INVENTORY.json', c.INVENTORY_SHA, 8192)
    expected = json.loads(raw_inventory)
    snapshot_raw = pinned_read(HERE / 'FAILURE_SCOPE_READ.json', FAILURE_SNAPSHOT_SHA, 16384)
    snapshot = json.loads(snapshot_raw)
    assert snapshot['path'] == str(ORIGINAL) and snapshot['mutation'] is False
    runtime = c.Runtime()  # O_EXCL fixed continuation-1; cannot retry this attempt.
    parent_fd = source_fd = None
    try:
        parent_fd = c.directory(ORIGINAL)
        parent = c.dir_identity(parent_fd)
        runtime.phase = 'original-failure-and-full-source-fences'
        protected, raw = original_attempt(c, runtime, parent_fd, snapshot)
        assert c.dir_identity(parent_fd) == parent
        source_fd = c.directory(c.SOURCE)
        source, small = c.source_inventory(runtime, source_fd, expected)
        dependencies = c.historical_join(source, small)
        manifest = json.loads(raw[MANIFEST_NAME])
        preflight = json.loads(raw['SOURCE_PREFLIGHT.json'])
        assert manifest['schema'] == 'otzaria.private-session-pair-differential-transport/1'
        assert manifest['sourceDirectory'] == str(c.SOURCE) and manifest['sourceParent'] == expected['parent']
        assert manifest['selfContained'] is False and manifest['fullTreeRestore'] is False
        assert manifest['windowsAccess'] is False and manifest['localRetirement'] is False
        assert manifest['originalInventorySHA256'] == c.INVENTORY_SHA
        assert manifest['privateRepository'] == {'id': c.REPO_ID, 'full_name': c.REPO, 'private': True}
        assert manifest['unchangedExternalDependencies'] == preflight['dependencies'] == dependencies
        assert preflight['all13LeavesFullyHashed'] is True
        for name in source:
            assert source[name]['identity'] == preflight['entries'][name]['identity']
            assert source[name]['sha256'] == preflight['entries'][name]['sha256']
            assert source[name]['restoreMetadata']['xattrs'] == preflight['entries'][name]['restoreMetadata']['xattrs']
        # Retain original pre-read atime metadata; later reads intentionally do
        # not rewrite the old manifest or refresh its source evidence.
        source = preflight['entries']
        assert manifest['originalArchive'] == source[c.ARCHIVE_NAME]
        assert manifest['metadataMembers'] == [source[n] for n in sorted(source) if n != c.ARCHIVE_NAME]
        bundle = manifest['metadataArchive']
        assert bundle['name'] == METADATA_NAME and bundle['all12RegularMembersVerified'] is True
        assert {k: bundle[k] for k in ('bytes', 'sha256')} == METADATA_PIN
        assert bundle['identity'] == protected[METADATA_NAME]['identity']
        assert len(manifest['metadataMembers']) == 12
        release = same_release(c, runtime, {})  # Must be the SAME genuinely empty draft.
        runtime.write('CONTINUATION_PREFLIGHT.json', {
            'utc': c.utc(), 'helperSHA256': HELPER_SHA, 'failedAttemptSnapshotSHA256': FAILURE_SNAPSHOT_SHA,
            'originalControlParent': parent, 'all30OriginalSmallFilesUnchanged': True,
            'originalMetadataBundle': METADATA_PIN, 'originalManifest': MANIFEST_PIN,
            'originalSourceFullHashesUnchanged': True, 'releaseID': RELEASE_ID,
            'uploadURL': UPLOAD_URL, 'emptyAssetsObserved': True, 'newRelease': False,
            'firstAssetUploadNotPreviouslyStarted': True, 'automaticUploadRetries': 0,
            'metadataMemberProof': 'Original 96d verifier completed all12 members before draft creation; current exact bundle+manifest hashes retain that proof without repacking.',
            'unchangedExternalDependencies': dependencies, 'selfContained': False, 'localRetirement': False})
        expected_assets = {
            METADATA_NAME: METADATA_PIN,
            MANIFEST_NAME: MANIFEST_PIN,
            c.ARCHIVE_NAME: {'bytes': c.ARCHIVE_BYTES, 'sha256': c.ARCHIVE_SHA},
        }
        inputs = {METADATA_NAME: ORIGINAL / METADATA_NAME, MANIFEST_NAME: ORIGINAL / MANIFEST_NAME,
                  c.ARCHIVE_NAME: c.SOURCE / c.ARCHIVE_NAME}
        known = {}
        runtime.phase = 'first-three-asset-posts-to-exact-existing-draft'
        runtime.write('FIRST_UPLOADS_STARTED.json', {'utc': c.utc(), 'releaseID': RELEASE_ID,
            'expectedAssets': expected_assets, 'newRelease': False, 'clobber': False, 'automaticRetries': 0})
        for index, (name, wanted) in enumerate(expected_assets.items(), 1):
            same_release(c, runtime, known)
            c.source_inventory(runtime, source_fd, expected, source, full=False)
            assert c.dir_identity(parent_fd) == parent
            endpoint = UPLOAD_URL.removesuffix('{?name,label}') + '?' + urllib.parse.urlencode({'name': name})
            assert endpoint.startswith(UPLOAD_URL.removesuffix('{?name,label}') + '?name=')
            runtime.write('POST-%d-STARTED.json' % index, {'utc': c.utc(), 'releaseID': RELEASE_ID,
                'name': name, 'inputPath': str(inputs[name]), 'bytes': wanted['bytes'],
                'sha256': wanted['sha256'], 'endpoint': endpoint, 'attemptNumber': 1})
            code, response, _ = runtime.gh(['api', '-X', 'POST', '-H', 'Content-Type: application/octet-stream',
                endpoint, '--input', str(inputs[name])], 'first-post-%d' % index, timeout=1200)
            assert code == 0
            asset = json.loads(response)
            assert type(asset['id']) is int and asset['id'] > 0
            assert asset['name'] == name and asset['size'] == wanted['bytes'] and asset['state'] == 'uploaded'
            assert asset['url'] == 'https://api.github.com/repos/%s/releases/assets/%d' % (c.REPO, asset['id'])
            assert not asset.get('digest') or asset['digest'] == 'sha256:' + wanted['sha256']
            assert asset['id'] not in {a['id'] for a in known.values()}
            known[name] = {'name': name, 'id': asset['id'], **wanted, 'apiURL': asset['url']}
            runtime.write('POST-%d-CREATED.json' % index, known[name])
            same_release(c, runtime, known)
        runtime.phase = 'three-complete-authenticated-readbacks'
        verified = []
        for name, asset in known.items():
            proof = runtime.gh(['api', '-H', 'Accept: application/octet-stream',
                'repos/%s/releases/assets/%d' % (c.REPO, asset['id'])], 'readback-%d' % asset['id'],
                timeout=1200, expected=expected_assets[name])
            verified.append({'name': name, 'id': asset['id'], 'apiURL': asset['apiURL'],
                             **proof, 'authenticatedFullReadback': True})
            runtime.write('READBACK-%d.json' % asset['id'], verified[-1])
        runtime.phase = 'final-source-journal-and-private-state-fences'
        c.source_inventory(runtime, source_fd, expected, source, full=True)
        original_attempt(c, runtime, parent_fd, snapshot, protected)
        release = same_release(c, runtime, known)
        c.source_inventory(runtime, source_fd, expected, source, full=False)
        assert c.dir_identity(parent_fd) == parent
        manifest_pin = {'path': str(ORIGINAL / MANIFEST_NAME), **MANIFEST_PIN}
        result = {'status': 'EXACT_PRIVATE_DIFFERENTIAL_AND_12_METADATA_FULL_BYTES_READBACK_VERIFIED_ORIGINALS_RETAINED',
            'utc': c.utc(), 'repository': {'id': c.REPO_ID, 'full_name': c.REPO, 'private': True},
            'releaseID': RELEASE_ID, 'tag': c.TAG, 'draft': True, 'releaseURL': release['html_url'],
            'sourceDirectory': str(c.SOURCE), 'sourceParent': expected['parent'],
            'sourceIdentity': source[c.ARCHIVE_NAME]['identity'],
            'sourceRestoreMetadata': source[c.ARCHIVE_NAME]['restoreMetadata'],
            'manifest': manifest_pin, 'assets': verified, 'metadataMembersVerified': 12,
            'metadataMemberVerificationScope': 'Exact prior12-member proof retained by full current bundle+manifest equality and full authenticated readback; no new archive extraction.',
            'currentSourceFullHashesUnchanged': True, 'unchangedExternalDependencies': dependencies,
            'selfContained': False, 'fullTreeRestorationVerified': False, 'windowsAccess': False,
            'localRetirement': False, 'newSDKBuilds': 0, 'nativeRuns': 0,
            'failedOriginalAttemptPreserved': {'snapshotSHA256': FAILURE_SNAPSHOT_SHA, 'files': 30,
                'metadataBundleUnchanged': True, 'originalFailedReceiptSHA256': protected['FAILED.json']['sha256']},
            'continuation': {'directory': str(JOURNAL), 'helperSHA256': HELPER_SHA,
                'controllerSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'sameDraft': True, 'newReleases': 0, 'assetPostAttempts': 3, 'automaticRetries': 0},
            'rootFreeBefore': runtime.root_before, 'rootFreeAfter': runtime.free(),
            'seconds': time.monotonic() - runtime.started}
        row = runtime.write(FINAL_NAME, result)
        completed_raw = c.canonical(result)
        runtime.guard(len(completed_raw))
        # Root explicitly allows this ONE new original-journal receipt only
        # after all three readbacks and full current/source/history fences.
        fd = os.open(FINAL_NAME, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644, dir_fd=parent_fd)
        try:
            with os.fdopen(os.dup(fd), 'wb') as f:
                f.write(completed_raw)
                f.flush()
                os.fsync(f.fileno())
        finally:
            os.close(fd)
        os.fsync(parent_fd)
        final_fd = c.open_regular(parent_fd, FINAL_NAME)
        try:
            count, sha, reread = c.hash_fd(final_fd, runtime, len(completed_raw), capture=True)
            assert count == len(completed_raw) and sha == row['sha256'] and reread == completed_raw
        finally:
            os.close(final_fd)
        original_attempt(c, runtime, parent_fd, snapshot, protected, final=True)
        original_row = {'path': str(ORIGINAL / FINAL_NAME), 'bytes': count, 'sha256': sha}
        runtime.write('FINAL_RECEIPT_PUBLISHED.json', {'originalReceipt': original_row, 'journalReceipt': row,
            'failedOriginalAttemptUnchanged': True, 'localRetirement': False})
        print(json.dumps({'status': result['status'], 'receipt': original_row, 'releaseID': RELEASE_ID,
                          'selfContained': False, 'localRetirement': False}))
    except BaseException as error:
        runtime.write('CONTINUATION_FAILED.json', {'status': 'INCOMPLETE_ORIGINALS_AND_PARTIAL_REMOTE_STATE_RETAINED',
            'utc': c.utc(), 'phase': runtime.phase, 'errorType': type(error).__name__, 'error': str(error)[:2000],
            'sameReleaseID': RELEASE_ID, 'noAutomaticRetry': True, 'localRetirement': False}, terminal=True)
        raise
    finally:
        if source_fd is not None:
            os.close(source_fd)
        if parent_fd is not None:
            os.close(parent_fd)
        os.close(runtime.fd)


if __name__ == '__main__':
    main()
