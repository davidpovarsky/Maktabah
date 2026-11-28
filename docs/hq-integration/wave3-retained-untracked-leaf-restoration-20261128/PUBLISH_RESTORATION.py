import os,pathlib,json,hashlib,stat,subprocess,base64,datetime,shutil,time
os.umask(0o077)
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
PREP=pathlib.Path('/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-20261128/retire-prepare')
BIND=pathlib.Path('/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-root-binding-20261128')
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-retained-untracked-leaf-git-intake-20261128')
REL='docs/hq-integration/wave3-retained-untracked-leaf-restoration-20261128'
DEST=ROOT/REL
BEFORE='07b08a287a03e571da4fcbf4f3149e58b1730960'
SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
PRE_SHA='bd1a444ff3b7fe334f1e7a12e92a719d4dfb532cd0eacbd9531f2dca4e811f19'
SEAL='b3fb30020b2bafffd741829e78974f1fa088e20c70d5291d8d35648463ab0e1e'
FLOOR=1593835520
started=time.monotonic();commands=[]
def need(v,m):
 if not v:raise RuntimeError(m)
def sha(b):return hashlib.sha256(b).hexdigest()
def canon(v):return(json.dumps(v,sort_keys=True,indent=2,ensure_ascii=True)+'\n').encode('ascii')
def free(p='/home/ubuntu'):
 s=os.statvfs(p);return s.f_bavail*s.f_frsize
def stable(s):return(s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,pin=None):
 need(p.resolve(strict=True)==p,'Exact no-alias input path')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME)
 try:
  s=os.fstat(fd);need(stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size<=2097152,'Bounded single-link input')
  b=os.pread(fd,2097153,0)
  need(len(b)==s.st_size and stable(os.fstat(fd))==stable(s) and stable(p.lstat())==stable(s),'Stable complete source bytes')
  if pin:need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Exact reviewed source pin')
  return b
 finally:os.close(fd)
def guard():
 need(time.monotonic()-started<900,'Bounded documentation publication')
 need(free()>=FLOOR+8388608,'Original Root reserve plus documentation allowance')
def cmd(argv,binary=False):
 guard()
 env=os.environ.copy();env['GIT_OPTIONAL_LOCKS']='0'
 p=subprocess.run(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90,env=env)
 need(len(p.stdout)<=2097152 and len(p.stderr)<=65536,'Bounded fixed-command output')
 row={'argv':argv,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row);need(p.returncode==0,'Fixed publication command failed')
 return p.stdout
