#!/usr/bin/env python3
"""Exact retained archive preservation primitives. Imports perform no operation."""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before any filesystem action')
from pathlib import Path
import base64
import datetime
import hashlib
import http.client
import importlib.util
import json
import os
import selectors
import signal
import ssl
import stat
import subprocess
import sys
import time
import types
import urllib.parse
import uuid

SOURCE = Path('/mnt/development/projects/preserved/maktabah-final-delivery-20261126.HEKmdGhG')
RELATIVE_LEAF = 'Maktabah/untracked.tar.gz'
LEAF = 'untracked.tar.gz'
SOURCE_DEVICE = 2064
SOURCE_INODE = 6204847
PARENT_INODE = 6204860
LEAF_INODE = 6204866
ARCHIVE_BYTES = 691303419
ARCHIVE_SHA = 'e7783edfe09c044fb8b13f398604b35011a987970495c47d52a3306a15b8b100'
SNAPSHOT_SHA = '8d1f5356ea716bfcbd1152386e834514802325c75efc857ab8e085bbeb6906c7'
PREFLIGHT_SHA = 'dc80359d614f918aab15a50e2a93918aa0b268a6e7a10794f5bcccb1c413845f'
REPO = 'davidpovarsky/Maktabah-preserved-evidence'
REPO_ID = 1474927804
TAG = 'retained-untracked-e7783edf-20261128-wave3'
MANIFEST_NAME = 'PRESERVED_UNTRACKED_LEAF_MANIFEST.json'
BASE = Path('/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128')
ROOT_FLOOR = 1593835520
DATA_RESTORE_FLOOR = 2147483648
CONTROL_CAP = 4 * 1024**2
TERMINAL_SLOT = 64 * 1024
OVERALL_SECONDS = 2700
BLOCK = 1024**2
SEALED_NAMES = {'leaf_common.py', 'preserve_untracked_leaf.py', 'retire_untracked_leaf.py',
                'restore_untracked_leaf.py', 'SOURCE_SNAPSHOT.json', 'SOURCE_PREFLIGHT_RESULT.json'}
TOOLS = Path(__file__).absolute().parent

def require(value, code):
    if not value:
        raise RuntimeError(code)

def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True) + '\n').encode('ascii')

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

def leaf(name):
    require(type(name) is str and name not in ('', '.', '..') and
            '/' not in name and '\\' not in name and '\0' not in name, 'CLOSED_LEAF_NAME')
    return name

def hex_digest(value, length=64):
    require(type(value) is str and len(value)==length and
            all(c in '0123456789abcdef' for c in value), 'EXACT_HEX_DIGEST')
    return value

def stable_stat(s):
    return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,
            s.st_blocks,s.st_atime_ns,s.st_mtime_ns,s.st_ctime_ns)

def open_directory(path):
    """No component of the fixed absolute path may be a symlink."""
    path = Path(path)
    assert path.is_absolute() and '..' not in path.parts
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise

def process_identity(pid):
    raw = Path('/proc/%d/stat' % pid).read_text()
    fields = raw[raw.rfind(')') + 2:].split()
    assert len(fields) >= 20
    return {'pid': pid, 'pgid': int(fields[2]), 'session': int(fields[3]),
            'startTicks': fields[19]}

def stop_owned(process, original):
    # Never poll/reap before a signal decision. An unreaped Popen leader cannot
    # have its PID reused. Every child was started in its own session/group.
    if process.returncode is not None:
        return
    current = process_identity(process.pid)
    assert current['pgid'] == current['session'] == process.pid
    assert original is None or current == original
    os.killpg(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        current = process_identity(process.pid)
        assert current['pgid'] == current['session'] == process.pid
        assert original is None or current == original
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=20)


# Explicit host-name bindings for the byte-exact reused transfer method.
leaf_name = leaf
owned_process_identity = process_identity

def read_regular(path, maximum=2*BLOCK):
    path=Path(path); parent=open_directory(path.parent)
    fd=None
    try:
        fd=os.open(leaf(path.name),os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME,dir_fd=parent)
        before=os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=maximum,
                'BOUNDED_SINGLE_REGULAR_INPUT')
        b=os.pread(fd,maximum+1,0)
        require(len(b)==before.st_size and stable_stat(os.fstat(fd))==stable_stat(before),
                'INPUT_CHANGED_DURING_READ')
        require(stable_stat(os.stat(path.name,dir_fd=parent,follow_symlinks=False))==stable_stat(before),
                'INPUT_NAME_IDENTITY_CHANGED')
        return b
    finally:
        if fd is not None: os.close(fd)
        os.close(parent)

def verify_seal(expected):
    require(sys.flags.isolated == 1 and sys.flags.dont_write_bytecode == 1,
            'ISOLATED_AND_NO_BYTECODE_REQUIRED')
    require('GH_DEBUG' not in os.environ, 'GH_DEBUG_MUST_BE_ABSENT')
    raw=read_regular(TOOLS/'SOURCE_SEAL.json',65536)
    require(digest(raw)==hex_digest(expected),'SOURCE_SEAL_SHA')
    value=json.loads(raw)
    require(value['schema']=='otzaria.retained-untracked-source-seal/1' and
            set(value['files'])==SEALED_NAMES,'CLOSED_SOURCE_SEAL')
    for name,pin in value['files'].items():
        b=read_regular(TOOLS/name)
        require({'bytes':len(b),'sha256':digest(b)}==pin,'SEALED_INPUT_CHANGED')
    require(value['files']['SOURCE_SNAPSHOT.json']=={'bytes':53140,'sha256':SNAPSHOT_SHA} and
            value['files']['SOURCE_PREFLIGHT_RESULT.json']=={'bytes':1110,'sha256':PREFLIGHT_SHA},
            'PINNED_ORIGINAL_PREFLIGHT')
    return raw,value

