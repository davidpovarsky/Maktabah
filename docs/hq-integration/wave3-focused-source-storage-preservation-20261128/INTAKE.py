import os,pathlib,stat,json,hashlib,zipfile,io,subprocess,shutil,datetime,base64
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
INPUT=pathlib.Path('/home/ubuntu/otzaria-wave3-native116-v3-focused-controls-20261128')
REL='docs/hq-integration/wave3-focused-source-storage-preservation-20261128'
DEST=ROOT/REL
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-focused-storage-git-intake-20261128')
BEFORE='6878075d67afb7bb5e58ebf90c9a6a6aeeacd27d';SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
PINS=json.loads("[{\"path\":\"HISTORICAL_SOURCES.zip\",\"bytes\":87596,\"sha256\":\"d00812b52bbfedc7ad8424f92c346f673fe82d74ded02ad89a4491259aa11433\"},{\"path\":\"resolve_preserved_sources.py\",\"bytes\":6558,\"sha256\":\"1ca9f9d9ae105407bb47c8396655e7e22987035662a34fe220d06e268f74caca\"},{\"path\":\"PREPARE_SOURCE_STORAGE.py\",\"bytes\":21239,\"sha256\":\"9d43ad1eccc66cf94cb8267b7c9d7073716df6813cc892a0abe7d3188c9a279b\"},{\"path\":\"SOURCE_STORAGE_PREPARED.json\",\"bytes\":7360,\"sha256\":\"1f21b056271a04d2c1146687cdb4c65e0fed3f8c7853912daabdb64854c8d73c\"},{\"path\":\"SOURCE_STORAGE_README.md\",\"bytes\":1698,\"sha256\":\"d584b29948a78ea7ad0f515e806418f5c4e78642fbc3338705bf736080593a8d\"},{\"path\":\"RETIRE_PRESERVED_SOURCES.py\",\"bytes\":10986,\"sha256\":\"a54c32e758dc2fb27e22bd4822299ea49b92200a5a9ec980f8057d2c799a41ce\"},{\"path\":\"RETIRE_PRESERVED_SOURCES_REVIEW2.py\",\"bytes\":13502,\"sha256\":\"0a89e349e9f0b02a9d1c6c7a7632cc47430b72afbcd0b489206780daf7a1651f\"}]")
def need(x,m):
 if not x:raise RuntimeError(m)
