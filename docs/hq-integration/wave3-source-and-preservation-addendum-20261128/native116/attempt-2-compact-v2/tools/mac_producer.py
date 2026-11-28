"""Fixed Native116 read-only producer. Runs only inside the reviewed SSH bootstrap."""
if not __debug__:
    raise RuntimeError('Optimized Python is refused')

import base64
import ctypes
import datetime
import errno
import gzip
import hashlib
import io
import json
import os
import platform
import posixpath
import pwd
import signal
import stat
import struct
import sys
import tarfile
import time
import zlib

from stream_format import (
    SOURCE_ROOT, SOURCE_DEVICE, SOURCE_INODE, ARCHIVE_CAP, SNAPSHOT_CAP,
    MAX_ENTRIES, MAX_LOGICAL_BYTES, BLOCK, METADATA_MEMBER, HISTORICAL_FILES,
    require, canonical, digest, b64, unb64, relative_bytes, stable_row,
    encode_snapshot, decode_snapshot, validate_snapshot, compact_row,
)

MAC_RESERVE = 2415919104
MAX_XATTR = 2 * 1024**2
ROOT_FD = None
STARTED = time.monotonic()
DEADLINE = STARTED + 1200
ORIGINAL_PARENT_PID = os.getppid()
FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
require(sys.platform == 'darwin' and ctypes.sizeof(ctypes.c_void_p) == 8,
        'Qualified 64-bit Darwin native ABI required')
# Installed Apple SDK header, independently read by Root after the actual
# Python3.9 import refusal. Python need not export every native open(2) flag.
NATIVE_FCNTL_HEADER = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.0.sdk/usr/include/sys/fcntl.h'
NATIVE_FCNTL_HEADER_BYTES = 27609
NATIVE_FCNTL_HEADER_SHA256 = '9aca8ca87031ab7b670617e5af8b15a0cad8f34f7ab3bdb5dd799eb153b3ad0e'
SYMLINK_FLAG = 0x00200000
PYTHON_SYMLINK_FLAG = getattr(os, 'O_SYMLINK', None)
require(PYTHON_SYMLINK_FLAG is None or
        (type(PYTHON_SYMLINK_FLAG) is int and PYTHON_SYMLINK_FLAG == SYMLINK_FLAG),
        'Python/native O_SYMLINK ABI disagreement')


def guard():
    require(time.monotonic() < DEADLINE, 'Original owned producer deadline')
    require(os.getppid() == ORIGINAL_PARENT_PID, 'Original SSH parent detached')
    v = os.statvfs('/System/Volumes/Data')
    require(v.f_bavail * v.f_frsize >= MAC_RESERVE, 'Unchanged Mac live reserve unavailable')


def expired(_signal, _frame):
    raise RuntimeError('Owned producer 1200-second alarm')


def identity(s):
    return (s.st_dev, s.st_ino, s.st_mode, s.st_uid, s.st_gid, s.st_nlink,
            s.st_size, str(s.st_mtime_ns), str(s.st_ctime_ns), s.st_flags, s.st_rdev)


def open_parts(start_fd, parts):
    current = os.dup(start_fd)
    try:
        for part in parts:
            guard()
            child = os.open(part, FLAGS, dir_fd=current)
            os.close(current); current = child
            require(os.fstat(current).st_dev == SOURCE_DEVICE, 'Cross-device descendant refused')
        return current
    except BaseException:
        os.close(current)
        raise


def open_root():
    current = os.open('/', FLAGS)
    try:
        for part in SOURCE_ROOT.strip('/').split('/'):
            guard()
            child = os.open(part, FLAGS, dir_fd=current)
            os.close(current); current = child
        s = os.fstat(current)
        require(s.st_dev == SOURCE_DEVICE and s.st_ino == SOURCE_INODE, 'Exact Native116 root changed')
        require(stat.S_ISDIR(s.st_mode) and s.st_uid == 501 and s.st_gid == 20, 'Exact root owner/type')
        return current
    except BaseException:
        os.close(current)
        raise


