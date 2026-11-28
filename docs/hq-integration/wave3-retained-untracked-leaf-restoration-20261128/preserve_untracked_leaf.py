#!/usr/bin/env python3
"""Prepare or publish one exact existing opaque archive. Neither command retires source."""
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


def upload_fd(h,rt,token,rid,pin,fd):
    before=h.metadata_fd(fd)
    h.require(before['bytes']==pin['bytes'],'EXACT_UPLOAD_FD_SIZE')
    rt.write('UPLOAD_STARTED-'+pin['name']+'.json',{'utc':h.utc(),'releaseID':rid,'asset':pin,
        'automaticRetries':0,'redirects':0,'existingArchiveRegenerated':False})
    u=None
    try:
        u=h.Upload(rt,token,rid,pin,'application/gzip' if pin['name']==h.LEAF else 'application/json')
        n=0;sha=hashlib.sha256()
        while n<pin['bytes']:
            rt.guard();b=os.pread(fd,min(h.BLOCK,pin['bytes']-n),n)
            h.require(bool(b),'EXISTING_ARCHIVE_SHORT_READ')
            n+=len(b);sha.update(b);u.send(b)
        h.require(os.pread(fd,1,n)==b'' and sha.hexdigest()==pin['sha256'] and
                  h.metadata_fd(fd)==before,'COMPLETE_UPLOAD_SOURCE_FENCE')
        asset=u.finish()
        rt.write('UPLOADED-'+pin['name']+'.json',asset)
        return asset
    finally:
        if u is not None:u.close()

def prepare(h,rt,seal_sha,seal_raw):
    raw,snapshot=h.original_snapshot();root=h.source_root()
    try:
        rt.phase='PREPARE_FULL_CURRENT_85'
        proof=h.source_tree(rt,root,snapshot)
        rt.write('SOURCE_REVERIFIED.json',proof)
        manifest={'schema':'otzaria.retained-untracked-private-leaf/1',
            'sourceRoot':str(h.SOURCE),'relativeLeaf':h.RELATIVE_LEAF,
            'archive':{'name':h.LEAF,'bytes':h.ARCHIVE_BYTES,'sha256':h.ARCHIVE_SHA},
            'originalLeaf':snapshot['entries'][h.RELATIVE_LEAF],
            'sourceSnapshotBase64':base64.b64encode(raw).decode(),
            'originalSnapshotSHA256':h.SNAPSHOT_SHA,'originalPreflightResultSHA256':h.PREFLIGHT_SHA,
            'repository':{'id':h.REPO_ID,'full_name':h.REPO,'private':True},'tag':h.TAG,
            'sourceSealSHA256':seal_sha,'protectedEntriesRetainedLocally':84,
            'otherEntriesPayloadsUploaded':False,'archiveMembersValidated':False,
            'contentsQualified':False,'selfContainedSourceTree':False,'sourceTreeRestored':False,
            'closureEstablishedByThisTransport':False,
            'scope':'Exact opaque retained November 26 archive bytes and captured metadata only. No archive extraction, source-tree recovery, SDK/app/native qualification, or disposal eligibility is inferred.'}
        body=h.canonical(manifest);h.verify_manifest(body)
        m=rt.write(h.MANIFEST_NAME,body)
        h.verify_seal(seal_sha)
        result={'status':'PREPARED_ORIGINAL_85_ENTRIES_RETAINED','utc':h.utc(),
            'sourceSealSHA256':seal_sha,'snapshotSHA256':h.SNAPSHOT_SHA,'manifest':m,
            'archive':manifest['archive'],'sourceVerification':proof,
            'sourceUnchanged':True,'APIRequests':0,'localRetirement':False}
        pin=rt.write('PREPARED.json',result)
        terminal=rt.terminal({'status':'SUCCEEDED','phase':'prepare','preparedSHA256':pin['sha256'],
                             'sourceUnchanged':True,'retirementAuthorized':False})
        print(json.dumps({'prepared':pin,'terminal':terminal,'sourceUnchanged':True}))
    finally:os.close(root)

