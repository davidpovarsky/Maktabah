#!/usr/bin/env python3
"""Prepare, then conditionally unlink ONE exact privately preserved archive.

No recursion, process termination, remote mutation or archive extraction.
Root must preserve the PREDELETE/pointer/scripts in Git and independently read
their hashes before supplying --ack-predelete-sha256 to the commit phase.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import importlib.util
import json
import os
import stat
import time

RESTORE_SCRIPT_SHA256 = '1b37904c91524d856c66060a2f8c227e943d7e945beb817ef24fbdf4d759b16f'
RESTORE_PATH = Path(__file__).with_name('restore_closed_native_archive.py')


def load_helpers():
    fd = os.open(RESTORE_PATH, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        assert stat.S_ISREG(before.st_mode) and before.st_nlink == 1 and before.st_size <= 128 * 1024
        raw = os.pread(fd, 128 * 1024, 0)
        assert len(raw) == before.st_size and hashlib.sha256(raw).hexdigest() == RESTORE_SCRIPT_SHA256
        after = os.fstat(fd)
        assert (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) == (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns)
    finally:
        os.close(fd)
    # Compile exactly the bytes just verified, without path-based reload or a
    # bytecode-cache write. Importing these definitions performs no operation.
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader('pinned_archive_restoration', loader=None))
    module.__file__ = str(RESTORE_PATH)
    exec(compile(raw, str(RESTORE_PATH), 'exec'), module.__dict__)
    return module, raw


def capture_restore_metadata(fd):
    s = os.fstat(fd)
    rows, total = [], 0
    for name in sorted(os.listxattr(fd)):
        value = os.getxattr(fd, name); total += len(value)
        assert len(value) <= 1024 * 1024 and total <= 4 * 1024 * 1024
        rows.append({'name_base64': base64.b64encode(os.fsencode(name)).decode(),
            'value_base64': base64.b64encode(value).decode(), 'bytes': len(value),
            'sha256': hashlib.sha256(value).hexdigest()})
    return {'mode': stat.S_IMODE(s.st_mode), 'uid': s.st_uid, 'gid': s.st_gid,
        'atime_ns': s.st_atime_ns, 'mtime_ns': s.st_mtime_ns, 'xattrs': rows,
        'ctimeAndInodeAreEvidenceNotRestorableMetadata': True}


def no_use(target, allowed_fds, maximum_seconds=20):
    """Only inode metadata is reported; no command line, environment or data."""
    started = time.monotonic(); inspected = 0; matches = []; vanished = 0
    me = os.getpid()
    def deadline():
        assert time.monotonic() - started <= maximum_seconds, 'Bounded /proc inspection timeout'
    def start(pid):
        raw = Path('/proc/%d/stat' % pid).read_text()
        return raw[raw.rfind(')') + 2:].split()[19]
    def matches_stat(s):
        return (s.st_dev, s.st_ino) == (target['device'], target['inode'])
    def disappeared(pid, original):
        try:
            assert start(pid) == original, 'PID identity changed during no-use inspection'
            return False
        except FileNotFoundError:
            return True
    for entry in os.scandir('/proc'):
        if not entry.name.isdigit():
            continue
        deadline(); pid = int(entry.name)
        try:
            before = start(pid)
        except FileNotFoundError:
            vanished += 1; continue
        try:
            for fd_entry in os.scandir('/proc/%d/fd' % pid):
                deadline()
                if pid == me and fd_entry.name.isdigit() and int(fd_entry.name) in allowed_fds:
                    continue
                try:
                    s = os.stat(fd_entry.path)
                except FileNotFoundError:
                    continue  # A concurrently closed descriptor is not active.
                if matches_stat(s):
                    matches.append({'pid': pid, 'procStart': before, 'kind': 'fd', 'fd': fd_entry.name,
                                    'device': s.st_dev, 'inode': s.st_ino, 'size': s.st_size})
            # maps includes mappings after their original descriptor was closed.
            with open('/proc/%d/maps' % pid, 'rt') as maps:
                consumed = 0
                for line in maps:
                    deadline(); consumed += len(line)
                    assert consumed <= 16 * 1024 * 1024, 'Bounded process mapping size exceeded'
                    fields = line.split(None, 5)
                    assert len(fields) >= 5, 'Malformed process mapping observation'
                    major, minor = fields[3].split(':')
                    if (os.makedev(int(major, 16), int(minor, 16)), int(fields[4])) == (target['device'], target['inode']):
                        matches.append({'pid': pid, 'procStart': before, 'kind': 'mapping',
                                        'device': target['device'], 'inode': target['inode']})
            for facet in ('cwd', 'exe'):
                try:
                    s = os.stat('/proc/%d/%s' % (pid, facet))
                except FileNotFoundError:
                    continue  # Kernel/zombie processes need not have these.
                if matches_stat(s):
                    matches.append({'pid': pid, 'procStart': before, 'kind': facet,
                                    'device': s.st_dev, 'inode': s.st_ino})
            if disappeared(pid, before):
                vanished += 1
            else:
                inspected += 1
        except FileNotFoundError:
            if disappeared(pid, before):
                vanished += 1
            else:
                raise
        # PermissionError, unexpected errors, PID reuse and timeout fail closed.
    assert not matches, 'Archive has active holders: ' + json.dumps(matches)
    return {'status': 'NO_MATCHING_ACTIVE_FD_MAPPING_CWD_OR_EXE', 'processesInspected': inspected,
            'vanishedProcesses': vanished, 'seconds': time.monotonic() - started,
            'targetDevice': target['device'], 'targetInode': target['inode'],
            'ownAllowedFDs': sorted(allowed_fds), 'matches': [], 'inspectionErrors': 0}


def load_preservation(h, journal):
    raw_receipt = h.read_regular(h.CONTROL / 'VERIFIED_PRIVATE_PRESERVATION.json')
    receipt = h.verify_receipt(raw_receipt)
    raw_manifest = h.read_regular(h.CONTROL / h.MANIFEST_NAME)
    manifest = h.verify_manifest(raw_manifest, receipt)
    # Reuse the actual readback's exact local metadata bytes. No second 1.46GB
    # download is claimed; the original complete readback receipt stays pinned.
    fd = os.open(h.CONTROL / h.METADATA_NAME, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = h.identity(os.fstat(fd))
        assert before['size'] == h.ASSETS[h.METADATA_NAME]['bytes']
        assert h.hash_fd(fd, before['size']) == h.ASSETS[h.METADATA_NAME]['sha256']
        assert h.identity(os.fstat(fd)) == before
        metadata = h.verify_metadata_tar(h.CONTROL / h.METADATA_NAME, manifest)
        assert h.identity(os.stat(h.CONTROL / h.METADATA_NAME, follow_symlinks=False)) == before
    finally:
        os.close(fd)
    remote = h.remote_state(journal)
    return raw_receipt, receipt, raw_manifest, manifest, metadata, remote


def source_check(h, parent_fd, receipt, manifest, capture_metadata=False):
    assert h.parent_identity(parent_fd) == h.PARENT
    protected = h.verify_siblings(parent_fd, manifest, archive_present=True)
    fd = h.open_leaf(parent_fd, h.LEAF)
    try:
        before = h.identity(os.fstat(fd))
        assert before == receipt['sourceIdentity']
        saved = capture_restore_metadata(fd) if capture_metadata else None
        assert h.hash_fd(fd, h.ASSETS[h.LEAF]['bytes']) == h.ASSETS[h.LEAF]['sha256']
        assert h.identity(os.fstat(fd)) == before
        assert h.identity(os.stat(h.LEAF, dir_fd=parent_fd, follow_symlinks=False)) == before
        return fd, before, saved, protected
    except BaseException:
        os.close(fd)
        raise


def prepare(h, restoration_source, args):
    journal = h.Journal('retire', args.attempt)
    parent_fd = archive_fd = None
    try:
        raw_receipt, receipt, raw_manifest, manifest, metadata, remote = load_preservation(h, journal)
        parent_fd = h.open_source()
        archive_fd, original, saved, protected = source_check(h, parent_fd, receipt, manifest, True)
        use = no_use(original, {archive_fd})
        assert h.identity(os.fstat(archive_fd)) == original
        assert h.identity(os.stat(h.LEAF, dir_fd=parent_fd, follow_symlinks=False)) == original
        pointer = {'schema': 'otzaria.one-archive-restoration-pointer.v1', 'sourceDirectory': str(h.SOURCE),
            'leaf': h.LEAF, 'parent': h.PARENT, 'assets': h.ASSETS,
            'receiptSHA256': h.RECEIPT_SHA, 'receiptBase64': base64.b64encode(raw_receipt).decode(),
            'originalLeafIdentity': original, 'leafRestoreMetadata': saved,
            'metadataMemberCount': len(protected), 'restorationScriptSHA256': RESTORE_SCRIPT_SHA256,
            'semantics': 'Restore only the original archive leaf with exclusive creation. No Mac payload extraction. Inode/ctime cannot be restored. All 22 original metadata siblings remain.'}
        pointer_row = journal.write('RESTORATION_POINTER.json', pointer)
        script_row = journal.write('restore_closed_native_archive.py', restoration_source)
        controller = h.read_regular(Path(__file__))
        controller_row = journal.write('retire_closed_native_archive.py', controller)
        manifest_row = journal.write(h.MANIFEST_NAME, raw_manifest)
        receipt_row = journal.write('VERIFIED_PRIVATE_PRESERVATION.json', raw_receipt)
        predelete = {'schema': 'otzaria.one-archive-predelete.v1', 'status': 'PREPARED_ORIGINAL_RETAINED',
            'utc': h.utc(), 'sourceDirectory': str(h.SOURCE), 'leaf': h.LEAF, 'parent': h.PARENT,
            'sourceIdentity': original, 'archiveSHA256': h.ASSETS[h.LEAF]['sha256'],
            'leafRestoreMetadata': saved, 'protectedSiblings': protected,
            'restorationPointer': pointer_row, 'restorationScript': script_row,
            'retirementController': controller_row, 'verifiedReceipt': receipt_row, 'manifest': manifest_row,
            'metadataMembers': metadata, 'freshRemoteIdentity': remote, 'noUse': use,
            'fullRemotePayloadProof': h.RECEIPT_SHA, 'removed': False,
            'rootActionBeforeCommit': 'Independently preserve/read back the exact pointer, scripts, receipt and manifest in Git; then acknowledge this exact PREDELETE SHA. This controller does not manufacture or attest a Git publication.'}
        row = journal.write('PREDELETE.json', predelete)
        print(json.dumps({'status': predelete['status'], 'predelete': row,
                          'pointer': pointer_row, 'restorationScript': script_row, 'removed': False}))
    except BaseException as error:
        journal.write('PREPARE_FAILED.json', {'status': 'FAILED_ORIGINAL_RETAINED', 'utc': h.utc(),
            'errorType': type(error).__name__, 'message': str(error), 'removed': False}, terminal=True)
        raise
    finally:
        if archive_fd is not None:
            os.close(archive_fd)
        if parent_fd is not None:
            os.close(parent_fd)
        journal.close()


def commit(h, restoration_source, args):
    journal = h.Journal('retire', args.attempt, existing=True)
    journal.sequence = 1000  # Separate, exclusive audit names from prepare.
    parent_fd = archive_fd = None
    removed = False; before_free = None
    try:
        raw_predelete = h.read_regular(journal.path / 'PREDELETE.json')
        assert len(args.ack_predelete_sha256) == 64 and h.digest(raw_predelete) == args.ack_predelete_sha256
        pre = json.loads(raw_predelete)
        assert pre['schema'] == 'otzaria.one-archive-predelete.v1' and pre['status'] == 'PREPARED_ORIGINAL_RETAINED'
        assert pre['sourceDirectory'] == str(h.SOURCE) and pre['leaf'] == h.LEAF and pre['parent'] == h.PARENT
        assert pre['fullRemotePayloadProof'] == h.RECEIPT_SHA and pre['archiveSHA256'] == h.ASSETS[h.LEAF]['sha256']
        for key, name in [('restorationPointer', 'RESTORATION_POINTER.json'),
                          ('restorationScript', 'restore_closed_native_archive.py'),
                          ('retirementController', 'retire_closed_native_archive.py'),
                          ('verifiedReceipt', 'VERIFIED_PRIVATE_PRESERVATION.json'), ('manifest', h.MANIFEST_NAME)]:
            raw = h.read_regular(journal.path / name)
            assert pre[key] == {'path': str(journal.path / name), 'bytes': len(raw), 'sha256': h.digest(raw)}
        assert h.digest(restoration_source) == pre['restorationScript']['sha256'] == RESTORE_SCRIPT_SHA256
        assert h.digest(h.read_regular(Path(__file__))) == pre['retirementController']['sha256']
        assert pre['verifiedReceipt']['sha256'] == h.RECEIPT_SHA
        pointer_raw = h.read_regular(journal.path / 'RESTORATION_POINTER.json')
        pointer = json.loads(pointer_raw)
        assert pointer['leafRestoreMetadata'] == pre['leafRestoreMetadata'] and pointer['originalLeafIdentity'] == pre['sourceIdentity']
        # A second commit invocation refuses at this exclusive durable marker.
        journal.write('COMMIT_STARTED.json', {'utc': h.utc(), 'ackPREDELETE': args.ack_predelete_sha256,
            'pointerSHA256': h.digest(pointer_raw), 'scope': str(h.SOURCE / h.LEAF)})
        _, receipt, _, manifest, metadata, remote = load_preservation(h, journal)
        parent_fd = h.open_source()
        archive_fd, original, _, protected = source_check(h, parent_fd, receipt, manifest)
        assert original == pre['sourceIdentity'] and protected == pre['protectedSiblings']
        before_free = os.fstatvfs(parent_fd).f_bavail * os.fstatvfs(parent_fd).f_frsize
        use = no_use(original, {archive_fd})
        journal.write('COMMIT_REVALIDATED.json', {'utc': h.utc(), 'ackPREDELETE': args.ack_predelete_sha256,
            'sourceIdentity': original, 'parent': h.PARENT, 'metadataMembers': metadata,
            'freshRemoteIdentity': remote, 'noUse': use, 'freeBefore': before_free})
        # No subprocess or external callback after this final path/identity fence.
        assert h.parent_identity(parent_fd) == h.PARENT
        assert h.identity(os.fstat(archive_fd)) == original
        assert h.identity(os.stat(h.LEAF, dir_fd=parent_fd, follow_symlinks=False)) == original
        assert set(os.listdir(parent_fd)) == {h.LEAF} | {r['name'] for r in protected}
        os.unlink(h.LEAF, dir_fd=parent_fd)
        removed = True
        os.fsync(parent_fd)
        os.close(archive_fd); archive_fd = None
        assert h.parent_identity(parent_fd) == h.PARENT
        assert h.verify_siblings(parent_fd, manifest, archive_present=False) == protected
        after_free = os.fstatvfs(parent_fd).f_bavail * os.fstatvfs(parent_fd).f_frsize
        result = {'status': 'ONE_EXACT_PRIVATELY_PRESERVED_ARCHIVE_LEAF_RETIRED', 'utc': h.utc(),
            'removed': True, 'solePath': str(h.SOURCE / h.LEAF), 'oldIdentity': original,
            'parentPreserved': h.PARENT, 'protectedMetadataSiblings': len(protected),
            'ackPREDELETE': args.ack_predelete_sha256, 'restorationPointer': pre['restorationPointer'],
            'restorationScript': pre['restorationScript'], 'privateFullReadbackProof': h.RECEIPT_SHA,
            'freeBefore': before_free, 'freeAfter': after_free,
            'capacityClaim': 'Concurrent filesystem observations; no guaranteed or exclusively attributed reclaimed byte count.',
            'remoteChanges': False, 'SDKBuilds': 0, 'nativeRuns': 0}
        row = journal.write('RETIREMENT_RESULT.json', result, terminal=True)
        print(json.dumps({'status': result['status'], 'receipt': row, 'removed': True,
                          'freeBefore': before_free, 'freeAfter': after_free}))
    except BaseException as error:
        journal.write('RETIREMENT_FAILED.json', {'status': 'FAILED_WITH_EXACT_PARTIAL_STATE_PRESERVED',
            'utc': h.utc(), 'errorType': type(error).__name__, 'message': str(error),
            'solePath': str(h.SOURCE / h.LEAF), 'removed': removed, 'freeBefore': before_free,
            'noOtherRemovalAttempted': True}, terminal=True)
        raise
    finally:
        if archive_fd is not None:
            os.close(archive_fd)
        if parent_fd is not None:
            os.close(parent_fd)
        journal.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('prepare', 'commit'))
    parser.add_argument('--attempt', required=True, help='Canonical UUID; commit reuses its prepared attempt')
    parser.add_argument('--ack-predelete-sha256')
    args = parser.parse_args()
    if args.phase == 'commit':
        assert args.ack_predelete_sha256 is not None, 'Root must acknowledge exact durable PREDELETE'
    else:
        assert args.ack_predelete_sha256 is None
    h, source = load_helpers()
    (prepare if args.phase == 'prepare' else commit)(h, source, args)


if __name__ == '__main__':
    main()