def git(*args,binary=False):
 return cmd(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','core.fsmonitor=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','-C',str(ROOT),*args],binary)
def api(endpoint):
 return json.loads(cmd(['sudo','-u','ubuntu','-H','gh','api','--hostname','github.com',endpoint],True))
def write(p,b):
 guard();need(len(b)<=2097152,'Bounded documentation leaf')
 stack=[];q=p.parent
 while not q.exists():stack.append(q);q=q.parent
 for d in reversed(stack):
  d.mkdir(mode=0o750);os.chown(d,1001,1001)
  parent=os.open(d.parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
  try:os.fsync(parent)
  finally:os.close(parent)
 fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o640)
 try:
  os.fchown(fd,1001,1001);v=memoryview(b)
  while v:
   n=os.write(fd,v);need(n>0,'Complete documentation write');v=v[n:]
  os.fsync(fd)
 finally:os.close(fd)
 parent=os.open(p.parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
 try:os.fsync(parent)
 finally:os.close(parent)
 need(read(p)==b,'Exact durable written bytes')
need(os.geteuid()==0 and 'GH_DEBUG' not in os.environ and not any(k.startswith('GIT_TRACE') or k=='GIT_CURL_VERBOSE' for k in os.environ),'Root non-debug executor')
need(free()>=FLOOR+16777216,'Complete documentation allowance')
need(not os.path.lexists(OUT) and not os.path.lexists(DEST),'Fresh exact documentation scope')
pre_raw=read(PREP/'PREDELETE.json',{'bytes':7049,'sha256':PRE_SHA});pre=json.loads(pre_raw)
need(pre['status']=='PREPARED_ORIGINAL_RETAINED' and pre['removed'] is False and pre['sourceSealSHA256']==SEAL,'Actual retirement preparation only')
need(pre['sourceVerification']['entryCount']==85 and pre['sourceVerification']['allRegularHashesVerified'] is True and pre['noUse']['inspectionErrors']==0 and pre['noUse']['matches']==[],'Actual full source and no-use proof')
expected={'leaf_common.py','preserve_untracked_leaf.py','retire_untracked_leaf.py','restore_untracked_leaf.py','SOURCE_SNAPSHOT.json','SOURCE_PREFLIGHT_RESULT.json','SOURCE_SEAL.json','ACTUAL_TRANSPORT_BINDING.json','CLOSURE_REVIEW.json','PRESERVED_UNTRACKED_LEAF_MANIFEST.json','TRANSPORT_RECEIPT.json','PUBLISH_MARKER.json','PUBLISH_TERMINAL.json','ACTUAL_PUBLISH_JOB.json','RESTORATION_POINTER.json'}
need(set(pre['files'])==expected,'Exact15 original prepared restoration files')
required={}
for n,pin in pre['files'].items():
 need(pin['path']==str(PREP/n),'Exact original prepared path')
 required[n]=read(PREP/n,pin)
required['PREDELETE.json']=pre_raw
need(sha(required['SOURCE_SEAL.json'])==SEAL and sha(required['RESTORATION_POINTER.json'])=='c7c944a1f5d742d30d644acf525bfa68aefecdd755ceb8139bd815603c676c78','Full reviewed restoration join')
term=json.loads(read(PREP/'TERMINAL_RESULT.json',{'bytes':315,'sha256':'94c99fa7f2360733618101476599c5b72ea59c992211279ee5ba2c82f29086cb'}))
need(term['status']=='SUCCEEDED' and term['removed'] is False and term['predelete']['sha256']==PRE_SHA,'Actual preparation terminal')
need(git('rev-parse','HEAD').decode().strip()==BEFORE and git('status','--porcelain=v1','-z')==b'','Exact clean Root predecessor')
need(git('branch','--show-current').decode().strip()==BRANCH and git('remote','get-url','origin').decode().strip()=='https://github.com/davidpovarsky/Maktabah.git','Exact existing branch/origin')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Exact unchanged product source')
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
docs=dict(required)
versions=[
('REVIEW1_SOURCE_PACKET.zip','/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-proposal-20261128/SOURCE_PROPOSAL.zip',234796,'93be4acb6c3f9729a5b168eee9b2a1b2a9bf73bf15d0b87a1b390c8ddd01cc45'),
('REVIEW1_RESULT.json','/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-proposal-20261128/RESULT.json',2115,'eb262fe366bcf8bfb2a0284df56eeb7831c65eacbea14e6965251aae691a6388'),
('REVIEW2_SOURCE_PACKET.zip','/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-review2-proposal-20261128/SOURCE_PROPOSAL.zip',326631,'8455ee2686451f377d0cb14f6fa920a08e688fc80d52ac9abefc2f80bc0ee8c3'),
('REVIEW2_RESULT.json','/home/ubuntu/otzaria-wave3-preserved-untracked-leaf-transport-review2-proposal-20261128/RESULT.json',2262,'e03fd3ff1e21d9d87beb796c81406de1c2fd6863d4f48a2130156a2c23beac9c')]
for n,path,count,h in versions:docs[n]=read(pathlib.Path(path),{'bytes':count,'sha256':h})
docs['ROOT_PUBLICATION_REVIEW.json']=read(BIND/'ROOT_PUBLICATION_REVIEW.json',{'bytes':10164,'sha256':'4f59ac8e5332c916b4103b53a04c31bc7d8a4f929243848392c05adfcb500cc8'})
docs['BIND_INPUTS.py']=read(BIND/'BIND_INPUTS.py',{'bytes':17830,'sha256':'3e9e86ae94c04620cc0997f611afa909f61e4fd7a3817a78891f8dab5d710164'})
docs['ROOT_INTAKE_PROOF.json']=canon({'schema':'otzaria.retained-untracked-root-intake/1','status':'EXACT_ACTUAL_RESTORATION_INPUTS_VERIFIED_BEFORE_GIT','sourceTree':SOURCE,'before':BEFORE,'actualPrepareJob':'job_adec27424e47','actualPublishJob':'job_ed3c7570ae45','rootPublishReadJob':'job_db5b02e1bba6','actualRetirementPrepareJob':'job_57b52caad25e','rootRetirementPrepareReadJob':'job_21ce4d6d7775','preparedFiles':15,'requiredDurableFiles':16,'PREDELETESHA256':PRE_SHA,'privateRepositoryID':1474927804,'privateReleaseID':461337522,'archiveAssetID':803430120,'manifestAssetID':803430071,'sourceRetired':False,'testsRun':0,'archiveExtracted':False,'sourceTreeRestored':False,'allOriginal84SurroundingEntriesRetained':True,'review1SourcesPreserved':True,'review2OnlySixReversibleHunks':True,'sourceFixes':['Bind two reused restore function names','Require isolated/no-bytecode/non-debug invocation','Join exact actual outer-job output to receipt, marker and terminal pins'],'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
docs['README.md']=b'''# Exact retained untracked archive restoration

This documentation-only checkpoint preserves the complete16-file restoration
closure for one existing691,303,419-byte archive. The original archive is private:
repository1474927804, draft461337522, immutable archive asset803430120. Its exact
SHA256 is e7783edfe09c044fb8b13f398604b35011a987970495c47d52a3306a15b8b100.
Manifest asset803430071 contains all85 original metadata/hash rows.

Both assets received full authenticated byte/size/SHA256 readbacks. Publication
job_ed3c7570ae45 finished with exit0; the exact outer result, receipt, marker and
terminal are preserved. Root's separate retirement preparation job_57b52caad25e
revalidated85 entries, all73 regular-file hashes, fresh private identities, and
387 processes with no active archive FD/mapping/cwd/exe and no inspection errors.
That preparation did not remove anything.

The actual pointer is RESTORATION_POINTER.json; its SHA256 is
c7c944a1f5d742d30d644acf525bfa68aefecdd755ceb8139bd815603c676c78.
SOURCE_SEAL.json SHA256 is
b3fb30020b2bafffd741829e78974f1fa088e20c70d5291d8d35648463ab0e1e.
The four exact Python sources and all other sealed inputs are adjacent.

A separate retirement commit still requires full remote Git-blob readback of
all16 required files, exact PREDELETE acknowledgement, fresh private identities,
all85 source hashes, fresh no-use and final descriptor/name joins. It can unlink
only the pinned untracked.tar.gz. The84 other contents/identities/modes/xattrs
remain protected; the immediate parent directory's namespace timestamps must
change and are explicitly recorded.

Future restoration uses restore_untracked_leaf.py with python3 -I -B as Root,
the exact source seal, pointer path/SHA, --restore-one-leaf, and a new canonical
UUID supplied to --attempt. It downloads only the immutable opaque archive to an
exclusive temporary sibling, verifies full disk bytes, restores the supported
metadata, and exclusively publishes the absent leaf. It never extracts the
archive or replaces another file. It retains failed partials. Original inode
and ctime cannot be recreated; historical metadata remains in the snapshot.
The original Data floor plus the complete payload is still required.

REVIEW1/REVIEW2 packets preserve the initial source findings and correction.
The initial unresolved restore aliases and missing outer-job-output join have
not been erased. This is evidence preservation only: no new product, SDK,
native, production, owner-signature, TestFlight or physical acceptance is claimed.
'''
docs['PUBLISH_RESTORATION.py']=pathlib.Path(__file__).read_bytes()
need(sum(map(len,docs.values()))<4194304,'Bounded complete documentation payload')
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
try:
 for n,b in docs.items():write(DEST/n,b)
 names=sorted(REL+'/'+n for n in docs)
 git('add','--sparse','-f','--',*names)
 need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0') if x)==names,'Only exact restoration docs staged')
 git('diff','--cached','--check')
 for n,b in docs.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Full index-byte join')
 git('commit','-m','docs: preserve exact retained archive restoration and reviewed sources')
 after=git('rev-parse','HEAD').decode().strip()
 need(git('rev-parse','HEAD^').decode().strip()==BEFORE,'Exact documentation parent')
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
 need(set(top_after)==set(top_before) and all(top_before[k]==top_after[k] for k in top_before if k!=b'docs'),'All non-doc root trees unchanged')
 need(git('status','--porcelain=v1','-z')==b'' and git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Clean exact product source')
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 ref=api('repos/davidpovarsky/Maktabah/git/ref/heads/'+BRANCH)
 need(ref['object']['type']=='commit' and ref['object']['sha']==after,'Exact published branch')
 repo=api('repos/davidpovarsky/Maktabah')
 need(repo['full_name']=='davidpovarsky/Maktabah' and type(repo['id']) is int and repo['owner']['login']=='davidpovarsky','Exact repository identity')
 remote={}
 for n,b in docs.items():
  oid=git('rev-parse',after+':'+REL+'/'+n).decode().strip()
  v=api('repos/davidpovarsky/Maktabah/git/blobs/'+oid)
  need(v['sha']==oid and v['encoding']=='base64' and v['size']==len(b),'Full exact Git envelope')
  decoded=base64.b64decode(''.join(v['content'].split()),validate=True)
  need(decoded==b and hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==oid,'Complete authenticated Git blob readback')
  remote[n]={'path':REL+'/'+n,'bytes':len(b),'sha256':sha(b),'gitBlob':oid}
 proof={'schema':'otzaria.retained-untracked-durable-git/1','repository':'davidpovarsky/Maktabah','repositoryID':repo['id'],'branch':BRANCH,'commit':after,'files':{n:remote[n] for n in required}}
 proof_raw=canon(proof);write(OUT/'DURABLE_GIT_PROOF.json',proof_raw)
 result={'status':'COMMITTED_PUSHED_ALL_RESTORATION_DOCS_FULL_READBACK','before':BEFORE,'after':after,'branch':BRANCH,'sourceUnchanged':SOURCE,'allNonDocsTopTreesUnchanged':True,'allRemoteFiles':remote,'requiredRestorationFiles':len(required),'documentationFiles':len(docs),'PREDELETESHA256':PRE_SHA,'durableGitProof':{'path':str(OUT/'DURABLE_GIT_PROOF.json'),'bytes':len(proof_raw),'sha256':sha(proof_raw)},'sourceRetired':False,'newTestsRun':0,'rootFreeBytes':free(),'dataFreeBytes':free('/mnt/development'),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 write(OUT/'RESULT.json',canon(result));write(OUT/'COMMANDS.json',canon(commands))
 print(json.dumps(result))
except BaseException as error:
 write(OUT/'FAILED.json',canon({'errorType':type(error).__name__,'message':str(error),'commands':commands,'sourceRetired':False,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}))
 raise