def publish(h,rt,args,seal_raw):
    token=None;root=parent=archive=None
    try:
        _,prep,manifest=h.prepared(args.prepared_sha256)
        h.require(prep['sourceSealSHA256']==args.source_seal_sha256,'SAME_PREPARED_SOURCE_SEAL')
        _,snapshot=h.original_snapshot()
        rt.phase='PUBLISH_FULL_SOURCE_PREFLIGHT';root=h.source_root()
        before=h.source_tree(rt,root,snapshot);parent,archive=h.open_candidate(root,snapshot)
        rt.write('FULL_SOURCE_BEFORE.json',before)
        repo=h.private_repository(rt,'private-repository')
        rt.phase='DRAFT_COMPLETE_ABSENCE'
        ended=False
        for page in range(1,11):
            values=rt.api('repos/%s/releases?per_page=100&page=%d'%(h.REPO,page),'release-list-%d'%page)
            h.require(type(values) is list and len(values)<=100,'BOUNDED_RELEASE_LIST')
            h.require(all(v['tag_name']!=h.TAG for v in values),'DRAFT_TAG_ALREADY_EXISTS_NO_RETRY')
            if len(values)<100:ended=True;break
        h.require(ended,'COMPLETE_RELEASE_LIST_REQUIRED')
        request=rt.write('DRAFT_REQUEST.json',{'tag_name':h.TAG,'draft':True,'prerelease':False,
            'name':'Exact retained untracked archive e7783edf',
            'body':'Private raw preservation only. Exact existing 691303419-byte November 26 retained archive. No unpacked source-tree restore or qualification claim. Original 84 surrounding entries remain protected. No automatic local retirement.'})
        rt.write('DRAFT_CREATE_STARTED.json',{'utc':h.utc(),'tag':h.TAG,'repositoryID':h.REPO_ID})
        rt.phase='SINGLE_DRAFT_CREATE'
        created=rt.api('repos/'+h.REPO+'/releases','create-one-draft',
                       ['--method','POST','--input',request['path']])
        h.require(type(created['id']) is int and 0<created['id']<2**63,'NEW_RELEASE_ID')
        rid=created['id'];assets={}
        h.release_state(rt,rid,assets,'new-private-draft-empty')
        rt.write('DRAFT_CREATED.json',{'releaseID':rid,'tag':h.TAG,'repository':repo})
        rt.phase='EXISTING_PRIVATE_TOKEN_GETTER';token=h.get_private_token(rt)
        manifest_pin={'name':h.MANIFEST_NAME,'bytes':len(manifest),'sha256':h.digest(manifest)}
        mf=os.open(h.BASE/'prepare'/h.MANIFEST_NAME,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME)
        try:
            h.require(h.hash_fd(mf,rt,len(manifest))==manifest_pin['sha256'],'MANIFEST_PRE_POST_FENCE')
            rt.phase='SINGLE_MANIFEST_POST'
            assets[h.MANIFEST_NAME]=upload_fd(h,rt,token,rid,manifest_pin,mf)
        finally:os.close(mf)
        h.release_state(rt,rid,assets,'before-one-archive-post')
        h.final_source_name_join(root,parent,archive,snapshot)
        rt.phase='SINGLE_EXISTING_ARCHIVE_POST'
        assets[h.LEAF]=upload_fd(h,rt,token,rid,
                                {'name':h.LEAF,'bytes':h.ARCHIVE_BYTES,'sha256':h.ARCHIVE_SHA},archive)
        token=None
        h.release_state(rt,rid,assets,'after-two-posts')
        rt.phase='FULL_AUTHENTICATED_READBACKS'
        readbacks=[h.full_readback(rt,assets[n],'full-readback-'+str(assets[n]['id']))
                   for n in (h.MANIFEST_NAME,h.LEAF)]
        for row in readbacks:rt.write('READBACK-'+str(row['assetID'])+'.json',row)
        rt.phase='FINAL_FULL_SOURCE_AND_REMOTE'
        after=h.source_tree(rt,root,snapshot)
        h.require(after==before,'FULL_85_SOURCE_REJOIN')
        h.final_source_name_join(root,parent,archive,snapshot)
        h.private_repository(rt,'final-private-repository')
        remote=h.release_state(rt,rid,assets,'final-exact-private-draft')
        h.prepared(args.prepared_sha256);h.verify_seal(args.source_seal_sha256)
        proof={'status':'EXACT_OPAQUE_ARCHIVE_AND_MANIFEST_FULL_READBACK_VERIFIED','utc':h.utc(),
            'sourceSealSHA256':args.source_seal_sha256,'preparedSHA256':args.prepared_sha256,
            'repository':repo,'release':remote,'readbacks':readbacks,
            'sourceUnchanged':True,'sourceVerification':after,'originalRetained':True,
            'protectedEntries':84,'archiveMembersValidated':False,'contentsQualified':False,
            'sourceTreeRestored':False,'selfContainedSourceTree':False,
            'retirementAuthorized':False,'rootFreeBefore':rt.root_before,'rootFreeAfter':rt.free()}
        receipt=rt.write('VERIFIED_PRIVATE_PRESERVATION.json',proof)
        marker=rt.write('FINAL_RECEIPT_PUBLISHED.json',{'receipt':receipt,'controllerMustExitZero':True,
                                                     'retirementAuthorized':False})
        terminal=rt.terminal({'status':'SUCCEEDED','phase':'publish','receipt':receipt,'marker':marker,
                             'originalRetained':True})
        print(json.dumps({'receipt':receipt,'marker':marker,'terminal':terminal,'originalRetained':True}))
    finally:
        token=None
        for fd in (archive,parent,root):
            if fd is not None:os.close(fd)

def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('phase',choices=('prepare','publish'))
    a.add_argument('--source-seal-sha256',required=True)
    a.add_argument('--prepared-sha256')
    args=a.parse_args();h=load_common()
    seal_raw,_=h.verify_seal(args.source_seal_sha256)
    h.require((args.phase=='publish')==(args.prepared_sha256 is not None),'EXACT_PHASE_ARGUMENTS')
    rt=None
    try:
        rt=h.Runtime(args.phase);rt.write('SOURCE_SEAL.json',seal_raw)
        if args.phase=='prepare':prepare(h,rt,args.source_seal_sha256,seal_raw)
        else:publish(h,rt,args,seal_raw)
    except BaseException as exc:
        if rt is not None:
            rt.terminal({'status':'FAILED_OR_INCOMPLETE_ORIGINAL_RETAINED','utc':h.utc(),
                **h.controlled_failure(exc,rt.phase),'partialRemoteAssetsRetained':True,
                'automaticRetry':False,'sourceRemovalAttempted':False})
        raise RuntimeError('Preservation refused or failed; inspect bounded nonsecret phase evidence') from None
    finally:
        if rt is not None:rt.close()

if __name__=='__main__':
    main()
