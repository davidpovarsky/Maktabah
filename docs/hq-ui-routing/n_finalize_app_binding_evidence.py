from pathlib import Path
import hashlib, json, re, subprocess
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/hq-ui-routing'
names = ['N-app-binding-initial12.log','N-app-binding-initial13-full.log','N-app-binding-joint-full.log']
logs=[]
for name in names:
    raw=(OUT/name).read_bytes(); text=raw.decode('utf-8-sig',errors='replace')
    rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',text)
    passed=re.findall(r"Test Case '([^']+)' passed",text)
    logs.append({'path':name,'sha256':hashlib.sha256(raw).hexdigest(),'methods':int(rows[-1][0]),
        'failures':int(rows[-1][1]),'compiler_warnings':text.count('warning:'),'passed_method_names':passed})
assert [(x['methods'],x['failures'],x['compiler_warnings']) for x in logs]==[(12,0,0),(106,0,0),(107,0,0)]
actual=[x for x in logs[-1]['passed_method_names'] if x.startswith('NActualAppBindingAdapterTests.')]
assert len(actual)==14
sources={}
for name in ['MaktabahNativePublicBindingAdapter.swift','MaktabahNativeRoutingComposition.swift','MaktabahNativeRoutingHost.swift','MaktabahNativeSceneSession.swift']:
    path='Source/ChavrusaText/UIRoutingHost/Integration/'+name
    raw=(ROOT/path).read_bytes()
    sources[path]={'working_sha256':hashlib.sha256(raw).hexdigest(),
        'normalized_lf_sha256':hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest(),
        'expected_git_blob':subprocess.check_output(['git','hash-object','--path',path,path],cwd=ROOT,text=True).strip()}
assert 'futurePublicBindingsEnabled = false' in (ROOT/'Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingComposition.swift').read_text()
protected=['Source/ChavrusaText/StudyWorkspace','Source/Otzaria','Source/UI','Maktabah.xcodeproj','.github','tools']
assert not subprocess.check_output(['git','diff','--name-only','HEAD','--',*protected],cwd=ROOT,text=True).strip()
report={'status':'ACTUAL_APP_ADAPTER_PORTABLE_SOURCE_CANDIDATE_DEFAULT_OFF_NATIVE_HOLD',
    'base_source':'dc6c24ae1b05d49559e30affeaee477049370c51','P':'050031fac1bb21f738048beb8b5d011d5d0a6b4d',
    'R_dependency':'44f518fcccce6bd20127f39eea8462d7a7a9dd47','sources':sources,'logs':logs,'new_methods':actual,
    'input_manifest_sha256':hashlib.sha256((OUT/'N-app-binding-inputs.json').read_bytes()).hexdigest(),
    'count_scope':'Final107 = Host84 + P2 + R7 + actualapp14; earlier12/106 subsets not added.',
    'actual_full_app_adapter_body_compiled':True,'actual_extracted_app_method_bodies_compiled':True,
    'native_shells':'Explicit UIKit/SwiftUI owner/visibility/presentation and R proposed-hook doubles',
    'R_owned_workspace_files_edited':False,'R_immutable_dependency_tested':True,'R_app_dependency_patch_applied':False,
    'project_registration_applied':False,'lifecycle_mount_patch_applied':False,'protected_reader_marker_applied':False,
    'R_native_setter_hook_applied':False,'new_native_sdk_device_run':'NOT_RUN','public_enablement':False,
    'current_v1_pair_modified':False,'current_frozen_native_run_queried':False,
    'source_review':'Manager independent review pending; no native/SDK acceptance inferred'}
(OUT/'N-app-binding-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Final actual-app14 within joint107/0/0; source identities and no protected/R edits verified.')
