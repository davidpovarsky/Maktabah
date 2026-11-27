"""Preserve raw patch bytes by encoding, then finish the unchanged proof commit."""
if not __debug__:
    raise RuntimeError('Optimized Python forbidden')
from pathlib import Path
import base64, hashlib, json, os, subprocess
ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
REL = 'docs/hq-integration/wave3-closed-native-restoration-20261127'
OUT = ROOT / REL
TRANSFER = Path('/home/ubuntu/otzaria-wave3-restoration-proof-20261127')
BASE = '3a665ae5d4a6ff0db78b356a5362d93e0f0fe408'
BRANCH = 'codex/otzaria-wave3-integration-20261127'
PATCHES = {
    'review/review/initial-tools-before-optimized-python-refusal/restore_closed_native_archive.py.patch': '564cf37b1adf772d986d46517a76f27c4d737a6f008f0395bb5dbf3b829efb49',
    'review/review/initial-tools-before-optimized-python-refusal/retire_closed_native_archive.py.patch': '47a8144c0750e2e1ae1b9b101ba8b4395d05d03efd34a616994ae544bd99c23d'}
def sha(b): return hashlib.sha256(b).hexdigest()
def raw_git(*args, timeout=60):
    return subprocess.run(['sudo','-u','ubuntu','-H','git','-c','gc.auto=0','-c','maintenance.auto=false',
                           '-C',str(ROOT),*args],capture_output=True,timeout=timeout)
def git(*args, timeout=60):
    p=raw_git(*args,timeout=timeout)
    if p.returncode: raise RuntimeError((args,p.returncode,p.stdout.decode(errors='replace')[:3000],p.stderr.decode(errors='replace')[:3000]))
    return p.stdout
def write(path,b):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('xb') as f: f.write(b);f.flush();os.fsync(f.fileno())
    os.chown(path,1001,1001)
def free(path):
    s=os.statvfs(path);return s.f_bavail*s.f_frsize
assert free('/') >= 1593835520
assert git('rev-parse','HEAD').decode().strip()==BASE
assert git('branch','--show-current').decode().strip()==BRANCH
paths=git('diff','--cached','--name-only').decode().splitlines()
assert paths and all(p.startswith(REL+'/') for p in paths)
assert git('diff','--name-only')==b''
record_raw=(OUT/'PRESERVATION.json').read_bytes()
record=json.loads(record_raw)
original_top=record['allNonDocumentationRootEntries']
assert [r for r in git('ls-tree','HEAD').decode().splitlines() if r.split('\t',1)[1]!='docs']==original_top
check=raw_git('diff','--cached','--check')
assert check.returncode==2 and not check.stderr
warnings=check.stdout.decode().splitlines()
assert warnings
diagnostics=[r for r in warnings if not r.startswith('+') and r]
assert diagnostics and all(any(r.startswith(REL+'/'+p+':') for p in PATCHES) and r.endswith(': trailing whitespace.') for r in diagnostics),warnings
write(OUT/'review/INITIAL_DOCUMENTATION_CHECK_FAILURE.json',(json.dumps({'actualExit':check.returncode,'stdout':check.stdout.decode(),
    'stderr':check.stderr.decode(),'initialJob':'job_78e0a9100aa5','scope':'Raw unified-diff context whitespace; original bytes will be preserved in base64. Product/tests and the whitespace gate remain unchanged.'},indent=2)+'\n').encode())
write(OUT/'review/PRESERVATION_BEFORE_PATCH_ENCODING.json',record_raw)
encodings=[]
for rel,expected in PATCHES.items():
    p=OUT/rel;b=p.read_bytes();assert sha(b)==expected
    encoded=base64.encodebytes(b)
    write(OUT/(rel+'.base64'),encoded)
    assert base64.decodebytes((OUT/(rel+'.base64')).read_bytes())==b
    write(TRANSFER/('raw-'+p.name),b)
    assert (TRANSFER/('raw-'+p.name)).read_bytes()==b
    p.unlink()
    encoding={'path':rel,'originalBytes':len(b),'originalSHA256':expected,'storedPath':rel+'.base64',
              'storedBytes':len(encoded),'storedSHA256':sha(encoded),'encoding':'base64','decodedBytesVerified':True}
    encodings.append(encoding)
    matched=[r for r in record['files'] if r['path']==rel]
    assert len(matched)==1 and matched[0]['sha256']==expected
    matched[0].update({'storedPath':rel+'.base64','storedBytes':len(encoded),'storedSHA256':sha(encoded),'encoding':'base64'})
record['rawPatchRepresentations']=encodings
record['documentationCorrection']='Raw unified-diff context whitespace is losslessly encoded; both original script drafts and the initial actual check failure remain preserved. Whitespace validation still runs.'
temporary=OUT/'PRESERVATION.corrected.json'
write(temporary,(json.dumps(record,indent=2)+'\n').encode())
os.replace(temporary,OUT/'PRESERVATION.json')
write(OUT/'CORRECTION_CONTROLLER.py',Path(__file__).read_bytes())
for parent,dirs,files in os.walk(OUT):
    os.chown(parent,1001,1001)
    for n in dirs: os.chown(Path(parent)/n,1001,1001)
    fd=os.open(parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:os.fsync(fd)
    finally:os.close(fd)
git('add','--sparse','--all','--force','--',REL)
changed=git('diff','--cached','--name-only').decode().splitlines()
assert changed and all(p.startswith(REL+'/') for p in changed)
assert set(changed)=={str(p.relative_to(ROOT)) for p in OUT.rglob('*') if p.is_file()}
git('diff','--cached','--check')
git('-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','commit','-m','docs: preserve pinned restoration and reviewed exact archive retirement')
head=git('rev-parse','HEAD').decode().strip()
assert [r for r in git('ls-tree','HEAD').decode().splitlines() if r.split('\t',1)[1]!='docs']==original_top
assert git('status','--porcelain=v1','--untracked-files=all')==b''
committed={}
for name,expected in record['verifiedPins'].items():
    digest=sha(git('show','HEAD:'+REL+'/prepared/'+name));assert digest==expected;committed[name]=digest
git('-c','remote.origin.mirror=false','-c','credential.helper=!gh auth git-credential','push','origin','HEAD:refs/heads/'+BRANCH,timeout=120)
result={'status':'RESTORATION_PREPARATION_COMMITTED_PUSHED_AND_READ_BACK','head':head,'changedPaths':len(changed),
    'nonDocumentationRootEntriesUnchanged':True,'committedPinsReadBack':committed,
    'preservationSHA256':sha((OUT/'PRESERVATION.json').read_bytes()),'rootFreeAfter':free('/'),
    'dataFreeObservedAfter':free('/mnt/development'),'rawPatchDecodedBytesVerified':2,'initialDocumentationCheckFailurePreserved':True,
    'localRetirement':False,'builds':0,'nativeRuns':0}
write(TRANSFER/'GIT_PRESERVATION_RESULT.json',(json.dumps(result,indent=2)+'\n').encode())
print(json.dumps(result))
