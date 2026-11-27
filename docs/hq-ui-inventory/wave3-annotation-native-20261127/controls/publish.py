from pathlib import Path
import hashlib, json, subprocess, shutil, time, zipfile, base64

BASE='b463ffd03a76026cea06c79c608df97d00094152'
BRANCH='codex/otzaria-wave3-annotation-native-20261127'
DOCS='docs/hq-ui-inventory/wave3-annotation-native-20261127'
PREFIX='Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'
SELECTOR='Maktabah-iOSUITests/NativeAnnotationSelectionAcceptanceTests.swift'
DONOR=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
CONTROL=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127/native-selectors-attempt-1')
TASK=Path('/home/ubuntu/otzaria-wave3-annotation-native-published-20261127')
REPO=TASK/'source'; DELIVERY=TASK/'delivery'

def sha(data): return hashlib.sha256(data).hexdigest()
def capacity():
    if shutil.disk_usage(TASK.parent).free < 1342177280 or shutil.disk_usage(CONTROL).free < 2147483648:
        raise RuntimeError('shared capacity floor')
capacity()
if TASK.exists(): raise RuntimeError('fresh isolated task required')
TASK.mkdir(); DELIVERY.mkdir()
result={'schema':'otzaria.annotation-native.publication.v1','base':BASE,'branch':BRANCH,
        'started':time.time(),'repo':str(REPO),'commands':[],'native':'NOT_RUN'}

def command(name,args,cwd=None,input=None):
    capacity()
    process=subprocess.run(list(map(str,args)),cwd=cwd,input=input,text=True,capture_output=True,timeout=180)
    row={'name':name,'argv':list(map(str,args)),'exit_code':process.returncode}
    for suffix,value in [('stdout',process.stdout),('stderr',process.stderr)]:
        p=DELIVERY/(name+'.'+suffix); p.write_text(value)
        row[suffix]={'path':str(p),'bytes':len(value.encode()),'sha256':sha(value.encode())}
    result['commands'].append(row)
    (DELIVERY/'PROGRESS.json').write_text(json.dumps(result,indent=2)+'\n')
    if process.returncode: raise RuntimeError(name+' failed; raw output preserved')
    return process.stdout.strip()
def git(name,args,cwd=REPO,input=None):
    return command(name,['git','-c','gc.auto=0','-c','maintenance.auto=false',
        '-c','user.name=ChatGPT','-c','user.email=chatgpt-agent@users.noreply.github.com',*args],cwd,input)