def original_snapshot():
    b=read_regular(TOOLS/'SOURCE_SNAPSHOT.json',65536)
    require(len(b)==53140 and digest(b)==SNAPSHOT_SHA,'ORIGINAL_SNAPSHOT')
    s=json.loads(b)
    require(s['schema']=='otzaria.retained-delivery-readonly-preflight/1' and
            s['sourceRoot']==str(SOURCE) and s['sourceUnchanged'] is True,'SNAPSHOT_SCOPE')
    rows=s['entries']
    require(len(rows)==85 and sum(v['kind']=='file' for v in rows.values())==73 and
            sum(v['kind']=='directory' for v in rows.values())==12,'EXACT_85_MEMBERS')
    require(rows[RELATIVE_LEAF]['content']=={'bytes':ARCHIVE_BYTES,'sha256':ARCHIVE_SHA},
            'EXACT_ARCHIVE_PIN')
    for n,row in rows.items():
        require(row['path']==n and row['kind'] in ('file','directory'),'ORIGINAL_ENTRY_SCHEMA')
        require(n=='.' or all(leaf(x)==x for x in n.split('/')),'ORIGINAL_RELATIVE_PATH')
        require(row['metadata']['device']==SOURCE_DEVICE and row['metadata']['xattrs']==[],
                'ORIGINAL_FIXED_METADATA')
        require(all(type(row['metadata'][k]) is str and row['metadata'][k].isdigit()
                    for k in ('atimeNS','mtimeNS','ctimeNS')),'EXACT_NS_STRINGS')
    return b,s

def xattrs_fd(fd):
    rows=[]
    for n in sorted(os.listxattr(fd)):
        v=os.getxattr(fd,n)
        require(len(v)<=BLOCK and len(rows)<128,'BOUNDED_XATTR')
        rows.append([base64.b64encode(os.fsencode(n)).decode(),base64.b64encode(v).decode()])
    require(sum(len(x[1]) for x in rows)<=4*BLOCK,'BOUNDED_TOTAL_XATTR')
    return rows

def metadata_fd(fd):
    s=os.fstat(fd)
    require(stat.S_ISREG(s.st_mode) or stat.S_ISDIR(s.st_mode),'NO_LINK_OR_SPECIAL_SOURCE')
    return {'device':s.st_dev,'inode':s.st_ino,'mode':s.st_mode,'uid':s.st_uid,
            'gid':s.st_gid,'nlink':s.st_nlink,'bytes':s.st_size,'allocatedBytes':s.st_blocks*512,
            'atimeNS':str(s.st_atime_ns),'mtimeNS':str(s.st_mtime_ns),
            'ctimeNS':str(s.st_ctime_ns),'xattrs':xattrs_fd(fd)}

def source_root():
    original=open_directory(SOURCE)
    try:
        fd=os.open('.',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_NOATIME,dir_fd=original)
    finally:os.close(original)
    try:
        s=os.fstat(fd)
        require(stat.S_ISDIR(s.st_mode) and (s.st_dev,s.st_ino,s.st_uid,s.st_gid)==
                (SOURCE_DEVICE,SOURCE_INODE,1001,1002),'PINNED_SOURCE_CONTAINER')
        return fd
    except BaseException:
        os.close(fd);raise

def open_relative(root,relative,directory=False):
    parts=[] if relative=='.' else relative.split('/')
    current=os.dup(root)
    try:
        if not parts: return current
        for i,name in enumerate(parts):
            leaf(name);last=i==len(parts)-1
            flags=os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME
            if not last or directory: flags|=os.O_DIRECTORY
            nxt=os.open(name,flags,dir_fd=current)
            os.close(current);current=nxt
        return current
    except BaseException:
        os.close(current);raise

def hash_fd(fd,rt,expected_bytes):
    h=hashlib.sha256();n=0
    while True:
        rt.guard()
        b=os.pread(fd,BLOCK,n)
        if not b: break
        n+=len(b);require(n<=expected_bytes,'SOURCE_GREW')
        h.update(b)
    require(n==expected_bytes,'SOURCE_SHORT_READ')
    return h.hexdigest()

def source_tree(rt,root,snapshot,present=True,parent_namespace_change=False,extra=(),full=True):
    rows=snapshot['entries'];wanted=set(rows)-({RELATIVE_LEAF} if not present else set())
    require(len(wanted)==(85 if present else 84),'CLOSED_SOURCE_CARDINALITY')
    found=set();observed={}
    stack=['.']
    while stack:
        rt.guard();rel=stack.pop()
        require(rel in wanted and rel not in found,'UNEXPECTED_SOURCE_ENTRY')
        exp=rows[rel];isdir=exp['kind']=='directory'
        fd=open_relative(root,rel,isdir)
        try:
            m=metadata_fd(fd);compare=dict(m);expected=dict(exp['metadata'])
            if parent_namespace_change and rel=='Maktabah':
                # Only unavoidable unlink/link namespace timestamps may differ.
                for k in ('mtimeNS','ctimeNS'): compare.pop(k);expected.pop(k)
            require(compare==expected,'SOURCE_METADATA_CHANGED')
            if isdir:
                names=os.listdir(fd)
                require(len(names)<=128,'FINITE_DIRECTORY_MEMBERSHIP')
                for n in names:
                    leaf(n)
                    child=n if rel=='.' else rel+'/'+n
                    if child in extra: continue
                    stack.append(child)
            else:
                require(m['nlink']==1,'SINGLE_LINK_SOURCE')
                if full:
                    require(hash_fd(fd,rt,m['bytes'])==exp['content']['sha256'],'SOURCE_FULL_HASH_CHANGED')
            require(metadata_fd(fd)==m,'SOURCE_CHANGED_DURING_FULL_READ')
            observed[rel]=m;found.add(rel)
        finally:os.close(fd)
    require(found==wanted,'EXACT_SOURCE_PATHSET_CHANGED')
    fresh=source_root()
    try:
        require((os.fstat(fresh).st_dev,os.fstat(fresh).st_ino)==
                (os.fstat(root).st_dev,os.fstat(root).st_ino),'SOURCE_PATH_FD_JOIN')
    finally:os.close(fresh)
    # No extra is silently accepted: these are exact owned restoration aliases.
    if extra:
        require(len(extra)==1 and extra[0].startswith('Maktabah/.untracked-restore-'),
                'CLOSED_RESTORE_ALIAS')
    return {'entryCount':len(found),'allRegularHashesVerified':full,
            'metadataSHA256':digest(canonical(observed)),
            'immediateParent':observed['Maktabah'],
            'parentNamespaceTimestampsMayDiffer':parent_namespace_change}

