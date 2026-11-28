import os,pathlib,stat,json,hashlib,zipfile,tarfile,io,gzip,subprocess,shutil,datetime,base64
FPINS=json.loads("[{\"path\":\"CLOSURE_MANIFEST.json\",\"bytes\":381406,\"sha256\":\"4298d4775f55d8b61bf18967fe7c55072ae766527ae19f8448d7f36b5b1009a0\"},{\"path\":\"EXTERNAL_REVIEW.json\",\"bytes\":857,\"sha256\":\"2439900631482622367a1e3e55b9d8b70a5db47cc57f020f4d39dd07f01de009\"},{\"path\":\"MANIFEST.json\",\"bytes\":753035,\"sha256\":\"e7045138b50cee80a592a4fd001109cc4fd09cf96498e6f8ee0c9d99281cfaa1\"},{\"path\":\"PACKAGE.py\",\"bytes\":23589,\"sha256\":\"e34696a867020482783de0ba3e81e75f38dafeebbc6aaa959329ea01cb9fffc0\"},{\"path\":\"PACKET.zip\",\"bytes\":383203,\"sha256\":\"bb16fb3cb7629576b45424e1613337428ff3a8fdbf08121a50a53e79bca62a2b\"},{\"path\":\"README.md\",\"bytes\":1450,\"sha256\":\"fafe650a4c9a26ceee77131e9248e88ff8a36a3010047091d7c2d77dc1a50f37\"},{\"path\":\"RESULT.json\",\"bytes\":2185,\"sha256\":\"60d3d54cb6e40eca58aa01ca52b99cb47651c39065f25324b5f07478aa7f497b\"},{\"path\":\"VERIFY_EXTERNAL.py\",\"bytes\":5836,\"sha256\":\"adcf18e771bf9652a4b1fa12604bb074a6725824e717bfbbc474a1079aa6b953\"}]")
SPINS=json.loads("[{\"path\":\"ARCHIVE_READBACK.json\",\"bytes\":117187,\"sha256\":\"90b604f96c894c545f8605e6f1c73bc5637a3d79fbc4f6f25ea55c5ce1c7d7c8\"},{\"path\":\"MANIFEST.json\",\"bytes\":32768,\"sha256\":\"2ae4a141d5d4dbcac629cd5a11a82d4c89f9ed1b91e682869c37ec194603b676\"},{\"path\":\"PRESERVE_NEW_SOURCE_PACKETS.py\",\"bytes\":21728,\"sha256\":\"9eaac8a3e7ce42899d0101902daa5a0174bb1b545bb84c262012595d20073700\"},{\"path\":\"PROVENANCE.json\",\"bytes\":3030,\"sha256\":\"393fbfe61a75b6c66b064d630b6d8c42c97bca18faacb3f3b6704afb552cd1dd\"},{\"path\":\"RESULT.json\",\"bytes\":32768,\"sha256\":\"0cf07f90b82653fb5898177e0bc1932eb9016afbdb250e027017650166c2ae6c\"},{\"path\":\"SOURCE_ARCHIVE.tar.gz\",\"bytes\":1354361,\"sha256\":\"c0b051efb17df7ac35f67853067a62f17f2a88f40f7b668d146d989ef6f000fe\"},{\"path\":\"SOURCE_SNAPSHOT_AFTER.json\",\"bytes\":256883,\"sha256\":\"4d7e2226be1a7958f290eb676833d34f29189e5ff7060e7b9d312f4b6c31a9ce\"},{\"path\":\"SOURCE_SNAPSHOT_BEFORE.json\",\"bytes\":256883,\"sha256\":\"4d7e2226be1a7958f290eb676833d34f29189e5ff7060e7b9d312f4b6c31a9ce\"}]")
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
FOCUS=pathlib.Path('/home/ubuntu/otzaria-wave3-focused-closed-evidence-preservation-20261128')
SOURCE=pathlib.Path('/home/ubuntu/otzaria-wave3-new-source-packets-preservation-20261128')
REL='docs/hq-integration/wave3-closed-controls-and-source-packets-20261128'
DEST=ROOT/REL
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-closed-packets-git-intake-20261128')
BEFORE='9e7031f23b7eb805f6c156d596755ffc06d9ffd7'
SOURCE_TREE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
FLOOR=1593835520
commands=[];input_rows=[]
def need(x,m):
 if not x:raise RuntimeError(m)
