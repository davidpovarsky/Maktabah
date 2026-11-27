from pathlib import Path
import os,base64,zlib,json,hashlib,shutil,subprocess,signal,time,traceback,zipfile,re
BASE='7230fe99a84c0b96abc0a3e86d1107811d30d6ce'
ROOT=Path('/home/ubuntu/.codex/worktrees/Maktabah-wave3-integration-rootfs-20261127')
TASK=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotations-selection-20261127')
OWN=TASK/'editor-scene-controls-attempt-1'
PRIOR=TASK/'caller-current-bindings-attempt-1'
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
INTEGRATION='Source/ChavrusaText/UIRoutingHost/Integration/'
HOST=Path('/mnt/development/projects/diagnostics/otzaria-wave3-annotation-selection-intake-20261127-attempt2/output')
UI=Path('/mnt/development/projects/diagnostics/otzaria-wave3-rn-semantic-intake-20261127/output')
CORE=ROOT/'.git/search-continuation-integrated-controls-20261127/output'
def sha(b):return hashlib.sha256(b).hexdigest()
def footprint():return sum(p.stat().st_blocks*512 for p in TASK.rglob('*') if p.is_file())
def capacity():
    if shutil.disk_usage(TASK).free<2147483648 or shutil.disk_usage(ROOT).free<1342177280 or footprint()>104857600:raise RuntimeError('shared floor / own100MiB cap')
def git(*args):return subprocess.check_output(['git','-c','gc.auto=0','-c','maintenance.auto=false','-C',str(ROOT),*args])
capacity()
if OWN.exists():raise RuntimeError('fresh attempt required')
OWN.mkdir();(OWN/'output').mkdir();(OWN/'tmp').mkdir()
def put(path,b):
    p=OWN/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);return p
def save(path,v):return put(path,(json.dumps(v,indent=2,sort_keys=True)+'\n').encode())
result={'schema':'otzaria.annotation-editor.source-controls.v1','base':BASE,'started':time.time(),'native':'NOT_RUN','apple_sdk':'NOT_RUN','steps':[]}
def run(name,args,expected=0,env=None):
    capacity();row={'name':name,'argv':list(map(str,args)),'started':time.time()};result['steps'].append(row)
    with (OWN/(name+'.stdout')).open('wb') as out,(OWN/(name+'.stderr')).open('wb') as err:
        p=subprocess.Popen(list(map(str,args)),stdout=out,stderr=err,start_new_session=True,env={**os.environ,'TMPDIR':str(OWN/'tmp'),**(env or {})})
        row['pid']=p.pid;row['start_ticks']=Path('/proc/'+str(p.pid)+'/stat').read_text().split()[21];save('STATUS.json',result)
        end=time.monotonic()+180
        while p.poll() is None:
            try:capacity()
            except BaseException as e:row['guard']=repr(e)
            if time.monotonic()>end:row['guard']='owned process deadline'
            if 'guard' in row:
                os.killpg(p.pid,signal.SIGTERM)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
                break
            time.sleep(.5)
        row.update(exit=p.returncode,finished=time.time());save('STATUS.json',result)
    if expected is None:
        if row['exit']==0:raise RuntimeError(name+' should fail the stated negative control')
    elif row['exit']!=expected:raise RuntimeError(name+' exit '+str(row['exit']))
    return row
