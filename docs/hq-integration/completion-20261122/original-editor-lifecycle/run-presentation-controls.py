#!/usr/bin/env python3
"""Focused actual presentation logic with explicit portable dependency probes."""
from pathlib import Path
import hashlib,json,subprocess,os,sys,re,time
ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
OUT=HERE/'validation'
OUT.mkdir(exist_ok=False)
ui=ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationOriginalEditorQualificationUI.swift'
models=ROOT/'Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorModels.swift'
text=ui.read_text(encoding='utf-8')
start=text.index('private enum AnnotationOriginalEditorQualificationUIError:')
end=text.index('\n#if canImport(AnytypeOriginalEditor)',start)
error=text[start:end]
start=text.index('@MainActor @Observable\nprivate final class AnnotationOriginalEditorQualificationPresentation:')
end=text.index('\n@MainActor\nprivate struct AnnotationOriginalEditorQualificationView:',start)
presentation=text[start:end]
original=models.read_text(encoding='utf-8')
start=original.index('final class AnnotationLocalEditorLifetime:')
end=original.index('\n/// Captured together',start)
lifetime=original[start:end]
assembled='import Foundation\nimport Observation\nimport Synchronization\n\n'+(HERE/'probes.swift').read_text(encoding='utf-8')+'\n'+lifetime+'\n'+error+'\n'+presentation+'\n'+(HERE/'controls.swift').read_text(encoding='utf-8')
swift=OUT/'PresentationControls.swift'
swift.write_text(assembled,encoding='utf-8',newline='\n')
paths=[ui,models,HERE/'probes.swift',HERE/'controls.swift',Path(__file__).resolve(),swift]
manifest={'schema':1,'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'extraction':{'presentation':'exact complete private class, including Observation annotation and isolated deinit; original wrappers excluded','lifetime':'exact complete original lifetime','error':'exact original error enum','dependencies':'explicit SDK/data/filesystem probes; no Apple/framework/SQLite/CloudKit acceptance'},
 'inputs':[{'path':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in paths],
 'presentation_sha256':hashlib.sha256(presentation.encode()).hexdigest(),'lifetime_sha256':hashlib.sha256(lifetime.encode()).hexdigest()}
(OUT/'SOURCE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
version=subprocess.run(['swiftc','--version'],capture_output=True,text=True,check=True).stdout
exe=OUT/'presentation-controls.exe'
command=['swiftc','-swift-version','6','-j','1','-parse-as-library',str(swift),'-o',str(exe)]
start=time.monotonic()
compile=subprocess.run(command,capture_output=True,text=True,timeout=180)
(OUT/'compile.stdout.log').write_text(compile.stdout,encoding='utf-8',newline='\n')
(OUT/'compile.stderr.log').write_text(compile.stderr,encoding='utf-8',newline='\n')
result={'toolchain':version,'compile_exit':compile.returncode,'compile_seconds':time.monotonic()-start,'command':command,'execution':'NOT_RUN'}
if compile.returncode==0:
 env=os.environ.copy()
 evidence=OUT/'actual-reports'
 evidence.mkdir()
 env['QUALIFICATION_PROBE_ROOT']=str(evidence)
 run=subprocess.run([str(exe)],capture_output=True,text=True,timeout=45,env=env)
 (OUT/'run.stdout.log').write_text(run.stdout,encoding='utf-8',newline='\n')
 (OUT/'run.stderr.log').write_text(run.stderr,encoding='utf-8',newline='\n')
 result.update(execution='PASS' if run.returncode==0 else 'FAIL',run_exit=run.returncode)
 if run.returncode==0:
  result['controls']=json.loads(run.stdout)
 # The binary is reproducible and its bytes are recorded, not committed.
 result['binary_sha256']=hashlib.sha256(exe.read_bytes()).hexdigest()
result['syntax']=[]
for name in ['AnnotationOriginalEditorQualificationUI.swift','AnnotationOriginalEditorQualification.swift','AnnotationOriginalEditorSourceObservation.swift']:
 source=ROOT/'Source/ChavrusaText/Annotations/LocalEditor'/name
 active=re.sub(r'^#if .+$','#if true',source.read_text(encoding='utf-8'),flags=re.M)
 target=OUT/('active-'+name);target.write_text(active,encoding='utf-8',newline='\n')
 checked=subprocess.run(['swiftc','-frontend','-parse',str(target)],capture_output=True,text=True,timeout=30)
 (OUT/('parse-'+name+'.stdout.log')).write_text(checked.stdout,encoding='utf-8',newline='\n')
 (OUT/('parse-'+name+'.stderr.log')).write_text(checked.stderr,encoding='utf-8',newline='\n')
 result['syntax'].append({'path':str(source.relative_to(ROOT)).replace('\\','/'),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'active_source_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'exit':checked.returncode})
(OUT/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(result,indent=2))
sys.exit(0 if result.get('run_exit')==0 and all(x['exit']==0 for x in result['syntax']) else 1)