def sha(b):return hashlib.sha256(b).hexdigest()
def canon(v):return(json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=True)+'\n').encode('ascii')
def stable(s):return(s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns,s.st_blocks)
def metadata(s):
 return {'device':s.st_dev,'inode':s.st_ino,'mode':s.st_mode,'uid':s.st_uid,'gid':s.st_gid,'nlink':s.st_nlink,'bytes':s.st_size,'atimeNS':str(s.st_atime_ns),'mtimeNS':str(s.st_mtime_ns),'ctimeNS':str(s.st_ctime_ns),'allocatedBytes':s.st_blocks*512}
def free():
 s=os.statvfs('/');return s.f_bavail*s.f_frsize
def read(p,pin=None,limit=8388608):
 need(p.resolve(strict=True)==p,'Exact input path')
 s=p.lstat();need(stat.S_ISREG(s.st_mode)and s.st_nlink==1 and s.st_size<=limit,'Bounded single regular file')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|getattr(os,'O_NOATIME',0))
 try:
  need(stable(os.fstat(fd))==stable(s),'Opened same input')
  with os.fdopen(os.dup(fd),'rb')as r:b=r.read(limit+1)
  need(len(b)==s.st_size and stable(os.fstat(fd))==stable(s),'Full stable input')
 finally:os.close(fd)
 need(stable(p.lstat())==stable(s),'Stable input path')
 if pin:need(len(b)==pin['bytes']and sha(b)==pin['sha256'],'Exact sealed packet pin: '+p.name)
 return b,s
def cmd(argv,binary=False):
 p=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
 row={'argv':argv,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row);need(p.returncode==0,'Exact bounded command failed: '+str(row));return p.stdout
def git(*args,binary=False):
 return cmd(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','-C',str(ROOT),*args],binary)
need(free()>=FLOOR+16777216,'Complete documentation/objects allowance')
need(not os.path.lexists(DEST)and not os.path.lexists(OUT),'Exclusive new documentation checkpoint')
need(git('rev-parse','HEAD').decode().strip()==BEFORE and git('status','--porcelain=v1','-z')==b'','Exact clean root predecessor')
need(git('branch','--show-current').decode().strip()==BRANCH and git('remote','get-url','origin').decode().strip()=='https://github.com/davidpovarsky/Maktabah.git','Exact branch/origin')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE_TREE,'Unchanged product source')
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
inputs={}
for label,root,pins in [('focused',FOCUS,FPINS),('new-source',SOURCE,SPINS)]:
 need(root.resolve(strict=True)==root and len(pins)==8 and set(os.listdir(root))=={x['path']for x in pins},'Exact eight-file closed packet')
 data={}
 for pin in pins:
  b,s=read(root/pin['path'],pin,2097152);data[pin['path']]=b
  xa=[]
  for name in sorted(os.listxattr(root/pin['path'],follow_symlinks=False)):
   value=os.getxattr(root/pin['path'],name,follow_symlinks=False)
   need(len(value)<=65536 and len(xa)<32,'Bounded packet xattrs')
   xa.append({'nameBase64':base64.b64encode(os.fsencode(name)).decode(),'valueBase64':base64.b64encode(value).decode()})
  input_rows.append({'scope':label,'root':str(root),**pin,'observedMetadata':metadata(s),'xattrs':xa})
 inputs[label]=data
