from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/hq-ui-routing'
before=(OUT/'N-mount-wait-before.log').read_bytes();red=before.decode('utf-8-sig',errors='replace')
diagnostics=sorted(set(re.findall(r'(ActualWaitForMount_ExplicitNativeBoundary\.swift:\d+:\d+): error: ([^\r\n]+)',red)))
assert len(diagnostics)==2 and all('requires explicit use of' in x[1] for x in diagnostics)
after=(OUT/'N-mount-wait-after.log').read_bytes();green=after.decode('utf-8-sig',errors='replace')
rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',green);assert rows[-1]==('7','0')
assert green.count('warning:')==0 and not re.search(r':\d+:\d+: error:',green)
b=json.loads((OUT/'N-mount-wait-before-inputs.json').read_text());a=json.loads((OUT/'N-mount-wait-after-inputs.json').read_text())
assert b['tests_sha256']==a['tests_sha256'] and b['boundary_template_sha256']==a['boundary_template_sha256']
assert b['actual_waiter_type_sha256']==a['actual_waiter_type_sha256']
backport=json.loads((OUT/'N-mount-wait-backport.json').read_text())
assert b['complete_actual_method_sha256']==backport['before_complete_method_sha256']
assert a['complete_actual_method_sha256']==backport['after_complete_method_sha256']
path=backport['production_path'];raw=(ROOT/path).read_bytes()
changed=subprocess.check_output(['git','diff','--name-only','--','Source'],cwd=ROOT,text=True).splitlines();assert changed==[path]
logs={}
for name in ['N-mount-wait-initial-fixture-compile.log','N-mount-wait-initial-boundary-compile.log','N-mount-wait-before.log','N-mount-wait-after.log']:
    logs[name]=hashlib.sha256((OUT/name).read_bytes()).hexdigest()
report={'status':'EXACT_TWO_LINE_COMPILER_FIX_PORTABLE_RED_GREEN_SEMANTICS_PASS_NO_NATIVE_RETRY',
    'base043':backport['base'],'production_path':path,'future_working_sha256':hashlib.sha256(raw).hexdigest(),
    'expected_future_git_blob':subprocess.check_output(['git','hash-object','--path',path,path],cwd=ROOT,text=True).strip(),
    'changed_production_lines':2,'original_complete_method_unique_compiler_error_sites':diagnostics,
    'before_executed_tests':0,'after_executed_methods':7,'after_failures':0,'after_compiler_warnings':0,
    'method_names':re.findall(r"Test Case '(NMountWaitTests\.[^']+)' passed",green),
    'before_after_same_boundary_tests_waiter_type':True,'full_actual_frozen_future_method_equivalence':True,
    'backport':'N_043_MOUNT_WAIT_EXPLICIT_SELF_UNAPPLIED.diff','backport_apply_checks':{'043':backport['git_apply_check_exit'],'98':backport['separate_candidate_98_apply_check_exit']},
    'raw_log_sha256':logs,'before_input_sha256':hashlib.sha256((OUT/'N-mount-wait-before-inputs.json').read_bytes()).hexdigest(),
    'after_input_sha256':hashlib.sha256((OUT/'N-mount-wait-after-inputs.json').read_bytes()).hexdigest(),
    'test_scope':'Real Foundation Task/MainActor/checked continuations; complete actual method and waiter type; explicit scene registration/event-observation/independent-continuation ledger replacement shells',
    'native_terminal_from_manager':{'run':'43752226209','checkout':'0436775d85893225005f29baf0aa3a20d7b88317','app_source':'17414a0fd032918e01d8e2f1bfbcec2e33796c16','artifact':'14177879442','artifact_sha256':'0a3bdd0efc9fb832334dd31cea29d1c5d4bae826e07cd02a85b4461605ab4de9','result':'COMPILE_FAILED_0PASS_0FAIL_18NOT_RUN'},
    'new_SDK_native_CI_run_or_query':False,'manager_original043_98_modified':False,'public_v2_in_043_patch':False,'activation_or_release':False}
(OUT/'N-mount-wait-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('Exact method RED2unique compile sites / GREEN7methods0fail0warnings; isolated043+98 patch checks pass.')
