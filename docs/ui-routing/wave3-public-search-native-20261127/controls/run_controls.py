import ast, base64, datetime, gzip, hashlib, json, os, signal, subprocess, sys, textwrap, time, traceback
from pathlib import Path

SCOPE=Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127/output'
HOST=SCOPE/'public-search-portable-attempt-1/output'
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
FLOOR=1342177280; CAP=300*1024*1024
sha=lambda b:hashlib.sha256(b).hexdigest()
def pin(p):
    b=Path(p).read_bytes();return {'bytes':len(b),'sha256':sha(b)}
def free():
    s=os.statvfs(SCOPE);return s.f_bavail*s.f_frsize
def allocated():
    seen=set();value=0
    for p in SCOPE.rglob('*'):
        s=p.lstat()
        if (s.st_dev,s.st_ino) not in seen:seen.add((s.st_dev,s.st_ino));value+=s.st_blocks*512
    return value
def proc_identity(pid):
    try:
        raw=Path('/proc',str(pid),'stat').read_text();v=raw[raw.rfind(')')+2:].split()
        return {'pid':pid,'parent':int(v[1]),'group':int(v[2]),'startTicks':int(v[19])}
    except(FileNotFoundError,ProcessLookupError):return None

attempt=SCOPE/'public-search-native-controls-attempt-1'
assert not attempt.exists()
assert free()>FLOOR+8*1024*1024 and allocated()<CAP-16*1024*1024
attempt.mkdir(mode=0o750)
result={'status':'RUNNING','steps':[],'scope':'Actual DEBUG immutable-return retention with actual Core/Host value types; reporting closures explicitly substitute encoding/I/O. Frontend syntax only for app/native proposal. No app/Core/OS execution.',
        'nativeRuns':0,'AppleSDK':'NOT_RUN','started':datetime.datetime.now(datetime.timezone.utc).isoformat()}
