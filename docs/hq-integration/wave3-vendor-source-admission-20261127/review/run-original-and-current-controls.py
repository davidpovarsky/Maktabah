import pathlib,subprocess,json,os,hashlib,time,pwd
r=pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave3-vendor-admission-private-20261127")
out=pathlib.Path("/mnt/development/projects/diagnostics/otzaria-wave3-vendor-admission-20261127/attempt-2")
assert not out.exists(); out.mkdir(parents=True);owner=pwd.getpwnam("ubuntu");os.chown(out,owner.pw_uid,owner.pw_gid);os.chown(out.parent,owner.pw_uid,owner.pw_gid)
free=os.statvfs(r).f_bavail*os.statvfs(r).f_frsize;assert free>687865856+268435456
inputs={str(p.relative_to(r)):{"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest()} for p in [r/"Scripts/CI"/n for n in ["final_integration_source.py","hq-stage2-focused-apple.py","prepare-normal-ios-workspace.py","reviewed-vendor-source.inputs.json","fixtures/reviewed-vendor-legacy-inputs.json","test-normal-ios-workspace.py","test-reviewed-vendor-source.py"]]}
(out/"SOURCE_INPUTS.json").write_text(json.dumps(inputs,indent=2)+"\n")
commands=[
 ["python3","Scripts/CI/test-normal-ios-workspace.py","--report",str(out/"ORIGINAL_NORMAL_RESULT.json")],
 ["python3","Scripts/CI/test-reviewed-vendor-source.py","--repository",str(r),"--output",str(out/"current-real-git")]]
rows=[]
for number,command in enumerate(commands):
 log=out/("original-normal.log" if number==0 else "current-real-git.log")
 with log.open("wb") as stream:
  start=time.time();p=subprocess.Popen(["runuser","-u","ubuntu","--",*command],cwd=r,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
  (out/("process-"+str(number)+".json")).write_text(json.dumps({"pid":p.pid,"pgid":os.getpgid(p.pid),"argv":command,"start_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime(start))},indent=2)+"\n")
  code=p.wait(timeout=1500)
 rows.append({"argv":command,"exit":code,"duration_s":time.time()-start,"log":str(log),"bytes":log.stat().st_size,"sha256":hashlib.sha256(log.read_bytes()).hexdigest()})
receipt={"scope":"ACTUAL_PYTHON_GIT_SOURCE_CONTROLS_ONLY","source_inputs":inputs,"commands":rows,"free_before":free,"free_after":os.statvfs(r).f_bavail*os.statvfs(r).f_frsize,"native":"NOT_RUN"}
(out/"RUN_RESULT.json").write_text(json.dumps(receipt,indent=2)+"\n")
print(json.dumps(receipt))
