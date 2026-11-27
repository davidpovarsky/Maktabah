import subprocess,pathlib,json,hashlib,datetime,os,time
w=pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave2-firstpage-guard-20261127")
source=w/"Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift"
d=w/"docs/hq-integration/wave2-20261127/reader/firstpage-guard/oracle-syntax"
assert not d.exists()
exe=pathlib.Path("/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swift-frontend")
def sha(p):
 h=hashlib.sha256()
 with p.open("rb") as f:
  while b:=f.read(1024*1024):h.update(b)
 return h.hexdigest()
assert not exe.is_symlink()
with exe.open("rb") as f: magic=f.read(4)
assert magic==bytes([127,69,76,70]),magic
assert sha(exe)=="d98470fed50d4efc0075bcbd45ba1f908382dc9222c2b8213d1ff074efaa2083"
assert sha(source)=="70d64d593d22dbfb512b74bd8d6ed9d259c9404b8a47072ced30f5bc18d989a2"
free=os.statvfs(w).f_bavail*os.statvfs(w).f_frsize; assert free>696254464,free
d.mkdir()
st=exe.stat()
v=subprocess.run([str(exe),"-version"],capture_output=True,timeout=10)
(d/"version.stdout.log").write_bytes(v.stdout);(d/"version.stderr.log").write_bytes(v.stderr)
argv=[str(exe),"-parse","-parse-as-library","-swift-version","6","-target","arm64-apple-ios27.0-simulator",str(source)]
start=datetime.datetime.now(datetime.timezone.utc).isoformat();t=time.monotonic()
r=subprocess.run(argv,capture_output=True,timeout=30)
elapsed=time.monotonic()-t
(d/"parse.stdout.log").write_bytes(r.stdout);(d/"parse.stderr.log").write_bytes(r.stderr)
assert sha(source)=="70d64d593d22dbfb512b74bd8d6ed9d259c9404b8a47072ced30f5bc18d989a2"
result={"schema":1,"status":"WHOLE_FILE_SWIFT_SYNTAX_PASS" if r.returncode==0 else "WHOLE_FILE_SWIFT_SYNTAX_FAIL","startedUTC":start,"endedUTC":datetime.datetime.now(datetime.timezone.utc).isoformat(),"elapsedSeconds":elapsed,"host":os.uname()._asdict() if hasattr(os.uname(),"_asdict") else list(os.uname()),"compiler":{"path":str(exe),"bytes":st.st_size,"dev":st.st_dev,"inode":st.st_ino,"mtimeNs":st.st_mtime_ns,"sha256":"d98470fed50d4efc0075bcbd45ba1f908382dc9222c2b8213d1ff074efaa2083","ELF":True,"versionExit":v.returncode,"version":v.stdout.decode(errors="replace")},"source":{"path":str(source),"bytes":source.stat().st_size,"sha256":sha(source)},"argv":argv,"returncode":r.returncode,"logs":[{"path":str(p.relative_to(d)),"bytes":p.stat().st_size,"sha256":sha(p)} for p in sorted(d.glob("*.log"))],"freeBeforeBytes":free,"freeAfterBytes":os.statvfs(w).f_bavail*os.statvfs(w).f_frsize,"scope":"Linux-host Swift frontend syntax parse with Apple target only; no SDK argument, imports/typechecking, app build, Simulator, native test or behavioral execution","behavioralValidation":"NOT_RUN"}
(d/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result))
