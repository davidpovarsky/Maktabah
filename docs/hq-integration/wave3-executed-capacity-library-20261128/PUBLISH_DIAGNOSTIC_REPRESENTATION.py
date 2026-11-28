import os,pathlib,json,hashlib,stat,subprocess,base64,datetime,time,re,zipfile,io
os.umask(0o077)
ROOT=pathlib.Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
OUT=pathlib.Path('/home/ubuntu/otzaria-wave3-executed-capacity-library-git-json-20261128')
REL='docs/hq-integration/wave3-executed-capacity-library-20261128'
DEST=ROOT/REL
BEFORE='607bd0a77009ad3495320a96761a60901928f26a'
SOURCE='182dd74229c04959cecae82a59d16268dcbd80bc'
BRANCH='codex/otzaria-wave3-integration-20261127'
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
 need(p.resolve(strict=True)==p,'Exact canonical input')
 fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NOATIME)
 try:
  s=os.fstat(fd);need(stat.S_ISREG(s.st_mode) and s.st_nlink==1 and s.st_size<=2097152,'Bounded regular single-link input')
  b=os.pread(fd,2097153,0)
  need(len(b)==s.st_size and stable(os.fstat(fd))==stable(s) and stable(p.lstat())==stable(s),'Stable complete source')
  if pin:need(len(b)==pin['bytes'] and sha(b)==pin['sha256'],'Exact source bytes/hash: '+str(p))
  return b
 finally:os.close(fd)
def guard():
 need(time.monotonic()-started<900,'Publication deadline')
 need(free()>=FLOOR+8388608,'Original Root reserve plus remaining documentation allowance')
