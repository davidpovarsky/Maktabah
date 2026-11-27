from pathlib import Path
import hashlib, json, os, re, shutil, signal, subprocess, time, traceback, zipfile

BASE='b463ffd03a76026cea06c79c608df97d00094152'
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
TASK=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
PRIOR=TASK/'caller-followup-attempt-2'
OWN=TASK/'caller-current-bindings-attempt-1'
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127'
UI=Path('/mnt/development/projects/diagnostics/otzaria-wave3-rn-semantic-intake-20261127')
HOST=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotation-selection-intake-20261127-attempt2')
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
DATA_FLOOR=2147483648; ROOT_FLOOR=1342177280; CAP=104857600
CORE_PREFIX='Source/Otzaria/Actions/Sources/OtzariaActionCore/'
UI_PREFIX='Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/'
HOST_PREFIX='Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/'
CONTROLLER='Source/Features/Annotations/iOS/iOSAnnotationViewController.swift'

def sha(data):return hashlib.sha256(data).hexdigest()
def footprint():return sum(p.stat().st_blocks*512 for p in TASK.rglob('*') if p.is_file())
def capacity():
    if shutil.disk_usage(TASK).free<DATA_FLOOR or shutil.disk_usage(ROOT).free<ROOT_FLOOR or footprint()>CAP:
        raise RuntimeError('shared capacity floor / own 100 MiB task cap')
def git(*args):
    return subprocess.run(['git','-C',str(ROOT),'-c','gc.auto=0','-c','maintenance.auto=false',*args],capture_output=True,check=True).stdout
def write(path,data):
    p=OWN/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);return p
def save(path,value):return write(path,(json.dumps(value,indent=2,sort_keys=True)+'\n').encode())
def checked_json(root,name,expected):
    data=(root/name).read_bytes()
    if sha(data)!=expected:raise RuntimeError('retained receipt identity '+str(root/name))
    write('retained-receipts/'+root.name+'/'+name,data)
    return json.loads(data)

capacity()
if OWN.exists():raise RuntimeError('fresh current-binding attempt required')
OWN.mkdir();(OWN/'output').mkdir();(OWN/'tmp').mkdir()
result={'schema':'otzaria.annotation-current-caller-binding.v1','base':BASE,'native':'NOT_RUN',
        'apple_sdk':'NOT_RUN','started':time.time(),'steps':[]}