focused=inputs['focused'];new=inputs['new-source']
fm=json.loads(focused['MANIFEST.json']);fr=json.loads(focused['RESULT.json'])
need(fr['status']=='FULL_PACKET_AND_SOURCE_VERIFIED'and fr['sourceEntryCount']==945 and not fr['sourceRetired']and fr['testsRun']==0,'Focused preservation boundary')
need(fm['schema']=='otzaria.lossless-focused-content-addressed-archive/1'and len(fm['sourceEntries'])==945 and len(fm['externalProofEntries'])==2,'Complete focused logical membership')
need(fm['sourceKinds']=={'directory':123,'file':821,'symlink':1}and fm['sourceAllocatedBytes']==3932160,'Original focused scope')
payloads={}
with zipfile.ZipFile(io.BytesIO(focused['PACKET.zip']))as z:
 infos=z.infolist();expected={'MANIFEST.json','CLOSURE_MANIFEST.json'}|{'blobs/'+h for h in fm['payloads']}
 need(len(infos)==122 and len(expected)==122 and {i.filename for i in infos}==expected and len(z.namelist())==len(set(z.namelist())),'Exact focused inner archive members')
 need(z.read('MANIFEST.json')==focused['MANIFEST.json']and z.read('CLOSURE_MANIFEST.json')==focused['CLOSURE_MANIFEST.json'],'Full focused metadata bytes')
 for h,pin in fm['payloads'].items():
  need(pin['archiveMember']=='blobs/'+h and pin['sha256']==h and pin['bytes']<=1048576,'Bounded content-addressed payload')
  b=z.read(pin['archiveMember']);need(len(b)==pin['bytes']and sha(b)==h,'Complete focused payload readback');payloads[h]=b
 need(len(payloads)==120,'Every unique focused payload')
allfocused=fm['sourceEntries']+fm['externalProofEntries']
for row in allfocused:
 need(base64.b64decode(row['pathBase64'],validate=True)==os.fsencode(row['path']),'Exact logical path bytes')
 if row['kind']=='file':
  c=row['content'];need(c['archiveMember']=='blobs/'+c['sha256']and len(payloads[c['sha256']])==c['bytes']==row['metadata']['bytes'],'Full logical focused file join')
 else:need(row['kind']in ('directory','symlink'),'No invented focused type')
original=json.loads(focused['CLOSURE_MANIFEST.json']);old={r['path']:r for r in original['entries']}
need(len(old)==945 and set(old)=={r['path']for r in fm['sourceEntries']},'Full original closure path set')
for row in fm['sourceEntries']:
 o=old[row['path']];m=row['metadata'];need(o['kind']==row['kind']and o['uid']==m['uid']and o['gid']==m['gid'],'Original kind/owner')
 if row['path']!='CONTROLS_CLOSED.json':
  now={k:m[k]for k in ('device','inode','mode','nlink','bytes','mtimeNS','ctimeNS')}
  need(now==o['identity']and m['blocks']*512==o['allocatedBytes'],'Complete stable closure metadata')
  if row['kind']=='file':need(row['content']['sha256']==o['sha256'],'Original closed file hash')
  if row['kind']=='symlink':need(row['targetBase64']==o['targetBase64']and row['targetFollowed']is False,'Exact original unfollowed symlink target')
 else:
  need(row['content']['sha256']=='00a78c8d29416c20af3c4cd40661601b5fad3de78e6e12b3f137196377bce036'and m['bytes']==58293 and m['inode']==632304 and m['device']==2049,'Exact final closure self')
