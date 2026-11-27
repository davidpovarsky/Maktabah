"""Preserve the actual single-leaf retirement and retain its restoration join."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')
from pathlib import Path
import datetime, hashlib, json, os, stat, subprocess
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='e3b780e2648f0cd221eedda5fc79524ae3b99b4d'
BRANCH='codex/otzaria-wave3-integration-20261127'
REL='docs/hq-integration/wave3-session-pair-restoration-20261127/terminal'
OUT=ROOT/REL
PREP=Path('/home/ubuntu/otzaria-wave3-private-session-pair-publication-20261127/retire-f0d875eb-2b71-49af-a2f9-1f2f7b85c792')
TOOLS=Path('/home/ubuntu/otzaria-wave3-session-pair-restoration-tools-20261127')
TRANSFER=Path('/home/ubuntu/otzaria-wave3-session-pair-retirement-result-proof-20261127')
RESULT_SHA='a7823fc706c1a2cd9b9765df59f0e5688b87f3ccbe4c93b99831b004de56f329'
def sha(b):return hashlib.sha256(b).hexdigest()
def free(p):
    s=os.statvfs(p);return s.f_bavail*s.f_frsize
def git(*args,timeout=60):
    r=subprocess.run(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-C',str(ROOT),*args],capture_output=True,timeout=timeout)
    if r.returncode:raise RuntimeError((args,r.returncode,r.stdout.decode(errors='replace')[:3000],r.stderr.decode(errors='replace')[:3000]))
    return r.stdout
def write(p,b):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(b);f.flush();os.fsync(f.fileno())
    os.chown(p,1001,1001)
assert free('/')>=1593835520
assert git('rev-parse','HEAD').decode().strip()==BASE
assert git('branch','--show-current').decode().strip()==BRANCH
assert git('status','--porcelain=v1','--untracked-files=all')==b''
non_docs=[x for x in git('ls-tree','HEAD').decode().splitlines() if x.split('\t',1)[1]!='docs']
raw=(PREP/'RETIREMENT_RESULT.json').read_bytes();assert sha(raw)==RESULT_SHA
result=json.loads(raw)
assert result['status']=='ONE_EXACT_PRIVATELY_PRESERVED_DIFFERENTIAL_LEAF_RETIRED' and result['removed'] is True
assert result['protectedMetadataSiblings']==12 and not os.path.lexists(result['solePath'])
assert result['ackPREDELETE']=='93738162a5ffc0f36cffe31eb2638cfa37081140477536ba9355a4f892c043ba'
assert result['privateFullReadbackProof']=='0c07d1c5b25136331d7790f88436aef3a3d7aef5b82e4cd23ca61ba848ffb05a'
assert result['SDKBuilds']==result['nativeRuns']==0 and result['remoteChanges'] is False
assert result['selfContained'] is False and result['fullTreeRestoration'] is False and result['windowsAccess'] is False
assert sha((PREP/'RESTORATION_POINTER.json').read_bytes())=='82f75ca26fcd83af71031383168879ad774153d8fad2fddee96be68b908471db'
pre=json.loads((PREP/'PREDELETE.json').read_bytes())
source=Path(result['solePath']).parent
assert set(os.listdir(source))=={r['name'] for r in pre['protectedSiblings']}
for row in pre['protectedSiblings']:
    p=source/row['name'];s=p.lstat()
    assert stat.S_ISREG(s.st_mode) and s.st_nlink==1
    assert {'device':s.st_dev,'inode':s.st_ino,'bytes':s.st_size,'uid':s.st_uid,'gid':s.st_gid,'mode':stat.S_IMODE(s.st_mode),'nlink':s.st_nlink,'mtime_ns':str(s.st_mtime_ns),'ctime_ns':str(s.st_ctime_ns)}==row['identity']
payload={}
for p in PREP.iterdir():
    if p.name.startswith(('1001-','1002-','COMMIT_','RETIREMENT_')):
        assert p.is_file() and not p.is_symlink() and p.stat().st_size<1048576
        payload['actual/'+p.name]=p.read_bytes()
for name in ('ROOT_ACKNOWLEDGEMENT.json',):
    payload['transport/'+name]=(TOOLS/name).read_bytes()
payload['transport/ACTUAL_SENTINEL_RETIREMENT_RESULT.json']=(TRANSFER/'ACTUAL_SENTINEL_RETIREMENT_RESULT.json').read_bytes()
payload['transport/INDEPENDENT_GIT_READBACK.json']=(TRANSFER/'INDEPENDENT_GIT_READBACK.json').read_bytes()
readback=json.loads(payload['transport/INDEPENDENT_GIT_READBACK.json'])['job']
assert readback['id']=='job_947ea99b063e' and readback['status']=='succeeded' and readback['exit_code']==0
job=json.loads(payload['transport/ACTUAL_SENTINEL_RETIREMENT_RESULT.json'])['job']
assert job['id']=='job_e8a1b542788c' and job['status']=='succeeded' and job['exit_code']==0
assert not OUT.exists()
for name,b in payload.items():write(OUT/name,b)
write(OUT/'PRESERVATION_CONTROLLER.py',Path(__file__).read_bytes())
proof={'schema':'otzaria.exact-session-pair-retirement-terminal-preservation.v1','status':'ACTUAL_RETIREMENT_RECEIPT_PRESERVED',
    'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'integrationBase':BASE,'retirementResultSHA256':RESULT_SHA,
    'actualJob':'job_e8a1b542788c','allNonDocumentationRootEntries':non_docs,'protectedMetadataSiblings':12,
    'sourceLeafAbsent':True,'restorationActualRuns':0,'SDKBuilds':0,'nativeRuns':0,'selfContained':False,'fullTreeRestoration':False,
    'unchangedExternalDependencies':result['unchangedExternalDependencies'],
    'freeBeforeRetirement':result['freeBefore'],'freeAfterRetirement':result['freeAfter'],
    'capacityScope':'Concurrent observations. Source-control admission always uses fresh unchanged floors.',
    'files':[{'path':n,'bytes':len(b),'sha256':sha(b)} for n,b in sorted(payload.items())]}
write(OUT/'PRESERVATION.json',(json.dumps(proof,indent=2)+'\n').encode())
for parent,dirs,files in os.walk(OUT):
    os.chown(parent,1001,1001)
    for name in dirs:os.chown(Path(parent)/name,1001,1001)
    fd=os.open(parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:os.fsync(fd)
    finally:os.close(fd)
assert free('/')>=1593835520
paths=sorted(str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file())
check=subprocess.run(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false','-C',str(ROOT),'check-ignore','-z','--stdin'],input=('\0'.join(paths)+'\0').encode(),capture_output=True,timeout=15)
assert check.returncode in (0,1)
ignored=set(check.stdout.decode().split('\0'))-{''}
ordinary=[p for p in paths if p not in ignored]
if ordinary:git('add','--sparse','--',*ordinary)
if ignored:git('add','--sparse','--force','--',*sorted(ignored))
changed=git('diff','--cached','--name-only').decode().splitlines()
assert set(changed)==set(paths) and all(p.startswith(REL+'/') for p in changed)
git('diff','--cached','--check')
git('-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','commit','-m','docs: preserve exact session-pair retirement and restoration evidence')
head=git('rev-parse','HEAD').decode().strip()
assert [x for x in git('ls-tree','HEAD').decode().splitlines() if x.split('\t',1)[1]!='docs']==non_docs
assert git('status','--porcelain=v1','--untracked-files=all')==b''
git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH,timeout=120)
out={'status':'TERMINAL_RETIREMENT_EVIDENCE_COMMITTED_PUSHED','head':head,'changedPaths':len(changed),
     'sourceTreeUnchanged':True,'preservationSHA256':sha((OUT/'PRESERVATION.json').read_bytes()),
     'rootFreeAfter':free('/'),'dataFreeObservedAfter':free('/mnt/development'),'SDKBuilds':0,'nativeRuns':0}
write(TRANSFER/'GIT_RESULT.json',(json.dumps(out,indent=2)+'\n').encode())
print(json.dumps(out))