class AttrList(ctypes.Structure):
    _fields_ = [('count', ctypes.c_uint16), ('reserved', ctypes.c_uint16),
                ('common', ctypes.c_uint32), ('vol', ctypes.c_uint32),
                ('directory', ctypes.c_uint32), ('file', ctypes.c_uint32), ('fork', ctypes.c_uint32)]


LIB = ctypes.CDLL(None, use_errno=True)
LIB.openat.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
LIB.openat.restype = ctypes.c_int
LIB.flistxattr.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
LIB.flistxattr.restype = ctypes.c_ssize_t
LIB.fgetxattr.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
LIB.fgetxattr.restype = ctypes.c_ssize_t
LIB.acl_get_fd_np.argtypes = [ctypes.c_int, ctypes.c_int]
LIB.acl_get_fd_np.restype = ctypes.c_void_p
LIB.acl_to_text.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ssize_t)]
LIB.acl_to_text.restype = ctypes.c_void_p
LIB.acl_free.argtypes = [ctypes.c_void_p]
LIB.acl_free.restype = ctypes.c_int
LIB.fgetattrlist.argtypes = [ctypes.c_int, ctypes.POINTER(AttrList), ctypes.c_void_p, ctypes.c_size_t, ctypes.c_ulong]
LIB.fgetattrlist.restype = ctypes.c_int


def qualify_native_metadata_abi():
    # This small read qualifies the same installed header for every producer
    # launch. It grants no access to source data and never writes SDK files.
    fd = os.open(NATIVE_FCNTL_HEADER, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_size == NATIVE_FCNTL_HEADER_BYTES,
                'Installed native header type/size changed')
        raw = bytearray()
        while len(raw) <= NATIVE_FCNTL_HEADER_BYTES:
            block = os.read(fd, NATIVE_FCNTL_HEADER_BYTES + 1 - len(raw))
            if not block: break
            raw.extend(block)
        require(len(raw) == NATIVE_FCNTL_HEADER_BYTES and
                digest(raw) == NATIVE_FCNTL_HEADER_SHA256,
                'Installed native header byte identity changed')
        definitions = [line.split()[:3] for line in bytes(raw).splitlines()
                       if line.split()[:2] == [b'#define', b'O_SYMLINK']]
        require(definitions == [[b'#define', b'O_SYMLINK', b'0x00200000']],
                'Installed O_SYMLINK definition changed')
        require(identity(os.fstat(fd)) == identity(before) and
                identity(os.stat(NATIVE_FCNTL_HEADER, follow_symlinks=False)) == identity(before),
                'Installed native header replaced during qualification')
    finally:
        os.close(fd)
    return {'headerPath': NATIVE_FCNTL_HEADER, 'headerBytes': NATIVE_FCNTL_HEADER_BYTES,
            'headerSHA256': NATIVE_FCNTL_HEADER_SHA256, 'symlinkFlag': SYMLINK_FLAG,
            'pythonExposesSymlinkFlag': PYTHON_SYMLINK_FLAG is not None,
            'metadataOpen': 'native libc openat with pinned parent and single final component'}


NATIVE_METADATA_ABI = qualify_native_metadata_abi()


def extended_metadata(parent_fd, name, before):
    # Darwin O_SYMLINK opens the link itself. Ordinary entries use O_NOFOLLOW.
    # Every native metadata call consumes this verified descriptor directly;
    # there is no /dev/fd path spelling or re-resolution of a source ancestor.
    flags = os.O_RDONLY | (SYMLINK_FLAG if stat.S_ISLNK(before.st_mode) else os.O_NOFOLLOW)
    if stat.S_ISDIR(before.st_mode): flags |= os.O_DIRECTORY
    raw_name = os.fsencode(name)
    require(raw_name and raw_name != b'..' and b'/' not in raw_name and b'\0' not in raw_name,
            'Native metadata open requires one exact final component')
    fd = LIB.openat(parent_fd, raw_name, flags)
    if fd < 0: raise OSError(ctypes.get_errno(), 'Native metadata openat failed')
    try:
        os.set_inheritable(fd, False)
        require(identity(os.fstat(fd)) == identity(before), 'Metadata descriptor identity mismatch')
        value = descriptor_metadata(fd, before)
        require(identity(os.fstat(fd)) == identity(before), 'Metadata descriptor changed')
        require(identity(os.stat(name, dir_fd=parent_fd, follow_symlinks=False)) == identity(before),
                'Metadata source name replaced')
        return value
    finally:
        os.close(fd)