def run(name,argv):
    capacity()
    step={'name':name,'argv':list(map(str,argv)),'started':time.time()};result['steps'].append(step)
    with (OWN/(name+'.stdout')).open('wb') as out,(OWN/(name+'.stderr')).open('wb') as err:
        p=subprocess.Popen(list(map(str,argv)),stdout=out,stderr=err,start_new_session=True,
                           env={**os.environ,'TMPDIR':str(OWN/'tmp')})
        step['pid']=p.pid;step['start_ticks']=Path('/proc/'+str(p.pid)+'/stat').read_text().split()[21]
        save('STATUS.json',result)
        end=time.monotonic()+150
        while p.poll() is None:
            try:capacity()
            except BaseException as error:step['guard']=str(error)
            if time.monotonic()>end:step['guard']='owned process deadline'
            if 'guard' in step:
                os.killpg(p.pid,signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
                break
            time.sleep(.5)
        step.update(exit=p.returncode,finished=time.time())
        save('STATUS.json',result)
    if step['exit']!=0:raise RuntimeError(name+' exit '+str(step['exit']))

try:
    write('RUN.py',RUN_SOURCE.encode())
    if sha(SWIFT.read_bytes())!='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a':raise RuntimeError('compiler identity')
    prior=checked_json(PRIOR,'RESULT.json','63415a94517b961fea07adc7688dc68a21a1d29b548feaf3f8b9e4c893b9c1fe')
    if prior['passed']!=6 or prior['failed']!=0:raise RuntimeError('preserved original six controls')
    stopped=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotation-expansion-intake-20261127')
    checked_json(stopped,'FAILURE.json','e847ab7462b262785e6c9ef0ce886a41f92ddc78bb1b30377a5ceb1df7627767')
    stopped_runner=(stopped/'RUN.py').read_bytes()
    if len(stopped_runner)!=10658 or sha(stopped_runner)!='65215dbd1073ddefc960323564ccb5fbc2f75695167a0b79b4bebacf57bbbcd4':raise RuntimeError('actual stopped root intake runner')
    write('retained-receipts/'+stopped.name+'/RUN.py',stopped_runner)
    write('retained-receipts/'+stopped.name+'/EVENTS.json',(stopped/'EVENTS.json').read_bytes())
    core_input=checked_json(CORE,'INPUTS.json','7855be65f64f938180d49026b3c1148f1981b47864bfd3c7082cb63c08edf3cb')
    core_result=checked_json(CORE,'RESULT.json','adade63bed54c1b527e41d0d68f81ac652c6916d878235d82081c20f0f942d96')
    ui_input=checked_json(UI,'PACKAGE_INPUTS.json','49ea79218a6e89e7251a451728a66e0e7937f03041a0dec2826e1ba513d085db')
    host_input=checked_json(HOST,'PACKAGE_INPUTS.json','972a7ff786370dc7c32dfda9e7412e2b47d94de463690862d57b5f37a9f55841')
    ui_steps=checked_json(UI,'STEPS.json','fb7a4c2ea05ffff4a40c358275bf87d9433851ebd9e80894ac69d9787a09f5be')
    host_steps=checked_json(HOST,'STEPS.json','d79349731fe559f495aeed0e1f09f36b2bc8b7e9c754d0dd12dea9189d1f59c6')
    groups=[('Core',CORE,CORE_PREFIX,[x for x in core_input['files'] if x['path'].startswith(CORE_PREFIX)],31,
             next(x for x in core_result['steps'] if x['name']=='compile-real-core')),
            ('UI',UI,UI_PREFIX,[x for x in ui_input['files'] if x['path'].startswith(UI_PREFIX)],13,
             next(x for x in ui_steps if x['name']=='compile-merged-ui')),
            ('Host',HOST,HOST_PREFIX,host_input['currentHost'],41,
             next(x for x in host_steps if x['name']=='compile-current-host'))]
    joined=[]
    for name,root,prefix,rows,count,step in groups:
        expected={x['path'] for x in rows}
        actual={p for p in git('ls-tree','-r','--name-only',BASE,'--',prefix).decode().splitlines() if p.endswith('.swift')}
        if len(rows)!=count or expected!=actual or step['exit']!=0 or step['argv'][0]!=str(SWIFT):raise RuntimeError('actual complete module inputs '+name)
        compiler_inputs={str(root/'inputs'/p) for p in expected}
        if not compiler_inputs.issubset(set(step['argv'])):raise RuntimeError('compile argv does not bind original inputs '+name)
        for row in rows:
            committed=git('show',BASE+':'+row['path']);prepared=(root/'inputs'/row['path']).read_bytes()
            if len(committed)!=row['bytes'] or sha(committed)!=row['sha256'] or committed!=prepared:
                raise RuntimeError('current original module source mismatch '+row['path'])
            joined.append({**row,'module':name,'base':BASE,'git_blob':git('rev-parse',BASE+':'+row['path']).decode().strip(),
                           'compiled_input':str(root/'inputs'/row['path'])})
    for key,rows in [('reusedExactUI',groups[1][3]),('reusedExactCore',groups[0][3])]:
        if host_input[key]!=rows:raise RuntimeError('Host original dependency closure '+key)
    products=[]
    expected_products=[
        (HOST/'output/ChavrusaUIRoutingHost.swiftmodule','66f9ec0fb9581527b483ef6e766c1ce7c5e405c8417f54dc9d6504af8e2e88cb'),
        (HOST/'output/libChavrusaUIRoutingHost.so','88d6217c0bec3136ad9a2f36c4bc68ef0daeb886fe994b1536560038a3b90f77'),
        (UI/'output/OtzariaUIRouting.swiftmodule','7d3b1cb4f488ef5178a117c9200458a33d5e83578255f648d87feb6a7d0793e4'),
        (UI/'output/libOtzariaUIRouting.so','d5f0b4a3880467dab9103481dd11b825008c74958395d1ac122671b2d482595d'),
        (CORE/'output/OtzariaActionCore.swiftmodule','c45482e0c872e1378e9048b9f1b9fef473b0a9b8973ef0e17ee9e2df22a24103'),
        (CORE/'output/libOtzariaActionCore.so','f7a7d43d27b341f53a32b5205306c6bcec69c7a05b1f381d6e2239d5803d049a')]
    for path,pin in expected_products:
        data=path.read_bytes()
        if sha(data)!=pin:raise RuntimeError('compiled product identity '+str(path))
        products.append({'path':str(path),'bytes':len(data),'sha256':pin,'use':'read-only existing original compiled product'})
    save('CURRENT_MODULE_SOURCE_JOIN.json',{'base':BASE,'files':joined,'counts':{'Core':31,'UI':13,'Host':41},'products':products})
    # Reuse the same six assertions and actual binding/caller; only replace
    # the extracted root publication with the exact current original class.
    for row in prior['inputs']:
        source=PRIOR/'inputs'/row['path'];data=source.read_bytes()
        if len(data)!=row['bytes'] or sha(data)!=row['sha256']:raise RuntimeError('retained caller input '+row['path'])
        write('prior-inputs/'+row['path'],data)
    production=(OWN/'prior-inputs/candidate'/CONTROLLER).read_bytes()
    if sha(production)!='a6577cf5d2060b3849ab06634c9e52915e9048260feda7814c02cf926965bd1c':raise RuntimeError('unchanged product')
    transformed=[]
    for name in ['MaktabahNativeAnnotationListPublication.swift','MaktabahNativeAnnotationSelectionBinding.swift']:
        path='Source/ChavrusaText/UIRoutingHost/Integration/'+name
        raw=git('show',BASE+':'+path)
        if raw!=(OWN/'prior-inputs/candidate'/path).read_bytes():raise RuntimeError('current actual binding identity')
        text=raw.decode().removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','').replace('@preconcurrency import Combine\n','')
        transformed.append(write('current-source/'+name,text.encode()))
    root_path='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSearchEntry.swift'
    root_raw=git('show',BASE+':'+root_path);text=root_raw.decode()
    a=text.index('@MainActor\nfinal class MaktabahNativeRootPublicationSource');b=text.index('/// Expected publications',a)
    root_fragment='import Foundation\nimport ChavrusaUIRoutingHost\n\n'+text[a:b].rstrip()+'\n'
    root_capsule=write('current-source/ActualOriginalRootPublication.swift',root_fragment.encode())
    if sha(root_raw)!='7e752dde2a43cf4625e12149dd9bc7b3fb383f0fdfdb529cd380bfa456f60532':raise RuntimeError('current original root publisher')
    window_path='Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWindowObservation.swift'
    window_raw=git('show',BASE+':'+window_path)
    window_fragment=window_raw.decode().removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','')
    if window_fragment!=(OWN/'prior-inputs/controls/ActualWindowObservation.swift').read_text():raise RuntimeError('actual unchanged window capsule')
    save('CURRENT_APP_SOURCE_JOIN.json',{'base':BASE,'root_publisher':{'path':root_path,'bytes':len(root_raw),'sha256':sha(root_raw),'capsule_sha256':sha(root_fragment.encode())},
        'window':{'path':window_path,'bytes':len(window_raw),'sha256':sha(window_raw)},
        'product_controller_sha256':sha(production),'six_control_sha256':sha((OWN/'prior-inputs/controls/CallerControls.swift').read_bytes()),
        'preserved_old_root_capsule':'prior-inputs/controls/ActualOriginalRootPublication.swift',
        'root_change':'Exact current original fixed source publication included; no assertion or product edit.'})
    controls=[OWN/'prior-inputs/controls'/name for name in ['ExplicitAnnotationBoundary.swift','ActualWindowObservation.swift','ActualBindingFixture.swift','CallerControls.swift','CandidateCaller.swift']]
    executable=OWN/'output/current-caller-controls'
    # Host41 comes first; UI's directory also contains an older same-name Host
    # product and must never win module, link or runtime-library resolution.
    argv=[SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',TASK/'attempt-1/module-cache']
    for root,libraries in [(HOST,['ChavrusaUIRoutingHost']),(UI,['OtzariaUIRouting']),(CORE,['OtzariaActionCore'])]:
        argv+=['-I',root/'output','-L',root/'output',*['-l'+x for x in libraries],'-Xlinker','-rpath','-Xlinker',root/'output']
    run('compile-current-candidate-caller',argv+transformed+controls+[root_capsule,'-o',executable])
    run('actual-linked-library-identity',['ldd',executable])
    linked=(OWN/'actual-linked-library-identity.stdout').read_text()
    for root,name in [(HOST,'libChavrusaUIRoutingHost.so'),(UI,'libOtzariaUIRouting.so'),(CORE,'libOtzariaActionCore.so')]:
        if re.search(r'^\s*'+re.escape(name)+r'\s+=>\s+'+re.escape(str(root/'output'/name))+r'\s',linked,re.M) is None:
            raise RuntimeError('actual runtime library resolution '+name)
    run('same-six-current-caller-controls',[executable])
    observed=json.loads((OWN/'same-six-current-caller-controls.stdout').read_text())
    if observed['passed']!=6 or observed['failed']!=0:raise RuntimeError('same six controls')
    for row in products:
        if sha(Path(row['path']).read_bytes())!=row['sha256']:raise RuntimeError('shared product changed')
    result.update(status='PASS_CURRENT_BINDINGS_SOURCE_CONTROLS_ONLY',passed=6,failed=0,
        current_module_counts={'Core':31,'UI':13,'Host':41},reused_products=products,
        scope='Same six actual binding/full caller/helper source controls, current original Core/UI/Host products, exact current root publisher. Explicit UIKit/Combine/Store/backend/workspace boundaries; no app or native execution. Original eleven and old compile diagnostic not rerun.')
except BaseException as error:
    result.update(status='FAILED',error=repr(error),traceback=traceback.format_exc())
finally:
    result.update(finished=time.time(),data_free=shutil.disk_usage(TASK).free,root_free=shutil.disk_usage(ROOT).free,task_bytes=footprint())
    p=save('RESULT.json',result)
    rows=[]
    for path in sorted(OWN.rglob('*')):
        if path.is_file() and 'output' not in path.relative_to(OWN).parts and path.name not in {'RAW.zip','RAW_MANIFEST.json'}:
            raw=path.read_bytes();rows.append({'path':str(path.relative_to(OWN)),'bytes':len(raw),'sha256':sha(raw)})
    save('RAW_MANIFEST.json',rows)
    with zipfile.ZipFile(OWN/'RAW.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for row in rows:archive.write(OWN/row['path'],row['path'])
        archive.write(OWN/'RAW_MANIFEST.json','RAW_MANIFEST.json')
    raw=(OWN/'RAW.zip').read_bytes()
    print(json.dumps({'path':str(p),'sha256':sha(p.read_bytes()),'status':result['status'],'passed':result.get('passed'),
        'raw_zip':str(OWN/'RAW.zip'),'raw_bytes':len(raw),'raw_sha256':sha(raw),'raw_members':len(rows),'error':result.get('error')}))
if result['status']!='PASS_CURRENT_BINDINGS_SOURCE_CONTROLS_ONLY':raise SystemExit(1)