def open_candidate(root,snapshot):
    parent=open_relative(root,'Maktabah',True);fd=None
    try:
        require(os.fstat(parent).st_ino==PARENT_INODE,'PINNED_LEAF_PARENT')
        fd=os.open(LEAF,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME,dir_fd=parent)
        require(metadata_fd(fd)==snapshot['entries'][RELATIVE_LEAF]['metadata'],'EXACT_LEAF_IDENTITY')
        require(os.fstat(fd).st_nlink==1,'SINGLE_LINK_LEAF')
        return parent,fd
    except BaseException:
        if fd is not None:os.close(fd)
        os.close(parent);raise

def final_source_name_join(root,parent,fd,snapshot):
    require(metadata_fd(fd)==snapshot['entries'][RELATIVE_LEAF]['metadata'],'FINAL_LEAF_FD')
    named=os.stat(LEAF,dir_fd=parent,follow_symlinks=False)
    require(stable_stat(named)==stable_stat(os.fstat(fd)),'FINAL_SAME_DIRFD_LEAF_JOIN')
    fresh=source_root()
    try:
        require((os.fstat(root).st_dev,os.fstat(root).st_ino)==
                (os.fstat(fresh).st_dev,os.fstat(fresh).st_ino),'FINAL_ROOT_PATH_FD')
        p=open_relative(fresh,'Maktabah',True)
        try:
            require((os.fstat(p).st_dev,os.fstat(p).st_ino)==
                    (os.fstat(parent).st_dev,os.fstat(parent).st_ino)==
                    (SOURCE_DEVICE,PARENT_INODE),'FINAL_PARENT_PATH_FD')
        finally:os.close(p)
    finally:os.close(fresh)

def allocated_tree(path):
    if not os.path.lexists(path):return 0
    total=0;stack=[Path(path)];count=0
    while stack:
        p=stack.pop();s=p.lstat();count+=1
        require(count<=1024 and (stat.S_ISDIR(s.st_mode) or stat.S_ISREG(s.st_mode)) and
                s.st_dev==os.stat('/').st_dev,'CLOSED_ROOTFS_JOURNAL')
        total+=s.st_blocks*512
        if stat.S_ISDIR(s.st_mode):stack.extend(p.iterdir())
    return total

