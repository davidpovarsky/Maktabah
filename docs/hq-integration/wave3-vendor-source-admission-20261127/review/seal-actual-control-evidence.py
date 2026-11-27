import pathlib,json,hashlib,os,pwd,time,ctypes,select,tarfile,collections,re,io
base=pathlib.Path("/mnt/development/projects/diagnostics/otzaria-wave3-vendor-admission-20261127")
receipt=base/"attempt-3/RUN_RESULT.json"
lib=ctypes.CDLL(None,use_errno=True);fd=lib.inotify_init1(os.O_CLOEXEC|os.O_NONBLOCK);assert fd>=0
assert lib.inotify_add_watch(fd,os.fsencode(receipt.parent),0x8|0x80)>=0
deadline=time.monotonic()+1200
while not receipt.exists():
 if time.monotonic()>deadline:raise TimeoutError("Owned source-control completion receipt not written")
 if select.select([fd],[],[],min(60,deadline-time.monotonic()))[0]:os.read(fd,65536)
os.close(fd)
run=json.loads(receipt.read_bytes())
r=pathlib.Path("/mnt/development/projects/worktrees/Maktabah-wave3-vendor-admission-private-20261127")
dst=r/"docs/hq-integration/wave3-vendor-source-admission-20261127/validation"
assert not dst.exists();dst.mkdir(parents=True);owner=pwd.getpwnam("ubuntu")
for p in [dst,dst.parent]:os.chown(p,owner.pw_uid,owner.pw_gid)
def sha(b):return hashlib.sha256(b).hexdigest()
for name,row in run["source_inputs"].items():
 raw=(r/name).read_bytes();assert len(raw)==row["bytes"] and sha(raw)==row["sha256"],name
 p=base/"attempt-3/sources"/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
result=json.loads((base/"attempt-3/current-real-git/RESULT.json").read_bytes())
old=json.loads((base/"attempt-2/ORIGINAL_NORMAL_RESULT.json").read_bytes())
counts=collections.Counter((row.get("route","direct"),row.get("outcome","boundary")) for row in result.get("records",[]))
summary={"scope":"ACTUAL_SOURCE_CONTROLS_ONLY","native":"NOT_RUN","metro":"NOT_RUN","app_sdk":"NOT_RUN",
 "current":{"status":result.get("status"),"tests":result.get("tests"),"failures":result.get("failures"),"errors":result.get("errors"),"process_exit":run["commands"][0]["exit"]},
 "original_normal":{"tests":old["tests_run"],"failures":old["failures"],"errors":old["errors"],"process_exit":0},
 "entrypoint_outcomes":[{"route":a,"outcome":b,"count":n} for (a,b),n in sorted(counts.items())],
 "original_refusals":[row for row in result.get("records",[]) if row.get("route","").startswith("original_")],
 "source_inputs":run["source_inputs"],"raw_receipts":{}}
for path in [receipt,base/"attempt-3/current-real-git/RESULT.json",base/"attempt-3/current-real-git/CONTROL_FIXTURE.json",base/"attempt-2/ORIGINAL_NORMAL_RESULT.json"]:
 if path.exists():summary["raw_receipts"][str(path)]={"bytes":path.stat().st_size,"sha256":sha(path.read_bytes())}
paths=sorted(p for attempt in ["attempt-1","attempt-2","attempt-3"] for p in (base/attempt).rglob("*") if p.is_file() or p.is_symlink())
index={};total=0
for p in paths:
 name=str(p.relative_to(base))
 if p.is_symlink():index[name]={"type":"symlink","target":os.readlink(p)}
 else:
  raw=p.read_bytes();total+=len(raw);index[name]={"type":"file","bytes":len(raw),"sha256":sha(raw)}
assert total<67108864,("Unexpected source-control evidence size",total)
archive=dst/"actual-source-controls.tar.gz"
with tarfile.open(archive,"w:gz",dereference=False) as t:
 for p in paths:t.add(p,arcname=str(p.relative_to(base)),recursive=False)
assert archive.stat().st_size<16777216
with tarfile.open(archive,"r:gz") as t:
 members=t.getmembers();assert len(members)==len(index) and set(m.name for m in members)==set(index)
 for m in members:
  row=index[m.name]
  if row["type"]=="symlink":assert m.issym() and m.linkname==row["target"]
  else:
   assert m.isfile();raw=t.extractfile(m).read();assert len(raw)==row["bytes"] and sha(raw)==row["sha256"]
summary["archive"]={"path":str(archive),"bytes":archive.stat().st_size,"sha256":sha(archive.read_bytes()),"members":len(index),"regular_payload_bytes":total,"verified_all_members":True}
(dst/"ARCHIVE_INDEX.json").write_text(json.dumps(index,sort_keys=True,indent=2)+"\n")
(dst/"CONTROL_SUMMARY.json").write_text(json.dumps(summary,sort_keys=True,indent=2)+"\n")
for p in dst.iterdir():os.chown(p,owner.pw_uid,owner.pw_gid)
print(json.dumps(summary))
