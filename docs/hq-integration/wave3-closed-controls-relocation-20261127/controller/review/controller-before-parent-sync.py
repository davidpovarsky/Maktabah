"""Two-phase, lossless relocation of an exact closed diagnostic allowlist.

Prepare copies and verifies everything without changing a Data path. Cutover is
explicit and requires the exact PREPARED receipt hash. Neither phase runs tests.
"""
from pathlib import Path
import base64, datetime, hashlib, json, os, shutil, stat, subprocess, sys, time

HERE = Path(__file__).resolve().parent
PLAN = json.loads((HERE / 'PLAN.json').read_bytes())
DEST = Path(PLAN['rootDestination'])
DEADLINE = time.monotonic() + 360
FLOOR = PLAN['rootFloorBytes'] + PLAN['keepAdditionalAgentReserveBytes']

def check_time():
    if time.monotonic() > DEADLINE:
        raise RuntimeError('Relocation deadline reached; retained evidence is not cleaned up')

def free(path):
    s = os.statvfs(path)
    return s.f_bavail * s.f_frsize

def guard():
    check_time()
    if free('/') < FLOOR:
        raise RuntimeError('Root floor plus reserved agent allocation not available')

def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()

def digest(data):
    return hashlib.sha256(data).hexdigest()

def durable(path, value):
    data = canonical(value)
    with path.open('xb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    return digest(data)

def regular_hash(path, expected):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NOATIME)
    try:
        a = os.fstat(fd)
        assert (a.st_dev, a.st_ino, a.st_size, a.st_mtime_ns, a.st_ctime_ns) == expected
        h = hashlib.sha256()
        while True:
            check_time()
            block = os.read(fd, 1024 * 1024)
            if not block:
                break
            h.update(block)
        b = os.fstat(fd)
        assert (b.st_dev, b.st_ino, b.st_size, b.st_mtime_ns, b.st_ctime_ns) == expected
        return h.hexdigest()
    finally:
        os.close(fd)

def inventory(root):
    root = Path(root)
    assert root.resolve() == root and not root.is_symlink()
    device = root.lstat().st_dev
    rows = []
    def walk(path, rel):
        guard()
        s = path.lstat()
        assert s.st_dev == device, ('cross-device entry', str(path))
        assert path.name != '.git', ('Git entry not eligible', str(path))
        row = {'path': rel, 'mode': s.st_mode, 'uid': s.st_uid, 'gid': s.st_gid,
               'atime_ns': s.st_atime_ns, 'mtime_ns': s.st_mtime_ns,
               'ctime_ns': s.st_ctime_ns, 'device': s.st_dev, 'inode': s.st_ino,
               'nlink': s.st_nlink, 'blocks': s.st_blocks, 'size': s.st_size,
               'xattrs': {k: base64.b64encode(os.getxattr(path, k, follow_symlinks=False)).decode()
                         for k in sorted(os.listxattr(path, follow_symlinks=False))}}
        if stat.S_ISREG(s.st_mode):
            assert s.st_nlink == 1, ('hardlinked file not eligible', str(path))
            row['type'] = 'file'
            row['sha256'] = regular_hash(path, (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns))
        elif stat.S_ISLNK(s.st_mode):
            row['type'] = 'symlink'
            row['target'] = os.readlink(path)
            if not os.path.isabs(row['target']):
                lexical = os.path.abspath(os.path.join(str(path.parent), row['target']))
                assert lexical == str(root) or lexical.startswith(str(root) + '/'), ('Escaping relative link is not eligible', str(path))
        elif stat.S_ISDIR(s.st_mode):
            row['type'] = 'directory'
        else:
            raise RuntimeError(('Special file not eligible', str(path)))
        rows.append(row)
        if row['type'] == 'directory':
            fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NOATIME)
            try:
                with os.scandir(fd) as entries:
                    names = sorted(e.name for e in entries)
            finally:
                os.close(fd)
            for name in names:
                walk(path / name, name if rel == '.' else rel + '/' + name)
    walk(root, '.')
    return rows

def content_metadata(rows):
    # Inode, device, ctime and allocated blocks necessarily change across volumes.
    # Original values and original atime remain in the complete source manifest.
    ignored = {'inode', 'device', 'ctime_ns', 'blocks', 'atime_ns', 'nlink'}
    return [{k: v for k, v in r.items() if k not in ignored
             and not (k == 'size' and r['type'] == 'directory')} for r in rows]

def restore_times(root, rows):
    for row in reversed(rows):
        os.utime(root / row['path'], ns=(row['atime_ns'], row['mtime_ns']), follow_symlinks=False)

def sync_copy(root, rows):
    # Flush copied content and inode metadata, then directory entries bottom-up.
    for row in rows:
        guard()
        if row['type'] != 'file':
            continue
        fd = os.open(root / row['path'], os.O_RDONLY | os.O_NOFOLLOW | os.O_NOATIME)
        try:
            assert stat.S_ISREG(os.fstat(fd).st_mode)
            os.fsync(fd)
        finally:
            os.close(fd)
    for row in reversed(rows):
        guard()
        if row['type'] != 'directory':
            continue
        fd = os.open(root / row['path'], os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NOATIME)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

