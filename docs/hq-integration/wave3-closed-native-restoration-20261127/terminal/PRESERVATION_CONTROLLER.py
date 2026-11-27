"""Preserve the actual single-leaf retirement and retain its restoration join."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')
from pathlib import Path
import datetime, hashlib, json, os, stat, subprocess
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='643252b92482cdaea33ab22067749577f6a07399'
BRANCH='codex/otzaria-wave3-integration-20261127'
REL='docs/hq-integration/wave3-closed-native-restoration-20261127/terminal'
OUT=ROOT/REL
PREP=Path('/home/ubuntu/otzaria-wave3-private-evidence-publication-20261127/retire-4e93087e-2565-441f-a6cb-9d33296cc916')
TOOLS=Path('/home/ubuntu/otzaria-wave3-private-archive-tools-20261127')
TRANSFER=Path('/home/ubuntu/otzaria-wave3-retirement-result-proof-20261127')
RESULT_SHA='b0ec2a6446e0eab758eb33cd8dc1ad5e07a388a9f7a423022f50f9d733a28398'
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
assert result['status']=='ONE_EXACT_PRIVATELY_PRESERVED_ARCHIVE_LEAF_RETIRED' and result['removed'] is True
assert result['protectedMetadataSiblings']==22 and not os.path.lexists(result['solePath'])
assert result['ackPREDELETE']=='31be7ad1aeb4f672059edac8b57c04429da38f495eef0fb7aacc0401ff1486f5'
assert result['privateFullReadbackProof']=='c8eb38f53a7b704587523d330c1c1ac63a2dd17cf49900cebb7a9406b545c1ed'
assert result['SDKBuilds']==result['nativeRuns']==0 and result['remoteChanges'] is False
assert sha((PREP/'RESTORATION_POINTER.json').read_bytes())=='e89db2f5ee59d9dbc466eeffbc43beb64f145aa823a3071aa08d48424b3dbabc'
pre=json.loads((PREP/'PREDELETE.json').read_bytes())
source=Path(result['solePath']).parent
assert set(os.listdir(source))=={r['name'] for r in pre['protectedSiblings']}
for row in pre['protectedSiblings']:
    p=source/row['name'];s=p.lstat()
    assert stat.S_ISREG(s.st_mode) and s.st_nlink==1
    assert {'device':s.st_dev,'inode':s.st_ino,'size':s.st_size,'mtime_ns':s.st_mtime_ns,'ctime_ns':s.st_ctime_ns}==row['identity']
payload={}
for p in PREP.iterdir():
    if p.name.startswith(('1001-','1002-','COMMIT_','RETIREMENT_')):
        assert p.is_file() and not p.is_symlink() and p.stat().st_size<1048576
        payload['actual/'+p.name]=p.read_bytes()
for name in ('ROOT_GIT_ACKNOWLEDGEMENT.json','COMMIT.stdout','COMMIT.stderr'):
    payload['transport/'+name]=(TOOLS/name).read_bytes()
payload['transport/ACTUAL_SENTINEL_RETIREMENT_RESULT.json']=(TRANSFER/'ACTUAL_SENTINEL_RETIREMENT_RESULT.json').read_bytes()
job=json.loads(payload['transport/ACTUAL_SENTINEL_RETIREMENT_RESULT.json'])['job']
assert job['id']=='job_157aaaf99df2' and job['status']=='succeeded' and job['exit_code']==0
assert not OUT.exists()
for name,b in payload.items():write(OUT/name,b)
write(OUT/'PRESERVATION_CONTROLLER.py',Path(__file__).read_bytes())
proof={'schema':'otzaria.exact-archive-retirement-terminal-preservation.v1','status':'ACTUAL_RETIREMENT_RECEIPT_PRESERVED',
    'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'integrationBase':BASE,'retirementResultSHA256':RESULT_SHA,
    'actualJob':'job_157aaaf99df2','allNonDocumentationRootEntries':non_docs,'protectedMetadataSiblings':22,
    'sourceLeafAbsent':True,'restorationActualRuns':0,'SDKBuilds':0,'nativeRuns':0,
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
git('add','--sparse','--force','--',REL)
changed=git('diff','--cached','--name-only').decode().splitlines()
assert changed and all(p.startswith(REL+'/') for p in changed)
git('diff','--cached','--check')
git('-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','commit','-m','docs: preserve exact private archive retirement and restoration evidence')
head=git('rev-parse','HEAD').decode().strip()
assert [x for x in git('ls-tree','HEAD').decode().splitlines() if x.split('\t',1)[1]!='docs']==non_docs
assert git('status','--porcelain=v1','--untracked-files=all')==b''
git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH,timeout=120)
out={'status':'TERMINAL_RETIREMENT_EVIDENCE_COMMITTED_PUSHED','head':head,'changedPaths':len(changed),
     'sourceTreeUnchanged':True,'preservationSHA256':sha((OUT/'PRESERVATION.json').read_bytes()),
     'rootFreeAfter':free('/'),'dataFreeObservedAfter':free('/mnt/development'),'SDKBuilds':0,'nativeRuns':0}
write(TRANSFER/'GIT_RESULT.json',(json.dumps(out,indent=2)+'\n').encode())
print(json.dumps(out))