def sha(b):return hashlib.sha256(b).hexdigest()
def ident(s):return(s.st_dev,s.st_ino,s.st_mode,s.st_uid,s.st_gid,s.st_nlink,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def read(p,pin=None):
 need(p.resolve(strict=True)==p,'Exact source path')
 s=p.lstat();need(stat.S_ISREG(s.st_mode)and s.st_nlink==1 and s.st_size<=1048576,'Bounded single regular source')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
 try:
  need(ident(os.fstat(fd))==ident(s),'Open identity')
  with os.fdopen(os.dup(fd),'rb')as f:b=f.read(s.st_size+1)
  need(len(b)==s.st_size and ident(os.fstat(fd))==ident(s),'Full stable read')
 finally:os.close(fd)
 need(ident(p.lstat())==ident(s),'Stable path')
 if pin:need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Exact source pin')
 return b
commands=[]
def cmd(argv,binary=False):
 p=subprocess.run(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90)
 row={'argv':argv,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row);need(p.returncode==0,'Bounded command failed: '+str(row))
 return p.stdout
def git(*args,binary=False):
 return cmd(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','-C',str(ROOT),*args],binary)
need(shutil.disk_usage('/').free>=1593835520+8388608,'Root documentation reserve')
need(not DEST.exists() and not OUT.exists(),'Exclusive docs checkpoint')
need(git('rev-parse','HEAD').decode().strip()==BEFORE and git('status','--porcelain=v1','-z')==b'','Exact clean predecessor')
need(git('branch','--show-current').decode().strip()==BRANCH and git('remote','get-url','origin').decode().strip()=='https://github.com/davidpovarsky/Maktabah.git','Exact project branch/origin')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Source tree unchanged')
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
files={p['path']:read(INPUT/p['path'],p)for p in PINS}
prep=json.loads(files['SOURCE_STORAGE_PREPARED.json'])
need(prep['status']=='ADDITIVE_SOURCE_PREPARATION_NO_RAW_RETIREMENT','Prepared sources only')
need(not os.path.lexists(INPUT/'SOURCE_STORAGE_RETIRED.json') and not os.path.lexists(INPUT/'runs/mac-candidate'),'No retirement or candidate yet')
for name,pin in prep['originalSourcePins'].items():read(INPUT/name,pin)
for pin in prep['phaseEvidencePins']:read(INPUT/pin['path'],pin)
with zipfile.ZipFile(io.BytesIO(files['HISTORICAL_SOURCES.zip']))as z:
 mr=z.read('MANIFEST.json');need(len(mr)==prep['manifest']['bytes']and sha(mr)==prep['manifest']['sha256'],'Complete archived metadata')
 manifest=json.loads(mr);entries=manifest['entries']
 need(len(z.infolist())==15 and len(entries)==14 and set(z.namelist())=={r['name']for r in entries}|{'MANIFEST.json'},'Exact archived source membership')
 for row in entries:
  b=z.read(row['name']);need(len(b)==row['bytes']and sha(b)==row['sha256'],'Complete member readback')
  need(read(INPUT/row['name'])==b,'Original raw source rejoined')
proof={'schema':'otzaria.focused-source-storage-doc-intake/1','status':'EXACT_PRESERVATION_PREPARED_FOR_GIT','before':BEFORE,'source':SOURCE,'inputs':PINS,'historicalSourceMembers':14,'fullMembersRejoined':14,'archivedMetadataSHA256':sha(mr),'original22SourcesVerified':True,'all20PhaseFilesVerified':True,'originalRaw14StillPresent':True,'resolverExecuted':False,'retirementExecuted':False,'initialRetirementSourceRetained':True,'review2OwnRecordReserve':8192,'originalTestOutputCapsUnchanged':True,'macCandidateRun':False,'originalSourceAndOutputCapsUnchanged':True,'newTests':0,'productChanges':0,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
files['INPUT_MANIFEST.json']=(json.dumps(PINS,indent=2,sort_keys=True)+'\n').encode()
files['ROOT_INTAKE_PROOF.json']=(json.dumps(proof,indent=2,sort_keys=True)+'\n').encode()
files['INTAKE.py']=pathlib.Path(__file__).read_bytes()
need(len(files)==10 and sum(map(len,files.values()))<524288,'Bounded ten-file docs packet')
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
def write(p,b):
 parents=[];q=p.parent
 while not q.exists():parents.append(q);q=q.parent
 for d in reversed(parents):d.mkdir(mode=0o750);os.chown(d,1001,1001)
 f=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o640)
 try:
  v=memoryview(b)
  while v:
   n=os.write(f,v);need(n>0,'Full docs write');v=v[n:]
  os.fsync(f);os.fchown(f,1001,1001)
 finally:os.close(f)
 need(read(p)==b,'Exact docs readback')
try:
 for name,b in files.items():write(DEST/name,b)
 names=[REL+'/'+n for n in sorted(files)]
 git('add','--sparse','-f','--',*names)
 need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0')if x)==names,'Only exact docs additions staged')
 git('diff','--cached','--check')
 for name,b in files.items():need(git('show',':'+REL+'/'+name,binary=True)==b,'Full index byte join')
 git('commit','-m','docs: preserve exact focused sources before bounded storage migration')
 after=git('rev-parse','HEAD').decode().strip();need(git('rev-parse','HEAD^').decode().strip()==BEFORE,'Exact docs parent')
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0]for x in git('ls-tree','-z','HEAD').split(b'\0')if x}
 need(set(top_after)==set(top_before)and all(top_before[k]==top_after[k]for k in top_before if k!=b'docs'),'All non-docs trees unchanged')
 need(git('status','--porcelain=v1','-z')==b'' and git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Clean unchanged product')
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 remote=git('-c','credential.helper=!gh auth git-credential','ls-remote','--heads','origin','refs/heads/'+BRANCH).decode().strip()
 need(remote.split()[0]==after,'Remote branch readback')
 blob=git('rev-parse',after+':'+REL+'/HISTORICAL_SOURCES.zip').decode().strip()
 apiraw=cmd(['sudo','-u','ubuntu','-H','gh','api','repos/davidpovarsky/Maktabah/git/blobs/'+blob],binary=True)
 need(len(apiraw)<=262144,'Bounded complete remote blob response')
 obj=json.loads(apiraw);need(obj['encoding']=='base64'and obj['sha']==blob and obj['size']==len(files['HISTORICAL_SOURCES.zip']),'Exact remote blob fields')
 payload=base64.b64decode(''.join(obj['content'].splitlines()),validate=True)
 need(payload==files['HISTORICAL_SOURCES.zip']and hashlib.sha1(b'blob '+str(len(payload)).encode()+b'\0'+payload).hexdigest()==blob,'Full durable remote archive byte readback')
 result={'schema':'otzaria.focused-source-storage-doc-commit/1','status':'COMMITTED_PUSHED_FULL_REMOTE_ARCHIVE_READBACK','before':BEFORE,'after':after,'branch':BRANCH,'sourceUnchanged':SOURCE,'allNonDocsTopTreesUnchanged':True,'files':10,'archiveBytes':len(payload),'archiveSHA256':sha(payload),'archiveGitBlob':blob,'fullRemoteArchiveReadback':True,'proofSHA256':sha(files['ROOT_INTAKE_PROOF.json']),'inputManifestSHA256':sha(files['INPUT_MANIFEST.json']),'controllerSHA256':sha(files['INTAKE.py']),'originalRaw14Retired':False,'testsRun':0,'remote':remote,'completedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rootFree':shutil.disk_usage('/').free,'oracleDataFree':shutil.disk_usage('/mnt/development').free}
 write(OUT/'RESULT.json',(json.dumps(result,indent=2,sort_keys=True)+'\n').encode())
 write(OUT/'COMMANDS.json',(json.dumps(commands,indent=2,sort_keys=True)+'\n').encode())
 print(json.dumps(result))
except BaseException as e:
 write(OUT/'FAILED.json',(json.dumps({'type':type(e).__name__,'error':str(e),'commands':commands,'at':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2,sort_keys=True)+'\n').encode())
 raise