def no_use(roots):
    started = time.monotonic()
    prefixes = tuple(str(p) for p in roots)
    matches, count = [], 0
    def relevant(value):
        return any(value == p or value.startswith(p + '/') for p in prefixes)
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit() or int(proc.name) == os.getpid():
            continue
        check_time()
        if time.monotonic() - started > 20:
            raise RuntimeError('No-use metadata observation exceeded its deadline')
        count += 1
        try:
            for name in ['cwd', 'root', 'exe']:
                try:
                    value = os.readlink(proc / name)
                    if relevant(value):
                        matches.append({'pid': int(proc.name), 'kind': name, 'path': value})
                except (FileNotFoundError, ProcessLookupError):
                    pass
            for fd in (proc / 'fd').iterdir():
                try:
                    value = os.readlink(fd)
                    if relevant(value):
                        matches.append({'pid': int(proc.name), 'kind': 'fd', 'path': value})
                except (FileNotFoundError, ProcessLookupError):
                    pass
            # Read mapping path metadata only; never inspect arguments or environment.
            for line in (proc / 'maps').read_text().splitlines():
                fields = line.split(None, 5)
                if len(fields) == 6 and relevant(fields[5]):
                    matches.append({'pid': int(proc.name), 'kind': 'mapping', 'path': fields[5]})
        except (FileNotFoundError, ProcessLookupError):
            pass
    assert not matches, ('Closed diagnostic has live users', matches)
    return {'processMetadataRows': count, 'matches': matches,
            'seconds': time.monotonic() - started, 'processSignals': 0,
            'limits': 'Point-in-time fd/cwd/exe/mapping observation; agent leases also checked. Original aliases preserve future reads.'}

def validate_plan():
    assert len(PLAN['scopes']) == 15
    assert DEST == Path('/home/ubuntu/otzaria-wave3-closed-controls-relocated-20261127')
    roots = [Path(r['path']) for r in PLAN['scopes']]
    assert len(set(roots)) == 15
    for root in roots:
        assert root.parent in [Path('/mnt/development/projects/worktrees'), Path('/mnt/development/projects/diagnostics')]
        assert all(not str(root).startswith(p + '/') and str(root) != p for p in PLAN['protected'])
    return roots

def prepare():
    guard()
    roots = validate_plan()
    assert not DEST.exists()
    before = {'rootFree': free('/'), 'dataFree': free('/mnt/development')}
    live = no_use(roots)
    all_rows = []
    for config, root in zip(PLAN['scopes'], roots):
        rows = inventory(root)
        identity = config['expectedTopIdentity']
        if identity:
            assert all(rows[0][k] == identity[k] for k in ['device', 'inode', 'uid', 'gid'])
        by_path = {r['path']: r for r in rows}
        for pin in config['receiptPins']:
            row = by_path[pin['path']]
            assert row['type'] == 'file' and row['sha256'] == pin['sha256'] and row['size'] == pin['bytes']
        all_rows.append(rows)
    allocated = sum(r['blocks'] * 512 for rows in all_rows for r in rows)
    assert allocated <= PLAN['maxCopiedAllocationBytes']
    assert free('/') - allocated - 16777216 >= FLOOR
    DEST.mkdir(mode=0o755)
    os.chown(DEST, 1001, 1001)
    durable(DEST / 'PLAN.json', PLAN)
    shutil.copy2(__file__, DEST / 'CONTROLLER.py')
    summaries = []
    for index, (root, rows) in enumerate(zip(roots, all_rows)):
        guard()
        target = DEST / root.name
        assert not target.exists()
        subprocess.run(['/usr/bin/cp', '--archive', '--reflink=never', '--', str(root), str(target)], check=True, timeout=60)
        restore_times(target, rows)
        copied = inventory(target)
        assert content_metadata(copied) == content_metadata(rows), str(root)
        fresh = inventory(root)
        assert content_metadata(fresh) == content_metadata(rows), str(root)
        assert [(r['device'], r['inode'], r['ctime_ns']) for r in fresh] == [(r['device'], r['inode'], r['ctime_ns']) for r in rows]
        restore_times(target, rows)
        sync_copy(target, rows)
        manifest = {'source': str(root), 'destination': str(target), 'original': rows, 'copied': copied}
        sha = durable(DEST / ('MANIFEST-%02d.json' % index), manifest)
        summaries.append({'source': str(root), 'destination': str(target), 'entries': len(rows), 'manifestSHA256': sha})
    guard()
    after_no_use = no_use(roots + [DEST])
    receipt = {'status': 'FULL_COPY_AND_METADATA_VERIFIED_DATA_ORIGINS_UNCHANGED',
               'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'planSHA256': digest(canonical(PLAN)), 'scopes': summaries,
               'allocatedSourceBytes': allocated, 'before': before,
               'after': {'rootFree': free('/'), 'dataFree': free('/mnt/development')},
               'beforeNoUse': live, 'afterNoUse': after_no_use,
               'sourcePathMutations': 0, 'builds': 0, 'testRuns': 0}
    sha = durable(DEST / 'PREPARED.json', receipt)
    print(json.dumps({'status': receipt['status'], 'receiptSHA256': sha,
                      'scopes': len(roots), 'entries': sum(len(r) for r in all_rows),
                      'allocatedSourceBytes': allocated, 'after': receipt['after']}))