def descriptor_metadata(fd, before):
    options = 0x0020  # XATTR_SHOWCOMPRESSION; fd already identifies the link itself.
    size = LIB.flistxattr(fd, None, 0, options)
    require(0 <= size <= MAX_XATTR, 'xattr name list unavailable/over bound')
    names = ctypes.create_string_buffer(max(1, size))
    require(LIB.flistxattr(fd, names, size, options) == size, 'xattr names changed')
    attributes = []
    for attribute in sorted(x for x in names.raw[:size].split(b'\0') if x):
        guard(); n = LIB.fgetxattr(fd, attribute, None, 0, 0, options)
        require(0 <= n <= MAX_XATTR, 'xattr payload unavailable/over bound')
        value = ctypes.create_string_buffer(max(1, n))
        require(LIB.fgetxattr(fd, attribute, value, n, 0, options) == n, 'xattr changed')
        raw = value.raw[:n]
        attributes.append({'nameBase64': b64(attribute), 'valueBase64': b64(raw),
                           'bytes': n, 'sha256': digest(raw)})
    ctypes.set_errno(0)
    acl = LIB.acl_get_fd_np(fd, 0x00000100)
    acl_value = None
    if not acl:
        require(ctypes.get_errno() == errno.ENOENT, 'ACL inspection failed')
    else:
        length = ctypes.c_ssize_t()
        text = LIB.acl_to_text(acl, ctypes.byref(length))
        try:
            require(text and 0 <= length.value <= MAX_XATTR, 'ACL text unavailable/over bound')
            raw = ctypes.string_at(text, length.value)
            acl_value = {'textBase64': b64(raw), 'bytes': len(raw), 'sha256': digest(raw)}
        finally:
            if text: LIB.acl_free(text)
            LIB.acl_free(acl)
    attrs = AttrList(5, 0, 0x00000200, 0, 0, 0, 0)
    output = ctypes.create_string_buffer(64)
    require(LIB.fgetattrlist(fd, ctypes.byref(attrs), output, 64, 0) == 0, 'Exact birthtime unavailable')
    require(struct.unpack_from('=I', output.raw, 0)[0] == 20, 'Birthtime layout mismatch')
    seconds, ns = struct.unpack_from('=qq', output.raw, 4)
    require(0 <= ns < 10**9 and abs(seconds - int(before.st_birthtime)) <= 1, 'Birthtime check')
    return {'xattrs': attributes, 'acl': acl_value, 'birthtimeNS': str(seconds * 10**9 + ns)}


def record(parent_fd, name, relative, before, full):
    guard()
    kind = 'file' if stat.S_ISREG(before.st_mode) else 'directory' if stat.S_ISDIR(before.st_mode) else 'symlink'
    require(stat.S_ISREG(before.st_mode) or stat.S_ISDIR(before.st_mode) or stat.S_ISLNK(before.st_mode), 'Unsupported special source entry')
    require(before.st_dev == SOURCE_DEVICE, 'Cross-device source entry')
    metadata = extended_metadata(parent_fd, name, before)
    row = {'pathBase64': b64(relative), 'kind': kind, 'device': before.st_dev,
           'inode': before.st_ino, 'mode': before.st_mode, 'uid': before.st_uid,
           'gid': before.st_gid, 'nlink': before.st_nlink, 'bytes': before.st_size,
           'allocatedBytes': before.st_blocks * 512, 'mtimeNS': str(before.st_mtime_ns),
           'ctimeNS': str(before.st_ctime_ns), 'atimeNS': str(before.st_atime_ns),
           'flags': before.st_flags, 'rdev': before.st_rdev, **metadata}
    if kind == 'file' and full:
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_fd)
        try:
            require(identity(os.fstat(fd)) == identity(before), 'File replaced before read')
            h, count = hashlib.sha256(), 0
            while True:
                guard(); block = os.read(fd, BLOCK)
                if not block: break
                count += len(block); require(count <= before.st_size, 'Source grew during hash'); h.update(block)
            require(count == before.st_size and identity(os.fstat(fd)) == identity(before), 'File changed during hash')
            row['sha256'] = h.hexdigest()
        finally:
            os.close(fd)
    elif kind == 'symlink':
        row['targetBase64'] = b64(os.fsencode(os.readlink(name, dir_fd=parent_fd)))
    require(identity(os.stat(name, dir_fd=parent_fd, follow_symlinks=False)) == identity(before), 'Source path identity changed')
    require(extended_metadata(parent_fd, name, before) == metadata, 'Source extended metadata changed')
    return row