closed=payloads['00a78c8d29416c20af3c4cd40661601b5fad3de78e6e12b3f137196377bce036']
cv=json.loads(closed);gz=base64.b64decode(cv['manifestGzipBase64'],validate=True)
need(gzip.decompress(gz)==focused['CLOSURE_MANIFEST.json'],'Exact complete original closure decode')
need(len(fm['hardlinkTopology'])==1 and fm['hardlinkTopology'][0]['unresolvedExternalLinkCount']==0,'Original internal hardlink topology')
need(payloads['2439900631482622367a1e3e55b9d8b70a5db47cc57f020f4d39dd07f01de009']==focused['EXTERNAL_REVIEW.json']and payloads['adcf18e771bf9652a4b1fa12604bb074a6725824e717bfbbc474a1079aa6b953']==focused['VERIFY_EXTERNAL.py'],'Both external complete proof files')
nr=json.loads(new['RESULT.json']);nm=json.loads(new['MANIFEST.json']);ns=json.loads(new['SOURCE_SNAPSHOT_BEFORE.json']);rb=json.loads(new['ARCHIVE_READBACK.json'])
need(nr['status']=='PRESERVED_FULL_READBACK_SOURCE_UNCHANGED'and nr['newCompilerOrTestExecutions']==0 and not nr['sourceCleanup'],'New source-only preservation')
need(nm['status']=='IMMUTABLE_CLOSED_PACKET'and nm['excludeOnly']==['MANIFEST.json']and nm['newControlsExecution']=='NOT_RUN','Original closed source packet status')
need(len(new['RESULT.json'])==32768 and len(new['MANIFEST.json'])==32768,'Both original reserved JSON byte lengths retained')
for pin in nm['files']:need(len(new[pin['path']])==pin['bytes']and sha(new[pin['path']])==pin['sha256'],'Seven source packet members match final manifest')
need(new['SOURCE_SNAPSHOT_BEFORE.json']==new['SOURCE_SNAPSHOT_AFTER.json']and ns['files']==273 and ns['directories']==144,'Original full source metadata snapshots equal')
rows={r['archivePath']:r for r in ns['entries']};rbr={r['path']:r for r in rb['rows']}
need(len(rows)==len(rbr)==417 and rb['sourceFiles']==273 and rb['decodedBytesEqual']and rb['exactMetadataBinding'],'All original source paths and readback records')
def ns_text(v):
 a,b=divmod(v,1000000000);return str(a)+'.'+('%09d'%b)
files_read=0;dirs_read=0;payload_bytes=0
with tarfile.open(fileobj=io.BytesIO(new['SOURCE_ARCHIVE.tar.gz']),mode='r:gz')as t:
 members=t.getmembers();need(len(members)==417 and len({m.name for m in members})==417 and {m.name for m in members}==set(rows),'Complete source tar membership')
 for m in members:
  row=rows[m.name];st=row['metadata']['stat'];pax=m.pax_headers
  need(m.uid==st['st_uid']and m.gid==st['st_gid']and m.mode==stat.S_IMODE(st['st_mode']),'Original archive uid/gid/mode')
  for key in ('atime','mtime','ctime'):need(pax[key]==ns_text(st['st_'+key+'_ns']),'Exact archived nanoseconds')
  need(pax['Otzaria.snapshot.sha256']==sha(new['SOURCE_SNAPSHOT_BEFORE.json'])and pax['Otzaria.metadata.sha256']==rbr[m.name]['metadataSHA256'],'Exact full metadata association')
  if row['kind']=='file':
   need(m.isfile()and m.size==row['bytes']==st['st_size']and m.size<=2097152,'Exact original regular file')
   f=t.extractfile(m);need(f is not None,'Read file payload');b=f.read(m.size+1)
   need(len(b)==m.size and sha(b)==row['sha256'],'Full original source payload readback')
   files_read+=1;payload_bytes+=len(b)
  else:need(row['kind']=='directory'and m.isdir(),'Exact directory record');dirs_read+=1
need(files_read==273 and dirs_read==144,'All source files and directory records decoded')
def outer(data):
 memory=io.BytesIO()
 with zipfile.ZipFile(memory,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9)as z:
  for name in sorted(data):
   zi=zipfile.ZipInfo(name,(1980,1,1,0,0,0));zi.create_system=3;zi.external_attr=(stat.S_IFREG|0o640)<<16;zi.compress_type=zipfile.ZIP_DEFLATED
   z.writestr(zi,data[name],compresslevel=9)
 raw=memory.getvalue();need(len(raw)<=4194304,'Bounded exact packet wrapper')
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  need(len(z.infolist())==8 and set(z.namelist())==set(data),'Exact eight packet leaves')
  for n,b in data.items():need(z.read(n)==b,'Full outer packet byte readback')
 return raw