try:
    put('RUN.py',RUN_SOURCE.encode())
    if sha(SWIFT.read_bytes())!='39d41b0dc9eba623b0e37cea42c3145720168214ba4349d6fa3bd9db9b1e651a':raise RuntimeError('original compiler')
    raw=zlib.decompress(base64.b64decode(PAYLOAD['zlib_base64']))
    if len(raw)!=PAYLOAD['bytes'] or sha(raw)!=PAYLOAD['sha256']:raise RuntimeError('transport identity')
    payload=json.loads(raw);rows=[]
    for row in payload['files']:
        data=row['text'].encode();rel=Path(row['path'])
        if rel.is_absolute() or '..' in rel.parts or sha(data)!=row['sha256'] or len(data)!=row['bytes']:raise RuntimeError('exact input')
        put('inputs/'+row['path'],data);rows.append({k:v for k,v in row.items() if k!='text'})
    save('INPUTS.json',{'base':BASE,'files':rows,'transport_sha256':PAYLOAD['sha256']})
    prior_result=(PRIOR/'RESULT.json').read_bytes();prior_raw=(PRIOR/'RAW.zip').read_bytes()
    if sha(prior_result)!='ebe40c5edffc71696bda9b7336786a277288ed90510816a7f46de471eb9c6e85' or sha(prior_raw)!='37147c288d2f942e4b69aaca87ed99fabde89bde737324d5829f976bfd97c8ce':raise RuntimeError('current module admission receipt')
    with zipfile.ZipFile(PRIOR/'RAW.zip') as z:
        manifest=json.loads(z.read('RAW_MANIFEST.json'))
        row=next(x for x in manifest if x['path']=='CURRENT_MODULE_SOURCE_JOIN.json');joined_raw=z.read(row['path'])
        if sha(joined_raw)!=row['sha256'] or len(joined_raw)!=row['bytes'] or joined_raw!=(PRIOR/row['path']).read_bytes():raise RuntimeError('admitted module join')
    joined=json.loads(joined_raw)
    if joined['counts']!={'Core':31,'UI':13,'Host':41}:raise RuntimeError('full original closure')
    for row in joined['files']:
        source=git('show',BASE+':'+row['path'])
        if sha(source)!=row['sha256'] or len(source)!=row['bytes'] or source!=Path(row['compiled_input']).read_bytes():raise RuntimeError('original module source '+row['path'])
    for prefix,name in [('Source/Otzaria/Actions/Sources/OtzariaActionCore/','Core'),('Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/','UI'),('Source/ChavrusaText/UIRoutingHost/Sources/ChavrusaUIRoutingHost/','Host')]:
        actual={x for x in git('ls-tree','-r','--name-only',BASE,'--',prefix).decode().splitlines() if x.endswith('.swift')}
        if actual!={x['path'] for x in joined['files'] if x['module']==name}:raise RuntimeError('module complete membership')
    for row in joined['products']:
        if sha(Path(row['path']).read_bytes())!=row['sha256']:raise RuntimeError('actual original product')
    put('retained-receipts/CALLER_RESULT.json',prior_result);put('retained-receipts/CURRENT_MODULE_SOURCE_JOIN.json',joined_raw)
    save('CURRENT_MODULE_JOIN.json',{'base':BASE,'rejoined':85,'counts':joined['counts'],'source_join_sha256':sha(joined_raw),'products':joined['products']})
    for path in ['Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift','Source/Features/Annotations/iOS/AnnotationListView.swift']:
        if git('show',BASE+':'+path)!=(OWN/'inputs/original'/path).read_bytes():raise RuntimeError('original view preimage '+path)
    component=git('show',BASE+':'+INTEGRATION+'MaktabahNativeComponentBinding.swift').decode()
    a=component.index('typealias MaktabahNativeComponentDescriptor');b=component.index('/// A passive view',a)
    expected='import Foundation\nimport ChavrusaUIRoutingHost\nimport OtzariaUIRouting\n\n'+component[a:b]
    if expected!=(OWN/'inputs/controls/ActualComponentSourceObservation.swift').read_text():raise RuntimeError('actual source/backend bridge')
    window_path=INTEGRATION+'MaktabahNativeWindowObservation.swift'
    if git('show',BASE+':'+window_path)!=(OWN/'inputs/controls/OriginalWindowObservation.swift').read_bytes():raise RuntimeError('actual original window observation')
    def source_body(text,signature):
        start=text.index(signature);a=text.index('{',start);depth=1;i=a+1
        while depth:
            if text[i]=='{':depth+=1
            elif text[i]=='}':depth-=1
            i+=1
        return text[start:i]
    extraction=json.loads((OWN/'inputs/controls/SCENE_EXTRACTION.json').read_text())
    actual_session=(OWN/'inputs/proposal/candidate'/INTEGRATION/'MaktabahNativeSceneSession.swift').read_text()
    if sha(actual_session.encode())!=extraction['session_sha256']:raise RuntimeError('actual Session source pin')
    fragments=[]
    for row in extraction['actual_methods']:
        fragment=source_body(actual_session,row['signature']);fragments.append(fragment)
        if len(fragment.encode())!=row['bytes'] or sha(fragment.encode())!=row['sha256']:raise RuntimeError('actual Session body '+row['signature'])
    expected_capsule='import Foundation\nimport OtzariaUIRouting\nimport ChavrusaUIRoutingHost\n@MainActor final class MaktabahNativeSceneSession {\n'+(OWN/'inputs/controls/EditorSceneFields.swift').read_text()+'\n\n'+'\n\n'.join(fragments)+'\n}\n'
    if expected_capsule!=(OWN/'inputs/controls/ActualEditorSessionCapsule.swift').read_text():raise RuntimeError('actual complete Session capsule')
    for variant in ['candidate','original']:
        text=(OWN/'inputs'/variant/'Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift').read_text()
        at=text.index('iOSAutoDirectionTextView(text:');a=text.index('onCreated: {',at)+len('onCreated: ');b=text.index('\n                    })',a)+len('\n                    }');fragment=text[a:b]
        expected=extraction['created_candidate_sha256' if variant=='candidate' else 'created_original_sha256']
        if sha(fragment.encode())!=expected:raise RuntimeError('actual original onCreated '+variant)
        capsule='ActualOriginalEditorCreated.swift' if variant=='candidate' else 'OldOriginalEditorCreated.swift'
        if (OWN/'inputs/controls'/capsule).read_text().count(fragment)!=1:raise RuntimeError('actual callback in compiled capsule')
    window=(OWN/'inputs/controls/OriginalWindowObservation.swift').read_text().removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','')
    common=[OWN/'inputs/controls'/n for n in ['ExplicitEditorBoundary.swift','ActualComponentSourceObservation.swift','ActualOriginalEditorSetter.swift','EditorFixture.swift','EditorSceneBoundary.swift','ActualEditorSessionCapsule.swift','ActualOriginalEditorCreated.swift','EditorSceneControls.swift']]
    common.append(put('capsules/OriginalWindowObservation.swift',window.encode()))
    candidate_path=OWN/'inputs/candidate'/INTEGRATION/'MaktabahNativeAnnotationEditorControls.swift'
    transform=lambda text:text.removeprefix('#if os(iOS)\n').removesuffix('#endif\n').replace('import UIKit\n','')
    candidate=put('capsules/CandidateOwner.swift',transform(candidate_path.read_text()).encode())
    argv=[SWIFT,'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',TASK/'attempt-1/module-cache']
    for path,name in [(HOST,'ChavrusaUIRoutingHost'),(UI,'OtzariaUIRouting'),(CORE,'OtzariaActionCore')]:
        argv+=['-I',path,'-L',path,'-l'+name,'-Xlinker','-rpath','-Xlinker',path]
    exe=OWN/'output/editor-owner-controls'
    run('compile-actual-owner',argv+common+[candidate,'-o',exe])
    run('actual-runtime-library-identity',['ldd',exe])
    linked=(OWN/'actual-runtime-library-identity.stdout').read_text()
    for path,name in [(HOST,'ChavrusaUIRoutingHost'),(UI,'OtzariaUIRouting'),(CORE,'OtzariaActionCore')]:
        if re.search(r'^\s*lib'+name+r'\.so\s+=>\s+'+re.escape(str(path/('lib'+name+'.so')))+r'\s',linked,re.M) is None:raise RuntimeError('actual linked library '+name)
    run('actual-owner-controls',[exe])
    output=(OWN/'actual-owner-controls.stdout').read_text()
    if 'RESULT passed=17 failed=0 ' not in output:raise RuntimeError('actual17 scene/callback controls')
    old_common=[p if p.name!='ActualOriginalEditorCreated.swift' else OWN/'inputs/controls/OldOriginalEditorCreated.swift' for p in common]
    old=OWN/'output/old-original-created-callback'
    run('compile-old-original-created-callback',argv+old_common+[candidate,'-o',old])
    run('old-original-created-equal-callback-negative',[old],expected=None,env={'EDITOR_CONTROL_FILTER':'actual original onCreated equal field callback retires before forwarding'})
    syntax=[]
    for i,row in enumerate(r for r in rows if (r['path'].startswith('proposal/candidate/') or r['path']=='candidate/Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift') and r['path'].endswith('.swift')):
        for configuration in ['Debug','Release']:
            flags=['-D','DEBUG'] if configuration=='Debug' else []
            name='full-ios-syntax-'+str(i)+'-'+configuration
            run(name,[SWIFT,'-frontend','-parse','-target','arm64-apple-ios27.0',*flags,OWN/'inputs'/row['path']]);syntax.append(name)
    for row in joined['products']:
        if sha(Path(row['path']).read_bytes())!=row['sha256']:raise RuntimeError('original product changed')
    result.update(status='PASS_SOURCE_ONLY',passed=17,failed=0,actual_original_created_counterexample=1,prior_report_receipt='5f8a7cf1ebd2f36fad8cd5910bbb33b1639ffa637b0decd62a073d22e4404458',prior_25_control_receipt='66654d1650bcd81fa5aeac92ea97bbc6cfdac34ef2c6bb422d47bd3c07a1a00c',full_swift_syntax=len(syntax),
                  original_module_counts=joined['counts'],scope='Actual Session modal callbacks, exact original full window/mapping reader caller with editor-only private overload, actual editor owner and original onCreated callback with same current source modules; explicit Apple/app/Store/window/platform boundaries. No Core execution, real UIKit, persistence, native receipt or Apple SDK.')
