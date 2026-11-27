import subprocess,json,hashlib,datetime,os,signal,time
from pathlib import Path
b=Path('/Users/m1/builds/otzaria-wave3-feature-intents-20261127')
source=b/'source';out=b/'apple-sdk-attempt-1';out.mkdir(exist_ok=False)
manifest=json.loads((source/'INPUT_MANIFEST.json').read_text())
for row in manifest['files']:
 x=(source/row['path']).read_bytes()
 if len(x)!=row['bytes']or hashlib.sha256(x).hexdigest()!=row['sha256']:raise RuntimeError('Source input changed '+row['path'])
sdk=subprocess.run(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],capture_output=True,text=True,check=True).stdout.strip()
def free():return int(subprocess.run(['df','-k','/System/Volumes/Data'],capture_output=True,text=True,check=True).stdout.splitlines()[1].split()[3])*1024
cmd=['xcrun','swift','build','--package-path',str(source/'Source/ChavrusaText/UIRoutingHost'),'--scratch-path',str(out/'swift-build'),'--triple','arm64-apple-ios27.0-simulator','--sdk',sdk,'--target','ChavrusaUIRoutingHost','--jobs','2']
state={'schema':1,'status':'RUNNING','started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':cmd,'sdk':sdk,'freeBefore':free(),'manifestSHA256':hashlib.sha256((source/'INPUT_MANIFEST.json').read_bytes()).hexdigest(),'inputFiles':len(manifest['files']),'scope':'Original source Core/UIRouting and complete Host package compilation for actual iOS27 simulator SDK; no app, simulator UI or system Intent invocation','newNativeTests':0}
if state['freeBefore']<3221225472:raise RuntimeError('Insufficient bounded component compile budget')
def save(name='STATUS.json'):(out/name).write_text(json.dumps(state,indent=2)+'\n')
save()
stopped=False
with (out/'build.stdout.log').open('wb')as so,(out/'build.stderr.log').open('wb')as se:
 p=subprocess.Popen(cmd,stdout=so,stderr=se,start_new_session=True,cwd=source)
 state.update(pid=p.pid,pgid=p.pid);save()
 while p.poll()is None:
  f=free()
  if f<2415919104:
   stopped=True;state['interruption']='Shared free below2GiB+256MiB reserve';os.killpg(p.pid,signal.SIGINT);break
  time.sleep(2)
 try:rc=p.wait(timeout=30)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGTERM);rc=p.wait(timeout=15)
state['buildExit']=rc
if rc==0:
 loc=out/'compiled-localizations';loc.mkdir()
 argv=['xcrun','xcstringstool','compile','--output-directory',str(loc),str(source/'Source/Localizable.xcstrings')]
 q=subprocess.run(argv,capture_output=True)
 (out/'localizations.stdout.log').write_bytes(q.stdout);(out/'localizations.stderr.log').write_bytes(q.stderr)
 state['localizations']={'command':argv,'exit':q.returncode,'outputs':[str(p.relative_to(loc))for p in loc.rglob('*')if p.is_file()]}
 if q.returncode:rc=q.returncode
for row in manifest['files']:
 x=(source/row['path']).read_bytes()
 if len(x)!=row['bytes']or hashlib.sha256(x).hexdigest()!=row['sha256']:raise RuntimeError('Source changed during compile '+row['path'])
state.update(status='PASS_COMPONENT_APPLE_SDK_ONLY'if rc==0 else'NOT_COMPLETE'if stopped else'FAIL',finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),freeAfter=free())
state['logs']={p.name:{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in out.glob('*.log')}
state['modules']=[{'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in (out/'swift-build').glob('**/Modules/*.swiftmodule')if p.is_file()]
save('RESULT.json');save()
print(json.dumps({'result':state,'receiptSHA256':hashlib.sha256((out/'RESULT.json').read_bytes()).hexdigest(),'stdoutTail':(out/'build.stdout.log').read_text(errors='replace')[-8000:],'stderrTail':(out/'build.stderr.log').read_text(errors='replace')[-8000:]}))
raise SystemExit(rc)