try:
    old=subprocess.run(['git','-C',str(DONOR),'-c','gc.auto=0','-c','maintenance.auto=false',
        'show',BASE+':'+PREFIX],capture_output=True,check=True).stdout
    if len(old)!=375434 or sha(old)!='2157fe667fc215e3ac46e8115a1b1731dc96874cf06bb8d4ee880e5d35f9b74e':
        raise RuntimeError('actual original prefix')
    suffix=(CONTROL/'NATIVE_HELPER_ADDITION.swift').read_bytes()
    combined=(CONTROL/'candidate'/PREFIX).read_bytes()
    selector=(CONTROL/'candidate'/SELECTOR).read_bytes()
    if len(suffix)!=31681 or sha(suffix)!='9f6af6530cd8ead9d2747a9a6c3a5b1f7f33e95fc2d29781eff8523116be8dc0' or combined!=old+suffix:
        raise RuntimeError('exact independent suffix')
    if sha(combined)!='93fade04cfeb99c75870f886d211d7144fc20e952ac0c8b56eb385cabc24b01f' or sha(selector)!='2f7e720a2cd85112158553816d3fa1ac5ffb12861d9475767eefecc46bd472d2':
        raise RuntimeError('frozen current sources')
    raw=(CONTROL/'RESULT.json').read_bytes()
    if sha(raw)!='4ec69e698fb83f2c070ce8d4040fcaf390ba03b5df9d63c0dfb1c5ab7e672fe3':raise RuntimeError('actual source result')
    evidence=json.loads(raw)
    if evidence['status']!='PASS_SOURCE_JOIN_AND_SYNTAX_ONLY' or evidence['test_execution_count']!=0 or evidence['original_dependencies']!=20:
        raise RuntimeError('source-only evidence boundary')
    if len(evidence['selector_declarations'])!=6 or evidence['steps'][0]['exit']!=0:
        raise RuntimeError('source declarations/syntax')
    archive=(CONTROL/'RAW.zip').read_bytes()
    if len(archive)!=364351 or sha(archive)!='cf65c780fe1dc2f3bd6b0b4c7ba7f32c0ab251495e5cc8fef7447ab9e3c636b7':raise RuntimeError('raw evidence archive')
    files={path:base64.b64decode(encoded) for path,encoded in LOCAL_DOCS.items()}
    files.update({'NATIVE_HELPER_ADDITION.swift':suffix, 'evidence/RAW.zip':archive,
                  'MEMBERSHIP.json':(CONTROL/'MEMBERSHIP.json').read_bytes()})
    with zipfile.ZipFile(CONTROL/'RAW.zip') as z:
        rows=json.loads(z.read('RAW_MANIFEST.json'))
        if len(rows)!=31 or set(z.namelist())!={r['path'] for r in rows}|{'RAW_MANIFEST.json'}:raise RuntimeError('raw member closure')
        for row in rows:
            value=z.read(row['path'])
            if len(value)!=row['bytes'] or sha(value)!=row['sha256']:raise RuntimeError('raw member hash')
            files['evidence/raw/'+row['path']]=value
        files['evidence/raw/RAW_MANIFEST.json']=z.read('RAW_MANIFEST.json')
    files['MANIFEST.json']=(json.dumps({'files':[{'path':p,'bytes':len(b),'sha256':sha(b)}
        for p,b in sorted(files.items())]},indent=2,sort_keys=True)+'\n').encode()
    common=git('donor-common',['rev-parse','--git-common-dir'],DONOR)
    objects=(DONOR/common if not Path(common).is_absolute() else Path(common)).resolve()/'objects'
    if not objects.is_dir():raise RuntimeError('actual original object store')
    command('private-init',['git','-c','gc.auto=0','-c','maintenance.auto=false','init','-q',REPO])
    (REPO/'.git/objects/info/alternates').write_text(str(objects)+'\n')
    git('sparse-init',['sparse-checkout','init','--no-cone'])
    git('sparse-scope',['sparse-checkout','set','--no-cone','--stdin'],input='/'+PREFIX+'\n/'+SELECTOR+'\n/'+DOCS+'/\n')
    git('isolated-base',['checkout','-q','-b',BRANCH,BASE])
    if git('base-clean',['status','--porcelain']):raise RuntimeError('dirty base')
    (REPO/PREFIX).write_bytes(combined)
    if (REPO/SELECTOR).exists():raise RuntimeError('new selector collision')
    (REPO/SELECTOR).write_bytes(selector)
    git('stage-source',['add','--',PREFIX,SELECTOR])
    if set(git('source-scope',['diff','--cached','--name-only']).splitlines())!={PREFIX,SELECTOR}:raise RuntimeError('source scope')
    git('source-check',['diff','--cached','--check'])
    git('commit-source',['commit','-m','test: add original Annotation system entity selection journeys'])
    source=git('source-head',['rev-parse','HEAD'])
    for path,data in files.items():
        p=REPO/DOCS/path; p.parent.mkdir(parents=True,exist_ok=True)
        if p.exists():raise RuntimeError('fresh docs required')
        p.write_bytes(data)
    git('stage-evidence',['add','--sparse','--',DOCS])
    if set(git('docs-scope',['diff','--cached','--name-only']).splitlines())!={DOCS+'/'+p for p in files}:raise RuntimeError('evidence scope')
    git('commit-evidence',['commit','-m','docs: bind six unrun Annotation native selectors to original source'])
    head=git('head',['rev-parse','HEAD'])
    if git('final-clean',['status','--porcelain']):raise RuntimeError('dirty result')
    changed=set(git('complete-scope',['diff','--name-only',BASE,head]).splitlines())
    if changed!={PREFIX,SELECTOR}|{DOCS+'/'+p for p in files}:raise RuntimeError('complete scope')
    for top in ['Source','Vendor','Maktabah.xcodeproj','Scripts']:
        if git('original-'+top.replace('.','-'),['rev-parse',BASE+':'+top])!=git('current-'+top.replace('.','-'),['rev-parse',head+':'+top]):
            raise RuntimeError('preserved original tree '+top)
    credentials=['-c','credential.helper=!/usr/local/bin/gh auth git-credential','-c','remote.origin.mirror=false']
    remote='https://github.com/davidpovarsky/Maktabah.git'
    git('scoped-push',credentials+['push',remote,'HEAD:refs/heads/'+BRANCH])
    remote_head=git('remote-readback',credentials+['ls-remote',remote,'refs/heads/'+BRANCH]).split()[0]
    if remote_head!=head:raise RuntimeError('remote readback')
    result.update(status='PUBLISHED_SOURCE_AND_EVIDENCE',source_commit=source,docs_commit=head,
        source_tree=git('source-tree',['rev-parse',head+':Source']),test_tree=git('test-tree',['rev-parse',head+':Maktabah-iOSUITests']),
        docs_files=len(files),changed_paths=len(changed),manifest_sha256=sha(files['MANIFEST.json']),remote_head=remote_head)
except BaseException as error:
    result.update(status='FAILED',error=repr(error))
finally:
    result.update(finished=time.time(),free_after=shutil.disk_usage(TASK).free)
    p=DELIVERY/'PUBLICATION_RESULT.json'; p.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='commands'}|{'receipt':str(p),'receipt_sha256':sha(p.read_bytes())}))
if result['status']!='PUBLISHED_SOURCE_AND_EVIDENCE':raise SystemExit(1)
