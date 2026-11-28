"""Retire only fourteen fully preserved historical focused-source raw copies."""
if not __debug__:raise RuntimeError('Optimized retirement refused')
import argparse,base64,datetime,hashlib,io,json,os,pathlib,shutil,stat,subprocess,zipfile
R=pathlib.Path('/home/ubuntu/otzaria-wave3-native116-v3-focused-controls-20261128')
G=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
REL='docs/hq-integration/wave3-focused-source-storage-preservation-20261128'
BRANCH='codex/otzaria-wave3-integration-20261127'
PARENT='6878075d67afb7bb5e58ebf90c9a6a6aeeacd27d'
SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
CAP=4194304;FLOOR=1593835520
def need(x,m):
 if not x:raise RuntimeError(m)
def sha(b):return hashlib.sha256(b).hexdigest()
def canonical(v):return (json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=True)+'\n').encode()
def ident(s):return (s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,limit=1048576):
 s=p.lstat();need(stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size<=limit,'Exact regular single source')
 f=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
 try:
  need(ident(os.fstat(f))==ident(s),'Source open identity')
  with os.fdopen(os.dup(f),'rb')as h:b=h.read(limit+1)
  need(len(b)==s.st_size and ident(os.fstat(f))==ident(s),'Full stable source read')
 finally:os.close(f)
 need(ident(p.lstat())==ident(s),'Source path identity')
 return b,s
def used():
 count=0
 def walk(p,d=0):
  nonlocal count
  count+=1;need(count<=2048 and d<=12,'Finite controls scope')
  s=p.lstat();v=s.st_blocks*512
  if stat.S_ISDIR(s.st_mode):
   for e in os.scandir(p):v+=walk(pathlib.Path(e.path),d+1)
  return v
 return walk(R)
def guard(extra=0):
 need(shutil.disk_usage('/').free>=FLOOR+CAP,'Root floor plus complete controls reserve')
 n=used();need(n+extra+8192<=CAP,'Unchanged4MiB allocation guard');return n
def git(*a):
 p=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-C',str(G),*a],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=45)
 need(p.returncode==0,'Git verification failed: '+p.stderr[:512].decode('utf-8','replace'))
 return p.stdout
