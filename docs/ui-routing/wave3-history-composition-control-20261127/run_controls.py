from pathlib import Path
import base64, gzip, hashlib, json, os, signal, subprocess, time, traceback

PARENT = Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
OWN = PARENT/'history-composition-attempt-1'
ROOT = Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
HISTORY = Path('/mnt/development/projects/worktrees/Maktabah-wave3-history-reader-controls-20261127')
CORE = ROOT/'.git/search-continuation-integrated-controls-20261127/output'
HOST = HISTORY/'output'
SWIFTC = Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
CACHE = PARENT/'module-cache-local'
FLOOR = 1342177280
CAP = 300*1024*1024
sha = lambda b: hashlib.sha256(b).hexdigest()
def free():
    s=os.statvfs(PARENT);return s.f_bavail*s.f_frsize
def allocated():
    return sum(p.stat().st_blocks*512 for p in PARENT.rglob('*') if p.is_file())
def save(name,value):
    (OWN/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
steps=[]
def run(name,argv,allowed=(0,)):
    assert free()>=FLOOR and allocated()<CAP
    step={'name':name,'argv':[str(v) for v in argv],'startedEpoch':time.time()};steps.append(step)
    save('STATUS.json',{'steps':steps,'state':'RUNNING'})
    with (OWN/(name+'.stdout')).open('wb') as out,(OWN/(name+'.stderr')).open('wb') as err:
        p=subprocess.Popen(step['argv'],stdout=out,stderr=err,env={**os.environ,'TMPDIR':str(OWN/'tmp')},start_new_session=True)
        step['pid']=p.pid
        stat=Path(f'/proc/{p.pid}/stat')
        initial=stat.read_text().split(') ',1)[1].split()[19]
        step['startTicks']=initial;end=time.monotonic()+120
        while p.poll() is None:
            if time.monotonic()>end or free()<FLOOR or allocated()>CAP:
                step['interrupted']='exact owned child deadline/capacity guard'
                current=stat.read_text().split(') ',1)[1].split()[19]
                assert current==initial and os.getpgid(p.pid)==p.pid
                os.killpg(p.pid,signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    assert stat.read_text().split(') ',1)[1].split()[19]==initial and os.getpgid(p.pid)==p.pid
                    os.killpg(p.pid,signal.SIGKILL);p.wait()
                break
            time.sleep(.25)
        step['exit']=p.returncode
    step['finishedEpoch']=time.time()
    step['logs']={s:{'bytes':(OWN/(name+s)).stat().st_size,'sha256':sha((OWN/(name+s)).read_bytes())} for s in ['.stdout','.stderr']}
    save('STATUS.json',{'steps':steps,'state':'RUNNING'})
    if p.returncode not in allowed:raise RuntimeError(name+' exited '+str(p.returncode))

OWN.mkdir(exist_ok=False)
for name in ['inputs','output','tmp']:(OWN/name).mkdir()
inputs=[]
def put(name,b,scope,source=None):
    p=OWN/'inputs'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
    inputs.append({'path':name,'bytes':len(b),'sha256':sha(b),'scope':scope,'source':source})
    return p
try:
    assert free()>=FLOOR and allocated()<CAP
    assert sha(SWIFTC.read_bytes())=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
    raw=gzip.decompress(base64.b64decode(PAYLOAD_B64));assert sha(raw)==PAYLOAD_SHA
    payload=json.loads(raw)
    for f in payload['files']:
        b=base64.b64decode(f['base64']);assert len(b)==f['bytes'] and sha(b)==f['sha256']
        put(f['path'],b,'New explicit app/window/generic-open fixtures, or exact labeled Composition extraction')
    prior=HISTORY/'source-attempt-1'
    assert sha((prior/'RESULT.json').read_bytes())=='0082e1f2e05f27f4fc74ed6370ab829638e805c24d18b7b08b2bf56e71b44947'
    assert sha((prior/'INPUTS.json').read_bytes())=='991724e164afa605382cc04237be1b154840111efefa784fd6ef444a85830f9e'
    original=json.loads((prior/'INPUTS.json').read_text())
    wanted=['HistorySourceFixtures.swift','ActualLibraryIdentityTypes.swift','ActualBackendPublicationObservation.swift','ActualHistoryQualifiedPublication.swift','ActualActionAppIdentityBridge.swift','ReadingEntry.swift','ReaderDestinationResolver.swift','ActualQualifiedLocatorStore.swift','candidate/EnabledHistoryReaderSource.swift']
    for name in wanted:
        row=next(r for r in original['files'] if r['path']==name)
        b=(prior/'inputs'/name).read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256']
        put('reused/'+name,b,row['kind'],{'sourcePath':str(prior/'inputs'/name),'originalPin':row})
    # Bind current real module closures to their exact, already executed input manifest.
    assert sha((HISTORY/'RESULT.json').read_bytes())=='e547715ea4e70a8be52c63724be1acdc2c70e18fd8d8610be671b11d2b8c212e'
    module_inputs=json.loads((HISTORY/'INPUTS.json').read_text())
    for row in module_inputs['files']:
        b=(HISTORY/'inputs'/row['path']).read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256']
    put('REUSED_MODULE_INPUTS.json',(HISTORY/'INPUTS.json').read_bytes(),'Read-only exact actual module compile closure')
    put('REUSED_SOURCE_INPUTS.json',(prior/'INPUTS.json').read_bytes(),'Read-only exact prior actual-source extraction closure')
    products=[]
    product_pins=[(CORE/'OtzariaActionCore.swiftmodule','c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103'),(CORE/'libOtzariaActionCore.so','f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a'),(HOST/'OtzariaUIRouting.swiftmodule','a10fed3e949bf8ac990dd6df1055142198c7ddf695b90352ab8fde2c51266d25'),(HOST/'libOtzariaUIRouting.so','715c4829ee430c89cd48d7846cf768c5ee29ba766ec290d45a5040137ca1f86e'),(HOST/'ChavrusaUIRoutingHost.swiftmodule','7894b6af69d5f7d67e5873d5f7ea809e74be4c21f0cc2735890af981bce75183'),(HOST/'libChavrusaUIRoutingHost.so','96d672ab0cdd32dc6fc830d0b552b3e74cab074d44bd7e67e16eda7ddb5fe928')]
    for path,pin in product_pins:
        b=path.read_bytes();assert sha(b)==pin;products.append({'path':str(path),'bytes':len(b),'sha256':pin,'mode':'READ_ONLY'})
    deadline_path='Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeObservationDeadline.swift'
    deadline=subprocess.check_output(['git','-C',str(ROOT),'show','24cd9291dbc87d799c22a41f0bc73a82c6415bfa:'+deadline_path])
    assert sha(deadline)=='bce22578534f69f4f24fb4472c54786431b427e09e754443f662b0e78fd95943'
    put('ActualNativeObservationDeadline.swift',deadline,'Unchanged complete original structured observation deadline',{'path':deadline_path,'base':'24cd9291'})
    boundary=(OWN/'inputs/HistoryCompositionBoundary.swift').read_bytes()
    marker=b'    // ACTUAL_METHOD_INSERTION: generator inserts exact original helper/method bytes here.\n'
    assert boundary.count(marker)==1
    for name in ['initial','candidate']:
        block=(OWN/'inputs'/f'{name}-actual-method.swift').read_bytes()
        generated=boundary.replace(marker,block)
        assert generated.replace(block,marker,1)==boundary
        put(f'{name}/EnabledComposition.swift',generated,'Exact original two Composition methods in explicit app/window/generic-open test shell',{'methodBytes':len(block),'methodSHA256':sha(block)})
    save('INPUTS.json',{'files':inputs,'readOnlyProducts':products,'scope':'Actual original Composition two methods + actual History source/service/deadline/resolver/Observation. App/window/generic-open/Combine/database remain explicit boundary substitutes. No native or Core execution.'})
    common=[OWN/'inputs/HistoryCompositionControls.swift',OWN/'inputs/ActualNativeObservationDeadline.swift']+list((OWN/'inputs/reused').glob('*.swift'))+[OWN/'inputs/reused/candidate/EnabledHistoryReaderSource.swift']
    flags=[SWIFTC,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',CACHE,'-I',CORE,'-L',CORE,'-lOtzariaActionCore','-I',HOST,'-L',HOST,'-lOtzariaUIRouting','-lChavrusaUIRoutingHost','-Xlinker','-rpath','-Xlinker',CORE,'-Xlinker','-rpath','-Xlinker',HOST]
    for name in ['initial','candidate']:
        run('compile-'+name,flags+common+[OWN/'inputs'/name/'EnabledComposition.swift','-o',OWN/'output'/name])
        run('run-'+name,[OWN/'output'/name],allowed=(0,1) if name=='initial' else (0,))
    before=json.loads((OWN/'run-initial.stdout').read_text());after=json.loads((OWN/'run-candidate.stdout').read_text())
    assert after['failed']==0 and after['passed']==16
    expected=['a pending native receipt cannot replace the generic returned refusal','throw after native report retains receipt without manufacturing ACK','late original-session witness failure retains actual core receipt and returned ACK']
    for name in expected:assert next(v for v in before['cases'] if v['name']==name)['pass'] is False
    save('RESULT.json',{'status':'PASS_ACTUAL_METHOD_EXPLICIT_APP_BOUNDARIES','steps':steps,'initial':before,'candidate':after,'requiredActualCounterexamples':expected,'nativeRuns':0,'AppleSDK':'NOT_RUN','CoreExecution':'NOT_RUN','ownedAllocatedBytes':allocated(),'freeRootfs':free()})
except BaseException as error:
    save('RESULT.json',{'status':'FAILED','steps':steps,'error':repr(error),'traceback':traceback.format_exc(),'nativeRuns':0,'AppleSDK':'NOT_RUN','ownedAllocatedBytes':allocated()});raise
finally:
    r=json.loads((OWN/'RESULT.json').read_text())
    print(json.dumps({'result':str(OWN/'RESULT.json'),'sha256':sha((OWN/'RESULT.json').read_bytes()),'status':r['status'],'steps':[{'name':s['name'],'exit':s.get('exit')}for s in steps],'initial':{k:r.get('initial',{}).get(k)for k in ['passed','failed']},'candidate':{k:r.get('candidate',{}).get(k)for k in ['passed','failed']}}))
