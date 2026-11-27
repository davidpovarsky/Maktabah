import json,hashlib,subprocess,tarfile,datetime
from pathlib import Path
b=Path('/Users/m1/builds/otzaria-wave3-feature-intents-20261127');p=b/'apple-sdk-attempt-1'
out=b/'evidence-export-1';out.mkdir(exist_ok=False)
files=[]
for f in (p/'swift-build').rglob('*'):
 if f.is_file()and(f.name.endswith('.swiftmodule')or f.name in('NativeFeatureIntents.o','NativeIntentService.o')or f.name.endswith('.SwiftFileList')):
  row={'path':str(f.relative_to(p)),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'file':subprocess.run(['/usr/bin/file',str(f)],capture_output=True,text=True,check=True).stdout.strip()}
  files.append(row)
  if f.name.endswith('.SwiftFileList'):(out/f.name).write_bytes(f.read_bytes())
  if f.name=='NativeFeatureIntents.o':
   q=subprocess.run(['xcrun','vtool','-show-build',str(f)],capture_output=True,text=True)
   (out/'NativeFeatureIntents.vtool.txt').write_text(q.stdout+q.stderr)
   row['vtoolExit']=q.returncode
   if q.returncode or 'IOSSIMULATOR'not in q.stdout:raise RuntimeError('Expected iOS Simulator object')
   q=subprocess.run(['xcrun','nm',str(f)],capture_output=True,text=True,check=True)
   lines=[x for x in q.stdout.splitlines()if any(y in x for y in['OpenSettingsSectionIntent','OpenReaderContentsIntent','OpenReadingHistoryIntent'])]
   if not all(any(y in x for x in lines)for y in['OpenSettingsSectionIntent','OpenReaderContentsIntent','OpenReadingHistoryIntent']):raise RuntimeError('Missing actual intent compiled symbols')
   (out/'NativeFeatureIntents.symbols.txt').write_text('\n'.join(lines)+'\n')
if len([x for x in files if x['path'].endswith('/NativeFeatureIntents.o')])!=1:raise RuntimeError('Missing unique actual object')
filelist=(out/'ChavrusaUIRoutingHost.SwiftFileList').read_text()
if '/NativeFeatureIntents.swift'not in filelist:raise RuntimeError('New file not in compiler source list')
ob={'status':'ACTUAL_IOS27_COMPONENT_ARTIFACTS_OBSERVED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'artifacts':files,'originalResultSHA256':hashlib.sha256((p/'RESULT.json').read_bytes()).hexdigest(),'originalResultUntouched':True,'originalResultModulesArrayNote':'Original glob expected Modules layout; SwiftPM27 emitted out/Products and Intermediates. This separate observation records actual artifacts without rewriting original receipt.','nativeExecutions':0,'fullAppBuilds':0}
(out/'ARTIFACT_OBSERVATION.json').write_text(json.dumps(ob,indent=2)+'\n')
members={}
for f in out.iterdir():
 if f.is_file():members['apple-observation/'+f.name]=f
for f in p.iterdir():
 if f.is_file():members['apple/'+f.name]=f
members['apple/INPUT_MANIFEST.json']=b/'source/INPUT_MANIFEST.json'
members['apple/TRANSFER_RESULT.json']=b/'TRANSFER_RESULT.json'
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':[{'path':k,'bytes':v.stat().st_size,'sha256':hashlib.sha256(v.read_bytes()).hexdigest()}for k,v in sorted(members.items())]}
mf=out/'MANIFEST.json';mf.write_text(json.dumps(manifest,indent=2)+'\n');members['MANIFEST.json']=mf
a=out/'apple-evidence.tar.gz'
with tarfile.open(a,'w:gz')as t:
 for k,v in sorted(members.items()):t.add(v,arcname=k,recursive=False)
print(json.dumps({'archive':str(a),'bytes':a.stat().st_size,'sha256':hashlib.sha256(a.read_bytes()).hexdigest(),'manifestSHA256':hashlib.sha256(mf.read_bytes()).hexdigest(),'memberFiles':len(members),'observationSHA256':hashlib.sha256((out/'ARTIFACT_OBSERVATION.json').read_bytes()).hexdigest()}))