def create(name,b):
 guard(((len(b)+4095)//4096)*4096)
 p=R/name;fd=os.open(p,os.O_RDWR|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o644)
 try:
  v=memoryview(b)
  while v:
   n=os.write(fd,v);need(n>0,'Complete retained record write');v=v[n:]
  os.fsync(fd)
  need(os.pread(fd,len(b)+1,0)==b,'Full new record readback')
 except BaseException:os.close(fd);raise
 return fd
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-sha256',required=True)
p.add_argument('--preservation-commit',required=True)
a=p.parse_args()
need(os.geteuid()==1001 and os.getegid()==1001,'Original owned user')
need(R.resolve(strict=True)==R and R.lstat().st_uid==1001,'Exact owned controls root')
own=pathlib.Path(__file__);need(own==R/'RETIRE_PRESERVED_SOURCES.py','Exact retirement source path')
code,_=read(own,12288);need(sha(code)==a.source_sha256,'Root-approved retirement source')
need(len(a.preservation_commit)==40 and all(c in '0123456789abcdef'for c in a.preservation_commit),'Exact preservation commit')
need(not os.path.lexists(R/'SOURCE_STORAGE_RETIRED.json') and not os.path.lexists(R/'SOURCE_STORAGE_GIT_POINTER.json'),'Exclusive retirement')
need(not os.path.lexists(R/'runs/mac-candidate'),'Candidate not started')
closure,_=read(R/'CONTROLS_CLOSED.json');need(closure==bytes(65536),'Closure remains open')
guard(4096+16384)
prep_raw,_=read(R/'SOURCE_STORAGE_PREPARED.json');need(sha(prep_raw)=='1f21b056271a04d2c1146687cdb4c65e0fed3f8c7853912daabdb64854c8d73c','Pinned preparation')
prep=json.loads(prep_raw);need(prep['status']=='ADDITIVE_SOURCE_PREPARATION_NO_RAW_RETIREMENT','Original preparation status')
archive,archive_stat=read(R/'HISTORICAL_SOURCES.zip',131072)
need(len(archive)==87596 and sha(archive)=='d00812b52bbfedc7ad8424f92c346f673fe82d74ded02ad89a4491259aa11433','Exact archive')
need(git('rev-parse','HEAD').decode().strip()==a.preservation_commit and git('rev-parse','HEAD^').decode().strip()==PARENT,'Exact new preservation commit')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE and git('status','--porcelain=v1','-z')==b'','Product and clean tree unchanged')
need(git('remote','get-url','origin').decode().strip()=='https://github.com/davidpovarsky/Maktabah.git','Exact project origin')
remote=git('-c','credential.helper=!gh auth git-credential','ls-remote','--heads','origin','refs/heads/'+BRANCH).decode().split()
need(remote and remote[0]==a.preservation_commit,'Durable remote preservation ref')
for name in ['HISTORICAL_SOURCES.zip','resolve_preserved_sources.py','PREPARE_SOURCE_STORAGE.py','SOURCE_STORAGE_PREPARED.json','SOURCE_STORAGE_README.md','RETIRE_PRESERVED_SOURCES.py']:
 need(git('show',a.preservation_commit+':'+REL+'/'+name)==read(R/name)[0],'Exact durable source body')
blob=git('rev-parse',a.preservation_commit+':'+REL+'/HISTORICAL_SOURCES.zip').decode().strip()
api=subprocess.run(['gh','api','repos/davidpovarsky/Maktabah/git/blobs/'+blob],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=45)
need(api.returncode==0 and len(api.stdout)<=262144,'Full remote blob response')
obj=json.loads(api.stdout);need(obj['sha']==blob and obj['encoding']=='base64' and obj['size']==len(archive),'Exact remote blob metadata')
remote_raw=base64.b64decode(''.join(obj['content'].splitlines()),validate=True)
need(remote_raw==archive and hashlib.sha1(b'blob '+str(len(archive)).encode()+b'\0'+remote_raw).hexdigest()==blob,'Full remote Git archive readback')
with zipfile.ZipFile(io.BytesIO(archive))as z:
 manifest_raw=z.read('MANIFEST.json');need(len(manifest_raw)==prep['manifest']['bytes'] and sha(manifest_raw)==prep['manifest']['sha256'],'Full metadata pin')
 manifest=json.loads(manifest_raw);entries=manifest['entries']
 need(len(entries)==14 and len(z.infolist())==15 and set(z.namelist())=={r['name']for r in entries}|{'MANIFEST.json'},'Exact15 archived members')
 payloads={}
 for row in entries:
  need(pathlib.Path(row['name']).name==row['name'] and row['originalPath']==str(R/row['name']),'Closed raw source path')
  b=z.read(row['name']);need(len(b)==row['bytes'] and sha(b)==row['sha256'],'Full archived original bytes')
  payloads[row['name']]=b
def original(row):
 b,s=read(R/row['name'])
 need(b==payloads[row['name']],'Original equals complete archive member')
 for k,v in [('device',s.st_dev),('inode',s.st_ino),('mode',s.st_mode),('uid',s.st_uid),('gid',s.st_gid),('nlink',s.st_nlink),('bytes',s.st_size),('blocks',s.st_blocks)]:
  need(row[k]==v,'Exact original '+k)
 need(row['mtimeNS']==str(s.st_mtime_ns) and row['ctimeNS']==str(s.st_ctime_ns),'Exact original change times')
 attrs=[{'nameBase64':base64.b64encode(os.fsencode(n)).decode(),'valueBase64':base64.b64encode(os.getxattr(R/row['name'],n,follow_symlinks=False)).decode()}for n in sorted(os.listxattr(R/row['name'],follow_symlinks=False))]
 need(attrs==row['xattrs'],'Complete original xattrs')
 return s
for row in entries:original(row)
for name,pin in prep['originalSourcePins'].items():
 b,_=read(R/name);need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'All original22 source pins')
for pin in prep['phaseEvidencePins']:
 b,_=read(R/pin['path']);need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Completed actual phase evidence')
