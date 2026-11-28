#!/usr/bin/env python3
"""Restore only the exact absent archive leaf; never extract its contents."""
if not __debug__:
    raise RuntimeError('Optimized Python is refused before any filesystem action')
from pathlib import Path
import argparse
import base64
import hashlib
import importlib.util
import json
import os
import stat
import sys
import uuid

HELPER_SHA = 'a9bfb63bfd5538b51450051ddd8a0260d4396d856d6f4b9a64d255216b63afa7'
def load_common():
    p=Path(__file__).absolute().with_name('leaf_common.py')
    fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
    try:
        s=os.fstat(fd)
        if not stat.S_ISREG(s.st_mode) or s.st_nlink!=1 or s.st_size>131072:
            raise RuntimeError('PINNED_HELPER_SHAPE')
        b=os.pread(fd,131073,0)
        if len(b)!=s.st_size or hashlib.sha256(b).hexdigest()!=HELPER_SHA:
            raise RuntimeError('PINNED_HELPER_BYTES')
        t=os.fstat(fd)
        if (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)!=(t.st_dev,t.st_ino,t.st_size,t.st_mtime_ns,t.st_ctime_ns):
            raise RuntimeError('PINNED_HELPER_CHANGED')
    finally:os.close(fd)
    m=importlib.util.module_from_spec(importlib.util.spec_from_loader('retained_leaf_common',loader=None))
    m.__file__=str(p)
    exec(compile(b,str(p),'exec'),m.__dict__)
    return m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--restore-one-leaf',action='store_true',required=True)
    p.add_argument('--source-seal-sha256',required=True)
    p.add_argument('--pointer',type=Path,required=True);p.add_argument('--pointer-sha256',required=True)
    p.add_argument('--attempt',required=True)
    a=p.parse_args();h=load_common();h.verify_seal(a.source_seal_sha256)
    h.require(str(uuid.UUID(a.attempt))==a.attempt,'FRESH_CANONICAL_RESTORE_UUID')
    raw=h.read_regular(a.pointer);h.require(h.digest(raw)==h.hex_digest(a.pointer_sha256),'DURABLE_POINTER_SHA')
    ptr=json.loads(raw)
    h.require(ptr['schema']=='otzaria.retained-untracked-restoration-pointer/1' and
              ptr['sourceRoot']==str(h.SOURCE) and ptr['relativeLeaf']==h.RELATIVE_LEAF and
              ptr['sourceSealSHA256']==a.source_seal_sha256 and ptr['originalSnapshotSHA256']==h.SNAPSHOT_SHA and
              ptr['helperSHA256']==HELPER_SHA and
              ptr['restoreScriptSHA256']==h.digest(h.read_regular(Path(__file__))),
              'EXACT_RESTORATION_POINTER_SCOPE')
    braw=base64.b64decode(ptr['bindingBase64'],validate=True)
    payloads={'receipt':base64.b64decode(ptr['receiptBase64'],validate=True),
              'marker':base64.b64decode(ptr['publicationBase64'],validate=True),
              'terminal':base64.b64decode(ptr['publishTerminalBase64'],validate=True),
              'manifest':base64.b64decode(ptr['manifestBase64'],validate=True)}
    b,_,rec,manifest=h.verify_transport_bytes(braw,ptr['bindingSHA256'],a.source_seal_sha256,payloads)
    h.require(ptr['archive']==rec['release']['assets'][h.LEAF] and ptr['release']==rec['release'] and
              ptr['repository']==rec['repository'] and ptr['protectedEntries']==84,
              'RESTORE_SAME_IMMUTABLE_PRIVATE_ASSET')
    _,snapshot=h.original_snapshot()
    saved=snapshot['entries'][h.RELATIVE_LEAF]['metadata']
    h.require(ptr['originalLeafMetadata']==saved and ptr['parentIdentity']==snapshot['entries']['Maktabah']['metadata'],
              'FULL_ORIGINAL_RESTORE_METADATA')
    rt=None;root=parent=fd=None;linked=False;temporary='.untracked-restore-'+a.attempt+'.partial'
    try:
        rt=h.Runtime('restore-'+a.attempt)
        rt.write('POINTER.json',raw)
        h.private_repository(rt,'restore-private-repository')
        h.release_state(rt,rec['release']['id'],rec['release']['assets'],'restore-exact-assets')
        root=h.source_root()
        before=h.source_tree(rt,root,snapshot,present=False,parent_namespace_change=True)
        parent=h.open_relative(root,'Maktabah',True)
        h.require(os.fstat(parent).st_ino==h.PARENT_INODE,'RESTORE_FIXED_PARENT')
        v=os.fstatvfs(parent)
        h.require(v.f_bavail*v.f_frsize>=h.DATA_RESTORE_FLOOR+h.ARCHIVE_BYTES+h.BLOCK,
                  'DATA_RESTORE_FULL_PAYLOAD_PLUS_FLOOR')
        fd=os.open(temporary,os.O_RDWR|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW|os.O_NOATIME,
                   0o600,dir_fd=parent)
        os.fsync(parent)
        def data_guard(amount):
            rt.guard()
            v=os.fstatvfs(parent)
            h.require(v.f_bavail*v.f_frsize-amount>=h.DATA_RESTORE_FLOOR,'LIVE_DATA_RESTORE_FLOOR')
        asset=rec['release']['assets'][h.LEAF]
        transfer=rt.transfer(['api','--hostname','github.com','-H','Accept: application/octet-stream',
                             'repos/%s/releases/assets/%d'%(h.REPO,asset['id'])],
                            'whole-archive-restore',h.ARCHIVE_BYTES,expected=asset,output_fd=fd,data_guard=data_guard)
        h.require(h.hash_fd(fd,rt,h.ARCHIVE_BYTES)==h.ARCHIVE_SHA,'RESTORE_FULL_DISK_READBACK')
        h.source_tree(rt,root,snapshot,present=False,parent_namespace_change=True,
                      extra=('Maktabah/'+temporary,))
        h.restore_metadata(fd,saved)
        current=h.metadata_fd(fd)
        h.require(h.stable_stat(os.stat(temporary,dir_fd=parent,follow_symlinks=False))==
                  h.stable_stat(os.fstat(fd)),'OWNED_PARTIAL_NAME_IDENTITY')
        # Exclusive link cannot replace an existing archive. Only own alias is removed.
        os.link(temporary,h.LEAF,src_dir_fd=parent,dst_dir_fd=parent,follow_symlinks=False)
        linked=True;os.fsync(parent)
        h.require(os.stat(h.LEAF,dir_fd=parent,follow_symlinks=False).st_ino==os.fstat(fd).st_ino and
                  os.stat(temporary,dir_fd=parent,follow_symlinks=False).st_ino==os.fstat(fd).st_ino,
                  'PUBLISHED_AND_PARTIAL_SAME_INODE')
        os.unlink(temporary,dir_fd=parent);os.fsync(parent)
        final=h.metadata_fd(fd);h.require(final['nlink']==1,'FINAL_SINGLE_LINK_ARCHIVE')
        h.require(all(final[k]==saved[k] for k in ('mode','uid','gid','bytes','atimeNS','mtimeNS','xattrs')),
                  'EXACT_RESTORABLE_METADATA_AFTER_PUBLICATION')
        restored=json.loads(h.canonical(snapshot))
        restored['entries'][h.RELATIVE_LEAF]['metadata']=final
        after=h.source_tree(rt,root,restored,present=True,parent_namespace_change=True)
        proof={'status':'EXACT_OPAQUE_LEAF_RESTORED_NO_EXTRACTION','utc':h.utc(),'pointerSHA256':a.pointer_sha256,
            'archive':str(h.SOURCE/h.RELATIVE_LEAF),'archiveSHA256':h.ARCHIVE_SHA,'transfer':transfer,
            'originalMetadata':saved,'newIdentity':final,'originalInodeCtimeNotRestorable':True,
            'protectedEntries':84,'allOtherBytesIdentitiesModesXattrsRetained':True,
            'immediateParentBefore':before['immediateParent'],'immediateParentAfter':after['immediateParent'],
            'sourceTreeRestored':False,'archiveContentsQualified':False,'archiveExtracted':False}
        result=rt.write('RESTORED.json',proof)
        terminal=rt.terminal({'status':'SUCCEEDED','phase':'restore','receipt':result})
        print(json.dumps({'receipt':result,'terminal':terminal}))
    except BaseException as exc:
        if parent is not None:
            try:os.fsync(parent)
            except BaseException:pass
        if rt is not None:
            rt.terminal({'status':'FAILED_WITH_OWNED_PARTIAL_OR_FINAL_PRESERVED',
                **h.controlled_failure(exc,rt.phase),'partialName':temporary,'finalLinkPublished':linked,
                'noOtherSourceMutation':True})
        raise RuntimeError('One-leaf restore failed or refused; partial evidence retained') from None
    finally:
        for x in (fd,parent,root):
            if x is not None:os.close(x)
        if rt is not None:rt.close()

if __name__=='__main__':
    main()
