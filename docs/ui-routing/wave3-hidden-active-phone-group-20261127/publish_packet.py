from pathlib import Path
import ast, base64, datetime, gzip, hashlib, json, os, subprocess, textwrap

ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
REPO = Path('/mnt/development/projects/worktrees/Maktabah-wave3-hidden-active-phone-group-20261127')
SCOPE = Path('/mnt/development/projects/diagnostics/otzaria-wave3-hidden-group-20261127')
PRIOR = Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
BASE = 'b463ffd03a76026cea06c79c608df97d00094152'
BRANCH = 'codex/otzaria-wave3-hidden-active-phone-group-20261127'
DOC = Path('docs/ui-routing/wave3-hidden-active-phone-group-20261127')
sha = lambda b: hashlib.sha256(b).hexdigest()
def pin(p):
    b = Path(p).read_bytes()
    return {'bytes':len(b), 'sha256':sha(b)}
def git(repo,*args):
    return subprocess.check_output(['git','-C',str(repo),*args],text=True).strip()
def run(repo,*args,input=None):
    return subprocess.run(['git','-C',str(repo),*args],input=input,text=True,check=True,capture_output=True,timeout=90)
def blob(ref,path):
    return subprocess.check_output(['git','-C',str(ROOT),'show',ref+':'+path])
def free(path):
    s=os.statvfs(path);return s.f_bavail*s.f_frsize
def capsule(path,members,**extra):
    rows=[]
    for name,data in members:
        b=data if isinstance(data,bytes) else Path(data).read_bytes()
        rows.append({'path':name,**{'bytes':len(b),'sha256':sha(b)},'base64':base64.b64encode(b).decode()})
    raw=(json.dumps({'files':rows,**extra},ensure_ascii=False,indent=2)+'\n').encode()
    z=gzip.compress(raw,mtime=0);path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(z)
    summary={'rawBytes':len(raw),'rawSHA256':sha(raw),'gzipBytes':len(z),'gzipSHA256':sha(z),
             'files':[{k:r[k]for k in ['path','bytes','sha256']}for r in rows],**extra}
    path.with_name(path.name+'.manifest.json').write_text(json.dumps(summary,indent=2)+'\n')
    for row in json.loads(gzip.decompress(path.read_bytes()))['files']:
        b=base64.b64decode(row['base64']);assert len(b)==row['bytes'] and sha(b)==row['sha256']
    return summary

payload=json.loads(gzip.decompress(base64.b64decode(PAYLOAD_B64)))
assert free(SCOPE)>687865856+48*1024*1024 and free(PRIOR)>1342177280
assert not REPO.exists()
observed=git(ROOT,'rev-parse','HEAD');rows=payload['sourceFiles']
assert len(rows)==3
for row in rows:
    old=blob(BASE,row['path']);assert old==blob(observed,row['path'])
    assert {'bytes':len(old),'sha256':sha(old)}==row['before']
final=SCOPE/'attempt-5';result=json.loads((final/'RESULT.json').read_text())
assert pin(final/'RESULT.json')=={'bytes':107310,'sha256':'1f3ff09b4dac620220c1764300345effa407c07ddc6ee71ea53921422280d070'}
assert result['status']=='PASS_SOURCE_CONTROLS_AND_BASELINE_NEGATIVES_NOT_NATIVE'
assert [(result[k]['pass'],result[k]['fail'])for k in ['baseline','candidate','negative','annotationFixture']]==[(0,4),(22,0),(0,3),(2,0)]
assert sum(x['name'].startswith('syntax-') and x.get('exit')==0 for x in result['steps'])==6
assert result['productPins']==rows
old_complete=json.loads((SCOPE/'attempt-4/run-candidate.stdout').read_text());assert (old_complete['pass'],old_complete['fail'])==(19,3)
assert json.loads((SCOPE/'attempt-3/RESULT.json').read_text())['fixtureFailure']['exit']==-11

subprocess.run(['git','clone','--shared','--no-checkout',str(ROOT),str(REPO)],check=True,capture_output=True,text=True,timeout=90)
run(REPO,'remote','set-url','origin',git(ROOT,'remote','get-url','origin'))
run(REPO,'sparse-checkout','init','--no-cone')
run(REPO,'sparse-checkout','set','--no-cone','--stdin',input=''.join('/'+r['path']+'\n'for r in rows)+'/'+str(DOC)+'/\n')
run(REPO,'checkout','-b',BRANCH,BASE)
assert not git(REPO,'status','--porcelain')
allowed=set()
for row in payload['files']:
    rel=Path(row['path']);assert not rel.is_absolute() and '..'not in rel.parts
    assert str(rel).startswith(str(DOC)+'/') or str(rel)in{r['path']for r in rows}
    b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert len(b)==row['bytes'] and sha(b)==row['sha256']
    p=REPO/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);allowed.add(str(rel))
docs=REPO/DOC
for row in rows:
    assert pin(REPO/row['path'])==row['after']
    assert (REPO/row['path']).read_bytes()==(final/'inputs/candidate'/row['path']).read_bytes()
    assert (final/'inputs/controls/candidate'/Path(row['path']).name).read_bytes()==(REPO/row['path']).read_bytes()
edits=json.loads((docs/'SOURCE_EDITS.json').read_text())
for row in rows:
    actual=(REPO/row['path']).read_text()
    changes=[e for e in edits['edits'] if e['path']==row['path']]
    for change in reversed(changes):
        assert actual.count(change['after'])==1
        actual=actual.replace(change['after'],change['before'],1)
    assert actual.encode()==blob(BASE,row['path'])

