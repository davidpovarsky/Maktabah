import ast, base64, datetime, gzip, hashlib, json, os, shutil, signal, subprocess, textwrap, time, traceback
from pathlib import Path

SCOPE=Path('/home/ubuntu/.codex/artifacts/otzaria-wave3-profile-group-controls-20261127')
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
BASE='37caafcfaa4eb9b7bcfd02857bcb7c3f62daa4be'
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127'
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
def blob(p):return subprocess.check_output(['git','-C',str(ROOT),'show',BASE+':'+p])

attempt=SCOPE/'group-parent-portable-attempt-1'
assert not attempt.exists()
assert free()>FLOOR+32*1024*1024 and allocated()<CAP-64*1024*1024
attempt.mkdir(mode=0o750)
result={'status':'RUNNING','base':BASE,'steps':[],'nativeRuns':0,'AppleSDK':'NOT_RUN',
        'scope':'Actual original Core and actual candidate UIRouting plus original Host. Source/native/geometry authority fixtures are explicit boundaries.',
        'started':datetime.datetime.now(datetime.timezone.utc).isoformat()}
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
    overrides={};bindings=[]
    for row in payload['files']:
        relative=Path(row['path']);assert not relative.is_absolute() and '..' not in relative.parts
        b=gzip.decompress(base64.b64decode(row['gzipBase64']));assert len(b)==row['bytes'] and sha(b)==row['sha256']
        p=inputs/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        bindings.append({k:v for k,v in row.items() if k!='gzipBase64'})
        if row.get('baselineSHA256'):assert sha(blob(row['originalPath']))==row['baselineSHA256']
        if str(relative).startswith('source/'):overrides[str(relative)[7:]]=b
    result['submittedInputs']=bindings
    result['packageInputs']=[]
    for folder in ['Source/Otzaria/UIRouting/Sources/OtzariaUIRouting','Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost']:
        paths=subprocess.check_output(['git','-C',str(ROOT),'ls-tree','-r','--name-only',BASE,folder]).decode().splitlines()
        for relative in paths:
            if not relative.endswith('.swift'):continue
            original=blob(relative);b=overrides.get(relative,original)
            p=inputs/'package'/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
            result['packageInputs'].append({'path':relative,**pin(p),'originalSHA256':sha(original),'candidate':relative in overrides})
    result['coreSourceJoins']=[]
    for p in sorted((CORE/'inputs/Source/Otzaria/Actions/Sources/OtzariaActionCore').rglob('*.swift')):
        relative=p.relative_to(CORE/'inputs').as_posix();assert p.read_bytes()==blob(relative)
        result['coreSourceJoins'].append({'path':relative,**pin(p)})
    assert len(result['coreSourceJoins'])==31
    expected={'OtzariaActionCore.swiftmodule':'c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103',
              'libOtzariaActionCore.so':'f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a'}
    result['reusedCore']=[]
    for name,digest in expected.items():
        p=CORE/'output'/name;assert pin(p)['sha256']==digest;result['reusedCore'].append({'path':str(p),**pin(p)})
    assert pin(CORE/'RESULT.json')['sha256']=='adade63bed54c1b527e41d0d68f81ac652c6916d878235d82081c20f0f942d96'
    result['originalCoreResult']=pin(CORE/'RESULT.json')
    result['originalGeneratedAccessor']={'path':str(CORE/'inputs/original-generated-resource_bundle_accessor.swift'),**pin(CORE/'inputs/original-generated-resource_bundle_accessor.swift')}
    bundle=CORE/'output/OtzariaActionCore_OtzariaActionCore.bundle'
    shutil.copytree(bundle,output/bundle.name)
    result['coreResources']=[]
    for p in sorted(bundle.rglob('*')):
        if p.is_file():
            relative=p.relative_to(bundle);assert p.read_bytes()==(output/bundle.name/relative).read_bytes()
            result['coreResources'].append({'path':relative.as_posix(),**pin(p)})
    assert pin(SWIFT)['sha256']=='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a'
    result['compiler']={'path':str(SWIFT),**pin(SWIFT)}
    common=[str(SWIFT),'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(SCOPE/'module-cache-local')]
    links=['-I',str(CORE/'output'),'-L',str(CORE/'output'),'-lOtzariaActionCore','-Xlinker','-rpath','-Xlinker',str(CORE/'output')]
    ui=inputs/'package/Source/Otzaria/UIRouting/Sources/OtzariaUIRouting'
    host=inputs/'package/Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost'
    run('compile-actual-ui',common+links+['-emit-module','-emit-library','-enable-testing','-module-name','OtzariaUIRouting',
        '-emit-module-path',str(output/'OtzariaUIRouting.swiftmodule'),'-o',str(output/'libOtzariaUIRouting.so')]+[str(p)for p in sorted(ui.rglob('*.swift'))])
    nativeLinks=['-I',str(output),'-L',str(output),'-lOtzariaUIRouting','-Xlinker','-rpath','-Xlinker',str(output)]
    run('compile-actual-host',common+links+nativeLinks+['-emit-module','-emit-library','-enable-testing','-module-name','ChavrusaUIRoutingHost',
        '-emit-module-path',str(output/'ChavrusaUIRoutingHost.swiftmodule'),'-o',str(output/'libChavrusaUIRoutingHost.so')]+[str(p)for p in sorted(host.rglob('*.swift'))])
    run('compile-controls',common+links+nativeLinks+['-lChavrusaUIRoutingHost',str(inputs/'controls/PortableControls.swift'),'-o',str(output/'controls')])
    run('run-controls',[str(output/'controls')],timeout=30)
    result['controls']=json.loads((attempt/'run-controls.stdout').read_text());assert result['controls']['fail']==0
    for row in bindings:
        if row['path'].endswith('.swift') and row['path'].startswith(('source/','proposal-candidate/')):
            run('syntax-'+Path(row['path']).stem,[str(SWIFT),'-frontend','-parse','-target','arm64-apple-ios27.0-simulator','-D','DEBUG',str(inputs/row['path'])],timeout=30)
    result['status']='PASS_ACTUAL_SOURCE_CONTROLS_NOT_NATIVE'
    result['artifacts']=[{'path':p.relative_to(attempt).as_posix(),**pin(p)}for p in sorted(output.iterdir())if p.is_file()]
except BaseException as error:
    result['status']='FAILED';result['error']=repr(error);result['traceback']=traceback.format_exc()
finally:
    result['freeFinal']=free();result['allocatedFinal']=allocated();result['finished']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    print(json.dumps({'path':str(attempt),'result':pin(attempt/'RESULT.json'),'status':result['status'],'error':result.get('error'),'steps':[{'name':s['name'],'exit':s.get('exit')}for s in result['steps']]}))
