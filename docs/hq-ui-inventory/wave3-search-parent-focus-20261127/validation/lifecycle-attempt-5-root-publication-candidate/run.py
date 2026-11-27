
import subprocess,json,time,os,signal,hashlib
from pathlib import Path
d=Path(__file__).parent
cache=Path('/mnt/development/projects/diagnostics/otzaria-wave3-search-entry-20261127/module-cache')
cache.mkdir(parents=True,exist_ok=True)
def size(path):return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())
def free():v=os.statvfs(d);return v.f_bavail*v.f_frsize
files=sorted(str(p) for p in d.glob('*.swift'))
cmd=['/usr/local/bin/swiftc','-swift-version','6','-parse-as-library','-module-name','SearchEntrySourceControls','-module-cache-path',str(cache),*files,'-o',str(d/'Controls')]
result={'scope':'Actual source/component lifecycle with explicit domain/UIKit/Combine/lifetime boundary; NOT app SDK/native acceptance','command':cmd,'free_before':free(),'cache_before':size(cache),'compiler':subprocess.check_output(['/usr/local/bin/swiftc','--version'],text=True),'source_inputs':json.loads((d/'INPUTS.json').read_text())['source_inputs'],'native_tests_executed':0}
start=time.time();stopped=None
with (d/'COMPILE.log').open('w') as log:
 p=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 (d/'PID.json').write_text(json.dumps({'driver':os.getpid(),'compiler':p.pid})+'\n')
 while p.poll() is None:
  if free()<512*1024*1024 or size(cache)>96*1024*1024 or time.time()-start>90:
   stopped='bounded_free_space_cache_or_runtime';os.killpg(p.pid,signal.SIGTERM);break
  time.sleep(0.25)
 try:code=p.wait(timeout=5)
 except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);code=p.wait()
result.update(compile_exit=code,compile_seconds=round(time.time()-start,3),stopped=stopped,free_after_compile=free(),cache_after=size(cache),compile_log_sha256=hashlib.sha256((d/'COMPILE.log').read_bytes()).hexdigest())
if code==0:
 with (d/'RUN.log').open('w') as log:
  run=subprocess.run([str(d/'Controls')],stdout=log,stderr=subprocess.STDOUT,timeout=20)
 result.update(run_exit=run.returncode,run_log_sha256=hashlib.sha256((d/'RUN.log').read_bytes()).hexdigest())
result['harness_files']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(d.glob('*.swift'))}
(d/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