docs={'FOCUSED_PACKET.zip':outer(focused),'SOURCE_PACKET.zip':outer(new)}
proof={'schema':'otzaria.closed-packets-root-git-intake/1','status':'COMPLETE_RAW_PACKETS_AND_ALL_LOGICAL_PAYLOADS_VERIFIED','before':BEFORE,'sourceTree':SOURCE_TREE,'focused':{'originalEntries':945,'files':821,'directories':123,'symlinks':1,'externalProofFiles':2,'uniquePayloads':120,'innerArchiveMembers':122,'originalClosureSHA256':sha(closed),'sourceRetired':False},'newSource':{'originalFiles':273,'directories':144,'archiveMembers':417,'logicalFileBytesRead':payload_bytes,'completeBeforeAfterMetadataEqual':True,'reservedResultAndManifestBytesPreserved':True,'newControls':'NOT_RUN'},'wrappers':{n:{'bytes':len(b),'sha256':sha(b),'completeRawLeaves':8}for n,b in docs.items()},'rootSourceRecheck':'All sixteen sealed packet inputs will be rejoined before commit; original source scopes remain intact.','originalMetadata':'Complete historical metadata remains byte-exact in inner manifests; current packet read-atime is recorded separately and not used as source qualification.','newTestsRun':0,'native116ProductQualification':False,'native116ActualPrivateSnapshotIncluded':False,'sourceChanges':0,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
docs['ROOT_INTAKE_PROOF.json']=canon(proof)
docs['INPUT_MANIFEST.json']=canon({'schema':'otzaria.closed-packets-input-pins/1','inputs':input_rows,'rawLeaves':16,'rawBytesUnmodified':True})
docs['PROVENANCE.json']=canon({'schema':'otzaria.closed-packets-execution-provenance/1','focusedOracle11':'job_c50595e079e4','focusedOmissionNegative':'job_c0ebef6d24a8','focusedMacBaselineTwo':'job_768bd7986225','focusedMacCandidate17':'job_f0085cf1a6c6','actualFocusedClosure':'job_11302726b340','externalClosureReview':'job_782f1832af09','focusedPacket':'job_da00a2071a5a','newSourcePacket':{'transport':'synchronous SentinelX sentinel_exec','jobID':None,'exit':0,'durationSeconds':1.35,'terminalUTC':'2026-11-28T04:34:49.570453+00:00'},'qualification':'Focused controls:28 pass and3 intended negative outcomes. New TOC/Inspector/BookInfo controls unrun. No SDK/native/product/TestFlight or physical claim.'})
docs['README.md']=b'''# Closed focused evidence and new source packets

This documentation-only checkpoint preserves two complete eight-file packets.
FOCUSED_PACKET.zip retains the 945-entry closed focused scope through its original
content-addressed archive, complete metadata, closure, external verification,
packaging controller and receipt. All 821 file payloads, 123 directory records,
one symlink target, the original hardlink topology and both external proof files
were decoded and joined. The actual focused result remains 28 passed methods and
three separate intended negative outcomes.

SOURCE_PACKET.zip retains all eight original source-preservation files, including
the exact 32 KiB RESULT.json and MANIFEST.json with their reserved whitespace.
No whitespace or raw evidence was normalized. Its original tar.gz carries all
273 source files and 144 directory records from the closed TOC, Inspector and
BookInfo source-continuation scopes. All 417 members were decoded; bytes, modes,
owners, exact timestamp strings and metadata associations were verified.

Extracting either outer ZIP recovers the original packet leaves byte-for-byte.
The original snapshots and inner manifests retain historical metadata; filesystem
inode identities are provenance and are not promised on restoration. Reading
can affect access time. Original source scopes remain in place.

INPUT_MANIFEST.json records every original packet input. ROOT_INTAKE_PROOF.json
records the complete readback scope and wrapper digests. PROVENANCE.json separates
actual focused execution from the unrun product source controls. INTAKE.py is the
exact Root controller. No product source, vendor, build project, catalog, owner
signature or test assertion is changed. There is no new native acceptance or
TestFlight release. Actual Native116 private snapshot and payloads belong to the
separate private preservation operation and are not included in this checkpoint.
'''
docs['INTAKE.py']=pathlib.Path(__file__).read_bytes()
need(len(docs)==7 and sum(map(len,docs.values()))<=8388608,'Bounded seven-file checkpoint')
for label,root,pins in [('focused',FOCUS,FPINS),('new-source',SOURCE,SPINS)]:
 need(set(os.listdir(root))=={x['path']for x in pins},'Closed packet membership remains exact')
 for pin in pins:need(read(root/pin['path'],pin,2097152)[0]==inputs[label][pin['path']],'All sixteen original bytes rejoined')
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
def write(p,b):
 need(free()>=FLOOR+8388608,'Documentation reserve before write')
 chain=[];q=p.parent
 while not q.exists():chain.append(q);q=q.parent
 for d in reversed(chain):d.mkdir(mode=0o750);os.chown(d,1001,1001)
 fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o640)
 try:
  os.fchown(fd,1001,1001);view=memoryview(b)
  while view:
   n=os.write(fd,view);need(n>0,'Complete docs write');view=view[n:]
  os.fsync(fd)
 finally:os.close(fd)
 need(read(p)[0]==b,'Exact written docs bytes')
