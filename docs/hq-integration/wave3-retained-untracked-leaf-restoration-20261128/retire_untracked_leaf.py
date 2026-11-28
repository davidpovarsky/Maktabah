#!/usr/bin/env python3
"""Prepare or commit retirement of exactly one already-preserved opaque leaf."""
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


def closure_review(h,path,expected):
    raw=h.read_regular(path,65536);h.require(h.digest(raw)==h.hex_digest(expected),'ROOT_CLOSURE_REVIEW_PIN')
    v=json.loads(raw)
    h.require(v['schema']=='otzaria.retained-untracked-root-closure/1' and
              v['sourceRoot']==str(h.SOURCE) and v['relativeLeaf']==h.RELATIVE_LEAF and
              v['snapshotSHA256']==h.SNAPSHOT_SHA and v['archiveSHA256']==h.ARCHIVE_SHA and
              v['retainedRootOwnedArtifact'] is True and v['localConsumersRequireArchive'] is False and
              v['sourceWriterExclusion'] is True and v['protectedEntries']==84 and
              type(v['evidence']) is list and 0<len(v['evidence'])<=32,
              'EXACT_ROOT_OWNERSHIP_AND_DEPENDENCY_REVIEW_REQUIRED')
    return raw,v

def prepare(h,rt,args,seal_raw):
    b,braw,rec,manifest=h.bound_transport(args.binding,args.binding_sha256,args.source_seal_sha256)
    closure_raw,closure=closure_review(h,args.closure,args.closure_sha256)
    _,snapshot=h.original_snapshot();root=parent=fd=None
    try:
        h.private_repository(rt,'retire-prepare-private-repository')
        remote=h.release_state(rt,rec['release']['id'],rec['release']['assets'],'retire-prepare-assets')
        root=h.source_root();full=h.source_tree(rt,root,snapshot)
        parent,fd=h.open_candidate(root,snapshot)
        no_use=h.no_use({'device':h.SOURCE_DEVICE,'inode':h.LEAF_INODE},{fd})
        h.final_source_name_join(root,parent,fd,snapshot)
        files={}
        for name in sorted(h.SEALED_NAMES|{'SOURCE_SEAL.json'}):
            files[name]=rt.write(name,h.read_regular(h.TOOLS/name))
        files['ACTUAL_TRANSPORT_BINDING.json']=rt.write('ACTUAL_TRANSPORT_BINDING.json',braw)
        files['CLOSURE_REVIEW.json']=rt.write('CLOSURE_REVIEW.json',closure_raw)
        files[h.MANIFEST_NAME]=rt.write(h.MANIFEST_NAME,manifest)
        for label,name in [('receipt','TRANSPORT_RECEIPT.json'),('marker','PUBLISH_MARKER.json'),
                           ('terminal','PUBLISH_TERMINAL.json')]:
            actual={'receipt':'VERIFIED_PRIVATE_PRESERVATION.json','marker':'FINAL_RECEIPT_PUBLISHED.json',
                    'terminal':'TERMINAL_RESULT.json'}[label]
            files[name]=rt.write(name,h.read_regular(h.BASE/'publish'/actual))
        files['ACTUAL_PUBLISH_JOB.json']=rt.write('ACTUAL_PUBLISH_JOB.json',
                                                 base64.b64decode(b['actualJob']['base64'],validate=True))
        pointer={'schema':'otzaria.retained-untracked-restoration-pointer/1',
            'sourceRoot':str(h.SOURCE),'relativeLeaf':h.RELATIVE_LEAF,
            'archive':rec['release']['assets'][h.LEAF],'release':rec['release'],
            'repository':rec['repository'],'sourceSealSHA256':args.source_seal_sha256,
            'bindingSHA256':args.binding_sha256,'bindingBase64':base64.b64encode(braw).decode(),
            'receiptBase64':base64.b64encode(h.read_regular(h.BASE/'publish'/'VERIFIED_PRIVATE_PRESERVATION.json')).decode(),
            'publicationBase64':base64.b64encode(h.read_regular(h.BASE/'publish'/'FINAL_RECEIPT_PUBLISHED.json')).decode(),
            'publishTerminalBase64':base64.b64encode(h.read_regular(h.BASE/'publish'/'TERMINAL_RESULT.json')).decode(),
            'manifestBase64':base64.b64encode(manifest).decode(),
            'originalSnapshotSHA256':h.SNAPSHOT_SHA,
            'originalLeafMetadata':snapshot['entries'][h.RELATIVE_LEAF]['metadata'],
            'restoreScriptSHA256':files['restore_untracked_leaf.py']['sha256'],
            'helperSHA256':files['leaf_common.py']['sha256'],
            'parentIdentity':snapshot['entries']['Maktabah']['metadata'],
            'protectedEntries':84,'archiveMembersValidated':False,'sourceTreeRestored':False,
            'selfContainedSourceTree':False,
            'restoration':'Download only this immutable asset to an exclusive temporary sibling, verify all raw bytes, restore mode/uid/gid/atime/mtime/xattrs, then publish the one absent archive leaf. Do not extract the archive.',
            'metadataLimits':'Original inode/ctime are evidence and cannot be recreated; parent namespace timestamps necessarily change on unlink/restore. No non-target content, identity, mode or xattr mutation is permitted.'}
        files['RESTORATION_POINTER.json']=rt.write('RESTORATION_POINTER.json',pointer)
        h.verify_seal(args.source_seal_sha256)
        pre={'schema':'otzaria.retained-untracked-predelete/1','status':'PREPARED_ORIGINAL_RETAINED',
            'sourceRoot':str(h.SOURCE),'relativeLeaf':h.RELATIVE_LEAF,
            'snapshotSHA256':h.SNAPSHOT_SHA,'archiveSHA256':h.ARCHIVE_SHA,
            'sourceSealSHA256':args.source_seal_sha256,'bindingSHA256':args.binding_sha256,
            'closureSHA256':args.closure_sha256,'files':files,'sourceVerification':full,
            'noUse':no_use,'remoteIdentity':remote,'protectedEntries':84,
            'onlyAllowedNamespaceTimestampException':'Maktabah: mtimeNS and ctimeNS after sole leaf unlink',
            'removed':False,'requiredBeforeCommit':'Root independently publishes every exact prepared file plus this PREDELETE in Git, reads them back, and acknowledges the exact PREDELETE digest.'}
        pin=rt.write('PREDELETE.json',pre)
        terminal=rt.terminal({'status':'SUCCEEDED','phase':'retire-prepare','predelete':pin,'removed':False})
        print(json.dumps({'predelete':pin,'pointer':files['RESTORATION_POINTER.json'],'terminal':terminal,'removed':False}))
    finally:
        for x in (fd,parent,root):
            if x is not None:os.close(x)