leaders=[]
for rel in ['runs/accounting-candidate','runs/accounting-omit-first','runs/mac-baseline','runs/mac-baseline/alias']:
 t=json.loads(read(R/rel/'worker.TERMINAL.json')[0])
 need(t['ownedLeaderReaped'] and t['returncode']==0 and t['streamsFullyDrainedBeforeCleanup'] and t['cleanupError']is None and t['terminalAbort']is None and t['outputOverflow']is None and not t['reportingErrors'],'Completed known phase leader')
 need(not os.path.exists('/proc/'+str(t['pid'])),'Known original local leader must be absent; no PID adoption')
 leaders.append({'path':rel,'pid':t['pid'],'absentNow':True})
pointer={'schema':'otzaria.focused-source-storage-git-pointer/1','commit':a.preservation_commit,'branch':BRANCH,'path':REL+'/HISTORICAL_SOURCES.zip','gitBlob':blob,'archiveBytes':len(archive),'archiveSHA256':sha(archive),'fullRemoteBlobReadback':True,'retirementSourceSHA256':a.source_sha256,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
pb=canonical(pointer);need(len(pb)<=4096,'Bounded durable pointer')
pf=create('SOURCE_STORAGE_GIT_POINTER.json',pb);os.close(pf)
fd=create('SOURCE_STORAGE_RETIRED.json',bytes(16384));slot_initial=os.fstat(fd)
rootfd=os.open(R,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
deleted=[];status='PARTIAL_RETIREMENT';error=None;before_alloc=used()
try:
 for row in entries:
  guard()
  need(read(R/'HISTORICAL_SOURCES.zip',131072)[0]==archive,'Preserved archive stable before retirement')
  original(row)
  os.unlink(row['name'],dir_fd=rootfd);deleted.append(row['name'])
 os.fsync(rootfd)
 need(all(not os.path.lexists(R/n)for n in payloads),'Exact raw14 absent after verified retirement')
 for name,pin in prep['originalSourcePins'].items():
  b=payloads[name]if name in payloads else read(R/name)[0]
  need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Original22 source bytes retained')
 for pin in prep['phaseEvidencePins']:
  b,_=read(R/pin['path']);need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Actual phase evidence unchanged')
 guard();status='PRESERVED_AND_RAW14_RETIRED'
except BaseException as e:error={'type':type(e).__name__,'message':str(e)[:1024]}
finally:
 os.close(rootfd)
 result={'schema':'otzaria.focused-source-storage-retirement/1','status':status,'gitPointer':pointer,'deletedHistoricalRawNames':deleted,'remainingHistoricalRawNames':[n for n in payloads if os.path.lexists(R/n)],'historicalSourcesPreserved':14,'originalRawAllocationBytes':307200,'scopeAllocatedBeforeRetirement':before_alloc,'scopeAllocatedBeforeReportShrink':used(),'knownOwnedLocalLeaders':leaders,'broaderDescendantOrGlobalNoUseClaim':False,'rootHadNoOtherFocusedPhaseAuthorized':True,'error':error,'candidateExecuted':False,'guardsTestBodiesAndOutputCapsChanged':False,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 rb=canonical(result);need(len(rb)<=16384,'Bounded complete retirement receipt')
 need(os.fstat(fd).st_ino==slot_initial.st_ino and (R/'SOURCE_STORAGE_RETIRED.json').lstat().st_ino==slot_initial.st_ino,'Original retained receipt slot')
 os.lseek(fd,0,os.SEEK_SET);v=memoryview(rb)
 while v:
  n=os.write(fd,v);need(n>0,'Complete retirement receipt');v=v[n:]
 os.ftruncate(fd,len(rb));os.fsync(fd);need(os.pread(fd,len(rb)+1,0)==rb,'Full retirement receipt readback');os.close(fd)
 print(json.dumps({'status':status,'receiptBytes':len(rb),'receiptSHA256':sha(rb),'deletedCount':len(deleted),'scopeAllocatedBytes':used(),'futureCandidateGuardPeak':used()+208896+8192,'preservationCommit':a.preservation_commit,'archiveSHA256':sha(archive),'error':error}))
 if error:raise RuntimeError('Retirement incomplete; exact failure retained')