def cmd(argv,binary=False):
 guard()
 env=os.environ.copy();env['GIT_OPTIONAL_LOCKS']='0'
 p=subprocess.run(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=90,env=env)
 need(len(p.stdout)<=2097152 and len(p.stderr)<=65536,'Bounded command output')
 row={'argv':argv,'exit':p.returncode,'stdoutBytes':len(p.stdout),'stdoutSHA256':sha(p.stdout),'stderrBytes':len(p.stderr),'stderrSHA256':sha(p.stderr)}
 if not binary and len(p.stdout)<=16384:row['stdout']=p.stdout.decode('utf-8','replace')
 if len(p.stderr)<=16384:row['stderr']=p.stderr.decode('utf-8','replace')
 commands.append(row);need(p.returncode==0,'Publication command failed')
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
 fd=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o640)
 try:
  os.fchown(fd,1001,1001);v=memoryview(b)
  while v:
   n=os.write(fd,v);need(n>0,'Complete documentation write');v=v[n:]
  os.fsync(fd)
 finally:os.close(fd)
 fd=os.open(p.parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
 try:os.fsync(fd)
 finally:os.close(fd)
 need(read(p)==b,'Written bytes verified')
def permitted_text_bytes(b,label,depth=0):
 for pat in [rb'gh[pousr]_[A-Za-z0-9_]{30,}',rb'github_pat_[A-Za-z0-9_]{30,}',rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',rb'"temp_clone_token"\s*:\s*"[^"]{10,}"']:
  need(re.search(pat,b) is None,'Sensitive literal refused from documentation: '+label)
 if b.startswith(b'PK\x03\x04'):
  need(depth<3,'Bounded nested source archive')
  with zipfile.ZipFile(io.BytesIO(b)) as z:
   need(len(z.infolist())<=2000 and sum(i.file_size for i in z.infolist())<=16777216,'Bounded source archive inspection')
   for i in z.infolist():
    need(not i.filename.startswith('/') and '..' not in pathlib.PurePosixPath(i.filename).parts,'Source archive name')
    if not i.is_dir():permitted_text_bytes(z.read(i),label+'!'+i.filename,depth+1)
need(os.geteuid()==0 and 'GH_DEBUG' not in os.environ and not any(k.startswith('GIT_TRACE') or k=='GIT_CURL_VERBOSE' for k in os.environ),'Non-debug Root executor')
PREV=pathlib.Path('/home/ubuntu/otzaria-wave3-executed-capacity-library-git-representation-20261128')
ORIGINAL=pathlib.Path('/home/ubuntu/otzaria-wave3-executed-capacity-library-git-intake-20261128/INITIAL_DOCUMENTATION_BYTES')
need(not os.path.lexists(OUT) and free()>=FLOOR+16777216,'Fresh bounded JSON continuation')
failure=read(PREV/'FAILED.json',{'bytes':143002,'sha256':'c74fb8ce0d2cde4090aeba6c027caad4ec5ae94a546a19172318d5a6c7e3e856'})
need(git('rev-parse','HEAD').decode().strip()==BEFORE and git('branch','--show-current').decode().strip()==BRANCH,'Exact parent/branch')
need(git('rev-parse','HEAD:Source').decode().strip()==SOURCE and git('diff','--name-only','-z')==b'','Only owned staged docs')
expected={'EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip','ORIGINAL_FILES.json','ACTUAL_SOURCE_CONTROL_SUMMARY.json','NATIVE_POST_TIMEOUT_SAFE_OBSERVATION.json','INITIAL_WHITESPACE_DIAGNOSTIC.txt','FIRST_CHECKPOINT_FAILURE.json','REPRESENTATION_DECISION.json','README.md','PUBLISH_REPRESENTATION.py'}
docs={str(p.relative_to(DEST)):read(p) for p in DEST.rglob('*') if p.is_file()}
need(set(docs)==expected,'Exact second-attempt9 files')
staged=sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0') if x)
need(staged==sorted(REL+'/'+n for n in docs),'Exact owned staging')
for n,b in docs.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Complete original index bytes')
diagnostic=docs['INITIAL_WHITESPACE_DIAGNOSTIC.txt']
need(len(diagnostic)==17900 and sha(diagnostic)=='273a16a7ec7aa2db5bebe23ffa2c340d38b9943fbada7a7965aa49a286b9d659','Exact diagnostic text')
inventory=json.loads(docs['ORIGINAL_FILES.json']);need(inventory['originalCount']==105 and len(inventory['files'])==105,'Exact105 original files')
archive=docs['EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip']
need(sha(archive)==inventory['archive']['sha256'] and len(archive)==inventory['archive']['bytes'],'Exact archived representation')
with zipfile.ZipFile(io.BytesIO(archive)) as z:
 need(z.testzip() is None and set(z.namelist())==set(inventory['files']),'Complete archive membership')
 for n,pin in inventory['files'].items():need(z.read(n)==read(ORIGINAL/n,pin),'Exact original105 byte replay')
top_before={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
OUT.mkdir(mode=0o750);os.chown(OUT,1001,1001)
try:
 old_readme=docs['README.md']
 new_readme=old_readme.replace(b'INITIAL_WHITESPACE_DIAGNOSTIC.txt',b'INITIAL_WHITESPACE_DIAGNOSTIC.json')
 new_readme+=b'\nThe raw initial whitespace diagnostic is stored losslessly as base64 in its\nJSON wrapper. Its decoded bytes and hash remain exact; the unencoded copy and\nthe second diagnostic-publication refusal are retained privately and recorded.\n'
 wrapper=canon({'schema':'otzaria.raw-diagnostic/1','originalName':'INITIAL_WHITESPACE_DIAGNOSTIC.txt','bytes':len(diagnostic),'sha256':sha(diagnostic),'encoding':'base64','rawBase64':base64.b64encode(diagnostic).decode('ascii')})
 need(base64.b64decode(json.loads(wrapper)['rawBase64'],validate=True)==diagnostic,'Exact diagnostic representation')
 write(OUT/'SECOND_ATTEMPT_README.md',old_readme)
 git('restore','--staged','--',REL+'/INITIAL_WHITESPACE_DIAGNOSTIC.txt')
 os.rename(DEST/'INITIAL_WHITESPACE_DIAGNOSTIC.txt',OUT/'SECOND_ATTEMPT_DIAGNOSTIC.txt')
 os.rename(DEST/'README.md',OUT/'SECOND_ATTEMPT_README_ORIGINAL.md')
 for p in [DEST,OUT]:
  fd=os.open(p,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW);os.fsync(fd);os.close(fd)
 del docs['INITIAL_WHITESPACE_DIAGNOSTIC.txt']
 docs['README.md']=new_readme;docs['INITIAL_WHITESPACE_DIAGNOSTIC.json']=wrapper
 docs['SECOND_CHECKPOINT_FAILURE.json']=failure
 docs['DIAGNOSTIC_REPRESENTATION_FIX.json']=canon({'schema':'otzaria.raw-diagnostic-representation-fix/1','priorJob':'job_81e2d468e995','priorFailureSHA256':sha(failure),'priorFailureStage':'unchanged git diff--cached--check','onlyWhitespaceOffender':'INITIAL_WHITESPACE_DIAGNOSTIC.txt','originalDiagnosticSHA256':sha(diagnostic),'newJSONDecodedBytesExact':True,'normalGitChecksAndHooksRetained':True,'previousSourceArchiveUnchanged':inventory['archive'],'testsRepeated':0,'sourceChanged':False,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
 docs['PUBLISH_DIAGNOSTIC_REPRESENTATION.py']=pathlib.Path(__file__).read_bytes()
 for n in ['README.md','INITIAL_WHITESPACE_DIAGNOSTIC.json','SECOND_CHECKPOINT_FAILURE.json','DIAGNOSTIC_REPRESENTATION_FIX.json','PUBLISH_DIAGNOSTIC_REPRESENTATION.py']:
  permitted_text_bytes(docs[n],n);write(DEST/n,docs[n])
 final_names=sorted(REL+'/'+n for n in docs)
 git('add','--sparse','-f','--',*final_names)
 need(sorted(x for x in git('diff','--cached','--name-only','-z').decode().split('\0') if x)==final_names,'Exact final documentation staging')
 git('diff','--cached','--check')
 for n,b in docs.items():need(git('show',':'+REL+'/'+n,binary=True)==b,'Exact final index bytes')
 git('commit','-m','docs: preserve actual capacity and Library35 evidence with exact source archive')
 after=git('rev-parse','HEAD').decode().strip();need(git('rev-parse','HEAD^').decode().strip()==BEFORE,'Exact parent')
 top_after={x.split(b'\t',1)[1]:x.split(b'\t',1)[0] for x in git('ls-tree','-z','HEAD').split(b'\0') if x}
 need(set(top_after)==set(top_before) and all(top_before[k]==top_after[k] for k in top_before if k!=b'docs'),'All non-doc trees exact')
 need(git('status','--porcelain=v1','-z')==b'' and git('rev-parse','HEAD:Source').decode().strip()==SOURCE,'Clean unchanged source')
 git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH)
 ref=api('repos/davidpovarsky/Maktabah/git/ref/heads/'+BRANCH);need(ref['object']['type']=='commit' and ref['object']['sha']==after,'Exact remote branch')
 remote={}
 for n,b in docs.items():
  oid=git('rev-parse',after+':'+REL+'/'+n).decode().strip();v=api('repos/davidpovarsky/Maktabah/git/blobs/'+oid)
  need(v['sha']==oid and v['encoding']=='base64' and v['size']==len(b),'Exact Git envelope')
  decoded=base64.b64decode(''.join(v['content'].split()),validate=True)
  need(decoded==b and hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==oid,'Complete authenticated Git bytes')
  if n=='EXECUTED_SOURCE_AND_EVIDENCE_RAW.zip':
   with zipfile.ZipFile(io.BytesIO(decoded)) as z:
    need(z.testzip() is None and set(z.namelist())==set(inventory['files']),'Remote archive CRC/membership')
    for member,pin in inventory['files'].items():need(z.read(member)==read(ORIGINAL/member,pin),'Remote105 original payload bytes')
  if n=='INITIAL_WHITESPACE_DIAGNOSTIC.json':need(base64.b64decode(json.loads(decoded)['rawBase64'],validate=True)==diagnostic,'Remote decoded raw diagnostic exact')
  remote[n]={'path':REL+'/'+n,'bytes':len(b),'sha256':sha(b),'gitBlob':oid}
 proof=canon({'schema':'otzaria.executed-capacity-library-git/3','commit':after,'branch':BRANCH,'source':SOURCE,'files':remote,'all105OriginalArchivePayloadsFullRemoteReadback':True})
 write(OUT/'FULL_REMOTE_READBACK.json',proof);write(OUT/'COMMANDS.json',canon(commands))
 result={'status':'COMMITTED_PUSHED_ALL_FILES_AND105_ORIGINALS_FULL_READBACK','before':BEFORE,'after':after,'sourceUnchanged':SOURCE,'allNonDocsTopTreesUnchanged':True,'fileCount':len(docs),'originalFiles':105,'sourcePacketFiles':92,'archiveBytes':len(archive),'archiveSHA256':sha(archive),'proof':{'path':str(OUT/'FULL_REMOTE_READBACK.json'),'bytes':len(proof),'sha256':sha(proof)},'bothInitialFailuresPreserved':True,'newTestsRun':0,'rootFree':free(),'dataFree':free('/mnt/development'),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
 write(OUT/'RESULT.json',canon(result));print(json.dumps(result))
except BaseException as e:
 write(OUT/'FAILED.json',canon({'errorType':type(e).__name__,'message':str(e),'commands':commands,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}));raise