def commit(h,rt,args,seal_raw):
    removed=False;root=parent=fd=None;before_free=None
    try:
        base=h.BASE/'retire-prepare'
        pre_raw=h.read_regular(base/'PREDELETE.json')
        h.require(h.digest(pre_raw)==h.hex_digest(args.ack_predelete_sha256),'EXACT_PREDELETE_ACK')
        pre=json.loads(pre_raw)
        h.require(pre['schema']=='otzaria.retained-untracked-predelete/1' and
                  pre['status']=='PREPARED_ORIGINAL_RETAINED' and pre['sourceRoot']==str(h.SOURCE) and
                  pre['relativeLeaf']==h.RELATIVE_LEAF and pre['snapshotSHA256']==h.SNAPSHOT_SHA and
                  pre['archiveSHA256']==h.ARCHIVE_SHA and pre['sourceSealSHA256']==args.source_seal_sha256 and
                  pre['bindingSHA256']==args.binding_sha256 and pre['closureSHA256']==args.closure_sha256,
                  'EXACT_PREDELETE_SCOPE')
        terminal=json.loads(h.read_regular(base/'TERMINAL_RESULT.json'))
        h.require(terminal['status']=='SUCCEEDED' and terminal['phase']=='retire-prepare' and
                  terminal['predelete']=={'path':str(base/'PREDELETE.json'),'bytes':len(pre_raw),
                                         'sha256':args.ack_predelete_sha256},'RETIRE_PREPARE_COMPLETED')
        b,braw,rec,manifest=h.bound_transport(args.binding,args.binding_sha256,args.source_seal_sha256)
        closure_raw,closure=closure_review(h,args.closure,args.closure_sha256)
        required={}
        expected_names=h.SEALED_NAMES|{'SOURCE_SEAL.json','ACTUAL_TRANSPORT_BINDING.json','CLOSURE_REVIEW.json',
            h.MANIFEST_NAME,'TRANSPORT_RECEIPT.json','PUBLISH_MARKER.json','PUBLISH_TERMINAL.json',
            'ACTUAL_PUBLISH_JOB.json','RESTORATION_POINTER.json'}
        h.require(set(pre['files'])==expected_names,'CLOSED_FULL_RESTORATION_FILE_SET')
        for name,pin in pre['files'].items():
            raw=h.read_regular(base/name)
            h.require(pin=={'path':str(base/name),'bytes':len(raw),'sha256':h.digest(raw)},
                      'PREPARED_FILE_FULL_REJOIN')
            required[name]=raw
        required['PREDELETE.json']=pre_raw
        h.require(required['ACTUAL_TRANSPORT_BINDING.json']==braw and
                  required['CLOSURE_REVIEW.json']==closure_raw and required[h.MANIFEST_NAME]==manifest,
                  'SAME_BOUND_CLOSURE_AND_TRANSPORT')
        for name in h.SEALED_NAMES|{'SOURCE_SEAL.json'}:
            h.require(required[name]==h.read_regular(h.TOOLS/name),'CURRENT_SOURCE_EQUALS_DURABLE_SOURCE')
        pointer=json.loads(required['RESTORATION_POINTER.json'])
        h.require(pointer['bindingSHA256']==args.binding_sha256 and
                  base64.b64decode(pointer['bindingBase64'],validate=True)==braw and
                  base64.b64decode(pointer['manifestBase64'],validate=True)==manifest and
                  pointer['sourceSealSHA256']==args.source_seal_sha256,'POINTER_SAME_ACTUAL_BINDING')
        git_raw=h.read_regular(args.git_proof)
        h.require(h.digest(git_raw)==h.hex_digest(args.git_proof_sha256),'ROOT_DURABLE_GIT_PROOF_PIN')
        rt.phase='FULL_DURABLE_GIT_READBACK'
        git=h.verified_durable_git(rt,git_raw,required)
        rt.write('DURABLE_GIT_READBACK.json',git);rt.write('GIT_PROOF.json',git_raw)
        h.private_repository(rt,'commit-private-repository')
        remote=h.release_state(rt,rec['release']['id'],rec['release']['assets'],'commit-immutable-private-assets')
        _,snapshot=h.original_snapshot();root=h.source_root()
        rt.phase='FRESH_FULL_85_SOURCE_HASHES'
        full=h.source_tree(rt,root,snapshot)
        h.require(full==pre['sourceVerification'],'FRESH_EXACT_ALL_85_SOURCE')
        parent,fd=h.open_candidate(root,snapshot)
        before_free=os.fstatvfs(parent).f_bavail*os.fstatvfs(parent).f_frsize
        rt.phase='FINAL_NO_USE'
        use=h.no_use({'device':h.SOURCE_DEVICE,'inode':h.LEAF_INODE},{fd})
        rt.write('PREUNLINK_REVALIDATED.json',{'utc':h.utc(),'ackPREDELETE':args.ack_predelete_sha256,
            'sourceVerification':full,'noUse':use,'freshRemoteIdentity':remote,
            'durableGitCommit':git['commit'],'freeBefore':before_free,'soleLeaf':str(h.SOURCE/h.RELATIVE_LEAF)})
        rt.phase='EXACT_ONE_LEAF_UNLINK'
        # No process, network or callback after the final complete metadata and FD joins.
        current=h.source_tree(rt,root,snapshot,full=False)
        h.require(current['metadataSHA256']==full['metadataSHA256'],'IMMEDIATE_FULL_METADATA_FENCE')
        h.final_source_name_join(root,parent,fd,snapshot)
        os.unlink(h.LEAF,dir_fd=parent);removed=True
        os.fsync(parent);os.close(fd);fd=None
        after=h.source_tree(rt,root,snapshot,present=False,parent_namespace_change=True)
        after_free=os.fstatvfs(parent).f_bavail*os.fstatvfs(parent).f_frsize
        result={'status':'ONE_EXACT_PRIVATELY_PRESERVED_UNTRACKED_ARCHIVE_RETIRED','utc':h.utc(),
            'removed':True,'solePath':str(h.SOURCE/h.RELATIVE_LEAF),'oldMetadata':snapshot['entries'][h.RELATIVE_LEAF]['metadata'],
            'archiveSHA256':h.ARCHIVE_SHA,'ackPREDELETE':args.ack_predelete_sha256,
            'sourceSealSHA256':args.source_seal_sha256,'bindingSHA256':args.binding_sha256,
            'durableGitCommit':git['commit'],'privateFullReadbackReceiptSHA256':b['receipt']['sha256'],
            'protectedEntries':84,'allOtherBytesIdentitiesModesXattrsRetained':True,
            'parentBefore':snapshot['entries']['Maktabah']['metadata'],'parentAfter':after['immediateParent'],
            'soleExpectedParentEffect':'mtimeNS/ctimeNS namespace timestamps',
            'postSourceVerification':after,'freeBefore':before_free,'freeAfter':after_free,
            'capacityClaim':'Observed concurrent volume delta only; no guaranteed attributable reclaim or compiler admission.',
            'archiveExtracted':False,'sourceTreeRestored':False}
        pin=rt.write('RETIREMENT_RESULT.json',result)
        terminal=rt.terminal({'status':'SUCCEEDED','phase':'retire-commit','removed':True,'receipt':pin})
        print(json.dumps({'receipt':pin,'terminal':terminal,'removed':True}))
    except BaseException as exc:
        if parent is not None:
            try:os.fsync(parent)
            except BaseException:pass
        rt.terminal({'status':'FAILED_WITH_EXACT_PARTIAL_STATE_PRESERVED','utc':h.utc(),
            **h.controlled_failure(exc,rt.phase),'removed':removed,'solePath':str(h.SOURCE/h.RELATIVE_LEAF),
            'freeBefore':before_free,'noOtherRemovalAttempted':True})
        raise RuntimeError('Retirement failed or refused; exact partial state retained') from None
    finally:
        for x in (fd,parent,root):
            if x is not None:os.close(x)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase',choices=('prepare','commit'))
    p.add_argument('--source-seal-sha256',required=True)
    p.add_argument('--binding',type=Path,required=True);p.add_argument('--binding-sha256',required=True)
    p.add_argument('--closure',type=Path,required=True);p.add_argument('--closure-sha256',required=True)
    p.add_argument('--ack-predelete-sha256');p.add_argument('--git-proof',type=Path);p.add_argument('--git-proof-sha256')
    a=p.parse_args();h=load_common();seal,_=h.verify_seal(a.source_seal_sha256)
    h.require((a.phase=='commit')==all(v is not None for v in
               (a.ack_predelete_sha256,a.git_proof,a.git_proof_sha256)),'EXACT_COMMIT_ARGUMENTS')
    if a.phase=='prepare':
        h.require(all(v is None for v in (a.ack_predelete_sha256,a.git_proof,a.git_proof_sha256)),
                  'PREPARE_HAS_NO_COMMIT_AUTHORITY')
    h.bound_transport(a.binding,a.binding_sha256,a.source_seal_sha256)
    closure_review(h,a.closure,a.closure_sha256)
    rt=None
    try:
        rt=h.Runtime('retire-'+a.phase);rt.write('SOURCE_SEAL_CURRENT.json',seal)
        if a.phase=='prepare':prepare(h,rt,a,seal)
        else:commit(h,rt,a,seal)
    except BaseException as exc:
        if rt is not None and a.phase=='prepare':
            rt.terminal({'status':'FAILED_ORIGINAL_RETAINED','phase':rt.phase,
                         **h.controlled_failure(exc,rt.phase),'removed':False})
        raise RuntimeError('One-leaf retirement phase failed or refused; inspect exact phase journal') from None
    finally:
        if rt is not None:rt.close()

if __name__=='__main__':
    main()