def save():(attempt/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')

driver=SCOPE/'public-search-portable-runner-attempt-2.py'
assert pin(driver)['sha256']=='ff27bc9c964c9a86c0869e83f679e105ff773807a73777fc32241f36538c9b0c'
s=driver.read_text();parsed=ast.parse(s);outer=next(x for x in parsed.body if isinstance(x,ast.FunctionDef) and x.name=='main')
fn=next(x for x in outer.body if isinstance(x,ast.FunctionDef) and x.name=='run')
run_source=textwrap.dedent(''.join(s.splitlines(keepends=True)[fn.lineno-1:fn.end_lineno]))
exec(compile(run_source,str(driver)+':exact-bounded-run-body','exec'),globals())
result['runner']={'file':pin(driver),'exactFunctionSHA256':sha(run_source.encode())}
try:
    payload=json.loads(gzip.decompress(base64.b64decode(PAYLOAD_B64)))
    inputs=attempt/'inputs';output=attempt/'output';inputs.mkdir();output.mkdir()
    bindings=[]
    for row in payload['files']:
        relative=Path(row['path']);assert not relative.is_absolute() and '..' not in relative.parts
        b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert len(b)==row['bytes'] and sha(b)==row['sha256']
        p=inputs/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        bindings.append({k:v for k,v in row.items() if k!='gzipBase64'})
    original_native=subprocess.check_output(['git','-C',str(ROOT),'show','24cd9291dbc87d799c22a41f0bc73a82c6415bfa:Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift'])
    assert len(original_native)==307308 and sha(original_native)=='e0fff6e19dc8bdea7b2f6e9a6a79f874f652c60816b6302dc6993f1a79019b1d'
    native=original_native+(inputs/'proposal/NATIVE_HELPER_ADDITION.swift').read_bytes()
    assert sha(native)==payload['combinedNativeSHA256']
    nativepath=inputs/'candidate/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift';nativepath.parent.mkdir(parents=True,exist_ok=True);nativepath.write_bytes(native)
    bindings.append({'path':str(nativepath.relative_to(inputs)),**pin(nativepath),'originalPrefixBytes':307308,'originalPrefixSHA256':sha(original_native),'assembly':'Exact immutable Git prefix + only declared suffix'})
    result['sourceBindings']=bindings
    prior=SCOPE/'public-search-portable-attempt-2/RESULT.json'
    assert pin(prior)['sha256']=='ed10f3e1e6324c585d8b545e7f4435b631b4808ab7a44c4baf296071fb4b44df'
    previous=json.loads(prior.read_text());assert previous['xctestSummary']==['40','0']
    reused=[]
    for artifact in previous['readOnlyPortableReuse']['artifacts']:
        path=HOST/artifact['path'];assert pin(path)=={k:artifact[k]for k in ['bytes','sha256']}
        reused.append({'path':str(path),**pin(path)})
    for name,expected in [('OtzariaActionCore.swiftmodule','c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103'),('libOtzariaActionCore.so','f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a')]:
        assert pin(CORE/name)['sha256']==expected;reused.append({'path':str(CORE/name),**pin(CORE/name)})
    (inputs/'REUSED_PORTABLE_RESULT.json').write_bytes(prior.read_bytes())
    result['readOnlyProducts']={'actualPriorResult':pin(prior),'products':reused,'originalCore31SourceJoins':previous['coreSourceJoins']}
    template=(inputs/'controls/RetentionControls.swift').read_text();actual=(inputs/'proposal/PUBLIC_EXECUTION_RETENTION.swift').read_text()
    marker='// ACTUAL_RETENTION_INSERTION\n';assert template.count(marker)==1
    candidate=template.replace(marker,actual)
    counter=actual.replace('        retained = value\n','        _ = value // COUNTERFACTUAL ONLY: omit process-lived retention\n')
    assert counter!=actual
    result['retentionExact']={'bytes':len(actual.encode()),'sha256':sha(actual.encode()),'counterfactual':'Only omit process-lived retention; never product'}
    for name,body in [('candidate',candidate),('counterfactual',template.replace(marker,counter))]:
        (inputs/(name+'.swift')).write_text(body)
    assert pin(SWIFT)['sha256']=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
    flags=[str(SWIFT),'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(SCOPE/'module-cache-local'),
           '-I',str(CORE),'-L',str(CORE),'-lOtzariaActionCore','-Xlinker','-rpath','-Xlinker',str(CORE),
           '-I',str(HOST),'-L',str(HOST),'-lOtzariaUIRouting','-lChavrusaUIRoutingHost','-Xlinker','-rpath','-Xlinker',str(HOST)]
    cases=['checkpoint-failure-keeps-raw-partial-return','envelope-failure-keeps-checkpoint-and-return',
           'duplicate-publication-never-retries-writer','nested-callback-cannot-recapture-or-republish',
           'second-invocation-cannot-replace-first','old-or-mismatched-kind-does-not-capture']
    result['cases']=[]
    for name in ['candidate','counterfactual']:
        run('compile-'+name,flags+[str(inputs/(name+'.swift')),'-o',str(output/name)])
        for case in cases if name=='candidate' else [cases[0],cases[4]]:
            label=name+'-'+case
            try:run(label,[str(output/name),case],timeout=20)
            except RuntimeError:
                if not(name=='counterfactual' and result['steps'][-1].get('exit')==1):raise
            answer=json.loads((attempt/(label+'.stdout')).read_text());result['cases'].append({'variant':name,**answer})
            assert answer['pass']==(name=='candidate')
    for relative in ['candidate/Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift',
                     'candidate/Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift',
                     'candidate/Maktabah-iOSUITests/NativePublicSearchContinuationAcceptanceTests.swift']:
        run('syntax-'+Path(relative).stem,[str(SWIFT),'-frontend','-parse','-target','arm64-apple-ios27.0-simulator','-D','DEBUG',str(inputs/relative)],timeout=30)
    result['status']='PASS_6_RETENTION_CONTROLS_2_MEANINGFUL_NEGATIVE_FAILURES_3_SYNTAX_ONLY'
except BaseException as error:
    result['status']='FAILED';result['error']=repr(error);result['traceback']=traceback.format_exc()
finally:
    result['freeFinal']=free();result['allocatedFinal']=allocated();result['finished']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    print(json.dumps({'path':str(attempt),'result':pin(attempt/'RESULT.json'),'status':result['status'],'error':result.get('error'),'steps':[{'name':s['name'],'exit':s.get('exit')}for s in result['steps']]}))
