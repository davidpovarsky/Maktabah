import pathlib,subprocess,json,os,signal,time,datetime,shutil,hashlib
root=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-search-results-intent-20261127')
base=root/'build/search-intent-service-controls-20261127'
out=base/'attempt-1'
cache=pathlib.Path('/mnt/development/projects/worktrees/Maktabah-wave3-feature-intents-20261127/build/feature-intent-service-controls-20261127/swift-build')
def utc(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
assert not out.exists(),'fresh output'
assert cache.is_dir() and (base/'PRESERVATION.json').is_file(),'preserved cache required'
free=shutil.disk_usage(root).free
assert free>320*1024*1024,'Oracle reserve plus compilation headroom'
out.mkdir()
paths=[]
for prefix in ['Source/Otzaria/Actions','Source/Otzaria/UIRouting','Source/ChavrusaText/UIRoutingHost']:
 for p in sorted((root/prefix).rglob('*')):
  if p.is_file() and '.build' not in p.parts and 'build' not in p.parts:
   paths.append({'path':str(p.relative_to(root)),'bytes':p.stat().st_size,'sha256':digest(p)})
sourcefile=out/'SOURCE_INPUTS.json';sourcefile.write_text(json.dumps({'base':'1a4d64dca46b61ea3d9dbcab5d152dc618f2be39','files':paths},indent=2)+'\n')
cmd=['/usr/local/bin/swift','test','--package-path',str(root/'Source/ChavrusaText/UIRoutingHost'),
 '--scratch-path',str(cache),'--jobs','2','--filter','Native(Search|Reader|Feature)?IntentServiceTests']
record={'schema':1,'status':'RUNNING','started_at':utc(),'command':cmd,'cwd':str(root),
 'scope':'Actual original Core/UIRouting/Host package compilation and selected source-bound XCTest classes. Catalog/native transports are explicitly injected doubles; Apple AppIntents SDK and native UI acceptance NOT_RUN.',
 'source_inputs_sha256':digest(sourcefile),'cache_preservation_sha256':digest(base/'PRESERVATION.json'),
 'free_before':free,'reserve_bytes':256*1024*1024,'termination_threshold_bytes':288*1024*1024,
 'version':subprocess.check_output(['/usr/local/bin/swift','--version'],text=True).strip()}
with (out/'stdout.log').open('xb') as stdout,(out/'stderr.log').open('xb') as stderr:
 p=subprocess.Popen(cmd,cwd=root,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,start_new_session=True)
 record['pid']=p.pid;record['pgid']=p.pid
 (out/'START.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps({'event':'STARTED','pid':p.pid,'pgid':p.pid,'command':cmd,'free':free,'utc':utc()}),flush=True)
 samples=[]
 stopped=False
 while p.poll() is None:
  current=shutil.disk_usage(root).free
  samples.append({'utc':utc(),'free':current})
  if current<288*1024*1024:
   stopped=True;record['capacity_stop_at']=utc()
   os.killpg(p.pid,signal.SIGTERM)
   try:p.wait(timeout=12)
   except subprocess.TimeoutExpired:
    os.killpg(p.pid,signal.SIGKILL);p.wait(timeout=10)
   break
  time.sleep(2)
 record['exit']=p.wait()
record['finished_at']=utc();record['free_after']=shutil.disk_usage(root).free
record['minimum_observed_free']=min([free,record['free_after']]+[s['free'] for s in samples])
record['status']='NOT_COMPLETE_CAPACITY' if stopped else ('PASS' if record['exit']==0 else 'FAIL')
record['inputs_unchanged']=all((root/r['path']).is_file() and digest(root/r['path'])==r['sha256'] for r in paths)
if not record['inputs_unchanged']:record['status']='FAIL_SOURCE_CHANGED'
record['logs']={n:{'bytes':(out/n).stat().st_size,'sha256':digest(out/n)} for n in ['stdout.log','stderr.log']}
(out/'DISK_SAMPLES.json').write_text(json.dumps(samples,indent=2)+'\n')
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'event':'FINISHED','status':record['status'],'exit':record['exit'],'free':record['free_after'],'result_sha256':digest(out/'RESULT.json')}),flush=True)
