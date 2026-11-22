#!/usr/bin/env python3
"""Exact original Core termination callback wiring; no request/CloudKit execution."""
from pathlib import Path
import hashlib,json,subprocess,sys,time,traceback
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
CORE=ROOT/'Source/Core/CloudKit/CloudKitCoreManager.swift'
OWNER=ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudOwnership.swift'
PRIOR=ROOT/'docs/hq-integration/completion-20261122/local-cloud-worker-response'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,value):p.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n',encoding='utf-8',newline='\n')
def main():
 out=HERE/'validation';out.mkdir(exist_ok=False)
 build=HERE/'build';build.mkdir(exist_ok=False)
 old=(HERE/'original-callback.txt').read_text().rstrip('\n')
 new=(HERE/'candidate-callback.txt').read_text().rstrip('\n')
 original=(HERE/'CoreManager-before.swift').read_text()
 current=CORE.read_text()
 assert original.count(old)==1 and current.count(new)==1
 assert original.replace(old,'CALLBACK')==current.replace(new,'CALLBACK')
 assert 'let timeoutResult = semaphore.wait(timeout: .now() + 3.0)' in current
 generated=(HERE/'ExactCallbacks.swift').read_text()
 for callback in [old,new]:
  closure=callback[callback.index('{'):callback.rindex('}.resume()')+1]
  assert generated.count(closure)==1
 prior=json.loads((PRIOR/'validation/SOURCE_MANIFEST.json').read_text())
 prior_result=json.loads((PRIOR/'validation/RESULT.json').read_text())
 assert prior_result['controls']['count']==16 and prior_result['execution']=='PASS'
 for p in [OWNER,PRIOR/'WorkerResponse.swift']:
  expected=next(x for x in prior['inputs'] if x['path']==p.relative_to(ROOT).as_posix())
  assert sha(p)==expected['sha256']
 excerpt=(PRIOR/'WorkerResponse.swift').read_text().split('\n\n',1)[1].rstrip()
 assert OWNER.read_text().count(excerpt)==1
 inputs=[CORE,OWNER,PRIOR/'WorkerResponse.swift',HERE/'CoreManager-before.swift',
  HERE/'original-callback.txt',HERE/'candidate-callback.txt',HERE/'ExactCallbacks.swift',HERE/'controls.swift',Path(__file__).resolve()]
 before={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
 write(out/'SOURCE_MANIFEST.json',{'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  'inputs':before,'outside_callback_unchanged':True,'original_three_second_wait_unchanged':True,
  'classifier16_reused':str((PRIOR/'validation/RESULT.json').relative_to(ROOT)).replace('\\','/'),
  'new_controls':'Only callback-to-Mutex error state and one semaphore signal; original classifier suite is not reexecuted.',
  'boundary':'URLSession transport invocation replaced by exact @Sendable callback invocation in a small harness; no full CloudKitCoreManager typecheck or network.'})
 result={'status':'FAILED','commands':[],'network_requests':0,'cloudkit_runtime_executed':0,'native_ui_executed':0,'prior_classifier16_reexecuted':False}
 try:
  result['toolchain']=subprocess.check_output(['swiftc','--version'],text=True).strip()
  exe=build/'core-worker-callback.exe'
  command=['swiftc','-swift-version','6','-j','1','-parse-as-library',str(PRIOR/'WorkerResponse.swift'),
   str(HERE/'ExactCallbacks.swift'),str(HERE/'controls.swift'),'-o',str(exe)]
  for label,args,timeout in [('compile',command,180),('run',[str(exe)],30)]:
   start=time.monotonic();completed=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',timeout=timeout)
   (out/(label+'.stdout.log')).write_text(completed.stdout,encoding='utf-8',newline='\n')
   (out/(label+'.stderr.log')).write_text(completed.stderr,encoding='utf-8',newline='\n')
   result['commands'].append({'label':label,'command':args,'exit':completed.returncode,'seconds':time.monotonic()-start})
   assert completed.returncode==0,label+' failed'
   if label=='run':result['controls']=json.loads(completed.stdout)
  assert result['controls']['status']=='PASS_EXACT_TERMINATION_CALLBACK_WIRING' and result['controls']['passed']==4
  result['executable_sha256']=sha(exe)
  result['status']='PASS_EXACT_TERMINATION_CALLBACK_WIRING'
 except Exception as error:
  result['error']=repr(error);(out/'failure.log').write_text(traceback.format_exc(),encoding='utf-8',newline='\n')
 finally:
  result['source_unchanged']=before=={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
  if not result['source_unchanged']:result['status']='FAILED'
  write(out/'RESULT.json',result);print(json.dumps(result,indent=2),flush=True)
 return 0 if result['status']=='PASS_EXACT_TERMINATION_CALLBACK_WIRING' else 1
if __name__=='__main__':sys.exit(main())