def enumerate_source(full):
    fresh = open_root()
    try: require(identity(os.fstat(fresh)) == identity(os.fstat(ROOT_FD)), 'Root path replaced')
    finally: os.close(fresh)
    pending = [b'']; rows = []; metadata_bytes = 0; logical = 0
    while pending:
        guard(); relative = pending.pop()
        require(len(rows) < MAX_ENTRIES, 'Entry cap')
        parent = open_parts(ROOT_FD, relative.split(b'/')[:-1] if relative else [])
        try:
            name = relative.split(b'/')[-1] if relative else b'.'
            before = os.stat(name, dir_fd=parent, follow_symlinks=False)
            row = record(parent, name, relative, before, full)
            metadata_bytes += len(canonical(compact_row(row, full=full)))
            require(metadata_bytes <= SNAPSHOT_CAP, 'Compact metadata cap')
            if row['kind'] == 'file':
                logical += row['bytes']; require(logical <= MAX_LOGICAL_BYTES, 'Logical source cap')
            rows.append(row)
            if row['kind'] == 'directory':
                child = os.open(name, FLAGS, dir_fd=parent)
                try:
                    require(identity(os.fstat(child)) == identity(before), 'Directory changed before enumeration')
                    names = sorted((os.fsencode(x) for x in os.listdir(child)), reverse=True)
                    require(len(names) + len(rows) + len(pending) <= MAX_ENTRIES, 'Directory entry cap')
                    pending.extend(relative + b'/' + x if relative else x for x in names)
                    require(identity(os.fstat(child)) == identity(before), 'Directory changed during enumeration')
                finally: os.close(child)
        finally: os.close(parent)
    return sorted(rows, key=relative_bytes)


def fingerprint(tool_hashes):
    def module_sha(module):
        with open(module.__file__, 'rb') as f: raw = f.read(1024**2 + 1)
        require(len(raw) <= 1024**2, 'Compressor module full-hash byte bound')
        return digest(raw)
    return {'python': sys.version, 'executable': sys.executable, 'machine': platform.machine(),
            'zlibCompileVersion': zlib.ZLIB_VERSION, 'zlibRuntimeVersion': zlib.ZLIB_RUNTIME_VERSION,
            'gzipModuleSHA256': module_sha(gzip), 'tarfileModuleSHA256': module_sha(tarfile),
            'toolHashes': tool_hashes, 'nativeMetadataABI': NATIVE_METADATA_ABI}


def compare_rows(expected, actual, full):
    require(len(expected) == len(actual), 'Source path count changed')
    for old, new in zip(expected, actual):
        left, right = stable_row(old), stable_row(new)
        if not full: left.pop('sha256', None)
        require(left == right, 'Captured source metadata/content changed')


