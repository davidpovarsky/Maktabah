"""One authorized retirement of three verified, released compiler caches."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess

ROOT = Path('/Users/m1/builds/otzaria-wave2-library-controls-20261127')
TARGETS = {
    'inspector-generation-attempt-1/module-cache': 69059376,
    'inspector-generation-attempt-2/module-cache': 69162831,
    'ui-attempt-1/module-cache': 67222188,
}
EXPECTED_DEVICE = 16777232


def require(value, message):
    if not value:
        raise RuntimeError(message)


def raw_identity(path):
    s = path.lstat()
    return {'device': s.st_dev, 'inode': s.st_ino, 'uid': s.st_uid, 'gid': s.st_gid,
            'mode': s.st_mode, 'bytes': s.st_size, 'mtimeNs': s.st_mtime_ns,
            'ctimeNs': s.st_ctime_ns, 'links': s.st_nlink, 'allocatedBytes': s.st_blocks * 512}


def inventory(path):
    require(path == path.resolve(strict=True), 'Noncanonical target')
    rows = []
    pending = [path]
    while pending:
        member = pending.pop()
        s = raw_identity(member)
        require(s['uid'] == os.getuid() and s['device'] == EXPECTED_DEVICE, 'Foreign cache owner/device')
        require(stat.S_ISDIR(s['mode']) or stat.S_ISREG(s['mode']), 'Symlink/nonregular cache member')
        require(member == member.resolve(strict=True) and member.is_relative_to(path), 'Cache member escape')
        row = {'relativePath': '.' if member == path else member.relative_to(path).as_posix(), **s}
        if stat.S_ISDIR(s['mode']):
            pending.extend(member.iterdir())
        else:
            require(s['links'] == 1, 'Shared hardlink is not a disposable owned cache member')
        rows.append(row)
        require(len(rows) <= 10000, 'Unexpected cache membership bound')
    return sorted(rows, key=lambda x: x['relativePath'])


def adjacent():
    result = {}
    total = 0
    for name in TARGETS:
        parent = (ROOT / name).parent
        for path in parent.iterdir():
            if path.name == 'module-cache':
                continue
            record = raw_identity(path)
            if stat.S_ISREG(record['mode']):
                require(record['bytes'] <= 64 * 1024**2, 'Adjacent file hash bound')
                total += record['bytes']
                require(total <= 128 * 1024**2, 'Adjacent total hash bound')
                with path.open('rb') as stream:
                    record['sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
            result[str(path)] = record
    return result


def no_active_references():
    ps = subprocess.run(['/bin/ps', '-ww', '-axo', 'pid=,command='], capture_output=True, text=True, timeout=15)
    require(ps.returncode == 0 and not ps.stderr, 'Cannot verify active commands')
    active = [row for row in ps.stdout.splitlines() if str(ROOT) in row]
    require(not active, 'Active command references owned artifacts')
    checks = []
    for name in TARGETS:
        path = ROOT / name
        result = subprocess.run(['/usr/sbin/lsof', '-nP', '+D', str(path)], capture_output=True, text=True, timeout=20)
        checks.append({'path': str(path), 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
        require(result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip(),
                'Open FD or incomplete lsof ownership check')
    return {'commandsReferencingOwnedRoot': active, 'lsof': checks}


def write(path, value):
    with path.open('x') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, sort_keys=True)
        stream.write('\n')


require(ROOT == ROOT.resolve(strict=True) and ROOT.is_dir(), 'Wrong owned artifact root')
require(subprocess.check_output(['id', '-un'], text=True).strip() == 'm1', 'Wrong native owner')
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
out = ROOT / ('cache-retirement-' + stamp)
out.mkdir()
result = {'schema': 1, 'status': 'STARTED_NOT_COMPLETE', 'utcStarted': stamp, 'output': str(out),
          'authorization': 'Root explicit 2026-11-27 message: only three released module-cache directories',
          'freeBytesBefore': shutil.disk_usage(ROOT).free, 'removed': []}
try:
    before = {}
    for name, inode in TARGETS.items():
        path = ROOT / name
        rows = inventory(path)
        require(rows[0]['relativePath'] == '.' and rows[0]['inode'] == inode, 'Expected canonical cache inode changed')
        du = subprocess.run(['du', '-sk', str(path)], text=True, capture_output=True, timeout=15)
        require(du.returncode == 0 and not du.stderr, 'Cache allocation inventory failed')
        before[name] = {'allocatedKiB': int(du.stdout.split()[0]), 'members': rows}
    preserved = adjacent()
    references = no_active_references()
    for name in TARGETS:
        require(inventory(ROOT / name) == before[name]['members'], 'Cache changed after open-reference check')
    write(out / 'BEFORE.json', {'caches': before, 'adjacent': preserved, 'activeReferences': references})
    for name in TARGETS:
        target = ROOT / name
        rows = sorted(before[name]['members'], key=lambda x: len(Path(x['relativePath']).parts), reverse=True)
        # The root '.' sorts last explicitly; remove only originally inventoried
        # members, rejecting any newly created file instead of recursive guessing.
        rows = [row for row in rows if row['relativePath'] != '.'] + [row for row in rows if row['relativePath'] == '.']
        for row in rows:
            path = target if row['relativePath'] == '.' else target / row['relativePath']
            current = raw_identity(path)
            require(path == path.resolve(strict=True), 'Target changed into an alias before removal')
            for field in ('device', 'inode', 'uid', 'gid', 'mode'):
                require(current[field] == row[field], 'Owned member identity changed before removal')
            if stat.S_ISDIR(row['mode']):
                path.rmdir()
            else:
                require(current == {key: row[key] for key in current}, 'Owned generated file changed before removal')
                path.unlink()
        result['removed'].append({'path': str(target), 'originalInode': TARGETS[name],
                                  'memberCount': len(rows), 'allocatedKiBBefore': before[name]['allocatedKiB']})
    require(adjacent() == preserved, 'Adjacent source/binary/input/receipt identity changed')
    require(all(not (ROOT / name).exists() and not (ROOT / name).is_symlink() for name in TARGETS), 'A requested cache remains')
    result.update(status='THREE_RELEASED_OWNED_MODULE_CACHES_REMOVED', adjacentArtifactsUnchanged=True)
except Exception as error:
    result.update(status='FAILED_OR_PARTIAL_NO_AUTOMATIC_RETRY', errorType=type(error).__name__, error=str(error))
finally:
    result['freeBytesAfter'] = shutil.disk_usage(ROOT).free
    result['utcFinished'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result['dfAfter'] = subprocess.run(['df', '-k', str(ROOT)], capture_output=True, text=True, timeout=15).stdout
    write(out / 'RESULT.json', result)
    print(json.dumps(result, ensure_ascii=False))