class Runtime:
    """One immutable phase; terminal storage is allocated before source/auth work."""
    def __init__(self,phase):
        require(os.geteuid()==0,'ROOT_EXECUTOR_REQUIRED_FOR_EXACT_PROC_INSPECTION')
        require(phase in ('prepare','publish','retire-prepare','retire-commit') or
                (phase.startswith('restore-') and str(uuid.UUID(phase[8:]))==phase[8:]),
                'CLOSED_PHASE')
        self.started=time.monotonic();self.deadline=self.started+OVERALL_SECONDS
        self.sequence=0;self.phase=phase;self.fd=None;self.terminal_fd=None
        self.path=BASE/phase
        require(self.free()>=ROOT_FLOOR+CONTROL_CAP,'ROOT_ADMISSION_PLUS_METADATA_RESERVE')
        home=open_directory(BASE.parent)
        try:
            if phase=='prepare' or (phase.startswith('restore-') and not os.path.lexists(BASE)):
                os.mkdir(BASE.name,0o700,dir_fd=home);os.chown(BASE,1001,1001)
                os.fsync(home)
            base=open_directory(BASE)
            try:
                s=os.fstat(base)
                require(s.st_dev==os.stat('/').st_dev and s.st_uid==1001 and
                        stat.S_IMODE(s.st_mode)==0o700,'OWNED_FIXED_BASE')
                self.guard(TERMINAL_SLOT+8192)
                os.mkdir(phase,0o700,dir_fd=base);os.chown(self.path,1001,1001)
                os.fsync(base)
                self.fd=os.open(phase,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=base)
            finally:os.close(base)
            self.terminal_fd=os.open('TERMINAL_RESULT.json',os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,
                                     0o600,dir_fd=self.fd)
            os.fchown(self.terminal_fd,1001,1001)
            os.posix_fallocate(self.terminal_fd,0,TERMINAL_SLOT)
            os.fsync(self.terminal_fd);os.fsync(self.fd)
            self.root_before=self.free();self.guard()
        except BaseException:
            self.close();raise
        finally:os.close(home)

    def free(self):
        s=os.statvfs('/home/ubuntu')
        return s.f_bavail*s.f_frsize

    def guard(self,addition=0):
        require(time.monotonic()<self.deadline,'OVERALL_2700_SECOND_DEADLINE')
        require(self.free()-addition>=ROOT_FLOOR,'ROOT_FLOOR')
        require(allocated_tree(BASE)+addition<=CONTROL_CAP,'FOUR_MIB_RUNTIME_METADATA_CAP')

    def write(self,name,value,terminal=False):
        raw=value if isinstance(value,bytes) else canonical(value)
        require(len(raw)<=BLOCK,'BOUNDED_JOURNAL_LEAF')
        self.guard(((len(raw)+4095)//4096)*4096+4096)
        fd=os.open(leaf(name),os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=self.fd)
        try:
            os.fchown(fd,1001,1001)
            view=memoryview(raw)
            while view:
                n=os.write(fd,view);require(n>0,'JOURNAL_SHORT_WRITE');view=view[n:]
            os.fsync(fd)
        finally:os.close(fd)
        os.fsync(self.fd)
        require(read_regular(self.path/name)==raw,'JOURNAL_DURABLE_READBACK')
        return {'path':str(self.path/name),'bytes':len(raw),'sha256':digest(raw)}

    def terminal(self,value):
        raw=canonical(value);require(len(raw)<=TERMINAL_SLOT,'BOUNDED_RESERVED_TERMINAL')
        os.lseek(self.terminal_fd,0,os.SEEK_SET)
        view=memoryview(raw)
        while view:
            n=os.write(self.terminal_fd,view);require(n>0,'TERMINAL_SHORT_WRITE');view=view[n:]
        os.ftruncate(self.terminal_fd,len(raw));os.fsync(self.terminal_fd);os.fsync(self.fd)
        require(read_regular(self.path/'TERMINAL_RESULT.json')==raw,'TERMINAL_READBACK')
        return {'path':str(self.path/'TERMINAL_RESULT.json'),'bytes':len(raw),'sha256':digest(raw)}

    def close(self):
        if self.terminal_fd is not None:
            os.close(self.terminal_fd);self.terminal_fd=None
        if self.fd is not None:
            os.close(self.fd);self.fd=None

    def gh(self, args, label, timeout=60, expected=None, allow_error=False):
        self.guard()
        self.sequence += 1
        label = '%02d-%s' % (self.sequence, leaf(label))
        argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', *args]
        limit = expected['bytes'] if expected else BLOCK
        original = None
        selector = None
        out, err = bytearray(), bytearray()
        h, count = hashlib.sha256(), 0
        code = None
        started = time.monotonic()
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        # Immediate cleanup scope: identity, durable ledger, pipe setup and all
        # later operations are inside this try, including their failures.
        try:
            original = process_identity(process.pid)
            assert original['pgid'] == original['session'] == process.pid
            self.write(label + '.PROCESS.json', {'utc': utc(), 'identity': original, 'argv': argv})
            selector = selectors.DefaultSelector()
            for channel, pipe in [('stdout', process.stdout), ('stderr', process.stderr)]:
                os.set_blocking(pipe.fileno(), False)
                selector.register(pipe.fileno(), selectors.EVENT_READ, channel)
            until = min(started + timeout, self.deadline)
            while selector.get_map():
                self.guard()
                assert time.monotonic() < until, 'Owned process/stream deadline'
                for key, _ in selector.select(timeout=0.25):
                    try:
                        b = os.read(key.fd, BLOCK)
                    except BlockingIOError:
                        continue
                    if not b:
                        selector.unregister(key.fd)
                        continue
                    if key.data == 'stderr':
                        assert len(err) + len(b) <= BLOCK, 'Bounded stderr exceeded'
                        err.extend(b)
                    else:
                        count += len(b)
                        assert count <= limit, 'Bounded stdout/payload exceeded'
                        h.update(b)
                        if expected is None:
                            out.extend(b)
            code = process.wait(timeout=max(0.01, min(20, until - time.monotonic())))
            assert allow_error or code == 0, 'Owned gh command failed; no retry'
            if expected:
                assert code == 0 and count == expected['bytes'] and h.hexdigest() == expected['sha256']
            result = {'exit': code, 'bytes': count, 'sha256': h.hexdigest(),
                      'stderrBytes': len(err), 'seconds': time.monotonic() - started}
            self.write(label + '.RESULT.json', result)
            return (code, bytes(out), bytes(err)) if expected is None else result
        finally:
            try:
                stop_owned(process, original)
            finally:
                if selector is not None:
                    selector.close()
                process.stdout.close()
                process.stderr.close()
                # Bounded original logs are retained; streamed archive bytes
                # never become a second local archive or a tool response.
                try:
                    if self.free() - len(out) - len(err) >= ROOT_FLOOR:
                        self.write(label + '.stdout', bytes(out))
                        self.write(label + '.stderr', bytes(err))
                finally:
                    self.write(label + '.TERMINAL.json', {
                        'utc': utc(), 'pid': process.pid, 'startIdentity': original,
                        'returncode': process.returncode, 'stdoutBytes': count,
                        'stdoutSHA256': h.hexdigest(), 'stderrBytes': len(err),
                        'stderrSHA256': digest(err), 'noAutomaticRetry': True,
                    }, terminal=True)


    def transfer(self, args, label, maximum, expected=None, output_fd=None, data_guard=None, timeout=1200):
        self.guard()
        self.sequence += 1
        label = str(self.sequence).zfill(2) + '-' + leaf_name(label)
        selector = None
        started = time.monotonic()
        start_identity = None
        captured, errors = bytearray(), bytearray()
        h, count = hashlib.sha256(), 0
        argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', *args]
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=True)
        try:
            start_identity = owned_process_identity(process.pid)
            assert start_identity['pgid'] == start_identity['session'] == process.pid
            self.write(label + '.PROCESS.json', {'identity': start_identity, 'argv': argv, 'utc': utc()})
            selector = selectors.DefaultSelector()
            for channel, pipe in [('stdout', process.stdout), ('stderr', process.stderr)]:
                os.set_blocking(pipe.fileno(), False)
                selector.register(pipe.fileno(), selectors.EVENT_READ, channel)
            until = min(started + timeout, self.deadline)
            while selector.get_map():
                self.guard()
                assert time.monotonic() < until, 'Owned authenticated transfer deadline'
                for key, _ in selector.select(timeout=0.25):
                    try:
                        block = os.read(key.fd, 1024 * 1024)
                    except BlockingIOError:
                        continue
                    if not block:
                        selector.unregister(key.fd)
                        continue
                    if key.data == 'stderr':
                        assert len(errors) + len(block) <= 1024 * 1024, 'Bounded stderr exceeded'
                        errors.extend(block)
                        continue
                    count += len(block)
                    assert count <= maximum, 'Unexpected authenticated payload length'
                    h.update(block)
                    if output_fd is not None:
                        if data_guard:
                            data_guard(len(block))
                        else:
                            self.guard(len(block))
                        view = memoryview(block)
                        while view:
                            n = os.write(output_fd, view)
                            assert n > 0
                            view = view[n:]
                    elif expected is None:
                        assert len(captured) + len(block) <= 1024 * 1024
                        captured.extend(block)
            code = process.wait(timeout=max(0.01, min(20, until - time.monotonic())))
            assert code == 0, 'Authenticated transfer failed; no automatic retry'
            if expected:
                assert count == expected['bytes'] and h.hexdigest() == expected['sha256']
            if output_fd is not None:
                os.fsync(output_fd)
            result = {'bytes': count, 'sha256': h.hexdigest(), 'exit': code, 'seconds': time.monotonic() - started}
            self.write(label + '.RESULT.json', result)
            return bytes(captured) if expected is None else result
        finally:
            try:
                stop_owned(process, start_identity)
            finally:
                if selector is not None:
                    selector.close()
                process.stdout.close()
                process.stderr.close()
                try:
                    v = os.fstatvfs(self.fd)
                    if v.f_bavail * v.f_frsize - len(captured) - len(errors) >= ROOT_FLOOR:
                        self.write(label + '.stdout', bytes(captured))
                        self.write(label + '.stderr', bytes(errors))
                finally:
                    self.write(label + '.TERMINAL.json', {'utc': utc(), 'identity': start_identity,
                        'pid': process.pid, 'returncode': process.returncode,
                        'stdoutBytes': count, 'stdoutSHA256': h.hexdigest(),
                        'stderrBytes': len(errors), 'stderrSHA256': digest(errors),
                        'noAutomaticRetry': True}, terminal=True)

    def api(self,endpoint,label,extra=()):
        require(endpoint.startswith('repos/'+REPO) or endpoint.startswith('repos/davidpovarsky/Maktabah/'),
                'CLOSED_GITHUB_REPOSITORY')
        code,raw,_=self.gh(['api','--hostname','github.com',*extra,endpoint],label)
        require(code==0,'AUTHENTICATED_API_FAILURE')
        return json.loads(raw)

R=types.SimpleNamespace(process_identity=process_identity,stop_owned=stop_owned,utc=utc)
def get_private_token(runtime):
    """Never use Runtime.gh here: it deliberately logs command stdout hashes."""
    runtime.guard(); original = None; selector = None; output = bytearray()
    argv = ['sudo', '-u', 'ubuntu', '-H', 'gh', 'auth', 'token', '--hostname', 'github.com']
    process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        original = R.process_identity(process.pid)
        require(original['pgid'] == original['session'] == process.pid, 'Private getter owned identity')
        runtime.write('PRIVATE_TOKEN_GETTER_PROCESS.json', {'utc': R.utc(), 'identity': original,
                      'purpose': 'Existing Oracle authentication; value/length/digest/output intentionally not recorded'})
        selector = selectors.DefaultSelector(); os.set_blocking(process.stdout.fileno(), False)
        selector.register(process.stdout.fileno(), selectors.EVENT_READ)
        until = min(runtime.deadline, time.monotonic() + 20)
        while selector.get_map():
            runtime.guard(); require(time.monotonic() < until, 'Private getter deadline')
            for key, _ in selector.select(0.25):
                try: raw = os.read(key.fd, 4096)
                except BlockingIOError: continue
                if not raw: selector.unregister(key.fd); continue
                require(len(output) + len(raw) <= 8192, 'Private getter bounded output')
                output.extend(raw)
        require(process.wait(timeout=5) == 0, 'Existing Oracle auth getter failed; no login/retry')
        token = bytes(output).strip().decode('ascii', 'strict')
        require(20 <= len(token) <= 4096 and all(33 <= ord(c) <= 126 for c in token), 'Private header value shape')
        return token
    finally:
        try: R.stop_owned(process, original)
        finally:
            if selector is not None: selector.close()
            process.stdout.close()
            output[:] = b'\0' * len(output)
            runtime.write('PRIVATE_TOKEN_GETTER_TERMINAL.json', {'utc': R.utc(), 'pid': process.pid,
                          'identity': original, 'exit': process.returncode,
                          'stdoutPersisted': False, 'stderrPersisted': False}, terminal=True)


class UploadHTTPStatusError(RuntimeError):
    def __init__(self,status):
        self.status=int(status)
        super().__init__('UPLOAD_HTTP_STATUS_REFUSED')

class Upload:
    """One credential-bearing exact-length POST; no redirect, retry or proxy."""
    def __init__(self,runtime,token,release_id,pin,content_type):
        self.runtime,self.pin,self.sent=runtime,pin,0
        require(pin['name'] in (LEAF,MANIFEST_NAME),'CLOSED_ASSET_NAME')
        require(type(release_id) is int and 0<release_id<2**63,'EXACT_RELEASE_ID')
        path='/repos/%s/releases/%d/assets?%s'%(REPO,release_id,urllib.parse.urlencode({'name':pin['name']}))
        context=ssl.create_default_context(cafile='/etc/ssl/certs/ca-certificates.crt')
        context.set_alpn_protocols(['http/1.1'])
        self.connection=http.client.HTTPSConnection('uploads.github.com',443,timeout=20,context=context)
        self.connection.set_debuglevel(0);self.started=time.monotonic()
        try:
            self.connection.connect()
            require(self.connection.sock is not None,'EXPLICIT_VERIFIED_TLS')
            self.connection.putrequest('POST',path,skip_accept_encoding=True)
            self.connection.putheader('Authorization','Bearer '+token)
            self.connection.putheader('User-Agent','OtzariaRetainedLeafPreservation/1')
            self.connection.putheader('Accept','application/vnd.github+json')
            self.connection.putheader('Content-Type',content_type)
            self.connection.putheader('Content-Length',str(pin['bytes']))
            self.connection.putheader('Connection','close')
            self.connection.endheaders(encode_chunked=False)
        except BaseException:
            self.connection.close();raise

    def send(self,b):
        self.runtime.guard()
        require(time.monotonic()-self.started<1200,'UPLOAD_1200_SECOND_DEADLINE')
        require(0<len(b)<=BLOCK and self.sent+len(b)<=self.pin['bytes'],'EXACT_BODY_LENGTH')
        require(self.connection.sock is not None,'NO_UPLOAD_RECONNECTION')
        self.connection.send(b);self.sent+=len(b)

    def finish(self):
        self.runtime.guard();require(self.sent==self.pin['bytes'],'INCOMPLETE_UPLOAD')
        r=self.connection.getresponse()
        if r.status!=201:raise UploadHTTPStatusError(r.status)
        raw=r.read(BLOCK+1);require(len(raw)<=BLOCK,'BOUNDED_UPLOAD_RESPONSE')
        return verify_asset(json.loads(raw),self.pin)

    def close(self):self.connection.close()

def controlled_failure(exc,stage):
    value={'stage':stage,'errorType':type(exc).__name__,'messageSuppressed':True}
    if isinstance(exc,UploadHTTPStatusError):value['httpStatus']=exc.status
    return value

def private_repository(rt,label):
    v=rt.api('repos/'+REPO,label)
    require(type(v['id']) is int and v['id']==REPO_ID and v['full_name']==REPO and
            v['private'] is True and v['archived'] is False and
            v['owner']['login']=='davidpovarsky','EXACT_PRIVATE_REPOSITORY')
    return {'id':REPO_ID,'full_name':REPO,'private':True}

def verify_asset(v,pin):
    require(type(v['id']) is int and 0<v['id']<2**63,'EXACT_ASSET_ID')
    require(v['name']==pin['name'] and v['state']=='uploaded' and v['size']==pin['bytes'],
            'ASSET_NAME_STATE_SIZE')
    require(v.get('digest') in (None,'sha256:'+pin['sha256']),'SERVER_SHA256_IF_PRESENT')
    require(v['url']=='https://api.github.com/repos/%s/releases/assets/%d'%(REPO,v['id']),
            'EXACT_ASSET_API_URL')
    return {'name':pin['name'],'id':v['id'],'bytes':pin['bytes'],'sha256':pin['sha256'],'apiURL':v['url'],'serverDigest':v.get('digest')}

def release_state(rt,rid,assets,label):
    v=rt.api('repos/%s/releases/%d'%(REPO,rid),label)
    require(v['id']==rid and v['tag_name']==TAG and v['draft'] is True and
            v['prerelease'] is False,'EXACT_PRIVATE_DRAFT')
    require(v['url']=='https://api.github.com/repos/%s/releases/%d'%(REPO,rid) and
            v['upload_url']=='https://uploads.github.com/repos/%s/releases/%d/assets{?name,label}'%(REPO,rid),
            'EXACT_RELEASE_URLS')
    require(len(v['assets'])==len(assets) and {x['name'] for x in v['assets']}==set(assets),
            'EXACT_RELEASE_ASSET_SET')
    seen=set()
    for x in v['assets']:
        require(x['id'] not in seen,'DISTINCT_ASSET_IDS');seen.add(x['id'])
        require(verify_asset(x,assets[x['name']])==assets[x['name']],'UNCHANGED_ASSET_IDENTITY')
    return {'id':rid,'tag':TAG,'draft':True,'repositoryID':REPO_ID,'assets':assets}

def full_readback(rt,asset,label,expected_body=None,output_fd=None,data_guard=None):
    # Existing reviewed gh client owns normal authenticated GitHub GET handling.
    # No caller-written signed-location forwarding or bearer-token routing.
    if output_fd is not None:
        raise RuntimeError('USE_ONLY_THE_SEPARATE_FIXED_RESTORE_DOWNLOADER')
    result=rt.gh(['api','--hostname','github.com','-H','Accept: application/octet-stream',
                  'repos/%s/releases/assets/%d'%(REPO,asset['id'])],
                 label,timeout=1200,expected=asset)
    require(result['exit']==0 and result['bytes']==asset['bytes'] and
            result['sha256']==asset['sha256'],'FULL_AUTHENTICATED_BYTES')
    return {'assetID':asset['id'],'name':asset['name'],'bytes':asset['bytes'],
            'sha256':asset['sha256'],'authenticatedFullReadback':True,'exit':0}

def prepared(expected_sha):
    raw=read_regular(BASE/'prepare'/'PREPARED.json')
    require(digest(raw)==hex_digest(expected_sha),'EXACT_PREPARED_RECEIPT')
    v=json.loads(raw)
    require(v['status']=='PREPARED_ORIGINAL_85_ENTRIES_RETAINED' and
            v['snapshotSHA256']==SNAPSHOT_SHA and v['archive']=={'name':LEAF,'bytes':ARCHIVE_BYTES,'sha256':ARCHIVE_SHA},
            'PREPARED_SCOPE')
    m=read_regular(BASE/'prepare'/MANIFEST_NAME)
    require({'path':str(BASE/'prepare'/MANIFEST_NAME),'bytes':len(m),'sha256':digest(m)}==v['manifest'],
            'PREPARED_MANIFEST')
    verify_manifest(m)
    terminal=json.loads(read_regular(BASE/'prepare'/'TERMINAL_RESULT.json'))
    require(terminal['status']=='SUCCEEDED' and terminal['preparedSHA256']==expected_sha,
            'PREPARE_TERMINAL_COMPLETION')
    return raw,v,m

def verify_manifest(raw):
    v=json.loads(raw);original,snapshot=original_snapshot()
    require(v['schema']=='otzaria.retained-untracked-private-leaf/1' and
            v['sourceRoot']==str(SOURCE) and v['relativeLeaf']==RELATIVE_LEAF and
            v['archive']=={'name':LEAF,'bytes':ARCHIVE_BYTES,'sha256':ARCHIVE_SHA},
            'EXACT_MANIFEST_SCOPE')
    require(base64.b64decode(v['sourceSnapshotBase64'],validate=True)==original and
            v['originalLeaf']==snapshot['entries'][RELATIVE_LEAF] and
            v['originalSnapshotSHA256']==SNAPSHOT_SHA,'FULL_ORIGINAL_METADATA')
    require(v['repository']=={'id':REPO_ID,'full_name':REPO,'private':True} and
            v['tag']==TAG and v['selfContainedSourceTree'] is False and
            v['archiveMembersValidated'] is False and v['contentsQualified'] is False,
            'OPAQUE_ARCHIVE_ONLY')
    return v

def bound_transport(binding_path,binding_sha,source_seal_sha):
    return verify_transport_bytes(read_regular(binding_path),binding_sha,source_seal_sha)

def verify_transport_bytes(raw,binding_sha,source_seal_sha,payloads=None):
    require(digest(raw)==hex_digest(binding_sha),'ACTUAL_BINDING_SHA')
    if payloads is not None:
        require(set(payloads)=={'receipt','marker','terminal','manifest'},'CLOSED_EMBEDDED_TRANSPORT_PAYLOADS')
    b=json.loads(raw)
    require(b['schema']=='otzaria.retained-untracked-actual-transport-binding/1' and
            b['sourceSealSHA256']==source_seal_sha and b['repositoryID']==REPO_ID and
            b['archiveSHA256']==ARCHIVE_SHA,'ACTUAL_BINDING_SCOPE')
    out={}
    names={'receipt':'VERIFIED_PRIVATE_PRESERVATION.json','marker':'FINAL_RECEIPT_PUBLISHED.json',
           'terminal':'TERMINAL_RESULT.json'}
    for key,name in names.items():
        data=read_regular(BASE/'publish'/name) if payloads is None else payloads[key]
        require({'bytes':len(data),'sha256':digest(data)}==b[key],'ACTUAL_COMPLETED_PAYLOAD_PIN')
        out[key]=json.loads(data);out[key+'Raw']=data
    rec=out['receipt'];mark=out['marker'];term=out['terminal']
    require(rec['status']=='EXACT_OPAQUE_ARCHIVE_AND_MANIFEST_FULL_READBACK_VERIFIED' and
            rec['repository']=={'id':REPO_ID,'full_name':REPO,'private':True} and
            rec['sourceSealSHA256']==source_seal_sha and rec['sourceUnchanged'] is True and
            rec['originalRetained'] is True and rec['archiveMembersValidated'] is False,'ACTUAL_TRANSPORT_RESULT')
    require(rec['release']['id']==b['releaseID'] and rec['release']['tag']==TAG and rec['release']['draft'] is True,
            'ACTUAL_RELEASE_BINDING')
    assets=rec['release']['assets']
    require(set(assets)=={LEAF,MANIFEST_NAME} and assets[LEAF]['bytes']==ARCHIVE_BYTES and
            assets[LEAF]['sha256']==ARCHIVE_SHA and assets==b['assets'],'ACTUAL_ASSETS')
    require(len(rec['readbacks'])==2,'EXACT_TWO_READBACKS')
    for name,a in assets.items():
        matches=[r for r in rec['readbacks'] if r['name']==name]
        require(len(matches)==1 and matches[0]=={'assetID':a['id'],'name':name,'bytes':a['bytes'],
                'sha256':a['sha256'],'authenticatedFullReadback':True,'exit':0},'FULL_READBACK_BINDING')
    receipt_pin={'path':str(BASE/'publish'/names['receipt']),**b['receipt']}
    require(mark=={'receipt':receipt_pin,'controllerMustExitZero':True,'retirementAuthorized':False},
            'FINAL_PUBLICATION_MARKER')
    require(term['status']=='SUCCEEDED' and term['receipt']==receipt_pin and
            term['marker']=={'path':str(BASE/'publish'/names['marker']),**b['marker']},'PUBLISH_TERMINAL')
    # Root supplies the independently observed real Sentinel terminal, never a guessed job.
    terminal_raw=base64.b64decode(b['actualJob']['base64'],validate=True)
    require(len(terminal_raw)==b['actualJob']['bytes'] and digest(terminal_raw)==b['actualJob']['sha256'],
            'ACTUAL_JOB_RAW_PIN')
    job_doc=json.loads(terminal_raw);job=job_doc['job']
    require(job_doc['ok'] is True and job['host']=='host_299cf75f6b338ecd' and job['tool']=='script_run' and
            job['status']=='succeeded' and type(job['exit_code']) is int and job['exit_code']==0 and
            job['error'] is None and job['output_truncated'] is False,'ACTUAL_OUTER_TERMINAL')
    require(b['actualJob']['id']==job['id'] and job['id'].startswith('job_'),'ACTUAL_JOB_ID')
    require(type(job.get('output')) is str and len(job['output'].encode('utf-8'))<=65536,
            'ACTUAL_JOB_OUTPUT_JSON_BOUND')
    observed_output=json.loads(job['output'])
    expected_output={'receipt':receipt_pin,
                     'marker':{'path':str(BASE/'publish'/names['marker']),**b['marker']},
                     'terminal':{'path':str(BASE/'publish'/names['terminal']),**b['terminal']},
                     'originalRetained':True}
    require(observed_output==expected_output,'ACTUAL_JOB_EXACT_OUTPUT_BINDING')
    manifest=read_regular(BASE/'prepare'/MANIFEST_NAME) if payloads is None else payloads['manifest']
    require(len(manifest)==assets[MANIFEST_NAME]['bytes'] and digest(manifest)==assets[MANIFEST_NAME]['sha256'],
            'BOUND_ORIGINAL_MANIFEST')
    verify_manifest(manifest)
    return b,raw,rec,manifest

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


def verified_durable_git(rt,proof_raw,required):
    """Read only exact published Git objects; no Git executable or repository write."""
    p=json.loads(proof_raw)
    require(p['schema']=='otzaria.retained-untracked-durable-git/1' and
            p['repository']=='davidpovarsky/Maktabah' and
            p['branch']=='codex/otzaria-wave3-integration-20261127','CLOSED_GIT_CHECKPOINT')
    commit=hex_digest(p['commit'],40);repo=p['repository']
    require(type(p['repositoryID']) is int and p['repositoryID']>0 and set(p['files'])==set(required),
            'FULL_GIT_RESTORATION_CLOSURE')
    r=rt.api('repos/'+repo+'/','git-repository')
    require(r['id']==p['repositoryID'] and r['full_name']==repo and r['owner']['login']=='davidpovarsky',
            'EXACT_GIT_REPOSITORY')
    ref=rt.api('repos/'+repo+'/git/ref/heads/'+p['branch'],'git-branch')
    require(ref['object']['type']=='commit' and ref['object']['sha']==commit,'PUBLISHED_GIT_HEAD')
    c=rt.api('repos/'+repo+'/git/commits/'+commit,'git-commit')
    require(c['sha']==commit,'EXACT_GIT_COMMIT')
    tree=hex_digest(c['tree']['sha'],40);cache={};verified=[]
    def tree_entries(oid):
        if oid not in cache:
            v=rt.api('repos/'+repo+'/git/trees/'+hex_digest(oid,40),'git-tree-'+oid[:8])
            require(v['sha']==oid and v.get('truncated') is False and len(v['tree'])<20000,
                    'COMPLETE_FINITE_GIT_TREE')
            require(len({x['path'] for x in v['tree']})==len(v['tree']),'UNIQUE_GIT_TREE_NAMES')
            cache[oid]={leaf(x['path']):x for x in v['tree']}
        return cache[oid]
    for name,raw in sorted(required.items()):
        row=p['files'][name];path=row['path']
        prefix='docs/hq-integration/wave3-retained-untracked-leaf-restoration-20261128/'
        require(path==prefix+leaf(name) and row['bytes']==len(raw) and row['sha256']==digest(raw),
                'EXACT_DURABLE_GIT_PATH_AND_BYTES')
        parts=path.split('/');current=tree
        for part in parts[:-1]:
            e=tree_entries(current)[leaf(part)]
            require(e['type']=='tree' and e['mode']=='040000','GIT_PARENT_TREE')
            current=hex_digest(e['sha'],40)
        e=tree_entries(current)[parts[-1]]
        require(e['type']=='blob' and e['mode'] in ('100644','100755'),'GIT_REGULAR_BLOB')
        oid=hex_digest(e['sha'],40)
        v=rt.api('repos/'+repo+'/git/blobs/'+oid,'git-blob-'+oid[:8])
        require(v['sha']==oid and v['encoding']=='base64' and v['size']==len(raw),'GIT_BLOB_ENVELOPE')
        content=base64.b64decode(''.join(v['content'].split()),validate=True)
        require(content==raw and hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==oid,
                'FULL_REMOTE_GIT_BLOB_READBACK')
        verified.append({'name':name,'path':path,'gitBlob':oid,'bytes':len(raw),'sha256':digest(raw)})
    return {'repository':repo,'repositoryID':p['repositoryID'],'commit':commit,
            'branch':p['branch'],'completeFiles':verified,'fullRemoteBytesReadBack':True}

def restore_metadata(fd,saved):
    os.fchown(fd,saved['uid'],saved['gid'])
    os.fchmod(fd,stat.S_IMODE(saved['mode']))
    require(not os.listxattr(fd),'RESTORE_EXCLUSIVE_NEW_XATTRS')
    for n,v in saved['xattrs']:
        os.setxattr(fd,base64.b64decode(n,validate=True),base64.b64decode(v,validate=True))
    os.utime(fd,ns=(int(saved['atimeNS']),int(saved['mtimeNS'])))
    os.fsync(fd)
    m=metadata_fd(fd)
    require(all(m[k]==saved[k] for k in ('mode','uid','gid','bytes','atimeNS','mtimeNS','xattrs')),
            'FULL_RESTORABLE_LEAF_METADATA')
    return m
