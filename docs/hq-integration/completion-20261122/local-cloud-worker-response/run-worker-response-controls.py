#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,subprocess,sys,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
OUT=HERE/'validation';OUT.mkdir(exist_ok=False)
ownership=ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudOwnership.swift'
cloudkit=ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorCloudKit.swift'
source=ownership.read_text(encoding='utf-8')
start=source.index('/// Transport completion for the existing optional worker notification only.')
end=source.index('struct AnnotationLocalEditorCloudCompletion:',start)
helper=source[start:end]
assert (HERE/'WorkerResponse.swift').read_text(encoding='utf-8')=='import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n\n'+helper
assert 'AnnotationLocalEditorCloudWorkerResponse.result(\n                        response: response, error: error' in cloudkit.read_text(encoding='utf-8')
paths=[ownership,cloudkit,HERE/'WorkerResponse.swift',HERE/'OriginalCompletion.swift',HERE/'original-worker-callback.txt',HERE/'controls.swift',Path(__file__).resolve()]
manifest={'schema':1,'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'scope':'new downstream HTTP classifier and exact previous callback statements; real Foundation responses; zero network or CloudKit',
 'helper_sha256':hashlib.sha256(helper.encode()).hexdigest(),
 'inputs':[{'path':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in paths]}
(OUT/'SOURCE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
exe=OUT/'worker-response-controls.exe'
command=['swiftc','-swift-version','6','-j','1','-parse-as-library',str(HERE/'WorkerResponse.swift'),str(HERE/'OriginalCompletion.swift'),str(HERE/'controls.swift'),'-o',str(exe)]
start=time.monotonic();build=subprocess.run(command,capture_output=True,text=True,timeout=180)
(OUT/'compile.stdout.log').write_text(build.stdout,encoding='utf-8',newline='\n')
(OUT/'compile.stderr.log').write_text(build.stderr,encoding='utf-8',newline='\n')
result={'toolchain':subprocess.check_output(['swiftc','--version'],text=True),'compile_exit':build.returncode,'compile_seconds':time.monotonic()-start,'execution':'NOT_RUN','command':command}
if build.returncode==0:
 run=subprocess.run([str(exe)],capture_output=True,text=True,timeout=20)
 (OUT/'run.stdout.log').write_text(run.stdout,encoding='utf-8',newline='\n')
 (OUT/'run.stderr.log').write_text(run.stderr,encoding='utf-8',newline='\n')
 result.update(execution='PASS' if run.returncode==0 else 'FAIL',run_exit=run.returncode,binary_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
 if run.returncode==0:result['controls']=json.loads(run.stdout)
result['syntax']=json.loads((HERE/'attempt1-foundation-networking/RESULT.json').read_text())['syntax']
for row in result['syntax']:
 assert row['exit']==0 and hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256']
result['syntax_reused_from']='attempt1-foundation-networking/RESULT.json; exact unchanged source bytes, zero repeated parses'
(OUT/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(result,indent=2))
sys.exit(0 if result.get('run_exit')==0 and all(p['exit']==0 for p in result['syntax']) else 1)
