from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'docs/hq-ui-routing'
logs=[]
for name in ['N-app-owner-initial-fixture-compile.log','N-app-owner-legacy-mount-before.log','N-app-owner-initial110-full.log','N-app-owner-correction-full.log']:
    raw=(OUT/name).read_bytes(); text=raw.decode('utf-8-sig',errors='replace')
    rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',text)
    logs.append({'path':name,'sha256':hashlib.sha256(raw).hexdigest(),
        'methods':int(rows[-1][0]) if rows else 0,'failures':int(rows[-1][1]) if rows else None,
        'compiler_warnings':text.count('warning:'),'passed_methods':re.findall(r"Test Case '([^']+)' passed",text)})
assert (logs[1]['methods'],logs[1]['failures'],logs[1]['compiler_warnings'])==(1,2,0)
assert (logs[2]['methods'],logs[2]['failures'],logs[2]['compiler_warnings'])==(110,0,0)
assert (logs[-1]['methods'],logs[-1]['failures'],logs[-1]['compiler_warnings'])==(111,0,0)
methods=[x for x in logs[-1]['passed_methods'] if x.startswith('NActualAppBindingAdapterTests.')]; assert len(methods)==18
sources={}
for filename in ['MaktabahNativeWorkspaceOwner.swift','MaktabahNativePublicBindingAdapter.swift','MaktabahNativeRoutingComposition.swift','MaktabahNativeRoutingHost.swift','MaktabahNativeSceneSession.swift']:
    path='Source/ChavrusaText/UIRoutingHost/Integration/'+filename; raw=(ROOT/path).read_bytes()
    sources[path]={'working_sha256':hashlib.sha256(raw).hexdigest(),'expected_git_blob':subprocess.check_output(['git','hash-object','--path',path,path],cwd=ROOT,text=True).strip()}
protected=['Source/ChavrusaText/StudyWorkspace','Source/ChavrusaText/ReaderHost','Source/Otzaria','Source/UI','Maktabah.xcodeproj','.github','tools']
assert not subprocess.check_output(['git','diff','--name-only','HEAD','--',*protected],cwd=ROOT,text=True).strip()
report={'status':'OWNER_PATH_SOURCE_CORRECTED_REAL_PRODUCER_CONNECTION_UNAPPLIED_NATIVE_HOLD',
    'superseded_claim_source':'4b68336fcea12e02989130facbadac9963286bd2','package_source':'98e6c7b94fd5e4c06b83cdda57cd6c9d9f41db6e',
    'R_test_input':'44f518fcccce6bd20127f39eea8462d7a7a9dd47','sources':sources,'logs':logs,'corrected_app_methods':methods,
    'input_manifest_sha256':hashlib.sha256((OUT/'N-app-owner-correction-inputs.json').read_bytes()).hexdigest(),
    'actual_host_mount_refresh_methods_compiled':True,'actual_canonical_owner_and_projection_source_compiled':True,
    'actual_lifecycle_owner_file_connection_applied':False,'current_host_without_producer':'UNAVAILABLE even enabled=true',
    'native_UI_SwiftUI_shells':'Explicit doubles, not SDK/app behavior','actual_native_run':'NOT_RUN',
    'R_reconciled_dependency_consumed':False,'owner_R_upstream_project_files_modified':False,'public_enablement':False,
    'count_scope':'Final111 = prior93 + correctedapp18. Previous107/110 and RED1 are not added.',
    'manager_independent_review':'PENDING'}
(OUT/'N-app-owner-correction-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Exact legacy mount RED1/2, corrected final111/0/0; real lifecycle producer remains explicitly unapplied/unavailable.')
