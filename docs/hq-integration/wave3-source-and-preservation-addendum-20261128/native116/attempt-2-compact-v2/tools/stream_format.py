"""Closed Native116 stream format. No network, host scan, extraction or main."""
if not __debug__:
    raise RuntimeError('Optimized Python is refused')

import base64
import gzip
import hashlib
import io
import json
import posixpath
import stat
import tarfile

SOURCE_ROOT = '/Users/m1/builds/otzaria-root-actions-acceptance-20261126.wjQnLNJl/original-native116-prebuilt-evidence.X0L7wYFd'
SOURCE_DEVICE = 16777232
SOURCE_INODE = 61944944
ARCHIVE_CAP = 2 * 1024**3 - 16 * 1024**2
SNAPSHOT_CAP = 24 * 1024**2
MAX_ENTRIES = 200000
MAX_LOGICAL_BYTES = 16 * 1024**3
BLOCK = 1024**2
METADATA_MEMBER = 'metadata/native116-snapshot.json.gz'
ARCHIVE_NAME = 'native116-remaining-original-evidence.tar.gz'
SNAPSHOT_NAME = 'native116-source-snapshot.json.gz'
MANIFEST_NAME = 'native116-stream-preservation-manifest.json'
WIRE_SCHEMA = 'otzaria.native116-stream-snapshot-columns/2'
ENTRY_COLUMNS = (
    'pathBase64', 'kind', 'device', 'inode', 'mode', 'uid', 'gid', 'nlink',
    'bytes', 'allocatedBytes', 'mtimeNS', 'ctimeNS', 'atimeNS', 'flags',
    'rdev', 'xattrs', 'acl', 'birthtimeNS', 'sha256', 'targetBase64',
)
HISTORICAL_FILES = {
    'native116-actual-baseline-diagnostic.json': (1561, '0754ec183a78623bd2392a8250bb32e7e1e922d9c181584f0992da5090066c64'),
    'exit-status': (2, '4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865'),
    'native116-original-large-xcresults-relocation.json': (599, '226ec63cf8dfdc5944fc0d916e9280271389a37b784805c97ef292f63824528b'),
    'native116-videos-relocation.json': (1415, '82b4b9348b2fc94f8f30d9c873c7e3a08baafa5cc5a3b698d6ed0c0687fada4b'),
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n').encode('ascii')


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def b64(raw):
    return base64.b64encode(raw).decode('ascii')


def unb64(value):
    return base64.b64decode(value, validate=True)


def relative_bytes(row):
    value = unb64(row['pathBase64'])
    require(not value.startswith(b'/') and b'\x00' not in value, 'Invalid fixed relative path')
    require(value == b'' or all(x not in (b'', b'.', b'..') for x in value.split(b'/')), 'Unsafe path component')
    return value


def stable_row(row):
    # Original atime is preserved in the immutable snapshot, but reading may
    # naturally advance it. No other captured source metadata is refreshed.
    return {k: v for k, v in row.items() if k != 'atimeNS'}


def compact_row(row, *, full=True):
    """Remove repeated field labels only; no value, type or source field is lost."""
    require(type(row) is dict and type(full) is bool, 'Typed source row required')
    kind = row.get('kind')
    require(kind in ('file', 'directory', 'symlink'), 'Closed source row kind')
    required = set(ENTRY_COLUMNS[:-2])
    if kind == 'file' and full: required.add('sha256')
    if kind == 'symlink': required.add('targetBase64')
    require(set(row) == required, 'Exact source row fields; no metadata may be dropped')
    return [row.get(key) for key in ENTRY_COLUMNS]


def expand_row(values, *, full=True):
    require(type(values) is list and len(values) == len(ENTRY_COLUMNS), 'Exact 20-column source row')
    row = dict(zip(ENTRY_COLUMNS[:-2], values[:-2]))
    kind = row.get('kind')
    if kind == 'file' and full:
        require(values[-2] is not None and values[-1] is None, 'Regular source hash/target columns')
        row['sha256'] = values[-2]
    elif kind == 'symlink':
        require(values[-2] is None and values[-1] is not None, 'Symlink hash/target columns')
        row['targetBase64'] = values[-1]
    else:
        require(values[-2] is None and values[-1] is None, 'Absent source hash/target columns')
    require(compact_row(row, full=full) == values, 'Lossless exact source row expansion')
    return row


def snapshot_wire(snapshot):
    require(snapshot['schema'] == 'otzaria.native116-stream-snapshot/1', 'Original semantic snapshot schema')
    require('entryColumns' not in snapshot, 'Wire labels cannot replace original metadata')
    wire = dict(snapshot)
    wire.update(schema=WIRE_SCHEMA, entryColumns=list(ENTRY_COLUMNS),
                entries=[compact_row(row) for row in snapshot['entries']])
    return wire


def encode_snapshot(snapshot):
    raw = canonical(snapshot_wire(snapshot))
    require(len(raw) <= SNAPSHOT_CAP, 'Uncompressed snapshot exceeds 24 MiB')
    output = io.BytesIO()
    with gzip.GzipFile(filename='', mode='wb', fileobj=output, mtime=0, compresslevel=6) as z:
        z.write(raw)
    body = output.getvalue()
    require(len(body) <= SNAPSHOT_CAP, 'Compressed snapshot exceeds 24 MiB')
    return body


def decode_snapshot(body):
    require(0 < len(body) <= SNAPSHOT_CAP, 'Snapshot byte bound')
    with gzip.GzipFile(fileobj=io.BytesIO(body), mode='rb') as z:
        raw = z.read(SNAPSHOT_CAP + 1)
        require(len(raw) <= SNAPSHOT_CAP and not z.read(1), 'Snapshot inflation bound')
    wire = json.loads(raw)
    require(canonical(wire) == raw, 'Snapshot must be exact canonical JSON')
    require(wire['schema'] == WIRE_SCHEMA and wire['entryColumns'] == list(ENTRY_COLUMNS),
            'Exact compact wire schema and column order; no legacy fallback')
    require(type(wire['entries']) is list and 0 < len(wire['entries']) <= MAX_ENTRIES, 'Wire entry bound')
    value = dict(wire)
    del value['entryColumns']
    value.update(schema='otzaria.native116-stream-snapshot/1',
                 entries=[expand_row(row) for row in wire['entries']])
    require(snapshot_wire(value) == wire, 'Lossless complete semantic snapshot expansion')
    validate_snapshot(value)
    return value


def validate_snapshot(snapshot):
    require(snapshot['schema'] == 'otzaria.native116-stream-snapshot/1', 'Snapshot schema')
    require(snapshot['sourceRoot'] == SOURCE_ROOT, 'Fixed Native116 root only')
    require(snapshot['rootDevice'] == SOURCE_DEVICE and snapshot['rootInode'] == SOURCE_INODE, 'Root identity')
    require(snapshot['selfContained'] is False and snapshot['fullTreeRestorePerformed'] is False, 'Dependency qualification')
    require(snapshot['metadataOmissions'] == [] and snapshot['specialFilesOmitted'] is False,
            'No silent metadata/type omissions')
    rows = snapshot['entries']
    require(0 < len(rows) <= MAX_ENTRIES, 'Entry bound')
    require([relative_bytes(x) for x in rows] == sorted(relative_bytes(x) for x in rows), 'Byte-sorted entry order')
    paths, objects, links, groups, inodes = set(), {}, [], {}, {}
    logical = 0
    for row in rows:
        path = relative_bytes(row)
        require(path not in paths, 'Duplicate source path')
        paths.add(path)
        require(row['device'] == SOURCE_DEVICE, 'Cross-device source entry')
        for key in ('inode', 'mode', 'uid', 'gid', 'nlink', 'bytes', 'allocatedBytes', 'flags', 'rdev'):
            require(type(row[key]) is int and row[key] >= 0, 'Invalid numeric source metadata')
        require(row['nlink'] >= 1, 'Live source entry has no links')
        for key in ('mtimeNS', 'ctimeNS', 'atimeNS', 'birthtimeNS'):
            require(isinstance(row[key], str) and str(int(row[key])) == row[key], 'Exact timestamp string')
        attribute_names = [unb64(x['nameBase64']) for x in row['xattrs']]
        require(attribute_names == sorted(set(attribute_names)), 'Exact unique byte-sorted xattr names')
        for attribute in row['xattrs']:
            require(unb64(attribute['nameBase64']), 'Empty xattr name')
            raw = unb64(attribute['valueBase64'])
            require(len(raw) == attribute['bytes'] and digest(raw) == attribute['sha256'], 'Exact xattr payload')
        if row['acl'] is not None:
            acl = row['acl']; raw = unb64(acl['textBase64'])
            require(len(raw) == acl['bytes'] and digest(raw) == acl['sha256'], 'Exact ACL payload')
        if row['kind'] == 'file':
            require(stat.S_ISREG(row['mode']), 'Regular file type')
            sha = row['sha256']; require(isinstance(sha, str) and len(sha) == 64
                                         and all(c in '0123456789abcdef' for c in sha), 'File SHA')
            logical += row['bytes']
            require(logical <= MAX_LOGICAL_BYTES, 'Logical source-size cap')
            if sha in objects:
                require(objects[sha]['bytes'] == row['bytes'], 'Content-addressed size collision')
            else:
                objects[sha] = row
        elif row['kind'] == 'directory':
            require(stat.S_ISDIR(row['mode']), 'Directory type')
        else:
            require(row['kind'] == 'symlink' and stat.S_ISLNK(row['mode']), 'Unsupported source type')
            require(b'\x00' not in unb64(row['targetBase64']), 'Invalid symlink target')
            links.append(row['pathBase64'])
        if row['kind'] != 'directory':
            key = str(row['device']) + ':' + str(row['inode'])
            if key in inodes:
                a = {k: v for k, v in stable_row(inodes[key]).items() if k != 'pathBase64'}
                b = {k: v for k, v in stable_row(row).items() if k != 'pathBase64'}
                require(a == b, 'Hardlinked source metadata/content disagree')
            else:
                inodes[key] = row
            if row['nlink'] > 1:
                groups.setdefault(key, []).append(row['pathBase64'])
    require(b'' in paths and rows[0]['kind'] == 'directory', 'Original root row required')
    require(rows[0]['inode'] == SOURCE_INODE, 'Exact root row inode')
    for path in paths:
        if path:
            require(posixpath.dirname(path) in paths, 'Missing parent metadata')
    by_path = {relative_bytes(x): x for x in rows}
    for path in paths:
        if path:
            require(by_path[posixpath.dirname(path)]['kind'] == 'directory', 'Parent is not a captured directory')
    external_hardlinks = {}
    for key, group in groups.items():
        require(len(group) <= inodes[key]['nlink'], 'Captured links exceed original link count')
        if len(group) < inodes[key]['nlink']:
            external_hardlinks[key] = inodes[key]['nlink'] - len(group)
    for path, (size, sha) in HISTORICAL_FILES.items():
        row = by_path[path.encode()]
        require(row['kind'] == 'file' and row['bytes'] == size and row['sha256'] == sha, 'Historical Native116 binding changed')
    require(snapshot['logicalBytes'] == logical, 'Logical source total')
    require(snapshot['uniquePayloads'] == len(objects), 'Unique payload count')
    require(snapshot['uniquePayloadBytes'] == sum(x['bytes'] for x in objects.values()), 'Unique payload bytes')
    require(snapshot['hardlinkGroups'] == groups, 'Exact hardlink groups')
    require(snapshot['unresolvedExternalHardlinkCounts'] == external_hardlinks, 'Exact outside-link dependency counts')
    require(snapshot['symlinkEntries'] == links, 'Exact symlink entries')
    return objects


def archive_header(name, size):
    value = tarfile.TarInfo(name)
    value.size = size; value.mode = 0o600; value.uid = value.gid = 0
    value.uname = value.gname = ''; value.mtime = 0
    return value.tobuf(tarfile.USTAR_FORMAT, 'utf-8', 'strict')


def exact_read(stream, amount):
    result = bytearray()
    while len(result) < amount:
        block = stream.read(min(BLOCK, amount - len(result)))
        require(block, 'Truncated deterministic stream')
        result.extend(block)
    return bytes(result)


def verify_tar_gzip(stream, snapshot_body, guard):
    """Parse every USTAR header, payload, padding byte and gzip trailer; extract nothing."""
    snapshot = decode_snapshot(snapshot_body)
    objects = validate_snapshot(snapshot)
    expected = [(METADATA_MEMBER, len(snapshot_body), digest(snapshot_body))]
    expected += [('objects/sha256/' + sha, objects[sha]['bytes'], sha) for sha in sorted(objects)]
    tar_bytes = 0; members = 0; payload_bytes = 0
    with gzip.GzipFile(fileobj=stream, mode='rb') as z:
        for name, size, sha in expected:
            guard()
            header = exact_read(z, 512); tar_bytes += 512
            require(header == archive_header(name, size), 'Exact deterministic USTAR header differs')
            info = tarfile.TarInfo.frombuf(header, 'utf-8', 'strict')
            require(info.name == name and info.isfile() and info.size == size, 'Unexpected archive member/order/size')
            require(info.uid == info.gid == 0 and info.mode == 0o600 and info.mtime == 0, 'Unexpected transport header metadata')
            require(info.uname == info.gname == '' and not info.linkname, 'Unexpected transport link/user metadata')
            h = hashlib.sha256(); remaining = size
            while remaining:
                guard(); block = exact_read(z, min(BLOCK, remaining))
                h.update(block); remaining -= len(block); tar_bytes += len(block)
            require(h.hexdigest() == sha, 'Archive member hash mismatch')
            pad = (-size) % 512
            require(exact_read(z, pad) == b'\0' * pad, 'Nonzero tar member padding')
            tar_bytes += pad; members += 1
            if name != METADATA_MEMBER: payload_bytes += size
        tail = 1024 + (-(tar_bytes + 1024)) % tarfile.RECORDSIZE
        require(exact_read(z, tail) == b'\0' * tail, 'Invalid deterministic tar terminator')
        require(z.read(1) == b'', 'Undeclared tar or concatenated gzip payload')
    require(payload_bytes == snapshot['uniquePayloadBytes'], 'Complete payload total')
    return {'membersVerified': members, 'uniquePayloadsVerified': len(objects),
            'uniquePayloadBytesVerified': payload_bytes, 'originalEntries': len(snapshot['entries']),
            'everyOriginalRegularFileMapsToVerifiedPayload': True,
            'snapshotSHA256': digest(snapshot_body), 'selfContained': False,
            'fullTreeRestorePerformed': False, 'windowsDependenciesVerifiedNow': False}