def capture(tool_hashes):
    rows = enumerate_source(True)
    compare_rows(rows, enumerate_source(False), False)
    objects, groups, links, references, inodes = {}, {}, [], [], {}
    for row in rows:
        path = relative_bytes(row)
        if row['kind'] == 'file':
            objects.setdefault(row['sha256'], row)
            if posixpath.basename(path) == b'.git' or path.endswith(b'/objects/info/alternates'):
                references.append({'kind': 'opaque-original-git-reference-file', 'pathBase64': row['pathBase64'],
                                   'bytes': row['bytes'], 'sha256': row['sha256'], 'resolvedOrFollowed': False})
        elif row['kind'] == 'symlink':
            links.append(row['pathBase64'])
            target = unb64(row['targetBase64'])
            lexical = posixpath.normpath(target if target.startswith(b'/') else os.fsencode(SOURCE_ROOT) + b'/' + posixpath.dirname(path) + b'/' + target)
            references.append({'kind': 'original-symlink', 'pathBase64': row['pathBase64'],
                               'targetBase64': row['targetBase64'], 'lexicalTargetBase64': b64(lexical),
                               'lexicallyInsideRoot': lexical == os.fsencode(SOURCE_ROOT) or lexical.startswith(os.fsencode(SOURCE_ROOT) + b'/'),
                               'resolvedOrFollowed': False})
        if row['kind'] != 'directory' and row['nlink'] > 1:
            key = str(row['device']) + ':' + str(row['inode'])
            groups.setdefault(key, []).append(row['pathBase64'])
            inodes[key] = row
    outside_links = {k: inodes[k]['nlink'] - len(v) for k, v in groups.items()
                     if inodes[k]['nlink'] > len(v)}
    value = {'schema': 'otzaria.native116-stream-snapshot/1', 'sourceRoot': SOURCE_ROOT,
             'rootDevice': SOURCE_DEVICE, 'rootInode': SOURCE_INODE,
             'capturedUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
             'runtime': fingerprint(tool_hashes), 'entries': rows,
             'logicalBytes': sum(x['bytes'] for x in rows if x['kind'] == 'file'),
             'uniquePayloads': len(objects), 'uniquePayloadBytes': sum(x['bytes'] for x in objects.values()),
             'hardlinkGroups': groups, 'symlinkEntries': links, 'dependencyReferences': references,
             'unresolvedExternalHardlinkCounts': outside_links,
             'historicalWindowsReferences': {k: {'bytes': v[0], 'sha256': v[1]} for k, v in HISTORICAL_FILES.items() if 'relocation' in k},
             'selfContained': False, 'fullTreeRestorePerformed': False,
             'externalReferencesVerifiedNow': False, 'windowsDependenciesVerifiedNow': False,
             'metadataOmissions': [], 'specialFilesOmitted': False,
             'physicalExtentOrCloneTopologyPreserved': False,
             'unsupportedTypesPolicy': 'Refuse special/cross-device entries or any unavailable/over-budget metadata; omit nothing.'}
    validate_snapshot(value)
    return value


class CountedWriter:
    def __init__(self, output): self.output, self.count, self.sha = output, 0, hashlib.sha256()
    def write(self, raw):
        guard(); require(self.count + len(raw) <= ARCHIVE_CAP, 'Single-asset conservative compressed cap')
        result = self.output.write(raw)
        require(result == len(raw), 'Short archive pipe write')
        self.count += len(raw); self.sha.update(raw)
        return result
    def flush(self): self.output.flush()


class FileBody:
    def __init__(self, fd, expected): self.fd, self.expected, self.count, self.sha = fd, expected, 0, hashlib.sha256()
    def read(self, size):
        guard(); require(0 <= size <= BLOCK, 'Bounded tar source read')
        result = bytearray()
        while len(result) < size:
            guard(); block = os.read(self.fd, size - len(result))
            require(block, 'Truncated source file while producing tar')
            result.extend(block)
        raw = bytes(result); self.count += len(raw); self.sha.update(raw)
        require(self.count <= self.expected['bytes'], 'Source grew during archive')
        return raw


def tar_info(name, size):
    value = tarfile.TarInfo(name); value.size = size; value.mode = 0o600
    value.uid = value.gid = 0; value.uname = value.gname = ''; value.mtime = 0
    return value