except BaseException as error:result.update(status='FAILED',error=repr(error),traceback=traceback.format_exc())
finally:
    result.update(finished=time.time(),task_bytes=footprint(),data_free=shutil.disk_usage(TASK).free,root_free=shutil.disk_usage(ROOT).free)
    path=save('RESULT.json',result);rows=[]
    for file in sorted(OWN.rglob('*')):
        if file.is_file() and 'output' not in file.relative_to(OWN).parts and file.name not in {'RAW.zip','RAW_MANIFEST.json'}:
            b=file.read_bytes();rows.append({'path':str(file.relative_to(OWN)),'bytes':len(b),'sha256':sha(b)})
    save('RAW_MANIFEST.json',rows)
    with zipfile.ZipFile(OWN/'RAW.zip','w',zipfile.ZIP_DEFLATED) as z:
        for row in rows:z.write(OWN/row['path'],row['path'])
        z.write(OWN/'RAW_MANIFEST.json','RAW_MANIFEST.json')
    raw=(OWN/'RAW.zip').read_bytes()
    print(json.dumps({'path':str(path),'sha256':sha(path.read_bytes()),'status':result['status'],'passed':result.get('passed'),
                     'raw_sha256':sha(raw),'raw_bytes':len(raw),'raw_members':len(rows),'error':result.get('error')}))
if result['status']!='PASS_SOURCE_ONLY':raise SystemExit(1)