try:
 for n,b in docs.items():write(DEST/n,b)
 names=[REL+'/'+n for n in sorted(docs)]
 git('add','--sparse','-f','--',*names)
 need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0')if x)==names,'Only exact seven docs staged')
 git('diff','--cached','--check')
 for n,b in docs.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Complete Git index byte join')
 git('commit','-m','docs: preserve closed focused evidence and new UI source packets')
 after=git('rev-parse','HEAD').decode().strip();need(git('rev-parse','HEAD^').decode().strip()==BEFORE,'Exact preservation parent')
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
 need(set(top_after)==set(top_before)and all(top_before[k]==top_after[k]for k in top_before if k!=b'docs'),'All non-doc top trees unchanged')
 need(git('status','--porcelain=v1','-z')==b''and git('rev-parse','HEAD:Source').decode().strip()==SOURCE_TREE,'Clean exact unchanged source')
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 remote=git('-c','credential.helper=!gh auth git-credential','ls-remote','--heads','origin','refs/heads/'+BRANCH).decode().strip()
 need(remote.split()[0]==after,'Remote branch head readback')
 remote_archives={}
 for n in ('FOCUSED_PACKET.zip','SOURCE_PACKET.zip'):
  blob=git('rev-parse',after+':'+REL+'/'+n).decode().strip()
  raw=cmd(['sudo','-u','ubuntu','-H','gh','api','repos/davidpovarsky/Maktabah/git/blobs/'+blob],binary=True)
  need(len(raw)<=len(docs[n])*2+65536,'Bounded complete remote blob response')
  v=json.loads(raw);need(v['sha']==blob and v['encoding']=='base64'and v['size']==len(docs[n]),'Exact remote archive blob')
  decoded=base64.b64decode(''.join(v['content'].splitlines()),validate=True)
  need(decoded==docs[n]and hashlib.sha1(b'blob '+str(len(decoded)).encode()+b'\0'+decoded).hexdigest()==blob,'Full remote archive byte readback')
  remote_archives[n]={'gitBlob':blob,'bytes':len(decoded),'sha256':sha(decoded),'fullRemoteReadback':True}
 result={'schema':'otzaria.closed-packets-git-publication/1','status':'COMMITTED_PUSHED_FULL_TWO_ARCHIVE_READBACK','before':BEFORE,'after':after,'branch':BRANCH,'sourceUnchanged':SOURCE_TREE,'allNonDocsTopTreesUnchanged':True,'docs':7,'archives':remote_archives,'rawPacketLeaves':16,'focusedEntries':945,'newSourceFiles':273,'newSourceDirectories':144,'proofSHA256':sha(docs['ROOT_INTAKE_PROOF.json']),'inputManifestSHA256':sha(docs['INPUT_MANIFEST.json']),'controllerSHA256':sha(docs['INTAKE.py']),'newTestsRun':0,'sourceRetired':False,'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rootFreeBytes':free(),'dataFreeBytes':shutil.disk_usage('/mnt/development').free}
 write(OUT/'RESULT.json',canon(result));write(OUT/'COMMANDS.json',canon(commands))
 print(json.dumps(result))
except BaseException as error:
 write(OUT/'FAILED.json',canon({'type':type(error).__name__,'error':str(error),'commands':commands,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}))
 raise