def stream(snapshot_body, tool_hashes):
    snapshot = decode_snapshot(snapshot_body)
    require(snapshot['runtime'] == fingerprint(tool_hashes), 'Producer/interpreter/compressor changed')
    compare_rows(snapshot['entries'], enumerate_source(True), True)
    objects = validate_snapshot(snapshot); output = CountedWriter(sys.stdout.buffer)
    with gzip.GzipFile(filename='', fileobj=output, mode='wb', mtime=0, compresslevel=6) as z:
        with tarfile.open(fileobj=z, mode='w|', format=tarfile.USTAR_FORMAT) as archive:
            archive.addfile(tar_info(METADATA_MEMBER, len(snapshot_body)), io.BytesIO(snapshot_body))
            for sha in sorted(objects):
                row = objects[sha]; relative = relative_bytes(row); parts = relative.split(b'/')
                parent = open_parts(ROOT_FD, parts[:-1]); fd = None
                try:
                    before = os.stat(parts[-1], dir_fd=parent, follow_symlinks=False)
                    fresh = record(parent, parts[-1], relative, before, False)
                    compare_rows([row], [fresh], False)
                    fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
                    require(identity(os.fstat(fd)) == identity(before), 'Archive file replaced')
                    body = FileBody(fd, row)
                    archive.addfile(tar_info('objects/sha256/' + sha, row['bytes']), body)
                    require(body.count == row['bytes'] and body.sha.hexdigest() == sha, 'Archive source content mismatch')
                    require(identity(os.fstat(fd)) == identity(before), 'Archive source changed during read')
                finally:
                    if fd is not None: os.close(fd)
                    os.close(parent)
    output.flush()
    # The Oracle sender withholds the final archive tail until this full fence
    # and the owned SSH producer's terminal status have been accepted.
    compare_rows(snapshot['entries'], enumerate_source(True), True)
    require(snapshot['runtime'] == fingerprint(tool_hashes), 'Runtime changed after archive')
    return {'archiveBytes': output.count, 'archiveSHA256': output.sha.hexdigest(),
            'snapshotSHA256': digest(snapshot_body), 'fullSourceBeforeAndAfter': True}


def main(request):
    global ROOT_FD
    require(platform.system() == 'Darwin' and pwd.getpwuid(os.getuid()).pw_name == 'm1', 'Exact Mac account required')
    require(request['mode'] in ('snapshot', 'stream', 'reverify'), 'Closed producer mode')
    signal.signal(signal.SIGALRM, expired); signal.setitimer(signal.ITIMER_REAL, 1200)
    result = {'schema': 'otzaria.native116-owned-producer-terminal/1', 'mode': request['mode'],
              'pid': os.getpid(), 'sourceRoot': SOURCE_ROOT, 'sourceModified': False}
    try:
        guard(); ROOT_FD = open_root()
        if request['mode'] == 'snapshot':
            body = encode_snapshot(capture(request['toolHashes']))
            sys.stdout.buffer.write(body); sys.stdout.buffer.flush()
            result.update(snapshotBytes=len(body), snapshotSHA256=digest(body))
        else:
            body = unb64(request['snapshotBase64']); require(digest(body) == request['snapshotSHA256'], 'Pinned snapshot input')
            if request['mode'] == 'stream': result.update(stream(body, request['toolHashes']))
            else:
                value = decode_snapshot(body)
                require(value['runtime'] == fingerprint(request['toolHashes']), 'Producer runtime changed')
                compare_rows(value['entries'], enumerate_source(True), True)
                result.update(snapshotSHA256=digest(body), fullCurrentSourceEqual=True)
        result.update(status='SOURCE_VERIFIED_READ_ONLY', elapsedSeconds=time.monotonic() - STARTED)
        sys.stderr.write(json.dumps(result, separators=(',', ':')) + '\n'); sys.stderr.flush()
    except BaseException as error:
        result.update(status='FAILED_SOURCE_NOT_ACCEPTED', errorType=type(error).__name__, error=str(error)[:500])
        sys.stderr.write(json.dumps(result, separators=(',', ':')) + '\n'); sys.stderr.flush()
        raise
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        if ROOT_FD is not None: os.close(ROOT_FD)


# No automatic main. The reviewed nonsecret stdin bootstrap invokes main only
# after checking the embedded source hashes and the closed request envelope.
