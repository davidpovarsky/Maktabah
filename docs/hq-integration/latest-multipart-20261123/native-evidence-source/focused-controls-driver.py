
from pathlib import Path
import importlib.util, unittest, io, contextlib, json, hashlib, datetime, subprocess, ast
w=Path('/mnt/development/projects/worktrees/Maktabah-multipart-native-evidence-20261123')
d=Path('/mnt/development/projects/diagnostics/otzaria-multipart-native-evidence-20261123/peer-delta')
source=w/'Scripts/CI/test_otzaria_bootstrap_evidence.py'
new=[
 'BootstrapEvidenceControls.test_install_final_path_must_be_absolute_and_present',
 'BootstrapEvidenceControls.test_restore_final_path_must_be_absolute_and_present',
 'BootstrapEvidenceControls.test_cancel_errors_are_rejected_despite_pass_boolean',
 'NativeBootstrapSimulatorSelectionControls.test_empty_explicit_owned_id_never_falls_back',
 'NativeBootstrapSimulatorSelectionControls.test_valid_owned_sdk_matched_ipad_is_selected',
 'NativeBootstrapSimulatorSelectionControls.test_absent_owned_id_preserves_original_selection']
affected=[
 'BootstrapEvidenceControls.test_three_original_phases_require_actual_nonzero_resume',
 'BootstrapEvidenceControls.test_restore_count_change_is_rejected',
 'BootstrapEvidenceControls.test_native_sqlite_failure_cannot_be_relabelled_by_pass_boolean']
selected=new+affected
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
paths=['Scripts/CI/otzaria_bootstrap_evidence.py','Scripts/CI/test_otzaria_bootstrap_evidence.py','Scripts/run-otzaria-native-bootstrap-acceptance.sh','.github/workflows/ios-build.yml']
before={p:sha(w/p) for p in paths}
module_name='actual_bootstrap_peer_delta_controls'
spec=importlib.util.spec_from_file_location(module_name,source)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
suite=unittest.defaultTestLoader.loadTestsFromNames(selected,module)
class Result(unittest.TextTestResult):
 def __init__(self,*a,**kw):super().__init__(*a,**kw);self.started=[];self.passed=[]
 def startTest(self,test):self.started.append(test.id());super().startTest(test)
 def addSuccess(self,test):self.passed.append(test.id());super().addSuccess(test)
stream=io.StringIO()
with contextlib.redirect_stdout(stream),contextlib.redirect_stderr(stream):
 result=unittest.TextTestRunner(stream=stream,verbosity=2,resultclass=Result).run(suite)
log=d/'nine-new-and-affected-controls.log';log.write_text(stream.getvalue())
syntax=subprocess.run(['bash','-n','Scripts/run-otzaria-native-bootstrap-acceptance.sh'],cwd=w,capture_output=True,text=True)
(d/'shell-syntax.log').write_text(syntax.stdout+syntax.stderr)
diff=subprocess.run(['git','-C',str(w),'diff','--check'],capture_output=True,text=True)
(d/'diff-whitespace.log').write_text(diff.stdout+diff.stderr)
for p in paths[:2]:ast.parse((w/p).read_bytes())
expected=[module_name+'.'+name for name in selected]
ok=(result.testsRun==9 and result.started==expected and result.passed==expected and result.wasSuccessful() and not result.failures and not result.errors and not result.skipped and not result.expectedFailures and not result.unexpectedSuccesses and syntax.returncode==diff.returncode==0 and before=={p:sha(w/p) for p in paths})
receipt={'schema':'otzaria.multipart-native-evidence-peer-controls/1','at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS' if ok else 'FAIL','new_controls':6,'affected_original_controls_rerun':3,'tests_run':result.testsRun,'expected_ids':expected,'started_ids':result.started,'passed_ids':result.passed,'failures':[t.id() for t,_ in result.failures],'errors':[t.id() for t,_ in result.errors],'skipped':[t.id() for t,_ in result.skipped],'source_inputs':before,'inputs_stable':before=={p:sha(w/p) for p in paths},'shell_syntax_returncode':syntax.returncode,'python_AST_parse':'PASS','diff_whitespace_returncode':diff.returncode,'log_sha256':sha(log),'native_execution':False,'simctl_executed':False,'apple_toolchain_executed':False,'selector_source':'Exact embedded Python selector extracted from actual shell script; only subprocess.check_output is replaced by explicit read-only inventory fixtures. No CI environment is fabricated.','historical37_component_tests_replayed':0}
p=d/'RESULT.json';p.write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
print(stream.getvalue())
print(json.dumps({'status':receipt['status'],'receipt':str(p),'receipt_sha256':sha(p),'tests_run':result.testsRun,'new':6,'affected':3},indent=2))
if not ok:raise SystemExit(1)