def cutover(expected_hash):
    guard()
    roots = validate_plan()
    raw = (DEST / 'PREPARED.json').read_bytes()
    assert digest(raw) == expected_hash
    prepared = json.loads(raw)
    assert prepared['planSHA256'] == digest(canonical(PLAN))
    assert not (DEST / 'CUTOVER_RESULT.json').exists()
    assert shutil.rmtree.avoids_symlink_attacks
    before = {'rootFree': free('/'), 'dataFree': free('/mnt/development')}
    no_use(roots + [DEST])
    manifests = []
    for index, scope in enumerate(prepared['scopes']):
        b = (DEST / ('MANIFEST-%02d.json' % index)).read_bytes()
        assert digest(b) == scope['manifestSHA256']
        m = json.loads(b)
        root, target = Path(m['source']), Path(m['destination'])
        original = inventory(root)
        assert content_metadata(original) == content_metadata(m['original'])
        assert [(r['device'], r['inode'], r['ctime_ns']) for r in original] == [(r['device'], r['inode'], r['ctime_ns']) for r in m['original']]
        assert content_metadata(inventory(target)) == content_metadata(m['original'])
        restore_times(target, m['original'])
        sync_copy(target, m['original'])
        manifests.append(m)
    no_use(roots + [DEST])
    durable(DEST / 'PRE_CUTOVER.json', {'preparedSHA256': expected_hash, 'verifiedScopes': len(manifests),
                                     'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'before': before})
    moved = []
    for index, m in enumerate(manifests):
        guard()
        root, target = Path(m['source']), Path(m['destination'])
        parent_fd = os.open(root.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        retired = root.name + '.verified-relocation-20261127'
        try:
            assert not os.path.lexists(root.parent / retired)
            original_stat = os.stat(root.name, dir_fd=parent_fd, follow_symlinks=False)
            expected = m['original'][0]
            assert (original_stat.st_dev, original_stat.st_ino) == (expected['device'], expected['inode'])
            os.rename(root.name, retired, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
            try:
                os.symlink(str(target), root.name, dir_fd=parent_fd)
                os.chown(root.name, expected['uid'], expected['gid'], dir_fd=parent_fd, follow_symlinks=False)
            except BaseException:
                if not os.path.lexists(root):
                    os.rename(retired, root.name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
                raise
            os.fsync(parent_fd)
            assert root.is_symlink() and root.resolve() == target
            retired_stat = os.stat(retired, dir_fd=parent_fd, follow_symlinks=False)
            assert (retired_stat.st_dev, retired_stat.st_ino) == (expected['device'], expected['inode'])
            assert content_metadata(inventory(target)) == content_metadata(m['original'])
            assert content_metadata(inventory(root.parent / retired)) == content_metadata(m['original'])
            restore_times(target, m['original'])
            sync_copy(target, m['original'])
            durable(DEST / ('CUTOVER-%02d-READY.json' % index),
                    {'source': str(root), 'destination': str(target), 'retired': str(root.parent / retired),
                     'preparedSHA256': expected_hash, 'verifiedCopyPresent': True})
            no_use([root.parent / retired, root, target])
            shutil.rmtree(retired, dir_fd=parent_fd)
            os.fsync(parent_fd)
            assert not os.path.lexists(root.parent / retired)
            moved.append({'source': str(root), 'destination': str(target), 'aliasVerified': True})
            durable(DEST / ('CUTOVER-%02d-DONE.json' % index), moved[-1])
        finally:
            os.close(parent_fd)
    result = {'status': 'EXACT_CLOSED_CONTROLS_RELOCATED_ALL_ORIGINAL_PATH_ALIASES_VERIFIED',
              'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'scopes': moved,
              'preparedSHA256': expected_hash, 'before': before,
              'after': {'rootFree': free('/'), 'dataFree': free('/mnt/development')},
              'allocatedBytesRelocated': prepared['allocatedSourceBytes'],
              'spaceDeltaScope': 'Filesystem free values are concurrent observations, not exclusive attribution.',
              'uniqueEvidenceDeleted': 0, 'builds': 0, 'testRuns': 0, 'signals': []}
    sha = durable(DEST / 'CUTOVER_RESULT.json', result)
    print(json.dumps({'status': result['status'], 'receiptSHA256': sha,
                      'scopes': len(moved), 'after': result['after']}))

if __name__ == '__main__':
    if sys.argv[1:] == ['prepare']:
        prepare()
    elif len(sys.argv) == 3 and sys.argv[1] == 'cutover':
        cutover(sys.argv[2])
    else:
        raise SystemExit('Use prepare, or cutover followed by the exact PREPARED SHA256')
