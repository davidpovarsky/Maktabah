from pathlib import Path
import sys,subprocess,hashlib,json,importlib.util,unittest,time
p=Path(r'C:\Users\DAVID\Code\Maktabah-d5-prebuilt-binding-20261120'); out=p/'build/d5-prebuilt-20261120/acceptance-final2';out.mkdir(parents=True,exist_ok=False)
paths=['Scripts/CI/hq-stage2-focused-apple.py','Scripts/CI/hq-stage2-focused-apple.inputs.json','Scripts/CI/hq-stage2-otzaria-test-additions.json','Tests/CI/test_stage2_prebuilt_bindings.py']
paths += [str(f.relative_to(p)) for f in (p/'Tests/CI/fixtures/d5-prebuilt-20261120').glob('*.json')]
def hashes():return {f:hashlib.sha256((p/f).read_bytes()).hexdigest() for f in paths}
before=hashes();(out/'source-before.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf-8')
spec=importlib.util.spec_from_file_location('test_stage2_prebuilt_bindings',p/'Tests/CI/test_stage2_prebuilt_bindings.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
suite=unittest.defaultTestLoader.loadTestsFromModule(m)
class Results(unittest.TextTestResult):
 def __init__(self,*a,**k):super().__init__(*a,**k);self.passed=[];self.subcases=[]
 def addSuccess(self,test):super().addSuccess(test);self.passed.append(test.id())
 def addSubTest(self,test,subtest,err):super().addSubTest(test,subtest,err);self.subcases.append({'id':subtest.id(),'result':'PASS' if err is None else 'FAIL'})
start=time.monotonic()
with (out/'tests.log').open('w',encoding='utf-8') as log:r=unittest.TextTestRunner(stream=log,verbosity=2,resultclass=Results).run(suite)
after=hashes(); summary={'checkout_sha':subprocess.check_output(['git','rev-parse','HEAD'],cwd=p,text=True).strip(),'elapsed_s':round(time.monotonic()-start,3),'tests_run':r.testsRun,'passed':r.passed,'failures':[(t.id(),e) for t,e in r.failures],'errors':[(t.id(),e) for t,e in r.errors],'skipped':[(t.id(),e) for t,e in r.skipped],'subcases':r.subcases,'source_before':before,'source_after':after,'source_unchanged':before==after,'apple_or_native_execution':False}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
with (out/'macro-original4.log').open('w',encoding='utf-8') as log:macro=subprocess.run([sys.executable,'Scripts/CI/test_hq_stage2_macro_trust.py'],cwd=p,stdout=log,stderr=subprocess.STDOUT,timeout=60)
summary['macro_original4_exit']=macro.returncode
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary));print((out/'tests.log').read_text(encoding='utf-8'));print((out/'macro-original4.log').read_text(encoding='utf-8'))
assert before==after and r.wasSuccessful() and r.testsRun==36 and macro.returncode==0