members=[];products=[]
for number in range(1,6):
    attempt=SCOPE/('attempt-'+str(number))
    for p in sorted(attempt.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(attempt)
        if rel.parts[0]=='output':products.append({'path':str(p),**pin(p),'preserved':True})
        else:members.append((attempt.name+'/'+rel.as_posix(),p))
for p in sorted(SCOPE.glob('run_attempt*.py')):members.append(('runners/'+p.name,p))
for p in sorted(SCOPE.glob('attempt*-delta.json')):members.append(('runners/'+p.name,p))
raw=capsule(docs/'evidence/RAW_CONTROLS.json.gz',members,preservedProducts=products,
    scope='Actual complete three product files and original source chain over declared platform/domain/renderer boundaries; no app SDK or native result.')
(docs/'evidence/FINAL_RESULT.json').write_bytes((final/'RESULT.json').read_bytes())
(docs/'evidence/ATTEMPT4_19PASS_3FAIL.json').write_bytes((SCOPE/'attempt-4/run-candidate.stdout').read_bytes())
driver=PRIOR/'public-search-portable-runner-attempt-2.py'
assert pin(driver)['sha256']=='ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c'
t=ast.parse(driver.read_text());main=next(x for x in t.body if isinstance(x,ast.FunctionDef)and x.name=='main')
fn=next(x for x in main.body if isinstance(x,ast.FunctionDef)and x.name=='run')
body=textwrap.dedent(''.join(driver.read_text().splitlines(keepends=True)[fn.lineno-1:fn.end_lineno]))
assert sha(body.encode())==result['runner']['exactFunctionSHA256']
(docs/'controls/exact_bounded_subprocess.py').write_text(body)
deps=[]
for row in result['originalSourceJoins']['files']:
    b=blob(BASE,row['path']);assert len(b)==row['bytes'] and sha(b)==row['sha256']
    now=blob(observed,row['path']);deps.append({'path':row['path'],'baseSHA256':sha(b),'observedSHA256':sha(now),'unchanged':b==now})
summary={'base':BASE,'observedRootHEAD':observed,'observedSourceTree':git(ROOT,'rev-parse',observed+':Source'),
    'sourceFiles':rows,'baseToObservedDependencies':deps,'productSourceMatchesCompiledWholeFiles':True,
    'counts':{'originalBaseline':{'passed':0,'failed':4},'finalCandidate':{'passed':22,'failed':0},
        'omitCanonicalValidator':{'passed':0,'failed':3},'explicitObservationFixture':{'passed':2,'failed':0},
        'preservedAttempt4':{'passed':19,'failed':3},'wholeFileSyntaxOnly':6,'appSDK':0,'native':0},
    'preservedFailures':['Attempt1 missing runner free() before compiler spawn','Attempt2 initial recursive callback fixture: signal11',
        'Attempt3 isolated same callback: signal11; exact corrected compile timed out and was reaped','Attempt4 unseeded optional Int annotation-clear callback fixture:19passed/3failed'],
    'coreDump':'Exact owned PID/core policy and absent exact core paths are recorded; no nonexistent core is claimed preserved.',
    'rawEvidenceFiles':len(raw['files']),'preservedGeneratedProducts':products,
    'peerReview':json.loads((docs/'PEER_REVIEW.json').read_text()),
    'unchanged':['Manager/Core/Viewer/Store/Session/Composition','Original ordinary selectTab early return and original effect order','Original first4 baseline scenarios and all prior after-effect assertions'],
    'open':['Actual iOS app SDK typecheck','Six proposed hidden-phone Group/Profile native selectors','Full document restoration, viewport/selection/TOC, relaunch, multiwindow, VoiceOver and production acceptance'],
    'PBX':'No new product file or membership change in this packet. Root retains all shared integration.',
    'sealedUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'dataFree':free(SCOPE),'rootFree':free(PRIOR)}
(docs/'RESULT.json').write_text(json.dumps(summary,indent=2)+'\n')
artifact_rows=[{'path':p.relative_to(docs).as_posix(),**pin(p)}for p in sorted(docs.rglob('*'))if p.is_file()]
for p in docs.rglob('*.json'):json.loads(p.read_text())
(docs/'ARTIFACTS.json').write_text(json.dumps({'files':artifact_rows,'sourceFiles':rows},indent=2)+'\n')
allowed|={p.relative_to(REPO).as_posix()for p in docs.rglob('*')if p.is_file()}
assert free(SCOPE)>687865856 and free(PRIOR)>1342177280
run(REPO,'add','--sparse','--',str(DOC),*[r['path']for r in rows])
assert set(git(REPO,'diff','--cached','--name-only').splitlines())==allowed
run(REPO,'diff','--cached','--check')
run(REPO,'-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com','commit','-m','Present the exact already-active phone Reader in workspace selection')
head=git(REPO,'rev-parse','HEAD');assert not git(REPO,'status','--porcelain')
receipt={'head':head,'branch':BRANCH,'worktree':str(REPO),'paths':len(allowed),'sourceFiles':rows,
         'result':pin(docs/'RESULT.json'),'artifacts':pin(docs/'ARTIFACTS.json'),'rawEvidenceFiles':len(raw['files']),
         'dataFree':free(SCOPE),'rootFree':free(PRIOR),'appSDK':0,'native':0}
(SCOPE/'PUBLISH_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt))
