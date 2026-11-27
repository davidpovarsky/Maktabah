import pathlib,json,hashlib,shutil,subprocess,time,datetime,os,signal,sys
root=pathlib.Path(sys.argv[1]);task=root.parent
def size(): return sum(p.lstat().st_blocks*512 for p in task.rglob('*'))
if shutil.disk_usage('/home').free<1342177280 or size()>104857600: raise RuntimeError('reserve')
s=root/'OwnerControls.swift';module=task/'actual-modules-attempt-3/candidate/out';cache=task/'actual-modules-attempt-1/module-cache';binary=root/'OwnerControls'
argv=['/usr/local/bin/swiftc','-swift-version','6','-parse-as-library','-module-cache-path',str(cache),'-I',str(module),'-L',str(module),'-lOtzariaActionCore','-lOtzariaUIRouting','-lChavrusaUIRoutingHost',str(s),'-o',str(binary)]
copies=[]
for name in ['OtzariaActionCore_OtzariaActionCore.bundle','OtzariaUIRouting_OtzariaUIRouting.bundle']:
 src=module/name;dst=root/name;shutil.copytree(src,dst)
 for a in src.rglob('*'):
  if a.is_file():
   b=dst/a.relative_to(src)
   if a.read_bytes()!=b.read_bytes():raise RuntimeError('bundle copy mismatch')
   copies.append({'original':str(a),'copy':str(b),'sha256':hashlib.sha256(b.read_bytes()).hexdigest()})
(root/'EXACT_BUNDLE_INPUTS.json').write_text(json.dumps(copies,sort_keys=True,indent=2)+'\n')
result={'schema':'otzaria.viewer-parent.owner-source-controls.v1','started':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':hashlib.sha256(s.read_bytes()).hexdigest(),'argv':argv,'before_free':shutil.disk_usage('/home').free,'boundary':'Exact source bodies; explicit UIKit/app-domain boundaries; native NOT_RUN'}
for name,args in [('compile',argv),('run',[str(binary)])]:
 env=dict(os.environ);env['LD_LIBRARY_PATH']=str(module)
 with (root/(name+'.stdout')).open('xb') as out,(root/(name+'.stderr')).open('xb') as err:
  proc=subprocess.Popen(args,stdout=out,stderr=err,env=env,start_new_session=True);result[name+'_pid']=proc.pid
  started=time.monotonic()
  while proc.poll() is None:
   if shutil.disk_usage('/home').free<1342177280 or size()>104857600 or time.monotonic()-started>40:
    os.killpg(proc.pid,signal.SIGTERM);proc.wait();raise RuntimeError('owned bounded control stop')
   time.sleep(.25)
 result[name+'_exit']=proc.returncode
 if proc.returncode:break
result['finished']=datetime.datetime.now(datetime.timezone.utc).isoformat();result['after_free']=shutil.disk_usage('/home').free;result['own_allocated_bytes']=size();result['files']=[{'path':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in root.iterdir() if p.is_file()]
(root/'RESULT.json').write_text(json.dumps(result,sort_keys=True,indent=2)+'\n');print(json.dumps(result))
for p in [root/'compile.stderr',root/'run.stdout',root/'run.stderr']:
 if p.exists() and p.stat().st_size: print(p.name);print(p.read_text()[-14000:])
