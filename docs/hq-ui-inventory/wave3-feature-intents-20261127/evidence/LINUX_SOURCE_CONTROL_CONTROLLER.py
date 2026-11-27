import subprocess,json,datetime,hashlib,os,signal,time,shutil
from pathlib import Path
t=Path('/mnt/development/projects/worktrees/Maktabah-wave3-feature-intents-20261127')
pkg=t/'Source/ChavrusaText/UIRoutingHost'
out=t/'build/feature-intent-service-controls-20261127';out.mkdir(parents=True,exist_ok=False)
swift=shutil.which('swift')
helpout=subprocess.run([swift,'test','--help'],capture_output=True,text=True,check=True)
(out/'swift-test-help.txt').write_text(helpout.stdout)
version=subprocess.run([swift,'--version'],capture_output=True,text=True,check=True).stdout
if '--scratch-path' not in helpout.stdout or '--filter'not in helpout.stdout:raise RuntimeError('Actual SwiftPM flags unavailable')
cmd=[swift,'test','--package-path',str(pkg),'--scratch-path',str(out/'swift-build'),'--jobs','2','--filter','Native(Feature)?IntentServiceTests']
files=sorted(list((t/'Source/Otzaria/Actions').rglob('*.swift'))+list((t/'Source/Otzaria/UIRouting').rglob('*.swift'))+list(pkg.rglob('*.swift')))
inputs={str(p.relative_to(t)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in files}
(out/'SOURCE_INPUTS.json').write_text(json.dumps(inputs,indent=2)+'\n')
state={'schema':1,'status':'RUNNING','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':cmd,'version':version,'scope':'Actual original Foundation Core/UIRouting/NativeIntentService SwiftPM build and selected XCTest classes; iOS AppIntents source is platform-conditional, Apple SDK typecheck/native still required','newNativeTests':0,'freeBefore':shutil.disk_usage(t).free}
if state['freeBefore']<1000000000:raise RuntimeError('Insufficient measured source-control budget')
(out/'STATUS.json').write_text(json.dumps(state,indent=2)+'\n')
with (out/'stdout.log').open('wb')as so,(out/'stderr.log').open('wb')as se:
 p=subprocess.Popen(cmd,stdout=so,stderr=se,start_new_session=True,cwd=str(t))
 state.update(pid=p.pid,pgid=p.pid);(out/'STATUS.json').write_text(json.dumps(state,indent=2)+'\n')
 interrupted=False
 while p.poll()is None:
  free=shutil.disk_usage(t).free
  if free<600000000:
   interrupted=True;state['interruption']='Free space below bounded600MB floor';os.killpg(p.pid,signal.SIGINT);break
  time.sleep(2)
 try:rc=p.wait(timeout=30)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGTERM);rc=p.wait(timeout=15)
state.update(status='PASS'if rc==0 else'NOT_COMPLETE'if interrupted else'FAIL',exit=rc,finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),freeAfter=shutil.disk_usage(t).free)
state['logs']={n:{'bytes':(out/n).stat().st_size,'sha256':hashlib.sha256((out/n).read_bytes()).hexdigest()}for n in ['stdout.log','stderr.log']}
(out/'RESULT.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'result':state,'stdoutTail':(out/'stdout.log').read_text(errors='replace')[-10000:],'stderrTail':(out/'stderr.log').read_text(errors='replace')[-5000:],'receiptSHA256':hashlib.sha256((out/'RESULT.json').read_bytes()).hexdigest()}))
raise SystemExit(rc)
