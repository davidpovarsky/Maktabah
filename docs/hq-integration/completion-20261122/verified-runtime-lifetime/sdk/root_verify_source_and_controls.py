from pathlib import Path
import ast
import copy
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
WORK = HERE.parent
read = lambda p: json.loads(p.read_bytes())
sha = lambda b: hashlib.sha256(b).hexdigest()
def identity(p):
    b = p.read_bytes()
    return {'bytes':len(b),'sha256':sha(b),'git_blob':hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()}
def funcs(p):
    text = p.read_text(); tree = ast.parse(text)
    return {n.name:ast.get_source_segment(text,n) for n in tree.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
manifest = read(HERE/'SOURCE_MANIFEST.json')
assert len(manifest['product_files']) == 10 and manifest['new_executions_total'] == 71
for row in manifest['product_files']:
    assert identity(HERE/'candidate'/row['path']) == {k:row[k] for k in ('bytes','sha256','git_blob')}
    if row['preimage_sha256']:
        assert sha((HERE/'preimage'/row['path']).read_bytes()) == row['preimage_sha256']
old_project = (HERE/'preimage/Anytype.xcodeproj/project.pbxproj').read_bytes()
new_project = (HERE/'candidate/Anytype.xcodeproj/project.pbxproj').read_bytes()
lines = new_project.splitlines(keepends=True)
added = [line for line in lines if b'"LD_DYLIB_INSTALL_NAME" = "@rpath/$(EXECUTABLE_PATH)";' in line]
assert len(added) == 4 and b''.join(line for line in lines if line not in added) == old_project
old = funcs(HERE/'preimage/Tools/OriginalEditor/run_framework_acceptance.py')
new = funcs(HERE/'candidate/Tools/OriginalEditor/run_framework_acceptance.py')
preservation = read(HERE/'SOURCE_PRESERVATION.json')
for row in preservation['unchanged_driver_functions']:
    assert old[row['name']] == new[row['name']] and sha(new[row['name']].encode()) == row['sha256']
assert len(preservation['unchanged_driver_functions']) == 7
def tests(path):
    text=path.read_text()
    return {n.name:ast.get_source_segment(text,n) for n in ast.walk(ast.parse(text))
            if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
old_tests=tests(HERE/'preimage/Tools/OriginalEditor/test_framework_flow.py')
assert old_tests == tests(HERE/'candidate/Tools/OriginalEditor/test_framework_flow.py') and len(old_tests)==10
groups=[('controls-v1',28),('failure-integration-v1',4),('retention-adapter-v1',8),
        ('diagnostic-recorder-v1',1),('retained-admission-v1',11)]
group_receipts=[]; all_ids=set()
for name,count in groups:
    root=HERE/'evidence'/name; result=read(root/'RESULT.json')
    assert result['status']=='PASS' and result['returncode']==0 and result['source_unchanged'] is True
    assert result['expected_count']==result['passed_count']==count
    expected=result['expected_ids']; assert len(set(expected))==len(expected)==count
    assert sorted(result['started_ids'])==sorted(result['passed_ids'])==sorted(expected)
    assert result['native_execution'] is False
    assert result.get('prior_controls_replayed',result.get('old_controls_replayed'))==0
    stdout=(root/'controls.stdout').read_bytes();stderr=(root/'controls.stderr').read_bytes()
    assert sha(stdout)==result['stdout_sha256'] and sha(stderr)==result['stderr_sha256']
    started=[line.removeprefix('START ') for line in stdout.decode().splitlines() if line.startswith('START ')]
    passed=[line.removeprefix('PASS ') for line in stdout.decode().splitlines() if line.startswith('PASS ')]
    assert sorted(started)==sorted(passed)==sorted(expected)
    assert not set(expected)&all_ids;all_ids.update(expected)
    assert f'Ran {count} test' in stderr.decode() and stderr.decode().rstrip().endswith('OK')
    group_receipts.append({'group':name,'count':count,'result_sha256':sha((root/'RESULT.json').read_bytes()),'raw_start_pass_verified':True})
helper=HERE/'evidence/failure-helper-19/evidence/controls-v1'
hr=read(helper/'RESULT.json')
assert hr['status']=='PASS_NEW_DIAGNOSTIC_HELPER_BOUNDARIES' and hr['returncode']==0
assert hr['passed']==hr['expected_controls']==19 and hr['old_controls_replayed']==hr['native_runs']==0
for name,row in hr['streams'].items():
    b=(helper/name).read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256']
observed=[line for line in (helper/'controls.stderr').read_text().splitlines() if ' ... ' in line]
assert observed==hr['control_events'] and len(set(observed))==19 and all(line.endswith(' ... ok') for line in observed)
for row in read(helper/'SOURCE_BEFORE.json')['files']:
    b=(WORK/row['path']).read_bytes();assert len(b)==row['bytes'] and sha(b)==row['sha256']
assert (WORK/'sdk_consumer_failure_capture/candidate/Tools/OriginalEditor/consumer_failure_capture.py').read_bytes()==(HERE/'candidate/Tools/OriginalEditor/consumer_failure_capture.py').read_bytes()
group_receipts.append({'group':'failure-helper-19','count':19,'result_sha256':sha((helper/'RESULT.json').read_bytes()),'raw_unittest_successes_verified':19})
assert sum(row['count'] for row in group_receipts)==71
# Rebind each control's actually exercised code without replaying it.
before28=read(HERE/'evidence/controls-v1/SOURCE_BEFORE.json')['files']
for name in ('candidate/Anytype.xcodeproj/project.pbxproj','candidate/Tools/OriginalEditor/framework_install_names.py',
             'candidate/Tools/OriginalEditor/framework_profile.py','fixtures/INSTALL_NAME_BINARY_EVIDENCE.json'):
    assert {k:identity(HERE/name)[k] for k in ('bytes','sha256')}==before28[name]
assert sha((HERE/'evidence/controls-v1/EXECUTED_CONTROLS.py').read_bytes())==before28['controls/install_name_controls.py']['sha256']
assert sha((HERE/'evidence/controls-v1/EXECUTED_FLOW_FIXTURE.py').read_bytes())==before28['candidate/Tools/OriginalEditor/test_framework_flow.py']['sha256']
for group,substitutions in [('failure-integration-v1',{'candidate/Tools/OriginalEditor/run_framework_acceptance.py':'evidence/failure-integration-v1/EXECUTED_DRIVER.py','controls/failure_integration_controls.py':'evidence/failure-integration-v1/EXECUTED_CONTROLS.py'}),
                            ('retention-adapter-v1',{}),('diagnostic-recorder-v1',{}),
                            ('retained-admission-v1',{'admission/INPUTS.json':'evidence/retained-admission-v1/EXECUTED_INPUTS.json'})]:
    for name,row in read(HERE/'evidence'/group/'SOURCE_BEFORE.json')['files'].items():
        b=(HERE/substitutions.get(name,name)).read_bytes()
        assert len(b)==row['bytes'] and sha(b)==row['sha256'],(group,name)
# Only the new guard around the diagnostic-error recorder differs in the
# previously exercised launch/observation try block.
def wrapper(path):
    tree=ast.parse(path.read_text())
    matches=[n for n in ast.walk(tree) if isinstance(n,ast.Try)
             and any(isinstance(h,ast.ExceptHandler) and h.name=='diagnostic_error' for h in ast.walk(n))
             and any(isinstance(c,ast.Call) and c.args and isinstance(c.args[0],ast.Name) and c.args[0].id=='launch' for c in ast.walk(n))]
    assert len(matches)==1
    return copy.deepcopy(matches[0])
old_wrapper=wrapper(HERE/'evidence/failure-integration-v1/EXECUTED_DRIVER.py')
current_wrapper=wrapper(HERE/'candidate/Tools/OriginalEditor/run_framework_acceptance.py')
handlers=[n for n in ast.walk(current_wrapper) if isinstance(n,ast.ExceptHandler) and n.name=='diagnostic_error']
assert len(handlers)==1 and len(handlers[0].body)==1 and isinstance(handlers[0].body[0],ast.Try)
guard=handlers[0].body[0]; assert len(guard.handlers)==1 and all(isinstance(n,ast.Pass) for n in guard.handlers[0].body)
handlers[0].body=guard.body
assert ast.dump(current_wrapper)==ast.dump(old_wrapper)
plan=read(HERE/'admission/INPUTS.json')
executed_plan=read(HERE/'evidence/retained-admission-v1/EXECUTED_INPUTS.json')
rebinding=read(HERE/'ADMISSION_INPUT_REBIND.json')
assert sha((HERE/'admission/INPUTS.json').read_bytes())==rebinding['current_plan_sha256']
assert sha((HERE/'evidence/retained-admission-v1/EXECUTED_INPUTS.json').read_bytes())==rebinding['executed_plan_sha256']
old_field=executed_plan['reviewed_source_input_changes']['Tools/OriginalEditor/framework_profile.json']['after']
new_field=plan['reviewed_source_input_changes']['Tools/OriginalEditor/framework_profile.json']['after']
inverse=copy.deepcopy(plan);inverse['reviewed_source_input_changes']['Tools/OriginalEditor/framework_profile.json']['after']=old_field
assert inverse==executed_plan and new_field==identity(HERE/'candidate/Tools/OriginalEditor/framework_profile.json')
# The admitted historical documents are the already retained authentic result,
# inventory and independent review, not newly synthesized current outcomes.
for saved,original,key in [('original-source-controls-result.json','source-controls-result.json','retained_controls'),
                         ('original-source-before.json','source-before.json','retained_source_inventory'),
                         ('ROOT_ORIGINAL_EVIDENCE_REVIEW.json','ROOT_EVIDENCE_REVIEW.json','original_root_evidence_review')]:
    p=HERE/'admission'/saved
    assert p.read_bytes()==(WORK/'sdk_run_45041382512/evidence'/original).read_bytes()
    assert identity(p)==plan[key]
historical=read(HERE/'admission/original-source-controls-result.json')
original=read(HERE/'admission/original-source-before.json')
assert historical['status']=='PASS_SOURCE_CONTROLS_245' and historical['tests_run']==245
catalog=set(historical['expected_ids']);assert len(catalog)==245
for key in ('expected_ids','discovered_ids','started_ids','passed_ids'):
    assert len(historical[key])==245 and set(historical[key])==catalog
assert original['head_sha']=='edce5b975b173059522f90adb71271fb95adf963' and original['run_id']=='45041382512'
changes=plan['reviewed_source_input_changes']; expected=dict(original['source_inputs'])
added=changed=0
for path,row in changes.items():
    assert row['before']==expected.get(path)
    if path in expected:changed+=1
    else:added+=1
    expected[path]=row['after']
    candidate=HERE/'candidate'/path
    if candidate.is_file():assert identity(candidate)==row['after']
assert len(original['source_inputs'])==60 and len(expected)==69 and (changed,added)==(6,9)
ids=plan['current_affected_ids'];assert len(ids)==len(set(ids))==8 and set(ids)<=catalog
workflow=(HERE/'candidate/.github/workflows/pinkha-original-editor-framework.yml').read_text()
assert 'python3 Tools/OriginalEditor/run_source_controls.py ' not in workflow
assert workflow.count('python3 Tools/OriginalEditor/admit_retained_source_controls.py ')==1
assert workflow.count('include-hidden-files: true')==2
assert 'framework_source_inputs.json' not in workflow
receipt={'status':'PASS_ROOT_SDK_INSTALL_NAME_SOURCE_AND_RETAINED_CONTROLS_REVIEW',
    'manifest_sha256':sha((HERE/'SOURCE_MANIFEST.json').read_bytes()),'operational_files':10,
    'project_change':'Exactly four framework-only install-name settings; whole previous project bytes recover after removal',
    'unchanged_driver_functions':7,'unchanged_old_flow_test_bodies':10,
    'new_local_controls':group_receipts,'new_local_total':71,'historical_control_replays':0,
    'historical245_exact_original_bytes_and_identity_sets_verified':True,
    'historical38':'Original edce/450413 evidence only; new native collector remains mandatory',
    'new_source_ledger':{'original':60,'current':69,'changed':6,'added':9,'final_profile_afterimage_verified':True},
    'future_current_affected_ids':ids,'future_eight_executed_by_root':0,
    'executed_admission_plan_later_delta':'Only current profile afterimage binding; original executed plan bytes retained and exact inverse verified',
    'old_error_wrapper_later_delta':'Only guarded diagnostic-error recorder; inverse AST equals four previously executed paths; new failing-recorder path passed once',
    'source_review':['Actual Mach-O gates require exact framework identity and reachable strong consumer load; neither rewrites a binary.',
        'Signature/byte archive adapter requires original successful command and both exact streams before retaining unqualified app bytes.',
        'Bounded exact-app output/crash capture cannot grant acceptance or hide the original launch/observation exception.',
        'Runtime observations and original command/main remain unchanged. Single install300s and bootstatus180s retain their explicit scopes.'],
    'remaining':'Exact final Git69input/75path readback, one genuine build, actual current affected8, current public/Clang/signature/binary gates and en/he observations.'}
(HERE/'ROOT_SOURCE_AND_CONTROLS_REVIEW.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:receipt[k] for k in ('status','operational_files','unchanged_driver_functions','unchanged_old_flow_test_bodies','new_local_total','new_source_ledger')}))
